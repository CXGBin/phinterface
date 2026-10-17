--[[
  Priest_Shadow（暗影牧师）—— 专精配置：暗影牧师（specID 258）——天赋方案、默认宏、动作→按键映射、像素额外字段(GetExtraValues)与施法回调
  原始文件：63cab8.lua（TOC 第 60 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local lastCastSpellID = nil
local lastCastAt = 0
local scalarValueErrors = {}
local insanityCurve, insanityCurveMax
local function isVoidTorrentInterruptReady()
    local isChanneling, inWindow, reliable = P8BA6426E.GetPlayerChannelWindowState(263165, 0, 1)
    assert(reliable, "虚空洪流引导状态不可读")
    if not isChanneling or not inWindow then
        return false
    end
    local insanity = Enum.PowerType.Insanity
    local power = UnitPower("player", insanity)
    if not (issecretvalue and issecretvalue(power)) then
        assert(
            type(power) == "number" and (power == power and (power >= 0 and power < math.huge)),
            "狂乱值不可读"
        )
        return power > 40
    end
    local powerMax = UnitPowerMax("player", insanity)
    assert(
        not (issecretvalue and issecretvalue(powerMax))
            and (type(powerMax) == "number" and (powerMax > 0 and (powerMax < math.huge and powerMax % 1 == 0))),
        "狂乱值上限不可读"
    )
    if powerMax <= 40 then
        return false
    end
    if not insanityCurve or insanityCurveMax ~= powerMax then
        local colorCurve = C_CurveUtil.CreateColorCurve()
        colorCurve:SetType(Enum.LuaCurveType.Step)
        colorCurve:AddPoint(0, CreateColor(1, 0, 0, 1))
        colorCurve:AddPoint(41 / powerMax, CreateColor(0, 1, 0, 1))
        insanityCurve, insanityCurveMax = colorCurve, powerMax
    end
    local powerPercent = UnitPowerPercent("player", insanity, false, insanityCurve)
    assert(type(powerPercent) == "table" and type(powerPercent.GetRGB) == "function", "狂乱值阈值颜色不可读")
    return powerPercent
end
local function isShadowformActive()
    if not (GetNumShapeshiftForms and GetShapeshiftFormInfo) then
        return false
    end
    for i = 1, GetNumShapeshiftForms(), 1 do
        local _icon, active, _castable, formSpellID = GetShapeshiftFormInfo(i)
        if active and formSpellID == 232698 then
            return true
        end
    end
    return false
end
P8BA6426E.RegisterClass(258, {
    scalarValueErrors = scalarValueErrors,
    talentLoadouts = {
        {
            name = "虚空大痛单体",
            importString = "CIQAAAAAAAAAAAAAAAAAAAAAAMjZMAAAAAAAAAAAAYMLzMzYbmxMz2MDzw2MzYmZGbIzYxMNAzMzAABY2mtFwsxAADGzMzY2GzgZGMDGA",
        },
        {
            name = "虚空大米",
            importString = "CIQAAAAAAAAAAAAAAAAAAAAAAMMDDAAAAAAAAAAAAmZxMmZbmxMzyMzYG2mZGzMzYDZGLmpBYmZGAIAz2stAmNGAYwYmZGzGzgZGMDGA",
        },
    },
    showAoeModeButton = true,
    DEFAULT_MACROS = {
        spell_15407 = "/cast 精神鞭笞",
        spell_8092 = "/cast 心灵震爆",
        spell_34914 = "/cast 吸血鬼之触",
        spell_1227280 = "/cast 触须猛击",
        spell_1236425 = "/cast 虚空齐射",
        spell_32379 = "/cast 暗言术：灭",
        spell_335467 = "/cast 暗言术：癫",
        spell_120644 = "/cast 光晕",
        spell_228260 = "/cast 虚空形态\n/cast 能量灌注",
        spell_528 = "/cast [target=mouseover][]驱散魔法",
        spell_263165 = "/cast 虚空洪流",
        mouseover_vt = "/cast [@mouseover,harm,nodead] 吸血鬼之触",
        mouseover_swp = "/cast [@mouseover,harm,nodead] 暗言术：痛",
        mouseover_tentacle = "/cast [@mouseover,harm,nodead] 触须猛击",
        spell_32379_mouseover = "/cast [@mouseover,harm,nodead] 暗言术：灭",
        spell_589 = "/cast 暗言术：痛",
        spell_15286 = "/cast 吸血鬼的拥抱",
        spell_17 = "/cast [@player] 真言术：盾",
        spell_232698 = "/cast [noform:1]暗影形态",
        item_burst_potion = "/use item:241308\n/use item:241309\n/use item:241288\n/use item:241289",
        cd_15487 = "/cast 沉默",
        spell_15487_mouseover = "/cast [@mouseover,harm,nodead,exists] 沉默",
        focus_interrupt = "/cast [@focus]沉默",
        cd_19236 = "/cast 绝望祷言",
        cd_47585 = "/cast 消散",
        cd_586 = "/cast 渐隐术",
        item_red_potion = "/use item:271883\n/use item:271884",
        item_healing_stone = "/use item:5512",
        trinket1_cd = "/use 13",
        trinket2_cd = "/use 14",
    },
    testSpells = {
        15407,
        8092,
        34914,
        1227280,
        1236425,
        32379,
        335467,
        120644,
        228260,
        528,
        263165,
        589,
        15286,
        17,
        232698,
    },
    ACTION_LABELS = {
        spell_15407 = "精神鞭笞",
        spell_8092 = "心灵震爆",
        spell_34914 = "吸血鬼之触",
        spell_1227280 = "触须猛击",
        spell_1236425 = "虚空齐射",
        spell_32379 = "暗言术：灭",
        spell_335467 = "暗言术：癫",
        spell_120644 = "光晕",
        spell_228260 = "虚空形态",
        spell_528 = "驱散魔法",
        spell_263165 = "虚空洪流",
        mouseover_vt = "指向触",
        mouseover_swp = "指向痛",
        mouseover_tentacle = "指向触须",
        spell_32379_mouseover = "指向灭",
        spell_589 = "暗言术：痛",
        spell_15286 = "吸血鬼的拥抱",
        spell_17 = "真言术：盾",
        spell_232698 = "暗影形态",
        item_burst_potion = "爆发药水",
        cd_15487 = "沉默",
        spell_15487_mouseover = "沉默指向",
        focus_interrupt = "沉默焦点",
        cd_19236 = "绝望祷言",
        cd_47585 = "消散",
        cd_586 = "渐隐术",
        item_red_potion = "红药水",
        item_healing_stone = "治疗石",
        trinket1_cd = "饰品1",
        trinket2_cd = "饰品2",
    },
    ACTION_TO_KEY = {
        spell_15407 = "F6",
        spell_8092 = "F7",
        spell_34914 = "F10",
        spell_1227280 = "F11",
        spell_1236425 = "F12",
        spell_32379 = "8",
        spell_335467 = "F8",
        spell_120644 = ";",
        spell_228260 = "]",
        spell_528 = ".",
        spell_263165 = "[",
        mouseover_vt = "9",
        mouseover_swp = "0",
        mouseover_tentacle = "-",
        spell_32379_mouseover = "=",
        spell_589 = "F9",
        spell_15286 = "'",
        spell_17 = ",",
        spell_232698 = "\\",
        item_burst_potion = "DELETE",
        cd_15487 = "UP",
        spell_15487_mouseover = "CTRL-F8",
        focus_interrupt = "INSERT",
        cd_19236 = "DOWN",
        cd_47585 = "LEFT",
        cd_586 = "RIGHT",
        item_red_potion = "CTRL-F6",
        item_healing_stone = "CTRL-F7",
        trinket1_cd = "HOME",
        trinket2_cd = "END",
    },
    macroOrder = {
        "spell_15407",
        "spell_8092",
        "spell_34914",
        "spell_1227280",
        "spell_1236425",
        "spell_32379",
        "spell_335467",
        "spell_120644",
        "spell_228260",
        "spell_528",
        "spell_263165",
        "mouseover_vt",
        "mouseover_swp",
        "mouseover_tentacle",
        "spell_32379_mouseover",
        "spell_589",
        "spell_15286",
        "spell_17",
        "spell_232698",
        "item_burst_potion",
        "cd_15487",
        "spell_15487_mouseover",
        "focus_interrupt",
        "cd_19236",
        "cd_47585",
        "cd_586",
        "item_red_potion",
        "item_healing_stone",
        "trinket1_cd",
        "trinket2_cd",
    },
    testData = {},
    actionAvailSpellIDs = { 17, 528, 589, 15286, 15407, 34914, 232698, 335467 },
    spellReadyAliases = { [17] = { 1246768 }, [232698] = { 1251209 } },
    OnSpellCast = function(spellID)
        local now = GetTime()
        if lastCastSpellID == spellID and (now - lastCastAt) < 0.5 then
            return
        end
        lastCastSpellID = spellID
        lastCastAt = now
    end,
    GetExtraValues = function(values)
        values.shadowform = isShadowformActive()
        local isChanneling, inWindow, reliable = P8BA6426E.GetPlayerChannelWindowState(15407, 2, 6)
        values.mind_flay_interrupt_ready = reliable and (not isChanneling or inWindow) or false
        local ok, void_torrent_interrupt_ready = pcall(isVoidTorrentInterruptReady)
        if ok then
            values.void_torrent_interrupt_ready, scalarValueErrors.void_torrent_interrupt_ready =
                void_torrent_interrupt_ready, nil
        else
            values.void_torrent_interrupt_ready, scalarValueErrors.void_torrent_interrupt_ready =
                nil, tostring(void_torrent_interrupt_ready)
        end
        local mouseover_health_pct = 16777215
        if SecureCmdOptionParse and (UnitHealthPercent and P8BA6426E.healthColorCurve) then
            local ok, result = pcall(function()
                if SecureCmdOptionParse("[@mouseover,harm,nodead,exists] 1; 0") ~= "1" then
                    return nil
                end
                return UnitHealthPercent("mouseover", true, P8BA6426E.healthColorCurve)
            end)
            if ok and (type(result) == "table" and result.GetRGB) then
                mouseover_health_pct = result
            end
        end
        values.mouseover_health_pct = mouseover_health_pct
    end,
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
})
