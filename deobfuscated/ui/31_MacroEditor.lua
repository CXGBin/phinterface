--[[
  MacroEditor —— 宏编辑标签页：列出各动作按键与宏，支持编辑/恢复默认
  原始文件：e2be40.lua（TOC 第 31 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E.macroEditorFrame = CreateFrame("Frame", nil, P8BA6426E.mainFrame)
P8BA6426E.macroEditorFrame:SetSize(520, 444)
P8BA6426E.macroEditorFrame:SetPoint("TOPLEFT", P8BA6426E.mainFrame, "TOPLEFT", 10, -76)
P8BA6426E.macroEditorFrame:SetPoint("BOTTOMRIGHT", P8BA6426E.mainFrame, "BOTTOMRIGHT", -10, 40)
P8BA6426E.macroEditorFrame:Hide()
local editorScroll =
    CreateFrame("ScrollFrame", "P8BA6426EMacroEditorScroll", P8BA6426E.macroEditorFrame, "UIPanelScrollFrameTemplate")
editorScroll:SetPoint("TOPLEFT", P8BA6426E.macroEditorFrame, "TOPLEFT", 0, 0)
editorScroll:SetPoint("BOTTOMRIGHT", P8BA6426E.macroEditorFrame, "BOTTOMRIGHT", -26, 0)
editorScroll:EnableMouseWheel(true)
editorScroll:SetScript("OnMouseWheel", function(self, delta)
    local scrollBar = _G[self:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:SetValue(scrollBar:GetValue() - delta * 48)
    end
end)
local rowContainer = CreateFrame("Frame", nil, editorScroll)
rowContainer:SetSize(480, 36)
editorScroll:SetScrollChild(rowContainer)
local rows = {}
ShowMacroEditor = function()
    for _, row in ipairs(rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(rows)
    local actionOrder = (P8BA6426E.classData and P8BA6426E.classData.macroOrder) or {}
    if #actionOrder == 0 then
        for actionKey, _ in pairs(P8BA6426E.ACTION_TO_KEY) do
            table.insert(actionOrder, actionKey)
        end
        table.sort(actionOrder, function(a, b)
            local idA = tonumber(a:match("spell_(%d+)")) or 0
            local idB = tonumber(b:match("spell_(%d+)")) or 0
            return idA < idB
        end)
    end
    local topY = -20
    local ROW_HEIGHT = 24
    local LEFT_X = 24
    local RIGHT_X = 260
    local column = 0
    local rowIndex = 0
    for _, actionKey in ipairs(actionOrder) do
        local bindKey = P8BA6426E.ACTION_TO_KEY[actionKey]
        local label = P8BA6426E.LocalizeActionLabel(actionKey, P8BA6426E.ACTION_LABELS[actionKey] or actionKey)
        if bindKey then
            local x = (column == 0) and LEFT_X or RIGHT_X
            local y = topY - rowIndex * ROW_HEIGHT
            local row = P8BA6426E.CreateMacroRow(rowContainer, actionKey, bindKey, label, x, y)
            table.insert(rows, row)
            column = column + 1
            if column >= 2 then
                column = 0
                rowIndex = rowIndex + 1
            end
        end
    end
    local rowCount = rowIndex
    if column > 0 then
        rowCount = rowCount + 1
    end
    rowContainer:SetHeight(36 + rowCount * ROW_HEIGHT)
    editorScroll:SetVerticalScroll(0)
end
P8BA6426E.tabFrames[3] = P8BA6426E.macroEditorFrame
local resetButton = P8BA6426E.CreateStyledButton(P8BA6426E.macroEditorFrame, P8BA6426E.L("恢复默认"), 100, 24)
resetButton:SetPoint("BOTTOMLEFT", P8BA6426E.macroEditorFrame, "BOTTOMLEFT", 30, 10)
local function updateEnabled()
    if InCombatLockdown() then
        resetButton:Disable()
    else
        resetButton:Enable()
    end
end
resetButton:RegisterEvent("PLAYER_REGEN_DISABLED")
resetButton:RegisterEvent("PLAYER_REGEN_ENABLED")
resetButton:SetScript("OnEvent", updateEnabled)
updateEnabled()
resetButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        return
    end
    for actionKey, bindKey in pairs(P8BA6426E.ACTION_TO_KEY) do
        P8BA6426E.ClearUserMacro(actionKey)
        local macroText = P8BA6426E.GetDefaultMacro and P8BA6426E.GetDefaultMacro(actionKey)
        if macroText then
            P8BA6426E.CreateSecureButton(actionKey, bindKey, macroText)
        end
    end
    SaveBindings(GetCurrentBindingSet())
    ShowMacroEditor()
    print(P8BA6426E.L("|cff00ff00[P8BA6426E]|r 全部宏已恢复官方默认"))
end)
