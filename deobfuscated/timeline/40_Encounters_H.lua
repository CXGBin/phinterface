--[[
  Encounters_H —— 时间轴规划器：首领时间轴事件 → 技能识别（一批地下城首领）
  原始文件：be4f96.lua（TOC 第 40 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E.TimelinePlannerEncounters = P8BA6426E.TimelinePlannerEncounters or {}
local function roundSeconds(seconds)
    return math.floor(seconds + 0.5)
end
local function createPlanner_3285_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic = (
                { [6] = "nether_dash", [16] = "umbral_rupture", [25] = "void_blast", [31] = "dark_bloom" }
            )[seconds]
            return mechanic, 1
        end,
    }
end
local function createPlanner_3286_8()
    local sharedTimerCount = 0
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic
            if seconds == 5 or (seconds == 20 and sharedTimerCount % 2 == 1) then
                mechanic = "poison_splash"
            elseif seconds == 10 or (seconds == 20 and sharedTimerCount % 2 == 0) then
                mechanic = "hulking_claw"
            elseif seconds == 15 or seconds == 30 then
                mechanic = "noxious_breath"
            elseif seconds == 35 then
                mechanic = "monstrous_roar"
            end
            if seconds == 20 then
                sharedTimerCount = sharedTimerCount + 1
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_3287_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local entry = ({
                [5] = "unstable_singularity",
                [17] = "cosmic_crash",
                [28] = "gravitic_orbs",
                [34] = "dark_waves",
                [43] = "void_cascade",
            })[seconds]
            return entry, 1
        end,
    }
end
local function createPlanner_3456_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic
            if seconds == 8 or seconds == 24 then
                mechanic = "triple_shot"
            elseif seconds == 25 or seconds == 45 then
                mechanic = "ssscavenging"
            elseif seconds == 13 then
                mechanic = "regurgitate"
            elseif seconds == 23 then
                mechanic = "ravenous_stomp"
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_3457_8()
    local sharedTimerCount, stage = 0, 1
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic
            if seconds == 1 or (seconds == 10 and sharedTimerCount % 2 == 0) then
                mechanic = "synchronized_venom"
            elseif seconds == 7 or seconds == 16 then
                mechanic = "tail_scythe"
            elseif seconds == 14 or seconds == 23 then
                mechanic = "preparing_toxin"
            elseif seconds == 30 or seconds == 39 then
                mechanic = "vindictive_onslaught"
            elseif seconds == 44 or seconds == 53 then
                mechanic = "death_rattle"
                if stage == 2 then
                    stage = 1
                end
            elseif seconds == 10 and sharedTimerCount % 2 == 1 then
                mechanic = "toxic_atrophy"
            elseif seconds == 25 then
                mechanic, stage = "assimilation", 2
            end
            if seconds == 10 then
                sharedTimerCount = sharedTimerCount + 1
            end
            return mechanic, stage
        end,
    }
end
local function createPlanner_3458_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic
            if seconds == 3 or seconds == 65 then
                mechanic = "ritual_of_the_fang"
            elseif seconds == 18 then
                mechanic = "axegrinder"
            elseif seconds == 26 or seconds == 30 then
                mechanic = "chop_down"
            elseif seconds == 36 or seconds == 16 then
                mechanic = "boneslicer"
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_3200_8()
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic
            if seconds == 6 or seconds == 29 then
                mechanic = "verdant_stomp"
            elseif seconds == 22 then
                mechanic = "thorncaller_roar"
            elseif seconds == 50 then
                mechanic = "bloodthirsty_gaze"
            end
            return mechanic, 1
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[328508] = {
    Create = createPlanner_3285_8,
    countIdentifiableAdds = true,
    mechanicCodes = { nether_dash = 1, umbral_rupture = 2, void_blast = 3, dark_bloom = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[328608] = {
    Create = createPlanner_3286_8,
    countIdentifiableAdds = true,
    mechanicCodes = { poison_splash = 1, hulking_claw = 2, noxious_breath = 3, monstrous_roar = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[328708] = {
    Create = createPlanner_3287_8,
    countIdentifiableAdds = true,
    mechanicCodes = { unstable_singularity = 1, cosmic_crash = 2, gravitic_orbs = 3, dark_waves = 4, void_cascade = 5 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[345608] = {
    Create = createPlanner_3456_8,
    countIdentifiableAdds = true,
    mechanicCodes = { triple_shot = 1, ssscavenging = 2, regurgitate = 3, ravenous_stomp = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[345708] = {
    Create = createPlanner_3457_8,
    countIdentifiableAdds = true,
    mechanicCodes = {
        synchronized_venom = 1,
        tail_scythe = 2,
        preparing_toxin = 3,
        vindictive_onslaught = 4,
        death_rattle = 5,
        toxic_atrophy = 6,
        assimilation = 7,
    },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[345808] = {
    Create = createPlanner_3458_8,
    countIdentifiableAdds = true,
    mechanicCodes = { ritual_of_the_fang = 1, axegrinder = 2, chop_down = 3, boneslicer = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[320008] = {
    Create = createPlanner_3200_8,
    countIdentifiableAdds = true,
    mechanicCodes = { verdant_stomp = 1, thorncaller_roar = 2, bloodthirsty_gaze = 3 },
    unitEvents = {},
}
