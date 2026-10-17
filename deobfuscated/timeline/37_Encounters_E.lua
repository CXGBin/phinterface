--[[
  Encounters_E —— 时间轴规划器：首领时间轴事件 → 技能识别（一批首领）
  原始文件：9bf7e6.lua（TOC 第 37 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local function createPlanner_3379_15()
    local rotationIndex = 0
    return {
        Resolve = function(duration)
            local seconds = math.floor(duration + 0.5)
            if seconds == 44 then
                rotationIndex = rotationIndex % 3 + 1
                if rotationIndex == 1 then
                    return "alluring_bubble_adds", 1
                end
                if rotationIndex == 2 then
                    return "chilling_frost", 1
                end
                return "abyssal_rain", 1
            elseif duration == 18 then
                return "alluring_bubble", 1
            elseif seconds == 8 or seconds == 23 or seconds == 33 then
                return "abyssal_rain", 1
            elseif seconds == 22 or seconds == 27 or seconds == 9 then
                return "iceblade_flurry", 1
            elseif seconds == 25 or seconds == 7 then
                return "alluring_bubble_adds", 1
            elseif seconds == 107 or seconds == 89 then
                return "swirling_whirlpools", 1
            elseif seconds == 35 or seconds == 17 then
                return "chilling_frost", 1
            end
            return nil, 1
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[337915] = {
    Create = createPlanner_3379_15,
    countIdentifiableAdds = true,
    mechanicCodes = {
        alluring_bubble_adds = 1,
        alluring_bubble = 2,
        swirling_whirlpools = 3,
        abyssal_rain = 4,
        iceblade_flurry = 5,
        chilling_frost = 6,
    },
    unitEvents = {},
}
