--[[
  PresenceProducer —— 像素“存在性”生产器：光环存在、驱散、失控、团队光环计数、治疗吸收等
  原始文件：5991da.lua（TOC 第 21 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local function spellIDSet(field, singleSpellID)
    if singleSpellID then
        return { [singleSpellID] = true }
    end
    if field.spellID then
        return { [field.spellID] = true }
    end
    if not field.spellIDs then
        return nil
    end
    local set = {}
    for _, spellID in ipairs(field.spellIDs) do
        set[spellID] = true
    end
    return set
end
local function getAuraFilter(field)
    if field.filter then
        return field.filter
    end
    if field.kind == "dispel_presence" then
        return "HARMFUL"
    end
    if field.unit == "target" then
        return "HARMFUL|PLAYER"
    end
    return "HELPFUL|PLAYER"
end
local function dispelTypeSet(field)
    local set = {}
    for _, dispelType in ipairs(field.dispelTypes or {}) do
        set[dispelType] = true
    end
    return set
end
local function knowsDispel(field, cache)
    if not field.dispelSpellIDs then
        return true
    end
    assert(C_SpellBook and C_SpellBook.IsSpellKnown, "驱散学习接口不可用")
    for _, dispelSpellID in ipairs(field.dispelSpellIDs) do
        local known = cache[dispelSpellID]
        if known == nil then
            known = C_SpellBook.IsSpellKnown(dispelSpellID)
            assert(
                not (issecretvalue and issecretvalue(known)) and type(known) == "boolean",
                "驱散学习状态不可读"
            )
            cache[dispelSpellID] = known
        end
        if known then
            return true
        end
    end
    return false
end
local function isUnitValid(unit, relation)
    if unit == "player" then
        return true
    end
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then
        return false
    end
    if relation == "assist" then
        return UnitCanAssist("player", unit)
    end
    if relation == "help" then
        return UnitIsFriend("player", unit)
    end
    if relation == "harm" then
        return UnitCanAttack("player", unit)
    end
    return true
end
local function shrinkAuraFrame(frame)
    frame:SetSize(1, 1)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", 0, 0)
    if frame.SetMouseClickEnabled then
        pcall(frame.SetMouseClickEnabled, frame, false)
    end
    if frame.SetMouseMotionEnabled then
        pcall(frame.SetMouseMotionEnabled, frame, false)
    end
end
local ABSORB_SPECS_BY_FLAVOR = {
    retail = {
        [65] = true,
        [66] = true,
        [105] = true,
        [256] = true,
        [257] = true,
        [264] = true,
        [270] = true,
        [1468] = true,
    },
    forever = { [1486] = true, [1484] = true, [1487] = true, [1489] = true },
}
function P8BA6426E.IsPixelNativeAbsorbSpec(specID)
    return ((ABSORB_SPECS_BY_FLAVOR[P8BA6426E.flavor] or ABSORB_SPECS_BY_FLAVOR.retail))[specID] == true
end
-- 存在性生产器：用 AuraContainer 的初始化回调在对应像素行叠加颜色，表示光环/驱散/失控是否存在
function P8BA6426E.CreatePixelNativePresenceProducer(params)
    local frame, contract = assert(params.frame), assert(params.contract)
    local onFieldError = assert(params.onFieldError)
    local producer = {}
    local containers, presenceEntries, groupCountEntries, locEntries, dispelEntries, absorbEntries =
        {}, {}, {}, {}, {}, {}
    local active = false
    local presenceLayoutByKey, classicRowByKey = {}, {}
    for _, presenceField in ipairs(contract.presenceFields or {}) do
        assert(not presenceLayoutByKey[presenceField.field.key], "V3 存在字段重复")
        presenceLayoutByKey[presenceField.field.key] = presenceField
    end
    for i, classicKey in ipairs(contract.classicKeys or {}) do
        classicRowByKey[classicKey] = contract.classicRows[i]
    end
    local function setError(row, key, err)
        onFieldError(row, "native:" .. key, err)
    end
    local function runGuarded(row, key, fn)
        local ok, result = pcall(fn)
        setError(row, key, not ok and result or nil)
        return ok
    end
    local function newCell(row, r, g, b)
        return params.newCell(row, r, g, b)
    end
    local function paintCell(cell, row, key, r, g, b)
        runGuarded(row, key, function()
            assert(cell:SetTextColor(r, g, b, 1) ~= false, "V3 存在底色写入失败")
        end)
    end
    local function createAuraContainer(field, nativeRow, suffix, candidateFilters, onInit)
        local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        local slotOptions = {
            initializeFrame = function(auraFrame)
                runGuarded(nativeRow, field.key .. (suffix .. ":binding"), function()
                    shrinkAuraFrame(auraFrame)
                    onInit(auraFrame)
                end)
            end,
        }
        if candidateFilters then
            slotOptions.candidateFilters = candidateFilters
        end
        container:AddAuraSlot(field.key .. suffix, getAuraFilter(field), slotOptions)
        container:SetUnit(field.unit or "player")
        container:Hide()
        container.nativeRow, container.nativeKey = nativeRow, field.key .. suffix
        containers[#containers + 1] = container
        return container
    end
    local function paintPresenceGlyph(auraFrame, row)
        local glyphsByProducer = auraFrame.p8ba6426ePresenceGlyphs
        if not glyphsByProducer then
            glyphsByProducer = {}
            auraFrame.p8ba6426ePresenceGlyphs = glyphsByProducer
        end
        local glyphs = glyphsByProducer[producer]
        if not glyphs then
            glyphs = {}
            glyphsByProducer[producer] = glyphs
        end
        local glyph = glyphs[row]
        if not glyph then
            glyph = params.newGlyph(auraFrame, row)
            glyphs[row] = glyph
        end
        glyph:SetTextColor(0, 1, 0, 1)
    end
    local function buildPresence(field, layout)
        local rows = layout.rows or 1
        local spellIDs = field.spellIDs
        for i = 1, rows, 1 do
            local row = (layout.row + i) - 1
            local base = newCell(row, 51, 51, 51)
            local unit = field.unit or "player"
            local isDispel = field.kind == "dispel_presence"
            local relation = isDispel and "assist"
                or (unit == "mouseover" and (field.unitRelation == "help" and "assist" or "harm"))
            local filters
            if field.dispelTypes then
                filters = { includeDispelTypes = dispelTypeSet(field) }
            else
                local includeSpellIDs = spellIDSet(field, spellIDs and spellIDs[i])
                if includeSpellIDs then
                    filters = { includeSpellIDs = includeSpellIDs }
                end
            end
            local container = createAuraContainer(field, row, "#" .. i, filters, function(auraFrame)
                paintPresenceGlyph(auraFrame, row)
            end)
            local entry =
                { row = row, field = field, unit = unit, relation = relation, base = base, container = container }
            presenceEntries[#presenceEntries + 1] = entry
        end
    end
    local function buildLossOfControl(field, layout)
        local types = {}
        for _, locType in ipairs(field.locTypes or {}) do
            types[locType] = true
        end
        locEntries[#locEntries + 1] =
            { row = layout.row, key = field.key, types = types, field = field, cell = newCell(layout.row, 51, 51, 51) }
    end
    local function buildGroupCount(field, layout)
        local row = layout.row
        local entry = { row = row, key = field.key, containers = {} }
        newCell(row, 0, 0, 0)
        for i = 1, 30, 1 do
            local container = createAuraContainer(
                field,
                row,
                "#group#" .. i,
                { includeSpellIDs = spellIDSet(field) },
                function(auraFrame)
                    local ink = auraFrame.p8ba6426eGroupCountTexture
                    if not ink then
                        ink = auraFrame:CreateTexture(nil, "OVERLAY")
                        auraFrame.p8ba6426eGroupCountTexture = ink
                    end
                    ink:SetSize(1, 1)
                    ink:ClearAllPoints()
                    ink:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -row)
                    ink:SetBlendMode("ADD")
                    ink:SetColorTexture(0, 0, 0.031372549019608, 1)
                end
            )
            entry.containers[i] = container
        end
        groupCountEntries[#groupCountEntries + 1] = entry
    end
    local function buildDispelOverlay(field)
        if (field.unit or "player") == "focus" then
            return
        end
        local row = assert(classicRowByKey[field.rowRef], "V3 驱散血量行不存在")
        assert(row >= 0, "V3 驱散血量行未绘制")
        local container = createAuraContainer(
            field,
            row,
            "#dispel",
            { includeDispelTypes = dispelTypeSet(field) },
            function(auraFrame)
                local ink = auraFrame.p8ba6426eDispelTexture
                if not ink then
                    ink = auraFrame:CreateTexture(nil, "OVERLAY")
                    auraFrame.p8ba6426eDispelTexture = ink
                end
                ink:SetSize(1, 1)
                ink:ClearAllPoints()
                ink:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -row)
                ink:SetDrawLayer("OVERLAY", 2)
                ink:SetBlendMode("ADD")
                ink:SetColorTexture(1, 0, 0, 1)
            end
        )
        dispelEntries[#dispelEntries + 1] =
            { row = row, field = field, container = container, unit = field.unit or "player" }
    end
    local ABSORB_UNITS = { "player", "party1", "party2", "party3", "party4", "mouseover" }
    local function buildAbsorbBars()
        if not P8BA6426E.IsPixelNativeAbsorbSpec(params.specID) then
            return
        end
        for _, unit in ipairs(ABSORB_UNITS) do
            local row = classicRowByKey[unit .. "_health_pct"]
            if row and row >= 0 then
                runGuarded(row, "heal_absorb:" .. (unit .. ":build"), function()
                    local bar = CreateFrame("StatusBar", nil, frame)
                    bar:SetSize(1, 1)
                    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -row)
                    bar:SetMinMaxValues(0, 1)
                    bar:SetOrientation("HORIZONTAL")
                    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    bar:SetFrameLevel(frame:GetFrameLevel() + 1)
                    bar:EnableMouse(false)
                    local barTexture = bar:GetStatusBarTexture()
                    barTexture:SetDrawLayer("OVERLAY", 1)
                    barTexture:SetBlendMode("ADD")
                    bar:SetStatusBarColor(0, 1, 0, 1)
                    bar:SetValue(0)
                    bar:Hide()
                    absorbEntries[#absorbEntries + 1] = { row = row, unit = unit, bar = bar }
                end)
            end
        end
    end
    local nameplateFields = {}
    for _, bindingField in ipairs(contract.bindingFields or {}) do
        local kind = bindingField.kind
        if kind == "dispel_presence" and bindingField.rowRef then
            local row = classicRowByKey[bindingField.rowRef]
            assert(row and row >= 0, "V3 驱散叠加字段缺少物理行")
            runGuarded(row, bindingField.key .. ":build", function()
                buildDispelOverlay(bindingField)
            end)
        elseif
            kind == "presence"
            or kind == "presence_all"
            or kind == "presence_count"
            or kind == "presence_index"
            or (kind == "dispel_presence" and not bindingField.rowRef)
        then
            local layout = assert(presenceLayoutByKey[bindingField.key], "V3 存在字段缺少物理行")
            runGuarded(layout.row, bindingField.key .. ":build", function()
                buildPresence(bindingField, layout)
            end)
        elseif kind == "loc_presence" then
            local layout = assert(presenceLayoutByKey[bindingField.key], "V3 失控字段缺少物理行")
            runGuarded(layout.row, bindingField.key .. ":build", function()
                buildLossOfControl(bindingField, layout)
            end)
        elseif kind == "presence_group_count" then
            local layout = assert(presenceLayoutByKey[bindingField.key], "V3 团队字段缺少物理行")
            runGuarded(layout.row, bindingField.key .. ":build", function()
                buildGroupCount(bindingField, layout)
            end)
        elseif
            kind == "presence_nameplate_missing_count"
            or kind == "presence_nameplate_all_absent"
            or kind == "presence_nameplate_aura_average"
            or kind == "presence_nameplate_expiring_count"
        then
            nameplateFields[#nameplateFields + 1] = {
                field = bindingField,
                layout = assert(presenceLayoutByKey[bindingField.key], "V3 姓名板字段缺少物理行"),
            }
        elseif kind ~= "cd_seconds" and (kind ~= "charge_lua" and kind ~= "aura_seconds") then
            error("V3 原生字段类型未接管：" .. tostring(kind))
        end
    end
    buildAbsorbBars()
    producer.nameplates = P8BA6426E.CreatePixelNativeNameplateProducer({
        frame = frame,
        fields = nameplateFields,
        newCell = params.newCell,
        onFieldError = onFieldError,
    })
    function producer.RefreshGroupCounts(forceUpdate)
        if not active then
            return true
        end
        for _, entry in ipairs(groupCountEntries) do
            for i, container in ipairs(entry.containers) do
                local groupUnit = IsInRaid() and ("raid" .. i)
                    or (i == 1 and "player" or (i <= 5 and ("party" .. (i - 1)) or nil))
                local ok = runGuarded(entry.row, entry.key .. (":group:" .. i), function()
                    local exists = groupUnit
                        and (
                            UnitExists(groupUnit) and (UnitIsConnected(groupUnit) and not UnitIsDeadOrGhost(groupUnit))
                        )
                    if exists then
                        if container.groupUnit ~= groupUnit then
                            container:Hide()
                            container:SetUnit(groupUnit)
                            container.groupUnit = groupUnit
                            container:UpdateAllAuras()
                        elseif forceUpdate then
                            container:UpdateAllAuras()
                        end
                        container:Show()
                    else
                        container:Hide()
                        container.groupUnit = nil
                    end
                end)
                if not ok then
                    container.groupUnit = nil
                end
            end
        end
        return true
    end
    function producer.MarkGroupRefreshError(stage, err)
        for _, entry in ipairs(groupCountEntries) do
            setError(entry.row, entry.key .. (":group_" .. stage), err)
        end
    end
    function producer.Refresh(forceUpdate)
        if not active then
            return true
        end
        local dispelKnownCache = {}
        for _, entry in ipairs(presenceEntries) do
            runGuarded(entry.row, entry.field.key .. ":lifecycle", function()
                local valid = isUnitValid(entry.unit, entry.relation)
                paintCell(
                    entry.base,
                    entry.row,
                    entry.field.key .. ":base",
                    valid and 0.2 or 0,
                    valid and 0.2 or 0,
                    valid and 0.2 or 1
                )
                local show = valid and knowsDispel(entry.field, dispelKnownCache)
                entry.container:SetShown(show)
                if
                    show
                    and (forceUpdate or entry.unit == "mouseover" or entry.unit == "focus" or entry.unit == "target")
                then
                    entry.container:UpdateAllAuras()
                end
            end)
        end
        for _, entry in ipairs(dispelEntries) do
            runGuarded(entry.row, entry.field.key .. ":lifecycle", function()
                local valid = isUnitValid(entry.unit, entry.unit == "mouseover" and "assist" or "help")
                entry.container:SetShown(valid)
                if valid and (forceUpdate or entry.unit == "mouseover" or not entry.valid) then
                    entry.container:UpdateAllAuras()
                end
                entry.valid = valid
            end)
        end
        producer.RefreshGroupCounts(forceUpdate)
        local locSnapshot
        if P8BA6426E.ClientCapabilities.completeLossOfControlSnapshot and #locEntries > 0 then
            locSnapshot = P8BA6426E.ReadPixelLossOfControlSnapshot()
        end
        for _, entry in ipairs(locEntries) do
            runGuarded(entry.row, entry.key .. ":loc", function()
                local isLocked = false
                local locAPI = C_LossOfControl
                if P8BA6426E.ClientCapabilities.completeLossOfControlSnapshot then
                    local err
                    isLocked, err = P8BA6426E.ReadPixelLossOfControl(entry.types, locSnapshot)
                    assert(isLocked ~= nil, err or "失控状态不可读")
                    if not isLocked then
                        assert(not entry.field.positiveOnly, "此类型尚未证明可完整枚举")
                        for _, ambiguousLocType in ipairs(entry.field.ambiguousLocTypes or {}) do
                            assert(not locSnapshot.types[ambiguousLocType], "此失控类型无法精确区分")
                        end
                    end
                elseif locAPI and (locAPI.GetActiveLossOfControlDataCount and locAPI.GetActiveLossOfControlData) then
                    local count = locAPI.GetActiveLossOfControlDataCount() or 0
                    for i = 1, count, 1 do
                        local data = locAPI.GetActiveLossOfControlData(i)
                        if
                            data
                            and (
                                data.locType
                                and (
                                    (not issecretvalue or not issecretvalue(data.locType))
                                    and entry.types[data.locType]
                                )
                            )
                        then
                            isLocked = true
                            break
                        end
                    end
                end
                assert(
                    entry.cell:SetTextColor(isLocked and 0 or 0.2, isLocked and 1 or 0.2, isLocked and 0 or 0.2, 1)
                        ~= false
                )
            end)
        end
        for _, entry in ipairs(absorbEntries) do
            runGuarded(entry.row, "heal_absorb:" .. entry.unit, function()
                local valid = entry.unit == "player" or isUnitValid(entry.unit, "help")
                entry.bar:SetValue(valid and UnitGetTotalHealAbsorbs(entry.unit) or 0)
            end)
        end
        producer.nameplates.Refresh(forceUpdate)
        return true
    end
    function producer.Enable()
        if InCombatLockdown() then
            return false, "请脱战后启用原生存在容器"
        end
        active = true
        for _, entry in ipairs(containers) do
            runGuarded(entry.nativeRow, entry.nativeKey .. ":enable", function()
                entry:SetEnabled(true)
            end)
        end
        for _, entry in ipairs(absorbEntries) do
            runGuarded(entry.row, "heal_absorb:" .. (entry.unit .. ":enable"), function()
                entry.bar:Show()
            end)
        end
        producer.nameplates.Enable()
        producer.Refresh(true)
        return true
    end
    function producer.Disable()
        active = false
        for _, entry in ipairs(containers) do
            runGuarded(entry.nativeRow, entry.nativeKey .. ":disable", function()
                entry:SetEnabled(false)
                entry:Hide()
            end)
        end
        for _, entry in ipairs(absorbEntries) do
            runGuarded(entry.row, "heal_absorb:" .. (entry.unit .. ":disable"), function()
                entry.bar:Hide()
            end)
        end
        producer.nameplates.Disable()
    end
    return producer
end
