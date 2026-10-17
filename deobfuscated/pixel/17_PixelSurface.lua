--[[
  PixelSurface —— 像素表面：创建 1 像素宽的色块列、单像素字体字形、故障回执行（校验和）
  原始文件：426da6.lua（TOC 第 17 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local GLYPH_FONT_SIZE = 15
local CHECKSUM_MODULUS = 16777215
-- 像素表面：每个“单元格”是 1×1 纹理，按物理行垂直排列；字段异常会记录到 errors，并以位图+校验和写入尾部回执行
function P8BA6426E.CreatePixelSurface(params)
    local frame = assert(params.frame)
    local height = assert(params.height)
    local receiptStart = assert(params.receiptStart)
    local receiptWordCount = assert(params.receiptWordCount)
    assert(
        params.receiptCount == receiptWordCount + 1 and receiptStart + receiptWordCount < height,
        "像素故障回执布局无效"
    )
    local surface = { frame = frame, errors = {}, fontLoaded = false }
    local cellCounter, glyphFont = 0, nil
    local fontPath = "Interface\\AddOns\\" .. (assert(params.addonName) .. "\\ArmsColorProbe.ttf")
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0, 0, 0, 1)
    function surface.SetFieldError(row, key, err)
        assert(type(row) == "number" and (row % 1 == 0 and (row >= 0 and row < height)), "像素故障行超出布局")
        local rowErrors = surface.errors[row]
        if err ~= nil then
            if not rowErrors then
                rowErrors = {}
                surface.errors[row] = rowErrors
            end
            rowErrors[key] = tostring(err)
        elseif rowErrors then
            rowErrors[key] = nil
            if next(rowErrors) == nil then
                surface.errors[row] = nil
            end
        end
    end
    function surface.Run(row, key, fn)
        local ok, result = pcall(fn)
        surface.SetFieldError(row, key, not ok and result or nil)
        return ok, result
    end
    function surface.NewCell(row, r, g, b, parent)
        assert(type(row) == "number" and (row % 1 == 0 and (row >= 0 and row < height)), "像素物理行超出布局")
        cellCounter = cellCounter + 1
        local cellKey = "texture:" .. cellCounter
        local cellFrame, cellTexture, buildError
        local cell = { row = row }
        local function ensureTexture()
            assert(not buildError, buildError)
            if cellTexture then
                return
            end
            local ok, result = pcall(function()
                if not cellFrame then
                    local newFrame = CreateFrame("Frame", nil, parent or frame)
                    newFrame:SetSize(1, 1)
                    newFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -row)
                    cellFrame = newFrame
                end
                local tex = cellFrame:CreateTexture(nil, "OVERLAY")
                tex:SetAllPoints(cellFrame)
                tex:SetColorTexture(1, 1, 1, 1)
                cellTexture = tex
            end)
            if not ok then
                buildError = tostring(result)
                error(result)
            end
        end
        function cell.GetParent(_)
            return assert(cellFrame, "像素单格容器尚未建立")
        end
        function cell.SetTextColor(_, r, g, b, a)
            local ok, result = pcall(function()
                ensureTexture()
                cellTexture:SetVertexColor(r, g, b, a)
            end)
            surface.SetFieldError(row, cellKey .. ":color", not ok and result or nil)
            return ok
        end
        function cell.SetAlpha(_, alpha)
            local ok, result = pcall(function()
                ensureTexture()
                cellTexture:SetAlpha(alpha)
            end)
            surface.SetFieldError(row, cellKey .. ":alpha", not ok and result or nil)
            return ok
        end
        cell:SetTextColor(r / 255, g / 255, b / 255, 1)
        return cell
    end
    local function isFontBound(fontObject)
        local path, size = fontObject:GetFont()
        return type(path) == "string"
            and (
                (path:lower()):gsub("/", "\\") == fontPath:lower()
                and (type(size) == "number" and math.abs(size - GLYPH_FONT_SIZE) < 0.001)
            )
    end
    function surface.NewGlyph(parent, row)
        if not glyphFont then
            local fontObject = CreateFont(assert(params.fontName))
            assert(
                fontObject:SetFont(fontPath, GLYPH_FONT_SIZE, "") ~= false and isFontBound(fontObject),
                "单像素方块字体加载失败"
            )
            glyphFont = fontObject
            surface.fontLoaded = true
        end
        local glyph = parent:CreateFontString(nil, "OVERLAY")
        glyph:SetFontObject(glyphFont)
        assert(isFontBound(glyph), "单像素方块字体绑定失败")
        glyph:SetSize(GLYPH_FONT_SIZE, GLYPH_FONT_SIZE)
        glyph:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0.25 - row)
        glyph:SetJustifyH("LEFT")
        glyph:SetJustifyV("TOP")
        glyph:SetWordWrap(false)
        glyph:SetText("A")
        return glyph
    end
    local receiptCells = {}
    for i = 1, receiptWordCount + 1, 1 do
        receiptCells[i] = surface.NewCell((receiptStart + i) - 1, 0, 0, 0)
    end
    -- 把故障行位图（每 24 行一个字）及校验和写入回执单元格
    function surface.FlushReceipts()
        local receiptWords = {}
        for i = 1, receiptWordCount, 1 do
            receiptWords[i] = 0
        end
        for errorRow in pairs(surface.errors) do
            if errorRow < receiptStart then
                local wordIndex = math.floor(errorRow / 24) + 1
                receiptWords[wordIndex] = receiptWords[wordIndex] + 2 ^ (errorRow % 24)
            end
        end
        local checksum, allPainted = 5940570, true
        for i = 1, receiptWordCount, 1 do
            local word = receiptWords[i]
            checksum = (checksum + i * word) % CHECKSUM_MODULUS
            local painted = receiptCells[i]:SetTextColor(
                math.floor(word / 65536) / 255,
                (math.floor(word / 256) % 256) / 255,
                (word % 256) / 255,
                1
            )
            allPainted = painted and allPainted
        end
        if not allPainted then
            checksum = CHECKSUM_MODULUS
        end
        local checksumPainted = receiptCells[receiptWordCount + 1]:SetTextColor(
            math.floor(checksum / 65536) / 255,
            (math.floor(checksum / 256) % 256) / 255,
            (checksum % 256) / 255,
            1
        )
        return allPainted and checksumPainted
    end
    return surface
end
