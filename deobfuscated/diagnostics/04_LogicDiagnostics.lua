--[[
  LogicDiagnostics —— 逻辑诊断/性能剖析：/pmsprofile 开关，函数钩子计时、渲染故障、受保护 API 错误、插件阻断事件记录并序列化为 JSON
  原始文件：64ed69.lua（TOC 第 4 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local addonName = ...
local addon = _G.P8BA6426E
local logicDiagnostics = {}
addon.LogicDiagnostics = logicDiagnostics
local MAX_OBSERVE_SECONDS = 180
local SAMPLE_INTERVAL_SECONDS = 1
local _UNUSED_LIMIT = 30
local MAX_PROFILE_ROWS = 128
local MAX_SLOW_CALLS = 128
local SLOW_CALL_THRESHOLD_MS = 20
local MAX_RENDER_FAULTS = 32
local PROFILE_SCHEMA_VERSION = 2
local observing = false
local stopReason
local startedAtMs, observeDeadline
local frozenProfileJSON
local currentContext = "unknown"
local moduleName
local observeTicker
local declaredHooks = {}
local surfaceHooks = {}
local profileGroups, profileGroupOrder, profileRowCount = {}, {}, 0
local slowCalls, slowCallCount, slowCallsDropped = {}, 0, 0
local _unusedFaults, renderFaults = {}, {}
local renderFaultsDropped = 0
local faultsDirty = false
local activeMeasurement = nil
local unpackFn = unpack
local function pack(...)
    return { n = select("#", ...), ... }
end
local function safeNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then
        return nil
    end
    if type(value) == "number" and (value == value and (value >= 0 and value < math.huge)) then
        return value
    end
end
local function nowMs()
    if type(debugprofilestop) ~= "function" then
        return nil
    end
    local ok, result = pcall(debugprofilestop)
    if ok then
        return safeNumber(result)
    end
end
local function getProfileGroup(name)
    local entry = profileGroups[name]
    if entry then
        return entry
    end
    if type(name) ~= "string" or #name > 40 or not name:match("^[a-z][a-z0-9_.]*$") then
        return nil
    end
    entry = { name = name, beginName = "b:" .. name, endName = "e:" .. name, rows = {} }
    profileGroups[name], profileGroupOrder[#profileGroupOrder + 1] = entry, entry
    return entry
end
local function getProfileRow(group, context)
    if not group then
        return nil
    end
    local row = group.rows[context]
    if row then
        return row
    end
    if profileRowCount >= MAX_PROFILE_ROWS then
        return nil
    end
    row =
        { key = group.name, context = context, calls = 0, measuredCalls = 0, measurementErrors = 0, nextSampleAt = nil }
    profileRowCount = profileRowCount + 1
    group.rows[context] = row
    return row
end
local function getCurrentContext()
    return activeMeasurement and activeMeasurement.context or currentContext
end
local function recordSlowCall(atMs, key, context, elapsedMs)
    if elapsedMs == nil or elapsedMs < SLOW_CALL_THRESHOLD_MS then
        return
    end
    if slowCallCount >= MAX_SLOW_CALLS then
        slowCallsDropped = slowCallsDropped + 1
        return
    end
    slowCallCount = slowCallCount + 1
    slowCalls[slowCallCount] = { atMs = atMs, module = moduleName, key = key, context = context, elapsedMs = elapsedMs }
end
local function wrapTimed(hook)
    local name, get = hook.name, hook.get
    return function(...)
        local original = hook.original or get()
        local startMs = nowMs()
        if startMs == nil then
            return original(...)
        end
        local results = pack(pcall(original, ...))
        local endMs = nowMs()
        local row = getProfileRow(getProfileGroup(name), getCurrentContext())
        if row then
            row.calls = row.calls + 1
            if endMs ~= nil then
                local elapsedMs = endMs - startMs
                if elapsedMs >= 0 then
                    row.measuredCalls = row.measuredCalls + 1
                    row.elapsedTotalMs = (row.elapsedTotalMs or 0) + elapsedMs
                    row.elapsedMaxMs = math.max(row.elapsedMaxMs or 0, elapsedMs)
                    recordSlowCall(endMs, name, row.context, elapsedMs)
                else
                    row.measurementErrors = row.measurementErrors + 1
                end
            else
                row.measurementErrors = row.measurementErrors + 1
            end
        end
        if not results[1] then
            error(results[2], 0)
        end
        return unpackFn(results, 2, results.n)
    end
end
local function addProfilerMarker(markerName)
    if not activeMeasurement or activeMeasurement.markersFailed then
        return
    end
    local addMeasuredCallEventFn = C_AddOnProfiler and C_AddOnProfiler.AddMeasuredCallEvent
    if type(addMeasuredCallEventFn) ~= "function" or not pcall(addMeasuredCallEventFn, markerName) then
        activeMeasurement.markersFailed = true
    end
end
local function accumulateMetrics(row, elapsedMs, allocatedBytes, deallocatedBytes)
    if not row then
        return
    end
    elapsedMs, allocatedBytes = safeNumber(elapsedMs), safeNumber(allocatedBytes)
    deallocatedBytes = safeNumber(deallocatedBytes)
    if not elapsedMs or not allocatedBytes or not deallocatedBytes then
        return false
    end
    row.measuredCalls = row.measuredCalls + 1
    row.elapsedTotalMs = (row.elapsedTotalMs or 0) + elapsedMs
    row.elapsedMaxMs = math.max(row.elapsedMaxMs or 0, elapsedMs)
    row.allocatedTotalBytes = (row.allocatedTotalBytes or 0) + allocatedBytes
    row.allocatedMaxBytes = math.max(row.allocatedMaxBytes or 0, allocatedBytes)
    row.deallocatedTotalBytes = (row.deallocatedTotalBytes or 0) + deallocatedBytes
    return true
end
local function applyProfilerResult(row, result, context, markersFailed)
    if type(result) ~= "table" then
        error("invalid_profiler_result")
    end
    if not accumulateMetrics(row, result.elapsedMilliseconds, result.allocatedBytes, result.deallocatedBytes) then
        error("invalid_profiler_metrics")
    end
    if markersFailed or type(result.events) ~= "table" then
        return
    end
    local openMarkers = {}
    for _, event in ipairs(result.events) do
        local eventName = type(event) == "table" and event.name
        if type(eventName) == "string" then
            local markerKind, groupName = eventName:match("^([be]):([a-z][a-z0-9_.]*)$")
            if markerKind == "b" and profileGroups[groupName] then
                openMarkers[#openMarkers + 1] = event
            elseif markerKind == "e" and (profileGroups[groupName] and #openMarkers > 0) then
                local beginIndex = #openMarkers
                while beginIndex > 0 and openMarkers[beginIndex].name ~= profileGroups[groupName].beginName do
                    beginIndex = beginIndex - 1
                end
                if beginIndex > 0 then
                    for i = #openMarkers, beginIndex + 1, -1 do
                        local orphanRow = getProfileRow(profileGroups[openMarkers[i].name:sub(3)], context)
                        if orphanRow then
                            orphanRow.measurementErrors = orphanRow.measurementErrors + 1
                        end
                        openMarkers[i] = nil
                    end
                    local beginEvent = openMarkers[beginIndex]
                    openMarkers[beginIndex] = nil
                    local beginElapsed, beginAlloc, beginDealloc =
                        safeNumber(beginEvent.elapsedMilliseconds),
                        safeNumber(beginEvent.allocatedBytes),
                        safeNumber(beginEvent.deallocatedBytes)
                    local endElapsed, endAlloc, endDealloc =
                        safeNumber(event.elapsedMilliseconds),
                        safeNumber(event.allocatedBytes),
                        safeNumber(event.deallocatedBytes)
                    if
                        beginElapsed
                        and (
                            beginAlloc
                            and (
                                beginDealloc
                                and (
                                    endElapsed
                                    and (
                                        endAlloc
                                        and (
                                            endDealloc
                                            and (
                                                endElapsed >= beginElapsed
                                                and (endAlloc >= beginAlloc and endDealloc >= beginDealloc)
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    then
                        accumulateMetrics(
                            getProfileRow(profileGroups[groupName], context),
                            endElapsed - beginElapsed,
                            endAlloc - beginAlloc,
                            endDealloc - beginDealloc
                        )
                    end
                end
            end
        end
    end
    for _, orphan in ipairs(openMarkers) do
        local orphanRow = getProfileRow(profileGroups[orphan.name:sub(3)], context)
        if orphanRow then
            orphanRow.measurementErrors = orphanRow.measurementErrors + 1
        end
    end
end
local function wrapSampled(hook)
    local name, get = hook.name, hook.get
    local group = getProfileGroup(name)
    return function(...)
        local original = hook.original or get()
        local row = getProfileRow(group, getCurrentContext())
        if row then
            row.calls = row.calls + 1
        end
        if activeMeasurement then
            addProfilerMarker(group.beginName)
            return original(...)
        end
        local measureCall = C_AddOnProfiler and C_AddOnProfiler.MeasureCall
        if
            not row
            or type(measureCall) ~= "function"
            or (hook.nextSampleClock ~= nil and (nowMs() or 0) < hook.nextSampleClock)
        then
            return original(...)
        end
        hook.nextSampleClock = (nowMs() or 0) + SAMPLE_INTERVAL_SECONDS * 1000
        local measurement = { arguments = pack(...) }
        local function invokeOriginal()
            measurement.called = true
            local returns = pack(pcall(original, unpackFn(measurement.arguments, 1, measurement.arguments.n)))
            if not returns[1] then
                measurement.businessError = returns[2]
                error(returns[2], 0)
            end
            measurement.returns, measurement.completed = returns, true
            return unpackFn(returns, 2, returns.n)
        end
        local context = getCurrentContext()
        activeMeasurement = measurement
        local ok, profilerResult = pcall(measureCall, invokeOriginal)
        activeMeasurement = nil
        if not ok or not measurement.called or not measurement.completed then
            row.measurementErrors = row.measurementErrors + 1
            if not measurement.called then
                return original(...)
            end
            if not measurement.completed then
                if measurement.businessError ~= nil then
                    error(measurement.businessError, 0)
                end
                error(profilerResult, 0)
            end
        else
            local ok = pcall(applyProfilerResult, row, profilerResult, context, measurement.markersFailed)
            if not ok or measurement.markersFailed then
                row.measurementErrors = row.measurementErrors + 1
            end
        end
        if measurement.completed then
            return unpackFn(measurement.returns, 2, measurement.returns.n)
        end
    end
end
local function installHook(hook)
    local original = hook.get()
    if type(original) ~= "function" then
        return
    end
    hook.original = original
    hook.wrapper = hook.kind == "timed" and wrapTimed(hook) or wrapSampled(hook)
    hook.set(hook.wrapper)
end
local function removeHook(hook)
    if hook.wrapper ~= nil and hook.get() == hook.wrapper then
        hook.set(hook.original)
    end
    hook.wrapper, hook.original, hook.nextSampleClock = nil, nil, nil
end
function logicDiagnostics.Declare(name, kind, get, set)
    if type(name) ~= "string" or type(get) ~= "function" or type(set) ~= "function" then
        return
    end
    for _, hook in ipairs(declaredHooks) do
        if hook.name == name then
            return
        end
    end
    declaredHooks[#declaredHooks + 1] = { name = name, kind = kind, get = get, set = set }
end
local function hookTableMethod(target, methodName, name, kind)
    if type(target) ~= "table" or type(target[methodName]) ~= "function" then
        return nil
    end
    local hook = {
        name = name,
        kind = kind,
        get = function()
            return target[methodName]
        end,
        set = function(fn)
            target[methodName] = fn
        end,
    }
    installHook(hook)
    surfaceHooks[#surfaceHooks + 1] = hook
    return hook
end
function logicDiagnostics.OnSurfaceBuilt(surface)
    if not observing or type(surface) ~= "table" then
        return
    end
    for i = #surfaceHooks, 1, -1 do
        removeHook(surfaceHooks[i])
        surfaceHooks[i] = nil
    end
    if surface.numeric then
        hookTableMethod(surface.numeric, "Refresh", "numeric.refresh", "sampled")
    end
    if surface.readiness then
        hookTableMethod(surface.readiness, "Refresh", "readiness.refresh", "sampled")
    end
    if surface.aura then
        hookTableMethod(surface.aura, "Refresh", "native.presence", "sampled")
        if surface.aura.nameplates then
            hookTableMethod(surface.aura.nameplates, "Refresh", "nameplate.refresh", "sampled")
            hookTableMethod(surface.aura.nameplates, "RefreshVisuals", "nameplate.visual", "sampled")
        end
    end
end
local function jsonNumber(n)
    return (string.format("%.17g", n)):gsub(",", ".")
end
local function jsonString(value)
    return '"'
        .. (
            (tostring(value)):gsub('[%z\1-\31"\\]', function(ch)
                if ch == '"' then
                    return '\\"'
                end
                if ch == "\\" then
                    return "\\\\"
                end
                return string.format("\\u%04x", string.byte(ch))
            end) .. '"'
        )
end
local function sampledEntriesJSON()
    local parts = {}
    for _, group in ipairs(profileGroupOrder) do
        for _, context in ipairs({ "combat", "idle", "unknown" }) do
            local row = group.rows[context]
            if row then
                local json = '{"key":'
                    .. (
                        jsonString(row.key)
                        .. (
                            ',"context":"'
                            .. (
                                context
                                .. (
                                    '"'
                                    .. (
                                        ',"calls":'
                                        .. (
                                            jsonNumber(row.calls)
                                            .. (
                                                ',"measuredCalls":'
                                                .. (
                                                    jsonNumber(row.measuredCalls)
                                                    .. (',"measurementErrors":' .. jsonNumber(row.measurementErrors))
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                for _, field in ipairs({
                    "elapsedTotalMs",
                    "elapsedMaxMs",
                    "allocatedTotalBytes",
                    "allocatedMaxBytes",
                    "deallocatedTotalBytes",
                }) do
                    if row[field] ~= nil then
                        json = json .. (',"' .. (field .. ('":' .. jsonNumber(row[field]))))
                    end
                end
                parts[#parts + 1] = json .. "}"
            end
        end
    end
    return table.concat(parts, ",")
end
local function timedEntriesJSON()
    local timedNames = {}
    for _, hook in ipairs(declaredHooks) do
        if hook.kind == "timed" then
            timedNames[hook.name] = true
        end
    end
    local parts = {}
    for _, group in ipairs(profileGroupOrder) do
        if timedNames[group.name] then
            for _, context in ipairs({ "combat", "idle", "unknown" }) do
                local row = group.rows[context]
                if row then
                    local json = '{"key":'
                        .. (
                            jsonString(row.key)
                            .. (
                                ',"context":"'
                                .. (
                                    context
                                    .. (
                                        '"'
                                        .. (
                                            ',"calls":'
                                            .. (
                                                jsonNumber(row.calls)
                                                .. (',"errors":' .. jsonNumber(row.measurementErrors))
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    for _, field in ipairs({ "elapsedTotalMs", "elapsedMaxMs" }) do
                        if row[field] ~= nil then
                            json = json .. (',"' .. (field .. ('":' .. jsonNumber(row[field]))))
                        end
                    end
                    parts[#parts + 1] = json .. "}"
                end
            end
        end
    end
    return table.concat(parts, ",")
end
local function slowCallsJSON()
    if slowCallCount == 0 and slowCallsDropped == 0 then
        return nil
    end
    local parts = {}
    for i = 1, slowCallCount, 1 do
        local call = slowCalls[i]
        parts[#parts + 1] = '{"atMs":'
            .. (
                jsonNumber(call.atMs)
                .. (
                    ',"module":'
                    .. (
                        jsonString(call.module or "unknown")
                        .. (
                            ',"key":'
                            .. (
                                jsonString(call.key)
                                .. (
                                    ',"context":"'
                                    .. (
                                        call.context
                                        .. ('"' .. (',"elapsedMs":' .. (jsonNumber(call.elapsedMs) .. "}")))
                                    )
                                )
                            )
                        )
                    )
                )
            )
    end
    return '"slowCalls":{"thresholdMs":'
        .. (
            jsonNumber(SLOW_CALL_THRESHOLD_MS)
            .. (
                ',"count":'
                .. (
                    jsonNumber(slowCallCount)
                    .. (
                        ',"dropped":'
                        .. (jsonNumber(slowCallsDropped) .. (',"items":[' .. (table.concat(parts, ",") .. "]}")))
                    )
                )
            )
        )
end
local function buildProfileJSON(reason)
    local snapshotAtMs = nowMs()
    local parts = {
        '{"schemaVersion":',
        jsonNumber(PROFILE_SCHEMA_VERSION),
        ',"state":"',
        observing and "ok" or "stopped",
        '","stopReason":',
        reason ~= nil and jsonString(reason) or "null",
        ',"module":',
        jsonString(moduleName or "unknown"),
        ',"clock":"debugprofilestop"',
        ',"startedAtMs":',
        startedAtMs ~= nil and jsonNumber(startedAtMs) or "null",
        ',"snapshotAtMs":',
        snapshotAtMs ~= nil and jsonNumber(snapshotAtMs) or "null",
        ',"timed":{"unit":"milliseconds_per_call","accounting":"per_call","entries":[',
        timedEntriesJSON(),
        "]}",
        ',"sampled":{"clock":"debugprofilestop"',
        ',"unit":"milliseconds_per_call"',
        ',"memoryUnit":"allocated_bytes_per_call"',
        ',"accounting":"inclusive_do_not_sum"',
        ',"sampleIntervalSeconds":',
        jsonNumber(SAMPLE_INTERVAL_SECONDS),
        ',"groups":[',
        sampledEntriesJSON(),
        "]}",
    }
    local slowJSON = slowCallsJSON()
    if slowJSON then
        parts[#parts + 1] = "," .. slowJSON
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end
function logicDiagnostics.FrozenProfileJSON()
    if frozenProfileJSON == nil and stopReason ~= nil then
        frozenProfileJSON = buildProfileJSON(stopReason)
    end
    return frozenProfileJSON
end
local function renderFaultsJSON()
    if #renderFaults == 0 and renderFaultsDropped == 0 then
        return nil
    end
    local parts = {}
    for _, fault in ipairs(renderFaults) do
        parts[#parts + 1] = '{"stage":'
            .. (
                jsonString(fault.stage)
                .. (
                    ',"category":'
                    .. (
                        jsonString(fault.category)
                        .. (
                            ',"count":'
                            .. (
                                jsonNumber(fault.count)
                                .. (
                                    ',"firstAtMs":'
                                    .. (
                                        jsonNumber(fault.firstAtMs)
                                        .. (
                                            ',"lastAtMs":'
                                            .. (
                                                jsonNumber(fault.lastAtMs)
                                                .. (
                                                    ',"module":'
                                                    .. (
                                                        jsonString(fault.module or "unknown")
                                                        .. (
                                                            ',"recovered":'
                                                            .. ((fault.recovered and "true" or "false") .. "}")
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
    end
    local json = '{"schemaVersion":1,"count":' .. jsonNumber(#renderFaults)
    if renderFaultsDropped > 0 then
        json = json .. (',"overflowDropped":' .. jsonNumber(renderFaultsDropped))
    end
    return json .. (',"items":[' .. (table.concat(parts, ",") .. "]}"))
end
function logicDiagnostics.RenderFaultsJSON()
    return renderFaultsJSON()
end
function logicDiagnostics.RecordRenderFault(stage, category)
    if type(stage) ~= "string" or type(category) ~= "string" then
        return
    end
    local lastAtMs = nowMs() or 0
    local fault
    for _, existing in ipairs(renderFaults) do
        if existing.stage == stage and existing.category == category then
            fault = existing
            break
        end
    end
    if fault == nil then
        if #renderFaults >= MAX_RENDER_FAULTS then
            renderFaultsDropped = renderFaultsDropped + 1
            faultsDirty = true
            return
        end
        fault = {
            stage = stage,
            category = category,
            count = 0,
            firstAtMs = lastAtMs,
            lastAtMs = lastAtMs,
            module = moduleName,
            recovered = false,
        }
        renderFaults[#renderFaults + 1] = fault
    end
    fault.count = fault.count + 1
    fault.lastAtMs = lastAtMs
    fault.recovered = false
    faultsDirty = true
end
function logicDiagnostics.RecordRenderRecovery(stage, category)
    for _, fault in ipairs(renderFaults) do
        if fault.stage == stage and (fault.category == category and not fault.recovered) then
            fault.recovered = true
            fault.lastAtMs = nowMs() or fault.lastAtMs
            faultsDirty = true
            return
        end
    end
end
function logicDiagnostics.SetModuleName(name)
    if type(name) == "string" then
        moduleName = name
    end
end
local MAX_SECRET_API_FAULTS = 16
local MAX_ERROR_LENGTH = 200
local secretApiFaults = {}
function addon.RecordSecretApiFault(api, err)
    if type(api) ~= "string" or api == "" then
        return
    end
    local lastAtMs = nowMs() or 0
    local fault
    for _, existing in ipairs(secretApiFaults) do
        if existing.api == api then
            fault = existing
            break
        end
    end
    if fault == nil then
        if #secretApiFaults >= MAX_SECRET_API_FAULTS then
            return
        end
        fault = { api = api, count = 0, firstAtMs = lastAtMs, lastAtMs = lastAtMs, lastError = "", taintSource = "" }
        secretApiFaults[#secretApiFaults + 1] = fault
    end
    local lastError = tostring(err or "")
    if #lastError > MAX_ERROR_LENGTH then
        local cut = MAX_ERROR_LENGTH + 1
        while cut > 1 do
            local byte = lastError:byte(cut)
            if byte < 128 or byte >= 192 then
                break
            end
            cut = cut - 1
        end
        lastError = lastError:sub(1, cut - 1)
    end
    fault.count = fault.count + 1
    fault.lastAtMs = lastAtMs
    fault.lastError = lastError
    local taintSource = lastError:match("tainted by '([^']+)'")
    if taintSource and taintSource ~= "" then
        fault.taintSource = taintSource
    end
    faultsDirty = true
end
local function secretApiFaultsJSON()
    if #secretApiFaults == 0 then
        return nil
    end
    local parts = {}
    for _, fault in ipairs(secretApiFaults) do
        parts[#parts + 1] = '{"api":'
            .. (
                jsonString(fault.api)
                .. (
                    ',"count":'
                    .. (
                        jsonNumber(fault.count)
                        .. (
                            ',"firstAtMs":'
                            .. (
                                jsonNumber(fault.firstAtMs)
                                .. (
                                    ',"lastAtMs":'
                                    .. (
                                        jsonNumber(fault.lastAtMs)
                                        .. (
                                            ',"lastError":'
                                            .. (
                                                jsonString(fault.lastError)
                                                .. (',"taintSource":' .. (jsonString(fault.taintSource) .. "}"))
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
    end
    return '{"schemaVersion":1,"count":'
        .. (jsonNumber(#secretApiFaults) .. (',"items":[' .. (table.concat(parts, ",") .. "]}")))
end
local MAX_ENABLED_ADDONS = 128
local enabledAddons
local function collectEnabledAddons()
    enabledAddons = {}
    if
        type(C_AddOns) ~= "table"
        or type(C_AddOns.GetNumAddOns) ~= "function"
        or type(C_AddOns.GetAddOnInfo) ~= "function"
    then
        return
    end
    local characterName
    if type(UnitFullName) == "function" then
        local name, realm = UnitFullName("player")
        if type(name) == "string" and name ~= "" then
            characterName = (type(realm) == "string" and realm ~= "") and (name .. ("-" .. realm)) or name
        end
    end
    if characterName == nil and type(UnitName) == "function" then
        characterName = UnitName("player")
    end
    for i = 1, C_AddOns.GetNumAddOns(), 1 do
        if #enabledAddons >= MAX_ENABLED_ADDONS then
            break
        end
        local ok, addonName = pcall(C_AddOns.GetAddOnInfo, i)
        if ok and (type(addonName) == "string" and addonName ~= "") then
            local isEnabled = true
            if characterName and type(C_AddOns.GetAddOnEnableState) == "function" then
                local ok, state = pcall(C_AddOns.GetAddOnEnableState, i, characterName)
                isEnabled = ok and state == 2 or false
            end
            if isEnabled then
                enabledAddons[#enabledAddons + 1] = addonName
            end
        end
    end
end
local function enabledAddonsJSON()
    if type(enabledAddons) ~= "table" or #enabledAddons == 0 then
        return nil
    end
    local parts = {}
    for _, name in ipairs(enabledAddons) do
        parts[#parts + 1] = jsonString(name)
    end
    return "[" .. (table.concat(parts, ",") .. "]")
end
local function conflictGuardJSON()
    local log = type(addon.DB) == "table" and (type(addon.DB.conflictGuardLog) == "table" and addon.DB.conflictGuardLog)
        or nil
    if log == nil or log.lastAddon == nil then
        return nil
    end
    local parts = {}
    parts[#parts + 1] = '"lastAddon":' .. jsonString(log.lastAddon)
    parts[#parts + 1] = '"lastWasLoaded":' .. tostring(log.lastWasLoaded == true)
    if type(log.lastTime) == "number" then
        parts[#parts + 1] = '"lastTime":' .. jsonNumber(log.lastTime)
    end
    return "{" .. (table.concat(parts, ",") .. "}")
end
local function saveResourceSnapshot()
    if type(addon.SaveLuaResourceSnapshot) == "function" then
        pcall(addon.SaveLuaResourceSnapshot)
    end
end
local function statusText()
    if observing then
        local secondsLeft = math.max(0, math.ceil(observeDeadline - (GetTime and GetTime() or observeDeadline)))
        return string.format("%s %d s", addon.L("观测进行中，剩余秒数："), secondsLeft)
    end
    if stopReason ~= nil then
        return addon.L("观测已结束，请执行 /reload 或正常退出游戏后导出诊断包。")
            .. (" reason=" .. tostring(stopReason))
    end
    return addon.L("观测未开启。输入 /pmsprofile on 开始，最长 180 秒。")
end
local function stopObserving(reason)
    if not observing then
        return
    end
    observing = false
    stopReason = reason
    if observeTicker and type(observeTicker.Cancel) == "function" then
        pcall(observeTicker.Cancel, observeTicker)
    end
    observeTicker = nil
    for _, hook in ipairs(declaredHooks) do
        removeHook(hook)
    end
    for i = #surfaceHooks, 1, -1 do
        removeHook(surfaceHooks[i])
        surfaceHooks[i] = nil
    end
    frozenProfileJSON = buildProfileJSON(reason)
    saveResourceSnapshot()
    print(statusText())
end
function logicDiagnostics.Start()
    if observing then
        print(statusText())
        return
    end
    stopReason = nil
    frozenProfileJSON = nil
    profileGroups, profileGroupOrder, profileRowCount = {}, {}, 0
    slowCalls, slowCallCount, slowCallsDropped = {}, 0, 0
    startedAtMs = nowMs()
    if startedAtMs == nil then
        print(addon.L("系统时钟不可用，观测未开启。"))
        return
    end
    if type(GetTime) ~= "function" then
        print(addon.L("游戏时钟不可用，观测未开启。"))
        return
    end
    observeDeadline = GetTime() + MAX_OBSERVE_SECONDS
    observing = true
    for _, hook in ipairs(declaredHooks) do
        installHook(hook)
    end
    local fontPixelRoute = addon.FontPixelRoute
    if fontPixelRoute and type(fontPixelRoute.CurrentSurface) == "function" then
        logicDiagnostics.OnSurfaceBuilt(fontPixelRoute.CurrentSurface())
    end
    if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
        local ok, ticker = pcall(C_Timer.NewTicker, 1, function()
            if observing and GetTime() >= observeDeadline then
                stopObserving("timeout")
            end
        end)
        if ok then
            observeTicker = ticker
        end
    end
    print(addon.L("观测已开始，最长 180 秒。复现问题后输入 /pmsprofile off 停止。"))
end
function logicDiagnostics.StopRequested()
    if not observing then
        print(statusText())
        return
    end
    stopObserving("manual")
end
function logicDiagnostics.IsEnabled()
    return observing
end
SLASH_PMSPROFILE1 = "/pmsprofile"
SlashCmdList.PMSPROFILE = function(msg)
    local cmd = ((((msg or "")):lower()):gsub("^%s+", "")):gsub("%s+$", "")
    if cmd == "on" then
        logicDiagnostics.Start()
    elseif cmd == "off" then
        logicDiagnostics.StopRequested()
    else
        print(statusText())
    end
end
local MAX_ADDON_FAULTS = 16
local MAX_MESSAGE_LENGTH = 200
local addonFaults = {}
local function truncateUtf8(str)
    if #str > MAX_MESSAGE_LENGTH then
        local cut = MAX_MESSAGE_LENGTH + 1
        while cut > 1 do
            local byte = str:byte(cut)
            if byte < 128 or byte >= 192 then
                break
            end
            cut = cut - 1
        end
        str = str:sub(1, cut - 1)
    end
    return str
end
function addon.RecordAddonFault(event, addonArg, funcArg, message)
    if type(event) ~= "string" or event == "" then
        return
    end
    local addon = addonArg or ""
    local func = funcArg or ""
    local key = event .. ("|" .. (addon .. ("|" .. func)))
    local lastAtMs = nowMs() or 0
    local fault
    for _, existing in ipairs(addonFaults) do
        if existing.key == key then
            fault = existing
            break
        end
    end
    if fault == nil then
        if #addonFaults >= MAX_ADDON_FAULTS then
            return
        end
        fault = {
            key = key,
            event = event,
            addon = addon,
            func = func,
            count = 0,
            firstAtMs = lastAtMs,
            lastAtMs = lastAtMs,
            lastMessage = "",
        }
        addonFaults[#addonFaults + 1] = fault
    end
    fault.count = fault.count + 1
    fault.lastAtMs = lastAtMs
    if type(message) == "string" and message ~= "" then
        fault.lastMessage = truncateUtf8(message)
    end
    faultsDirty = true
end
local function addonFaultsJSON()
    if #addonFaults == 0 then
        return nil
    end
    local parts = {}
    for _, fault in ipairs(addonFaults) do
        parts[#parts + 1] = '{"event":'
            .. (
                jsonString(fault.event)
                .. (
                    ',"addon":'
                    .. (
                        jsonString(fault.addon)
                        .. (
                            ',"func":'
                            .. (
                                jsonString(fault.func)
                                .. (
                                    ',"count":'
                                    .. (
                                        jsonNumber(fault.count)
                                        .. (
                                            ',"firstAtMs":'
                                            .. (
                                                jsonNumber(fault.firstAtMs)
                                                .. (
                                                    ',"lastAtMs":'
                                                    .. (
                                                        jsonNumber(fault.lastAtMs)
                                                        .. (',"lastMessage":' .. (jsonString(fault.lastMessage) .. "}"))
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
    end
    return '{"schemaVersion":1,"count":'
        .. (jsonNumber(#addonFaults) .. (',"items":[' .. (table.concat(parts, ",") .. "]}")))
end
function logicDiagnostics.AttachSnapshotJSON(out)
    local profileJSON = logicDiagnostics.FrozenProfileJSON()
    if observing then
        profileJSON = buildProfileJSON(nil)
    end
    if profileJSON ~= nil then
        out[#out + 1] = ',"logicProfile":' .. profileJSON
    end
    local faultsJSON = renderFaultsJSON()
    if faultsJSON ~= nil then
        out[#out + 1] = ',"renderFaults":' .. faultsJSON
    end
    local secretJSON = secretApiFaultsJSON()
    if secretJSON ~= nil then
        out[#out + 1] = ',"secretApiFaults":' .. secretJSON
    end
    local addonJSON = addonFaultsJSON()
    if addonJSON ~= nil then
        out[#out + 1] = ',"addonFaults":' .. addonJSON
    end
    local enabledJSON = enabledAddonsJSON()
    if enabledJSON ~= nil then
        out[#out + 1] = ',"enabledAddons":' .. enabledJSON
    end
    local guardJSON = conflictGuardJSON()
    if guardJSON ~= nil then
        out[#out + 1] = ',"conflictGuard":' .. guardJSON
    end
end
function logicDiagnostics.ConsumeFaultsDirty()
    local wasDirty = faultsDirty
    faultsDirty = false
    return wasDirty
end
local diagnosticsFrame = CreateFrame("Frame")
diagnosticsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
diagnosticsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
diagnosticsFrame:RegisterEvent("PLAYER_LOGOUT")
diagnosticsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
diagnosticsFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
diagnosticsFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
diagnosticsFrame:RegisterEvent("LUA_WARNING")
diagnosticsFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        currentContext = "combat"
    elseif event == "PLAYER_REGEN_ENABLED" then
        currentContext = "idle"
    elseif event == "PLAYER_ENTERING_WORLD" then
        pcall(collectEnabledAddons)
        faultsDirty = true
    elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        local blockedAddon, blockedFunc = ...
        pcall(
            addon.RecordAddonFault,
            event,
            blockedAddon,
            blockedFunc,
            string.format(
                "%s: AddOn '%s' -> protected '%s'",
                event,
                tostring(blockedAddon or "<name>"),
                tostring(blockedFunc or "<func>")
            )
        )
    elseif event == "LUA_WARNING" then
        local warning = ...
        pcall(addon.RecordAddonFault, event, nil, nil, warning)
    elseif event == "PLAYER_LOGOUT" and observing then
        stopObserving("logout")
    end
end)
