--[[
  DemonHunter_Vengeance（复仇恶魔猎手）—— 专精配置：复仇恶魔猎手（specID 581）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：1c2300.lua（TOC 第 47 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local demonSpikesExpiresAt = 0
local fieryBrandExpiresAt = 0
P8BA6426E.RegisterClass(581, {
    talentLoadouts = {
        {
            name = "茨木歼灭者",
            importString = "CUkAAAAAAAAAAAAAAAAAAAAAAAAMjZmZmhZkZmxwyMzMDMjZGzYmZGDmZmx2MzsNGzAAAAAAAAwMYDAAAADMzMzMbtNzMDAAAAAwA",
        },
    },
    DEFAULT_MACROS = {
        spell_204021 = "/cast [nochanneling]烈火烙印",
        spell_212084 = "/cast [nochanneling]邪能毁灭",
        spell_204596 = "/cast [target=cursor] 烈焰咒符",
        spell_263642 = "/cast [nochanneling]破裂",
        spell_263642_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]破裂\n/targetlasttarget",
        spell_232893 = "/cast [nochanneling]邪能之刃",
        spell_228477 = "/cast [nochanneling]灵魂裂劈",
        spell_228477_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]灵魂裂劈\n/targetlasttarget",
        spell_247454 = "/cast [nochanneling]幽魂炸弹",
        spell_258920 = "/cast [nochanneling]献祭光环",
        spell_204157 = "/cast [nochanneling]投掷利刃",
        spell_187827 = "/cast [nochanneling]恶魔变形",
        cd_196718 = "/cast 黑暗",
        cd_202138 = "/cast [target=cursor] 锁链咒符",
        cd_202137 = "/cast [target=cursor] 沉默咒符",
        cd_390163 = "/cast [target=cursor] 怨念咒符",
        cd_278326 = "/cast [@mouseover,harm,exists] 吞噬魔法; [@focus,harm,exists] 吞噬魔法; 吞噬魔法",
        cd_179057 = "/cast [nochanneling]混乱新星",
        cd_203720 = "/cast [nochanneling]恶魔尖刺",
        cd_183752 = "/cast [nochanneling]瓦解",
        spell_183752_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]瓦解",
        focus_interrupt = "/cast [nochanneling,@focus]瓦解",
        cd_198793 = "/cast [nochanneling]复仇回避",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        204021,
        212084,
        204596,
        263642,
        232893,
        228477,
        247454,
        258920,
        204157,
        187827,
        202138,
        202137,
        390163,
        278326,
        196718,
        179057,
    },
    ACTION_LABELS = {
        spell_204021 = "烈火烙印",
        spell_212084 = "邪能毁灭",
        spell_204596 = "烈焰咒符",
        spell_263642 = "破裂",
        spell_263642_nearest = "就近破裂",
        spell_232893 = "邪能之刃",
        spell_228477 = "灵魂裂劈",
        spell_228477_nearest = "就近灵魂裂劈",
        spell_247454 = "幽魂炸弹",
        spell_258920 = "献祭光环",
        spell_204157 = "投掷利刃",
        spell_187827 = "恶魔变形",
        cd_202138 = "锁链咒符",
        cd_202137 = "沉默咒符",
        cd_390163 = "怨念咒符",
        cd_278326 = "吞噬魔法",
        cd_179057 = "混乱新星",
        cd_196718 = "黑暗",
        cd_203720 = "恶魔尖刺",
        cd_183752 = "瓦解",
        spell_183752_mouseover = "瓦解指向",
        focus_interrupt = "瓦解焦点",
        cd_198793 = "复仇回避",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_204021 = "-",
        spell_212084 = "0",
        spell_204596 = "F10",
        spell_263642 = "F6",
        spell_263642_nearest = "8",
        spell_232893 = "F11",
        spell_228477 = "F7",
        spell_228477_nearest = "9",
        spell_247454 = "F8",
        spell_258920 = "F9",
        spell_204157 = "F12",
        spell_187827 = "=",
        cd_202138 = "]",
        cd_202137 = ";",
        cd_390163 = "'",
        cd_278326 = ",",
        cd_179057 = ".",
        cd_196718 = "\\",
        cd_203720 = "[",
        cd_183752 = "UP",
        spell_183752_mouseover = "CTRL-F6",
        focus_interrupt = "INSERT",
        cd_198793 = "DOWN",
        item_red_potion = "HOME",
        item_healing_stone = "END",
        item_burst_potion = "LEFT",
        trinket1_cd = "RIGHT",
        trinket2_cd = "DELETE",
    },
    macroOrder = {
        "spell_204021",
        "spell_212084",
        "spell_204596",
        "spell_263642",
        "spell_263642_nearest",
        "spell_232893",
        "spell_228477",
        "spell_228477_nearest",
        "spell_247454",
        "spell_258920",
        "spell_204157",
        "spell_187827",
        "cd_196718",
        "cd_202138",
        "cd_202137",
        "cd_390163",
        "cd_278326",
        "cd_179057",
        "cd_203720",
        "cd_183752",
        "cd_198793",
        "spell_183752_mouseover",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 228477 },
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
        if spellID == 203720 then
            demonSpikesExpiresAt = now + 12
        end
        if spellID == 204021 then
            fieryBrandExpiresAt = now + 16
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local buff_203720 = 0
        if demonSpikesExpiresAt > now then
            buff_203720 = demonSpikesExpiresAt - now
        end
        values.buff_203720 = buff_203720
        local buff_204021_dot = 0
        if fieryBrandExpiresAt > now then
            buff_204021_dot = fieryBrandExpiresAt - now
        end
        values.buff_204021_dot = buff_204021_dot
    end,
})
