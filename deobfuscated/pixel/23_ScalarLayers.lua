--[[
  ScalarLayers —— 像素标量图层：为血量/治疗相关标量字段创建叠加纹理层
  原始文件：cf935d.lua（TOC 第 23 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local layersBySurface = setmetatable({}, { __mode = "k" })
local function createLayerTexture(surfaceFrame, row, blendMode, r, g, b, startHidden, subLevel)
    local texture = surfaceFrame:CreateTexture(nil, "OVERLAY")
    texture:SetSize(1, 1)
    texture:SetPoint("TOPLEFT", surfaceFrame, "TOPLEFT", 0, -row)
    texture:SetDrawLayer("OVERLAY", subLevel or (blendMode == "BLEND" and 0 or 1))
    texture:SetBlendMode(blendMode)
    texture:SetColorTexture(r, g, b, 1)
    if startHidden then
        texture:SetAlpha(0)
    end
    return texture
end
local function isLayeredScalar(key, healerMode)
    return key == "player_health_pct"
        or key == "mouseover_health_pct"
        or key == "team_avg_health"
        or key == "mouseover_npc_state"
        or key == "focus_is_player"
        or key == "party_tank_index"
        or (healerMode and key == "master_switch")
        or key:match("^party[1-4]_health_pct$")
        or key:match("^raid_health_%d%d$")
end
-- 为需要“多层叠加”的标量（血量、团队、回执）在条带上创建额外纹理层
function P8BA6426E.AcquirePixelScalarLayers(surfaceFrame, contract, healerMode, raidFocusEnabled, raidAckKey)
    local existing = layersBySurface[surfaceFrame]
    if existing and existing.contract == contract then
        existing:Show()
        return existing
    end
    if existing then
        existing:Hide()
    end
    local layers = {
        contract = contract,
        textures = {},
        bases = {},
        buildErrors = {},
        healerMaster = nil,
        healingNpc = nil,
        raidHealth = nil,
        raidAck = nil,
        raidPartyUnavailable = nil,
        teamAvg = nil,
    }
    local currentScalarKey
    local function addLayer(row, blendMode, r, g, b, startHidden, subLevel)
        local texture = createLayerTexture(surfaceFrame, row, blendMode, r, g, b, startHidden, subLevel)
        texture.scalarKey = currentScalarKey
        texture.initialColor = { r, g, b }
        layers.textures[#layers.textures + 1] = texture
        return texture
    end
    function layers.Hide(self)
        for _, texture in ipairs(self.textures) do
            texture:Hide()
        end
    end
    function layers.Show(self)
        for _, texture in ipairs(self.textures) do
            local ok, result = pcall(function()
                texture:Show()
                texture:SetColorTexture(texture.initialColor[1], texture.initialColor[2], texture.initialColor[3], 1)
                if texture.initialAlphaZero then
                    texture:SetAlpha(0)
                end
            end)
            if not ok then
                pcall(texture.Hide, texture)
                self.buildErrors[texture.scalarKey] = tostring(result)
            end
        end
    end
    for i, scalarRecord in ipairs(contract.scalarRecords or {}) do
        local field = scalarRecord.field or scalarRecord
        local key = scalarRecord.key or field.key or field.id
        local row = scalarRecord.row or contract.classicRows[i]
        if row and (row >= 0 and (key and isLayeredScalar(key, healerMode))) then
            currentScalarKey = key
            local textureCountBefore = #layers.textures
            local ok, result = pcall(function()
                local base = addLayer(row, "BLEND", 0.2, 0.2, 0.2)
                layers.bases[key] = base
                if key == "master_switch" and healerMode then
                    base:SetColorTexture(1, 0, 0, 1)
                    base.initialColor = { 1, 0, 0 }
                    layers.healerMaster = {}
                    for i = 1, 41, 1 do
                        local layer = addLayer(row, "BLEND", 0, 1, 0, true, 1)
                        layer.initialAlphaZero = true
                        layers.healerMaster[i] = layer
                    end
                elseif key == "mouseover_npc_state" then
                    base:SetColorTexture(0, 0, 0, 1)
                    base.initialColor = { 0, 0, 0 }
                    local healingNpc = addLayer(row, "ADD", 0.015686274509804, 0, 0, true)
                    healingNpc.initialAlphaZero = true
                    layers.healingNpc = healingNpc
                elseif key == "team_avg_health" then
                    base:SetColorTexture(0, 0, 0, 1)
                    base.initialColor = { 0, 0, 0 }
                    layers.teamAvg = {}
                    for i = 1, 40, 1 do
                        layers.teamAvg[i] = addLayer(row, "ADD", 0, 0, 0)
                    end
                else
                    local raidSlot = tonumber(key:match("^raid_health_(%d%d)$"))
                    local partyIndex = tonumber(key:match("^party([1-4])_health_pct$"))
                    if raidSlot then
                        base:SetColorTexture(0, 0, 0, 1)
                        base.initialColor = { 0, 0, 0 }
                        layers.raidHealth = layers.raidHealth or {}
                        local channels = {}
                        for i = 1, 3, 1 do
                            channels[i] = addLayer(row, "ADD", 0, 0, 0)
                        end
                        layers.raidHealth[raidSlot] = channels
                    elseif partyIndex and raidFocusEnabled then
                        layers.raidPartyUnavailable = layers.raidPartyUnavailable or {}
                        local layer = addLayer(row, "ADD", 0, 0, 0.50196078431373, true)
                        layer.initialAlphaZero = true
                        layers.raidPartyUnavailable[partyIndex] = layer
                    elseif raidFocusEnabled and key == raidAckKey then
                        base:SetColorTexture(0, 0, 0, 1)
                        base.initialColor = { 0, 0, 0 }
                        local raidAck = { raid = {}, party = {} }
                        for i = 1, 30, 1 do
                            local layer = addLayer(row, "ADD", i / 255, 0, 0, true)
                            layer.initialAlphaZero = true
                            raidAck.raid[i] = layer
                        end
                        for i = 1, 5, 1 do
                            local layer = addLayer(row, "ADD", 0, i / 255, 0, true)
                            layer.initialAlphaZero = true
                            raidAck.party[i] = layer
                        end
                        if raidAckKey == "focus_is_player" then
                            local selfLayer = addLayer(row, "ADD", 0, 0, 0.50196078431373, true)
                            selfLayer.initialAlphaZero = true
                            raidAck.self = selfLayer
                        end
                        layers.raidAck = raidAck
                    end
                end
            end)
            if not ok then
                for i = #layers.textures, textureCountBefore + 1, -1 do
                    layers.textures[i]:Hide()
                    layers.textures[i] = nil
                end
                layers.bases[key] = nil
                if key == "master_switch" then
                    layers.healerMaster = nil
                end
                if key == "team_avg_health" then
                    layers.teamAvg = nil
                end
                layers.buildErrors[key] = tostring(result)
            end
        end
    end
    layersBySurface[surfaceFrame] = layers
    return layers
end
