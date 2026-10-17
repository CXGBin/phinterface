--[[
  DeathKnight_Blood（鲜血死亡骑士）—— 专精配置：鲜血死亡骑士（specID 250）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：89ab3b.lua（TOC 第 67 个加载的插件脚本）

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
local function isSpell433895Ready()
    local spellID = 433895
    local known = false
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        local playerBank = Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "player"
        known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, playerBank, true)
    elseif IsSpellKnown then
        known = IsSpellKnown(spellID)
    end
    if not known then
        return false
    end
    local usable = true
    if P8BA6426E.IsSpellUsable then
        usable = P8BA6426E.IsSpellUsable(spellID)
    end
    if not usable then
        return false
    end
    local remaining = P8BA6426E.GetSpellCooldownRemaining(spellID)
    if remaining and remaining > 0 then
        return false
    end
    return true
end
P8BA6426E.RegisterClass(250, {
    talentLoadouts = {
        {
            name = "PTR萨莱因推荐",
            importString = "CoPAAAAAAAAAAAAAAAAAAAAAAwMz2MzwMmZmhZbmZmmZxMjZmBAAAAwMMzMzMjZmZAAjZmZGAAADMwMW0YZDw2A2AMjBAAYmBGGA",
        },
        {
            name = "PTR死亡使者备用",
            importString = "CoPAAAAAAAAAAAAAAAAAAAAAAwMzyMzwMmZmhZZmZmmZzYmZmxAAAAAGMzMzMjZmZMAYmZmZGAAgxsNwAWALDTghFAzYAAwMDAMA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_55233 = "/cast 吸血鬼之血",
        spell_49028 = "/cast 符文刃舞",
        spell_206930 = "/cast 心脏打击",
        spell_195182 = "/cast 精髓分裂",
        spell_439843 = "/cast 死神印记",
        spell_50842 = "/cast 血液沸腾",
        spell_195292 = "/cast 死神的抚摩",
        spell_49998 = "/cast 灵界打击",
        spell_43265 = "/cast [@player]枯萎凋零",
        spell_47541 = "/cast 凋零缠绕",
        spell_49576 = "/cast 死亡之握",
        cd_48792 = "/cast 冰封之韧",
        cd_49039 = "/cast 巫妖之躯",
        cd_47528 = "/cast 心灵冰冻",
        spell_47528_mouseover = "/cast [@mouseover,harm,nodead,exists] 心灵冰冻",
        focus_interrupt = "/cast [@focus]心灵冰冻",
        spell_46585 = "/cast 亡者复生",
        spell_61999 = "/cast [@mouseover,help,dead] [help,dead] [@party1,dead] [@party2,dead] [@party3,dead] [@party4,dead] [@party5,dead] 复活盟友",
        spell_206930_nearest = '/cleartarget\n/script SetCVar("targetNearestDistance",5)\n/targetenemy\n/startattack\n/cast 心脏打击\n/targetlasttarget',
        spell_49998_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 灵界打击\n/targetlasttarget",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 55233, 49028, 206930, 195182, 439843, 50842, 195292, 49998, 49576 },
    ACTION_LABELS = {
        spell_55233 = "吸血鬼之血",
        spell_49028 = "符文刃舞",
        spell_206930 = "心脏打击",
        spell_195182 = "精髓分裂",
        spell_439843 = "死神印记",
        spell_50842 = "血液沸腾",
        spell_195292 = "死神的抚摩",
        spell_49998 = "灵界打击",
        spell_43265 = "枯萎凋零",
        spell_47541 = "凋零缠绕",
        spell_49576 = "死亡之握",
        cd_48792 = "冰封之韧",
        cd_49039 = "巫妖之躯",
        cd_47528 = "心灵冰冻",
        spell_47528_mouseover = "心灵冰冻指向",
        focus_interrupt = "心灵冰冻焦点",
        spell_46585 = "亡者复生",
        spell_61999 = "复活盟友",
        spell_206930_nearest = "就近心打",
        spell_49998_nearest = "就近灵界打击",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_55233 = "=",
        spell_49028 = "-",
        spell_206930 = "F6",
        spell_195182 = "F9",
        spell_439843 = "9",
        spell_50842 = "F8",
        spell_195292 = "F10",
        spell_49998 = "F11",
        spell_43265 = "8",
        spell_47541 = "0",
        spell_49576 = "UP",
        cd_48792 = "[",
        cd_49039 = "]",
        cd_47528 = "DOWN",
        spell_47528_mouseover = "DELETE",
        focus_interrupt = "LEFT",
        spell_46585 = "\\",
        spell_61999 = ".",
        spell_206930_nearest = "F7",
        spell_49998_nearest = "F12",
        item_red_potion = "INSERT",
        item_burst_potion = ";",
        item_healing_stone = "RIGHT",
        trinket1_cd = "'",
        trinket2_cd = ",",
    },
    macroOrder = {
        "spell_55233",
        "spell_49028",
        "spell_206930",
        "spell_195182",
        "spell_439843",
        "spell_50842",
        "spell_195292",
        "spell_49998",
        "spell_43265",
        "spell_47541",
        "spell_49576",
        "spell_46585",
        "spell_206930_nearest",
        "spell_49998_nearest",
        "cd_48792",
        "cd_49039",
        "cd_47528",
        "spell_47528_mouseover",
        "focus_interrupt",
        "spell_61999",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 47541, 49998, 61999, 195182, 206930 },
    OverrideIsSpellReady = function(spellID)
        if spellID == 433895 then
            return isSpell433895Ready()
        end
        return nil
    end,
    GetExtraValues = function(values)
        values.pet_exists = UnitExists("pet") == true
        local spell_433895_ready = false
        pcall(function()
            spell_433895_ready = P8BA6426E.IsSpellReady(433895)
        end)
        values.spell_433895_ready = spell_433895_ready
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
