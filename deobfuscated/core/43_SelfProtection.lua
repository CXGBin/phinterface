--[[
  SelfProtection —— 自我保护：检测并撤销插件管理器对本插件的禁用（强制重新启用）
  原始文件：bf775c.lua（TOC 第 43 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local addonName = ...
local addOnsAPI = C_AddOns
if
    type(addonName) ~= "string"
    or addonName == ""
    or type(addOnsAPI) ~= "table"
    or type(addOnsAPI.EnableAddOn) ~= "function"
then
    return
end
local pendingInterruption, pendingInterruptionCount = nil, 0
local function getEnableState(character)
    if type(addOnsAPI.GetAddOnEnableState) ~= "function" then
        return nil
    end
    local ok, result = pcall(addOnsAPI.GetAddOnEnableState, addonName, character)
    if ok and type(result) == "number" then
        return result
    end
end
local function isEnabledFor(character)
    local state = getEnableState(character)
    if character == nil or character == "0" or character == 0 then
        return state == 2
    end
    return type(state) == "number" and state > 0
end
local function saveAddOns()
    if type(addOnsAPI.SaveAddOns) == "function" then
        pcall(addOnsAPI.SaveAddOns)
    end
end
local function flushInterruptionLog()
    if not pendingInterruption or type(P8BA6426E.DB) ~= "table" then
        return
    end
    if type(P8BA6426E.DB.addonEnableProtection) ~= "table" then
        P8BA6426E.DB.addonEnableProtection = {}
    end
    local addonEnableProtection = P8BA6426E.DB.addonEnableProtection
    addonEnableProtection.interruptionCount = (tonumber(addonEnableProtection.interruptionCount) or 0)
        + pendingInterruptionCount
    addonEnableProtection.lastInterruption = pendingInterruption
    pendingInterruption, pendingInterruptionCount = nil, 0
end
-- 重新启用本插件（EnableAddOn），并记录是谁/何时尝试禁用
local function forceReEnable(character, operation)
    local source, at = nil, nil
    if operation and type(debugstack) == "function" then
        local ok, result = pcall(debugstack, 2, 10, 5)
        if ok and type(result) == "string" then
            source = result:sub(1, 2400)
        end
    end
    if operation and type(GetTime) == "function" then
        local ok, result = pcall(GetTime)
        if ok then
            at = result
        end
    end
    local ok = pcall(addOnsAPI.EnableAddOn, addonName, character)
    local recovered = ok and isEnabledFor(character)
    if operation then
        pendingInterruption =
            { operation = operation, character = character, source = source, time = at, recovered = recovered }
        pendingInterruptionCount = pendingInterruptionCount + 1
        flushInterruptionLog()
    end
end
-- 把自己加入 ACP / RurutiaSuite 等插件管理器的“受保护插件”列表
local function markAsProtectedInAddonManagers()
    if type(ACP_Data) == "table" then
        if type(ACP_Data.ProtectedAddons) ~= "table" then
            ACP_Data.ProtectedAddons = {}
        end
        ACP_Data.ProtectedAddons[addonName] = true
    end
    local rurutiaProfile = type(RurutiaSuite) == "table" and RurutiaSuite.AddonProfileData
    if type(rurutiaProfile) == "table" and type(rurutiaProfile.ProtectedAddons) == "table" then
        rurutiaProfile.ProtectedAddons[addonName] = true
    end
end
local function isThisAddon(addonRef)
    if type(addonRef) == "number" and type(addOnsAPI.GetAddOnName) == "function" then
        local ok, result = pcall(addOnsAPI.GetAddOnName, addonRef)
        if not ok then
            return false
        end
        addonRef = result
    end
    return addonRef == addonName
end
if type(hooksecurefunc) == "function" then
    if type(addOnsAPI.DisableAddOn) == "function" then
        pcall(hooksecurefunc, addOnsAPI, "DisableAddOn", function(addonRef, character)
            if isThisAddon(addonRef) then
                forceReEnable(character, "DisableAddOn")
            end
        end)
    end
    for _, apiName in ipairs({ "DisableAllAddOns", "ResetAddOns", "ResetDisabledAddOns" }) do
        if type(addOnsAPI[apiName]) == "function" then
            local name = apiName
            pcall(hooksecurefunc, addOnsAPI, name, function(character)
                if not isEnabledFor(character) then
                    forceReEnable(character, name)
                end
            end)
        end
    end
end
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
    markAsProtectedInAddonManagers()
    flushInterruptionLog()
    if event == "ADDONS_UNLOADING" then
        local playerGUID = type(UnitGUID) == "function" and UnitGUID("player") or nil
        if not isEnabledFor(playerGUID) then
            forceReEnable(playerGUID, event)
        end
        saveAddOns()
    elseif event == "PLAYER_LOGIN" then
        forceReEnable(nil)
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "ADDONS_UNLOADING" }) do
    P8BA6426E.SafeRegisterEvent(frame, event)
end
markAsProtectedInAddonManagers()
forceReEnable(nil)
