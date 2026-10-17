--[[
  DeathKnight_Frost（冰霜死亡骑士）—— 专精配置：冰霜死亡骑士（specID 251）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：e49775.lua（TOC 第 81 个加载的插件脚本）

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
P8BA6426E.RegisterClass(251, {
    talentLoadouts = {
        {
            name = "大米死亡使者",
            importString = "CsPAkXBWxkyfx9CbGaHonEAhLNAzMjZMDDz2MzMzMbmZkZMGDzMGMzMzMzMzMDAAAAAAAAAjZbgBsAWGmQGLYmxMzADADzMAzAD",
        },
        {
            name = "团本单体",
            importString = "CsPAAAAAAAAAAAAAAAAAAAAAAMAmZMjZYY2mZmZmZZmZkZMGDzMGMzMzMzMzMDAAAAAAAAAjZbgBsAWGmAjFMzYmZgBghZGAzgB",
        },
        {
            name = "PTR死亡使者推荐",
            importString = "CsPAAAAAAAAAAAAAAAAAAAAAAMAzMMjZGDz2MzMzMbzY0MjxMDjxgZmZmZmZmZAAAAAAAAAYMbDMgFwywEYsgZGzMDMAMMzAwgB",
        },
        {
            name = "PTR天启骑士备用",
            importString = "CsPAAAAAAAAAAAAAAAAAAAAAAMDYmhZMDDzyMzMzMbzMjmZMGDjxgZmZmZmZmZAAAAAAAAAAsZWMMwAzGDNshZGzMDMAMAMzwgB",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        item_healing_stone = "/use item:5512",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        spell_49143 = "/cast 冰霜打击",
        spell_49143_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 冰霜打击\n/targetlasttarget",
        spell_49020 = "/cast 湮灭",
        spell_49020_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 湮灭\n/targetlasttarget",
        spell_49184 = "/cast 凛风冲击",
        spell_51271 = "/cast 冰霜之柱",
        spell_152279 = "/cast 冰龙吐息",
        spell_47568 = "/cast 符文武器增效",
        spell_279302 = "/cast 冰霜巨龙之怒",
        spell_207230 = "/cast 冰霜之镰",
        spell_207230_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 冰霜之镰\n/targetlasttarget",
        spell_194913 = "/cast 冰川突进",
        spell_194913_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 冰川突进\n/targetlasttarget",
        spell_49998 = "/cast 灵界打击",
        spell_49998_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 灵界打击\n/targetlasttarget",
        spell_46585 = "/cast 亡者复生",
        spell_439843 = "/cast 死神印记",
        cd_48792 = "/cast 冰封之韧",
        cd_49039 = "/cast 巫妖之躯",
        cd_47528 = "/cast 心灵冰冻",
        spell_47528_mouseover = "/cast [@mouseover,harm,nodead,exists] 心灵冰冻",
        focus_interrupt = "/cast [@focus]心灵冰冻",
    },
    testSpells = { 49143, 49020, 49184, 51271, 152279, 47568, 279302, 207230, 194913, 49998 },
    consumableItems = {
        { id = "item_red_potion", label = "红药水", cooldown = 300, itemIDs = { 271883, 271884 } },
        { id = "item_healing_stone", label = "治疗石", cooldown = 60, itemIDs = { 5512 } },
        {
            id = "item_burst_potion",
            label = "爆发药水",
            cooldown = 300,
            itemIDs = { 241308, 241309, 241288, 241289 },
        },
    },
    ACTION_LABELS = {
        item_healing_stone = "治疗石",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        spell_49143 = "冰霜打击",
        spell_49143_nearest = "就近冰霜打击",
        spell_49020 = "湮灭",
        spell_49020_nearest = "就近湮灭",
        spell_49184 = "凛风冲击",
        spell_51271 = "冰霜之柱",
        spell_152279 = "冰龙吐息",
        spell_47568 = "符文武器增效",
        spell_279302 = "冰霜巨龙之怒",
        spell_207230 = "冰霜之镰",
        spell_207230_nearest = "就近冰霜之镰",
        spell_194913 = "冰川突进",
        spell_194913_nearest = "就近冰川突进",
        spell_49998 = "灵界打击",
        spell_49998_nearest = "就近灵界打击",
        spell_46585 = "亡者复生",
        spell_439843 = "死神印记",
        cd_48792 = "冰封之韧",
        cd_49039 = "巫妖之躯",
        cd_47528 = "心灵冰冻",
        spell_47528_mouseover = "心灵冰冻指向",
        focus_interrupt = "心灵冰冻焦点",
    },
    ACTION_TO_KEY = {
        item_healing_stone = "DELETE",
        item_red_potion = "HOME",
        item_burst_potion = ",",
        trinket1_cd = ".",
        trinket2_cd = "\\",
        spell_49143 = "F8",
        spell_49143_nearest = "F9",
        spell_49020 = "F6",
        spell_49020_nearest = "F7",
        spell_49184 = "F10",
        spell_51271 = "[",
        spell_152279 = "]",
        spell_47568 = ";",
        spell_279302 = "'",
        spell_207230 = "F11",
        spell_207230_nearest = "F12",
        spell_194913 = "8",
        spell_194913_nearest = "9",
        spell_49998 = "-",
        spell_49998_nearest = "=",
        spell_46585 = "UP",
        spell_439843 = "0",
        cd_48792 = "DOWN",
        cd_49039 = "LEFT",
        cd_47528 = "RIGHT",
        spell_47528_mouseover = "END",
        focus_interrupt = "INSERT",
    },
    macroOrder = {
        "spell_49143",
        "spell_49143_nearest",
        "spell_49020",
        "spell_49020_nearest",
        "spell_49184",
        "spell_51271",
        "spell_152279",
        "spell_47568",
        "spell_279302",
        "spell_207230",
        "spell_207230_nearest",
        "spell_194913",
        "spell_194913_nearest",
        "spell_49998",
        "spell_49998_nearest",
        "spell_46585",
        "spell_439843",
        "cd_48792",
        "cd_49039",
        "cd_47528",
        "spell_47528_mouseover",
        "focus_interrupt",
        "item_healing_stone",
        "item_red_potion",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    GetExtraValues = function(values)
        values.pet_exists = UnitExists("pet") == true
        local ok, result = pcall(function()
            return UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))
        end)
        values.target_attackable = ok and result == true
    end,
    actionReadyCooldowns = { [1249658] = 90 },
    actionAvailSpellIDs = { 49020, 49143, 49184, 49998, 152279, 194913, 207230 },
    spellReadyAliases = { [49020] = { 1264082, 1264084 }, [152279] = { 1226969, 1231316, 1249658 } },
})
