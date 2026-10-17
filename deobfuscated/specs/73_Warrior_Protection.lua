--[[
  Warrior_Protection（防护战士）—— 专精配置：防护战士（specID 73）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：ab288f.lua（TOC 第 69 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
local function isShieldSlamHighlighted()
    if not getHostileTargetGUID() then
        return false
    end
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        return C_SpellActivationOverlay.IsSpellOverlayed(384110) == true
    end
    return false
end
P8BA6426E.RegisterClass(73, {
    talentLoadouts = {
        {
            name = "PTR山丘领主推荐",
            importString = "CkEAAAAAAAAAAAAAAAAAAAAAAkBAAGzwMzMzMmNzMLzYMGNmxwyMzMzYGmZAAAAwyMDwMGgB2glFjGzAYWwMbwYmBjNAYmBAgZgxA",
        },
    },
    DEFAULT_MACROS = {
        spell_23922 = "/cast [nochanneling]盾牌猛击",
        spell_23922_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]盾牌猛击\n/targetlasttarget",
        spell_6343 = "/cast [nochanneling]雷霆一击",
        spell_6572 = "/cast [nochanneling]复仇",
        spell_6572_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]复仇\n/targetlasttarget",
        spell_57755 = "/cast [nochanneling]英勇投掷",
        spell_385952 = "/cast [nochanneling]盾牌冲锋",
        spell_190456 = "/cast [nochanneling]无视苦痛",
        spell_1160 = "/cast [nochanneling]挫志怒吼",
        spell_871 = "/cast [nochanneling]盾墙",
        spell_384110 = "/cast [nochanneling]破裂投掷",
        spell_2565 = "/cast [nochanneling]盾牌格挡",
        spell_107574 = "/cast [nochanneling]天神下凡",
        cd_202168 = "/cast [nochanneling]胜利在望",
        spell_6673 = "/cast 战斗怒吼",
        cd_97462 = "/cast [nochanneling]集结呐喊",
        cd_6552 = "/cast [nochanneling]拳击",
        spell_6552_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]拳击",
        cd_18499 = "/cast [nochanneling]狂暴之怒",
        spell_163201 = "/cast 斩杀",
        spell_163201_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 斩杀\n/targetlasttarget",
        spell_436358 = "/cast [nochanneling]崩摧",
        focus_interrupt = "/cast [nochanneling,@focus]拳击",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 23922, 6343, 6572, 57755, 385952, 190456, 1160, 871, 163201, 436358 },
    ACTION_LABELS = {
        spell_23922 = "盾牌猛击",
        spell_23922_nearest = "就近盾牌猛击",
        spell_6343 = "雷霆一击",
        spell_6572 = "复仇",
        spell_6572_nearest = "就近复仇",
        spell_57755 = "英勇投掷",
        spell_385952 = "盾牌冲锋",
        spell_190456 = "无视苦痛",
        spell_1160 = "挫志怒吼",
        spell_871 = "盾墙",
        spell_384110 = "破裂投掷",
        spell_2565 = "盾牌格挡",
        spell_107574 = "天神下凡",
        cd_202168 = "胜利在望",
        spell_6673 = "战斗怒吼",
        cd_97462 = "集结呐喊",
        cd_6552 = "拳击",
        spell_6552_mouseover = "拳击指向",
        cd_18499 = "狂暴之怒",
        spell_163201 = "斩杀",
        spell_163201_nearest = "就近斩杀",
        spell_436358 = "崩摧",
        focus_interrupt = "拳击焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_23922 = "F6",
        spell_23922_nearest = "F7",
        spell_6343 = "F8",
        spell_6572 = "F9",
        spell_6572_nearest = "F10",
        spell_57755 = "F11",
        spell_385952 = "F12",
        spell_190456 = "8",
        spell_1160 = "0",
        spell_871 = "]",
        spell_384110 = ";",
        spell_2565 = "9",
        spell_107574 = "[",
        cd_202168 = ",",
        spell_6673 = "'",
        cd_97462 = ".",
        cd_18499 = "\\",
        spell_163201 = "-",
        spell_163201_nearest = "=",
        spell_436358 = "END",
        cd_6552 = "UP",
        spell_6552_mouseover = "CTRL-F6",
        focus_interrupt = "DOWN",
        item_red_potion = "HOME",
        item_healing_stone = "DELETE",
        item_burst_potion = "LEFT",
        trinket1_cd = "RIGHT",
        trinket2_cd = "INSERT",
    },
    macroOrder = {
        "spell_23922",
        "spell_23922_nearest",
        "spell_6343",
        "spell_6572",
        "spell_6572_nearest",
        "spell_57755",
        "spell_385952",
        "spell_190456",
        "spell_1160",
        "spell_871",
        "spell_384110",
        "spell_2565",
        "spell_107574",
        "cd_202168",
        "spell_6673",
        "cd_97462",
        "cd_18499",
        "spell_163201",
        "spell_163201_nearest",
        "spell_436358",
        "cd_6552",
        "spell_6552_mouseover",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 6572, 6673, 57755, 163201, 190456 },
    spellReadyAliases = { [6572] = { 1215174, 1264147 }, [190456] = { 1277297 } },
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
        local now = GetTime()
        if spellID == lastCastSpellID and (now - lastCastAt) < 0.5 then
            return
        end
        lastCastSpellID = spellID
        lastCastAt = now
    end,
    GetExtraValues = function(values)
        values.target_shield = isShieldSlamHighlighted()
    end,
})
