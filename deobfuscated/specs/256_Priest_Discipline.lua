--[[
  Priest_Discipline（戒律牧师）—— 专精配置：戒律牧师（specID 256）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：ecd88b.lua（TOC 第 83 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local party_tank_index = 0
local TRACKED_CHARGES = { [33206] = { max = 2, duration = 180 } }
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
                table.insert(chargeRechargeTimes[spellID], now + i * config.duration)
            end
        end
    end
end
local stack_evangelism = 0
local chargeFrame = CreateFrame("Frame")
chargeFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
chargeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
chargeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
chargeFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        syncChargesFromAPI()
        stack_evangelism = 0
        return
    end
    if unit ~= "player" then
        return
    end
    local config = TRACKED_CHARGES[spellID]
    if config then
        local pending = chargeRechargeTimes[spellID]
        local now = GetTime()
        while pending[1] and pending[1] <= now do
            table.remove(pending, 1)
        end
        if #pending < config.max then
            local last = pending[#pending] or now
            local readyAt = math.max(last + config.duration, now + config.duration)
            table.insert(pending, readyAt)
        end
    end
    if spellID == 472433 then
        stack_evangelism = 2
    elseif spellID == 194509 then
        if stack_evangelism > 0 then
            stack_evangelism = stack_evangelism - 1
        end
    end
end)
local function getHostileTargetGUID()
    local ok, result = pcall(function()
        if not (UnitExists("target") and (UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target"))) then
            return nil
        end
        return UnitGUID("target")
    end)
    return (ok and result) or nil
end
P8BA6426E.RegisterClass(256, {
    talentLoadouts = {
        {
            name = "茨木虚空编织者",
            importString = "CAQAR03Gt7xPmcDNOjs2Zlb3yCDsMzwyMjxMzgZbGzMjZMzAAAAAAAAAAYMzyMYmZGmhZM2oZiBYmFMEGzyAMGsAAAjZGjBzAMzMTwA",
        },
    },
    showAoeModeButton = true,
    raidFocusEnabled = true,
    raidFocusAckPixel = "party_tank_index",
    raidFocusRangeSpellIDs = { 2061 },
    DEFAULT_MACROS = {
        spell_47540 = "/cast [nochanneling,@focus,help,nodead] 苦修",
        spell_200829 = "/cast [nochanneling,@focus,help,nodead] 恳求",
        spell_472433 = "/cast [nochanneling,@focus,help,nodead] 福音",
        spell_421453 = "/cast [@mouseover,exists,nodead] [@target,exists,nodead] [] 终极苦修",
        heal_flash_heal = "/cast [nochanneling,@focus,help,nodead] 快速治疗",
        cd_17 = "/cast [nochanneling,@focus,help,nodead] 真言术：盾",
        cd_33206 = "/cast [nochanneling,@focus,help,nodead] 痛苦压制",
        cd_194509 = "/cast 真言术：耀",
        spell_589 = "/cast [nochanneling] 暗言术：痛",
        cd_19236 = "/cast [nochanneling] 绝望祷言",
        cd_62618 = "/cast [target=player] 真言术：障",
        cd_10060 = "/cast [nochanneling] 能量灌注",
        spell_585 = "/cast [nochanneling] 惩击",
        spell_8092 = "/cast [nochanneling] 心灵震爆",
        spell_32379 = "/cast [nochanneling] 暗言术：灭",
        spell_586 = "/cast [nochanneling] 渐隐术",
        spell_47540_off = "/cast [nochanneling]苦修",
        cd_527 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]纯净术",
        spell_528 = "/cast [target=mouseover][]驱散魔法",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
        cd_213634 = "/cast [nochanneling,@focus,help,nodead,exists][nochanneling,@mouseover,help,nodead,exists][nochanneling,@player]净化疾病",
        focus_player = "/focus [@player]",
        focus_party1 = "/focus [@party1,exists,nodead]",
        focus_party2 = "/focus [@party2,exists,nodead]",
        focus_party3 = "/focus [@party3,exists,nodead]",
        focus_party4 = "/focus [@party4,exists,nodead]",
        focus_mouseover = "/focus [@mouseover,exists,nodead]",
    },
    testSpells = {
        589,
        19236,
        585,
        47540,
        17,
        194509,
        10060,
        62618,
        33206,
        2061,
        8092,
        32379,
        586,
        472433,
        200829,
        421453,
        527,
        528,
    },
    HEAL_FOCUS_SPELL_IDS = {
        [47540] = true,
        [200829] = true,
        [472433] = true,
        [2061] = true,
        [17] = true,
        [33206] = true,
        [527] = true,
        [213634] = true,
    },
    ACTION_LABELS = {
        spell_589 = "暗言术：痛",
        cd_19236 = "绝望祷言",
        heal_flash_heal = "快速治疗",
        spell_585 = "惩击",
        spell_8092 = "心灵震爆",
        spell_32379 = "暗言术：灭",
        spell_586 = "渐隐术",
        spell_47540 = "苦修",
        cd_17 = "真言术：盾",
        cd_194509 = "真言术：耀",
        cd_10060 = "能量灌注",
        spell_472433 = "福音",
        spell_200829 = "恳求",
        spell_47540_off = "进攻苦修",
        spell_421453 = "终极苦修",
        cd_62618 = "真言术：障",
        cd_33206 = "痛苦压制",
        cd_527 = "纯净术",
        spell_528 = "驱散魔法",
        item_red_potion = "红药水",
        item_burst_potion = "爆发药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
        cd_213634 = "净化疾病",
        focus_player = "焦点：自己",
        focus_party1 = "焦点：队友1",
        focus_party2 = "焦点：队友2",
        focus_party3 = "焦点：队友3",
        focus_party4 = "焦点：队友4",
        focus_mouseover = "焦点：鼠标指向",
    },
    ACTION_TO_KEY = {
        spell_589 = "F11",
        cd_19236 = "\\",
        heal_flash_heal = "F9",
        spell_585 = "F12",
        spell_8092 = "8",
        spell_32379 = "9",
        spell_586 = "UP",
        spell_47540 = "F6",
        cd_17 = "F7",
        cd_194509 = "F8",
        cd_10060 = "[",
        spell_472433 = "=",
        spell_200829 = "F10",
        spell_47540_off = "0",
        spell_421453 = "-",
        cd_62618 = ",",
        cd_33206 = ".",
        cd_527 = "]",
        spell_528 = "'",
        item_red_potion = "INSERT",
        item_burst_potion = "DOWN",
        item_healing_stone = "DELETE",
        trinket1_cd = "LEFT",
        trinket2_cd = "RIGHT",
        cd_213634 = ";",
        focus_player = "HOME",
        focus_party1 = "END",
        focus_party2 = "CTRL-F6",
        focus_party3 = "CTRL-F7",
        focus_party4 = "CTRL-F8",
        focus_mouseover = "CTRL-F9",
    },
    macroOrder = {
        "focus_player",
        "focus_party1",
        "focus_party2",
        "focus_party3",
        "focus_party4",
        "focus_mouseover",
        "spell_589",
        "cd_19236",
        "heal_flash_heal",
        "spell_585",
        "spell_8092",
        "spell_32379",
        "spell_586",
        "spell_47540",
        "cd_17",
        "cd_194509",
        "cd_10060",
        "spell_472433",
        "spell_200829",
        "spell_47540_off",
        "spell_421453",
        "cd_62618",
        "cd_33206",
        "cd_527",
        "spell_528",
        "item_red_potion",
        "item_burst_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
        "cd_213634",
    },
    actionAvailSpellIDs = { 528, 585, 200829 },
    trinketItemID = nil,
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
        values.stack_evangelism = stack_evangelism
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
