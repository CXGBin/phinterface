--[[
  Evoker_Preservation（恩护唤魔师）—— 专精配置：恩护唤魔师（specID 1468）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：642c87.lua（TOC 第 61 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local party_tank_index = 0
local EMPOWER_SPELL_IDS = { 355936, 357208 }
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(1468, {
    talentLoadouts = {
        {
            name = "茨木塑焰者",
            importString = "CwbBAAAAAAAAAAAAAAAAAAAAAAAAAAAmZmZ2WGzYYMzsZGw2wAAAzYGzMjhZiZmBAAAMzMTGzMjxMzAAjZgFwGYGmAbM2MMAmZGD",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusAckPixel = "party_tank_index",
    raidFocusRangeSpellIDs = { 361469 },
    DEFAULT_MACROS = {
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
        spell_361469 = "/cast [nochanneling,@focus]活化烈焰",
        spell_361469_attack = "/cast [nochanneling]活化烈焰",
        spell_356995 = "/cast [nochanneling]裂解",
        spell_362969 = "/cast [nochanneling]碧蓝打击",
        spell_366155 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]逆转",
        spell_364343 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]回响",
        spell_360995 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]青翠之拥",
        spell_355936 = "/cast 梦境吐息",
        spell_357208 = "/cast 火焰吐息",
        spell_367226 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]精神之花",
        spell_355913 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]翡翠之花",
        spell_357170 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]时间膨胀",
        spell_370537 = "/cast [nochanneling]静滞",
        spell_363534 = "/cast [nochanneling]回溯",
        spell_359816 = "/cast [nochanneling]梦境飞行",
        spell_373861 = "/cast [nochanneling]时空畸体",
        spell_360823 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]自然平衡",
        spell_374251 = "/cast [nochanneling,@focus,help,nodead][nochanneling,@mouseover,help,nodead][nochanneling,@player]灼烧之焰",
        cd_363916 = "/cast [nochanneling]黑曜鳞片",
        item_red_potion = "/use [nochanneling] item:271883\n/use [nochanneling] item:271884",
        item_burst_potion = "/use [nochanneling] item:241308\n/use [nochanneling] item:241309\n/use [nochanneling] item:241288\n/use [nochanneling] item:241289",
        item_healing_stone = "/use [nochanneling] item:5512",
        trinket1_cd = "/use [nochanneling] 13",
        trinket2_cd = "/use [nochanneling] 14",
    },
    testSpells = {
        361469,
        356995,
        362969,
        366155,
        364343,
        360995,
        355936,
        357208,
        367226,
        355913,
        357170,
        370537,
        363534,
        359816,
        373861,
        360823,
        374251,
        363916,
    },
    HEAL_FOCUS_SPELL_IDS = {
        [361469] = true,
        [366155] = true,
        [364343] = true,
        [360995] = true,
        [367226] = true,
        [355913] = true,
        [357170] = true,
        [360823] = true,
        [374251] = true,
    },
    ACTION_LABELS = {
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
        spell_361469 = "焦点活化烈焰",
        spell_361469_attack = "进攻活化烈焰",
        spell_356995 = "裂解",
        spell_362969 = "碧蓝打击",
        spell_366155 = "逆转",
        spell_364343 = "回响",
        spell_360995 = "青翠之拥",
        spell_355936 = "梦境吐息",
        spell_357208 = "火焰吐息",
        spell_367226 = "精神之花",
        spell_355913 = "翡翠之花",
        spell_357170 = "时间膨胀",
        spell_370537 = "静滞",
        spell_363534 = "回溯",
        spell_359816 = "梦境飞行",
        spell_373861 = "时空畸体",
        spell_360823 = "自然平衡",
        spell_374251 = "灼烧之焰",
        cd_363916 = "黑曜鳞片",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        focus_player = "DELETE",
        focus_party1 = "HOME",
        focus_party2 = "END",
        focus_party3 = "CTRL-F6",
        focus_party4 = "CTRL-F7",
        focus_mouseover = "CTRL-F8",
        spell_361469 = "F6",
        spell_361469_attack = "F7",
        spell_356995 = "9",
        spell_362969 = "0",
        spell_366155 = "F8",
        spell_364343 = "F9",
        spell_360995 = "F10",
        spell_355936 = "F11",
        spell_357208 = "-",
        spell_367226 = "F12",
        spell_355913 = "8",
        spell_357170 = "]",
        spell_370537 = ";",
        spell_363534 = "'",
        spell_359816 = ",",
        spell_373861 = ".",
        spell_360823 = "=",
        spell_374251 = "[",
        cd_363916 = "\\",
        item_red_potion = "RIGHT",
        item_burst_potion = "UP",
        item_healing_stone = "INSERT",
        trinket1_cd = "DOWN",
        trinket2_cd = "LEFT",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "spell_361469",
        "spell_361469_attack",
        "spell_356995",
        "spell_362969",
        "spell_366155",
        "spell_364343",
        "spell_360995",
        "spell_355936",
        "spell_357208",
        "spell_367226",
        "spell_355913",
        "spell_357170",
        "spell_370537",
        "spell_363534",
        "spell_359816",
        "spell_373861",
        "spell_360823",
        "spell_374251",
        "cd_363916",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 355913, 356995, 361469, 362969, 364343, 374251 },
    spellReadyAliases = { [356995] = { 1236949 }, [362969] = { 1237211 } },
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
        local empower_spell_id, empower_stage, empower_max_stage = P8BA6426E.GetPlayerEmpowerState(EMPOWER_SPELL_IDS)
        values.empower_spell_id = empower_spell_id
        values.empower_stage = empower_stage
        values.empower_max_stage = empower_max_stage
        values.focus_cast_unreachable = P8BA6426E.GetFocusCastUnreachable()
    end,
})
