--[[
  HealingNpcMouseover —— 治疗：鼠标指向可治疗 NPC 的检测与数据包编码、焦点匹配层渲染
  原始文件：30bc61.lua（TOC 第 7 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local PACKET_BASE = 10485760
local ELIGIBLE_FLAG = 524288
local MAX_SEQUENCE = 1023
local EPOCH_MODULUS = 256
local EPOCH_MULTIPLIER = 1024
local state = { enabled = false, eligible = false, epoch = 0, sequence = 0, packet = 0 }
local function isSecret(v)
    if type(issecretvalue) ~= "function" then
        return false
    end
    local ok, result = pcall(issecretvalue, v)
    return not ok or result == true
end
local function readBoolean(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok or isSecret(result) then
        return nil
    end
    if result == true then
        return true
    end
    if result == false then
        return false
    end
    return nil
end
local function contractHasNpcField()
    local contract = P8BA6426E.FontPixelRoute and P8BA6426E.FontPixelRoute.GetScalarContract()
    if not contract then
        return false
    end
    for _, scalarRecord in ipairs(contract.scalarRecords or {}) do
        if type(scalarRecord) == "table" and scalarRecord.id == "mouseover_npc_state" then
            return true
        end
    end
    return false
end
local function isHealableNpcMouseover()
    local unit = "mouseover"
    return readBoolean(UnitExists, unit) == true
        and (
            readBoolean(UnitIsDeadOrGhost, unit) == false
            and (
                readBoolean(UnitCanAssist, "player", unit) == true
                and (
                    readBoolean(UnitIsPlayer, unit) == false
                    and (readBoolean(UnitIsMinion, unit) == false and readBoolean(UnitPlayerControlled, unit) == false)
                )
            )
        )
end
function P8BA6426E.HasHealingNpcMouseover()
    return state.enabled == true and state.eligible == true
end
-- 鼠标指向可治疗 NPC 的状态数据包（epoch*1024 + 序号，符合条件时加标志位）
function P8BA6426E.UpdateHealingNpcMouseover()
    local wasEligible = state.eligible == true
    state.enabled = contractHasNpcField()
    local eligible = false
    if state.enabled then
        eligible = isHealableNpcMouseover()
    end
    if wasEligible and not eligible then
        state.epoch = (state.epoch + 1) % EPOCH_MODULUS
    end
    state.eligible = eligible
    if not state.enabled then
        state.packet = 0
        return 0
    end
    state.sequence = (state.sequence % MAX_SEQUENCE) + 1
    local packet = (PACKET_BASE + state.epoch * EPOCH_MULTIPLIER) + state.sequence
    if state.eligible then
        packet = packet + ELIGIBLE_FLAG
    end
    state.packet = packet
    return packet
end
local function hideLayer(layer)
    if layer and type(layer.SetAlpha) == "function" then
        pcall(layer.SetAlpha, layer, 0)
    end
end
function P8BA6426E.RenderHealingNpcFocusMatch(layer)
    hideLayer(layer)
    if
        not P8BA6426E.HasHealingNpcMouseover()
        or type(UnitIsUnit) ~= "function"
        or not layer
        or type(layer.SetAlphaFromBoolean) ~= "function"
    then
        return
    end
    local ok, isSame = pcall(UnitIsUnit, "focus", "mouseover")
    if not ok then
        return
    end
    pcall(layer.SetAlphaFromBoolean, layer, isSame, 255, 0)
end
local mouseoverFrame = CreateFrame("Frame")
mouseoverFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
mouseoverFrame:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        state.epoch = (state.epoch + 1) % EPOCH_MODULUS
    end
end)
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("healing.npc_update", "sampled", function()
        return P8BA6426E.UpdateHealingNpcMouseover
    end, function(updateHealingNpcMouseover)
        P8BA6426E.UpdateHealingNpcMouseover = updateHealingNpcMouseover
    end)
    logicDiagnostics.Declare("healing.npc_focus", "sampled", function()
        return P8BA6426E.RenderHealingNpcFocusMatch
    end, function(renderHealingNpcFocusMatch)
        P8BA6426E.RenderHealingNpcFocusMatch = renderHealingNpcFocusMatch
    end)
end
