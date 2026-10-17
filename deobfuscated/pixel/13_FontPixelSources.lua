--[[
  FontPixelSources —— 像素字段数据源：宠物法术、技能是否学会、冷却/充能/真实充能读取、光环容器构建与时长/层数绑定
  原始文件：00d496.lua（TOC 第 13 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local fontPixelSources = {}
P8BA6426E.FontPixelSources = fontPixelSources
function fontPixelSources.ResolvePetSpell(candidateSpellIDs)
    assert(
        C_SpellBook and (C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemInfo),
        "宠物法术书接口不可用"
    )
    local petBank =
        assert(Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet), "宠物法术书身份不可用")
    local spellItemType =
        assert(Enum.SpellBookItemType and Enum.SpellBookItemType.Spell, "宠物法术书类型不可用")
    local numPetSpells = C_SpellBook.HasPetSpells()
    assert(not (issecretvalue and issecretvalue(numPetSpells)), "宠物法术书数量不可读")
    if numPetSpells == nil then
        return nil, nil, petBank, false
    end
    assert(
        type(numPetSpells) == "number" and (numPetSpells >= 0 and numPetSpells % 1 == 0),
        "宠物法术书数量无效"
    )
    local slotBySpellOrAction = {}
    for i = 1, numPetSpells, 1 do
        local info = assert(C_SpellBook.GetSpellBookItemInfo(i, petBank), "宠物法术书本帧不完整")
        assert(
            not (issecretvalue and issecretvalue(info.itemType)) and type(info.itemType) == "number",
            "宠物法术书类型不可读"
        )
        if info.itemType == spellItemType then
            local spellID, actionID = info.spellID, info.actionID
            assert(
                not (issecretvalue and (issecretvalue(spellID) or issecretvalue(actionID)))
                    and (
                        type(spellID) == "number"
                        and (
                            spellID > 0
                            and (
                                spellID % 1 == 0
                                and (type(actionID) == "number" and (actionID > 0 and actionID % 1 == 0))
                            )
                        )
                    ),
                "宠物技能身份不可读"
            )
            assert(
                not (issecretvalue and issecretvalue(info.isPassive)) and type(info.isPassive) == "boolean",
                "宠物被动状态不可读"
            )
            if not info.isPassive then
                slotBySpellOrAction[spellID], slotBySpellOrAction[actionID] = i, i
            end
        end
    end
    for _, candidate in ipairs(candidateSpellIDs) do
        if slotBySpellOrAction[candidate] then
            return candidate, slotBySpellOrAction[candidate], petBank, true
        end
    end
    return nil, nil, petBank, true
end
local function findHighestLearned(spellIDs)
    assert(C_SpellBook and C_SpellBook.IsSpellKnown, "严格技能学习接口不可用")
    for _, spellID in ipairs(spellIDs) do
        local known = C_SpellBook.IsSpellKnown(spellID)
        assert(
            not (issecretvalue and issecretvalue(known)) and type(known) == "boolean",
            "严格技能学习状态不可读"
        )
        if known then
            return spellID
        end
    end
end
function fontPixelSources.PrepareField(field)
    local cooldownIDs = field.spellIDs or { field.spellID }
    local cooldownIDSet
    if field.spellIDs then
        cooldownIDSet = {}
        for _, id in ipairs(cooldownIDs) do
            cooldownIDSet[id] = true
        end
    end
    return {
        cooldownIDs = cooldownIDs,
        cooldownIDSet = cooldownIDSet,
        knownIDs = field.knownSpellID and { field.knownSpellID } or cooldownIDs,
    }
end
function fontPixelSources.IsUnlearned(field, options, prepared)
    if field.knownExempt then
        return false
    end
    if field.actor == "pet" then
        local petSpellID, _slot, _bank, readable =
            fontPixelSources.ResolvePetSpell(prepared and prepared.knownIDs or field.spellIDs)
        return readable == true and petSpellID == nil
    end
    if field.rankPolicy == "highest_learned" then
        local knownIDs = prepared and prepared.knownIDs or field.spellIDs
        assert(type(knownIDs) == "table" and #knownIDs > 0, "明确等级链缺失")
        return findHighestLearned(knownIDs) == nil
    end
    if options.traitNode and field.knownTraitNodeID then
        assert(
            C_ClassTalents and (C_ClassTalents.GetActiveConfigID and (C_Traits and C_Traits.GetNodeInfo)),
            "天赋节点接口不可用"
        )
        local activeConfigID = C_ClassTalents.GetActiveConfigID()
        assert(type(activeConfigID) == "number", "当前天赋配置不可读")
        local nodeInfo = C_Traits.GetNodeInfo(activeConfigID, field.knownTraitNodeID)
        assert(nodeInfo and type(nodeInfo.activeRank) == "number", "当前天赋节点不可读")
        return nodeInfo.activeRank == 0
    end
    if options.overrideBook and field.knownPolicy == "override_book" then
        local isSpellKnownOrInSpellBook
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            local playerBank = Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "player"
            isSpellKnownOrInSpellBook = C_SpellBook.IsSpellKnownOrInSpellBook(field.spellID, playerBank, true)
        elseif IsSpellKnown then
            isSpellKnownOrInSpellBook = IsSpellKnown(field.spellID)
        else
            error("替换技能学习接口不可用")
        end
        return not isSpellKnownOrInSpellBook
    end
    local knownIDs = prepared and prepared.knownIDs
        or field.knownSpellID and { field.knownSpellID }
        or field.spellIDs
        or { field.spellID }
    if not options.aliasAfterError then
        assert(P8BA6426E.IsSpellKnown, "技能学习状态接口不可用")
    end
    local lastError
    for _, id in ipairs(knownIDs) do
        if options.aliasAfterError then
            local ok, result = pcall(P8BA6426E.IsSpellKnown, id)
            if ok and result then
                return false
            end
            if not ok then
                lastError = result
            end
        else
            if P8BA6426E.IsSpellKnown(id) then
                return false
            end
        end
    end
    if lastError then
        error(lastError)
    end
    return true
end
function fontPixelSources.IsReplacedSpell(field, spellID, idSet)
    if field.spellIDs and C_Spell.GetOverrideSpell then
        local ok, overrideID = pcall(C_Spell.GetOverrideSpell, spellID, 0, false)
        return ok and (type(overrideID) == "number" and (overrideID ~= spellID and idSet[overrideID] == true))
    end
    return false
end
local function callWithPolicy(policy, func, firstArg, ...)
    if policy.bestEffort then
        return pcall(func, firstArg, ...)
    end
    return true, func(firstArg, ...)
end
-- 读取冷却 DurationObject：宠物技能走法术书，普通技能可按 GetSpellCooldownDuration 或充能恢复读取
function fontPixelSources.ReadCooldown(field, policy, prepared)
    local cooldownIDs = prepared and prepared.cooldownIDs or field.spellIDs or { field.spellID }
    if field.actor == "pet" then
        local petSpellID, slot, bank = fontPixelSources.ResolvePetSpell(cooldownIDs)
        if not petSpellID then
            return nil, false, 0, 0
        end
        assert(C_SpellBook.GetSpellBookItemCooldownDuration, "宠物冷却接口不可用")
        local duration = C_SpellBook.GetSpellBookItemCooldownDuration(slot, bank, policy.ignoreGCD)
        return duration, true, duration and 1 or 0, 0
    end
    if field.rankPolicy == "highest_learned" then
        local learned = findHighestLearned(cooldownIDs)
        cooldownIDs = learned and { learned } or {}
    end
    local chargeRecoveryOnly = policy.chargeRecoveryOnly and field.chargeRecoveryOnly
    local cooldownIDSet = prepared and prepared.cooldownIDSet
    if chargeRecoveryOnly and (field.spellIDs and not cooldownIDSet) then
        cooldownIDSet = {}
        for _, id in ipairs(cooldownIDs) do
            cooldownIDSet[id] = true
        end
    end
    local duration, readable, sourceKind = nil, false, 0
    local hadError = false
    for _, id in ipairs(cooldownIDs) do
        assert(type(id) == "number", "技能冷却必须明确声明本体数字 ID")
        if
            (not (field.petOnly or field.learnedOnly) or P8BA6426E.IsSpellKnown(id))
            and (not chargeRecoveryOnly or not fontPixelSources.IsReplacedSpell(field, id, cooldownIDSet))
        then
            if chargeRecoveryOnly then
                if C_Spell.GetSpellChargeDuration then
                    local ok, result = callWithPolicy(policy, C_Spell.GetSpellChargeDuration, id)
                    if ok then
                        duration, readable = result, true
                        sourceKind = duration and 2 or 0
                    else
                        hadError = true
                    end
                end
            else
                local ok, result = callWithPolicy(policy, C_Spell.GetSpellCooldownDuration, id, policy.ignoreGCD)
                if ok then
                    duration, readable = result, true
                    sourceKind = duration and 1 or 0
                else
                    hadError = true
                end
            end
            if duration then
                break
            end
        end
    end
    if not duration and hadError then
        readable = false
    end
    return duration, readable, sourceKind, 0
end
local function isPlainNil(v)
    return not (issecretvalue and issecretvalue(v)) and v == nil
end
function fontPixelSources.ReadCharge(field, displayOnly)
    if displayOnly then
        local chargeDisplaySpellID = P8BA6426E.ResolveChargeDisplaySpellID(field.spellID, field.spellIDs)
        assert(chargeDisplaySpellID and C_Spell.GetSpellDisplayCount, "充能显示接口不可用")
        return C_Spell.GetSpellDisplayCount(chargeDisplaySpellID)
    end
    local count
    if field.fallbackAuraSpellID and (P8BA6426E.classData and P8BA6426E.classData.OverrideChargeDisplayCount) then
        count = P8BA6426E.classData.OverrideChargeDisplayCount(field.spellID)
    end
    if isPlainNil(count) and P8BA6426E.GetSpellChargeCount then
        count = P8BA6426E.GetSpellChargeCount(field.spellID, field.spellIDs)
    end
    if isPlainNil(count) and P8BA6426E.GetSpellChargeDisplayRaw then
        local ok, raw = P8BA6426E.GetSpellChargeDisplayRaw(field.spellID, field.spellIDs)
        if ok then
            count = raw
        end
    end
    if not isPlainNil(count) then
        return count, true
    end
    if C_Spell and C_Spell.GetSpellDisplayCount then
        local chargeDisplaySpellID = P8BA6426E.ResolveChargeDisplaySpellID(field.spellID, field.spellIDs)
        assert(chargeDisplaySpellID, "充能显示技能身份不可读")
        local ok, displayCount = pcall(C_Spell.GetSpellDisplayCount, chargeDisplaySpellID, 9, "?")
        if ok then
            return displayCount, true
        end
    end
    return count, not isPlainNil(count)
end
function fontPixelSources.ReadChargeRecovery(field)
    if not (C_Spell and C_Spell.GetSpellChargeDuration) then
        return nil, false
    end
    local spellID = field.spellID
    if field.spellIDs then
        spellID = P8BA6426E.ResolveChargeDisplaySpellID(field.spellID, field.spellIDs)
    end
    if not spellID then
        return nil, false
    end
    local ok, duration = pcall(C_Spell.GetSpellChargeDuration, spellID)
    if not ok then
        return nil, false
    end
    return duration, ok
end
function fontPixelSources.ReadTrueCharge(field)
    assert(C_Spell and C_Spell.GetSpellCharges, "真实充能接口不可用")
    local charges = C_Spell.GetSpellCharges(field.spellID)
    assert(type(charges) == "table", "技能未返回真实充能信息")
    local maxCharges = charges.maxCharges
    assert(
        not (issecretvalue and issecretvalue(maxCharges))
            and (type(maxCharges) == "number" and (maxCharges % 1 == 0 and (maxCharges >= 1 and maxCharges <= 9))),
        "真实充能上限不符合通用编码范围"
    )
    local currentCharges = charges.currentCharges
    if not (issecretvalue and issecretvalue(currentCharges)) then
        assert(
            type(currentCharges) == "number"
                and (currentCharges % 1 == 0 and (currentCharges >= 0 and currentCharges <= maxCharges)),
            "真实充能次数缺失或无效"
        )
    end
    local recovery, readable = fontPixelSources.ReadChargeRecovery(field)
    if not recovery and charges.isActive ~= false then
        readable = false
    end
    return currentCharges, recovery, readable
end
function fontPixelSources.AuraSource(field)
    local unit = field.unit or "player"
    local filter = field.filter or (unit == "target" and "HARMFUL|PLAYER" or "HELPFUL|PLAYER")
    local spellIDs = field.spellIDs or { field.spellID }
    return {
        unit = unit,
        filter = filter,
        spellIDs = spellIDs,
        identity = unit .. ("\0" .. (filter .. ("\0" .. table.concat(spellIDs, ",")))),
    }
end
function fontPixelSources.CreateAuraContainer(parent, source, slotKey, initializeFrame)
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetEnabled(false)
    local includeSpellIDs = {}
    for _, spellID in ipairs(source.spellIDs) do
        includeSpellIDs[spellID] = true
    end
    container:AddAuraSlot(
        slotKey,
        source.filter,
        { candidateFilters = { includeSpellIDs = includeSpellIDs }, initializeFrame = initializeFrame }
    )
    container:SetUnit(source.unit)
    return container
end
function fontPixelSources.BindDuration(auraFrame, glyph, textFormatter, curve)
    auraFrame:SetDurationText(glyph, {
        textFormatter = textFormatter,
        textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration },
    })
end
function fontPixelSources.BindStacks(auraFrame, glyph, countGlyph, formatter, companionText)
    glyph:SetText(companionText)
    countGlyph:SetText("")
    auraFrame:SetApplicationCount(countGlyph, { formatter = formatter })
end
