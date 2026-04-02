-- MainGameServer: Central orchestrator that connects all server systems
-- Handles remote events, game loop, event scheduling, and player management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Wait for modules to be available
local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")
local GameConfig = require(SharedModules:WaitForChild("GameConfig"))

-- Server modules
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
local CombatAI = require(script.Parent:WaitForChild("CombatAIController"))
local RacingAI = require(script.Parent:WaitForChild("RacingAIController"))
local BettingManager = require(script.Parent:WaitForChild("BettingManager"))
local TradeManager = require(script.Parent:WaitForChild("TradeManager"))
local AutoFix = require(script.Parent:WaitForChild("AutoFixSystem"))

-- ============================================================
-- SETUP REMOTES
-- ============================================================
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name, className)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

-- Remote Events
local PlaceBetEvent = getOrCreateRemote("PlaceBet", "RemoteEvent")
local EventUpdateEvent = getOrCreateRemote("EventUpdate", "RemoteEvent")
local FightUpdateEvent = getOrCreateRemote("FightUpdate", "RemoteEvent")
local RaceUpdateEvent = getOrCreateRemote("RaceUpdate", "RemoteEvent")
local TradeRequestEvent = getOrCreateRemote("TradeRequest", "RemoteEvent")
local TradeUpdateEvent = getOrCreateRemote("TradeUpdate", "RemoteEvent")
local TradeActionEvent = getOrCreateRemote("TradeAction", "RemoteEvent")
local EquipItemEvent = getOrCreateRemote("EquipItem", "RemoteEvent")
local UnequipItemEvent = getOrCreateRemote("UnequipItem", "RemoteEvent")
local SetActiveCreatureEvent = getOrCreateRemote("SetActiveCreature", "RemoteEvent")
local TrainCreatureEvent = getOrCreateRemote("TrainCreature", "RemoteEvent")
local BuyItemEvent = getOrCreateRemote("BuyItem", "RemoteEvent")
local PlayerDataUpdateEvent = getOrCreateRemote("PlayerDataUpdate", "RemoteEvent")
local NotificationEvent = getOrCreateRemote("Notification", "RemoteEvent")

-- Remote Functions
local GetPlayerDataFunc = getOrCreateRemote("GetPlayerData", "RemoteFunction")
local GetBettingInfoFunc = getOrCreateRemote("GetBettingInfo", "RemoteFunction")
local GetShopItemsFunc = getOrCreateRemote("GetShopItems", "RemoteFunction")
local GetCreatureInfoFunc = getOrCreateRemote("GetCreatureInfo", "RemoteFunction")

-- ============================================================
-- GAME STATE
-- ============================================================
local gameState = {
	CurrentEvent = nil,       -- Currently running event
	EventType = nil,          -- "Fight", "CamelRace", "LobsterRace"
	EventPhase = "Idle",      -- "Idle", "Betting", "Running", "Results"
	EventResults = nil,
	EventId = nil,
	NextEventTime = os.time() + 10, -- First event starts quickly
	EventQueue = {"Fight", "CamelRace", "LobsterRace"}, -- Rotation
	EventIndex = 0,
}

-- ============================================================
-- PLAYER JOIN/LEAVE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	if AntiExploit.IsBanned(player) then
		player:Kick("You are temporarily suspended.")
		return
	end
	
	local data = DataStoreManager.LoadPlayerData(player)
	
	if data then
		-- Send initial data to client
		task.wait(1)
		if player.Parent then
			PlayerDataUpdateEvent:FireClient(player, data)
			NotificationEvent:FireClient(player, {
				Type = "Welcome",
				Message = "Welcome to Arena Bestial! You have $" .. data.Money,
			})
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	DataStoreManager.OnPlayerRemoving(player)
	AntiExploit.OnPlayerRemoving(player)
	TradeManager.OnPlayerRemoving(player.UserId)
end)

-- Save all data on server shutdown
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataStoreManager.SavePlayerData(player)
	end
end)

-- ============================================================
-- REMOTE EVENT HANDLERS
-- ============================================================

-- Get Player Data
GetPlayerDataFunc.OnServerInvoke = function(player)
	local valid, reason = AntiExploit.ValidateRemoteCall(player, "GetPlayerData")
	if not valid then return nil end
	
	return DataStoreManager.GetData(player)
end

-- Get Betting Info
GetBettingInfoFunc.OnServerInvoke = function(player, eventId)
	local valid = AntiExploit.ValidateRemoteCall(player, "GetBettingInfo")
	if not valid then return nil end
	
	if not eventId then
		eventId = gameState.EventId
	end
	
	return BettingManager.GetBettingInfo(eventId)
end

-- Place Bet
PlaceBetEvent.OnServerEvent:Connect(function(player, optionId, amount)
	local valid, reason = AntiExploit.ValidateRemoteCall(player, "PlaceBet")
	if not valid then return end
	
	if gameState.EventPhase ~= "Betting" or not gameState.EventId then
		NotificationEvent:FireClient(player, {
			Type = "Error",
			Message = "No active betting round",
		})
		return
	end
	
	local data = DataStoreManager.GetData(player)
	if not data then return end
	
	-- Validate bet
	local betValid, betReason = AntiExploit.ValidateBet(player, amount, data)
	if not betValid then
		NotificationEvent:FireClient(player, {
			Type = "Error",
			Message = betReason,
		})
		return
	end
	
	-- Place bet
	local success, msg = BettingManager.PlaceBet(player.UserId, gameState.EventId, optionId, amount, data)
	if success then
		DataStoreManager.AddMoney(player, -amount)
		data.Stats.TotalBetsPlaced = (data.Stats.TotalBetsPlaced or 0) + 1
		PlayerDataUpdateEvent:FireClient(player, data)
		NotificationEvent:FireClient(player, {
			Type = "Success",
			Message = "Bet placed: $" .. amount,
		})
	else
		NotificationEvent:FireClient(player, {
			Type = "Error",
			Message = msg or "Failed to place bet",
		})
	end
end)

-- Equip Item
EquipItemEvent.OnServerEvent:Connect(function(player, itemUUID, creatureUUID)
	local valid = AntiExploit.ValidateRemoteCall(player, "EquipItem")
	if not valid then return end
	
	local data = DataStoreManager.GetData(player)
	if not data then return end
	
	if not AntiExploit.ValidateEquip(player, itemUUID, creatureUUID, data) then
		return
	end
	
	local success, reason = DataStoreManager.EquipItem(player, itemUUID, creatureUUID)
	PlayerDataUpdateEvent:FireClient(player, data)
	
	NotificationEvent:FireClient(player, {
		Type = success and "Success" or "Error",
		Message = success and "Item equipped!" or (reason or "Failed to equip"),
	})
end)

-- Unequip Item
UnequipItemEvent.OnServerEvent:Connect(function(player, itemUUID)
	local valid = AntiExploit.ValidateRemoteCall(player, "UnequipItem")
	if not valid then return end
	
	DataStoreManager.UnequipItem(player, itemUUID)
	local data = DataStoreManager.GetData(player)
	PlayerDataUpdateEvent:FireClient(player, data)
end)

-- Set Active Creature
SetActiveCreatureEvent.OnServerEvent:Connect(function(player, creatureUUID, creatureType)
	local valid = AntiExploit.ValidateRemoteCall(player, "SetActiveCreature")
	if not valid then return end
	
	if type(creatureType) ~= "string" then return end
	if creatureType ~= "Monkey" and creatureType ~= "Camel" and creatureType ~= "Lobster" then
		return
	end
	
	DataStoreManager.SetActiveCreature(player, creatureUUID, creatureType)
	local data = DataStoreManager.GetData(player)
	PlayerDataUpdateEvent:FireClient(player, data)
end)

-- Train Creature
TrainCreatureEvent.OnServerEvent:Connect(function(player, creatureUUID)
	local valid = AntiExploit.ValidateRemoteCall(player, "TrainCreature")
	if not valid then return end
	
	local success, levelsGained, cost, xpGain = DataStoreManager.TrainCreature(player, creatureUUID)
	local data = DataStoreManager.GetData(player)
	PlayerDataUpdateEvent:FireClient(player, data)
	
	if success then
		local msg = "Training complete! +" .. xpGain .. " XP"
		if levelsGained and levelsGained > 0 then
			msg = msg .. " (Level up! +" .. levelsGained .. ")"
		end
		NotificationEvent:FireClient(player, {
			Type = "Success",
			Message = msg,
		})
	else
		NotificationEvent:FireClient(player, {
			Type = "Error",
			Message = levelsGained or "Training failed", -- levelsGained is error msg on failure
		})
	end
end)

-- Buy Item from Shop
BuyItemEvent.OnServerEvent:Connect(function(player, itemId)
	local valid = AntiExploit.ValidateRemoteCall(player, "BuyItem")
	if not valid then return end
	
	if type(itemId) ~= "string" then return end
	
	local itemConfig = GameConfig.GetEquipmentById(itemId)
	if not itemConfig then
		NotificationEvent:FireClient(player, {Type = "Error", Message = "Item not found"})
		return
	end
	
	local data = DataStoreManager.GetData(player)
	if not data then return end
	
	if data.Money < itemConfig.Price then
		NotificationEvent:FireClient(player, {Type = "Error", Message = "Not enough money"})
		return
	end
	
	DataStoreManager.AddMoney(player, -itemConfig.Price)
	table.insert(data.Inventory, {
		Id = itemId,
		UUID = game:GetService("HttpService"):GenerateGUID(false),
		Equipped = false,
		EquippedTo = nil,
	})
	
	PlayerDataUpdateEvent:FireClient(player, data)
	NotificationEvent:FireClient(player, {
		Type = "Success",
		Message = "Purchased " .. itemConfig.Name .. " for $" .. itemConfig.Price,
	})
end)

-- Get Shop Items
GetShopItemsFunc.OnServerInvoke = function(player)
	local valid = AntiExploit.ValidateRemoteCall(player, "GetShopItems")
	if not valid then return nil end
	
	return GameConfig.Equipment
end

-- Get Creature Info
GetCreatureInfoFunc.OnServerInvoke = function(player, creatureUUID)
	local valid = AntiExploit.ValidateRemoteCall(player, "GetCreatureInfo")
	if not valid then return nil end
	
	local creature, cType = DataStoreManager.GetCreatureByUUID(player, creatureUUID)
	if not creature then return nil end
	
	return {Creature = creature, Type = cType}
end

-- Trade Request
TradeRequestEvent.OnServerEvent:Connect(function(player, targetPlayerName)
	local valid = AntiExploit.ValidateRemoteCall(player, "TradeRequest")
	if not valid then return end
	
	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then
		NotificationEvent:FireClient(player, {Type = "Error", Message = "Player not found"})
		return
	end
	
	local success, result = TradeManager.SendTradeRequest(player.UserId, targetPlayer.UserId)
	if success then
		NotificationEvent:FireClient(player, {Type = "Info", Message = "Trade request sent to " .. targetPlayerName})
		TradeUpdateEvent:FireClient(targetPlayer, {
			Action = "TradeRequest",
			FromPlayer = player.Name,
			RequestId = result,
		})
	else
		NotificationEvent:FireClient(player, {Type = "Error", Message = result})
	end
end)

-- Trade Action (accept, decline, update offer, confirm)
TradeActionEvent.OnServerEvent:Connect(function(player, action, ...)
	local valid = AntiExploit.ValidateRemoteCall(player, "TradeAction")
	if not valid then return end
	
	local args = {...}
	
	if action == "Accept" then
		local requestId = args[1]
		if type(requestId) ~= "string" then return end
		local success, msg = TradeManager.AcceptTradeRequest(player.UserId, requestId)
		if success then
			local trade = TradeManager.GetTradeInfo(requestId)
			if trade then
				local otherPlayer = Players:GetPlayerByUserId(trade.Player1)
				if otherPlayer then
					TradeUpdateEvent:FireClient(otherPlayer, {Action = "TradeAccepted"})
				end
				TradeUpdateEvent:FireClient(player, {Action = "TradeStarted", Trade = trade})
			end
		end
		
	elseif action == "Decline" then
		local requestId = args[1]
		if type(requestId) ~= "string" then return end
		TradeManager.DeclineTradeRequest(player.UserId, requestId)
		
	elseif action == "UpdateOffer" then
		local trade = TradeManager.GetPlayerTrade(player.UserId)
		if trade then
			local offerData = args[1]
			if type(offerData) ~= "table" then return end
			TradeManager.UpdateOffer(player.UserId, trade.Id, offerData)
			-- Notify other player
			local otherId = trade.Player1 == player.UserId and trade.Player2 or trade.Player1
			local otherPlayer = Players:GetPlayerByUserId(otherId)
			if otherPlayer then
				TradeUpdateEvent:FireClient(otherPlayer, {Action = "OfferUpdated", Trade = trade})
			end
		end
		
	elseif action == "Confirm" then
		local trade = TradeManager.GetPlayerTrade(player.UserId)
		if trade then
			local success, status = TradeManager.ConfirmOffer(player.UserId, trade.Id)
			if success and status == "BothConfirmed" then
				local execSuccess, execMsg = TradeManager.ExecuteTrade(trade.Id, DataStoreManager)
				if execSuccess then
					local p1 = Players:GetPlayerByUserId(trade.Player1)
					local p2 = Players:GetPlayerByUserId(trade.Player2)
					if p1 then
						PlayerDataUpdateEvent:FireClient(p1, DataStoreManager.GetData(p1))
						NotificationEvent:FireClient(p1, {Type = "Success", Message = "Trade completed!"})
					end
					if p2 then
						PlayerDataUpdateEvent:FireClient(p2, DataStoreManager.GetData(p2))
						NotificationEvent:FireClient(p2, {Type = "Success", Message = "Trade completed!"})
					end
				end
			end
		end
		
	elseif action == "Cancel" then
		local trade = TradeManager.GetPlayerTrade(player.UserId)
		if trade then
			TradeManager.CancelTrade(trade.Id)
			local otherId = trade.Player1 == player.UserId and trade.Player2 or trade.Player1
			local otherPlayer = Players:GetPlayerByUserId(otherId)
			if otherPlayer then
				TradeUpdateEvent:FireClient(otherPlayer, {Action = "TradeCancelled"})
				NotificationEvent:FireClient(otherPlayer, {Type = "Info", Message = "Trade cancelled"})
			end
		end
	end
end)

-- ============================================================
-- EVENT SCHEDULER (Main Game Loop)
-- ============================================================
local function getNextEventType()
	gameState.EventIndex = gameState.EventIndex + 1
	if gameState.EventIndex > #gameState.EventQueue then
		gameState.EventIndex = 1
		-- Shuffle the queue for variety
		for i = #gameState.EventQueue, 2, -1 do
			local j = math.random(i)
			gameState.EventQueue[i], gameState.EventQueue[j] = gameState.EventQueue[j], gameState.EventQueue[i]
		end
	end
	return gameState.EventQueue[gameState.EventIndex]
end

local function gatherPlayerCreatures(creatureType)
	local creatures = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataStoreManager.GetData(player)
		if data then
			local activeKey = "Active" .. creatureType
			local activeUUID = data[activeKey]
			if activeUUID then
				local creature = DataStoreManager.GetCreatureByUUID(player, activeUUID)
				if creature then
					table.insert(creatures, creature)
				end
			end
		end
	end
	return creatures
end

local function runEvent(eventType)
	gameState.EventType = eventType
	gameState.EventId = game:GetService("HttpService"):GenerateGUID(false)
	
	-- Determine betting options
	local bettingOptions = {}
	
	if eventType == "Fight" then
		-- Pick two monkeys to fight
		local monkeys = gatherPlayerCreatures("Monkey")
		
		-- Add NPC monkeys if not enough
		while #monkeys < 2 do
			local npcMonkey = {
				UUID = "NPC_" .. game:GetService("HttpService"):GenerateGUID(false),
				BaseId = GameConfig.Monkeys[math.random(#GameConfig.Monkeys)].Id,
				Nickname = "Wild " .. GameConfig.Monkeys[math.random(#GameConfig.Monkeys)].Name,
				Level = math.random(1, 20),
				XP = 0,
				Rarity = GameConfig.RollRarity(),
				EquippedItems = {},
				Stats = nil,
			}
			local config = GameConfig.GetMonkeyById(npcMonkey.BaseId)
			if config then
				npcMonkey.Stats = {
					HP = config.BaseHP + npcMonkey.Level * 5,
					Attack = config.BaseAttack + npcMonkey.Level * 2,
					Defense = config.BaseDefense + npcMonkey.Level * 1,
					Speed = config.BaseSpeed + npcMonkey.Level * 1,
					CritChance = config.BaseCritChance,
				}
				npcMonkey.Nickname = "Wild " .. config.Name
			end
			table.insert(monkeys, npcMonkey)
		end
		
		-- Select two fighters
		local idx1, idx2
		if #monkeys >= 2 then
			idx1 = math.random(#monkeys)
			repeat idx2 = math.random(#monkeys) until idx2 ~= idx1
		else
			idx1, idx2 = 1, 2
		end
		
		gameState.CurrentEvent = {monkeys[idx1], monkeys[idx2]}
		bettingOptions = {
			{Id = "fighter1", Name = monkeys[idx1].Nickname or "Fighter 1"},
			{Id = "fighter2", Name = monkeys[idx2].Nickname or "Fighter 2"},
		}
		
	elseif eventType == "CamelRace" then
		local camels = gatherPlayerCreatures("Camel")
		gameState.CurrentEvent = camels
		
		-- We'll know full racer list after NPC fill, for now use placeholder
		bettingOptions = {}
		for i = 1, math.max(6, #camels) do
			table.insert(bettingOptions, {
				Id = "lane" .. i,
				Name = "Lane " .. i,
			})
		end
		
	elseif eventType == "LobsterRace" then
		local lobsters = gatherPlayerCreatures("Lobster")
		gameState.CurrentEvent = lobsters
		
		bettingOptions = {}
		for i = 1, math.max(8, #lobsters) do
			table.insert(bettingOptions, {
				Id = "lane" .. i,
				Name = "Lane " .. i,
			})
		end
	end
	
	-- PHASE 1: Betting
	gameState.EventPhase = "Betting"
	BettingManager.OpenBettingPool(gameState.EventId, eventType, bettingOptions)
	
	-- Notify all players
	for _, player in ipairs(Players:GetPlayers()) do
		EventUpdateEvent:FireClient(player, {
			Phase = "Betting",
			EventType = eventType,
			EventId = gameState.EventId,
			Options = bettingOptions,
			Duration = GameConfig.Timing.BettingWindowDuration,
		})
	end
	
	-- Wait for betting window
	task.wait(GameConfig.Timing.BettingWindowDuration)
	
	-- Close betting
	BettingManager.CloseBetting(gameState.EventId)
	
	-- PHASE 2: Running the event
	gameState.EventPhase = "Running"
	
	for _, player in ipairs(Players:GetPlayers()) do
		EventUpdateEvent:FireClient(player, {
			Phase = "Running",
			EventType = eventType,
			EventId = gameState.EventId,
		})
	end
	
	local results
	
	if eventType == "Fight" then
		results = CombatAI.RunFight(gameState.CurrentEvent[1], gameState.CurrentEvent[2])
		
		-- Send fight results with round-by-round replay data
		for _, player in ipairs(Players:GetPlayers()) do
			FightUpdateEvent:FireClient(player, results)
		end
		
		-- Wait for the fight to be "watched"
		local watchTime = results.TotalRounds * GameConfig.Timing.FightRoundDelay
		task.wait(watchTime)
		
	elseif eventType == "CamelRace" or eventType == "LobsterRace" then
		local raceType = eventType == "CamelRace" and "Camel" or "Lobster"
		results = RacingAI.RunRace(raceType, gameState.CurrentEvent)
		
		-- Send race results with replay snapshots
		for _, player in ipairs(Players:GetPlayers()) do
			RaceUpdateEvent:FireClient(player, results)
		end
		
		-- Wait for race duration
		task.wait(results.TotalTime or GameConfig.Timing.RaceDuration)
	end
	
	-- PHASE 3: Results
	gameState.EventPhase = "Results"
	gameState.EventResults = results
	
	-- Resolve bets
	local winningOption
	if eventType == "Fight" then
		winningOption = results.Winner == "Fighter 1" and "fighter1" or "fighter2"
	else
		if results.Winner then
			winningOption = "lane" .. results.Winner.Lane
		end
	end
	
	if winningOption then
		local betResults = BettingManager.ResolveBets(gameState.EventId, winningOption)
		
		if betResults then
			-- Pay winners
			for _, winner in ipairs(betResults.Winners) do
				local winPlayer = Players:GetPlayerByUserId(winner.PlayerId)
				if winPlayer then
					DataStoreManager.AddMoney(winPlayer, winner.Payout)
					local data = DataStoreManager.GetData(winPlayer)
					if data then
						data.Stats.TotalBetsWon = (data.Stats.TotalBetsWon or 0) + 1
						data.Stats.TotalMoneyWon = (data.Stats.TotalMoneyWon or 0) + winner.Payout
						PlayerDataUpdateEvent:FireClient(winPlayer, data)
					end
					NotificationEvent:FireClient(winPlayer, {
						Type = "BigWin",
						Message = "You won $" .. winner.Payout .. "!",
					})
				end
			end
			
			-- Notify losers
			for _, loser in ipairs(betResults.Losers) do
				local losePlayer = Players:GetPlayerByUserId(loser.PlayerId)
				if losePlayer then
					local data = DataStoreManager.GetData(losePlayer)
					if data then
						data.Stats.TotalMoneyLost = (data.Stats.TotalMoneyLost or 0) + loser.BetAmount
						PlayerDataUpdateEvent:FireClient(losePlayer, data)
					end
					NotificationEvent:FireClient(losePlayer, {
						Type = "Loss",
						Message = "You lost your bet of $" .. loser.BetAmount,
					})
				end
			end
		end
	end
	
	-- XP rewards for participating creatures
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataStoreManager.GetData(player)
		if data then
			local activeKey
			if eventType == "Fight" then activeKey = "ActiveMonkey"
			elseif eventType == "CamelRace" then activeKey = "ActiveCamel"
			else activeKey = "ActiveLobster" end
			
			if data[activeKey] then
				local xpReward = 20 + math.random(0, 10)
				DataStoreManager.AddXP(player, data[activeKey], xpReward)
			end
		end
	end
	
	-- Broadcast results
	for _, player in ipairs(Players:GetPlayers()) do
		EventUpdateEvent:FireClient(player, {
			Phase = "Results",
			EventType = eventType,
			EventId = gameState.EventId,
			Results = results,
		})
	end
	
	task.wait(10) -- Show results for 10 seconds
	
	-- Reset
	gameState.EventPhase = "Idle"
	gameState.CurrentEvent = nil
	gameState.EventResults = nil
	BettingManager.Cleanup()
end

-- ============================================================
-- MAIN GAME LOOP
-- ============================================================
task.spawn(function()
	-- Initialize auto-fix system
	AutoFix.Start()
	
	-- Start auto-save
	DataStoreManager.StartAutoSave()
	
	-- Wait for initial setup
	task.wait(5)
	
	print("[Arena Bestial] Game server started!")
	
	while true do
		-- Wait between events
		for _, player in ipairs(Players:GetPlayers()) do
			EventUpdateEvent:FireClient(player, {
				Phase = "Idle",
				NextEventIn = GameConfig.Timing.TimeBetweenEvents,
			})
		end
		
		task.wait(GameConfig.Timing.TimeBetweenEvents)
		
		-- Run next event
		local eventType = getNextEventType()
		
		local success, err = pcall(function()
			runEvent(eventType)
		end)
		
		if not success then
			warn("[Arena Bestial] Event error: " .. tostring(err))
			gameState.EventPhase = "Idle"
			task.wait(5)
		end
		
		-- Periodic cleanup
		TradeManager.CleanupExpired()
		AntiExploit.CleanupOldData()
	end
end)

print("[Arena Bestial] Server script loaded!")
