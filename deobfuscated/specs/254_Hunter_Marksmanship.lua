--[[
  Hunter_Marksmanship（射击猎人）—— 专精配置：射击猎人（specID 254）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：47d05d.lua（TOC 第 58 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastSpearheadAt = 0
local spearheadConsumed = false
local lunarStormReadyUntil = 0
local explosiveShotCDUntil = 0
local cd260240Until = 0
local cd389019Until = 0
local cd257621Until = 0
local lastCastSpellID = nil
local lastCastAt = 0
local function knownRemaining(spellID, readyAt, now)
    if not P8BA6426E.IsSpellKnown(spellID) then
        return 601
    end
    if readyAt <= now then
        return 0
    end
    return math.ceil(readyAt - now)
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
P8BA6426E.RegisterClass(254, {
    talentLoadouts = {
        {
            name = "哨兵大米",
            importString = "C4PAAAAAAAAAAAAAAAAAAAAAAwCMwMGNWGAzgNAAAAAAAAwMmxMMjZmxMYMNjBz222MzMzMzMzgZWGmBAAYegZGGAzYjZxAswMbzYA",
        },
    },
    DEFAULT_MACROS = {
        spell_19434 = "/cast [nochanneling]瞄准射击",
        spell_257620 = "/cast [nochanneling]多重射击",
        spell_56641 = "/cast [nochanneling]稳固射击",
        spell_288613 = "/cast [nochanneling]百发百中",
        spell_257044 = "/cast [nochanneling]急速射击",
        spell_260243 = "/cast [nochanneling,@cursor]乱射",
        spell_212431 = "/cast [nochanneling]爆炸射击",
        spell_212431_retarget = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling]爆炸射击\n/targetlasttarget",
        spell_185358 = "/cast [nochanneling]奥术射击",
        spell_257284 = "/cast [nochanneling]猎人印记",
        spell_53351 = "/cast [nochanneling]夺命射击",
        spell_53351_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]夺命射击",
        cd_109304 = "/cast [nochanneling]意气风发",
        cd_264735 = "/cast [nochanneling]优胜劣汰",
        cd_186265 = "/cast [nochanneling]灵龟守护",
        cd_147362 = "/cast [nochanneling]反制射击",
        spell_147362_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]反制射击",
        focus_interrupt = "/cast [nochanneling,@focus]反制射击",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 19434, 257620, 56641, 288613, 257044, 260243, 212431, 185358, 257284, 53351 },
    ACTION_LABELS = {
        spell_19434 = "瞄准射击",
        spell_257620 = "多重射击",
        spell_56641 = "稳固射击",
        spell_288613 = "百发百中",
        spell_257044 = "急速射击",
        spell_260243 = "乱射",
        spell_212431 = "爆炸射击",
        spell_212431_retarget = "切目标爆炸",
        spell_185358 = "奥术射击",
        spell_257284 = "猎人印记",
        spell_53351 = "夺命射击",
        spell_53351_mouseover = "指向夺命射击",
        cd_109304 = "意气风发",
        cd_264735 = "优胜劣汰",
        cd_186265 = "灵龟守护",
        cd_147362 = "反制射击",
        spell_147362_mouseover = "反制射击指向",
        focus_interrupt = "反制射击焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_19434 = "F6",
        spell_257620 = "F11",
        spell_56641 = "F9",
        spell_288613 = "0",
        spell_257044 = "F8",
        spell_260243 = "9",
        spell_212431 = "F12",
        spell_212431_retarget = "8",
        spell_185358 = "F10",
        spell_257284 = "-",
        spell_53351 = "LEFT",
        spell_53351_mouseover = "F7",
        cd_109304 = "=",
        cd_264735 = "[",
        cd_186265 = "]",
        cd_147362 = ";",
        spell_147362_mouseover = "RIGHT",
        focus_interrupt = "'",
        item_red_potion = "DOWN",
        item_healing_stone = "UP",
        item_burst_potion = ",",
        trinket1_cd = ".",
        trinket2_cd = "\\",
    },
    macroOrder = {
        "spell_19434",
        "spell_257620",
        "spell_56641",
        "spell_288613",
        "spell_257044",
        "spell_260243",
        "spell_212431",
        "spell_212431_retarget",
        "spell_185358",
        "spell_257284",
        "spell_53351",
        "spell_53351_mouseover",
        "cd_109304",
        "cd_264735",
        "cd_186265",
        "cd_147362",
        "spell_147362_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 56641, 185358, 257284, 257620 },
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
        if spellID == 288613 then
            lastSpearheadAt = now
            spearheadConsumed = false
            if P8BA6426E.IsSpellKnown(1264902) then
                lunarStormReadyUntil = now + 17
            else
                lunarStormReadyUntil = 0
            end
        end
        if spellID == 392060 then
            spearheadConsumed = true
        end
        if spellID == 1264949 then
            lunarStormReadyUntil = 0
        end
        if spellID == 212431 then
            if explosiveShotCDUntil > now then
                explosiveShotCDUntil = 0
            else
                explosiveShotCDUntil = now + 3
            end
        end
        if spellID == 257620 then
            cd257621Until = now + 20
        end
        if spellID == 185358 or spellID == 257620 then
            cd260240Until = 0
        end
        if spellID == 19434 or spellID == 257044 then
            cd257621Until = 0
        end
        if spellID == 19434 then
            cd389019Until = 0
        end
        if spellID == 19434 then
            cd260240Until = now + 15
        end
        if spellID == 257044 then
            cd389019Until = now + 15
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local spell_53351 = false
        pcall(function()
            local isSpellUsable = P8BA6426E.IsSpellUsable(53351)
            local spellCooldownRemaining = P8BA6426E.GetSpellCooldownRemaining(53351)
            spell_53351 = isSpellUsable and spellCooldownRemaining == 0
        end)
        values.spell_53351 = spell_53351
        local spell_392060 = false
        if lastSpearheadAt > 0 and not spearheadConsumed then
            spell_392060 = (now - lastSpearheadAt) <= 15
        end
        values.spell_392060 = spell_392060
        values.spell_1264949 = P8BA6426E.IsSpellKnown(1264902) and now < lunarStormReadyUntil
        values.cd_473520 = knownRemaining(473520, explosiveShotCDUntil, now)
        values.cd_260240 = knownRemaining(260240, cd260240Until, now)
        values.cd_389019 = knownRemaining(389019, cd389019Until, now)
        values.cd_257621 = knownRemaining(257621, cd257621Until, now)
    end,
})
