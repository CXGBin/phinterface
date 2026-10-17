--[[
  MainUI —— 主设置界面：标签页（设置/天赋/按键/CVar/宏帮助）、按键绑定、天赋导入、CVar 面板
  原始文件：dfbb6a.lua（TOC 第 30 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
-- 主设置窗口（/pms 打开）
local mainFrame = CreateFrame("Frame", "P8BA6426EMain", UIParent, BackdropTemplateMixin and "BackdropTemplate")
mainFrame:SetSize(540, 560)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
})
mainFrame:SetBackdropColor(0.08, 0.08, 0.09, 0.95)
mainFrame:SetBackdropBorderColor(0.22, 0.22, 0.24, 1)
mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:Hide()
P8BA6426E.mainFrame = mainFrame
local titleLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
titleLabel:SetPoint("TOP", mainFrame, "TOP", 0, -14)
titleLabel:SetText("P8BA6426E")
local tabButtons = {}
P8BA6426E.tabFrames = {}
function P8BA6426E.SwitchTab(tabIndex)
    for i, tabButton in ipairs(tabButtons) do
        if i == tabIndex then
            tabButton.bg:SetColorTexture(0.6, 0.1, 0.15, 0.9)
            tabButton.border:SetColorTexture(0.8, 0.2, 0.25, 1);
            (tabButton:GetFontString()):SetTextColor(1, 1, 1, 1)
            if P8BA6426E.tabFrames[i] then
                P8BA6426E.tabFrames[i]:Show()
            end
        else
            tabButton.bg:SetColorTexture(0, 0, 0, 0)
            tabButton.border:SetColorTexture(0, 0, 0, 0);
            (tabButton:GetFontString()):SetTextColor(0.9, 0.75, 0.35, 1)
            if P8BA6426E.tabFrames[i] then
                P8BA6426E.tabFrames[i]:Hide()
            end
        end
    end
    if tabIndex == 2 and P8BA6426E.ShowTalentPicker then
        P8BA6426E.ShowTalentPicker()
    end
    if tabIndex == 3 and ShowMacroEditor then
        ShowMacroEditor()
    end
    if tabIndex == 4 and P8BA6426E.RefreshCVarPanel then
        P8BA6426E.RefreshCVarPanel()
    end
    if tabIndex == 5 and P8BA6426E.RefreshMacroHelper then
        P8BA6426E.RefreshMacroHelper()
    end
end
local TAB_TITLES =
    { P8BA6426E.L("设置"), P8BA6426E.L("天赋"), P8BA6426E.L("按键"), "CVar设置", "制作按键宏" }
local TAB_WIDTH = 92
local TAB_GAP = 10
local tabsWidth = #TAB_TITLES * TAB_WIDTH + (#TAB_TITLES - 1) * TAB_GAP
local tabsLeft = (540 - tabsWidth) / 2
for i, title in ipairs(TAB_TITLES) do
    local tabButton = P8BA6426E.CreateStyledButton(mainFrame, title, TAB_WIDTH, 24)
    tabButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", tabsLeft + (i - 1) * (TAB_WIDTH + TAB_GAP), -40)
    local tabIndex = i
    tabButton:SetScript("OnClick", function()
        P8BA6426E.SwitchTab(tabIndex)
    end)
    tabButtons[i] = tabButton
end
local closeButton = P8BA6426E.CreateStyledButton(mainFrame, "关 闭", 80, 24)
closeButton:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 12)
closeButton:SetScript("OnClick", function()
    mainFrame:Hide()
end)
P8BA6426E.configFrame = CreateFrame("Frame", nil, mainFrame)
P8BA6426E.configFrame:SetSize(520, 444)
P8BA6426E.configFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -76)
P8BA6426E.configFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 40)
P8BA6426E.configFrame:Hide()
local frameLevelCounter = 100
P8BA6426E.mklFrames = { P8BA6426E.configFrame }
function P8BA6426E.BringToFront(frameToRaise)
    frameLevelCounter = frameLevelCounter + 1
    frameToRaise:SetFrameLevel(frameLevelCounter)
end
local pendingTalentCommit = nil
-- 导入天赋字符串到当前配置（暂存，点击“应用改动”后提交）
local function stageTalentImport(importString, name, nameIsRaw)
    if InCombatLockdown() then
        print(P8BA6426E.L("|cffff0000[MKK]|r 战斗中无法修改天赋"))
        return false
    end
    local canEdit, reason = C_ClassTalents.CanEditTalents()
    if not canEdit then
        print(P8BA6426E.L("|cffff0000[MKK]|r 当前无法编辑天赋: ") .. tostring(reason))
        return false
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        local loaded, _reason = C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
        if not loaded then
            print(P8BA6426E.L("|cffff0000[MKK]|r 无法加载天赋框架"))
            return false
        end
    end
    local loadoutName = P8BA6426E.L("MKL导入_") .. (nameIsRaw and name or P8BA6426E.L(name))
    local ok, result = pcall(function()
        local importer = ClassTalentImportExportMixin
        local stream = ExportUtil.MakeImportDataStream(importString)
        local headerOk, serializationVersion, headerSpecID, treeHash = importer:ReadLoadoutHeader(stream)
        if not headerOk then
            error(P8BA6426E.L("天赋字符串无效"), 0)
        end
        if serializationVersion ~= C_Traits.GetLoadoutSerializationVersion() then
            error(P8BA6426E.L("天赋字符串版本不兼容，请重新导出"), 0)
        end
        local _classFile, _specIndex, specID = P8BA6426E.GetPlayerClassSpec()
        if headerSpecID ~= specID then
            error(P8BA6426E.L("天赋字符串不属于当前专精"), 0)
        end
        local configID = C_ClassTalents.GetActiveConfigID()
        local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
        local hashIsZero = true
        for _, hashByte in ipairs(treeHash) do
            if hashByte ~= 0 then
                hashIsZero = false
                break
            end
        end
        if not hashIsZero then
            local currentTreeHash = C_Traits.GetTreeHash(treeID)
            for i, hashByte in ipairs(treeHash) do
                if currentTreeHash[i] ~= hashByte then
                    error(P8BA6426E.L("天赋树已变更，字符串已过期"), 0)
                end
            end
        end
        local content = importer:ReadLoadoutContent(stream, treeID)
        local entries = importer:ConvertToImportLoadoutEntryInfo(configID, treeID, content)
        local imported, importError = C_ClassTalents.ImportLoadout(configID, entries, loadoutName, importString)
        if not imported then
            error(tostring(importError or P8BA6426E.L("未知错误")), 0)
        end
    end)
    if not ok then
        print(P8BA6426E.L("|cffff0000[MKK]|r 导入失败: ") .. tostring(result))
        return false
    end
    pendingTalentCommit = { configID = C_ClassTalents.GetActiveConfigID(), name = name }
    return true
end
P8BA6426E.talentPickerFrame = CreateFrame("Frame", nil, mainFrame)
P8BA6426E.talentPickerFrame:SetSize(520, 444)
P8BA6426E.talentPickerFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -76)
P8BA6426E.talentPickerFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 40)
P8BA6426E.talentPickerFrame:Hide()
local rotationLabel = P8BA6426E.talentPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rotationLabel:SetPoint("TOP", P8BA6426E.talentPickerFrame, "TOP", 0, -10)
rotationLabel:SetWidth(470)
rotationLabel:SetText("")
local statusLabel = P8BA6426E.talentPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusLabel:SetPoint("TOP", P8BA6426E.talentPickerFrame, "TOP", 0, -34)
statusLabel:SetText("")
statusLabel:SetTextColor(0.7, 0.7, 0.7, 1)
local talentScroll = CreateFrame("ScrollFrame", nil, P8BA6426E.talentPickerFrame, "UIPanelScrollFrameTemplate")
talentScroll:SetPoint("TOPLEFT", P8BA6426E.talentPickerFrame, "TOPLEFT", 20, -58)
talentScroll:SetPoint("BOTTOMRIGHT", P8BA6426E.talentPickerFrame, "BOTTOMRIGHT", -34, 50)
local talentList = CreateFrame("Frame", nil, talentScroll)
talentList:SetSize(440, 1)
talentScroll:SetScrollChild(talentList)
local talentListItems = {}
function P8BA6426E.ShowTalentPicker()
    for _, item in ipairs(talentListItems) do
        item:Hide()
        if item.SetParent then
            item:SetParent(nil)
        end
    end
    wipe(talentListItems)
    local _classFile, _specIndex, specID = P8BA6426E.GetPlayerClassSpec()
    local builtinLoadouts = {}
    if specID and (P8BA6426E.classes[specID] and P8BA6426E.classes[specID].talentLoadouts) then
        builtinLoadouts = P8BA6426E.classes[specID].talentLoadouts
    end
    local rotationLoadouts = P8BA6426E.rotationTalentLoadouts
    local rotationLoadoutList = {}
    if specID and (type(rotationLoadouts) == "table" and rotationLoadouts.specID == specID) then
        rotationLabel:SetText(P8BA6426E.L("当前循环：") .. rotationLoadouts.rotationName)
        if type(rotationLoadouts.loadouts) == "table" then
            rotationLoadoutList = rotationLoadouts.loadouts
        end
    else
        rotationLabel:SetText(P8BA6426E.L("当前循环：暂无同步数据，请 /reload"))
    end
    statusLabel:SetText("")
    statusLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    talentScroll:SetVerticalScroll(0)
    local cursorY = -4
    local function addHeader(text, brightness)
        local header = talentList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", talentList, "TOPLEFT", 4, cursorY)
        header:SetWidth(420)
        header:SetJustifyH("LEFT")
        header:SetText(text)
        header:SetTextColor(brightness, brightness, brightness, 1)
        table.insert(talentListItems, header)
        cursorY = cursorY - 28
    end
    local function addLoadoutButtons(loadoutList, rawNames)
        for _, loadout in ipairs(loadoutList) do
            local name = rawNames and loadout.name or P8BA6426E.L(loadout.name)
            local loadoutButton = P8BA6426E.CreateStyledButton(talentList, name, 420, 28)
            if rawNames then
                loadoutButton:SetText(name)
            end
            loadoutButton:SetPoint("TOPLEFT", talentList, "TOPLEFT", 4, cursorY)
            loadoutButton:SetScript("OnClick", function()
                local staged = stageTalentImport(loadout.importString, loadout.name, rawNames)
                if staged then
                    statusLabel:SetText(
                        P8BA6426E.L("已暂存：「")
                            .. (name .. P8BA6426E.L("」，请点击下方【应用改动】"))
                    )
                    statusLabel:SetTextColor(0, 1, 0.5, 1)
                end
            end)
            table.insert(talentListItems, loadoutButton)
            cursorY = cursorY - 34
        end
    end
    if #rotationLoadoutList > 0 then
        addHeader(P8BA6426E.L("循环配套天赋"), 1)
        addLoadoutButtons(rotationLoadoutList, true)
        cursorY = cursorY - 8
    end
    addHeader(P8BA6426E.L("内置推荐天赋"), 1)
    if #builtinLoadouts == 0 then
        addHeader(P8BA6426E.L("当前专精暂无预设天赋"), 0.7)
    else
        addLoadoutButtons(builtinLoadouts, false)
    end
    talentList:SetHeight(-cursorY + 4)
end
local applyTalentButton = P8BA6426E.CreateStyledButton(P8BA6426E.talentPickerFrame, "应用改动", 100, 26)
applyTalentButton:SetPoint("BOTTOM", P8BA6426E.talentPickerFrame, "BOTTOM", 0, 16)
applyTalentButton:SetScript("OnClick", function()
    if pendingTalentCommit then
        C_Traits.CommitConfig(pendingTalentCommit.configID)
        pendingTalentCommit = nil
        statusLabel:SetText("")
        statusLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    else
        print(P8BA6426E.L("|cffff0000[MKK]|r 没有待应用的天赋"))
    end
end)
-- 全屏按键捕获层：设置总开关/爆发/模式切换快捷键
local keyCaptureFrame = CreateFrame("Frame", nil, UIParent)
keyCaptureFrame:SetAllPoints()
keyCaptureFrame:EnableKeyboard(true)
keyCaptureFrame:EnableMouse(true)
keyCaptureFrame:SetPropagateKeyboardInput(false)
keyCaptureFrame:Hide()
keyCaptureFrame:SetFrameStrata("FULLSCREEN_DIALOG")
local keyCaptureLabel = keyCaptureFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
keyCaptureLabel:SetPoint("CENTER", keyCaptureFrame, "CENTER", 0, 0)
keyCaptureLabel:SetText(P8BA6426E.L("请按下要绑定的按键（ESC取消）"))
local MODIFIER_KEYS = {
    SHIFT = true,
    LSHIFT = true,
    RSHIFT = true,
    CTRL = true,
    LCTRL = true,
    RCTRL = true,
    ALT = true,
    LALT = true,
    RALT = true,
}
local function withModifiers(key)
    local parts = {}
    if IsAltKeyDown() then
        parts[#parts + 1] = "ALT"
    end
    if IsControlKeyDown() then
        parts[#parts + 1] = "CTRL"
    end
    if IsShiftKeyDown() then
        parts[#parts + 1] = "SHIFT"
    end
    parts[#parts + 1] = key
    return table.concat(parts, "-")
end
local function describeConflict(key)
    local conflictKind, conflictRef = P8BA6426E.GetControlBindingConflict(key)
    if conflictKind == "action" then
        local actionLabel = ((P8BA6426E.ACTION_LABELS or {}))[conflictRef] or conflictRef
        return string.format(P8BA6426E.L("动作源「%s」"), P8BA6426E.L(actionLabel))
    elseif conflictKind == "raid" then
        return string.format(P8BA6426E.L("团队选人 raid%d"), conflictRef)
    end
end
local function assignControlKey(key)
    local conflict = describeConflict(key)
    if conflict then
        keyCaptureLabel:SetText(
            "|cffff5555"
                .. (
                    string.format(
                        P8BA6426E.L("按键 %s 已被%s占用，无法设置。\n请换一个按键（ESC取消）"),
                        P8BA6426E.GetKeyDisplayText(key),
                        conflict
                    ) .. "|r"
                )
        )
        return false
    end
    if P8BA6426E.waitingForKey == "master" then
        P8BA6426E.DB.masterKey = key
        if P8BA6426E.configFrame.masterUpdate then
            P8BA6426E.configFrame.masterUpdate()
        end
    elseif P8BA6426E.waitingForKey == "burst" then
        P8BA6426E.DB.burstKey = key
        if P8BA6426E.configFrame.burstUpdate then
            P8BA6426E.configFrame.burstUpdate()
        end
    elseif P8BA6426E.waitingForKey == "aoe" then
        P8BA6426E.DB.aoeKey = key
        if P8BA6426E.configFrame.aoeUpdate then
            P8BA6426E.configFrame.aoeUpdate()
        end
    end
    return true
end
keyCaptureFrame:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        P8BA6426E.waitingForKey = nil
        self:Hide()
        return
    end
    if MODIFIER_KEYS[key] then
        return
    end
    local bind = withModifiers(key)
    if not assignControlKey(bind) then
        return
    end
    P8BA6426E.waitingForKey = nil
    self:Hide()
end)
keyCaptureFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        return
    end
    local buttonIndex = button == "RightButton" and "2"
        or button == "MiddleButton" and "3"
        or button:match("(%d+)")
        or "1"
    local bind = withModifiers("BUTTON" .. buttonIndex)
    if not assignControlKey(bind) then
        return
    end
    P8BA6426E.waitingForKey = nil
    self:Hide()
end)
local function addDivider(parent, offsetY)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetHeight(1)
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, offsetY)
    texture:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, offsetY)
    texture:SetColorTexture(0.3, 0.3, 0.35, 1)
    return texture
end
local function createKeyBindRow(parent, labelText, keyKind, offsetY)
    local rowLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, offsetY)
    rowLabel:SetText(labelText)
    rowLabel:SetJustifyH("LEFT")
    rowLabel:SetWidth(100)
    local keyButton = P8BA6426E.CreateStyledButton(parent, "", 120, 24)
    keyButton:SetPoint("LEFT", rowLabel, "RIGHT", 10, 0)
    local function refresh()
        local key
        if keyKind == "master" then
            key = P8BA6426E.DB.masterKey
        elseif keyKind == "burst" then
            key = P8BA6426E.DB.burstKey
        elseif keyKind == "aoe" then
            key = P8BA6426E.DB.aoeKey
        end
        keyButton.controlConflict = describeConflict(key)
        local keyText = P8BA6426E.GetKeyDisplayText(key)
        keyButton:SetText(keyButton.controlConflict and ("|cffff5555" .. (keyText .. "|r")) or keyText)
    end
    keyButton:HookScript("OnEnter", function(self)
        if not self.controlConflict then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(P8BA6426E.L("快捷键占用"))
        GameTooltip:AddLine(
            string.format(
                P8BA6426E.L(
                    "此快捷键已被%s占用，暂不切换开关。\n左键重新设置，右键清除；仍可使用界面按钮。"
                ),
                self.controlConflict
            ),
            1,
            0.35,
            0.35,
            true
        )
        GameTooltip:Show()
    end)
    keyButton:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    keyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    keyButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if keyKind == "master" then
                P8BA6426E.DB.masterKey = nil
            elseif keyKind == "burst" then
                P8BA6426E.DB.burstKey = nil
            elseif keyKind == "aoe" then
                P8BA6426E.DB.aoeKey = nil
            end
            refresh()
            SaveBindings(GetCurrentBindingSet())
        else
            P8BA6426E.waitingForKey = keyKind
            keyCaptureLabel:SetText(P8BA6426E.L("请按下要绑定的按键（ESC取消）"))
            keyCaptureFrame:Show()
        end
    end)
    refresh()
    return keyButton, refresh
end
P8BA6426E.InitDB()
local masterKeyButton, masterUpdate = createKeyBindRow(P8BA6426E.configFrame, P8BA6426E.L("总开关:"), "master", -58)
local burstKeyButton, burstUpdate = createKeyBindRow(P8BA6426E.configFrame, P8BA6426E.L("爆发开关:"), "burst", -93)
local _aoeKeyButton, aoeUpdate = createKeyBindRow(P8BA6426E.configFrame, P8BA6426E.L("模式切换:"), "aoe", -128)
P8BA6426E.configFrame.masterUpdate = masterUpdate
P8BA6426E.configFrame.burstUpdate = burstUpdate
P8BA6426E.configFrame.aoeUpdate = aoeUpdate
function P8BA6426E.RefreshControlKeySettingUI()
    masterUpdate()
    burstUpdate()
    aoeUpdate()
end
local burstSecondsBox = CreateFrame("EditBox", nil, P8BA6426E.configFrame, "InputBoxTemplate")
burstSecondsBox:SetSize(48, 24)
burstSecondsBox:SetPoint("LEFT", burstKeyButton, "RIGHT", 10, 0)
burstSecondsBox:SetAutoFocus(false)
burstSecondsBox:SetNumeric(true)
burstSecondsBox:SetMaxLetters(6)
burstSecondsBox:SetJustifyH("CENTER")
burstSecondsBox:SetText("0")
local function refreshBurstSecondsBox()
    local seconds = P8BA6426E.GetBurstAutoCloseSeconds()
    burstSecondsBox:SetText(tostring(seconds))
end
local function saveBurstSeconds()
    local saved, seconds, specName = P8BA6426E.SaveBurstAutoCloseSeconds(burstSecondsBox:GetText())
    if not saved then
        print(P8BA6426E.L("|cffff0000[P8BA6426E]|r 当前专精识别失败，设置未保存"))
        refreshBurstSecondsBox()
        burstSecondsBox:ClearFocus()
        return
    end
    burstSecondsBox:SetText(tostring(seconds))
    burstSecondsBox:ClearFocus()
    print(
        P8BA6426E.L("|cff00ff88[P8BA6426E]|r 爆发自动关闭设置已保存：")
            .. (P8BA6426E.L(specName) .. (" · " .. (tostring(seconds) .. P8BA6426E.L(" 秒"))))
    )
end
burstSecondsBox:SetScript("OnEnterPressed", saveBurstSeconds)
burstSecondsBox:SetScript("OnEscapePressed", function(self)
    refreshBurstSecondsBox()
    self:ClearFocus()
end)
local burstSecondsSuffix = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
burstSecondsSuffix:SetPoint("LEFT", burstSecondsBox, "RIGHT", 6, 0)
burstSecondsSuffix:SetText(P8BA6426E.L("秒后自动关闭爆发"))
local saveBurstButton = P8BA6426E.CreateStyledButton(P8BA6426E.configFrame, P8BA6426E.L("保存"), 52, 22)
saveBurstButton:SetPoint("LEFT", burstSecondsSuffix, "RIGHT", 8, 0)
saveBurstButton:SetScript("OnClick", saveBurstSeconds)
refreshBurstSecondsBox()
local specInfoLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
specInfoLabel:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 24, -163)
specInfoLabel:SetText(P8BA6426E.L("职业: 检测中..."))
specInfoLabel:SetTextColor(0.65, 0.65, 0.65, 1)
local function refreshSpecInfo()
    local currentClass = P8BA6426E.DB.currentClass or "UNKNOWN"
    local currentSpecName = P8BA6426E.DB.currentSpecName or P8BA6426E.L("未知")
    specInfoLabel:SetText(P8BA6426E.L("职业: ") .. (currentClass .. (P8BA6426E.L("    天赋: ") .. currentSpecName)))
end
function P8BA6426E.RefreshBurstAutoCloseSettingUI()
    refreshSpecInfo()
    refreshBurstSecondsBox()
end
addDivider(P8BA6426E.configFrame, -185)
local autoTargetCheck = CreateFrame("CheckButton", nil, P8BA6426E.configFrame, "UICheckButtonTemplate")
autoTargetCheck:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 20, -199)
local function refreshAutoTargetSettingUI()
    autoTargetCheck:SetChecked(P8BA6426E.GetAutoTargetEnabled())
    autoTargetCheck:Enable()
end
P8BA6426E.RefreshAutoTargetSettingUI = refreshAutoTargetSettingUI
autoTargetCheck:SetScript("OnClick", function(self)
    P8BA6426E.SetAutoTargetEnabled(self:GetChecked() and true or false)
end)
refreshAutoTargetSettingUI()
local autoTargetLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoTargetLabel:SetPoint("LEFT", autoTargetCheck, "RIGHT", 4, 0)
autoTargetLabel:SetText(P8BA6426E.L("自动寻怪"))
local showLogoTextCheck = CreateFrame("CheckButton", nil, P8BA6426E.configFrame, "UICheckButtonTemplate")
showLogoTextCheck:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 20, -229)
showLogoTextCheck:SetScript("OnClick", function(self)
    P8BA6426E.DB.showLogoText = self:GetChecked()
    if P8BA6426E.RefreshStateLogo then
        P8BA6426E.RefreshStateLogo()
    end
end)
local showLogoTextLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showLogoTextLabel:SetPoint("LEFT", showLogoTextCheck, "RIGHT", 4, 0)
showLogoTextLabel:SetText(P8BA6426E.L("显示状态文字"))
local disableTextAlertCheck = CreateFrame("CheckButton", nil, P8BA6426E.configFrame, "UICheckButtonTemplate")
disableTextAlertCheck:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 260, -199)
disableTextAlertCheck:SetScript("OnClick", function(self)
    P8BA6426E.DB.disableTextAlert = self:GetChecked() or false
end)
local disableTextAlertLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
disableTextAlertLabel:SetPoint("LEFT", disableTextAlertCheck, "RIGHT", 4, 0)
disableTextAlertLabel:SetText(P8BA6426E.L("禁用文字提示"))
local disableSoundCheck = CreateFrame("CheckButton", nil, P8BA6426E.configFrame, "UICheckButtonTemplate")
disableSoundCheck:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 260, -229)
disableSoundCheck:SetScript("OnClick", function(self)
    P8BA6426E.DB.disableSound = self:GetChecked() or false
end)
local disableSoundLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
disableSoundLabel:SetPoint("LEFT", disableSoundCheck, "RIGHT", 4, 0)
disableSoundLabel:SetText(P8BA6426E.L("禁用音效"))
local refreshPixelSizeButton
P8BA6426E.configFrame:SetScript("OnShow", function()
    P8BA6426E.RefreshBurstAutoCloseSettingUI()
    if P8BA6426E.configFrame.masterUpdate then
        P8BA6426E.configFrame.masterUpdate()
    end
    if P8BA6426E.configFrame.burstUpdate then
        P8BA6426E.configFrame.burstUpdate()
    end
    if P8BA6426E.configFrame.aoeUpdate then
        P8BA6426E.configFrame.aoeUpdate()
    end
    refreshAutoTargetSettingUI()
    disableTextAlertCheck:SetChecked(P8BA6426E.DB.disableTextAlert)
    disableSoundCheck:SetChecked(P8BA6426E.DB.disableSound)
    showLogoTextCheck:SetChecked(P8BA6426E.DB.showLogoText ~= false)
    if P8BA6426E.UpdateLogoToggleBtn then
        P8BA6426E.UpdateLogoToggleBtn()
    end
    if refreshPixelSizeButton then
        refreshPixelSizeButton()
    end
end)
addDivider(P8BA6426E.configFrame, -323)
local INVITE_URL = "https://blizzardgames.cn/invite/5qn5JYBUX4R"
local inviteLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
inviteLabel:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 24, -330)
inviteLabel:SetText(P8BA6426E.L("P8BA6426E 社区永久邀请链接："))
local copyHintLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
copyHintLabel:SetPoint("TOPRIGHT", P8BA6426E.configFrame, "TOPRIGHT", -24, -330)
copyHintLabel:SetText(P8BA6426E.L("按 Ctrl+C 复制链接"))
copyHintLabel:SetTextColor(0, 1, 0.53, 1)
copyHintLabel:Hide()
local inviteBox = CreateFrame("EditBox", nil, P8BA6426E.configFrame, "InputBoxTemplate")
inviteBox:SetSize(382, 20)
inviteBox:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 24, -346)
inviteBox:SetAutoFocus(false)
inviteBox:SetText(INVITE_URL)
inviteBox:SetCursorPosition(0)
inviteBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
inviteBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)
inviteBox:SetScript("OnEditFocusLost", function()
    copyHintLabel:Hide()
end)
inviteBox:SetScript("OnHide", function(self)
    self:ClearFocus()
end)
local copyButton = P8BA6426E.CreateStyledButton(P8BA6426E.configFrame, P8BA6426E.L("复制"), 82, 20)
copyButton:SetPoint("LEFT", inviteBox, "RIGHT", 8, 0)
copyButton:SetScript("OnClick", function()
    inviteBox:SetText(INVITE_URL)
    inviteBox:SetFocus()
    inviteBox:HighlightText()
    copyHintLabel:Show()
end)
-- 宏编辑行：显示动作名、按键，点击“编辑”弹出宏编辑框
function P8BA6426E.CreateMacroRow(parent, actionKey, keyText, labelText, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(240, 22)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
    nameLabel:SetText(labelText)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetWidth(110)
    local keyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keyLabel:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
    keyLabel:SetText("|cffffcc00" .. (keyText .. "|r"))
    keyLabel:SetJustifyH("LEFT")
    keyLabel:SetWidth(70)
    local editButton = P8BA6426E.CreateStyledButton(row, P8BA6426E.L("编辑"), 50, 20)
    editButton:SetPoint("LEFT", keyLabel, "RIGHT", 4, 0)
    local function updateEnabled()
        if InCombatLockdown() then
            editButton:Disable()
        else
            editButton:Enable()
        end
    end
    row:RegisterEvent("PLAYER_REGEN_DISABLED")
    row:RegisterEvent("PLAYER_REGEN_ENABLED")
    row:SetScript("OnEvent", updateEnabled)
    updateEnabled()
    editButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            return
        end
        local editor = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        editor:SetSize(440, 280)
        editor:SetPoint("CENTER")
        editor:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        editor:SetBackdropColor(0.08, 0.08, 0.09, 1)
        editor:SetBackdropBorderColor(0.22, 0.22, 0.24, 1)
        editor:SetAlpha(1)
        editor:EnableMouse(true)
        editor:SetMovable(true)
        editor:RegisterForDrag("LeftButton")
        editor:SetScript("OnDragStart", editor.StartMoving)
        editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
        editor:SetFrameStrata("FULLSCREEN_DIALOG")
        editor:Show()
        P8BA6426E.BringToFront(editor)
        local editorTitle = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        editorTitle:SetPoint("TOP", editor, "TOP", 0, -18)
        editorTitle:SetText(P8BA6426E.L("编辑宏: ") .. (labelText .. (" (" .. (keyText .. ")"))))
        local editorScroll = CreateFrame("ScrollFrame", "MKLScroll" .. actionKey, editor, "UIPanelScrollFrameTemplate")
        editorScroll:SetSize(400, 130)
        editorScroll:SetPoint("TOP", editorTitle, "BOTTOM", 0, -20)
        local scrollBar = _G[editorScroll:GetName() .. "ScrollBar"]
        if scrollBar then
            local upButton = _G[scrollBar:GetName() .. "ScrollUpButton"]
            local downButton = _G[scrollBar:GetName() .. "ScrollDownButton"]
            if upButton then
                upButton:SetSize(16, 16)
                upButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            end
            if downButton then
                downButton:SetSize(16, 16)
                downButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            end
        end
        local macroBox = CreateFrame("EditBox", nil, editorScroll)
        macroBox:SetSize(380, 130)
        macroBox:SetMultiLine(true)
        macroBox:SetAutoFocus(true)
        macroBox:SetTextInsets(6, 6, 6, 6)
        macroBox:SetFontObject("ChatFontNormal")
        local hasUserMacro, macroText = P8BA6426E.GetUserMacro(actionKey)
        if not hasUserMacro then
            macroText = P8BA6426E.GetDefaultMacro(actionKey)
        end
        macroBox:SetText(macroText)
        local macroBg = macroBox:CreateTexture(nil, "BACKGROUND")
        macroBg:SetAllPoints()
        macroBg:SetColorTexture(0.05, 0.05, 0.06, 1)
        editorScroll:SetScrollChild(macroBox)
        editorScroll:EnableMouseWheel(true)
        editorScroll:SetScript("OnMouseWheel", function(self, delta)
            local scrollBar = _G[self:GetName() .. "ScrollBar"]
            if scrollBar then
                local step = -delta * 20
                scrollBar:SetValue(scrollBar:GetValue() + step)
            end
        end)
        local saveButton = P8BA6426E.CreateStyledButton(editor, P8BA6426E.L("保存"), 90, 24)
        saveButton:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 70, 18)
        saveButton:SetScript("OnClick", function()
            if InCombatLockdown() then
                return
            end
            local newMacro = macroBox:GetText() or ""
            if not P8BA6426E.SaveUserMacro(actionKey, newMacro) then
                return
            end
            P8BA6426E.CreateSecureButton(actionKey, keyText, newMacro)
            SaveBindings(GetCurrentBindingSet())
            editor:Hide()
        end)
        local cancelButton = P8BA6426E.CreateStyledButton(editor, P8BA6426E.L("取消"), 90, 24)
        cancelButton:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -70, 18)
        cancelButton:SetScript("OnClick", function()
            editor:Hide()
        end)
    end)
    return row
end
local pixelSizeButton = P8BA6426E.CreateStyledButton(P8BA6426E.configFrame, "", 214, 24)
pixelSizeButton:SetPoint("TOPLEFT", P8BA6426E.configFrame, "TOPLEFT", 260, -274)
refreshPixelSizeButton = function()
    local fontPixelRoute = P8BA6426E.FontPixelRoute
    if not fontPixelRoute then
        pixelSizeButton:Hide()
        return
    end
    pixelSizeButton:Show()
    local size = fontPixelRoute.GetPixelSize()
    pixelSizeButton:SetText(
        P8BA6426E.L(size == 4 and "像素格：4×4，切换至 1×1" or "像素格：1×1，切换至 4×4")
    )
    if InCombatLockdown() then
        pixelSizeButton:Disable()
    else
        pixelSizeButton:Enable()
    end
end
pixelSizeButton:SetScript("OnClick", function()
    local fontPixelRoute = P8BA6426E.FontPixelRoute
    if not fontPixelRoute then
        return
    end
    local nextSize = fontPixelRoute.GetPixelSize() == 4 and 1 or 4
    local ok, reason = fontPixelRoute.SetPixelSize(nextSize)
    if not ok then
        print(P8BA6426E.L("像素路线：") .. P8BA6426E.L(reason))
    end
    refreshPixelSizeButton()
end)
pixelSizeButton:RegisterEvent("PLAYER_REGEN_DISABLED")
pixelSizeButton:RegisterEvent("PLAYER_REGEN_ENABLED")
pixelSizeButton:SetScript("OnEvent", refreshPixelSizeButton)
refreshPixelSizeButton()
local resetButton = P8BA6426E.CreateStyledButton(P8BA6426E.configFrame, "恢复默认设置", 130, 24)
resetButton:SetPoint("BOTTOMLEFT", P8BA6426E.configFrame, "BOTTOMLEFT", 24, 46)
local function updateResetEnabled()
    if InCombatLockdown() then
        resetButton:Disable()
    else
        resetButton:Enable()
    end
end
resetButton:RegisterEvent("PLAYER_REGEN_DISABLED")
resetButton:RegisterEvent("PLAYER_REGEN_ENABLED")
resetButton:SetScript("OnEvent", updateResetEnabled)
updateResetEnabled()
resetButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        return
    end
    for actionKey, bindKey in pairs(P8BA6426E.ACTION_TO_KEY) do
        P8BA6426E.ClearUserMacro(actionKey)
        local macroText = P8BA6426E.GetDefaultMacro(actionKey)
        P8BA6426E.CreateSecureButton(actionKey, bindKey, macroText)
    end
    P8BA6426E.DB.masterKey = nil
    P8BA6426E.DB.burstKey = nil
    P8BA6426E.SaveBurstAutoCloseSeconds(0)
    P8BA6426E.DB.aoeKey = nil
    P8BA6426E.DB.autoTarget = false
    P8BA6426E.DB.healerAutoTarget = true
    P8BA6426E.DB.protectionPaladinAutoTarget = false
    P8BA6426E.DB.masterSwitch = true
    if P8BA6426E.FontPixelRoute then
        P8BA6426E.FontPixelRoute.SetPixelSize(4)
    end
    refreshPixelSizeButton()
    if P8BA6426E.UpdateMasterSwitchUI then
        P8BA6426E.UpdateMasterSwitchUI(true)
    end
    P8BA6426E.SetBurstSwitch(false)
    if P8BA6426E.configFrame.masterUpdate then
        P8BA6426E.configFrame.masterUpdate()
    end
    if P8BA6426E.configFrame.burstUpdate then
        P8BA6426E.configFrame.burstUpdate()
    end
    if P8BA6426E.configFrame.aoeUpdate then
        P8BA6426E.configFrame.aoeUpdate()
    end
    refreshBurstSecondsBox()
    refreshAutoTargetSettingUI()
    SaveBindings(GetCurrentBindingSet())
end)
local logoLabel = P8BA6426E.configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
logoLabel:SetText(P8BA6426E.L("logo"))
do
    local rowWidth = ((logoLabel:GetStringWidth() + 8) + 176) + 36
    logoLabel:SetPoint("BOTTOMLEFT", P8BA6426E.configFrame, "BOTTOMLEFT", (520 - rowWidth) / 2, 18)
end
local function createLogoSizeButton(text, logoSize, offsetX)
    local sizeButton = P8BA6426E.CreateStyledButton(P8BA6426E.configFrame, text, 44, 22)
    sizeButton:SetPoint("LEFT", logoLabel, "RIGHT", offsetX, 0)
    sizeButton:SetScript("OnClick", function()
        P8BA6426E.DB.logoSize = logoSize
        if P8BA6426E.RefreshStateLogo then
            P8BA6426E.RefreshStateLogo()
        end
    end)
    return sizeButton
end
createLogoSizeButton(P8BA6426E.L("小"), 32, 8)
createLogoSizeButton(P8BA6426E.L("中"), 48, 56)
createLogoSizeButton(P8BA6426E.L("大"), 64, 104)
local logoToggleButton = P8BA6426E.CreateStyledButton(P8BA6426E.configFrame, "", 44, 22)
logoToggleButton:SetPoint("LEFT", logoLabel, "RIGHT", 152, 0)
function P8BA6426E.UpdateLogoToggleBtn()
    logoToggleButton:SetText(P8BA6426E.DB.logoHidden and P8BA6426E.L("显示") or P8BA6426E.L("隐藏"))
end
logoToggleButton:SetScript("OnClick", function()
    P8BA6426E.DB.logoHidden = not P8BA6426E.DB.logoHidden
    if P8BA6426E.RefreshAllOverlayVisibility then
        P8BA6426E.RefreshAllOverlayVisibility()
    elseif P8BA6426E.stateLogo then
        P8BA6426E.stateLogo:SetShown(not P8BA6426E.DB.logoHidden)
    end
    P8BA6426E.UpdateLogoToggleBtn()
end)
P8BA6426E.UpdateLogoToggleBtn()
local cvarPanel = CreateFrame("Frame", nil, mainFrame)
cvarPanel:SetSize(520, 444)
cvarPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -76)
cvarPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 40)
cvarPanel:Hide()
local cvarTitle = cvarPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cvarTitle:SetPoint("TOP", cvarPanel, "TOP", 0, -14)
cvarTitle:SetText(P8BA6426E.L("游戏参数设置"))
cvarTitle:SetTextColor(0.7, 0.7, 0.7, 1)
local cvarSubtitle = cvarPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cvarSubtitle:SetPoint("TOP", cvarTitle, "BOTTOM", 0, -4)
cvarSubtitle:SetText(P8BA6426E.L("调整以下参数可优化 P8BA6426E 的运行效果，修改后立即生效"))
cvarSubtitle:SetTextColor(0.5, 0.5, 0.5, 1)
cvarSubtitle:SetFont(P8BA6426E.fontFile, 11, "")
local function createSliderRow(parent, labelText, minValue, maxValue, step, offsetY, _)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(480, 54)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, offsetY)
    local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    rowLabel:SetText(labelText)
    rowLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", rowLabel, "BOTTOMLEFT", 0, -6)
    slider:SetWidth(340)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local thumbTexture = slider:GetThumbTexture()
    if thumbTexture then
        thumbTexture:SetVertexColor(0.9, 0.75, 0.35, 1)
    end
    if slider.Low then
        slider.Low:SetText("")
    end
    if slider.High then
        slider.High:SetText("")
    end
    if slider.Text then
        slider.Text:SetText("")
    end
    local valueLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    valueLabel:SetTextColor(0.9, 0.75, 0.35, 1)
    return row, slider, valueLabel
end
local _sqwRow, sqwSlider, sqwValueLabel =
    createSliderRow(cvarPanel, "延迟容限 (SpellQueueWindow)", 0, 400, 10, -50, false)
sqwSlider:SetScript("OnValueChanged", function(_, value)
    local rounded = value - value % 10
    sqwValueLabel:SetText(tostring(rounded))
end)
local pendingSpellQueueWindow = nil
local sqwRetryFrame = CreateFrame("Frame")
sqwRetryFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local pending = pendingSpellQueueWindow
    pendingSpellQueueWindow = nil
    if pending == nil then
        return
    end
    local ok = pcall(C_CVar.SetCVar, "SpellQueueWindow", tostring(pending))
    if ok then
        print("|cff00ff88[P8BA6426E]|r " .. string.format(P8BA6426E.L("延迟容限已在脱战后设为 %d"), pending))
    else
        print("|cffff0000[P8BA6426E]|r " .. P8BA6426E.L("延迟容限修改失败"))
    end
    if P8BA6426E.RefreshCVarPanel then
        P8BA6426E.RefreshCVarPanel()
    end
end)
sqwSlider:SetScript("OnMouseUp", function(self)
    local rounded = self:GetValue() - self:GetValue() % 10
    if InCombatLockdown() then
        pendingSpellQueueWindow = rounded
        sqwRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        print(
            "|cffffcc00[P8BA6426E]|r "
                .. string.format(P8BA6426E.L("战斗中无法修改延迟容限，将在脱战后设为 %d"), rounded)
        )
        return
    end
    local ok = pcall(C_CVar.SetCVar, "SpellQueueWindow", tostring(rounded))
    if ok then
        print("|cff00ff88[P8BA6426E]|r " .. string.format(P8BA6426E.L("延迟容限已设为 %d"), rounded))
    else
        print("|cffff0000[P8BA6426E]|r " .. P8BA6426E.L("延迟容限修改失败"))
        self:SetValue(tonumber(C_CVar.GetCVar("SpellQueueWindow")) or 400)
    end
    if P8BA6426E.RefreshCVarPanel then
        P8BA6426E.RefreshCVarPanel()
    end
end)
local ROW_HEIGHT = 20
local COLUMNS = {
    { x = 0, w = 220, align = "LEFT" },
    { x = 230, w = 70, align = "RIGHT" },
    { x = 310, w = 70, align = "RIGHT" },
    {
        x = 390,
        w = 70,
        align = "LEFT",
    },
}
local function createTableRow(parent, rowIndex, isHeader)
    local offsetY = -(rowIndex - 1) * ROW_HEIGHT
    local cells = {}
    local fontObject = isHeader and "GameFontNormal" or "GameFontHighlightSmall"
    for i, column in ipairs(COLUMNS) do
        local cell = parent:CreateFontString(nil, "OVERLAY", fontObject)
        cell:SetPoint("TOPLEFT", parent, "TOPLEFT", column.x, offsetY)
        cell:SetSize(column.w, ROW_HEIGHT)
        cell:SetJustifyH(column.align)
        if isHeader then
            cell:SetTextColor(1, 0.85, 0.5, 1)
        else
            cell:SetTextColor(0.8, 0.8, 0.8, 1)
        end
        cells[i] = cell
    end
    return cells
end
local _className, classFile = UnitClass("player")
local defaultSQW = classFile == "EVOKER" and "50" or "400"
local CVAR_ROWS = {
    { cvar = "RenderScale", value = "1", name = "渲染倍数", type = "float" },
    { cvar = "Gamma", value = "1", name = "伽马值", type = "float" },
    { cvar = "Brightness", value = "50", name = "亮度", type = "percent" },
    { cvar = "Contrast", value = "50", name = "对比度", type = "percent" },
    { cvar = "nameplateShowEnemies", value = "1", name = "敌方姓名板", type = "bool" },
    { cvar = "nameplateShowEnemyMinions", value = "1", name = "敌方仆从姓名板", type = "bool" },
    { cvar = "nameplateShowEnemyMinus", value = "1", name = "敌方杂兵姓名板", type = "bool" },
    { cvar = "nameplateShowAll", value = "1", name = "显示所有姓名板", type = "bool" },
    { cvar = "screenEdgeFlash", value = "0", name = "屏幕边缘闪光", type = "bool" },
    { cvar = "doNotFlashLowHealthWarning", value = "1", name = "生命值过低时不闪烁屏幕", type = "bool" },
    { cvar = "cooldownViewerEnabled", value = "1", name = "冷却管理器显示", type = "bool" },
    { cvar = "ffxDeath", value = "0", name = "死亡全屏特效", type = "bool" },
    { cvar = "ffxGlow", value = "0", name = "全屏泛光", type = "bool" },
    { cvar = "ffxNether", value = "0", name = "虚空特效", type = "bool" },
    { cvar = "SpellQueueWindow", value = defaultSQW, name = "施法队列窗口（延迟容限）", type = "int" },
    { cvar = "ActionButtonUseKeyDown", value = "1", name = "按下按键时施法", type = "bool" },
}
local headerRow = CreateFrame("Frame", nil, cvarPanel)
headerRow:SetPoint("TOPLEFT", cvarPanel, "TOPLEFT", 20, -120)
headerRow:SetSize(480, ROW_HEIGHT)
local headerCells = createTableRow(headerRow, 1, true)
headerCells[1]:SetText(P8BA6426E.L("参数名称"))
headerCells[2]:SetText(P8BA6426E.L("当前值"))
headerCells[3]:SetText(P8BA6426E.L("目标值"))
headerCells[4]:SetText(P8BA6426E.L("状态"))
local headerLine = headerRow:CreateTexture(nil, "BACKGROUND")
headerLine:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 0, 0)
headerLine:SetSize(460, 1)
headerLine:SetColorTexture(0.3, 0.3, 0.3, 0.5)
local cvarScroll = CreateFrame("ScrollFrame", "P8BA6426ECVarEnvScroll", cvarPanel, "UIPanelScrollFrameTemplate")
cvarScroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -4)
cvarScroll:SetPoint("BOTTOMRIGHT", cvarPanel, "BOTTOMRIGHT", -30, 56)
local scrollBar = _G[cvarScroll:GetName() .. "ScrollBar"]
if scrollBar then
    local upButton = _G[scrollBar:GetName() .. "ScrollUpButton"]
    local downButton = _G[scrollBar:GetName() .. "ScrollDownButton"]
    if upButton then
        upButton:SetSize(16, 16)
        upButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    end
    if downButton then
        downButton:SetSize(16, 16)
        downButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    end
end
cvarScroll:EnableMouseWheel(true)
cvarScroll:SetScript("OnMouseWheel", function(self, delta)
    local scrollBar = _G[self:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:SetValue(scrollBar:GetValue() - delta * 20)
    end
end)
local rowCount = 1 + #CVAR_ROWS
local cvarRows = CreateFrame("Frame", nil, cvarScroll)
cvarRows:SetSize(460, rowCount * ROW_HEIGHT)
cvarScroll:SetScrollChild(cvarRows)
local rowCells = {}
for i = 1, rowCount, 1 do
    rowCells[i] = createTableRow(cvarRows, i, false)
end
local function formatCVarValue(value, kind)
    local num = tonumber(value)
    if kind == "bool" then
        if value == "0" or value == 0 then
            return "关"
        end
        if value == "1" or value == 1 then
            return "开"
        end
        return tostring(value)
    elseif kind == "percent" then
        if num then
            return string.format("%.2f", num / 100)
        end
        return tostring(value)
    elseif kind == "int" then
        if num then
            return string.format("%d", num)
        end
        return tostring(value)
    else
        if num then
            return string.format("%.2f", num)
        end
        return tostring(value)
    end
end
local function isCVarAtTarget(value, row)
    if value == nil or value == "" then
        return false
    end
    local num = tonumber(value)
    local target = tonumber(row.value)
    if num and target then
        if row.type == "percent" then
            local a = num > 1 and num / 100 or num
            local b = target > 1 and target / 100 or target
            return math.abs(a - b) < 0.001
        else
            return math.abs(num - target) < 0.001
        end
    end
    return tostring(value) == row.value
end
function P8BA6426E.UpdateCVarEnvInfo()
    local rowIndex = 1
    local scale = UIParent:GetEffectiveScale()
    local cells = rowCells[rowIndex]
    cells[1]:SetText(P8BA6426E.L("实际 UI 缩放"))
    cells[1]:SetTextColor(0.8, 0.8, 0.8, 1)
    cells[2]:SetText(string.format("%.3f", scale or 1))
    cells[2]:SetTextColor(0.5, 0.75, 1, 1)
    cells[3]:SetText("-")
    cells[3]:SetTextColor(0.5, 0.5, 0.5, 1)
    cells[4]:SetText(P8BA6426E.L("|cff888888只读|r"))
    rowIndex = rowIndex + 1
    for _, row in ipairs(CVAR_ROWS) do
        cells = rowCells[rowIndex]
        local current = C_CVar.GetCVar(row.cvar)
        if not current or current == "" then
            current = "N/A"
        end
        cells[1]:SetText(P8BA6426E.L(row.name))
        cells[1]:SetTextColor(0.8, 0.8, 0.8, 1)
        cells[2]:SetText(formatCVarValue(current, row.type))
        cells[2]:SetTextColor(0.8, 0.8, 0.8, 1)
        cells[3]:SetText(formatCVarValue(row.value, row.type))
        cells[3]:SetTextColor(0.5, 0.5, 0.5, 1)
        if isCVarAtTarget(current, row) then
            cells[4]:SetText(P8BA6426E.L("|cff00ff88安全|r"))
        else
            cells[4]:SetText(P8BA6426E.L("|cffff5555不安全|r"))
        end
        rowIndex = rowIndex + 1
    end
    for i = rowIndex, #rowCells, 1 do
        local cells = rowCells[i]
        cells[1]:SetText("")
        cells[2]:SetText("")
        cells[3]:SetText("")
        cells[4]:SetText("")
    end
end
local applyCVarsButton = P8BA6426E.CreateStyledButton(cvarPanel, "设置为推荐值", 140, 28)
applyCVarsButton:SetPoint("BOTTOM", cvarPanel, "BOTTOM", 0, 16)
applyCVarsButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        print("|cffff0000[P8BA6426E]|r 战斗中无法修改受保护的 CVar")
        return
    end
    local applied = {}
    for _, row in ipairs(CVAR_ROWS) do
        local ok = pcall(function()
            C_CVar.SetCVar(row.cvar, row.value)
        end)
        if ok then
            table.insert(applied, P8BA6426E.L(row.name) .. ("=" .. row.value))
        end
    end
    if #applied > 0 then
        print(P8BA6426E.L("|cff00ff88[P8BA6426E]|r 安全模式已应用：") .. table.concat(applied, ", "))
    end
    P8BA6426E.RefreshCVarPanel()
end)
function P8BA6426E.RefreshCVarPanel()
    local sqw = tonumber(C_CVar.GetCVar("SpellQueueWindow")) or 400
    sqwSlider:SetValue(sqw)
    sqwValueLabel:SetText(tostring(sqw - sqw % 10))
    if P8BA6426E.UpdateCVarEnvInfo then
        P8BA6426E.UpdateCVarEnvInfo()
    end
end
local macroHelpPanel = CreateFrame("Frame", nil, mainFrame)
macroHelpPanel:SetSize(520, 444)
macroHelpPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -76)
macroHelpPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 40)
macroHelpPanel:Hide()
local macroHelpTitle = macroHelpPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
macroHelpTitle:SetPoint("TOP", macroHelpPanel, "TOP", 0, -14)
macroHelpTitle:SetText(P8BA6426E.L("通用宏命令（可复制到游戏宏中使用）"))
macroHelpTitle:SetTextColor(0.7, 0.7, 0.7, 1)
local macroHelpSubtitle = macroHelpPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
macroHelpSubtitle:SetPoint("TOP", macroHelpTitle, "BOTTOM", 0, -4)
macroHelpSubtitle:SetText(P8BA6426E.L("在聊天框输入即可生效，也可绑定到按键"))
macroHelpSubtitle:SetTextColor(0.5, 0.5, 0.5, 1)
macroHelpSubtitle:SetFont(P8BA6426E.fontFile, 11, "")
local SLASH_COMMANDS = {
    { cmd = "/ON", desc = "总开关设置为开" },
    { cmd = "/OFF", desc = "总开关设置为关" },
    { cmd = "/bfk", desc = "爆发开关设置为开" },
    { cmd = "/bfg", desc = "爆发开关设置为关" },
    { cmd = "/dan", desc = "模式设置为单体" },
    { cmd = "/qun", desc = "强制群体：敌人数固定为5" },
    { cmd = "/AUTO", desc = "模式设置为自动" },
    { cmd = "/charu", desc = "临时关闭总开关0.5秒（插入技能用）" },
}
local commandRows = {}
for i, command in ipairs(SLASH_COMMANDS) do
    local offsetY = -60 - (i - 1) * 36
    local row = CreateFrame("Frame", nil, macroHelpPanel)
    row:SetSize(480, 30)
    row:SetPoint("TOP", macroHelpPanel, "TOP", 0, offsetY)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 1)
    row.bg = bg
    local border = row:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.22, 0.22, 0.24, 1)
    local cmdLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdLabel:SetPoint("LEFT", row, "LEFT", 12, 0)
    cmdLabel:SetText("|cffffcc00" .. (command.cmd .. "|r"))
    cmdLabel:SetJustifyH("LEFT")
    cmdLabel:SetWidth(100)
    local descText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("LEFT", cmdLabel, "RIGHT", 12, 0)
    row.descText = descText
    descText:SetJustifyH("LEFT")
    descText:SetTextColor(0.8, 0.8, 0.8, 1)
    table.insert(commandRows, row)
end
function P8BA6426E.RefreshMacroHelper()
    for i, row in ipairs(commandRows) do
        row.descText:SetText(P8BA6426E.L(SLASH_COMMANDS[i].desc))
    end
end
P8BA6426E.tabFrames[1] = P8BA6426E.configFrame
P8BA6426E.tabFrames[2] = P8BA6426E.talentPickerFrame
P8BA6426E.tabFrames[4] = cvarPanel
P8BA6426E.tabFrames[5] = macroHelpPanel
mainFrame:SetScript("OnShow", function()
    P8BA6426E.SwitchTab(1)
end)
