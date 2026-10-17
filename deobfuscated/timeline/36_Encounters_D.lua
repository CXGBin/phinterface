--[[
  Encounters_D —— 时间轴规划器：首领时间轴事件 → 技能识别（一批首领）
  原始文件：a4c483.lua（TOC 第 36 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local function roundSeconds(seconds)
    local tenths = math.floor(seconds * 10 + 0.5) / 10
    return math.floor(tenths + 0.5)
end
local function createPlanner_3421_15()
    local seenCountBySeconds = {}
    local FEAST_ROTATION = {
        "caustic_deluge",
        "stone_breaker",
        "venomous_emergence",
        "coiling_ichor",
        "stir_the_depths",
        "ravenous_feast",
    }
    return {
        Resolve = function(duration)
            local seconds = roundSeconds(duration)
            local mechanic
            if seconds == 144 then
                mechanic = "submerge"
            elseif seconds == 6 then
                seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                mechanic = seenCountBySeconds[seconds] % 2 == 1 and "sanguine_storm" or "vile_flood"
            elseif seconds == 44 then
                mechanic = "coiling_ichor"
            elseif seconds == 63 then
                mechanic = "ravenous_feast"
            elseif seconds == 20 or seconds == 22 then
                mechanic = "stone_breaker"
            elseif seconds == 37 then
                mechanic = "venomous_emergence"
            elseif seconds == 9 then
                mechanic = "caustic_deluge"
            elseif seconds == 52 then
                mechanic = "stir_the_depths"
            elseif seconds == 68 then
                seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                mechanic = FEAST_ROTATION[(seenCountBySeconds[seconds] - 1) % #FEAST_ROTATION + 1]
            end
            return mechanic, 1
        end,
    }
end
local function createPlanner_3429_15()
    local STATE_FINISHED, STATE_CANCELED = 2, 3
    local stage = 1
    local seenCountBySeconds = {}
    local markerOrdinalByEventID, stage2Events = {}, {}
    local advanceArmed, armedOrdinal = false, nil
    local channelArmed = false
    local twelveSecondCount, markerOrdinal = 1, 1
    local PHASE_MARKER_SECONDS =
        { [6] = true, [13] = true, [22] = true, [31] = true, [33] = true, [34] = true, [38] = true, [70] = true }
    local function resetCounts()
        wipe(seenCountBySeconds)
    end
    local function advanceStage(newStage)
        if newStage > stage then
            stage = newStage
            resetCounts()
        end
    end
    local function enterIntermission()
        if stage == 2 then
            stage = 2.5
            channelArmed = false
            resetCounts()
        end
    end
    return {
        IsPhaseMarker = function(duration)
            local seconds = roundSeconds(duration)
            return stage == 1 and (seconds ~= 70 and PHASE_MARKER_SECONDS[seconds] == true)
        end,
        PrepareBatch = function(batch)
            if stage ~= 1 or not advanceArmed or not armedOrdinal then
                return
            end
            local batchTwelveCount = 0
            for _, entry in ipairs(batch) do
                if roundSeconds(entry.duration) == 12 then
                    batchTwelveCount = batchTwelveCount + 1
                end
            end
            if twelveSecondCount + batchTwelveCount > armedOrdinal then
                advanceArmed, armedOrdinal = false, nil
            end
        end,
        Resolve = function(duration, eventID)
            local seconds = roundSeconds(duration)
            if stage == 1 and (advanceArmed and PHASE_MARKER_SECONDS[seconds]) then
                advanceStage(2)
                advanceArmed = false
            end
            local mechanic
            if stage == 1 then
                if seconds == 2 then
                    mechanic = "toxic_deluge"
                elseif seconds == 12 then
                    twelveSecondCount = twelveSecondCount + 1
                    mechanic = "axegrinder"
                elseif seconds == 28 or seconds == 35 then
                    mechanic = "venomfang"
                elseif seconds == 43 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    mechanic = seenCountBySeconds[seconds] % 2 == 1 and "guillotine" or "toxic_deluge"
                elseif seconds == 20 or seconds == 17 or seconds == 21 or seconds == 16 then
                    mechanic = "sever"
                elseif seconds == 85 then
                    markerOrdinal = markerOrdinal + 1
                    markerOrdinalByEventID[eventID] = markerOrdinal
                    mechanic = "fangs_of_the_coiled_altar"
                end
            elseif stage == 2 then
                if seconds == 13 or seconds == 33 then
                    mechanic = "spiritcackle"
                elseif seconds == 70 then
                    stage2Events[eventID] = true
                    mechanic = "eternal_nightfall"
                elseif seconds == 6 then
                    mechanic = "dreadmarch"
                elseif seconds == 22 or seconds == 38 then
                    mechanic = "gloombomb"
                elseif seconds == 31 then
                    mechanic = "soul_sever"
                elseif seconds == 34 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    mechanic = seenCountBySeconds[seconds] % 2 == 1 and "soul_sever" or "dreadmarch"
                end
            elseif stage == 3 then
                if seconds == 61 or seconds == 101 or seconds == 44 or seconds == 108 then
                    mechanic = "dreadmarch"
                elseif seconds == 39 or seconds == 100 then
                    mechanic = "eternal_nightfall"
                elseif seconds == 26 or seconds == 51 or seconds == 67 or seconds == 86 then
                    mechanic = "gloombomb"
                elseif seconds == 2 or seconds == 47 or seconds == 57 or seconds == 43 or seconds == 62 then
                    mechanic = "toxic_deluge"
                elseif seconds == 32 or seconds == 34 or seconds == 38 then
                    mechanic = "blighted_sever"
                elseif seconds == 17 or seconds == 170 then
                    mechanic = "grim_guillotine"
                elseif seconds == 106 or seconds == 105 then
                    mechanic = "defilement_of_the_coiled_altar"
                elseif seconds == 33 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    local seenCount = seenCountBySeconds[seconds]
                    if seenCount == 1 or seenCount == 3 then
                        mechanic = "blighted_sever"
                    elseif seenCount == 2 then
                        mechanic = "gloombomb"
                    end
                elseif seconds == 60 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    local seenCount = seenCountBySeconds[seconds]
                    if seenCount == 1 then
                        mechanic = "defilement_of_the_coiled_altar"
                    elseif seenCount == 2 then
                        mechanic = "toxic_deluge"
                    end
                end
            end
            return mechanic, stage == 2.5 and 2 or stage
        end,
        OnEventClosed = function(eventID, state)
            local ordinal = markerOrdinalByEventID[eventID]
            if ordinal then
                markerOrdinalByEventID[eventID] = nil
                if state == STATE_CANCELED and stage == 1 then
                    advanceArmed, armedOrdinal = true, ordinal
                    if twelveSecondCount > ordinal then
                        advanceArmed, armedOrdinal = false, nil
                    end
                end
            end
            if stage2Events[eventID] then
                stage2Events[eventID] = nil
                if stage == 2 then
                    if state == STATE_CANCELED then
                        enterIntermission()
                    elseif state == STATE_FINISHED then
                        channelArmed = true
                    end
                end
            end
        end,
        OnUnitEvent = function(event, _, unit)
            if unit ~= "boss2" then
                return
            end
            if event == "UNIT_SPELLCAST_CHANNEL_START" and (stage == 2 and channelArmed) then
                enterIntermission()
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and stage == 2.5 then
                advanceStage(3)
            end
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[342115] = {
    Create = createPlanner_3421_15,
    countIdentifiableAdds = true,
    mechanicCodes = {
        caustic_deluge = 1,
        sanguine_storm = 2,
        vile_flood = 3,
        coiling_ichor = 4,
        ravenous_feast = 5,
        stone_breaker = 6,
        venomous_emergence = 7,
        stir_the_depths = 8,
        submerge = 9,
    },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[342915] = {
    Create = createPlanner_3429_15,
    batchSeconds = 0.1,
    countIdentifiableAdds = true,
    mechanicCodes = {
        fangs_of_the_coiled_altar = 1,
        toxic_deluge = 2,
        axegrinder = 3,
        venomfang = 4,
        guillotine = 5,
        sever = 6,
        spiritcackle = 7,
        eternal_nightfall = 8,
        dreadmarch = 9,
        gloombomb = 10,
        soul_sever = 11,
        defilement_of_the_coiled_altar = 12,
        grim_guillotine = 13,
        blighted_sever = 14,
    },
    unitEvents = { "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" },
    unitEventUnits = { UNIT_SPELLCAST_CHANNEL_START = { "boss2" }, UNIT_SPELLCAST_CHANNEL_STOP = { "boss2" } },
}
