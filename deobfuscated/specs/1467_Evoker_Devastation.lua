--[[
  Evoker_Devastation（湮灭唤魔师）—— 专精配置：湮灭唤魔师（specID 1467）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：b9dc3d.lua（TOC 第 72 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local hoverUntil = 0
local lastCastSpellID = nil
local lastCastAt = 0
local EMPOWER_SPELL_IDS = { 357208, 359073, 382411 }
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(1467, {
    talentLoadouts = {
        {
            name = "大米/团本ADD",
            importString = "CsbBPJc41CfcseY0baneJ1IHrBAAAAAAAAAAAjZAPgZGmBGGjZaMzMNjx2MmZmZmZmZGwMzMGzMLzMDMwMzM2YxyY2asNzwkZyGYbYGMzMzMMA",
        },
        {
            name = "团本单体",
            importString = "CsbBPJc41CfcseY0baneJ1IHrBAAAAAAAAAAAjZgZYGzMgBjZamZmpZM2mxMzMzMzMzAmxMGzMLzMDMwMzM2YxyY2asNzwkZyGYbYgZmZmhB",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        item_healing_stone = "/use [nochanneling] item:5512",
        item_red_potion = "/use [nochanneling] item:271883\n/use [nochanneling] item:271884",
        item_burst_potion = "/use [nochanneling] item:241308\n/use [nochanneling] item:241309\n/use [nochanneling] item:241288\n/use [nochanneling] item:241289",
        trinket1_cd = "/use [nochanneling] 13",
        trinket2_cd = "/use [nochanneling] 14",
        spell_361469 = "/cast [nochanneling]活化烈焰",
        spell_362969 = "/cast [nochanneling]碧蓝打击",
        spell_356995 = "/cast [nochanneling]裂解",
        spell_357211 = "/cast [nochanneling]葬火",
        spell_357208 = "/cast 火焰吐息",
        spell_382411 = "/cast 永恒之涌",
        spell_375087 = "/cast [nochanneling]狂龙之怒",
        spell_357210 = "/cast [nochanneling]!深呼吸",
        spell_1265804 = "/cast [nochanneling]碎裂星辰",
        spell_370553 = "/cast [nochanneling]扭转天平",
        spell_358267 = "/cast [nochanneling]悬空",
        cd_351338 = "/cast [nochanneling]镇压",
        spell_351338_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]镇压",
        focus_interrupt = "/cast [nochanneling,@focus]镇压",
        cd_363916 = "/cast [nochanneling]黑曜鳞片",
    },
    testSpells = { 361469, 362969, 356995, 357211, 357208, 382411, 375087, 357210, 1265804, 370553, 358267 },
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
    ACTION_LABELS = {
        item_healing_stone = "治疗石",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        spell_361469 = "活化烈焰",
        spell_362969 = "碧蓝打击",
        spell_356995 = "裂解",
        spell_357211 = "葬火",
        spell_357208 = "火焰吐息",
        spell_382411 = "永恒之涌",
        spell_375087 = "狂龙之怒",
        spell_357210 = "深呼吸",
        spell_1265804 = "碎裂星辰",
        spell_370553 = "扭转天平",
        spell_358267 = "悬空",
        cd_351338 = "镇压",
        spell_351338_mouseover = "镇压指向",
        focus_interrupt = "镇压焦点",
        cd_363916 = "黑曜鳞片",
    },
    ACTION_TO_KEY = {
        item_healing_stone = ".",
        item_red_potion = ",",
        item_burst_potion = "]",
        trinket1_cd = ";",
        trinket2_cd = "'",
        spell_361469 = "F6",
        spell_362969 = "F7",
        spell_356995 = "F8",
        spell_357211 = "F9",
        spell_357208 = "F10",
        spell_382411 = "F11",
        spell_375087 = "8",
        spell_357210 = "9",
        spell_1265804 = "F12",
        spell_370553 = "0",
        spell_358267 = "-",
        cd_351338 = "=",
        spell_351338_mouseover = "UP",
        focus_interrupt = "\\",
        cd_363916 = "[",
    },
    macroOrder = {
        "spell_361469",
        "spell_362969",
        "spell_356995",
        "spell_357211",
        "spell_357208",
        "spell_382411",
        "spell_375087",
        "spell_357210",
        "spell_1265804",
        "spell_370553",
        "spell_358267",
        "cd_351338",
        "spell_351338_mouseover",
        "focus_interrupt",
        "cd_363916",
        "item_healing_stone",
        "item_red_potion",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    GetExtraValues = function(values)
        local now = GetTime()
        values.hover_duration = math.max(0, hoverUntil - now)
        local empower_spell_id, empower_stage, empower_max_stage = P8BA6426E.GetPlayerEmpowerState(EMPOWER_SPELL_IDS)
        if empower_spell_id == 359073 then
            empower_spell_id = 382411
        end
        values.empower_spell_id = empower_spell_id
        values.empower_stage = empower_stage
        values.empower_max_stage = empower_max_stage
    end,
    actionAvailSpellIDs = { 356995, 357210, 357211, 361469, 362969, 1265804, 382411 },
    spellReadyAliases = {
        [356995] = { 1236949 },
        [357211] = { 1236970 },
        [362969] = { 1237211 },
        [1265804] = {
            1265802,
        },
    },
    OnSpellCast = function(spellID)
        local now = GetTime()
        if spellID == lastCastSpellID and (now - lastCastAt) < 0.5 then
            return
        end
        lastCastSpellID = spellID
        lastCastAt = now
        if spellID == 358267 then
            hoverUntil = now + 6
        end
    end,
})
