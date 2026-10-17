--[[
  Druid_Guardian（守护德鲁伊）—— 专精配置：守护德鲁伊（specID 104）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：bd1dd9.lua（TOC 第 73 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local frenziedRegenUntil = 0
local lastCastSpellID = nil
local lastCastAt = 0
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
local function isSpell213771Ready()
    local spellID = 213771
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
P8BA6426E.RegisterClass(104, {
    talentLoadouts = {
        {
            name = "PTR艾露恩钦选者推荐",
            importString = "CgGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgZmxsYmZMziZxMPwMLLDMbzwoJyMzyMzMzsMmBAAAAAGYsZALbzMYMbDgJAAAgNMzAsYgBsYBgZGAD",
        },
        {
            name = "PTR利爪德鲁伊备用",
            importString = "CgGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgZmxsMmZMziZZegxMWGY2MMaimZmlZmZmZZMDDAAAAAYGLzAAAAgmZZWmZmBAwCm5BAWMDGwiFDAmZDG",
        },
    },
    DEFAULT_MACROS = {
        spell_77758 = "/cast [nochanneling]痛击",
        spell_33917 = "/cast [nochanneling]裂伤",
        spell_33917_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]裂伤\n/targetlasttarget",
        spell_400254 = "/cast [nochanneling]摧折",
        spell_400254_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]摧折\n/targetlasttarget",
        spell_102558 = "/cast [nochanneling]化身：乌索克的守护者",
        spell_8921 = "/cast [nochanneling]月火术",
        spell_192081 = "/cast [nochanneling]铁鬃",
        cd_61336 = "/cast [nochanneling]生存本能",
        spell_22842 = "/cast [nochanneling]狂暴回复",
        cd_22812 = "/cast [nochanneling]树皮术",
        cd_106839 = "/cast [nochanneling]迎头痛击",
        spell_106839_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]迎头痛击",
        focus_interrupt = "/cast [nochanneling,@focus]迎头痛击",
        cd_1253799 = "/cast [nochanneling]碎甲咆哮",
        cd_2040666 = "/cast [nochanneling]明月普照",
        spell_6807 = "/cast [nochanneling]重殴",
        spell_6807_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]重殴\n/targetlasttarget",
        spell_5487 = "/cast [noform:1]熊形态",
        spell_213771 = "/cast [nochanneling]横扫",
        spell_2782 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]清除腐蚀",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        spell_1126 = "/cast 野性印记",
        spell_20484 = "/cast [@mouseover,help,dead] [help,dead] [@party1,dead] [@party2,dead] [@party3,dead] [@party4,dead] 复生",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 77758, 33917, 400254, 102558, 8921, 192081, 6807, 213771, 22842, 20484, 2782 },
    ACTION_LABELS = {
        spell_77758 = "痛击",
        spell_33917 = "裂伤",
        spell_33917_nearest = "就近裂伤",
        spell_400254 = "摧折",
        spell_400254_nearest = "就近摧折",
        spell_102558 = "化身：乌索克的守护者",
        spell_8921 = "月火术",
        spell_192081 = "铁鬃",
        cd_61336 = "生存本能",
        spell_22842 = "狂暴回复",
        cd_22812 = "树皮术",
        cd_106839 = "迎头痛击",
        spell_106839_mouseover = "迎头痛击指向",
        focus_interrupt = "迎头痛击焦点",
        cd_1253799 = "碎甲咆哮",
        cd_2040666 = "明月普照",
        spell_6807 = "重殴",
        spell_6807_nearest = "就近重殴",
        spell_5487 = "熊形态",
        spell_213771 = "横扫",
        spell_2782 = "清除腐蚀",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        spell_1126 = "野性印记",
        spell_20484 = "复生",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_77758 = "F6",
        spell_33917 = "F7",
        spell_33917_nearest = "8",
        spell_400254 = "F8",
        spell_400254_nearest = "9",
        spell_102558 = "-",
        spell_8921 = "F10",
        spell_192081 = "F9",
        cd_61336 = "]",
        spell_22842 = ";",
        cd_22812 = "'",
        cd_106839 = ",",
        spell_106839_mouseover = "CTRL-F6",
        focus_interrupt = "INSERT",
        cd_1253799 = "=",
        cd_2040666 = "[",
        spell_6807 = "F11",
        spell_6807_nearest = "0",
        spell_5487 = ".",
        spell_213771 = "F12",
        spell_2782 = "\\",
        item_red_potion = "HOME",
        item_healing_stone = "END",
        item_burst_potion = "LEFT",
        spell_1126 = "UP",
        spell_20484 = "DOWN",
        trinket1_cd = "RIGHT",
        trinket2_cd = "DELETE",
    },
    macroOrder = {
        "spell_77758",
        "spell_33917",
        "spell_33917_nearest",
        "spell_400254",
        "spell_400254_nearest",
        "spell_102558",
        "spell_8921",
        "spell_192081",
        "cd_61336",
        "spell_22842",
        "cd_22812",
        "cd_106839",
        "cd_1253799",
        "cd_2040666",
        "spell_106839_mouseover",
        "spell_6807",
        "spell_6807_nearest",
        "spell_5487",
        "spell_213771",
        "spell_2782",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "spell_1126",
        "spell_20484",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 1126, 5487, 6807, 8921, 20484, 192081, 213771, 400254 },
    OverrideIsSpellReady = function(spellID)
        if spellID == 213771 then
            return isSpell213771Ready()
        end
        return nil
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
    showAoeModeButton = true,
    OnSpellCast = function(spellID)
        local now = GetTime()
        if spellID == lastCastSpellID and (now - lastCastAt) < 0.5 then
            return
        end
        lastCastSpellID = spellID
        lastCastAt = now
        if spellID == 22842 then
            frenziedRegenUntil = now + 4
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local bear_form = 0
        pcall(function()
            bear_form = GetShapeshiftForm()
        end)
        values.bear_form = bear_form
        local frenziedRegenRemains = 0
        if frenziedRegenUntil > 0 then
            frenziedRegenRemains = frenziedRegenUntil - now
            if frenziedRegenRemains <= 0 then
                frenziedRegenRemains = 0
                frenziedRegenUntil = 0
            end
        end
        values.duration_22842 = math.floor(frenziedRegenRemains + 0.5)
    end,
})
