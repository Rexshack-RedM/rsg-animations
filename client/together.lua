-- shared animations: ask the closest player, they accept, both play
local RSGCore = RSGAnims.Core
local invite = nil -- the request waiting for an answer: { token }

function RSGAnims.HasInvite()
    return invite ~= nil
end

local function hidePrompt()
    invite = nil
    SendNUIMessage({ type = 'Invite', Text = '', Hint = '' })
end

-- closest visible player within the configured distance (invisible staff are never asked).
-- RSGCore.Functions.GetClosestPlayer only searches 5 metres, so the range is passed here
local function closestPlayer()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDistance
    for _, player in ipairs(RSGCore.Functions.GetPlayersFromCoords(coords, Config.Shared.Distance)) do
        local ped = GetPlayerPed(player)
        if player ~= PlayerId() and IsEntityVisible(ped) then
            local distance = #(GetEntityCoords(ped) - coords)
            if not bestDistance or distance < bestDistance then
                best, bestDistance = player, distance
            end
        end
    end
    return best
end

local function request(name)
    if not Config.Shared.Enabled or not LocalPlayer.state.isLoggedIn then return end

    local animation = RSGAnims.Find(name)
    if not animation or not RSGAnims.IsShared(animation.Label) then
        return RSGAnims.NotifyError(locale('err_not_shared'))
    end
    if not RSGAnims.HasAccess(animation) then return RSGAnims.NotifyError(locale('err_no_access')) end
    if not RSGAnims.CanAnimate(PlayerPedId()) then return RSGAnims.NotifyError(locale('err_cannot_animate')) end

    local player = closestPlayer()
    if not player then
        return RSGAnims.NotifyError(locale('err_no_player'))
    end

    TriggerServerEvent('rsg-animations:server:invite', GetPlayerServerId(player), animation.Label)
end

RegisterNUICallback('Invite', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    RSGAnims.Close()
    request(data.label)
end)

if Config.Shared.Enabled and Config.CommandWith ~= '' then
    RegisterCommand(Config.CommandWith, function(_, args) request(table.concat(args, ' ')) end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.CommandWith, locale('cmd_with_help'))
end

RegisterNetEvent('rsg-animations:client:invited', function(token, fromName, label)
    local animation = RSGAnims.Find(label)
    local accept = RSGCore.Shared.Keybinds[Config.Shared.AcceptKey]
    local decline = RSGCore.Shared.Keybinds[Config.Shared.DeclineKey]
    if not animation or not accept or not decline then return end

    local mine = { token = token }
    invite = mine
    SendNUIMessage({
        type = 'Invite',
        Text = locale('invite_text', tostring(fromName), animation.DisplayName),
        Hint = locale('invite_hint', Config.Shared.AcceptKey, Config.Shared.DeclineKey),
    })
    PlaySoundFrontend('BACK', 'RDRO_Character_Creator_Sounds', true, 0)

    CreateThread(function()
        local deadline = GetGameTimer() + Config.Shared.Timeout * 1000
        while invite == mine and GetGameTimer() < deadline do
            Wait(0)
            if not IsNuiFocused() and not IsPauseMenuActive() then
                local yes = IsControlJustPressed(0, accept)
                if yes or IsControlJustPressed(0, decline) then
                    if yes and not RSGAnims.CanAnimate(PlayerPedId()) then
                        RSGAnims.NotifyError(locale('err_cannot_animate'))
                        yes = false
                    end
                    TriggerServerEvent('rsg-animations:server:respond', mine.token, yes)
                    Wait(0) -- so the same key press doesn't also reach the cancel hint
                    break
                end
            end
        end
        if invite == mine then hidePrompt() end
    end)
end)

-- sent by the server to both players, only after the invite was accepted
RegisterNetEvent('rsg-animations:client:together', function(partnerId, label)
    local ped = PlayerPedId()
    if not RSGAnims.CanAnimate(ped) then return end

    local player = GetPlayerFromServerId(partnerId)
    if player == -1 then return end
    local partner = GetPlayerPed(player)
    if partner == 0 or not DoesEntityExist(partner) then return end

    if not RSGAnims.IsSeated(ped) then
        ClearPedTasks(ped)
        TaskTurnPedToFaceEntity(ped, partner, 1000)
        Wait(1100)
    end
    RSGAnims.Play(label) -- re-checks state, and job / gang access
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    hidePrompt()
end)
