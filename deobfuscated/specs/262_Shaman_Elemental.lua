--[[
  Shaman_Elemental（元素萨满）—— 专精配置：元素萨满（specID 262）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：442949.lua（TOC 第 56 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local buff_master_of_the_elements = false
local MOTE_CONSUMER_SPELLS = {
    [188196] = true,
    [188443] = true,
    [188389] = true,
    [470411] = true,
    [470057] = true,
    [462620] = true,
    [117014] = true,
}
P8BA6426E.RegisterClass(262, {
    talentLoadouts = {
        {
            name = "元素宗师",
            importString = "CYQALMl7AwW51MWzGneuHE3tPCAAAAzMbLzMGjZZbZMmhZAAAAgFzsthBMgZjJkZBAmtZGjx2ipFmZ2GLmZm5BGWsMzsMMmZWAAmBAzMGGGA",
        },
        {
            name = "团本单体",
            importString = "CYQALMl7AwW51MWzGneuHE3tPCAAAAzMbLzMmZmZZbZMMjBAAAAsYmNYADY2YCZWAgZZmZGjtFTYmZZmFzMzYYxywiZGmZZAgZYAMzYYYA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_470057 = "/cancelaura 幽魂之狼\n/cast 流电炽焰",
        spell_135813 = "/cancelaura 幽魂之狼\n/cast 烈焰震击",
        spell_51505 = "/cancelaura 幽魂之狼\n/cast 熔岩爆裂",
        spell_188443 = "#showtooltip 闪电链\n/cancelaura 幽魂之狼\n/cast [known:狂风怒号] 自然迅捷\n/cast [known:狂风怒号] 狂风怒号\n/cast 闪电链",
        spell_188196 = "#showtooltip 闪电箭\n/cancelaura 幽魂之狼\n/cast [known:狂风怒号] 自然迅捷\n/cast [known:狂风怒号] 狂风怒号\n/cast 闪电箭",
        spell_462620 = "/cancelaura 幽魂之狼\n/cast 地震术",
        spell_117014 = "/cancelaura 幽魂之狼\n/cast 元素冲击",
        spell_191634 = "/cancelaura 幽魂之狼\n/cast 风暴守护者",
        spell_114050 = "/cancelaura 幽魂之狼\n/use 一瓶肮脏的烈性毒液\n/use 货运者水壶\n/cast 升腾",
        spell_79206 = "/cancelaura 幽魂之狼\n/cast 灵魂行者的恩赐",
        cd_57994 = "/cancelaura 幽魂之狼\n/cast 风剪",
        spell_57994_mouseover = "/cancelaura 幽魂之狼\n/cast [@mouseover,harm,nodead,exists] 风剪",
        focus_interrupt = "/cancelaura 幽魂之狼\n/cast [@focus]风剪",
        cd_108271 = "/cancelaura 幽魂之狼\n/cast 星界转移",
        cd_198103 = "/cast 土元素",
        spell_462854 = "/cast 天怒",
        spell_370 = "/cancelaura 幽魂之狼\n/cast 净化术",
        spell_51886 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]净化灵魂",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        cd_443454 = "/cast 先祖迅捷",
    },
    testSpells = { 470057, 135813, 51505, 188443, 188196, 462620, 117014, 191634, 114050, 370, 51886 },
    ACTION_LABELS = {
        spell_470057 = "流电炽焰",
        spell_135813 = "烈焰震击",
        spell_51505 = "熔岩爆裂",
        spell_188443 = "闪电链",
        spell_188196 = "闪电箭",
        spell_462620 = "地震术",
        spell_117014 = "元素冲击",
        spell_191634 = "风暴守护者",
        spell_114050 = "升腾",
        spell_79206 = "灵魂行者的恩赐",
        cd_57994 = "风剪",
        spell_57994_mouseover = "风剪指向",
        focus_interrupt = "风剪焦点",
        cd_108271 = "星界转移",
        cd_198103 = "土元素",
        spell_462854 = "天怒",
        spell_370 = "净化术",
        spell_51886 = "指向净化灵魂",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        cd_443454 = "先祖迅捷",
    },
    ACTION_TO_KEY = {
        spell_470057 = "F6",
        spell_135813 = "F7",
        spell_51505 = "F8",
        spell_188443 = "F10",
        spell_188196 = "F9",
        spell_462620 = "F11",
        spell_117014 = "F12",
        spell_191634 = "8",
        spell_114050 = "0",
        spell_79206 = "-",
        cd_57994 = "=",
        spell_57994_mouseover = "INSERT",
        focus_interrupt = "RIGHT",
        cd_108271 = "[",
        cd_198103 = "]",
        spell_462854 = ";",
        spell_370 = "'",
        spell_51886 = ",",
        item_red_potion = "DOWN",
        item_burst_potion = ".",
        item_healing_stone = "LEFT",
        trinket1_cd = "\\",
        trinket2_cd = "UP",
        cd_443454 = "9",
    },
    macroOrder = {
        "spell_470057",
        "spell_135813",
        "spell_51505",
        "spell_188443",
        "spell_188196",
        "spell_462620",
        "spell_117014",
        "spell_191634",
        "spell_114050",
        "spell_79206",
        "cd_57994",
        "cd_108271",
        "spell_57994_mouseover",
        "cd_198103",
        "spell_462854",
        "spell_370",
        "spell_51886",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
        "cd_443454",
    },
    testData = {},
    actionAvailSpellIDs = { 188196, 188443, 462854, 370 },
    OnSpellCast = function(spellID)
        if spellID == 51505 then
            buff_master_of_the_elements = true
        elseif MOTE_CONSUMER_SPELLS[spellID] then
            buff_master_of_the_elements = false
        end
    end,
    GetExtraValues = function(values)
        values.buff_master_of_the_elements = buff_master_of_the_elements
        values.talent_462440 = P8BA6426E.IsSpellKnown(462440)
    end,
    consumableItems = {
        { id = "item_red_potion", label = "红药水", cooldown = 300, itemIDs = { 271883, 271884 } },
        {
            id = "item_burst_potion",
            label = "爆发药水",
            cooldown = 300,
            itemIDs = { 241308, 241309, 241288, 241289 },
        },
        { id = "item_healing_stone", label = "治疗石", cooldown = 60, itemIDs = { 5512 } },
    },
})
