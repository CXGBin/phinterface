--[[
  Rogue_Assassination（奇袭潜行者）—— 专精配置：奇袭潜行者（specID 259）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：d69975.lua（TOC 第 79 个加载的插件脚本）

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
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(259, {
    talentLoadouts = {
        {
            name = "大米死亡猎手",
            importString = "CMQAAAAAAAAAAAAAAAAAAAAAAYmlZmFDGAAAAAYWGsNDAAAAAotlZmZmZmxYbmZmtZWmZmHYmxMDmxMjxAsZWGYALglhJwwiBzMADGA",
        },
        {
            name = "团本死亡猎手",
            importString = "CMQAAAAAAAAAAAAAAAAAAAAAAYmlZmFDGAAAAAYWGsNDAAAAAIbzMzMzMjxyMzMbzsMzMPw8AjZGjhZGjBwALwMGNmNAbDYzAgZmxYA",
        },
        {
            name = "团本命缚者",
            importString = "CMQAAAAAAAAAAAAAAAAAAAAAAYmlZmFDGAAAAAYWGsNDAAAAAIbzMzMzMjxyMzMbzsMzMPw8AjZGjhZGjBwALwMGNmNAbDYzAgZmxYA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_1329 = "/cast [nochanneling]毁伤",
        spell_1329_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]毁伤\n/targetlasttarget",
        spell_32645 = "/cast [nochanneling]毒伤",
        spell_703 = "/cast [nochanneling]锁喉",
        spell_1943 = "/cast [nochanneling]割裂",
        spell_51723 = "/cast [nochanneling]刀扇",
        cd_5938 = "/cast [nochanneling]毒刃",
        cd_5938_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]毒刃\n/targetlasttarget",
        spell_360194 = "/cast [nochanneling]死亡印记",
        spell_385627 = "/cast [nochanneling]君王之灾",
        spell_1856 = "/cast [nochanneling]消失",
        spell_8676 = "/cast [nochanneling]伏击",
        spell_315496 = "/cast [nochanneling]切割",
        spell_1252005 = "/cast !潜行",
        spell_1247227 = "/cast [nochanneling]猩红风暴",
        spell_185565 = "/cast [nochanneling]剧毒之刃",
        spell_1293340 = "/cast [nochanneling]死亡印记",
        spell_2823 = "/cast [nochanneling]夺命药膏",
        spell_381637 = "/cast [nochanneling]萎缩药膏",
        spell_381664 = "/cast [nochanneling]增效药膏",
        spell_3408 = "/cast [nochanneling]减速药膏",
        spell_381623 = "/cast [nochanneling]蓟叶茶",
        cd_5277 = "/cast [nochanneling]闪避",
        cd_1966 = "/cast [nochanneling]佯攻",
        cd_31224 = "/cast [nochanneling]暗影斗篷",
        cd_185311 = "/cast 猩红之瓶",
        cd_1766 = "/cast [nochanneling]脚踢",
        spell_1766_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]脚踢",
        focus_interrupt = "/cast [nochanneling,@focus,harm,nodead]脚踢",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_healing_stone = "/use item:5512",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    DIRECT_SPELL_ACTIONS = { spell_360194 = 360194, spell_1293340 = 1293340 },
    testSpells = {
        1329,
        32645,
        703,
        1943,
        51723,
        5938,
        360194,
        385627,
        381623,
        1856,
        8676,
        315496,
        1252005,
        1247227,
        185565,
        1293340,
        2823,
        381637,
        381664,
        3408,
    },
    ACTION_LABELS = {
        spell_1329 = "毁伤",
        spell_1329_nearest = "就近毁伤",
        spell_32645 = "毒伤",
        spell_703 = "锁喉",
        spell_1943 = "割裂",
        spell_51723 = "刀扇",
        cd_5938 = "毒刃",
        cd_5938_nearest = "就近毒刃",
        spell_360194 = "死亡印记",
        spell_385627 = "君王之灾",
        spell_1856 = "消失",
        spell_8676 = "伏击",
        spell_315496 = "切割",
        spell_1252005 = "潜行",
        spell_1247227 = "猩红风暴",
        spell_185565 = "剧毒之刃",
        spell_1293340 = "死亡猎手印记",
        spell_2823 = "夺命药膏",
        spell_381637 = "萎缩药膏",
        spell_381664 = "增效药膏",
        spell_3408 = "减速药膏",
        spell_381623 = "蓟叶茶",
        cd_5277 = "闪避",
        cd_1966 = "佯攻",
        cd_31224 = "暗影斗篷",
        cd_185311 = "猩红之瓶",
        cd_1766 = "脚踢",
        spell_1766_mouseover = "脚踢指向",
        focus_interrupt = "脚踢焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_1329 = "F7",
        spell_1329_nearest = "F8",
        spell_32645 = "F10",
        spell_703 = "F6",
        spell_1943 = "F11",
        spell_51723 = "F12",
        cd_5938 = "8",
        cd_5938_nearest = "9",
        spell_360194 = "]",
        spell_385627 = ";",
        spell_1856 = "'",
        spell_8676 = "F9",
        spell_315496 = "[",
        spell_1252005 = ",",
        spell_1247227 = "0",
        spell_185565 = "-",
        spell_1293340 = "=",
        spell_2823 = ".",
        spell_381637 = "\\",
        spell_381664 = "UP",
        spell_3408 = "DOWN",
        spell_381623 = "LEFT",
        cd_5277 = "CTRL-F9",
        cd_1966 = "HOME",
        cd_31224 = "END",
        cd_185311 = "RIGHT",
        cd_1766 = "INSERT",
        spell_1766_mouseover = "CTRL-F12",
        focus_interrupt = "DELETE",
        item_red_potion = "CTRL-F11",
        item_healing_stone = "CTRL-F10",
        item_burst_potion = "CTRL-F6",
        trinket1_cd = "CTRL-F7",
        trinket2_cd = "CTRL-F8",
    },
    macroOrder = {
        "spell_1329",
        "spell_1329_nearest",
        "spell_32645",
        "spell_703",
        "spell_1943",
        "spell_51723",
        "cd_5938",
        "cd_5938_nearest",
        "spell_360194",
        "spell_385627",
        "spell_1856",
        "spell_8676",
        "spell_315496",
        "spell_1252005",
        "spell_1247227",
        "spell_185565",
        "spell_1293340",
        "spell_2823",
        "spell_381637",
        "spell_381664",
        "spell_3408",
        "spell_381623",
        "cd_5277",
        "cd_1966",
        "cd_31224",
        "cd_185311",
        "cd_1766",
        "focus_interrupt",
        "spell_1766_mouseover",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    consumableItems = {
        { id = "item_red_potion", label = "红药水", cooldown = 300, itemIDs = { 271883, 271884 } },
        { id = "item_healing_stone", label = "治疗石", cooldown = 60, itemIDs = { 5512 } },
        {
            id = "item_burst_potion",
            label = "爆发药水",
            cooldown = 300,
            itemIDs = { 241308, 241309, 241288, 241289 },
        },
    },
    actionAvailSpellIDs = {
        1329,
        1943,
        2823,
        3408,
        8676,
        32645,
        51723,
        185565,
        315496,
        381637,
        381664,
        1247227,
        1252005,
        381623,
    },
    spellReadyAliases = { [1943] = { 1270203, 1270243 }, [381623] = { 1298826 }, [1252005] = { 1784 } },
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
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        while #rechargeTimes > 0 and now >= rechargeTimes[1] do
            table.remove(rechargeTimes, 1)
            charge_1298826 = math.min(MAX_CHARGES, charge_1298826 + 1)
        end
        values.charge_1298826 = charge_1298826
        local ok, result = pcall(GetUnitChargedPowerPoints, "player")
        local charge_supercharger = 0
        if ok and type(result) == "table" then
            charge_supercharger = #result
        end
        values.charge_supercharger = charge_supercharger
    end,
})
