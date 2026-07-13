local function playAnim(animDict, animName, duration, flags, introtiming, exittiming)
    RequestAnimDict(animDict)

    local t = 5
    while not HasAnimDictLoaded(animDict) and t > 0 do
        t = t - 1
        Wait(300)
    end

    TaskPlayAnim(cache.ped, animDict, animName, tonumber(introtiming) or 1.0, tonumber(exittiming) or 1.0, duration or -1, flags or 1, 1, false, false, false, 0, true)
    RemoveAnimDict(animDict)
end

local function normalizeBodyOption(bodyOption)
    if type(bodyOption) == 'table' then
        bodyOption = bodyOption.body
    end

    if type(bodyOption) ~= 'string' or bodyOption == '' then
        return 'full'
    end

    bodyOption = bodyOption:lower()

    if bodyOption == 'upper' then
        return 'upper'
    end

    return 'full'
end

local function findAnimation(animationName)
    if type(animationName) ~= 'string' or animationName == '' then
        return nil
    end

    local requestedName = animationName:lower()

    for _, animation in pairs(Config.Animations) do
        if animation.Label and animation.Label:lower() == requestedName then
            return animation
        end
    end

    return nil
end

local function playEmote(emoteType, bodyMode)
    if bodyMode == 'upper' then
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, cache.ped, 0, 0, joaat(emoteType), 1, 1, 0, 0, 0)
        return
    end

    Citizen.InvokeNative(0xB31A277C1AC7B7FF, cache.ped, 0, 2, joaat(emoteType), 0, 0, 0, 0, 0)
end

local function playAnimationByName(animationName, bodyOption)
    local animation = findAnimation(animationName)
    local bodyMode = normalizeBodyOption(bodyOption)

    if not animation then
        return false, ('Animation "%s" was not found'):format(tostring(animationName))
    end

    if bodyMode == 'upper' then
        ClearPedSecondaryTask(cache.ped)
    else
        ClearPedTasks(cache.ped)
    end

    if animation.Type == 'Anim' and animation.Dict and animation.Body then
        local flags = bodyMode == 'upper' and (animation.HalfBodyFlag or 31) or (animation.FullBodyFlag or animation.Flag or 0)
        playAnim(animation.Dict, animation.Body, -1, flags)
        return true
    end

    if animation.Type == 'Emote' and animation.EmoteType then
        playEmote(animation.EmoteType, bodyMode)
        return true
    end

    if animation.Type == 'Scenario' and animation.Scenario then
        TaskStartScenarioInPlace(cache.ped, joaat(animation.Scenario), -1, true)
        return true
    end

    return false, ('Animation "%s" has unsupported animation data'):format(animation.Label)
end

exports('PlayAnimation', playAnimationByName)

-- exports['rsg-animations']:PlayAnimation('Wave', 'full')
-- animation does the full body.
-- exports['rsg-animations']:PlayAnimation('Wave', 'upper')
-- animation does only the upper of the body. Allows animations to be done on horse and other positions.
