--[[
  Druid_Balance（平衡德鲁伊）—— 专精配置：平衡德鲁伊（specID 102）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：21c39c.lua（TOC 第 48 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local eclipseKind = "none"
local eclipseExpiresAt = 0
local lastCastSpellID = nil
local lastCastAt = 0
local _UNUSED_100 = 100
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(102, {
    talentLoadouts = {
        {
            name = "夏天",
            importString = "CYGADBD3hSPCL9Y9gz68WcKvMAAAAAAAAAAAAAAAAAWoMbNjxMD8AmFmZmZhhZMLzsMzCzM2YZmlxMjxGGGgx22Mz22MLz2MNzsMTAAAAWMz8AzMYzwYMAAMzglBA",
        },
    },
    DEFAULT_MACROS = {
        spell_190984 = "/cast [nochanneling,nostance:1]愤怒",
        spell_194153 = "/cast [nochanneling,nostance:1]星火术",
        spell_8921 = "/cast [nochanneling,nostance:1]月火术",
        spell_78674 = "/cast [nochanneling,nostance:1]星涌术",
        spell_191034 = "/cast [nochanneling,nostance:1]星辰坠落",
        spell_202770 = "/cast [nochanneling,nostance:1]艾露恩之怒",
        spell_1233346 = "/cast [nochanneling,nostance:1]日蚀",
        spell_102560 = "/cast [nochanneling,nostance:1]化身：艾露恩之眷",
        spell_205636 = "/cast [nochanneling,nostance:1,@cursor]自然之力",
        spell_24858 = "/cast [noform:4]枭兽形态",
        spell_93402 = "/cast [nochanneling,nostance:1]阳炎术",
        mouseover_moonfire = "/cast [nochanneling,@mouseover,harm,nodead]月火术",
        mouseover_sunfire = "/cast [nochanneling,@mouseover,harm,nodead]阳炎术",
        spell_2782 = "/cast [nochanneling,@mouseover,help,nodead][nochanneling,@player]清除腐蚀",
        cd_22812 = "/cast [nochanneling]树皮术",
        cd_78675 = "/cast [nochanneling]日光术",
        spell_78675_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]日光术",
        focus_interrupt = "/cast [nochanneling,@focus]日光术",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        spell_1126 = "/cast 野性印记",
        spell_20484 = "/cast [@mouseover,help,dead] [help,dead] [@party1,dead] [@party2,dead] [@party3,dead] [@party4,dead] 复生",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 190984, 194153, 8921, 78674, 191034, 202770, 1233346, 102560, 205636, 24858, 93402, 2782, 20484 },
    ACTION_LABELS = {
        spell_190984 = "愤怒",
        spell_194153 = "星火术",
        spell_8921 = "月火术",
        spell_78674 = "星涌术",
        spell_191034 = "星辰坠落",
        spell_202770 = "艾露恩之怒",
        spell_1233346 = "日蚀",
        spell_102560 = "化身：艾露恩之眷",
        spell_205636 = "自然之力",
        spell_24858 = "枭兽形态",
        spell_93402 = "阳炎术",
        mouseover_moonfire = "指向月火",
        mouseover_sunfire = "指向阳炎",
        spell_2782 = "清除腐蚀",
        cd_22812 = "树皮术",
        cd_78675 = "日光术",
        spell_78675_mouseover = "日光术指向",
        focus_interrupt = "日光术焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        spell_1126 = "野性印记",
        spell_20484 = "复生",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_190984 = "F6",
        spell_194153 = "F7",
        spell_8921 = "F8",
        spell_78674 = "F10",
        spell_191034 = "F11",
        spell_202770 = "F12",
        spell_1233346 = "8",
        spell_102560 = "-",
        spell_205636 = "=",
        spell_24858 = "[",
        spell_93402 = "F9",
        mouseover_moonfire = "9",
        mouseover_sunfire = "0",
        spell_2782 = "]",
        cd_22812 = ",",
        cd_78675 = ".",
        spell_78675_mouseover = "DELETE",
        focus_interrupt = "INSERT",
        item_red_potion = "LEFT",
        item_healing_stone = "RIGHT",
        item_burst_potion = "\\",
        spell_1126 = ";",
        spell_20484 = "'",
        trinket1_cd = "UP",
        trinket2_cd = "DOWN",
    },
    macroOrder = {
        "spell_190984",
        "spell_194153",
        "spell_8921",
        "spell_78674",
        "spell_191034",
        "spell_202770",
        "spell_1233346",
        "spell_102560",
        "spell_205636",
        "spell_24858",
        "spell_93402",
        "mouseover_moonfire",
        "mouseover_sunfire",
        "spell_2782",
        "cd_22812",
        "cd_78675",
        "spell_78675_mouseover",
        "spell_1126",
        "spell_20484",
        "focus_interrupt",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 1126, 8921, 20484, 24858, 78674, 93402, 190984, 191034, 194153 },
    spellReadyAliases = {
        [78674] = { 1236640, 1236917, 1264677, 1271222 },
        [191034] = { 1236607, 1236613, 1264671, 1264676, 1286243, 1301742 },
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
        if spellID == 102560 then
            eclipseKind = "both"
            eclipseExpiresAt = now + 20
        elseif spellID == 1233346 then
            eclipseKind = "solar"
            eclipseExpiresAt = now + 15
        elseif spellID == 1233272 then
            eclipseKind = "lunar"
            eclipseExpiresAt = now + 15
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        if now >= eclipseExpiresAt then
            eclipseKind = "none"
        end
        local eclipse_state = 0
        if eclipseKind == "solar" then
            eclipse_state = 1
        elseif eclipseKind == "lunar" then
            eclipse_state = 2
        elseif eclipseKind == "both" then
            eclipse_state = 3
        end
        values.eclipse_state = eclipse_state
        local eclipse_duration = 0
        if eclipseKind ~= "none" then
            eclipse_duration = math.max(0, eclipseExpiresAt - now)
        end
        values.eclipse_duration = eclipse_duration
        local buff_overflowing_power = false
        pcall(function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(405189)
            if aura then
                buff_overflowing_power = true
            end
        end)
        values.buff_overflowing_power = buff_overflowing_power
        local moonkin_form = 0
        pcall(function()
            moonkin_form = GetShapeshiftForm()
        end)
        values.moonkin_form = moonkin_form
    end,
})
