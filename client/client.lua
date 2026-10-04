local isMenuOpen = false
local favorites = nil -- [label] = true, loaded once from the server

---------------------------------
-- lookup / locale helpers
---------------------------------
local AnimationsByLabel = {}

local function getLabelKey(label)
    local key = label:lower():gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    return 'anim_' .. key
end

local function getDisplayLabel(label)
    local key = getLabelKey(label)
    local text = locale(key)
    if not text or text == key then return label end
    return text
end

local function getUILocale()
    return {
        searchPlaceholder = locale('ui_search_placeholder'),
        title = locale('ui_title'),
        subtitle = locale('ui_subtitle'),
        all = locale('ui_category_all'),
        close = locale('ui_close'),
        gestures = locale('ui_category_gestures'),
        dances = locale('ui_category_dances'),
        emotes = locale('ui_category_emotes'),
        favorites = locale('ui_category_favorites'),
        stopAnimation = locale('ui_stop_animation'),
        favoriteHint = locale('ui_favorite_hint'),
        noResults = locale('ui_no_results'),
    }
end

-- build the lookup + translated labels once instead of on every open
for _, animation in ipairs(Config.Animations) do
    if animation.Label then
        animation.DisplayLabel = getDisplayLabel(animation.Label)
        AnimationsByLabel[animation.Label:lower()] = animation
    end
end

---------------------------------
-- playback
---------------------------------
local function playAnim(animDict, animName, flags)
    local ok = pcall(lib.requestAnimDict, animDict, 1500)
    if not ok or not HasAnimDictLoaded(animDict) then return false end

    TaskPlayAnim(cache.ped, animDict, animName, 1.0, 1.0, -1, flags or 0, 0, false, false, false, 0, true)
    RemoveAnimDict(animDict)
    return true
end

local function playEmote(emoteType, bodyMode)
    if bodyMode == 'upper' then
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, cache.ped, 0, 0, joaat(emoteType), 1, 1, 0, 0, 0)
    else
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, cache.ped, 0, 2, joaat(emoteType), 0, 0, 0, 0, 0)
    end
    return true
end

local function stopAnimation()
    ClearPedTasks(cache.ped)
    ClearPedSecondaryTask(cache.ped)
end

local function canAnimate()
    local ped = cache.ped
    return not IsEntityDead(ped) and not IsPedRagdoll(ped) and not IsPedFalling(ped) and not IsPedSwimming(ped)
end

local function normalizeBodyOption(bodyOption)
    if type(bodyOption) == 'table' then bodyOption = bodyOption.body end
    if type(bodyOption) == 'string' and bodyOption:lower() == 'upper' then return 'upper' end
    return 'full'
end

local function playAnimationByName(animationName, bodyOption)
    if type(animationName) ~= 'string' or animationName == '' then
        return false, locale('err_anim_not_found'):format(tostring(animationName))
    end

    local animation = AnimationsByLabel[animationName:lower()]
    if not animation then
        return false, locale('err_anim_not_found'):format(animationName)
    end

    if not canAnimate() then return false end

    local bodyMode = normalizeBodyOption(bodyOption)
    -- scenarios are always full body
    if animation.Type == 'Scenario' then bodyMode = 'full' end

    if bodyMode == 'upper' then
        ClearPedSecondaryTask(cache.ped)
    else
        ClearPedTasks(cache.ped)
    end

    if animation.Type == 'Anim' and animation.Dict and animation.Body then
        local flags = bodyMode == 'upper' and (animation.HalfBodyFlag or 31) or (animation.FullBodyFlag or animation.Flag or 0)
        return playAnim(animation.Dict, animation.Body, flags)
    elseif animation.Type == 'Emote' and animation.EmoteType then
        return playEmote(animation.EmoteType, bodyMode)
    elseif animation.Type == 'Scenario' and animation.Scenario then
        TaskStartScenarioInPlace(cache.ped, joaat(animation.Scenario), -1, true, false, false, false)
        return true
    end

    return false, locale('err_anim_unsupported'):format(animation.Label)
end

exports('PlayAnimation', playAnimationByName)
exports('StopAnimation', stopAnimation)

---------------------------------
-- menu
---------------------------------
local function closeMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    SetNuiFocus(false, false)
    PlaySoundFrontend('BACK', 'RDRO_Character_Creator_Sounds', true, 0)
end

local function openMenu()
    if isMenuOpen or not LocalPlayer.state.isLoggedIn then return end

    if not favorites then
        favorites = {}
        local list = lib.callback.await('rsg-animations:server:getFavorites', false) or {}
        for _, label in ipairs(list) do favorites[label] = true end
    end

    for _, animation in ipairs(Config.Animations) do
        animation.Favorite = favorites[animation.Label] == true
    end

    isMenuOpen = true
    SendNUIMessage({
        type = 'Open',
        Animations = Config.Animations,
        Locale = getUILocale(),
    })
    SetNuiFocus(true, true)
    PlaySoundFrontend('BACK', 'RDRO_Character_Creator_Sounds', true, 0)
end

RegisterCommand(Config.CommandOpen, openMenu, false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. Config.CommandOpen, locale('cmd_help'))
end)

-- reset the favourites cache on character switch
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    favorites = nil
    closeMenu()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isMenuOpen then
        SetNuiFocus(false, false)
    end
end)

---------------------------------
-- nui callbacks
---------------------------------
RegisterNUICallback('Play', function(data, cb)
    cb('ok')
    if type(data) == 'table' and type(data.label) == 'string' then
        playAnimationByName(data.label)
    end
end)

RegisterNUICallback('StopAnim', function(_, cb)
    cb('ok')
    stopAnimation()
end)

RegisterNUICallback('Close', function(_, cb)
    cb('ok')
    closeMenu()
end)

RegisterNUICallback('Favorite', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.label) ~= 'string' or not favorites then return end
    if not AnimationsByLabel[data.label:lower()] then return end

    local state = data.favorite == true
    favorites[data.label] = state or nil
    TriggerServerEvent('rsg-animations:server:Favorite', data.label, state)
end)
