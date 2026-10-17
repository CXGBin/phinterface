--[[
  ClientCompat —— 客户端兼容层：区分正式服(retail)/“forever”版本的专精 API、客户端能力开关、英雄天赋与打包身份编码
  原始文件：ffb3a6.lua（TOC 第 2 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
-- 专精 API 选择：forever 客户端使用 C_SpecializationInfo
P8BA6426E.SpecializationAPI = _G
P8BA6426E.ClientCapabilities = {
    completeLossOfControlSnapshot = P8BA6426E.flavor == "forever",
    retailEnemyCountCorrections = P8BA6426E.flavor ~= "forever",
}
if P8BA6426E.flavor == "forever" then
    local specInfoAPI = C_SpecializationInfo or {}
    P8BA6426E.SpecializationAPI =
        { GetSpecialization = specInfoAPI.GetSpecialization, GetSpecializationInfo = specInfoAPI.GetSpecializationInfo }
    if specInfoAPI.GetSpecializationInfo then
        P8BA6426E.SpecializationAPI.GetSpecializationRole = function(specIndex)
            local _specID, _specName, _specDesc, _specIcon, specRole = specInfoAPI.GetSpecializationInfo(specIndex)
            return specRole
        end
    end
end
function P8BA6426E.GetActiveHeroTalentSpecID()
    if P8BA6426E.flavor == "forever" then
        return 0
    end
    if not C_ClassTalents or type(C_ClassTalents.GetActiveHeroTalentSpec) ~= "function" then
        return nil
    end
    local ok, result = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
    if not ok or type(result) ~= "number" or result <= 0 or result >= 4096 then
        return nil
    end
    return result
end
-- 打包身份：专精ID*4096 + 英雄天赋ID（spec_id 像素字段）
function P8BA6426E.GetPackedGameIdentity()
    local specID = P8BA6426E.DB and P8BA6426E.DB.currentSpecID or nil
    local heroSpecID = P8BA6426E.DB and P8BA6426E.DB.currentHeroSpecID or nil
    if type(specID) ~= "number" or specID <= 0 or specID >= 4096 then
        return nil
    end
    if P8BA6426E.flavor == "forever" then
        return specID * 4096
    end
    if type(heroSpecID) ~= "number" or heroSpecID <= 0 or heroSpecID >= 4096 then
        return specID
    end
    return specID * 4096 + heroSpecID
end
function P8BA6426E.UpdateClassSpecDB()
    local currentClass, currentSpecIndex, currentSpecID, currentSpecName = P8BA6426E.GetPlayerClassSpec()
    P8BA6426E.DB.currentClass = currentClass
    P8BA6426E.DB.currentSpecIndex = currentSpecIndex
    P8BA6426E.DB.currentSpecID = currentSpecID
    P8BA6426E.DB.currentSpecName = currentSpecName
    P8BA6426E.DB.currentHeroSpecID = P8BA6426E.GetActiveHeroTalentSpecID()
end
if IsLoggedIn() then
    P8BA6426E.UpdateClassSpecDB()
end
