--[[
  ReadinessProducer —— 像素“技能就绪”生产器：技能可用(绿)/高亮(蓝)状态编码到像素
  原始文件：096638.lua（TOC 第 15 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local COLOR_ERROR_RED = CreateColor(0.87843137254902, 0.12549019607843, 0.12549019607843, 1)
local COLOR_READY_GREEN = CreateColor(0, 1, 0, 1)
local COLOR_FAULT_MAGENTA = CreateColor(1, 0, 1, 1)
local COLOR_BLACK = CreateColor(0, 0, 0, 1)
local COLOR_HIGHLIGHT_BLUE = CreateColor(0, 0, 1, 1)
local function setColor(glyph, color)
    glyph:SetTextColor(color:GetRGBA())
end
local function evaluateUsableColor(field, notReadyColor)
    notReadyColor = notReadyColor or COLOR_ERROR_RED
    local spellID = assert(field.spellID)
    assert(P8BA6426E.IsSpellUsable, "技能可用前置接口不可用")
    if field.actor == "pet" then
        assert(field.basePolicy == "learned_usable", "宠物就绪策略无效")
        local petSpellID, slot, bank = P8BA6426E.FontPixelSources.ResolvePetSpell(field.spellIDs)
        if not petSpellID then
            return notReadyColor
        end
        assert(C_SpellBook.IsSpellBookItemUsable, "宠物技能可用接口不可用")
        local usable = C_SpellBook.IsSpellBookItemUsable(slot, bank)
        if not (issecretvalue and issecretvalue(usable)) then
            assert(type(usable) == "boolean", "宠物技能可用状态不可读")
        end
        return C_CurveUtil.EvaluateColorFromBoolean(usable, COLOR_READY_GREEN, notReadyColor)
    end
    if field.basePolicy == "learned_usable" then
        assert(C_SpellBook and C_SpellBook.IsSpellKnown, "严格技能学习接口不可用")
        assert(type(field.spellIDs) == "table" and #field.spellIDs > 0, "技能等级候选缺失")
        local learnedID
        for _, spellID in ipairs(field.spellIDs) do
            local known = C_SpellBook.IsSpellKnown(spellID)
            assert(
                not (issecretvalue and issecretvalue(known)) and type(known) == "boolean",
                "严格技能学习状态不可读"
            )
            if known then
                learnedID = spellID
                break
            end
        end
        if not learnedID then
            return notReadyColor
        end
        spellID = learnedID
    else
        assert(field.basePolicy == "usable_only", "技能可用前置策略无效")
    end
    local usable = P8BA6426E.IsSpellUsable(spellID)
    if not (issecretvalue and issecretvalue(usable)) then
        assert(type(usable) == "boolean", "技能可用状态不可读")
    end
    return C_CurveUtil.EvaluateColorFromBoolean(usable, COLOR_READY_GREEN, notReadyColor)
end
local function evaluateHighlightColor(highlight)
    local spellID = assert(highlight.spellID)
    if highlight.queryPolicy == "highest_learned" then
        spellID = nil
        for _, candidateID in ipairs(assert(highlight.spellIDs)) do
            local known = C_SpellBook.IsSpellKnown(candidateID)
            assert(
                not (issecretvalue and issecretvalue(known)) and type(known) == "boolean",
                "高亮学习状态不可读"
            )
            if known then
                spellID = candidateID
                break
            end
        end
        if not spellID then
            return COLOR_BLACK
        end
    end
    assert(C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed, "技能高亮接口不可用")
    local overlayed = C_SpellActivationOverlay.IsSpellOverlayed(spellID)
    if highlight.queryPolicy == "highest_learned" then
        assert(
            not (issecretvalue and issecretvalue(overlayed)) and type(overlayed) == "boolean",
            "无限服高亮不可读"
        )
    elseif not (issecretvalue and issecretvalue(overlayed)) then
        assert(type(overlayed) == "boolean", "技能高亮不是布尔值")
    end
    return C_CurveUtil.EvaluateColorFromBoolean(overlayed, COLOR_HIGHLIGHT_BLUE, COLOR_BLACK)
end
local function usableGreen(field)
    local color = evaluateUsableColor(field, COLOR_BLACK)
    local _r, green = color:GetRGB()
    return green
end
local function highlightBlue(highlight)
    local color = evaluateHighlightColor(highlight)
    local _r, _g, blue = color:GetRGB()
    return blue
end
-- 技能就绪生产器：G 通道=可用，B 通道=技能高亮（触发）
function P8BA6426E.CreateFontPixelReadinessProducer(params)
    local contract = assert(params.contract)
    assert(params.specID)
    assert(params.frame)
    local newCell = assert(params.newCell)
    assert(params.newGlyph)
    local producer = { errors = {} }
    local entries = {}
    local active = false
    local function renderSkillStatusGB(entry)
        local green, blue = 0.37647058823529, 0.37647058823529
        local ok, usableG = pcall(usableGreen, entry.field)
        producer.errors[entry.field.key .. ":usable"] = not ok and tostring(usableG) or nil
        if ok then
            green = usableG
        end
        local highlight = entry.field.highlight
        local ok, highlightB = pcall(highlightBlue, highlight)
        producer.errors[highlight.key] = not ok and tostring(highlightB) or nil
        if ok then
            blue = highlightB
        end
        entry.glyph:SetTextColor(0.50196078431373, green, blue, 1)
    end
    local function setEntryError(entry, err)
        producer.errors[entry.field.key] = err and tostring(err) or nil
        if params.onFieldError then
            pcall(params.onFieldError, entry.row, entry.field.key, err)
        end
    end
    for _, internalField in ipairs(contract.internalFields or {}) do
        if internalField.kind == "ready_base" then
            local field = assert(internalField.field)
            assert(field.kind == "ready_base" and internalField.rows == 1, "技能前置格声明无效")
            local row = assert(internalField.row)
            local ok, result = pcall(newCell, row, 0, 0, 0)
            local entry = {
                field = field,
                row = row,
                glyph = ok and result or nil,
                constructionError = not ok and result or nil,
            }
            entries[#entries + 1] = entry
            if not ok then
                setEntryError(entry, result)
            end
        end
    end
    function producer.Refresh()
        if not active then
            return false
        end
        for _, entry in ipairs(entries) do
            local field = entry.field
            if entry.constructionError then
                setEntryError(entry, entry.constructionError)
            else
                local isGBEncoding = field.statusEncoding == "skill_status_gb_v1"
                local ok, colorOrNil =
                    pcall(isGBEncoding and renderSkillStatusGB or evaluateUsableColor, isGBEncoding and entry or field)
                local err = nil
                if not ok then
                    err = colorOrNil
                elseif not isGBEncoding then
                    local ok, result = pcall(setColor, entry.glyph, colorOrNil)
                    if not ok then
                        err = result
                    end
                end
                if err then
                    pcall(setColor, entry.glyph, COLOR_FAULT_MAGENTA)
                    setEntryError(entry, err)
                    if params.onError then
                        pcall(params.onError, field.key, err)
                    end
                else
                    setEntryError(entry, nil)
                end
            end
        end
        return true
    end
    function producer.Enable()
        active = true
        producer.Refresh()
        return true
    end
    function producer.Disable()
        active = false
    end
    function producer.Reset()
        for errorKey in pairs(producer.errors) do
            producer.errors[errorKey] = nil
        end
    end
    return producer
end
