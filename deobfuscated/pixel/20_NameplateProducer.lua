--[[
  NameplateProducer —— 像素姓名板生产器：统计附近敌人身上指定光环缺失/剩余时间并编码
  原始文件：9fece1.lua（TOC 第 20 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local MAX_NAMEPLATES, REBIND_SETTLE_SECONDS = 40, 0.05
local function readNumber(value, minValue, maxValue)
    if issecretvalue then
        local ok, result = pcall(issecretvalue, value)
        if not ok or result then
            return nil
        end
    end
    if type(value) ~= "number" or value < minValue or value > maxValue then
        return nil
    end
    return value
end
local function readInt(v, minValue, maxValue)
    local n = readNumber(v, minValue, maxValue)
    return n and (n % 1 == 0 and n) or nil
end
local function readGUID(unit)
    local ok, result = pcall(UnitGUID, unit)
    if not ok then
        return nil
    end
    if issecretvalue then
        local ok, result = pcall(issecretvalue, result)
        if not ok or result then
            return nil
        end
    end
    return type(result) == "string" and result or nil
end
local function isLiveHostile(unit)
    local ok, result = pcall(function()
        return type(unit) == "string"
            and (UnitExists(unit) and (UnitCanAttack("player", unit) and not UnitIsDeadOrGhost(unit)))
    end)
    return ok and result or false
end
local function isSpellInRange(spellID, unit)
    if not spellID then
        return true
    end
    if not C_Spell or not C_Spell.IsSpellInRange then
        return nil
    end
    local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
    if not ok then
        return nil
    end
    if issecretvalue then
        local ok, result = pcall(issecretvalue, result)
        if not ok or result then
            return nil
        end
    end
    return type(result) == "boolean" and result or nil
end
local function rgb255(r, g, b)
    return CreateColor(r / 255, g / 255, b / 255, 1)
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
local function createInkTexture(parent, anchor, row, r, g, b, subLevel)
    local texture = parent:CreateTexture(nil, "OVERLAY", nil, subLevel)
    texture:SetSize(1, 1)
    texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -row)
    texture:SetBlendMode("ADD")
    texture:SetColorTexture(r / 255, g / 255, b / 255, 1)
    return texture
end
-- 姓名板生产器：对快照中的敌人姓名板绑定 AuraContainer，统计光环缺失数量或平均剩余时间
function P8BA6426E.CreatePixelNativeNameplateProducer(params)
    local frame, onFieldError = assert(params.frame), assert(params.onFieldError)
    local producer = {}
    local allEntries, countEntriesByKey, timeEntries = {}, {}, {}
    local active = false
    local curveCache = {}
    local function setEntryError(entry, err, suffix)
        for i = entry.layout.row, (entry.layout.row + entry.layout.rows) - 1, 1 do
            onFieldError(i, "native:nameplate:" .. (entry.field.key .. (suffix or "")), err)
        end
    end
    local function runGuarded(entry, fn, suffix)
        local ok, result = pcall(fn)
        setEntryError(entry, not ok and result or nil, suffix)
        return ok
    end
    local function paintCells(entry, r, g, b)
        for _, cell in ipairs(entry.cells) do
            assert(cell:SetTextColor(r, g, b, 1) ~= false, "姓名板底色写入失败")
        end
    end
    local function showLayers(entry, shown)
        for _, layer in ipairs(entry.layers) do
            layer.texture:SetShown(shown)
        end
    end
    local function hideEntry(entry)
        for _, container in ipairs(entry.containers) do
            container:Hide()
            if container.marker then
                container.marker:SetAlpha(0)
            end
        end
        showLayers(entry, false)
    end
    local function createContainer(entry, parent, _)
        local container = CreateFrame("AuraContainer", nil, parent or frame, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", parent or frame, "TOPLEFT", 0, 0)
        container:Hide()
        container.entry = entry
        entry.containers[#entry.containers + 1] = container
        return container
    end
    local function addAuraSlot(entry, container, spellID, suffix, onInit)
        container:AddAuraSlot(entry.field.key .. suffix, entry.field.filter or "HARMFUL|PLAYER", {
            candidateFilters = { includeSpellIDs = { [spellID] = true } },
            initializeFrame = function(auraFrame)
                local ok, result = pcall(function()
                    shrinkAuraFrame(auraFrame)
                    onInit(auraFrame)
                end)
                if not ok then
                    entry.bindError = tostring(result)
                    setEntryError(entry, result)
                end
            end,
        })
    end
    local function selectUnits(entry, snapshot)
        if type(snapshot) ~= "table" then
            return nil, nil
        end
        local field = entry.field
        local count = readInt(snapshot[field.sourcePixel], 0, MAX_NAMEPLATES)
        local updatedAt = readNumber(snapshot.updatedAt, 0, 1000000000)
        local now = GetTime()
        local units = field.sourcePixel == "enemies_8yd_raw" and snapshot.nearby8
            or field.sourcePixel == "combat_enemies_raw" and snapshot.combat
            or snapshot.active
        if
            not count
            or not updatedAt
            or now - updatedAt > 0.35
            or now - updatedAt < -0.05
            or type(units) ~= "table"
            or #units ~= count
            or type(snapshot.guids) ~= "table"
            or (field.sourcePixel == "combat_enemies_raw" and snapshot.combatKnown ~= true)
            or (field.sourcePixel == "enemies_8yd_raw" and snapshot.nearby8Overflow ~= false)
        then
            return nil, nil
        end
        local selected, seenUnits, seenGUIDs = {}, {}, {}
        for _, unit in ipairs(units) do
            local snapshotGUID = snapshot.guids[unit]
            local liveGUID = readGUID(unit)
            local hasGUID = type(snapshotGUID) == "string" or liveGUID ~= nil
            if field.sourcePixel == "combat_enemies_raw" and (type(snapshotGUID) ~= "string" or liveGUID == nil) then
                return nil, nil
            end
            if
                not isLiveHostile(unit)
                or seenUnits[unit]
                or (liveGUID and seenGUIDs[liveGUID])
                or (hasGUID and (type(snapshotGUID) ~= "string" or liveGUID ~= snapshotGUID))
            then
                return nil, nil
            end
            seenUnits[unit] = true
            if liveGUID then
                seenGUIDs[liveGUID] = true
            end
            local inRange = isSpellInRange(field.rangeSpellID, unit)
            if inRange == nil then
                return nil, nil
            end
            if inRange then
                selected[#selected + 1] = { unit = unit, guid = liveGUID }
            end
        end
        if field.rangeSpellID and #selected ~= count then
            return nil, nil
        end
        return selected, count
    end
    local function bindContainers(entry, selected, forceUpdate)
        local changed, allBound = false, true
        for i, container in ipairs(entry.containers) do
            local pick = selected and selected[i]
            local boundUnit, boundGUID = pick and pick.unit, pick and pick.guid
            if container.boundUnit ~= boundUnit or container.boundGUID ~= boundGUID then
                changed = true
                container:Hide()
                container.boundUnit, container.boundGUID = nil, nil
                if boundUnit then
                    local ok = pcall(function()
                        container:SetUnit(boundUnit)
                        container:UpdateAllAuras()
                    end)
                    if ok then
                        container.boundUnit, container.boundGUID = boundUnit, boundGUID
                        container:Show()
                    else
                        allBound = false
                    end
                end
            elseif boundUnit then
                if forceUpdate and not pcall(container.UpdateAllAuras, container) then
                    allBound = false
                end
                container:Show()
            end
        end
        if changed then
            entry.invalidUntil = GetTime() + REBIND_SETTLE_SECONDS
        end
        return allBound
    end
    local function updateTargetMask(entry)
        if not entry.field.excludeCurrentTarget then
            return
        end
        for _, container in ipairs(entry.containers) do
            if container.boundUnit then
                local isUnit = UnitIsUnit(container.boundUnit, "target")
                container.mask:SetAlphaFromBoolean(isUnit, 0, 255)
                if container.marker then
                    container.marker:SetAlphaFromBoolean(isUnit, 255, 0)
                end
            elseif container.marker then
                container.marker:SetAlpha(0)
            end
        end
    end
    local function buildCountEntry(entry)
        local field = entry.field
        local ids = field.spellIDs or { field.spellID }
        assert(
            field.unit == "nameplate"
                and (
                    (#ids == 1 or #ids == 2)
                    and (
                        (
                            field.sourcePixel == "enemies_8yd_raw"
                            or field.sourcePixel == "active_enemies_raw"
                            or field.sourcePixel == "combat_enemies_raw"
                        )
                        and (
                            (not field.excludeCurrentTarget or (#ids == 2 and field.sourcePixel == "enemies_8yd_raw"))
                            and entry.layout.rows == #ids
                        )
                    )
                ),
            "姓名板缺失字段声明不符"
        )
        entry.ids = ids
        for i = 1, MAX_NAMEPLATES, 1 do
            local mask = field.excludeCurrentTarget and CreateFrame("Frame", nil, frame) or nil
            if mask then
                mask:SetSize(1, 1)
                mask:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            end
            local container = createContainer(entry, mask, "#" .. i)
            container.mask = mask
            if mask then
                container.marker =
                    createInkTexture(entry.cells[2]:GetParent(), frame, entry.layout.row + 1, 0, 6 * i, 0, 1)
                container.marker:SetAlpha(0)
            end
            local function paintCountInk(auraFrame, row, r, g, b)
                local inks = auraFrame.p8ba6426eNameplateCountInks
                if not inks then
                    inks = {}
                    auraFrame.p8ba6426eNameplateCountInks = inks
                end
                local ink = inks[row]
                if not ink then
                    ink = auraFrame:CreateTexture(nil, "OVERLAY")
                    inks[row] = ink
                end
                ink:SetSize(1, 1)
                ink:ClearAllPoints()
                ink:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -row)
                ink:SetBlendMode("ADD")
                ink:SetColorTexture(r / 255, g / 255, b / 255, 1)
            end
            addAuraSlot(entry, container, ids[1], "#a#" .. i, function(auraFrame)
                paintCountInk(auraFrame, entry.layout.row, 0, #ids == 2 and 6 or 0, #ids == 1 and 6 or 0)
            end)
            if #ids == 2 then
                addAuraSlot(entry, container, ids[2], "#b#" .. i, function(auraFrame)
                    paintCountInk(auraFrame, entry.layout.row, 0, 0, 6)
                end)
                container:AddAuraSlot(field.key .. ("#either#" .. i), field.filter or "HARMFUL|PLAYER", {
                    candidateFilters = { includeSpellIDs = { [ids[1]] = true, [ids[2]] = true } },
                    initializeFrame = function(auraFrame)
                        local ok, result = pcall(function()
                            shrinkAuraFrame(auraFrame)
                            paintCountInk(auraFrame, entry.layout.row + 1, 0, 0, 6)
                        end)
                        if not ok then
                            entry.bindError = tostring(result)
                            setEntryError(entry, result)
                        end
                    end,
                })
            end
        end
    end
    local function getAverageCurve(count)
        if curveCache[count] then
            return curveCache[count]
        end
        local base = math.floor(240 / (2 * count)) + 1
        local maxIndex = math.min(254, base ^ 3 - 1)
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        for i = 0, maxIndex, 1 do
            curve:AddPoint(i, rgb255(i % base, math.floor(i / base) % base, math.floor(i / (base * base))))
        end
        curve:AddPoint(maxIndex + 1, rgb255(255, 255, 255))
        curveCache[count] = curve
        return curve
    end
    local function getExpiryCurve(weight, channel)
        local cacheKey = "exp:" .. (weight .. (":" .. channel))
        if curveCache[cacheKey] then
            return curveCache[cacheKey]
        end
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        local unit = weight / 255
        curve:AddPoint(0, rgb255(0, 0, 0))
        curve:AddPoint(1e-009, CreateColor(channel == 1 and 2 * unit or 0, channel == 2 and 2 * unit or 0, 0, 1))
        curve:AddPoint(3, CreateColor(channel == 1 and unit or 0, channel == 2 and unit or 0, 0, 1))
        curveCache[cacheKey] = curve
        return curve
    end
    local function buildTimeEntry(entry)
        local field = entry.field
        local source = countEntriesByKey[field.countSource]
        local spellIDs = field.spellIDs or {}
        local isAverage = field.kind == "presence_nameplate_aura_average"
        assert(
            source
                and (
                    (#spellIDs == 2 or (not isAverage and #spellIDs == 1))
                    and (
                        source.ids[1] == spellIDs[1]
                        and (
                            source.ids[2] == spellIDs[2]
                            and (
                                field.unit == "nameplate"
                                and (
                                    field.sourcePixel == "enemies_8yd_raw"
                                    and (
                                        field.sourcePixel == source.field.sourcePixel
                                        and (
                                            field.filter == source.field.filter
                                            and (
                                                (
                                                    (
                                                        isAverage
                                                        and (
                                                            field.excludeCurrentTarget == true
                                                            and source.field.excludeCurrentTarget == true
                                                        )
                                                    )
                                                    or (
                                                        not isAverage
                                                        and (field.excludeCurrentTarget == true)
                                                            == (source.field.excludeCurrentTarget == true)
                                                    )
                                                )
                                                and entry.layout.rows == (isAverage and 2 or 10)
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                ),
            "姓名板时间字段与计数来源不一致"
        )
        entry.source = source
        for i = 1, MAX_NAMEPLATES, 1 do
            local mask = isAverage and CreateFrame("Frame", nil, frame) or nil
            if mask then
                mask:SetSize(1, 1)
                mask:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            end
            local container = createContainer(entry, mask, "#" .. i)
            container.mask = mask
            local row = isAverage and entry.layout.row or entry.layout.row + math.floor((i - 1) / 4)
            for i2, spellID in ipairs(spellIDs) do
                local curve = isAverage and nil or getExpiryCurve(3 * (3 ^ ((i - 1) % 4)), i2)
                addAuraSlot(entry, container, spellID, "#" .. (i2 .. ("#" .. i)), function(parent)
                    local layers = container.layers and container.layers[i2]
                    local cell = entry.cells[(row - entry.layout.row) + 1]
                    local texture = layers and layers.texture
                        or createInkTexture(cell:GetParent(), frame, row, 0, 0, 0, 1)
                    texture:SetShown(false)
                    local durationBar = parent.p8ba6426eNameplateDurationBar
                    if not durationBar then
                        durationBar = CreateFrame("StatusBar", nil, parent)
                        durationBar:SetAllPoints(parent)
                        durationBar:SetAlpha(0)
                        parent.p8ba6426eNameplateDurationBar = durationBar
                    end
                    parent:SetDurationBar(durationBar)
                    local duration = durationBar:GetTimerDuration()
                    local layer = layers or {}
                    layer.texture, layer.duration, layer.container = texture, duration, container
                    layer.curve, layer.colored = curve, false
                    if not layers then
                        entry.layers[#entry.layers + 1] = layer
                    end
                    container.layers = container.layers or {}
                    container.layers[i2] = layer
                    if isAverage and not parent.p8ba6426eNameplateAverageMarker then
                        parent.p8ba6426eNameplateAverageMarker = createInkTexture(
                            parent,
                            frame,
                            entry.layout.row + 1,
                            i2 == 1 and 6 or 0,
                            i2 == 2 and 6 or 0,
                            0
                        )
                    end
                end)
            end
        end
    end
    for _, spec in ipairs(params.fields or {}) do
        local entry =
            { field = spec.field, layout = spec.layout, containers = {}, layers = {}, cells = {}, invalidUntil = 0 }
        for i = 0, spec.layout.rows - 1, 1 do
            entry.cells[#entry.cells + 1] = params.newCell(spec.layout.row + i, 255, 255, 255)
        end
        allEntries[#allEntries + 1] = entry
        if
            spec.field.kind == "presence_nameplate_missing_count"
            or spec.field.kind == "presence_nameplate_all_absent"
        then
            countEntriesByKey[spec.field.key] = entry
            local ok, result = pcall(buildCountEntry, entry)
            if not ok then
                entry.buildError = tostring(result)
                setEntryError(entry, result)
            end
        else
            timeEntries[#timeEntries + 1] = entry
        end
    end
    for _, entry in ipairs(timeEntries) do
        local ok, result = pcall(buildTimeEntry, entry)
        if not ok then
            entry.buildError = tostring(result)
            setEntryError(entry, result)
        end
    end
    local function refreshTimeEntries(forceUpdate)
        for _, entry in ipairs(timeEntries) do
            runGuarded(entry, function()
                assert(not entry.buildError, entry.buildError)
                local source = entry.source
                local ready = source.ready
                    and (source.snapshotUpdatedAt and GetTime() - source.snapshotUpdatedAt <= 0.35)
                local selected = ready and source.selected or nil
                local bound = bindContainers(entry, selected, forceUpdate)
                local valid = selected and (bound and (not entry.bindError and GetTime() >= entry.invalidUntil))
                local isAverage = entry.field.kind == "presence_nameplate_aura_average"
                local averageCurve = valid and (isAverage and (source.count > 0 and getAverageCurve(source.count)))
                    or nil
                if isAverage and (source.count and (source.count > 0 and not averageCurve)) then
                    valid = false
                end
                if not valid then
                    paintCells(entry, 1, 1, 1)
                    hideEntry(entry)
                    error("姓名板时间来源未知")
                end
                for _, layer in ipairs(entry.layers) do
                    if layer.container.boundUnit then
                        local curve = isAverage and averageCurve or layer.curve
                        local color = layer.duration:EvaluateRemainingDuration(curve)
                        layer.texture:SetColorTexture(color:GetRGB())
                        layer.colored = true
                        if isAverage then
                            local isUnit = UnitIsUnit(layer.container.boundUnit, "target")
                            layer.container.mask:SetAlphaFromBoolean(isUnit, 0, 255)
                            layer.texture:SetAlphaFromBoolean(isUnit, 0, 255)
                        end
                    elseif layer.colored then
                        layer.texture:SetColorTexture(0, 0, 0, 1)
                        layer.colored = false
                    end
                end
                paintCells(entry, 0, 0, 0)
                showLayers(entry, true)
            end)
        end
    end
    function producer.RefreshVisuals()
        if not active or #timeEntries == 0 then
            return false
        end
        for _, entry in pairs(countEntriesByKey) do
            if entry.ready then
                runGuarded(entry, function()
                    updateTargetMask(entry)
                end, ":targetMask")
            end
        end
        refreshTimeEntries(false)
        return true
    end
    function producer.MarkRefreshError(stage, err)
        for _, entry in ipairs(allEntries) do
            setEntryError(entry, err, ":" .. stage)
        end
    end
    function producer.Refresh(forceUpdate)
        if not active then
            return true
        end
        local ok, snapshot = pcall(P8BA6426E.GetEnemyCountSnapshot)
        if not ok then
            snapshot = nil
        end
        for _, entry in pairs(countEntriesByKey) do
            runGuarded(entry, function()
                assert(not entry.buildError, entry.buildError)
                local selected, count = selectUnits(entry, snapshot)
                local bound = bindContainers(entry, selected, forceUpdate)
                local valid = selected and (bound and (not entry.bindError and GetTime() >= entry.invalidUntil))
                entry.ready = valid and true or false
                entry.selected = entry.ready and selected or nil
                entry.count = entry.ready and count or nil
                entry.snapshotUpdatedAt = entry.ready and snapshot.updatedAt or nil
                if entry.ready then
                    paintCells(entry, count / 255, 0, 0)
                    updateTargetMask(entry)
                else
                    paintCells(entry, 0, 1, 0)
                    hideEntry(entry)
                    error("姓名板数量快照或原生光环绑定未知")
                end
            end)
        end
        refreshTimeEntries(forceUpdate)
        return true
    end
    function producer.Enable()
        active = true
        for _, entry in ipairs(allEntries) do
            runGuarded(entry, function()
                for _, container in ipairs(entry.containers) do
                    container:SetEnabled(true)
                end
            end)
        end
        producer.Refresh(true)
        return true
    end
    function producer.Disable()
        active = false
        for _, entry in ipairs(allEntries) do
            runGuarded(entry, function()
                hideEntry(entry)
                for _, container in ipairs(entry.containers) do
                    container:SetEnabled(false)
                end
            end)
        end
    end
    return producer
end
