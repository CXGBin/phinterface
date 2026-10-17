--[[
  SpellCharges —— 技能充能辅助：解析充能显示技能 ID、读取充能次数
  原始文件：b87b4a.lua（TOC 第 25 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local getSpellDisplayCount = C_Spell and C_Spell.GetSpellDisplayCount
function P8BA6426E.ResolveChargeDisplaySpellID(spellID, spellIDs)
    local candidates = spellIDs or { spellID }
    local fallback = spellID or candidates[1]
    if C_Spell and C_Spell.GetOverrideSpell then
        for _, id in ipairs(candidates) do
            local ok, overrideID = pcall(C_Spell.GetOverrideSpell, id, 0, true)
            if ok and (type(overrideID) == "number" and overrideID ~= id) then
                return overrideID
            end
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        for _, id in ipairs(candidates) do
            local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
            if ok and known then
                return id
            end
        end
    end
    return fallback
end
function P8BA6426E.GetSpellChargeCount(spellID, spellIDs)
    if not getSpellDisplayCount then
        return nil
    end
    local displayID = P8BA6426E.ResolveChargeDisplaySpellID(spellID, spellIDs)
    if not displayID then
        return nil
    end
    local ok, count = pcall(getSpellDisplayCount, displayID)
    if ok then
        if type(count) == "number" then
            return count
        end
        if type(count) == "string" then
            local ok, num = pcall(tonumber, count)
            if ok and type(num) == "number" then
                return count
            end
        end
    end
    return nil
end
function P8BA6426E.GetSpellChargeDisplayRaw(spellID, spellIDs)
    if not getSpellDisplayCount then
        return false
    end
    local displayID = P8BA6426E.ResolveChargeDisplaySpellID(spellID, spellIDs)
    if not displayID then
        return false
    end
    local ok, count = pcall(getSpellDisplayCount, displayID)
    if ok and type(count) ~= "nil" then
        return true, count
    end
    return false
end
