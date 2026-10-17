--[[
  Mage_Fire（火焰法师）—— 专精配置：火焰法师（specID 63）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：dc3a68.lua（TOC 第 80 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(63, {
    talentLoadouts = {
        {
            name = "PTR日怒",
            importString = "C8DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFmZGZmxAAAwAAmZmmltlZAA2MzY2mZmZmZDAAAAALmZmZAAgZMmZYMzsBgZGghxghxA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        item_healing_stone = "/use item:5512",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        spell_133 = "/cast [nochanneling]火球术",
        spell_108853 = "/cast 火焰冲击",
        spell_11366 = "/cast [nochanneling]炎爆术",
        spell_2120 = "/cast [@cursor,nochanneling]烈焰风暴",
        spell_2948 = "/cast [nochanneling]灼烧",
        spell_190319 = "/cast 燃烧",
        spell_153561 = "/cast [@cursor,nochanneling]流星",
        cd_235313 = "/cast 烈焰护体",
        cd_2139 = "/cast 法术反制",
        spell_2139_mouseover = "/cast [@mouseover,harm,nodead,exists] 法术反制",
        focus_interrupt = "/cast [@focus]法术反制",
        spell_475 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]解除诅咒",
    },
    testSpells = { 133, 108853, 11366, 2120, 2948, 190319, 153561, 475 },
    consumableItems = {
        { id = "item_red_potion", label = "红药水", cooldown = 300, itemIDs = { 271883, 271884 } },
        { id = "item_healing_stone", label = "治疗石", cooldown = 60, itemIDs = { 5512 } },
        {
            id = "item_burst_potion",
            label = "爆发药水",
            cooldown = 300,
            itemIDs = {
                241308,
                241309,
                241288,
                241289,
            },
        },
    },
    ACTION_LABELS = {
        item_healing_stone = "治疗石",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        spell_133 = "火球术",
        spell_108853 = "火焰冲击",
        spell_11366 = "炎爆术",
        spell_2120 = "烈焰风暴",
        spell_2948 = "灼烧",
        spell_190319 = "燃烧",
        spell_153561 = "流星",
        cd_235313 = "烈焰护体",
        cd_2139 = "法术反制",
        spell_2139_mouseover = "法术反制指向",
        focus_interrupt = "法术反制焦点",
        spell_475 = "指向解除诅咒",
    },
    ACTION_TO_KEY = {
        item_healing_stone = ";",
        item_red_potion = "'",
        item_burst_potion = "=",
        trinket1_cd = "[",
        trinket2_cd = "]",
        spell_133 = "F6",
        spell_108853 = "F7",
        spell_11366 = "F8",
        spell_2120 = "F10",
        spell_2948 = "F9",
        spell_190319 = "F11",
        spell_153561 = "F12",
        cd_235313 = "8",
        cd_2139 = "9",
        spell_2139_mouseover = ",",
        focus_interrupt = "0",
        spell_475 = "-",
    },
    macroOrder = {
        "spell_133",
        "spell_108853",
        "spell_11366",
        "spell_2120",
        "spell_2948",
        "spell_190319",
        "spell_153561",
        "cd_235313",
        "cd_2139",
        "spell_2139_mouseover",
        "focus_interrupt",
        "item_healing_stone",
        "item_red_potion",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
        "spell_475",
    },
    actionAvailSpellIDs = { 133, 2120, 2948, 11366 },
    spellReadyAliases = { [133] = { 431044 }, [2120] = { 1254851 }, [11366] = { 1236212, 1262863 } },
})
