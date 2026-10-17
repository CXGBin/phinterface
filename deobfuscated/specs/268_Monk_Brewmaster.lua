--[[
  Monk_Brewmaster（酒仙武僧）—— 专精配置：酒仙武僧（specID 268）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：7041c9.lua（TOC 第 62 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local breathOfFireReadyAt = 0
local BREATH_OF_FIRE_COOLDOWN = 15
local niuzaoCastAt = 0
local NIUZAO_DURATION = 25
local blackoutCombo = false
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(268, {
    talentLoadouts = {
        {
            name = "PTR和谐宗师推荐",
            importString = "CwQAAAAAAAAAAAAAAAAAAAAAAAAAAgZbzYGGzyMzGzMjBAAAAAAYZBzEzMwMM2AmZmZY2sNzYsMss9AbbzGmFAAYZWmWmtZWGAAAADbgZGw0YADAYA",
        },
        {
            name = "PTR影踪派备用",
            importString = "CwQAAAAAAAAAAAAAAAAAAAAAAAAAAgZbzYGGzyM2YmZMAAAAAAALLYEzMwMMzmBmZmZY2YmxMLDLbPwy2sNjZBAA2AAAAz2s0MzMbMsBwMDTjBAAMA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_115181 = "/cast [nochanneling] 火焰之息",
        spell_121253 = "/cast [nochanneling] 醉酿投",
        spell_322109 = "/cast [@mouseover,harm,nodead] [] 轮回之触",
        spell_325153 = "/cast [@player,nochanneling] 爆炸酒桶",
        spell_132578 = "/cast [nochanneling] 玄牛下凡",
        spell_123986 = "/cast [nochanneling] 真气爆裂",
        spell_322729 = "/cast [nochanneling] 神鹤引项踢",
        spell_117952 = "/cast [nochanneling] 碎玉闪电",
        spell_100780 = "/cast [nochanneling] 猛虎掌",
        spell_100780_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 猛虎掌\n/targetlasttarget",
        spell_205523 = "/cast [nochanneling] 幻灭踢",
        spell_205523_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm] 幻灭踢\n/targetlasttarget",
        cd_119582 = "/cast [nochanneling] 活血酒",
        cd_116670 = "/cast [nochanneling] 活血术",
        cd_1241059 = "/cast [nochanneling] 天神灌注",
        cd_115203 = "/cast [nochanneling] 壮胆酒",
        cd_322101 = "/cast [nochanneling] 移花接木",
        cd_115399 = "/cast [nochanneling] 玄牛酒",
        spell_218164 = "/cast [nochanneling,@mouseover,help,nodead] 清创生血",
        spell_218164_player = "/cast [nochanneling,@player] 清创生血",
        cd_116705 = "/cast [nochanneling] 切喉手",
        spell_116705_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists] 切喉手",
        focus_interrupt = "/cast [nochanneling,@focus]切喉手",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 115181, 121253, 322109, 325153, 132578, 123986, 322729, 117952, 100780, 205523, 115399, 218164 },
    ACTION_LABELS = {
        spell_115181 = "火焰之息",
        spell_121253 = "醉酿投",
        spell_322109 = "轮回之触",
        spell_325153 = "爆炸酒桶",
        spell_132578 = "玄牛下凡",
        spell_123986 = "真气爆裂",
        spell_322729 = "神鹤引项踢",
        spell_117952 = "碎玉闪电",
        spell_100780 = "猛虎掌",
        spell_100780_nearest = "就近猛虎掌",
        spell_205523 = "幻灭踢",
        spell_205523_nearest = "就近幻灭踢",
        cd_119582 = "活血酒",
        cd_116670 = "活血术",
        cd_1241059 = "天神灌注",
        cd_115203 = "壮胆酒",
        cd_322101 = "移花接木",
        cd_115399 = "玄牛酒",
        spell_218164 = "指向清创生血",
        spell_218164_player = "自身清创生血",
        cd_116705 = "切喉手",
        spell_116705_mouseover = "切喉手指向",
        focus_interrupt = "切喉手焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_115181 = "F9",
        spell_121253 = "F6",
        spell_322109 = "=",
        spell_325153 = "-",
        spell_132578 = "[",
        spell_123986 = "F11",
        spell_322729 = "F10",
        spell_117952 = "]",
        spell_100780 = "F7",
        spell_100780_nearest = "9",
        spell_205523 = "F8",
        spell_205523_nearest = "0",
        cd_119582 = "8",
        cd_116670 = ",",
        cd_1241059 = ";",
        cd_115203 = "'",
        cd_322101 = "F12",
        cd_115399 = "INSERT",
        spell_218164 = "END",
        spell_218164_player = "CTRL-F6",
        cd_116705 = ".",
        spell_116705_mouseover = "HOME",
        focus_interrupt = "DELETE",
        item_red_potion = "LEFT",
        item_healing_stone = "RIGHT",
        item_burst_potion = "\\",
        trinket1_cd = "UP",
        trinket2_cd = "DOWN",
    },
    macroOrder = {
        "spell_115181",
        "spell_121253",
        "spell_322109",
        "spell_325153",
        "spell_132578",
        "spell_123986",
        "spell_322729",
        "spell_117952",
        "spell_100780",
        "spell_100780_nearest",
        "spell_205523",
        "spell_205523_nearest",
        "cd_119582",
        "cd_116670",
        "cd_1241059",
        "cd_115203",
        "cd_322101",
        "cd_116705",
        "spell_116705_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
        "cd_115399",
        "spell_218164",
        "spell_218164_player",
    },
    actionAvailSpellIDs = { 100780, 117952, 322729 },
    spellReadyAliases = { [100780] = { 1251114 }, [322729] = { 1250997, 1250999 } },
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
        if spellID == 115181 then
            breathOfFireReadyAt = GetTime() + BREATH_OF_FIRE_COOLDOWN
        end
        if spellID == 121253 then
            breathOfFireReadyAt = GetTime()
        end
        if spellID == 132578 then
            niuzaoCastAt = GetTime()
        end
        if spellID == 205523 then
            blackoutCombo = true
        end
        if blackoutCombo and (spellID == 121253 or spellID == 100780) then
            blackoutCombo = false
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local cd_115181 = math.max(0, breathOfFireReadyAt - now)
        values.cd_115181 = cd_115181
        local spell_322109_ready = false
        pcall(function()
            local isSpellUsable = P8BA6426E.IsSpellUsable(322109)
            local spellCooldownRemaining = P8BA6426E.GetSpellCooldownRemaining(322109)
            spell_322109_ready = isSpellUsable and spellCooldownRemaining == 0
        end)
        values.spell_322109_ready = spell_322109_ready
        local niuzaoRemains = math.max(0, NIUZAO_DURATION - (now - niuzaoCastAt))
        values.ox_stomp_remains = math.floor(niuzaoRemains + 0.5)
        local stagger = 0
        local healthMax = 1
        pcall(function()
            stagger = UnitStagger("player") or 0
            healthMax = UnitHealthMax("player") or 1
        end)
        if healthMax > 0 then
            values.stagger_pct = math.floor((stagger / healthMax) * 100 + 0.5)
        else
            values.stagger_pct = 0
        end
        values.blackoutCombo = blackoutCombo
    end,
})
