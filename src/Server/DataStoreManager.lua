--[[
    DataStoreManager.lua
    Server-side DataStore management with retry logic, auto-save,
    anti-exploit validation, and data versioning.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DataStoreManager = {}

local DATA_STORE_NAME = "PlayerData_v1"
local DATA_STORE_KEY_PREFIX = "Player_"
local MAX_RETRIES = 3
local AUTO_SAVE_INTERVAL = 300
local CURRENT_DATA_VERSION = 1
local MAX_COINS = 1e12
local MAX_LEVEL = 1000
local MAX_EXPERIENCE = 1e9
local MAX_INVENTORY_SIZE = 500
local MAX_CREATURES = 200

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

-- In-memory cache of loaded player data keyed by UserId
local playerDataCache = {}

local DEFAULT_DATA = {
    Version = 1,
    Coins = 500,
    Level = 1,
    Experience = 0,
    TotalWins = 0,
    TotalBets = 0,
    DailyLoginStreak = 0,
    LastLoginDate = "",
    Creatures = {},
    Inventory = {},
    EquippedItems = {},
    TradeHistory = {},
    Settings = {
        MusicVolume = 0.5,
        SFXVolume = 0.7,
    },
    Statistics = {
        MonkeyFightsWon = 0,
        CamelRacesWon = 0,
        LobsterRacesWon = 0,
        TotalCoinsEarned = 0,
        TotalCoinsSpent = 0,
        TradesCompleted = 0,
    },
}

--------------------------------------------------------------------------------
-- Utility helpers
--------------------------------------------------------------------------------

local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[deepCopy(key)] = deepCopy(value)
    end
    return copy
end

local function getDataStoreKey(player)
    return DATA_STORE_KEY_PREFIX .. tostring(player.UserId)
end

--- Retry wrapper with exponential back-off for DataStore calls.
local function retryAsync(operationName, callback)
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(callback)
        if success then
            return true, result
        end
        print(string.format(
            "[DataStoreManager] %s failed (attempt %d/%d): %s",
            operationName, attempt, MAX_RETRIES, tostring(result)
        ))
        if attempt < MAX_RETRIES then
            local backoff = math.pow(2, attempt - 1)
            task.wait(backoff)
        end
    end
    return false, nil
end

--------------------------------------------------------------------------------
-- Validation helpers
--------------------------------------------------------------------------------

local function isValidPlayer(player)
    return typeof(player) == "Instance"
        and player:IsA("Player")
        and player:IsDescendantOf(Players)
end

local function clampNumber(value, min, max)
    if type(value) ~= "number" then
        return min
    end
    return math.clamp(math.floor(value), min, max)
end

--- Ensure a loaded table has every key from the default template.
local function reconcileData(data)
    if type(data) ~= "table" then
        return deepCopy(DEFAULT_DATA)
    end

    local reconciled = deepCopy(DEFAULT_DATA)

    for key, defaultValue in pairs(DEFAULT_DATA) do
        if data[key] ~= nil then
            if type(defaultValue) == "table" then
                if type(data[key]) == "table" then
                    -- Shallow-merge sub-tables (Settings, Statistics)
                    if key == "Settings" or key == "Statistics" then
                        for subKey, subDefault in pairs(defaultValue) do
                            if data[key][subKey] ~= nil and type(data[key][subKey]) == type(subDefault) then
                                reconciled[key][subKey] = data[key][subKey]
                            end
                        end
                    else
                        reconciled[key] = data[key]
                    end
                end
            elseif type(data[key]) == type(defaultValue) then
                reconciled[key] = data[key]
            end
        end
    end

    return reconciled
end

--- Sanitise and clamp numeric fields to prevent impossible values.
local function sanitizeData(data)
    data.Coins = clampNumber(data.Coins, 0, MAX_COINS)
    data.Level = clampNumber(data.Level, 1, MAX_LEVEL)
    data.Experience = clampNumber(data.Experience, 0, MAX_EXPERIENCE)
    data.TotalWins = clampNumber(data.TotalWins, 0, 1e9)
    data.TotalBets = clampNumber(data.TotalBets, 0, 1e9)
    data.DailyLoginStreak = clampNumber(data.DailyLoginStreak, 0, 3650)

    if type(data.Creatures) ~= "table" then
        data.Creatures = {}
    end
    if #data.Creatures > MAX_CREATURES then
        print("[DataStoreManager] Creature list exceeds max; truncating.")
        local trimmed = {}
        for i = 1, MAX_CREATURES do
            trimmed[i] = data.Creatures[i]
        end
        data.Creatures = trimmed
    end

    if type(data.Inventory) ~= "table" then
        data.Inventory = {}
    end
    if #data.Inventory > MAX_INVENTORY_SIZE then
        print("[DataStoreManager] Inventory exceeds max; truncating.")
        local trimmed = {}
        for i = 1, MAX_INVENTORY_SIZE do
            trimmed[i] = data.Inventory[i]
        end
        data.Inventory = trimmed
    end

    if type(data.EquippedItems) ~= "table" then
        data.EquippedItems = {}
    end
    if type(data.TradeHistory) ~= "table" then
        data.TradeHistory = {}
    end

    -- Sanitise statistics
    if type(data.Statistics) == "table" then
        for statKey, _ in pairs(DEFAULT_DATA.Statistics) do
            data.Statistics[statKey] = clampNumber(data.Statistics[statKey], 0, 1e12)
        end
    else
        data.Statistics = deepCopy(DEFAULT_DATA.Statistics)
    end

    -- Sanitise settings
    if type(data.Settings) == "table" then
        data.Settings.MusicVolume = math.clamp(tonumber(data.Settings.MusicVolume) or 0.5, 0, 1)
        data.Settings.SFXVolume = math.clamp(tonumber(data.Settings.SFXVolume) or 0.7, 0, 1)
    else
        data.Settings = deepCopy(DEFAULT_DATA.Settings)
    end

    data.Version = CURRENT_DATA_VERSION
    return data
end

--------------------------------------------------------------------------------
-- Data migration
--------------------------------------------------------------------------------

local function migrateData(data)
    if type(data) ~= "table" then
        return deepCopy(DEFAULT_DATA)
    end

    local version = data.Version or 0

    -- Example: migrate from version 0 (legacy) to version 1
    if version < 1 then
        print("[DataStoreManager] Migrating data from version " .. tostring(version) .. " to 1")
        data.TradeHistory = data.TradeHistory or {}
        data.Settings = data.Settings or deepCopy(DEFAULT_DATA.Settings)
        data.Statistics = data.Statistics or deepCopy(DEFAULT_DATA.Statistics)
        data.EquippedItems = data.EquippedItems or {}
        data.DailyLoginStreak = data.DailyLoginStreak or 0
        data.LastLoginDate = data.LastLoginDate or ""
        data.Version = 1
    end

    -- Future migrations go here:
    -- if version < 2 then ... end

    return data
end

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

--- Load player data from DataStore, reconcile, sanitize, and cache it.
function DataStoreManager.LoadPlayerData(player)
    if not isValidPlayer(player) then
        print("[DataStoreManager] LoadPlayerData called with invalid player.")
        return nil
    end

    local key = getDataStoreKey(player)
    print(string.format("[DataStoreManager] Loading data for %s (%d)…", player.Name, player.UserId))

    local success, data = retryAsync("GetAsync:" .. key, function()
        return dataStore:GetAsync(key)
    end)

    if not success then
        print(string.format(
            "[DataStoreManager] CRITICAL – Failed to load data for %s after %d retries. Using defaults.",
            player.Name, MAX_RETRIES
        ))
        data = nil
    end

    if data == nil then
        data = deepCopy(DEFAULT_DATA)
        print(string.format("[DataStoreManager] No existing data for %s; initialised defaults.", player.Name))
    else
        data = migrateData(data)
        data = reconcileData(data)
    end

    data = sanitizeData(data)

    -- Daily login tracking
    local today = os.date("!%Y-%m-%d")
    if data.LastLoginDate ~= today then
        if data.LastLoginDate == os.date("!%Y-%m-%d", os.time() - 86400) then
            data.DailyLoginStreak = data.DailyLoginStreak + 1
        else
            data.DailyLoginStreak = 1
        end
        data.LastLoginDate = today
    end

    playerDataCache[player.UserId] = data
    print(string.format(
        "[DataStoreManager] Data loaded for %s – Coins: %d, Level: %d",
        player.Name, data.Coins, data.Level
    ))
    return data
end

--- Persist cached player data to DataStore.
function DataStoreManager.SavePlayerData(player)
    if not isValidPlayer(player) then
        -- Player may have left; try saving from cache by UserId
        if typeof(player) == "Instance" and player:IsA("Player") then
            -- still okay, continue
        else
            print("[DataStoreManager] SavePlayerData called with invalid player.")
            return false
        end
    end

    local userId = player.UserId
    local data = playerDataCache[userId]
    if not data then
        print(string.format("[DataStoreManager] No cached data to save for UserId %d.", userId))
        return false
    end

    data = sanitizeData(data)

    local key = getDataStoreKey(player)
    local success, _ = retryAsync("SetAsync:" .. key, function()
        dataStore:SetAsync(key, data)
    end)

    if success then
        print(string.format("[DataStoreManager] Data saved for %s (%d).", player.Name, userId))
    else
        print(string.format(
            "[DataStoreManager] CRITICAL – Failed to save data for %s (%d) after %d retries!",
            player.Name, userId, MAX_RETRIES
        ))
    end

    return success
end

--- Return the in-memory cached data for a player (read-only copy).
function DataStoreManager.GetPlayerData(player)
    if not isValidPlayer(player) then
        return nil
    end
    local data = playerDataCache[player.UserId]
    if data then
        return deepCopy(data)
    end
    return nil
end

--- Update a single top-level key on the cached player data with validation.
function DataStoreManager.UpdatePlayerData(player, key, value)
    if not isValidPlayer(player) then
        print("[DataStoreManager] UpdatePlayerData: invalid player.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] UpdatePlayerData: no data loaded for " .. player.Name)
        return false
    end

    -- Only allow updating keys that exist in the default template
    if DEFAULT_DATA[key] == nil then
        print(string.format(
            "[DataStoreManager] UpdatePlayerData: rejected unknown key '%s' for %s.",
            tostring(key), player.Name
        ))
        return false
    end

    -- Type must match default (tables may be replaced wholesale)
    if type(value) ~= type(DEFAULT_DATA[key]) then
        print(string.format(
            "[DataStoreManager] UpdatePlayerData: type mismatch for key '%s' (expected %s, got %s).",
            tostring(key), type(DEFAULT_DATA[key]), type(value)
        ))
        return false
    end

    -- Prevent direct writes to protected numeric fields via this generic setter
    local protectedKeys = { Coins = true, Level = true, Experience = true }
    if protectedKeys[key] then
        print(string.format(
            "[DataStoreManager] UpdatePlayerData: key '%s' is protected; use dedicated API.",
            key
        ))
        return false
    end

    data[key] = value
    print(string.format("[DataStoreManager] Updated '%s' for %s.", key, player.Name))
    return true
end

--------------------------------------------------------------------------------
-- Coin operations (server-validated)
--------------------------------------------------------------------------------

function DataStoreManager.AddCoins(player, amount)
    if not isValidPlayer(player) then
        return false
    end
    if type(amount) ~= "number" or amount ~= amount then -- NaN check
        print("[DataStoreManager] AddCoins: invalid amount.")
        return false
    end
    amount = math.floor(amount)
    if amount <= 0 then
        print("[DataStoreManager] AddCoins: amount must be positive.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] AddCoins: no data for " .. player.Name)
        return false
    end

    local newCoins = data.Coins + amount
    if newCoins > MAX_COINS then
        print(string.format(
            "[DataStoreManager] AddCoins: would exceed cap for %s (%d + %d > %d).",
            player.Name, data.Coins, amount, MAX_COINS
        ))
        newCoins = MAX_COINS
    end

    data.Coins = newCoins
    data.Statistics.TotalCoinsEarned = math.min(
        (data.Statistics.TotalCoinsEarned or 0) + amount, 1e12
    )

    print(string.format(
        "[DataStoreManager] Added %d coins to %s (total: %d).",
        amount, player.Name, data.Coins
    ))
    return true
end

function DataStoreManager.RemoveCoins(player, amount)
    if not isValidPlayer(player) then
        return false
    end
    if type(amount) ~= "number" or amount ~= amount then
        print("[DataStoreManager] RemoveCoins: invalid amount.")
        return false
    end
    amount = math.floor(amount)
    if amount <= 0 then
        print("[DataStoreManager] RemoveCoins: amount must be positive.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] RemoveCoins: no data for " .. player.Name)
        return false
    end

    if data.Coins < amount then
        print(string.format(
            "[DataStoreManager] RemoveCoins: %s has insufficient coins (%d < %d).",
            player.Name, data.Coins, amount
        ))
        return false
    end

    data.Coins = data.Coins - amount
    data.Statistics.TotalCoinsSpent = math.min(
        (data.Statistics.TotalCoinsSpent or 0) + amount, 1e12
    )

    print(string.format(
        "[DataStoreManager] Removed %d coins from %s (remaining: %d).",
        amount, player.Name, data.Coins
    ))
    return true
end

--------------------------------------------------------------------------------
-- Creature operations
--------------------------------------------------------------------------------

local function isValidCreatureData(creatureData)
    if type(creatureData) ~= "table" then
        return false
    end
    if type(creatureData.Id) ~= "string" or #creatureData.Id == 0 then
        return false
    end
    if type(creatureData.Type) ~= "string" then
        return false
    end
    local validTypes = { Monkey = true, Camel = true, Lobster = true }
    if not validTypes[creatureData.Type] then
        return false
    end
    if type(creatureData.Name) ~= "string" or #creatureData.Name == 0 or #creatureData.Name > 50 then
        return false
    end
    return true
end

function DataStoreManager.AddCreature(player, creatureData)
    if not isValidPlayer(player) then
        return false
    end
    if not isValidCreatureData(creatureData) then
        print("[DataStoreManager] AddCreature: invalid creature data.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] AddCreature: no data for " .. player.Name)
        return false
    end

    if #data.Creatures >= MAX_CREATURES then
        print(string.format(
            "[DataStoreManager] AddCreature: %s at creature cap (%d).",
            player.Name, MAX_CREATURES
        ))
        return false
    end

    -- Prevent duplicate IDs
    for _, existing in ipairs(data.Creatures) do
        if existing.Id == creatureData.Id then
            print(string.format(
                "[DataStoreManager] AddCreature: duplicate Id '%s' for %s.",
                creatureData.Id, player.Name
            ))
            return false
        end
    end

    table.insert(data.Creatures, {
        Id = creatureData.Id,
        Type = creatureData.Type,
        Name = creatureData.Name,
        Level = clampNumber(creatureData.Level or 1, 1, MAX_LEVEL),
        Experience = clampNumber(creatureData.Experience or 0, 0, MAX_EXPERIENCE),
        Wins = clampNumber(creatureData.Wins or 0, 0, 1e9),
        AcquiredDate = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })

    print(string.format(
        "[DataStoreManager] Added creature '%s' (%s) for %s.",
        creatureData.Name, creatureData.Type, player.Name
    ))
    return true
end

function DataStoreManager.RemoveCreature(player, creatureId)
    if not isValidPlayer(player) then
        return false
    end
    if type(creatureId) ~= "string" or #creatureId == 0 then
        print("[DataStoreManager] RemoveCreature: invalid creatureId.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] RemoveCreature: no data for " .. player.Name)
        return false
    end

    for i, creature in ipairs(data.Creatures) do
        if creature.Id == creatureId then
            table.remove(data.Creatures, i)
            -- Also unequip if equipped
            if data.EquippedItems then
                for j = #data.EquippedItems, 1, -1 do
                    if data.EquippedItems[j] == creatureId then
                        table.remove(data.EquippedItems, j)
                    end
                end
            end
            print(string.format(
                "[DataStoreManager] Removed creature '%s' from %s.",
                creatureId, player.Name
            ))
            return true
        end
    end

    print(string.format(
        "[DataStoreManager] RemoveCreature: creature '%s' not found for %s.",
        creatureId, player.Name
    ))
    return false
end

--------------------------------------------------------------------------------
-- Inventory operations
--------------------------------------------------------------------------------

local function isValidItemData(itemData)
    if type(itemData) ~= "table" then
        return false
    end
    if type(itemData.Id) ~= "string" or #itemData.Id == 0 then
        return false
    end
    if type(itemData.Name) ~= "string" or #itemData.Name == 0 or #itemData.Name > 100 then
        return false
    end
    if type(itemData.Type) ~= "string" or #itemData.Type == 0 then
        return false
    end
    return true
end

function DataStoreManager.AddInventoryItem(player, itemData)
    if not isValidPlayer(player) then
        return false
    end
    if not isValidItemData(itemData) then
        print("[DataStoreManager] AddInventoryItem: invalid item data.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] AddInventoryItem: no data for " .. player.Name)
        return false
    end

    if #data.Inventory >= MAX_INVENTORY_SIZE then
        print(string.format(
            "[DataStoreManager] AddInventoryItem: %s at inventory cap (%d).",
            player.Name, MAX_INVENTORY_SIZE
        ))
        return false
    end

    -- Prevent duplicate IDs
    for _, existing in ipairs(data.Inventory) do
        if existing.Id == itemData.Id then
            print(string.format(
                "[DataStoreManager] AddInventoryItem: duplicate Id '%s' for %s.",
                itemData.Id, player.Name
            ))
            return false
        end
    end

    table.insert(data.Inventory, {
        Id = itemData.Id,
        Name = itemData.Name,
        Type = itemData.Type,
        Quantity = clampNumber(itemData.Quantity or 1, 1, 9999),
        AcquiredDate = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })

    print(string.format(
        "[DataStoreManager] Added item '%s' to %s's inventory.",
        itemData.Name, player.Name
    ))
    return true
end

function DataStoreManager.RemoveInventoryItem(player, itemId)
    if not isValidPlayer(player) then
        return false
    end
    if type(itemId) ~= "string" or #itemId == 0 then
        print("[DataStoreManager] RemoveInventoryItem: invalid itemId.")
        return false
    end

    local data = playerDataCache[player.UserId]
    if not data then
        print("[DataStoreManager] RemoveInventoryItem: no data for " .. player.Name)
        return false
    end

    for i, item in ipairs(data.Inventory) do
        if item.Id == itemId then
            table.remove(data.Inventory, i)
            -- Also unequip if equipped
            if data.EquippedItems then
                for j = #data.EquippedItems, 1, -1 do
                    if data.EquippedItems[j] == itemId then
                        table.remove(data.EquippedItems, j)
                    end
                end
            end
            print(string.format(
                "[DataStoreManager] Removed item '%s' from %s's inventory.",
                itemId, player.Name
            ))
            return true
        end
    end

    print(string.format(
        "[DataStoreManager] RemoveInventoryItem: item '%s' not found for %s.",
        itemId, player.Name
    ))
    return false
end

--------------------------------------------------------------------------------
-- Auto-save loop
--------------------------------------------------------------------------------

function DataStoreManager.AutoSaveLoop()
    print("[DataStoreManager] Auto-save loop started (interval: " .. AUTO_SAVE_INTERVAL .. "s).")
    while true do
        task.wait(AUTO_SAVE_INTERVAL)
        print("[DataStoreManager] Auto-save triggered.")
        for _, player in ipairs(Players:GetPlayers()) do
            if playerDataCache[player.UserId] then
                local ok, err = pcall(function()
                    DataStoreManager.SavePlayerData(player)
                end)
                if not ok then
                    print(string.format(
                        "[DataStoreManager] Auto-save error for %s: %s",
                        player.Name, tostring(err)
                    ))
                end
            end
        end
        print("[DataStoreManager] Auto-save cycle complete.")
    end
end

--------------------------------------------------------------------------------
-- Player lifecycle bindings
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
    DataStoreManager.LoadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    DataStoreManager.SavePlayerData(player)
    -- Clear cache after save so memory is freed
    playerDataCache[player.UserId] = nil
end)

-- Save all players on server shutdown
game:BindToClose(function()
    print("[DataStoreManager] Server shutting down – saving all player data…")
    for _, player in ipairs(Players:GetPlayers()) do
        if playerDataCache[player.UserId] then
            local ok, err = pcall(function()
                DataStoreManager.SavePlayerData(player)
            end)
            if not ok then
                print(string.format(
                    "[DataStoreManager] Shutdown save error for %s: %s",
                    player.Name, tostring(err)
                ))
            end
        end
    end
    print("[DataStoreManager] Shutdown save complete.")
end)

-- Kick off auto-save in a background thread
task.spawn(DataStoreManager.AutoSaveLoop)

return DataStoreManager
