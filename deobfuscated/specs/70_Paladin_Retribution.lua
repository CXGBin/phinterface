--[[
  Paladin_Retribution（惩戒骑士）—— 专精配置：惩戒骑士（specID 70）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：3c2bd5.lua（TOC 第 55 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local wakeOfAshesAt = 0
local highlightSpellAt = 0
local HIGHLIGHT_RESET_SPELLS = { 429826, 1217116, 1235934, 1246643 }
local HIGHLIGHT_SPELL_SET = { [427453] = true }
for _, spellID in ipairs(HIGHLIGHT_RESET_SPELLS) do
    HIGHLIGHT_SPELL_SET[spellID] = true
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
P8BA6426E.RegisterClass(70, {
    showAoeModeButton = true,
    talentLoadouts = {
        {
            name = "PTR烈日先驱推荐",
            importString = "CYEAAAAAAAAAAAAAAAAAAAAAAAAAAAwoZZbmZWGzYGAAAAAAzUmlZYmx2Y2GmZbGjxYYGLsBgZb2mZmtGAAAYBwAGwMbDYGzMbAzMDDjBD",
        },
        {
            name = "PTR圣殿骑士备用",
            importString = "CYEAAAAAAAAAAAAAAAAAAAAAAAAAAAwoZbbmZWGDzAAAAAAYmyYGmZsNmthZ2mxMjxwM2YDAAgZm2mZ2mBAsBYAMGzwAzMzMbYZGMMGGMA",
        },
        {
            name = "团本单体",
            importString = "CYEAzbn3egSOtoSwvPw1U1vTLAAAAAwoZZbmZWGGDAAAAAAzUmlZYmx2Y2GmZbGjxMDzYhtBgZZ2mZmtGEAAwCgBMgZ2GwMGzGwMzwwYwA",
        },
        {
            name = "大米/团本add",
            importString = "CYEAzbn3egSOtoSwvPw1U1vTLAAAAAwoZZbmZWGzYGAAAAAAzUmlZYmx2Y2GmZbGjxYYGLsBgZZ2mZmtGEAAwCgBMgZ2GwMmZ2AmZGGGDG",
        },
        {
            name = "大锤",
            importString = "CYEAAAAAAAAAAAAAAAAAAAAAAAAAAAwoZbbmZWGzMzAAAAAAYmysMDzM2Gz2wMbzYMGDzYjNAAAmZaZmZbGAwGgBAjZYgZMzshlZwwYYwA",
        },
    },
    DEFAULT_MACROS = {
        spell_20271 = "/cast 审判",
        spell_53385 = "/cast 神圣风暴",
        spell_383328 = "/cast 最终审判",
        spell_184575 = "/cast 公正之剑",
        spell_255937 = "/cast 灰烬觉醒",
        spell_255937_six_line = "/cast 灰烬觉醒\n/ON",
        spell_375576 = "/cast 圣洁鸣钟",
        spell_343527 = "/cast 处决宣判",
        spell_31884 = "/cast 复仇之怒",
        spell_427453 = "/cast 灰烬觉醒",
        cd_403876 = "/cast 圣佑术",
        cd_642 = "/cast 圣盾术",
        cd_633 = "/cast [@player]圣疗术",
        cd_96231 = "/cast 责难",
        spell_96231_mouseover = "/cast [@mouseover,harm,nodead,exists] 责难",
        spell_85673 = "/cast [@player]荣耀圣令",
        spell_213644 = "/cast [nochanneling,@mouseover,help,nodead,exists]清毒术",
        spell_213644_player = "/cast [nochanneling,@player]清毒术",
        focus_interrupt = "/cast [@focus]责难",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 20271, 53385, 383328, 184575, 255937, 375576, 343527, 31884, 427453, 213644 },
    ACTION_LABELS = {
        spell_20271 = "审判",
        spell_53385 = "神圣风暴",
        spell_383328 = "最终审判",
        spell_184575 = "公正之剑",
        spell_255937 = "灰烬觉醒",
        spell_255937_six_line = "六线灰烬觉醒",
        spell_375576 = "圣洁鸣钟",
        spell_343527 = "处决宣判",
        spell_31884 = "复仇之怒",
        spell_427453 = "圣光之锤",
        cd_403876 = "圣佑术",
        cd_642 = "圣盾术",
        cd_633 = "圣疗术",
        cd_96231 = "责难",
        spell_96231_mouseover = "责难指向",
        spell_85673 = "荣耀圣令",
        spell_213644 = "指向清毒术",
        spell_213644_player = "自身清毒术",
        focus_interrupt = "责难焦点",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_20271 = "F6",
        spell_53385 = "F8",
        spell_383328 = "F9",
        spell_184575 = "F7",
        spell_255937 = "F10",
        spell_255937_six_line = "F11",
        spell_375576 = "8",
        spell_343527 = "9",
        spell_31884 = "0",
        spell_427453 = "F12",
        cd_403876 = "=",
        cd_642 = "[",
        cd_633 = "]",
        cd_96231 = ";",
        spell_96231_mouseover = "INSERT",
        spell_85673 = "-",
        spell_213644 = "LEFT",
        spell_213644_player = "RIGHT",
        focus_interrupt = "'",
        item_red_potion = "DOWN",
        item_burst_potion = ",",
        item_healing_stone = "UP",
        trinket1_cd = ".",
        trinket2_cd = "\\",
    },
    macroOrder = {
        "spell_20271",
        "spell_53385",
        "spell_383328",
        "spell_184575",
        "spell_255937",
        "spell_255937_six_line",
        "spell_375576",
        "spell_343527",
        "spell_31884",
        "spell_427453",
        "cd_403876",
        "cd_642",
        "cd_633",
        "cd_96231",
        "spell_96231_mouseover",
        "spell_85673",
        "spell_213644",
        "spell_213644_player",
        "focus_interrupt",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 53385, 85673, 383328 },
    spellReadyAliases = { [427453] = HIGHLIGHT_RESET_SPELLS },
    OnSpellCast = function(spellID, _)
        if spellID == 255937 then
            wakeOfAshesAt = GetTime()
        elseif HIGHLIGHT_SPELL_SET[spellID] then
            highlightSpellAt = GetTime()
        end
    end,
    GetExtraValues = function(values)
        local highlight427453 = 0
        if C_Spell and C_Spell.GetOverrideSpell then
            local overrideSpell = C_Spell.GetOverrideSpell(255937)
            if overrideSpell and HIGHLIGHT_SPELL_SET[overrideSpell] then
                if wakeOfAshesAt > highlightSpellAt then
                    highlight427453 = 2
                else
                    highlight427453 = 1
                end
            end
        end
        values.highlight427453 = highlight427453
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
