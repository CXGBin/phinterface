--[[
  PixelBarsMain —— 像素主循环：每 20ms 采集游戏状态（开关、敌人数、施法、血量、冷却、饰品…）并逐字段编码为颜色；状态 Logo、小地图按钮、CVar 校准、UI 缩放保护
  原始文件：2f2403.lua（TOC 第 32 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local addonName = ...
local pixelLayers = nil
local activeScalarRecords = {}
local activeScalarIDs = {}
local frameValues = {}
local function recordSecretApiFault(source, err)
    local faultRecorder = P8BA6426E.RecordSecretApiFault
    if type(faultRecorder) == "function" then
        pcall(faultRecorder, source, err)
    end
end
-- 重建像素条：取当前专精的标量合同，创建标量图层，记录需要输出的字段
function P8BA6426E.RebuildPixelBars()
    wipe(activeScalarRecords)
    wipe(activeScalarIDs)
    if pixelLayers then
        pixelLayers:Hide()
    end
    pixelLayers = nil
    P8BA6426E.teamAvgLayers = nil
    P8BA6426E.teamAvgIndex = nil
    P8BA6426E.healerMasterHealthLayers = nil
    P8BA6426E.healingNpcFocusMatchLayer = nil
    P8BA6426E.raidFocusHealthLayers = nil
    P8BA6426E.raidFocusAckLayers = nil
    P8BA6426E.raidFocusPartyUnavailableLayers = nil
    P8BA6426E.raidFocusAckFrameSequence = nil
    P8BA6426E.raidFocusAckCarrier = nil
    local fontPixelRoute = P8BA6426E.FontPixelRoute
    local scalarContract = fontPixelRoute and (fontPixelRoute.GetScalarContract and fontPixelRoute.GetScalarContract())
    local pixelContainer = fontPixelRoute and (fontPixelRoute.GetSurfaceFrame and fontPixelRoute.GetSurfaceFrame())
    if not scalarContract or not pixelContainer then
        P8BA6426E.pixelContainer = nil
        P8BA6426E._pixelBarPositions = nil
        return
    end
    local scalarRecords = assert(scalarContract.scalarRecords, "V3 标量字段声明缺失")
    assert(#scalarRecords == #(scalarContract.classicKeys or {}), "V3 标量字段数量与物理合同不一致")
    for _, record in ipairs(scalarRecords) do
        activeScalarIDs[record.id] = true
    end
    P8BA6426E.pixelContainer = pixelContainer
    local raidFocusEnabled = P8BA6426E.classData and P8BA6426E.classData.raidFocusEnabled == true
    local raidAckMode = raidFocusEnabled
            and (P8BA6426E.classData.raidFocusAckPixel == "party_tank_index" and "party_tank_index")
        or "focus_is_player"
    local layers = P8BA6426E.AcquirePixelScalarLayers(
        pixelContainer,
        scalarContract,
        (P8BA6426E.IsHealingSpec and P8BA6426E.IsHealingSpec())
            or (P8BA6426E.IsForeverHealingSupported and P8BA6426E.IsForeverHealingSupported()),
        raidFocusEnabled,
        raidAckMode
    )
    pixelLayers = layers
    P8BA6426E.teamAvgLayers = layers.teamAvg
    P8BA6426E.healerMasterHealthLayers = layers.healerMaster
    P8BA6426E.healingNpcFocusMatchLayer = layers.healingNpc
    P8BA6426E.raidFocusHealthLayers = layers.raidHealth
    P8BA6426E.raidFocusAckLayers = layers.raidAck
    P8BA6426E.raidFocusPartyUnavailableLayers = layers.raidPartyUnavailable
    for _, record in ipairs(scalarRecords) do
        table.insert(activeScalarRecords, record)
    end
end
local COLOR_RED = CreateColor(1, 0, 0)
local COLOR_GREEN = CreateColor(0, 1, 0)
local COLOR_WHITE = CreateColor(1, 1, 1)
local function getTargetTargetIsPlayerColor()
    local ok, isPlayer = pcall(UnitIsUnit, "targettarget", "player")
    if not ok then
        return COLOR_WHITE
    end
    local ok, color = pcall(C_CurveUtil.EvaluateColorFromBoolean, isPlayer, COLOR_GREEN, COLOR_RED)
    if ok then
        return color
    end
    return COLOR_WHITE
end
local function getRaidAndMythicPlusState()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid",
        inInstance and (instanceType == "party" and C_ChallengeMode.IsChallengeModeActive())
end
local COLOR_CAST = CreateColor(0, 1, 1)
local COLOR_CHANNEL = CreateColor(0.50196078431373, 1, 1)
local castProgressCurve = nil
local channelProgressCurve = nil
local function ensureProgressCurves()
    if castProgressCurve and channelProgressCurve then
        return true
    end
    if not (C_CurveUtil and (C_CurveUtil.CreateColorCurve and (Enum and Enum.LuaCurveType))) then
        return false
    end
    castProgressCurve = C_CurveUtil.CreateColorCurve()
    channelProgressCurve = C_CurveUtil.CreateColorCurve()
    castProgressCurve:SetType(Enum.LuaCurveType.Step)
    channelProgressCurve:SetType(Enum.LuaCurveType.Step)
    for i = 0, 100, 1 do
        castProgressCurve:AddPoint(i / 100, CreateColor(0, 1, i / 255, 1))
        channelProgressCurve:AddPoint(i / 100, CreateColor(0.50196078431373, 1, i / 255, 1))
    end
    return true
end
local function getCastProgressColor(unit, durationFn, isChannel)
    if not durationFn or not ensureProgressCurves() then
        return isChannel and COLOR_CHANNEL or COLOR_CAST
    end
    local ok, result = pcall(function()
        local durationObj = durationFn(unit)
        return durationObj:EvaluateElapsedPercent(isChannel and channelProgressCurve or castProgressCurve)
    end)
    if ok and result then
        return result
    end
    recordSecretApiFault("EvaluateElapsedPercent:" .. unit, result)
    return isChannel and COLOR_CHANNEL or COLOR_CAST
end
-- 把单位的施法/引导状态编码为颜色：红=未施法；否则用进度曲线编码已施法百分比，并以“不可打断”与否选择颜色
local function getUnitCastingColor(unit)
    if not UnitExists(unit) then
        return COLOR_RED
    end
    local _name, _text, _texture, _startMS, _endMS, _isTradeSkill, _castID, notInterruptible, _ignored, castBarID =
        UnitCastingInfo(unit)
    if castBarID then
        local progressColor = getCastProgressColor(unit, UnitCastingDuration)
        local ok, result = pcall(C_CurveUtil.EvaluateColorFromBoolean, notInterruptible, COLOR_RED, progressColor)
        if not (ok and result) then
            recordSecretApiFault("EvaluateColorFromBoolean:" .. unit, result)
            return COLOR_RED
        end
        return result
    end
    _ignored, _ignored, _ignored, _ignored, _ignored, _ignored, notInterruptible, _ignored, _ignored, _ignored, castBarID =
        UnitChannelInfo(unit)
    if castBarID then
        local progressColor = getCastProgressColor(unit, UnitChannelDuration, true)
        local ok, result = pcall(C_CurveUtil.EvaluateColorFromBoolean, notInterruptible, COLOR_RED, progressColor)
        if not (ok and result) then
            recordSecretApiFault("EvaluateColorFromBoolean:" .. unit, result)
            return COLOR_RED
        end
        return result
    end
    return COLOR_RED
end
local function getHostileUnitCastingColor(unit)
    if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) then
        return COLOR_RED
    end
    return getUnitCastingColor(unit)
end
P8BA6426E.GetHostileUnitCastingColor = getHostileUnitCastingColor
local mouseoverRevision = 1
local mouseoverFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(mouseoverFrame, "UPDATE_MOUSEOVER_UNIT")
mouseoverFrame:SetScript("OnEvent", function()
    mouseoverRevision = mouseoverRevision % 99 + 1
end)
local function getTargetCastingColor()
    return getUnitCastingColor("target")
end
local function getFocusCastingColor()
    return getUnitCastingColor("focus")
end
local function getUnitDistance(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local distanceSquared, checked = UnitDistanceSquared(unit)
    distanceSquared = P8BA6426E.SafeNumber(distanceSquared)
    if checked and distanceSquared > 0 then
        return math.sqrt(distanceSquared)
    end
    if P8BA6426E.LibRangeCheck then
        local minRange, maxRange = P8BA6426E.LibRangeCheck:GetRange(unit, true)
        minRange = P8BA6426E.SafeNumber(minRange)
        maxRange = P8BA6426E.SafeNumber(maxRange)
        if maxRange > 0 then
            return (minRange + maxRange) / 2
        elseif minRange > 0 then
            return minRange
        end
    end
    return nil
end
local function isInRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance == true and instanceType == "raid"
end
local isSpecialEncounterActive = false
local TEAM_AVG_INTERVAL = 0.2
local lastTeamAvgAt = nil
local rosterDirty = true
local lastMasterSwitch = nil
local encounterFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(encounterFrame, "ENCOUNTER_START")
P8BA6426E.SafeRegisterEvent(encounterFrame, "ENCOUNTER_END")
P8BA6426E.SafeRegisterEvent(encounterFrame, "PLAYER_ENTERING_WORLD")
local rosterDirtyFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(rosterDirtyFrame, "PLAYER_REGEN_DISABLED")
P8BA6426E.SafeRegisterEvent(rosterDirtyFrame, "PLAYER_ENTERING_WORLD")
P8BA6426E.SafeRegisterEvent(rosterDirtyFrame, "GROUP_ROSTER_UPDATE")
P8BA6426E.SafeRegisterEvent(rosterDirtyFrame, "PLAYER_SPECIALIZATION_CHANGED")
rosterDirtyFrame:SetScript("OnEvent", function()
    rosterDirty = true
end)
encounterFrame:SetScript("OnEvent", function(_, event, encounterID)
    isSpecialEncounterActive = false
    if not P8BA6426E.ClientCapabilities.retailEnemyCountCorrections then
        return
    end
    if event ~= "ENCOUNTER_START" then
        return
    end
    local ok, result = pcall(function()
        if type(issecretvalue) ~= "function" or issecretvalue(encounterID) then
            return false
        end
        return type(encounterID) == "number" and encounterID == 3200
    end)
    isSpecialEncounterActive = ok and result == true
end)
local function shouldCountOutOfCombatEnemies()
    if isInRaidInstance() then
        return true
    end
    if not isSpecialEncounterActive then
        return false
    end
    local inInstance, instanceType = IsInInstance()
    return inInstance == true and instanceType == "party"
end
-- 扫描所有敌对姓名板：统计 maxRange 码内敌人数、战斗中敌人数、GUID 等（用于 AOE 判断）
local function scanVisibleHostileEnemies(maxRange)
    local inRangeCount = 0
    local inRangeTruncated = false
    local combatEnemyCount = 0
    local inRangeUnits = {}
    local combatUnits = {}
    local unitGUIDs = {}
    local engagedUnits, seenUnitsAndGUIDs, reliable = {}, {}, true
    local function considerEngagedUnit(unit)
        local ok, result = pcall(function()
            if
                type(unit) ~= "string"
                or not UnitExists(unit)
                or not UnitCanAttack("player", unit)
                or UnitIsDeadOrGhost(unit)
            then
                return false
            end
            local inCombat = UnitAffectingCombat(unit)
            assert(type(inCombat) == "boolean", "敌人进战状态未知")
            return inCombat and true or false
        end)
        if not ok then
            reliable = false
            return
        end
        if not result or seenUnitsAndGUIDs[unit] then
            return
        end
        seenUnitsAndGUIDs[unit] = true
        local ok, guid = pcall(UnitGUID, unit)
        if ok and issecretvalue then
            local ok, isSecret = pcall(issecretvalue, guid)
            if not ok or isSecret then
                guid = nil
            end
        end
        if not ok or type(guid) ~= "string" then
            reliable = false
            return
        end
        if seenUnitsAndGUIDs[guid] then
            return
        end
        unitGUIDs[unit] = guid
        seenUnitsAndGUIDs[guid] = true
        if unit == "target" then
            for _, otherUnit in ipairs(engagedUnits) do
                local ok, sameUnit = pcall(function()
                    return UnitIsUnit(otherUnit, unit) and true or false
                end)
                if not ok then
                    reliable = false
                    return
                end
                if sameUnit then
                    return
                end
            end
        end
        engagedUnits[#engagedUnits + 1] = unit
    end
    local countAllHostiles = shouldCountOutOfCombatEnemies()
    local namePlates = C_NamePlate and (C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()) or {}
    for _, namePlate in ipairs(namePlates) do
        local unit = namePlate.namePlateUnitToken or namePlate.unitToken or namePlate.unit
        considerEngagedUnit(unit)
        local ok, isHostile, isEngaged = pcall(function()
            if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) then
                return false, false
            end
            return true, countAllHostiles or (UnitAffectingCombat(unit) and true or false)
        end)
        if ok and isHostile then
            local ok, guid = pcall(UnitGUID, unit)
            if ok and issecretvalue then
                local ok, isSecret = pcall(issecretvalue, guid)
                if not ok or isSecret then
                    guid = nil
                end
            end
            if type(guid) == "string" then
                unitGUIDs[unit] = guid
            end
            if isEngaged then
                combatEnemyCount = math.min(100, combatEnemyCount + 1)
                combatUnits[#combatUnits + 1] = unit
            end
            local ok, inRange = pcall(function()
                local distance = getUnitDistance(unit)
                if distance then
                    return distance <= maxRange
                end
                if P8BA6426E.LibRangeCheck then
                    local rcMinRange, rcMaxRange = P8BA6426E.LibRangeCheck:GetRange(unit, true)
                    rcMaxRange = P8BA6426E.SafeNumber(rcMaxRange)
                    return rcMaxRange > 0 and rcMaxRange <= maxRange
                end
                return false
            end)
            if ok and inRange then
                if inRangeCount < 40 then
                    inRangeCount = inRangeCount + 1
                    inRangeUnits[#inRangeUnits + 1] = unit
                else
                    inRangeTruncated = true
                end
            end
        end
    end
    table.sort(inRangeUnits)
    table.sort(combatUnits)
    considerEngagedUnit("target")
    table.sort(engagedUnits)
    return inRangeCount,
        combatEnemyCount,
        inRangeUnits,
        combatUnits,
        unitGUIDs,
        inRangeTruncated,
        engagedUnits,
        reliable
end
local FORCED_COUNT_NPC_IDS = { ["243208"] = true, ["225982"] = true }
local FORCED_ENEMY_COUNT = 5
-- 特定 NPC（如训练假人）强制把敌人数修正为 5
local function applyEnemyCountCorrection(count)
    if not P8BA6426E.ClientCapabilities.retailEnemyCountCorrections then
        return count
    end
    local ok, result = pcall(function()
        if type(UnitGUID) ~= "function" or type(strsplit) ~= "function" then
            return count
        end
        local guid = UnitGUID("target")
        if not guid then
            return count
        end
        local guidParts = { strsplit("-", guid) }
        if guidParts[1] == "Creature" and FORCED_COUNT_NPC_IDS[guidParts[6]] then
            return FORCED_ENEMY_COUNT
        end
        return count
    end)
    return ok and result or count
end
local function getNearbyEnemiesCount(maxRange)
    local count = scanVisibleHostileEnemies(maxRange)
    return count
end
P8BA6426E.GetNearbyEnemiesCount = getNearbyEnemiesCount
P8BA6426E.ScanVisibleHostileEnemies = scanVisibleHostileEnemies
function P8BA6426E.IsSpellKnown(spellID)
    local isPetSpell = P8BA6426E.IsPetSpell and P8BA6426E.IsPetSpell(spellID)
    if isPetSpell then
        if UnitExists("pet") then
            if UnitIsDeadOrGhost("pet") then
                return false
            end
            if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
                if not (Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet)) then
                    return false
                end
                return C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet, true)
            end
            return IsSpellKnown(spellID, true)
        end
        local wrapperSpellIDs = P8BA6426E.classData
            and (P8BA6426E.classData.petSpellPlayerWrappers and P8BA6426E.classData.petSpellPlayerWrappers[spellID])
        if not wrapperSpellIDs then
            return false
        end
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            local playerBank = Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "player"
            for _, spellID in ipairs(wrapperSpellIDs) do
                if C_SpellBook.IsSpellKnownOrInSpellBook(spellID, playerBank, true) then
                    return true
                end
            end
            return false
        end
        for _, spellID in ipairs(wrapperSpellIDs) do
            if IsSpellKnown(spellID) then
                return true
            end
        end
        return false
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        local playerBank = Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "player"
        return C_SpellBook.IsSpellKnownOrInSpellBook(spellID, playerBank, true)
    end
    return IsSpellKnown(spellID)
end
-- 技能是否可用：已学会 + IsSpellUsable + 无冷却（或被规则强制可用）
function P8BA6426E.IsSpellReadyRaw(spellID)
    if P8BA6426E.forceAvailableState[spellID] then
        return true
    end
    if not P8BA6426E.IsSpellKnown(spellID) then
        return false
    end
    local usable = true
    if P8BA6426E.IsSpellUsable then
        usable = P8BA6426E.IsSpellUsable(spellID)
    end
    if not usable then
        return false
    end
    local remaining = P8BA6426E.GetActionReadyCooldownRemaining(spellID)
    if remaining and remaining > 0 then
        return false
    end
    return true
end
function P8BA6426E.IsSpellReady(spellID)
    if P8BA6426E.classData and P8BA6426E.classData.OverrideIsSpellReady then
        local overrideIsSpellReady = P8BA6426E.classData.OverrideIsSpellReady(spellID)
        if overrideIsSpellReady ~= nil then
            return overrideIsSpellReady
        end
    end
    local aliases = P8BA6426E.classData and P8BA6426E.classData.spellReadyAliases
    if aliases and aliases[spellID] then
        if P8BA6426E.IsSpellReadyRaw(spellID) then
            return true
        end
        for _, aliasSpellID in ipairs(aliases[spellID]) do
            if P8BA6426E.IsSpellReadyRaw(aliasSpellID) then
                return true
            end
        end
        return false
    end
    return P8BA6426E.IsSpellReadyRaw(spellID)
end
local function setTextureRGB(texture, r, g, b)
    texture:SetColorTexture(r, g, b, 1)
end
-- 把 0..16777215 的整数拆成 R/G/B 三个 0..1 分量——像素协议的基本编码方式
local function intToRGB(value)
    local ok, packed = pcall(function()
        local clamped = math.floor(value + 0.5)
        if clamped > 16777215 then
            clamped = 16777215
        end
        if clamped < 0 then
            clamped = 0
        end
        return clamped
    end)
    if not ok or type(packed) ~= "number" then
        return 0, 0, 0
    end
    local r = math.floor(packed / 65536) / 255
    local g = math.floor((packed % 65536) / 256) / 255
    local b = (packed % 256) / 255
    return r, g, b
end
local DISTANCE_UNKNOWN = 16777215
local COUNT_UNKNOWN = 16777215
local function encodeDistance(distance)
    if not distance then
        return intToRGB(DISTANCE_UNKNOWN)
    end
    return intToRGB(distance * 10)
end
local function encodeCount(count)
    if count == nil then
        return intToRGB(COUNT_UNKNOWN)
    end
    return intToRGB(count)
end
local function ensureHealthColorCurve()
    if P8BA6426E.healthColorCurve then
        return true
    end
    if not (C_CurveUtil and (C_CurveUtil.CreateColorCurve and UnitHealthPercent)) then
        return false
    end
    P8BA6426E.healthColorCurve = C_CurveUtil.CreateColorCurve()
    P8BA6426E.healthColorCurve:SetType(Enum.LuaCurveType.Step)
    for i = 0, 100, 1 do
        P8BA6426E.healthColorCurve:AddPoint(i / 100, CreateColor(0, 0, i / 255, 1))
    end
    return true
end
local function getMouseoverHostileHealthColor()
    if not UnitExists("mouseover") or not UnitCanAttack("player", "mouseover") or UnitIsDeadOrGhost("mouseover") then
        return 16777215
    end
    if not ensureHealthColorCurve() then
        return 16777215
    end
    local ok, result = pcall(UnitHealthPercent, "mouseover", true, P8BA6426E.healthColorCurve)
    if not ok or not result or type(result.GetRGB) ~= "function" then
        return 16777215
    end
    return result
end
local deadOrAliveCurve = nil
local function getAliveCurve()
    if deadOrAliveCurve then
        return deadOrAliveCurve
    end
    if not (C_CurveUtil and (C_CurveUtil.CreateColorCurve and UnitHealthPercent)) then
        return nil
    end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(0, 0, 1, 1))
    curve:AddPoint(1, CreateColor(0, 0, 0, 1))
    deadOrAliveCurve = curve
    return curve
end
local function getUnitAliveBlue(unit, curve)
    if not UnitExists(unit) then
        return 1
    end
    if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
        return 0
    end
    local color = UnitHealthPercent(unit, true, curve)
    if not color or not color.GetRGB then
        return 1
    end
    local _r, _g, blue = color:GetRGB()
    return blue
end
local function getHealingNpcMouseoverAlive(curve)
    if type(P8BA6426E.HasHealingNpcMouseover) ~= "function" or not P8BA6426E.HasHealingNpcMouseover() then
        return 0
    end
    local ok, result = pcall(UnitHealthPercent, "mouseover", true, curve)
    if not ok or not result or not result.GetRGB then
        return 0
    end
    local _r, _g, blue = result:GetRGB()
    return blue
end
-- 治疗专精脱战且总开关关闭时，在 master_switch 像素上叠加队伍存活信息
local function renderHealerMasterHealth(masterSwitch)
    local layers = P8BA6426E.healerMasterHealthLayers
    if not layers then
        return false
    end
    for _, layer in ipairs(layers) do
        layer:SetAlpha(0)
    end
    if not masterSwitch or not P8BA6426E.IsHealingSpec() then
        return false
    end
    if UnitAffectingCombat("player") then
        return false
    end
    local curve = getAliveCurve()
    if not curve then
        return false
    end
    local inRaid = IsInRaid()
    local groupSize = math.max(GetNumGroupMembers(), 1)
    groupSize = math.min(groupSize, inRaid and 40 or 5)
    for i = 1, groupSize, 1 do
        local unit = inRaid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        local ok, alpha = pcall(getUnitAliveBlue, unit, curve)
        if ok then
            layers[i]:SetAlpha(alpha)
        else
            layers[i]:SetAlpha(1)
        end
    end
    local mouseoverLayer = layers[41]
    if mouseoverLayer then
        mouseoverLayer:SetAlpha(getHealingNpcMouseoverAlive(curve))
    end
    return true
end
local teamAvgCurve = nil
local teamAvgCurveSize = 0
local function getTeamAvgCurve(memberCount)
    if memberCount < 1 then
        return nil
    end
    if teamAvgCurve and teamAvgCurveSize == memberCount then
        return teamAvgCurve
    end
    if not (C_CurveUtil and (C_CurveUtil.CreateColorCurve and UnitHealthPercent)) then
        return nil
    end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    for i = 0, 100, 1 do
        curve:AddPoint(i / 100, CreateColor(0, 0, (i / memberCount) / 255, 1))
    end
    teamAvgCurve = curve
    teamAvgCurveSize = memberCount
    return curve
end
local UPDATE_INTERVAL = 0.02
local updateAccumulator = 0
local elapsedSinceLastUpdate = 0
local partyHealthColors, partyUnavailable, aliveMembers = {}, {}, {}
local function isHealerIdleOutOfCombat()
    if not P8BA6426E.IsHealingSpec or not P8BA6426E.IsHealingSpec() then
        return false
    end
    if type(UnitAffectingCombat) ~= "function" then
        return false
    end
    local ok, result = pcall(UnitAffectingCombat, "player")
    if not ok or result ~= false then
        return false
    end
    return P8BA6426E.DB ~= nil and P8BA6426E.DB.masterSwitch == false
end
-- 团队平均血量：每个存活成员一个 ADD 混合纹理，叠加后蓝色通道即平均血量
local function renderTeamAvgHealth()
    local members = aliveMembers
    wipe(members)
    if IsInRaid and IsInRaid() then
        local groupSize = math.min((GetNumGroupMembers and GetNumGroupMembers()) or 0, 40)
        for i = 1, groupSize, 1 do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
                members[#members + 1] = unit
            end
        end
    else
        if UnitExists("player") and not UnitIsDeadOrGhost("player") then
            members[#members + 1] = "player"
        end
        for i = 1, 4, 1 do
            local unit = "party" .. i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
                members[#members + 1] = unit
            end
        end
    end
    local curve = getTeamAvgCurve(#members)
    local teamAvgLayers = P8BA6426E.teamAvgLayers
    if teamAvgLayers then
        for i, unit in ipairs(members) do
            local texture = teamAvgLayers[i]
            if texture then
                local ok, color = false, nil
                if curve then
                    ok, color = pcall(UnitHealthPercent, unit, true, curve)
                    if not ok then
                        recordSecretApiFault("UnitHealthPercent:" .. (unit .. ":teamavg"), color)
                    end
                end
                if ok and (color and color.GetRGB) then
                    texture:SetColorTexture(color:GetRGB())
                else
                    texture:SetColorTexture(0, 0, (100 / #members) / 255, 1)
                end
            end
        end
        for i = #members + 1, #teamAvgLayers, 1 do
            teamAvgLayers[i]:SetColorTexture(0, 0, 0, 1)
        end
        if #members == 0 then
            teamAvgLayers[1]:SetColorTexture(0, 0, 0.3921568627451, 1)
        end
    end
end
local consumableRemainingCache = {}
local consumableRefreshAccumulator = 5
local masterAlert, burstAlert
local masterAlertHideAt, burstAlertHideAt, aoeAlertHideAt = 0, 0, 0
local enemies_8yd = 0
local active_enemies = 0
local nearby8 = {}
local active = {}
local guids = {}
local nearby8Overflow = false
local combat, combatKnown = {}, false
P8BA6426E.enemyCountSnapshot = nil
function P8BA6426E.GetEnemyCountSnapshot()
    return P8BA6426E.enemyCountSnapshot
end
local combatStartedAt = nil
local _AOE_MODE_TEXT_OLD = { [0] = "单/|cff00ff00自|r", [1] = "|cff00ff00单|r/自" }
local AOE_MODE_TEXT = { [0] = "自动", [1] = "单体", [2] = "群体" }
local function showAlert(label, text, duration)
    if not label then
        return
    end
    if P8BA6426E.DB and P8BA6426E.DB.disableTextAlert then
        return
    end
    label:SetText(P8BA6426E.L(text))
    label:Show()
    local seconds = duration or 1
    if label == masterAlert then
        masterAlertHideAt = GetTime() + seconds
    elseif label == burstAlert then
        burstAlertHideAt = GetTime() + seconds
    elseif label == alertAoeMode then
        aoeAlertHideAt = GetTime() + seconds
    else
        C_Timer.After(seconds, function()
            if label then
                label:Hide()
            end
        end)
    end
end
local function playToggleSound(enabled, isBurst)
    if P8BA6426E.DB and P8BA6426E.DB.disableSound then
        return
    end
    local soundFile
    if isBurst then
        soundFile = enabled and ("Interface\\AddOns\\" .. (addonName .. "\\toggle_baofa.ogg"))
            or ("Interface\\AddOns\\" .. (addonName .. "\\toggle_off.ogg"))
    else
        soundFile = enabled and ("Interface\\AddOns\\" .. (addonName .. "\\toggle_on.ogg"))
            or ("Interface\\AddOns\\" .. (addonName .. "\\toggle_off.ogg"))
    end
    PlaySoundFile(soundFile)
end
local function cycleAoeMode()
    local aoeMode = ((P8BA6426E.aoeMode or 0) + 1) % 3
    P8BA6426E.aoeMode = aoeMode
    if P8BA6426E.RefreshStateLogo then
        P8BA6426E.RefreshStateLogo()
    end
    if P8BA6426E.alertAoeMode then
        showAlert(P8BA6426E.alertAoeMode, "|cff00ff00" .. (P8BA6426E.L(AOE_MODE_TEXT[aoeMode]) .. "|r"), 1)
    end
    playToggleSound(false)
end
local function toggleMasterSwitch()
    P8BA6426E.DB.masterSwitch = not P8BA6426E.DB.masterSwitch
    P8BA6426E.UpdateMasterSwitchUI(P8BA6426E.DB.masterSwitch)
end
local function toggleBurstSwitch()
    P8BA6426E.SetBurstSwitch(not P8BA6426E.DB.burstSwitch)
end
local function readStrictBoolean(fn, ...)
    assert(type(fn) == "function", "目标玩家状态接口不可用")
    local result = fn(...)
    assert(not (issecretvalue and issecretvalue(result)) and type(result) == "boolean", "目标玩家状态不可读")
    return result
end
local function isTargetEnemyPlayer()
    if not readStrictBoolean(UnitExists, "target") then
        return false
    end
    if not readStrictBoolean(UnitIsPlayer, "target") then
        return false
    end
    return readStrictBoolean(UnitCanAttack, "player", "target")
end
-- 渲染单个标量字段：按字段类型（开关/布尔/距离/计数/数值/冷却/资源…）把 value 编码成 RGB 并写入对应物理行
local function renderScalarField(
    fieldIndex,
    record,
    value,
    status,
    fieldCount,
    route,
    raidPacket,
    forceMasterRed,
    playerHealthColor,
    targetHealthColor
)
    local buildError = pixelLayers and pixelLayers.buildErrors[record.id]
    if buildError then
        error(buildError)
    end
    local valueError = P8BA6426E.classData
        and (P8BA6426E.classData.scalarValueErrors and P8BA6426E.classData.scalarValueErrors[record.id])
    if valueError then
        error(valueError)
    end
    if record.unavailableCode then
        assert(record.statusSource == "same_frame", "标量不可用来源未声明本帧状态")
        if status == "unavailable" then
            value = record.unavailableCode
        elseif status == "unknown" then
            value = 16777215
        elseif status == "known" then
            if type(value) ~= "number" or value ~= value or value < 0 or value > 601 then
                value = 16777215
            end
        else
            error("标量冷却缺少本帧来源状态")
        end
    end
    local chargeSpellID = record.id:match("^charge_(%d+)$")
    if chargeSpellID and not P8BA6426E.IsSpellKnown(tonumber(chargeSpellID)) then
        value = 601
    end
    local r, g, b = 0.2, 0.2, 0.2
    if record.resourceSource then
        local resourceColor = P8BA6426E.ReadPixelResource(record.resourceSource)
        r, g, b = resourceColor:GetRGB()
    elseif fieldIndex <= fieldCount then
        local raidSlot = raidPacket and tonumber(record.id:match("^raid_health_(%d%d)$"))
        if record.id == "master_switch" and forceMasterRed then
            r, g, b = 1, 0, 0
        elseif raidPacket and record.id == raidPacket.ackPixel then
            local frameSequence = raidPacket.frameSequence or 1
            r = 0.003921568627451
            g = 0.003921568627451
            if raidPacket.ackPixel == "party_tank_index" then
                local tankIndex = tonumber(value) or 0
                if tankIndex < 0 or tankIndex > 4 or tankIndex % 1 ~= 0 then
                    tankIndex = 0
                end
                b = (frameSequence * 8 + tankIndex) / 255
            else
                b = frameSequence / 255
            end
        elseif raidPacket and record.id == "focus_cast_unreachable" then
            r = (raidPacket.rosterEpoch or 0) / 255
            local raidCount = tonumber(raidPacket.raidCount) or 0
            if raidCount < 0 or raidCount > 40 or raidCount % 1 ~= 0 then
                raidCount = 0
            end
            local feedbackKind = tonumber(raidPacket.feedbackKind) or 0
            if feedbackKind < 0 or feedbackKind > 3 or feedbackKind % 1 ~= 0 then
                feedbackKind = 0
            end
            local feedbackSequence = tonumber(raidPacket.feedbackSequence) or 0
            if feedbackSequence < 0 or feedbackSequence > 31 or feedbackSequence % 1 ~= 0 then
                feedbackSequence = 0
            end
            g = (128 + raidCount) / 255
            b = (((raidPacket.focusUnreachable and 128 or 0) + feedbackKind * 32) + feedbackSequence) / 255
        elseif raidSlot then
            local base = (raidSlot - 1) * 3
            local healthColors = raidPacket.healthColors
            local tankBySlot = raidPacket.tankBySlot
            local raidFocusHealthLayers = P8BA6426E.raidFocusHealthLayers and P8BA6426E.raidFocusHealthLayers[raidSlot]
            local health1 = healthColors and healthColors[base + 1]
            local health2 = healthColors and healthColors[base + 2]
            local health3 = healthColors and healthColors[base + 3]
            if raidFocusHealthLayers and raidFocusHealthLayers[1] then
                if health1 and health1.GetRGB then
                    raidFocusHealthLayers[1]:SetColorTexture(health1:GetRGB())
                else
                    raidFocusHealthLayers[1]:SetColorTexture(0, 0, 0, 1)
                end
            end
            if raidFocusHealthLayers and raidFocusHealthLayers[2] then
                if health2 and health2.GetRGB then
                    raidFocusHealthLayers[2]:SetColorTexture(health2:GetRGB())
                else
                    raidFocusHealthLayers[2]:SetColorTexture(0, 0, 0, 1)
                end
            end
            if raidFocusHealthLayers and raidFocusHealthLayers[3] then
                if health3 and health3.GetRGB then
                    raidFocusHealthLayers[3]:SetColorTexture(health3:GetRGB())
                else
                    raidFocusHealthLayers[3]:SetColorTexture(0, 0, 0, 1)
                end
            end
            r = tankBySlot and (tankBySlot[base + 1] and 0.50196078431373) or 0
            g = tankBySlot and (tankBySlot[base + 2] and 0.50196078431373) or 0
            b = tankBySlot and (tankBySlot[base + 3] and 0.50196078431373) or 0
        elseif record.id == "team_avg_health" then
            local now = GetTime and GetTime() or 0
            local healerIdle = isHealerIdleOutOfCombat()
            if
                healerIdle and (not rosterDirty and (lastTeamAvgAt ~= nil and now - lastTeamAvgAt < TEAM_AVG_INTERVAL))
            then
                r, g, b = 0, 0, 0
            else
                lastTeamAvgAt = now
                rosterDirty = nil
                renderTeamAvgHealth()
                r, g, b = 0, 0, 0
            end
        elseif record.id == "isMoving" then
            local code = type(value) == "number" and value or 3527951
            r, g, b = intToRGB(code)
        elseif record.id == "player_casting" then
            local playerCastGeneration = tonumber(P8BA6426E.playerCastGeneration) or 0
            if playerCastGeneration < 1 or playerCastGeneration > 99 or playerCastGeneration % 1 ~= 0 then
                playerCastGeneration = 0
            end
            if value then
                r, g, b = 0, 1, playerCastGeneration / 255
            else
                r, g, b = 1, 0, playerCastGeneration / 255
            end
        elseif
            (
                record.id == "target_targets_player"
                or record.id == "target_casting"
                or record.id == "focus_casting"
                or record.id == "mouseover_casting"
            ) and (type(value) == "table" and value.GetRGB)
        then
            r, g, b = value:GetRGB()
        elseif record.id == "player_race_id" then
            local _raceName, _raceFile, raceID = UnitRace("player")
            assert(
                not (issecretvalue and issecretvalue(raceID))
                    and (type(raceID) == "number" and (raceID > 0 and (raceID < 16777216 and raceID % 1 == 0))),
                "种族身份不可读"
            )
            r, g, b = intToRGB(raceID)
        elseif record.id == "target_is_enemy_player" then
            if isTargetEnemyPlayer() then
                r, g, b = 0, 1, 0
            else
                r, g, b = 1, 0, 0
            end
        elseif record.id == "burst" then
            if value then
                r, g, b = 0, 0, 1
            else
                r, g, b = 1, 1, 0
            end
        elseif record.type == "switch" or record.type == "bool" then
            if type(value) == "table" and type(value.GetRGB) == "function" then
                r, g, b = value:GetRGB()
            elseif value then
                r, g, b = 0, 1, 0
            else
                r, g, b = 1, 0, 0
            end
        elseif record.type == "distance" then
            r, g, b = encodeDistance(value)
        elseif record.type == "count" then
            if record.id == "highlight427453" then
                local state = value or 0
                if state == 2 then
                    r, g, b = 0, 0, 1
                elseif state == 1 then
                    r, g, b = 0, 1, 0
                else
                    r, g, b = 1, 0, 0
                end
            else
                r, g, b = encodeCount(value)
            end
        elseif record.type == "number" then
            if type(value) == "table" and value.GetRGB then
                r, g, b = value:GetRGB()
            elseif record.id == "player_health_pct" and playerHealthColor then
                r, g, b = playerHealthColor:GetRGB()
            elseif record.id == "target_health_pct" and targetHealthColor then
                r, g, b = targetHealthColor:GetRGB()
            elseif record.id:match("^party%d+_health_pct$") and (type(value) == "table" and value.GetRGB) then
                r, g, b = value:GetRGB()
            elseif record.id == "combo_strike" then
                local n = value or 0
                local ok, rr, gg, bb = pcall(intToRGB, n)
                if ok then
                    r, g, b = rr, gg, bb
                else
                    r, g, b = 0, 0, 0
                end
            else
                local n = value or 0
                local ok, rr, gg, bb = pcall(intToRGB, n)
                if ok then
                    r, g, b = rr, gg, bb
                else
                    r, g, b = 0, 0, 0
                end
            end
        elseif record.type == "spell" then
            if value then
                r, g, b = 0, 1, 0
            else
                r, g, b = 1, 0, 0
            end
        elseif record.type == "cooldown" then
            local seconds = math.ceil(value or 0)
            r, g, b = intToRGB(seconds)
        elseif record.type == "string" then
        end
    end
    local partyIndex = tonumber(record.id:match("^party(%d)_health_pct$"))
    if partyIndex and P8BA6426E.raidFocusPartyUnavailableLayers then
        local layer = P8BA6426E.raidFocusPartyUnavailableLayers[partyIndex]
        local unavailable = raidPacket
            and (raidPacket.partyUnavailableByIndex and raidPacket.partyUnavailableByIndex[partyIndex] == true)
        if layer then
            layer:SetAlpha(unavailable and 1 or 0)
        end
    end
    if fieldIndex <= fieldCount and (record.row and record.row >= 0) then
        local base = pixelLayers and pixelLayers.bases[record.id]
        if base then
            setTextureRGB(base, r, g, b)
        end
        route.RenderClassicColor(fieldIndex, r, g, b)
    end
end
local updateFrame = CreateFrame("Frame")
-- 主循环（每 0.02 秒）：处理快捷键 → 扫描敌人 → 汇总本帧所有字段值到 frameValues → 逐字段渲染 → 心跳
updateFrame:SetScript("OnUpdate", function(_, elapsed)
    updateAccumulator = updateAccumulator + elapsed
    elapsedSinceLastUpdate = elapsedSinceLastUpdate + elapsed
    if updateAccumulator < UPDATE_INTERVAL then
        return
    end
    updateAccumulator = updateAccumulator - UPDATE_INTERVAL
    local elapsedTotal = elapsedSinceLastUpdate
    elapsedSinceLastUpdate = 0
    local fontPixelRoute = P8BA6426E.FontPixelRoute
    local scalarContract = fontPixelRoute and (fontPixelRoute.GetScalarContract and fontPixelRoute.GetScalarContract())
    local fieldCount = scalarContract and #(scalarContract.scalarRecords or {}) or 0
    ensureHealthColorCurve()
    local mouseover_npc_state = 0
    if type(P8BA6426E.UpdateHealingNpcMouseover) == "function" then
        local ok, result = pcall(P8BA6426E.UpdateHealingNpcMouseover)
        if ok and type(result) == "number" then
            mouseover_npc_state = result
        end
    end
    local editBoxFocused = false
    if type(GetCurrentKeyBoardFocus) == "function" then
        local ok, result = pcall(GetCurrentKeyBoardFocus)
        editBoxFocused = ok and result ~= nil
    end
    if not P8BA6426E.waitingForKey then
        if P8BA6426E.IsBindPressed(P8BA6426E.DB.masterKey) then
            if not P8BA6426E.masterKeyPressed then
                P8BA6426E.masterKeyPressed = true
                if not editBoxFocused then
                    toggleMasterSwitch()
                end
            end
        else
            P8BA6426E.masterKeyPressed = false
        end
        if P8BA6426E.IsBindPressed(P8BA6426E.DB.burstKey) then
            if not P8BA6426E.burstKeyPressed then
                P8BA6426E.burstKeyPressed = true
                if not editBoxFocused then
                    toggleBurstSwitch()
                end
            end
        else
            P8BA6426E.burstKeyPressed = false
        end
        if P8BA6426E.IsBindPressed(P8BA6426E.DB.aoeKey) then
            if not P8BA6426E.aoeKeyPressed then
                P8BA6426E.aoeKeyPressed = true
                if not editBoxFocused then
                    cycleAoeMode()
                end
            end
        else
            P8BA6426E.aoeKeyPressed = false
        end
    end
    enemies_8yd, active_enemies, nearby8, active, guids, nearby8Overflow, combat, combatKnown =
        scanVisibleHostileEnemies(8)
    active_enemies = applyEnemyCountCorrection(active_enemies)
    P8BA6426E.enemyCountSnapshot = {
        updatedAt = GetTime(),
        enemies_8yd_raw = enemies_8yd,
        active_enemies_raw = active_enemies,
        nearby8 = nearby8,
        nearby8Overflow = nearby8Overflow,
        active = active,
        guids = guids,
        combat = combat,
        combat_enemies_raw = #combat,
        combatKnown = combatKnown,
    }
    if type(P8BA6426E.OnEnemyCountSnapshotUpdated) == "function" then
        P8BA6426E.OnEnemyCountSnapshotUpdated(false)
    end
    local aoe_mode = P8BA6426E.aoeMode or 0
    local masterSwitch = P8BA6426E.DB.masterSwitch
    if editBoxFocused then
        masterSwitch = false
    end
    if _G.P8BA6426ECharuExpire and GetTime() < _G.P8BA6426ECharuExpire then
        masterSwitch = false
    end
    if not P8BA6426E.IsAutoTargetGateOpen(enemies_8yd) then
        masterSwitch = false
    end
    local forceMasterRed = false
    if renderHealerMasterHealth(masterSwitch) then
        forceMasterRed = true
    end
    local distance = getUnitDistance("target")
    local db = P8BA6426E.DB and P8BA6426E.DB.masterSwitch or nil
    if db ~= false and lastMasterSwitch == false then
        rosterDirty = true
    end
    lastMasterSwitch = db
    wipe(frameValues)
    frameValues.master_switch = masterSwitch
    frameValues.mouseover_npc_state = mouseover_npc_state
    frameValues.burst = P8BA6426E.DB.burstSwitch
    frameValues.aoe_mode = aoe_mode
    local ttd = 0
    if type(P8BA6426E.GetAutoTargetPacket) == "function" then
        local ok, result = pcall(P8BA6426E.GetAutoTargetPacket)
        if ok and type(result) == "number" then
            ttd = result
        end
    end
    frameValues.ttd = ttd
    if P8BA6426E.IsForeverHealingSupported and P8BA6426E.IsForeverHealingSupported() then
        local ok, result = pcall(P8BA6426E.GetForeverHealingModePacket)
        frameValues._forever_healing_mode = ok and result or nil
    end
    frameValues.ttf = 0
    frameValues.distance = distance
    frameValues.active_enemies = active_enemies
    frameValues.enemies_8yd = enemies_8yd
    local statuses = {}
    local scalarUnavailableCodes = scalarContract and scalarContract.scalarUnavailableCodes
    if scalarUnavailableCodes and scalarUnavailableCodes.trinket1_cd then
        frameValues.trinket1_cd, statuses.trinket1_cd = P8BA6426E.GetTrinketSlotCooldownRemaining(13)
        frameValues.trinket2_cd, statuses.trinket2_cd = P8BA6426E.GetTrinketSlotCooldownRemaining(14)
    else
        frameValues.trinket1_cd = P8BA6426E.GetTrinketSlotCooldownRemaining(13) or 601
        frameValues.trinket2_cd = P8BA6426E.GetTrinketSlotCooldownRemaining(14) or 601
    end
    frameValues.gcd = P8BA6426E.IsGcdActive()
    local player_casting, cast_remaining, player_cast_spell_id, player_cast_observation_code =
        P8BA6426E.GetPlayerCastState(true)
    frameValues.player_casting = player_casting
    frameValues.cast_remaining = cast_remaining
    frameValues.player_cast_spell_id = player_cast_spell_id
    frameValues.player_cast_observation_code = player_cast_observation_code
    local player_succeeded_generation, player_succeeded_spell_id = P8BA6426E.GetPlayerSucceededState()
    frameValues.player_succeeded_generation = player_succeeded_generation
    frameValues.player_succeeded_spell_id = player_succeeded_spell_id
    for i = 1, 3, 1 do
        local generation, spellID = P8BA6426E.GetFocusedSuccessHistory(i + 1)
        frameValues["player_succeeded_previous_" .. (i .. "_generation")] = generation
        frameValues["player_succeeded_previous_" .. (i .. "_spell_id")] = spellID
    end
    if UnitAffectingCombat("player") then
        local now = GetTime()
        if not combatStartedAt then
            combatStartedAt = now
        end
        frameValues.combat_time = math.floor(now - combatStartedAt)
    else
        combatStartedAt = nil
        frameValues.combat_time = 0
    end
    frameValues.class = P8BA6426E.DB.currentClass or "UNKNOWN"
    frameValues.specIndex = P8BA6426E.DB.currentSpecIndex or 0
    frameValues.specID = P8BA6426E.DB.currentSpecID or 0
    frameValues.specName = P8BA6426E.DB.currentSpecName or P8BA6426E.L("未知")
    frameValues.spec_id = P8BA6426E.GetPackedGameIdentity()
    frameValues.target_casting = getTargetCastingColor()
    frameValues.target_targets_player = getTargetTargetIsPlayerColor()
    frameValues.in_raid, frameValues.in_mythic_plus = getRaidAndMythicPlusState()
    frameValues.focus_casting = getFocusCastingColor()
    frameValues.mouseover_casting = getHostileUnitCastingColor("mouseover")
    frameValues.mouseover_revision = mouseoverRevision
    local playerHealthColor, targetHealthColor = nil, nil
    wipe(partyHealthColors)
    wipe(partyUnavailable)
    local playerDead = UnitIsDeadOrGhost("player")
    for i = 1, 4, 1 do
        local unit = "party" .. i
        partyUnavailable[i] = not UnitExists(unit) or UnitIsDeadOrGhost(unit)
    end
    if ensureHealthColorCurve() then
        if not playerDead then
            local ok, result = pcall(UnitHealthPercent, "player", true, P8BA6426E.healthColorCurve)
            if ok and result then
                playerHealthColor = result
            elseif not ok then
                recordSecretApiFault("UnitHealthPercent:player", result)
            end
        end
        local ok, result = pcall(UnitHealthPercent, "target", true, P8BA6426E.healthColorCurve)
        if ok and result then
            targetHealthColor = result
        elseif not ok then
            recordSecretApiFault("UnitHealthPercent:target", result)
        end
        for i = 1, 4, 1 do
            local unit = "party" .. i
            if not partyUnavailable[i] then
                local ok, result = pcall(UnitHealthPercent, unit, true, P8BA6426E.healthColorCurve)
                if ok and result then
                    partyHealthColors[i] = result
                elseif not ok then
                    recordSecretApiFault("UnitHealthPercent:" .. unit, result)
                end
            end
        end
    end
    frameValues.player_health_pct = playerDead and 127 or (playerHealthColor and 0 or 255)
    frameValues.target_health_pct = targetHealthColor and 0 or 255
    frameValues.mouseover_target_health_pct = getMouseoverHostileHealthColor()
    for i = 1, 4, 1 do
        local key = "party" .. (i .. "_health_pct")
        if partyHealthColors[i] then
            frameValues[key] = partyHealthColors[i]
        else
            frameValues[key] = partyUnavailable[i] and 127 or 126
        end
    end
    for _, testSpell in ipairs(P8BA6426E.testSpells) do
        local key = "spell_" .. testSpell
        if activeScalarIDs[key] then
            frameValues["spell_" .. testSpell] = P8BA6426E.IsSpellReady(testSpell)
        end
    end
    local action_avail = 1
    if P8BA6426E.actionAvailSpellIDs then
        for i = 1, #P8BA6426E.actionAvailSpellIDs, 1 do
            if P8BA6426E.IsSpellReady(P8BA6426E.actionAvailSpellIDs[i]) then
                action_avail = action_avail + 2 ^ i
            end
        end
    end
    frameValues.action_avail = action_avail
    consumableRefreshAccumulator = consumableRefreshAccumulator + elapsedTotal
    if consumableRefreshAccumulator >= 5 then
        consumableRefreshAccumulator = 0
        wipe(consumableRemainingCache)
        for _, consumableItem in ipairs(P8BA6426E.consumableItems) do
            if not (scalarUnavailableCodes and scalarUnavailableCodes[consumableItem.id]) then
                consumableRemainingCache[consumableItem.id] = P8BA6426E.GetConsumableCooldownRemaining(consumableItem)
            end
        end
    end
    for _, consumableItem in ipairs(P8BA6426E.consumableItems) do
        if scalarUnavailableCodes and scalarUnavailableCodes[consumableItem.id] then
            frameValues[consumableItem.id], statuses[consumableItem.id] =
                P8BA6426E.GetConsumableCooldownSample(consumableItem)
        elseif consumableRemainingCache[consumableItem.id] == 601 then
            frameValues[consumableItem.id] = 601
        else
            frameValues[consumableItem.id] = P8BA6426E.GetConsumableCooldownFast(consumableItem) or 0
        end
    end
    if P8BA6426E.trinketItemID then
        frameValues.trinketCD = P8BA6426E.GetTrinketCooldownRemaining()
    end
    if P8BA6426E.classData and P8BA6426E.classData.GetExtraValues then
        P8BA6426E.classData.GetExtraValues(frameValues)
    end
    if P8BA6426E.healingNpcFocusMatchLayer and P8BA6426E.RenderHealingNpcFocusMatch then
        pcall(P8BA6426E.RenderHealingNpcFocusMatch, P8BA6426E.healingNpcFocusMatchLayer)
    end
    local raidPacket = P8BA6426E.GetRaidFocusPacket and P8BA6426E.GetRaidFocusPacket() or nil
    if
        raidPacket
        and (
            P8BA6426E.raidFocusAckLayers
            and (
                (
                    raidPacket.frameSequence ~= P8BA6426E.raidFocusAckFrameSequence
                    or raidPacket.ackPixel ~= P8BA6426E.raidFocusAckCarrier
                ) and P8BA6426E.RenderRaidFocusAcknowledgement
            )
        )
    then
        pcall(P8BA6426E.RenderRaidFocusAcknowledgement, P8BA6426E.raidFocusAckLayers, raidPacket)
        P8BA6426E.raidFocusAckFrameSequence = raidPacket.frameSequence
        P8BA6426E.raidFocusAckCarrier = raidPacket.ackPixel
    end
    frameValues.addon_version_code = P8BA6426E.addonVersionCode
    frameValues.isMoving = P8BA6426E.isMoving or false
    _G.P8BA6426EValues = frameValues
    for i, record in ipairs(activeScalarRecords) do
        local value = frameValues[record.id]
        if i <= fieldCount and (record.row and (record.row >= 0 and fontPixelRoute)) then
            fontPixelRoute.RunClassicField(
                i,
                renderScalarField,
                i,
                record,
                value,
                statuses[record.id],
                fieldCount,
                fontPixelRoute,
                raidPacket,
                forceMasterRed,
                playerHealthColor,
                targetHealthColor
            )
        end
    end
    if fieldCount > 0 then
        fontPixelRoute.OnClassicFrame()
    end
    if masterAlertHideAt > 0 and GetTime() >= masterAlertHideAt then
        if masterAlert then
            masterAlert:Hide()
        end
        masterAlertHideAt = 0
    end
    if burstAlertHideAt > 0 and GetTime() >= burstAlertHideAt then
        if burstAlert then
            burstAlert:Hide()
        end
        burstAlertHideAt = 0
    end
    if aoeAlertHideAt > 0 and GetTime() >= aoeAlertHideAt then
        if alertAoeMode then
            alertAoeMode:Hide()
        end
        aoeAlertHideAt = 0
    end
end)
-- 屏幕上的状态 Logo（左键打开设置，右键切换爆发）与右侧的 总开关/爆发/模式 三个按钮
local stateLogo = CreateFrame("Button", "P8BA6426EStateLogo", UIParent)
P8BA6426E.stateLogo = stateLogo
local function getLogoSize()
    local size = P8BA6426E.DB and tonumber(P8BA6426E.DB.logoSize) or 48
    return math.min(96, math.max(24, size))
end
local function getLogoTexturePath(state, singleTarget)
    local base = "Interface\\AddOns\\" .. (addonName .. "\\P8BA6426ELogo")
    if state == "blind" then
        return base .. (singleTarget and "BlindR" or "Blind")
    elseif state == "red" then
        return base .. (singleTarget and "RedR" or "Red")
    end
    return base .. (singleTarget and "NormalR" or "Normal")
end
stateLogo:SetSize(getLogoSize(), getLogoSize())
local savedPoint = P8BA6426E.DB and P8BA6426E.DB.logoPoint
if savedPoint and (type(savedPoint) == "table" and #savedPoint >= 5) then
    pcall(function()
        stateLogo:ClearAllPoints()
        stateLogo:SetPoint(unpack(savedPoint))
    end)
else
    stateLogo:SetPoint("LEFT", UIParent, "LEFT", 30, 0)
end
stateLogo:SetFrameStrata("LOW")
stateLogo:SetClampedToScreen(true)
stateLogo:EnableMouse(true)
stateLogo:SetMovable(true)
stateLogo:RegisterForDrag("LeftButton")
stateLogo:RegisterForClicks("LeftButtonUp", "RightButtonUp")
stateLogo:SetScript("OnDragStart", stateLogo.StartMoving)
stateLogo:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self._didDrag = true
    local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
    if P8BA6426E.DB then
        P8BA6426E.DB.logoPoint = { point, relativeTo and relativeTo:GetName() or nil, relativePoint, x, y }
    end
end)
stateLogo:SetScript("OnClick", function(self, button)
    if self._didDrag then
        self._didDrag = nil
        return
    end
    if button == "RightButton" then
        toggleBurstSwitch()
    else
        P8BA6426E.ToggleDock()
    end
end)
local logoTexture = stateLogo:CreateTexture(nil, "ARTWORK")
logoTexture:SetAllPoints(stateLogo)
stateLogo.tex = logoTexture
local statusPanel = CreateFrame("Frame", nil, UIParent)
statusPanel:SetPoint("LEFT", stateLogo, "RIGHT", 4, 0)
statusPanel:SetSize(58, 66)
statusPanel:SetFrameStrata("LOW")
local function createStatusButton(offsetY, onClick)
    local button = CreateFrame("Button", nil, statusPanel, BackdropTemplateMixin and "BackdropTemplate")
    button:SetSize(56, 19)
    button:SetPoint("TOPLEFT", statusPanel, "TOPLEFT", 0, offsetY)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0.5)
    button:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetScript("OnClick", onClick)
    return button
end
local function localeText(zh, en)
    local locale = GetLocale()
    return (locale == "zhCN" or locale == "zhTW") and zh or en
end
local masterButton = createStatusButton(0, toggleMasterSwitch)
local burstButton = createStatusButton(-23, toggleBurstSwitch)
local aoeButton = createStatusButton(-46, cycleAoeMode)
function P8BA6426E.RefreshAllOverlayVisibility()
    if P8BA6426E.FontPixelRoute then
        P8BA6426E.FontPixelRoute.RefreshVisibility()
    end
    if P8BA6426E.stateLogo and P8BA6426E.DB then
        P8BA6426E.stateLogo:SetShown(not P8BA6426E.DB.logoHidden)
    end
    if P8BA6426E.DB then
        statusPanel:SetShown(P8BA6426E.DB.showLogoText ~= false)
    else
        statusPanel:Hide()
    end
end
function P8BA6426E.RefreshStateLogo()
    if not P8BA6426E.stateLogo then
        return
    end
    local masterOn = P8BA6426E.DB and P8BA6426E.DB.masterSwitch
    local burstOn = P8BA6426E.DB and P8BA6426E.DB.burstSwitch
    local singleTarget = P8BA6426E.aoeMode == 1
    local state = (not masterOn) and "blind" or (burstOn and "red" or "normal")
    local texturePath = getLogoTexturePath(state, singleTarget)
    logoTexture:SetTexture(texturePath)
    if P8BA6426E.minimapButton and P8BA6426E.minimapButton.icon then
        P8BA6426E.minimapButton.icon:SetTexture(texturePath)
    end
    masterButton.text:SetText(localeText("总开关", "Master"))
    masterButton.text:SetTextColor(masterOn and 0.2 or 0.8, masterOn and 1 or 0.2, 0.2, 1)
    burstButton.text:SetText(localeText("爆发", "Burst"))
    burstButton.text:SetTextColor(burstOn and 0.2 or 0.8, burstOn and 1 or 0.2, 0.2, 1)
    local isSingle = P8BA6426E.aoeMode == 1
    local isAoe = P8BA6426E.aoeMode == 2
    aoeButton.text:SetText(
        isAoe and localeText("群体", "AoE")
            or localeText(isSingle and "单体" or "自动", isSingle and "ST" or "Auto")
    )
    aoeButton.text:SetTextColor(isSingle and 1 or 0.2, isSingle and 0.2 or 1, 0.2, 1)
    local showAoe = P8BA6426E.classData and P8BA6426E.classData.showAoeModeButton
    aoeButton:SetShown(not not showAoe)
    stateLogo:SetSize(getLogoSize(), getLogoSize())
    P8BA6426E.RefreshAllOverlayVisibility()
end
P8BA6426E.RefreshStateLogo()
local DEFAULT_MINIMAP_ANGLE = 220
local DEFAULT_MINIMAP_RADIUS = 80
local minimapButton
local minimapAngle = DEFAULT_MINIMAP_ANGLE
local function normalizeAngle(angle)
    return (tonumber(angle) or DEFAULT_MINIMAP_ANGLE) % 360
end
local function getMinimapRadius()
    local width = Minimap and Minimap:GetWidth() or 0
    local height = Minimap and Minimap:GetHeight() or 0
    local minSide = math.min(width or 0, height or 0)
    if minSide <= 0 then
        return DEFAULT_MINIMAP_RADIUS
    end
    return minSide / 2 + 10
end
local function placeMinimapButton(angle)
    if not minimapButton or not Minimap then
        return
    end
    minimapAngle = normalizeAngle(angle)
    local radians = math.rad(minimapAngle)
    local radius = getMinimapRadius()
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end
local function onMinimapDragUpdate()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then
        return
    end
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale <= 0 then
        return
    end
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    placeMinimapButton(math.deg(math.atan2(cursorY - centerY, cursorX - centerX)))
end
local function saveMinimapAngle()
    if not P8BA6426E.DB and P8BA6426E.InitDB then
        P8BA6426E.InitDB()
    end
    if P8BA6426E.DB then
        P8BA6426E.DB.minimapButtonAngle = normalizeAngle(minimapAngle)
    end
end
local function showMinimapTooltip(owner)
    local x = owner:GetCenter()
    local anchor = x and (x < UIParent:GetWidth() / 2 and "ANCHOR_RIGHT") or "ANCHOR_LEFT"
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetText("P8BA6426E", 1, 1, 1)
    GameTooltip:AddLine(P8BA6426E.L("左键：呼出/隐藏设置"), 0.82, 0.82, 0.82)
    GameTooltip:AddLine(P8BA6426E.L("拖动：移动小地图角标"), 0.82, 0.82, 0.82)
    GameTooltip:Show()
end
if Minimap then
    minimapButton = CreateFrame("Button", "P8BA6426EMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    minimapButton:RegisterForClicks("LeftButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton.icon = minimapButton:CreateTexture(nil, "ARTWORK")
    minimapButton.icon:SetPoint("CENTER")
    minimapButton.icon:SetSize(32, 32)
    minimapButton.icon:SetTexture("Interface\\AddOns\\" .. (addonName .. "\\P8BA6426EIcon"))
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("CENTER")
    highlight:SetSize(42, 42)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    minimapButton:SetScript("OnEnter", showMinimapTooltip)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    minimapButton:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        self.icon:SetSize(32, 32)
    end)
    minimapButton:SetScript("OnMouseDown", function(self)
        self._didDrag = false
        self.icon:SetSize(30, 30)
    end)
    minimapButton:SetScript("OnMouseUp", function(self)
        self.icon:SetSize(32, 32)
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self._didDrag = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", onMinimapDragUpdate)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        onMinimapDragUpdate()
        self:SetScript("OnUpdate", nil)
        self.icon:SetSize(32, 32)
        saveMinimapAngle()
    end)
    minimapButton:SetScript("OnClick", function(self)
        if self._didDrag then
            return
        end
        P8BA6426E.ToggleDock()
    end)
    if type(Minimap.HookScript) == "function" then
        Minimap:HookScript("OnSizeChanged", function()
            placeMinimapButton(minimapAngle)
        end)
    end
    P8BA6426E.minimapButton = minimapButton
    placeMinimapButton(P8BA6426E.DB and P8BA6426E.DB.minimapButtonAngle)
    local loginFrame = CreateFrame("Frame")
    P8BA6426E.SafeRegisterEvent(loginFrame, "PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        if not P8BA6426E.DB and P8BA6426E.InitDB then
            P8BA6426E.InitDB()
        end
        placeMinimapButton(P8BA6426E.DB and P8BA6426E.DB.minimapButtonAngle)
    end)
end
-- 进入游戏时自动把影响色块识别的 CVar（渲染倍数、伽马、亮度、对比度、姓名板…）设为推荐值
local RECOMMENDED_CVARS = {
    { key = "RenderScale", target = 1, name = "渲染倍数", scale = nil },
    { key = "Gamma", target = 1, name = "伽马值", scale = nil },
    { key = "Brightness", target = 0.5, name = "亮度", scale = 100 },
    { key = "Contrast", target = 0.5, name = "对比度", scale = 100 },
    { key = "nameplateShowEnemies", target = 1, name = "敌方姓名板", scale = nil },
    { key = "nameplateShowEnemyMinions", target = 1, name = "敌方仆从姓名板", scale = nil },
    { key = "nameplateShowEnemyMinus", target = 1, name = "敌方杂兵姓名板", scale = nil },
    { key = "nameplateShowAll", target = 1, name = "显示所有姓名板", scale = nil },
    { key = "screenEdgeFlash", target = 0, name = "屏幕边缘闪光", scale = nil },
    { key = "doNotFlashLowHealthWarning", target = 1, name = "生命值过低时不闪烁屏幕", scale = nil },
}
local function getCVarNumber(name)
    local ok, result = pcall(GetCVar, name)
    if not ok or result == nil or result == "" then
        return nil
    end
    return tonumber(result)
end
local function applyRecommendedCVars()
    if InCombatLockdown() then
        print("|cffff0000[P8BA6426E]|r 战斗中无法修改受保护的游戏设置，请脱战后重试")
        return
    end
    local applied = {}
    for _, cvar in ipairs(RECOMMENDED_CVARS) do
        local value = cvar.scale and (cvar.target * cvar.scale) or cvar.target
        local ok = pcall(SetCVar, cvar.key, tostring(value))
        if ok then
            table.insert(applied, P8BA6426E.L(cvar.name))
        end
    end
    if #applied > 0 then
        local separator = P8BA6426E.IsChineseClient() and "、" or ", "
        print(
            P8BA6426E.L("|cff00ff88[P8BA6426E]|r 已将校准所需设置为推荐值：")
                .. table.concat(applied, separator)
        )
    end
end
local cvarFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(cvarFrame, "PLAYER_ENTERING_WORLD")
cvarFrame:SetScript("OnEvent", function()
    applyRecommendedCVars()
end)
do
    -- 强制关闭“使用 UI 缩放”，否则像素色块会被插值导致读数错误
    local uiScaleFrame = CreateFrame("Frame")
    local worldEntered, pendingAfterCombat, checkScheduled, settingCVar = false, false, false, false
    local disabledNotified, failureNotified, combatNotified = false, false, false
    StaticPopupDialogs.P8BA6426E_UI_SCALE_WARNING =
        { text = "%s", button1 = OKAY, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
    local function enforceNoUiScale()
        local useUiScale = getCVarNumber("useUiScale")
        if useUiScale == 0 then
            pendingAfterCombat = false
            if failureNotified then
                StaticPopup_Hide("P8BA6426E_UI_SCALE_WARNING")
            end
            return
        end
        if InCombatLockdown() then
            pendingAfterCombat = true
            if not combatNotified then
                combatNotified = true
                print(
                    P8BA6426E.L(
                        "|cffffff00[P8BA6426E]|r UI 缩放可能影响色块识别，将在脱战后自动关闭“使用 UI 缩放”。"
                    )
                )
            end
            return
        end
        pendingAfterCombat = false
        local disabled = false
        if useUiScale == 1 then
            settingCVar = true
            local ok, result = pcall(SetCVar, "useUiScale", "0")
            disabled = ok and (result ~= false and getCVarNumber("useUiScale") == 0)
            settingCVar = false
        end
        if disabled then
            if failureNotified then
                StaticPopup_Hide("P8BA6426E_UI_SCALE_WARNING")
            end
            if not disabledNotified then
                disabledNotified = true
                print(
                    P8BA6426E.L(
                        "|cff00ff88[P8BA6426E]|r 已自动关闭“使用 UI 缩放”，以避免色块读数异常。界面大小可能变化，原缩放比例已保留。"
                    )
                )
            end
        elseif not failureNotified then
            failureNotified = true
            local message = P8BA6426E.L(
                "|cffff8800[P8BA6426E]|r 无法自动关闭“使用 UI 缩放”。请在游戏设置中搜索“UI 缩放”，手动取消勾选“使用 UI 缩放”；否则可能出现团队血量 N/A、自动选择焦点停止。"
            )
            print(message)
            StaticPopup_Show("P8BA6426E_UI_SCALE_WARNING", message)
        end
    end
    local function scheduleUiScaleCheck()
        if checkScheduled or settingCVar or not worldEntered then
            return
        end
        checkScheduled = true
        C_Timer.After(0, function()
            checkScheduled = false
            enforceNoUiScale()
        end)
    end
    P8BA6426E.SafeRegisterEvent(uiScaleFrame, "PLAYER_ENTERING_WORLD")
    P8BA6426E.SafeRegisterEvent(uiScaleFrame, "CVAR_UPDATE")
    P8BA6426E.SafeRegisterEvent(uiScaleFrame, "UI_SCALE_CHANGED")
    P8BA6426E.SafeRegisterEvent(uiScaleFrame, "PLAYER_REGEN_ENABLED")
    uiScaleFrame:SetScript("OnEvent", function(_, event, cvarName)
        if event == "PLAYER_ENTERING_WORLD" then
            worldEntered = true
        elseif event == "CVAR_UPDATE" then
            cvarName = type(cvarName) == "string" and string.lower(cvarName) or ""
            if cvarName ~= "useuiscale" and cvarName ~= "uiscale" then
                return
            end
        elseif event == "PLAYER_REGEN_ENABLED" and not pendingAfterCombat then
            return
        end
        scheduleUiScaleCheck()
    end)
end
function P8BA6426E.UpdateDockLayout()
    P8BA6426E.RefreshStateLogo()
end
function P8BA6426E.RefreshDockButtonColors()
    P8BA6426E.RefreshStateLogo()
end
local alertFrame = CreateFrame("Frame", nil, UIParent)
alertFrame:SetSize(600, 220)
alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
alertFrame:SetFrameStrata("HIGH")
local function createAlertLabel(parent, offsetY)
    local label = parent:CreateFontString(nil, "OVERLAY")
    P8BA6426E.fontFile, _, fontFlags = GameFontNormal:GetFont()
    label:SetFont(P8BA6426E.fontFile, 56, "OUTLINE")
    label:SetShadowOffset(2, -2)
    label:SetShadowColor(0, 0, 0, 0.8)
    label:SetPoint("TOP", parent, "TOP", 0, offsetY)
    return label
end
masterAlert = createAlertLabel(alertFrame, -10)
masterAlert:Hide()
burstAlert = createAlertLabel(alertFrame, -70)
burstAlert:Hide()
alertAoeMode = createAlertLabel(alertFrame, -130)
alertAoeMode:Hide()
P8BA6426E.alertAoeMode = alertAoeMode
function P8BA6426E.UpdateMasterSwitchUI(enabled)
    playToggleSound(not not enabled)
    showAlert(masterAlert, enabled and "|cff00ff00开|r" or "|cffff0000关|r", 1)
    P8BA6426E.RefreshStateLogo()
end
function P8BA6426E.UpdateBurstSwitchUI(enabled)
    playToggleSound(not not enabled, true)
    showAlert(burstAlert, enabled and "|cff00ff00爆发开|r" or "|cffff0000爆发关|r", 1)
    P8BA6426E.RefreshStateLogo()
end
function P8BA6426E.UpdateAoeModeUI(mode)
    local safeMode = AOE_MODE_TEXT[mode] and mode or 0
    P8BA6426E.RefreshStateLogo()
    if P8BA6426E.alertAoeMode then
        local text = P8BA6426E.L(AOE_MODE_TEXT[safeMode])
        showAlert(P8BA6426E.alertAoeMode, "|cff00ff00" .. (text .. "|r"), 1)
    end
end
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("public.update", "timed", function()
        return updateFrame and updateFrame:GetScript("OnUpdate") or nil
    end, function(handler)
        if updateFrame then
            updateFrame:SetScript("OnUpdate", handler)
        end
    end)
    logicDiagnostics.Declare("public.enemy_count", "sampled", function()
        return scanVisibleHostileEnemies
    end, function(fn)
        scanVisibleHostileEnemies = fn
    end)
end
