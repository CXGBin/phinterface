--[[
  Monk_Mistweaver（织雾武僧）—— 专精配置：织雾武僧（specID 270）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：46c611.lua（TOC 第 57 个加载的插件脚本）

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
P8BA6426E.RegisterClass(270, {
    talentLoadouts = {
        {
            name = "ptr茨木",
            importString = "C4QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAghxyMLjZx2MmZsZstsMjZ2Mz2yyMjFmRzYGwgBwMzMDzGmhZZmAAAAAAgFbzsMbzMAAwgBgZAjBWkxMA",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusAckPixel = "party_tank_index",
    raidFocusRangeSpellIDs = { 116670 },
    DEFAULT_MACROS = {
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
        heal_vivify = "/cast [nochanneling:天神御身,@focus,help,nodead] 活血术",
        heal_enveloping_mist = "/cast [nochanneling:天神御身,@focus,help,nodead] 氤氲之雾",
        heal_renewing_mist = "/cast [nochanneling:天神御身,@focus,help,nodead] 复苏之雾",
        heal_spread_renewing_mist = "/castsequence [@party2] reset=3 复苏之雾,null\n/castsequence [@party4] reset=3 复苏之雾,复苏之雾,null\n/castsequence [@party3] reset=3 复苏之雾,复苏之雾,复苏之雾,null",
        spell_essence_font = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]清创生血",
        spell_revival = "/cast [nochanneling:天神御身] 还魂术",
        spell_399491 = "/cast [nochanneling:天神御身] 抚慰之雾",
        spell_443028 = "/cast [nochanneling:天神御身] 天神御身",
        cd_322118 = "/cast [nochanneling:天神御身] 青龙下凡",
        spell_107428 = "/cast [nochanneling:天神御身] 旭日东升踢",
        spell_107428_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling:天神御身,harm] 旭日东升踢\n/targetlasttarget",
        spell_100784 = "/cast [nochanneling:天神御身] 幻灭踢",
        spell_100784_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling:天神御身,harm] 幻灭踢\n/targetlasttarget",
        spell_100780 = "/cast [nochanneling:天神御身] 猛虎掌",
        spell_100780_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling:天神御身,harm] 猛虎掌\n/targetlasttarget",
        spell_101546 = "/cast [nochanneling:天神御身] 神鹤引项踢",
        cd_116849 = "/cast [nochanneling:天神御身,@focus,help,nodead] 作茧缚命",
        cd_116680 = "/cast [nochanneling:天神御身] 雷光聚神茶",
        cd_325197 = "/cast [nochanneling:天神御身] 朱鹤下凡",
        cd_115203 = "/cast [nochanneling:天神御身] 壮胆酒",
        cd_115294 = "/cast [nochanneling:天神御身] 法力茶",
        spell_expel_harm = "/cast [nochanneling:天神御身,@player] 移花接木",
        spell_322109 = "/cast [@mouseover,harm,nodead] [] 轮回之触",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        116670,
        124682,
        115151,
        191837,
        115310,
        399491,
        443028,
        322118,
        107428,
        100784,
        100780,
        101546,
        116849,
        116680,
        325197,
        115203,
        115294,
        322101,
        322109,
    },
    HEAL_FOCUS_SPELL_IDS = { [116670] = true, [124682] = true, [115151] = true, [115450] = true, [116849] = true },
    ACTION_LABELS = {
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
        heal_vivify = "活血术",
        heal_enveloping_mist = "氤氲之雾",
        heal_renewing_mist = "复苏之雾",
        heal_spread_renewing_mist = "铺复苏",
        spell_essence_font = "清创生血",
        spell_revival = "还魂术",
        spell_399491 = "抚慰之雾",
        spell_443028 = "天神御身",
        cd_322118 = "青龙下凡",
        spell_107428 = "旭日东升踢",
        spell_107428_nearest = "就近旭日东升踢",
        spell_100784 = "幻灭踢",
        spell_100784_nearest = "就近幻灭踢",
        spell_100780 = "猛虎掌",
        spell_100780_nearest = "就近猛虎掌",
        spell_101546 = "神鹤引项踢",
        cd_116849 = "作茧缚命",
        cd_116680 = "雷光聚神茶",
        cd_325197 = "朱鹤下凡",
        cd_115203 = "壮胆酒",
        cd_115294 = "法力茶",
        spell_expel_harm = "移花接木",
        spell_322109 = "轮回之触",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        focus_player = "CTRL-F7",
        focus_party1 = "CTRL-F8",
        focus_party2 = "CTRL-F9",
        focus_party3 = "CTRL-F10",
        focus_party4 = "CTRL-F11",
        focus_mouseover = "CTRL-F12",
        heal_vivify = "F8",
        heal_enveloping_mist = "F9",
        heal_renewing_mist = "F6",
        heal_spread_renewing_mist = "F7",
        spell_essence_font = "F11",
        spell_revival = ";",
        spell_399491 = "F10",
        spell_443028 = "'",
        cd_322118 = ",",
        spell_107428 = "F12",
        spell_107428_nearest = "=",
        spell_100784 = "8",
        spell_100784_nearest = "[",
        spell_100780 = "9",
        spell_100780_nearest = "]",
        spell_101546 = "0",
        cd_116849 = "\\",
        cd_116680 = "UP",
        cd_325197 = "DOWN",
        cd_115203 = "RIGHT",
        cd_115294 = "LEFT",
        spell_expel_harm = "-",
        spell_322109 = ".",
        item_red_potion = "END",
        item_burst_potion = "INSERT",
        item_healing_stone = "CTRL-F6",
        trinket1_cd = "DELETE",
        trinket2_cd = "HOME",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "heal_vivify",
        "heal_enveloping_mist",
        "heal_renewing_mist",
        "heal_spread_renewing_mist",
        "spell_essence_font",
        "spell_revival",
        "spell_399491",
        "spell_443028",
        "cd_322118",
        "spell_107428",
        "spell_107428_nearest",
        "spell_100784",
        "spell_100784_nearest",
        "spell_100780",
        "spell_100780_nearest",
        "spell_101546",
        "cd_116849",
        "cd_116680",
        "cd_325197",
        "cd_115203",
        "cd_115294",
        "spell_expel_harm",
        "spell_322109",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 100780, 101546, 399491 },
    spellReadyAliases = { [100780] = { 1251114 }, [101546] = { 1250997, 1250999 } },
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
        local now = GetTime()
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
