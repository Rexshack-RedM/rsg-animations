-- quick slots, recent, now playing + cancel hint, walk styles, /e and rsg-radialmenu entries
local RSGCore = RSGAnims.Core
local SLOTS = math.max(1, math.min(8, math.floor(Config.QuickSlots)))
local RADIAL_ID = 'rsg-animations'

local store = nil -- { citizenid, slots = { ['1'] = label }, recent = { label } }
local playing = nil

---------------------------------
-- per-character storage (client KVP: a per-player convenience)
---------------------------------
local function getStore()
    local data = RSGCore.Functions.GetPlayerData()
    local citizenid = data and data.citizenid
    if not citizenid then return nil end
    if store and store.citizenid == citizenid then return store end

    local ok, decoded = pcall(json.decode, GetResourceKvpString('data_' .. citizenid) or '{}')
    if not ok or type(decoded) ~= 'table' then decoded = {} end

    store = {
        citizenid = citizenid,
        slots = type(decoded.slots) == 'table' and decoded.slots or {},
        recent = type(decoded.recent) == 'table' and decoded.recent or {},
    }
    return store
end

local function saveStore()
    if not store then return end
    -- string keys keep json from turning a sparse slot table into an array
    SetResourceKvp('data_' .. store.citizenid, json.encode({ slots = store.slots, recent = store.recent }))
end

-- array of SLOTS entries, '' = empty
local function slotList()
    local data, list = getStore(), {}
    for i = 1, SLOTS do
        local animation = data and RSGAnims.Find(data.slots[tostring(i)])
        list[i] = animation and animation.Label or ''
    end
    return list
end

local function addRecent(label)
    local data = getStore()
    if not data then return end
    for i = #data.recent, 1, -1 do
        if data.recent[i] == label then table.remove(data.recent, i) end
    end
    table.insert(data.recent, 1, label)
    while #data.recent > Config.RecentLimit do table.remove(data.recent) end
    saveStore()
    SendNUIMessage({ type = 'Recent', Recent = data.recent })
end

---------------------------------
-- now playing + cancel hint
---------------------------------
local cancelControl = RSGCore.Shared.Keybinds[Config.CancelKey]
if Config.ShowCancelHint and not cancelControl then
    print(('^1[rsg-animations]^7 Config.CancelKey "%s" is not in RSGCore.Shared.Keybinds, the cancel hint is disabled'):format(tostring(Config.CancelKey)))
end

local function clearPlaying()
    if not playing then return end
    playing = nil
    SendNUIMessage({ type = 'NowPlaying', Name = '', Hint = '' })
end

local function hasFinished(entry, ped)
    local age = GetGameTimer() - entry.started
    local animation = entry.animation
    if animation.Type == 'Anim' then
        return age > 1500 and not IsEntityPlayingAnim(ped, animation.Dict, animation.Body, 3)
    elseif animation.Type == 'Scenario' then
        return age > 5000 and not IsPedUsingAnyScenario(ped)
    end
    return age > Config.EmoteHintSeconds * 1000
end

function RSGAnims.OnPlay(animation)
    local entry = { animation = animation, started = GetGameTimer() }
    playing = entry
    addRecent(animation.Label)

    local showHint = Config.ShowCancelHint and cancelControl ~= nil
    SendNUIMessage({
        type = 'NowPlaying',
        Name = animation.DisplayName,
        Hint = showHint and locale('hint_cancel', Config.CancelKey) or '',
    })

    -- only runs while this animation is playing
    CreateThread(function()
        local nextCheck = 0
        while playing == entry do
            -- a pending shared request owns the keys until it is answered
            if showHint and IsControlJustPressed(0, cancelControl)
                and not RSGAnims.HasInvite() and not IsNuiFocused() and not IsPauseMenuActive() then
                RSGAnims.Stop()
            end
            local now = GetGameTimer()
            if now >= nextCheck and playing == entry then
                nextCheck = now + 500
                local ped = PlayerPedId()
                if RSGAnims.IsRestrained(ped) or hasFinished(entry, ped) then clearPlaying() end
            end
            Wait(showHint and 0 or 500)
        end
    end)
end

function RSGAnims.OnStop()
    clearPlaying()
end

---------------------------------
-- walk styles (rsg-radialmenu)
---------------------------------
local function radialRunning()
    return GetResourceState('rsg-radialmenu') == 'started'
end

local function walkList()
    local list = {}
    if not radialRunning() then return list end
    for _, key in ipairs(Config.Walkstyles) do
        list[#list + 1] = { key = key, label = locale('walk_' .. key) }
    end
    return list
end

local lastWalk = -10000

RegisterNUICallback('Walk', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or not radialRunning() then return end
    if RSGAnims.IsRestrained(PlayerPedId()) then return RSGAnims.NotifyError(locale('err_cannot_animate')) end

    for _, key in ipairs(Config.Walkstyles) do
        if key == data.key then
            -- rsg-radialmenu silently ignores changes inside its cooldown, so match it here
            local now = GetGameTimer()
            if now - lastWalk < 2100 then return RSGAnims.NotifyError(locale('err_walk_wait')) end
            lastWalk = now
            TriggerEvent('rsg-radialmenu:client:setWalkstyle', key)
            SendNUIMessage({ type = 'Walk', Current = key })
            return
        end
    end
end)

function RSGAnims.MenuData()
    local data = getStore()
    return {
        Slots = slotList(),
        Recent = data and data.recent or {},
        Walkstyles = walkList(),
        CurrentWalk = LocalPlayer.state.walkstyle or 'normal',
    }
end

---------------------------------
-- quick slots
---------------------------------
local function playSlot(slot)
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > SLOTS or not LocalPlayer.state.isLoggedIn then return end
    local label = slotList()[slot]
    if label == '' then return RSGAnims.NotifyError(locale('err_slot_empty', slot)) end
    RSGAnims.Play(label)
end

---------------------------------
-- rsg-radialmenu entries
---------------------------------
local function removeRadial()
    if Config.RadialMenu and radialRunning() then
        exports['rsg-radialmenu']:RemoveOption(RADIAL_ID)
    end
end

local function refreshRadial()
    if not Config.RadialMenu or not radialRunning() or not LocalPlayer.state.isLoggedIn then return end

    local items = {
        { id = 'anim_open', title = locale('radial_open'), icon = 'list', type = 'client', event = 'rsg-animations:client:radialOpen', shouldClose = true },
        { id = 'anim_stop', title = locale('ui_stop_animation'), icon = 'stop', type = 'client', event = 'rsg-animations:client:radialStop', shouldClose = true },
    }
    for slot, label in ipairs(slotList()) do
        if label ~= '' then
            items[#items + 1] = {
                id = 'anim_slot' .. slot, title = RSGAnims.Find(label).DisplayName, icon = 'person', slot = slot,
                type = 'client', event = 'rsg-animations:client:radialSlot', shouldClose = true,
            }
        end
    end

    exports['rsg-radialmenu']:AddOption({ id = 'animations', title = locale('ui_title'), icon = 'masks-theater', items = items }, RADIAL_ID)
end

AddEventHandler('rsg-animations:client:radialOpen', function()
    SetTimeout(200, RSGAnims.Open) -- let the radial menu release focus first
end)
AddEventHandler('rsg-animations:client:radialStop', function() RSGAnims.Stop() end)
AddEventHandler('rsg-animations:client:radialSlot', function(item)
    if type(item) == 'table' then playSlot(item.slot) end
end)

RegisterNUICallback('SetSlot', function(data, cb)
    cb('ok')
    local saved = getStore()
    if not saved or type(data) ~= 'table' then return end
    local slot = math.floor(tonumber(data.slot) or 0)
    if slot < 1 or slot > SLOTS then return end

    local animation = RSGAnims.Find(data.label) -- nil clears the slot
    saved.slots[tostring(slot)] = animation and animation.Label or nil
    saveStore()
    refreshRadial()
    SendNUIMessage({ type = 'Slots', Slots = slotList() })
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'rsg-radialmenu' or resource == GetCurrentResourceName() then
        SetTimeout(1000, refreshRadial)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    SetTimeout(1000, refreshRadial)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    clearPlaying()
    store = nil
    removeRadial()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then removeRadial() end
end)

---------------------------------
-- commands and keys
---------------------------------
if Config.CommandPlay ~= '' then
    RegisterCommand(Config.CommandPlay, function(_, args)
        if not LocalPlayer.state.isLoggedIn then return end
        if #args == 0 then return RSGAnims.Open() end

        local upper = false
        if #args > 1 and args[#args]:lower() == 'upper' then
            upper = true
            args[#args] = nil
        end

        local name = table.concat(args, ' ')
        if name:lower() == 'stop' then return RSGAnims.Stop() end
        RSGAnims.Play(name, upper and 'upper' or 'full')
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.CommandPlay, locale('cmd_play_help'))
end

RegisterCommand(Config.CommandSlot, function(_, args) playSlot(args[1]) end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.CommandSlot, locale('cmd_slot_help'))

if Config.UseKeyMapping then
    for slot = 1, SLOTS do
        RSGCore.Functions.RegisterKey('rsganimations_slot' .. slot, locale('key_slot', slot), '', function() playSlot(slot) end, nil, {
            canTrigger = function() return not IsPauseMenuActive() end,
        })
    end
end
