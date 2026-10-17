--[[
  Warrior_Arms（武器战士）—— 专精配置：武器战士（specID 71）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：39f566.lua（TOC 第 54 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local avatarStartedAt = 0
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
local function isSpell1269383Ready()
    local spellID = 1269383
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
P8BA6426E.RegisterClass(71, {
    talentLoadouts = {
        {
            name = "大米通用",
            importString = "CcEASWsDSHNyPDXnbxuIhH3ZdjZmZmFzYmZGAAAghphZGmZbZmZmZYGzMAAAAAGLzMwEGLbDsAGwMMhMD2AzMMMYWmZbAmZAwMMA",
        },
        {
            name = "团本5号",
            importString = "CcEASWsDSHNyPDXnbxuIhH3ZdjZmZmFz8AmZGAAAghphZGmZbZmZmZYGzMAAAAAmZZmBEGLLDsAGwMMhMD2AzMMMDWmZbAmZAwMMA",
        },
        {
            name = "团本通用",
            importString = "CcEASWsDSHNyPDXnbxuIhH3ZdjZmZmFzYmZGAAAghphZGmZbZmZmZYGzMAAAAAmZZmBmwYZbgFwAmhJkZwGYmhhBWmZbAmZAwMMA",
        },
    },
    DEFAULT_MACROS = {
        spell_12294 = "/cast [nochanneling]致死打击",
        spell_12294_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 致死打击\n/targetlasttarget",
        spell_163201 = "/cast [nochanneling]斩杀",
        spell_163201_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 斩杀\n/targetlasttarget",
        spell_7384 = "/cast [nochanneling]压制",
        spell_7384_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 压制\n/targetlasttarget",
        spell_1464 = "/cast [nochanneling]猛击",
        spell_1464_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 猛击\n/targetlasttarget",
        spell_107574 = "/cast [nochanneling]天神下凡",
        spell_436358 = "/cast [nochanneling]崩摧",
        spell_167105 = "/cast 天神下凡\n/cast 巨人打击",
        spell_260708 = "/cast [nochanneling]横扫攻击",
        spell_772 = "/cast [nochanneling]撕裂",
        spell_845 = "/cast [nochanneling]顺劈斩",
        spell_845_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 顺劈斩\n/targetlasttarget",
        spell_384110 = "/cast [nochanneling]破裂投掷",
        spell_228920 = "/cast [nochanneling]破坏者",
        spell_446035 = "/cast [nochanneling]剑刃风暴",
        cd_202168 = "/cast [nochanneling]胜利在望",
        spell_6673 = "/cast 战斗怒吼",
        cd_118038 = "/cast [nochanneling]剑在人在",
        cd_6552 = "/cast [nochanneling]拳击",
        spell_6552_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]拳击",
        focus_interrupt = "/cast [nochanneling,@focus]拳击",
        cd_97462 = "/cast [nochanneling]集结呐喊",
        cd_18499 = "/cast [nochanneling]狂暴之怒",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 12294, 163201, 7384, 1464, 107574, 436358, 167105, 260708 },
    ACTION_LABELS = {
        spell_12294 = "致死打击",
        spell_12294_nearest = "就近致死打击",
        spell_163201 = "斩杀",
        spell_163201_nearest = "就近斩杀",
        spell_7384 = "压制",
        spell_7384_nearest = "就近压制",
        spell_1464 = "猛击",
        spell_1464_nearest = "就近猛击",
        spell_107574 = "天神下凡",
        spell_436358 = "崩摧",
        spell_167105 = "巨人打击",
        spell_260708 = "横扫攻击",
        spell_772 = "撕裂",
        spell_845 = "顺劈斩",
        spell_845_nearest = "就近顺劈斩",
        spell_384110 = "破裂投掷",
        spell_228920 = "破坏者",
        spell_446035 = "剑刃风暴",
        cd_202168 = "胜利在望",
        spell_6673 = "战斗怒吼",
        cd_118038 = "剑在人在",
        cd_6552 = "拳击",
        spell_6552_mouseover = "拳击指向",
        focus_interrupt = "拳击焦点",
        cd_97462 = "集结呐喊",
        cd_18499 = "狂暴之怒",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_12294 = "F6",
        spell_12294_nearest = "F7",
        spell_163201 = "F8",
        spell_163201_nearest = "F9",
        spell_7384 = "F10",
        spell_7384_nearest = "F11",
        spell_1464 = "F12",
        spell_1464_nearest = "8",
        spell_107574 = ";",
        spell_436358 = "9",
        spell_167105 = "]",
        spell_260708 = "[",
        spell_772 = "0",
        spell_845 = "-",
        spell_845_nearest = "=",
        spell_384110 = "RIGHT",
        spell_228920 = "'",
        spell_446035 = ",",
        cd_202168 = "\\",
        spell_6673 = ".",
        cd_118038 = "UP",
        cd_6552 = "INSERT",
        spell_6552_mouseover = "CTRL-F9",
        focus_interrupt = "DELETE",
        cd_97462 = "DOWN",
        cd_18499 = "LEFT",
        item_red_potion = "CTRL-F8",
        item_healing_stone = "CTRL-F7",
        item_burst_potion = "HOME",
        trinket1_cd = "END",
        trinket2_cd = "CTRL-F6",
    },
    macroOrder = {
        "spell_12294",
        "spell_12294_nearest",
        "spell_163201",
        "spell_163201_nearest",
        "spell_7384",
        "spell_7384_nearest",
        "spell_1464",
        "spell_1464_nearest",
        "spell_107574",
        "spell_436358",
        "spell_167105",
        "spell_260708",
        "spell_446035",
        "spell_772",
        "spell_845",
        "spell_845_nearest",
        "spell_384110",
        "spell_228920",
        "cd_202168",
        "spell_6673",
        "cd_118038",
        "cd_6552",
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
    actionAvailSpellIDs = { 1464, 6673 },
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
        if spellID == 107574 then
            avatarStartedAt = now
        end
    end,
    OverrideIsSpellReady = function(spellID)
        if spellID == 1269383 then
            return isSpell1269383Ready()
        end
        return nil
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local avatarRemains = 0
        if avatarStartedAt > 0 then
            avatarRemains = 20 - (now - avatarStartedAt)
            if avatarRemains <= 0 then
                avatarRemains = 0
                avatarStartedAt = 0
            end
        end
        values.duration_107574 = math.floor(avatarRemains + 0.5)
        local spell_163201_ready = false
        pcall(function()
            local isSpellUsable = P8BA6426E.IsSpellUsable(163201)
            local spellCooldownRemaining = P8BA6426E.GetSpellCooldownRemaining(163201)
            spell_163201_ready = isSpellUsable and spellCooldownRemaining == 0
        end)
        values.spell_163201_ready = spell_163201_ready
        local spell_1269383_ready = false
        pcall(function()
            spell_1269383_ready = P8BA6426E.IsSpellReady(1269383)
        end)
        values.spell_1269383_ready = spell_1269383_ready
        values.target_shield = isShieldSlamHighlighted()
        values.talent_383703 = P8BA6426E.IsSpellKnown(383703) == true
    end,
})
