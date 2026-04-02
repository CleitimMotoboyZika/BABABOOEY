--[[
    TradeSystem.lua
    Server-side player-to-player trading system with full validation and anti-exploit measures.

    Trade Flow:
        1. Player A sends trade request to Player B
        2. Player B accepts or declines
        3. Both players add/remove items and set coin offers
        4. Both players confirm ("Ready")
        5. Server validates ownership, balances, and limits
        6. Items and coins transferred atomically
        7. Trade logged to both players' TradeHistory

    Public API:
        TradeSystem.Initialize()                          -- Set up RemoteEvents and listeners
        TradeSystem.RequestTrade(fromPlayer, toPlayer)    -- Send trade request
        TradeSystem.AcceptTrade(player)                   -- Accept incoming request
        TradeSystem.DeclineTrade(player)                  -- Decline incoming request
        TradeSystem.AddItemToTrade(player, itemId, itemType) -- Add creature or equipment
        TradeSystem.RemoveItemFromTrade(player, itemId)   -- Remove item from offer
        TradeSystem.SetTradeCoins(player, amount)         -- Set coin offer
        TradeSystem.ConfirmTrade(player)                  -- Mark ready / confirm
        TradeSystem.CancelTrade(player)                   -- Cancel active trade
        TradeSystem.GetActiveTrade(player)                -- Get read-only trade state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local DataStoreManager = require(script.Parent.DataStoreManager)

local TradeSystem = {}

-- ============================================================================
-- Constants
-- ============================================================================

local TRADE_COOLDOWN = 30              -- seconds between trades per player
local MAX_ITEMS_PER_SIDE = 6           -- max items each player can offer
local COIN_TAX_RATE = 0.02             -- 2% tax on coin portion
local MIN_TRADE_LEVEL = 5              -- minimum player level to trade
local REQUEST_TIMEOUT = 60             -- seconds before a pending request expires
local MAX_TRADE_HISTORY = 100          -- max entries kept per player
local TRADE_SESSION_TIMEOUT = 300      -- seconds before an active trade auto-cancels

-- Trade session states
local STATE_PENDING = "Pending"        -- waiting for target to accept
local STATE_ACTIVE = "Active"          -- both players building offers
local STATE_COMPLETED = "Completed"
local STATE_CANCELLED = "Cancelled"

-- ============================================================================
-- Internal State
-- ============================================================================

local Remotes = {}                     -- RemoteEvent references
local activeTrades = {}                -- [tradeId] = tradeSession
local playerToTrade = {}               -- [UserId] = tradeId (quick lookup)
local pendingRequests = {}             -- [targetUserId] = { fromPlayer, toPlayer, timestamp }
local lastTradeTime = {}               -- [UserId] = os.time() of last completed trade
local initialized = false

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function generateTradeId()
    return HttpService:GenerateGUID(false)
end

local function getTimestamp()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

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

local function isValidPlayer(player)
    return typeof(player) == "Instance"
        and player:IsA("Player")
        and player:IsDescendantOf(Players)
end

local function getPlayerData(player)
    local success, data = pcall(function()
        return DataStoreManager.GetPlayerData(player)
    end)
    if success and data then
        return data
    end
    return nil
end

local function notifyClient(player, eventName, ...)
    local remote = Remotes[eventName]
    if not remote then
        warn("[TradeSystem] Remote not found: " .. tostring(eventName))
        return
    end
    local success, err = pcall(function()
        remote:FireClient(player, ...)
    end)
    if not success then
        warn("[TradeSystem] Failed to notify client: " .. tostring(err))
    end
end

local function notifyBothPlayers(trade, eventName, ...)
    if trade.PlayerA and trade.PlayerA.Parent then
        notifyClient(trade.PlayerA, eventName, ...)
    end
    if trade.PlayerB and trade.PlayerB.Parent then
        notifyClient(trade.PlayerB, eventName, ...)
    end
end

-- ============================================================================
-- RemoteEvent Setup
-- ============================================================================

local function getOrCreateRemote(name)
    local folder = ReplicatedStorage:FindFirstChild("TradeEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "TradeEvents"
        folder.Parent = ReplicatedStorage
    end
    local remote = folder:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = folder
    end
    return remote
end

-- ============================================================================
-- Validation Helpers
-- ============================================================================

local function isOnCooldown(player)
    local last = lastTradeTime[player.UserId]
    if last and (os.time() - last) < TRADE_COOLDOWN then
        return true, TRADE_COOLDOWN - (os.time() - last)
    end
    return false, 0
end

local function meetsLevelRequirement(player)
    local data = getPlayerData(player)
    if not data then return false end
    return (data.Level or 0) >= MIN_TRADE_LEVEL
end

local function isInTrade(player)
    return playerToTrade[player.UserId] ~= nil
end

local function hasPendingRequest(player)
    return pendingRequests[player.UserId] ~= nil
end

local function ownsCreature(playerData, creatureId)
    if not playerData or not playerData.Creatures then return false end
    for _, creature in ipairs(playerData.Creatures) do
        if creature.Id == creatureId then
            return true
        end
    end
    return false
end

local function ownsItem(playerData, itemId)
    if not playerData or not playerData.Inventory then return false end
    for _, item in ipairs(playerData.Inventory) do
        if item.Id == itemId then
            return true
        end
    end
    return false
end

local function getCreatureById(playerData, creatureId)
    if not playerData or not playerData.Creatures then return nil end
    for _, creature in ipairs(playerData.Creatures) do
        if creature.Id == creatureId then
            return deepCopy(creature)
        end
    end
    return nil
end

local function getItemById(playerData, itemId)
    if not playerData or not playerData.Inventory then return nil end
    for _, item in ipairs(playerData.Inventory) do
        if item.Id == itemId then
            return deepCopy(item)
        end
    end
    return nil
end

local function isItemAlreadyInOffer(offer, itemId)
    for _, entry in ipairs(offer.Items) do
        if entry.Id == itemId then
            return true
        end
    end
    return false
end

--- Verify that every item in an offer is still owned by the player at execution time.
local function validateOfferOwnership(player, offer)
    local data = getPlayerData(player)
    if not data then return false, "Could not load player data" end

    for _, entry in ipairs(offer.Items) do
        if entry.ItemType == "Creature" then
            if not ownsCreature(data, entry.Id) then
                return false, "Creature no longer owned: " .. tostring(entry.Id)
            end
        elseif entry.ItemType == "Equipment" then
            if not ownsItem(data, entry.Id) then
                return false, "Item no longer owned: " .. tostring(entry.Id)
            end
        else
            return false, "Unknown item type: " .. tostring(entry.ItemType)
        end
    end

    -- Validate coin balance
    if offer.Coins > 0 then
        local totalCoinsNeeded = offer.Coins + math.floor(offer.Coins * COIN_TAX_RATE)
        if (data.Coins or 0) < totalCoinsNeeded then
            return false, "Insufficient coins (including tax)"
        end
    end

    return true
end

-- ============================================================================
-- Trade Session Management
-- ============================================================================

local function createTradeSession(playerA, playerB)
    local tradeId = generateTradeId()

    local session = {
        TradeId = tradeId,
        State = STATE_ACTIVE,
        PlayerA = playerA,
        PlayerB = playerB,
        OfferA = {
            Items = {},     -- { { Id, ItemType, Name, Data } }
            Coins = 0,
            Confirmed = false,
        },
        OfferB = {
            Items = {},
            Coins = 0,
            Confirmed = false,
        },
        CreatedAt = os.time(),
        CompletedAt = nil,
    }

    activeTrades[tradeId] = session
    playerToTrade[playerA.UserId] = tradeId
    playerToTrade[playerB.UserId] = tradeId

    return session
end

local function getTradeSession(player)
    local tradeId = playerToTrade[player.UserId]
    if not tradeId then return nil end
    return activeTrades[tradeId]
end

local function getPlayerOffer(trade, player)
    if trade.PlayerA == player then
        return trade.OfferA
    elseif trade.PlayerB == player then
        return trade.OfferB
    end
    return nil
end

local function getPartnerOffer(trade, player)
    if trade.PlayerA == player then
        return trade.OfferB
    elseif trade.PlayerB == player then
        return trade.OfferA
    end
    return nil
end

local function getPartner(trade, player)
    if trade.PlayerA == player then
        return trade.PlayerB
    elseif trade.PlayerB == player then
        return trade.PlayerA
    end
    return nil
end

local function cleanupTrade(tradeId)
    local trade = activeTrades[tradeId]
    if not trade then return end

    if trade.PlayerA then
        playerToTrade[trade.PlayerA.UserId] = nil
    end
    if trade.PlayerB then
        playerToTrade[trade.PlayerB.UserId] = nil
    end

    activeTrades[tradeId] = nil
end

--- Build a sanitized snapshot of the trade for client display.
local function buildTradeSnapshot(trade)
    return {
        TradeId = trade.TradeId,
        State = trade.State,
        PlayerA = trade.PlayerA and trade.PlayerA.Name or "Unknown",
        PlayerB = trade.PlayerB and trade.PlayerB.Name or "Unknown",
        OfferA = {
            Items = deepCopy(trade.OfferA.Items),
            Coins = trade.OfferA.Coins,
            Confirmed = trade.OfferA.Confirmed,
        },
        OfferB = {
            Items = deepCopy(trade.OfferB.Items),
            Coins = trade.OfferB.Coins,
            Confirmed = trade.OfferB.Confirmed,
        },
    }
end

-- ============================================================================
-- Trade History
-- ============================================================================

local function logTradeHistory(player, tradeRecord)
    local success, err = pcall(function()
        local data = DataStoreManager.GetPlayerData(player)
        if not data then return end

        if not data.TradeHistory then
            data.TradeHistory = {}
        end

        table.insert(data.TradeHistory, tradeRecord)

        -- Trim to max history
        while #data.TradeHistory > MAX_TRADE_HISTORY do
            table.remove(data.TradeHistory, 1)
        end
    end)

    if not success then
        warn("[TradeSystem] Failed to log trade history for " .. player.Name .. ": " .. tostring(err))
    end
end

local function recordCompletedTrade(trade)
    local record = {
        TradeId = trade.TradeId,
        Timestamp = getTimestamp(),
        PlayerA = trade.PlayerA and trade.PlayerA.Name or "Unknown",
        PlayerAUserId = trade.PlayerA and trade.PlayerA.UserId or 0,
        PlayerB = trade.PlayerB and trade.PlayerB.Name or "Unknown",
        PlayerBUserId = trade.PlayerB and trade.PlayerB.UserId or 0,
        OfferA = {
            Items = deepCopy(trade.OfferA.Items),
            Coins = trade.OfferA.Coins,
        },
        OfferB = {
            Items = deepCopy(trade.OfferB.Items),
            Coins = trade.OfferB.Coins,
        },
        TaxApplied = math.floor(trade.OfferA.Coins * COIN_TAX_RATE)
            + math.floor(trade.OfferB.Coins * COIN_TAX_RATE),
    }

    if trade.PlayerA and trade.PlayerA.Parent then
        logTradeHistory(trade.PlayerA, deepCopy(record))
    end
    if trade.PlayerB and trade.PlayerB.Parent then
        logTradeHistory(trade.PlayerB, deepCopy(record))
    end

    print(string.format(
        "[TradeSystem] Trade %s completed: %s <-> %s (%d items, %d coins exchanged)",
        trade.TradeId,
        record.PlayerA,
        record.PlayerB,
        #record.OfferA.Items + #record.OfferB.Items,
        record.OfferA.Coins + record.OfferB.Coins
    ))
end

-- ============================================================================
-- Atomic Trade Execution
-- ============================================================================

--- Execute the trade atomically. Removes all items/coins first, then adds them.
--- If any step fails, attempts rollback.
local function executeTrade(trade)
    local playerA = trade.PlayerA
    local playerB = trade.PlayerB
    local offerA = trade.OfferA
    local offerB = trade.OfferB

    -- Phase 1: Final validation
    local validA, errA = validateOfferOwnership(playerA, offerA)
    if not validA then
        return false, "Player A validation failed: " .. tostring(errA)
    end

    local validB, errB = validateOfferOwnership(playerB, offerB)
    if not validB then
        return false, "Player B validation failed: " .. tostring(errB)
    end

    -- Phase 2: Calculate taxes
    local taxA = math.floor(offerA.Coins * COIN_TAX_RATE)
    local taxB = math.floor(offerB.Coins * COIN_TAX_RATE)
    local netCoinsA = offerA.Coins - taxA   -- amount B receives from A
    local netCoinsB = offerB.Coins - taxB   -- amount A receives from B

    -- Phase 3: Remove all offered items and coins (debit phase)
    local removedItemsA = {}
    local removedItemsB = {}
    local removedCoinsA = false
    local removedCoinsB = false
    local rollbackNeeded = false
    local failReason = ""

    -- Remove Player A's offered items
    for _, entry in ipairs(offerA.Items) do
        local ok, result = false, false
        if entry.ItemType == "Creature" then
            ok, result = pcall(function()
                return DataStoreManager.RemoveCreature(playerA, entry.Id)
            end)
        elseif entry.ItemType == "Equipment" then
            ok, result = pcall(function()
                return DataStoreManager.RemoveInventoryItem(playerA, entry.Id)
            end)
        end
        if ok and result ~= false then
            table.insert(removedItemsA, entry)
        else
            rollbackNeeded = true
            failReason = "Failed to remove item " .. tostring(entry.Id) .. " from " .. playerA.Name
            break
        end
    end

    -- Remove Player B's offered items
    if not rollbackNeeded then
        for _, entry in ipairs(offerB.Items) do
            local ok, result = false, false
            if entry.ItemType == "Creature" then
                ok, result = pcall(function()
                    return DataStoreManager.RemoveCreature(playerB, entry.Id)
                end)
            elseif entry.ItemType == "Equipment" then
                ok, result = pcall(function()
                    return DataStoreManager.RemoveInventoryItem(playerB, entry.Id)
                end)
            end
            if ok and result ~= false then
                table.insert(removedItemsB, entry)
            else
                rollbackNeeded = true
                failReason = "Failed to remove item " .. tostring(entry.Id) .. " from " .. playerB.Name
                break
            end
        end
    end

    -- Remove Player A's coins (offer + tax)
    if not rollbackNeeded and offerA.Coins > 0 then
        local totalDebitA = offerA.Coins + taxA
        local ok, result = pcall(function()
            return DataStoreManager.RemoveCoins(playerA, totalDebitA)
        end)
        if ok and result ~= false then
            removedCoinsA = true
        else
            rollbackNeeded = true
            failReason = "Failed to remove coins from " .. playerA.Name
        end
    end

    -- Remove Player B's coins (offer + tax)
    if not rollbackNeeded and offerB.Coins > 0 then
        local totalDebitB = offerB.Coins + taxB
        local ok, result = pcall(function()
            return DataStoreManager.RemoveCoins(playerB, totalDebitB)
        end)
        if ok and result ~= false then
            removedCoinsB = true
        else
            rollbackNeeded = true
            failReason = "Failed to remove coins from " .. playerB.Name
        end
    end

    -- Phase 4: Rollback if needed
    if rollbackNeeded then
        warn("[TradeSystem] Rolling back trade " .. trade.TradeId .. ": " .. failReason)

        -- Restore Player A's items
        for _, entry in ipairs(removedItemsA) do
            pcall(function()
                if entry.ItemType == "Creature" then
                    DataStoreManager.AddCreature(playerA, entry.Data)
                elseif entry.ItemType == "Equipment" then
                    DataStoreManager.AddInventoryItem(playerA, entry.Data)
                end
            end)
        end

        -- Restore Player B's items
        for _, entry in ipairs(removedItemsB) do
            pcall(function()
                if entry.ItemType == "Creature" then
                    DataStoreManager.AddCreature(playerB, entry.Data)
                elseif entry.ItemType == "Equipment" then
                    DataStoreManager.AddInventoryItem(playerB, entry.Data)
                end
            end)
        end

        -- Restore coins
        if removedCoinsA then
            pcall(function()
                DataStoreManager.AddCoins(playerA, offerA.Coins + taxA)
            end)
        end
        if removedCoinsB then
            pcall(function()
                DataStoreManager.AddCoins(playerB, offerB.Coins + taxB)
            end)
        end

        return false, failReason
    end

    -- Phase 5: Credit phase — give items to recipients
    -- Player A's items go to Player B
    for _, entry in ipairs(offerA.Items) do
        pcall(function()
            local itemData = deepCopy(entry.Data)
            itemData.AcquiredDate = getTimestamp()
            if entry.ItemType == "Creature" then
                DataStoreManager.AddCreature(playerB, itemData)
            elseif entry.ItemType == "Equipment" then
                DataStoreManager.AddInventoryItem(playerB, itemData)
            end
        end)
    end

    -- Player B's items go to Player A
    for _, entry in ipairs(offerB.Items) do
        pcall(function()
            local itemData = deepCopy(entry.Data)
            itemData.AcquiredDate = getTimestamp()
            if entry.ItemType == "Creature" then
                DataStoreManager.AddCreature(playerA, itemData)
            elseif entry.ItemType == "Equipment" then
                DataStoreManager.AddInventoryItem(playerA, itemData)
            end
        end)
    end

    -- Credit net coins
    if netCoinsA > 0 then
        pcall(function()
            DataStoreManager.AddCoins(playerB, netCoinsA)
        end)
    end
    if netCoinsB > 0 then
        pcall(function()
            DataStoreManager.AddCoins(playerA, netCoinsB)
        end)
    end

    -- Phase 6: Update statistics
    pcall(function()
        local dataA = DataStoreManager.GetPlayerData(playerA)
        if dataA and dataA.Statistics then
            dataA.Statistics.TradesCompleted = (dataA.Statistics.TradesCompleted or 0) + 1
        end
    end)
    pcall(function()
        local dataB = DataStoreManager.GetPlayerData(playerB)
        if dataB and dataB.Statistics then
            dataB.Statistics.TradesCompleted = (dataB.Statistics.TradesCompleted or 0) + 1
        end
    end)

    return true
end

-- ============================================================================
-- Timeout / Cleanup Background Loop
-- ============================================================================

local function startCleanupLoop()
    task.spawn(function()
        while initialized do
            task.wait(10)

            local now = os.time()

            -- Expire pending requests
            for targetId, request in pairs(pendingRequests) do
                if (now - request.Timestamp) >= REQUEST_TIMEOUT then
                    pendingRequests[targetId] = nil
                    if request.FromPlayer and request.FromPlayer.Parent then
                        notifyClient(request.FromPlayer, "TradeRequestExpired", request.ToPlayer and request.ToPlayer.Name or "Unknown")
                    end
                    if request.ToPlayer and request.ToPlayer.Parent then
                        notifyClient(request.ToPlayer, "TradeRequestExpired", request.FromPlayer and request.FromPlayer.Name or "Unknown")
                    end
                end
            end

            -- Expire stale trade sessions
            for tradeId, trade in pairs(activeTrades) do
                if trade.State == STATE_ACTIVE and (now - trade.CreatedAt) >= TRADE_SESSION_TIMEOUT then
                    trade.State = STATE_CANCELLED
                    notifyBothPlayers(trade, "TradeCancelled", "Trade timed out")
                    cleanupTrade(tradeId)
                end
            end
        end
    end)
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Initialize the trade system, creating RemoteEvents and binding listeners.
function TradeSystem.Initialize()
    if initialized then return end
    initialized = true

    -- Create all RemoteEvents
    local remoteNames = {
        -- Server → Client
        "TradeRequestReceived",     -- target receives a trade request
        "TradeRequestSent",         -- sender confirmation
        "TradeRequestExpired",      -- request timed out
        "TradeStarted",             -- trade session opened for both
        "TradeUpdated",             -- offer changed (items/coins)
        "TradeConfirmUpdate",       -- ready status changed
        "TradeCompleted",           -- trade successfully executed
        "TradeCancelled",           -- trade cancelled or failed
        "TradeError",               -- validation error message
        -- Client → Server
        "RequestTrade",
        "AcceptTrade",
        "DeclineTrade",
        "AddItem",
        "RemoveItem",
        "SetCoins",
        "ConfirmTrade",
        "CancelTrade",
    }

    for _, name in ipairs(remoteNames) do
        Remotes[name] = getOrCreateRemote(name)
    end

    -- Bind client → server events
    Remotes.RequestTrade.OnServerEvent:Connect(function(player, targetPlayer)
        TradeSystem.RequestTrade(player, targetPlayer)
    end)

    Remotes.AcceptTrade.OnServerEvent:Connect(function(player)
        TradeSystem.AcceptTrade(player)
    end)

    Remotes.DeclineTrade.OnServerEvent:Connect(function(player)
        TradeSystem.DeclineTrade(player)
    end)

    Remotes.AddItem.OnServerEvent:Connect(function(player, itemId, itemType)
        TradeSystem.AddItemToTrade(player, itemId, itemType)
    end)

    Remotes.RemoveItem.OnServerEvent:Connect(function(player, itemId)
        TradeSystem.RemoveItemFromTrade(player, itemId)
    end)

    Remotes.SetCoins.OnServerEvent:Connect(function(player, amount)
        TradeSystem.SetTradeCoins(player, amount)
    end)

    Remotes.ConfirmTrade.OnServerEvent:Connect(function(player)
        TradeSystem.ConfirmTrade(player)
    end)

    Remotes.CancelTrade.OnServerEvent:Connect(function(player)
        TradeSystem.CancelTrade(player)
    end)

    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        -- Cancel any active trade
        local trade = getTradeSession(player)
        if trade and trade.State == STATE_ACTIVE then
            trade.State = STATE_CANCELLED
            local partner = getPartner(trade, player)
            if partner and partner.Parent then
                notifyClient(partner, "TradeCancelled", player.Name .. " left the game")
            end
            cleanupTrade(trade.TradeId)
        end

        -- Clear pending requests involving this player
        pendingRequests[player.UserId] = nil
        for targetId, request in pairs(pendingRequests) do
            if request.FromPlayer == player then
                pendingRequests[targetId] = nil
                if request.ToPlayer and request.ToPlayer.Parent then
                    notifyClient(request.ToPlayer, "TradeCancelled", player.Name .. " left the game")
                end
            end
        end

        -- Clean up cooldown entry (optional, prevents memory leak)
        lastTradeTime[player.UserId] = nil
        playerToTrade[player.UserId] = nil
    end)

    startCleanupLoop()
    print("[TradeSystem] Initialized successfully")
end

--- Send a trade request from one player to another.
function TradeSystem.RequestTrade(fromPlayer, toPlayer)
    -- Type validation
    if not isValidPlayer(fromPlayer) or not isValidPlayer(toPlayer) then
        if isValidPlayer(fromPlayer) then
            notifyClient(fromPlayer, "TradeError", "Invalid trade target")
        end
        return false
    end

    -- Cannot trade with yourself
    if fromPlayer == toPlayer then
        notifyClient(fromPlayer, "TradeError", "You cannot trade with yourself")
        return false
    end

    -- Level requirement
    if not meetsLevelRequirement(fromPlayer) then
        notifyClient(fromPlayer, "TradeError", "You must be at least level " .. MIN_TRADE_LEVEL .. " to trade")
        return false
    end
    if not meetsLevelRequirement(toPlayer) then
        notifyClient(fromPlayer, "TradeError", toPlayer.Name .. " has not reached the required level to trade")
        return false
    end

    -- Cooldown check
    local onCooldown, remaining = isOnCooldown(fromPlayer)
    if onCooldown then
        notifyClient(fromPlayer, "TradeError", "Trade on cooldown. Wait " .. math.ceil(remaining) .. " seconds")
        return false
    end

    -- Already in a trade
    if isInTrade(fromPlayer) then
        notifyClient(fromPlayer, "TradeError", "You are already in a trade")
        return false
    end
    if isInTrade(toPlayer) then
        notifyClient(fromPlayer, "TradeError", toPlayer.Name .. " is already in a trade")
        return false
    end

    -- Already has a pending request as sender
    for _, request in pairs(pendingRequests) do
        if request.FromPlayer == fromPlayer then
            notifyClient(fromPlayer, "TradeError", "You already have a pending trade request")
            return false
        end
    end

    -- Target already has a pending request
    if hasPendingRequest(toPlayer) then
        notifyClient(fromPlayer, "TradeError", toPlayer.Name .. " already has a pending trade request")
        return false
    end

    -- Create pending request
    pendingRequests[toPlayer.UserId] = {
        FromPlayer = fromPlayer,
        ToPlayer = toPlayer,
        Timestamp = os.time(),
    }

    notifyClient(toPlayer, "TradeRequestReceived", fromPlayer.Name, fromPlayer.UserId)
    notifyClient(fromPlayer, "TradeRequestSent", toPlayer.Name)

    print("[TradeSystem] " .. fromPlayer.Name .. " requested trade with " .. toPlayer.Name)
    return true
end

--- Accept an incoming trade request.
function TradeSystem.AcceptTrade(player)
    if not isValidPlayer(player) then return false end

    local request = pendingRequests[player.UserId]
    if not request then
        notifyClient(player, "TradeError", "No pending trade request")
        return false
    end

    local fromPlayer = request.FromPlayer
    pendingRequests[player.UserId] = nil

    -- Re-validate both players
    if not fromPlayer or not fromPlayer.Parent then
        notifyClient(player, "TradeError", "The requesting player is no longer available")
        return false
    end

    if isInTrade(player) or isInTrade(fromPlayer) then
        notifyClient(player, "TradeError", "One of the players is already in a trade")
        if fromPlayer.Parent then
            notifyClient(fromPlayer, "TradeError", "Trade could not be started")
        end
        return false
    end

    -- Create trade session
    local trade = createTradeSession(fromPlayer, player)
    local snapshot = buildTradeSnapshot(trade)

    notifyClient(fromPlayer, "TradeStarted", snapshot)
    notifyClient(player, "TradeStarted", snapshot)

    print("[TradeSystem] Trade started: " .. fromPlayer.Name .. " <-> " .. player.Name .. " (" .. trade.TradeId .. ")")
    return true
end

--- Decline an incoming trade request.
function TradeSystem.DeclineTrade(player)
    if not isValidPlayer(player) then return false end

    local request = pendingRequests[player.UserId]
    if not request then
        notifyClient(player, "TradeError", "No pending trade request to decline")
        return false
    end

    local fromPlayer = request.FromPlayer
    pendingRequests[player.UserId] = nil

    if fromPlayer and fromPlayer.Parent then
        notifyClient(fromPlayer, "TradeCancelled", player.Name .. " declined your trade request")
    end

    print("[TradeSystem] " .. player.Name .. " declined trade from " .. (fromPlayer and fromPlayer.Name or "Unknown"))
    return true
end

--- Add an item (creature or equipment) to the player's trade offer.
function TradeSystem.AddItemToTrade(player, itemId, itemType)
    if not isValidPlayer(player) then return false end

    -- Validate inputs
    if type(itemId) ~= "string" or itemId == "" then
        notifyClient(player, "TradeError", "Invalid item ID")
        return false
    end
    if itemType ~= "Creature" and itemType ~= "Equipment" then
        notifyClient(player, "TradeError", "Invalid item type. Must be 'Creature' or 'Equipment'")
        return false
    end

    local trade = getTradeSession(player)
    if not trade or trade.State ~= STATE_ACTIVE then
        notifyClient(player, "TradeError", "No active trade")
        return false
    end

    local offer = getPlayerOffer(trade, player)
    if not offer then
        notifyClient(player, "TradeError", "Could not find your trade offer")
        return false
    end

    -- Cannot modify after confirming
    if offer.Confirmed then
        notifyClient(player, "TradeError", "You have already confirmed. Unconfirm to modify your offer")
        return false
    end

    -- Max items check
    if #offer.Items >= MAX_ITEMS_PER_SIDE then
        notifyClient(player, "TradeError", "Maximum " .. MAX_ITEMS_PER_SIDE .. " items per trade")
        return false
    end

    -- Duplicate check
    if isItemAlreadyInOffer(offer, itemId) then
        notifyClient(player, "TradeError", "Item already in your offer")
        return false
    end

    -- Ownership verification
    local data = getPlayerData(player)
    if not data then
        notifyClient(player, "TradeError", "Could not load your data")
        return false
    end

    local itemData = nil
    local itemName = "Unknown"

    if itemType == "Creature" then
        if not ownsCreature(data, itemId) then
            notifyClient(player, "TradeError", "You do not own this creature")
            return false
        end
        itemData = getCreatureById(data, itemId)
        itemName = itemData and itemData.Name or "Unknown Creature"
    elseif itemType == "Equipment" then
        if not ownsItem(data, itemId) then
            notifyClient(player, "TradeError", "You do not own this item")
            return false
        end
        itemData = getItemById(data, itemId)
        itemName = itemData and itemData.Name or "Unknown Item"
    end

    -- Add to offer
    table.insert(offer.Items, {
        Id = itemId,
        ItemType = itemType,
        Name = itemName,
        Data = itemData,
    })

    -- Reset both confirmations when an offer changes
    trade.OfferA.Confirmed = false
    trade.OfferB.Confirmed = false

    -- Notify both players of the update
    local snapshot = buildTradeSnapshot(trade)
    notifyBothPlayers(trade, "TradeUpdated", snapshot)

    return true
end

--- Remove an item from the player's trade offer.
function TradeSystem.RemoveItemFromTrade(player, itemId)
    if not isValidPlayer(player) then return false end

    if type(itemId) ~= "string" or itemId == "" then
        notifyClient(player, "TradeError", "Invalid item ID")
        return false
    end

    local trade = getTradeSession(player)
    if not trade or trade.State ~= STATE_ACTIVE then
        notifyClient(player, "TradeError", "No active trade")
        return false
    end

    local offer = getPlayerOffer(trade, player)
    if not offer then
        notifyClient(player, "TradeError", "Could not find your trade offer")
        return false
    end

    if offer.Confirmed then
        notifyClient(player, "TradeError", "You have already confirmed. Unconfirm to modify your offer")
        return false
    end

    -- Find and remove the item
    local removed = false
    for i, entry in ipairs(offer.Items) do
        if entry.Id == itemId then
            table.remove(offer.Items, i)
            removed = true
            break
        end
    end

    if not removed then
        notifyClient(player, "TradeError", "Item not found in your offer")
        return false
    end

    -- Reset both confirmations
    trade.OfferA.Confirmed = false
    trade.OfferB.Confirmed = false

    local snapshot = buildTradeSnapshot(trade)
    notifyBothPlayers(trade, "TradeUpdated", snapshot)

    return true
end

--- Set the coin amount the player is offering in the trade.
function TradeSystem.SetTradeCoins(player, amount)
    if not isValidPlayer(player) then return false end

    -- Validate amount
    if type(amount) ~= "number" then
        notifyClient(player, "TradeError", "Invalid coin amount")
        return false
    end

    amount = math.floor(amount)
    if amount < 0 then
        notifyClient(player, "TradeError", "Coin amount cannot be negative")
        return false
    end

    local trade = getTradeSession(player)
    if not trade or trade.State ~= STATE_ACTIVE then
        notifyClient(player, "TradeError", "No active trade")
        return false
    end

    local offer = getPlayerOffer(trade, player)
    if not offer then
        notifyClient(player, "TradeError", "Could not find your trade offer")
        return false
    end

    if offer.Confirmed then
        notifyClient(player, "TradeError", "You have already confirmed. Unconfirm to modify your offer")
        return false
    end

    -- Verify player has enough coins (including tax)
    local data = getPlayerData(player)
    if not data then
        notifyClient(player, "TradeError", "Could not load your data")
        return false
    end

    local tax = math.floor(amount * COIN_TAX_RATE)
    local totalRequired = amount + tax
    if (data.Coins or 0) < totalRequired then
        notifyClient(player, "TradeError", "Insufficient coins. You need " .. totalRequired .. " (includes " .. tax .. " tax)")
        return false
    end

    offer.Coins = amount

    -- Reset both confirmations
    trade.OfferA.Confirmed = false
    trade.OfferB.Confirmed = false

    local snapshot = buildTradeSnapshot(trade)
    notifyBothPlayers(trade, "TradeUpdated", snapshot)

    return true
end

--- Toggle or set the player's confirmation status. Both must confirm to execute.
function TradeSystem.ConfirmTrade(player)
    if not isValidPlayer(player) then return false end

    local trade = getTradeSession(player)
    if not trade or trade.State ~= STATE_ACTIVE then
        notifyClient(player, "TradeError", "No active trade")
        return false
    end

    local offer = getPlayerOffer(trade, player)
    if not offer then
        notifyClient(player, "TradeError", "Could not find your trade offer")
        return false
    end

    -- Toggle confirmation
    offer.Confirmed = not offer.Confirmed

    -- Notify both of the confirmation status change
    local snapshot = buildTradeSnapshot(trade)
    notifyBothPlayers(trade, "TradeConfirmUpdate", snapshot)

    -- If both confirmed, execute the trade
    if trade.OfferA.Confirmed and trade.OfferB.Confirmed then
        print("[TradeSystem] Both players confirmed trade " .. trade.TradeId .. ". Executing...")

        local success, err = executeTrade(trade)

        if success then
            trade.State = STATE_COMPLETED
            trade.CompletedAt = os.time()

            -- Record history
            recordCompletedTrade(trade)

            -- Set cooldowns
            lastTradeTime[trade.PlayerA.UserId] = os.time()
            lastTradeTime[trade.PlayerB.UserId] = os.time()

            -- Notify clients
            local finalSnapshot = buildTradeSnapshot(trade)
            notifyBothPlayers(trade, "TradeCompleted", finalSnapshot)

            -- Save both players' data
            pcall(function() DataStoreManager.SavePlayerData(trade.PlayerA) end)
            pcall(function() DataStoreManager.SavePlayerData(trade.PlayerB) end)

            cleanupTrade(trade.TradeId)
        else
            -- Trade failed — reset confirmations and notify
            trade.OfferA.Confirmed = false
            trade.OfferB.Confirmed = false
            local errorMsg = "Trade failed: " .. tostring(err)
            notifyBothPlayers(trade, "TradeError", errorMsg)
            notifyBothPlayers(trade, "TradeConfirmUpdate", buildTradeSnapshot(trade))
            warn("[TradeSystem] Trade execution failed (" .. trade.TradeId .. "): " .. tostring(err))
        end
    end

    return true
end

--- Cancel the current active trade.
function TradeSystem.CancelTrade(player)
    if not isValidPlayer(player) then return false end

    -- Check for pending request first (as sender)
    for targetId, request in pairs(pendingRequests) do
        if request.FromPlayer == player then
            pendingRequests[targetId] = nil
            if request.ToPlayer and request.ToPlayer.Parent then
                notifyClient(request.ToPlayer, "TradeCancelled", player.Name .. " cancelled the trade request")
            end
            notifyClient(player, "TradeCancelled", "Trade request cancelled")
            return true
        end
    end

    -- Check for active trade
    local trade = getTradeSession(player)
    if not trade or trade.State ~= STATE_ACTIVE then
        notifyClient(player, "TradeError", "No active trade to cancel")
        return false
    end

    trade.State = STATE_CANCELLED
    local partner = getPartner(trade, player)

    notifyClient(player, "TradeCancelled", "You cancelled the trade")
    if partner and partner.Parent then
        notifyClient(partner, "TradeCancelled", player.Name .. " cancelled the trade")
    end

    cleanupTrade(trade.TradeId)

    print("[TradeSystem] Trade " .. trade.TradeId .. " cancelled by " .. player.Name)
    return true
end

--- Get a read-only snapshot of the player's active trade, or nil if none.
function TradeSystem.GetActiveTrade(player)
    if not isValidPlayer(player) then return nil end

    local trade = getTradeSession(player)
    if not trade then return nil end

    return buildTradeSnapshot(trade)
end

return TradeSystem
