--[[
  RaidFocus —— 治疗：团队/小队治疗焦点数据包（成员血量颜色、坦克标记、距离/不可协助、灵魂救赎检测）、焦点按键绑定与回执
  原始文件：32b0ff.lua（TOC 第 10 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local RAID_SLOTS = 30
local MAX_RAID_SIZE = 40
local PACKET_INTERVAL = 0.02
local RANGE_INTERVAL = 0.2
local SPIRIT_INTERVAL = 0.2
local MAX_AURA_SCAN = 40
local SPIRIT_AURA_IDS = { [27827] = true, [20758] = true }
local CODE_OUT_OF_RANGE = 102
local ACK_FOCUS_IS_PLAYER = "focus_is_player"
local ACK_PARTY_TANK_INDEX = "party_tank_index"
P8BA6426E.RAID_FOCUS_KEYS = {}
for i = 1, RAID_SLOTS, 1 do
    table.insert(P8BA6426E.RAID_FOCUS_KEYS, P8BA6426E.ACTION_KEY_ORDER[i])
end
-- 团队治疗数据包（每 0.02 秒刷新）：帧序号、成员数、血量颜色、坦克标记、不可达代码、反馈序号等
local packet = {
    lastUpdate = 0,
    frameSequence = 0,
    rosterEpoch = 0,
    rosterDirty = true,
    roleRefreshRequested = true,
    rolesNeedPostCombatRefresh = false,
    lastObservedRaidCount = nil,
    raidCount = 0,
    focusUnreachable = false,
    feedbackKind = 0,
    feedbackSequence = 0,
    lastRangeUpdate = 0,
    lastSpiritUpdate = 0,
    lastClassData = nil,
    ackPixel = ACK_FOCUS_IS_PLAYER,
    healthColors = {},
    roleBySlot = {},
    tankBySlot = {},
    unavailableCodeBySlot = {},
    spiritBySlot = {},
    partyUnavailableByIndex = {},
    spiritByPartyIndex = {},
}
local healthCurves = nil
local unavailableColors = nil
local function resetRangeState()
    for i = 1, RAID_SLOTS, 1 do
        packet.unavailableCodeBySlot[i] = nil
    end
    for i = 1, 4, 1 do
        packet.partyUnavailableByIndex[i] = nil
    end
    packet.lastRangeUpdate = 0
end
local function resetFeedback()
    packet.feedbackKind = 0
    packet.feedbackSequence = 0
end
local function isRaidFocusEnabled()
    return P8BA6426E.classData and P8BA6426E.classData.raidFocusEnabled == true
end
local function getAckPixelMode()
    if P8BA6426E.classData and P8BA6426E.classData.raidFocusAckPixel == ACK_PARTY_TANK_INDEX then
        return ACK_PARTY_TANK_INDEX
    end
    return ACK_FOCUS_IS_PLAYER
end
local function getFrameSequenceModulus(ackMode)
    return ackMode == ACK_PARTY_TANK_INDEX and 31 or 127
end
local function syncClassData()
    local classData = P8BA6426E.classData
    local ackMode = getAckPixelMode()
    if packet.lastClassData ~= classData or packet.ackPixel ~= ackMode then
        packet.lastClassData = classData
        packet.ackPixel = ackMode
        packet.frameSequence = 0
        packet.lastUpdate = 0
        resetRangeState()
        resetFeedback()
        if P8BA6426E.ClearFocusHealFailurePair then
            P8BA6426E.ClearFocusHealFailurePair()
        end
    end
    return ackMode
end
local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end
local function isSecret(v)
    if type(issecretvalue) ~= "function" then
        return false
    end
    local ok, result = pcall(issecretvalue, v)
    return not ok or result == true
end
local function readBoolean(fn, unit)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, unit)
    if not ok or isSecret(result) then
        return nil
    end
    local ok, isTrue = pcall(function()
        return result == true
    end)
    if not ok or isSecret(isTrue) then
        return nil
    end
    if isTrue == true then
        return true
    end
    local ok, isFalse = pcall(function()
        return result == false
    end)
    if not ok or isSecret(isFalse) then
        return nil
    end
    if isFalse == true then
        return false
    end
    return nil
end
local function bumpRosterEpoch()
    packet.rosterEpoch = (packet.rosterEpoch + 1) % 256
end
local function clearHealthState()
    for i = 1, RAID_SLOTS, 1 do
        packet.healthColors[i] = nil
        packet.tankBySlot[i] = false
    end
end
local function clearRoleState()
    clearHealthState()
    for i = 1, RAID_SLOTS, 1 do
        packet.roleBySlot[i] = nil
    end
end
local function resetRoster()
    clearRoleState()
    resetRangeState()
    resetFeedback()
    for i = 1, RAID_SLOTS, 1 do
        packet.spiritBySlot[i] = nil
    end
    for i = 1, 4, 1 do
        packet.spiritByPartyIndex[i] = nil
    end
    packet.lastSpiritUpdate = 0
    if P8BA6426E.ClearFocusHealFailurePair then
        P8BA6426E.ClearFocusHealFailurePair()
    end
    packet.rosterDirty = true
    packet.roleRefreshRequested = true
    packet.rolesNeedPostCombatRefresh = false
    packet.lastUpdate = 0
    bumpRosterEpoch()
end
local function ensureHealthCurves()
    if healthCurves then
        return true
    end
    if not (C_CurveUtil and (C_CurveUtil.CreateColorCurve and UnitHealthPercent)) then
        return false
    end
    local curves = {}
    local colors = {}
    for i = 1, 3, 1 do
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        for j = 0, 100, 1 do
            local channel = (j + 1) / 255
            if i == 1 then
                curve:AddPoint(j / 100, CreateColor(channel, 0, 0, 1))
            elseif i == 2 then
                curve:AddPoint(j / 100, CreateColor(0, channel, 0, 1))
            else
                curve:AddPoint(j / 100, CreateColor(0, 0, channel, 1))
            end
        end
        curves[i] = curve
        colors[CODE_OUT_OF_RANGE] = colors[CODE_OUT_OF_RANGE] or {}
        colors[103] = colors[103] or {}
        local outOfRangeChannel = CODE_OUT_OF_RANGE / 255
        local CANNOT_ASSIST_CHANNEL = 0.40392156862745
        if i == 1 then
            colors[CODE_OUT_OF_RANGE][i] = CreateColor(outOfRangeChannel, 0, 0, 1)
            colors[103][i] = CreateColor(CANNOT_ASSIST_CHANNEL, 0, 0, 1)
        elseif i == 2 then
            colors[CODE_OUT_OF_RANGE][i] = CreateColor(0, outOfRangeChannel, 0, 1)
            colors[103][i] = CreateColor(0, CANNOT_ASSIST_CHANNEL, 0, 1)
        else
            colors[CODE_OUT_OF_RANGE][i] = CreateColor(0, 0, outOfRangeChannel, 1)
            colors[103][i] = CreateColor(0, 0, CANNOT_ASSIST_CHANNEL, 1)
        end
    end
    healthCurves = curves
    unavailableColors = colors
    return true
end
local function getRaidCount()
    if not (IsInRaid and IsInRaid()) then
        return 0
    end
    local groupSize = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if groupSize < 0 then
        groupSize = 0
    end
    if groupSize > MAX_RAID_SIZE then
        groupSize = MAX_RAID_SIZE
    end
    return groupSize
end
local function isFeedbackEnabled()
    return isRaidFocusEnabled()
end
function P8BA6426E.IsRaidFocusFeedbackEnabled()
    return isFeedbackEnabled()
end
local FEEDBACK_KIND = { range = 1, los = 2, success = 3 }
function P8BA6426E.RecordRaidFocusFeedback(kind)
    local kindCode = FEEDBACK_KIND[kind]
    local enabled = isFeedbackEnabled()
    if not kindCode or not enabled then
        if not enabled then
            resetFeedback()
        end
        return false
    end
    packet.feedbackKind = kindCode
    packet.feedbackSequence = (packet.feedbackSequence + 1) % 32
    return true
end
local function isTankRole(unit)
    if type(UnitGroupRolesAssigned) ~= "function" then
        return nil
    end
    local ok, result = pcall(UnitGroupRolesAssigned, unit)
    if not ok or isSecret(result) then
        return nil
    end
    local ok, isTank = pcall(function()
        if result == "TANK" then
            return true
        end
        if result == "HEALER" or result == "DAMAGER" then
            return false
        end
        return nil
    end)
    if not ok or isSecret(isTank) then
        return nil
    end
    if isTank == true then
        return true
    end
    if isTank == false then
        return false
    end
    return nil
end
local function refreshRoles(raidCount)
    if not packet.roleRefreshRequested then
        return
    end
    local needRetry = false
    local slots = math.min(raidCount, RAID_SLOTS)
    for i = 1, RAID_SLOTS, 1 do
        if i <= slots then
            if packet.roleBySlot[i] == nil then
                local unit = "raid" .. i
                if readBoolean(UnitExists, unit) == true then
                    local isTank = isTankRole(unit)
                    if isTank == nil then
                        needRetry = true
                    end
                    packet.roleBySlot[i] = isTank
                else
                    needRetry = true
                    packet.roleBySlot[i] = nil
                end
            end
        else
            packet.roleBySlot[i] = nil
        end
    end
    packet.rosterDirty = false
    packet.roleRefreshRequested = false
    packet.rolesNeedPostCombatRefresh = needRetry
end
local function getRangeSpellIDs()
    local spellIDs = P8BA6426E.classData and P8BA6426E.classData.raidFocusRangeSpellIDs
    if type(spellIDs) ~= "table" or #spellIDs < 1 then
        return nil
    end
    return spellIDs
end
local function isSpellInRange(spellID, unit)
    if not (C_Spell and type(C_Spell.IsSpellInRange) == "function") then
        return nil
    end
    local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
    if not ok or isSecret(result) then
        return nil
    end
    local ok, isTrue = pcall(function()
        return result == true
    end)
    if not ok or isSecret(isTrue) then
        return nil
    end
    if isTrue == true then
        return true
    end
    local ok, isFalse = pcall(function()
        return result == false
    end)
    if not ok or isSecret(isFalse) then
        return nil
    end
    if isFalse == true then
        return false
    end
    return nil
end
local function isAnySpellInRange(spellIDs, unit)
    local anyFalse = false
    local anyUnknown = false
    for _, spellID in ipairs(spellIDs) do
        if type(spellID) == "number" and spellID > 0 then
            local inRange = isSpellInRange(spellID, unit)
            if inRange == true then
                return true
            end
            if inRange == false then
                anyFalse = true
            else
                anyUnknown = true
            end
        end
    end
    if anyFalse and not anyUnknown then
        return false
    end
    return nil
end
local function isUnitAlive(unit)
    return readBoolean(UnitExists, unit) == true
        and (readBoolean(UnitIsConnected, unit) == true and readBoolean(UnitIsDeadOrGhost, unit) == false)
end
local function hasSpiritAura(unit)
    if not (C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function") then
        return false
    end
    for i = 1, MAX_AURA_SCAN, 1 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or type(aura) ~= "table" then
            return false
        end
        local ok, isSpirit = pcall(function()
            return SPIRIT_AURA_IDS[aura.spellId] == true
        end)
        if ok and isSpirit then
            return true
        end
    end
    return false
end
local function refreshSpirits(raidCount, now)
    if packet.lastSpiritUpdate > 0 and now - packet.lastSpiritUpdate < SPIRIT_INTERVAL then
        return
    end
    packet.lastSpiritUpdate = now
    local slots = math.min(raidCount, RAID_SLOTS)
    for i = 1, RAID_SLOTS, 1 do
        if i <= slots then
            packet.spiritBySlot[i] = hasSpiritAura("raid" .. i)
        else
            packet.spiritBySlot[i] = nil
        end
    end
    for i = 1, 4, 1 do
        packet.spiritByPartyIndex[i] = hasSpiritAura("party" .. i)
    end
end
local function canAssist(unit)
    if type(UnitCanAssist) ~= "function" then
        return nil
    end
    local ok, result = pcall(UnitCanAssist, "player", unit)
    if not ok or isSecret(result) then
        return nil
    end
    local ok, isTrue = pcall(function()
        return result == true
    end)
    if not ok or isSecret(isTrue) then
        return nil
    end
    if isTrue == true then
        return true
    end
    local ok, isFalse = pcall(function()
        return result == false
    end)
    if not ok or isSecret(isFalse) then
        return nil
    end
    if isFalse == true then
        return false
    end
    return nil
end
local function getPlayerRaidIndex()
    if type(UnitInRaid) ~= "function" then
        return nil
    end
    local ok, result = pcall(UnitInRaid, "player")
    if not ok or isSecret(result) then
        return nil
    end
    local ok, valid = pcall(function()
        return type(result) == "number" and (result % 1 == 0 and (result >= 1 and result <= MAX_RAID_SIZE))
    end)
    if not ok or isSecret(valid) or valid ~= true then
        return nil
    end
    return result
end
local function refreshRange(raidCount, now)
    if packet.lastRangeUpdate > 0 and now - packet.lastRangeUpdate < RANGE_INTERVAL then
        return
    end
    resetRangeState()
    packet.lastRangeUpdate = now
    local rangeSpellIDs = getRangeSpellIDs()
    if not rangeSpellIDs then
        return
    end
    if raidCount > 0 then
        local selfIndex = getPlayerRaidIndex()
        local slots = math.min(raidCount, RAID_SLOTS)
        if selfIndex then
            for i = 1, slots, 1 do
                if i ~= selfIndex then
                    local unit = "raid" .. i
                    if isUnitAlive(unit) then
                        if canAssist(unit) == false then
                            packet.unavailableCodeBySlot[i] = 103
                        elseif isAnySpellInRange(rangeSpellIDs, unit) == false then
                            packet.unavailableCodeBySlot[i] = CODE_OUT_OF_RANGE
                        end
                    end
                end
            end
        end
    end
    for i = 1, 4, 1 do
        local unit = "party" .. i
        local exists = readBoolean(UnitExists, unit)
        local connected = readBoolean(UnitIsConnected, unit)
        local dead = readBoolean(UnitIsDeadOrGhost, unit)
        local isSpirit = packet.spiritByPartyIndex[i] == true
        local unavailable = exists == false or connected == false or dead == true or isSpirit
        if exists == true and (connected == true and (dead == false and not isSpirit)) then
            if canAssist(unit) == false or isAnySpellInRange(rangeSpellIDs, unit) == false then
                unavailable = true
            end
        end
        if unavailable then
            packet.partyUnavailableByIndex[i] = true
        end
    end
end
local function refreshRaidHealth(raidCount)
    clearHealthState()
    if raidCount < 1 or not ensureHealthCurves() then
        return
    end
    local slots = math.min(raidCount, RAID_SLOTS)
    for i = 1, slots, 1 do
        local unit = "raid" .. i
        local exists = readBoolean(UnitExists, unit)
        local connected = readBoolean(UnitIsConnected, unit)
        local dead = readBoolean(UnitIsDeadOrGhost, unit)
        local isSpirit = packet.spiritBySlot[i] == true
        if exists == true and (connected == true and (dead == false and not isSpirit)) then
            local channel = ((i - 1) % 3) + 1
            local color = nil
            local unavailableCode = packet.unavailableCodeBySlot[i]
            if unavailableCode then
                local codeColors = unavailableColors and unavailableColors[unavailableCode]
                color = codeColors and codeColors[channel]
            else
                local ok, result = pcall(UnitHealthPercent, unit, true, healthCurves[channel])
                if ok then
                    color = result
                end
            end
            if color then
                packet.healthColors[i] = color
                packet.tankBySlot[i] = packet.roleBySlot[i] ~= false
            end
        else
            packet.unavailableCodeBySlot[i] = nil
        end
    end
end
local function refreshPacket()
    local now = GetTime and GetTime() or 0
    local raidCount = getRaidCount()
    if packet.lastObservedRaidCount ~= raidCount then
        packet.lastObservedRaidCount = raidCount
        if not packet.rosterDirty then
            resetRoster()
        end
    end
    if packet.lastUpdate > 0 and now - packet.lastUpdate < PACKET_INTERVAL then
        return packet
    end
    packet.lastUpdate = now
    packet.raidCount = raidCount
    refreshRoles(raidCount)
    refreshSpirits(raidCount, now)
    refreshRange(raidCount, now)
    refreshRaidHealth(raidCount)
    packet.focusUnreachable = P8BA6426E.GetFocusCastUnreachable and P8BA6426E.GetFocusCastUnreachable() == true or false
    local modulus = getFrameSequenceModulus(packet.ackPixel)
    packet.frameSequence = (packet.frameSequence % modulus) + 1
    return packet
end
function P8BA6426E.GetRaidFocusPacket()
    local ackMode = syncClassData()
    if not isRaidFocusEnabled() then
        resetRangeState()
        resetFeedback()
        return nil
    end
    local result = refreshPacket()
    result.ackPixel = ackMode
    return result
end
local function hideLayer(layer)
    if layer and type(layer.SetAlpha) == "function" then
        pcall(layer.SetAlpha, layer, 0)
    end
end
local function setLayerVisible(layer, visible)
    if layer and type(layer.SetAlphaFromBoolean) == "function" then
        pcall(layer.SetAlphaFromBoolean, layer, visible, 255, 0)
    end
end
local function renderFocusMatch(unit, layer, extraLayer)
    hideLayer(layer)
    hideLayer(extraLayer)
    if type(UnitIsUnit) ~= "function" then
        return
    end
    local ok, isFocus = pcall(UnitIsUnit, "focus", unit)
    if not ok then
        return
    end
    setLayerVisible(layer, isFocus)
    setLayerVisible(extraLayer, isFocus)
end
function P8BA6426E.RenderRaidFocusAcknowledgement(layers, raidPacket)
    if not isRaidFocusEnabled() or type(layers) ~= "table" then
        return
    end
    local raidCount = raidPacket and raidPacket.raidCount or 0
    local count = math.min(tonumber(raidCount) or 0, RAID_SLOTS)
    local raid = layers.raid or {}
    for i = 1, RAID_SLOTS, 1 do
        if i <= count then
            renderFocusMatch("raid" .. i, raid[i])
        else
            hideLayer(raid[i])
        end
    end
    local party = layers.party or {}
    local ackMode = raidPacket and raidPacket.ackPixel or getAckPixelMode()
    local selfLayer = ackMode == ACK_FOCUS_IS_PLAYER and layers.self or nil
    renderFocusMatch("player", party[1], selfLayer)
    for i = 1, 4, 1 do
        renderFocusMatch("party" .. i, party[i + 1])
    end
end
-- 为 raid1..raid30 分配 30 个“设焦点”按键（治疗模式下使用 SHIFT/CTRL-SHIFT 组合）
function P8BA6426E.GetRaidFocusKeys()
    if type(P8BA6426E.ACTION_KEY_ORDER) ~= "table" or type(P8BA6426E.NormalizeActionKey) ~= "function" then
        return {}
    end
    local usedKeys = {}
    if type(P8BA6426E.ACTION_TO_KEY) == "table" then
        for _, bindKey in pairs(P8BA6426E.ACTION_TO_KEY) do
            local normalized = P8BA6426E.NormalizeActionKey(bindKey)
            if normalized then
                usedKeys[normalized] = true
            end
        end
    end
    local keys = {}
    local function tryAdd(key)
        local normalized = P8BA6426E.NormalizeActionKey(key)
        if normalized and (#keys < RAID_SLOTS and not usedKeys[normalized]) then
            keys[#keys + 1] = key
        end
    end
    if P8BA6426E.classData and (P8BA6426E.classData.healingModeSwitchEnabled == true and isRaidFocusEnabled()) then
        for _, modifier in ipairs({ "SHIFT", "CTRL-SHIFT" }) do
            for i = 1, 27, 1 do
                tryAdd(modifier .. ("-" .. P8BA6426E.ACTION_KEY_ORDER[i]))
            end
        end
    else
        for _, key in ipairs(P8BA6426E.ACTION_KEY_ORDER) do
            tryAdd(key)
        end
    end
    if #keys ~= RAID_SLOTS then
        return {}
    end
    return keys
end
-- 创建 30 个焦点按钮并绑定按键：外部程序按下对应键即可把焦点切到某个团队成员
function P8BA6426E.ApplyRaidFocusBindings()
    if not isRaidFocusEnabled() then
        return true
    end
    if inCombat() or not P8BA6426E.CreateSecureFocusButton then
        return false
    end
    if
        P8BA6426E.classData
        and (
            P8BA6426E.classData.healingModeSwitchEnabled == true
            and not (P8BA6426E.IsHealingSpec and P8BA6426E.IsHealingSpec())
        )
    then
        return true
    end
    local keys = P8BA6426E.GetRaidFocusKeys()
    if #keys ~= RAID_SLOTS then
        return false
    end
    local allOk = true
    for i, key in ipairs(keys) do
        local ok, result = pcall(P8BA6426E.CreateSecureFocusButton, "raid_focus_" .. i, key, "raid" .. i)
        if not ok or result ~= true then
            allOk = false
        end
    end
    return allOk
end
local rosterFrame = CreateFrame("Frame")
rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rosterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
rosterFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if packet.rolesNeedPostCombatRefresh then
            packet.roleRefreshRequested = true
            packet.lastUpdate = 0
        end
        return
    end
    resetRoster()
end)
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("healing.raid_packet_refresh", "sampled", function()
        return refreshPacket
    end, function(fn)
        refreshPacket = fn
    end)
    logicDiagnostics.Declare("healing.raid_health", "sampled", function()
        return refreshRaidHealth
    end, function(fn)
        refreshRaidHealth = fn
    end)
    logicDiagnostics.Declare("healing.raid_range", "sampled", function()
        return refreshRange
    end, function(fn)
        refreshRange = fn
    end)
    logicDiagnostics.Declare("healing.raid_packet", "sampled", function()
        return P8BA6426E.GetRaidFocusPacket
    end, function(getRaidFocusPacket)
        P8BA6426E.GetRaidFocusPacket = getRaidFocusPacket
    end)
    logicDiagnostics.Declare("healing.raid_ack", "sampled", function()
        return P8BA6426E.RenderRaidFocusAcknowledgement
    end, function(renderRaidFocusAcknowledgement)
        P8BA6426E.RenderRaidFocusAcknowledgement = renderRaidFocusAcknowledgement
    end)
end
