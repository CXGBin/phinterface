--[[
  Druid_Restoration（恢复德鲁伊）—— 专精配置：恢复德鲁伊（specID 105）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：37634a.lua（TOC 第 53 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local party_tank_index = 0
local soulOfForestStartedAt = 0
local lastHealCastSpellID = 0
local lastHealCastAt = 0
local ironbarkReadyAt = 0
local SOUL_OF_FOREST_DURATION = 15
local IRONBARK_COOLDOWN = 180
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(105, {
    talentLoadouts = {
        {
            name = "丛林守护者茨木",
            importString = "CkGAAAAAAAAAAAAAAAAAAAAAAMMmxYmZmZMbzMYMbMb2mBAAAAAAAAAALGa2mZMNzAMLmZmxihxAAAAAYAAzAstNWw0MzyAAAAYBzMPwwMzGoZAwMDAYA",
        },
        {
            name = "荒野追猎者茨木",
            importString = "CkGAAAAAAAAAAAAAAAAAAAAAAMMmZZMjZmxsNMMmFmFbzAAAAAAAAAAglBNbmx0MjBmlZmZmhhZAAAAAAAgBAAAAAz2MLNbzsZjxMzwMDMaGAgZGAGA",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusAckPixel = "party_tank_index",
    raidFocusRangeSpellIDs = { 8936 },
    DEFAULT_MACROS = {
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        spell_774 = "/cast [nochanneling,@focus,help,nodead] 回春术",
        heal_rejuvenation_player = "/cast [nochanneling,@player,help,nodead] 回春术",
        heal_rejuvenation_party1 = "/cast [nochanneling,@party1,help,nodead] 回春术",
        heal_rejuvenation_party2 = "/cast [nochanneling,@party2,help,nodead] 回春术",
        heal_rejuvenation_party3 = "/cast [nochanneling,@party3,help,nodead] 回春术",
        heal_rejuvenation_party4 = "/cast [nochanneling,@party4,help,nodead] 回春术",
        spell_8936 = "/cast [nochanneling,@focus,help,nodead] 愈合",
        spell_33763 = "/cast [nochanneling,@player,help,nodead] 生命绽放",
        spell_48438 = "/cast [nochanneling,@focus,help,nodead] 野性成长",
        spell_18562 = "/cast [nochanneling,@focus,help,nodead] 迅捷治愈",
        spell_18562_player = "/cast [nochanneling, @player] 迅捷治愈",
        spell_145205 = "/cast [nochanneling,@cursor] 百花齐放",
        cd_132158 = "/cast [nochanneling] 自然迅捷",
        cd_102342 = "/cast [nochanneling,@focus,help,nodead] 铁木树皮",
        cd_740 = "/cast [nochanneling] 宁静",
        cd_29166 = "/cast [@player] 激活",
        cd_33891 = "/cast [nochanneling] 化身：生命之树",
        cd_391528 = "/cast [nochanneling] 万灵之召",
        cd_88423 = "/cast [nochanneling,@focus,help,nodead] 自然之愈",
        cd_22812 = "/cast [nochanneling] 树皮术",
        spell_1126 = "/cast 野性印记",
        spell_20484 = "/cast [@mouseover,help,dead] [help,dead] [@party1,dead] [@party2,dead] [@party3,dead] [@party4,dead] 复生",
        spell_197628 = "/cast [nochanneling]星火术",
        spell_197626 = "/cast [nochanneling]星涌术",
        spell_93402 = "/cast [nochanneling]阳炎术",
        spell_5176 = "/cast [nochanneling]愤怒",
        spell_8921 = "/cast [nochanneling]月火术",
        mouseover_moonfire = "/cast [nochanneling,@mouseover,harm,nodead]月火术",
        spell_1822 = "/cast [nochanneling]斜掠",
        spell_1079 = "/cast [nochanneling]割裂",
        spell_22568 = "/cast [nochanneling]凶猛撕咬",
        spell_22568_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]凶猛撕咬\n/targetlasttarget",
        spell_768 = "/cast [noform:2,nochanneling] 猎豹形态",
        spell_24858 = "/cast [noform:4] 枭兽形态",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        774,
        8936,
        33763,
        48438,
        18562,
        145205,
        132158,
        102342,
        740,
        29166,
        33891,
        391528,
        88423,
        22812,
        1126,
        20484,
        197628,
        197626,
        93402,
        5176,
        8921,
        1822,
        1079,
        22568,
        768,
        24858,
    },
    HEAL_FOCUS_SPELL_IDS = {
        [774] = true,
        [8936] = true,
        [48438] = true,
        [18562] = true,
        [102342] = true,
        [88423] = true,
    },
    ACTION_LABELS = {
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        spell_774 = "回春术",
        heal_rejuvenation_player = "回春术：自己",
        heal_rejuvenation_party1 = "回春术：队友1",
        heal_rejuvenation_party2 = "回春术：队友2",
        heal_rejuvenation_party3 = "回春术：队友3",
        heal_rejuvenation_party4 = "回春术：队友4",
        spell_8936 = "愈合",
        spell_33763 = "生命绽放",
        spell_48438 = "野性成长",
        spell_18562 = "迅捷治愈",
        spell_18562_player = "自我迅捷治愈",
        spell_145205 = "百花齐放",
        cd_132158 = "自然迅捷",
        cd_102342 = "铁木树皮",
        cd_740 = "宁静",
        cd_29166 = "激活",
        cd_33891 = "化身：生命之树",
        cd_391528 = "万灵之召",
        cd_88423 = "自然之愈",
        cd_22812 = "树皮术",
        spell_1126 = "野性印记",
        spell_20484 = "复生",
        spell_197628 = "星火术",
        spell_197626 = "星涌术",
        spell_93402 = "阳炎术",
        spell_5176 = "愤怒",
        spell_8921 = "月火术",
        mouseover_moonfire = "指向月火",
        spell_1822 = "斜掠",
        spell_1079 = "割裂",
        spell_22568 = "凶猛撕咬",
        spell_22568_nearest = "就近凶猛撕咬",
        spell_768 = "猎豹形态",
        spell_24858 = "枭兽形态",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        focus_player = "CTRL-=",
        focus_party1 = "CTRL-[",
        focus_party2 = "CTRL-]",
        focus_party3 = "CTRL-;",
        focus_party4 = "CTRL-'",
        focus_mouseover = "CTRL-,",
        item_red_potion = "CTRL-0",
        item_burst_potion = "CTRL-F12",
        item_healing_stone = "CTRL--",
        spell_774 = "F6",
        heal_rejuvenation_player = "F7",
        heal_rejuvenation_party1 = "F8",
        heal_rejuvenation_party2 = "F9",
        heal_rejuvenation_party3 = "F10",
        heal_rejuvenation_party4 = "F11",
        spell_8936 = "F12",
        spell_33763 = "8",
        spell_48438 = "9",
        spell_18562 = "0",
        spell_18562_player = "-",
        spell_145205 = "=",
        cd_132158 = "INSERT",
        cd_102342 = "RIGHT",
        cd_740 = "CTRL-F6",
        cd_29166 = "CTRL-F8",
        cd_33891 = "CTRL-F7",
        cd_391528 = "END",
        cd_88423 = "LEFT",
        cd_22812 = "CTRL-F9",
        spell_1126 = "CTRL-F10",
        spell_20484 = "CTRL-F11",
        spell_197628 = "'",
        spell_197626 = ",",
        spell_93402 = "[",
        spell_5176 = ";",
        spell_8921 = "]",
        mouseover_moonfire = "ALT-]",
        spell_1822 = ".",
        spell_1079 = "\\",
        spell_22568 = "UP",
        spell_22568_nearest = "DOWN",
        spell_768 = "DELETE",
        spell_24858 = "HOME",
        trinket1_cd = "CTRL-8",
        trinket2_cd = "CTRL-9",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "spell_774",
        "heal_rejuvenation_player",
        "heal_rejuvenation_party1",
        "heal_rejuvenation_party2",
        "heal_rejuvenation_party3",
        "heal_rejuvenation_party4",
        "spell_8936",
        "spell_33763",
        "spell_48438",
        "spell_18562",
        "spell_18562_player",
        "spell_145205",
        "cd_132158",
        "cd_102342",
        "cd_740",
        "cd_29166",
        "cd_33891",
        "cd_391528",
        "cd_88423",
        "cd_22812",
        "spell_1126",
        "spell_20484",
        "spell_197628",
        "spell_197626",
        "spell_93402",
        "spell_5176",
        "spell_8921",
        "mouseover_moonfire",
        "spell_1822",
        "spell_1079",
        "spell_22568",
        "spell_22568_nearest",
        "spell_768",
        "spell_24858",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = {
        768,
        774,
        1079,
        1126,
        1822,
        5176,
        8921,
        8936,
        20484,
        22568,
        24858,
        33763,
        93402,
        145205,
        197628,
    },
    spellReadyAliases = { [8936] = { 1236647, 1264664 }, [33763] = { 1227806 }, [145205] = { 1232285 } },
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
    OnSpellCast = function(spellID)
        local now = GetTime()
        if spellID == 33891 then
            ironbarkReadyAt = now + IRONBARK_COOLDOWN
        end
        if
            (spellID == 18562 or spellID == 8936 or spellID == 774)
            and (lastHealCastSpellID ~= spellID or (now - lastHealCastAt) >= 0.5)
        then
            lastHealCastSpellID = spellID
            lastHealCastAt = now
            if spellID == 18562 then
                soulOfForestStartedAt = now
            else
                soulOfForestStartedAt = 0
            end
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local soulOfForestRemains = 0
        if soulOfForestStartedAt > 0 then
            local elapsed = now - soulOfForestStartedAt
            if elapsed < SOUL_OF_FOREST_DURATION then
                soulOfForestRemains = SOUL_OF_FOREST_DURATION - elapsed
            else
                soulOfForestStartedAt = 0
            end
        end
        values.soul_of_forest_remains = math.floor(soulOfForestRemains + 0.5)
        local bear_form = 0
        pcall(function()
            bear_form = GetShapeshiftForm()
        end)
        values.bear_form = bear_form
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
        local cd_33891 = 0
        if ironbarkReadyAt > now then
            cd_33891 = math.ceil(ironbarkReadyAt - now)
        end
        values.cd_33891 = cd_33891
        values.focus_cast_unreachable = P8BA6426E.GetFocusCastUnreachable()
    end,
})
