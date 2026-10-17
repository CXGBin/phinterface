--[[
  Rogue_Outlaw（狂徒潜行者）—— 专精配置：狂徒潜行者（specID 260）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：85702a.lua（TOC 第 66 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local charge_1298826 = 3
local rechargeTimes = {}
local MAX_CHARGES = 3
local RECHARGE_SECONDS = 60
local rollTheBonesAt = 0
local LOADED_DICE_DURATION = 45
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(260, {
    talentLoadouts = {
        {
            name = "夏天",
            importString = "CQQA5HmDzx68KWyrW/8Y781L7Dgx2MMzMjZmtZmZMzMzsAmZbaZw2MAAAAAAbLzMzwMzMziZmZbAAAAMjBMY2mFzMzoZmFmFWWmWYjBYmZmZgB",
        },
    },
    DEFAULT_MACROS = {
        spell_51690 = "/cast [nochanneling]影舞步",
        spell_1784 = "/cast !潜行",
        spell_315341 = "/cast [nochanneling]正中眉心",
        spell_13750 = "/cast [nochanneling]冲动",
        spell_185763 = "/cast [nochanneling]手枪射击",
        spell_271877 = "/cast [nochanneling]刀锋冲刺",
        spell_13877 = "/cast [nochanneling]剑刃乱舞",
        spell_2098 = "/cast [nochanneling]斩击",
        nearest_dispatch = '/cleartarget\n/script SetCVar("targetNearestDistance",4)\n/targetenemy\n/startattack\n/cast [harm] 斩击\n/targetlasttarget',
        spell_1214909 = "/cast [nochanneling]命运骨骰",
        spell_381989 = "/cast [nochanneling]时运继延",
        spell_193315 = "/cast [nochanneling]影袭",
        nearest_sinister_strike = '/cleartarget\n/script SetCVar("targetNearestDistance",4)\n/targetenemy\n/startattack\n/cast [harm] 影袭\n/targetlasttarget',
        spell_315496 = "/cast [nochanneling]切割",
        spell_1277933 = "/cast [nochanneling]伺机待发",
        spell_315584 = "/cast [nochanneling]速效药膏",
        spell_381637 = "/cast [nochanneling]萎缩药膏",
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
    testSpells = { 51690, 1784, 315341, 13750, 185763, 271877, 13877, 315584, 381637, 381623 },
    ACTION_LABELS = {
        spell_51690 = "影舞步",
        spell_1784 = "潜行",
        spell_315341 = "正中眉心",
        spell_13750 = "冲动",
        spell_185763 = "手枪射击",
        spell_271877 = "刀锋冲刺",
        spell_13877 = "剑刃乱舞",
        spell_2098 = "斩击",
        nearest_dispatch = "就近斩击",
        spell_1214909 = "命运骨骰",
        spell_381989 = "时运继延",
        spell_193315 = "影袭",
        nearest_sinister_strike = "就近影袭",
        spell_315496 = "切割",
        spell_1277933 = "伺机待发",
        spell_315584 = "速效药膏",
        spell_381637 = "萎缩药膏",
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
        spell_51690 = "]",
        spell_1784 = ";",
        spell_315341 = "F11",
        spell_13750 = "[",
        spell_185763 = "F8",
        spell_271877 = "F12",
        spell_13877 = "8",
        spell_2098 = "F9",
        nearest_dispatch = "F10",
        spell_1214909 = "9",
        spell_381989 = "0",
        spell_193315 = "F6",
        nearest_sinister_strike = "F7",
        spell_315496 = "=",
        spell_1277933 = "-",
        spell_315584 = "'",
        spell_381637 = ",",
        spell_381623 = ".",
        cd_5277 = "RIGHT",
        cd_1966 = "HOME",
        cd_31224 = "END",
        cd_185311 = "\\",
        cd_1766 = "INSERT",
        spell_1766_mouseover = "CTRL-F8",
        focus_interrupt = "DELETE",
        item_red_potion = "CTRL-F7",
        item_burst_potion = "UP",
        item_healing_stone = "CTRL-F6",
        trinket1_cd = "DOWN",
        trinket2_cd = "LEFT",
    },
    macroOrder = {
        "spell_51690",
        "spell_1784",
        "spell_315341",
        "spell_13750",
        "spell_185763",
        "spell_271877",
        "spell_13877",
        "spell_2098",
        "nearest_dispatch",
        "spell_1214909",
        "spell_381989",
        "spell_193315",
        "nearest_sinister_strike",
        "spell_315496",
        "spell_1277933",
        "spell_315584",
        "spell_381637",
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
    actionAvailSpellIDs = { 1784, 2098, 185763, 193315, 315496, 315584, 381637, 381623 },
    spellReadyAliases = { [381623] = { 1298826 }, [1784] = { 1252005 } },
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
        if spellID == 1298826 then
            if charge_1298826 > 0 then
                charge_1298826 = charge_1298826 - 1
            end
            local readyAt = (#rechargeTimes > 0) and (rechargeTimes[#rechargeTimes] + RECHARGE_SECONDS)
                or (now + RECHARGE_SECONDS)
            table.insert(rechargeTimes, readyAt)
        end
        if spellID == 13750 then
            rollTheBonesAt = now
        end
        if spellID == 1214909 then
            rollTheBonesAt = 0
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local loadedDiceRemains = 0
        if rollTheBonesAt > 0 then
            local elapsed = now - rollTheBonesAt
            if elapsed < LOADED_DICE_DURATION then
                loadedDiceRemains = LOADED_DICE_DURATION - elapsed
            else
                rollTheBonesAt = 0
            end
        end
        values.buff_loaded_dice = math.floor(loadedDiceRemains + 0.5)
        local ok, result = pcall(GetUnitChargedPowerPoints, "player")
        local charge_supercharger = 0
        if ok and type(result) == "table" then
            charge_supercharger = #result
        end
        values.charge_supercharger = charge_supercharger
        while #rechargeTimes > 0 and now >= rechargeTimes[1] do
            table.remove(rechargeTimes, 1)
            charge_1298826 = math.min(MAX_CHARGES, charge_1298826 + 1)
        end
        values.charge_1298826 = charge_1298826
    end,
})
