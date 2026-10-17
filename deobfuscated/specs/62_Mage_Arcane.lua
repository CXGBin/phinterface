--[[
  Mage_Arcane（奥术法师）—— 专精配置：奥术法师（specID 62）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：7d37cc.lua（TOC 第 65 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local touchOfMagiCastAt = 0
local TOUCH_DURATION = 12
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(62, {
    talentLoadouts = {
        {
            name = "团本老5",
            importString = "C4DAche08tHz49KSVf7iKFnyuZGGLzMzsgZQzMzAAAwAAmZmmlllZAgYDAgNMzMDbWmZmZZGjxMzMswMzMzMAADAAwAMzAmBADzMD",
        },
        {
            name = "通用日怒",
            importString = "C4DAche08tHz49KSVf7iKFnyuZGGLzMmFMzQzMzAAAwAAmZmmlllZAgYDAgNYmZYzyMmZZGjZmZmhFmZmZmBAYAAAGgZGYmBADzMD",
        },
    },
    DEFAULT_MACROS = {
        spell_30451 = "/cast [nochanneling]奥术冲击",
        spell_44425 = "/cast [nochanneling]奥术弹幕",
        spell_44425_stopcasting = "/stopcasting\n/cast 奥术弹幕",
        spell_365350 = "/cast [nochanneling]奥术涌动",
        spell_321507 = "/cast [nochanneling]奥术弹幕\n/use [nochanneling]货运者水壶\n/cast [nochanneling]大法师之触",
        spell_321507_pure = "/cast [nochanneling]大法师之触",
        spell_153626 = "/cast [nochanneling]奥术宝珠",
        spell_5143 = "/cast [nochanneling]奥术飞弹",
        spell_5143_chain = "/cast 奥术飞弹",
        cd_55342 = "/cast [nochanneling]镜像",
        cd_414658 = "/cast [nochanneling]寒冰屏障",
        cd_235450 = "/cast [nochanneling]棱光护体",
        cd_2139 = "/cast [nochanneling]法术反制",
        spell_2139_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]法术反制",
        focus_interrupt = "/cast [nochanneling,@focus]法术反制",
        item_red_potion = "/use [nochanneling] item:271883\n/use [nochanneling] item:271884",
        item_healing_stone = "/use [nochanneling] item:5512",
        item_burst_potion = "/use [nochanneling] item:241308\n/use [nochanneling] item:241309\n/use [nochanneling] item:241288\n/use [nochanneling] item:241289",
        trinket1_cd = "/use [nochanneling] 13",
        trinket2_cd = "/use [nochanneling] 14",
        spell_475 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]解除诅咒",
    },
    testSpells = { 365350, 321507, 153626, 5143, 475 },
    ACTION_LABELS = {
        spell_30451 = "奥术冲击",
        spell_44425 = "奥术弹幕",
        spell_44425_stopcasting = "奥魂弹幕",
        spell_365350 = "奥术涌动",
        spell_321507 = "大法师之触",
        spell_321507_pure = "纯大法师之触",
        spell_153626 = "奥术宝珠",
        spell_5143 = "奥术飞弹",
        spell_5143_chain = "奥术飞弹连击",
        cd_55342 = "镜像",
        cd_414658 = "深寒凝冰",
        cd_235450 = "棱光护体",
        cd_2139 = "法术反制",
        spell_2139_mouseover = "法术反制指向",
        focus_interrupt = "法术反制焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        spell_475 = "指向解除诅咒",
    },
    ACTION_TO_KEY = {
        spell_30451 = "F6",
        spell_44425 = "F9",
        spell_44425_stopcasting = "F10",
        spell_365350 = "8",
        spell_321507 = "F12",
        spell_321507_pure = "INSERT",
        spell_153626 = "F11",
        spell_5143 = "F7",
        spell_5143_chain = "F8",
        cd_55342 = "9",
        cd_414658 = "0",
        cd_235450 = "-",
        cd_2139 = "=",
        spell_2139_mouseover = "UP",
        focus_interrupt = "[",
        item_red_potion = "\\",
        item_healing_stone = ".",
        item_burst_potion = ";",
        trinket1_cd = "'",
        trinket2_cd = ",",
        spell_475 = "]",
    },
    macroOrder = {
        "spell_30451",
        "spell_44425",
        "spell_44425_stopcasting",
        "spell_365350",
        "spell_321507",
        "spell_321507_pure",
        "spell_153626",
        "spell_5143",
        "spell_5143_chain",
        "cd_55342",
        "cd_414658",
        "cd_235450",
        "cd_2139",
        "spell_2139_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
        "spell_475",
    },
    actionAvailSpellIDs = { 5143, 30451, 44425 },
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
    showAoeModeButton = true,
    OnSpellCast = function(spellID)
        if spellID == 321507 then
            touchOfMagiCastAt = GetTime()
        end
    end,
    GetExtraValues = function(values)
        local touchRemains = 0
        if touchOfMagiCastAt > 0 then
            local elapsed = GetTime() - touchOfMagiCastAt
            if elapsed < TOUCH_DURATION then
                touchRemains = TOUCH_DURATION - elapsed
            else
                touchOfMagiCastAt = 0
            end
        end
        values.touch_remains = math.floor(touchRemains + 0.5)
        local isChanneling, inWindow, reliable = P8BA6426E.GetPlayerChannelWindowState(5143, 5, 6)
        values.arcane_missiles_chain_ready = reliable and inWindow or false
    end,
})
