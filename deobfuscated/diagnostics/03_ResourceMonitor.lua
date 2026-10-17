--[[
  ResourceMonitor —— 资源监控：脱战时每 30 秒采样本插件内存/CPU，写入 SavedVariables 供导出诊断
  原始文件：5205cd.lua（TOC 第 3 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local addonName = ...
local addon = _G.P8BA6426E
local SAMPLE_INTERVAL = 30
local MAX_SAMPLES = 60
local samples = {}
local sequence = 0
local startedAt
local sampleTicker
local sampling = false
local loggingOut = false
local function validNumber(value)
    local ok, result = pcall(function()
        if type(issecretvalue) == "function" and issecretvalue(value) then
            return false
        end
        return type(value) == "number" and (value == value and (value >= 0 and value < math.huge))
    end)
    if ok and result then
        return value
    end
end
local function readMetric(func, ...)
    if type(func) ~= "function" then
        return nil, "unavailable"
    end
    local ok, result = pcall(func, ...)
    if not ok then
        return nil, "error"
    end
    result = validNumber(result)
    if result == nil then
        return nil, "error"
    end
    return result, "ok"
end
local function jsonNumber(n)
    return (string.format("%.17g", n)):gsub(",", ".")
end
local function sampleJSON(sample)
    local parts = {
        '{"sequence":',
        jsonNumber(sample.sequence),
        ',"sampledAt":',
        jsonNumber(sample.sampledAt),
        ',"uptimeSeconds":',
        jsonNumber(sample.uptimeSeconds),
        ',"memoryState":"',
        sample.memoryState,
        '"',
        ',"profilerState":"',
        sample.profilerState,
        '"',
    }
    if sample.inCombat ~= nil then
        parts[#parts + 1] = ',"inCombat":'
        parts[#parts + 1] = sample.inCombat and "true" or "false"
    end
    for _, field in ipairs({ "memoryKiB", "cpuSessionAverageMs", "cpuRecentAverageMs", "cpuPeakMs" }) do
        if sample[field] ~= nil then
            parts[#parts + 1] = ',"' .. (field .. '":')
            parts[#parts + 1] = jsonNumber(sample[field])
        end
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end
local function buildSnapshotJSON()
    local parts = {
        '{"schemaVersion":1,"scope":"wow_addon_only","sampleIntervalSeconds":30',
        ',"samplingPolicy":"out_of_combat_only"',
        ',"maxSamples":60,"startedAt":',
        jsonNumber(startedAt),
        ',"samples":[',
    }
    for i, sample in ipairs(samples) do
        if i > 1 then
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = sampleJSON(sample)
    end
    parts[#parts + 1] = "]"
    local diagnostics = _G.P8BA6426E and _G.P8BA6426E.LogicDiagnostics
    if diagnostics and type(diagnostics.AttachSnapshotJSON) == "function" then
        pcall(diagnostics.AttachSnapshotJSON, parts)
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end
local function saveLuaResourceSnapshot()
    if type(addon.DB) == "table" then
        addon.DB.luaResourceSnapshot = buildSnapshotJSON()
    end
end
if addon ~= nil then
    addon.SaveLuaResourceSnapshot = saveLuaResourceSnapshot
end
local function sampleMemory(sample)
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
        sample.memoryState = "unavailable"
        return
    end
    local ok = pcall(UpdateAddOnMemoryUsage)
    if not ok then
        sample.memoryState = "error"
        return
    end
    sample.memoryKiB, sample.memoryState = readMetric(GetAddOnMemoryUsage, addonName)
end
local function sampleCPU(sample)
    local profilerAPI = C_AddOnProfiler
    local metricEnum = Enum and Enum.AddOnProfilerMetric
    if
        type(profilerAPI) ~= "table"
        or type(profilerAPI.IsEnabled) ~= "function"
        or type(profilerAPI.GetAddOnMetric) ~= "function"
        or type(metricEnum) ~= "table"
        or metricEnum.SessionAverageTime == nil
        or metricEnum.RecentAverageTime == nil
        or metricEnum.PeakTime == nil
    then
        sample.profilerState = "unavailable"
        return
    end
    local ok, result = pcall(function()
        local enabledState = profilerAPI.IsEnabled()
        if enabledState == true then
            return true
        end
        if enabledState == false then
            return false
        end
    end)
    if not ok then
        sample.profilerState = "error"
        return
    end
    if result == false then
        sample.profilerState = "disabled"
        return
    end
    if result ~= true then
        sample.profilerState = "error"
        return
    end
    sample.profilerState = "ok"
    local metrics = {
        { "cpuSessionAverageMs", metricEnum.SessionAverageTime },
        { "cpuRecentAverageMs", metricEnum.RecentAverageTime },
        { "cpuPeakMs", metricEnum.PeakTime },
    }
    for _, metric in ipairs(metrics) do
        local metricValue, status = readMetric(profilerAPI.GetAddOnMetric, addonName, metric[2])
        if metricValue ~= nil then
            sample[metric[1]] = metricValue
        end
        if status ~= "ok" then
            sample.profilerState = "error"
        end
    end
end
local function consumeFaultsDirty()
    local logicDiagnostics = addon and addon.LogicDiagnostics
    if logicDiagnostics and type(logicDiagnostics.ConsumeFaultsDirty) == "function" then
        return logicDiagnostics.ConsumeFaultsDirty()
    end
    return false
end
local function takeSample()
    local ok, result = pcall(function()
        if type(UnitAffectingCombat) ~= "function" then
            return nil
        end
        local inCombat = UnitAffectingCombat("player")
        if inCombat == true then
            return true
        end
        if inCombat == false then
            return false
        end
    end)
    if not ok or result ~= false then
        if consumeFaultsDirty() then
            saveLuaResourceSnapshot()
        end
        return
    end
    local sampledAt = readMetric(time)
    local uptimeSeconds = readMetric(GetTime)
    if sampledAt == nil or uptimeSeconds == nil then
        return
    end
    if startedAt == nil then
        startedAt = sampledAt
    end
    local sample = { sequence = sequence + 1, sampledAt = sampledAt, uptimeSeconds = uptimeSeconds, inCombat = false }
    sampleMemory(sample)
    sampleCPU(sample)
    samples[#samples + 1] = sample
    if #samples > MAX_SAMPLES then
        table.remove(samples, 1)
    end
    sequence = sample.sequence
    consumeFaultsDirty()
    saveLuaResourceSnapshot()
end
local function safeTakeSample()
    pcall(takeSample)
end
local function startSampling()
    if sampling or loggingOut or type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    sampling = true
    samples = {}
    sequence = 0
    startedAt = readMetric(time)
    local ok, ticker = pcall(C_Timer.NewTicker, SAMPLE_INTERVAL, safeTakeSample)
    if ok and ticker ~= nil then
        sampleTicker = ticker
    else
        sampling = false
    end
end
local lifecycleFrame = CreateFrame("Frame")
lifecycleFrame:RegisterEvent("PLAYER_LOGIN")
lifecycleFrame:RegisterEvent("PLAYER_LOGOUT")
lifecycleFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        loggingOut = false
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            pcall(C_Timer.After, 0, startSampling)
        end
    elseif event == "PLAYER_LOGOUT" then
        loggingOut = true
        if sampling then
            safeTakeSample()
        end
        sampling = false
        if sampleTicker and type(sampleTicker.Cancel) == "function" then
            pcall(sampleTicker.Cancel, sampleTicker)
        end
        sampleTicker = nil
    end
end)
if type(IsLoggedIn) == "function" then
    local ok, result = pcall(IsLoggedIn)
    if ok and (result == true and (type(C_Timer) == "table" and type(C_Timer.After) == "function")) then
        pcall(C_Timer.After, 0, startSampling)
    end
end
