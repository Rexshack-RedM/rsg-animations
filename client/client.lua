local RSGCore = exports['rsg-core']:GetCoreObject()
local isMenuOpen = false
local isOpening = false
local favorites = nil -- [label] = true, loaded once per character
local menuSession = 0 -- ends the loops of an earlier menu opening
local playToken = 0   -- the newest play / stop request wins while an anim dict is loading
RSGAnims = {}         -- shared with client/extras.lua and client/together.lua

---------------------------------
-- lookup / locale helpers
---------------------------------
local AnimationsByLabel = {}
local MenuAnimations = {} -- only what the UI needs, built once

local function getDisplayLabel(label)
    local key = 'anim_' .. label:lower():gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    local text = locale(key)
    if not text or text == key then return label end
    return text
end

-- "Tip hat", "tip_hat" and "tiphat" all find the same entry
local function normalizeName(name)
    return (name:lower():gsub('[%s_%-%(%)\']', ''))
end

local AnimationsByName = {} -- normalised label, alias or translated name
local SharedSet = {}
for _, label in ipairs(Config.Shared.Animations) do SharedSet[label] = true end

for _, animation in ipairs(Config.Animations) do
    animation.DisplayName = getDisplayLabel(animation.Label)
    AnimationsByLabel[animation.Label:lower()] = animation
    AnimationsByName[normalizeName(animation.Label)] = animation
    MenuAnimations[#MenuAnimations + 1] = {
        Label = animation.Label,
        DisplayLabel = animation.DisplayName,
        Category = animation.Category,
        Type = animation.Type,
        Shared = Config.Shared.Enabled and SharedSet[animation.Label] or false,
    }
end

for _, animation in ipairs(Config.Animations) do
    local name = normalizeName(animation.DisplayName)
    AnimationsByName[name] = AnimationsByName[name] or animation
end

for old, new in pairs(Config.LabelAliases) do
    local animation = AnimationsByLabel[new:lower()]
    AnimationsByLabel[old:lower()] = animation
    AnimationsByName[normalizeName(old)] = animation
end

local function findAnimation(name)
    if type(name) ~= 'string' then return nil end
    return AnimationsByLabel[name:lower()] or AnimationsByName[normalizeName(name)]
end

-- job / gang restrictions (cosmetic: animations run on the player's own game)
local function hasAccess(animation)
    if not animation.Jobs and not animation.Gangs then return true end
    return HasAnimationAccess(animation, RSGCore.Functions.GetPlayerData())
end

local UILocale = {
    searchPlaceholder = locale('ui_search_placeholder'),
    title = locale('ui_title'),
    subtitle = locale('ui_subtitle'),
    all = locale('ui_category_all'),
    close = locale('ui_close'),
    gestures = locale('ui_category_gestures'),
    dances = locale('ui_category_dances'),
    emotes = locale('ui_category_emotes'),
    favorites = locale('ui_category_favorites'),
    upperBody = locale('ui_upper_body'),
    stopAnimation = locale('ui_stop_animation'),
    recent = locale('ui_category_recent'),
    together = locale('ui_category_together'),
    walk = locale('ui_category_walk'),
    quickSlots = locale('ui_quick_slots'),
    slotHint = locale('ui_slot_hint'),
    assignHint = locale('ui_assign_hint'),
    assign = locale('ui_assign'),
    invite = locale('ui_invite'),
    togetherHint = locale('ui_together_hint'),
    nowPlaying = locale('ui_now_playing'),
    favoriteHint = locale('ui_favorite_hint'),
    noResults = locale('ui_no_results'),
}

local function notifyError(description)
    RSGCore.Functions.Notify({ title = locale('ui_title'), description = description, type = 'error' })
end

---------------------------------
-- player state
---------------------------------
-- dead, cuffed, hogtied, lassoed or dragged: playing or clearing tasks here would let the player break free
local function isRestrained(ped)
    local data = RSGCore.Functions.GetPlayerData()
    local meta = data and data.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed or meta.isescorted then return true end

    return IsEntityDead(ped)
        or IsPedCuffed(ped)
        or Citizen.InvokeNative(0x3AA24CCC0D451379, ped, Citizen.ResultAsInteger()) == 1 -- IsPedHogtied
        or Citizen.InvokeNative(0x9682F850056C9ADE, ped, Citizen.ResultAsInteger()) == 1 -- IsPedLassoed
end

local function isSeated(ped)
    return IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false)
end

local function canAnimate(ped)
    return not isRestrained(ped) and not IsPedRagdoll(ped) and not IsPedFalling(ped) and not IsPedSwimming(ped)
end

---------------------------------
-- playback
---------------------------------
local function stopAnimation()
    playToken = playToken + 1

    local ped = PlayerPedId()
    if isRestrained(ped) then return false end

    ClearPedSecondaryTask(ped)
    -- clearing the primary task would throw the player off a horse or wagon
    if not isSeated(ped) then ClearPedTasks(ped) end
    RSGAnims.OnStop()
    return true
end

local function playAnimationByName(animationName, bodyOption)
    if type(animationName) ~= 'string' or animationName == '' then
        return false, locale('err_anim_not_found', tostring(animationName))
    end

    local animation = findAnimation(animationName)
    if not animation then
        return false, locale('err_anim_not_found', animationName)
    end

    if not hasAccess(animation) then return false, locale('err_no_access') end

    local ped = PlayerPedId()
    if not canAnimate(ped) then return false, locale('err_cannot_animate') end

    if type(bodyOption) == 'table' then bodyOption = bodyOption.body end
    local upper = type(bodyOption) == 'string' and bodyOption:lower() == 'upper'

    if animation.Type == 'Scenario' then
        if isSeated(ped) then return false, locale('err_mounted') end
        upper = false -- scenarios are always full body
    elseif isSeated(ped) then
        upper = true
    end

    local isAnim = animation.Type == 'Anim' and animation.Dict and animation.Body
    local isEmote = animation.Type == 'Emote' and animation.EmoteType
    local isScenario = animation.Type == 'Scenario' and animation.Scenario
    if not (isAnim or isEmote or isScenario) then
        return false, locale('err_anim_unsupported', animation.Label)
    end

    playToken = playToken + 1
    local token = playToken

    if isAnim then
        -- rsg-core errors on an invalid dict or timeout, so guard it
        if not pcall(RSGCore.Functions.RequestAnimDict, animation.Dict, 1500) then
            return false, locale('err_anim_unsupported', animation.Label)
        end
        -- loading yields: the player may have clicked something else, mounted or been cuffed
        ped = PlayerPedId()
        if token ~= playToken or not canAnimate(ped) or (not upper and isSeated(ped)) then
            RemoveAnimDict(animation.Dict)
            return false
        end
    end

    ClearPedSecondaryTask(ped)
    if not upper then ClearPedTasks(ped) end

    if isAnim then
        local flags
        if upper then
            flags = animation.HalfBodyFlag or 31
        else
            flags = animation.FullBodyFlag or animation.Flag or 0
        end
        TaskPlayAnim(ped, animation.Dict, animation.Body, 1.0, 1.0, -1, flags, 0, false, false, false, 0, true)
        RemoveAnimDict(animation.Dict)
    elseif isEmote then
        -- TASK_PLAY_EMOTE_WITH_HASH: playbackMode 0 = upper body, 2 = full body
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, 0, upper and 0 or 2, joaat(animation.EmoteType), upper, upper, false, false, false)
    else
        TaskStartScenarioInPlace(ped, joaat(animation.Scenario), -1, true, false, false, false)
    end

    RSGAnims.OnPlay(animation)
    return true
end

exports('PlayAnimation', playAnimationByName)
exports('StopAnimation', stopAnimation)

---------------------------------
-- menu
---------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game, so only runs while the menu is open
local function pttWhitelistLoop(session)
    if not Config.AllowPushToTalkWhileOpen then return end
    CreateThread(function()
        while isMenuOpen and session == menuSession do
            for group = 0, 2 do
                DisableAllControlActions(group)
                for _, control in ipairs(Config.PushToTalkControls) do
                    EnableControlAction(group, control, true)
                end
            end
            Wait(0)
        end
    end)
end

local function closeMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ type = 'Close' })
    PlaySoundFrontend('BACK', 'RDRO_Character_Creator_Sounds', true, 0)
end

local function loadFavorites()
    if favorites then return end
    local citizenid = (RSGCore.Functions.GetPlayerData() or {}).citizenid
    local list = RSGCore.Functions.AwaitCallback('rsg-animations:server:getFavorites', 5000)
    if type(list) ~= 'table' then return end -- timed out or failed: retry on the next open
    -- the character may have changed while waiting
    if (RSGCore.Functions.GetPlayerData() or {}).citizenid ~= citizenid then return end
    favorites = {}
    for _, label in ipairs(list) do favorites[label] = true end
end

local function canOpen()
    return not isRestrained(PlayerPedId())
end

-- close the menu if the player dies or is restrained while it is open
local function watchMenu(session)
    CreateThread(function()
        while isMenuOpen and session == menuSession do
            Wait(500)
            if isMenuOpen and session == menuSession and not canOpen() then closeMenu() end
        end
    end)
end

local function openMenu()
    if isMenuOpen or isOpening or not LocalPlayer.state.isLoggedIn then return end
    if not canOpen() then return notifyError(locale('err_cannot_animate')) end

    isOpening = true
    loadFavorites()
    isOpening = false
    if not LocalPlayer.state.isLoggedIn or not canOpen() then return end

    local list = {}
    for label in pairs(favorites or {}) do list[#list + 1] = label end

    local allowed = {}
    for _, item in ipairs(MenuAnimations) do
        if hasAccess(AnimationsByLabel[item.Label:lower()]) then allowed[#allowed + 1] = item end
    end

    local message = RSGAnims.MenuData()
    message.type = 'Open'
    message.Animations = allowed
    message.Favorites = list
    message.Locale = UILocale

    isMenuOpen = true
    menuSession = menuSession + 1
    SendNUIMessage(message)
    applyNuiFocus(true)
    pttWhitelistLoop(menuSession)
    watchMenu(menuSession)
    PlaySoundFrontend('BACK', 'RDRO_Character_Creator_Sounds', true, 0)
end

-- play and show why if it can't
local function tryPlay(name, bodyOption)
    local ok, err = playAnimationByName(name, bodyOption)
    if not ok and err then notifyError(err) end
    return ok
end

local function tryStop()
    if not stopAnimation() then notifyError(locale('err_cannot_animate')) end
end

RSGAnims.Core = RSGCore
RSGAnims.Play = tryPlay
RSGAnims.Stop = tryStop
RSGAnims.Open = openMenu
RSGAnims.Close = closeMenu
RSGAnims.Find = findAnimation
RSGAnims.HasAccess = hasAccess
RSGAnims.CanAnimate = canAnimate
RSGAnims.IsRestrained = isRestrained
RSGAnims.IsSeated = isSeated
RSGAnims.NotifyError = notifyError
RSGAnims.IsShared = function(label) return SharedSet[label] == true end

RegisterCommand(Config.CommandOpen, function() openMenu() end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.CommandOpen, locale('cmd_help'))

if Config.UseKeyMapping then
    local function notPaused() return not IsPauseMenuActive() end
    RSGCore.Functions.RegisterKey('rsganimations_open', locale('key_open'), Config.OpenKey, openMenu, nil, { canTrigger = notPaused })
    RSGCore.Functions.RegisterKey('rsganimations_stop', locale('key_stop'), Config.StopKey, stopAnimation, nil, { canTrigger = notPaused })
end

-- reset the favourites cache on character switch
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeMenu()
    favorites = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isMenuOpen then
        applyNuiFocus(false)
    end
end)

---------------------------------
-- nui callbacks
---------------------------------
RegisterNUICallback('Play', function(data, cb)
    cb('ok')
    if type(data) == 'table' and type(data.label) == 'string' then
        tryPlay(data.label, data.upper == true and 'upper' or 'full')
    end
end)

RegisterNUICallback('StopAnim', function(_, cb)
    cb('ok')
    tryStop()
end)

RegisterNUICallback('Close', function(_, cb)
    cb('ok')
    closeMenu()
end)

RegisterNUICallback('Favorite', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.label) ~= 'string' or not AnimationsByLabel[data.label:lower()] then return end

    local state = data.favorite == true
    if not favorites then -- never loaded: undo the star so the menu doesn't show unsaved state
        SendNUIMessage({ type = 'SetFavorite', label = data.label, favorite = not state })
        return
    end

    favorites[data.label] = state or nil
    TriggerServerEvent('rsg-animations:server:Favorite', data.label, state)
end)

-- server refused a favourite change (limit / rate limit): restore the real state
RegisterNetEvent('rsg-animations:client:syncFavorite', function(label, state)
    if type(label) ~= 'string' then return end
    if favorites then favorites[label] = state == true or nil end
    SendNUIMessage({ type = 'SetFavorite', label = label, favorite = state == true })
end)
