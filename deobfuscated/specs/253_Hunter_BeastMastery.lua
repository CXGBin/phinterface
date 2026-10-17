--[[
  Hunter_BeastMastery（野兽控制猎人）—— 专精配置：野兽控制猎人（specID 253）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：281448.lua（TOC 第 51 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local mark_257284 = false
local natures_ally = false
local naturesAllyExpiresAt = 0
local targetFrame = CreateFrame("Frame")
targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetFrame:SetScript("OnEvent", function()
    mark_257284 = false
end)
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
P8BA6426E.RegisterClass(253, {
    talentLoadouts = {
        {
            name = "ptr兽群领袖",
            importString = "C0PAAAAAAAAAAAAAAAAAAAAAAAMmxwGsAzwQDbAAYGzMzs8AzYmZmZMzgZGzMMzYmZGMzYGzgx0MAAAAAAAAYmZGAzsAYxsA2GAA",
        },
    },
    DEFAULT_MACROS = {
        spell_34026 = "/cast [nochanneling]杀戮命令\n/petattack",
        spell_217200 = "/cast [nochanneling]倒刺射击",
        spell_193455 = "/cast [nochanneling]眼镜蛇射击",
        spell_1264359 = "/cast [nochanneling]狂野鞭笞",
        spell_19574 = "/cast [nochanneling]狂野怒火",
        spell_257284 = "/cast [nochanneling]猎人印记",
        cd_109304 = "/cast [nochanneling]意气风发",
        cd_264735 = "/cast [nochanneling]优胜劣汰",
        cd_186265 = "/cast [nochanneling]灵龟守护",
        cd_147362 = "/cast [nochanneling]反制射击",
        spell_147362_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]反制射击",
        focus_interrupt = "/cast [nochanneling,@focus]反制射击",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        spell_883 = "/cast [@pet,dead] 复活宠物\n/castsequence [nopet] reset=3 召唤宠物 1, 复活宠物\n/cast 治疗宠物",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 34026, 217200, 193455, 1264359, 19574, 257284 },
    ACTION_LABELS = {
        spell_34026 = "杀戮命令",
        spell_217200 = "倒刺射击",
        spell_193455 = "眼镜蛇射击",
        spell_1264359 = "狂野鞭笞",
        spell_19574 = "狂野怒火",
        spell_257284 = "猎人印记",
        cd_109304 = "意气风发",
        cd_264735 = "优胜劣汰",
        cd_186265 = "灵龟守护",
        cd_147362 = "反制射击",
        spell_147362_mouseover = "反制射击指向",
        focus_interrupt = "反制射击焦点",
        spell_883 = "召唤宠物",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_34026 = "F6",
        spell_217200 = "F7",
        spell_193455 = "F8",
        spell_1264359 = "F9",
        spell_19574 = "F10",
        spell_257284 = "F11",
        cd_109304 = "F12",
        spell_883 = "=",
        cd_264735 = "8",
        cd_186265 = "9",
        cd_147362 = "0",
        spell_147362_mouseover = ".",
        focus_interrupt = "-",
        item_red_potion = ",",
        item_healing_stone = "'",
        item_burst_potion = "[",
        trinket1_cd = "]",
        trinket2_cd = ";",
    },
    macroOrder = {
        "spell_34026",
        "spell_217200",
        "spell_193455",
        "spell_1264359",
        "spell_19574",
        "spell_257284",
        "cd_109304",
        "cd_264735",
        "cd_186265",
        "cd_147362",
        "spell_147362_mouseover",
        "spell_883",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 883, 193455, 257284 },
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
        if spellID == 257284 then
            mark_257284 = true
        end
        if spellID == 193455 or spellID == 217200 then
            natures_ally = true
            naturesAllyExpiresAt = now + 8
        elseif spellID == 34026 then
            natures_ally = false
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        values.mark_257284 = mark_257284
        if natures_ally and now >= naturesAllyExpiresAt then
            natures_ally = false
        end
        values.natures_ally = natures_ally
        values.pet_exists = UnitExists("pet") == true and not UnitIsDeadOrGhost("pet")
    end,
})
