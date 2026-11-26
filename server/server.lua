local RSGCore = exports['rsg-core']:GetCoreObject()

-- build the favorites table on start (Config.AutoDatabase); manual install: installation/rsg-animations.sql
MySQL.ready(function()
    if Config.AutoDatabase == false then return end
    local ok, err = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `favorites_animations` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `favorites` longtext NOT NULL DEFAULT ('[]'),
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    if ok then
        print('^2[rsg-animations]^7 database tables ready')
    else
        print(('^1[rsg-animations]^7 failed to create database table, import installation/rsg-animations.sql manually: %s'):format(tostring(err)))
    end
end)

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
local Loading = {}

local function decodeFavorites(raw)
    local ok, list = pcall(json.decode, raw or '[]')
    if not ok or type(list) ~= 'table' then return {} end

    -- redirect removed duplicates, drop unknown entries and duplicates
    local clean, seen = {}, {}
    for _, label in ipairs(list) do
        label = Config.LabelAliases[label] or label
        if ValidLabels[label] and not seen[label] and #clean < MAX_FAVORITES then
            seen[label] = true
            clean[#clean + 1] = label
        end
    end
    return clean
end

-- returns nil if the database read failed or the character changed while it ran
local function loadCache(src, citizenid)
    -- only one read per player at a time, so two events can't build two caches (and insert two rows)
    while Loading[src] do Wait(0) end

    local entry = Cache[src]
    if entry and entry.citizenid == citizenid then return entry end

    Loading[src] = true
    local ok, raw = pcall(MySQL.scalar.await, 'SELECT favorites FROM favorites_animations WHERE citizenid = ? LIMIT 1', { citizenid })
    Loading[src] = nil

    if not ok then
        print(('^1[rsg-animations]^7 failed to load favourites: %s'):format(tostring(raw)))
        return nil
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.citizenid ~= citizenid then return nil end

    local list = decodeFavorites(raw)
    local set = {}
    for _, label in ipairs(list) do set[label] = true end

    entry = { citizenid = citizenid, list = list, set = set, exists = raw ~= nil, last = 0 }
    Cache[src] = entry
    return entry
end

-- one write at a time per character, in order. Changes made during a write are saved by the next pass,
-- and a failed INSERT is retried as an INSERT on the next change
local function saveFavorites(entry)
    entry.dirty = true
    if entry.saving then return end
    entry.saving = true

    CreateThread(function()
        while entry.dirty do
            entry.dirty = false
            local encoded = json.encode(entry.list)
            local ok, err
            if entry.exists then
                ok, err = pcall(MySQL.update.await, 'UPDATE favorites_animations SET favorites = ? WHERE citizenid = ?', { encoded, entry.citizenid })
            else
                ok, err = pcall(MySQL.insert.await, 'INSERT INTO favorites_animations (citizenid, favorites) VALUES (?, ?)', { entry.citizenid, encoded })
                if ok then entry.exists = true end
            end
            if not ok then print(('^1[rsg-animations]^7 failed to save favourites: %s'):format(tostring(err))) end
        end
        entry.saving = false
    end)
end

RSGCore.Functions.CreateCallback('rsg-animations:server:getFavorites', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end -- false = try again next time

    local entry = loadCache(source, Player.PlayerData.citizenid)
    cb(entry and entry.list or false)
end)

RegisterNetEvent('rsg-animations:server:Favorite', function(label, favorite)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(label) ~= 'string' or not ValidLabels[label] then return end
    favorite = favorite == true

    local entry = loadCache(src, Player.PlayerData.citizenid)
    if not entry then
        TriggerClientEvent('rsg-animations:client:syncFavorite', src, label, not favorite)
        return
    end
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
            TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('ui_title'), description = locale('err_max_favorites', MAX_FAVORITES), type = 'error' })
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

    saveFavorites(entry)
end)

AddEventHandler('playerDropped', function()
    Cache[source] = nil
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    Cache[src] = nil
end)
