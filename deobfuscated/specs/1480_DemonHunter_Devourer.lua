--[[
  DemonHunter_Devourer（噬灭恶魔猎手）—— 专精配置：噬灭恶魔猎手（specID 1480）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：21e6a5.lua（TOC 第 49 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local collapsingStarForcedUntil = 0
local lastVoidMetamorphosisAt = 0
local yuanqi_count = 0
local lastYuanqiAt = 0
local YUANQI_RESET_SECONDS = 20
local function getSoulFragments()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(1225789)
    if aura then
        return aura.applications or 0
    end
    aura = C_UnitAuras.GetPlayerAuraBySpellID(1217607)
    if aura then
        return aura.applications or 0
    end
    return 0
end
local function getCollapsingStarStacks()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(1227702)
    if aura then
        return aura.applications or 0
    end
    return 0
end
local function isMetamorphosisActive()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(1217607)
    return aura ~= nil
end
local function _getCooldown(spellID)
    return P8BA6426E.GetSpellCooldownRemaining(spellID)
end
local function isSpell1239123Ready()
    local spellID = 1239123
    local known = false
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        local playerBank = Enum and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "player"
        known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, playerBank, true)
    elseif IsSpellKnown then
        known = IsSpellKnown(spellID)
    end
    if not known then
        return false
    end
    local usable = true
    if P8BA6426E.IsSpellUsable then
        usable = P8BA6426E.IsSpellUsable(spellID)
    end
    if not usable then
        return false
    end
    local remaining = P8BA6426E.GetSpellCooldownRemaining(spellID)
    if remaining and remaining > 0 then
        return false
    end
    return true
end
P8BA6426E.RegisterClass(1480, {
    talentLoadouts = {
        {
            name = "PTR歼灭者推荐",
            importString = "CgcBAAAAAAAAAAAAAAAAAAAAAAA2mxMzMzMzMGmBAAAAAAgxsNYGAAAAAAAAmxMMzMzMzMzMDzsYGjFZhZmZmt2mZmBwMGAAegxgxMA",
        },
        {
            name = "PTR虚空之痕备用",
            importString = "CgcBAAAAAAAAAAAAAAAAAAAAAAAWmZmZmZmZMGmBAAAAAAYxYMYGAAAAAAAAmxMMmZmZmZmZGzsNzMjNttAAADgxMzsNzMNbzsNzMMzA",
        },
    },
    DEFAULT_MACROS = {
        spell_1226019 = "/cast [nochanneling]收割",
        spell_473662 = "/cast [nochanneling]吞噬",
        cd_1241937 = "/cast [nochanneling]灵魂献祭",
        spell_1217605 = "/cast [nochanneling]虚空变形",
        spell_473728 = "/cast [nochanneling]虚空射线",
        spell_1221150 = "/cast [nochanneling]坍缩之星",
        spell_370965 = "/cast [nochanneling]恶魔追击",
        cd_198793 = "/cast [nochanneling]复仇回避",
        cd_1245412 = "/cast [nochanneling]虚空之刃",
        cd_198589 = "/cast [nochanneling]疾影",
        cd_196718 = "/cast 黑暗",
        cd_278326 = "/cast [@mouseover,harm,exists] 吞噬魔法; [@focus,harm,exists] 吞噬魔法; 吞噬魔法",
        cd_183752 = "/cast [nochanneling]瓦解",
        spell_183752_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]瓦解",
        focus_interrupt = "/cast [nochanneling,@focus]瓦解",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 1217605, 196718, 278326, 370965, 198793 },
    ACTION_LABELS = {
        spell_1226019 = "收割",
        spell_473662 = "吞噬",
        cd_1241937 = "灵魂献祭",
        spell_1217605 = "虚空变形",
        spell_473728 = "虚空射线",
        spell_1221150 = "坍缩之星",
        spell_370965 = "恶魔追击",
        cd_198793 = "复仇回避",
        cd_1245412 = "虚空之刃",
        cd_278326 = "吞噬魔法",
        cd_198589 = "疾影",
        cd_196718 = "黑暗",
        cd_183752 = "瓦解",
        spell_183752_mouseover = "瓦解指向",
        focus_interrupt = "瓦解焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_1226019 = "F6",
        spell_473662 = "F7",
        cd_1241937 = "F12",
        spell_1217605 = "F11",
        spell_473728 = "F8",
        spell_1221150 = "F9",
        cd_278326 = "8",
        spell_370965 = "F10",
        cd_198793 = "=",
        cd_1245412 = "UP",
        cd_196718 = "9",
        cd_198589 = "0",
        cd_183752 = "-",
        spell_183752_mouseover = "\\",
        item_red_potion = "'",
        item_healing_stone = ",",
        item_burst_potion = "[",
        focus_interrupt = ".",
        trinket1_cd = "]",
        trinket2_cd = ";",
    },
    macroOrder = {
        "spell_1226019",
        "spell_473662",
        "cd_1241937",
        "spell_1217605",
        "spell_473728",
        "spell_1221150",
        "spell_370965",
        "cd_198589",
        "cd_198793",
        "cd_196718",
        "cd_278326",
        "cd_183752",
        "cd_1245412",
        "spell_183752_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 473662 },
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
        if spellID == 473728 then
            lastVoidMetamorphosisAt = now
        elseif spellID == 1217605 then
            collapsingStarForcedUntil = now + 1
        elseif spellID == 1221150 then
            yuanqi_count = yuanqi_count + 1
            lastYuanqiAt = now
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local ok, result = pcall(getSoulFragments)
        values.soul_fragments = ok and result or 0
        local ok, result = pcall(isMetamorphosisActive)
        values.metamorphosis_active = ok and result or false
        if now - lastYuanqiAt > YUANQI_RESET_SECONDS then
            yuanqi_count = 0
        end
        values.yuanqi_count = yuanqi_count
        local ok, result = pcall(P8BA6426E.IsSpellReady, 1221150)
        local collapsing_star_ready = ok and result or false
        if GetTime() < collapsingStarForcedUntil then
            collapsing_star_ready = true
        end
        values.collapsing_star_ready = collapsing_star_ready
        local spell_1239123_ready = false
        pcall(function()
            spell_1239123_ready = P8BA6426E.IsSpellReady(1239123)
        end)
        values.spell_1239123_ready = spell_1239123_ready
        local ok, result = pcall(getCollapsingStarStacks)
        values.stacks_collapsing_star = ok and result or 0
    end,
    OverrideIsSpellReady = function(spellID)
        if spellID == 1239123 then
            return isSpell1239123Ready()
        end
        if spellID == 473728 then
            local ok, result = pcall(P8BA6426E.GetSpellCooldownRemaining, spellID)
            if ok and (result and result > 0) then
                return false
            end
            if GetTime() - lastVoidMetamorphosisAt < 1.5 then
                return false
            end
        end
        return nil
    end,
})
