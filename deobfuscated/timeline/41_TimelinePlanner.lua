--[[
  TimelinePlanner —— 时间轴规划器引擎：监听 ENCOUNTER_TIMELINE_* 事件，识别技能后以时间轴记录写入像素条
  原始文件：39d512.lua（TOC 第 41 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
-- 时间轴记录格式：[魔数, 序号*2, 战斗范围(首领ID*100+难度), 代数, 事件ID, 机制字(机制*65536+阶段*4096+次数), 状态字(状态*8192+剩余十分之一秒+1)]
local TIMELINE_MAGIC = 3260648
local MAX_U24 = 16777215
local MAX_SEQUENCE = 8388607
local MAX_QUEUE = 32
local MIN_PUBLISH_INTERVAL = 0.15
local STATE_MULTIPLIER = 8192
local MECHANIC_MULTIPLIER = 65536
local STAGE_MULTIPLIER = 4096
local STATE_ACTIVE = 0
local STATE_PAUSED = 1
local STATE_FINISHED = 2
local STATE_CANCELED = 3
local STATE_REMOVED = 4
local STATE_RESET = 5
local encounterFrame = CreateFrame("Frame")
local timelineFrame = CreateFrame("Frame")
local running = false
local manuallyArmed = false
local hasSpec, disarmed = false, false
local currentSpecID = nil
local generation = 0
local sequenceCounter = 0
local encounterScope = nil
local encounterDef = nil
local planner = nil
local occurrenceByMechanic = {}
local seenEventIDs = {}
local trackedByEventID = {}
local publishQueue = {}
local lastPublished = nil
local lastPublishedAt = 0
local pendingBatch, pendingBatchByEventID = {}, {}
local batchDeadline = nil
local captureRun = nil
local MAX_CAPTURE_RUNS = 3
local MAX_CAPTURE_EVENTS = 1024
local TIMELINE_EVENTS = {
    "ENCOUNTER_TIMELINE_EVENT_ADDED",
    "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",
    "ENCOUNTER_TIMELINE_EVENT_REMOVED",
    "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED",
}
local function isFinite(n)
    return n == n and (n ~= math.huge and n ~= -math.huge)
end
local function isSecret(v)
    if type(issecretvalue) ~= "function" then
        return true
    end
    local ok, result = pcall(issecretvalue, v)
    return not ok or result == true
end
local function readInt(value, minValue, maxValue)
    if
        isSecret(value)
        or type(value) ~= "number"
        or not isFinite(value)
        or value % 1 ~= 0
        or value < minValue
        or (maxValue and value > maxValue)
    then
        return nil
    end
    return value
end
local function readSeconds(value)
    if isSecret(value) or type(value) ~= "number" or not isFinite(value) or value < 0 or value > 600 then
        return nil
    end
    return value
end
local function nowPrecise()
    local clockFn = type(GetTimePreciseSec) == "function" and GetTimePreciseSec or GetTime
    if type(clockFn) ~= "function" then
        return 0
    end
    local ok, result = pcall(clockFn)
    if ok and (not isSecret(result) and (type(result) == "number" and (isFinite(result) and result >= 0))) then
        return result
    end
    return 0
end
local function getRemaining(record, now)
    if record.state == STATE_ACTIVE then
        return math.max(0, record.remaining - math.max(0, now - record.observedAt))
    end
    return math.max(0, record.remaining)
end
local function safeCapture(func, ...)
    local ok = pcall(func, ...)
    if not ok then
        local run = captureRun
        captureRun = nil
        if run then
            pcall(function()
                run.captureFailed = true
            end)
        end
        if not running then
            pcall(timelineFrame.UnregisterAllEvents, timelineFrame)
        end
    end
end
local function beginCaptureRun(encounterId, difficultyId, observationOnly)
    if type(P8BA6426E.DB) ~= "table" then
        return
    end
    local capture = P8BA6426E.DB.timelinePlannerCapture
    if capture == nil then
        capture = { schemaVersion = 1, nextRunId = 1, droppedRuns = 0, runs = {} }
        P8BA6426E.DB.timelinePlannerCapture = capture
    end
    if
        type(capture) ~= "table"
        or capture.schemaVersion ~= 1
        or type(capture.runs) ~= "table"
        or not readInt(capture.nextRunId, 1, MAX_U24)
        or not readInt(capture.droppedRuns, 0, MAX_U24)
    then
        return
    end
    while #capture.runs >= MAX_CAPTURE_RUNS do
        table.remove(capture.runs, 1)
        capture.droppedRuns = capture.droppedRuns + 1
    end
    captureRun = {
        runId = capture.nextRunId,
        encounterId = encounterId,
        difficultyId = difficultyId,
        observationOnly = observationOnly,
        startedAt = nowPrecise(),
        eventsSeen = 0,
        eventsDropped = 0,
        events = {},
    }
    capture.nextRunId = capture.nextRunId % MAX_U24 + 1
    capture.runs[#capture.runs + 1] = captureRun
    if type(GetBuildInfo) == "function" then
        local ok, _version, build = pcall(GetBuildInfo)
        if ok and (not isSecret(build) and (type(build) == "string" and (#build <= 32 and build:match("^%d+$")))) then
            captureRun.build = build
        end
    end
end
local function captureGuard(fn, ...)
    captureRun.eventsSeen = captureRun.eventsSeen + 1
    if #captureRun.events >= MAX_CAPTURE_EVENTS then
        captureRun.eventsDropped = captureRun.eventsDropped + 1
        return
    end
    fn(...)
end
local function appendCaptureEvent(kind, data)
    data.index, data.at, data.kind = captureRun.eventsSeen, nowPrecise(), kind
    captureRun.events[#captureRun.events + 1] = data
end
local function endCaptureRun(reason)
    captureRun.endedAt, captureRun.endReason = nowPrecise(), reason or "stopped"
    captureRun = nil
end
local function captureSurfaceEvent(record, sequence, mechanicWord, stateWord)
    appendCaptureEvent("surface", {
        sequence = sequence,
        encounterScope = encounterScope,
        generation = generation,
        eventId = record.eventID,
        mechanicWord = mechanicWord,
        stateWord = stateWord,
    })
end
-- 把一条已识别的时间轴事件写入像素条（并可选记录到采集日志）
local function publishRecord(record, now)
    sequenceCounter = sequenceCounter % MAX_SEQUENCE + 1
    local sequence = sequenceCounter * 2
    local remainingTenths = math.max(0, math.min(6000, math.floor(getRemaining(record, now) * 10 + 0.5)))
    local mechanicWord = (record.mechanicCode * MECHANIC_MULTIPLIER + record.stageCode * STAGE_MULTIPLIER)
        + record.occurrence
    local stateWord = (record.state * STATE_MULTIPLIER + remainingTenths) + 1
    if P8BA6426E.FontPixelRoute then
        P8BA6426E.FontPixelRoute.RenderTimelineRecord(
            TIMELINE_MAGIC,
            sequence,
            encounterScope,
            generation,
            record.eventID,
            mechanicWord,
            stateWord
        )
    end
    lastPublished = record
    lastPublishedAt = now
    if captureRun then
        safeCapture(captureGuard, captureSurfaceEvent, record, sequence, mechanicWord, stateWord)
    end
end
local function dropQueuedEvent(eventID)
    if eventID <= 0 then
        return
    end
    for i = #publishQueue, 1, -1 do
        if publishQueue[i].eventID == eventID then
            table.remove(publishQueue, i)
        end
    end
end
local onPlannerUpdate, flushBatch, stopPlanner
local function updateOnUpdateHook()
    if #publishQueue > 0 or #pendingBatch > 0 then
        timelineFrame:SetScript("OnUpdate", onPlannerUpdate)
    else
        timelineFrame:SetScript("OnUpdate", nil)
    end
end
onPlannerUpdate = function()
    local now = nowPrecise()
    if batchDeadline and now >= batchDeadline then
        local ok = pcall(flushBatch)
        if not ok then
            stopPlanner()
            return
        end
    end
    if not running or #publishQueue == 0 then
        updateOnUpdateHook()
        return
    end
    if now - lastPublishedAt < MIN_PUBLISH_INTERVAL then
        return
    end
    publishRecord(table.remove(publishQueue, 1), now)
    updateOnUpdateHook()
end
local function enqueuePublish(record, urgent)
    local observedAt = nowPrecise()
    if record.state == STATE_RESET then
        wipe(publishQueue)
    else
        dropQueuedEvent(record.eventID)
    end
    if #publishQueue >= MAX_QUEUE then
        wipe(publishQueue)
        wipe(trackedByEventID)
        generation = generation % MAX_U24 + 1
        publishRecord(
            {
                eventID = 0,
                mechanicCode = 0,
                stageCode = 0,
                occurrence = 0,
                state = STATE_RESET,
                remaining = 0,
                observedAt = observedAt,
            },
            observedAt
        )
        updateOnUpdateHook()
        return
    end
    local recentlyPublished = lastPublished ~= nil and observedAt - lastPublishedAt < MIN_PUBLISH_INTERVAL
    if urgent then
        if record.state == STATE_RESET then
            publishRecord(record, observedAt)
            updateOnUpdateHook()
            return
        end
        if recentlyPublished and lastPublished.state >= STATE_FINISHED then
            table.insert(publishQueue, 1, record)
            updateOnUpdateHook()
            return
        end
        if recentlyPublished and (lastPublished.eventID ~= record.eventID and lastPublished.state <= STATE_PAUSED) then
            dropQueuedEvent(lastPublished.eventID)
            table.insert(publishQueue, 1, lastPublished)
        end
        publishRecord(record, observedAt)
        updateOnUpdateHook()
        return
    end
    if not recentlyPublished and #publishQueue == 0 then
        publishRecord(record, observedAt)
        updateOnUpdateHook()
        return
    end
    table.insert(publishQueue, record)
    updateOnUpdateHook()
end
local function publishTracked(tracked, state, remaining, urgent, observedAt)
    enqueuePublish({
        eventID = tracked.eventID,
        mechanicCode = encounterDef.mechanicCodes[tracked.mechanicKey],
        stageCode = tracked.stageCode,
        occurrence = tracked.occurrence,
        state = state,
        remaining = remaining,
        observedAt = observedAt or nowPrecise(),
    }, urgent)
end
local function publishReset()
    enqueuePublish(
        {
            eventID = 0,
            mechanicCode = 0,
            stageCode = 0,
            occurrence = 0,
            state = STATE_RESET,
            remaining = 0,
            observedAt = nowPrecise(),
        },
        true
    )
end
local function readEventInfo(info)
    local ok, rawID = pcall(function()
        return info.id
    end)
    local ok2, rawSource = pcall(function()
        return info.source
    end)
    local ok3, rawDuration = pcall(function()
        return info.duration
    end)
    if not ok or not ok2 or not ok3 then
        return nil
    end
    local eventID = readInt(rawID, 1, MAX_U24)
    local source = readInt(rawSource, 0, 2)
    local duration = readSeconds(rawDuration)
    if not eventID or source ~= 0 or not duration then
        return nil
    end
    return eventID, duration
end
local function getEventState(eventID)
    if type(C_EncounterTimeline) ~= "table" or type(C_EncounterTimeline.GetEventState) ~= "function" then
        return nil
    end
    local ok, result = pcall(C_EncounterTimeline.GetEventState, eventID)
    return ok and readInt(result, STATE_ACTIVE, STATE_CANCELED) or nil
end
local function getEventRemaining(eventID)
    if type(C_EncounterTimeline) ~= "table" or type(C_EncounterTimeline.GetEventTimeRemaining) ~= "function" then
        return nil
    end
    local ok, result = pcall(C_EncounterTimeline.GetEventTimeRemaining, eventID)
    return ok and readSeconds(result) or nil
end
local function getEventStateAndRemaining(eventID)
    local state = getEventState(eventID)
    if state == nil then
        return nil
    end
    if state >= STATE_FINISHED then
        return state, 0
    end
    local remaining = getEventRemaining(eventID)
    return state, remaining
end
local function captureRawEvent(event, ...)
    local payload = ...
    local data, kind = {}, nil
    if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        kind = "added"
        local ok, rawID = pcall(function()
            return payload.id
        end)
        local ok2, rawSource = pcall(function()
            return payload.source
        end)
        local ok3, rawDuration = pcall(function()
            return payload.duration
        end)
        local ok4, rawSpellID = pcall(function()
            return payload.spellID
        end)
        data.eventId = ok and readInt(rawID, 1, MAX_U24) or nil
        data.source = ok2 and readInt(rawSource, 0, 2) or nil
        data.duration = ok3 and readSeconds(rawDuration) or nil
        data.spellId = ok4 and readInt(rawSpellID, 1, MAX_U24) or nil
        if data.eventId and data.source == 0 then
            data.state = getEventState(data.eventId)
            data.remaining = getEventRemaining(data.eventId)
        end
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        kind, data.eventId = "state_changed", readInt(payload, 1, MAX_U24)
        if data.eventId then
            data.state = getEventState(data.eventId)
            if data.state and data.state < STATE_FINISHED then
                data.remaining = getEventRemaining(data.eventId)
            end
        end
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        kind, data.eventId = "removed", readInt(payload, 1, MAX_U24)
    elseif event == "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED" then
        kind = "view_reset"
    else
        kind, data.event = "unit_event", event
    end
    appendCaptureEvent(kind, data)
end
local function captureResolvedEvent(event, mechanicKey, stage, occurrence, publish)
    appendCaptureEvent("resolved", {
        eventId = event.eventID,
        duration = event.duration,
        mechanicKey = mechanicKey,
        stage = stage,
        occurrence = occurrence,
        publishRequested = mechanicKey ~= nil and publish ~= false,
    })
end
local function nextOccurrence(mechanicKey)
    occurrenceByMechanic[mechanicKey] = (occurrenceByMechanic[mechanicKey] or 0) + 1
    return occurrenceByMechanic[mechanicKey]
end
local function closeTracked(tracked)
    if tracked.state < STATE_FINISHED then
        publishTracked(tracked, STATE_REMOVED, 0, true)
    end
    trackedByEventID[tracked.eventID] = nil
end
-- 调用首领规划器 Resolve(持续时间, 事件ID, 时间, 状态) 识别机制，再发布
local function resolveAndPublish(event, publish)
    local mechanicKey, stageCode, replacesEventID =
        planner.Resolve(event.duration, event.eventID, event.observedAt, event.state)
    if not mechanicKey then
        if captureRun then
            safeCapture(captureGuard, captureResolvedEvent, event, nil, stageCode, nil, false)
        end
        return
    end
    local previous = replacesEventID and trackedByEventID[replacesEventID]
    if
        previous
        and (
            previous.eventID ~= event.eventID
            and (previous.mechanicKey == mechanicKey and previous.state <= STATE_PAUSED)
        )
    then
        closeTracked(previous)
    end
    local tracked = {
        eventID = event.eventID,
        mechanicKey = mechanicKey,
        stageCode = stageCode,
        occurrence = nextOccurrence(mechanicKey),
        state = event.state,
    }
    if captureRun then
        safeCapture(captureGuard, captureResolvedEvent, event, mechanicKey, stageCode, tracked.occurrence, publish)
    end
    if publish == false then
        return
    end
    if not event.removed then
        trackedByEventID[tracked.eventID] = tracked
    end
    publishTracked(tracked, event.state, event.remaining, event.state >= STATE_FINISHED, event.observedAt)
end
flushBatch = function(publish)
    if #pendingBatch == 0 then
        return
    end
    local batch = pendingBatch
    pendingBatch, pendingBatchByEventID, batchDeadline = {}, {}, nil
    planner.PrepareBatch(batch)
    for _, event in ipairs(batch) do
        resolveAndPublish(event, publish ~= false and not event.identityOnly)
    end
end
local function addToBatch(event)
    local observedAt = event.observedAt or nowPrecise()
    if batchDeadline and observedAt >= batchDeadline then
        flushBatch()
    end
    if #pendingBatch >= MAX_QUEUE then
        stopPlanner()
        return
    end
    pendingBatch[#pendingBatch + 1] = event
    pendingBatchByEventID[event.eventID] = event
    batchDeadline = batchDeadline or observedAt + encounterDef.batchSeconds
    updateOnUpdateHook()
end
local function onEventAdded(info)
    local eventID, duration = readEventInfo(info)
    if not eventID or seenEventIDs[eventID] then
        return
    end
    local state, remaining = getEventStateAndRemaining(eventID)
    if state == nil or remaining == nil or state >= STATE_FINISHED then
        if encounterDef.batchSeconds and (planner.IsPhaseMarker and planner.IsPhaseMarker(duration)) then
            seenEventIDs[eventID] = true
            addToBatch({ eventID = eventID, duration = duration, identityOnly = true, observedAt = nowPrecise() })
        elseif encounterDef.countIdentifiableAdds then
            seenEventIDs[eventID] = true
            resolveAndPublish(
                { eventID = eventID, duration = duration, state = state, observedAt = nowPrecise() },
                false
            )
            if state and (state >= STATE_FINISHED and planner.OnEventClosed) then
                planner.OnEventClosed(eventID, state, "added")
            end
        end
        return
    end
    seenEventIDs[eventID] = true
    local observedAt = nowPrecise()
    local event =
        { eventID = eventID, duration = duration, state = state, remaining = remaining, observedAt = observedAt }
    if encounterDef.batchSeconds then
        addToBatch(event)
        return
    end
    resolveAndPublish(event)
end
local function onEventStateChanged(rawEventID)
    local eventID = readInt(rawEventID, 1, MAX_U24)
    local state
    if eventID and planner.OnEventClosed then
        state = getEventState(eventID)
        if state and state >= STATE_FINISHED then
            planner.OnEventClosed(eventID, state, "state_changed")
        end
    end
    local batched = eventID and pendingBatchByEventID[eventID] or nil
    if batched then
        if batched.identityOnly or batched.removed or batched.state >= STATE_FINISHED then
            return
        end
        if not planner.OnEventClosed then
            state = getEventState(eventID)
        end
        local remaining = 0
        if state and state < STATE_FINISHED then
            remaining = getEventRemaining(eventID)
        end
        if state == nil or remaining == nil then
            state, remaining, batched.removed = STATE_REMOVED, 0, true
        end
        batched.state, batched.remaining, batched.observedAt = state, remaining, nowPrecise()
        return
    end
    local tracked = eventID and trackedByEventID[eventID] or nil
    if not tracked then
        return
    end
    if not planner.OnEventClosed then
        state = getEventState(eventID)
    end
    if state == nil then
        closeTracked(tracked)
        return
    end
    local remaining = 0
    if state < STATE_FINISHED then
        remaining = getEventRemaining(eventID)
        if remaining == nil then
            closeTracked(tracked)
            return
        end
    end
    tracked.state = state
    publishTracked(tracked, state, remaining, true)
end
local function onEventRemoved(rawEventID)
    local eventID = readInt(rawEventID, 1, MAX_U24)
    if eventID and planner.OnEventClosed then
        planner.OnEventClosed(eventID, STATE_REMOVED, "removed")
    end
    local batched = eventID and pendingBatchByEventID[eventID] or nil
    if batched then
        if batched.identityOnly then
            return
        end
        batched.removed = true
        if batched.state < STATE_FINISHED then
            batched.state, batched.remaining, batched.observedAt = STATE_REMOVED, 0, nowPrecise()
        end
        return
    end
    local tracked = eventID and trackedByEventID[eventID] or nil
    if not tracked then
        return
    end
    if tracked.state < STATE_FINISHED then
        publishTracked(tracked, STATE_REMOVED, 0, true)
    end
    trackedByEventID[eventID] = nil
end
local function registerTimelineEvents()
    for _, event in ipairs(TIMELINE_EVENTS) do
        timelineFrame:RegisterEvent(event)
    end
    if encounterDef then
        for _, unitEvent in ipairs(encounterDef.unitEvents) do
            local units = encounterDef.unitEventUnits and encounterDef.unitEventUnits[unitEvent]
            if units then
                timelineFrame:RegisterUnitEvent(unitEvent, unpack(units))
            else
                timelineFrame:RegisterUnitEvent(unitEvent, "boss1")
            end
        end
    end
end
stopPlanner = function(reason)
    if captureRun then
        safeCapture(endCaptureRun, reason)
    end
    running = false
    timelineFrame:UnregisterAllEvents()
    timelineFrame:SetScript("OnUpdate", nil)
    wipe(trackedByEventID)
    wipe(occurrenceByMechanic)
    wipe(seenEventIDs)
    wipe(publishQueue)
    wipe(pendingBatch)
    wipe(pendingBatchByEventID)
    batchDeadline = nil
    lastPublished = nil
    lastPublishedAt = 0
    encounterScope, encounterDef, planner = nil, nil, nil
    if P8BA6426E.FontPixelRoute then
        P8BA6426E.FontPixelRoute.InvalidateTimelineRecord()
    end
end
-- 进入首领战：按 首领ID*100+难度 查找规划器，开始监听时间轴事件
local function startEncounter(encounterID, difficultyID)
    stopPlanner("replaced")
    local scope = encounterID * 100 + difficultyID
    local def = P8BA6426E.TimelinePlannerEncounters[scope]
    safeCapture(beginCaptureRun, encounterID, difficultyID, def == nil)
    if not def then
        if captureRun then
            registerTimelineEvents()
        end
        return
    end
    encounterScope, encounterDef = scope, def
    planner = def.Create()
    generation = generation % MAX_U24 + 1
    running = true
    registerTimelineEvents()
    publishReset()
end
local function dispatchTimelineEvent(event, ...)
    if not running then
        return
    end
    if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        onEventAdded(...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        onEventStateChanged(...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        onEventRemoved(...)
    elseif event == "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED" then
        flushBatch(false)
        wipe(trackedByEventID)
        generation = generation % MAX_U24 + 1
        publishReset()
    elseif planner.OnUnitEvent then
        planner.OnUnitEvent(event, nowPrecise(), ...)
    end
end
encounterFrame:SetScript("OnEvent", function(_, event, ...)
    if not manuallyArmed and not (hasSpec and not disarmed) then
        return
    end
    if event == "ENCOUNTER_START" then
        local rawEncounterID, _encounterName, rawDifficultyID = ...
        local encounterID = readInt(rawEncounterID, 1, 10000)
        local difficultyID = readInt(rawDifficultyID, 1, 99)
        if
            not manuallyArmed
            and not (
                encounterID and (difficultyID and P8BA6426E.TimelinePlannerEncounters[encounterID * 100 + difficultyID])
            )
        then
            stopPlanner("outside_catalog")
            return
        end
        if encounterID and difficultyID then
            local ok = pcall(startEncounter, encounterID, difficultyID)
            if not ok then
                stopPlanner("start_error")
            end
        else
            stopPlanner("invalid_start")
        end
    elseif event == "ENCOUNTER_END" then
        stopPlanner("encounter_end")
    end
end)
local function refreshEncounterRegistration()
    encounterFrame:UnregisterAllEvents()
    if manuallyArmed or (hasSpec and not disarmed) then
        encounterFrame:RegisterEvent("ENCOUNTER_START")
        encounterFrame:RegisterEvent("ENCOUNTER_END")
    end
end
-- 手动武装/解除时间轴规划器（默认只在已知专精下自动启用）
function P8BA6426E.SetTimelinePlannerArmed(armed)
    local isArmed = armed == true
    manuallyArmed = isArmed
    disarmed = not isArmed
    refreshEncounterRegistration()
    if not manuallyArmed then
        stopPlanner("disarmed")
    end
    return manuallyArmed
end
local specFrame = CreateFrame("Frame")
local function onSpecUpdate()
    local ok, result = pcall(function()
        return GetSpecializationInfo(GetSpecialization())
    end)
    local specID = ok and readInt(result, 1, 10000) or nil
    if specID ~= currentSpecID then
        stopPlanner("spec_changed")
    end
    currentSpecID, hasSpec = specID, specID ~= nil
    refreshEncounterRegistration()
end
specFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then
        return
    end
    onSpecUpdate()
end)
onSpecUpdate()
timelineFrame:SetScript("OnEvent", function(_, event, ...)
    if captureRun then
        safeCapture(captureGuard, captureRawEvent, event, ...)
    end
    local ok = pcall(dispatchTimelineEvent, event, ...)
    if not ok then
        stopPlanner("event_error")
    end
end)
