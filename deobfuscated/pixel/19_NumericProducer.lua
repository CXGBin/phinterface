--[[
  NumericProducer —— 像素“数字字段”生产器：冷却秒数、充能、光环剩余时间/层数编码为颜色
  原始文件：d825ba.lua（TOC 第 19 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local COLOR_BLACK = CreateColor(0, 0, 0, 1)
local COLOR_ERROR_RED = CreateColor(0.87843137254902, 0.12549019607843, 0.12549019607843, 1)
local COLOR_UNAVAILABLE = CreateColor(0.94509803921569, 0.67843137254902, 0.14509803921569, 1)
local COLOR_TRANSPARENT = CreateColor(0, 0, 0, 0)
local COLOR_ABSENT_BLUE = CreateColor(0.12549019607843, 0.37647058823529, 0.87843137254902, 1)
local COLOR_PRESENT_GRAY = CreateColor(0.2, 0.2, 0.2, 1)
local fontPixelSources = assert(P8BA6426E.FontPixelSources)
local UNLEARNED_IGNORE = { traitNode = true }
local function setColor(glyph, color)
    glyph:SetTextColor(color:GetRGBA())
end
local function stackColorMarkup(stacks)
    if stacks > 255 then
        return "|cFFFF00FFA|r"
    end
    local low = (stacks % 32) * 8
    local high = 64 + math.floor(stacks / 32) * 8
    return string.format("|cFF%02X%02X%02XA|r", low, 255 - low, high)
end
local function createTimeCurve(extended)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, COLOR_BLACK)
    curve:AddPoint(2.55, CreateColor(1, 0, 0, 1))
    curve:AddPoint(25.5, CreateColor(1, 1, 0, 1))
    curve:AddPoint(255, CreateColor(1, 1, 1, 1))
    curve:AddPoint(510, CreateColor(0, 1, 1, 1))
    curve:AddPoint(765, CreateColor(0, 0, 1, 1))
    if extended then
        curve:AddPoint(3305, CreateColor(0, 0, 0.003921568627451, 1))
        curve:AddPoint(18605, CreateColor(1, 0, 0.003921568627451, 1))
    end
    return curve
end
local function createFormatters()
    assert(
        C_CurveUtil and (C_CurveUtil.CreateColorCurve and (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter)),
        "原生数值格式接口不可用"
    )
    local timeCurve = createTimeCurve(false)
    local presenceFormatter = C_StringUtil.CreateNumericRuleFormatter()
    presenceFormatter:SetBreakpoints({
        { threshold = 0, format = "A", step = 1, rounding = Enum.NumericRuleFormatRounding.Nearest },
    })
    local stackFormatter = C_StringUtil.CreateNumericRuleFormatter()
    local breakpoints = {}
    for threshold = 0, 255, 1 do
        breakpoints[#breakpoints + 1] = {
            threshold = threshold,
            format = stackColorMarkup(threshold),
            step = 1,
            rounding = Enum.NumericRuleFormatRounding.Nearest,
        }
    end
    breakpoints[#breakpoints + 1] =
        { threshold = 256, format = stackColorMarkup(256), step = 1, rounding = Enum.NumericRuleFormatRounding.Nearest }
    stackFormatter:SetBreakpoints(breakpoints)
    return timeCurve, presenceFormatter, stackFormatter
end
local function isUnlearned(field, prepared)
    return fontPixelSources.IsUnlearned(field, UNLEARNED_IGNORE, prepared)
end
local function isMouseoverRelationValid(field)
    if not UnitExists("mouseover") or UnitIsDeadOrGhost("mouseover") then
        return false
    end
    if field.unitRelation == "help" then
        return UnitCanAssist("player", "mouseover")
    end
    return UnitCanAttack("player", "mouseover")
end
-- 数字字段生产器：利用暴雪的 DurationObject/NumericRuleFormatter 与颜色曲线，把“秒数/层数”直接渲染为颜色（绕过 secret value 限制）
function P8BA6426E.CreateFontPixelNumericProducer(params)
    local contract = assert(params.contract)
    local frame = assert(params.frame)
    local newCell = assert(params.newCell)
    local newGlyph = assert(params.newGlyph)
    local addonName = assert(params.addonName)
    local ok, timeCurve, presenceFormatter, stackFormatter = pcall(createFormatters)
    local producer = { errors = {} }
    local function setFieldError(row, key, err)
        producer.errors[key] = err and tostring(err) or nil
        if params.onFieldError then
            pcall(params.onFieldError, row, key, err)
        end
    end
    if not ok then
        local classicChargeIndexes = {}
        local failedFields = {}
        local function registerFailed(spec)
            local field = assert(spec.field, "数字字段缺少来源声明")
            local row = assert(spec.row, "数字字段缺少物理行")
            local owner = field.key or field.ruleKey
            assert(owner, "数字字段缺少业务身份")
            setFieldError(row, owner, timeCurve)
            failedFields[#failedFields + 1] = { row = row, owner = owner }
            if spec.classicIndex then
                classicChargeIndexes[spec.classicIndex + 1] = true
            end
        end
        for _, nativeField in ipairs(contract.nativeFields or {}) do
            registerFailed(nativeField)
        end
        for _, internalField in ipairs(contract.internalFields or {}) do
            if internalField.kind == "cd_seconds" then
                registerFailed(internalField)
            end
        end
        for _, chargeField in ipairs(contract.chargeFields or {}) do
            registerFailed(chargeField)
        end
        for _, textField in ipairs(assert(contract.textFields)) do
            registerFailed(textField)
        end
        function producer.Rescale()
            return true
        end
        function producer.HasGeometryError()
            return false
        end
        function producer.UpdateClassicCharge(classicIndex)
            return classicChargeIndexes[classicIndex] == true
        end
        function producer.Refresh()
            for _, failed in ipairs(failedFields) do
                setFieldError(failed.row, failed.owner, timeCurve)
            end
            return true
        end
        function producer.Enable()
            for _, failed in ipairs(failedFields) do
                setFieldError(failed.row, failed.owner, timeCurve)
            end
            return true
        end
        function producer.Disable() end
        function producer.Reset() end
        return producer
    end
    local extendedTimeCurve
    local function getTimeCurve(field)
        local timeEncoding = field.timeEncoding
        if timeEncoding == nil or timeEncoding == "segmented_seconds_765_v1" then
            return timeCurve
        end
        assert(timeEncoding == "extended_seconds_18605_v1", "未知时间编码")
        if not extendedTimeCurve then
            extendedTimeCurve = createTimeCurve(true)
        end
        return extendedTimeCurve
    end
    local cooldownEntries, chargeEntries, classicChargeEntries, auraGroups = {}, {}, {}, {}
    local handledKeys = {}
    local auraGroupByIdentity = {}
    local active = false
    function producer.Rescale()
        for _, chargeEntry in ipairs(chargeEntries) do
            if chargeEntry.codec then
                local ok, result = pcall(chargeEntry.codec.Rescale)
                chargeEntry.geometryError = not ok and tostring(result) or nil
                if not ok then
                    pcall(chargeEntry.codec.Fail)
                end
                setFieldError(chargeEntry.row, chargeEntry.field.key .. ":geometry", chargeEntry.geometryError)
            end
        end
        for _, classicEntry in pairs(classicChargeEntries) do
            if classicEntry.codec then
                local ok, result = pcall(classicEntry.codec.Rescale)
                classicEntry.geometryError = not ok and tostring(result) or nil
                if not ok then
                    pcall(classicEntry.codec.Fail)
                    classicEntry.hasRaw = false
                end
                setFieldError(classicEntry.row, classicEntry.field.ruleKey .. ":geometry", classicEntry.geometryError)
            end
        end
        return true
    end
    function producer.HasGeometryError()
        for _, chargeEntry in ipairs(chargeEntries) do
            if chargeEntry.geometryError then
                return true
            end
        end
        for _, classicEntry in pairs(classicChargeEntries) do
            if classicEntry.geometryError then
                return true
            end
        end
        return false
    end
    local function reportError(field, row, glyph, err)
        setFieldError(row, field.key or field.ruleKey, err)
        if glyph then
            pcall(setColor, glyph, COLOR_ERROR_RED)
        end
    end
    local function clearError(field, row)
        setFieldError(row, field.key or field.ruleKey, nil)
    end
    local function addAuraOutput(field, row, existingBase, encodePresence)
        local auraSource = fontPixelSources.AuraSource(field)
        local identity = auraSource.identity
        local group = auraGroupByIdentity[identity]
        if not group then
            group = {
                field = field,
                unit = auraSource.unit,
                filter = auraSource.filter,
                spellIDs = auraSource.spellIDs,
                outputs = {},
            }
            auraGroupByIdentity[identity] = group
            auraGroups[#auraGroups + 1] = group
        end
        local baseOk, base = true, existingBase
        if not base then
            local gray = encodePresence and 51 or 0
            baseOk, base = pcall(newCell, row, gray, gray, gray)
        end
        local ok, cover = pcall(newCell, row, 0, 0, 0)
        if ok then
            ok, cover = pcall(function()
                setColor(cover, COLOR_TRANSPARENT)
                return cover
            end)
        end
        local output = {
            field = field,
            row = row,
            base = base,
            cover = cover,
            encodePresence = encodePresence,
            constructionError = not baseOk and base or not ok and cover or nil,
        }
        if not baseOk then
            output.base = nil
        end
        if not ok then
            output.cover = nil
        end
        group.outputs[#group.outputs + 1] = output
        if output.constructionError then
            reportError(field, row, output.base, output.constructionError)
        end
    end
    local function addCooldownField(spec, markHandled)
        local field = assert(spec.field, "冷却字段缺少来源声明")
        assert((spec.rows or 1) == 1, "冷却字段必须占一个物理行")
        if markHandled then
            handledKeys[field.key] = true
        end
        local row = assert(spec.row)
        local ok, result = pcall(newCell, row, 0, 0, 0)
        cooldownEntries[#cooldownEntries + 1] = {
            field = field,
            row = row,
            glyph = ok and result or nil,
            constructionError = not ok and result or nil,
            prepared = fontPixelSources.PrepareField(field),
            policy = { ignoreGCD = true, bestEffort = true, chargeRecoveryOnly = true },
        }
        if not ok then
            reportError(field, row, nil, result)
        end
        if field.blockedByAura then
            local blockedKey = field.key .. "#blocked"
            handledKeys[blockedKey] = true
            addAuraOutput(
                {
                    key = blockedKey,
                    kind = "blocked_cd",
                    unit = "player",
                    filter = "HARMFUL",
                    spellID = field.blockedByAura,
                },
                spec.row,
                result
            )
        end
    end
    for _, nativeField in ipairs(contract.nativeFields or {}) do
        addCooldownField(nativeField, true)
    end
    for _, internalField in ipairs(contract.internalFields or {}) do
        if internalField.kind == "cd_seconds" then
            addCooldownField({ field = internalField.field, row = internalField.row, rows = 1 }, true)
        end
    end
    for _, chargeField in ipairs(contract.chargeFields or {}) do
        if chargeField.classicIndex then
            local field = chargeField.field
            handledKeys[field.ruleKey:sub(7)] = true
            local ok, result = pcall(
                P8BA6426E.CreateFontPixelChargeCodec,
                {
                    frame = frame,
                    row = chargeField.row,
                    addonName = addonName,
                    specID = params.specID,
                    newCell = newCell,
                }
            )
            classicChargeEntries[chargeField.classicIndex + 1] = {
                field = field,
                row = chargeField.row,
                codec = ok and result or nil,
                constructionError = not ok and result or nil,
                hasRaw = false,
                prepared = fontPixelSources.PrepareField(field),
            }
            if not ok then
                reportError(field, chargeField.row, nil, result)
            end
        end
    end
    local textFields = assert(contract.textFields)
    assert(#textFields == contract.textCount, "数字字段数量与条带声明不符")
    for _, spec in ipairs(textFields) do
        local field = assert(spec.field, "数字字段缺少业务声明")
        local row = assert(spec.row, "数字字段缺少物理行")
        if field.kind == "cd_seconds" then
            addCooldownField(spec, false)
        elseif field.kind == "charge_lua" then
            assert(
                spec.charge and spec.rows == (field.fallbackAuraSpellID and 2 or 1),
                "充能单格及光环覆盖行与声明不符"
            )
            handledKeys[field.key] = true
            local ok, result = pcall(
                P8BA6426E.CreateFontPixelChargeCodec,
                { frame = frame, row = row, addonName = addonName, specID = params.specID, newCell = newCell }
            )
            local chargeEntry = {
                field = field,
                row = row,
                codec = ok and result or nil,
                constructionError = not ok and result or nil,
                prepared = fontPixelSources.PrepareField(field),
            }
            chargeEntries[#chargeEntries + 1] = chargeEntry
            if not ok then
                reportError(field, row, nil, result)
            end
            if field.fallbackAuraSpellID then
                addAuraOutput({
                    key = field.key .. "#fallback",
                    kind = "aura_stacks",
                    spellID = field.fallbackAuraSpellID,
                    unit = field.unit or "player",
                }, row + 1)
            end
        elseif field.kind == "aura_seconds" or field.kind == "aura_stacks" then
            assert((spec.rows or 1) == 1, "光环字段必须占一个物理行")
            addAuraOutput(field, row, nil, true)
        else
            error("不支持的数字字段类型：" .. tostring(field.kind))
        end
    end
    producer.Rescale()
    local function bindAuraGlyphs(group, auraFrame)
        local ok, result = pcall(function()
            auraFrame:ClearAllPoints()
            auraFrame:SetSize(1, 1)
            auraFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        end)
        if not ok then
            group.error = tostring(result)
            for _, output in ipairs(group.outputs) do
                reportError(output.field, output.row, output.base, result)
            end
            return
        end
        group.error = nil
        for _, output in ipairs(group.outputs) do
            if not output.constructionError then
                local ok, result = pcall(function()
                    local field = output.field
                    local glyphsByOutput = auraFrame.p8ba6426eFontPixelGlyphs
                    if not glyphsByOutput then
                        glyphsByOutput = {}
                        auraFrame.p8ba6426eFontPixelGlyphs = glyphsByOutput
                    end
                    local glyphs = glyphsByOutput[output]
                    if not glyphs then
                        glyphs = {}
                        glyphsByOutput[output] = glyphs
                    end
                    if output.encodePresence then
                        if not glyphs.present then
                            glyphs.present = newGlyph(auraFrame, output.row)
                        end
                        setColor(glyphs.present, COLOR_BLACK)
                    end
                    local valueGlyph = glyphs.value
                    if not valueGlyph then
                        valueGlyph = newGlyph(auraFrame, output.row)
                        glyphs.value = valueGlyph
                    end
                    if field.kind == "blocked_cd" then
                        setColor(valueGlyph, COLOR_UNAVAILABLE)
                    elseif field.kind == "aura_seconds" then
                        fontPixelSources.BindDuration(auraFrame, valueGlyph, presenceFormatter, getTimeCurve(field))
                    else
                        local countGlyph = glyphs.count
                        if not countGlyph then
                            countGlyph = newGlyph(auraFrame, output.row)
                            glyphs.count = countGlyph
                        end
                        fontPixelSources.BindStacks(
                            auraFrame,
                            valueGlyph,
                            countGlyph,
                            stackFormatter,
                            field.no_companion and "" or stackColorMarkup(1)
                        )
                    end
                end)
                output.bindingError = not ok and tostring(result) or nil
                if output.bindingError then
                    reportError(output.field, output.row, output.base, result)
                elseif not output.layerError then
                    clearError(output.field, output.row)
                end
            end
        end
        if auraFrame.SetMouseClickEnabled then
            pcall(auraFrame.SetMouseClickEnabled, auraFrame, false)
        end
        if auraFrame.SetMouseMotionEnabled then
            pcall(auraFrame.SetMouseMotionEnabled, auraFrame, false)
        end
    end
    for _, group in ipairs(auraGroups) do
        local ok, container = pcall(function()
            local auraContainer = fontPixelSources.CreateAuraContainer(
                frame,
                group,
                group.field.key .. ".font",
                function(auraFrame)
                    bindAuraGlyphs(group, auraFrame)
                end
            )
            for _, output in ipairs(group.outputs) do
                if output.cover then
                    local ok, result = pcall(function()
                        (output.cover:GetParent()):SetFrameLevel(auraContainer:GetFrameLevel() + 2)
                    end)
                    if not ok then
                        output.layerError = tostring(result)
                        reportError(output.field, output.row, output.base, result)
                    end
                end
            end
            return auraContainer
        end)
        if ok then
            group.container = container
        else
            group.error = tostring(container)
            for _, output in ipairs(group.outputs) do
                reportError(output.field, output.row, output.base, container)
            end
        end
    end
    local function refreshCooldown(entry)
        local field = entry.field
        local timeCurve = getTimeCurve(field)
        if isUnlearned(field, entry.prepared) then
            setColor(entry.glyph, COLOR_UNAVAILABLE)
            return
        end
        assert(C_Spell and C_Spell.GetSpellCooldownDuration, "冷却时间对象接口不可用")
        local cooldown, readable = fontPixelSources.ReadCooldown(field, entry.policy, entry.prepared)
        assert(readable, "冷却时间对象不可读")
        if cooldown then
            local remainingColor = cooldown:EvaluateRemainingDuration(timeCurve)
            setColor(entry.glyph, remainingColor)
        else
            setColor(entry.glyph, COLOR_BLACK)
        end
    end
    local function refreshCharge(entry)
        local field, codec = entry.field, entry.codec
        if isUnlearned(field, entry.prepared) then
            codec.Update(nil, nil, true, false)
            return
        end
        local charge, readable = fontPixelSources.ReadCharge(field, false)
        assert(readable, "充能来源不可读")
        local chargeRecovery, recoveryReadable = fontPixelSources.ReadChargeRecovery(field)
        codec.Update(charge, chargeRecovery, true, true, recoveryReadable)
    end
    local function refreshClassicCharge(entry)
        if entry.field.sourcePolicy == "true_count" then
            if isUnlearned(entry.field, entry.prepared) then
                entry.codec.Update(nil, nil, true, false)
                return
            end
            local trueCharge, recovery, readable = fontPixelSources.ReadTrueCharge(entry.field)
            entry.codec.Update(trueCharge, recovery, true, true, readable)
            return
        end
        if not entry.hasRaw then
            entry.codec.Reset()
            return
        end
        if entry.rawCount == 601 then
            entry.codec.Update(nil, nil, true, false)
            return
        end
        local chargeRecovery, readable = fontPixelSources.ReadChargeRecovery(entry.field)
        entry.codec.Update(entry.rawCount, chargeRecovery, true, true, readable)
    end
    function producer.UpdateClassicCharge(classicIndex, r, g, b)
        local classicEntry = classicChargeEntries[classicIndex]
        if not classicEntry then
            return false
        end
        if classicEntry.field.sourcePolicy == "true_count" then
            return true
        end
        if classicEntry.constructionError then
            return true
        end
        if classicEntry.geometryError then
            return true
        end
        local ok, result = pcall(function()
            if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then
                error("经典充能颜色受保护")
            end
            local r8 = math.floor(r * 255 + 0.5)
            local g8 = math.floor(g * 255 + 0.5)
            local b8 = math.floor(b * 255 + 0.5)
            classicEntry.rawCount = (r8 * 65536 + g8 * 256) + b8
            classicEntry.hasRaw = true
            refreshClassicCharge(classicEntry)
        end)
        if not ok then
            pcall(classicEntry.codec.Fail)
            setFieldError(classicEntry.row, classicEntry.field.ruleKey, result)
        else
            setFieldError(classicEntry.row, classicEntry.field.ruleKey, nil)
        end
        return true
    end
    local function unitExistsCoverColor(group)
        return C_CurveUtil.EvaluateColorFromBoolean(UnitExists(group.unit), COLOR_TRANSPARENT, COLOR_ABSENT_BLUE)
    end
    local function refreshAuraGroup(group)
        if group.unit == "mouseover" then
            local valid = isMouseoverRelationValid(group.field)
            group.container:SetShown(valid)
            for _, output in ipairs(group.outputs) do
                if output.base and not output.constructionError then
                    local ok, result = pcall(
                        setColor,
                        output.base,
                        valid and (output.encodePresence and COLOR_PRESENT_GRAY or COLOR_BLACK) or COLOR_ABSENT_BLUE
                    )
                    if not ok then
                        output.refreshError = tostring(result)
                        reportError(output.field, output.row, output.base, result)
                    end
                end
            end
        end
        if group.container:IsShown() then
            group.container:UpdateAllAuras()
        end
    end
    function producer.Refresh()
        if not active then
            return false
        end
        for _, cooldownEntry in ipairs(cooldownEntries) do
            if cooldownEntry.constructionError then
                reportError(cooldownEntry.field, cooldownEntry.row, nil, cooldownEntry.constructionError)
            else
                local ok, result = pcall(refreshCooldown, cooldownEntry)
                if ok then
                    clearError(cooldownEntry.field, cooldownEntry.row)
                else
                    reportError(cooldownEntry.field, cooldownEntry.row, cooldownEntry.glyph, result)
                end
            end
        end
        for _, chargeEntry in ipairs(chargeEntries) do
            if chargeEntry.constructionError then
                reportError(chargeEntry.field, chargeEntry.row, nil, chargeEntry.constructionError)
            elseif not chargeEntry.geometryError then
                local ok, result = pcall(refreshCharge, chargeEntry)
                if ok then
                    clearError(chargeEntry.field, chargeEntry.row)
                else
                    pcall(chargeEntry.codec.Fail)
                    reportError(chargeEntry.field, chargeEntry.row, nil, result)
                end
            end
        end
        for _, classicEntry in pairs(classicChargeEntries) do
            if classicEntry.constructionError then
                setFieldError(classicEntry.row, classicEntry.field.ruleKey, classicEntry.constructionError)
            elseif not classicEntry.geometryError then
                local ok, result = pcall(refreshClassicCharge, classicEntry)
                if not ok then
                    pcall(classicEntry.codec.Fail)
                    setFieldError(classicEntry.row, classicEntry.field.ruleKey, result)
                else
                    setFieldError(classicEntry.row, classicEntry.field.ruleKey, nil)
                end
            end
        end
        for _, group in ipairs(auraGroups) do
            for _, output in ipairs(group.outputs) do
                if output.constructionError then
                    reportError(output.field, output.row, output.base, output.constructionError)
                elseif output.bindingError then
                    reportError(output.field, output.row, output.base, output.bindingError)
                elseif output.layerError then
                    reportError(output.field, output.row, output.base, output.layerError)
                end
            end
            if group.container then
                local ok, result = pcall(unitExistsCoverColor, group)
                for _, output in ipairs(group.outputs) do
                    output.refreshError = nil
                    if not output.constructionError and (not output.bindingError and not output.layerError) then
                        local coverOk, coverErr
                        if ok then
                            coverOk, coverErr = pcall(setColor, output.cover, result)
                        else
                            coverOk, coverErr = false, result
                        end
                        if not coverOk then
                            output.refreshError = tostring(coverErr)
                            reportError(output.field, output.row, output.base, coverErr)
                        end
                    end
                end
                local ok, result = pcall(refreshAuraGroup, group)
                for _, output in ipairs(group.outputs) do
                    if output.constructionError or output.bindingError or output.layerError then
                    elseif ok and (not group.error and not group.lifecycleError) then
                        if not output.refreshError then
                            clearError(output.field, output.row)
                        end
                    else
                        reportError(
                            output.field,
                            output.row,
                            output.base,
                            group.error or group.lifecycleError or result
                        )
                        if output.cover then
                            pcall(setColor, output.cover, COLOR_ERROR_RED)
                        end
                    end
                end
            else
                for _, output in ipairs(group.outputs) do
                    if not output.constructionError then
                        reportError(output.field, output.row, output.base, group.error or "光环容器创建失败")
                    end
                end
            end
        end
        return true
    end
    function producer.Enable()
        if InCombatLockdown() then
            return false, "请脱战后启用数字容器"
        end
        for _, group in ipairs(auraGroups) do
            if group.container then
                local ok, result = pcall(function()
                    group.container:Show()
                    group.container:SetEnabled(true)
                end)
                if not ok then
                    group.lifecycleError = tostring(result)
                    for _, output in ipairs(group.outputs) do
                        reportError(output.field, output.row, output.base, result)
                    end
                else
                    group.lifecycleError = nil
                end
            end
        end
        active = true
        producer.Refresh()
        return true
    end
    function producer.Disable()
        active = false
        for _, group in ipairs(auraGroups) do
            if group.container then
                local ok, result = pcall(function()
                    group.container:SetEnabled(false)
                    group.container:Hide()
                end)
                if not ok then
                    group.lifecycleError = tostring(result)
                    for _, output in ipairs(group.outputs) do
                        reportError(output.field, output.row, output.base, result)
                    end
                end
            end
        end
    end
    function producer.Reset()
        for errorKey in pairs(producer.errors) do
            producer.errors[errorKey] = nil
        end
    end
    return producer
end
