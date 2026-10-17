--[[
  FontPixelRoute —— 像素路由（核心协议）：按专精构建像素条带、写入头部/心跳/时间轴、驱动各生产器刷新
  原始文件：2e962d.lua（TOC 第 22 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local addonName = ...
local fontPixelRoute = { enabled = false, invalid = false, lastError = nil }
P8BA6426E.FontPixelRoute = fontPixelRoute
-- 像素条带头部 8 行：0-2 魔数色(19,227,149)(241,173,37)(61,109,211)、3 尺寸头、4 布局摘要、5 字段计数、6 心跳、7 激活标志
local HEADER_ROWS = 8
local surfacesBySpec = {}
local activeSurface, workerFrame
local heartbeatCounter, refreshAccumulator = 0, 0
local startFailureReported = {}
local buildingSpecs = {}
local retrySpecID, retryAccumulator = nil, 0
local fontPixelGeometry = assert(P8BA6426E.FontPixelGeometry)
local geometryPollAccumulator, geometryRefreshScheduled = 0, false
local function getCurrentSpecID()
    local specializationAPI = P8BA6426E.SpecializationAPI
    local specIndex = specializationAPI.GetSpecialization and specializationAPI.GetSpecialization()
    return specIndex
            and (specIndex > 0 and (specializationAPI.GetSpecializationInfo and specializationAPI.GetSpecializationInfo(
                specIndex
            )))
        or nil
end
local function getContractForSpec(specID)
    local contract = P8BA6426E.FontPixelContracts and P8BA6426E.FontPixelContracts[specID]
    if contract and (contract.flavor or "retail") == (P8BA6426E.flavor or "retail") then
        return contract
    end
end
local function getTimelineRowCount(contract)
    return contract.timelineRows or 8
end
local function getAnchorOffset()
    local offset = P8BA6426E.DB and P8BA6426E.DB.pixelAnchorOffset
    if type(offset) ~= "table" then
        return 0, 0
    end
    local x, y = offset[1], offset[2]
    if type(x) ~= "number" or type(y) ~= "number" then
        return 0, 0
    end
    return x, y
end
local function getPixelCellSize()
    return P8BA6426E.DB and (P8BA6426E.DB.pixelCellSize == 1 and 1) or 4
end
local function setCellRGB(cell, r, g, b)
    return cell:SetTextColor(r / 255, g / 255, b / 255, 1)
end
local function writeTimelineWord(cell, value)
    assert(type(value) == "number" and (value % 1 == 0 and (value >= 0 and value <= 16777215)), "时间轴字段越界")
    assert(
        setCellRGB(cell, math.floor(value / 65536) % 256, math.floor(value / 256) % 256, value % 256) ~= false,
        "时间轴纹理写入失败"
    )
end
local function flushReceipts(surface)
    if surface.pixel.FlushReceipts() then
        return true
    end
    if surface.active then
        setCellRGB(surface.active, 0, 0, 0)
    end
    return false
end
local logicDiagnostics = P8BA6426E.LogicDiagnostics
local function recordRenderFault(stage, category)
    if logicDiagnostics and type(logicDiagnostics.RecordRenderFault) == "function" then
        pcall(logicDiagnostics.RecordRenderFault, stage, category)
    end
end
local function recordRenderRecovery(stage, category)
    if logicDiagnostics and type(logicDiagnostics.RecordRenderRecovery) == "function" then
        pcall(logicDiagnostics.RecordRenderRecovery, stage, category)
    end
end
local function newGlyph(surface, parent, offsetY)
    return surface.pixel.NewGlyph(parent, offsetY)
end
local function newCell(surface, row, r, g, b, parent)
    return surface.pixel.NewCell(row, r, g, b, parent)
end
local function encodeSizeHeader(contract, pixelSize)
    if contract.protocol == 7 and contract.height <= 255 then
        return 7, pixelSize, contract.height
    end
    if
        contract.protocol == 8 and (contract.height > 255 and (contract.height <= 512 and contract.flavor == "forever"))
    then
        return 8, contract.height % 256, math.floor(contract.height / 256)
    end
    error("单像素头部版本或高度无效")
end
local function writeSizeHeader(surface, pixelSize)
    local r, g, b = encodeSizeHeader(surface.contract, pixelSize)
    return surface.sizeHeader:SetTextColor(r / 255, g / 255, b / 255, 1)
end
-- 校验合同布局：各字段物理行不重叠、无空洞、五个分组顺序正确、回执区位于尾部
local function validateLayout(contract)
    encodeSizeHeader(contract, 1)
    local timelineRows = getTimelineRowCount(contract)
    assert(timelineRows == 0 or timelineRows == 8, "时间轴行数无效")
    assert(
        type(contract.receiptStart) == "number"
            and (
                type(contract.receiptWordCount) == "number"
                and (
                    contract.receiptWordCount == math.ceil(contract.receiptStart / 24)
                    and (
                        contract.receiptCount == contract.receiptWordCount + 1
                        and contract.receiptStart + contract.receiptCount == contract.height - 2
                    )
                )
            ),
        "故障回执行与尾部布局不一致"
    )
    local usedRows = {}
    local function claimRows(startRow, count)
        for i = startRow, (startRow + count) - 1, 1 do
            assert(
                type(i) == "number"
                    and (i % 1 == 0 and (i >= HEADER_ROWS and (i < contract.receiptStart and not usedRows[i]))),
                "单像素字段物理行重叠或越界"
            )
            usedRows[i] = true
        end
    end
    assert(
        #contract.classicRows == #contract.classicKeys and #contract.presenceRows == contract.presenceCount,
        "单像素原序与物理行映射不一致"
    )
    local classicPhysical = 0
    for _, classicRow in ipairs(contract.classicRows) do
        if classicRow >= 0 then
            claimRows(classicRow, 1)
            classicPhysical = classicPhysical + 1
        end
    end
    assert(classicPhysical == contract.classicPhysicalCount, "经典业务键与实际物理格数量不一致")
    for _, presenceField in ipairs(contract.presenceFields) do
        claimRows(presenceField.row, presenceField.rows)
    end
    for _, textField in ipairs(contract.textFields) do
        assert(textField.rows == 1 or textField.rows == 2, "数字字段物理行数无效")
        claimRows(textField.row, textField.rows)
    end
    for _, internalField in ipairs(contract.internalFields or {}) do
        claimRows(internalField.row, 1)
    end
    local mappedClassic = {}
    for _, nativeField in ipairs(contract.nativeFields or {}) do
        local classicIndex = assert(nativeField.classicIndex) + 1
        assert(
            contract.classicKeys[classicIndex] == nativeField.field.key
                and (contract.classicRows[classicIndex] == nativeField.row and not mappedClassic[classicIndex]),
            "原生冷却与经典字段映射不一致"
        )
        mappedClassic[classicIndex] = true
    end
    for _, chargeField in ipairs(contract.chargeFields or {}) do
        if chargeField.classicIndex then
            local classicIndex = chargeField.classicIndex + 1
            assert(
                contract.classicKeys[classicIndex] == chargeField.field.ruleKey:sub(7)
                    and contract.classicRows[classicIndex] == chargeField.row,
                "原生充能与经典字段映射不一致"
            )
        end
    end
    claimRows(contract.timelineRow, timelineRows)
    for i = HEADER_ROWS, contract.receiptStart - 1, 1 do
        assert(usedRows[i], "单像素字段布局存在空洞")
    end
    local GROUP_ORDER = { "common", "exclusive", "skill", "aura", "timeline" }
    local nextRow = HEADER_ROWS
    assert(#contract.groups == #GROUP_ORDER, "单像素五组布局不完整")
    for i, groupKey in ipairs(GROUP_ORDER) do
        local group = contract.groups[i]
        assert(group.key == groupKey and group.row == nextRow, "单像素字段组顺序不一致")
        nextRow = nextRow + group.rows
    end
    assert(
        nextRow == contract.receiptStart
            and (contract.groups[5].row == contract.timelineRow and contract.groups[5].rows == timelineRows),
        "单像素时间轴段不一致"
    )
end
local function setProducerError(surface, producerName, err)
    for row in pairs(surface[producerName .. "Rows"]) do
        surface.pixel.SetFieldError(row, producerName .. ":producer", err)
    end
end
-- 根据屏幕物理尺寸与 UI 缩放设置条带缩放和锚点，保证每个色块正好对应 pixelSize×pixelSize 个物理像素
local function applyGeometry(surface, reason, force, snapshot, pixelSizeOverride)
    snapshot = snapshot or fontPixelGeometry.Read()
    local anchorX, anchorY = getAnchorOffset()
    local geometry = surface.geometry
    local pixelSize = pixelSizeOverride or getPixelCellSize()
    if surface.contract.flavor == "forever" then
        pixelSize = fontPixelGeometry.EffectivePixelSize(surface.contract.height, pixelSize, snapshot, anchorY)
    end
    snapshot.pixelSize = pixelSize
    if
        not force
        and (
            not fontPixelGeometry.Changed(geometry, snapshot)
            and (geometry.anchorX == anchorX and geometry.anchorY == anchorY)
        )
    then
        return false
    end
    surface.pixelSize = pixelSize
    if surface.sizeHeader then
        assert(writeSizeHeader(surface, pixelSize), "像素格尺寸头部写入失败")
    end
    local scale = snapshot.unit * surface.pixelSize
    surface.frame:SetScale(scale)
    surface.frame:ClearAllPoints()
    surface.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", anchorX / scale, anchorY / scale)
    snapshot.anchorX, snapshot.anchorY = anchorX, anchorY
    surface.geometry = fontPixelGeometry.Commit(snapshot, geometry, reason or "build")
    if surface.numeric and surface.numeric.Rescale then
        surface.numeric.Rescale()
    end
    return true
end
local function refreshGeometry(reason, force)
    if not fontPixelRoute.enabled or not activeSurface then
        return
    end
    local ok, result = pcall(function()
        local numericGeometryError = activeSurface.numeric
            and (activeSurface.numeric.HasGeometryError and activeSurface.numeric.HasGeometryError())
        applyGeometry(activeSurface, reason, force or fontPixelRoute.geometryError ~= nil or numericGeometryError)
    end)
    if not ok then
        fontPixelRoute.geometryError = tostring(result)
        fontPixelRoute.lastError = fontPixelRoute.geometryError
        setCellRGB(activeSurface.active, 0, 0, 0)
        recordRenderFault("route.geometry", "exception")
    else
        if fontPixelRoute.lastError == fontPixelRoute.geometryError then
            fontPixelRoute.lastError = nil
        end
        if fontPixelRoute.geometryError ~= nil then
            recordRenderRecovery("route.geometry", "exception")
        end
        fontPixelRoute.geometryError = nil
    end
    flushReceipts(activeSurface)
end
local function refreshGeometrySoon(reason)
    refreshGeometry(reason, true)
    if geometryRefreshScheduled then
        return
    end
    geometryRefreshScheduled = true
    C_Timer.After(0, function()
        geometryRefreshScheduled = false
        refreshGeometry("deferred", true)
    end)
end
-- 为某专精构建完整的像素条带：头部、经典标量行、时间轴行、尾部标记，以及数字/就绪/存在三个生产器
local function buildSurface(specID, contract)
    assert(
        type(contract.height) == "number"
            and (contract.height <= 512 and contract.height > (HEADER_ROWS + getTimelineRowCount(contract)) + 2),
        "单像素条带高度无效"
    )
    local classicCount = #assert(contract.classicKeys)
    local textCount = #assert(contract.textFields)
    assert(
        contract.classicCount == classicCount and contract.textCount == textCount,
        "单像素字段数量与声明不一致"
    )
    assert(#assert(contract.scalarRecords) == classicCount, "标量生产器记录与业务声明不一致")
    assert(
        classicCount < 256 and (contract.presenceCount < 256 and textCount < 256),
        "单像素字段数量超过头部字节"
    )
    validateLayout(contract)
    assert(
        type(contract.wireLayoutID) == "string" and contract.wireLayoutID:match("^%x%x%x%x%x%x$"),
        "单像素布局摘要无效"
    )
    local snapshot = fontPixelGeometry.Read()
    buildingSpecs[specID] = true
    local stripFrame = CreateFrame("Frame", nil, UIParent)
    stripFrame:Hide()
    stripFrame:SetSize(1, contract.height)
    stripFrame:SetFrameStrata("TOOLTIP")
    stripFrame:SetFrameLevel(9900)
    stripFrame:SetIgnoreParentAlpha(true)
    stripFrame:SetAlpha(1)
    stripFrame:EnableMouse(false)
    local surface = {
        frame = stripFrame,
        contract = contract,
        pixelSize = getPixelCellSize(),
        specID = specID,
        timeline = {},
        classic = {},
    }
    surface.pixel = P8BA6426E.CreatePixelSurface({
        frame = stripFrame,
        height = contract.height,
        receiptStart = contract.receiptStart,
        receiptWordCount = contract.receiptWordCount,
        receiptCount = contract.receiptCount,
        addonName = addonName,
        fontName = "P8BA6426EFontPixelColor" .. specID,
    })
    surface.numericRows, surface.readinessRows, surface.auraRows = {}, {}, {}
    local function markRows(rowSet, field)
        for i = field.row, (field.row + (field.rows or 1)) - 1, 1 do
            rowSet[i] = true
        end
    end
    for _, nativeField in ipairs(contract.nativeFields or {}) do
        markRows(surface.numericRows, nativeField)
    end
    for _, chargeField in ipairs(contract.chargeFields or {}) do
        markRows(surface.numericRows, chargeField)
    end
    for _, textField in ipairs(contract.textFields or {}) do
        markRows(surface.numericRows, textField)
    end
    for _, presenceField in ipairs(contract.presenceFields or {}) do
        markRows(surface.auraRows, presenceField)
    end
    for _, bindingField in ipairs(contract.bindingFields or {}) do
        if bindingField.kind == "dispel_presence" and bindingField.rowRef then
            for i, classicKey in ipairs(contract.classicKeys or {}) do
                if classicKey == bindingField.rowRef and contract.classicRows[i] >= 0 then
                    surface.auraRows[contract.classicRows[i]] = true
                end
            end
        end
    end
    if P8BA6426E.IsPixelNativeAbsorbSpec(specID) then
        for i, classicKey in ipairs(contract.classicKeys or {}) do
            if
                (
                    classicKey == "player_health_pct"
                    or classicKey == "mouseover_health_pct"
                    or classicKey:match("^party[1-4]_health_pct$")
                ) and contract.classicRows[i] >= 0
            then
                surface.auraRows[contract.classicRows[i]] = true
            end
        end
    end
    for _, internalField in ipairs(contract.internalFields or {}) do
        if internalField.kind == "ready_base" then
            markRows(surface.readinessRows, internalField)
        elseif internalField.kind == "cd_seconds" then
            markRows(surface.numericRows, internalField)
        end
    end
    applyGeometry(surface, "build", true, snapshot)
    newCell(surface, 0, 19, 227, 149)
    newCell(surface, 1, 241, 173, 37)
    newCell(surface, 2, 61, 109, 211)
    local headerR, headerG, headerB = encodeSizeHeader(contract, surface.pixelSize)
    surface.sizeHeader = newCell(surface, 3, headerR, headerG, headerB)
    local wireLayoutID = contract.wireLayoutID
    newCell(
        surface,
        4,
        tonumber(wireLayoutID:sub(1, 2), 16),
        tonumber(wireLayoutID:sub(3, 4), 16),
        tonumber(wireLayoutID:sub(5, 6), 16)
    )
    newCell(surface, 5, classicCount, contract.presenceCount, textCount)
    surface.heartbeat = newCell(surface, 6, 0, 0, contract.heartbeatMarker or 127)
    surface.active = newCell(surface, 7, 0, 0, 0)
    local NON_CLASSIC_KEYS = {
        team_avg_health = true,
        mouseover_npc_state = true,
        player_health_pct = true,
        mouseover_health_pct = true,
        focus_is_player = true,
        party_tank_index = true,
    }
    surface.nativeClassic = {}
    surface.nativeCooldownKeys = {}
    for _, nativeField in ipairs(contract.nativeFields or {}) do
        surface.nativeClassic[nativeField.classicIndex + 1] = true
        surface.nativeCooldownKeys[nativeField.field.key] = true
    end
    for _, chargeField in ipairs(contract.chargeFields or {}) do
        if chargeField.classicIndex then
            surface.nativeClassic[chargeField.classicIndex + 1] = true
        end
    end
    for i, classicKey in ipairs(contract.classicKeys) do
        local handledElsewhere = NON_CLASSIC_KEYS[classicKey]
            or classicKey:match("^party%d_health_pct$")
            or classicKey:match("^raid_health_%d%d$")
            or (classicKey == "master_switch" and (P8BA6426E.IsHealingSpec and P8BA6426E.IsHealingSpec()))
        if contract.classicRows[i] >= 0 and (not handledElsewhere and not surface.nativeClassic[i]) then
            surface.classic[i] = newCell(surface, contract.classicRows[i], 0, 0, 0)
        end
    end
    for i = 1, getTimelineRowCount(contract), 1 do
        surface.timeline[i] = newCell(surface, (contract.timelineRow + i) - 1, 0, 0, 0)
    end
    newCell(surface, contract.height - 2, 32, 96, 224)
    newCell(surface, contract.height - 1, 61, 109, 211)
    local numericParams = {
        frame = stripFrame,
        contract = contract,
        specID = specID,
        addonName = addonName,
        newCell = function(row, r, g, b)
            return newCell(surface, row, r, g, b)
        end,
        newGlyph = function(parent, offsetY)
            return newGlyph(surface, parent, offsetY)
        end,
        onFieldError = function(row, key, err)
            surface.pixel.SetFieldError(row, key, err)
        end,
    }
    local readinessParams = {
        frame = stripFrame,
        contract = contract,
        specID = specID,
        newCell = function(row, r, g, b)
            return newCell(surface, row, r, g, b)
        end,
        newGlyph = function(parent, offsetY)
            return newGlyph(surface, parent, offsetY)
        end,
        onFieldError = function(row, key, err)
            surface.pixel.SetFieldError(row, key, err)
        end,
    }
    local ok, producer = pcall(P8BA6426E.CreateFontPixelNumericProducer, numericParams)
    surface.numeric = ok and producer or nil
    if not surface.numeric then
        surface.numericError = tostring(producer)
        setProducerError(surface, "numeric", surface.numericError)
    end
    local ok, producer = pcall(P8BA6426E.CreateFontPixelReadinessProducer, readinessParams)
    surface.readiness = ok and producer or nil
    if not surface.readiness then
        surface.readinessError = tostring(producer)
        setProducerError(surface, "readiness", surface.readinessError)
    end
    local ok, producer = pcall(P8BA6426E.CreatePixelNativePresenceProducer, {
        frame = stripFrame,
        contract = contract,
        specID = specID,
        newCell = numericParams.newCell,
        newGlyph = numericParams.newGlyph,
        onFieldError = numericParams.onFieldError,
    })
    surface.aura = ok and producer or nil
    if not surface.aura then
        surface.auraError = tostring(producer)
        setProducerError(surface, "aura", surface.auraError)
    end
    flushReceipts(surface)
    buildingSpecs[specID] = nil
    return surface
end
local function refreshVisibility()
    for _, surface in pairs(surfacesBySpec) do
        surface.frame:SetShown(fontPixelRoute.enabled and activeSurface == surface)
    end
end
fontPixelRoute.RefreshVisibility = refreshVisibility
local function refreshAll()
    if P8BA6426E.RebuildPixelBars then
        P8BA6426E.RebuildPixelBars()
    end
    if P8BA6426E.RefreshAllOverlayVisibility then
        P8BA6426E.RefreshAllOverlayVisibility()
    end
    refreshVisibility()
end
function fontPixelRoute.IsActive()
    return fontPixelRoute.enabled and activeSurface ~= nil
end
function fontPixelRoute.GetScalarContract()
    return fontPixelRoute.IsActive() and activeSurface.contract or nil
end
function fontPixelRoute.GetSurfaceFrame()
    return fontPixelRoute.IsActive() and activeSurface.frame or nil
end
function fontPixelRoute.GetGeometry()
    if not fontPixelRoute.IsActive() then
        return nil
    end
    local contract = activeSurface.contract
    local geometry = assert(activeSurface.geometry)
    local physicalUnit = geometry.unit * geometry.pixelSize
    local anchorX, anchorY = geometry.anchorX, geometry.anchorY
    return {
        specID = activeSurface.specID,
        classicCount = contract.classicCount,
        classicPhysicalCount = contract.classicPhysicalCount,
        parentScale = physicalUnit / 4,
        physicalUnit = physicalUnit,
        pixelSize = geometry.pixelSize,
        physicalHeight = contract.height * geometry.pixelSize,
        anchorX = anchorX,
        anchorY = anchorY,
        classicRow = contract.classicRow,
        presenceRow = contract.presenceRow,
        timelineRow = contract.timelineRow,
        textRow = contract.textRow,
        receiptStart = contract.receiptStart,
        receiptWordCount = contract.receiptWordCount,
        receiptCount = contract.receiptCount,
        height = contract.height,
        wireLayoutID = contract.wireLayoutID,
        nativeRows = activeSurface.nativeRows,
    }
end
function fontPixelRoute.GetPixelSize()
    return getPixelCellSize()
end
function fontPixelRoute.SetPixelSize(size)
    if size ~= 1 and size ~= 4 then
        return false, "像素格尺寸无效"
    end
    if InCombatLockdown() then
        return false, "请脱战后切换显示模式"
    end
    if getPixelCellSize() == size then
        return true
    end
    if not activeSurface then
        P8BA6426E.DB.pixelCellSize = size
        return true
    end
    local surface, previousSize = activeSurface, activeSurface.pixelSize
    setCellRGB(surface.active, 0, 0, 0)
    local ok, result = pcall(function()
        applyGeometry(surface, "pixel_size", true, nil, size)
    end)
    if not ok then
        surface.pixelSize = previousSize
        local ok, headerOk = pcall(writeSizeHeader, surface, previousSize)
        local rollbackOk = pcall(applyGeometry, surface, "pixel_size_rollback", true)
        if not ok or not headerOk or not rollbackOk then
            fontPixelRoute.geometryError = tostring(result)
        end
        fontPixelRoute.lastError = tostring(result)
        return false, "像素格尺寸切换失败"
    end
    P8BA6426E.DB.pixelCellSize = size
    fontPixelRoute.geometryError = nil
    flushReceipts(surface)
    return true
end
function fontPixelRoute.GetBindingFields()
    return fontPixelRoute.IsActive() and activeSurface.contract.bindingFields or nil
end
function fontPixelRoute.GetGeometrySnapshot()
    return fontPixelRoute.IsActive() and activeSurface.geometry or nil
end
function fontPixelRoute.UsesClassicFont(classicIndex)
    return fontPixelRoute.IsActive()
        and (activeSurface.classic[classicIndex] ~= nil or activeSurface.nativeClassic[classicIndex] == true)
end
function P8BA6426E.IsNativeClassicCooldownField(key)
    return fontPixelRoute.IsActive() and activeSurface.nativeCooldownKeys[key] == true or false
end
-- 写入一个经典标量字段的颜色（充能字段交给数字生产器处理）
function fontPixelRoute.RenderClassicColor(classicIndex, r, g, b)
    if not fontPixelRoute.IsActive() then
        return
    end
    local classicRow = activeSurface.contract.classicRows[classicIndex]
    if not classicRow or classicRow < 0 then
        return
    end
    if activeSurface.numeric and activeSurface.numeric.UpdateClassicCharge then
        local ok, handled = pcall(activeSurface.numeric.UpdateClassicCharge, classicIndex, r, g, b)
        if not ok then
            activeSurface.pixel.SetFieldError(classicRow, "classic:" .. classicIndex, handled)
            return
        end
        if handled then
            activeSurface.pixel.SetFieldError(classicRow, "classic:" .. classicIndex, nil)
            return
        end
    end
    local cell = activeSurface.classic[classicIndex]
    if cell then
        activeSurface.pixel.Run(classicRow, "classic:" .. classicIndex, function()
            cell:SetTextColor(r, g, b, 1)
        end)
    end
end
function fontPixelRoute.RunClassicField(classicIndex, fn, ...)
    if not fontPixelRoute.IsActive() then
        return fn(...)
    end
    local classicRow = activeSurface.contract.classicRows[classicIndex]
    local ok, result = pcall(fn, ...)
    if not ok then
        local classicKey = activeSurface.contract.classicKeys and activeSurface.contract.classicKeys[classicIndex]
        if classicKey then
            local faultRecorder = P8BA6426E.RecordSecretApiFault
            if type(faultRecorder) == "function" then
                pcall(faultRecorder, "classic:" .. classicKey, result)
            end
        end
    end
    if classicRow and classicRow >= 0 then
        activeSurface.pixel.SetFieldError(classicRow, "classic_source", not ok and result or nil)
    end
    return ok, result
end
function fontPixelRoute.Stop()
    local previous = activeSurface
    retrySpecID, retryAccumulator = nil, 0
    fontPixelRoute.enabled = false
    activeSurface = nil
    fontPixelRoute.invalid = false
    fontPixelRoute.geometryError = nil
    if previous then
        if previous.numeric then
            pcall(previous.numeric.Disable)
        end
        if previous.readiness then
            pcall(previous.readiness.Disable)
        end
        if previous.aura then
            pcall(previous.aura.Disable)
        end
        previous.frame:Hide()
    end
    refreshAll()
end
local function start(specID)
    if InCombatLockdown() then
        return false, "请脱战后切换显示模式"
    end
    local contract = getContractForSpec(specID)
    if not contract then
        return false, "当前专精没有单像素字段声明"
    end
    if buildingSpecs[specID] then
        fontPixelRoute.lastError = buildingSpecs[specID]
        return false, "试验启动失败"
    end
    local ok, builtOrErr = pcall(function()
        local surface = surfacesBySpec[specID]
        if not surface then
            surface = buildSurface(specID, contract)
            surfacesBySpec[specID] = surface
        end
        applyGeometry(surface, "start", true)
        if surface.numeric then
            local ok, enabled, reason = pcall(surface.numeric.Enable)
            local err
            if not ok then
                err = enabled
            elseif not enabled then
                err = reason or "数字生产器启用失败"
            end
            setProducerError(surface, "numeric", err)
        end
        if surface.readiness then
            local ok, enabled, reason = pcall(surface.readiness.Enable)
            local err
            if not ok then
                err = enabled
            elseif not enabled then
                err = reason or "技能前置生产器启用失败"
            end
            setProducerError(surface, "readiness", err)
        end
        if surface.aura then
            local ok, enabled, reason = pcall(surface.aura.Enable)
            local err
            if not ok then
                err = enabled
            elseif not enabled then
                err = reason or "原生存在生产器启用失败"
            end
            setProducerError(surface, "aura", err)
        end
        flushReceipts(surface)
        return surface
    end)
    if not ok then
        fontPixelRoute.lastError = builtOrErr
        recordRenderFault("route.start", "build_failed")
        if buildingSpecs[specID] then
            buildingSpecs[specID] = builtOrErr
            retrySpecID = nil
        else
            retrySpecID, retryAccumulator = specID, 0
        end
        return false, "试验启动失败"
    end
    if activeSurface and activeSurface ~= builtOrErr then
        if activeSurface.numeric then
            pcall(activeSurface.numeric.Disable)
        end
        if activeSurface.readiness then
            pcall(activeSurface.readiness.Disable)
        end
        if activeSurface.aura then
            pcall(activeSurface.aura.Disable)
        end
        activeSurface.frame:Hide()
    end
    activeSurface = builtOrErr
    activeSurface.nativeRows = {}
    for _, classicRow in ipairs(activeSurface.contract.classicRows) do
        activeSurface.nativeRows[#activeSurface.nativeRows + 1] = classicRow
    end
    for _, presenceRow in ipairs(activeSurface.contract.presenceRows) do
        activeSurface.nativeRows[#activeSurface.nativeRows + 1] = presenceRow
    end
    fontPixelRoute.enabled = true
    fontPixelRoute.invalid = false
    fontPixelRoute.lastError = nil
    fontPixelRoute.geometryError = nil
    retrySpecID, retryAccumulator = nil, 0
    heartbeatCounter = 0
    setCellRGB(activeSurface.active, 0, 0, 0)
    refreshAll()
    recordRenderRecovery("route.start", "build_failed")
    if logicDiagnostics and type(logicDiagnostics.OnSurfaceBuilt) == "function" then
        pcall(logicDiagnostics.SetModuleName, activeSurface.contract.moduleName)
        pcall(logicDiagnostics.OnSurfaceBuilt, activeSurface)
    end
    return true
end
function fontPixelRoute.CurrentSurface()
    return activeSurface
end
fontPixelRoute.Start = start
-- 每帧结束：先清激活位、刷新回执，全部成功后写激活位=白并递增心跳计数——外部程序据此判断本帧数据完整
function fontPixelRoute.OnClassicFrame()
    if not fontPixelRoute.IsActive() then
        return
    end
    local invalid = fontPixelRoute.invalid or fontPixelRoute.geometryError ~= nil
    local painted = setCellRGB(activeSurface.active, 0, 0, 0) ~= false
    if activeSurface.pixel.errors[6] then
        painted = setCellRGB(
            activeSurface.heartbeat,
            heartbeatCounter % 256,
            math.floor(heartbeatCounter / 256),
            activeSurface.contract.heartbeatMarker or 127
        ) ~= false and painted
    end
    if invalid then
        recordRenderFault("route.frame", "geometry_unavailable")
    end
    if not painted then
        recordRenderFault("route.frame", "control_paint_failed")
    end
    local flushed = flushReceipts(activeSurface)
    if not flushed then
        recordRenderFault("route.frame", "receipt_flush_failed")
    end
    if not flushed or invalid or not painted then
        return
    end
    if setCellRGB(activeSurface.active, 255, 255, 255) == false then
        setCellRGB(activeSurface.active, 0, 0, 0)
        flushReceipts(activeSurface)
        return
    end
    local nextCounter = (heartbeatCounter + 1) % 65536
    if
        setCellRGB(
            activeSurface.heartbeat,
            nextCounter % 256,
            math.floor(nextCounter / 256),
            activeSurface.contract.heartbeatMarker or 127
        ) == false
    then
        setCellRGB(activeSurface.active, 0, 0, 0)
        flushReceipts(activeSurface)
        return
    end
    heartbeatCounter = nextCounter
end
-- 写一条时间轴记录：先把第 2 行清零（作废），写完其余字后再写入序号，保证读取方不会读到半条记录
function fontPixelRoute.RenderTimelineRecord(
    magic,
    sequence,
    encounterScope,
    generation,
    eventID,
    mechanicWord,
    stateWord
)
    if not fontPixelRoute.IsActive() or getTimelineRowCount(activeSurface.contract) == 0 then
        return
    end
    local function writeRow(index, value)
        local row = (activeSurface.contract.timelineRow + index) - 1
        activeSurface.pixel.Run(row, "timeline:" .. index, function()
            writeTimelineWord(activeSurface.timeline[index], value)
        end)
    end
    writeRow(2, 0)
    writeRow(1, magic)
    writeRow(3, encounterScope)
    writeRow(4, generation)
    writeRow(5, eventID)
    writeRow(6, mechanicWord)
    writeRow(7, stateWord)
    writeRow(8, sequence)
    writeRow(2, sequence)
    flushReceipts(activeSurface)
end
function fontPixelRoute.InvalidateTimelineRecord()
    if fontPixelRoute.IsActive() and getTimelineRowCount(activeSurface.contract) > 0 then
        local row = activeSurface.contract.timelineRow + 1
        activeSurface.pixel.Run(row, "timeline:2", function()
            writeTimelineWord(activeSurface.timeline[2], 0)
        end)
        flushReceipts(activeSurface)
    end
end
function fontPixelRoute.OnSpecChanged()
    local specID = getCurrentSpecID()
    if specID and (retrySpecID and specID ~= retrySpecID) then
        retrySpecID, retryAccumulator = nil, 0
    end
    if fontPixelRoute.IsActive() and activeSurface.specID ~= specID then
        fontPixelRoute.Stop()
    end
    if not specID or InCombatLockdown() then
        return
    end
    if fontPixelRoute.IsActive() then
        return
    end
    if getContractForSpec(specID) then
        local started, reason = start(specID)
        if not started then
            if not startFailureReported[specID] then
                startFailureReported[specID] = true
                print(P8BA6426E.L("像素路线：") .. P8BA6426E.L(reason))
                if fontPixelRoute.lastError then
                    print(fontPixelRoute.lastError)
                end
            end
        else
            startFailureReported[specID] = nil
        end
    end
end
function P8BA6426E.OnEnemyCountSnapshotUpdated(force)
    if not fontPixelRoute.IsActive() or not activeSurface.aura or not activeSurface.aura.nameplates then
        return
    end
    local nameplates = activeSurface.aura.nameplates
    local ok, result = pcall(nameplates.Refresh, force == true)
    nameplates.MarkRefreshError("snapshot", not ok and result or nil)
    flushReceipts(activeSurface)
end
workerFrame = CreateFrame("Frame")
-- 工作循环：每 0.25 秒检查几何变化；每 0.02 秒刷新数字/就绪/存在生产器
workerFrame:SetScript("OnUpdate", function(_, elapsed)
    if not fontPixelRoute.IsActive() then
        if retrySpecID then
            retryAccumulator = retryAccumulator + elapsed
            if retryAccumulator >= 1 then
                retryAccumulator = 0
                fontPixelRoute.OnSpecChanged()
            end
        end
        return
    end
    geometryPollAccumulator = geometryPollAccumulator + elapsed
    if geometryPollAccumulator >= 0.25 then
        geometryPollAccumulator = geometryPollAccumulator % 0.25
        refreshGeometry("poll", false)
    end
    if activeSurface.aura and activeSurface.aura.nameplates then
        local nameplates = activeSurface.aura.nameplates
        local ok, result = pcall(nameplates.RefreshVisuals)
        nameplates.MarkRefreshError("visual", not ok and result or nil)
        if not ok or result then
            flushReceipts(activeSurface)
        end
    end
    refreshAccumulator = refreshAccumulator + elapsed
    if refreshAccumulator < 0.02 then
        return
    end
    refreshAccumulator = refreshAccumulator % 0.02
    if activeSurface.numeric then
        local ok, result = pcall(activeSurface.numeric.Refresh)
        local err
        if not ok then
            err = result
        elseif not result then
            err = "数字字段刷新失败"
        end
        setProducerError(activeSurface, "numeric", err)
    end
    if activeSurface.readiness then
        local ok, result = pcall(activeSurface.readiness.Refresh)
        local err
        if not ok then
            err = result
        elseif not result then
            err = "技能前置刷新失败"
        end
        setProducerError(activeSurface, "readiness", err)
    end
    if activeSurface.aura then
        local ok, result = pcall(activeSurface.aura.Refresh, false)
        local err
        if not ok then
            err = result
        elseif not result then
            err = "原生存在字段刷新失败"
        end
        setProducerError(activeSurface, "aura", err)
    end
    flushReceipts(activeSurface)
end)
for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_REGEN_ENABLED",
    "GROUP_ROSTER_UPDATE",
    "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED",
}) do
    P8BA6426E.SafeRegisterEvent(workerFrame, event)
end
local specCheckScheduled = false
workerFrame:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        if fontPixelRoute.IsActive() and activeSurface.aura then
            local ok, result = pcall(activeSurface.aura.RefreshGroupCounts, true)
            activeSurface.aura.MarkGroupRefreshError("roster", not ok and result or nil)
            flushReceipts(activeSurface)
        end
        return
    end
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        refreshGeometrySoon("display")
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        refreshGeometrySoon("world")
    end
    if specCheckScheduled then
        return
    end
    specCheckScheduled = true
    C_Timer.After(0, function()
        specCheckScheduled = false
        fontPixelRoute.OnSpecChanged()
    end)
end)
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("route.frame", "timed", function()
        return fontPixelRoute.OnClassicFrame
    end, function(onClassicFrame)
        fontPixelRoute.OnClassicFrame = onClassicFrame
    end)
    logicDiagnostics.Declare("route.worker", "timed", function()
        return workerFrame and workerFrame:GetScript("OnUpdate") or nil
    end, function(handler)
        if workerFrame then
            workerFrame:SetScript("OnUpdate", handler)
        end
    end)
    logicDiagnostics.Declare("route.geometry", "sampled", function()
        return refreshGeometry
    end, function(fn)
        refreshGeometry = fn
    end)
    logicDiagnostics.Declare("route.build", "sampled", function()
        return start
    end, function(start2)
        start = start2
        fontPixelRoute.Start = start2
    end)
    logicDiagnostics.Declare("receipt.flush", "sampled", function()
        return flushReceipts
    end, function(fn)
        flushReceipts = fn
    end)
end
(workerFrame:GetScript("OnEvent"))(workerFrame, "PLAYER_LOGIN")
