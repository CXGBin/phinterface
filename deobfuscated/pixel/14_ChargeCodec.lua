--[[
  ChargeCodec —— 像素充能编解码：用专用字体（FontPixelCharge0-9）把充能层数/恢复进度画成像素
  原始文件：d97326.lua（TOC 第 14 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local GLYPH_FONT_SIZE = 15
local MAX_RED_DIGIT = 9
local RED_STEP = 26
local COLOR_ERROR_RED = CreateColor(0.87843137254902, 0.12549019607843, 0.12549019607843, 1)
local COLOR_UNAVAILABLE = CreateColor(0.94509803921569, 0.67843137254902, 0.14509803921569, 1)
local COLOR_FAULT = CreateColor(0.98039215686275, 0.12549019607843, 0.12549019607843, 1)
local function isFontBound(fontObject, expectedPath)
    local path, size = fontObject:GetFont()
    return type(path) == "string"
        and (
            (path:lower()):gsub("/", "\\") == expectedPath:lower()
            and (type(size) == "number" and math.abs(size - GLYPH_FONT_SIZE) < 0.001)
        )
end
local function setColor(glyph, color)
    glyph:SetTextColor(color:GetRGBA())
end
-- 充能编解码：11 套掩码字体分别把数字 0-9/无效 画成不同红色，配合恢复进度曲线写入 G/B 通道
function P8BA6426E.CreateFontPixelChargeCodec(params)
    local frame, row = assert(params.frame), assert(params.row)
    local addonName, specID = assert(params.addonName), assert(params.specID)
    local base = params.base or (assert(params.newCell))(row, 0, 0, 0)
    local clipFrame = CreateFrame("Frame", nil, frame)
    clipFrame:SetSize(3, 3)
    clipFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1 - row)
    clipFrame:SetFrameLevel((base:GetParent()):GetFrameLevel() + 1)
    clipFrame:SetClipsChildren(true)
    local fontsByIndex, pathsByIndex, glyphs = {}, {}, {}
    local function getMaskFont(index)
        if fontsByIndex[index] then
            return fontsByIndex[index], pathsByIndex[index]
        end
        local suffix = index == 11 and "Invalid" or tostring(index - 1)
        local path = "Interface\\AddOns\\" .. (addonName .. ("\\FontPixelCharge" .. (suffix .. ".ttf")))
        local font = CreateFont("P8BA6426ECharge" .. (specID .. ("Row" .. (row .. ("Mask" .. suffix)))))
        assert(
            font and (font:SetFont(path, GLYPH_FONT_SIZE, "") ~= false and isFontBound(font, path)),
            "充能遮罩字体加载失败：" .. suffix
        )
        fontsByIndex[index], pathsByIndex[index] = font, path
        return font, path
    end
    local function addGlyph(fontIndex, position, red)
        local fontObject, path = getMaskFont(fontIndex)
        local glyph = clipFrame:CreateFontString(nil, "OVERLAY")
        glyph:SetFontObject(fontObject)
        assert(isFontBound(glyph, path), "充能遮罩字形绑定失败")
        glyph:SetSize(GLYPH_FONT_SIZE * 32, GLYPH_FONT_SIZE)
        glyph:SetJustifyH("LEFT")
        glyph:SetJustifyV("TOP")
        glyph:SetWordWrap(false)
        glyph:SetText("")
        glyphs[#glyphs + 1] = { glyph = glyph, position = position, red = red, invalid = red == nil }
        return glyph
    end
    for i = 0, 9, 1 do
        addGlyph(i + 1, 0, i <= MAX_RED_DIGIT and i * RED_STEP or nil)
    end
    addGlyph(11, 0, nil)
    for i = 1, 11, 1 do
        addGlyph(i, 1, nil)
    end
    local measureLabel = frame:CreateFontString(nil, "OVERLAY")
    measureLabel:SetFontObject(getMaskFont(1))
    measureLabel:SetTextColor(0, 0, 0, 0)
    local recoveryCurve = C_CurveUtil.CreateColorCurve()
    recoveryCurve:SetType(Enum.LuaCurveType.Linear)
    recoveryCurve:AddPoint(0, CreateColor(0, 0, 0, 1))
    recoveryCurve:AddPoint(2.55, CreateColor(0, 1, 0, 1))
    recoveryCurve:AddPoint(25.5, CreateColor(0, 1, 0.99607843137255, 1))
    recoveryCurve:AddPoint(255, CreateColor(0, 0, 0.99607843137255, 1))
    recoveryCurve:AddPoint(765, CreateColor(0, 0, 0.12549019607843, 1))
    local codec = { base = base, glyphs = glyphs }
    function codec.Rescale()
        measureLabel:SetText("00")
        local width2 = measureLabel:GetStringWidth()
        measureLabel:SetText("0")
        local width1 = measureLabel:GetStringWidth()
        measureLabel:SetText("")
        local advance = math.ceil((width2 - width1) - 0.001)
        assert(advance > 0 and advance < GLYPH_FONT_SIZE, "充能字形字距无效")
        for _, entry in ipairs(glyphs) do
            local glyph = entry.glyph
            glyph:ClearAllPoints()
            glyph:SetPoint("TOPLEFT", frame, "TOPLEFT", -entry.position * advance, 0.25 - row)
        end
        return true
    end
    local function clearGlyphs()
        pcall(measureLabel.SetText, measureLabel, "")
        for _, entry in ipairs(glyphs) do
            entry.glyph:SetText("")
        end
    end
    function codec.Fail()
        clearGlyphs()
        setColor(base, COLOR_FAULT)
        return false
    end
    function codec.Reset()
        clearGlyphs()
        setColor(base, COLOR_ERROR_RED)
        return false
    end
    function codec.Update(countText, recoveryDuration, sourceReadable, countReadable, recoveryReadable)
        if countReadable == false then
            clearGlyphs()
            setColor(base, COLOR_UNAVAILABLE)
            return false
        end
        if sourceReadable ~= true or countReadable ~= true then
            return codec.Reset()
        end
        local green, blue = 0, 0
        codec.recoveryError = nil
        if recoveryReadable == false then
            green, blue = 0.12549019607843, 0.12549019607843
            codec.recoveryError = "充能恢复时间接口不可读"
        elseif recoveryDuration then
            local ok, g, b = pcall(function()
                local color = recoveryDuration:EvaluateRemainingDuration(recoveryCurve)
                local _r, gg, bb = color:GetRGB()
                return gg, bb
            end)
            if ok then
                green, blue = g, b
            else
                green, blue = 0.12549019607843, 0.12549019607843
                codec.recoveryError = tostring(g)
            end
        end
        setColor(base, COLOR_ERROR_RED)
        if not (issecretvalue and issecretvalue(countText)) and (countText == nil or countText == "") then
            countText = "0"
        end
        for _, entry in ipairs(glyphs) do
            local glyph = entry.glyph
            if entry.invalid then
                setColor(glyph, COLOR_FAULT)
            else
                glyph:SetTextColor(entry.red / 255, green, blue, 1)
            end
            glyph:SetFormattedText("%s", countText)
        end
        return true
    end
    codec.Rescale()
    codec.Reset()
    return codec
end
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("charge.build", "sampled", function()
        return P8BA6426E.CreateFontPixelChargeCodec
    end, function(fn)
        P8BA6426E.CreateFontPixelChargeCodec = fn
    end)
end
