--[[
  Shaman_Restoration（恢复萨满）—— 专精配置：恢复萨满（specID 264）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：0c0750.lua（TOC 第 44 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local party_tank_index = 0
local TRACKED_CHARGES = { [51505] = { max = 2, duration = 8 } }
local chargeRechargeTimes = {}
for key in pairs(TRACKED_CHARGES) do
    chargeRechargeTimes[key] = {}
end
local getSpellCharges = C_Spell and C_Spell.GetSpellCharges or _G.GetSpellCharges
local function syncChargesFromAPI()
    for spellID, config in pairs(TRACKED_CHARGES) do
        local chargeInfo = getSpellCharges(spellID)
        local current, maximum = nil, nil
        if chargeInfo and type(chargeInfo) == "table" then
            current = P8BA6426E.SafeNumber(chargeInfo.currentCharges)
            maximum = P8BA6426E.SafeNumber(chargeInfo.maxCharges) or config.max
        elseif chargeInfo then
            current = P8BA6426E.SafeNumber(chargeInfo)
            maximum = P8BA6426E.SafeNumber(select(2, getSpellCharges(spellID))) or config.max
        end
        if current and (maximum and maximum > 0) then
            wipe(chargeRechargeTimes[spellID])
            local missing = maximum - current
            local now = GetTime()
            for i = 1, missing, 1 do
                table.insert(chargeRechargeTimes[spellID], now + config.duration)
            end
        end
    end
end
local function getTrackedCharges(spellID)
    local config = TRACKED_CHARGES[spellID]
    if not config then
        return 0
    end
    local pending = chargeRechargeTimes[spellID]
    local now = GetTime()
    while pending[1] and pending[1] <= now do
        table.remove(pending, 1)
    end
    return math.max(0, config.max - #pending)
end
local chargeFrame = CreateFrame("Frame")
chargeFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
chargeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
chargeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
chargeFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        syncChargesFromAPI()
        return
    end
    if unit ~= "player" then
        return
    end
    local config = TRACKED_CHARGES[spellID]
    if not config then
        return
    end
    local pending = chargeRechargeTimes[spellID]
    local now = GetTime()
    while pending[1] and pending[1] <= now do
        table.remove(pending, 1)
    end
    if #pending < config.max then
        table.insert(pending, now + config.duration)
    end
end)
P8BA6426E.RegisterClass(264, {
    talentLoadouts = {
        {
            name = "ptr图腾祭祀",
            importString = "CgQALMl7AwW51MWzGneuHE3tPCAAAAAAAAYmZmltlxMzYMzYMjZsAbwMW0YbAZGYjZmxMz2MjRz2yMzmZMbsYMzYYZWGAAMDwMDmZAgBD",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusAckPixel = "party_tank_index",
    raidFocusRangeSpellIDs = { 77472 },
    DEFAULT_MACROS = {
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
        spell_470411 = "/cast [nochanneling,harm,nodead] 烈焰震击",
        cd_108271 = "/cast [nochanneling,@player] 星界转移",
        cd_378081 = "/cast [nochanneling] 自然迅捷",
        spell_462854 = "/cast 天怒",
        spell_370 = "/cast [nochanneling,harm,nodead] 净化术",
        heal_chain_heal = "/cast [nochanneling,@focus,help,nodead] 治疗链",
        cd_79206 = "/cast [nochanneling] 灵魂行者的恩赐",
        spell_188196 = "/cast [nochanneling] 闪电箭",
        spell_188443 = "/cast [nochanneling] 闪电链",
        cd_57994 = "/cast [nochanneling,harm,nodead] 风剪",
        spell_57994_mouseover = "/cast [nochanneling,@mouseover,harm,nodead,exists] 风剪",
        cd_108280 = "/cast 治疗之潮图腾",
        spell_51505 = "/cast [nochanneling] 熔岩爆裂",
        cd_73685 = "/cast [nochanneling,@focus,help,nodead] 生命释放",
        cd_444995 = "/cast [target=player] 涌动图腾",
        cd_457481 = "/cast [nochanneling] 唤潮者的护卫",
        cd_114052 = "/cast [nochanneling] 升腾",
        spell_382021 = "/cast [nochanneling,@player] 大地生命武器",
        heal_riptide = "/cast [nochanneling,@focus,help,nodead] 激流",
        spell_52127 = "/cast [nochanneling,@player] 水之护盾",
        cd_98008 = "/cast [target=cursor] 灵魂链接图腾",
        cd_77130 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]净化灵魂",
        cd_5394 = "/cast [nochanneling] 治疗之泉图腾",
        heal_healing_wave = "/cast [nochanneling,@focus,help,nodead] 治疗波",
        cd_198103 = "/cast 土元素",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        108271,
        378081,
        462854,
        1064,
        79206,
        188196,
        188443,
        57994,
        108280,
        51505,
        73685,
        457481,
        114052,
        382021,
        61295,
        52127,
        98008,
        77130,
        5394,
        77472,
        370,
    },
    HEAL_FOCUS_SPELL_IDS = { [1064] = true, [73685] = true, [61295] = true, [77130] = true, [77472] = true },
    ACTION_LABELS = {
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
        spell_470411 = "烈焰震击",
        cd_108271 = "星界转移",
        cd_378081 = "自然迅捷",
        spell_462854 = "天怒",
        spell_370 = "净化术",
        heal_chain_heal = "治疗链",
        cd_79206 = "灵魂行者的恩赐",
        spell_188196 = "闪电箭",
        spell_188443 = "闪电链",
        cd_57994 = "风剪",
        spell_57994_mouseover = "风剪指向",
        cd_108280 = "治疗之潮图腾",
        spell_51505 = "熔岩爆裂",
        cd_73685 = "生命释放",
        cd_444995 = "涌动图腾",
        cd_457481 = "唤潮者的护卫",
        cd_114052 = "升腾",
        spell_382021 = "大地生命武器",
        heal_riptide = "激流",
        spell_52127 = "水之护盾",
        cd_98008 = "灵魂链接图腾",
        cd_77130 = "净化灵魂",
        cd_5394 = "治疗之泉图腾",
        heal_healing_wave = "治疗波",
        cd_198103 = "土元素",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        focus_player = "CTRL-F8",
        focus_party1 = "CTRL-F9",
        focus_party2 = "CTRL-F10",
        focus_party3 = "CTRL-F11",
        focus_party4 = "CTRL-F12",
        focus_mouseover = "CTRL-8",
        spell_470411 = "F12",
        cd_108271 = "LEFT",
        cd_378081 = "[",
        spell_462854 = "INSERT",
        spell_370 = ";",
        heal_chain_heal = "F7",
        cd_79206 = "]",
        spell_188196 = "9",
        spell_188443 = "0",
        cd_57994 = ",",
        spell_57994_mouseover = "CTRL-9",
        cd_108280 = ".",
        spell_51505 = "8",
        cd_73685 = "F10",
        cd_444995 = "F11",
        cd_457481 = "DOWN",
        cd_114052 = "UP",
        spell_382021 = "=",
        heal_riptide = "F6",
        spell_52127 = "-",
        cd_98008 = "\\",
        cd_77130 = "'",
        cd_5394 = "F9",
        heal_healing_wave = "F8",
        cd_198103 = "RIGHT",
        item_red_potion = "CTRL-F6",
        item_burst_potion = "DELETE",
        item_healing_stone = "CTRL-F7",
        trinket1_cd = "HOME",
        trinket2_cd = "END",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "spell_470411",
        "cd_108271",
        "cd_378081",
        "spell_462854",
        "spell_370",
        "heal_chain_heal",
        "cd_79206",
        "spell_188196",
        "spell_188443",
        "cd_57994",
        "cd_108280",
        "spell_57994_mouseover",
        "spell_51505",
        "cd_73685",
        "cd_444995",
        "cd_457481",
        "cd_114052",
        "spell_382021",
        "heal_riptide",
        "spell_52127",
        "cd_98008",
        "cd_77130",
        "cd_5394",
        "heal_healing_wave",
        "cd_198103",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    cooldownKnownCheckExemptions = { [470411] = true, [444995] = true },
    actionAvailSpellIDs = { 51505, 52127, 188196, 188443, 382021, 462854, 370 },
    testData = {},
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
    GetExtraValues = function(values)
        local now = GetTime()
        values.stack_51505 = getTrackedCharges(51505)
        if not InCombatLockdown() then
            local tankIndex = 0
            for i = 1, 4, 1 do
                local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("party" .. i) or "NONE"
                if role == "TANK" then
                    tankIndex = i
                    break
                end
            end
            party_tank_index = tankIndex
        end
        values.party_tank_index = party_tank_index
        local mouseover_health_pct = 100
        if
            UnitExists("mouseover")
            and (
                UnitIsFriend("player", "mouseover")
                and (not UnitIsDeadOrGhost("mouseover") and P8BA6426E.healthColorCurve)
            )
        then
            local ok, result = pcall(UnitHealthPercent, "mouseover", true, P8BA6426E.healthColorCurve)
            if ok and (type(result) == "table" and result.GetRGB) then
                mouseover_health_pct = result
            end
        end
        values.mouseover_health_pct = mouseover_health_pct
        values.focus_cast_unreachable = P8BA6426E.GetFocusCastUnreachable()
    end,
})
