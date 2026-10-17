--[[
  Hunter_Survival（生存猎人）—— 专精配置：生存猎人（specID 255）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：bfe008.lua（TOC 第 74 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local raptor_swipe = false
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(255, {
    talentLoadouts = {
        {
            name = "ptr兽群领袖",
            importString = "C8PAAAAAAAAAAAAAAAAAAAAAAMgxMG2gFYGGawiZmZGDLDAAAAAAzYGzgxYGzwyYaGAAAgBAPwYZZmZWMzMDzMjBMzGwwYMzsZAA",
        },
    },
    DEFAULT_MACROS = {
        spell_259489 = "/cast [nochanneling]杀戮命令\n/petattack",
        spell_193265 = "/cast [nochanneling]投掷手斧",
        spell_259495 = "/cast [nochanneling]野火炸弹",
        spell_186270 = "/cast [nochanneling]猛禽一击",
        spell_186270_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]猛禽一击\n/targetlasttarget",
        spell_1250646 = "/cast [nochanneling]狩魂一击",
        spell_1261193 = "/cast [nochanneling]爆裂火铳",
        spell_186289 = "/cast [nochanneling]雄鹰守护",
        cd_109304 = "/cast [nochanneling]意气风发",
        cd_264735 = "/cast [nochanneling]优胜劣汰",
        cd_186265 = "/cast [nochanneling]灵龟守护",
        cd_187707 = "/cast [nochanneling]压制",
        spell_187707_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]压制",
        focus_interrupt = "/cast [nochanneling,@focus]压制",
        spell_883 = "/cast [@pet,dead] 复活宠物\n/castsequence [nopet] reset=3 召唤宠物 1, 复活宠物\n/cast 治疗宠物",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 259489, 193265, 259495, 186270, 1250646, 1261193, 186289 },
    ACTION_LABELS = {
        spell_259489 = "杀戮命令",
        spell_193265 = "投掷手斧",
        spell_259495 = "野火炸弹",
        spell_186270 = "猛禽一击",
        spell_186270_nearest = "就近猛禽一击",
        spell_1250646 = "狩魂一击",
        spell_1261193 = "爆裂火铳",
        spell_186289 = "雄鹰守护",
        cd_109304 = "意气风发",
        cd_264735 = "优胜劣汰",
        cd_186265 = "灵龟守护",
        cd_187707 = "压制",
        spell_187707_mouseover = "压制指向",
        focus_interrupt = "压制焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        spell_883 = "召唤宠物",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_259489 = "F6",
        spell_193265 = "F7",
        spell_259495 = "F8",
        spell_186270 = "F9",
        spell_186270_nearest = "F10",
        spell_1250646 = "F11",
        spell_1261193 = "F12",
        spell_186289 = "8",
        spell_883 = "]",
        cd_109304 = "9",
        cd_264735 = "0",
        cd_186265 = "-",
        cd_187707 = "=",
        spell_187707_mouseover = "UP",
        focus_interrupt = "[",
        item_red_potion = "\\",
        item_healing_stone = ".",
        item_burst_potion = ";",
        trinket1_cd = "'",
        trinket2_cd = ",",
    },
    macroOrder = {
        "spell_259489",
        "spell_193265",
        "spell_259495",
        "spell_186270",
        "spell_186270_nearest",
        "spell_1250646",
        "spell_1261193",
        "spell_186289",
        "cd_109304",
        "cd_264735",
        "cd_186265",
        "cd_187707",
        "spell_187707_mouseover",
        "focus_interrupt",
        "spell_883",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 883, 186270, 193265 },
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
        if spellID == 186270 then
            raptor_swipe = true
        elseif spellID == 1262293 then
            raptor_swipe = false
        end
    end,
    GetExtraValues = function(values)
        values.raptor_swipe = raptor_swipe
        values.pet_exists = UnitExists("pet") == true
        local stacks_tip_of_spear = 0
        pcall(function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286)
            if aura and aura.applications then
                stacks_tip_of_spear = aura.applications
            end
        end)
        values.stacks_tip_of_spear = stacks_tip_of_spear
    end,
})
