--[[
  Mage_Frost（冰霜法师）—— 专精配置：冰霜法师（specID 64）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：1a5317.lua（TOC 第 46 个加载的插件脚本）

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
P8BA6426E.RegisterClass(64, {
    talentLoadouts = {
        {
            name = "不三单体",
            importString = "CAEAche08tHz49KSVf7iKFnyuZGGLzMzsMmZmYmxYmZmZWMzMjZMzwkZWmFAwMzMLLzMtBAAAAAAbAstMmZmZY2GGzwCAAAzsNzgZgBMDGA",
        },
        {
            name = "不三多目标",
            importString = "CAEAche08tHz49KSVf7iKFnyuNzwYZmZmFmZmYGzYmZmZWMzMMjZgAAAzMzssMz0GAAsBAAAWAYbZMzMDmthxMjNAAAmZDYGGDYGMA",
        },
    },
    DEFAULT_MACROS = {
        spell_205021 = "/cast [nochanneling]冰霜射线",
        spell_116 = "/cast [nochanneling]寒冰箭",
        spell_1248829 = "/cast [nochanneling]暴风雪",
        spell_44614 = "/cast [nochanneling]冰风暴",
        spell_30455 = "/cast [nochanneling]冰枪术",
        spell_84714 = "/cast [nochanneling]寒冰宝珠",
        spell_11426 = "/cast [nochanneling]寒冰护体",
        spell_414658 = "/cast [nochanneling]深寒凝冰",
        cd_2139 = "/cast [nochanneling]法术反制",
        spell_2139_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]法术反制",
        focus_interrupt = "/cast [nochanneling,@focus]法术反制",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_healing_stone = "/use item:5512",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        spell_475 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]解除诅咒",
    },
    testSpells = { 205021, 116, 1248829, 44614, 30455, 84714, 11426, 414658, 475 },
    ACTION_LABELS = {
        spell_205021 = "冰霜射线",
        spell_116 = "寒冰箭",
        spell_1248829 = "暴风雪",
        spell_44614 = "冰风暴",
        spell_30455 = "冰枪术",
        spell_84714 = "寒冰宝珠",
        spell_11426 = "寒冰护体",
        spell_414658 = "深寒凝冰",
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
        spell_205021 = "F11",
        spell_116 = "F6",
        spell_1248829 = "F9",
        spell_44614 = "F7",
        spell_30455 = "F8",
        spell_84714 = "F10",
        spell_11426 = "F12",
        spell_414658 = "8",
        cd_2139 = "9",
        spell_2139_mouseover = ",",
        focus_interrupt = "0",
        item_red_potion = "'",
        item_healing_stone = ";",
        item_burst_potion = "=",
        trinket1_cd = "[",
        trinket2_cd = "]",
        spell_475 = "-",
    },
    macroOrder = {
        "spell_205021",
        "spell_116",
        "spell_1248829",
        "spell_44614",
        "spell_30455",
        "spell_84714",
        "spell_11426",
        "spell_414658",
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
    spellReadyAliases = { [116] = { 431044 } },
    actionAvailSpellIDs = { 116, 30455 },
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
    GetExtraValues = function(values)
        local stacks_icicles = 0
        pcall(function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(205473)
            if aura then
                stacks_icicles = aura.applications or 0
            end
        end)
        values.stacks_icicles = stacks_icicles
    end,
})
