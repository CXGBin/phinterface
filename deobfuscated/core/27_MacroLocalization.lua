--[[
  MacroLocalization —— 宏本地化：根据授权引用表把中文宏中的技能名替换为客户端本地技能名
  原始文件：549815.lua（TOC 第 27 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E = P8BA6426E or {}
local baseRegisterClass = P8BA6426E.RegisterClass
local baseGetDefaultMacro = P8BA6426E.GetDefaultMacro
local reportedFailures = {}
local function trim(s)
    return ((s:gsub("^%s+", "")):gsub("%s+$", ""))
end
local function splitLines(text)
    local lines = {}
    local pos = 1
    while true do
        local newline = text:find("\n", pos, true)
        if not newline then
            table.insert(lines, text:sub(pos))
            break
        end
        table.insert(lines, text:sub(pos, newline - 1))
        pos = newline + 1
    end
    return lines
end
local function commandPrefix(command)
    if command == "showtooltip" then
        return "#showtooltip"
    end
    return "/" .. command
end
local function lineStartsWithCommand(line, command)
    local stripped = line:gsub("^%s+", "")
    local lower = stripped:lower()
    local prefix = commandPrefix(command)
    if lower:sub(1, #prefix) ~= prefix then
        return false
    end
    local nextChar = lower:sub(#prefix + 1, #prefix + 1)
    return nextChar == "" or nextChar == "[" or nextChar:match("%s") ~= nil
end
local function replaceRange(s, startPos, endPos, replacement)
    return s:sub(1, startPos - 1) .. (replacement .. s:sub(endPos + 1))
end
local function findBracketRanges(line)
    local ranges = {}
    local pos = 1
    while pos <= #line do
        local openPos = line:find("[", pos, true)
        if not openPos then
            break
        end
        local closePos = line:find("]", openPos + 1, true)
        if not closePos then
            return nil
        end
        table.insert(ranges, { openPos, closePos })
        pos = closePos + 1
    end
    return ranges
end
local function isInsideRanges(pos, ranges)
    for _, range in ipairs(ranges) do
        if pos >= range[1] and pos <= range[2] then
            return true
        end
    end
    return false
end
local function replaceOutsideBrackets(line, needle, replacement)
    local ranges = findBracketRanges(line)
    if not ranges then
        return nil
    end
    local pos = 1
    while pos <= #line do
        local startPos, endPos = line:find(needle, pos, true)
        if not startPos then
            return nil
        end
        if not isInsideRanges(startPos, ranges) then
            return replaceRange(line, startPos, endPos, replacement)
        end
        pos = endPos + 1
    end
    return nil
end
local function replaceConditionArgument(line, ref, replacement)
    local ranges = findBracketRanges(line)
    if not ranges then
        return nil
    end
    local conditionType = ((ref.condition_type or "")):lower()
    for _, range in ipairs(ranges) do
        local innerStart = range[1] + 1
        local innerEnd = range[2] - 1
        local pos = innerStart
        local currentCondition
        while pos <= innerEnd do
            local comma = line:find(",", pos, true)
            local partEnd = comma and math.min(comma - 1, innerEnd) or innerEnd
            local part = line:sub(pos, partEnd)
            local leadingSpace = part:match("^(%s*)") or ""
            local trimmed = trim(part)
            local condName, condValue = trimmed:match("^([^:]+):(.*)$")
            local valueOffset = 1
            if condName then
                currentCondition = (trim(condName)):lower()
                valueOffset = trimmed:find(":", 1, true) + 1
            else
                condValue = trimmed
            end
            if currentCondition == conditionType and trim(condValue) == ref.source_value then
                local valueText = trimmed:sub(valueOffset)
                local valueLeading = valueText:match("^(%s*)") or ""
                local replaceStart = (((pos + #leadingSpace) + valueOffset) - 1) + #valueLeading
                local replaceEnd = (replaceStart + #ref.source_value) - 1
                return replaceRange(line, replaceStart, replaceEnd, replacement)
            end
            if not comma or comma > innerEnd then
                break
            end
            pos = comma + 1
        end
    end
    return nil
end
local function appliesToHeroSpec(ref)
    local heroSpecs = ref.hero_applicability or {}
    if #heroSpecs == 0 then
        return true
    end
    if not C_ClassTalents or not C_ClassTalents.GetActiveHeroTalentSpec then
        return false
    end
    local ok, heroSpecID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
    if not ok or not heroSpecID then
        return false
    end
    for _, heroSpec in ipairs(heroSpecs) do
        if heroSpec == heroSpecID then
            return true
        end
    end
    return false
end
local function getSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, result = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and result then
            return result.name
        end
    end
    if GetSpellInfo then
        local ok, result = pcall(GetSpellInfo, spellID)
        if ok then
            return result
        end
    end
    return nil
end
local function applyRef(line, ref)
    if ref.kind ~= "spell" and ref.kind ~= "item" then
        return nil, "宏授权包含未知引用类型"
    end
    if not lineStartsWithCommand(line, ref.command) then
        return nil, "宏命令与授权不一致"
    end
    if not appliesToHeroSpec(ref) then
        return line
    end
    local replacement
    if ref.kind == "item" then
        replacement = "item:" .. tostring(ref.id)
    else
        replacement = getSpellName(ref.id)
        if not replacement or replacement == "" then
            return nil, "客户端无法解析授权 SpellID"
        end
    end
    if ref.role == "condition_argument" then
        local replaced = replaceConditionArgument(line, ref, replacement)
        if not replaced then
            return nil, "条件参数与授权源值不一致"
        end
        return replaced
    end
    if ref.role == "command_argument" or ref.role == "sequence_entry" or ref.role == "tooltip_argument" then
        local replaced = replaceOutsideBrackets(line, ref.source_value, replacement)
        if not replaced then
            return nil, "命令参数与授权源值不一致"
        end
        return replaced
    end
    return nil, "授权包含未知宏参数角色"
end
-- 按授权引用表逐行替换宏中的技能/物品引用；任何不一致都拒绝（返回 nil, 原因）
function P8BA6426E.CompileAuthorizedMacro(macroText, refs)
    if not macroText or macroText == "" then
        return macroText
    end
    if P8BA6426E.IsChineseClient() then
        return macroText
    end
    if type(refs) ~= "table" or #refs == 0 then
        return macroText
    end
    local lines = splitLines(macroText)
    for _, ref in ipairs(refs) do
        if type(ref.line) ~= "number" or not lines[ref.line] then
            return nil, "授权宏行已从源码消失"
        end
        local replaced, err = applyRef(lines[ref.line], ref)
        if not replaced then
            return nil, err
        end
        lines[ref.line] = replaced
    end
    return table.concat(lines, "\n")
end
function P8BA6426E.RegisterClass(specID, classDef)
    local macroRefs = P8BA6426E.MacroRefsBySpec and P8BA6426E.MacroRefsBySpec[specID]
    if macroRefs and macroRefs.schema_version == 1 then
        classDef.macro_refs = macroRefs
    end
    return baseRegisterClass(specID, classDef)
end
function P8BA6426E.GetDefaultMacro(actionKey)
    if P8BA6426E.IsChineseClient() then
        return baseGetDefaultMacro(actionKey)
    end
    local classDef = P8BA6426E.classData
    local macroText = classDef and (classDef.DEFAULT_MACROS and classDef.DEFAULT_MACROS[actionKey])
    if not macroText then
        return baseGetDefaultMacro(actionKey)
    end
    local actionRefs = classDef.macro_refs and (classDef.macro_refs.actions and classDef.macro_refs.actions[actionKey])
    if not actionRefs or not actionRefs.complete then
        return macroText
    end
    local refs = actionRefs.refs
    if type(refs) ~= "table" or #refs == 0 then
        return macroText
    end
    local compiled, err = P8BA6426E.CompileAuthorizedMacro(macroText, refs)
    if compiled then
        return compiled
    end
    if not reportedFailures[actionKey] then
        reportedFailures[actionKey] = true
        if P8BA6426E.AddErrorLog then
            P8BA6426E.AddErrorLog("宏本地化", tostring(actionKey) .. ("：" .. tostring(err)))
        end
    end
    return macroText
end
