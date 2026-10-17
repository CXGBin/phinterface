--[[
  Encounters_F —— 时间轴规划器：首领时间轴事件 → 技能识别（一批首领/地下城）
  原始文件：3cc5aa.lua（TOC 第 38 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E.TimelinePlannerEncounters = P8BA6426E.TimelinePlannerEncounters or {}
local function roundTo(value, digits)
    local scale = 10 ^ digits
    return math.floor(value * scale + 0.5) / scale
end
local function createPlanner_2139_8()
    local sharedTimerCount = 1
    return {
        Resolve = function(duration)
            local seconds = roundTo(duration, 0)
            local mechanic
            if seconds == 5 or (seconds == 25 and sharedTimerCount % 2 == 1) then
                mechanic = "spit_gold"
            elseif seconds == 8 or (seconds == 25 and sharedTimerCount % 2 == 0) then
                mechanic = "tail_thrash"
            elseif seconds == 14 or seconds == 28 then
                mechanic = "serpentine_gust"
            elseif seconds == 54 then
                mechanic = "lucres_call"
            end
            if seconds == 25 then
                sharedTimerCount = sharedTimerCount + 1
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_2142_8()
    local openingPhase, deadlineByEventID, watchedEvents = true, {}, {}
    local function expireDeadlines(now)
        if type(now) ~= "number" then
            return
        end
        for eventID, deadline in pairs(deadlineByEventID) do
            if now >= deadline then
                openingPhase, deadlineByEventID[eventID] = false, nil
            end
        end
    end
    local function nowPrecise()
        if type(GetTimePreciseSec) ~= "function" then
            return nil
        end
        local ok, result = pcall(GetTimePreciseSec)
        return ok and (type(result) == "number" and (result == result and result)) or nil
    end
    return {
        Resolve = function(duration, eventID, observedAt)
            expireDeadlines(observedAt)
            local seconds = roundTo(duration, 0)
            local mechanic
            if seconds == 63 then
                return nil, 1
            elseif (openingPhase and seconds == 5) or (not openingPhase and seconds == 32) then
                mechanic = "drain_fluids"
            elseif (openingPhase and seconds == 20) or (not openingPhase and seconds == 30) then
                mechanic = "burn_corruption"
            elseif (openingPhase and seconds == 30) or (not openingPhase and seconds == 102) then
                mechanic = "awakening_slam"
            elseif seconds == 60 then
                mechanic = "entomb"
                watchedEvents[eventID] = true
                if type(observedAt) == "number" then
                    deadlineByEventID[eventID] = observedAt + 1
                end
            end
            return mechanic, 1
        end,
        OnEventClosed = function(eventID, state, reason)
            if not watchedEvents[eventID] or reason ~= "state_changed" then
                return
            end
            expireDeadlines(nowPrecise())
            if state == 2 then
                openingPhase, deadlineByEventID[eventID] = true, nil
            elseif state == 3 then
                deadlineByEventID[eventID] = nil
            end
            watchedEvents[eventID] = nil
        end,
    }
end
local function createPlanner_2140_8()
    local openingPhase, stage, watchedEvents = true, 1, {}
    return {
        Resolve = function(duration, eventID)
            local tenths = roundTo(duration, 1)
            local mechanic
            if tenths == 8 or tenths == 14.8 then
                mechanic = "whirling_axes"
            elseif tenths == 15 or tenths == 16.5 then
                mechanic = "severing_axe"
            elseif tenths == 5 or (openingPhase and tenths == 20) then
                mechanic = "barrel_through"
            elseif tenths == 14 or tenths == 22 then
                mechanic = "debilitating_backhand"
            elseif tenths == 2 or tenths == 7 then
                mechanic = "arc_lightning"
            elseif tenths == 10 or tenths == 24 or tenths == 24.4 or tenths == 25.2 then
                mechanic = "poison_nova"
            elseif tenths == 20 or tenths == 52.5 then
                mechanic = "call_of_the_elements"
            end
            if mechanic == "barrel_through" then
                if stage == 1 then
                    stage = 2
                end
                watchedEvents[eventID] = true
            elseif mechanic == "arc_lightning" and stage == 2 then
                stage = 3
            end
            return mechanic, stage
        end,
        OnEventClosed = function(eventID, state, reason)
            if watchedEvents[eventID] and (reason == "state_changed" and state == 3) then
                openingPhase = false
            end
            if reason ~= "added" then
                watchedEvents[eventID] = nil
            end
        end,
    }
end
local function createPlanner_2143_8()
    local stage, sharedTimerCount, watchedEvents = 1, 1, {}
    return {
        Resolve = function(duration, eventID)
            local seconds = roundTo(duration, 0)
            local mechanic
            if seconds == 8 or (seconds == 10 and sharedTimerCount % 2 == 1) or seconds == 28 then
                mechanic = "hunting_leap"
            elseif seconds == 14 or (seconds == 10 and sharedTimerCount % 2 == 0) or seconds == 27 then
                mechanic = "deathly_roar"
            elseif seconds == 15 then
                mechanic = "aerial_smash"
            elseif seconds == 23 or seconds == 38 then
                mechanic = "blade_combo"
            elseif (stage == 1 and seconds == 30) or seconds == 24 then
                mechanic = "gilded_destruction"
            elseif seconds == 9 then
                mechanic = "quaking_leap"
            elseif seconds == 36 then
                mechanic = "savage_maul"
            end
            if seconds == 10 then
                sharedTimerCount = sharedTimerCount + 1
            end
            if mechanic == "deathly_roar" then
                watchedEvents[eventID] = true
            end
            return mechanic, stage
        end,
        OnEventClosed = function(eventID, state, reason)
            if watchedEvents[eventID] and (reason == "state_changed" and state == 3) then
                stage = 2
            end
            if reason ~= "added" then
                watchedEvents[eventID] = nil
            end
        end,
    }
end
local function createPlanner_2124_8()
    local seenMechanics, firstSeenDeadline = {}, nil
    return {
        Resolve = function(duration, _, observedAt)
            local precise = roundTo(duration, 3)
            if not firstSeenDeadline and type(observedAt) == "number" then
                firstSeenDeadline = observedAt + 1
            end
            if firstSeenDeadline and (type(observedAt) == "number" and observedAt > firstSeenDeadline) then
                return nil, 1
            end
            if precise == 5 and not seenMechanics.gale_force then
                seenMechanics.gale_force = true
                return "gale_force", 1
            elseif precise == 9 and not seenMechanics.thunder_and_lightning then
                seenMechanics.thunder_and_lightning = true
                return "thunder_and_lightning", 1
            elseif precise == 29 and not seenMechanics.tempest_winds then
                seenMechanics.tempest_winds = true
                return "tempest_winds", 1
            elseif precise == 39 and not seenMechanics.overload then
                seenMechanics.overload = true
                return "overload", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_2125_8()
    return {
        Resolve = function(duration)
            local seconds = roundTo(duration, 0)
            if seconds == 5 then
                return "lightning_bite", 1
            elseif seconds == 13 then
                return "a_knot_of_snakes", 1
            elseif seconds == 25 then
                return "thunder_spit", 1
            elseif seconds == 36 then
                return "serpentstorm", 1
            elseif seconds == 44 then
                return "hatch", 1
            elseif seconds == 49 then
                return "burrow", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_2126_8()
    local sharedTimerCount = 1
    return {
        Resolve = function(duration)
            local seconds = roundTo(duration, 0)
            local mechanic
            if seconds == 5 or (seconds == 22 and sharedTimerCount % 2 == 1) then
                mechanic = "lightning_spire"
            elseif seconds == 20 or (seconds == 22 and sharedTimerCount % 2 == 0) then
                mechanic = "induction"
            end
            if seconds == 22 then
                sharedTimerCount = sharedTimerCount + 1
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_2127_8()
    return {
        Resolve = function(duration)
            local tenths = roundTo(duration, 1)
            if tenths == 15 then
                return "defiling_taint", 1
            end
            if tenths == 32.5 then
                return "stage_one", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_2609_8()
    local sharedTimerCount = 1
    return {
        Resolve = function(duration)
            local seconds = roundTo(duration, 0)
            local mechanic
            if seconds == 5 or (seconds == 24 and sharedTimerCount % 2 == 1) then
                mechanic = "hailburst"
            elseif seconds == 15 or (seconds == 24 and sharedTimerCount % 2 == 0) then
                mechanic = "chillstorm"
            elseif seconds == 12 then
                mechanic = "frost_overload"
            end
            if seconds == 24 then
                sharedTimerCount = sharedTimerCount + 1
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_2606_8()
    local sharedTimerCount = 1
    return {
        Resolve = function(duration)
            local seconds = roundTo(duration, 0)
            local mechanic
            if seconds == 8 or (seconds == 40 and sharedTimerCount % 2 == 1) then
                mechanic = "ritual_of_blazebinding"
            elseif seconds == 19 or seconds == 20 then
                mechanic = "molten_boulder"
            elseif seconds == 28 or (seconds == 40 and sharedTimerCount % 2 == 0) then
                mechanic = "searing_blows"
            end
            if seconds == 40 then
                sharedTimerCount = sharedTimerCount + 1
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_2623_8()
    local fiveCount, twentyCount, sixteenCount = 1, 1, 1
    return {
        Resolve = function(duration, _, _, state)
            if state == 1 then
                return nil, 1
            end
            local tenths = roundTo(duration, 1)
            local mechanic
            if
                tenths == 1
                or (fiveCount > 1 and tenths == 5)
                or (tenths == 20 and twentyCount % 2 == 1)
                or (tenths == 16 and sixteenCount % 2 == 1)
            then
                mechanic = "roaring_firebreath"
            elseif (fiveCount == 1 and tenths == 5) or tenths == 22.5 then
                mechanic = "stormslam"
                fiveCount = fiveCount + 1
            elseif tenths == 10 or tenths == 21.5 then
                mechanic = "winds_of_change"
            elseif
                tenths == 12
                or (tenths == 20 and twentyCount % 2 == 0)
                or tenths == 13
                or (tenths == 16 and sixteenCount % 2 == 0)
            then
                mechanic = "inferno_spit"
            elseif tenths == 21 or tenths == 25 then
                mechanic = "interrupting_cloudburst"
            end
            if tenths == 20 then
                twentyCount = twentyCount + 1
            end
            if tenths == 16 then
                sixteenCount = sixteenCount + 1
            end
            return mechanic, 1
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[213908] = {
    Create = createPlanner_2139_8,
    countIdentifiableAdds = true,
    mechanicCodes = { spit_gold = 1, tail_thrash = 2, serpentine_gust = 3, lucres_call = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[214208] = {
    Create = createPlanner_2142_8,
    countIdentifiableAdds = true,
    mechanicCodes = { drain_fluids = 1, burn_corruption = 2, awakening_slam = 3, entomb = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[214008] = {
    Create = createPlanner_2140_8,
    countIdentifiableAdds = true,
    mechanicCodes = {
        whirling_axes = 1,
        severing_axe = 2,
        barrel_through = 3,
        debilitating_backhand = 4,
        arc_lightning = 5,
        poison_nova = 6,
        call_of_the_elements = 7,
    },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[214308] = {
    Create = createPlanner_2143_8,
    countIdentifiableAdds = true,
    mechanicCodes = {
        hunting_leap = 1,
        deathly_roar = 2,
        aerial_smash = 3,
        blade_combo = 4,
        gilded_destruction = 5,
        quaking_leap = 6,
        savage_maul = 7,
    },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[212408] = {
    Create = createPlanner_2124_8,
    countIdentifiableAdds = true,
    mechanicCodes = { gale_force = 1, thunder_and_lightning = 2, tempest_winds = 3, overload = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[212508] = {
    Create = createPlanner_2125_8,
    countIdentifiableAdds = true,
    mechanicCodes = {
        lightning_bite = 1,
        a_knot_of_snakes = 2,
        thunder_spit = 3,
        hatch = 4,
        serpentstorm = 5,
        burrow = 6,
    },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[212608] = {
    Create = createPlanner_2126_8,
    countIdentifiableAdds = true,
    mechanicCodes = { lightning_spire = 1, induction = 2 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[212708] = {
    Create = createPlanner_2127_8,
    countIdentifiableAdds = true,
    mechanicCodes = { defiling_taint = 1, stage_one = 2 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[260908] = {
    Create = createPlanner_2609_8,
    countIdentifiableAdds = true,
    mechanicCodes = { hailburst = 1, chillstorm = 2, frost_overload = 3 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[260608] = {
    Create = createPlanner_2606_8,
    countIdentifiableAdds = true,
    mechanicCodes = { ritual_of_blazebinding = 1, molten_boulder = 2, searing_blows = 3 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[262308] = {
    Create = createPlanner_2623_8,
    countIdentifiableAdds = true,
    mechanicCodes = {
        roaring_firebreath = 1,
        stormslam = 2,
        winds_of_change = 3,
        inferno_spit = 4,
        interrupting_cloudburst = 5,
    },
    unitEvents = {},
}
