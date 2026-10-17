--[[
  Monk_Windwalker（踏风武僧）—— 专精配置：踏风武僧（specID 269）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：273527.lua（TOC 第 50 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local combo_strike = 0
local COMBO_STRIKE_SPELLS = {
    [100780] = 1,
    [100784] = 2,
    [113656] = 3,
    [152175] = 4,
    [101546] = 5,
    [322109] = 6,
    [1249625] = 7,
    [1272696] = 7,
    [443028] = 9,
    [117952] = 10,
    [107428] = 11,
}
local xuanjiStartedAt = nil
local XUANJI_DURATION = 20
local function getXuanjiRemaining()
    if not xuanjiStartedAt then
        return 0
    end
    return math.max(0, XUANJI_DURATION - (GetTime() - xuanjiStartedAt))
end
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(269, {
    talentLoadouts = {
        {
            name = "雾中踏风",
            importString = "C0QAQnG51S19isUJoJoTeJ/IKPzYAjxYZmZ2mBAAAAAAAAAAAYZY0MmhhxgxMMzMzwshZYWegJAgFzsNmxYmZgAYxMLz2YaWmlmZmZBYMDMzMDAGwYmZ2M",
        },
        {
            name = "天神御师pro",
            importString = "C0QAQnG51S19isUJoJoTeJ/IKPzYM2GGjlZmZbGAAAAAAAAAAAglhxMjZYYAzYYmZmhZbYGmlZGAgFzsNmxMzMDEALmllZbMDEAgxAYGAWGAzMzmHE",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_100780 = "/cast [nochanneling:怒雷破,神鹤引项踢] 猛虎掌",
        spell_100784 = "/cast [nochanneling:怒雷破,神鹤引项踢] 幻灭踢",
        spell_107428 = "/cast [nochanneling:怒雷破,神鹤引项踢] 旭日东升踢",
        spell_101546 = "/cast [nochanneling:怒雷破,神鹤引项踢] 神鹤引项踢",
        spell_113656 = "/cast [nochanneling:怒雷破] 怒雷破",
        spell_322109 = "/cast [@mouseover,harm,nodead] [] 轮回之触",
        spell_117952 = "/cast [nochanneling:怒雷破,神鹤引项踢] 碎玉闪电",
        spell_1249625 = "/cast [nochanneling:怒雷破,神鹤引项踢] 乾元之巅",
        spell_152175 = "/cast [nochanneling:怒雷破,神鹤引项踢] 升龙霸",
        spell_123904 = "/cast [nochanneling:怒雷破,神鹤引项踢] 白虎下凡",
        spell_392983 = "/cast [nochanneling:怒雷破,神鹤引项踢] 风领主之击",
        spell_116670 = "/cast [@player,nochanneling:怒雷破,神鹤引项踢] 活血术",
        spell_218164 = "/cast [nochanneling:怒雷破,神鹤引项踢,@mouseover,help,nodead] 清创生血",
        spell_218164_player = "/cast [nochanneling:怒雷破,神鹤引项踢,@player] 清创生血",
        spell_100780_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling:怒雷破,神鹤引项踢,harm] 猛虎掌\n/targetlasttarget",
        spell_100784_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling:怒雷破,神鹤引项踢,harm] 幻灭踢\n/targetlasttarget",
        spell_107428_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling:怒雷破,神鹤引项踢,harm] 旭日东升踢\n/targetlasttarget",
        cd_122470 = "/cast [nochanneling:怒雷破,神鹤引项踢] 业报之触",
        cd_115203 = "/cast [nochanneling:怒雷破,神鹤引项踢] 壮胆酒",
        cd_116705 = "/cast [nochanneling:怒雷破,神鹤引项踢] 切喉手",
        spell_116705_mouseover = "/cast [nochanneling:怒雷破,神鹤引项踢,@mouseover,harm,nodead,exists] 切喉手",
        focus_interrupt = "/cast [nochanneling:怒雷破,神鹤引项踢,@focus]切喉手",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        100780,
        100784,
        107428,
        101546,
        113656,
        322109,
        117952,
        1249625,
        152175,
        123904,
        392983,
        116670,
        218164,
    },
    ACTION_LABELS = {
        spell_100780 = "猛虎掌",
        spell_100784 = "幻灭踢",
        spell_107428 = "旭日东升踢",
        spell_101546 = "神鹤引项踢",
        spell_113656 = "怒雷破",
        spell_322109 = "轮回之触",
        spell_117952 = "碎玉闪电",
        spell_1249625 = "乾元之巅",
        spell_152175 = "升龙霸",
        spell_123904 = "白虎下凡",
        spell_392983 = "风领主之击",
        spell_116670 = "活血术",
        spell_218164 = "指向清创生血",
        spell_218164_player = "自身清创生血",
        spell_100780_nearest = "就近猛虎掌",
        spell_100784_nearest = "就近幻灭踢",
        spell_107428_nearest = "就近旭日东升踢",
        cd_122470 = "业报之触",
        cd_115203 = "壮胆酒",
        cd_116705 = "切喉手",
        spell_116705_mouseover = "切喉手指向",
        focus_interrupt = "切喉手焦点",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_100780 = "F6",
        spell_100784 = "F7",
        spell_107428 = "F8",
        spell_101546 = "F9",
        spell_113656 = "F10",
        spell_322109 = "=",
        spell_117952 = "[",
        spell_1249625 = "8",
        spell_152175 = "F12",
        spell_123904 = "]",
        spell_392983 = "F11",
        spell_116670 = ";",
        spell_218164 = "HOME",
        spell_218164_player = "END",
        spell_100780_nearest = "9",
        spell_100784_nearest = "0",
        spell_107428_nearest = "-",
        item_burst_potion = "\\",
        cd_122470 = "'",
        cd_115203 = ",",
        cd_116705 = ".",
        spell_116705_mouseover = "DELETE",
        focus_interrupt = "INSERT",
        item_red_potion = "LEFT",
        item_healing_stone = "RIGHT",
        trinket1_cd = "UP",
        trinket2_cd = "DOWN",
    },
    macroOrder = {
        "spell_100780",
        "spell_100784",
        "spell_107428",
        "spell_101546",
        "spell_113656",
        "spell_322109",
        "spell_117952",
        "spell_1249625",
        "spell_152175",
        "spell_123904",
        "spell_392983",
        "spell_116670",
        "spell_218164",
        "spell_218164_player",
        "spell_100780_nearest",
        "spell_100784_nearest",
        "spell_107428_nearest",
        "cd_122470",
        "cd_115203",
        "cd_116705",
        "spell_116705_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    cooldownKnownCheckExemptions = { [443028] = true },
    actionAvailSpellIDs = { 100780, 100784, 101546, 116670, 117952, 152175 },
    spellReadyAliases = { [100780] = { 1251114 }, [101546] = { 1250997, 1250999 } },
    OverrideChargeDisplayCount = function(spellID)
        if spellID == 1249625 and getXuanjiRemaining() > 0 then
            return 0
        end
        return nil
    end,
    OnSpellCast = function(spellID)
        local now = GetTime()
        local entry = COMBO_STRIKE_SPELLS[spellID]
        if entry then
            combo_strike = entry
        end
        if spellID == 1249625 then
            xuanjiStartedAt = now
        end
    end,
    GetExtraValues = function(values)
        values.combo_strike = combo_strike
        values.xuanji_remains = math.ceil(getXuanjiRemaining())
        local conduit_channel_state = 2
        if P8BA6426E.GetPlayerChannelWindowState then
            local isChanneling, inWindow, reliable = P8BA6426E.GetPlayerChannelWindowState(443028, 0, 1)
            if reliable then
                conduit_channel_state = isChanneling and 1 or 0
            end
        end
        values.conduit_channel_state = conduit_channel_state
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
