--[[
  Shaman_Enhancement（增强萨满）—— 专精配置：增强萨满（specID 263）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：127748.lua（TOC 第 45 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local arc_discharge = 0
local lastCastSpellID = nil
local lastCastAt = 0
local function targetHasDebuff(spellID)
    if not spellID then
        return false
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40, 1 do
            local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL")
            if not aura then
                break
            end
            if P8BA6426E.SafeNumber(aura.spellId) == spellID then
                return true
            end
        end
    end
    return false
end
P8BA6426E.RegisterClass(263, {
    talentLoadouts = {
        {
            name = "夏天",
            importString = "CcQALMl7AwW51MWzGneuHE3tPOzMzgZmZmZmhZmZAAAAAAAAA2AsZGDbkFYGGawCAzyMmxYZZGYmZbsMzMz8AGLMDAwMMmZYmAzMYwYA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_444995 = "/cancelaura 幽魂之狼\n/cast [@player] 涌动图腾",
        spell_17364 = "/cancelaura 幽魂之狼\n/cast 风暴打击",
        spell_17364_nearest = '#showtooltip 风暴打击\n/cleartarget\n/script SetCVar("targetNearestDistance",5)\n/targetenemy\n/startattack\n/cast [harm] 风暴打击\n/targetlasttarget',
        spell_60103 = "/cancelaura 幽魂之狼\n/cast 熔岩猛击",
        spell_60103_nearest = '#showtooltip 熔岩猛击\n/cleartarget\n/script SetCVar("targetNearestDistance",5)\n/targetenemy\n/startattack\n/cast [harm] 熔岩猛击\n/targetlasttarget',
        spell_384352 = "/cancelaura 幽魂之狼\n/cast 毁灭之风",
        spell_187874 = "/cancelaura 幽魂之狼\n/cast 毁灭闪电",
        spell_197214 = "/cancelaura 幽魂之狼\n/cast 裂地术",
        spell_188196 = "/cancelaura 幽魂之狼\n/cast 闪电箭",
        spell_188443 = "/cancelaura 幽魂之狼\n/cast 闪电链",
        spell_57994 = "/cancelaura 幽魂之狼\n/cast 风剪",
        spell_470057 = "/cancelaura 幽魂之狼\n/cast 流电炽焰",
        spell_108271 = "/cancelaura 幽魂之狼\n/cast 星界转移",
        spell_1218090 = "/cancelaura 幽魂之狼\n/cast 始源风暴",
        spell_114051 = "/cancelaura 幽魂之狼\n/cast 升腾",
        spell_8004 = "/cast 治疗之涌",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        cd_108271 = "/cancelaura 幽魂之狼\n/cast 星界转移",
        cd_57994 = "/cancelaura 幽魂之狼\n/cast 风剪",
        spell_57994_mouseover = "/cancelaura 幽魂之狼\n/cast [@mouseover,harm,nodead,exists] 风剪",
        focus_interrupt = "/cancelaura 幽魂之狼\n/cast [@focus]风剪",
        cd_198103 = "/cast 土元素",
        spell_462854 = "/cast 天怒",
        spell_370 = "/cancelaura 幽魂之狼\n/cast 净化术",
        spell_51886 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]净化灵魂",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        444995,
        17364,
        60103,
        384352,
        57994,
        470057,
        188196,
        188443,
        187874,
        197214,
        108271,
        1218090,
        114051,
        8004,
        370,
        51886,
    },
    ACTION_LABELS = {
        spell_444995 = "涌动图腾",
        spell_17364 = "风暴打击",
        spell_17364_nearest = "就近风打",
        spell_60103 = "熔岩猛击",
        spell_60103_nearest = "就近火打",
        spell_384352 = "毁灭之风",
        spell_187874 = "毁灭闪电",
        spell_197214 = "裂地术",
        spell_188196 = "闪电箭",
        spell_188443 = "闪电链",
        spell_57994 = "风剪",
        spell_470057 = "流电炽焰",
        spell_108271 = "星界转移",
        spell_1218090 = "始源风暴",
        spell_114051 = "升腾",
        spell_8004 = "治疗之涌",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        cd_108271 = "星界转移",
        cd_57994 = "风剪",
        spell_57994_mouseover = "风剪指向",
        focus_interrupt = "风剪焦点",
        cd_198103 = "土元素",
        spell_462854 = "天怒",
        spell_370 = "净化术",
        spell_51886 = "指向净化灵魂",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_444995 = "F6",
        spell_17364 = "F7",
        spell_17364_nearest = "=",
        spell_60103 = "F8",
        spell_60103_nearest = "[",
        spell_384352 = "0",
        spell_187874 = "F9",
        spell_197214 = "F10",
        spell_188196 = "F12",
        spell_188443 = "8",
        spell_57994 = ";",
        spell_470057 = "9",
        spell_108271 = "'",
        spell_1218090 = "F11",
        spell_114051 = "-",
        spell_8004 = "]",
        item_red_potion = "DELETE",
        item_burst_potion = "DOWN",
        item_healing_stone = "HOME",
        cd_108271 = "'",
        cd_57994 = ";",
        spell_57994_mouseover = "END",
        focus_interrupt = "INSERT",
        cd_198103 = ",",
        spell_462854 = ".",
        spell_370 = "\\",
        spell_51886 = "UP",
        trinket1_cd = "LEFT",
        trinket2_cd = "RIGHT",
    },
    macroOrder = {
        "spell_444995",
        "spell_17364",
        "spell_17364_nearest",
        "spell_60103",
        "spell_60103_nearest",
        "spell_384352",
        "spell_187874",
        "spell_197214",
        "spell_188196",
        "spell_188443",
        "spell_57994",
        "spell_470057",
        "spell_108271",
        "spell_1218090",
        "spell_114051",
        "spell_8004",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "cd_108271",
        "cd_57994",
        "spell_57994_mouseover",
        "cd_198103",
        "spell_462854",
        "spell_370",
        "spell_51886",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 8004, 188196, 188443, 462854, 1218090, 370 },
    spellReadyAliases = { [1218090] = { 1218047, 1218125 } },
    primordialStormAvailable = false,
    primordialStormExpires = 0,
    whirlingFireAvailable = false,
    whirlingFireExpires = 0,
    whirlingAirAvailable = false,
    whirlingAirExpires = 0,
    whirlingEarthAvailable = false,
    whirlingEarthExpires = 0,
    GetExtraValues = function(values)
        local now = GetTime()
        local classData = P8BA6426E.classData
        local cd_primordial_storm = 0
        if classData.primordialStormAvailable then
            if now > classData.primordialStormExpires then
                classData.primordialStormAvailable = false
            else
                local remaining = classData.primordialStormExpires - now
                cd_primordial_storm = math.floor(remaining + 0.5)
            end
        end
        values.cd_primordial_storm = cd_primordial_storm
        now = GetTime()
        if classData.whirlingFireAvailable and now > classData.whirlingFireExpires then
            classData.whirlingFireAvailable = false
        end
        values.buff_whirling_fire = classData.whirlingFireAvailable
        if classData.whirlingAirAvailable and now > classData.whirlingAirExpires then
            classData.whirlingAirAvailable = false
        end
        values.buff_whirling_air = classData.whirlingAirAvailable
        if classData.whirlingEarthAvailable and now > classData.whirlingEarthExpires then
            classData.whirlingEarthAvailable = false
        end
        values.buff_whirling_earth = classData.whirlingEarthAvailable
        values.arc_discharge = arc_discharge
        local stacks_maelstrom = 0
        pcall(function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
            if aura and aura.applications then
                stacks_maelstrom = aura.applications
            end
        end)
        values.stacks_maelstrom = stacks_maelstrom
    end,
    OnSpellCast = function(spellID)
        local classData = P8BA6426E.classData
        local now = GetTime()
        if spellID == lastCastSpellID and (now - lastCastAt) < 0.5 then
            return
        end
        lastCastSpellID = spellID
        lastCastAt = now
        if spellID == 197214 then
            classData.primordialStormAvailable = true
            classData.primordialStormExpires = now + 15
            classData.whirlingEarthAvailable = false
        elseif spellID == 1218090 then
            classData.primordialStormAvailable = false
        elseif spellID == 444995 then
            classData.whirlingFireAvailable = true
            classData.whirlingFireExpires = now + 15
            classData.whirlingAirAvailable = true
            classData.whirlingAirExpires = now + 15
            classData.whirlingEarthAvailable = true
            classData.whirlingEarthExpires = now + 15
        elseif spellID == 60103 then
            classData.whirlingFireAvailable = false
            if arc_discharge > 0 then
                arc_discharge = arc_discharge - 1
            end
        elseif spellID == 188196 then
            classData.whirlingAirAvailable = false
        elseif spellID == 188443 then
            classData.whirlingAirAvailable = false
            if arc_discharge > 0 then
                arc_discharge = arc_discharge - 1
            end
        elseif spellID == 17364 then
            if arc_discharge > 0 then
                arc_discharge = arc_discharge - 1
            end
        elseif spellID == 452201 then
            arc_discharge = arc_discharge + 1
        end
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
