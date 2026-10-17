--[[
  Warlock_Affliction（痛苦术士）—— 专精配置：痛苦术士（specID 265）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：ec2661.lua（TOC 第 82 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local darkglareUntil = 0
local lastDarkglareCastAt = -1
P8BA6426E.RegisterClass(265, {
    talentLoadouts = {
        {
            name = "天宇灵魂收割者",
            importString = "CkQAMrNP5kak+EBqLfUa3dMm+yMmZGNbM2mZGzyAAAmZmlZxMz2YAgx2yADYCmhtADbDAAAzAAAYmZMjZmtxYGjZmZYYmZGAgZgB",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_980 = "/cast [nochanneling]痛楚",
        spell_172 = "/cast [nochanneling]腐蚀术",
        spell_1259790 = "/cast [nochanneling]痛苦无常",
        spell_27243 = "/cast [nochanneling]腐蚀之种",
        spell_48181 = "/cast [nochanneling]鬼影缠身",
        spell_1257052 = "/cast [nochanneling]幽冥收割",
        spell_205180 = "/cast [nochanneling]召唤黑眼",
        spell_686 = "/cast [nochanneling]暗影箭",
        spell_198590 = "/cast [nochanneling]吸取灵魂",
        spell_1261153 = "/cast [nochanneling]灾难之握",
        spell_445468 = "/cast [nochanneling]枯萎",
        spell_442726 = "/cast [nochanneling]怨毒",
        mouseover_corruption = "/cast [nochanneling,@mouseover,harm,nodead] 腐蚀术",
        mouseover_agony = "/cast [nochanneling,@mouseover,harm,nodead] 痛楚",
        spell_691 = "/cast [nochanneling]召唤地狱猎犬",
        spell_333889 = "/cast [nochanneling]邪能统御\n/cast [nochanneling]召唤地狱猎犬",
        cd_19647 = "/cast [nochanneling]法术封锁",
        spell_19647_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]法术封锁",
        focus_interrupt = "/cast [nochanneling,@focus]法术封锁",
        cd_108416 = "/cast [nochanneling]黑暗契约",
        cd_104773 = "/cast [nochanneling]不灭决心",
        item_healing_stone = "/use [nochanneling] item:5512",
        item_224464 = "/use [nochanneling] item:224464",
        item_red_potion = "/use [nochanneling] item:271883\n/use [nochanneling] item:271884",
        item_burst_potion = "/use [nochanneling] item:241308\n/use [nochanneling] item:241309\n/use [nochanneling] item:241288\n/use [nochanneling] item:241289",
        trinket1_cd = "/use [nochanneling] 13",
        trinket2_cd = "/use [nochanneling] 14",
    },
    testSpells = { 980, 172, 1259790, 27243, 48181, 1257052, 205180, 686, 198590, 1261153, 445468, 442726, 691, 333889 },
    petSpells = { [19647] = true },
    petSpellPlayerWrappers = { [19647] = { 119910, 132409 } },
    cooldownEventAliases = { [119910] = 19647, [132409] = 19647 },
    consumableItems = {
        { id = "item_red_potion", label = "红药水", cooldown = 300, itemIDs = { 271883, 271884 } },
        { id = "item_healing_stone", label = "治疗石", cooldown = 60, itemIDs = { 5512 } },
        {
            id = "item_burst_potion",
            label = "爆发药水",
            cooldown = 300,
            itemIDs = { 241308, 241309, 241288, 241289 },
        },
        { id = "item_224464", label = "恶魔治疗石", cooldown = 60, itemIDs = { 224464 }, spellIDs = { 452930 } },
    },
    ACTION_LABELS = {
        spell_980 = "痛楚",
        spell_172 = "腐蚀术",
        spell_1259790 = "痛苦无常",
        spell_27243 = "腐蚀之种",
        spell_48181 = "鬼影缠身",
        spell_1257052 = "幽冥收割",
        spell_205180 = "召唤黑眼",
        spell_686 = "暗影箭",
        spell_198590 = "吸取灵魂",
        spell_1261153 = "灾难之握",
        spell_445468 = "枯萎",
        spell_442726 = "怨毒",
        mouseover_corruption = "指向腐蚀",
        mouseover_agony = "指向痛楚",
        spell_691 = "召唤地狱猎犬",
        spell_333889 = "邪能统御",
        cd_19647 = "法术封锁",
        spell_19647_mouseover = "法术封锁指向",
        focus_interrupt = "法术封锁焦点",
        cd_108416 = "黑暗契约",
        cd_104773 = "不灭决心",
        item_healing_stone = "治疗石",
        item_224464 = "恶魔治疗石",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_980 = "F6",
        spell_172 = "F8",
        spell_1259790 = "F10",
        spell_27243 = "F11",
        spell_48181 = "F12",
        spell_1257052 = "8",
        spell_205180 = "]",
        spell_686 = "9",
        spell_198590 = "0",
        spell_1261153 = "-",
        spell_445468 = "=",
        spell_442726 = "[",
        mouseover_corruption = "F9",
        mouseover_agony = "F7",
        spell_691 = ";",
        spell_333889 = "'",
        cd_19647 = "DOWN",
        spell_19647_mouseover = "END",
        focus_interrupt = "LEFT",
        cd_108416 = "RIGHT",
        cd_104773 = "INSERT",
        item_healing_stone = "DELETE",
        item_224464 = "UP",
        item_red_potion = "HOME",
        item_burst_potion = ",",
        trinket1_cd = ".",
        trinket2_cd = "\\",
    },
    macroOrder = {
        "spell_980",
        "spell_172",
        "spell_1259790",
        "spell_27243",
        "spell_48181",
        "spell_1257052",
        "spell_205180",
        "spell_686",
        "spell_198590",
        "spell_1261153",
        "spell_445468",
        "spell_442726",
        "mouseover_corruption",
        "mouseover_agony",
        "spell_691",
        "spell_333889",
        "cd_19647",
        "focus_interrupt",
        "cd_108416",
        "cd_104773",
        "spell_19647_mouseover",
        "item_healing_stone",
        "item_224464",
        "item_red_potion",
        "item_burst_potion",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 686, 980, 172, 1259790, 27243, 198590, 1261153, 445468, 691 },
    spellReadyAliases = {
        [980] = { 1261166 },
        [172] = { 1261158 },
        [1259790] = { 1219045, 1261176 },
        [1261153] = { 1261149, 1279659 },
        [445468] = { 1279686 },
    },
    OnSpellCast = function(spellID)
        if spellID ~= 205180 then
            return
        end
        local now = GetTime()
        if (now - lastDarkglareCastAt) < 0.5 then
            return
        end
        lastDarkglareCastAt = now
        darkglareUntil = now + 25
    end,
    GetExtraValues = function(values)
        values.pet_exists = UnitExists("pet") == true
        values.darkglare_remains = math.max(0, darkglareUntil - GetTime())
    end,
})
