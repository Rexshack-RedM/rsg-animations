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

local function playAnimationByName(animationName)
    local animation = findAnimation(animationName)

    if not animation then
        return false, ('Animation "%s" was not found'):format(tostring(animationName))
    end

    ClearPedTasks(cache.ped)

    if animation.Type == 'Anim' and animation.Dict and animation.Body then
        playAnim(animation.Dict, animation.Body, -1, animation.Flag or 0)
        return true
    end

    if animation.Type == 'Emote' and animation.EmoteType then
        TaskEmote(cache.ped, 0, 2, joaat(animation.EmoteType), true, true, true, true, true)
        return true
    end

    if animation.Type == 'Scenario' and animation.Scenario then
        TaskStartScenarioInPlace(cache.ped, joaat(animation.Scenario), -1, true)
        return true
    end

    return false, ('Animation "%s" has unsupported animation data'):format(animation.Label)
end

exports('PlayAnimation', playAnimationByName)
