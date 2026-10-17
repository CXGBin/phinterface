--[[
  DemonHunter_Havoc（浩劫恶魔猎手）—— 专精配置：浩劫恶魔猎手（specID 577）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：c49d59.lua（TOC 第 78 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local buff258920Until = 0
local felSurgeStartedAt = 0
local sawSpell210152 = false
local sawSpell201427 = false
P8BA6426E.RegisterClass(577, {
    talentLoadouts = {
        {
            name = "团本单体",
            importString = "CEkAp/epaxe7D0A403L+Tvk0iamZGzMzmxMzMmZmMmZAAAAAAAzyDMmtZYmBzMWmZMDzMGzyALzmZMMbaaMzMG2AAAAAAQAwMDGACAAM",
        },
        {
            name = "大米天赋",
            importString = "CEkAp/epaxe7D0A403L+Tvk0iamZGzMz2MmZmxwkxMDAAAAAAY2MmtZGzMwMWmZmZYmBzyALzmZMMbaaMzMG2AAAAGAACAmZwAQAAgB",
        },
    },
    DEFAULT_MACROS = {
        spell_188499 = "/cast [nochanneling]刃舞",
        spell_198013 = "/cast [nochanneling]眼棱",
        spell_162794 = "/cast [nochanneling]混乱打击",
        spell_162794_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]混乱打击\n/targetlasttarget",
        spell_232893 = "/cast [nochanneling]邪能之刃",
        spell_258920 = "/cast [nochanneling]献祭光环",
        spell_185123 = "/cast [nochanneling]投掷利刃",
        spell_370965 = "/cast [nochanneling]恶魔追击",
        spell_191427 = "/cast [@player,nochanneling]恶魔变形",
        cd_196718 = "/cast 黑暗",
        cd_278326 = "/cast [@mouseover,harm,exists] 吞噬魔法; [@focus,harm,exists] 吞噬魔法; 吞噬魔法",
        spell_258860 = "/cast [nochanneling]精华破碎",
        spell_258860_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [nochanneling,harm]精华破碎\n/targetlasttarget",
        cd_198589 = "/cast [nochanneling]疾影",
        cd_183752 = "/cast [nochanneling]瓦解",
        spell_183752_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists]瓦解",
        focus_interrupt = "/cast [nochanneling,@focus]瓦解",
        cd_198793 = "/cast [nochanneling]复仇回避",
        cd_195072 = "/cast [nochanneling]邪能冲撞",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 188499, 198013, 162794, 232893, 258920, 185123, 370965, 191427, 258860, 196718, 278326 },
    ACTION_LABELS = {
        spell_188499 = "刃舞",
        spell_198013 = "眼棱",
        spell_162794 = "混乱打击",
        spell_162794_nearest = "就近混乱打击",
        spell_232893 = "邪能之刃",
        spell_258920 = "献祭光环",
        spell_185123 = "投掷利刃",
        spell_370965 = "恶魔追击",
        spell_191427 = "恶魔变形",
        spell_258860 = "精华破碎",
        spell_258860_nearest = "就近精华破碎",
        cd_278326 = "吞噬魔法",
        cd_196718 = "黑暗",
        cd_198589 = "疾影",
        cd_183752 = "瓦解",
        spell_183752_mouseover = "瓦解指向",
        focus_interrupt = "瓦解焦点",
        cd_198793 = "复仇回避",
        cd_195072 = "邪能冲撞",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        item_burst_potion = "爆发药水",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_188499 = "F6",
        spell_198013 = "F7",
        spell_162794 = "F8",
        spell_162794_nearest = "9",
        spell_232893 = "F11",
        spell_258920 = "F10",
        spell_185123 = "F12",
        spell_370965 = "8",
        spell_191427 = "-",
        spell_258860 = "F9",
        spell_258860_nearest = "0",
        cd_278326 = "=",
        cd_196718 = "[",
        cd_198589 = "]",
        cd_183752 = ";",
        spell_183752_mouseover = "INSERT",
        focus_interrupt = "RIGHT",
        cd_198793 = "'",
        cd_195072 = ",",
        item_red_potion = "DOWN",
        item_healing_stone = "LEFT",
        item_burst_potion = ".",
        trinket1_cd = "\\",
        trinket2_cd = "UP",
    },
    macroOrder = {
        "spell_188499",
        "spell_198013",
        "spell_162794",
        "spell_162794_nearest",
        "spell_232893",
        "spell_258920",
        "spell_185123",
        "spell_370965",
        "spell_191427",
        "cd_196718",
        "cd_278326",
        "spell_258860",
        "spell_258860_nearest",
        "cd_198589",
        "cd_183752",
        "cd_198793",
        "cd_195072",
        "spell_183752_mouseover",
        "item_red_potion",
        "item_healing_stone",
        "item_burst_potion",
        "focus_interrupt",
        "trinket1_cd",
        "trinket2_cd",
    },
    actionAvailSpellIDs = { 162794 },
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
        if spellID == 258920 then
            buff258920Until = now + 10
        end
        if spellID == 191427 then
            felSurgeStartedAt = now
            sawSpell210152 = false
            sawSpell201427 = false
        end
        if (now - felSurgeStartedAt) < 20 then
            if spellID == 210152 then
                sawSpell210152 = true
            end
            if spellID == 201427 then
                sawSpell201427 = true
            end
        end
    end,
    GetExtraValues = function(values)
        local now = GetTime()
        local buff_258920 = 0
        if buff258920Until > now then
            buff_258920 = buff258920Until - now
        end
        values.buff_258920 = buff_258920
        values.fel_surge_active = (
            felSurgeStartedAt > 0 and ((now - felSurgeStartedAt) < 20 and (sawSpell210152 and sawSpell201427))
        )
    end,
})
