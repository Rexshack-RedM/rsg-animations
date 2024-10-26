local RSGCore = exports['rsg-core']:GetCoreObject()

--------------
--- acces
--------------
RegisterCommand(Config.CommandOpen, function(source, args, rawCommand)
    TriggerServerEvent('rsg-animations:server:Open')
end, false)

RegisterNetEvent('rsg-animations:client:Open')
AddEventHandler('rsg-animations:client:Open', function(favorites)
    local Animations = Config.Animations

    for i, v in pairs(Animations) do
        Animations[i].Favorite = false
        for _, x in pairs(favorites) do
            if x == v.Label then
                Animations[i].Favorite = true
            end
        end
    end

    SendNUIMessage({
        type = 'Open',
        Animations = Animations,
    })

    SetNuiFocus(true, true)
    PlaySoundFrontend("BACK", "RDRO_Character_Creator_Sounds", true, 0)
end)

--------------
--- nui
--------------
RegisterNUICallback('StopAnim', function(args, cb)
    ClearPedTasks(cache.ped)
end)

RegisterNUICallback('Close', function(args, cb)
    SetNuiFocus(false, false)
    PlaySoundFrontend("BACK", "RDRO_Character_Creator_Sounds", true, 0)
end)

RegisterNUICallback('Favorite', function(args, cb)
    TriggerServerEvent('rsg-animations:server:Favorite', args.Animation, args.Favorite)
end)

--------------
--- ANIMATION
--------------
local function Anim(animDict, animName, duration, flags, introtiming, exittiming)
    RequestAnimDict(animDict)

    local t = 5
    while not HasAnimDictLoaded(animDict) and t > 0 do
        t = t - 1
        Wait(300)
    end

    TaskPlayAnim(cache.ped, animDict, animName, tonumber(introtiming) or 1.0, tonumber(exittiming) or 1.0, duration or -1, flags or 1, 1, false, false, false, 0, true)
    RemoveAnimDict(animDict)
end

RegisterNUICallback('Anim', function(args, cb)
    if args.Animation.Dict and args.Animation.Body then
        ClearPedTasks(cache.ped)
        Anim(args.Animation.Dict, args.Animation.Body, -1, args.Animation.Flag or 0)
    end
end)

RegisterNUICallback('Emote', function(args, cb)
    if args.Animation.EmoteType then
        ClearPedTasks(cache.ped)
        TaskEmote(cache.ped, 0, 2, joaat(args.Animation.EmoteType), true, true, true, true, true)
    end
end)

RegisterNUICallback('Scenario', function(args, cb)
    if args.Animation.Scenario then
        TaskStartScenarioInPlace(cache.ped, joaat(args.Animation.Scenario), -1, true)
    end
end)