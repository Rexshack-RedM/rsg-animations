local RSGCore = exports['rsg-core']:GetCoreObject()

local MAX_FAVORITES = 100
local FAVORITE_COOLDOWN = 100 -- ms between favourite writes per player

-- only labels that exist in the config may be stored
local ValidLabels = {}
for _, animation in ipairs(Config.Animations) do
    if animation.Label then ValidLabels[animation.Label] = true end
end

-- per-source cache: { citizenid, list, set, exists, last }
-- avoids a DB read on every toggle and the read-modify-write race between rapid toggles
local Cache = {}

local function decodeFavorites(raw)
    local ok, list = pcall(json.decode, raw or '[]')
    if not ok or type(list) ~= 'table' then return {} end

    -- drop entries that no longer exist in the config (and duplicates)
    local clean, seen = {}, {}
    for _, label in ipairs(list) do
        if ValidLabels[label] and not seen[label] and #clean < MAX_FAVORITES then
            seen[label] = true
            clean[#clean + 1] = label
        end
    end
    return clean
end

local function loadCache(src, citizenid)
    local entry = Cache[src]
    if entry and entry.citizenid == citizenid then return entry end

    local raw = MySQL.scalar.await('SELECT favorites FROM favorites_animations WHERE citizenid = ? LIMIT 1', { citizenid })
    local list = decodeFavorites(raw)
    local set = {}
    for _, label in ipairs(list) do set[label] = true end

    entry = { citizenid = citizenid, list = list, set = set, exists = raw ~= nil, last = 0 }
    Cache[src] = entry
    return entry
end

RSGCore.Functions.CreateCallback('rsg-animations:server:getFavorites', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    cb(loadCache(source, Player.PlayerData.citizenid).list)
end)

RegisterNetEvent('rsg-animations:server:Favorite', function(label, favorite)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(label) ~= 'string' or not ValidLabels[label] then return end
    favorite = favorite == true

    local entry = loadCache(src, Player.PlayerData.citizenid)
    if entry.set[label] == (favorite or nil) then return end -- no change

    local now = GetGameTimer()
    if now - entry.last < FAVORITE_COOLDOWN then
        TriggerClientEvent('rsg-animations:client:syncFavorite', src, label, entry.set[label] == true)
        return
    end
    entry.last = now

    if favorite then
        if #entry.list >= MAX_FAVORITES then
            TriggerClientEvent('rsg-animations:client:syncFavorite', src, label, false)
            TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('ui_title'), description = locale('err_max_favorites'):format(MAX_FAVORITES), type = 'error' })
            return
        end
        entry.list[#entry.list + 1] = label
        entry.set[label] = true
    else
        for i, v in ipairs(entry.list) do
            if v == label then table.remove(entry.list, i) break end
        end
        entry.set[label] = nil
    end

    local encoded = json.encode(entry.list)
    if entry.exists then
        MySQL.update('UPDATE favorites_animations SET favorites = ? WHERE citizenid = ?', { encoded, entry.citizenid })
    else
        entry.exists = true
        MySQL.insert('INSERT INTO favorites_animations (citizenid, favorites) VALUES (?, ?)', { entry.citizenid, encoded })
    end
end)

AddEventHandler('playerDropped', function()
    Cache[source] = nil
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    Cache[src] = nil
end)
