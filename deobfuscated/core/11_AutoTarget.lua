--[[
  AutoTarget —— 自动选怪：/targetenemy 宏按键绑定、外部程序触发的会话门控与状态数据包
  原始文件：286686.lua（TOC 第 11 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local AUTO_TARGET_ACTION = "auto_target"
local AUTO_TARGET_MACRO =
    "/targetenemy [combat,nochanneling,noexists][combat,nochanneling,dead]\n/run P8BA6426E.RecordAutoTargetAttempt()"
local PACKET_BASE = 13631488
P8BA6426E.AUTO_TARGET_KEYS = {}
for i, key in ipairs(P8BA6426E.ACTION_KEY_ORDER) do
    if i > 127 then
        break
    end
    table.insert(P8BA6426E.AUTO_TARGET_KEYS, key)
end
local state = { keyIndex = 0, key = nil, ack = 0, sequence = 0, bound = false }
local function readBoolean(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(function(...)
        local result = fn(...)
        if result == true then
            return true
        end
        if result == false then
            return false
        end
        return nil
    end, ...)
    if ok then
        return result
    end
    return nil
end
local function hasKeyboardFocus()
    if type(GetCurrentKeyBoardFocus) ~= "function" then
        return false
    end
    local ok, result = pcall(GetCurrentKeyBoardFocus)
    if not ok then
        return nil
    end
    return result ~= nil
end
local sessionReady = false
local sessionSpecID = nil
local function resetSession()
    sessionReady = false
    sessionSpecID = nil
end
local function hasLiveHostileTarget()
    return readBoolean(UnitExists, "target") == true
        and (
            readBoolean(UnitIsDeadOrGhost, "target") == false
            and readBoolean(UnitCanAttack, "player", "target") == true
        )
end
function P8BA6426E.IsRemoteAutoTargetSessionReady()
    local inCombat = readBoolean(UnitAffectingCombat, "player")
    if inCombat == false or readBoolean(P8BA6426E.IsRangedDamageSpec) ~= true then
        resetSession()
        return false
    end
    if inCombat ~= true then
        return false
    end
    local specID = P8BA6426E.SpecializationAPI.GetSpecializationInfo(P8BA6426E.SpecializationAPI.GetSpecialization())
    if sessionSpecID ~= specID then
        sessionReady = false
        sessionSpecID = specID
    end
    if hasLiveHostileTarget() then
        sessionReady = true
    end
    return sessionReady
end
local sessionFrame = CreateFrame("Frame")
sessionFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
sessionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
sessionFrame:SetScript("OnEvent", resetSession)
local function conflictsWithControlKeys()
    if not state.bound or type(state.key) ~= "string" or type(P8BA6426E.DB) ~= "table" then
        return false
    end
    local boundKey = P8BA6426E.NormalizeActionKey(state.key)
    local function same(key)
        return boundKey ~= nil and boundKey == P8BA6426E.NormalizeActionKey(key)
    end
    return same(P8BA6426E.DB.masterKey) or same(P8BA6426E.DB.burstKey) or same(P8BA6426E.DB.aoeKey)
end
local function rebindIfConflicting()
    if not conflictsWithControlKeys() or readBoolean(InCombatLockdown) ~= false then
        return
    end
    if type(P8BA6426E.RefreshMacroBindings) == "function" then
        pcall(P8BA6426E.RefreshMacroBindings)
    end
end
local function computeTargetState()
    local sessionReady = P8BA6426E.IsRemoteAutoTargetSessionReady()
    if
        not state.bound
        or conflictsWithControlKeys()
        or type(P8BA6426E.DB) ~= "table"
        or P8BA6426E.DB.masterSwitch ~= true
        or readBoolean(P8BA6426E.GetAutoTargetEnabled) ~= true
        or readBoolean(UnitAffectingCombat, "player") ~= true
        or readBoolean(UnitIsDeadOrGhost, "player") ~= false
        or hasKeyboardFocus() ~= false
    then
        return 0
    end
    if readBoolean(P8BA6426E.IsRangedDamageSpec) == true and not sessionReady then
        return 0
    end
    local targetExists = readBoolean(UnitExists, "target")
    if targetExists == false then
        return 1
    end
    if targetExists ~= true then
        return 4
    end
    local targetDead = readBoolean(UnitIsDeadOrGhost, "target")
    if targetDead == true then
        return 1
    end
    if targetDead ~= false then
        return 4
    end
    local canAttack = readBoolean(UnitCanAttack, "player", "target")
    if canAttack == true then
        return 2
    end
    if canAttack ~= false then
        return 4
    end
    if readBoolean(UnitCanAssist, "player", "target") == true then
        return 3
    end
    return 4
end
function P8BA6426E.IsRemoteAutoTargetGateOpen()
    if not P8BA6426E.IsRemoteAutoTargetSessionReady() then
        return false
    end
    return hasLiveHostileTarget() or computeTargetState() ~= 0
end
local function collectUsedKeys()
    local used = {}
    local function add(key)
        local actionKey = P8BA6426E.NormalizeActionKey(key)
        if actionKey then
            used[actionKey] = true
        end
    end
    for _, bindKey in pairs(P8BA6426E.ACTION_TO_KEY or {}) do
        add(bindKey)
    end
    if type(P8BA6426E.DB) == "table" then
        add(P8BA6426E.DB.masterKey)
        add(P8BA6426E.DB.burstKey)
        add(P8BA6426E.DB.aoeKey)
    end
    if
        P8BA6426E.classData
        and (P8BA6426E.classData.raidFocusEnabled == true and type(P8BA6426E.GetRaidFocusKeys) == "function")
    then
        local ok, result = pcall(P8BA6426E.GetRaidFocusKeys)
        if ok and type(result) == "table" then
            for _, key in ipairs(result) do
                add(key)
            end
        end
    end
    return used
end
local function pickFreeKey()
    local used = collectUsedKeys()
    for i, autoTargetKey in ipairs(P8BA6426E.AUTO_TARGET_KEYS) do
        if not used[P8BA6426E.NormalizeActionKey(autoTargetKey)] then
            return autoTargetKey, i
        end
    end
    return nil, 0
end
function P8BA6426E.RecordAutoTargetAttempt()
    state.ack = (state.ack + 1) % 32
    return true
end
-- 自动选怪数据包：基数 + 按键序号*8192 + 目标状态*1024 + 回执*32 + 序号
function P8BA6426E.GetAutoTargetPacket()
    state.sequence = state.sequence % 31 + 1
    rebindIfConflicting()
    return (((PACKET_BASE + state.keyIndex * 8192) + computeTargetState() * 1024) + state.ack * 32) + state.sequence
end
function P8BA6426E.ApplyAutoTargetBinding()
    if readBoolean(InCombatLockdown) == true then
        return false
    end
    state.keyIndex = 0
    state.key = nil
    state.bound = false
    if
        type(P8BA6426E.classData) ~= "table"
        or type(P8BA6426E.CreateSecureButton) ~= "function"
        or type(P8BA6426E.NormalizeActionKey) ~= "function"
    then
        return false
    end
    local key, keyIndex = pickFreeKey()
    if not key then
        return false
    end
    local ok = pcall(P8BA6426E.CreateSecureButton, AUTO_TARGET_ACTION, key, AUTO_TARGET_MACRO)
    if not ok then
        return false
    end
    state.keyIndex = keyIndex
    state.key = key
    state.bound = true
    return true
end
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("target.packet", "sampled", function()
        return P8BA6426E.GetAutoTargetPacket
    end, function(getAutoTargetPacket)
        P8BA6426E.GetAutoTargetPacket = getAutoTargetPacket
    end)
    logicDiagnostics.Declare("target.binding", "sampled", function()
        return P8BA6426E.ApplyAutoTargetBinding
    end, function(applyAutoTargetBinding)
        P8BA6426E.ApplyAutoTargetBinding = applyAutoTargetBinding
    end)
end
