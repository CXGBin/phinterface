--[[
  ActionKeys —— 动作按键：按键名规范化、可分配给动作的按键顺序表
  原始文件：d1f0d9.lua（TOC 第 9 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local VERIFIED_FKEYS = { "F6", "F7", "F8", "F9", "F10", "F11", "F12" }
function P8BA6426E.NormalizeActionKey(key)
    if type(key) ~= "string" then
        return nil
    end
    local base = key:upper()
    local modifiers = {}
    while true do
        local modifier, rest = base:match("^(%a+)%-(.+)$")
        if modifier ~= "CTRL" and (modifier ~= "ALT" and modifier ~= "SHIFT") then
            break
        end
        modifiers[modifier] = true
        base = rest
    end
    if base == "NUMPADPLUS" then
        base = "NUMPADADD"
    end
    if base == "NUMPADMINUS" then
        base = "NUMPADSUBTRACT"
    end
    return (modifiers.CTRL and "CTRL-" or "")
        .. ((modifiers.ALT and "ALT-" or "") .. ((modifiers.SHIFT and "SHIFT-" or "") .. base))
end
local BASE_ACTION_KEYS = {
    "F6",
    "F7",
    "F8",
    "F9",
    "F10",
    "F11",
    "F12",
    "8",
    "9",
    "0",
    "-",
    "=",
    "[",
    "]",
    ";",
    "'",
    ",",
    ".",
    "\\",
    "UP",
    "DOWN",
    "LEFT",
    "RIGHT",
    "INSERT",
    "DELETE",
    "HOME",
    "END",
}
P8BA6426E.ACTION_KEY_ORDER = {}
P8BA6426E.VERIFIED_ACTION_KEYS = {}
for _, key in ipairs(BASE_ACTION_KEYS) do
    table.insert(P8BA6426E.ACTION_KEY_ORDER, key)
end
for _, modifier in ipairs({ "CTRL", "ALT" }) do
    for _, key in ipairs(BASE_ACTION_KEYS) do
        table.insert(P8BA6426E.ACTION_KEY_ORDER, modifier .. ("-" .. key))
    end
end
for _, key in ipairs(VERIFIED_FKEYS) do
    table.insert(P8BA6426E.VERIFIED_ACTION_KEYS, key)
end
for i = 1, 23, 1 do
    table.insert(P8BA6426E.VERIFIED_ACTION_KEYS, "CTRL-" .. BASE_ACTION_KEYS[i])
end
for i = 7, 12, 1 do
    table.insert(P8BA6426E.VERIFIED_ACTION_KEYS, "ALT-F" .. i)
end
for _, key in ipairs({ "8", "9", "0", ";", "'" }) do
    table.insert(P8BA6426E.VERIFIED_ACTION_KEYS, "ALT-" .. key)
end
