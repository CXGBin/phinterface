--[[
  SpellSuccessTracker —— 施法成功追踪：基于 UNIT_SPELLCAST_SENT + castGUID 记录最近 4 次关键技能成功施放（供像素条输出）
  原始文件：63785f.lua（TOC 第 6 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local successHistory = {}
local pendingSentCasts = {}
local trackedSpells = {}
local trackedSpellAlias = {}
local catalogSpecID = nil
local generation = 1
P8BA6426E.successEventUnknownIDs = {}
local function isReadableNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end
local function resetHistory()
    wipe(successHistory)
    wipe(pendingSentCasts)
    generation = generation % 99 + 1
    P8BA6426E.playerSucceededSpellID = 0
    P8BA6426E.playerSucceededGeneration = generation
end
-- 按专精建立需要追踪“施法成功”的技能集合（有冷却或在时间轴目录中的技能）
local function refreshFocusedSuccessCatalog()
    if catalogSpecID and (InCombatLockdown and InCombatLockdown()) then
        return
    end
    local _classFile, _specIndex, specID = P8BA6426E.GetPlayerClassSpec()
    if catalogSpecID ~= specID then
        catalogSpecID = specID
        resetHistory()
    end
    wipe(trackedSpells)
    wipe(trackedSpellAlias)
    wipe(P8BA6426E.successEventUnknownIDs)
    local catalog = P8BA6426E.successSpellCatalog and P8BA6426E.successSpellCatalog[specID]
    if not catalog then
        return
    end
    local function trackSpell(spellID, actionSpellID)
        local ok, _start, baseCooldownMs = pcall(function()
            if not GetSpellBaseCooldown then
                return nil, nil
            end
            return GetSpellBaseCooldown(spellID)
        end)
        if (not ok or not isReadableNumber(baseCooldownMs)) and spellID ~= actionSpellID then
            ok, _start, baseCooldownMs = pcall(function()
                if not GetSpellBaseCooldown then
                    return nil, nil
                end
                return GetSpellBaseCooldown(actionSpellID)
            end)
        end
        if
            (not ok or not isReadableNumber(baseCooldownMs))
            and (catalog.gcd and isReadableNumber(catalog.gcd[spellID]))
        then
            ok, baseCooldownMs = true, catalog.gcd[spellID]
        end
        if catalog.timeline[spellID] then
            trackedSpells[spellID] = true
        elseif ok and isReadableNumber(baseCooldownMs) then
            trackedSpells[spellID] = baseCooldownMs > 0
        else
            P8BA6426E.successEventUnknownIDs[spellID] = true
        end
        trackedSpellAlias[spellID] = actionSpellID
    end
    for spellID, actionSpellID in pairs(catalog.actions) do
        trackSpell(spellID, actionSpellID)
        if C_Spell and C_Spell.GetOverrideSpell then
            local ok, overrideID = pcall(C_Spell.GetOverrideSpell, spellID)
            if ok and (isReadableNumber(overrideID) and (overrideID > 0 and overrideID ~= spellID)) then
                trackSpell(overrideID, actionSpellID)
            end
        end
    end
    for spellID in pairs(catalog.timeline) do
        trackedSpells[spellID] = true
        trackedSpellAlias[spellID] = trackedSpellAlias[spellID] or spellID
    end
end
function P8BA6426E.RecordFocusedSpellSuccess(spellID, castGUID)
    local now = GetTime()
    local sent = castGUID and pendingSentCasts[castGUID]
    if not sent or now - sent.time > 30 then
        return
    end
    pendingSentCasts[castGUID] = nil
    if not trackedSpells[spellID] then
        return
    end
    generation = generation % 99 + 1
    table.insert(successHistory, 1, { generation = generation, spellID = spellID })
    if #successHistory > 4 then
        table.remove(successHistory)
    end
    P8BA6426E.playerSucceededSpellID = spellID
    P8BA6426E.playerSucceededGeneration = generation
end
function P8BA6426E.GetFocusedSuccessHistory(index)
    local record = successHistory[index]
    if record then
        return record.generation, record.spellID
    end
    return 0, 0
end
local sentFrame = CreateFrame("Frame")
sentFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
sentFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
sentFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
sentFrame:RegisterEvent("SPELLS_CHANGED")
sentFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
sentFrame:SetScript("OnEvent", function(_, event, unit, _, castGUID, spellID)
    if event == "UNIT_SPELLCAST_SENT" then
        if unit ~= "player" or not castGUID then
            return
        end
        local now = GetTime()
        for guid, sent in pairs(pendingSentCasts) do
            if now - sent.time > 30 then
                pendingSentCasts[guid] = nil
            end
        end
        pendingSentCasts[castGUID] = { time = now, spellID = spellID }
    else
        refreshFocusedSuccessCatalog()
    end
end)
P8BA6426E.RefreshFocusedSuccessCatalog = refreshFocusedSuccessCatalog
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("success.rebuild", "sampled", function()
        return refreshFocusedSuccessCatalog
    end, function(fn)
        refreshFocusedSuccessCatalog = fn
    end)
    logicDiagnostics.Declare("success.events", "sampled", function()
        return P8BA6426E.RecordFocusedSpellSuccess
    end, function(recordFocusedSpellSuccess)
        P8BA6426E.RecordFocusedSpellSuccess = recordFocusedSpellSuccess
    end)
end
