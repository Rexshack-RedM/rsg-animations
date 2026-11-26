-- shared animations: the server owns the invite, so nobody is sent an animation without accepting
local RSGCore = exports['rsg-core']:GetCoreObject()

local Pending = {}   -- [targetSrc] = { from, fromCid, targetCid, label, token, expires }
local Cooldowns = {} -- [src] = GetGameTimer() of the last request
local Unanswered = {} -- ['fromCid:targetCid'] = time before the same player may be asked again
local nextToken = 0

local SharedAnimations = {} -- [label] = animation config
for _, label in ipairs(Config.Shared.Animations) do
    for _, animation in ipairs(Config.Animations) do
        if animation.Label == label then SharedAnimations[label] = animation end
    end
    if not SharedAnimations[label] then
        print(('^3[rsg-animations]^7 Config.Shared.Animations: "%s" is not a label in Config.Animations'):format(tostring(label)))
    end
end

local function notify(src, key, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('ui_title'), description = locale(key), type = ntype or 'error' })
end

local function isRestrained(Player)
    local meta = Player.PlayerData.metadata or {}
    return meta.isdead or meta.inlaststand or meta.ishandcuffed or meta.isescorted
end

local function isNear(a, b)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA == 0 or pedB == 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= Config.Shared.Distance + 1.0 -- small sync allowance
end

RegisterNetEvent('rsg-animations:server:invite', function(targetId, label)
    local src = source
    if not Config.Shared.Enabled then return end
    if math.type(targetId) ~= 'integer' or targetId == src then return end
    if type(label) ~= 'string' or not SharedAnimations[label] then return end

    local now = GetGameTimer()
    if Cooldowns[src] and now - Cooldowns[src] < Config.Shared.Cooldown * 1000 then
        return notify(src, 'err_invite_wait')
    end
    Cooldowns[src] = now

    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Player or not Target or isRestrained(Player) then return end
    if not HasAnimationAccess(SharedAnimations[label], Player.PlayerData) then return notify(src, 'err_no_access') end
    if not isNear(src, targetId) then return notify(src, 'err_no_player') end
    if isRestrained(Target) or not HasAnimationAccess(SharedAnimations[label], Target.PlayerData)
        or (Pending[targetId] and Pending[targetId].expires > now) then
        return notify(src, 'err_partner_busy')
    end

    -- an ignored or declined request can't be repeated at the same player straight away
    local pair = Player.PlayerData.citizenid .. ':' .. Target.PlayerData.citizenid
    if Unanswered[pair] and Unanswered[pair] > now then return notify(src, 'err_partner_busy') end
    Unanswered[pair] = now + Config.Shared.DeclineCooldown * 1000

    nextToken = nextToken + 1
    Pending[targetId] = {
        from = src,
        fromCid = Player.PlayerData.citizenid,
        targetCid = Target.PlayerData.citizenid,
        label = label,
        token = nextToken,
        expires = now + Config.Shared.Timeout * 1000 + 1000,
    }

    local info = Player.PlayerData.charinfo
    TriggerClientEvent('rsg-animations:client:invited', targetId, nextToken, ('%s %s'):format(info.firstname, info.lastname), label)
    notify(src, 'invite_sent', 'inform')
end)

RegisterNetEvent('rsg-animations:server:respond', function(token, accepted)
    local src = source
    local entry = Pending[src]
    if not entry or entry.token ~= token then return end
    Pending[src] = nil

    local Player = RSGCore.Functions.GetPlayer(src)
    local From = RSGCore.Functions.GetPlayer(entry.from)
    if not Player or not From then return end
    -- either side may have switched character since the invite
    if Player.PlayerData.citizenid ~= entry.targetCid or From.PlayerData.citizenid ~= entry.fromCid then return end

    if accepted ~= true then return notify(entry.from, 'invite_declined') end
    Unanswered[entry.fromCid .. ':' .. entry.targetCid] = nil
    if GetGameTimer() > entry.expires or isRestrained(Player) or isRestrained(From) then
        return notify(entry.from, 'err_partner_busy')
    end
    if not isNear(src, entry.from) then
        notify(src, 'err_no_player')
        return notify(entry.from, 'err_no_player')
    end

    TriggerClientEvent('rsg-animations:client:together', src, entry.from, entry.label)
    TriggerClientEvent('rsg-animations:client:together', entry.from, src, entry.label)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Cooldowns[src] = nil
    Pending[src] = nil
    local now = GetGameTimer()
    for pair, expires in pairs(Unanswered) do
        if expires <= now then Unanswered[pair] = nil end
    end
    for target, entry in pairs(Pending) do
        if entry.from == src then Pending[target] = nil end
    end
end)
