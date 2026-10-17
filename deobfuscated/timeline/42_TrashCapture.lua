--[[
  TrashCapture —— 大秘境小怪采集器：记录姓名板出现/施法事件到 SavedVariables（数据采集用）
  原始文件：0aff22.lua（TOC 第 42 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
-- 仅在这些大秘境地图（难度 8）中采集
local SUPPORTED_INSTANCE_IDS = {
    [1762] = true,
    [1877] = true,
    [2521] = true,
    [2813] = true,
    [2825] = true,
    [2859] = true,
    [2923] = true,
    [2993] = true,
}
local MAX_RUNS = 3
local MAX_EVENTS = 1024
local MAX_UNIT_SLOTS = 200
local MAX_INT32 = 2147483647
local MAX_UINT32 = 4294967295
local armed = false
local captureFrame = nil
local session = nil
local waitingForNextKey = false
local handleEvent
local stopCapture
local safeHandleEvent
local ZONE_EVENTS = {
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_ENTERING_WORLD",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
}
local CAPTURE_EVENTS = {
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_DELAYED",
}
local SPELLCAST_KIND = {
    UNIT_SPELLCAST_START = "spell_start",
    UNIT_SPELLCAST_SUCCEEDED = "spell_succeeded",
    UNIT_SPELLCAST_STOP = "spell_stop",
    UNIT_SPELLCAST_INTERRUPTED = "spell_interrupted",
    UNIT_SPELLCAST_FAILED = "spell_failed",
    UNIT_SPELLCAST_CHANNEL_START = "spell_channel_start",
    UNIT_SPELLCAST_CHANNEL_STOP = "spell_channel_stop",
    UNIT_SPELLCAST_DELAYED = "spell_delayed",
}
local VALID_EVENT_KINDS = {
    nameplate_added = true,
    nameplate_removed = true,
    combat_started = true,
    combat_ended = true,
    boss_started = true,
    boss_ended = true,
    spell_start = true,
    spell_succeeded = true,
    spell_stop = true,
    spell_interrupted = true,
    spell_failed = true,
    spell_channel_start = true,
    spell_channel_stop = true,
    spell_delayed = true,
}
local VALID_END_REASONS = {
    disarmed = true,
    map_changed = true,
    left_instance = true,
    capture_error = true,
    registration_failed = true,
    challenge_completed = true,
    challenge_reset = true,
}
local READABLE_FLAGS = {
    unitGuid = true,
    unitIsPlayer = true,
    npcId = true,
    eventSpellId = true,
    castSpellId = true,
    castStartedAt = true,
    castEndsAt = true,
    castBarId = true,
}
local function isSecret(v)
    if type(issecretvalue) ~= "function" then
        return true
    end
    local ok, result = pcall(issecretvalue, v)
    return not ok or result == true
end
local function isFiniteNumber(value)
    return type(value) == "number" and (value == value and (value ~= math.huge and value ~= -math.huge))
end
local function readInt(v, minValue, maxValue)
    if isSecret(v) or not isFiniteNumber(v) or v % 1 ~= 0 or v < minValue or (maxValue and v > maxValue) then
        return nil
    end
    return v
end
local function readString(v, maxLength)
    if isSecret(v) or type(v) ~= "string" or #v > maxLength then
        return nil
    end
    return v
end
local function inRange(v, minValue, maxValue)
    return not isSecret(v) and (isFiniteNumber(v) and (v >= minValue and v <= maxValue))
end
local function isArrayOf(arr, maxLength, validator)
    if type(arr) ~= "table" or isSecret(arr) then
        return false
    end
    local n = #arr
    if n > maxLength then
        return false
    end
    for key in pairs(arr) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > n then
            return false
        end
    end
    for i = 1, n, 1 do
        if not validator(arr[i]) then
            return false
        end
    end
    return true
end
local function isValidReadable(readable)
    if type(readable) ~= "table" or isSecret(readable) then
        return false
    end
    for key, value in pairs(readable) do
        if not READABLE_FLAGS[key] or isSecret(value) or type(value) ~= "boolean" then
            return false
        end
    end
    for key in pairs(READABLE_FLAGS) do
        if type(readable[key]) ~= "boolean" then
            return false
        end
    end
    return true
end
local function isOptionalInt(v, minValue, maxValue)
    return v == nil or readInt(v, minValue, maxValue) ~= nil
end
local function isOptionalNumber(v, minValue, maxValue)
    return v == nil or inRange(v, minValue, maxValue)
end
local function isValidEvent(value)
    if
        type(value) ~= "table"
        or isSecret(value)
        or not readInt(value.sequence, 1, MAX_INT32)
        or not VALID_EVENT_KINDS[readString(value.kind, 64)]
        or not inRange(value.receivedAt, 0, MAX_UINT32 / 1000)
        or not readInt(value.combatGeneration, 0, MAX_INT32)
        or not isValidReadable(value.readable)
    then
        return false
    end
    return isOptionalInt(value.appearanceOrdinal, 1, MAX_INT32)
        and (
            isOptionalInt(value.npcId, 1, MAX_INT32)
            and (
                isOptionalInt(value.spellId, 1, MAX_INT32)
                and (
                    isOptionalInt(value.castSpellId, 1, MAX_INT32)
                    and (
                        isOptionalInt(value.castBarId, 0, MAX_INT32)
                        and (
                            isOptionalNumber(value.castStartedAt, -MAX_UINT32 / 1000, MAX_UINT32 / 1000)
                            and isOptionalNumber(value.castEndsAt, -MAX_UINT32 / 1000, MAX_UINT32 / 1000)
                        )
                    )
                )
            )
        )
end
local function isValidRun(value)
    if
        type(value) ~= "table"
        or isSecret(value)
        or not readInt(value.runId, 1, MAX_INT32)
        or not readInt(value.instanceId, 1, MAX_INT32)
        or not SUPPORTED_INSTANCE_IDS[value.instanceId]
        or value.difficultyId ~= 8
        or not inRange(value.startedAt, 0, MAX_UINT32 / 1000)
        or not readInt(value.eventsSeen, 0, MAX_INT32)
        or not readInt(value.eventsDropped, 0, MAX_INT32)
        or not readInt(value.unitMappingsSeen, 0, MAX_UNIT_SLOTS)
        or not readInt(value.unitMappingsDropped, 0, MAX_INT32)
        or not readInt(value.apiQueriesSkipped, 0, MAX_INT32)
        or not isArrayOf(value.events, MAX_EVENTS, isValidEvent)
    then
        return false
    end
    if value.eventsSeen < #value.events or value.eventsSeen < value.eventsDropped then
        return false
    end
    if value.build ~= nil and not readString(value.build, 32) then
        return false
    end
    if value.endedAt ~= nil and not inRange(value.endedAt, 0, MAX_UINT32 / 1000) then
        return false
    end
    return value.endReason == nil or VALID_END_REASONS[readString(value.endReason, 64)] == true
end
local function nowPrecise()
    local clockFn = type(GetTimePreciseSec) == "function" and GetTimePreciseSec or GetTime
    if type(clockFn) ~= "function" then
        return nil
    end
    local ok, result = pcall(clockFn)
    if not ok or isSecret(result) or not isFiniteNumber(result) or result < 0 then
        return nil
    end
    return result
end
local function newReadableFlags()
    return {
        unitGuid = false,
        unitIsPlayer = false,
        npcId = false,
        eventSpellId = false,
        castSpellId = false,
        castStartedAt = false,
        castEndsAt = false,
        castBarId = false,
    }
end
local function getSupportedInstance()
    if type(GetInstanceInfo) ~= "function" then
        return nil
    end
    local ok, _name, rawInstanceType, rawDifficultyID, _difficultyName, _maxPlayers, _dynamicDifficulty, _isDynamic, rawInstanceID =
        pcall(GetInstanceInfo)
    if not ok then
        return nil
    end
    local instanceType = readString(rawInstanceType, 16)
    local difficultyID = readInt(rawDifficultyID, 1, MAX_INT32)
    local instanceID = readInt(rawInstanceID, 1, MAX_INT32)
    if instanceType ~= "party" or difficultyID ~= 8 or not instanceID or not SUPPORTED_INSTANCE_IDS[instanceID] then
        return nil
    end
    return instanceID, difficultyID
end
local function getBuildNumber()
    if type(GetBuildInfo) ~= "function" then
        return nil
    end
    local ok, _version, rawBuild = pcall(GetBuildInfo)
    if not ok then
        return nil
    end
    local build = readString(rawBuild, 32)
    if build and build:match("^%d+$") then
        return build
    end
    return nil
end
local function isEncounterInProgress()
    if type(IsEncounterInProgress) ~= "function" then
        return nil
    end
    local ok, result = pcall(IsEncounterInProgress)
    if not ok or isSecret(result) or type(result) ~= "boolean" then
        return nil
    end
    return result
end
local function getCaptureStore()
    if type(P8BA6426E) ~= "table" or isSecret(P8BA6426E) or type(P8BA6426E.DB) ~= "table" or isSecret(P8BA6426E.DB) then
        return nil
    end
    local store = P8BA6426E.DB.timelinePlannerTrashCapture
    if store == nil then
        store = { schemaVersion = 1, nextRunId = 1, droppedRuns = 0, runs = {} }
        P8BA6426E.DB.timelinePlannerTrashCapture = store
    end
    if
        type(store) ~= "table"
        or isSecret(store)
        or store.schemaVersion ~= 1
        or type(store.runs) ~= "table"
        or isSecret(store.runs)
        or not readInt(store.nextRunId, 1, MAX_INT32)
        or not readInt(store.droppedRuns, 0, MAX_INT32)
        or not isArrayOf(store.runs, MAX_RUNS, isValidRun)
    then
        return nil
    end
    return store
end
local function unregisterAll()
    if not captureFrame then
        return
    end
    if type(captureFrame.UnregisterAllEvents) == "function" then
        pcall(captureFrame.UnregisterAllEvents, captureFrame)
    end
    if type(captureFrame.SetScript) == "function" then
        pcall(captureFrame.SetScript, captureFrame, "OnEvent", nil)
    end
end
local function endRun(endReason)
    local previous = session
    session = nil
    if previous and previous.run then
        pcall(function()
            local endedAt = nowPrecise()
            if endedAt then
                previous.run.endedAt = endedAt
            end
            previous.run.endReason = endReason
        end)
    end
end
local function registerZoneEvents()
    unregisterAll()
    if not captureFrame then
        captureFrame = CreateFrame("Frame")
    end
    for _, event in ipairs(ZONE_EVENTS) do
        captureFrame:RegisterEvent(event)
    end
    captureFrame:SetScript("OnEvent", safeHandleEvent)
end
local function registerCaptureEvents()
    registerZoneEvents()
    for _, event in ipairs(CAPTURE_EVENTS) do
        captureFrame:RegisterEvent(event)
    end
end
stopCapture = function(reason)
    endRun(reason)
    armed = false
    waitingForNextKey = false
    unregisterAll()
end
local function beginRun(instanceId, difficultyId)
    local store = getCaptureStore()
    local startedAt = nowPrecise()
    if not store or not startedAt then
        return false
    end
    while #store.runs >= MAX_RUNS do
        table.remove(store.runs, 1)
        store.droppedRuns = store.droppedRuns + 1
    end
    local run = {
        runId = store.nextRunId,
        instanceId = instanceId,
        difficultyId = difficultyId,
        startedAt = startedAt,
        eventsSeen = 0,
        eventsDropped = 0,
        unitMappingsSeen = 0,
        unitMappingsDropped = 0,
        apiQueriesSkipped = 0,
        events = {},
    }
    local build = getBuildNumber()
    if build then
        run.build = build
    end
    store.nextRunId = store.nextRunId % MAX_INT32 + 1
    store.runs[#store.runs + 1] = run
    local encounterActive = isEncounterInProgress()
    session = {
        run = run,
        instanceId = instanceId,
        difficultyId = difficultyId,
        bossActive = encounterActive ~= false,
        combatGeneration = 0,
        unitSlots = 0,
        nextAppearanceOrdinal = 0,
        byUnit = {},
        ignoredByUnit = {},
    }
    waitingForNextKey = false
    local ok = pcall(registerCaptureEvents)
    if not ok then
        endRun("registration_failed")
        unregisterAll()
        return false
    end
    return true
end
local function newEvent(kind)
    if not session then
        return nil
    end
    local run = session.run
    run.eventsSeen = run.eventsSeen + 1
    if #run.events >= MAX_EVENTS then
        run.eventsDropped = run.eventsDropped + 1
        return nil
    end
    local now = nowPrecise()
    if not now then
        error("采集时钟不可读")
    end
    return {
        sequence = run.eventsSeen,
        kind = kind,
        receivedAt = now - run.startedAt,
        combatGeneration = session.combatGeneration,
        readable = newReadableFlags(),
    }
end
local function hasEventCapacity()
    return session and #session.run.events < MAX_EVENTS
end
local function dropEvent()
    session.run.eventsSeen = session.run.eventsSeen + 1
    session.run.eventsDropped = session.run.eventsDropped + 1
end
local function appendEvent(event)
    session.run.events[#session.run.events + 1] = event
end
local function isNameplateUnit(value)
    if isSecret(value) or type(value) ~= "string" then
        return false
    end
    return value:match("^nameplate%d+$") ~= nil
end
local function parseNpcID(guid)
    local unitType, npcIDText = guid:match("^([^-]+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-")
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end
    return readInt(tonumber(npcIDText), 1, MAX_INT32)
end
local function dropUnitMapping()
    local run = session.run
    run.unitMappingsDropped = run.unitMappingsDropped + 1
    run.apiQueriesSkipped = run.apiQueriesSkipped + 1
    dropEvent()
end
local function mapUnit(unit)
    if session.unitSlots >= MAX_UNIT_SLOTS then
        dropUnitMapping()
        return nil, true
    end
    session.unitSlots = session.unitSlots + 1
    session.run.unitMappingsSeen = session.unitSlots
    local mapping = { isNpc = false, readable = newReadableFlags() }
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or isSecret(guid) or type(guid) ~= "string" then
        session.nextAppearanceOrdinal = session.nextAppearanceOrdinal + 1
        mapping.appearanceOrdinal = session.nextAppearanceOrdinal
        session.byUnit[unit] = mapping
        return mapping
    end
    mapping.readable.unitGuid = true
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or isSecret(isPlayer) or type(isPlayer) ~= "boolean" then
        session.nextAppearanceOrdinal = session.nextAppearanceOrdinal + 1
        mapping.appearanceOrdinal = session.nextAppearanceOrdinal
        session.byUnit[unit] = mapping
        return mapping
    end
    mapping.readable.unitIsPlayer = true
    if isPlayer then
        session.ignoredByUnit[unit] = true
        return nil, false, true
    end
    local npcID = parseNpcID(guid)
    if not npcID then
        session.ignoredByUnit[unit] = true
        return nil, false, true
    end
    session.nextAppearanceOrdinal = session.nextAppearanceOrdinal + 1
    mapping.appearanceOrdinal = session.nextAppearanceOrdinal
    mapping.isNpc = true
    mapping.npcId = npcID
    mapping.readable.npcId = true
    session.byUnit[unit] = mapping
    return mapping
end
local function getUnitMapping(unit)
    if session.ignoredByUnit[unit] then
        return nil, false, true
    end
    local mapping = session.byUnit[unit]
    if mapping then
        return mapping, false
    end
    return mapUnit(unit)
end
local function copyMapping(event, mapping)
    if not mapping then
        return
    end
    event.appearanceOrdinal = mapping.appearanceOrdinal
    event.readable.unitGuid = mapping.readable.unitGuid
    event.readable.unitIsPlayer = mapping.readable.unitIsPlayer
    event.readable.npcId = mapping.readable.npcId
    if mapping.npcId then
        event.npcId = mapping.npcId
    end
end
local function readSpellID(v)
    return readInt(v, 1, MAX_INT32)
end
local function msToRunSeconds(ms, runStartedAt)
    if isSecret(ms) or not isFiniteNumber(ms) or ms < 0 or ms > MAX_UINT32 then
        return nil
    end
    return ms / 1000 - runStartedAt
end
local function fillCastInfo(event, unit, eventName)
    if session.unitSlots >= MAX_UNIT_SLOTS then
        session.run.apiQueriesSkipped = session.run.apiQueriesSkipped + 1
        return
    end
    local ok, _name, _text, _texture, startMS, endMS, _r7, _r8, _r9, _r10
    if eventName == "UNIT_SPELLCAST_CHANNEL_START" then
        ok, _name, _text, _texture, startMS, endMS, _r7, _r8, _r9 = pcall(UnitChannelInfo, unit)
    else
        ok, _name, _text, _texture, startMS, endMS, _r7, _r8, _r9, _r10 = pcall(UnitCastingInfo, unit)
    end
    if not ok then
        return
    end
    local rawSpellID
    if eventName == "UNIT_SPELLCAST_CHANNEL_START" then
        rawSpellID = _r9
    else
        rawSpellID = _r10
    end
    local castStartedAt = msToRunSeconds(startMS, session.run.startedAt)
    local castEndsAt = msToRunSeconds(endMS, session.run.startedAt)
    local castSpellId = readSpellID(rawSpellID)
    if castStartedAt then
        event.castStartedAt = castStartedAt
        event.readable.castStartedAt = true
    end
    if castEndsAt then
        event.castEndsAt = castEndsAt
        event.readable.castEndsAt = true
    end
    if castSpellId then
        event.castSpellId = castSpellId
        event.readable.castSpellId = true
    end
end
local function onNameplateEvent(event, unit)
    if not isNameplateUnit(unit) then
        return
    end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local mapping = session.byUnit[unit]
        local ignored = session.ignoredByUnit[unit]
        session.byUnit[unit] = nil
        session.ignoredByUnit[unit] = nil
        if ignored or not mapping then
            return
        end
        if not hasEventCapacity() then
            dropEvent()
            return
        end
        local record = newEvent("nameplate_removed")
        if not record then
            return
        end
        copyMapping(record, mapping)
        appendEvent(record)
        return
    end
    session.byUnit[unit] = nil
    session.ignoredByUnit[unit] = nil
    if not hasEventCapacity() then
        dropEvent()
        return
    end
    local mapping, dropped, ignored = mapUnit(unit)
    if dropped or ignored then
        return
    end
    local record = newEvent("nameplate_added")
    if not record then
        return
    end
    copyMapping(record, mapping)
    appendEvent(record)
end
local function onSpellcastEvent(event, unit, _, spellID, castBarID)
    if not isNameplateUnit(unit) or session.bossActive then
        return
    end
    if session.ignoredByUnit[unit] then
        return
    end
    if not hasEventCapacity() then
        dropEvent()
        return
    end
    local mapping, dropped, ignored = getUnitMapping(unit)
    if dropped or ignored then
        return
    end
    local record = newEvent(SPELLCAST_KIND[event])
    if not record then
        return
    end
    copyMapping(record, mapping)
    if mapping and mapping.isNpc then
        local validSpellID = readSpellID(spellID)
        if validSpellID then
            record.spellId = validSpellID
            record.readable.eventSpellId = true
        end
        if event == "UNIT_SPELLCAST_START" then
            local validCastBarID = readInt(castBarID, 0, MAX_INT32)
            if validCastBarID then
                record.castBarId = validCastBarID
                record.readable.castBarId = true
            end
        end
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            fillCastInfo(record, unit, event)
        end
    end
    appendEvent(record)
end
handleEvent = function(_, event, ...)
    if not armed then
        return
    end
    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        if session then
            endRun(event == "CHALLENGE_MODE_COMPLETED" and "challenge_completed" or "challenge_reset")
        end
        waitingForNextKey = true
        registerZoneEvents()
        return
    end
    if event == "CHALLENGE_MODE_START" then
        local instanceID, difficultyID = getSupportedInstance()
        if not instanceID then
            return
        end
        if session then
            endRun("map_changed")
        end
        if not beginRun(instanceID, difficultyID) then
            stopCapture("registration_failed")
        end
        return
    end
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        local instanceID, difficultyID = getSupportedInstance()
        if not instanceID then
            if session then
                endRun("left_instance")
            end
            registerZoneEvents()
            return
        end
        if waitingForNextKey then
            return
        end
        if session and (session.instanceId == instanceID and session.difficultyId == difficultyID) then
            return
        end
        if session then
            endRun("map_changed")
        end
        if not beginRun(instanceID, difficultyID) then
            stopCapture("registration_failed")
        end
        return
    end
    if not session then
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        session.combatGeneration = session.combatGeneration % MAX_INT32 + 1
        local record = newEvent("combat_started")
        if record then
            appendEvent(record)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local record = newEvent("combat_ended")
        if record then
            appendEvent(record)
        end
    elseif event == "ENCOUNTER_START" then
        session.bossActive = true
        local record = newEvent("boss_started")
        if record then
            appendEvent(record)
        end
    elseif event == "ENCOUNTER_END" then
        session.bossActive = false
        local record = newEvent("boss_ended")
        if record then
            appendEvent(record)
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        onNameplateEvent(event, ...)
    elseif SPELLCAST_KIND[event] then
        onSpellcastEvent(event, ...)
    end
end
safeHandleEvent = function(frame, event, ...)
    local ok = pcall(handleEvent, frame, event, ...)
    if not ok then
        pcall(stopCapture, "capture_error")
    end
end
local function setArmed(enable)
    if enable ~= true then
        if armed or session then
            stopCapture("disarmed")
        end
        return false
    end
    armed = true
    local instanceID, difficultyID = getSupportedInstance()
    if not instanceID then
        waitingForNextKey = false
        registerZoneEvents()
        return true
    end
    if session and (session.instanceId == instanceID and session.difficultyId == difficultyID) then
        return true
    end
    if session then
        endRun("map_changed")
    end
    if beginRun(instanceID, difficultyID) then
        return true
    end
    stopCapture("registration_failed")
    return false
end
if type(P8BA6426E) == "table" then
    P8BA6426E.SetTimelinePlannerTrashCaptureArmed = function(enable)
        local ok, result = pcall(setArmed, enable)
        if ok then
            return result == true
        end
        pcall(stopCapture, "capture_error")
        return false
    end
end
