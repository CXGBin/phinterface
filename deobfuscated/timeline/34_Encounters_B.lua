--[[
  Encounters_B —— 时间轴规划器：首领时间轴事件 → 技能识别（一批首领）
  原始文件：9bac05.lua（TOC 第 34 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E.TimelinePlannerEncounters = P8BA6426E.TimelinePlannerEncounters or {}
local function createPlanner_3445_15()
    local stage, advancePending = 1, false
    local seenCountBySeconds, stasisEvents = {}, {}
    local GATED_SECONDS = { [12] = true, [8] = true, [4] = true, [16] = true, [40] = true, [6] = true }
    local function resetCounts()
        wipe(seenCountBySeconds)
    end
    local function applyPendingAdvance()
        if advancePending then
            stage, advancePending = stage + 1, false
            resetCounts()
        end
    end
    return {
        Resolve = function(duration, eventID)
            applyPendingAdvance()
            local rounded = math.floor(duration * 10 + 0.5) / 10
            local n = math.floor(rounded + 0.5)
            seenCountBySeconds[n] = (seenCountBySeconds[n] or 0) + 1
            if stage > 1 and (GATED_SECONDS[n] and seenCountBySeconds[n] < 3) then
                return nil, stage
            end
            local mechanic
            if n == 12 or n == 32 then
                mechanic = "toxic_droplets"
            elseif n == 8 or n == 10 or rounded == 51.5 then
                mechanic = "venom_coagulation"
            elseif n == 4 then
                mechanic = "empowering_slam"
            elseif n == 16 or n == 41 then
                mechanic = "unstable_miasma"
            elseif n == 40 or n == 52 then
                mechanic = "blighted_blood"
            elseif n == 6 then
                mechanic = "bloodvenom_injection"
            elseif n == 15 then
                mechanic = "berserk"
            elseif n == 20 then
                mechanic = "vitriolic_stasis"
                stasisEvents[eventID] = true
            end
            return mechanic, stage
        end,
        OnEventClosed = function(eventID, state)
            if not stasisEvents[eventID] then
                return
            end
            stasisEvents[eventID] = nil
            if state == 2 then
                advancePending = true
            end
        end,
    }
end
local function createPlanner_3497_15()
    local stage, seenCountBySeconds, channelGUID = 1, {}, nil
    local function resetCounts()
        wipe(seenCountBySeconds)
    end
    local function batchHasDuration(batch, target)
        for _, entry in ipairs(batch) do
            if entry.duration > target - 0.5 and entry.duration < target + 0.5 then
                return true
            end
        end
        return false
    end
    local function detectStageFromBatch(batch)
        if #batch < 3 then
            return nil
        end
        if batchHasDuration(batch, 60) then
            return 1
        end
        if batchHasDuration(batch, 27) then
            return 2
        end
        if batchHasDuration(batch, 11) then
            return 3
        end
        if batchHasDuration(batch, 16) then
            return 4
        end
    end
    local function readPlainValue(value)
        if issecretvalue(value) then
            return nil
        end
        local valueType = type(value)
        if valueType == "string" then
            return value
        end
        if valueType == "number" and value == value then
            return value
        end
        return nil
    end
    return {
        IsPhaseMarker = function()
            return true
        end,
        PrepareBatch = function(batch)
            local detected = detectStageFromBatch(batch)
            if detected and detected ~= stage then
                stage = detected
                resetCounts()
            end
        end,
        Resolve = function(duration)
            local seconds = math.floor(duration + 0.5)
            local mechanic
            if stage == 1 then
                if seconds == 60 then
                    mechanic = "final_ascension"
                elseif seconds == 20 or seconds == 4 or seconds == 27 or seconds == 23 then
                    mechanic = "throw_junk"
                elseif seconds == 30 then
                    mechanic = "shredding_shards"
                elseif seconds == 10 then
                    mechanic = "blink_nova"
                elseif seconds == 18 or seconds == 16 or seconds == 15 then
                    mechanic = "shell_spin"
                elseif seconds == 5 then
                    mechanic = "icebound_flames"
                elseif seconds == 31 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    mechanic = seenCountBySeconds[seconds] % 2 == 1 and "icebound_flames" or "blink_nova"
                end
            elseif stage == 2 then
                if seconds == 30 then
                    mechanic = "shredding_shards"
                elseif seconds == 2 or seconds == 16 then
                    mechanic = "icebound_flames"
                elseif seconds == 3 then
                    mechanic = "mushroom_toss"
                elseif seconds == 27 or seconds == 4 then
                    mechanic = "throw_junk"
                elseif seconds == 13 then
                    mechanic = "explosive_surprise"
                elseif seconds == 11 or seconds == 17 or seconds == 15 or seconds == 7 then
                    mechanic = "shell_spin"
                elseif seconds == 32 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    local seenCount = seenCountBySeconds[seconds]
                    if seenCount == 1 then
                        mechanic = "mushroom_toss"
                    elseif seenCount == 2 then
                        mechanic = "shell_spin"
                    elseif seenCount == 3 then
                        mechanic = "explosive_surprise"
                    elseif seenCount == 4 then
                        mechanic = "icebound_flames"
                    end
                end
            elseif stage == 3 then
                if seconds == 20 or seconds == 4 or seconds == 27 then
                    mechanic = "throw_junk"
                elseif seconds == 3 or seconds == 32 then
                    mechanic = "mighty_thud"
                elseif seconds == 30 then
                    mechanic = "shredding_shards"
                elseif seconds == 11 or seconds == 5 or seconds == 22 then
                    mechanic = "icebound_flames"
                end
            elseif stage == 4 then
                if seconds == 7 or seconds == 4 or seconds == 11 or seconds == 23 then
                    mechanic = "throw_junk"
                elseif seconds == 30 then
                    mechanic = "shredding_shards"
                elseif seconds == 21 then
                    mechanic = "blink_nova"
                elseif seconds == 2 or seconds == 13 then
                    mechanic = "icebound_flames"
                elseif seconds == 17 or seconds == 16 then
                    mechanic = "shell_spin"
                elseif seconds == 8 then
                    mechanic = "frostfire_volley"
                elseif seconds == 27 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    local seenCount = seenCountBySeconds[seconds]
                    if seenCount == 1 then
                        mechanic = "frostfire_volley"
                    elseif seenCount == 2 then
                        mechanic = "icebound_flames"
                    elseif seenCount == 3 then
                        mechanic = "shell_spin"
                    end
                end
            end
            return mechanic, stage
        end,
        OnUnitEvent = function(event, _, unit, castGUID)
            if unit ~= "boss2" then
                return
            end
            local guid = readPlainValue(castGUID)
            if event == "UNIT_SPELLCAST_CHANNEL_START" then
                channelGUID = guid
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and (guid and guid == channelGUID) then
                channelGUID = nil
                if stage ~= 1 then
                    stage = 1
                    resetCounts()
                end
            end
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[344515] = {
    Create = createPlanner_3445_15,
    countIdentifiableAdds = true,
    mechanicCodes = {
        venom_coagulation = 1,
        toxic_droplets = 2,
        empowering_slam = 3,
        bloodvenom_injection = 4,
        blighted_blood = 5,
        unstable_miasma = 6,
        vitriolic_stasis = 7,
        berserk = 8,
    },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[349715] = {
    Create = createPlanner_3497_15,
    batchSeconds = 0.1,
    countIdentifiableAdds = true,
    mechanicCodes = {
        final_ascension = 1,
        blink_nova = 2,
        icebound_flames = 3,
        shredding_shards = 4,
        frostfire_volley = 5,
        shell_spin = 6,
        mighty_thud = 7,
        throw_junk = 8,
        mushroom_toss = 9,
        explosive_surprise = 10,
    },
    unitEvents = { "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" },
    unitEventUnits = { UNIT_SPELLCAST_CHANNEL_START = { "boss2" }, UNIT_SPELLCAST_CHANNEL_STOP = { "boss2" } },
}
