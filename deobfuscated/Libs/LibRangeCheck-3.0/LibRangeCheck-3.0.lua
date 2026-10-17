--[[
  第三方开源库 LibRangeCheck-3.0（同样被混淆过，已还原并按上游源码习惯恢复主要命名）（注意：库名被改成 <插件名>-RangeCheck-3.0 以免与其他插件冲突）
  原始文件：Libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local addonName = ...
local MAJOR_VERSION = addonName .. "-RangeCheck-3.0"
local MINOR_VERSION = 34
local lib, oldminor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then
    return
end
local tocVersion = select(4, GetBuildInfo())
local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isMidnight = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and tocVersion >= 120000
local InCombatLockdownRestriction = function(unit)
    return InCombatLockdown() and not UnitCanAttack("player", unit)
end
local _G = _G
local next = next
local _sort = sort
local type = type
local wipe = wipe
local print = print
local pairs = pairs
local ipairs = ipairs
local tinsert = tinsert
local tremove = tremove
local tostring = tostring
local setmetatable = setmetatable
local BOOKTYPE_SPELL = BOOKTYPE_SPELL or Enum.SpellBookSpellBank.Player
local GetSpellBookItemName = GetSpellBookItemName or C_SpellBook.GetSpellBookItemName
local C_Item = C_Item
local UnitCanAttack = UnitCanAttack
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local CheckInteractDistance = CheckInteractDistance
local IsSpellInRange = _G.IsSpellInRange
    or function(spellID, _, unit)
        local inRange = C_Spell.IsSpellInRange(spellID, unit)
        if inRange == true then
            return 1
        elseif inRange == false then
            return 0
        end
        return nil
    end
local SPELLBOOK_ITEM_TYPE_NAMES = { "SPELL", "FUTURESPELL", "PETACTION", "FLYOUT" }
local GetSpellBookItemInfo = _G.GetSpellBookItemInfo
    or function(index, bookType)
        if type(bookType) == "string" then
            bookType = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.Pet
        end
        local info = C_SpellBook.GetSpellBookItemInfo(index, bookType)
        if info and SPELLBOOK_ITEM_TYPE_NAMES[info.itemType or 0] then
            return SPELLBOOK_ITEM_TYPE_NAMES[info.itemType or 0] or "None", info.spellID, info
        end
    end
local UnitClass = UnitClass
local UnitRace = UnitRace
local GetInventoryItemLink = GetInventoryItemLink
local GetTime = GetTime
local HandSlotId = GetInventorySlotInfo("HANDSSLOT")
local math_floor = math.floor
local UnitIsVisible = UnitIsVisible
local GetSpellInfo = GetSpellInfo
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
local GetNumSpellTabs = GetNumSpellTabs or C_SpellBook.GetNumSpellBookSkillLines
local GetSpellTabInfo = GetSpellTabInfo
    or function(index)
        local info = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if info then
            return info.name,
                info.iconID,
                info.itemIndexOffset,
                info.numSpellBookItems,
                info.isGuild,
                info.offSpecID,
                info.shouldHide,
                info.specID
        end
    end
local UpdateDelay = 0.5
local ItemRequestTimeout = 10
local DefaultInteractList = { [3] = 8, [4] = 28 }
local InteractLists = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }
local MeleeRange = 2
local FriendSpells, HarmSpells, ResSpells, PetSpells = {}, {}, {}, {}
for _, class in ipairs({
    "EVOKER",
    "DEATHKNIGHT",
    "DEMONHUNTER",
    "DRUID",
    "HUNTER",
    "SHAMAN",
    "MAGE",
    "PALADIN",
    "PRIEST",
    "WARLOCK",
    "WARRIOR",
    "MONK",
    "ROGUE",
}) do
    FriendSpells[class], HarmSpells[class], ResSpells[class], PetSpells[class] = {}, {}, {}, {}
end
tinsert(HarmSpells.EVOKER, 362969)
tinsert(FriendSpells.EVOKER, 355913)
tinsert(FriendSpells.EVOKER, 361469)
tinsert(FriendSpells.EVOKER, 360823)
tinsert(ResSpells.EVOKER, 361227)
tinsert(HarmSpells.DEATHKNIGHT, 49576)
tinsert(HarmSpells.DEATHKNIGHT, 47541)
tinsert(ResSpells.DEATHKNIGHT, 61999)
tinsert(HarmSpells.DEMONHUNTER, 185123)
tinsert(HarmSpells.DEMONHUNTER, 183752)
tinsert(HarmSpells.DEMONHUNTER, 204021)
tinsert(FriendSpells.DRUID, 8936)
tinsert(FriendSpells.DRUID, 774)
tinsert(FriendSpells.DRUID, 2782)
tinsert(FriendSpells.DRUID, 88423)
if not isRetail then
    tinsert(FriendSpells.DRUID, 5185)
end
tinsert(HarmSpells.DRUID, 5176)
tinsert(HarmSpells.DRUID, 339)
tinsert(HarmSpells.DRUID, 6795)
tinsert(HarmSpells.DRUID, 33786)
tinsert(HarmSpells.DRUID, 22568)
tinsert(HarmSpells.DRUID, 8921)
tinsert(ResSpells.DRUID, 50769)
tinsert(ResSpells.DRUID, 20484)
tinsert(HarmSpells.HUNTER, 466930)
tinsert(HarmSpells.HUNTER, 75)
if not isRetail then
    tinsert(HarmSpells.HUNTER, 2764)
end
tinsert(PetSpells.HUNTER, 136)
tinsert(FriendSpells.MAGE, 1459)
tinsert(FriendSpells.MAGE, 475)
if not isRetail then
    tinsert(FriendSpells.MAGE, 130)
end
tinsert(HarmSpells.MAGE, 44614)
tinsert(HarmSpells.MAGE, 11366)
tinsert(HarmSpells.MAGE, 5019)
tinsert(HarmSpells.MAGE, 118)
tinsert(HarmSpells.MAGE, 116)
tinsert(HarmSpells.MAGE, 133)
tinsert(HarmSpells.MAGE, 44425)
tinsert(FriendSpells.MONK, 115450)
tinsert(FriendSpells.MONK, 115546)
tinsert(FriendSpells.MONK, 116670)
tinsert(HarmSpells.MONK, 115546)
tinsert(HarmSpells.MONK, 115078)
tinsert(HarmSpells.MONK, 100780)
tinsert(HarmSpells.MONK, 117952)
tinsert(ResSpells.MONK, 115178)
tinsert(FriendSpells.PALADIN, 19750)
tinsert(FriendSpells.PALADIN, 85673)
tinsert(FriendSpells.PALADIN, 4987)
tinsert(FriendSpells.PALADIN, 213644)
if not isRetail then
    tinsert(FriendSpells.PALADIN, 635)
end
tinsert(HarmSpells.PALADIN, 853)
tinsert(HarmSpells.PALADIN, 35395)
tinsert(HarmSpells.PALADIN, 62124)
tinsert(HarmSpells.PALADIN, 183218)
tinsert(HarmSpells.PALADIN, 20271)
tinsert(HarmSpells.PALADIN, 20473)
tinsert(ResSpells.PALADIN, 7328)
if isRetail then
    tinsert(FriendSpells.PRIEST, 21562)
    tinsert(FriendSpells.PRIEST, 17)
else
    tinsert(FriendSpells.PRIEST, 2050)
end
tinsert(FriendSpells.PRIEST, 527)
tinsert(FriendSpells.PRIEST, 2061)
tinsert(HarmSpells.PRIEST, 589)
if isEra then
    tinsert(HarmSpells.PRIEST, 18807)
end
tinsert(HarmSpells.PRIEST, 8092)
tinsert(HarmSpells.PRIEST, 585)
tinsert(HarmSpells.PRIEST, 5019)
if not isRetail then
    tinsert(HarmSpells.PRIEST, 8092)
end
tinsert(ResSpells.PRIEST, 2006)
if isRetail then
    tinsert(FriendSpells.ROGUE, 36554)
    tinsert(FriendSpells.ROGUE, 921)
else
    tinsert(HarmSpells.ROGUE, 2764)
end
tinsert(HarmSpells.ROGUE, 185565)
tinsert(HarmSpells.ROGUE, 36554)
tinsert(HarmSpells.ROGUE, 185763)
tinsert(HarmSpells.ROGUE, 2094)
tinsert(HarmSpells.ROGUE, 921)
tinsert(FriendSpells.SHAMAN, 546)
tinsert(FriendSpells.SHAMAN, 8004)
tinsert(FriendSpells.SHAMAN, 188070)
if not isRetail then
    tinsert(FriendSpells.SHAMAN, 331)
    tinsert(FriendSpells.SHAMAN, 526)
    tinsert(FriendSpells.SHAMAN, 2870)
end
tinsert(HarmSpells.SHAMAN, 370)
tinsert(HarmSpells.SHAMAN, 8042)
tinsert(HarmSpells.SHAMAN, 117014)
tinsert(HarmSpells.SHAMAN, 188196)
tinsert(HarmSpells.SHAMAN, 73899)
if not isRetail then
    tinsert(HarmSpells.SHAMAN, 403)
    tinsert(HarmSpells.SHAMAN, 8042)
end
tinsert(ResSpells.SHAMAN, 2008)
tinsert(HarmSpells.WARRIOR, 355)
tinsert(HarmSpells.WARRIOR, 5246)
tinsert(HarmSpells.WARRIOR, 100)
if not isRetail then
    tinsert(HarmSpells.WARRIOR, 2764)
end
if isEra then
    tinsert(FriendSpells.WARLOCK, 132)
else
    tinsert(FriendSpells.WARLOCK, 20707)
end
tinsert(FriendSpells.WARLOCK, 5697)
if isRetail then
    tinsert(HarmSpells.WARLOCK, 234153)
    tinsert(HarmSpells.WARLOCK, 198590)
    tinsert(HarmSpells.WARLOCK, 232670)
else
    tinsert(HarmSpells.WARLOCK, 172)
    tinsert(HarmSpells.WARLOCK, 348)
    tinsert(HarmSpells.WARLOCK, 17877)
    tinsert(HarmSpells.WARLOCK, 18223)
    tinsert(HarmSpells.WARLOCK, 689)
end
if isEra then
    tinsert(HarmSpells.WARLOCK, 403677)
    tinsert(HarmSpells.WARLOCK, 426320)
end
tinsert(HarmSpells.WARLOCK, 5019)
tinsert(HarmSpells.WARLOCK, 686)
tinsert(HarmSpells.WARLOCK, 5782)
if not isEra then
    tinsert(ResSpells.WARLOCK, 20707)
end
tinsert(PetSpells.WARLOCK, 755)
local FriendItems
if isEra then
    FriendItems = {
        [5] = { 1970, 8149, 15826, 16308, 16991, 17117, 20403, 22259, 208855, 209027, 209057, 213036, 221199, 225943 },
        [10] = { 17626, 17689, 21267, 23164, 226207, 226208, 226209, 226210, 226211, 226212, 226213, 226214 },
        [15] = {
            1251,
            2581,
            3530,
            3531,
            6450,
            6451,
            8544,
            8545,
            14529,
            14530,
            19066,
            19067,
            19068,
            19307,
            20065,
            20066,
            20067,
            20232,
            20234,
            20235,
            20237,
            20243,
            20244,
            23684,
            232433,
        },
        [20] = {
            12450,
            12451,
            12455,
            12457,
            12458,
            12460,
            17757,
            21519,
            219963,
            219965,
            219983,
            219984,
            219985,
            219986,
            219987,
            219988,
            219989,
            219990,
            219991,
            219992,
            219993,
            219994,
            219995,
            219996,
            219997,
            219998,
            220053,
            220054,
            220055,
            220056,
            220057,
            220058,
            220059,
            220060,
            220061,
            220062,
            220063,
            220064,
            220065,
            220066,
            220067,
            220068,
            220069,
            220070,
            220071,
            220072,
            220073,
            220074,
            220075,
            220076,
            220077,
            220078,
            220079,
            220080,
            220081,
            220082,
            220083,
            220084,
            220085,
            220086,
            220087,
            220088,
            220089,
            220090,
            220091,
            220092,
            220093,
            220094,
            220095,
            220096,
            220097,
            220098,
            220099,
            220100,
            220101,
            220102,
            220103,
            220104,
            220105,
            220106,
            220792,
            223168,
            223171,
            224806,
            224893,
            231298,
            231836,
            232344,
        },
        [25] = { 13289 },
        [30] = {
            954,
            955,
            1180,
            1181,
            1477,
            1478,
            1711,
            1712,
            1851,
            1912,
            2289,
            2290,
            2948,
            3012,
            3013,
            4381,
            4419,
            4421,
            4422,
            4424,
            4425,
            4426,
            4444,
            5232,
            5613,
            6452,
            6453,
            10305,
            10306,
            10307,
            10308,
            10309,
            10310,
            11563,
            11564,
            11567,
            16892,
            16893,
            16895,
            16896,
            17202,
            17310,
            18637,
            19440,
            20908,
            21038,
            21713,
            22200,
            22206,
            22218,
        },
        [35] = { 18904 },
        [40] = { 1713, 5205, 5323, 8346, 11562, 18640, 18662, 213349, 216500, 216503, 216517, 216607, 230280 },
        [45] = { 221316 },
        [50] = { 221315 },
        [100] = { 5418, 17162, 23715, 23718, 23719, 23721, 23722, 227685 },
    }
elseif isCata then
    FriendItems = {
        [3] = { 42732 },
        [5] = {
            1970,
            8149,
            15826,
            16991,
            17117,
            20403,
            22259,
            23485,
            23659,
            33310,
            33342,
            33563,
            34954,
            34973,
            35116,
            35401,
            35736,
            36771,
            36786,
            36956,
            37187,
            37202,
            37568,
            37576,
            38330,
            38467,
            38627,
            38676,
            38731,
            40587,
            45001,
            45080,
            49743,
            49948,
            50471,
            50742,
            50746,
            52014,
            52271,
            52712,
            53120,
            56837,
            58502,
            58885,
            58955,
            58965,
            61302,
            63150,
            63427,
            65667,
            67232,
            71978,
            72110,
        },
        [7] = { 61323, 62899, 63350 },
        [8] = { 29052, 33278, 34368, 35943, 37932, 56821, 68678 },
        [10] = {
            17626,
            17689,
            21267,
            22896,
            22962,
            23164,
            30656,
            32321,
            33418,
            34083,
            34250,
            35293,
            36859,
            37307,
            38697,
            40551,
            41988,
            42164,
            43059,
            44576,
            47033,
            50131,
            52709,
            52819,
            53009,
            54215,
            54462,
            54463,
            56012,
            56222,
            58167,
            58200,
            58203,
            60382,
            60870,
            62057,
            62326,
            62541,
            64312,
            67249,
            68677,
            68679,
            68682,
            69240,
        },
        [15] = {
            1251,
            2581,
            3530,
            3531,
            6450,
            6451,
            8544,
            8545,
            14529,
            14530,
            19066,
            19067,
            19068,
            19307,
            20065,
            20066,
            20067,
            20232,
            20234,
            20235,
            20237,
            20243,
            20244,
            21990,
            21991,
            30651,
            30652,
            30653,
            30654,
            31129,
            32907,
            33621,
            34721,
            34722,
            36764,
            38573,
            38640,
            38641,
            38643,
            39268,
            44646,
            44959,
            46722,
            52481,
            53049,
            53050,
            53051,
            53101,
            53104,
            53105,
            54851,
            56180,
            56184,
            58169,
            58966,
            58967,
            63391,
            64995,
        },
        [20] = {
            17757,
            21519,
            22473,
            23394,
            23693,
            29817,
            29818,
            30175,
            32424,
            33088,
            34127,
            34257,
            34711,
            34869,
            36796,
            36827,
            36835,
            36847,
            37708,
            39157,
            39206,
            39238,
            39577,
            39651,
            39664,
            40397,
            42624,
            42894,
            43206,
            43315,
            44817,
            44975,
            46363,
            48104,
            49202,
            50053,
            52044,
            52073,
            52484,
            52566,
            53107,
            55141,
            55158,
            55230,
            56798,
            57920,
            58177,
            63079,
            63426,
            67241,
            68606,
            68607,
            71085,
        },
        [25] = { 13289, 31463, 32966, 34979, 46885, 56247 },
        [30] = {
            954,
            955,
            1180,
            1181,
            1477,
            1478,
            1711,
            1712,
            1912,
            2289,
            2290,
            3012,
            3013,
            4381,
            4419,
            4421,
            4422,
            4424,
            4425,
            4426,
            4444,
            5613,
            6452,
            6453,
            10305,
            10306,
            10307,
            10308,
            10309,
            10310,
            11567,
            17202,
            17310,
            18637,
            19440,
            20908,
            21713,
            22200,
            22206,
            22218,
            23337,
            27498,
            27499,
            27500,
            27501,
            27502,
            27503,
            31437,
            31828,
            32680,
            32960,
            33108,
            33457,
            33458,
            33459,
            33460,
            33461,
            33462,
            33865,
            34068,
            34191,
            34598,
            34684,
            35557,
            36732,
            37091,
            37092,
            37093,
            37094,
            37097,
            37098,
            38515,
            40686,
            40917,
            42774,
            43463,
            43464,
            43465,
            43466,
            43467,
            43468,
            44414,
            44653,
            44731,
            44915,
            45073,
            49138,
            49199,
            49219,
            49882,
            50163,
            52710,
            52715,
            56069,
            56227,
            57172,
            58935,
            60861,
            63303,
            63304,
            63305,
            63306,
            63307,
            63308,
            64637,
            69825,
        },
        [35] = { 16103, 18904, 24501, 35121, 41505, 44890, 49028, 56576 },
        [40] = {
            1713,
            5323,
            8346,
            11562,
            18640,
            18662,
            24541,
            31088,
            33081,
            33581,
            34255,
            34471,
            34494,
            37438,
            38266,
            38308,
            38332,
            39305,
            39615,
            40532,
            44114,
            44222,
            44228,
            44804,
            44812,
            44832,
            50354,
            50430,
            50726,
            52490,
            53794,
            55165,
            56136,
            56169,
            56463,
            60490,
            60808,
            65162,
            71627,
        },
        [45] = { 28369, 32698, 34691, 49647, 52059, 52833, 62794 },
        [60] = { 32825, 34111, 34121, 37877, 37887, 50851 },
        [70] = { 41265 },
        [80] = { 28131, 35278, 35506, 42769, 50031, 62775, 63092, 63104, 63393 },
        [100] = {
            17162,
            23715,
            23718,
            23719,
            23721,
            23722,
            28025,
            29877,
            34151,
            34152,
            34153,
            34154,
            34155,
            41058,
            44212,
        },
        [150] = { 46954 },
    }
else
    FriendItems = {
        [2] = { 168948, 194718 },
        [3] = { 42732, 200469 },
        [4] = { 129055 },
        [5] = {
            1970,
            8149,
            15826,
            16991,
            17117,
            20403,
            22259,
            23485,
            23659,
            33310,
            33342,
            33563,
            34954,
            34973,
            35116,
            35401,
            35736,
            36771,
            36786,
            36956,
            37187,
            37202,
            37568,
            37576,
            38330,
            38467,
            38627,
            38676,
            38731,
            40587,
            45001,
            45080,
            49948,
            50471,
            50742,
            50746,
            52014,
            52271,
            52712,
            53120,
            56837,
            58502,
            58885,
            58955,
            58965,
            61302,
            63150,
            63427,
            65667,
            67232,
            71978,
            72110,
            79021,
            79057,
            79102,
            79819,
            79932,
            80302,
            80590,
            80591,
            80592,
            80593,
            80594,
            80595,
            85215,
            85216,
            85217,
            85219,
            85267,
            85268,
            85269,
            89197,
            89202,
            89233,
            89326,
            89328,
            89329,
            89880,
            91806,
            114835,
            120293,
            133065,
            136605,
            137299,
            139463,
            142065,
            142262,
            143597,
            143773,
            150759,
            151563,
            151570,
            151624,
            152472,
            152630,
            152971,
            152995,
            153049,
            153112,
            153496,
            153513,
            156518,
            156532,
            157771,
            158678,
            159470,
            159782,
            160045,
            160429,
            160433,
            160559,
            160561,
            160571,
            160585,
            161247,
            162450,
            162589,
            163607,
            163720,
            163740,
            166972,
            166973,
            167041,
            168410,
            169653,
            172020,
            173013,
            173148,
            174197,
            174326,
            177817,
            180613,
            181364,
            183689,
            183698,
            183797,
            184622,
            186445,
            186448,
            186695,
            187504,
            192467,
            192795,
            194052,
            194434,
            197805,
            202874,
            203731,
            208124,
            208738,
            208985,
            213539,
            215145,
            216687,
            217159,
            219385,
            224799,
        },
        [6] = { 164766, 219525 },
        [7] = { 61323, 62899, 63350, 88589, 153249 },
        [8] = { 33278, 34368, 35943, 37932, 56821, 82311, 82787, 84242, 128776, 152730 },
        [10] = {
            17626,
            17689,
            21267,
            22962,
            30656,
            32321,
            33418,
            34083,
            35293,
            36859,
            37307,
            38697,
            40551,
            41988,
            42164,
            43059,
            44576,
            47033,
            50131,
            52709,
            52819,
            53009,
            54215,
            54462,
            54463,
            56012,
            56222,
            58167,
            58200,
            58203,
            60382,
            60870,
            62057,
            62326,
            62541,
            64312,
            67249,
            68679,
            69240,
            78947,
            79884,
            80220,
            81177,
            82381,
            90067,
            106958,
            106987,
            107656,
            112321,
            118418,
            119440,
            124100,
            129190,
            132877,
            136386,
            140314,
            152278,
            153537,
            153565,
            156549,
            158190,
            158907,
            158908,
            166701,
            166784,
            166785,
            168053,
            168811,
            168891,
            169860,
            169943,
            169944,
            170161,
            172955,
            173870,
            174323,
            175063,
            184292,
            184314,
            187943,
            191375,
            191376,
            191377,
            193917,
            202096,
            202112,
            202271,
            202714,
            205045,
            207632,
            219469,
            223322,
        },
        [12] = { 208068 },
        [15] = {
            1251,
            2581,
            3530,
            3531,
            6450,
            6451,
            8544,
            8545,
            14529,
            14530,
            19066,
            19067,
            19068,
            19307,
            20065,
            20066,
            20067,
            20232,
            20234,
            20235,
            20237,
            20243,
            20244,
            21990,
            21991,
            30651,
            30652,
            30653,
            30654,
            31129,
            32907,
            33621,
            34721,
            34722,
            36764,
            38573,
            39268,
            44646,
            44959,
            46722,
            52481,
            53049,
            53050,
            53051,
            53101,
            53104,
            53105,
            54851,
            56184,
            58169,
            58966,
            58967,
            63391,
            64995,
            72985,
            72986,
            79027,
            82829,
            111603,
            115475,
            115497,
            115533,
            133940,
            133942,
            136653,
            143636,
            144228,
            146971,
            147445,
            152395,
            152613,
            158381,
            158382,
            158935,
            161333,
            165762,
            165815,
            173191,
            173192,
            173691,
            179359,
            179921,
            179978,
            179983,
            186102,
            186569,
            189384,
            193064,
            194048,
            194049,
            194050,
            197928,
            211943,
            215133,
            219322,
            219323,
            219324,
            224194,
            224440,
            224441,
            224442,
        },
        [20] = {
            17757,
            21519,
            22473,
            23394,
            23693,
            29817,
            29818,
            30175,
            33088,
            34127,
            34257,
            34711,
            34869,
            36796,
            36827,
            36835,
            36847,
            37708,
            39157,
            39206,
            39238,
            39577,
            39651,
            39664,
            40397,
            42624,
            42894,
            43206,
            43315,
            44817,
            44975,
            46363,
            48104,
            49202,
            52044,
            52073,
            52484,
            52566,
            53107,
            55141,
            55158,
            55230,
            56798,
            57920,
            58177,
            63079,
            63426,
            67241,
            68606,
            71085,
            77475,
            85884,
            87558,
            87763,
            88487,
            88587,
            91902,
            93180,
            93751,
            103786,
            103789,
            103795,
            103797,
            110508,
            114967,
            116172,
            116810,
            116811,
            116812,
            118414,
            118415,
            118511,
            124506,
            127707,
            128634,
            128650,
            130260,
            134119,
            134824,
            134860,
            142260,
            142494,
            142495,
            142496,
            142497,
            143865,
            147886,
            151135,
            151763,
            151912,
            152590,
            158174,
            162140,
            162631,
            163172,
            163516,
            163517,
            163518,
            163520,
            163521,
            167071,
            167091,
            168122,
            168525,
            173534,
            174749,
            183105,
            184505,
            184506,
            186094,
            187708,
            187816,
            187839,
            188002,
            188697,
            189449,
            189479,
            189561,
            189572,
            189573,
            191408,
            191682,
            191854,
            191865,
            192477,
            192743,
            194447,
            202310,
            202875,
            203706,
            205980,
            208884,
            211535,
            223312,
            223316,
            229413,
        },
        [25] = {
            13289,
            31463,
            34979,
            46885,
            56247,
            74771,
            117013,
            152983,
            153012,
            169308,
            170540,
            185775,
            198088,
            198478,
            204274,
            204808,
            208846,
            209349,
            210010,
            210011,
            210199,
            210881,
            228996,
        },
        [30] = {
            954,
            955,
            1180,
            1181,
            1477,
            1478,
            1711,
            1712,
            2289,
            2290,
            3012,
            3013,
            4381,
            4419,
            4421,
            4422,
            4424,
            4425,
            4426,
            4444,
            5613,
            6452,
            6453,
            10305,
            10306,
            10307,
            10308,
            10309,
            10310,
            11567,
            17202,
            17310,
            18637,
            19440,
            21713,
            22200,
            22218,
            23337,
            27498,
            27499,
            27500,
            27501,
            27502,
            27503,
            31437,
            31828,
            32680,
            32960,
            33108,
            33457,
            33458,
            33459,
            33460,
            33461,
            33462,
            33865,
            34068,
            34191,
            34598,
            34684,
            35557,
            36732,
            37091,
            37092,
            37093,
            37094,
            37097,
            37098,
            38515,
            40686,
            40917,
            42774,
            43463,
            43464,
            43465,
            43466,
            43467,
            43468,
            44653,
            44915,
            45073,
            49138,
            49199,
            49882,
            50163,
            52710,
            52715,
            56069,
            56227,
            57172,
            58935,
            60861,
            63303,
            63304,
            63305,
            63306,
            63307,
            63308,
            64637,
            69825,
            80337,
            85231,
            86589,
            88580,
            92019,
            110490,
            110492,
            116648,
            116651,
            118179,
            118181,
            118182,
            118183,
            118184,
            118185,
            118283,
            118284,
            118285,
            118286,
            118287,
            118288,
            118643,
            119083,
            128632,
            128648,
            136339,
            138026,
            138733,
            139427,
            143863,
            147420,
            153219,
            156665,
            156831,
            158332,
            160307,
            160525,
            166230,
            166797,
            168407,
            168947,
            169209,
            169446,
            169673,
            169674,
            169675,
            173358,
            173693,
            173888,
            178873,
            183944,
            188692,
            188693,
            189454,
            192471,
            193736,
            193757,
            193892,
            194122,
            194712,
            194731,
            194733,
            194734,
            194735,
            194736,
            194738,
            194818,
            200120,
            202270,
            204473,
            205688,
            206160,
            210755,
            210764,
            210766,
            210767,
            212602,
            215142,
            215158,
            218124,
            223220,
            224026,
            225887,
        },
        [35] = { 18904, 24501, 35121, 41505, 44890, 49028, 56576, 151363, 180899, 193212 },
        [38] = { 140786 },
        [40] = {
            1713,
            5232,
            5323,
            8346,
            11562,
            18640,
            18662,
            31088,
            33081,
            33581,
            34255,
            34471,
            34494,
            37438,
            38266,
            38308,
            38332,
            39305,
            39615,
            40532,
            44114,
            44222,
            44228,
            44812,
            50354,
            50430,
            50726,
            52490,
            53794,
            55165,
            56136,
            56169,
            56463,
            60490,
            60808,
            65162,
            71627,
            74612,
            82468,
            90883,
            90888,
            92965,
            92980,
            93668,
            94525,
            95763,
            96135,
            96507,
            96879,
            104323,
            104324,
            110426,
            110506,
            114926,
            116400,
            116759,
            118190,
            118236,
            119159,
            128505,
            128506,
            128772,
            132511,
            133305,
            133462,
            133706,
            133928,
            133998,
            133999,
            136927,
            137462,
            138884,
            139333,
            139882,
            141005,
            141306,
            141411,
            147882,
            147883,
            152574,
            152996,
            153182,
            153483,
            153571,
            153675,
            155567,
            155569,
            156528,
            156649,
            156868,
            158320,
            159882,
            160649,
            163741,
            165702,
            167863,
            167865,
            168012,
            169152,
            169305,
            169311,
            169490,
            173379,
            174007,
            174927,
            175733,
            178495,
            178496,
            178530,
            180953,
            181360,
            182653,
            183599,
            183808,
            184017,
            184313,
            184841,
            185720,
            186421,
            186474,
            188761,
            191044,
            193678,
            193826,
            193856,
            198047,
            198081,
            201815,
            203714,
            204343,
            204388,
            204714,
            207390,
            211000,
            217929,
            219306,
            225656,
        },
        [45] = { 28369, 32698, 34691, 49647, 52059, 52833, 62794, 88377, 207057, 207083 },
        [46] = { 219320 },
        [50] = {
            110009,
            116139,
            147006,
            147007,
            151957,
            151958,
            160443,
            160557,
            161452,
            165578,
            182451,
            184020,
            184029,
            207084,
            212175,
        },
        [55] = { 74637 },
        [60] = { 32825, 34111, 34121, 37877, 37887, 50851, 127030, 153679, 156928, 169279 },
        [70] = { 41265, 202642 },
        [80] = {
            35278,
            35506,
            42769,
            50031,
            62775,
            63092,
            63104,
            63393,
            152572,
            152610,
            159761,
            168253,
            185742,
            194891,
        },
        [90] = { 133925 },
        [100] = { 41058, 44212, 83134, 109082, 160739, 161422, 200549, 202020, 210223, 222976 },
        [120] = { 160988, 168430, 169681, 211963 },
        [150] = { 46954, 153204, 192750 },
        [200] = { 75208, 86546, 89163, 152657 },
    }
end
local HarmItems
if isEra then
    HarmItems = {
        [5] = {
            8149,
            15826,
            16308,
            17117,
            22259,
            22432,
            206466,
            208760,
            208855,
            209027,
            209057,
            213036,
            221199,
            225943,
        },
        [10] = { 9606, 9618, 9619, 9620, 9621, 10699, 17626, 17689, 226472 },
        [15] = { 4559 },
        [20] = { 1191, 2012, 4388, 10645, 13892, 17757, 18209, 22048, 202251, 227936, 232344 },
        [25] = { 13289 },
        [30] = {
            835,
            1404,
            1434,
            1444,
            1472,
            1704,
            1854,
            1914,
            1995,
            2091,
            3434,
            3441,
            4479,
            4480,
            4481,
            4941,
            5079,
            5457,
            6436,
            7344,
            7734,
            9328,
            9394,
            10588,
            10716,
            10720,
            11170,
            11522,
            11565,
            12288,
            12646,
            12647,
            13213,
            13509,
            13514,
            17202,
            17310,
            20084,
            20908,
            21038,
            21713,
            22200,
            22206,
            22218,
            220649,
            228576,
            233226,
        },
        [35] = { 1258, 1399, 1402, 8688, 18904, 220568, 233216 },
        [40] = { 4945, 8348, 191414, 208773, 208843, 209047 },
        [45] = { 221316 },
        [100] = { 5418, 17162, 23715, 23718, 23719, 23721, 23722, 227685 },
    }
elseif isCata then
    HarmItems = {
        [3] = { 42732 },
        [5] = {
            8149,
            15826,
            17117,
            22259,
            22432,
            23485,
            23659,
            33310,
            33342,
            33554,
            33563,
            33806,
            34954,
            34973,
            35116,
            35401,
            35736,
            36771,
            36786,
            36956,
            37045,
            37125,
            37187,
            37202,
            37568,
            37576,
            38330,
            38467,
            38627,
            38676,
            38731,
            40587,
            45001,
            45080,
            49743,
            49948,
            50742,
            50746,
            52014,
            52271,
            52712,
            53120,
            56837,
            58502,
            58885,
            58955,
            58965,
            61302,
            63150,
            63427,
            65667,
            67232,
            71978,
            72110,
        },
        [7] = { 61323, 62899, 63350 },
        [8] = { 29052, 33278, 34368, 35943, 37932, 56821, 68678 },
        [10] = {
            9606,
            9618,
            9619,
            9620,
            9621,
            10699,
            17626,
            17689,
            22896,
            22962,
            28547,
            30656,
            32321,
            33418,
            34083,
            34250,
            35293,
            36859,
            37307,
            38697,
            40551,
            41988,
            42164,
            43059,
            44576,
            47033,
            50131,
            52709,
            52819,
            53009,
            54215,
            54462,
            54463,
            56012,
            56222,
            56794,
            58167,
            58200,
            58203,
            60382,
            60870,
            62057,
            62326,
            62541,
            64312,
            67249,
            68677,
            68679,
            68682,
            69240,
        },
        [15] = {
            30651,
            30652,
            30653,
            30654,
            31129,
            32907,
            33069,
            33621,
            36764,
            38573,
            39268,
            42480,
            44959,
            46722,
            50741,
            52481,
            53101,
            53104,
            53105,
            54455,
            56180,
            56184,
            58169,
            58966,
            58967,
        },
        [20] = {
            1191,
            4388,
            10645,
            13892,
            17757,
            18209,
            22048,
            22473,
            22783,
            22784,
            23394,
            23655,
            23693,
            29513,
            29817,
            29818,
            30175,
            30259,
            31518,
            31678,
            32424,
            33088,
            33796,
            34127,
            34257,
            34711,
            34869,
            36796,
            36827,
            36835,
            36847,
            37708,
            39157,
            39206,
            39238,
            39577,
            39651,
            39664,
            40397,
            42624,
            42894,
            43206,
            43315,
            44889,
            44975,
            46363,
            48104,
            49202,
            50053,
            52044,
            52073,
            52484,
            52566,
            53107,
            55141,
            55158,
            55230,
            56798,
            57920,
            58177,
            63079,
            63426,
            67241,
            68606,
            68607,
            71085,
        },
        [25] = { 13289, 24268, 31463, 32408, 32966, 34979, 46885, 49649, 50307, 55049, 55050 },
        [30] = {
            835,
            1399,
            1404,
            1434,
            1472,
            1704,
            1854,
            1914,
            1995,
            2091,
            3434,
            3441,
            4479,
            4480,
            4481,
            4941,
            5079,
            5457,
            6436,
            7734,
            9328,
            9394,
            10588,
            10716,
            10720,
            11170,
            11522,
            11565,
            12288,
            12646,
            12647,
            13213,
            13509,
            13514,
            17202,
            17310,
            20084,
            20908,
            21038,
            21713,
            22200,
            22206,
            22218,
            23337,
            23417,
            23835,
            23995,
            30811,
            30854,
            31403,
            31809,
            31828,
            32680,
            32960,
            33108,
            33606,
            33607,
            33865,
            34068,
            34191,
            34598,
            34684,
            35557,
            36732,
            38331,
            38515,
            40686,
            40917,
            41121,
            42774,
            43166,
            43663,
            44246,
            44414,
            44653,
            44731,
            44915,
            45073,
            49138,
            49199,
            49219,
            49882,
            50163,
            52710,
            52715,
            56069,
            56227,
            57172,
            58935,
            60861,
            64637,
            69825,
        },
        [35] = { 16103, 18904, 24269, 24501, 35121, 39158, 41505, 41509, 44890, 49028, 54442, 56576 },
        [40] = {
            996,
            1258,
            2012,
            4945,
            8688,
            24420,
            28767,
            33581,
            34255,
            37438,
            38332,
            38380,
            39615,
            44114,
            44222,
            44228,
            44804,
            44812,
            44832,
            50430,
            52490,
            53794,
            55165,
            56169,
            56847,
            60490,
            60808,
            65162,
            65357,
            69826,
            69832,
            206272,
        },
        [45] = { 23836, 28369, 32698, 34691, 34812, 35352, 35485, 35499, 49647, 52059, 52833, 62794, 64445 },
        [60] = { 32825, 34111, 34121, 37877, 37887, 49700, 50851, 52043 },
        [70] = { 41265 },
        [80] = { 28131, 35278, 35506, 42769, 49596, 50031, 62775, 63092, 63104, 63393 },
        [100] = {
            17162,
            23715,
            23718,
            23719,
            23721,
            23722,
            28025,
            29877,
            30292,
            33119,
            34151,
            34152,
            34153,
            34154,
            34155,
            41058,
            44212,
        },
        [150] = { 46954 },
    }
else
    HarmItems = {
        [2] = { 168948, 194718 },
        [3] = { 42732, 200469 },
        [4] = { 129055 },
        [5] = {
            8149,
            15826,
            17117,
            22259,
            22432,
            23485,
            23659,
            33310,
            33342,
            33554,
            33563,
            33806,
            34954,
            34973,
            35116,
            35401,
            35736,
            36771,
            36786,
            36956,
            37045,
            37125,
            37187,
            37202,
            37568,
            37576,
            38330,
            38467,
            38627,
            38676,
            38731,
            40587,
            45001,
            45080,
            49948,
            50742,
            50746,
            52014,
            52271,
            52712,
            53120,
            56837,
            58502,
            58885,
            58955,
            58965,
            61302,
            63150,
            63427,
            65667,
            67232,
            71978,
            72110,
            79021,
            79057,
            79102,
            79819,
            79932,
            80302,
            80590,
            80591,
            80592,
            80593,
            80594,
            80595,
            85215,
            85216,
            85217,
            85219,
            85267,
            85268,
            85269,
            89197,
            89202,
            89233,
            89326,
            89328,
            89329,
            89880,
            91806,
            114835,
            133065,
            136605,
            137299,
            139463,
            142065,
            142262,
            143597,
            143773,
            150759,
            151563,
            151570,
            151624,
            152472,
            152630,
            152971,
            152995,
            153049,
            153112,
            153496,
            153513,
            156518,
            156532,
            157771,
            158678,
            159470,
            159782,
            160045,
            160429,
            160433,
            160559,
            160561,
            160571,
            160585,
            161247,
            162450,
            162589,
            163607,
            163720,
            163740,
            166972,
            166973,
            167041,
            168410,
            169653,
            172020,
            173013,
            173148,
            174197,
            174326,
            177817,
            180613,
            181364,
            183689,
            183698,
            183797,
            184622,
            186445,
            186448,
            186695,
            187504,
            192467,
            192795,
            194052,
            194434,
            197805,
            202874,
            208124,
            208738,
            208985,
            213539,
            215145,
            216687,
            217159,
            219385,
            224799,
        },
        [6] = { 200868, 206964, 207024, 207165, 207783, 212449, 219915 },
        [6] = { 164766, 219525 },
        [7] = { 61323, 62899, 63350, 153249 },
        [8] = { 33278, 34368, 35943, 37932, 56821, 82311, 128776, 152730, 178751, 178901 },
        [9] = { 212453 },
        [10] = {
            9606,
            9618,
            9619,
            9620,
            9621,
            10699,
            17626,
            17689,
            22962,
            28547,
            30656,
            32321,
            33418,
            34083,
            35293,
            36859,
            37307,
            38697,
            40551,
            41988,
            42164,
            43059,
            44576,
            47033,
            50131,
            52709,
            52819,
            53009,
            54215,
            54462,
            54463,
            56012,
            56222,
            56794,
            58167,
            58200,
            58203,
            60382,
            60870,
            62057,
            62326,
            62541,
            64312,
            67249,
            68679,
            69240,
            78947,
            79884,
            80220,
            81177,
            82381,
            86536,
            90067,
            106958,
            106987,
            107656,
            112321,
            118418,
            119440,
            124100,
            129190,
            132877,
            136386,
            139584,
            152278,
            153537,
            153565,
            156549,
            158190,
            158907,
            158908,
            166784,
            166785,
            168053,
            168811,
            169860,
            169943,
            169944,
            170161,
            172955,
            173870,
            174040,
            174323,
            175063,
            184292,
            184314,
            187943,
            193917,
            202096,
            202112,
            202271,
            202714,
            205045,
            205276,
            207632,
            219469,
            223322,
        },
        [12] = { 208068 },
        [15] = {
            30651,
            30652,
            30653,
            30654,
            31129,
            32907,
            33069,
            33621,
            36764,
            38573,
            39268,
            42480,
            44959,
            46722,
            50741,
            52481,
            53101,
            53104,
            53105,
            54455,
            56184,
            58169,
            58966,
            58967,
            79027,
            115475,
            115533,
            152395,
            152613,
            153024,
            158935,
            161333,
            165723,
            165762,
            165815,
            170557,
            173691,
            178051,
            179359,
            179921,
            179978,
            179983,
            186089,
            186102,
            186199,
            186569,
            188252,
            189384,
            193064,
            197928,
            219322,
            219323,
            219324,
            224194,
        },
        [20] = {
            1191,
            4388,
            10645,
            13892,
            17757,
            22048,
            22473,
            22783,
            22784,
            23394,
            23693,
            29513,
            29817,
            29818,
            30175,
            30259,
            31518,
            31678,
            33088,
            33796,
            34127,
            34257,
            34711,
            34869,
            36796,
            36827,
            36835,
            36847,
            37708,
            39157,
            39206,
            39238,
            39577,
            39651,
            39664,
            40397,
            42624,
            42894,
            43206,
            43315,
            44889,
            44975,
            46363,
            48104,
            49202,
            52044,
            52073,
            52484,
            52566,
            53107,
            55141,
            55158,
            55230,
            56798,
            57920,
            58177,
            63079,
            63426,
            67241,
            68606,
            71085,
            77475,
            80074,
            85884,
            87558,
            87763,
            91902,
            93180,
            93751,
            93806,
            94123,
            102464,
            103786,
            103789,
            103795,
            103797,
            114967,
            116172,
            116810,
            116811,
            116812,
            118414,
            118415,
            118511,
            118905,
            124506,
            127707,
            128634,
            128650,
            130260,
            131760,
            133647,
            134119,
            134824,
            134860,
            137538,
            142260,
            142494,
            142495,
            142496,
            142497,
            151135,
            151763,
            152590,
            153350,
            162631,
            166230,
            167071,
            167091,
            168122,
            168525,
            169069,
            173534,
            174749,
            178940,
            183105,
            184505,
            184506,
            186094,
            187708,
            187816,
            187839,
            188002,
            188697,
            189449,
            189479,
            189561,
            189572,
            189573,
            191408,
            191682,
            191854,
            191865,
            192477,
            192743,
            194447,
            198355,
            202613,
            202875,
            203383,
            203390,
            203706,
            205980,
            208884,
            211535,
            229413,
        },
        [25] = {
            13289,
            24268,
            31463,
            32408,
            34979,
            46885,
            49649,
            50307,
            55049,
            55050,
            74771,
            86567,
            104298,
            117013,
            117015,
            153012,
            170540,
            195519,
            198088,
            198478,
            202855,
            204274,
            204808,
            206448,
            208846,
            209349,
            210010,
            210011,
            210199,
            210881,
            228996,
        },
        [30] = {
            835,
            1399,
            1434,
            4479,
            4480,
            4481,
            4941,
            5079,
            5457,
            6436,
            7734,
            9328,
            10716,
            10720,
            11522,
            11565,
            12288,
            12646,
            12647,
            13213,
            13514,
            17202,
            17310,
            21038,
            21713,
            22200,
            22218,
            23337,
            23417,
            23835,
            23995,
            30811,
            30854,
            31403,
            31809,
            31828,
            32680,
            32960,
            33108,
            33606,
            33607,
            33865,
            34068,
            34191,
            34598,
            34684,
            35557,
            36732,
            38515,
            40354,
            40686,
            40917,
            41121,
            42774,
            43166,
            43663,
            44246,
            44653,
            44915,
            45073,
            49138,
            49199,
            49882,
            50163,
            52710,
            52715,
            56069,
            56227,
            57172,
            58935,
            60861,
            64637,
            69825,
            80337,
            85231,
            86589,
            92019,
            93159,
            101677,
            110490,
            110492,
            114983,
            116119,
            116648,
            116651,
            117438,
            118179,
            118181,
            118182,
            118183,
            118184,
            118185,
            118283,
            118284,
            118285,
            118286,
            118287,
            118288,
            118643,
            119083,
            122120,
            128632,
            128648,
            130233,
            133580,
            133585,
            136339,
            138026,
            138733,
            139427,
            143863,
            147023,
            147420,
            153219,
            155823,
            156665,
            156831,
            156868,
            158332,
            160307,
            160525,
            168407,
            168947,
            169209,
            169446,
            169673,
            169674,
            169675,
            173157,
            173358,
            173693,
            177839,
            178873,
            180446,
            180661,
            180678,
            180688,
            180689,
            180874,
            183602,
            183944,
            185946,
            186431,
            186679,
            187186,
            188261,
            188268,
            188692,
            188693,
            189454,
            189862,
            192471,
            193757,
            193892,
            194122,
            194712,
            194731,
            194733,
            194734,
            194735,
            194736,
            194738,
            194818,
            198087,
            198477,
            200120,
            202270,
            204473,
            206160,
            209996,
            210755,
            210764,
            210766,
            210767,
            211302,
            212602,
            215142,
            215158,
            218124,
            223220,
            224026,
            225200,
            225887,
        },
        [35] = {
            18904,
            24269,
            24501,
            35121,
            39158,
            41505,
            41509,
            44890,
            49028,
            54442,
            56576,
            88378,
            119216,
            151363,
            180899,
            193212,
        },
        [38] = { 140786 },
        [40] = {
            4945,
            28767,
            33581,
            34255,
            37438,
            38332,
            38380,
            39615,
            44114,
            44222,
            44228,
            44812,
            50430,
            52490,
            53794,
            55165,
            56169,
            56847,
            60490,
            60808,
            65162,
            69832,
            74612,
            82468,
            88577,
            88590,
            93668,
            108903,
            114125,
            114926,
            116400,
            116759,
            118007,
            118190,
            118199,
            118616,
            124224,
            128505,
            128506,
            128772,
            132500,
            132501,
            132502,
            132503,
            132504,
            132505,
            132506,
            132507,
            132510,
            133706,
            133761,
            133775,
            133928,
            133998,
            133999,
            137329,
            138116,
            139589,
            139882,
            141005,
            141306,
            141411,
            142173,
            144331,
            144332,
            144333,
            144334,
            147882,
            147883,
            151368,
            151369,
            151370,
            152574,
            153483,
            153571,
            153675,
            156528,
            156649,
            159796,
            159882,
            160052,
            160659,
            160753,
            160833,
            165702,
            165806,
            167013,
            167018,
            167019,
            167383,
            168012,
            168271,
            169305,
            169307,
            169311,
            169490,
            169769,
            169816,
            169858,
            170252,
            171373,
            172672,
            173069,
            173087,
            174927,
            175732,
            175733,
            177836,
            178495,
            178496,
            178567,
            178809,
            178810,
            178826,
            179535,
            179613,
            179938,
            179939,
            180117,
            180708,
            181357,
            181360,
            182653,
            184313,
            185720,
            186421,
            186474,
            188254,
            188265,
            191044,
            191372,
            191373,
            191374,
            193826,
            193856,
            194308,
            194872,
            198047,
            198086,
            201815,
            204343,
            205224,
            208321,
            211000,
            212257,
            212258,
            212259,
            212325,
            212450,
            212963,
            212964,
            212965,
            213629,
            224047,
            225651,
        },
        [45] = {
            23836,
            28369,
            32698,
            34691,
            34812,
            35352,
            49647,
            52059,
            52833,
            62794,
            64445,
            167870,
            179719,
            194304,
            194310,
            203963,
            207057,
            207083,
            208615,
            208616,
        },
        [46] = { 202610 },
        [50] = {
            116139,
            129372,
            134836,
            147017,
            147019,
            151960,
            151970,
            155565,
            158216,
            159624,
            160443,
            160557,
            161452,
            165576,
            168905,
            173944,
            184021,
            184030,
            186422,
            186437,
            207084,
            208389,
            211344,
            212454,
            219313,
        },
        [55] = { 74637 },
        [60] = {
            32825,
            34111,
            34121,
            37877,
            37887,
            49700,
            50851,
            52043,
            127030,
            153679,
            155822,
            156516,
            156928,
            169279,
            183165,
            192436,
            209999,
        },
        [70] = { 41265, 202642 },
        [75] = { 185949 },
        [80] = {
            35278,
            35506,
            42769,
            49596,
            50031,
            62775,
            63092,
            63104,
            63393,
            152572,
            152610,
            159761,
            168253,
            185742,
            185829,
            194891,
        },
        [90] = { 133925 },
        [100] = { 33119, 41058, 44212, 83134, 109082, 144227, 151307, 160739, 161422, 163604, 222976 },
        [120] = { 160988, 168430, 169681, 211963 },
        [150] = { 42986, 46954, 153204, 154893, 192750 },
        [200] = { 75208, 86546, 89163, 152657 },
        [300] = { 201414 },
    }
end
for _, list in pairs(FriendSpells) do
    tinsert(list, 28880)
end
local pendingItemRequest = {}
local itemRequestTimeoutAt = {}
local foundNewItems
local cacheAllItems
local friendItemRequests
local harmItemRequests
local lastUpdate = 0
local checkers_Spell = setmetatable({}, {
    __index = function(t, spellIdx)
        local func = function(unit)
            if IsSpellInRange(spellIdx, BOOKTYPE_SPELL, unit) == 1 then
                return true
            end
        end
        t[spellIdx] = func
        return func
    end,
})
local checkers_SpellWithMin = {}
local checkers_Item = setmetatable({}, {
    __index = function(t, item)
        local func = function(unit, skipInCombatCheck)
            if not skipInCombatCheck and InCombatLockdownRestriction(unit) then
                return nil
            else
                return C_Item.IsItemInRange(item, unit) or nil
            end
        end
        t[item] = func
        return func
    end,
})
local checkers_Interact = setmetatable({}, {
    __index = function(t, index)
        local func = function(unit, skipInCombatCheck)
            if not skipInCombatCheck and InCombatLockdownRestriction(unit) then
                return nil
            else
                return CheckInteractDistance(unit, index) and true or false
            end
        end
        t[index] = func
        return func
    end,
})
local function copyTable(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end
    if type(src) == "table" then
        for k, v in pairs(src) do
            if type(v) == "table" then
                v = copyTable(v, dst[k])
            end
            dst[k] = v
        end
    end
    return dst
end
local function initItemRequests(cacheAll)
    friendItemRequests = copyTable(FriendItems)
    harmItemRequests = copyTable(HarmItems)
    cacheAllItems = cacheAll
    foundNewItems = nil
end
local function getNumSpells()
    local _name, _texture, offset, numSpells = GetSpellTabInfo(GetNumSpellTabs())
    if not offset or not numSpells then
        return 0
    end
    return offset + numSpells
end
local function findSpellIdx(spellName)
    if not spellName or spellName == "" then
        return nil
    end
    for i = 1, getNumSpells(), 1 do
        local spell = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if spell == spellName then
            local itemType, actionId, info = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
            if info then
                if
                    Enum.SpellBookItemType
                    and (info.itemType == Enum.SpellBookItemType.Spell and not info.isOffSpec)
                then
                    return actionId
                end
            elseif itemType == "SPELL" then
                return i
            end
        end
    end
    return nil
end
local function fixRange(range)
    if range then
        return math_floor(range + 0.5)
    end
end
local function getSpellData(sid)
    local name, _rank, _icon, _castTime, minRange, range = GetSpellInfo(sid)
    return name, fixRange(minRange), fixRange(range), findSpellIdx(name)
end
local function findMinRangeChecker(origMinRange, origRange, spellList, interactList)
    for i = 1, #spellList, 1 do
        local sid = spellList[i]
        local _name, minRange, range, spellIdx = getSpellData(sid)
        if range and (spellIdx and (origMinRange <= range and (range <= origRange and minRange == 0))) then
            return checkers_Spell[spellIdx]
        end
    end
    for k, v in pairs(interactList) do
        if origMinRange <= v and v <= origRange then
            return checkers_Interact[k]
        end
    end
end
local function getCheckerForSpellWithMinRange(spellIdx, minRange, range, spellList, interactList)
    local checker = checkers_SpellWithMin[spellIdx]
    if checker then
        return checker
    end
    local minRangeChecker = findMinRangeChecker(minRange, range, spellList, interactList)
    if minRangeChecker then
        checker = function(unit)
            if IsSpellInRange(spellIdx, BOOKTYPE_SPELL, unit) == 1 then
                return true
            elseif minRangeChecker(unit) then
                return true, true
            end
        end
        checkers_SpellWithMin[spellIdx] = checker
        return checker
    end
end
local function addChecker(t, range, minRange, checker, info)
    local tbl = { range = range, minRange = minRange, checker = checker, info = info }
    for i = 1, #t, 1 do
        local rc = t[i]
        if tbl.range == rc.range then
            return
        end
        if tbl.range > rc.range then
            tinsert(t, i, tbl)
            return
        end
    end
    tinsert(t, tbl)
end
local function createCheckerList(spellList, itemList, interactList)
    local res, resInCombat = {}, {}
    if itemList then
        for range, items in pairs(itemList) do
            for i = 1, #items, 1 do
                local item = items[i]
                if (Item:CreateFromItemID(item)):IsItemDataCached() and C_Item.GetItemInfo(item) then
                    addChecker(res, range, nil, checkers_Item[item], "item:" .. item)
                    break
                end
            end
        end
    end
    if interactList and not next(res) then
        for index, range in pairs(interactList) do
            addChecker(res, range, nil, checkers_Interact[index], "interact:" .. index)
        end
    end
    if spellList then
        for i = 1, #spellList, 1 do
            local sid = spellList[i]
            local name, minRange, range, spellIdx = getSpellData(sid)
            if spellIdx and range then
                if minRange == 0 then
                    minRange = nil
                end
                if range == 0 then
                    range = MeleeRange
                end
                if minRange then
                    local checker = getCheckerForSpellWithMinRange(spellIdx, minRange, range, spellList, interactList)
                    if checker then
                        addChecker(res, range, minRange, checker, "spell:" .. (sid .. (":" .. tostring(name))))
                        addChecker(resInCombat, range, minRange, checker, "spell:" .. (sid .. (":" .. tostring(name))))
                    end
                else
                    addChecker(
                        res,
                        range,
                        minRange,
                        checkers_Spell[spellIdx],
                        "spell:" .. (sid .. (":" .. tostring(name)))
                    )
                    addChecker(
                        resInCombat,
                        range,
                        minRange,
                        checkers_Spell[spellIdx],
                        "spell:" .. (sid .. (":" .. tostring(name)))
                    )
                end
            end
        end
    end
    return res, resInCombat
end
local rangeCache = {}
local function resetRangeCache()
    wipe(rangeCache)
end
local function invalidateRangeCache(maxAge)
    local currentTime = GetTime()
    for guid, cache in pairs(rangeCache) do
        if cache.updateTime + maxAge < currentTime then
            rangeCache[guid] = nil
        end
    end
end
local function getRangeWithCheckerList(unit, checkerList)
    local lo, hi = 1, #checkerList
    while lo <= hi do
        local mid = math_floor((lo + hi) / 2)
        local rc = checkerList[mid]
        if rc.checker(unit, true) then
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    if #checkerList == 0 then
        return nil, nil
    elseif lo > #checkerList then
        return 0, checkerList[#checkerList].range
    elseif lo <= 1 then
        return checkerList[1].range, nil
    else
        return checkerList[lo].range, checkerList[lo - 1].range
    end
end
local function getRange(unit, noItems)
    local canAssist = UnitCanAssist("player", unit)
    if UnitIsDeadOrGhost(unit) then
        if canAssist then
            return getRangeWithCheckerList(unit, InCombatLockdownRestriction(unit) and lib.resRCInCombat or lib.resRC)
        else
            return getRangeWithCheckerList(unit, InCombatLockdownRestriction(unit) and lib.miscRCInCombat or lib.miscRC)
        end
    end
    if UnitCanAttack("player", unit) then
        return getRangeWithCheckerList(unit, noItems and lib.harmNoItemsRC or lib.harmRC)
    elseif UnitIsUnit("pet", unit) then
        if InCombatLockdownRestriction(unit) then
            local minRange, maxRange =
                getRangeWithCheckerList(unit, noItems and lib.friendNoItemsRCInCombat or lib.friendRCInCombat)
            if minRange or maxRange then
                return minRange, maxRange
            else
                return getRangeWithCheckerList(unit, lib.petRCInCombat)
            end
        else
            local minRange, maxRange = getRangeWithCheckerList(unit, noItems and lib.friendNoItemsRC or lib.friendRC)
            if minRange or maxRange then
                return minRange, maxRange
            else
                return getRangeWithCheckerList(unit, lib.petRC)
            end
        end
    elseif canAssist then
        if InCombatLockdownRestriction(unit) then
            return getRangeWithCheckerList(unit, noItems and lib.friendNoItemsRCInCombat or lib.friendRCInCombat)
        else
            return getRangeWithCheckerList(unit, noItems and lib.friendNoItemsRC or lib.friendRC)
        end
    else
        return getRangeWithCheckerList(unit, InCombatLockdownRestriction(unit) and lib.miscRCInCombat or lib.miscRC)
    end
end
local function getCachedRange(unit, noItems, maxCacheAge)
    maxCacheAge = maxCacheAge or 0.1
    maxCacheAge = maxCacheAge > 1 and 1 or maxCacheAge
    local guid
    if WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
        local ok, unitGUID = pcall(UnitGUID, unit)
        if
            not ok
            or type(issecretvalue) ~= "function"
            or type(canaccessvalue) ~= "function"
            or issecretvalue(unitGUID)
            or not canaccessvalue(unitGUID)
            or type(unitGUID) ~= "string"
            or unitGUID == ""
        then
            return getRange(unit, noItems)
        end
        guid = unitGUID
    else
        guid = UnitGUID(unit)
    end
    local cacheKey = (isMidnight and (issecretvalue(guid) and unit) or guid) .. (noItems and "-1" or "-0")
    local cacheItem = rangeCache[cacheKey] or nil
    local currentTime = GetTime()
    if cacheItem and cacheItem.updateTime + maxCacheAge > currentTime then
        return cacheItem.minRange, cacheItem.maxRange
    end
    local result = cacheItem or {}
    result.minRange, result.maxRange = getRange(unit, noItems)
    result.updateTime = currentTime
    rangeCache[cacheKey] = result
    return result.minRange, result.maxRange
end
local function updateCheckers(origList, newList)
    if #origList ~= #newList then
        wipe(origList)
        copyTable(newList, origList)
        return true
    end
    for i = 1, #origList, 1 do
        if origList[i].range ~= newList[i].range or origList[i].checker ~= newList[i].checker then
            wipe(origList)
            copyTable(newList, origList)
            return true
        end
    end
end
local function updateCheckerLists(origList, origListInCombat, newList, newListInCombat)
    local changed = updateCheckers(origList, newList)
    changed = updateCheckers(origListInCombat, newListInCombat) or changed
    return changed
end
local function rcIterator(checkerList)
    local curr = #checkerList
    return function()
        local rc = checkerList[curr]
        if not rc then
            return nil
        end
        curr = curr - 1
        return rc.range, rc.checker
    end
end
local function getMinChecker(checkerList, targetRange)
    local checker, range
    for i = 1, #checkerList, 1 do
        local rc = checkerList[i]
        if rc.range < targetRange then
            return checker, range
        end
        checker, range = rc.checker, rc.range
    end
    return checker, range
end
local function getMaxChecker(checkerList, targetRange)
    for i = 1, #checkerList, 1 do
        local rc = checkerList[i]
        if rc.range <= targetRange then
            return rc.checker, rc.range
        end
    end
end
local function getChecker(checkerList, targetRange)
    for i = 1, #checkerList, 1 do
        local rc = checkerList[i]
        if rc.range == targetRange then
            return rc.checker
        end
    end
end
local function nullChecker() end
local function createSmartChecker(friendChecker, harmChecker, miscChecker)
    miscChecker = miscChecker or nullChecker
    friendChecker = friendChecker or miscChecker
    harmChecker = harmChecker or miscChecker
    return function(unit)
        if not UnitExists(unit) then
            return nil
        end
        if UnitIsDeadOrGhost(unit) then
            return miscChecker(unit)
        end
        if UnitCanAttack("player", unit) then
            return harmChecker(unit)
        elseif UnitCanAssist("player", unit) then
            return friendChecker(unit)
        else
            return miscChecker(unit)
        end
    end
end
local createItemCheckerFunc = function(item)
    if C_Item.GetItemInfo(item) then
        return function(unit)
            return C_Item.IsItemInRange(item, unit)
        end
    end
end
lib.checkerCache_Spell = lib.checkerCache_Spell or {}
lib.checkerCache_Item = lib.checkerCache_Item or {}
lib.miscRC = createCheckerList(nil, nil, DefaultInteractList)
lib.miscRCInCombat = {}
lib.friendRC = createCheckerList(nil, nil, DefaultInteractList)
lib.friendRCInCombat = {}
lib.harmRC = createCheckerList(nil, nil, DefaultInteractList)
lib.harmRCInCombat = {}
lib.resRC = createCheckerList(nil, nil, DefaultInteractList)
lib.resRCInCombat = {}
lib.petRC = createCheckerList(nil, nil, DefaultInteractList)
lib.petRCInCombat = {}
lib.friendNoItemsRC = createCheckerList(nil, nil, DefaultInteractList)
lib.friendNoItemsRCInCombat = {}
lib.harmNoItemsRC = createCheckerList(nil, nil, DefaultInteractList)
lib.harmNoItemsRCInCombat = {}
lib.failedItemRequests = {}
lib.CHECKERS_CHANGED = "CHECKERS_CHANGED"
lib.MeleeRange = MeleeRange
function lib.findSpellIndex(_, spell)
    if type(spell) == "number" then
        spell = GetSpellInfo(spell)
    end
    return findSpellIdx(spell)
end
function lib.getRangeAsString(self, unit, checkVisible, showOutOfRange)
    local minRange, maxRange = self:getRange(unit, checkVisible)
    if not minRange then
        return nil
    end
    if not maxRange then
        return showOutOfRange and minRange .. " +" or nil
    end
    return minRange .. (" - " .. maxRange)
end
function lib.init(self, forced)
    if self.initialized and not forced then
        return
    end
    self.initialized = true
    local _, playerClass = UnitClass("player")
    local _, playerRace = UnitRace("player")
    local interactList = InteractLists[playerRace] or DefaultInteractList
    self.handSlotItem = GetInventoryItemLink("player", HandSlotId)
    local changed = false
    if
        updateCheckerLists(
            self.friendRC,
            self.friendRCInCombat,
            createCheckerList(FriendSpells[playerClass], FriendItems, interactList)
        )
    then
        changed = true
    end
    if
        updateCheckerLists(
            self.harmRC,
            self.harmRCInCombat,
            createCheckerList(HarmSpells[playerClass], HarmItems, interactList)
        )
    then
        changed = true
    end
    if
        updateCheckerLists(
            self.friendNoItemsRC,
            self.friendNoItemsRCInCombat,
            createCheckerList(FriendSpells[playerClass], nil, interactList)
        )
    then
        changed = true
    end
    if
        updateCheckerLists(
            self.harmNoItemsRC,
            self.harmNoItemsRCInCombat,
            createCheckerList(HarmSpells[playerClass], nil, interactList)
        )
    then
        changed = true
    end
    if updateCheckerLists(self.miscRC, self.miscRCInCombat, createCheckerList(nil, nil, interactList)) then
        changed = true
    end
    if
        updateCheckerLists(self.resRC, self.resRCInCombat, createCheckerList(ResSpells[playerClass], nil, interactList))
    then
        changed = true
    end
    if
        updateCheckerLists(self.petRC, self.petRCInCombat, createCheckerList(PetSpells[playerClass], nil, interactList))
    then
        changed = true
    end
    if changed and self.callbacks then
        self.callbacks:Fire(self.CHECKERS_CHANGED)
    end
end
function lib.GetFriendCheckers(self, inCombat)
    return rcIterator(inCombat and self.friendRCInCombat or self.friendRC)
end
function lib.GetFriendCheckersNoItems(self, inCombat)
    return rcIterator(inCombat and self.friendNoItemsRCInCombat or self.friendNoItemsRC)
end
function lib.GetHarmCheckers(self, inCombat)
    return rcIterator(inCombat and self.harmRCInCombat or self.harmRC)
end
function lib.GetHarmCheckersNoItems(self, inCombat)
    return rcIterator(inCombat and self.harmNoItemsRCInCombat or self.harmNoItemsRC)
end
function lib.GetMiscCheckers(self, inCombat)
    return rcIterator(inCombat and self.miscRCInCombat or self.miscRC)
end
function lib.GetFriendMinChecker(self, range, inCombat)
    return getMinChecker(inCombat and self.friendRCInCombat or self.friendRC, range)
end
function lib.GetHarmMinChecker(self, range, inCombat)
    return getMinChecker(inCombat and self.harmRCInCombat or self.harmRC, range)
end
function lib.GetMiscMinChecker(self, range, inCombat)
    return getMinChecker(inCombat and self.miscRCInCombat or self.miscRC, range)
end
function lib.GetFriendMaxChecker(self, range, inCombat)
    return getMaxChecker(inCombat and self.friendRCInCombat or self.friendRC, range)
end
function lib.GetHarmMaxChecker(self, range, inCombat)
    return getMaxChecker(inCombat and self.harmRCInCombat or self.harmRC, range)
end
function lib.GetMiscMaxChecker(self, range, inCombat)
    return getMaxChecker(inCombat and (self.miscRCInCombat and self.miscRC), range)
end
function lib.GetFriendChecker(self, range, inCombat)
    return getChecker(inCombat and self.friendRCInCombat or self.friendRC, range)
end
function lib.GetHarmChecker(self, range, inCombat)
    return getChecker(inCombat and self.harmRCInCombat or self.harmRC, range)
end
function lib.GetMiscChecker(self, range, inCombat)
    return getChecker(inCombat and self.miscRCInCombat or self.miscRC, range)
end
function lib.GetSmartMinChecker(self, range, inCombat)
    if inCombat then
        return createSmartChecker(
            getMinChecker(self.friendRCInCombat, range),
            getMinChecker(self.harmRCInCombat, range),
            getMinChecker(self.miscRCInCombat, range)
        )
    else
        return createSmartChecker(
            getMinChecker(self.friendRC, range),
            getMinChecker(self.harmRC, range),
            getMinChecker(self.miscRC, range)
        )
    end
end
function lib.GetSmartMaxChecker(self, range, inCombat)
    if inCombat then
        return createSmartChecker(
            getMaxChecker(self.friendRCInCombat, range),
            getMaxChecker(self.harmRCInCombat, range),
            getMaxChecker(self.miscRCInCombat, range)
        )
    else
        return createSmartChecker(
            getMaxChecker(self.friendRC, range),
            getMaxChecker(self.harmRC, range),
            getMaxChecker(self.miscRC, range)
        )
    end
end
function lib.GetSmartChecker(self, range, fallback, inCombat)
    if inCombat then
        return createSmartChecker(
            getChecker(self.friendRCInCombat, range) or fallback,
            getChecker(self.harmRCInCombat, range) or fallback,
            getChecker(self.miscRCInCombat, range) or fallback
        )
    else
        return createSmartChecker(
            getChecker(self.friendRC, range) or fallback,
            getChecker(self.harmRC, range) or fallback,
            getChecker(self.miscRC, range) or fallback
        )
    end
end
function lib.GetRange(_, unit, checkVisible, noItems, maxCacheAge)
    if not UnitExists(unit) then
        return nil
    end
    if checkVisible and not UnitIsVisible(unit) then
        return nil
    end
    return getCachedRange(unit, noItems, maxCacheAge)
end
lib.getRange = lib.GetRange
function lib.OnEvent(self, event, ...)
    if type(self[event]) == "function" then
        self[event](self, event, ...)
    end
end
function lib.LEARNED_SPELL_IN_TAB(self)
    self:scheduleInit()
end
function lib.CHARACTER_POINTS_CHANGED(self)
    self:scheduleInit()
end
function lib.PLAYER_TALENT_UPDATE(self)
    self:scheduleInit()
end
function lib.SPELLS_CHANGED(self)
    self:scheduleInit()
end
function lib.CVAR_UPDATE(self, _, cvar)
    if cvar == "ShowAllSpellRanks" then
        self:scheduleInit()
    end
end
function lib.UNIT_INVENTORY_CHANGED(self, _, unit)
    if self.initialized and (unit == "player" and self.handSlotItem ~= GetInventoryItemLink("player", HandSlotId)) then
        self:scheduleInit()
    end
end
function lib.UNIT_AURA(self, _, unit)
    if self.initialized and unit == "player" then
        self:scheduleAuraCheck()
    end
end
function lib.GET_ITEM_INFO_RECEIVED(self, _, item, success)
    if pendingItemRequest[item] then
        pendingItemRequest[item] = nil
        itemRequestTimeoutAt[item] = nil
        if not success then
            self.failedItemRequests[item] = true
        end
        lastUpdate = UpdateDelay
    end
end
function lib.processItemRequests(self, itemRequests)
    while true do
        local range, items = next(itemRequests)
        if not range then
            return
        end
        while true do
            local i, item = next(items)
            if not i then
                itemRequests[range] = nil
                break
            elseif (Item:CreateFromItemID(item)):IsItemEmpty() or self.failedItemRequests[item] then
                tremove(items, i)
            elseif pendingItemRequest[item] and GetTime() < itemRequestTimeoutAt[item] then
                return true
            elseif C_Item.GetItemInfo(item) then
                foundNewItems = true
                itemRequestTimeoutAt[item] = nil
                pendingItemRequest[item] = nil
                if not cacheAllItems then
                    itemRequests[range] = nil
                    break
                end
                tremove(items, i)
            elseif not itemRequestTimeoutAt[item] then
                itemRequestTimeoutAt[item] = GetTime() + ItemRequestTimeout
                pendingItemRequest[item] = true
                if not self.frame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
                    self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
                end
                return true
            elseif GetTime() >= itemRequestTimeoutAt[item] then
                if cacheAllItems then
                    print(MAJOR_VERSION .. (": timeout for item: " .. tostring(item)))
                end
                self.failedItemRequests[item] = true
                itemRequestTimeoutAt[item] = nil
                pendingItemRequest[item] = nil
                tremove(items, i)
            else
                return true
            end
        end
    end
end
function lib.initialOnUpdate(self)
    self:init()
    if friendItemRequests then
        if self:processItemRequests(friendItemRequests) then
            return
        end
        friendItemRequests = nil
    end
    if harmItemRequests then
        if self:processItemRequests(harmItemRequests) then
            return
        end
        harmItemRequests = nil
    end
    if foundNewItems then
        self:init(true)
        foundNewItems = nil
    end
    if cacheAllItems then
        print(MAJOR_VERSION .. ": finished cache")
        cacheAllItems = nil
    end
    self.frame:Hide()
    self.frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end
function lib.scheduleInit(self)
    self.initialized = nil
    lastUpdate = 0
    self.frame:Show()
end
function lib.scheduleAuraCheck(self)
    lastUpdate = UpdateDelay
    self.frame:Show()
end
function lib.activate(self)
    if not self.frame then
        local frame = CreateFrame("Frame")
        self.frame = frame
        frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
        frame:RegisterEvent("SPELLS_CHANGED")
        if C_EventUtils and C_EventUtils.IsEventValid("LEARNED_SPELL_IN_TAB") then
            frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
        end
        if C_EventUtils and C_EventUtils.IsEventValid("PLAYER_TALENT_UPDATE") then
            frame:RegisterEvent("PLAYER_TALENT_UPDATE")
        end
        if isEra or isBCC or isWrath or isCata then
            frame:RegisterEvent("CVAR_UPDATE")
        end
        local _, playerClass = UnitClass("player")
        if playerClass == "MAGE" or playerClass == "SHAMAN" then
            frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        end
    end
    if not self.cacheResetTimer then
        self.cacheResetTimer = C_Timer.NewTicker(5, function()
            invalidateRangeCache(5)
        end)
    end
    initItemRequests()
    self.frame:SetScript("OnEvent", function(_, ...)
        self:OnEvent(...)
    end)
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        lastUpdate = lastUpdate + elapsed
        if lastUpdate < UpdateDelay then
            return
        end
        lastUpdate = 0
        self:initialOnUpdate()
    end)
    self:scheduleInit()
end
do
    lib.RegisterCallback = lib.RegisterCallback
        or function(...)
            local libStub = LibStub("CallbackHandler-1.0")
            lib.RegisterCallback = nil
            lib.callbacks = libStub:New(lib)
            return lib.RegisterCallback(...)
        end
end
lib:activate()
