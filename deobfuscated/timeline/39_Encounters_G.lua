--[[
  Encounters_G —— 时间轴规划器：首领时间轴事件 → 技能识别（一批地下城首领）
  原始文件：3b9655.lua（TOC 第 39 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E.TimelinePlannerEncounters = P8BA6426E.TimelinePlannerEncounters or {}
local function roundSeconds(seconds)
    return math.floor(seconds + 0.5)
end
local function roundTenths(seconds)
    return math.floor(seconds * 10 + 0.5) / 10
end
local function rememberReplacement(lastByMechanic, mechanic, eventID, observedAt, window)
    local entry = lastByMechanic[mechanic]
    local replacedEventID
    if entry and (entry.observedAt and observedAt) then
        local elapsed = observedAt - entry.observedAt
        if elapsed >= 0 and elapsed < window then
            replacedEventID = entry.eventID
        end
    end
    lastByMechanic[mechanic] = { eventID = eventID, observedAt = observedAt }
    return replacedEventID
end
local function forgetEvent(lastByMechanic, eventID)
    for mechanic, last in pairs(lastByMechanic) do
        if last.eventID == eventID then
            lastByMechanic[mechanic] = nil
        end
    end
end
local function createPlanner_3101_8()
    local lastByMechanic = {}
    return {
        Resolve = function(duration, eventID, observedAt)
            local tenths, mechanic = roundTenths(duration), nil
            if tenths == 8 or tenths == 27.5 then
                mechanic = "fel_spray"
            elseif tenths == 15 or tenths == 30 then
                mechanic = "mirror_images"
            elseif tenths == 12 or tenths == 25 then
                mechanic = "fel_nova"
            end
            if not mechanic then
                return nil, 1
            end
            return mechanic, 1, rememberReplacement(lastByMechanic, mechanic, eventID, observedAt, 3)
        end,
        OnEventClosed = function(eventID)
            forgetEvent(lastByMechanic, eventID)
        end,
    }
end
local function createPlanner_3102_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds == 8 then
                return "killing_spree", 1
            end
            if seconds == 12 or seconds == 16 then
                return "same_day_delivery", 1
            end
            if seconds == 18 then
                return "fire_bomb", 1
            end
            if seconds == 26 then
                return "envenom", 1
            end
            if seconds == 36 then
                return "murder_in_a_row", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_3103_8()
    local sharedTimerCount = 1
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds < 1 or seconds > 100 then
                return nil, 1
            end
            if seconds == 6 then
                return "legion_strike", 1
            end
            if seconds == 27 then
                local mechanic = sharedTimerCount % 2 == 1 and "legion_strike" or nil
                sharedTimerCount = sharedTimerCount + 1
                return mechanic, 1
            end
            if seconds == 15 then
                return "axe_toss", 1
            end
            if seconds == 30 then
                return "infernal_crush", 1
            end
            if seconds == 35 then
                return "demonic_rage", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_3105_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds == 10 or seconds == 57 then
                return "summon_vilefiend", 1
            end
            if seconds == 15 or seconds == 55 then
                return "fingers_of_guldan", 1
            end
            if seconds == 24 or seconds == 59 then
                return "malefic_wave", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_3207_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds == 6 then
                return "ravenous_bellow", 1
            end
            if seconds == 16 then
                return "earthshatter_slam", 1
            end
            if seconds == 30 then
                return "spoiled_supplies", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_3208_8()
    local lastByMechanic = {}
    return {
        Resolve = function(duration, eventID, observedAt)
            local seconds, mechanic = roundSeconds(duration), nil
            if seconds > 59 then
                return nil, 1
            end
            if seconds == 7 then
                mechanic = "glacial_torment"
            elseif seconds == 13 then
                mechanic = "raging_squall"
            elseif seconds == 25 then
                mechanic = "shattering_frostspike"
            elseif seconds == 50 then
                mechanic = "frozen_tempest"
            end
            if not mechanic then
                return nil, 1
            end
            return mechanic, 1, rememberReplacement(lastByMechanic, mechanic, eventID, observedAt, 2)
        end,
        OnEventClosed = function(eventID)
            forgetEvent(lastByMechanic, eventID)
        end,
    }
end
local function createPlanner_3209_8()
    local sharedTimerCount = 1
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds == 5 then
                return "echoing_maul", 1
            end
            if seconds == 13 then
                return "overwhelming_onslaught", 1
            end
            if seconds == 54 then
                return "fury_of_the_war_god", 1
            end
            if seconds == 25 then
                local mechanic = sharedTimerCount % 2 == 1 and "echoing_maul" or "overwhelming_onslaught"
                sharedTimerCount = sharedTimerCount + 1
                return mechanic, 1
            end
            return nil, 1
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[310108] = {
    Create = createPlanner_3101_8,
    countIdentifiableAdds = true,
    mechanicCodes = { fel_spray = 1, mirror_images = 2, fel_nova = 3 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[310208] = {
    Create = createPlanner_3102_8,
    countIdentifiableAdds = true,
    mechanicCodes = { killing_spree = 1, same_day_delivery = 2, fire_bomb = 3, envenom = 4, murder_in_a_row = 5 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[310308] = {
    Create = createPlanner_3103_8,
    countIdentifiableAdds = true,
    mechanicCodes = { legion_strike = 1, axe_toss = 2, infernal_crush = 3, demonic_rage = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[310508] = {
    Create = createPlanner_3105_8,
    countIdentifiableAdds = true,
    mechanicCodes = { summon_vilefiend = 1, fingers_of_guldan = 2, malefic_wave = 3 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[320708] = {
    Create = createPlanner_3207_8,
    countIdentifiableAdds = true,
    mechanicCodes = { ravenous_bellow = 1, earthshatter_slam = 2, spoiled_supplies = 3 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[320808] = {
    Create = createPlanner_3208_8,
    countIdentifiableAdds = true,
    mechanicCodes = { glacial_torment = 1, raging_squall = 2, shattering_frostspike = 3, frozen_tempest = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[320908] = {
    Create = createPlanner_3209_8,
    countIdentifiableAdds = true,
    mechanicCodes = { echoing_maul = 1, overwhelming_onslaught = 2, fury_of_the_war_god = 3 },
    unitEvents = {},
}
