--[[
  Paladin_Holy（神圣骑士）—— 专精配置：神圣骑士（specID 65）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：72728f.lua（TOC 第 63 个加载的插件脚本）

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
P8BA6426E.RegisterClass(65, {
    talentLoadouts = {
        {
            name = "茨木铸光者四件套",
            importString = "CEEAzbn3egSOtoSwvPw1U1vTLAAAALAwMAADWGGmZ2mZmFjZMsM2MziZaihxMzwY2yAwAwGYjNzMWmthRAAzMLbLWmZYjtxMYDYGzwAwMDGYGjRDA",
        },
        {
            name = "茨木烈日美德",
            importString = "CEEAzbn3egSOtoSwvPw1U1vTLAAAALAwMAAD2GzMzMjZmZBmZYZsZmFjmYYMzMMmtMAMAsB2YZmZmlZbmZ2aAAAAWAGsZgZMDzAAYmhZMGNA",
        },
        {
            name = "茨木团本",
            importString = "CEEAzbn3egSOtoSwvPw1U1vTLAAAALAwMAAD2GzMzMjZmZBmZYZsZmFjmYYMzMMmtMAMAsB2YZmZmlZbmZ2aAAAAWAGsZgZMDzAAYmhZMGNA",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusRangeSpellIDs = { 19750 },
    DEFAULT_MACROS = {
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,help,exists,nodead]",
        cd_31821 = "/cast [nochanneling] 光环掌握",
        spell_85222 = "/cast [nochanneling,@focus,help,nodead] 黎明之光",
        spell_415091 = "/cast [nochanneling,harm,nodead] 正义盾击",
        spell_82326 = "/cast [nochanneling,@focus,help,nodead] 圣光术",
        spell_156322 = "/cast [nochanneling,@focus,help,nodead] 永恒之火",
        cd_4987 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]清洁术",
        cd_375576 = "/cast [nochanneling,@focus,help,nodead] 圣洁鸣钟",
        cd_31884 = "/cast [nochanneling] 复仇之怒",
        cd_200025 = "/cast [nochanneling] 美德道标",
        cd_1044 = "/cast [nochanneling,@focus,help,nodead,exists]自由祝福",
        spell_20473 = "/cast [nochanneling,@focus,help,nodead] 神圣震击",
        spell_20473_harm = "/cast [nochanneling,harm,nodead] 神圣震击",
        spell_275773 = "/cast [nochanneling,harm,nodead] 审判",
        spell_19750 = "/cast [nochanneling,@focus,help,nodead] 圣光闪现",
        cd_633 = "/cast [nochanneling,@focus,help,nodead,exists]圣疗术",
        cd_6940 = "/cast [nochanneling,@focus,help,nodead,exists]牺牲祝福",
        cd_1022 = "/cast [nochanneling,@focus,help,nodead,exists]保护祝福",
        cd_642 = "/cast [nochanneling] 圣盾术",
        cd_498 = "/cast [nochanneling] 圣佑术",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        spell_85673 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]荣耀圣令",
    },
    testSpells = {
        31821,
        85222,
        498,
        415091,
        82326,
        156322,
        4987,
        375576,
        31884,
        200025,
        1044,
        20473,
        275773,
        19750,
        633,
        6940,
        642,
    },
    HEAL_FOCUS_SPELL_IDS = {
        [85222] = true,
        [82326] = true,
        [156322] = true,
        [4987] = true,
        [375576] = true,
        [1044] = true,
        [20473] = true,
        [19750] = true,
        [633] = true,
        [6940] = true,
        [1022] = true,
        [85673] = true,
    },
    ACTION_LABELS = {
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
        cd_31821 = "光环掌握",
        spell_85222 = "黎明之光",
        spell_415091 = "正义盾击",
        spell_82326 = "圣光术",
        spell_156322 = "永恒之火",
        cd_4987 = "清洁术",
        cd_375576 = "圣洁鸣钟",
        cd_31884 = "复仇之怒",
        cd_200025 = "美德道标",
        cd_1044 = "自由祝福",
        spell_20473 = "神圣震击",
        spell_20473_harm = "攻击震击",
        spell_275773 = "审判",
        spell_19750 = "圣光闪现",
        cd_633 = "圣疗术",
        cd_6940 = "牺牲祝福",
        cd_1022 = "保护祝福",
        cd_642 = "圣盾术",
        cd_498 = "圣佑术",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        spell_85673 = "荣耀圣令",
    },
    ACTION_TO_KEY = {
        focus_player = "HOME",
        focus_party1 = "END",
        focus_party2 = "CTRL-F6",
        focus_party3 = "CTRL-F7",
        focus_party4 = "CTRL-F8",
        focus_mouseover = "CTRL-F9",
        cd_31821 = ";",
        spell_85222 = "F9",
        spell_415091 = "8",
        spell_82326 = "F10",
        spell_156322 = "F12",
        cd_4987 = "-",
        cd_375576 = "[",
        cd_31884 = "]",
        cd_200025 = "0",
        cd_1044 = "=",
        spell_20473 = "F6",
        spell_20473_harm = "F7",
        spell_275773 = "9",
        spell_19750 = "F11",
        cd_633 = "'",
        cd_6940 = ",",
        cd_1022 = ".",
        cd_642 = "\\",
        cd_498 = "UP",
        item_red_potion = "INSERT",
        item_burst_potion = "DOWN",
        item_healing_stone = "DELETE",
        trinket1_cd = "LEFT",
        trinket2_cd = "RIGHT",
        spell_85673 = "F8",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "cd_31821",
        "spell_85222",
        "spell_415091",
        "spell_82326",
        "spell_156322",
        "cd_4987",
        "cd_375576",
        "cd_31884",
        "cd_200025",
        "cd_1044",
        "spell_20473",
        "spell_20473_harm",
        "spell_275773",
        "spell_19750",
        "cd_633",
        "cd_6940",
        "cd_1022",
        "cd_642",
        "cd_498",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
        "spell_85673",
    },
    actionAvailSpellIDs = { 19750, 82326, 85222, 85673, 156322, 415091 },
    spellReadyAliases = { [415091] = { 1270617 } },
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
    testData = {},
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
        pcall(function() end)
        pcall(function() end)
        values.focus_cast_unreachable = P8BA6426E.GetFocusCastUnreachable()
        values.focus_is_player = false
    end,
})
