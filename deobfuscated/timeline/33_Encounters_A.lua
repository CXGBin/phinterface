--[[
  Encounters_A —— 时间轴规划器：首领时间轴事件 → 技能识别（一批首领）
  原始文件：c6142a.lua（TOC 第 33 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
P8BA6426E.TimelinePlannerEncounters = {}
local function createPlanner_3470_15()
    local stage, introCastConfirmed, lastCastStartAt = 1, false, 0
    local seenCountBySeconds = {}
    local function resolve(duration)
        local seconds = math.floor(duration + 0.5)
        local mechanic
        if stage < 2 then
            if seconds == 40 or seconds == 28 or seconds == 15 then
                seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                if seenCountBySeconds[seconds] == 1 then
                    return nil
                end
            end
            if seconds == 40 then
                mechanic = seenCountBySeconds[seconds] % 2 == 0 and "restless_amani" or "essence_rend"
            elseif seconds == 28 or seconds == 36 then
                mechanic = "possession_barrage"
            elseif seconds == 15 then
                mechanic = "essence_rend"
            elseif seconds == 30 then
                mechanic = "restless_amani"
            end
        else
            if seconds == 28 then
                mechanic = "possession_barrage"
            elseif seconds == 40 then
                seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                mechanic = seenCountBySeconds[seconds] % 2 == 1 and "possession_barrage" or "restless_amani"
            elseif seconds == 50 then
                mechanic = "essence_rend"
            elseif seconds == 20 then
                mechanic = "restless_amani"
            end
        end
        return mechanic, stage == 1 and 1 or stage == 1.5 and 2 or 3
    end
    local function onUnitEvent(event, now)
        if event == "UNIT_SPELLCAST_START" then
            lastCastStartAt = now
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if stage == 1 and (lastCastStartAt > 0 and now - lastCastStartAt < 2) then
                introCastConfirmed = true
                wipe(seenCountBySeconds)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            if stage == 1 and introCastConfirmed then
                stage, introCastConfirmed = 1.5, false
            elseif stage == 1.5 then
                stage = 2
                wipe(seenCountBySeconds)
            end
        end
    end
    return { Resolve = resolve, OnUnitEvent = onUnitEvent }
end
local function createPlanner_3201_8()
    local stage, stageCycle = 1, 1
    local STAGE3_ROTATION = { "lightfire", "grievous_thrash", "lightfall", "pulverizing_strikes" }
    local function advanceStage(newStage)
        if newStage > stage then
            stage, stageCycle = newStage, 1
        end
    end
    return {
        IsPhaseMarker = function(duration)
            local rounded = math.floor(duration * 10 + 0.5) / 10
            return rounded == 2.5 or rounded == 3 or rounded == 9
        end,
        PrepareBatch = function(batch)
            for _, entry in ipairs(batch) do
                local rounded = math.floor(entry.duration * 10 + 0.5) / 10
                if rounded == 2.5 then
                    advanceStage(3)
                elseif rounded == 3 or rounded == 9 then
                    advanceStage(2)
                end
            end
        end,
        Resolve = function(duration)
            local rounded = math.floor(duration * 10 + 0.5) / 10
            local mechanic
            if stage == 1 and (rounded == 3 or rounded == 9) then
                advanceStage(2)
            end
            if rounded == 2.5 then
                advanceStage(3)
            elseif rounded == 0.5 then
                return nil
            elseif stage == 3 then
                if rounded == 7.3 then
                    mechanic = "lightfire"
                elseif rounded == 15.3 then
                    mechanic = "grievous_thrash"
                elseif rounded == 23.3 then
                    mechanic = "lightfall"
                elseif rounded == 31.1 or rounded == 31.3 then
                    mechanic = "pulverizing_strikes"
                elseif rounded == 32 then
                    mechanic = STAGE3_ROTATION[(stageCycle - 1) % 4 + 1]
                end
            elseif rounded == 5 or (stage == 1 and (rounded >= 19.9 and (rounded <= 21 and stageCycle % 2 == 1))) then
                mechanic = "lightfire"
            elseif rounded == 18 or (stage == 1 and (rounded >= 19.9 and (rounded <= 21 and stageCycle % 2 == 0))) then
                mechanic = "lightfall"
            elseif rounded == 3 or (stage == 2 and (rounded >= 19.9 and (rounded <= 21 and stageCycle % 2 == 1))) then
                mechanic = "grievous_thrash"
            elseif rounded == 9 or (stage == 2 and (rounded >= 19.9 and (rounded <= 21 and stageCycle % 2 == 0))) then
                mechanic = "pulverizing_strikes"
            end
            if (rounded >= 20 and rounded <= 21) or rounded == 32 then
                stageCycle = stageCycle + 1
            end
            return mechanic, stage
        end,
    }
end
local function createPlanner_3202_8()
    local ROTATION = { "awaken_lightbloom", "lightblooms_essence", "thornspike", "concentrated_lightbeam" }
    local MECHANIC_BY_SECONDS = { [4] = ROTATION[1], [14] = ROTATION[2], [26] = ROTATION[3], [40] = ROTATION[4] }
    local rotationIndex = 0
    return {
        Resolve = function(duration)
            if duration == 50 then
                rotationIndex = rotationIndex % #ROTATION + 1
                return ROTATION[rotationIndex], 1
            end
            return MECHANIC_BY_SECONDS[duration], 1
        end,
    }
end
local function createPlanner_3199_8()
    local ROTATION = { "bedrock_slam", "thornblade", "lightsower_dash", "lightblossom_beam" }
    local MECHANIC_BY_SECONDS = { [5] = ROTATION[1], [8] = ROTATION[2], [20] = ROTATION[3], [35] = ROTATION[4] }
    local rotationIndex = 0
    return {
        Resolve = function(duration)
            local seconds = math.floor(duration + 0.5)
            if seconds > 40 and seconds <= 45 then
                rotationIndex = rotationIndex % #ROTATION + 1
                return ROTATION[rotationIndex], 1
            end
            return MECHANIC_BY_SECONDS[seconds], 1
        end,
    }
end
local function createPlanner_3074_8()
    local ROTATION = { "hulking_fragment", "devouring_entropy", "unstable_void_essence" }
    local MECHANIC_BY_SECONDS = { [3] = ROTATION[1], [9] = ROTATION[2], [15] = ROTATION[3] }
    local rotationIndex = 0
    return {
        Resolve = function(duration)
            local seconds = math.floor(duration + 0.5)
            if seconds == 22 or seconds == 24 then
                rotationIndex = rotationIndex % #ROTATION + 1
                return ROTATION[rotationIndex], 1
            end
            return MECHANIC_BY_SECONDS[seconds], 1
        end,
    }
end
local function createPlanner_3073_8()
    local fiveSecondCount = 0
    return {
        Resolve = function(duration)
            local rounded = math.floor(duration * 10 + 0.5) / 10
            if rounded > 60 then
                return nil, 1
            end
            if rounded == 5 then
                fiveSecondCount = fiveSecondCount + 1
                return fiveSecondCount == 1 and "triplicate" or "cosmic_sting", 1
            elseif rounded == 8 then
                return "cosmic_sting", 1
            elseif rounded == 16 then
                return "neural_link", 1
            elseif rounded == 29 then
                return "astral_grasp", 1
            end
            return nil, 1
        end,
    }
end
local function createPlanner_3072_8()
    local lastRunicMarkSeconds, lastRunicMarkEventID, lastRunicMarkAt = 0, nil, nil
    return {
        Resolve = function(duration, eventID, observedAt)
            local seconds = math.floor(duration + 0.5)
            if seconds > 90 then
                return nil, 1
            end
            if seconds == 7 or seconds == 29 then
                if seconds == lastRunicMarkSeconds then
                    return nil, 1
                end
                local replacedEventID
                if lastRunicMarkEventID and (lastRunicMarkAt > 0 and observedAt > 0) then
                    local elapsed = observedAt - lastRunicMarkAt
                    if elapsed >= 0 and elapsed < 3 then
                        replacedEventID = lastRunicMarkEventID
                    end
                end
                lastRunicMarkSeconds = seconds
                lastRunicMarkEventID, lastRunicMarkAt = eventID, observedAt
                return "runic_mark", 1, replacedEventID
            elseif seconds == 17 then
                return "suppression_zone", 1
            elseif seconds == 26 then
                return "hastening_ward", 1
            elseif seconds == 51 then
                return "wave_of_silence", 1
            end
            return nil, 1
        end,
        OnEventClosed = function(eventID)
            if eventID == lastRunicMarkEventID then
                lastRunicMarkEventID, lastRunicMarkAt = nil, nil
            end
        end,
    }
end
local function createPlanner_3071_8()
    local stage, cycle = 1, 1
    local mechanicCount = { repulsing_slam = 1, arcane_expulsion = 1 }
    local mechanicByEventID = {}
    local preannounced, finalPhase = {}, false
    return {
        Resolve = function(duration, eventID, _, state)
            if state == 1 or finalPhase then
                return nil, stage
            end
            local rounded = math.floor(duration * 10 + 0.5) / 10
            local mechanic
            if rounded > 50 then
                return nil, stage
            end
            if rounded == 5 or rounded == 22.5 then
                if rounded == 22.5 and mechanicCount.repulsing_slam > cycle * 2 then
                    return nil, stage
                end
                mechanic = "repulsing_slam"
            elseif rounded == 15 or rounded == 23 then
                if rounded == 23 and mechanicCount.arcane_expulsion > cycle * 2 then
                    return nil, stage
                end
                mechanic = "arcane_expulsion"
            elseif rounded == 22 then
                mechanic = "ethereal_shackles"
            elseif duration == 45 then
                mechanic = "refueling_protocol"
            end
            if state == nil then
                if duration == 45 or duration == 48 then
                    finalPhase = true
                elseif mechanic then
                    preannounced[mechanic] = true
                end
                return nil, stage
            end
            if mechanic and preannounced[mechanic] then
                return nil, stage
            end
            if duration == 45 then
                stage = 1
            elseif duration == 48 then
                stage, cycle = 2, cycle + 1
            end
            if mechanic and mechanicCount[mechanic] then
                mechanicCount[mechanic] = mechanicCount[mechanic] + 1
                mechanicByEventID[eventID] = mechanic
            end
            return mechanic, stage
        end,
        OnEventClosed = function(eventID, state, reason)
            if reason == "added" then
                return
            end
            local mechanic = mechanicByEventID[eventID]
            if not mechanic then
                return
            end
            mechanicByEventID[eventID] = nil
            if state == 3 then
                mechanicCount[mechanic] = mechanicCount[mechanic] - 1
            end
        end,
    }
end
local function createPlanner_3492_15()
    local stage, pendingStage3 = 1, false
    local seenCountBySeconds = {}
    local stage1RageEvents, stage25MarkerEvents = {}, {}
    local submergeCheckAt
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
        if stage < 2.5 then
            stage, pendingStage3 = 2.5, false
            resetCounts()
        end
    end
    return {
        Resolve = function(duration, eventID)
            local seconds = math.floor(duration + 0.5)
            if stage == 1 and seconds == 118 then
                advanceStage(2)
            elseif stage == 2 and seconds == 10 then
                enterIntermission()
            elseif stage == 2.5 and pendingStage3 then
                advanceStage(3)
                pendingStage3 = false
            end
            if stage == 1 or stage == 2 then
                local mechanic
                if seconds == 5 or seconds == 70 then
                    mechanic = "gore_rattle"
                elseif seconds == 10 or seconds == 37 or seconds == 67 then
                    mechanic = "mothers_wrath"
                elseif seconds == 20 or seconds == 94 or seconds == 95 then
                    mechanic = "spectral_coils"
                elseif seconds == 35 then
                    mechanic = "mephitic_thrash"
                elseif seconds == 42 then
                    mechanic = "caustic_waves"
                elseif seconds == 62 then
                    mechanic = "submerge_p1"
                elseif seconds == 72 then
                    mechanic = "call_of_the_serpent"
                elseif seconds == 129 or seconds == 118 then
                    mechanic = "rage_of_the_shackled"
                    if stage == 1 and seconds == 129 then
                        stage1RageEvents[eventID] = true
                    end
                elseif seconds == 52 then
                    seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
                    if seenCountBySeconds[seconds] == 1 then
                        mechanic = "mephitic_thrash"
                    elseif seenCountBySeconds[seconds] == 2 then
                        mechanic = "caustic_waves"
                    end
                elseif seconds == 30 or seconds == 40 then
                    mechanic = "virulent_spit"
                end
                return mechanic, stage
            end
            if stage == 2.5 then
                if seconds == 10 then
                    stage25MarkerEvents[eventID] = true
                end
                return nil, 2
            end
            seenCountBySeconds[seconds] = (seenCountBySeconds[seconds] or 0) + 1
            local seenCount = seenCountBySeconds[seconds]
            if
                (
                    seconds == 235
                    or seconds == 205
                    or seconds == 67
                    or seconds == 60
                    or seconds == 50
                    or seconds == 25
                    or seconds == 10
                    or seconds == 5
                ) and seenCount == 1
            then
                return nil, 3
            end
            if seconds == 235 then
                return "fury_unleashed", 3
            end
            if seconds == 205 then
                return "rage_of_the_shackled", 3
            end
            if seconds == 5 or seconds == 30 or seconds == 45 then
                return "call_of_the_serpent", 3
            end
            if seconds == 10 or seconds == 75 or seconds == 76 then
                return "mothers_wrath", 3
            end
            if seconds == 25 or seconds == 71 or seconds == 37 then
                return "serpents_bite", 3
            end
            if seconds == 50 or seconds == 55 or seconds == 44 then
                return "caustic_waves", 3
            end
            if seconds == 51 or seconds == 61 or seconds == 52 then
                return "circling_prey", 3
            end
            if seconds == 67 or seconds == 53 then
                return "submerge_p3", 3
            end
            if seconds == 60 then
                if seenCount == 2 then
                    return "circling_prey", 3
                end
                if seenCount == 3 then
                    return "call_of_the_serpent", 3
                end
                if seenCount == 4 then
                    return "submerge_p3", 3
                end
                if seenCount == 5 then
                    return "serpents_bite", 3
                end
            end
            return nil, 3
        end,
        OnEventClosed = function(eventID, state)
            if stage1RageEvents[eventID] then
                stage1RageEvents[eventID] = nil
                if state == 2 and stage == 1 then
                    submergeCheckAt = GetTimePreciseSec() + 6.5
                end
            end
            if stage25MarkerEvents[eventID] then
                stage25MarkerEvents[eventID] = nil
                if state == 2 and stage == 2.5 then
                    pendingStage3 = true
                end
            end
        end,
        OnUnitEvent = function(event, now)
            if
                event == "UNIT_TARGETABLE_CHANGED"
                and (
                    stage == 1
                    and (
                        submergeCheckAt
                        and (
                            now >= submergeCheckAt
                            and (type(UnitCanAttack) == "function" and UnitCanAttack("player", "boss1") == false)
                        )
                    )
                )
            then
                advanceStage(2)
                submergeCheckAt = nil
            end
        end,
    }
end
P8BA6426E.TimelinePlannerEncounters[347015] = {
    Create = createPlanner_3470_15,
    mechanicCodes = { essence_rend = 1, possession_barrage = 2, restless_amani = 3 },
    unitEvents = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START" },
}
P8BA6426E.TimelinePlannerEncounters[320108] = {
    Create = createPlanner_3201_8,
    batchSeconds = 0.1,
    mechanicCodes = { lightfire = 1, lightfall = 2, grievous_thrash = 3, pulverizing_strikes = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[320208] = {
    Create = createPlanner_3202_8,
    countIdentifiableAdds = true,
    mechanicCodes = { awaken_lightbloom = 1, lightblooms_essence = 2, thornspike = 3, concentrated_lightbeam = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[319908] = {
    Create = createPlanner_3199_8,
    countIdentifiableAdds = true,
    mechanicCodes = { bedrock_slam = 1, thornblade = 2, lightsower_dash = 3, lightblossom_beam = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[307408] = {
    Create = createPlanner_3074_8,
    countIdentifiableAdds = true,
    mechanicCodes = { hulking_fragment = 1, devouring_entropy = 2, unstable_void_essence = 3 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[307308] = {
    Create = createPlanner_3073_8,
    countIdentifiableAdds = true,
    mechanicCodes = { triplicate = 1, cosmic_sting = 2, neural_link = 3, astral_grasp = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[307208] = {
    Create = createPlanner_3072_8,
    countIdentifiableAdds = true,
    mechanicCodes = { runic_mark = 1, suppression_zone = 2, hastening_ward = 3, wave_of_silence = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[307108] = {
    Create = createPlanner_3071_8,
    countIdentifiableAdds = true,
    mechanicCodes = { repulsing_slam = 1, arcane_expulsion = 2, ethereal_shackles = 3, refueling_protocol = 4 },
    unitEvents = {},
}
P8BA6426E.TimelinePlannerEncounters[349215] = {
    Create = createPlanner_3492_15,
    countIdentifiableAdds = true,
    mechanicCodes = {
        gore_rattle = 1,
        mothers_wrath = 2,
        spectral_coils = 3,
        mephitic_thrash = 4,
        caustic_waves = 5,
        submerge_p1 = 6,
        call_of_the_serpent = 7,
        rage_of_the_shackled = 8,
        virulent_spit = 9,
        fury_unleashed = 10,
        serpents_bite = 11,
        circling_prey = 12,
        submerge_p3 = 13,
    },
    unitEvents = { "UNIT_TARGETABLE_CHANGED" },
}
