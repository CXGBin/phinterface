--[[
  Evoker_Augmentation（增辉唤魔师）—— 专精配置：增辉唤魔师（specID 1473）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：b685a5.lua（TOC 第 71 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local charge_409311 = 2
local rechargeTimes409311 = {}
local destruction_approaches = 0
local destructionApproachesAt = 0
local prescience1Until = 0
local prescience2Until = 0
local hoverUntil = 0
local spatialParadoxUntil = 0
local lastCastSpellID = nil
local lastCastAt = 0
local EMPOWER_SPELL_IDS = { 357208, 396286 }
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(1473, {
    empowerSpellIDs = { 357208, 396286 },
    talentLoadouts = {
        {
            name = "时空守卫M7",
            importString = "CEcBPJc41CfcseY0baneJ1IHrNMmZbmZGMDzMLzMzMjZAAAAAAAAwMzADGTNzMzMAAAAYGzMjZmlxMDMjZgxMWYBGYGGaELYMmZAgB",
        },
        {
            name = "时空守卫M8",
            importString = "CEcBPJc41CfcseY0baneJ1IHrNMmZbmZGMYmZZmZmZMDAAAAAAAAmZGYwYqZmZmBAAAAzYmZMzsMmZgZWmBGzYhFYgZYoRsgxYmBAG",
        },
    },
    DEFAULT_MACROS = {
        spell_442204 = "/castsequence [nochanneling,@cursor] reset=3 鳞长亘古吐息,圣盾术",
        spell_403631 = "/cast [nochanneling,@cursor]!深呼吸",
        spell_409311 = "/cast [nochanneling]先知先觉",
        spell_395160 = "/cast [nochanneling]喷发",
        focus_eruption = "/castsequence [nochanneling,@focus,harm] reset=5 喷发,x\n/cast [nochanneling,@target,harm]喷发",
        spell_396286 = "/cast [nochanneling]扭转天平\n/cast 地壳激变",
        spell_370553 = "/cast [nochanneling]扭转天平",
        spell_361469 = "/cast [nochanneling]活化烈焰",
        spell_357208 = "/cast 火焰吐息",
        spell_395152 = "/cast [nochanneling]黑檀之力",
        spell_362969 = "/cast [nochanneling]碧蓝打击",
        spell_404977 = "/cast [nochanneling]时间跳跃",
        cd_351338 = "/cast [nochanneling]镇压",
        spell_351338_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]镇压",
        focus_interrupt = "/cast [nochanneling,@focus]镇压",
        cd_363916 = "/cast [nochanneling]黑曜鳞片",
        item_red_potion = "/use [nochanneling] item:271883\n/use [nochanneling] item:271884",
        item_burst_potion = "/use [nochanneling] item:241308\n/use [nochanneling] item:241309\n/use [nochanneling] item:241288\n/use [nochanneling] item:241289",
        item_healing_stone = "/use [nochanneling] item:5512",
        trinket1_cd = "/use [nochanneling] 13",
        trinket2_cd = "/use [nochanneling] 14",
    },
    testSpells = { 442204, 403631, 409311, 395160, 396286, 370553, 361469, 357208, 395152, 404977, 362969 },
    ACTION_LABELS = {
        spell_442204 = "鳞长亘古吐息",
        spell_403631 = "时空亘古吐息",
        spell_409311 = "先知先觉",
        spell_395160 = "喷发",
        focus_eruption = "焦点喷发",
        spell_396286 = "地壳激变",
        spell_370553 = "扭转天平",
        spell_361469 = "活化烈焰",
        spell_357208 = "火焰吐息",
        spell_395152 = "黑檀之力",
        spell_362969 = "碧蓝打击",
        spell_404977 = "时间跳跃",
        cd_351338 = "镇压",
        spell_351338_mouseover = "镇压指向",
        focus_interrupt = "镇压焦点",
        cd_363916 = "黑曜鳞片",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_442204 = "8",
        spell_403631 = "UP",
        spell_409311 = "F7",
        spell_395160 = "F8",
        focus_eruption = ",",
        spell_396286 = "F12",
        spell_370553 = "9",
        spell_361469 = "F9",
        spell_357208 = "F11",
        spell_395152 = "F6",
        spell_362969 = "F10",
        spell_404977 = "\\",
        cd_351338 = "0",
        spell_351338_mouseover = "DOWN",
        focus_interrupt = ".",
        cd_363916 = "-",
        item_red_potion = ";",
        item_healing_stone = "'",
        item_burst_potion = "=",
        trinket1_cd = "[",
        trinket2_cd = "]",
    },
    macroOrder = {
        "spell_442204",
        "spell_403631",
        "spell_409311",
        "spell_395160",
        "focus_eruption",
        "spell_396286",
        "spell_370553",
        "spell_361469",
        "spell_357208",
        "spell_395152",
        "spell_362969",
        "spell_404977",
        "cd_351338",
        "cd_363916",
        "spell_351338_mouseover",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 361469, 362969, 395160 },
    spellReadyAliases = { [362969] = { 1237211 }, [395160] = { 1259172 } },
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
        if spellID == 409311 then
            if charge_409311 > 0 then
                charge_409311 = charge_409311 - 1
            end
            local readyAt = (#rechargeTimes409311 > 0) and (rechargeTimes409311[#rechargeTimes409311] + 11)
                or (now + 11)
            table.insert(rechargeTimes409311, readyAt)
        end
        if spellID == 442204 or spellID == 403631 then
            destruction_approaches = 6
            destructionApproachesAt = now
        elseif spellID == 395160 then
            if destruction_approaches > 0 then
                destruction_approaches = destruction_approaches - 1
            end
        end
        if spellID == 409311 then
            if prescience1Until <= now then
                prescience1Until = now + 20
            elseif prescience2Until <= now then
                prescience2Until = now + 20
            else
                prescience1Until = now + 20
            end
        end
        if spellID == 358267 then
            hoverUntil = math.max(hoverUntil, now) + 11
        end
        if spellID == 406732 then
            spatialParadoxUntil = now + 11
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        while #rechargeTimes409311 > 0 and now >= rechargeTimes409311[1] do
            table.remove(rechargeTimes409311, 1)
            charge_409311 = math.min(2, charge_409311 + 1)
        end
        values.charge_409311 = charge_409311
        if now >= destructionApproachesAt + 30 then
            destruction_approaches = 0
        end
        values.destruction_approaches = destruction_approaches
        local prescience_1_duration = 0
        if prescience1Until > now then
            prescience_1_duration = prescience1Until - now
        end
        values.prescience_1_duration = prescience_1_duration
        local prescience_2_duration = 0
        if prescience2Until > now then
            prescience_2_duration = prescience2Until - now
        end
        values.prescience_2_duration = prescience_2_duration
        local hover_duration = 0
        if hoverUntil > now then
            hover_duration = hoverUntil - now
        end
        values.hover_duration = hover_duration
        local spatial_paradox_duration = 0
        if spatialParadoxUntil > now then
            spatial_paradox_duration = spatialParadoxUntil - now
        end
        values.spatial_paradox_duration = spatial_paradox_duration
        local empower_spell_id, empower_stage, empower_max_stage = P8BA6426E.GetPlayerEmpowerState(EMPOWER_SPELL_IDS)
        values.empower_spell_id = empower_spell_id
        values.empower_stage = empower_stage
        values.empower_max_stage = empower_max_stage
    end,
})
