--[[
  Warrior_Fury（狂怒战士）—— 专精配置：狂怒战士（specID 72）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：5c0eb8.lua（TOC 第 59 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local cd_190411 = 0
local recklessness_raging_blow = 0
local thunderBlastPending = false
local IGNORED_DURING_PENDING = { [23881] = true, [335096] = true, [335097] = true }
local CLEARS_PENDING = {
    [5308] = true,
    [6343] = true,
    [6552] = true,
    [6673] = true,
    [1719] = true,
    [18499] = true,
    [85288] = true,
    [97462] = true,
    [107574] = true,
    [163201] = true,
    [184364] = true,
    [184367] = true,
    [190411] = true,
    [202168] = true,
    [280735] = true,
    [384110] = true,
    [385059] = true,
}
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
local function isShieldSlamHighlighted()
    if not getHostileTargetGUID() then
        return false
    end
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        return C_SpellActivationOverlay.IsSpellOverlayed(384110) == true
    end
    return false
end
P8BA6426E.RegisterClass(72, {
    talentLoadouts = {
        {
            name = "屠戮通用",
            importString = "CgEASWsDSHNyPDXnbxuIhH3ZdDAAAAAAgGDzMmZ2MzMzMjZMzMzMzYmlZMmZMbmZmBAAixy2ALgJYGmAzwGwMDDAAwMDjZZYMYM",
        },
        {
            name = "屠戮单体",
            importString = "CgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgGDzwMzmZmZmZYMzMzYmZmlZmxMzMbGzMAAQMW2GYBMgZYCMDbAzMbGbAAwMDjxwYwYA",
        },
        {
            name = "山丘通用",
            importString = "CgEASWsDSHNyPDXnbxuIhH3ZdDAAAAAAgGDzMjZ2MzMzYmZMzYmZmZmlZGmZMLj5BmBAACDsBLLGNmBkZBzYBwMYAAzMAGmlZGGMG",
        },
    },
    DEFAULT_MACROS = {
        spell_23881 = "/cast [nochanneling]嗜血",
        spell_23881_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]嗜血\n/targetlasttarget",
        spell_85288 = "/cast [nochanneling]怒击",
        spell_85288_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]怒击\n/targetlasttarget",
        spell_184367 = "/cast [nochanneling]暴怒",
        spell_184367_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]暴怒\n/targetlasttarget",
        spell_163201 = "/cast [nochanneling]斩杀",
        spell_163201_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]斩杀\n/targetlasttarget",
        spell_385059 = "/cast [nochanneling]奥丁之怒",
        spell_1719 = "/cast [nochanneling]鲁莽\n/cast 天神下凡",
        spell_190411 = "/cast [nochanneling]旋风斩",
        spell_6343 = "/cast [nochanneling]雷霆一击",
        spell_446035 = "/cast [nochanneling]剑刃风暴",
        spell_384110 = "/cast [nochanneling]破裂投掷",
        cd_202168 = "/cast [nochanneling]胜利在望",
        spell_6673 = "/cast 战斗怒吼",
        cd_6552 = "/cast [nochanneling]拳击",
        spell_6552_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]拳击",
        focus_interrupt = "/cast [nochanneling,@focus]拳击",
        cd_184364 = "/cast [nochanneling]狂怒回复",
        cd_97462 = "/cast [nochanneling]集结呐喊",
        cd_18499 = "/cast [nochanneling]狂暴之怒",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 23881, 85288, 184367, 163201, 385059, 107574, 190411, 6343, 384110 },
    ACTION_LABELS = {
        spell_23881 = "嗜血",
        spell_23881_nearest = "就近嗜血",
        spell_85288 = "怒击",
        spell_85288_nearest = "就近怒击",
        spell_184367 = "暴怒",
        spell_184367_nearest = "就近暴怒",
        spell_163201 = "斩杀",
        spell_163201_nearest = "就近斩杀",
        spell_385059 = "奥丁之怒",
        spell_1719 = "鲁莽天神",
        spell_190411 = "旋风斩",
        spell_6343 = "雷霆一击",
        spell_446035 = "剑刃风暴",
        spell_384110 = "破裂投掷",
        cd_202168 = "胜利在望",
        spell_6673 = "战斗怒吼",
        cd_6552 = "拳击",
        spell_6552_mouseover = "拳击指向",
        focus_interrupt = "拳击焦点",
        cd_184364 = "狂怒回复",
        cd_97462 = "集结呐喊",
        cd_18499 = "狂暴之怒",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_23881 = "F6",
        spell_23881_nearest = "F7",
        spell_85288 = "F8",
        spell_85288_nearest = "F9",
        spell_184367 = "F10",
        spell_184367_nearest = "F11",
        spell_163201 = "F12",
        spell_163201_nearest = "8",
        spell_385059 = "-",
        spell_1719 = "=",
        spell_190411 = "9",
        spell_6343 = "0",
        spell_446035 = "[",
        spell_384110 = "\\",
        cd_202168 = ";",
        spell_6673 = "]",
        cd_6552 = "UP",
        spell_6552_mouseover = "END",
        focus_interrupt = "DOWN",
        cd_184364 = "'",
        cd_97462 = ",",
        cd_18499 = ".",
        item_red_potion = "HOME",
        item_healing_stone = "DELETE",
        item_burst_potion = "LEFT",
        trinket1_cd = "RIGHT",
        trinket2_cd = "INSERT",
    },
    macroOrder = {
        "spell_23881",
        "spell_23881_nearest",
        "spell_85288",
        "spell_85288_nearest",
        "spell_184367",
        "spell_184367_nearest",
        "spell_163201",
        "spell_163201_nearest",
        "spell_385059",
        "spell_1719",
        "spell_190411",
        "spell_6343",
        "spell_446035",
        "spell_384110",
        "cd_202168",
        "spell_6673",
        "cd_6552",
        "cd_184364",
        "cd_97462",
        "cd_18499",
        "spell_6552_mouseover",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 6673, 184367 },
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
        if spellID == 446035 then
            thunderBlastPending = true
            return
        end
        if thunderBlastPending then
            if IGNORED_DURING_PENDING[spellID] then
                return
            end
            if not CLEARS_PENDING[spellID] then
                return
            end
            thunderBlastPending = false
        end
        if spellID == 190411 or spellID == 6343 then
            cd_190411 = 4
        elseif
            spellID == 184367
            or spellID == 85288
            or spellID == 280735
            or spellID == 5308
            or spellID == 23881
            or spellID == 335096
            or spellID == 335097
        then
            if cd_190411 > 0 then
                cd_190411 = cd_190411 - 1
            end
        end
        if spellID == 1719 then
            recklessness_raging_blow = 0
        elseif spellID == 85288 or spellID == 335097 then
            if recklessness_raging_blow < 10 then
                recklessness_raging_blow = recklessness_raging_blow + 1
            end
        end
    end,
    GetExtraValues = function(values)
        local spell_163201_ready = false
        pcall(function()
            local isSpellUsable = P8BA6426E.IsSpellUsable(163201)
            local spellCooldownRemaining = P8BA6426E.GetSpellCooldownRemaining(163201)
            spell_163201_ready = isSpellUsable and spellCooldownRemaining == 0
        end)
        values.spell_163201_ready = spell_163201_ready
        values.cd_190411 = cd_190411
        values.recklessness_raging_blow = recklessness_raging_blow
        values.target_shield = isShieldSlamHighlighted()
    end,
})
