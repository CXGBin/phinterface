--[[
  Priest_Holy（神圣牧师）—— 专精配置：神圣牧师（specID 257）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：3552aa.lua（TOC 第 52 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local party_tank_index = 0
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(257, {
    talentLoadouts = {
        {
            name = "茨木神谕者",
            importString = "CEQAAAAAAAAAAAAAAAAAAAAAAwYAAAAAAAbGzYWGzwMjhZYsMzMzAAAAYYWmhZmZGmhZMgZKAmZBDhxsMAjBWMzMAYGzMGDmBYmZGYA",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusAckPixel = "party_tank_index",
    raidFocusRangeSpellIDs = { 2061 },
    DEFAULT_MACROS = {
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
        spell_2061 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]快速治疗",
        spell_2060 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]治疗术",
        spell_33076 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]愈合祷言",
        spell_596 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]治疗祷言",
        spell_2050 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player] 圣言术：静",
        spell_34861 = "/cast [nochanneling,@cursor]圣言术：灵",
        spell_88625 = "/cast [nochanneling]圣言术：罚",
        spell_200183 = "/cast [nochanneling]神圣化身",
        cd_47788 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]守护之魂",
        cd_64843 = "/cast [nochanneling]神圣赞美诗",
        cd_19236 = "/cast [nochanneling]绝望祷言",
        cd_527 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]纯净术",
        spell_528 = "/cast [nochanneling,target=mouseover][nochanneling]驱散魔法",
        spell_585 = "/cast [nochanneling]惩击",
        spell_589 = "/cast [nochanneling]暗言术：痛",
        spell_14914 = "/cast [nochanneling]神圣之火",
        spell_132157 = "/cast [nochanneling]神圣新星",
        spell_120517 = "/cast [nochanneling]光晕",
        spell_10060 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]能量灌注",
        spell_32379 = "/cast [nochanneling]暗言术：灭",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        2061,
        2060,
        33076,
        596,
        2050,
        34861,
        88625,
        200183,
        47788,
        64843,
        19236,
        527,
        528,
        585,
        589,
        14914,
        132157,
        120517,
        10060,
        32379,
    },
    HEAL_FOCUS_SPELL_IDS = {
        [2061] = true,
        [2060] = true,
        [33076] = true,
        [596] = true,
        [2050] = true,
        [47788] = true,
        [527] = true,
        [10060] = true,
    },
    ACTION_LABELS = {
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
        spell_2061 = "快速治疗",
        spell_2060 = "治疗术",
        spell_33076 = "愈合祷言",
        spell_596 = "治疗祷言",
        spell_2050 = "圣言术：静",
        spell_34861 = "圣言术：灵",
        spell_88625 = "圣言术：罚",
        spell_200183 = "神圣化身",
        cd_47788 = "守护之魂",
        cd_64843 = "神圣赞美诗",
        cd_19236 = "绝望祷言",
        cd_527 = "纯净术",
        spell_528 = "驱散魔法",
        spell_585 = "惩击",
        spell_589 = "暗言术：痛",
        spell_14914 = "神圣之火",
        spell_132157 = "神圣新星",
        spell_120517 = "光晕",
        spell_10060 = "能量灌注",
        spell_32379 = "暗言术：灭",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        focus_player = "HOME",
        focus_party1 = "END",
        focus_party2 = "CTRL-F6",
        focus_party3 = "CTRL-F7",
        focus_party4 = "CTRL-F8",
        focus_mouseover = "CTRL-F9",
        spell_2061 = "F6",
        spell_2060 = "F7",
        spell_33076 = "F8",
        spell_596 = "F9",
        spell_2050 = "F10",
        spell_34861 = "F11",
        spell_88625 = "F12",
        spell_200183 = "]",
        cd_47788 = ";",
        cd_64843 = "'",
        cd_19236 = "UP",
        cd_527 = ".",
        spell_528 = "\\",
        spell_585 = "8",
        spell_589 = "9",
        spell_14914 = "0",
        spell_132157 = "-",
        spell_120517 = "=",
        spell_10060 = ",",
        spell_32379 = "[",
        item_red_potion = "INSERT",
        item_burst_potion = "DOWN",
        item_healing_stone = "DELETE",
        trinket1_cd = "LEFT",
        trinket2_cd = "RIGHT",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "spell_2061",
        "spell_2060",
        "spell_33076",
        "spell_596",
        "spell_2050",
        "spell_34861",
        "spell_88625",
        "spell_200183",
        "cd_47788",
        "cd_64843",
        "cd_19236",
        "cd_527",
        "spell_528",
        "spell_585",
        "spell_589",
        "spell_14914",
        "spell_132157",
        "spell_120517",
        "spell_10060",
        "spell_32379",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 528, 585, 589, 596, 2060, 2061, 34861, 132157 },
    spellReadyAliases = { [2061] = { 1233784 } },
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
    GetExtraValues = function(values)
        if not InCombatLockdown() then
            local tankIndex = 0
            for i = 1, 4, 1 do
                local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("party" .. i) or "NONE"
                if role == "TANK" then
                    tankIndex = i
                    break
                end
            end
            party_tank_index = tankIndex
        end
        values.party_tank_index = party_tank_index
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
    end,
})
