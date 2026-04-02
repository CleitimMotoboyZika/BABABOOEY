-- TradeManager: Secure server-side trading system
-- Handles player-to-player trades with full validation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

local TradeManager = {}
TradeManager.__index = TradeManager

local activeTradeRequests = {} -- requestId -> trade data
local playerTradeState = {}    -- playerId -> current trade request id or nil

-- ============================================================
-- TRADE REQUEST
-- ============================================================
function TradeManager.SendTradeRequest(fromPlayerId, toPlayerId)
	if not GameConfig.Currency.TradeEnabled then
		return false, "Trading is currently disabled"
	end
	
	-- Check if either player is already in a trade
	if playerTradeState[fromPlayerId] then
		return false, "You are already in a trade"
	end
	if playerTradeState[toPlayerId] then
		return false, "That player is already in a trade"
	end
	
	local requestId = game:GetService("HttpService"):GenerateGUID(false)
	
	activeTradeRequests[requestId] = {
		Id = requestId,
		Status = "Pending", -- Pending, Active, Completed, Cancelled
		Player1 = fromPlayerId,
		Player2 = toPlayerId,
		
		Offer1 = { Creatures = {}, Items = {}, Money = 0, Confirmed = false },
		Offer2 = { Creatures = {}, Items = {}, Money = 0, Confirmed = false },
		
		CreatedAt = os.time(),
		ExpiresAt = os.time() + 60, -- 60 second expiry
	}
	
	playerTradeState[fromPlayerId] = requestId
	
	return true, requestId
end

-- ============================================================
-- ACCEPT TRADE REQUEST
-- ============================================================
function TradeManager.AcceptTradeRequest(playerId, requestId)
	local trade = activeTradeRequests[requestId]
	if not trade then return false, "Trade not found" end
	if trade.Status ~= "Pending" then return false, "Trade is not pending" end
	if trade.Player2 ~= playerId then return false, "This trade is not for you" end
	
	-- Check expiry
	if os.time() > trade.ExpiresAt then
		TradeManager.CancelTrade(requestId)
		return false, "Trade request expired"
	end
	
	trade.Status = "Active"
	playerTradeState[playerId] = requestId
	
	return true
end

-- ============================================================
-- DECLINE TRADE REQUEST
-- ============================================================
function TradeManager.DeclineTradeRequest(playerId, requestId)
	local trade = activeTradeRequests[requestId]
	if not trade then return false end
	if trade.Player2 ~= playerId then return false end
	
	TradeManager.CancelTrade(requestId)
	return true
end

-- ============================================================
-- UPDATE OFFER
-- ============================================================
function TradeManager.UpdateOffer(playerId, requestId, offerData)
	local trade = activeTradeRequests[requestId]
	if not trade then return false, "Trade not found" end
	if trade.Status ~= "Active" then return false, "Trade is not active" end
	
	local offerKey
	if trade.Player1 == playerId then
		offerKey = "Offer1"
	elseif trade.Player2 == playerId then
		offerKey = "Offer2"
	else
		return false, "You are not in this trade"
	end
	
	-- Updating offer resets both confirmations
	trade.Offer1.Confirmed = false
	trade.Offer2.Confirmed = false
	
	-- Validate and set offer
	local offer = trade[offerKey]
	
	if offerData.Creatures and type(offerData.Creatures) == "table" then
		offer.Creatures = offerData.Creatures
	end
	
	if offerData.Items and type(offerData.Items) == "table" then
		offer.Items = offerData.Items
	end
	
	if offerData.Money and type(offerData.Money) == "number" then
		offer.Money = math.max(0, math.floor(offerData.Money))
	end
	
	return true
end

-- ============================================================
-- CONFIRM OFFER
-- ============================================================
function TradeManager.ConfirmOffer(playerId, requestId)
	local trade = activeTradeRequests[requestId]
	if not trade then return false, "Trade not found" end
	if trade.Status ~= "Active" then return false, "Trade is not active" end
	
	if trade.Player1 == playerId then
		trade.Offer1.Confirmed = true
	elseif trade.Player2 == playerId then
		trade.Offer2.Confirmed = true
	else
		return false, "You are not in this trade"
	end
	
	-- Check if both confirmed
	if trade.Offer1.Confirmed and trade.Offer2.Confirmed then
		return true, "BothConfirmed"
	end
	
	return true, "WaitingForOther"
end

-- ============================================================
-- EXECUTE TRADE (called when both players confirm)
-- ============================================================
function TradeManager.ExecuteTrade(requestId, dataStore)
	local trade = activeTradeRequests[requestId]
	if not trade then return false, "Trade not found" end
	if not (trade.Offer1.Confirmed and trade.Offer2.Confirmed) then
		return false, "Both players must confirm"
	end
	
	local player1 = Players:GetPlayerByUserId(trade.Player1)
	local player2 = Players:GetPlayerByUserId(trade.Player2)
	
	if not player1 or not player2 then
		TradeManager.CancelTrade(requestId)
		return false, "A player left the game"
	end
	
	local data1 = dataStore.GetData(player1)
	local data2 = dataStore.GetData(player2)
	
	if not data1 or not data2 then
		return false, "Could not access player data"
	end
	
	-- Validate money
	local tax1 = math.floor(trade.Offer1.Money * GameConfig.Currency.TradeTax)
	local tax2 = math.floor(trade.Offer2.Money * GameConfig.Currency.TradeTax)
	
	if data1.Money < trade.Offer1.Money then
		return false, "Player 1 has insufficient funds"
	end
	if data2.Money < trade.Offer2.Money then
		return false, "Player 2 has insufficient funds"
	end
	
	-- Execute money transfer
	data1.Money = data1.Money - trade.Offer1.Money + trade.Offer2.Money - tax2
	data2.Money = data2.Money - trade.Offer2.Money + trade.Offer1.Money - tax1
	
	-- Transfer creatures from Player1 to Player2
	for _, uuid in ipairs(trade.Offer1.Creatures) do
		local creature, cType = TradeManager._FindAndRemoveCreature(data1, uuid)
		if creature and cType then
			TradeManager._AddCreature(data2, creature, cType)
		end
	end
	
	-- Transfer creatures from Player2 to Player1
	for _, uuid in ipairs(trade.Offer2.Creatures) do
		local creature, cType = TradeManager._FindAndRemoveCreature(data2, uuid)
		if creature and cType then
			TradeManager._AddCreature(data1, creature, cType)
		end
	end
	
	-- Transfer items from Player1 to Player2
	for _, uuid in ipairs(trade.Offer1.Items) do
		local item = TradeManager._FindAndRemoveItem(data1, uuid)
		if item then
			table.insert(data2.Inventory, item)
		end
	end
	
	-- Transfer items from Player2 to Player1
	for _, uuid in ipairs(trade.Offer2.Items) do
		local item = TradeManager._FindAndRemoveItem(data2, uuid)
		if item then
			table.insert(data1.Inventory, item)
		end
	end
	
	-- Update stats
	data1.Stats.TotalTradesCompleted = (data1.Stats.TotalTradesCompleted or 0) + 1
	data2.Stats.TotalTradesCompleted = (data2.Stats.TotalTradesCompleted or 0) + 1
	
	-- Cleanup
	trade.Status = "Completed"
	playerTradeState[trade.Player1] = nil
	playerTradeState[trade.Player2] = nil
	
	return true, "Trade completed successfully"
end

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
function TradeManager._FindAndRemoveCreature(data, uuid)
	for i, m in ipairs(data.Monkeys) do
		if m.UUID == uuid then
			table.remove(data.Monkeys, i)
			if data.ActiveMonkey == uuid then data.ActiveMonkey = nil end
			return m, "Monkey"
		end
	end
	for i, c in ipairs(data.Camels) do
		if c.UUID == uuid then
			table.remove(data.Camels, i)
			if data.ActiveCamel == uuid then data.ActiveCamel = nil end
			return c, "Camel"
		end
	end
	for i, l in ipairs(data.Lobsters) do
		if l.UUID == uuid then
			table.remove(data.Lobsters, i)
			if data.ActiveLobster == uuid then data.ActiveLobster = nil end
			return l, "Lobster"
		end
	end
	return nil, nil
end

function TradeManager._AddCreature(data, creature, cType)
	if cType == "Monkey" then
		table.insert(data.Monkeys, creature)
	elseif cType == "Camel" then
		table.insert(data.Camels, creature)
	elseif cType == "Lobster" then
		table.insert(data.Lobsters, creature)
	end
end

function TradeManager._FindAndRemoveItem(data, uuid)
	for i, item in ipairs(data.Inventory) do
		if item.UUID == uuid then
			-- Unequip if equipped
			item.Equipped = false
			item.EquippedTo = nil
			table.remove(data.Inventory, i)
			return item
		end
	end
	return nil
end

-- ============================================================
-- CANCEL TRADE
-- ============================================================
function TradeManager.CancelTrade(requestId)
	local trade = activeTradeRequests[requestId]
	if not trade then return end
	
	trade.Status = "Cancelled"
	playerTradeState[trade.Player1] = nil
	playerTradeState[trade.Player2] = nil
	
	-- Cleanup after a delay
	task.delay(5, function()
		activeTradeRequests[requestId] = nil
	end)
end

-- ============================================================
-- GET TRADE INFO
-- ============================================================
function TradeManager.GetTradeInfo(requestId)
	return activeTradeRequests[requestId]
end

function TradeManager.GetPlayerTrade(playerId)
	local requestId = playerTradeState[playerId]
	if requestId then
		return activeTradeRequests[requestId]
	end
	return nil
end

-- ============================================================
-- CLEANUP
-- ============================================================
function TradeManager.OnPlayerRemoving(playerId)
	local requestId = playerTradeState[playerId]
	if requestId then
		TradeManager.CancelTrade(requestId)
	end
end

function TradeManager.CleanupExpired()
	local now = os.time()
	for id, trade in pairs(activeTradeRequests) do
		if trade.Status == "Pending" and now > trade.ExpiresAt then
			TradeManager.CancelTrade(id)
		end
	end
end

return TradeManager
