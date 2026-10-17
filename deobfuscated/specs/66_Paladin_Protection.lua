--[[
  Paladin_Protection（防护骑士）—— 专精配置：防护骑士（specID 66）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：c22d2d.lua（TOC 第 75 个加载的插件脚本）

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
P8BA6426E.RegisterClass(66, {
    talentLoadouts = {
        {
            name = "ptr铸光者",
            importString = "CIEAzbn3egSOtoSwvPw1U1vTLsZYWGzYmZmZ22GjZZWmlZMAADAAAAAAaamZZmxMDDbtAgBGwMYDAAMz02MzyMzMLbLtMzYx2CzAYwMbYAwMz2MAzMgxC",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_275779 = "/cast 审判",
        spell_204019 = "/cast 祝福之锤",
        spell_53600 = "/cast 正义盾击",
        spell_85673 = "/cast [@player]荣耀圣令",
        spell_31935 = "/cast 复仇者之盾",
        focus_shield = "/cast [@mouseover,harm,nodead][]复仇者之盾",
        focus_word_of_glory = "/cast [@focus,help,nodead,exists]荣耀圣令",
        focus_lay_on_hands = "/cast [@focus,help,nodead,exists]圣疗术",
        focus_blessing_of_spellwarding = "/cast [@focus,help,nodead,exists]破咒祝福",
        focus_blessing_of_freedom = "/cast [@focus,help,nodead,exists]自由祝福",
        spell_375576 = "/cast 圣洁鸣钟",
        spell_31884 = "/cast 复仇之怒",
        spell_26573 = "/cast 奉献",
        cd_633 = "/cast [@player]圣疗术",
        spell_31850 = "/cast 炽热防御者",
        spell_86659 = "/cast 远古列王守卫",
        spell_432459 = "/cast 神圣壁垒",
        cd_642 = "/cast 圣盾术",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        cd_96231 = "/cast 责难",
        spell_96231_mouseover = "/cast [@mouseover,harm,nodead,exists] 责难",
        cd_6940 = "/cast [@focus,help,nodead,exists]牺牲祝福",
        cd_1044 = "/cast [@mouseover,help,nodead,exists][@player]自由祝福;自由祝福",
        cd_213644 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]清毒术",
        cd_1022 = "/cast [@focus,help,nodead,exists]保护祝福",
        cd_204018 = "/cast [@mouseover,help,nodead,exists]破咒祝福",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
    },
    testSpells = { 275779, 204019, 53600, 85673, 31935, 375576, 31884, 96231, 26573 },
    HEAL_FOCUS_SPELL_IDS = {
        [85673] = true,
        [633] = true,
        [204018] = true,
        [1044] = true,
        [6940] = true,
        [213644] = true,
        [1022] = true,
    },
    ACTION_LABELS = {
        spell_275779 = "审判",
        spell_204019 = "祝福之锤",
        spell_53600 = "正义盾击",
        spell_85673 = "荣耀圣令",
        spell_31935 = "复仇者之盾",
        focus_shield = "指向之盾",
        focus_word_of_glory = "焦点荣耀圣令",
        focus_lay_on_hands = "焦点圣疗术",
        focus_blessing_of_spellwarding = "焦点破咒祝福",
        focus_blessing_of_freedom = "焦点自由",
        spell_375576 = "圣洁鸣钟",
        spell_31884 = "复仇之怒",
        spell_26573 = "奉献",
        cd_633 = "圣疗术",
        spell_31850 = "炽热防御者",
        spell_86659 = "远古列王守卫",
        spell_432459 = "神圣壁垒",
        cd_642 = "圣盾术",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        cd_96231 = "责难",
        spell_96231_mouseover = "责难指向",
        cd_6940 = "牺牲祝福",
        cd_1044 = "自由祝福",
        cd_213644 = "清毒术",
        cd_1022 = "保护祝福",
        cd_204018 = "破咒祝福",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
    },
    ACTION_TO_KEY = {
        spell_275779 = "F6",
        spell_204019 = "F7",
        spell_53600 = "F8",
        spell_85673 = "F9",
        spell_31935 = "F11",
        focus_shield = "F12",
        focus_word_of_glory = "F10",
        focus_lay_on_hands = "'",
        focus_blessing_of_spellwarding = ".",
        focus_blessing_of_freedom = "UP",
        spell_375576 = "9",
        spell_31884 = "0",
        spell_26573 = "8",
        cd_633 = ";",
        spell_31850 = "-",
        spell_86659 = "=",
        spell_432459 = "[",
        cd_642 = "]",
        item_red_potion = "CTRL-F7",
        item_burst_potion = "DELETE",
        item_healing_stone = "CTRL-F6",
        cd_96231 = "INSERT",
        spell_96231_mouseover = "CTRL-9",
        cd_6940 = "DOWN",
        cd_1044 = "\\",
        cd_213644 = "LEFT",
        cd_1022 = "RIGHT",
        cd_204018 = ",",
        trinket1_cd = "HOME",
        trinket2_cd = "END",
        focus_player = "CTRL-F8",
        focus_party1 = "CTRL-F9",
        focus_party2 = "CTRL-F10",
        focus_party3 = "CTRL-F11",
        focus_party4 = "CTRL-F12",
        focus_mouseover = "CTRL-8",
    },
    macroOrder = {
        "spell_275779",
        "spell_204019",
        "spell_53600",
        "spell_85673",
        "spell_31935",
        "focus_shield",
        "focus_word_of_glory",
        "focus_lay_on_hands",
        "focus_blessing_of_spellwarding",
        "focus_blessing_of_freedom",
        "spell_375576",
        "spell_31884",
        "spell_26573",
        "cd_633",
        "spell_31850",
        "spell_86659",
        "spell_432459",
        "cd_642",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "cd_96231",
        "spell_96231_mouseover",
        "cd_6940",
        "cd_1044",
        "cd_213644",
        "cd_1022",
        "cd_204018",
        "trinket1_cd",
        "trinket2_cd",
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
    },
    testData = {},
    actionAvailSpellIDs = { 31884, 53600, 85673 },
    spellReadyAliases = { [53600] = { 1270617 } },
    GetExtraValues = function(values)
        local now = GetTime()
        local mouseover_health_pct = 100
        if
            UnitExists("mouseover")
            and (
                UnitIsFriend("player", "mouseover")
                and (not UnitIsDeadOrGhost("mouseover") and P8BA6426E.healthColorCurve)
            )
        then
            local ok, result = pcall(UnitHealthPercent, "mouseover", true, P8BA6426E.healthColorCurve)
            if ok and (type(result) == "table" and result.GetRGB) then
                mouseover_health_pct = result
            end
        end
        values.mouseover_health_pct = mouseover_health_pct
        values.focus_cast_unreachable = P8BA6426E.GetFocusCastUnreachable()
        values.focus_is_player = UnitExists("focus") and UnitIsUnit("focus", "player") or false
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
