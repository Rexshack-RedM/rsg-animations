local RSGCore = exports['rsg-core']:GetCoreObject()

local MAX_FAVORITES = 100
local FAVORITE_COOLDOWN = 250 -- ms between favourite toggles per player

-- only labels that exist in the config may be stored
local ValidLabels = {}
for _, animation in ipairs(Config.Animations) do
    if animation.Label then ValidLabels[animation.Label] = true end
end

local lastToggle = {}

local function decodeFavorites(raw)
    local ok, list = pcall(json.decode, raw or '[]')
    if not ok or type(list) ~= 'table' then return {} end

    -- drop entries that no longer exist in the config
    local clean = {}
    for _, label in ipairs(list) do
        if ValidLabels[label] then clean[#clean + 1] = label end
    end
    return clean
end

local function getFavorites(citizenid)
    local raw = MySQL.scalar.await('SELECT favorites FROM favorites_animations WHERE citizenid = ? LIMIT 1', { citizenid })
    return decodeFavorites(raw), raw ~= nil
end

lib.callback.register('rsg-animations:server:getFavorites', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end

    return (getFavorites(Player.PlayerData.citizenid))
end)

RegisterNetEvent('rsg-animations:server:Favorite', function(label, favorite)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(label) ~= 'string' or not ValidLabels[label] then return end
    favorite = favorite == true

    local now = GetGameTimer()
    if lastToggle[src] and now - lastToggle[src] < FAVORITE_COOLDOWN then return end
    lastToggle[src] = now

    local citizenid = Player.PlayerData.citizenid
    local list, exists = getFavorites(citizenid)

    local index
    for i, v in ipairs(list) do
        if v == label then index = i break end
    end

    if favorite and not index then
        if #list >= MAX_FAVORITES then return end
        list[#list + 1] = label
    elseif not favorite and index then
        table.remove(list, index)
    end

    local encoded = json.encode(list)
    if exists then
        MySQL.update('UPDATE favorites_animations SET favorites = ? WHERE citizenid = ?', { encoded, citizenid })
    else
        MySQL.insert('INSERT INTO favorites_animations (citizenid, favorites) VALUES (?, ?)', { citizenid, encoded })
    end
end)

AddEventHandler('playerDropped', function()
    lastToggle[source] = nil
end)
