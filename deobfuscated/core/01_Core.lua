--[[
  Core —— 核心：全局命名空间、SavedVariables 初始化与迁移、职业专精数据装载、消耗品/饰品/技能冷却与施法状态采集、宏与安全按钮按键绑定、主事件调度、斜杠命令、移动按键方案检测
  原始文件：8e5207.lua（TOC 第 1 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
-- 混淆器注入的构建常量：版本号编码与客户端类型（retail / forever）
local ADDON_VERSION_CODE = 10586464
local ADDON_FLAVOR = "retail"
local addonName, ns = ...
_G.P8BA6426E = _G.P8BA6426E or {}
P8BA6426E.classes = P8BA6426E.classes or {}
P8BA6426E.aoeMode = 0
P8BA6426E.addonVersionCode = ADDON_VERSION_CODE or 0
P8BA6426E.flavor = ADDON_FLAVOR or "retail"
-- 安全注册事件：先用 C_EventUtils.IsEventValid 校验事件在当前客户端存在，避免报错
function P8BA6426E.SafeRegisterEvent(frame, event)
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
        local ok, isValid = pcall(C_EventUtils.IsEventValid, event)
        if not ok or isValid ~= true then
            return false
        end
    end
    pcall(frame.RegisterEvent, frame, event)
    return true
end
dock = nil
P8BA6426E.classData = nil
local currentSpecID = nil
local currentHeroSpecID = nil
P8BA6426E.isClassActive = false
local _unusedForwardDecl
local loadClassData
local refreshMacroBindings
P8BA6426E.DB = nil
local DB_SCHEMA_VERSION = 2
-- SavedVariables 结构迁移：v1 清理旧 simc 字段，v2 把像素格尺寸重置为 4
local function migrateDBSchema(db)
    local schemaVersion = tonumber(db.p8ba6426eSchemaVersion) or 0
    if schemaVersion < 1 then
        db.simcProfile = nil
        db.simcProfileTimestamp = nil
        db.simcProfileError = nil
        db.simcBagItems = nil
        schemaVersion = 1
    end
    if schemaVersion < DB_SCHEMA_VERSION then
        db.pixelCellSize = 4
        schemaVersion = DB_SCHEMA_VERSION
    end
    db.p8ba6426eSchemaVersion = schemaVersion
    local legacySchemaKey = "p8ba6426eSchemaVersion"
    if legacySchemaKey ~= "p8ba6426eSchemaVersion" then
        db[legacySchemaKey] = nil
    end
end
-- 初始化 SavedVariables（P8BA6426EDB）并补齐所有默认值
function P8BA6426E.InitDB()
    _G.P8BA6426EDB = _G.P8BA6426EDB or {}
    P8BA6426E.DB = _G.P8BA6426EDB
    migrateDBSchema(P8BA6426E.DB)
    if P8BA6426E.DB.masterSwitch == nil then
        P8BA6426E.DB.masterSwitch = true
    end
    if P8BA6426E.DB.burstSwitch == nil then
        P8BA6426E.DB.burstSwitch = false
    end
    if type(P8BA6426E.DB.burstAutoCloseSecondsBySpec) ~= "table" then
        P8BA6426E.DB.burstAutoCloseSecondsBySpec = {}
    end
    if P8BA6426E.DB.autoTarget == nil then
        P8BA6426E.DB.autoTarget = false
    end
    if P8BA6426E.DB.healerAutoTarget == nil then
        P8BA6426E.DB.healerAutoTarget = true
    end
    if P8BA6426E.DB.protectionPaladinAutoTarget == nil then
        P8BA6426E.DB.protectionPaladinAutoTarget = false
    end
    if P8BA6426E.DB.masterKey == nil then
        P8BA6426E.DB.masterKey = nil
    end
    if P8BA6426E.DB.burstKey == nil then
        P8BA6426E.DB.burstKey = nil
    end
    if P8BA6426E.DB.aoeKey == nil then
        P8BA6426E.DB.aoeKey = nil
    end
    P8BA6426E.DB.aoeMode = nil
    if type(P8BA6426E.DB.macroMapBySpec) ~= "table" then
        P8BA6426E.DB.macroMapBySpec = {}
    end
    if type(P8BA6426E.DB.userEditedMacrosBySpec) ~= "table" then
        P8BA6426E.DB.userEditedMacrosBySpec = {}
    end
    if type(P8BA6426E.DB.persistentCooldownLedger) ~= "table" then
        P8BA6426E.DB.persistentCooldownLedger = {}
    end
    if P8BA6426E.DB.disableTextAlert == nil then
        P8BA6426E.DB.disableTextAlert = false
    end
    if P8BA6426E.DB.disableSound == nil then
        P8BA6426E.DB.disableSound = false
    end
    if P8BA6426E.DB.logoSize == nil then
        P8BA6426E.DB.logoSize = 64
    end
    if P8BA6426E.DB.showLogoText == nil then
        P8BA6426E.DB.showLogoText = true
    end
    if P8BA6426E.DB.logoHidden == nil then
        P8BA6426E.DB.logoHidden = false
    end
end
local function getCurrentSpecID()
    if P8BA6426E.GetPlayerClassSpec then
        local _classFile, _className, specID = P8BA6426E.GetPlayerClassSpec()
        if type(specID) == "number" and specID > 0 then
            return specID
        end
    end
    local savedSpecID = P8BA6426E.DB and P8BA6426E.DB.currentSpecID
    if type(savedSpecID) == "number" and savedSpecID > 0 then
        return savedSpecID
    end
    return nil
end
-- 取当前专精的“用户自定义宏”与“已编辑标记”两张表（并把旧版全局宏表迁移到按专精存储）
local function getSpecMacroTables()
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    local specID = getCurrentSpecID()
    if not specID then
        return nil, nil
    end
    if tonumber(P8BA6426E.DB.macroStorageVersion) ~= 2 then
        local legacyMacroMap = P8BA6426E.DB.macroMap
        local legacyUserEdited = P8BA6426E.DB.userEditedMacros
        local specMacroMap = P8BA6426E.DB.macroMapBySpec[specID] or {}
        local specUserEdited = P8BA6426E.DB.userEditedMacrosBySpec[specID] or {}
        if type(legacyMacroMap) == "table" and type(legacyUserEdited) == "table" then
            for actionKey, edited in pairs(legacyUserEdited) do
                local legacyMacro = legacyMacroMap[actionKey]
                if edited and (type(legacyMacro) == "string" and specMacroMap[actionKey] == nil) then
                    specMacroMap[actionKey] = legacyMacro
                    specUserEdited[actionKey] = true
                end
            end
        end
        P8BA6426E.DB.macroMapBySpec[specID] = specMacroMap
        P8BA6426E.DB.userEditedMacrosBySpec[specID] = specUserEdited
        P8BA6426E.DB.macroMap = nil
        P8BA6426E.DB.userEditedMacros = nil
        P8BA6426E.DB.macroStorageVersion = 2
    end
    if type(P8BA6426E.DB.macroMapBySpec[specID]) ~= "table" then
        P8BA6426E.DB.macroMapBySpec[specID] = {}
    end
    if type(P8BA6426E.DB.userEditedMacrosBySpec[specID]) ~= "table" then
        P8BA6426E.DB.userEditedMacrosBySpec[specID] = {}
    end
    return P8BA6426E.DB.macroMapBySpec[specID], P8BA6426E.DB.userEditedMacrosBySpec[specID]
end
function P8BA6426E.GetUserMacro(actionKey)
    local macroMap, userEdited = getSpecMacroTables()
    if not macroMap or not userEdited or not userEdited[actionKey] then
        return false, nil
    end
    local macroText = macroMap[actionKey]
    if type(macroText) ~= "string" then
        return false, nil
    end
    return true, macroText
end
function P8BA6426E.SaveUserMacro(actionKey, macroText)
    if type(actionKey) ~= "string" or type(macroText) ~= "string" then
        return false
    end
    local macroMap, userEdited = getSpecMacroTables()
    if not macroMap or not userEdited then
        return false
    end
    macroMap[actionKey] = macroText
    userEdited[actionKey] = true
    return true
end
function P8BA6426E.ClearUserMacro(actionKey)
    local macroMap, userEdited = getSpecMacroTables()
    if not macroMap or not userEdited then
        return false
    end
    macroMap[actionKey] = nil
    userEdited[actionKey] = nil
    return true
end
local CHIJI_MIGRATION_VERSION = 1
local CHIJI_LEGACY_MACRO =
    "/cast [nochanneling:天神御身] 朱鹤下凡\n/use 圣光潜力\n/use 光盲圣怒的连祷"
local CHIJI_LEGACY_MACRO_REFS = {
    {
        line = 1,
        command = "cast",
        role = "condition_argument",
        condition_type = "nochanneling",
        source_value = "天神御身",
        kind = "spell",
        id = 443028,
        hero_applicability = {},
    },
    {
        line = 1,
        command = "cast",
        role = "command_argument",
        source_value = "朱鹤下凡",
        kind = "spell",
        id = 325197,
        hero_applicability = {},
    },
    {
        line = 2,
        command = "use",
        role = "command_argument",
        source_value = "圣光潜力",
        kind = "item",
        id = 241308,
        hero_applicability = {},
    },
    {
        line = 3,
        command = "use",
        role = "command_argument",
        source_value = "光盲圣怒的连祷",
        kind = "item",
        id = 249808,
        hero_applicability = {},
    },
}
-- 织雾武僧一次性迁移：如果用户保存的“朱鹤下凡”宏与旧默认宏相同，则清除，改用新默认宏
local function migrateMistweaverChijiMacro()
    if getCurrentSpecID() ~= 270 then
        return
    end
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    if (tonumber(P8BA6426E.DB.mistweaverChijiHiddenUseMigrationVersion) or 0) >= CHIJI_MIGRATION_VERSION then
        return
    end
    local hasUserMacro, userMacroText = P8BA6426E.GetUserMacro("cd_325197")
    if not hasUserMacro then
        P8BA6426E.DB.mistweaverChijiHiddenUseMigrationVersion = CHIJI_MIGRATION_VERSION
        return
    end
    local shouldMigrate = false
    local isLegacyText = userMacroText == CHIJI_LEGACY_MACRO
    if isLegacyText then
        shouldMigrate = true
    elseif P8BA6426E.IsChineseClient and P8BA6426E.IsChineseClient() then
        shouldMigrate = true
    elseif type(P8BA6426E.CompileAuthorizedMacro) == "function" then
        local compiledLegacy = P8BA6426E.CompileAuthorizedMacro(CHIJI_LEGACY_MACRO, CHIJI_LEGACY_MACRO_REFS)
        if compiledLegacy then
            shouldMigrate = true
            isLegacyText = userMacroText == compiledLegacy
        end
    end
    if not shouldMigrate then
        return
    end
    if isLegacyText and not P8BA6426E.ClearUserMacro("cd_325197") then
        return
    end
    P8BA6426E.DB.mistweaverChijiHiddenUseMigrationVersion = CHIJI_MIGRATION_VERSION
end
local function toNonNegativeInt(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end
local function getSpecIDAndName()
    if not P8BA6426E.GetPlayerClassSpec then
        return nil, nil
    end
    local _classFile, _className, specID, specName = P8BA6426E.GetPlayerClassSpec()
    if type(specID) ~= "number" or specID <= 0 then
        return nil, nil
    end
    return specID, specName
end
-- 爆发开关“N 秒后自动关闭”设置（按专精保存）
function P8BA6426E.GetBurstAutoCloseSeconds()
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    local specID = getSpecIDAndName()
    if not specID then
        return 0
    end
    if P8BA6426E.DB.burstAutoCloseSeconds ~= nil then
        if P8BA6426E.DB.burstAutoCloseSecondsBySpec[specID] == nil then
            P8BA6426E.DB.burstAutoCloseSecondsBySpec[specID] = toNonNegativeInt(P8BA6426E.DB.burstAutoCloseSeconds)
        end
        P8BA6426E.DB.burstAutoCloseSeconds = nil
    end
    return toNonNegativeInt(P8BA6426E.DB.burstAutoCloseSecondsBySpec[specID])
end
function P8BA6426E.SaveBurstAutoCloseSeconds(seconds)
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    local specID, specName = getSpecIDAndName()
    if not specID then
        return false, 0, nil
    end
    local normalized = toNonNegativeInt(seconds)
    P8BA6426E.DB.burstAutoCloseSecondsBySpec[specID] = normalized
    P8BA6426E.DB.burstAutoCloseSeconds = nil
    P8BA6426E.ResetBurstAutoCloseTimer()
    return true, normalized, specName
end
P8BA6426E.burstAutoCloseGeneration = P8BA6426E.burstAutoCloseGeneration or 0
local burstAutoCloseTimer = nil
-- 重置爆发自动关闭计时器：爆发开启时启动 C_Timer，到时自动 SetBurstSwitch(false)
function P8BA6426E.ResetBurstAutoCloseTimer()
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    P8BA6426E.burstAutoCloseGeneration = P8BA6426E.burstAutoCloseGeneration + 1
    if burstAutoCloseTimer then
        burstAutoCloseTimer:Cancel()
        burstAutoCloseTimer = nil
    end
    if not P8BA6426E.DB.burstSwitch then
        return
    end
    local burstAutoCloseSeconds = P8BA6426E.GetBurstAutoCloseSeconds()
    if burstAutoCloseSeconds <= 0 then
        return
    end
    local generation = P8BA6426E.burstAutoCloseGeneration
    burstAutoCloseTimer = C_Timer.NewTimer(burstAutoCloseSeconds, function()
        if P8BA6426E.burstAutoCloseGeneration ~= generation then
            return
        end
        burstAutoCloseTimer = nil
        if not P8BA6426E.DB or not P8BA6426E.DB.burstSwitch then
            return
        end
        P8BA6426E.SetBurstSwitch(false)
    end)
end
function P8BA6426E.SetBurstSwitch(enabled)
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    P8BA6426E.DB.burstSwitch = not not enabled
    if P8BA6426E.UpdateBurstSwitchUI then
        P8BA6426E.UpdateBurstSwitchUI(P8BA6426E.DB.burstSwitch)
    end
    P8BA6426E.ResetBurstAutoCloseTimer()
end
local getSpellInfoCompat = GetSpellInfo
    or function(spellID)
        if not spellID then
            return nil
        end
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then
            return spellInfo.name,
                nil,
                spellInfo.iconID,
                spellInfo.castTime,
                spellInfo.minRange,
                spellInfo.maxRange,
                spellInfo.spellID,
                spellInfo.originalIconID
        end
    end
function P8BA6426E.SafeNumber(value)
    if type(value) == "number" then
        return tonumber(tostring(value)) or 0
    end
    return tonumber(value) or 0
end
local getSpellCooldownAPI = C_Spell and C_Spell.GetSpellCooldown or _G.GetSpellCooldown
local function getSpellCooldownSafe(spellID)
    if not spellID then
        return 0, 0, true
    end
    local startOrInfo, duration, isEnabled = getSpellCooldownAPI(spellID)
    if startOrInfo and type(startOrInfo) == "table" then
        return P8BA6426E.SafeNumber(startOrInfo.startTime),
            P8BA6426E.SafeNumber(startOrInfo.duration),
            startOrInfo.isEnabled ~= false
    elseif startOrInfo then
        return P8BA6426E.SafeNumber(startOrInfo), P8BA6426E.SafeNumber(duration), isEnabled
    end
    return 0, 0, true
end
P8BA6426E.IsSpellUsable = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
local LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
P8BA6426E.LibRangeCheck = LibStub and LibStub:GetLibrary(addonName .. "-RangeCheck-3.0", true)
local function fetchMedia(mediaType, key, fallback)
    if LSM then
        return LSM:Fetch(mediaType, key, true) or fallback
    end
    return fallback
end
local _tooltipBackground = fetchMedia("background", "Blizzard Tooltip", "Interface\\Tooltips\\UI-Tooltip-Background")
local _tooltipBorder = fetchMedia("border", "Blizzard Tooltip", "Interface\\Tooltips\\UI-Tooltip-Border")
P8BA6426E.fontFile = fetchMedia("font", "默认", "Fonts\\ARKai_T.ttf")
if not fetchMedia("font", "默认", nil) and LSM then
    P8BA6426E.fontFile = LSM:Fetch("font", LSM:GetDefault("font"), true) or "Fonts\\ARKai_T.ttf"
end
P8BA6426E.testSpells = {}
P8BA6426E.ACTION_LABELS = {}
P8BA6426E.ACTION_TO_KEY = {}
P8BA6426E.actionReadyCooldowns = {}
P8BA6426E.actionAvailSpellIDs = {}
-- —— 以下为“当前专精”运行时状态（loadClassData 时重置）——
local forceAvailableRules = {}
P8BA6426E.highlightRules = {}
P8BA6426E.trinketItemID = nil
P8BA6426E.consumableItems = {}
local consumableUsedAt = {}
local persistentBurstPotionRestored = false
local spellToConsumableID = {}
local pendingItemSpellLoads = {}
local trinketUsedAt = nil
local trinketCooldownDuration = nil
local lastCastTime = {}
local lastPlayerCastSpellID = nil
local lastCastGUID = nil
local lastCastSpellIDForDedup = nil
local lastCastDedupTime = 0
local _unusedConst1 = 1
P8BA6426E.playerSucceededGeneration = 1
P8BA6426E.playerSucceededSpellID = 0
P8BA6426E.forceAvailableState = {}
local inEncounterRestrictedZone = false
local function getPlayerGUID()
    if type(UnitGUID) ~= "function" then
        return nil
    end
    local guid = UnitGUID("player")
    if type(guid) ~= "string" or guid == "" then
        return nil
    end
    return guid
end
-- 按角色 GUID 存储的持久化冷却账本（用于跨 /reload 记住爆发药水冷却）
local function getPlayerCooldownLedger(create)
    if not P8BA6426E.DB then
        P8BA6426E.InitDB()
    end
    local guid = getPlayerGUID()
    if not guid then
        return nil
    end
    local persistentCooldownLedger = P8BA6426E.DB and P8BA6426E.DB.persistentCooldownLedger
    if type(persistentCooldownLedger) ~= "table" then
        if not create then
            return nil
        end
        persistentCooldownLedger = {}
        P8BA6426E.DB.persistentCooldownLedger = persistentCooldownLedger
    end
    local ledger = persistentCooldownLedger[guid]
    if type(ledger) ~= "table" then
        if not create then
            return nil
        end
        ledger = {}
        persistentCooldownLedger[guid] = ledger
    end
    return ledger
end
local CLOCK_DRIFT_TOLERANCE = 3
local BURST_POTION_ID = "item_burst_potion"
local BURST_POTION_LEDGER_KEY = "consumable:" .. BURST_POTION_ID
-- 由账本记录计算剩余冷却：优先使用会话时间（GetTime），与服务器时间偏差超过阈值时退回服务器时间
local function getLedgerRemaining(record, serverNow, sessionNow)
    if type(record) ~= "table" then
        local legacyExpiresAt = tonumber(record)
        return legacyExpiresAt and (legacyExpiresAt - serverNow) or nil
    end
    local serverRecordedAt = tonumber(record.serverRecordedAt)
    local serverExpiresAt = tonumber(record.serverExpiresAt)
    local sessionRecordedAt = tonumber(record.sessionRecordedAt)
    local sessionExpiresAt = tonumber(record.sessionExpiresAt)
    if serverRecordedAt and (sessionRecordedAt and sessionExpiresAt) then
        local serverElapsed = serverNow - serverRecordedAt
        local sessionElapsed = sessionNow - sessionRecordedAt
        if
            serverElapsed >= 0
            and (sessionElapsed >= 0 and math.abs(serverElapsed - sessionElapsed) <= CLOCK_DRIFT_TOLERANCE)
        then
            return sessionExpiresAt - sessionNow
        end
    end
    return serverExpiresAt and (serverExpiresAt - serverNow) or nil
end
local function newLedgerRecord(duration, serverRecordedAt, sessionRecordedAt)
    return {
        duration = duration,
        serverRecordedAt = serverRecordedAt,
        serverExpiresAt = serverRecordedAt + duration,
        sessionRecordedAt = sessionRecordedAt,
        sessionExpiresAt = sessionRecordedAt + duration,
    }
end
local function persistConsumableUse(consumableID, cooldown, usedAt)
    if consumableID ~= BURST_POTION_ID then
        return
    end
    persistentBurstPotionRestored = true
    cooldown = tonumber(cooldown)
    if not cooldown or cooldown <= 0 or type(GetServerTime) ~= "function" then
        return
    end
    local serverTime = GetServerTime()
    if type(serverTime) ~= "number" or serverTime <= 0 then
        return
    end
    usedAt = tonumber(usedAt) or GetTime()
    local ledger = getPlayerCooldownLedger(true)
    if ledger then
        ledger[BURST_POTION_LEDGER_KEY] = newLedgerRecord(cooldown, serverTime, usedAt)
    end
end
local function clearPersistedConsumable(consumableID)
    if consumableID ~= BURST_POTION_ID then
        return
    end
    persistentBurstPotionRestored = true
    consumableUsedAt[consumableID] = nil
    local ledger = getPlayerCooldownLedger(false)
    if ledger then
        ledger[BURST_POTION_LEDGER_KEY] = nil
    end
end
local function restoreConsumableFromLedger(consumable)
    if not consumable or consumable.id ~= BURST_POTION_ID then
        return false
    end
    persistentBurstPotionRestored = true
    local cooldown = tonumber(consumable.cooldown)
    if not cooldown or cooldown <= 0 or type(GetServerTime) ~= "function" then
        return false
    end
    local ledger = getPlayerCooldownLedger(false)
    if not ledger or ledger[BURST_POTION_LEDGER_KEY] == nil then
        return false
    end
    local serverTime = GetServerTime()
    local now = GetTime()
    if type(serverTime) ~= "number" or serverTime <= 0 then
        return false
    end
    local remaining = getLedgerRemaining(ledger[BURST_POTION_LEDGER_KEY], serverTime, now)
    if remaining and remaining > 0 then
        remaining = math.min(remaining, cooldown)
        consumableUsedAt[consumable.id] = now - (cooldown - remaining)
        return true
    end
    consumableUsedAt[consumable.id] = nil
    ledger[BURST_POTION_LEDGER_KEY] = nil
    return false
end
function P8BA6426E.RestorePersistentConsumableCooldowns()
    for _, consumableItem in ipairs(P8BA6426E.consumableItems or {}) do
        if consumableItem.id == BURST_POTION_ID then
            restoreConsumableFromLedger(consumableItem)
            return
        end
    end
end
function P8BA6426E.ClearPersistentCooldownsForGameReset()
    local ledger = getPlayerCooldownLedger(false)
    consumableUsedAt[BURST_POTION_ID] = nil
    persistentBurstPotionRestored = true
    if ledger then
        ledger[BURST_POTION_LEDGER_KEY] = nil
    end
end
local function isGameResetEvent(event, ...)
    if event == "CHALLENGE_MODE_START" then
        return true
    end
    if event == "ENCOUNTER_END" then
        local inInstance, instanceType = IsInInstance()
        return inInstance == true and instanceType == "raid"
    end
    return false
end
function P8BA6426E.IsPetSpell(spellID)
    local petSpells = P8BA6426E.classData and P8BA6426E.classData.petSpells
    return petSpells ~= nil and petSpells[spellID] == true
end
local function resolveCooldownAlias(spellID)
    local aliases = P8BA6426E.classData and P8BA6426E.classData.cooldownEventAliases
    return aliases and aliases[spellID] or spellID
end
-- 读取物品冷却剩余秒数；遇到受保护(secret)值或异常一律视为未知
local function getItemCooldownRemaining(itemID)
    if not itemID then
        return 0, false
    end
    local startTime, duration, isEnabled
    local queried = false
    local ok = pcall(function()
        if C_Item and C_Item.GetItemCooldown then
            local startOrInfo, rawDuration, rawEnabled = C_Item.GetItemCooldown(itemID)
            if type(startOrInfo) == "table" then
                startTime, duration, isEnabled = startOrInfo.startTime, startOrInfo.duration, startOrInfo.isEnabled
            else
                startTime, duration, isEnabled = startOrInfo, rawDuration, rawEnabled
            end
            queried = true
        elseif GetItemCooldown then
            startTime, duration, isEnabled = GetItemCooldown(itemID)
            queried = true
        end
    end)
    if
        not ok
        or not queried
        or (issecretvalue and (issecretvalue(startTime) or issecretvalue(duration) or issecretvalue(isEnabled)))
        or type(startTime) ~= "number"
        or type(duration) ~= "number"
        or isEnabled == nil
    then
        return 0, false
    end
    isEnabled = isEnabled == 1 or isEnabled == true
    if not isEnabled then
        return 0, false
    end
    if
        startTime ~= startTime
        or duration ~= duration
        or startTime < 0
        or duration < 0
        or startTime == math.huge
        or duration == math.huge
    then
        return 0, false
    end
    if duration > 0 and startTime > 0 then
        local remaining = duration - (GetTime() - startTime)
        if remaining > 0 then
            return math.ceil(remaining), true
        end
    end
    return 0, true
end
-- 建立“物品使用法术 ID → 消耗品动作 ID”映射，用于在 UNIT_SPELLCAST_SUCCEEDED 中识别喝药/吃石
local function rebuildConsumableSpellMap()
    spellToConsumableID = {}
    pendingItemSpellLoads = {}
    for _, consumableItem in ipairs(P8BA6426E.consumableItems) do
        for _, itemID in ipairs(consumableItem.itemIDs or {}) do
            local itemSpellID = nil
            pcall(function()
                if C_Item and C_Item.GetItemSpell then
                    itemSpellID = select(2, C_Item.GetItemSpell(itemID))
                end
            end)
            if itemSpellID then
                spellToConsumableID[itemSpellID] = consumableItem.id
            else
                pendingItemSpellLoads[itemID] = true
                if C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
            end
        end
        if consumableItem.spellIDs then
            for _, spellID in ipairs(consumableItem.spellIDs) do
                spellToConsumableID[spellID] = consumableItem.id
            end
        end
    end
    if P8BA6426E.trinketItemID then
        local trinketSpellID = nil
        pcall(function()
            if C_Item and C_Item.GetItemSpell then
                trinketSpellID = select(2, C_Item.GetItemSpell(P8BA6426E.trinketItemID))
            end
        end)
        if trinketSpellID then
            spellToConsumableID[trinketSpellID] = "trinketCD"
        end
    end
end
local function onItemDataLoaded(itemID, success)
    if success == false or not pendingItemSpellLoads[itemID] then
        return
    end
    rebuildConsumableSpellMap()
end
-- 消耗品剩余冷却：背包没有该物品返回 601（=不可用）；治疗石战斗中已用过也返回 601
function P8BA6426E.GetConsumableCooldownRemaining(consumable)
    if not consumable then
        return 0
    end
    local hasItem = false
    for _, itemID in ipairs(consumable.itemIDs or {}) do
        local itemCount = 0
        pcall(function()
            if C_Item and C_Item.GetItemCount then
                itemCount = C_Item.GetItemCount(itemID, false, false, true)
            elseif GetItemCount then
                itemCount = GetItemCount(itemID)
            end
        end)
        if itemCount > 0 then
            hasItem = true
            break
        end
    end
    if not hasItem then
        return 601
    end
    if consumable.id == "item_healing_stone" and (inEncounterRestrictedZone and InCombatLockdown()) then
        return 601
    end
    if consumable.id == BURST_POTION_ID and not persistentBurstPotionRestored then
        restoreConsumableFromLedger(consumable)
    end
    local entry = consumableUsedAt[consumable.id]
    if entry then
        local remaining = consumable.cooldown - (GetTime() - entry)
        if remaining > 0 then
            return math.ceil(remaining)
        end
        consumableUsedAt[consumable.id] = nil
        clearPersistedConsumable(consumable.id)
    end
    local maxRemaining = 0
    for _, itemID in ipairs(consumable.itemIDs or {}) do
        local itemRemaining = getItemCooldownRemaining(itemID)
        if itemRemaining > maxRemaining then
            maxRemaining = itemRemaining
        end
    end
    if maxRemaining > 0 then
        return maxRemaining
    end
    return 0
end
function P8BA6426E.GetConsumableCooldownFast(consumable, itemIDs)
    if not consumable then
        return 0, "unknown"
    end
    if consumable.id == BURST_POTION_ID and not persistentBurstPotionRestored then
        restoreConsumableFromLedger(consumable)
    end
    local entry = consumableUsedAt[consumable.id]
    if entry then
        local remaining = consumable.cooldown - (GetTime() - entry)
        if remaining > 0 then
            return math.ceil(remaining), "known"
        end
        consumableUsedAt[consumable.id] = nil
        clearPersistedConsumable(consumable.id)
    end
    local maxRemaining = 0
    local allKnown = true
    for _, itemID in ipairs(itemIDs or consumable.itemIDs or {}) do
        local itemRemaining, known = getItemCooldownRemaining(itemID)
        if not known then
            allKnown = false
        end
        if itemRemaining > maxRemaining then
            maxRemaining = itemRemaining
        end
    end
    if not allKnown then
        if itemIDs then
            return nil, "unknown"
        end
        return maxRemaining, "unknown"
    end
    return maxRemaining, "known"
end
function P8BA6426E.GetConsumableCooldownSample(consumable)
    if not consumable then
        return nil, "unknown"
    end
    if consumable.id == "item_healing_stone" and (inEncounterRestrictedZone and InCombatLockdown()) then
        return 601, "unavailable"
    end
    if not consumable.itemIDs or #consumable.itemIDs == 0 then
        return nil, "unknown"
    end
    local ownedItemIDs, allKnown = {}, true
    for _, itemID in ipairs(consumable.itemIDs or {}) do
        local ok, count = pcall(function()
            if C_Item and C_Item.GetItemCount then
                return C_Item.GetItemCount(itemID, false, false, true)
            end
            if GetItemCount then
                return GetItemCount(itemID)
            end
        end)
        if
            not ok
            or (issecretvalue and issecretvalue(count))
            or type(count) ~= "number"
            or count ~= count
            or count < 0
            or count == math.huge
        then
            allKnown = false
        elseif count > 0 then
            ownedItemIDs[#ownedItemIDs + 1] = itemID
        end
    end
    if not allKnown then
        return nil, "unknown"
    end
    if #ownedItemIDs == 0 then
        return 601, "unavailable"
    end
    return P8BA6426E.GetConsumableCooldownFast(consumable, ownedItemIDs)
end
-- 根据当前专精 ID 装载 P8BA6426E.classes[specID]（由各专精文件 RegisterClass 注册）的数据
loadClassData = function()
    P8BA6426E.classData = nil
    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization()
        or 0
    local specID = nil
    if specIndex and (specIndex > 0 and P8BA6426E.SpecializationAPI.GetSpecializationInfo) then
        specID = select(1, P8BA6426E.SpecializationAPI.GetSpecializationInfo(specIndex))
    end
    if specID and P8BA6426E.classes[specID] then
        P8BA6426E.classData = P8BA6426E.classes[specID]
        P8BA6426E.testSpells = P8BA6426E.classData.testSpells or {}
        P8BA6426E.ACTION_LABELS = P8BA6426E.classData.ACTION_LABELS or {}
        P8BA6426E.ACTION_TO_KEY = P8BA6426E.classData.ACTION_TO_KEY or {}
        P8BA6426E.actionReadyCooldowns = P8BA6426E.classData.actionReadyCooldowns or {}
        P8BA6426E.actionAvailSpellIDs = P8BA6426E.classData.actionAvailSpellIDs or {}
        forceAvailableRules = P8BA6426E.classData.forceAvailableRules or {}
        P8BA6426E.trinketItemID = P8BA6426E.classData.trinketItemID
        P8BA6426E.consumableItems = P8BA6426E.classData.consumableItems or {}
        consumableUsedAt = {}
        persistentBurstPotionRestored = false
        trinketUsedAt = nil
        trinketCooldownDuration = nil
        P8BA6426E.forceAvailableState = {}
        rebuildConsumableSpellMap()
        P8BA6426E.RestorePersistentConsumableCooldowns()
        if P8BA6426E.RefreshStateLogo then
            P8BA6426E.RefreshStateLogo()
        end
        P8BA6426E.isClassActive = true
        return specID
    end
    P8BA6426E.isClassActive = false
    P8BA6426E.testSpells = {}
    P8BA6426E.ACTION_LABELS = {}
    P8BA6426E.ACTION_TO_KEY = {}
    P8BA6426E.actionReadyCooldowns = {}
    P8BA6426E.actionAvailSpellIDs = {}
    forceAvailableRules = {}
    P8BA6426E.forceAvailableState = {}
    P8BA6426E.trinketItemID = nil
    P8BA6426E.consumableItems = {}
    consumableUsedAt = {}
    persistentBurstPotionRestored = false
    trinketUsedAt = nil
    trinketCooldownDuration = nil
    spellToConsumableID = {}
    pendingItemSpellLoads = {}
    return specID
end
-- 玩家/宠物施法成功事件：去重、记录技能/消耗品使用时间、更新强制可用状态、回调专精 OnSpellCast
local castEventFrame = CreateFrame("Frame")
castEventFrame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
    local cooldownSpellID = resolveCooldownAlias(spellID)
    if unit == "pet" and (cooldownSpellID and P8BA6426E.IsPetSpell(cooldownSpellID)) then
        lastCastTime[cooldownSpellID] = GetTime()
        return
    end
    if unit == "player" and spellID then
        local now = GetTime()
        local isDuplicate = false
        if castGUID then
            isDuplicate = castGUID == lastCastGUID
        else
            isDuplicate = lastCastSpellIDForDedup == spellID and (now - lastCastDedupTime) < 0.05
        end
        if not isDuplicate then
            lastCastGUID = castGUID
            lastCastSpellIDForDedup = spellID
            lastCastDedupTime = now
            if P8BA6426E.RecordFocusedSpellSuccess then
                P8BA6426E.RecordFocusedSpellSuccess(spellID, castGUID)
            end
        end
        if isDuplicate then
            return
        end
        local healFocusSpellIDs = P8BA6426E.classData and P8BA6426E.classData.HEAL_FOCUS_SPELL_IDS
        if healFocusSpellIDs and (P8BA6426E.IsRaidFocusFeedbackEnabled and P8BA6426E.RecordRaidFocusFeedback) then
            pcall(function()
                if healFocusSpellIDs[spellID] and P8BA6426E.IsRaidFocusFeedbackEnabled() then
                    P8BA6426E.RecordRaidFocusFeedback("success")
                end
            end)
        end
        lastCastTime[cooldownSpellID] = now
        lastPlayerCastSpellID = spellID
        P8BA6426E.lastCastSpellID = spellID
        local consumableID = spellToConsumableID[spellID]
        if consumableID then
            if consumableID == "trinketCD" then
                trinketUsedAt = now
            else
                consumableUsedAt[consumableID] = now
                for _, consumableItem in ipairs(P8BA6426E.consumableItems or {}) do
                    if consumableItem.id == consumableID then
                        persistConsumableUse(consumableID, consumableItem.cooldown, now)
                        break
                    end
                end
                if consumableID == "item_healing_stone" and InCombatLockdown() then
                    inEncounterRestrictedZone = true
                end
            end
        end
        if P8BA6426E.classData and P8BA6426E.classData.forceAvailableRules then
            local forceAvailableRule = P8BA6426E.classData.forceAvailableRules[spellID]
            if forceAvailableRule then
                if forceAvailableRule.setAvailable then
                    P8BA6426E.forceAvailableState[forceAvailableRule.setAvailable] = true
                end
                if forceAvailableRule.clearAvailable then
                    P8BA6426E.forceAvailableState[forceAvailableRule.clearAvailable] = false
                end
            end
        end
        if P8BA6426E.classData and P8BA6426E.classData.OnSpellCast then
            P8BA6426E.classData.OnSpellCast(spellID, consumableID)
        end
    end
end)
castEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
local combatEndFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(combatEndFrame, "PLAYER_REGEN_ENABLED")
combatEndFrame:SetScript("OnEvent", function(_, _)
    inEncounterRestrictedZone = false
end)
local combatEndTimeFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(combatEndTimeFrame, "PLAYER_REGEN_ENABLED")
combatEndTimeFrame:SetScript("OnEvent", function()
    P8BA6426E._lastCombatEnd = GetTime()
end)
function P8BA6426E.GetSpellCooldownRemaining(spellID)
    if not spellID then
        return 0
    end
    local startTime, duration, isEnabled = getSpellCooldownSafe(spellID)
    if not isEnabled then
        return 0
    end
    if duration and (duration > 0 and startTime) then
        local remaining = (startTime + duration) - GetTime()
        if remaining > 0 then
            return math.ceil(remaining)
        end
    end
    return 0
end
function P8BA6426E.GetActionReadyCooldownRemaining(spellID)
    local cooldownSeconds = P8BA6426E.actionReadyCooldowns and P8BA6426E.actionReadyCooldowns[spellID]
    if not cooldownSeconds then
        return P8BA6426E.GetSpellCooldownRemaining(spellID)
    end
    local castAt = lastCastTime[spellID] or 0
    if castAt == 0 then
        return 0
    end
    local remaining = cooldownSeconds - (GetTime() - castAt)
    if remaining <= 0 then
        lastCastTime[spellID] = nil
        return 0
    end
    return math.ceil(remaining)
end
P8BA6426E.lastCastTime = lastCastTime
local castGenerationCounter = 1
local lastCastIdentity = nil
local lastCastKind = nil
P8BA6426E.playerCastGeneration = 1
-- 读取玩家当前施法/引导状态，返回 (是否施法中, 剩余十分之一秒, 技能ID, 观测码)。观测码区分各种“读不到”的原因，供外部程序诊断
function P8BA6426E.GetPlayerCastState(includeChannel)
    local isCasting = false
    local remainingTenths = 0
    local castSpellID = 0
    local observationCode = 0
    local ok = pcall(function()
        local castName, _text, _texture, _startMS, endTimeMS, _isTradeSkill, _castID, _notInterruptible, castSpellIDRaw, castBarID =
            UnitCastingInfo("player")
        local castKind = "cast"
        if not castName and includeChannel == true then
            local channelName, _text, _texture, _startMS, channelEndMS, _isTradeSkill, _notInterruptible, channelSpellID, isEmpowered, _numStages, channelBarID =
                UnitChannelInfo("player")
            if channelName and isEmpowered ~= true then
                castName = channelName
                endTimeMS = channelEndMS
                castSpellIDRaw = channelSpellID
                castBarID = channelBarID
                castKind = "channel"
            elseif channelName then
                if isEmpowered == true then
                    lastCastIdentity = nil
                    lastCastKind = nil
                    if issecretvalue and issecretvalue(channelSpellID) then
                        observationCode = 19
                    elseif
                        type(channelSpellID) == "number"
                        and (channelSpellID > 1 and (channelSpellID < 16777215 and channelSpellID % 1 == 0))
                    then
                        castSpellID = channelSpellID
                        observationCode = 3
                    else
                        observationCode = 18
                    end
                    return
                end
            end
        end
        if not castName then
            lastCastIdentity = nil
            lastCastKind = nil
            return
        end
        if not endTimeMS then
            P8BA6426E.playerCastGeneration = 0
            observationCode = castKind == "channel" and 5 or 4
            return
        end
        if castName and endTimeMS then
            if issecretvalue and issecretvalue(endTimeMS) then
                P8BA6426E.playerCastGeneration = 0
                observationCode = castKind == "channel" and 7 or 6
                return
            end
            local remainingSeconds = (endTimeMS - GetTime() * 1000) / 1000
            if remainingSeconds > 0 then
                if issecretvalue and issecretvalue(castBarID) then
                    P8BA6426E.playerCastGeneration = 0
                    observationCode = castKind == "channel" and 13 or 12
                    return
                end
                if castBarID == nil then
                    P8BA6426E.playerCastGeneration = 0
                    observationCode = castKind == "channel" and 11 or 10
                    return
                end
                if castBarID ~= lastCastIdentity or castKind ~= lastCastKind then
                    castGenerationCounter = castGenerationCounter % 99 + 1
                    lastCastIdentity = castBarID
                    lastCastKind = castKind
                end
                P8BA6426E.playerCastGeneration = castGenerationCounter
                isCasting = true
                remainingTenths = math.floor(remainingSeconds * 10 + 0.5)
                if issecretvalue and issecretvalue(castSpellIDRaw) then
                    observationCode = castKind == "channel" and 17 or 16
                elseif
                    type(castSpellIDRaw) == "number"
                    and (castSpellIDRaw > 1 and (castSpellIDRaw < 16777215 and castSpellIDRaw % 1 == 0))
                then
                    castSpellID = castSpellIDRaw
                    observationCode = castKind == "channel" and 2 or 1
                else
                    observationCode = castKind == "channel" and 15 or 14
                end
            else
                observationCode = castKind == "channel" and 9 or 8
            end
        end
    end)
    if not ok then
        P8BA6426E.playerCastGeneration = 0
        observationCode = 20
    end
    return isCasting, remainingTenths, castSpellID, observationCode
end
-- 判断玩家是否正在引导指定技能，且当前处于引导的某个时间窗口（numerator/denominator）之后
function P8BA6426E.GetPlayerChannelWindowState(targetSpellID, windowNumerator, windowDenominator)
    local isTargetChannel = false
    local inWindow = false
    local reliable = true
    local ok = pcall(function()
        local channelName, _text, _texture, startMS, endMS, _isTradeSkill, _notInterruptible, channelSpellID, isEmpowered =
            UnitChannelInfo("player")
        if not channelName then
            return
        end
        if
            issecretvalue
            and (
                issecretvalue(startMS)
                or issecretvalue(endMS)
                or issecretvalue(channelSpellID)
                or issecretvalue(isEmpowered)
            )
        then
            reliable = false
            return
        end
        if isEmpowered == true then
            return
        end
        if type(channelSpellID) ~= "number" then
            reliable = false
            return
        end
        if channelSpellID ~= targetSpellID then
            return
        end
        isTargetChannel = true
        if
            type(startMS) ~= "number"
            or type(endMS) ~= "number"
            or type(windowNumerator) ~= "number"
            or type(windowDenominator) ~= "number"
            or windowDenominator <= 0
            or windowNumerator < 0
            or windowNumerator >= windowDenominator
            or endMS <= startMS
        then
            reliable = false
            return
        end
        local windowStartMS = startMS + ((endMS - startMS) * windowNumerator) / windowDenominator
        local nowMS = GetTime() * 1000
        inWindow = nowMS >= windowStartMS and nowMS < endMS
    end)
    if not ok then
        return false, false, false
    end
    return isTargetChannel, inWindow, reliable
end
function P8BA6426E.GetPlayerSucceededState()
    local playerSucceededGeneration = tonumber(P8BA6426E.playerSucceededGeneration) or 0
    local playerSucceededSpellID = tonumber(P8BA6426E.playerSucceededSpellID) or 0
    if playerSucceededGeneration < 1 or playerSucceededGeneration > 99 or playerSucceededGeneration % 1 ~= 0 then
        playerSucceededGeneration = 0
    end
    if playerSucceededSpellID <= 1 or playerSucceededSpellID >= 16777215 or playerSucceededSpellID % 1 ~= 0 then
        playerSucceededSpellID = 0
    end
    return playerSucceededGeneration, playerSucceededSpellID
end
-- —— 蓄力（唤魔师）技能状态跟踪 ——
local empowerGeneration = 0
local activeEmpower = nil
local finishedEmpower = nil
local trackedEmpowerSpellIDs = nil
local EMPOWER_RESULT_TTL = 0.35
local function findCurrentEmpowerSpell()
    if type(trackedEmpowerSpellIDs) ~= "table" or not C_Spell or type(C_Spell.IsCurrentSpell) ~= "function" then
        return nil
    end
    for _, spellID in ipairs(trackedEmpowerSpellIDs) do
        local ok, result = pcall(function()
            return C_Spell.IsCurrentSpell(spellID) == true
        end)
        if ok and result then
            return spellID
        end
    end
    return nil
end
local function parseEmpowerEvent(event, ...)
    local _unit, castGUIDRaw, spellIDRaw, eventArg4, eventArg5, eventArg6 = ...
    return pcall(function()
        local castBarIDRaw = nil
        local succeeded = nil
        if event == "UNIT_SPELLCAST_EMPOWER_START" then
            castBarIDRaw = eventArg4
        elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            if issecretvalue and issecretvalue(eventArg4) then
                succeeded = false
            else
                succeeded = eventArg4 == true
            end
            castBarIDRaw = eventArg6
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
            succeeded = false
            castBarIDRaw = eventArg4
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            succeeded = false
            castBarIDRaw = eventArg5
        else
            return nil
        end
        local castGUID = nil
        if
            not (issecretvalue and issecretvalue(castGUIDRaw)) and (type(castGUIDRaw) == "string" and castGUIDRaw ~= "")
        then
            castGUID = castGUIDRaw
        end
        local castBarID = nil
        if not (issecretvalue and issecretvalue(castBarIDRaw)) and type(castBarIDRaw) == "number" then
            castBarID = castBarIDRaw
        end
        if not castGUID and not castBarID then
            return nil
        end
        local spellID = nil
        if not (issecretvalue and issecretvalue(spellIDRaw)) and (type(spellIDRaw) == "number" and spellIDRaw > 1) then
            spellID = math.floor(spellIDRaw)
        end
        if event == "UNIT_SPELLCAST_EMPOWER_START" and not spellID then
            spellID = findCurrentEmpowerSpell()
        end
        return { spellID = spellID, castGUID = castGUID, castBarID = castBarID, succeeded = succeeded }
    end)
end
local function isSameCast(a, b)
    if a.castGUID and (b.castGUID and a.castGUID == b.castGUID) then
        return true
    end
    return a.castBarID and (b.castBarID and a.castBarID == b.castBarID)
end
local empowerEventFrame = CreateFrame("Frame")
empowerEventFrame:SetScript("OnEvent", function(_, event, ...)
    local ok, info = parseEmpowerEvent(event, ...)
    if not ok or type(info) ~= "table" then
        return
    end
    if event == "UNIT_SPELLCAST_EMPOWER_START" then
        if activeEmpower and isSameCast(activeEmpower, info) then
            if not activeEmpower.spellID then
                activeEmpower.spellID = info.spellID
            end
            return
        end
        empowerGeneration = empowerGeneration % 99 + 1
        activeEmpower = {
            spellID = info.spellID,
            castGUID = info.castGUID,
            castBarID = info.castBarID,
            generation = empowerGeneration,
        }
        finishedEmpower = nil
        return
    end
    if not activeEmpower or not isSameCast(activeEmpower, info) then
        return
    end
    if info.spellID then
        if activeEmpower.spellID and activeEmpower.spellID ~= info.spellID then
            return
        end
        activeEmpower.spellID = info.spellID
    end
    finishedEmpower = {
        spellID = activeEmpower.spellID,
        generation = activeEmpower.generation,
        succeeded = info.succeeded == true,
        expiresAt = GetTime() + EMPOWER_RESULT_TTL,
    }
    activeEmpower = nil
end)
empowerEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
empowerEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
empowerEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
empowerEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
empowerEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
local function listContains(list, target)
    for _, entry in ipairs(list) do
        if entry == target then
            return true
        end
    end
    return false
end
-- 返回 (蓄力技能ID, 已达阶段, 最大阶段)；刚结束的蓄力以 100/200+代数 形式短暂回报成功/失败
function P8BA6426E.GetPlayerEmpowerState(empowerSpellIDs)
    if type(empowerSpellIDs) ~= "table" then
        return 1, 0, 0
    end
    trackedEmpowerSpellIDs = empowerSpellIDs
    if finishedEmpower then
        if GetTime() > finishedEmpower.expiresAt then
            finishedEmpower = nil
        elseif listContains(empowerSpellIDs, finishedEmpower.spellID) then
            local resultBase = finishedEmpower.succeeded and 100 or 200
            return finishedEmpower.spellID, resultBase + finishedEmpower.generation, 0
        end
    end
    if not C_Spell or type(C_Spell.IsCurrentSpell) ~= "function" then
        return 1, 0, 0
    end
    local spellID = 0
    for _, entry in ipairs(empowerSpellIDs) do
        local ok, result = pcall(function()
            return C_Spell.IsCurrentSpell(entry) == true
        end)
        if not ok then
            return 1, 0, 0
        end
        if result then
            spellID = entry
            break
        end
    end
    if spellID > 0 and (activeEmpower and not activeEmpower.spellID) then
        activeEmpower.spellID = spellID
    end
    if not UnitChannelInfo then
        return spellID > 0 and spellID or 1, 0, 0
    end
    local ok, isEmpowered, numStages = pcall(function()
        local _name, _text, _texture, _startMS, _endMS, _isTradeSkill, _notInterruptible, _spellID, isEmpoweredRaw, numStagesRaw =
            UnitChannelInfo("player")
        if isEmpoweredRaw ~= true then
            return false, 0
        end
        if issecretvalue and issecretvalue(numStagesRaw) then
            return true, 0
        end
        return true, math.floor(tonumber(numStagesRaw) or 0)
    end)
    if not ok then
        return spellID > 0 and spellID or 1, 0, 0
    end
    if not isEmpowered then
        return spellID, 0, 0
    end
    if spellID == 0 then
        return 1, 0, 0
    end
    if numStages < 1 or not UnitEmpoweredStageDurations then
        return spellID, 0, 0
    end
    local ok, stageDurations = pcall(UnitEmpoweredStageDurations, "player")
    if not ok or type(stageDurations) ~= "table" or #stageDurations < numStages then
        return spellID, 0, numStages
    end
    local ok, reachedStage = pcall(function()
        local stage = 0
        for i = 1, numStages, 1 do
            local stageDuration = stageDurations[i]
            if not stageDuration or stageDuration:HasSecretValues() then
                return nil
            end
            if not stageDuration:HasExpired() then
                break
            end
            stage = i
        end
        return stage
    end)
    if not ok or type(reachedStage) ~= "number" then
        return spellID, 0, numStages
    end
    return spellID, reachedStage, numStages
end
function P8BA6426E.GetTrinketCooldownRemaining()
    if not P8BA6426E.trinketItemID then
        return 0
    end
    local equipped = false
    for i = 13, 14, 1 do
        if GetInventoryItemID("player", i) == P8BA6426E.trinketItemID then
            equipped = true
            break
        end
    end
    if not equipped then
        return 601
    end
    if trinketUsedAt and trinketCooldownDuration then
        local remaining = trinketCooldownDuration - (GetTime() - trinketUsedAt)
        if remaining > 0 then
            return math.ceil(remaining)
        end
        trinketUsedAt = nil
    end
    for i = 13, 14, 1 do
        local itemID = GetInventoryItemID("player", i)
        if itemID == P8BA6426E.trinketItemID then
            local startTime, duration, enable = GetInventoryItemCooldown("player", i)
            if enable == 1 and (duration > 0 and startTime > 0) then
                if duration < 10 then
                    return 0
                end
                local remaining = duration - (GetTime() - startTime)
                if remaining > 0 then
                    trinketCooldownDuration = duration
                    return math.ceil(remaining)
                end
            end
            break
        end
    end
    return 0
end
-- 读取 13/14 号饰品栏位冷却：返回 (秒数, "known"/"unknown"/"unavailable")
function P8BA6426E.GetTrinketSlotCooldownRemaining(slot)
    local ok, remaining, status = pcall(function()
        local itemID = GetInventoryItemID("player", slot)
        if not itemID then
            return 601, "unavailable"
        end
        if not C_Item or not C_Item.GetItemSpell then
            return nil, "unknown"
        end
        local itemSpellName, itemSpellID = C_Item.GetItemSpell(itemID)
        if not itemSpellName and not itemSpellID then
            if C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
            return nil, "unknown"
        end
        local startTime, duration, enable = GetInventoryItemCooldown("player", slot)
        if
            (issecretvalue and (issecretvalue(startTime) or issecretvalue(duration) or issecretvalue(enable)))
            or type(startTime) ~= "number"
            or type(duration) ~= "number"
            or enable == nil
            or startTime ~= startTime
            or duration ~= duration
            or startTime < 0
            or duration < 0
            or startTime == math.huge
            or duration == math.huge
        then
            return nil, "unknown"
        end
        if enable ~= 1 and enable ~= true then
            return nil, "unknown"
        end
        if duration <= 0 or startTime <= 0 then
            return 0, "known"
        end
        if duration < 10 then
            return 0, "known"
        end
        local remaining = duration - (GetTime() - startTime)
        if remaining <= 0 then
            return 0, "known"
        end
        return math.min(600, math.ceil(remaining)), "known"
    end)
    if not ok then
        return nil, "unknown"
    end
    return remaining, status
end
-- 公共冷却是否进行中（61304 为 GCD 虚拟技能）
function P8BA6426E.IsGcdActive()
    local ok, result = pcall(function()
        if not C_Spell or not C_Spell.GetSpellCooldown then
            return nil
        end
        return C_Spell.GetSpellCooldown(61304)
    end)
    if not ok or type(result) ~= "table" then
        return false
    end
    return result.isActive == true
end
P8BA6426E.LANG = nil
P8BA6426E._spellNameToID = P8BA6426E._spellNameToID or {}
local BUILTIN_SPELL_NAME_TO_ID = {
    ["狂风怒号"] = 454015,
    ["能量灌注"] = 10060,
    ["氤氲之雾"] = 124682,
    ["复苏之雾"] = 119611,
    ["活血术"] = 116670,
    ["清创生血"] = 115450,
    ["还魂术"] = 115310,
    ["治疗链"] = 1064,
    ["治疗波"] = 331,
    ["激流"] = 61295,
    ["召唤宠物 1"] = 883,
    ["复活宠物"] = 982,
    ["治疗宠物"] = 136,
}
for spellName, spellID in pairs(BUILTIN_SPELL_NAME_TO_ID) do
    if not P8BA6426E._spellNameToID[spellName] then
        P8BA6426E._spellNameToID[spellName] = spellID
    end
end
-- 本地化：中文客户端原样返回；否则查英文字典或用技能名→技能ID 取客户端技能名
function P8BA6426E.L(text)
    if P8BA6426E.IsChineseClient() then
        return text
    end
    local english = P8BA6426E._localeEN[text]
    if english then
        return english
    end
    local spellID = P8BA6426E._spellNameToID and P8BA6426E._spellNameToID[text]
    local localizedName = spellID and getSpellInfoCompat(spellID)
    return localizedName or text
end
function P8BA6426E.LocalizeActionLabel(actionKey, label)
    if P8BA6426E.IsChineseClient() then
        return label
    end
    if actionKey == "trinketCD" and P8BA6426E.trinketItemID then
        local itemName = C_Item and (C_Item.GetItemInfo and C_Item.GetItemInfo(P8BA6426E.trinketItemID))
        if itemName then
            return itemName
        end
    end
    if
        (tostring(actionKey)):match("_nearest$")
        or (P8BA6426E.classData and (P8BA6426E.classData.preserveLocalizedActionLabels and P8BA6426E.classData.preserveLocalizedActionLabels[actionKey]))
        or (tostring(actionKey)):match("_six_line$")
        or actionKey == "spell_5143_chain"
        or actionKey == "spell_44425_stopcasting"
        or actionKey == "spell_475"
        or actionKey == "spell_51886"
        or actionKey == "spell_213644"
        or actionKey == "spell_213644_player"
        or actionKey == "spell_218164"
        or actionKey == "spell_218164_player"
    then
        return P8BA6426E.L(label)
    end
    local spellID = tonumber(
        (tostring(actionKey)):match("spell_(%d+)")
            or (tostring(actionKey)):match("cd_(%d+)")
            or (tostring(actionKey)):match("seq_(%d+)")
    )
    local spellName = spellID and getSpellInfoCompat(spellID)
    if spellName then
        return spellName
    end
    local ENGLISH_FOCUS_LABELS = {
        focus_player = "Focus: Self",
        focus_party1 = "Focus: Party 1",
        focus_party2 = "Focus: Party 2",
        focus_party3 = "Focus: Party 3",
        focus_party4 = "Focus: Party 4",
        focus_mouseover = "Focus: Mouseover",
        focus_interrupt = "Focus Interrupt",
        focus_eruption = "Focus Eruption",
    }
    return ENGLISH_FOCUS_LABELS[actionKey] or P8BA6426E.L(label)
end
function P8BA6426E.GetClientLocale()
    return (GetLocale and GetLocale()) or "enUS"
end
function P8BA6426E.IsChineseClient()
    if P8BA6426E.LANG == "zh" then
        return true
    end
    if P8BA6426E.LANG == "en" then
        return false
    end
    local locale = P8BA6426E.GetClientLocale()
    return locale == "zhCN" or locale == "zhTW"
end
-- 把中文宏里的 /cast 技能名替换成客户端语言的技能名
function P8BA6426E.LocalizeMacroBody(macroBody)
    if not macroBody or macroBody == "" then
        return macroBody
    end
    if P8BA6426E.IsChineseClient() then
        return macroBody
    end
    local lines = { strsplit("\n", macroBody) }
    for i, line in ipairs(lines) do
        local command, conditions, argument = line:match("^(/%a+)%s*(%b[])%s*(.+)$")
        if not command then
            command, argument = line:match("^(/%a+)%s+(.+)$")
            conditions = nil
        end
        if command and argument then
            command = command:lower()
            if command == "/cast" or command == "/cancelaura" then
                argument = (argument:gsub("^%s+", "")):gsub("%s+$", "")
                local spellID = P8BA6426E._spellNameToID[argument]
                if spellID then
                    local localizedName = getSpellInfoCompat(spellID)
                    if localizedName then
                        if conditions then
                            lines[i] = command .. (" " .. (conditions .. (" " .. localizedName)))
                        else
                            lines[i] = command .. (" " .. localizedName)
                        end
                    end
                end
            end
        end
    end
    return table.concat(lines, "\n")
end
-- 动作的默认宏：优先治疗模式宏，其次专精 DEFAULT_MACROS，最后用 spell_<ID> 推导 /cast
function P8BA6426E.GetDefaultMacro(actionKey)
    local macroBody
    if
        P8BA6426E.IsForeverHealingSupported()
        and (
            P8BA6426E.IsHealingSpec()
            and (
                P8BA6426E.classData
                and (P8BA6426E.classData.foreverHealingMacros and P8BA6426E.classData.foreverHealingMacros[actionKey])
            )
        )
    then
        macroBody = P8BA6426E.classData.foreverHealingMacros[actionKey]
    elseif
        P8BA6426E.classData and (P8BA6426E.classData.DEFAULT_MACROS and P8BA6426E.classData.DEFAULT_MACROS[actionKey])
    then
        macroBody = P8BA6426E.classData.DEFAULT_MACROS[actionKey]
    else
        local spellID = tonumber(actionKey:match("spell_(%d+)") or actionKey:match("cd_(%d+)"))
        if not spellID then
            return ""
        end
        local spellName = getSpellInfoCompat(spellID)
        return spellName and ("/cast " .. spellName) or ""
    end
    return P8BA6426E.LocalizeMacroBody(macroBody)
end
P8BA6426E.errorLogs = {}
function P8BA6426E.AddErrorLog(kind, message)
    local timeValue = date("%H:%M:%S")
    table.insert(P8BA6426E.errorLogs, 1, { time = timeValue, type = kind, message = message })
    while #P8BA6426E.errorLogs > 50 do
        table.remove(P8BA6426E.errorLogs)
    end
    if P8BA6426E.RefreshErrorLog then
        P8BA6426E.RefreshErrorLog()
    end
end
function P8BA6426E.GetErrorLogs()
    return P8BA6426E.errorLogs
end
function P8BA6426E.ClearErrorLogs()
    wipe(P8BA6426E.errorLogs)
    if P8BA6426E.RefreshErrorLog then
        P8BA6426E.RefreshErrorLog()
    end
end
-- —— 安全按钮与按键绑定：每个动作创建一个隐藏的 SecureActionButton，并用 SetOverrideBinding 绑定到指定按键（外部程序模拟按键即可施法）——
local secureButtons = {}
local KEY_ALIASES = { NUMPADADD = "NUMPADPLUS", NUMPADSUBTRACT = "NUMPADMINUS" }
local function normalizeBindingKey(key)
    if type(key) ~= "string" then
        return key
    end
    local upperKey = key:upper()
    local hasAlt = upperKey:find("ALT%-") ~= nil
    local hasCtrl = upperKey:find("CTRL%-") ~= nil
    local hasShift = upperKey:find("SHIFT%-") ~= nil
    upperKey = ((upperKey:gsub("ALT%-", "")):gsub("CTRL%-", "")):gsub("SHIFT%-", "")
    upperKey = KEY_ALIASES[upperKey] or upperKey
    return (hasAlt and "ALT-" or "") .. ((hasCtrl and "CTRL-" or "") .. ((hasShift and "SHIFT-" or "") .. upperKey))
end
local overrideOwner = CreateFrame("Frame", "MKL_OverrideOwner")
local pendingEmpowerCVars = false
local empowerCVarRetryFrame = CreateFrame("Frame")
empowerCVarRetryFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not pendingEmpowerCVars then
        return
    end
    pendingEmpowerCVars = false
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "empowerTapControls", "1")
        pcall(C_CVar.SetCVar, "EmpowerTapControlsReleaseThreshold", "300")
    end
end)
local function applyEmpowerTapCVars()
    if not (C_CVar and C_CVar.SetCVar) then
        return
    end
    local okTap = pcall(C_CVar.SetCVar, "empowerTapControls", "1")
    local okThreshold = pcall(C_CVar.SetCVar, "EmpowerTapControlsReleaseThreshold", "300")
    if (not okTap or not okThreshold) and InCombatLockdown() then
        pendingEmpowerCVars = true
        P8BA6426E.SafeRegisterEvent(empowerCVarRetryFrame, "PLAYER_REGEN_ENABLED")
    end
end
local function isBindingApplied(key, expectedAction)
    if not (P8BA6426E.IsForeverHealingSupported and P8BA6426E.IsForeverHealingSupported()) then
        return true
    end
    if type(GetBindingAction) ~= "function" then
        return false
    end
    local ok, action = pcall(GetBindingAction, key, true)
    return ok and action == expectedAction
end
-- 创建/更新动作按钮并绑定按键；蓄力技能直接用 SetOverrideBindingSpell 绑定以支持“按住蓄力”
function P8BA6426E.CreateSecureButton(actionKey, bindingKey, macroText)
    local buttonName = "MKL_BTN_" .. actionKey
    local button = secureButtons[actionKey]
    if not button then
        button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 1, -1)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:Show()
        secureButtons[actionKey] = button
    end
    if not InCombatLockdown() then
        local directSpellID
        if
            P8BA6426E.classData
            and (P8BA6426E.classData.DIRECT_SPELL_ACTIONS and macroText == P8BA6426E.GetDefaultMacro(actionKey))
        then
            directSpellID = tonumber(P8BA6426E.classData.DIRECT_SPELL_ACTIONS[actionKey])
        end
        if directSpellID then
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", directSpellID)
            button:SetAttribute("macrotext", nil)
        else
            button:SetAttribute("type", "macro")
            button:SetAttribute("spell", nil)
            button:SetAttribute("macrotext", macroText)
        end
    else
    end
    local empowerSpellIDs = P8BA6426E.classData and P8BA6426E.classData.empowerSpellIDs
    local isEmpowerAction = false
    if type(empowerSpellIDs) == "table" then
        local actionSpellID = tonumber(actionKey and actionKey:match("spell_(%d+)"))
        for _, empowerSpellID in ipairs(empowerSpellIDs) do
            if empowerSpellID == actionSpellID then
                isEmpowerAction = true
                break
            end
        end
    end
    local normalizedKey = normalizeBindingKey(bindingKey)
    if isEmpowerAction then
        local spellID = tonumber(actionKey:match("spell_(%d+)"))
        local spellName = getSpellInfoCompat(spellID)
        if spellName then
            local ok, result = pcall(SetOverrideBindingSpell, overrideOwner, true, normalizedKey, spellName)
            if
                P8BA6426E.IsForeverHealingSupported
                and (
                    P8BA6426E.IsForeverHealingSupported()
                    and (not ok or result == false or not isBindingApplied(normalizedKey, "SPELL " .. spellName))
                )
            then
                return false
            end
            applyEmpowerTapCVars()
            return true
        end
    end
    local clickCommand = "CLICK " .. (buttonName .. ":LeftButton")
    local ok, result = pcall(SetOverrideBinding, overrideOwner, true, normalizedKey, clickCommand)
    return ok and (result ~= false and isBindingApplied(normalizedKey, clickCommand))
end
-- 创建“设焦点”按钮（type=focus），用于团队治疗选人
function P8BA6426E.CreateSecureFocusButton(actionKey, bindingKey, unit)
    local buttonName = "MKL_BTN_" .. actionKey
    local button = secureButtons[actionKey]
    if not button then
        button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 1, -1)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:Show()
        secureButtons[actionKey] = button
    end
    if not InCombatLockdown() then
        button:SetAttribute("type", "focus")
        button:SetAttribute("unit", unit)
        button:SetAttribute("spell", nil)
        button:SetAttribute("macrotext", nil)
    end
    local clickCommand = "CLICK " .. (buttonName .. ":LeftButton")
    local normalizedKey = normalizeBindingKey(bindingKey)
    local ok, result = pcall(SetOverrideBinding, overrideOwner, true, normalizedKey, clickCommand)
    return ok and (result ~= false and isBindingApplied(normalizedKey, clickCommand))
end
-- （全局函数）重建全部动作按键绑定：普通动作、团队焦点键、自动选怪键、治疗模式键
ApplyMacros_Internal = function()
    if InCombatLockdown() then
        overrideOwner.pendingMacroBindings = true
        return false
    end
    overrideOwner.pendingMacroBindings = nil
    local isForeverHealingSupported = P8BA6426E.IsForeverHealingSupported and P8BA6426E.IsForeverHealingSupported()
    local allApplied = true
    if P8BA6426E.InvalidateForeverHealingModeBindings then
        P8BA6426E.InvalidateForeverHealingModeBindings()
    end
    migrateMistweaverChijiMacro()
    ClearOverrideBindings(overrideOwner)
    for actionKey, bindingKey in pairs(P8BA6426E.ACTION_TO_KEY or {}) do
        local isFocusAction = actionKey == "focus_player"
            or actionKey == "focus_mouseover"
            or actionKey:match("^focus_party[1-4]$")
        if not (P8BA6426E.IsForeverHealingSupported() and (isFocusAction and not P8BA6426E.IsHealingSpec())) then
            local macroText = P8BA6426E.GetDefaultMacro(actionKey)
            local hasUserMacro, userMacroText = P8BA6426E.GetUserMacro(actionKey)
            if hasUserMacro then
                macroText = userMacroText
            end
            if macroText and macroText:find("spell:%d+") then
                macroText = nil
                hasUserMacro = false
            end
            if not hasUserMacro and (not macroText or macroText == "") then
                macroText = P8BA6426E.GetDefaultMacro(actionKey)
            end
            local ok, result = pcall(P8BA6426E.CreateSecureButton, actionKey, bindingKey, macroText)
            if isForeverHealingSupported and (not ok or result ~= true) then
                allApplied = false
            end
            if not ok then
            end
        end
    end
    if P8BA6426E.ApplyRaidFocusBindings then
        local ok, result = pcall(P8BA6426E.ApplyRaidFocusBindings)
        if isForeverHealingSupported and (not ok or result ~= true) then
            allApplied = false
        end
    end
    if P8BA6426E.ApplyAutoTargetBinding then
        pcall(P8BA6426E.ApplyAutoTargetBinding)
    end
    if P8BA6426E.ApplyForeverHealingModeBindings then
        local ok, result = pcall(P8BA6426E.ApplyForeverHealingModeBindings)
        if isForeverHealingSupported and (not ok or result ~= true) then
            allApplied = false
        end
    elseif isForeverHealingSupported then
        allApplied = false
    end
    if P8BA6426E.InvalidateControlBindingConflicts then
        P8BA6426E.InvalidateControlBindingConflicts()
    end
    return allApplied
end
refreshMacroBindings = function()
    local inCombat = InCombatLockdown()
    local ok, result = pcall(ApplyMacros_Internal)
    if not ok then
    end
    if inCombat then
        return false
    end
    if P8BA6426E.SetForeverHealingBindingsReady then
        P8BA6426E.SetForeverHealingBindingsReady(ok and result == true)
    end
    if
        P8BA6426E.IsForeverHealingSupported
        and (P8BA6426E.IsForeverHealingSupported() and ((not ok or result ~= true) and P8BA6426E.AddErrorLog))
    then
        P8BA6426E.AddErrorLog("ForeverHealingMode", P8BA6426E.L("治疗模式"))
    end
    return ok and result == true
end
P8BA6426E.RefreshMacroBindings = refreshMacroBindings
P8BA6426E.SafeRegisterEvent(overrideOwner, "UPDATE_BINDINGS")
P8BA6426E.SafeRegisterEvent(overrideOwner, "PLAYER_ENTERING_WORLD")
P8BA6426E.SafeRegisterEvent(overrideOwner, "PLAYER_REGEN_ENABLED")
overrideOwner:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_BINDINGS" then
        C_Timer.After(0, function()
            refreshMacroBindings()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        for _, delay in ipairs({ 3, 6, 9 }) do
            C_Timer.After(delay, function()
                refreshMacroBindings()
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" and self.pendingMacroBindings then
        refreshMacroBindings()
    end
end)
do
    -- 移除可能被外部按键误触的“切换声音/音乐/界面”等组合键绑定，并备份到 SavedVariables
    local SENSITIVE_BINDING_ACTIONS = { "TOGGLESOUND", "TOGGLEMUSIC", "TOGGLEAMBIENCE", "TOGGLEUI" }
    local sensitiveBindingFrame = CreateFrame("Frame")
    local pendingSensitiveCleanup = false
    local function removeSensitiveModifierBindings()
        if InCombatLockdown() then
            pendingSensitiveCleanup = true
            return
        end
        pendingSensitiveCleanup = false
        if not P8BA6426E.DB then
            return
        end
        local bindingSet = GetCurrentBindingSet()
        if bindingSet ~= 1 and bindingSet ~= 2 then
            return
        end
        local ownerKey = bindingSet == 1 and "account" or UnitGUID("player")
        if not ownerKey then
            return
        end
        local changed = false
        for _, action in ipairs(SENSITIVE_BINDING_ACTIONS) do
            local context = C_KeyBindings.GetBindingContextForAction(action)
            local keys = { GetBindingKey(action, nil, context) }
            for _, key in pairs(keys) do
                if
                    type(key) == "string"
                    and (
                        (key:find("^CTRL%-") or key:find("^ALT%-") or key:find("^SHIFT%-"))
                        and GetBindingAction(key, nil, context) == action
                    )
                then
                    local removedSensitiveBindings = P8BA6426E.DB.removedSensitiveBindings or {}
                    P8BA6426E.DB.removedSensitiveBindings = removedSensitiveBindings
                    removedSensitiveBindings[ownerKey] = removedSensitiveBindings[ownerKey] or {}
                    local recordKey = tostring(context) .. (":" .. key)
                    removedSensitiveBindings[ownerKey][recordKey] = removedSensitiveBindings[ownerKey][recordKey]
                        or { key = key, action = action, context = context }
                    if SetBinding(key, nil, context) then
                        changed = true
                    end
                end
            end
        end
        if changed then
            SaveBindings(bindingSet)
        end
    end
    P8BA6426E.SafeRegisterEvent(sensitiveBindingFrame, "PLAYER_ENTERING_WORLD")
    P8BA6426E.SafeRegisterEvent(sensitiveBindingFrame, "PLAYER_REGEN_ENABLED")
    sensitiveBindingFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or pendingSensitiveCleanup then
            pcall(removeSensitiveModifierBindings)
        end
    end)
end
-- 专精注册：保存专精定义，并从默认宏/动作标签中收集“技能名→技能ID”映射用于本地化
function P8BA6426E.RegisterClass(specID, classDef)
    P8BA6426E.classes[specID] = classDef
    if classDef.DEFAULT_MACROS then
        for defaultMacroKey, defaultMacro in pairs(classDef.DEFAULT_MACROS) do
            local spellID = tonumber(
                defaultMacroKey:match("spell_(%d+)")
                    or defaultMacroKey:match("cd_(%d+)")
                    or defaultMacroKey:match("seq_(%d+)")
            )
            if spellID and type(defaultMacro) == "string" then
                local isFirstCast = true
                for line in gmatch(defaultMacro, "[^\n]+") do
                    local spellName = line:match("^/cast%s+%b[]%s*(.+)$")
                    if not spellName then
                        spellName = line:match("^/cast%s+(.+)$")
                    end
                    if spellName and spellName ~= "" then
                        spellName = (spellName:gsub("^%s+", "")):gsub("%s+$", "")
                        if spellName ~= "" and (isFirstCast and not P8BA6426E._spellNameToID[spellName]) then
                            P8BA6426E._spellNameToID[spellName] = spellID
                        end
                        isFirstCast = false
                    else
                        if not line:match("^/cast") then
                        end
                    end
                end
            end
        end
    end
    local contract = P8BA6426E.FontPixelContracts and P8BA6426E.FontPixelContracts[specID]
    if contract then
        for _, scalarRecord in ipairs(contract.scalarRecords or {}) do
            if
                scalarRecord.scope == "module"
                and (scalarRecord.spellID and (scalarRecord.label and not P8BA6426E._spellNameToID[scalarRecord.label]))
            then
                P8BA6426E._spellNameToID[scalarRecord.label] = scalarRecord.spellID
            end
        end
    end
    if classDef.ACTION_LABELS then
        for actionLabelKey, actionLabel in pairs(classDef.ACTION_LABELS) do
            local spellID = tonumber(
                actionLabelKey:match("spell_(%d+)")
                    or actionLabelKey:match("cd_(%d+)")
                    or actionLabelKey:match("seq_(%d+)")
            )
            if spellID and (actionLabel and not P8BA6426E._spellNameToID[actionLabel]) then
                P8BA6426E._spellNameToID[actionLabel] = spellID
            end
        end
    end
    if IsLoggedIn and IsLoggedIn() then
        local currentSpec = select(3, P8BA6426E.GetPlayerClassSpec())
        if currentSpec == specID then
            loadClassData()
            refreshMacroBindings()
            P8BA6426E.RebuildPixelBars()
            if P8BA6426E.RefreshDockButtonColors then
                P8BA6426E.RefreshDockButtonColors()
            end
        end
    end
end
local coreEventFrame = CreateFrame("Frame")
local specCheckToken = 0
local function scheduleSpecCheck()
    if not (C_Timer and C_Timer.After) then
        return
    end
    specCheckToken = specCheckToken + 1
    local token = specCheckToken
    C_Timer.After(0.3, function()
        if token ~= specCheckToken then
            return
        end
        P8BA6426E.CheckSpecChange()
    end)
end
local errorSpeechFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(errorSpeechFrame, "PLAYER_ENTERING_WORLD")
errorSpeechFrame:SetScript("OnEvent", function()
    pcall(SetCVar, "Sound_EnableErrorSpeech", "0")
    if UIErrorsFrame then
        pcall(UIErrorsFrame.UnregisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
    end
end)
-- 返回 (职业文件名, 专精序号, 专精ID, 专精名)
function P8BA6426E.GetPlayerClassSpec()
    local className, classFile = UnitClass("player")
    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization()
        or 0
    local specID, specName = nil, nil
    if specIndex and (specIndex > 0 and P8BA6426E.SpecializationAPI.GetSpecializationInfo) then
        specID, specName = P8BA6426E.SpecializationAPI.GetSpecializationInfo(specIndex)
    end
    return classFile or "UNKNOWN", specIndex or 0, specID or 0, specName or P8BA6426E.L("未知")
end
function P8BA6426E.IsForeverHealingSupported()
    return P8BA6426E.classData ~= nil
        and (P8BA6426E.classData.healingModeSwitchEnabled == true and P8BA6426E.classData.raidFocusEnabled == true)
end
function P8BA6426E.SetForeverHealingMode(enabled)
    if not P8BA6426E.IsForeverHealingSupported() or InCombatLockdown() then
        return false
    end
    local previousMode = P8BA6426E.DB.foreverHealingMode == true
    local desiredMode = enabled == true
    if
        previousMode == desiredMode
        and (P8BA6426E.GetForeverHealingBindingsReady and P8BA6426E.GetForeverHealingBindingsReady())
    then
        return true
    end
    P8BA6426E.DB.foreverHealingMode = desiredMode
    local ok, applied = pcall(P8BA6426E.RefreshMacroBindings)
    local success = ok and applied == true
    if success and P8BA6426E.RebuildPixelBars then
        success = pcall(P8BA6426E.RebuildPixelBars)
    end
    if success then
        return true
    end
    P8BA6426E.DB.foreverHealingMode = previousMode
    if P8BA6426E.RefreshMacroBindings then
        pcall(P8BA6426E.RefreshMacroBindings)
    end
    if P8BA6426E.RebuildPixelBars then
        pcall(P8BA6426E.RebuildPixelBars)
    end
    if P8BA6426E.SetForeverHealingBindingsReady then
        P8BA6426E.SetForeverHealingBindingsReady(false)
    end
    if P8BA6426E.AddErrorLog then
        P8BA6426E.AddErrorLog("ForeverHealingMode", P8BA6426E.L("治疗模式") .. (": " .. tostring(applied)))
    end
    return false
end
function P8BA6426E.IsHealingSpec()
    if P8BA6426E.IsForeverHealingSupported and P8BA6426E.IsForeverHealingSupported() then
        return P8BA6426E.DB ~= nil and P8BA6426E.DB.foreverHealingMode == true
    end
    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization()
        or 0
    if specIndex <= 0 or not P8BA6426E.SpecializationAPI.GetSpecializationRole then
        return false
    end
    return P8BA6426E.SpecializationAPI.GetSpecializationRole(specIndex) == "HEALER"
end
local function isProtectionPaladin()
    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization()
        or 0
    if specIndex <= 0 or not P8BA6426E.SpecializationAPI.GetSpecializationInfo then
        return false
    end
    return P8BA6426E.SpecializationAPI.GetSpecializationInfo(specIndex) == 66
end
function P8BA6426E.GetAutoTargetEnabled()
    if P8BA6426E.IsHealingSpec() then
        return P8BA6426E.DB.healerAutoTarget == true
    end
    if isProtectionPaladin() then
        return P8BA6426E.DB.protectionPaladinAutoTarget == true
    end
    return P8BA6426E.DB.autoTarget == true
end
function P8BA6426E.SetAutoTargetEnabled(enabled)
    if P8BA6426E.IsHealingSpec() then
        P8BA6426E.DB.healerAutoTarget = enabled == true
    elseif isProtectionPaladin() then
        P8BA6426E.DB.protectionPaladinAutoTarget = enabled == true
    else
        P8BA6426E.DB.autoTarget = enabled == true
    end
end
local MELEE_SPECS_BY_FLAVOR = {
    retail = {
        [250] = true,
        [251] = true,
        [252] = true,
        [577] = true,
        [581] = true,
        [103] = true,
        [104] = true,
        [255] = true,
        [268] = true,
        [269] = true,
        [66] = true,
        [70] = true,
        [259] = true,
        [260] = true,
        [261] = true,
        [263] = true,
        [71] = true,
        [72] = true,
        [73] = true,
    },
    forever = { [1491] = true, [1488] = true, [1484] = true, [1486] = true, [1489] = true },
}
local MELEE_SPECS = MELEE_SPECS_BY_FLAVOR[P8BA6426E.flavor] or MELEE_SPECS_BY_FLAVOR.retail
function P8BA6426E.IsMeleeSpec()
    if P8BA6426E.IsForeverHealingSupported() and P8BA6426E.IsHealingSpec() then
        return false
    end
    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization()
        or 0
    if specIndex <= 0 or not P8BA6426E.SpecializationAPI.GetSpecializationInfo then
        return true
    end
    return MELEE_SPECS[P8BA6426E.SpecializationAPI.GetSpecializationInfo(specIndex) or 0] == true
end
function P8BA6426E.IsRangedDamageSpec()
    if P8BA6426E.IsForeverHealingSupported() and P8BA6426E.IsHealingSpec() then
        return false
    end
    local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization and P8BA6426E.SpecializationAPI.GetSpecialization()
        or 0
    return specIndex > 0
        and (
            P8BA6426E.SpecializationAPI.GetSpecializationRole
            and (
                P8BA6426E.SpecializationAPI.GetSpecializationRole(specIndex) == "DAMAGER"
                and not P8BA6426E.IsMeleeSpec()
            )
        )
end
-- 自动选怪/总开关门控：决定本帧是否允许外部程序动作（输出到 master_switch 像素）
function P8BA6426E.IsAutoTargetGateOpen(nearbyEnemyCount)
    if
        P8BA6426E.IsHealingSpec()
        and (type(P8BA6426E.HasHealingNpcMouseover) == "function" and P8BA6426E.HasHealingNpcMouseover())
    then
        return true
    end
    local autoTargetEnabled = P8BA6426E.GetAutoTargetEnabled()
    if autoTargetEnabled then
        local specIndex = P8BA6426E.SpecializationAPI.GetSpecialization
                and P8BA6426E.SpecializationAPI.GetSpecialization()
            or 0
        local role = specIndex > 0
            and (
                P8BA6426E.SpecializationAPI.GetSpecializationRole
                and P8BA6426E.SpecializationAPI.GetSpecializationRole(specIndex)
            )
        local isDpsOrTank = not P8BA6426E.IsHealingSpec() and (role == "DAMAGER" or role == "TANK")
        if not isDpsOrTank or UnitAffectingCombat("player") then
            if P8BA6426E.IsRangedDamageSpec() then
                return P8BA6426E.IsRemoteAutoTargetGateOpen()
            end
            return true
        end
    end
    local hasHostileTarget = UnitExists("target")
        and (not UnitIsDeadOrGhost("target") and UnitCanAttack("player", "target"))
    if hasHostileTarget then
        return true
    end
    return not autoTargetEnabled
        and (P8BA6426E.IsMeleeSpec() and (not IsStealthed() and (tonumber(nearbyEnemyCount) or 0) >= 1))
end
local function syncSpecToDB()
    P8BA6426E.UpdateClassSpecDB()
end
-- 专精或英雄天赋变化时：同步数据库、重新装载专精数据、重建像素条和按键绑定
function P8BA6426E.CheckSpecChange()
    local _classFile, _specIndex, specID = P8BA6426E.GetPlayerClassSpec()
    local heroSpecID = P8BA6426E.GetActiveHeroTalentSpecID()
    local specChanged = specID and specID ~= currentSpecID
    local heroChanged = heroSpecID ~= currentHeroSpecID
    if specChanged or heroChanged then
        currentSpecID = specID
        currentHeroSpecID = heroSpecID
        syncSpecToDB()
        if specChanged then
            local loadedSpecID = loadClassData()
            if loadedSpecID then
                P8BA6426E.RebuildPixelBars()
                refreshMacroBindings()
            end
            if P8BA6426E.RefreshBurstAutoCloseSettingUI then
                P8BA6426E.RefreshBurstAutoCloseSettingUI()
            end
            if P8BA6426E.RefreshAutoTargetSettingUI then
                P8BA6426E.RefreshAutoTargetSettingUI()
            end
            if P8BA6426E.RefreshControlKeySettingUI then
                P8BA6426E.RefreshControlKeySettingUI()
            end
            P8BA6426E.ResetBurstAutoCloseTimer()
        end
    end
    return specID
end
-- —— 焦点治疗失败配对：把 UNIT_SPELLCAST_FAILED 与 UI_ERROR_MESSAGE（距离/视野）配对，得出“焦点不可达”反馈 ——
local focusUnreachableUntil = 0
local focusCastFailedAt = 0
local focusErrorAt = 0
local focusErrorReason = nil
local focusFailureIsNew = false
local lastFailedCastGUID = nil
local lastFailedCastAt = 0
local seenFailedCastGUIDs = {}
local seenFailedCastGUIDOrder = {}
local MAX_SEEN_CAST_GUIDS = 64
local FAILURE_PAIR_WINDOW = 0.6
local UNREACHABLE_HOLD = 0.3
local UNREACHABLE_ERROR_GLOBALS = {
    { "SPELL_FAILED_OUT_OF_RANGE", "range" },
    { "SPELL_FAILED_LINE_OF_SIGHT", "los" },
    {
        "ERR_OUT_OF_RANGE",
        "range",
    },
}
local UNREACHABLE_ERROR_TEXTS = {
    zhCN = { { "距离太远", "range" }, { "目标不在射程内", "range" }, { "目标不在视野中", "los" } },
    enUS = { { "Out of range", "range" }, { "Target not in line of sight", "los" } },
    enGB = { { "Out of range", "range" }, { "Target not in line of sight", "los" } },
}
local function classifyErrorMessage(message)
    if type(message) ~= "string" then
        return false
    end
    for _, pair in ipairs(UNREACHABLE_ERROR_GLOBALS) do
        local globalText = rawget(_G, pair[1])
        if type(globalText) == "string" and message == globalText then
            return pair[2]
        end
    end
    local localePairs = UNREACHABLE_ERROR_TEXTS[GetLocale() or ""]
    for _, pair in ipairs(localePairs or {}) do
        if message == pair[1] then
            return pair[2]
        end
    end
    return nil
end
function P8BA6426E.ClearFocusHealFailurePair()
    focusCastFailedAt = 0
    focusErrorAt = 0
    focusErrorReason = nil
    focusFailureIsNew = false
    lastFailedCastGUID = nil
    lastFailedCastAt = 0
    for guid in pairs(seenFailedCastGUIDs) do
        seenFailedCastGUIDs[guid] = nil
    end
    for i = #seenFailedCastGUIDOrder, 1, -1 do
        seenFailedCastGUIDOrder[i] = nil
    end
end
local function rememberFailedCast(castGUID)
    if not castGUID or seenFailedCastGUIDs[castGUID] then
        return false
    end
    seenFailedCastGUIDs[castGUID] = true
    seenFailedCastGUIDOrder[#seenFailedCastGUIDOrder + 1] = castGUID
    if #seenFailedCastGUIDOrder > MAX_SEEN_CAST_GUIDS then
        local removed = table.remove(seenFailedCastGUIDOrder, 1)
        seenFailedCastGUIDs[removed] = nil
    end
    return true
end
local function tryPairFocusFailure(now)
    if focusCastFailedAt <= 0 or focusErrorAt <= 0 or not focusErrorReason then
        return false
    end
    local delta = focusCastFailedAt - focusErrorAt
    if math.abs(delta) >= FAILURE_PAIR_WINDOW then
        if delta < 0 then
            focusCastFailedAt = 0
            focusFailureIsNew = false
        else
            focusErrorAt = 0
            focusErrorReason = nil
        end
        return false
    end
    focusUnreachableUntil = now + UNREACHABLE_HOLD
    local reason = focusErrorReason
    local isNew = focusFailureIsNew
    focusCastFailedAt = 0
    focusErrorAt = 0
    focusErrorReason = nil
    focusFailureIsNew = false
    if isNew and (P8BA6426E.IsRaidFocusFeedbackEnabled and P8BA6426E.RecordRaidFocusFeedback) then
        pcall(function()
            if P8BA6426E.IsRaidFocusFeedbackEnabled() then
                P8BA6426E.RecordRaidFocusFeedback(reason)
            end
        end)
    end
    return true
end
function P8BA6426E.GetFocusCastUnreachable()
    return GetTime() < focusUnreachableUntil
end
-- 登录完成后的核心事件处理
local function onCoreEvent(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        P8BA6426E.aoeMode = 0
        if P8BA6426E.RefreshStateLogo then
            P8BA6426E.RefreshStateLogo()
        end
    elseif isGameResetEvent(event, ...) then
        P8BA6426E.ClearPersistentCooldownsForGameReset()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        onItemDataLoaded(...)
    elseif event == "UNIT_SPELLCAST_FAILED" then
        local unit, castGUID, spellID = ...
        if unit == "player" then
            if P8BA6426E.classData and P8BA6426E.classData.OnSpellCastFailed then
                P8BA6426E.classData.OnSpellCastFailed(spellID, spellToConsumableID[spellID])
            end
            local healFocusSpellIDs = P8BA6426E.classData and P8BA6426E.classData.HEAL_FOCUS_SPELL_IDS
            if healFocusSpellIDs then
                pcall(function()
                    if spellID and healFocusSpellIDs[spellID] then
                        local now = GetTime()
                        if castGUID ~= lastFailedCastGUID or (now - lastFailedCastAt) > 0.5 then
                            lastFailedCastGUID = castGUID
                            lastFailedCastAt = now
                            local newGUID = nil
                            if
                                not (issecretvalue and issecretvalue(castGUID))
                                and (type(castGUID) == "string" and castGUID ~= "")
                            then
                                newGUID = castGUID
                            end
                            focusFailureIsNew = rememberFailedCast(newGUID)
                            focusCastFailedAt = now
                            tryPairFocusFailure(now)
                        end
                    end
                end)
            end
        end
    elseif event == "UI_ERROR_MESSAGE" then
        local _messageType, message = ...
        if message then
            pcall(function()
                local reason = classifyErrorMessage(message)
                if reason then
                    local now = GetTime()
                    focusErrorAt = now
                    focusErrorReason = reason
                    tryPairFocusFailure(now)
                end
            end)
        end
    elseif
        event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "SPELLS_CHANGED"
    then
        P8BA6426E.ClearFocusHealFailurePair()
        P8BA6426E.CheckSpecChange()
        scheduleSpecCheck()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        if P8BA6426E.RebuildPixelBars then
            P8BA6426E.RebuildPixelBars()
        end
    end
end
local function registerCoreEvents(frame)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    local CORE_EVENTS = {
        "PLAYER_ENTERING_WORLD",
        "ACTIVE_TALENT_GROUP_CHANGED",
        "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
        "TRAIT_CONFIG_UPDATED",
        "PLAYER_TALENT_UPDATE",
        "SPELLS_CHANGED",
        "GET_ITEM_INFO_RECEIVED",
        "CHALLENGE_MODE_START",
        "ENCOUNTER_END",
        "DISPLAY_SIZE_CHANGED",
        "UI_SCALE_CHANGED",
        "UI_ERROR_MESSAGE",
    }
    for _, event in ipairs(CORE_EVENTS) do
        local valid = true
        if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
            local ok, result = pcall(C_EventUtils.IsEventValid, event)
            valid = ok and result == true
        end
        if valid then
            frame:RegisterEvent(event)
        end
    end
end
-- 首次加载：ADDON_LOADED 初始化数据库，PLAYER_LOGIN 完成全部初始化后切换到 onCoreEvent
coreEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            P8BA6426E.InitDB()
        end
    elseif event == "PLAYER_LOGIN" then
        P8BA6426E.InitDB()
        syncSpecToDB()
        currentSpecID = select(3, P8BA6426E.GetPlayerClassSpec())
        currentHeroSpecID = P8BA6426E.DB.currentHeroSpecID
        loadClassData()
        P8BA6426E.ResetBurstAutoCloseTimer()
        refreshMacroBindings()
        P8BA6426E.RebuildPixelBars()
        if P8BA6426E.RefreshDockButtonColors then
            P8BA6426E.RefreshDockButtonColors()
        end
        self:UnregisterEvent("PLAYER_LOGIN")
        self:SetScript("OnEvent", onCoreEvent)
        registerCoreEvents(self)
    else
        onCoreEvent(self, event, ...)
    end
end)
if IsLoggedIn() then
    P8BA6426E.InitDB()
    C_Timer.After(0, function()
        currentSpecID = select(3, P8BA6426E.GetPlayerClassSpec())
        currentHeroSpecID = P8BA6426E.DB.currentHeroSpecID
        loadClassData()
        P8BA6426E.ResetBurstAutoCloseTimer()
        refreshMacroBindings()
        if P8BA6426E.RebuildPixelBars then
            P8BA6426E.RebuildPixelBars()
        end
        if P8BA6426E.RefreshDockButtonColors then
            P8BA6426E.RefreshDockButtonColors()
        end
    end)
    coreEventFrame:SetScript("OnEvent", onCoreEvent)
    registerCoreEvents(coreEventFrame)
else
    P8BA6426E.SafeRegisterEvent(coreEventFrame, "ADDON_LOADED")
    P8BA6426E.SafeRegisterEvent(coreEventFrame, "PLAYER_LOGIN")
end
do
    local cachedActionToKey, cachedActionKeyOrder, cachedGetRaidFocusKeys, cachedRaidFocusEnabled
    local cachedHealingModeKey1, cachedHealingModeKey2
    local keyOwners = {}
    function P8BA6426E.InvalidateControlBindingConflicts()
        cachedActionToKey = nil
    end
    -- 检查某个按键是否已被动作/团队焦点/治疗模式占用（带缓存）
    function P8BA6426E.GetControlBindingConflict(key)
        if not key or key == "" then
            return nil
        end
        local raidFocusEnabled = P8BA6426E.classData and P8BA6426E.classData.raidFocusEnabled == true or false
        local healingModeKey1, healingModeKey2
        if P8BA6426E.GetForeverHealingModeKeys then
            healingModeKey1, healingModeKey2 = P8BA6426E.GetForeverHealingModeKeys()
        end
        if
            cachedActionToKey ~= P8BA6426E.ACTION_TO_KEY
            or cachedActionKeyOrder ~= P8BA6426E.ACTION_KEY_ORDER
            or cachedGetRaidFocusKeys ~= P8BA6426E.GetRaidFocusKeys
            or cachedRaidFocusEnabled ~= raidFocusEnabled
            or cachedHealingModeKey1 ~= healingModeKey1
            or cachedHealingModeKey2 ~= healingModeKey2
        then
            keyOwners = {}
            for key, value in pairs(P8BA6426E.ACTION_TO_KEY or {}) do
                keyOwners[P8BA6426E.NormalizeActionKey(value)] = { "action", key }
            end
            if raidFocusEnabled and P8BA6426E.GetRaidFocusKeys then
                for i, raidFocusKey in ipairs(P8BA6426E.GetRaidFocusKeys()) do
                    local actionKey = P8BA6426E.NormalizeActionKey(raidFocusKey)
                    if not keyOwners[actionKey] then
                        keyOwners[actionKey] = { "raid", i }
                    end
                end
            end
            for _, entry in ipairs({ healingModeKey1, healingModeKey2 }) do
                local actionKey = P8BA6426E.NormalizeActionKey(entry)
                if actionKey and not keyOwners[actionKey] then
                    keyOwners[actionKey] = { "forever_healing_mode", entry }
                end
            end
            cachedActionToKey = P8BA6426E.ACTION_TO_KEY
            cachedActionKeyOrder = P8BA6426E.ACTION_KEY_ORDER
            cachedGetRaidFocusKeys = P8BA6426E.GetRaidFocusKeys
            cachedRaidFocusEnabled = raidFocusEnabled
            cachedHealingModeKey1, cachedHealingModeKey2 = healingModeKey1, healingModeKey2
        end
        local owner = keyOwners[P8BA6426E.NormalizeActionKey(key)]
        if owner then
            return owner[1], owner[2]
        end
    end
end
P8BA6426E.waitingForKey = nil
P8BA6426E.masterKeyPressed = false
P8BA6426E.burstKeyPressed = false
-- 检测总开关/爆发/模式切换快捷键当前是否按下（含修饰键与鼠标按键）
function P8BA6426E.IsBindPressed(bind)
    if not bind or bind == "" then
        return false
    end
    local db = P8BA6426E.DB
    if
        db
        and (
            (bind == db.masterKey or bind == db.burstKey or bind == db.aoeKey)
            and P8BA6426E.GetControlBindingConflict(bind)
        )
    then
        return false
    end
    local baseKey = bind
    local needShift, needCtrl, needAlt = false, false, false
    if baseKey:find("SHIFT%-") then
        needShift = true
        baseKey = baseKey:gsub("SHIFT%-", "")
    end
    if baseKey:find("CTRL%-") then
        needCtrl = true
        baseKey = baseKey:gsub("CTRL%-", "")
    end
    if baseKey:find("ALT%-") then
        needAlt = true
        baseKey = baseKey:gsub("ALT%-", "")
    end
    local isShiftKeyDown = IsShiftKeyDown() and true or false
    local isControlKeyDown = IsControlKeyDown() and true or false
    local isAltKeyDown = IsAltKeyDown() and true or false
    if isShiftKeyDown ~= needShift then
        return false
    end
    if isControlKeyDown ~= needCtrl then
        return false
    end
    if isAltKeyDown ~= needAlt then
        return false
    end
    if baseKey:find("^BUTTON") then
        local buttonIndex = tonumber(baseKey:match("BUTTON(%d+)"))
        if buttonIndex then
            return IsMouseButtonDown(buttonIndex)
        end
        return false
    end
    if IsKeyDown then
        return IsKeyDown(baseKey)
    end
    return false
end
function P8BA6426E.GetKeyDisplayText(key)
    if not key or key == "" then
        return P8BA6426E.L("未设置")
    end
    return key
end
function P8BA6426E.CreateStyledButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 70, height or 22)
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetAlpha(0)
    end
    local highlightTexture = button:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetAlpha(0)
    end
    local pushedTexture = button:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetAlpha(0)
    end
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)
    button.bg = bg
    local border = button:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 0)
    button.border = border
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(P8BA6426E.L(text or ""))
    label:SetTextColor(0.9, 0.75, 0.35, 1)
    button:SetFontString(label)
    button.restoreTextColor = { 0.9, 0.75, 0.35, 1 }
    button:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.6, 0.1, 0.15, 0.9)
        self.border:SetColorTexture(0.8, 0.2, 0.25, 1);
        (self:GetFontString()):SetTextColor(1, 1, 1, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0)
        self.border:SetColorTexture(0, 0, 0, 0)
        local restoreTextColor = self.restoreTextColor
        if restoreTextColor then
            (self:GetFontString()):SetTextColor(
                restoreTextColor[1],
                restoreTextColor[2],
                restoreTextColor[3],
                restoreTextColor[4]
            )
        end
    end)
    return button
end
function P8BA6426E.ToggleDock()
    if not P8BA6426E.mainFrame then
        return
    end
    if P8BA6426E.mainFrame:IsShown() then
        P8BA6426E.mainFrame:Hide()
    else
        P8BA6426E.mainFrame:Show()
        P8BA6426E.SwitchTab(1)
    end
end
-- 斜杠命令：/pms 打开设置；/ON /OFF 总开关；/bfk /bfg 爆发开关；/dan /qun /AUTO /zi 单体/群体/自动；/charu 暂停 0.5 秒（手动插入技能）
SLASH_MAOKELI1 = "/pms"
SlashCmdList.MAOKELI = P8BA6426E.ToggleDock
SLASH_CHARU1 = "/charu"
SlashCmdList.CHARU = function()
    _G.P8BA6426ECharuExpire = GetTime() + 0.5
end
SLASH_MKL_ON1 = "/ON"
SlashCmdList.MKL_ON = function()
    P8BA6426E.DB.masterSwitch = true
    if P8BA6426E.UpdateMasterSwitchUI then
        P8BA6426E.UpdateMasterSwitchUI(true)
    end
end
SLASH_MKL_OFF1 = "/OFF"
SlashCmdList.MKL_OFF = function()
    P8BA6426E.DB.masterSwitch = false
    if P8BA6426E.UpdateMasterSwitchUI then
        P8BA6426E.UpdateMasterSwitchUI(false)
    end
end
SLASH_MKL_BFK1 = "/bfk"
SlashCmdList.MKL_BFK = function()
    P8BA6426E.SetBurstSwitch(true)
end
SLASH_MKL_BFG1 = "/bfg"
SlashCmdList.MKL_BFG = function()
    P8BA6426E.SetBurstSwitch(false)
end
SLASH_MKL_DAN1 = "/dan"
SlashCmdList.MKL_DAN = function()
    P8BA6426E.aoeMode = 1
    if P8BA6426E.UpdateAoeModeUI then
        P8BA6426E.UpdateAoeModeUI(1)
    end
end
SLASH_MKL_QUN1 = "/qun"
SlashCmdList.MKL_QUN = function()
    P8BA6426E.aoeMode = 2
    if P8BA6426E.UpdateAoeModeUI then
        P8BA6426E.UpdateAoeModeUI(2)
    end
end
SLASH_MKL_AUTO1 = "/AUTO"
SlashCmdList.MKL_AUTO = function()
    P8BA6426E.aoeMode = 0
    if P8BA6426E.UpdateAoeModeUI then
        P8BA6426E.UpdateAoeModeUI(0)
    end
end
SLASH_MKL_ZI1 = "/zi"
SlashCmdList.MKL_ZI = SlashCmdList.MKL_AUTO
-- 移动按键方案检测：识别 WSAD/EDSF/RFDG/WSQE 等布局及转向/平移模式，编码后经 isMoving 像素告知外部程序
local MOVEMENT_CODE_BASE = 3527936
local MOVEMENT_CODE_UNKNOWN = 7
local MOVEMENT_CODE_CLASSIC = 10
local MOVEMENT_PROFILES = {
    { name = "WSAD", forward = "W", backward = "S", left = "A", right = "D", turnCode = 1, strafeCode = 2 },
    { name = "EDSF", forward = "E", backward = "D", left = "S", right = "F", turnCode = 3, strafeCode = 4 },
    { name = "RFDG", forward = "R", backward = "F", left = "D", right = "G", turnCode = 5, strafeCode = 6 },
    { name = "WSQE", forward = "W", backward = "S", left = "Q", right = "E", turnCode = 8, strafeCode = 9 },
}
local function encodeMovementCode(code)
    return (MOVEMENT_CODE_BASE + code * 16) + (15 - code)
end
P8BA6426E.isMoving = encodeMovementCode(0)
P8BA6426E.movementBindingProfile = nil
P8BA6426E.movementBindingSideMode = nil
local function getBindingKeys(action)
    if type(GetBindingKey) ~= "function" then
        return nil
    end
    local results = { pcall(GetBindingKey, action) }
    if not results[1] then
        return nil
    end
    local keys = {}
    for i = 2, #results, 1 do
        if type(results[i]) == "string" and results[i] ~= "" then
            keys[#keys + 1] = results[i]
        end
    end
    return keys
end
local function isActionBoundTo(action, key)
    local keys = getBindingKeys(action)
    if not keys then
        return false
    end
    for _, boundKey in ipairs(keys) do
        if boundKey == key then
            return true
        end
    end
    return false
end
local function detectSideMode(profile)
    local isTurn = isActionBoundTo("TURNLEFT", profile.left) and isActionBoundTo("TURNRIGHT", profile.right)
    local isStrafe = isActionBoundTo("STRAFELEFT", profile.left) and isActionBoundTo("STRAFERIGHT", profile.right)
    if isTurn then
        return "turn"
    end
    if isStrafe then
        return "strafe"
    end
    return nil
end
local function isClassicWSADQE()
    return isActionBoundTo("MOVEFORWARD", "W")
        and (
            isActionBoundTo("MOVEBACKWARD", "S")
            and (
                isActionBoundTo("TURNLEFT", "A")
                and (
                    isActionBoundTo("TURNRIGHT", "D")
                    and (isActionBoundTo("STRAFELEFT", "Q") and isActionBoundTo("STRAFERIGHT", "E"))
                )
            )
        )
end
function P8BA6426E.RefreshMovementBindingProfile()
    if isClassicWSADQE() then
        P8BA6426E.isMoving = encodeMovementCode(MOVEMENT_CODE_CLASSIC)
        P8BA6426E.movementBindingProfile = "WSAD+QE"
        P8BA6426E.movementBindingSideMode = "classic"
        return
    end
    for _, profile in ipairs(MOVEMENT_PROFILES) do
        if isActionBoundTo("MOVEFORWARD", profile.forward) and isActionBoundTo("MOVEBACKWARD", profile.backward) then
            local sideMode = detectSideMode(profile)
            if sideMode then
                local code = sideMode == "turn" and profile.turnCode or profile.strafeCode
                P8BA6426E.isMoving = encodeMovementCode(code)
                P8BA6426E.movementBindingProfile = profile.name
                P8BA6426E.movementBindingSideMode = sideMode
                return
            end
        end
    end
    P8BA6426E.isMoving = encodeMovementCode(MOVEMENT_CODE_UNKNOWN)
    P8BA6426E.movementBindingProfile = nil
    P8BA6426E.movementBindingSideMode = nil
end
local movementBindingFrame = CreateFrame("Frame")
P8BA6426E.SafeRegisterEvent(movementBindingFrame, "BINDINGS_LOADED")
P8BA6426E.SafeRegisterEvent(movementBindingFrame, "UPDATE_BINDINGS")
P8BA6426E.SafeRegisterEvent(movementBindingFrame, "NOTIFY_TURN_STRAFE_CHANGE")
P8BA6426E.SafeRegisterEvent(movementBindingFrame, "PLAYER_ENTERING_WORLD")
movementBindingFrame:SetScript("OnEvent", function()
    P8BA6426E.isMoving = encodeMovementCode(0)
    P8BA6426E.movementBindingProfile = nil
    P8BA6426E.movementBindingSideMode = nil
    C_Timer.After(0, P8BA6426E.RefreshMovementBindingProfile)
end)
C_Timer.After(0, P8BA6426E.RefreshMovementBindingProfile)
-- 向诊断模块登记可被计时/采样的函数钩子
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("cast.success", "timed", function()
        return castEventFrame and castEventFrame:GetScript("OnEvent") or nil
    end, function(handler)
        if castEventFrame then
            castEventFrame:SetScript("OnEvent", handler)
        end
    end)
    logicDiagnostics.Declare("module.refresh", "sampled", function()
        return loadClassData
    end, function(fn)
        loadClassData = fn
    end)
    logicDiagnostics.Declare("macros.apply", "sampled", function()
        return refreshMacroBindings
    end, function(refreshMacroBindings2)
        refreshMacroBindings = refreshMacroBindings2
        P8BA6426E.RefreshMacroBindings = refreshMacroBindings2
    end)
end
