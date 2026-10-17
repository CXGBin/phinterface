--[[
  Encounters_C —— 时间轴规划器：首领时间轴事件 → 技能识别（一批首领）
  原始文件：735e43.lua（TOC 第 35 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local function roundSeconds(seconds)
    return math.floor(seconds + 0.5)
end
local function createPlanner_3455_15()
    local firstFroth = true
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds == 13 then
                if firstFroth then
                    firstFroth = false
                    return "plague_froth", 1
                end
                return "dripping_fangs", 1
            elseif seconds == 20 or seconds == 80 then
                return "imbibe", 1
            elseif seconds == 30 or seconds == 33 then
                return "plague_froth", 1
            elseif seconds == 8 or seconds == 27 or seconds == 28 then
                return "dripping_fangs", 1
            elseif seconds == 18 or seconds == 52 then
                return "adaptive_infection", 1
            elseif seconds == 6 or seconds == 39 then
                return "malignant_catalyst", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_3420_15()
    local seenCountBySeconds = {}
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            if seconds == 100 or seconds == 111 or seconds == 125 then
                return "howling_maelstrom", 1
            elseif seconds == 5 or seconds == 6 then
                return "apex_predator", 1
            elseif seconds == 29 or seconds == 32 or seconds == 36 then
                return "venomous_surge", 1
            elseif seconds == 39 or seconds == 43 or seconds == 49 then
                return "raging_crosswinds", 1
            elseif seconds == 47 or seconds == 52 or seconds == 59 then
                local count = (seenCountBySeconds[seconds] or 0) + 1
                seenCountBySeconds[seconds] = count
                local slot = count % 3
                if slot == 1 then
                    return "apex_predator", 1
                end
                if slot == 2 then
                    return "venomous_surge", 1
                end
                return "raging_crosswinds", 1
            end
            return nil, 1
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[345515] = {
    Create = createPlanner_3455_15,
    countIdentifiableAdds = true,
    mechanicCodes = { imbibe = 1, malignant_catalyst = 2, plague_froth = 3, dripping_fangs = 4, adaptive_infection = 5 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[342015] = {
    Create = createPlanner_3420_15,
    countIdentifiableAdds = true,
    mechanicCodes = { howling_maelstrom = 1, apex_predator = 2, venomous_surge = 3, raging_crosswinds = 4 },
    unitEvents = {},
}
