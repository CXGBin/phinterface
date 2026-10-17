--[[
  CooldownManagerProfiles —— 冷却管理器(CDM)：Blizzard CooldownViewer 布局/字体配置的保存、加载、导入导出（/cdms）
  原始文件：1e635b.lua（TOC 第 28 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local cdmDB = nil
local activeProfileName = "default"
local VIEWERS =
    { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local migrateDB
local function getDB()
    if not cdmDB then
        if _G.P8BA6426E and _G.P8BA6426E.DB then
            _G.P8BA6426E.DB.cdmStateSaverDB = _G.P8BA6426E.DB.cdmStateSaverDB or {}
            cdmDB = _G.P8BA6426E.DB.cdmStateSaverDB
        else
            _G.CDMStateSaverDB = _G.CDMStateSaverDB or {}
            cdmDB = _G.CDMStateSaverDB
        end
        migrateDB()
    end
    return cdmDB
end
local DEFAULT_COOLDOWN_FONT_SIZE = {
    EssentialCooldownViewer = 16,
    UtilityCooldownViewer = 16,
    BuffIconCooldownViewer = 16,
    BuffBarCooldownViewer = 16,
}
local DEFAULT_STACK_FONT_SIZE = {
    EssentialCooldownViewer = 16,
    UtilityCooldownViewer = 14,
    BuffIconCooldownViewer = 14,
    BuffBarCooldownViewer = 14,
}
local getBuffIconHideWhenInactive
migrateDB = function()
    local db = getDB()
    if db.dataConfig and not db.profiles then
        db.profiles = {
            default = {
                dataConfig = db.dataConfig,
                positions = db.positions,
                editModeSettings = db.editModeSettings,
                savedAt = db.dataSavedAt or time(),
            },
        }
        db.dataConfig = nil
        db.positions = nil
        db.editModeSettings = nil
        db.dataSavedAt = nil
        db.editModeSavedAt = nil
    end
    db.profiles = db.profiles or {}
    db.activeProfile = db.activeProfile or "default"
    activeProfileName = db.activeProfile
    if db.autoRestore == nil then
        db.autoRestore = false
    end
    db.cooldownFontSize = db.cooldownFontSize or {}
    db.stackFontSize = db.stackFontSize or {}
    if not db.fontVersion or db.fontVersion < 3 then
        db.fontFlags = nil
        db.fontSize = nil
        db.cooldownFontSize = {}
        db.stackFontSize = {}
        db.fontVersion = 3
    end
end
local function getProfile(name)
    local db = getDB()
    db.profiles = db.profiles or {}
    return db.profiles[name or activeProfileName or "default"]
end
local function setProfile(name, profile)
    local db = getDB()
    db.profiles = db.profiles or {}
    db.profiles[name] = profile
    activeProfileName = name
    db.activeProfile = name
end
local function ensureCooldownViewerReady()
    local cooldownViewerAPI = _G.C_CooldownViewer
    if cooldownViewerAPI and (cooldownViewerAPI.GetLayoutData and cooldownViewerAPI.SetLayoutData) then
        return true
    end
    local loadAddOn = _G.C_AddOns and _G.C_AddOns.LoadAddOn or _G.LoadAddOn
    if loadAddOn then
        pcall(loadAddOn, "Blizzard_CooldownViewer")
    end
    cooldownViewerAPI = _G.C_CooldownViewer
    return cooldownViewerAPI and (cooldownViewerAPI.GetLayoutData and cooldownViewerAPI.SetLayoutData)
end
local function getFontPath()
    local db = getDB()
    return (db and db.fontPath) or P8BA6426E.fontFile
end
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    pcall(LSM.Register, LSM, "font", "P8BA6426E", P8BA6426E.fontFile)
end
local function isFontUsable(fontPath)
    if not fontPath or fontPath == "" then
        return false
    end
    local probe = UIParent:CreateFontString(nil, "OVERLAY")
    local ok = pcall(function()
        probe:SetFont(fontPath, 12, "")
    end)
    probe:Hide()
    return ok
end
local function getFontFlags()
    local db = getDB()
    return db.fontFlags or "THICKOUTLINE"
end
local function getFontSize()
    local db = getDB()
    return (db and db.fontSize) or 18
end
local function getCooldownFontSize(viewerName)
    local db = getDB()
    local cooldownFontSize = db.cooldownFontSize and db.cooldownFontSize[viewerName]
    if cooldownFontSize then
        return cooldownFontSize
    end
    return DEFAULT_COOLDOWN_FONT_SIZE[viewerName] or 16
end
local function getStackFontSize(viewerName)
    local db = getDB()
    local stackFontSize = db.stackFontSize and db.stackFontSize[viewerName]
    if stackFontSize then
        return stackFontSize
    end
    return DEFAULT_STACK_FONT_SIZE[viewerName] or 14
end
local function applyFont(label, fontPath, size, whiteText)
    if not label then
        return
    end
    local _font, _size, currentFlags = label:GetFont()
    local flags = currentFlags or getFontFlags()
    local candidates =
        { fontPath, fontPath .. ":0", fontPath:gsub("%.ttf$", ".ttc"), fontPath:gsub("%.ttf$", ".ttc") .. ":0" }
    for _, candidate in ipairs(candidates) do
        local ok = pcall(function()
            label:SetFont(candidate, size or getFontSize(), flags)
        end)
        if ok then
            if whiteText then
                pcall(function()
                    label:SetTextColor(1, 1, 1, 1)
                end)
            end
            return
        end
    end
    local fallbackFont = select(1, GameFontNormal:GetFont())
    if fallbackFont then
        pcall(function()
            label:SetFont(fallbackFont, size or getFontSize(), flags)
        end)
    end
end
local function measureText(fontPath, size, sample, flags)
    flags = flags or ""
    sample = sample or "0:00"
    local label = UIParent:CreateFontString(nil, "OVERLAY")
    local ok = pcall(function()
        label:SetFont(fontPath, size, flags)
    end)
    if not ok then
        label:Hide()
        return 0, 0, 0, 0
    end
    label:SetText(sample)
    local stringWidth = label:GetStringWidth()
    local stringHeight = label:GetStringHeight()
    label:Hide()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    return stringWidth, stringHeight, stringWidth / width, stringHeight / height
end
local function _measureCooldownText()
    local fontPath = getFontPath()
    local flags = getFontFlags()
    local db = getDB()
    local cooldownFontSize = db.cooldownFontSize or 16
    local stackFontSize = db.stackFontSize or 14
    local cdWidth, cdHeight, _cdRelW, _cdRelH = measureText(fontPath, cooldownFontSize, "0:00", flags)
    local stWidth, stHeight, _stRelW, _stRelH = measureText(fontPath, stackFontSize, "99", flags)
    local maxWidth = math.max(cdWidth, stWidth)
    local maxHeight = math.max(cdHeight, stHeight)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    return maxWidth, maxHeight, maxWidth / width, maxHeight / height, cooldownFontSize, stackFontSize
end
local function anchorFontString(fontString, point, x, y, parent)
    if not fontString then
        return
    end
    if type(fontString) ~= "table" or not fontString.GetObjectType then
        return
    end
    local objectType = fontString:GetObjectType()
    if objectType ~= "FontString" then
        return
    end
    parent = parent or fontString:GetParent()
    if not parent then
        return
    end
    pcall(function()
        fontString:ClearAllPoints()
        fontString:SetPoint(point or "BOTTOMRIGHT", parent, point or "BOTTOMRIGHT", x or 0, y or 0)
    end)
end
local function anchorCountTexts()
    if InCombatLockdown() then
        return
    end
    for _, viewerName in ipairs(VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            for _, child in ipairs({ viewer:GetChildren() }) do
                if viewerName == "EssentialCooldownViewer" and (child.ChargeCount and child.ChargeCount.Current) then
                    pcall(anchorFontString, child.ChargeCount.Current, "BOTTOMRIGHT", 0, 0, child)
                end
                if
                    viewerName == "BuffIconCooldownViewer" and (child.Applications and child.Applications.Applications)
                then
                    pcall(anchorFontString, child.Applications.Applications, "BOTTOMRIGHT", 0, 0, child)
                end
            end
        end
    end
end
local function isViewerReady(viewer)
    if not viewer then
        return false
    end
    if viewer.IsInitialized and not viewer:IsInitialized() then
        return false
    end
    return true
end
local function setFontSizeOnly(fontString, size)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return false
    end
    local ok, font, _size, flags = pcall(fontString.GetFont, fontString)
    if not ok or not font then
        return false
    end
    return pcall(fontString.SetFont, fontString, font, size, flags or "")
end
local function applyViewerFontSizes(viewerName)
    local viewer = _G[viewerName]
    if not isViewerReady(viewer) then
        return 0
    end
    local updated = 0
    local cdSize = getCooldownFontSize(viewerName)
    local stackSize = getStackFontSize(viewerName)
    local function apply(fontString, size)
        if setFontSizeOnly(fontString, size) then
            updated = updated + 1
        end
    end
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.Cooldown and child.Cooldown.GetCountdownFontString then
            apply(child.Cooldown:GetCountdownFontString(), cdSize)
        end
        if child.ChargeCount and child.ChargeCount.Current then
            apply(child.ChargeCount.Current, stackSize)
        end
        if child.Applications and child.Applications.Applications then
            apply(child.Applications.Applications, stackSize)
        end
        if child.Icon and child.Icon.Applications then
            apply(child.Icon.Applications, stackSize)
        end
        if child.Bar and child.Bar.Duration then
            apply(child.Bar.Duration, cdSize)
        end
    end
    return updated
end
local function applyViewerFonts(viewerName)
    local viewer = _G[viewerName]
    if not isViewerReady(viewer) then
        return false
    end
    local fontPath = getFontPath()
    local cdSize = getCooldownFontSize(viewerName)
    local stackSize = getStackFontSize(viewerName)
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.Icon and child.Cooldown then
            if child.Cooldown.GetCountdownFontString then
                local countdownFontString = child.Cooldown:GetCountdownFontString()
                applyFont(countdownFontString, fontPath, cdSize, true)
            end
            if child.ChargeCount and child.ChargeCount.Current then
                applyFont(child.ChargeCount.Current, fontPath, stackSize, false)
            end
            if child.Applications and child.Applications.Applications then
                applyFont(child.Applications.Applications, fontPath, stackSize, false)
            end
        end
    end
    return true
end
local function applyAllViewerFonts()
    if InCombatLockdown() then
        print("|cffff0000[P8BA6426E CDM]|r 战斗中无法修改字体，请脱战后重试")
        return
    end
    for _, viewerName in ipairs(VIEWERS) do
        applyViewerFonts(viewerName)
    end
    anchorCountTexts()
end
local function setFont(fontPath, fontFlags)
    local db = getDB()
    if fontPath and fontPath ~= "" then
        db.fontPath = fontPath
    end
    if fontFlags then
        db.fontFlags = fontFlags
    end
    applyAllViewerFonts()
    anchorCountTexts()
end
local function setFontSize(sizeText)
    local db = getDB()
    local fontSize = tonumber(sizeText)
    if fontSize and fontSize > 0 then
        db.fontSize = fontSize
        applyAllViewerFonts()
        anchorCountTexts()
    else
        print("用法: /cdms fontsize <数字>    例: /cdms fontsize 22")
    end
end
local function isEditModeAvailable()
    return C_EditMode
        and (
            C_EditMode.GetLayouts
            and (C_EditMode.SaveLayouts and (Enum and (Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer)))
        )
end
local function getActiveLayout(layoutInfo)
    if not layoutInfo or not layoutInfo.layouts then
        return nil
    end
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
        if type(presets) == "table" and type(layoutInfo.layouts) == "table" then
            local layouts = {}
            for i, preset in ipairs(presets) do
                layouts[i] = preset
            end
            local presetCount = #presets
            for i, layout in ipairs(layoutInfo.layouts) do
                layouts[presetCount + i] = layout
            end
            layoutInfo.layouts = layouts
        end
    end
    local activeLayout = layoutInfo.activeLayout
    if activeLayout == nil then
        return nil
    end
    local layout = layoutInfo.layouts[activeLayout]
    if layout then
        return layout
    end
    layout = layoutInfo.layouts[activeLayout + 1]
    if layout then
        return layout
    end
    layout = layoutInfo.layouts[activeLayout - 1]
    if layout then
        return layout
    end
    for _, layout in ipairs(layoutInfo.layouts) do
        if layout.layoutID == activeLayout then
            return layout
        end
    end
    return nil
end
local function getBuffIconSystemIndex()
    if Enum.EditModeCooldownViewerSystemIndices and Enum.EditModeCooldownViewerSystemIndices.BuffIcon then
        return Enum.EditModeCooldownViewerSystemIndices.BuffIcon
    end
    return 3
end
local HIDE_WHEN_INACTIVE_SETTING = 8
local function getSystemIndexName(value)
    if not Enum.EditModeCooldownViewerSystemIndices then
        return "unknown"
    end
    for indexName, indexValue in pairs(Enum.EditModeCooldownViewerSystemIndices) do
        if indexValue == value then
            return indexName
        end
    end
    return "unknown(" .. (tostring(value) .. ")")
end
local function inspectEditModeSettings()
    if not isEditModeAvailable() then
        print("|cffff0000[P8BA6426E]|r EditMode API 不可用")
        return
    end
    local layouts = C_EditMode.GetLayouts()
    if not layouts or not layouts.layouts then
        print("|cffff0000[P8BA6426E]|r 无法获取 layouts")
        return
    end
    local activeLayout = getActiveLayout(layouts)
    if not activeLayout then
        print("|cffff0000[P8BA6426E]|r 无法获取 active layout")
        return
    end
    print(
        "|cff00ff00[P8BA6426E]|r active layout: "
            .. (tostring(activeLayout.layoutName) .. (" type=" .. tostring(activeLayout.layoutType)))
    )
    if not activeLayout.systems then
        print("|cffff0000[P8BA6426E]|r active layout 没有 systems")
        return
    end
    for _, system in ipairs(activeLayout.systems) do
        if system.system == Enum.EditModeSystem.CooldownViewer then
            local indexName = getSystemIndexName(system.systemIndex)
            print("|cff888888[P8BA6426E]|r system=" .. (indexName .. (" index=" .. tostring(system.systemIndex))))
            if system.settings then
                for _, setting in ipairs(system.settings) do
                    print(
                        "|cff888888[P8BA6426E]|r   setting="
                            .. (tostring(setting.setting) .. (" value=" .. tostring(setting.value)))
                    )
                end
            end
        end
    end
end
function getBuffIconHideWhenInactive()
    if not isEditModeAvailable() then
        return nil
    end
    local layouts = C_EditMode.GetLayouts()
    if not layouts or not layouts.layouts then
        return nil
    end
    local activeLayout = getActiveLayout(layouts)
    if not activeLayout or not activeLayout.systems then
        return nil
    end
    local buffIconIndex = getBuffIconSystemIndex()
    for _, system in ipairs(activeLayout.systems) do
        if system.system == Enum.EditModeSystem.CooldownViewer and system.systemIndex == buffIconIndex then
            for _, setting in ipairs(system.settings or {}) do
                if setting.setting == HIDE_WHEN_INACTIVE_SETTING then
                    return setting.value == 1
                end
            end
            return false
        end
    end
    return nil
end
local function refreshCooldownViewerSettings()
    if InCombatLockdown() then
        return false
    end
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame then
        return false
    end
    if settingsFrame.RefreshLayout then
        pcall(settingsFrame.RefreshLayout, settingsFrame)
        return true
    end
    return false
end
local function getLayoutData()
    if not ensureCooldownViewerReady() then
        return nil
    end
    if InCombatLockdown() then
        return nil
    end
    local cooldownViewerAPI = _G.C_CooldownViewer
    local layoutData = cooldownViewerAPI.GetLayoutData()
    if type(layoutData) ~= "string" or layoutData == "" then
        return nil
    end
    return layoutData
end
local function refreshAfterEditMode(_)
    if InCombatLockdown() then
        return
    end
    refreshCooldownViewerSettings()
end
local refreshRetryTimer = nil
local function loadDataConfig(layoutData)
    if not layoutData then
        return false, "missing_data"
    end
    if not ensureCooldownViewerReady() then
        return false, "cooldown_viewer_not_ready"
    end
    if InCombatLockdown() then
        return false, "in_combat"
    end
    local cooldownViewerAPI = _G.C_CooldownViewer
    local ok, result = pcall(cooldownViewerAPI.SetLayoutData, layoutData)
    if not ok then
        print("|cffff0000[P8BA6426E CDM]|r: 写入失败: " .. tostring(result))
        return false, tostring(result)
    end
    local refreshed = refreshCooldownViewerSettings()
    if not refreshed then
        if refreshRetryTimer then
            refreshRetryTimer:Cancel()
        end
        refreshRetryTimer = C_Timer.NewTimer(1.5, function()
            local _retried = refreshCooldownViewerSettings()
            refreshRetryTimer = nil
        end)
    end
    return true
end
local function captureViewerPositions(profile)
    local targetProfile = profile or getProfile()
    if not targetProfile then
        return
    end
    targetProfile.positions = targetProfile.positions or {}
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    for _, viewerName in ipairs(VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            local point, relativeTo, relativePoint, x, y = viewer:GetPoint(1)
            targetProfile.positions[viewerName] = {
                point = point,
                relativeTo = relativeTo and (relativeTo.GetName and relativeTo:GetName() or "UIParent") or "UIParent",
                relativePoint = relativePoint,
                x = x and tonumber(string.format("%.4f", x / width)) or 0,
                y = y and tonumber(string.format("%.4f", y / height)) or 0,
                normalized = true,
            }
        end
    end
end
local function restoreViewerPositions()
    local profile = getProfile()
    if not profile or not profile.positions then
        return false
    end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    for _, viewerName in ipairs(VIEWERS) do
        local position = profile.positions[viewerName]
        local viewer = _G[viewerName]
        if position and (viewer and not InCombatLockdown()) then
            viewer:ClearAllPoints()
            local relativeFrame = _G[position.relativeTo] or UIParent
            local x = position.x
            local y = position.y
            if position.normalized then
                x = x * width
                y = y * height
            end
            viewer:SetPoint(position.point, relativeFrame, position.relativePoint, x, y)
        end
    end
    return true
end
-- 保存当前 CDM 布局数据、编辑模式设置、位置、字体到命名配置
local function saveProfile(name)
    name = name or activeProfileName or "default"
    local dataConfig = getLayoutData()
    if not dataConfig then
        print("|cffff0000[P8BA6426E CDM]|r: 数据配置保存失败")
        return false
    end
    local editModeSettings = ExtractEditModeSettings()
    local db = getDB()
    local profile = {
        dataConfig = dataConfig,
        positions = {},
        editModeSettings = editModeSettings,
        savedAt = time(),
        class = select(2, UnitClass("player")),
        spec = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization() or nil,
        cooldownFontSize = db.cooldownFontSize,
        stackFontSize = db.stackFontSize,
        fontPath = db.fontPath,
        fontFlags = db.fontFlags,
        fontSize = db.fontSize,
    }
    captureViewerPositions(profile)
    setProfile(name, profile)
    activeProfileName = name
    return true
end
-- 加载命名配置：写回布局数据、字体、编辑模式布局和窗口位置
local function loadProfile(name)
    if InCombatLockdown() then
        print("|cffff0000[CDM]|r 战斗中无法加载配置")
        return false
    end
    name = name or activeProfileName or "default"
    activeProfileName = name
    local db = getDB()
    db.activeProfile = name
    local profile = getProfile(name)
    if not profile then
        print("|cffff0000[P8BA6426E CDM]|r: 未找到配置 '" .. (name .. "'"))
        return false
    end
    if profile.dataConfig then
        loadDataConfig(profile.dataConfig)
    end
    do
        local db = getDB()
        if profile.cooldownFontSize then
            db.cooldownFontSize = profile.cooldownFontSize
        end
        if profile.stackFontSize then
            db.stackFontSize = profile.stackFontSize
        end
        if profile.fontPath then
            db.fontPath = profile.fontPath
        end
        if profile.fontFlags then
            db.fontFlags = profile.fontFlags
        end
        if profile.fontSize then
            db.fontSize = profile.fontSize
        end
        local fontPath = getFontPath()
        if not isFontUsable(fontPath) then
            print("|cffff0000[P8BA6426E CDM]|r: 警告：字体文件 |cffffffff" .. (fontPath .. "|r 不存在！"))
        end
        for _, viewerName in ipairs(VIEWERS) do
            applyViewerFonts(viewerName)
        end
        anchorCountTexts()
    end
    if profile.editModeSettings then
        local _applied = ApplyEditModeSettings(profile.editModeSettings)
        refreshAfterEditMode(profile.editModeSettings)
        if not InCombatLockdown() and (C_EditMode and C_EditMode.SetActiveLayout) then
            local layouts = C_EditMode.GetLayouts()
            if layouts and layouts.activeLayout then
                local ok, result = pcall(C_EditMode.SetActiveLayout, layouts.activeLayout)
                if not ok then
                    print("|cffff0000[CDM]|r SetActiveLayout 失败: " .. tostring(result))
                else
                end
            else
                print("|cffff0000[CDM]|r 无法获取 activeLayout 来刷新")
            end
        elseif InCombatLockdown() then
            print("|cffff0000[CDM]|r 战斗中跳过 SetActiveLayout")
        else
            print("|cffff0000[CDM]|r C_EditMode.SetActiveLayout 不可用")
        end
    else
    end
    restoreViewerPositions()
    if profile.class then
    end
    return true
end
local function packProfile(profile)
    if not profile then
        return nil
    end
    return {
        v = 2,
        d = profile.dataConfig,
        p = profile.positions,
        e = profile.editModeSettings,
        c = profile.class,
        s = profile.spec,
        cds = profile.cooldownFontSize,
        ss = profile.stackFontSize,
        fp = profile.fontPath,
        ff = profile.fontFlags,
        fz = profile.fontSize,
    }
end
local function exportProfile(name)
    name = name or activeProfileName or "default"
    saveProfile(name)
    local profile = getProfile(name)
    if not profile then
        print("|cffff0000[P8BA6426E CDM]|r: 保存配置失败，无法导出")
        return
    end
    local function hashString(s)
        if type(s) ~= "string" then
            return 0
        end
        local hash = 0
        for i = 1, math.min(#s, 1000), 1 do
            hash = (hash * 31 + string.byte(s, i)) % 1000000007
        end
        return hash
    end
    local function serializeStable(value)
        if type(value) ~= "table" then
            return tostring(value)
        end
        local parts = {}
        local keys = {}
        for key in pairs(value) do
            table.insert(keys, key)
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        for _, key in ipairs(keys) do
            local fieldValue = value[key]
            if type(fieldValue) == "table" then
                table.insert(parts, tostring(key) .. ("={" .. (serializeStable(fieldValue) .. "}")))
            else
                table.insert(parts, tostring(key) .. ("=" .. tostring(fieldValue)))
            end
        end
        return table.concat(parts, ";")
    end
    local function _hashTable(value)
        return hashString(serializeStable(value))
    end
    local packed = packProfile(profile)
    if not packed then
        return
    end
    local c_EncodingUtil = _G.C_EncodingUtil
    if
        c_EncodingUtil
        and (c_EncodingUtil.SerializeCBOR and (c_EncodingUtil.CompressString and c_EncodingUtil.EncodeBase64))
    then
        local ok, cbor = pcall(c_EncodingUtil.SerializeCBOR, packed)
        if ok and cbor then
            local ok, compressed = pcall(c_EncodingUtil.CompressString, cbor, Enum.CompressionMethod.Deflate)
            if ok and compressed then
                local ok, encoded = pcall(c_EncodingUtil.EncodeBase64, compressed)
                if ok and encoded then
                    local exportString = "CDMSSv2|" .. encoded
                    StaticPopup_Show("CDMSS_COPY", nil, nil, exportString)
                    return
                end
            end
        end
    end
    print("|cffff0000[P8BA6426E CDM]|r: 导出失败，C_EncodingUtil API 不可用")
end
local function exportDataConfig()
    local d = getLayoutData()
    if not d then
        print("|cffff0000[P8BA6426E CDM]|r: 数据配置获取失败")
        return
    end
    local c = select(2, UnitClass("player"))
    local s = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization() or nil
    local payload = { d = d, c = c, s = s, v = 1 }
    local c_EncodingUtil = _G.C_EncodingUtil
    if
        c_EncodingUtil
        and (c_EncodingUtil.SerializeCBOR and (c_EncodingUtil.CompressString and c_EncodingUtil.EncodeBase64))
    then
        local ok, cbor = pcall(c_EncodingUtil.SerializeCBOR, payload)
        if ok and cbor then
            local ok, compressed = pcall(c_EncodingUtil.CompressString, cbor, Enum.CompressionMethod.Deflate)
            if ok and compressed then
                local ok, encoded = pcall(c_EncodingUtil.EncodeBase64, compressed)
                if ok and encoded then
                    local exportString = "CDMSSdata|" .. encoded
                    StaticPopup_Show("CDMSS_COPY", nil, nil, exportString)
                    return
                end
            end
        end
    end
    print("|cffff0000[P8BA6426E CDM]|r: 导出失败")
end
local function listProfiles()
    local db = getDB()
    db.profiles = db.profiles or {}
    if not next(db.profiles) then
        print("|cffffaa00[P8BA6426E CDM]|r: 暂无保存的配置")
        return
    end
    for name, profile in pairs(db.profiles) do
        local savedAtText = profile.savedAt and date("%Y-%m-%d %H:%M:%S", profile.savedAt) or P8BA6426E.L("未知")
        local class = profile.class or "?"
        local spec = profile.spec or "?"
        local dataLength = profile.dataConfig and #profile.dataConfig or 0
        local currentMark = (name == activeProfileName) and " |cff00ff00<< 当前|r" or ""
    end
end
local function deleteProfile(name)
    local db = getDB()
    db.profiles = db.profiles or {}
    if db.profiles[name] then
        db.profiles[name] = nil
    else
        print("|cffff0000[P8BA6426E CDM]|r: 未找到配置 '" .. (name .. "'"))
    end
end
StaticPopupDialogs.CDMSS_COPY = {
    text = "配置字符串已生成（Ctrl+C 复制，Esc 关闭）：",
    button1 = P8BA6426E.L("关闭"),
    hasEditBox = true,
    editBoxWidth = 450,
    OnShow = function(dialog)
        dialog.EditBox:SetText(dialog.data or "")
        dialog.EditBox:HighlightText()
        dialog.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(editBox)
        (editBox:GetParent()):Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        (editBox:GetParent()):Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
SLASH_CDMSS1 = "/cdms"
SlashCmdList.CDMSS = function(msg)
    local cmd, arg, rest = msg:match("^(%S*)%s*(%S*)%s*(.*)$")
    cmd = (((cmd or "")):lower()):trim()
    arg = ((arg or "")):trim()
    rest = ((rest or "")):trim()
    if cmd == "save" then
        saveProfile(arg ~= "" and arg or nil)
    elseif cmd == "load" then
        loadProfile(arg ~= "" and arg or nil)
    elseif cmd == "list" then
        listProfiles()
    elseif cmd == "delete" or cmd == "del" then
        if arg ~= "" then
            deleteProfile(arg)
        else
            print("用法: /cdms delete <名称>")
        end
    elseif cmd == "export" then
        exportProfile(arg ~= "" and arg or nil)
    elseif cmd == "import" then
        if arg ~= "" and rest ~= "" then
            if P8BA6426E.CDMImportProfile then
                P8BA6426E.CDMImportProfile(arg, rest)
            else
                print("|cffff0000[P8BA6426E CDM]|r: 导入模块未加载")
            end
        else
            print("用法: /cdms import <名称> <字符串>")
        end
    elseif cmd == "pos" then
        for _, viewerName in ipairs(VIEWERS) do
            local viewer = _G[viewerName]
            if viewer then
                local point, _relativeTo, _relativePoint, _x, _y = viewer:GetPoint(1)
            end
        end
    elseif cmd == "inspect" then
        if not isEditModeAvailable() then
            return
        end
        local layouts = C_EditMode.GetLayouts()
        if not layouts then
            return
        end
        local activeLayout = getActiveLayout(layouts)
        if not activeLayout then
            print("无法获取 activeLayout")
            return
        end
        for _, system in ipairs(activeLayout.systems) do
            if system.system == Enum.EditModeSystem.CooldownViewer then
                if system.settings then
                    for _, _ in ipairs(system.settings) do
                    end
                end
                if system.anchorInfo then
                    local anchorInfo = system.anchorInfo
                end
            end
        end
    elseif cmd == "font" then
        if arg ~= "" then
            setFont(arg)
        else
            print("用法: /cdms font <路径>    例: /cdms font Fonts\\2B518D9B.ttf")
        end
    elseif cmd == "fontsize" then
        setFontSize(arg)
    elseif cmd == "cdfontsize" then
        local viewerName, sizeText = arg, rest
        if sizeText == "" then
            sizeText = viewerName
            viewerName = nil
        end
        if viewerName and (viewerName ~= "" and (sizeText and sizeText ~= "")) then
            if not _G[viewerName] then
                print("|cffff0000未知 viewer:|r " .. viewerName)
                return
            end
            local size = tonumber(sizeText)
            if not size then
                print("|cffff0000请输入数字|r")
                return
            end
            local db = getDB()
            db.cooldownFontSize = db.cooldownFontSize or {}
            db.cooldownFontSize[viewerName] = size
            applyViewerFontSizes(viewerName)
        else
            print("用法: /cdms cdfontsize <viewer> <大小>")
            for _, viewerName in ipairs(VIEWERS) do
                local _size = getCooldownFontSize(viewerName)
            end
        end
    elseif cmd == "stfontsize" then
        local viewerName, sizeText = arg, rest
        if sizeText == "" then
            sizeText = viewerName
            viewerName = nil
        end
        if viewerName and (viewerName ~= "" and (sizeText and sizeText ~= "")) then
            if not _G[viewerName] then
                print("|cffff0000未知 viewer:|r " .. viewerName)
                return
            end
            local size = tonumber(sizeText)
            if not size then
                print("|cffff0000请输入数字|r")
                return
            end
            local db = getDB()
            db.stackFontSize = db.stackFontSize or {}
            db.stackFontSize[viewerName] = size
            applyViewerFontSizes(viewerName)
        else
            print("用法: /cdms stfontsize <viewer> <大小>")
            for _, viewerName in ipairs(VIEWERS) do
                local _size = getStackFontSize(viewerName)
            end
        end
    elseif cmd == "fontflags" then
        if arg ~= "" then
            setFont(nil, arg)
        else
            print("用法: /cdms fontflags <flags>  例: /cdms fontflags OUTLINE")
        end
    elseif cmd == "debug" then
        if Enum.EditModeCooldownViewerSystemIndices then
            for indexName, indexValue in pairs(Enum.EditModeCooldownViewerSystemIndices) do
                print("  " .. (tostring(indexName) .. (" = " .. tostring(indexValue))))
            end
        end
        for _, viewerName in ipairs(VIEWERS) do
            local viewer = _G[viewerName]
            if viewer then
            end
        end
    elseif cmd == "autorestore" then
        local db = getDB()
        if arg == "off" or arg == "disable" or arg == "0" then
            db.autoRestore = false
            print(
                "|cff00ff00[P8BA6426E CDM]|r 自动恢复已 |cffff0000关闭|r。/reload 后不再强制恢复 CDM 配置，可自由调整布局。"
            )
        elseif arg == "on" or arg == "enable" or arg == "1" then
            db.autoRestore = true
            print(
                "|cff00ff00[P8BA6426E CDM]|r 自动恢复已 |cff00ff00开启|r。/reload 后将恢复上次保存的 CDM 配置。"
            )
        else
            local stateText = db.autoRestore ~= false and "|cff00ff00开启|r" or "|cffff0000关闭|r"
            print("|cff00ff00[P8BA6426E CDM]|r 自动恢复状态: " .. stateText)
            print("  用法: /cdms autorestore on  |  /cdms autorestore off")
        end
    elseif cmd == "exportdata" then
        exportDataConfig()
    elseif cmd == "importdata" then
        if arg ~= "" then
            if P8BA6426E.CDMImportDataConfig then
                P8BA6426E.CDMImportDataConfig(arg)
            else
                print("|cffff0000[P8BA6426E CDM]|r: 导入模块未加载")
            end
        else
            print("用法: /cdms importdata <CDMSSdata|...>")
        end
    else
    end
end
P8BA6426E.CDMManager = {
    LoadProfile = loadProfile,
    SetProfile = setProfile,
    GetDB = getDB,
    LoadDataConfig = loadDataConfig,
    ExportProfile = exportProfile,
    EnsureCooldownViewerReady = ensureCooldownViewerReady,
    InspectEditModeSettings = inspectEditModeSettings,
    GetBuffIconHideWhenInactive = getBuffIconHideWhenInactive,
    VIEWERS = VIEWERS,
}
local cdmManager = P8BA6426E.CDMManager
if not cdmManager then
    print("|cffff0000CDMStateSaver Import|r: 核心模块未加载，导入功能不可用")
    return
end
local function unpackProfile(packed)
    if not packed then
        return nil
    end
    if packed.v == 2 then
        return {
            dataConfig = packed.d,
            positions = packed.p,
            editModeSettings = packed.e,
            class = packed.c,
            spec = packed.s,
            cooldownFontSize = packed.cds,
            stackFontSize = packed.ss,
            fontPath = packed.fp,
            fontFlags = packed.ff,
            fontSize = packed.fz,
            savedAt = time(),
        }
    end
    return nil
end
local function cdmImportDataConfig(importString)
    if not importString or importString == "" then
        print("|cffff0000[P8BA6426E CDM]|r: 请输入有效的配置字符串")
        return false
    end
    if not importString:match("^CDMSSdata%|") then
        print("|cffff0000[P8BA6426E CDM]|r: 格式错误，应以 CDMSSdata| 开头")
        return false
    end
    local payload = importString:match("^CDMSSdata%|(.+)$")
    if not payload then
        print("|cffff0000[P8BA6426E CDM]|r: 格式错误")
        return false
    end
    local c_EncodingUtil = _G.C_EncodingUtil
    if
        c_EncodingUtil
        and (c_EncodingUtil.DecodeBase64 and (c_EncodingUtil.DecompressString and c_EncodingUtil.DeserializeCBOR))
    then
        local ok, decoded = pcall(c_EncodingUtil.DecodeBase64, payload)
        if ok and decoded then
            local ok, decompressed = pcall(c_EncodingUtil.DecompressString, decoded, Enum.CompressionMethod.Deflate)
            if ok and decompressed then
                local ok, data = pcall(c_EncodingUtil.DeserializeCBOR, decompressed)
                if ok and (data and data.d) then
                    cdmManager.LoadDataConfig(data.d)
                    local db = cdmManager.GetDB()
                    db.specDataConfigs = db.specDataConfigs or {}
                    local classFile = select(2, UnitClass("player"))
                    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization
                            and P8BA6426E.SpecializationAPI.GetSpecialization()
                        or 0
                    local specKey = classFile .. ("-" .. specIndex)
                    db.specDataConfigs[specKey] = { dataConfig = data.d, importedAt = time() }
                    if data.c then
                        print("  来源职业: " .. (data.c .. (" 专精: " .. tostring(data.s or "?"))))
                    end
                    return true
                end
            end
        end
    end
    print("|cffff0000[P8BA6426E CDM]|r: 解码失败")
    return false
end
local function cdmImportProfile(name, importString)
    if not importString or importString == "" then
        print("|cffff0000[P8BA6426E CDM]|r: 请输入有效的配置字符串")
        return false
    end
    name = name or "imported"
    if importString:match("^CDMSSv2%|") then
        local payload = importString:match("^CDMSSv2%|(.+)$")
        if not payload then
            print("|cffff0000[P8BA6426E CDM]|r: 格式错误")
            return false
        end
        local c_EncodingUtil = _G.C_EncodingUtil
        if
            c_EncodingUtil
            and (c_EncodingUtil.DecodeBase64 and (c_EncodingUtil.DecompressString and c_EncodingUtil.DeserializeCBOR))
        then
            local ok, decoded = pcall(c_EncodingUtil.DecodeBase64, payload)
            if ok and decoded then
                local ok, decompressed = pcall(c_EncodingUtil.DecompressString, decoded, Enum.CompressionMethod.Deflate)
                if ok and decompressed then
                    local ok, data = pcall(c_EncodingUtil.DeserializeCBOR, decompressed)
                    if ok and data then
                        local profile = unpackProfile(data)
                        if profile then
                            cdmManager.SetProfile(name, profile)
                            cdmManager.LoadProfile(name)
                            return true
                        end
                    end
                end
            end
        end
        print("|cffff0000[P8BA6426E CDM]|r: 解码失败，可能缺少 C_EncodingUtil API")
        return false
    end
    print("|cffff0000[P8BA6426E CDM]|r: 未知格式，应以 CDMSSv2| 开头")
    return false
end
P8BA6426E.CDMImportProfile = cdmImportProfile
P8BA6426E.CDMImportDataConfig = cdmImportDataConfig
StaticPopupDialogs.CDMSS_IMPORT = {
    text = "粘贴配置字符串（以 CDMSSv2| 开头）：",
    button1 = "导入并 /reload",
    button2 = P8BA6426E.L("取消"),
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(dialog)
        dialog.EditBox:SetText("")
        dialog.EditBox:SetFocus()
    end,
    OnAccept = function(dialog)
        if InCombatLockdown() then
            print("|cffff0000[CDM]|r 战斗中无法重载界面，请脱战后重试")
            return
        end
        local text = dialog.EditBox:GetText()
        if text and text ~= "" then
            if cdmImportProfile("imported", text) then
                ReloadUI()
            end
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        if InCombatLockdown() then
            print("|cffff0000[CDM]|r 战斗中无法重载界面，请脱战后重试");
            (editBox:GetParent()):Hide()
            return
        end
        local text = editBox:GetText()
        if text and text ~= "" then
            if cdmImportProfile("imported", text) then
                ReloadUI()
            end
        end
        (editBox:GetParent()):Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        (editBox:GetParent()):Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
