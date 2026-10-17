--[[
  HealingModeSwitch —— 治疗模式开关（forever 版本）：分配开/关按键并以数据包回报状态
  原始文件：2fc6ca.lua（TOC 第 12 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local PACKET_BASE = 12582912
local CANDIDATE_KEYS = {
    "CTRL-SHIFT-F9",
    "CTRL-SHIFT-F10",
    "CTRL-SHIFT-F11",
    "CTRL-SHIFT-F12",
    "CTRL-SHIFT-F1",
    "CTRL-SHIFT-F2",
    "CTRL-SHIFT-F3",
    "CTRL-SHIFT-F4",
    "CTRL-SHIFT-F5",
    "CTRL-SHIFT-F6",
    "CTRL-SHIFT-F7",
    "CTRL-SHIFT-F8",
}
local state = {
    onKey = nil,
    offKey = nil,
    onIndex = 0,
    offIndex = 0,
    ready = false,
    ack = 0,
    sequence = 0,
    pending = nil,
    refreshQueued = false,
    nextRetryAt = nil,
}
local function isSupported()
    return P8BA6426E.IsForeverHealingSupported and P8BA6426E.IsForeverHealingSupported() == true
end
local function isInCombatOrUnknown()
    if type(InCombatLockdown) ~= "function" then
        return true
    end
    local ok, result = pcall(function()
        return InCombatLockdown() == false
    end)
    return not ok or result ~= true
end
local function hasKeyboardFocusOrUnknown()
    if type(GetCurrentKeyBoardFocus) ~= "function" then
        return true
    end
    local ok, result = pcall(function()
        return GetCurrentKeyBoardFocus() == nil
    end)
    return not ok or result ~= true
end
local function normalizeKey(key)
    return P8BA6426E.NormalizeActionKey and P8BA6426E.NormalizeActionKey(key) or key
end
local function isControlKey(key)
    local db = P8BA6426E.DB
    if type(db) ~= "table" then
        return true
    end
    local normalized = normalizeKey(key)
    return normalized == normalizeKey(db.masterKey)
        or normalized == normalizeKey(db.burstKey)
        or normalized == normalizeKey(db.aoeKey)
end
local function pickTwoFreeKeys()
    local used = {}
    for _, bindKey in pairs(P8BA6426E.ACTION_TO_KEY or {}) do
        used[normalizeKey(bindKey)] = true
    end
    if type(P8BA6426E.GetRaidFocusKeys) == "function" then
        for _, raidFocusKey in ipairs(P8BA6426E.GetRaidFocusKeys()) do
            used[normalizeKey(raidFocusKey)] = true
        end
    end
    local picked = {}
    for index, key in ipairs(CANDIDATE_KEYS) do
        local normalized = normalizeKey(key)
        if not used[normalized] and not isControlKey(key) then
            picked[#picked + 1] = { key = key, index = index }
            if #picked == 2 then
                break
            end
        end
    end
    return picked[1], picked[2]
end
function P8BA6426E.InvalidateForeverHealingModeBindings()
    state.onKey, state.offKey = nil, nil
    state.onIndex, state.offIndex = 0, 0
    state.ready = false
end
function P8BA6426E.SetForeverHealingBindingsReady(ready)
    state.ready = isSupported() and (ready == true and (state.onIndex ~= 0 and state.offIndex ~= 0))
    if state.ready then
        state.nextRetryAt = nil
    end
end
function P8BA6426E.GetForeverHealingBindingsReady()
    return isSupported() and state.ready == true
end
function P8BA6426E.GetForeverHealingModeKeys()
    return state.onKey, state.offKey
end
function P8BA6426E.ApplyForeverHealingModeBindings()
    if not isSupported() then
        return true
    end
    if isInCombatOrUnknown() or type(P8BA6426E.CreateSecureButton) ~= "function" then
        return false
    end
    local onPick, offPick = pickTwoFreeKeys()
    if not onPick or not offPick then
        return false
    end
    local ok, result = pcall(
        P8BA6426E.CreateSecureButton,
        "forever_healing_mode_on",
        onPick.key,
        "/run P8BA6426E.RequestForeverHealingMode(true)"
    )
    local ok2, result2 = pcall(
        P8BA6426E.CreateSecureButton,
        "forever_healing_mode_off",
        offPick.key,
        "/run P8BA6426E.RequestForeverHealingMode(false)"
    )
    if not ok or result ~= true or not ok2 or result2 ~= true then
        return false
    end
    state.onKey, state.offKey = onPick.key, offPick.key
    state.onIndex, state.offIndex = onPick.index, offPick.index
    return true
end
local function queueRebind()
    if
        state.refreshQueued
        or isInCombatOrUnknown()
        or type(C_Timer) ~= "table"
        or type(C_Timer.After) ~= "function"
    then
        return
    end
    state.refreshQueued = true
    C_Timer.After(0, function()
        state.refreshQueued = false
        if isSupported() and (not isInCombatOrUnknown() and P8BA6426E.RefreshMacroBindings) then
            P8BA6426E.RefreshMacroBindings()
        end
    end)
end
function P8BA6426E.RequestForeverHealingMode(enable)
    if not isSupported() or isInCombatOrUnknown() or hasKeyboardFocusOrUnknown() or not state.ready then
        return false
    end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
        return false
    end
    state.pending = enable == true
    if state.requestQueued then
        return true
    end
    state.requestQueued = true
    C_Timer.After(0, function()
        state.requestQueued = false
        local pending = state.pending
        state.pending = nil
        if not isSupported() or isInCombatOrUnknown() or hasKeyboardFocusOrUnknown() or not state.ready then
            return
        end
        if P8BA6426E.SetForeverHealingMode(pending) then
            state.ack = (state.ack + 1) % 16
        else
            state.ready = false
        end
    end)
    return true
end
-- 治疗模式数据包：开/关按键序号、是否治疗专精、战斗中、输入框聚焦、就绪、回执、序号
function P8BA6426E.GetForeverHealingModePacket()
    if not isSupported() then
        return 0
    end
    if state.ready and (isControlKey(state.onKey) or isControlKey(state.offKey)) then
        state.ready = false
        queueRebind()
    end
    if not state.ready and not isInCombatOrUnknown() then
        local now = type(GetTime) == "function" and GetTime() or 0
        if state.nextRetryAt == nil or now >= state.nextRetryAt then
            state.nextRetryAt = now + 2
            queueRebind()
        end
    end
    state.sequence = state.sequence % 15 + 1
    local ready = state.ready and 1 or 0
    local onIndex = ready == 1 and state.onIndex or 0
    local offIndex = ready == 1 and state.offIndex or 0
    local healingFlag = P8BA6426E.IsHealingSpec() and 1 or 0
    return (
        (
            (
                (
                    (((PACKET_BASE + onIndex * 65536) + offIndex * 4096) + healingFlag * 2048)
                    + (isInCombatOrUnknown() and 1 or 0) * 1024
                ) + (hasKeyboardFocusOrUnknown() and 1 or 0) * 512
            ) + ready * 256
        ) + state.ack * 16
    ) + state.sequence
end
