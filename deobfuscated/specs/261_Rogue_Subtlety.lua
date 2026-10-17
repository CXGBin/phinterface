--[[
  Rogue_Subtlety（敏锐潜行者）—— 专精配置：敏锐潜行者（specID 261）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：b5a193.lua（TOC 第 70 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local SHADOW_BLADES_ID = 121471
local SHADOW_DANCE_ID = 185313
local SHADOW_BLADES_DURATION = 16
local SHADOW_DANCE_RECHARGE = 20
local SHADOW_DANCE_MAX_CHARGES = 2
local lastCastSpellID = nil
local lastCastAt = 0
local shadowBladesUntil = 0
local target_revision = 1
local subtlety_entry_generation = 1
local targetFrame = CreateFrame("Frame")
targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetFrame:SetScript("OnEvent", function()
    target_revision = target_revision % 99 + 1
end)
local shadowDanceRecharges = {}
local charge_1298826 = 3
local rechargeTimes1298826 = {}
local MAX_CHARGES_1298826 = 3
local RECHARGE_SECONDS_1298826 = 60
local function remainingCeil(readyAt, now)
    local remaining = readyAt - now
    if remaining <= 0 then
        return 0
    end
    return math.ceil(remaining)
end
local function dropExpired(queue, now)
    while queue[1] and queue[1] <= now do
        table.remove(queue, 1)
    end
end
local function consumeShadowDance(now)
    dropExpired(shadowDanceRecharges, now)
    if #shadowDanceRecharges >= SHADOW_DANCE_MAX_CHARGES then
        return
    end
    local last = shadowDanceRecharges[#shadowDanceRecharges] or now
    table.insert(shadowDanceRecharges, math.max(last, now) + SHADOW_DANCE_RECHARGE)
end
local function getShadowDanceCharges(now)
    dropExpired(shadowDanceRecharges, now)
    return math.max(0, SHADOW_DANCE_MAX_CHARGES - #shadowDanceRecharges)
end
local function getShadowDanceCooldown(now)
    dropExpired(shadowDanceRecharges, now)
    local last = shadowDanceRecharges[#shadowDanceRecharges]
    if not last then
        return 0
    end
    return remainingCeil(last, now)
end
P8BA6426E.RegisterClass(261, {
    talentLoadouts = {
        {
            name = "团本单体",
            importString = "CUQA5HmDzx68KWyrW/8Y781L7Dgx2MAAAAAwsMGLTMbbjxMDDzMzMzgZbGzYbbmZmZmZMYMz2AAAAwgxsYWGYALglhJkZBzwMDwMGA",
        },
        {
            name = "大米通用",
            importString = "CUQAAAAAAAAAAAAAAAAAAAAAAAgx2MAAAAAwsMGLTMbbjxMDjZmZmZGGbzYGbLjZmZmZMYMz2AAAAwMMmNzyADYBsMMBmFMDzMAzYA",
        },
    },
    DEFAULT_MACROS = {
        spell_121471 = "/cast [nochanneling]暗影之刃",
        spell_185313 = "/cast [nochanneling]暗影之舞",
        spell_1856 = "/cast [nochanneling]消失",
        spell_1784 = "/cast !潜行",
        spell_185438 = "/cast [nochanneling]暗影打击",
        spell_197835 = "/cast [nochanneling]袖剑风暴",
        spell_280719 = "/cast [nochanneling]影分身",
        spell_319175 = "/cast [nochanneling]黑火药",
        spell_196819 = "/cast [nochanneling]刺骨",
        spell_196819_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]刺骨\n/targetlasttarget",
        spell_426591 = "/cast [nochanneling]赤喉之咬",
        spell_426591_burst = "/cast 暗影之舞\n/cast 暗影之刃",
        spell_53 = "/cast [nochanneling]背刺",
        spell_53_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]背刺\n/targetlasttarget",
        spell_315584 = "/cast [nochanneling]速效药膏",
        spell_5761 = "/cast [nochanneling]迟钝药膏",
        spell_381623 = "/cast [nochanneling]蓟叶茶",
        cd_5277 = "/cast [nochanneling]闪避",
        cd_1966 = "/cast [nochanneling]佯攻",
        cd_31224 = "/cast [nochanneling]暗影斗篷",
        cd_185311 = "/cast 猩红之瓶",
        cd_1766 = "/cast [nochanneling]脚踢",
        spell_1766_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]脚踢",
        focus_interrupt = "/cast [nochanneling,@focus]脚踢",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        121471,
        185313,
        1856,
        1784,
        185438,
        197835,
        280719,
        319175,
        196819,
        426591,
        53,
        315584,
        5761,
        381623,
    },
    ACTION_LABELS = {
        spell_121471 = "暗影之刃",
        spell_185313 = "暗影之舞",
        spell_1856 = "消失",
        spell_1784 = "潜行",
        spell_185438 = "暗影打击",
        spell_197835 = "袖剑风暴",
        spell_280719 = "影分身",
        spell_319175 = "黑火药",
        spell_196819 = "刺骨",
        spell_196819_nearest = "就近刺骨",
        spell_426591 = "赤喉之咬",
        spell_426591_burst = "影舞暗刃",
        spell_53 = "背刺",
        spell_53_nearest = "就近背刺",
        spell_315584 = "速效药膏",
        spell_5761 = "迟钝药膏",
        spell_381623 = "蓟叶茶",
        cd_5277 = "闪避",
        cd_1966 = "佯攻",
        cd_31224 = "暗影斗篷",
        cd_185311 = "猩红之瓶",
        cd_1766 = "脚踢",
        spell_1766_mouseover = "脚踢指向",
        focus_interrupt = "脚踢焦点",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_121471 = "-",
        spell_185313 = "F6",
        spell_1856 = "[",
        spell_1784 = "]",
        spell_185438 = "F7",
        spell_197835 = "F8",
        spell_280719 = "0",
        spell_319175 = "F9",
        spell_196819 = "F10",
        spell_196819_nearest = "F11",
        spell_426591 = "9",
        spell_426591_burst = "=",
        spell_53 = "F12",
        spell_53_nearest = "8",
        spell_315584 = ";",
        spell_5761 = "'",
        spell_381623 = ",",
        cd_5277 = "LEFT",
        cd_1966 = "RIGHT",
        cd_31224 = "HOME",
        cd_185311 = ".",
        cd_1766 = "INSERT",
        spell_1766_mouseover = "CTRL-F7",
        focus_interrupt = "DELETE",
        item_red_potion = "CTRL-F6",
        item_healing_stone = "END",
        item_burst_potion = "\\",
        trinket1_cd = "UP",
        trinket2_cd = "DOWN",
    },
    macroOrder = {
        "spell_121471",
        "spell_185313",
        "spell_1856",
        "spell_1784",
        "spell_185438",
        "spell_197835",
        "spell_280719",
        "spell_319175",
        "spell_196819",
        "spell_196819_nearest",
        "spell_426591",
        "spell_426591_burst",
        "spell_53",
        "spell_53_nearest",
        "spell_315584",
        "spell_5761",
        "spell_381623",
        "cd_5277",
        "cd_1966",
        "cd_31224",
        "cd_185311",
        "cd_1766",
        "spell_1766_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 1784, 5761, 196819, 315584, 319175, 381623 },
    spellReadyAliases = {
        [53] = { 1269209, 1269664 },
        [196819] = { 1269205, 1269630 },
        [197835] = { 1269340, 1269678 },
        [319175] = { 1269565, 1269634 },
        [381623] = { 1298826 },
        [1784] = { 1252005 },
    },
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
        if spellID == SHADOW_DANCE_ID or spellID == 1856 then
            subtlety_entry_generation = subtlety_entry_generation % 99 + 1
        end
        if spellID == SHADOW_BLADES_ID then
            shadowBladesUntil = now + SHADOW_BLADES_DURATION
        elseif spellID == SHADOW_DANCE_ID then
            consumeShadowDance(now)
        end
        if spellID == 1298826 then
            if charge_1298826 > 0 then
                charge_1298826 = charge_1298826 - 1
            end
            local readyAt = (#rechargeTimes1298826 > 0)
                    and (rechargeTimes1298826[#rechargeTimes1298826] + RECHARGE_SECONDS_1298826)
                or (now + RECHARGE_SECONDS_1298826)
            table.insert(rechargeTimes1298826, readyAt)
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        values.charge_shadow_dance = getShadowDanceCharges(now)
        values.cd_185313 = getShadowDanceCooldown(now)
        values.buff_shadow_blades = remainingCeil(shadowBladesUntil, now)
        while #rechargeTimes1298826 > 0 and now >= rechargeTimes1298826[1] do
            table.remove(rechargeTimes1298826, 1)
            charge_1298826 = math.min(MAX_CHARGES_1298826, charge_1298826 + 1)
        end
        values.charge_1298826 = charge_1298826
        local spell_185438_ready = false
        pcall(function()
            local isSpellUsable = P8BA6426E.IsSpellUsable(185438)
            spell_185438_ready = isSpellUsable and P8BA6426E.GetSpellCooldownRemaining(185438) == 0
        end)
        values.spell_185438_ready = spell_185438_ready
        local ok, talent_1265952 = pcall(P8BA6426E.IsSpellKnown, 1265952)
        if ok and type(talent_1265952) == "boolean" then
            values.talent_1265952 = talent_1265952
        end
        local ok, result = pcall(GetUnitChargedPowerPoints, "player")
        local charge_supercharger = 0
        if ok and type(result) == "table" then
            charge_supercharger = #result
        end
        values.charge_supercharger = charge_supercharger
        values.target_revision = target_revision
        values.subtlety_entry_generation = subtlety_entry_generation
    end,
})
