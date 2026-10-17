--[[
  Druid_Feral（野性德鲁伊）—— 专精配置：野性德鲁伊（specID 103）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：96bc77.lua（TOC 第 68 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local tigersFuryAt = 0
local berserkAt = 0
local TIGERS_FURY_DURATION = 15
local BERSERK_DURATION = 15
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(103, {
    talentLoadouts = {
        {
            name = "大米利爪",
            importString = "CcGADBD3hSPCL9Y9gz68WcKvMAAAAAAgZmZ2MzMzMGzmx2YbGzMmZAAAAYJY2M8AmZUzYWMzMzsMmhBAAAAAwADAAAgmZZWmZmBEYBmZGgFGMAAAmZDD",
        },
        {
            name = "团本荒野",
            importString = "CcGAAAAAAAAAAAAAAAAAAAAAAAAAAAAwYMDGzMjxstMPwyYbmZGzMDAAAALBzGMmZUzYWYmZGjZMDAAAAAgBGAAAAAgZbmlmlZW2gZmBYxMYAAMzAgB",
        },
        {
            name = "团本荒野·月光月火",
            importString = "CcGAAAAAAAAAAAAAAAAAAAAAAAAAAAAjZ2YmZmZGz2yYZsNjZmHYmBAAAglgZzwYmRNjZhZmZMmZAAAAAAwADAAAAAwsNzSzyMLbgZGgFzgBAwMDAGA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_5221 = "/cast [nochanneling]撕碎",
        spell_5221_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]撕碎\n/targetlasttarget",
        spell_1822 = "/cast [nochanneling]斜掠",
        mouseover_rake = "/cast [nochanneling,@mouseover,harm,nodead]斜掠",
        spell_1079 = "/cast [nochanneling]割裂",
        spell_22568 = "/cast [nochanneling]凶猛撕咬",
        spell_22568_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]凶猛撕咬\n/targetlasttarget",
        spell_106785 = "/cast [nochanneling]横扫",
        spell_285381 = "/cast [nochanneling]原始之怒",
        spell_5217 = "/cast [nochanneling]猛虎之怒",
        spell_106951 = "/cast [nochanneling]狂暴",
        spell_1243807 = "/cast [nochanneling]怒意狂乱",
        spell_274837 = "/cast [nochanneling]野性狂乱",
        spell_391528 = "/cast [nochanneling]万灵之召",
        spell_106830 = "/cast [nochanneling]痛击",
        spell_8921 = "/cast [nochanneling]月火术",
        spell_768 = "/cast [noform:2]猎豹形态",
        spell_102543 = "/cast [nochanneling]化身：阿莎曼之灵",
        spell_2782 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]清除腐蚀",
        spell_8936 = "/cast [nochanneling]愈合",
        cd_106839 = "/cast [nochanneling]迎头痛击",
        spell_106839_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]迎头痛击",
        focus_interrupt = "/cast [nochanneling,@focus]迎头痛击",
        cd_61336 = "/cast [nochanneling]生存本能",
        cd_22812 = "/cast [nochanneling]树皮术",
        item_red_potion = "/use [nochanneling]item:271883\n/use [nochanneling]item:271884",
        item_burst_potion = "/use [nochanneling]item:241308\n/use [nochanneling]item:241309\n/use [nochanneling]item:241288\n/use [nochanneling]item:241289",
        item_healing_stone = "/use [nochanneling]item:5512",
        spell_1126 = "/cast 野性印记",
        spell_20484 = "/cast [@mouseover,help,dead] [help,dead] [@party1,dead] [@party2,dead] [@party3,dead] [@party4,dead] 复生",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        5221,
        1822,
        1079,
        22568,
        106785,
        285381,
        5217,
        106951,
        1243807,
        274837,
        391528,
        8921,
        20484,
        2782,
        8936,
    },
    ACTION_LABELS = {
        spell_5221 = "撕碎",
        spell_5221_nearest = "就近撕碎",
        spell_1822 = "斜掠",
        mouseover_rake = "指向斜掠",
        spell_1079 = "割裂",
        spell_22568 = "凶猛撕咬",
        spell_22568_nearest = "就近凶猛撕咬",
        spell_106785 = "横扫",
        spell_285381 = "原始之怒",
        spell_5217 = "猛虎之怒",
        spell_106951 = "狂暴",
        spell_1243807 = "怒意狂乱",
        spell_274837 = "野性狂乱",
        spell_391528 = "万灵之召",
        spell_106830 = "痛击",
        spell_8921 = "月火术",
        spell_768 = "猎豹形态",
        spell_102543 = "化身：阿莎曼之灵",
        spell_2782 = "清除腐蚀",
        spell_8936 = "愈合",
        cd_106839 = "迎头痛击",
        spell_106839_mouseover = "迎头痛击指向",
        focus_interrupt = "迎头痛击焦点",
        cd_61336 = "生存本能",
        cd_22812 = "树皮术",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        spell_1126 = "野性印记",
        spell_20484 = "复生",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_5221 = "F6",
        spell_5221_nearest = "9",
        spell_1822 = "F7",
        mouseover_rake = "0",
        spell_1079 = "F8",
        spell_22568 = "F9",
        spell_22568_nearest = "-",
        spell_106785 = "F10",
        spell_285381 = "8",
        spell_5217 = "F12",
        spell_106951 = "]",
        spell_1243807 = "[",
        spell_274837 = "CTRL-F8",
        spell_391528 = "'",
        spell_106830 = "F11",
        spell_8921 = "=",
        spell_768 = ",",
        spell_102543 = ";",
        spell_2782 = ".",
        spell_8936 = "CTRL-F10",
        cd_106839 = "\\",
        spell_106839_mouseover = "CTRL-F9",
        focus_interrupt = "INSERT",
        cd_61336 = "UP",
        cd_22812 = "DOWN",
        item_red_potion = "CTRL-F6",
        item_burst_potion = "DELETE",
        item_healing_stone = "CTRL-F7",
        spell_1126 = "LEFT",
        spell_20484 = "RIGHT",
        trinket1_cd = "HOME",
        trinket2_cd = "END",
    },
    macroOrder = {
        "spell_5221",
        "spell_5221_nearest",
        "spell_1822",
        "mouseover_rake",
        "spell_1079",
        "spell_22568",
        "spell_22568_nearest",
        "spell_106785",
        "spell_285381",
        "spell_5217",
        "spell_106951",
        "spell_102543",
        "spell_1243807",
        "spell_274837",
        "spell_391528",
        "spell_106830",
        "spell_8921",
        "spell_768",
        "spell_2782",
        "spell_8936",
        "cd_106839",
        "cd_61336",
        "cd_22812",
        "spell_106839_mouseover",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "spell_1126",
        "spell_20484",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 768, 1079, 1126, 1822, 5221, 8921, 20484, 22568, 106830, 285381, 8936 },
    OnSpellCast = function(spellID)
        local now = GetTime()
        if spellID == 5217 then
            tigersFuryAt = now
        elseif spellID == 106951 or spellID == 102543 then
            berserkAt = now
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local cat_form = 0
        pcall(function()
            cat_form = GetShapeshiftForm()
        end)
        values.cat_form = cat_form
        local tigersFuryRemains = 0
        if tigersFuryAt > 0 then
            local elapsed = GetTime() - tigersFuryAt
            if elapsed < TIGERS_FURY_DURATION then
                tigersFuryRemains = TIGERS_FURY_DURATION - elapsed
            else
                tigersFuryAt = 0
            end
        end
        values.buff_tf_remains = math.floor(tigersFuryRemains + 0.5)
        local berserkRemains = 0
        if berserkAt > 0 then
            local elapsed = GetTime() - berserkAt
            if elapsed < BERSERK_DURATION then
                berserkRemains = BERSERK_DURATION - elapsed
            else
                berserkAt = 0
            end
        end
        values.buff_berserk_remains = math.floor(berserkRemains + 0.5)
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
