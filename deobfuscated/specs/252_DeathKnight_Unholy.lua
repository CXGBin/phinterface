--[[
  DeathKnight_Unholy（邪恶死亡骑士）—— 专精配置：邪恶死亡骑士（specID 252）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：c45c53.lua（TOC 第 77 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local spell458128CastAt = 0
local SPELL_458128_COOLDOWN = 25
local spell_1271967_ready = false
local specFrame = CreateFrame("Frame")
specFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
specFrame:SetScript("OnEvent", function()
    spell_1271967_ready = false
end)
local spell343294Until = 0
local window1233448Until = 0
local SPELL_343294_DURATION = 15
local WINDOW_1233448_DURATION = 20
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
local function isSpell433895Ready()
    local spellID = 433895
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
P8BA6426E.RegisterClass(252, {
    talentLoadouts = {},
    cdmLoadouts = {
        {
            name = "测试配置（用户字符串）",
            importString = "1|NZG9S4JRFMbVxAIzI8p8hMjGhpb+gbaohoYgrJDCSSyPDkJNQdnH4JKfEVTEW5vRFg7qEi3+DQ1N+YIVRDRFUZ3nNZcfz7n33HvOc86+c8fwTxmu9Ml8wObY2w7Y7INRIob4D8SG+DfEDxlGow5xQxyQkN5HfZB+iBfJJJK3erD+DHFCepF4hXRB+iA9EA+kG+JCM8uUN8VRk+qdJTYgA1o0MqNBoapqLayqyDBvKhZaitFpiI9BhXclZjHMPvJRit8keGGnivPrL0VuhKEQBUWsRlUkSsSxIvLJPC3oGN+kOiUeWBrEEnGhOLtXnP9q3uyWYtlJzClW+DY8qVj1Kg4+FIcZTfbcQYY0eElcjmU7nefNtg2rUbZn2bC8t21zAJY/ddzxZ42ikLLGpNMIZrgHbiOky/lfgs1aiZt7atQN16J5U3uqGq1yrnl1HZwIttJlc7fyBw==",
        },
        {
            name = "测试配置（Rurutia格式）",
            importString = "1|NZE9S0JxFMa9VzGhzAgrjxDZ2NoXaAsLamjpBUmcxPLoENQUpLcagshSI6iIBpfGCIdqkZY+Q0ObghVEBEIU1fP8Lbj8zgvnnpfnv+nZOA+N5VvO0bRoSHRAtDPsspL9orborKS/RV1IBJOiPlGPaJdkXkS7Rd2Szkr2StQv2oGSpSfRHtGAqJc/pID9GFB4BPbqwMmdaK9of9hlT6yJ9sGOrLJsEF4iCm+myUavQKnMsMrwDSiuMMeS4jW7LwND4/QyRJp1n/SUKAIHDSB1w7BEHAKJD047Jh5YIsQccYYNnHVJf8n9Ldx5DzEJLOAEOzYKLAaAOJeP86wgFzz94VoWclvvwPaO1Auwz1zKX6tYOaOE7Zjj/+v9NbfJlyMOpnGm+oZ3jR7Y2uhjJGmrYe41p/5pAA2NcO1RiWgFj5RzbMuLZm2rLmPNO9Kz8JImk29NNU8u8UWa+YtGrvoL",
        },
    },
    acdmLoadouts = { { name = "邪 DK 标准大米（占位）", importString = "!ACDM:PLACEHOLDER" } },
    cmcLoadouts = {},
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_47541 = "/cast 凋零缠绕",
        spell_207317 = "/cast 扩散",
        spell_48743 = "/cast 天灾契约",
        spell_343294 = "/cast 灵魂收割",
        spell_343294_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 灵魂收割\n/targetlasttarget",
        spell_42650 = "/cast 亡者大军",
        spell_1233448 = "/cast 黑暗突变\n/use 乌拉特克贪婪之心",
        spell_1271967 = "/cast 瘟疫降临",
        spell_46584 = "/cast 亡者复生",
        spell_85948 = "/cast 脓疮打击",
        spell_85948_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 脓疮打击\n/targetlasttarget",
        spell_55090 = "/cast 天灾打击\n/cast 爪击",
        spell_77575 = "/cast 爆发",
        spell_1247378 = "/cast 腐化",
        spell_43265 = "/cast [@player]枯萎凋零",
        spell_49998 = "/cast 灵界打击",
        spell_49998_nearest = "/cleartarget\n/targetenemy\n/startattack\n/cast [harm] 灵界打击\n/targetlasttarget",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        cd_48792 = "/cast 冰封之韧",
        cd_49039 = "/cast 巫妖之躯",
        cd_47528 = "/cast 心灵冰冻",
        spell_47528_mouseover = "/cast [@mouseover,harm,nodead,exists] 心灵冰冻",
        focus_interrupt = "/cast [@focus]心灵冰冻",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_healing_stone = "/use item:5512",
        spell_61999 = "/cast [@mouseover,help,dead] [help,dead] [@party1,dead] [@party2,dead] [@party3,dead] [@party4,dead] [@party5,dead] 复活盟友",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = { 47541, 207317, 48743, 343294, 42650, 1233448 },
    ACTION_LABELS = {
        spell_47541 = "凋零缠绕",
        spell_207317 = "扩散",
        spell_48743 = "天灾契约",
        spell_343294 = "灵魂收割",
        spell_343294_nearest = "就近灵魂收割",
        spell_42650 = "亡者大军",
        spell_1233448 = "黑暗突变",
        spell_1271967 = "瘟疫降临",
        spell_46584 = "亡者复生",
        spell_85948 = "脓疮打击",
        spell_85948_nearest = "就近脓疮打击",
        spell_55090 = "天灾打击",
        spell_77575 = "爆发",
        spell_1247378 = "腐化",
        spell_43265 = "枯萎凋零",
        spell_49998 = "灵界打击",
        spell_49998_nearest = "就近灵界打击",
        item_burst_potion = "爆发药水",
        cd_48792 = "冰封之韧",
        cd_49039 = "巫妖之躯",
        cd_47528 = "心灵冰冻",
        spell_47528_mouseover = "心灵冰冻指向",
        focus_interrupt = "心灵冰冻焦点",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        spell_61999 = "复活盟友",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_47541 = "F9",
        spell_207317 = "8",
        spell_48743 = "-",
        spell_343294 = "9",
        spell_343294_nearest = "0",
        spell_42650 = ";",
        spell_1233448 = "]",
        spell_1271967 = "END",
        spell_46584 = "\\",
        spell_85948 = "F6",
        spell_85948_nearest = "F7",
        spell_55090 = "F8",
        spell_77575 = "F10",
        spell_1247378 = "F11",
        spell_43265 = "F12",
        spell_49998 = "=",
        spell_49998_nearest = "[",
        item_burst_potion = "'",
        cd_48792 = "DOWN",
        cd_49039 = "LEFT",
        cd_47528 = "RIGHT",
        spell_47528_mouseover = "CTRL-F6",
        focus_interrupt = "INSERT",
        item_red_potion = "HOME",
        item_healing_stone = "DELETE",
        spell_61999 = "UP",
        trinket1_cd = ",",
        trinket2_cd = ".",
    },
    macroOrder = {
        "spell_47541",
        "spell_207317",
        "spell_48743",
        "spell_343294",
        "spell_343294_nearest",
        "spell_42650",
        "spell_1233448",
        "spell_1271967",
        "spell_46584",
        "spell_85948",
        "spell_85948_nearest",
        "spell_55090",
        "spell_77575",
        "spell_1247378",
        "spell_43265",
        "spell_49998",
        "spell_49998_nearest",
        "item_burst_potion",
        "cd_48792",
        "cd_49039",
        "cd_47528",
        "spell_47528_mouseover",
        "focus_interrupt",
        "item_red_potion",
        "item_healing_stone",
        "spell_61999",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 49998, 55090, 61999, 77575, 85948, 207317, 1271967 },
    spellReadyAliases = { [85948] = { 1240994 }, [207317] = { 1237172 } },
    OverrideIsSpellReady = function(spellID)
        if spellID == 433895 then
            return isSpell433895Ready()
        end
        if spellID == 1271967 then
            return spell_1271967_ready and P8BA6426E.IsSpellKnown(1271974)
        end
        return nil
    end,
    OnSpellCast = function(spellID)
        local now = GetTime()
        if spellID == lastCastSpellID and now - lastCastAt < 0.5 then
            return
        end
        lastCastSpellID = spellID
        lastCastAt = now
        if spellID == 458128 then
            spell458128CastAt = GetTime()
        end
        if spellID == 1233448 then
            if P8BA6426E.IsSpellKnown(1271974) then
                spell_1271967_ready = true
            end
            window1233448Until = GetTime() + WINDOW_1233448_DURATION
            spell343294Until = 0
        elseif spellID == 1271967 then
            spell_1271967_ready = false
        else
            if spellID == 343294 then
                spell343294Until = GetTime() + SPELL_343294_DURATION
                window1233448Until = 0
            end
        end
    end,
    GetExtraValues = function(values)
        if P8BA6426E.IsSpellReady(207317) then
            values.spell_47541 = true
        end
        local cd458128Remains = 0
        if spell458128CastAt > 0 then
            local elapsed = GetTime() - spell458128CastAt
            if elapsed < SPELL_458128_COOLDOWN then
                cd458128Remains = SPELL_458128_COOLDOWN - elapsed
            else
                spell458128CastAt = 0
            end
        end
        values.cd_458128 = math.floor(cd458128Remains + 0.5)
        local spell_433895_ready = false
        pcall(function()
            spell_433895_ready = P8BA6426E.IsSpellReady(433895)
        end)
        values.spell_433895_ready = spell_433895_ready
        if not P8BA6426E.IsSpellKnown(1271974) then
            spell_1271967_ready = false
        end
        values.spell_1271967_ready = spell_1271967_ready
        values.talent_1290864 = P8BA6426E.IsSpellKnown(1290864) == true
        local trinket1_cd = 601
        if GetInventoryItemID("player", 13) == 270175 then
            trinket1_cd = values.trinket1_cd
        elseif GetInventoryItemID("player", 14) == 270175 then
            trinket1_cd = values.trinket2_cd
        end
        values.cd_270175 = trinket1_cd or 601
        local spell_343294
        if not P8BA6426E.IsSpellKnown(343294) then
            spell_343294 = 601
        else
            local now = GetTime()
            if now < window1233448Until then
                if now < spell343294Until then
                    spell_343294 = math.ceil(spell343294Until - now)
                else
                    spell_343294 = 0
                end
            else
                if not P8BA6426E.IsSpellReady(343294) then
                    spell_343294 = 15
                else
                    if now < spell343294Until then
                        spell_343294 = math.ceil(spell343294Until - now)
                    else
                        spell_343294 = 0
                    end
                end
            end
        end
        values.spell_343294 = spell_343294
        values.pet_exists = UnitExists("pet") == true
    end,
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
})
