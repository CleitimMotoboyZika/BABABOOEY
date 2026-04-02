-- DataStoreManager: Handles all data persistence with server-side validation
-- Saves player inventory, creatures, equipment, currency, and progress

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

local DataStoreManager = {}
DataStoreManager.__index = DataStoreManager

local DATA_STORE_NAME = "ArenaBestial_v1"
local SESSION_LOCK_NAME = "ArenaBestial_SessionLock_v1"
local playerDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local sessionLockStore = DataStoreService:GetDataStore(SESSION_LOCK_NAME)

-- In-memory cache of player data
local playerDataCache = {}
local dataLoadedSignals = {}
local saveLock = {}

-- ============================================================
-- DEFAULT DATA TEMPLATE
-- ============================================================
local function getDefaultData()
	return {
		Version = 1,
		Money = GameConfig.Currency.StartingMoney,
		
		-- Owned creatures (list of creature instances)
		Monkeys = {},
		Camels = {},
		Lobsters = {},
		
		-- Inventory of equipment items
		Inventory = {},
		
		-- Currently equipped items per creature slot
		EquippedItems = {},
		
		-- Active creatures for each event type
		ActiveMonkey = nil,
		ActiveCamel = nil,
		ActiveLobster = nil,
		
		-- Statistics
		Stats = {
			TotalBetsPlaced = 0,
			TotalBetsWon = 0,
			TotalMoneyWon = 0,
			TotalMoneyLost = 0,
			TotalFightsWatched = 0,
			TotalRacesWatched = 0,
			TotalTradesCompleted = 0,
		},
		
		-- Timestamps
		LastLogin = 0,
		TotalPlayTime = 0,
		CreatedAt = 0,
	}
end

-- ============================================================
-- CREATE CREATURE INSTANCE
-- ============================================================
local function createCreatureInstance(creatureId, creatureType)
	local configData
	if creatureType == "Monkey" then
		configData = GameConfig.GetMonkeyById(creatureId)
	elseif creatureType == "Camel" then
		configData = GameConfig.GetCamelById(creatureId)
	elseif creatureType == "Lobster" then
		configData = GameConfig.GetLobsterById(creatureId)
	end
	
	if not configData then return nil end
	
	local instance = {
		UUID = game:GetService("HttpService"):GenerateGUID(false),
		BaseId = creatureId,
		Nickname = configData.Name,
		Level = 1,
		XP = 0,
		Rarity = configData.Rarity,
		EquippedItems = {},
		CreatedAt = os.time(),
	}
	
	-- Copy base stats
	if creatureType == "Monkey" then
		instance.Stats = {
			HP = configData.BaseHP,
			Attack = configData.BaseAttack,
			Defense = configData.BaseDefense,
			Speed = configData.BaseSpeed,
			CritChance = configData.BaseCritChance,
		}
	else
		instance.Stats = {
			Speed = configData.BaseSpeed,
			Stamina = configData.BaseStamina,
			Acceleration = configData.BaseAcceleration,
			Luck = configData.BaseLuck,
		}
	end
	
	return instance
end

-- ============================================================
-- DATA VALIDATION
-- ============================================================
local function validateData(data)
	local default = getDefaultData()
	
	-- Ensure all fields exist
	for key, value in pairs(default) do
		if data[key] == nil then
			data[key] = value
		end
	end
	
	-- Validate money bounds
	data.Money = math.clamp(data.Money, 0, GameConfig.Currency.MaxMoney)
	
	-- Ensure Stats subtable is complete
	for key, value in pairs(default.Stats) do
		if data.Stats[key] == nil then
			data.Stats[key] = value
		end
	end
	
	-- Validate creature data integrity
	local function validateCreatureList(list, getById)
		local validList = {}
		for _, creature in ipairs(list or {}) do
			if creature.UUID and creature.BaseId and getById(creature.BaseId) then
				table.insert(validList, creature)
			end
		end
		return validList
	end
	
	data.Monkeys = validateCreatureList(data.Monkeys, GameConfig.GetMonkeyById)
	data.Camels = validateCreatureList(data.Camels, GameConfig.GetCamelById)
	data.Lobsters = validateCreatureList(data.Lobsters, GameConfig.GetLobsterById)
	
	-- Validate inventory items
	local validInventory = {}
	for _, item in ipairs(data.Inventory or {}) do
		if item.Id and GameConfig.GetEquipmentById(item.Id) then
			table.insert(validInventory, item)
		end
	end
	data.Inventory = validInventory
	
	return data
end

-- ============================================================
-- LOAD PLAYER DATA
-- ============================================================
function DataStoreManager.LoadPlayerData(player)
	local userId = tostring(player.UserId)
	
	-- Check session lock
	local success, lockData = pcall(function()
		return sessionLockStore:GetAsync(userId)
	end)
	
	if success and lockData then
		local lockTime = lockData.Time or 0
		local jobId = lockData.JobId or ""
		-- If lock is from same server or expired (>5 min), allow
		if jobId ~= game.JobId and (os.time() - lockTime) < 300 then
			warn("[DataStore] Session locked for player " .. userId .. ", waiting...")
			task.wait(5)
		end
	end
	
	-- Set session lock
	pcall(function()
		sessionLockStore:SetAsync(userId, {
			JobId = game.JobId,
			Time = os.time()
		})
	end)
	
	local data
	local loadSuccess, loadError = pcall(function()
		data = playerDataStore:GetAsync(userId)
	end)
	
	if not loadSuccess then
		warn("[DataStore] Failed to load data for " .. userId .. ": " .. tostring(loadError))
		-- Use default data but flag as not saved
		data = getDefaultData()
		data.CreatedAt = os.time()
	end
	
	if not data then
		data = getDefaultData()
		data.CreatedAt = os.time()
		
		-- Give starter pack
		for _, monkeyId in ipairs(GameConfig.StarterPack.Monkeys) do
			local instance = createCreatureInstance(monkeyId, "Monkey")
			if instance then
				table.insert(data.Monkeys, instance)
				if not data.ActiveMonkey then
					data.ActiveMonkey = instance.UUID
				end
			end
		end
		
		for _, camelId in ipairs(GameConfig.StarterPack.Camels) do
			local instance = createCreatureInstance(camelId, "Camel")
			if instance then
				table.insert(data.Camels, instance)
				if not data.ActiveCamel then
					data.ActiveCamel = instance.UUID
				end
			end
		end
		
		for _, lobsterId in ipairs(GameConfig.StarterPack.Lobsters) do
			local instance = createCreatureInstance(lobsterId, "Lobster")
			if instance then
				table.insert(data.Lobsters, instance)
				if not data.ActiveLobster then
					data.ActiveLobster = instance.UUID
				end
			end
		end
		
		for _, eqId in ipairs(GameConfig.StarterPack.Equipment) do
			local eqData = GameConfig.GetEquipmentById(eqId)
			if eqData then
				table.insert(data.Inventory, {
					Id = eqId,
					UUID = game:GetService("HttpService"):GenerateGUID(false),
					Equipped = false,
					EquippedTo = nil,
				})
			end
		end
	end
	
	data.LastLogin = os.time()
	data = validateData(data)
	playerDataCache[userId] = data
	
	return data
end

-- ============================================================
-- SAVE PLAYER DATA
-- ============================================================
function DataStoreManager.SavePlayerData(player)
	local userId = tostring(player.UserId)
	local data = playerDataCache[userId]
	
	if not data then
		warn("[DataStore] No data in cache for " .. userId)
		return false
	end
	
	if saveLock[userId] then
		return false
	end
	
	saveLock[userId] = true
	
	local success, err = pcall(function()
		data.TotalPlayTime = data.TotalPlayTime + (os.time() - data.LastLogin)
		data.LastLogin = os.time()
		playerDataStore:SetAsync(userId, data)
	end)
	
	saveLock[userId] = nil
	
	if not success then
		warn("[DataStore] Failed to save data for " .. userId .. ": " .. tostring(err))
		return false
	end
	
	return true
end

-- ============================================================
-- GET CACHED DATA (for server scripts to read)
-- ============================================================
function DataStoreManager.GetData(player)
	return playerDataCache[tostring(player.UserId)]
end

-- ============================================================
-- MODIFY MONEY (with validation)
-- ============================================================
function DataStoreManager.AddMoney(player, amount)
	local data = DataStoreManager.GetData(player)
	if not data then return false end
	
	if type(amount) ~= "number" or amount ~= amount then return false end -- NaN check
	
	amount = math.floor(amount)
	if math.abs(amount) > GameConfig.Security.MaxMoneyPerTransaction then
		warn("[Security] Excessive money transaction blocked for " .. player.Name)
		return false
	end
	
	local newMoney = data.Money + amount
	newMoney = math.clamp(newMoney, 0, GameConfig.Currency.MaxMoney)
	data.Money = newMoney
	
	return true, newMoney
end

-- ============================================================
-- CREATURE MANAGEMENT
-- ============================================================
function DataStoreManager.AddCreature(player, creatureId, creatureType)
	local data = DataStoreManager.GetData(player)
	if not data then return false end
	
	local instance = createCreatureInstance(creatureId, creatureType)
	if not instance then return false end
	
	local listKey
	if creatureType == "Monkey" then listKey = "Monkeys"
	elseif creatureType == "Camel" then listKey = "Camels"
	elseif creatureType == "Lobster" then listKey = "Lobsters"
	else return false end
	
	table.insert(data[listKey], instance)
	return true, instance
end

function DataStoreManager.RemoveCreature(player, uuid, creatureType)
	local data = DataStoreManager.GetData(player)
	if not data then return false end
	
	local listKey
	if creatureType == "Monkey" then listKey = "Monkeys"
	elseif creatureType == "Camel" then listKey = "Camels"
	elseif creatureType == "Lobster" then listKey = "Lobsters"
	else return false end
	
	for i, creature in ipairs(data[listKey]) do
		if creature.UUID == uuid then
			table.remove(data[listKey], i)
			
			-- Clear active if this was active
			local activeKey = "Active" .. creatureType
			if data[activeKey] == uuid then
				data[activeKey] = nil
			end
			
			return true
		end
	end
	
	return false
end

function DataStoreManager.GetCreatureByUUID(player, uuid)
	local data = DataStoreManager.GetData(player)
	if not data then return nil end
	
	for _, monkey in ipairs(data.Monkeys) do
		if monkey.UUID == uuid then return monkey, "Monkey" end
	end
	for _, camel in ipairs(data.Camels) do
		if camel.UUID == uuid then return camel, "Camel" end
	end
	for _, lobster in ipairs(data.Lobsters) do
		if lobster.UUID == uuid then return lobster, "Lobster" end
	end
	
	return nil
end

-- ============================================================
-- EQUIPMENT MANAGEMENT
-- ============================================================
function DataStoreManager.EquipItem(player, itemUUID, creatureUUID)
	local data = DataStoreManager.GetData(player)
	if not data then return false, "No data" end
	
	-- Find item in inventory
	local item
	for _, inv in ipairs(data.Inventory) do
		if inv.UUID == itemUUID then
			item = inv
			break
		end
	end
	
	if not item then return false, "Item not found" end
	
	local itemConfig = GameConfig.GetEquipmentById(item.Id)
	if not itemConfig then return false, "Invalid item" end
	
	-- Find creature
	local creature, creatureType = DataStoreManager.GetCreatureByUUID(player, creatureUUID)
	if not creature then return false, "Creature not found" end
	
	-- Validate item type matches creature type
	if itemConfig.Type ~= creatureType then
		return false, "Item type mismatch"
	end
	
	-- Unequip any item in the same slot
	local slot = itemConfig.Slot
	for _, inv in ipairs(data.Inventory) do
		if inv.Equipped and inv.EquippedTo == creatureUUID then
			local invConfig = GameConfig.GetEquipmentById(inv.Id)
			if invConfig and invConfig.Slot == slot then
				inv.Equipped = false
				inv.EquippedTo = nil
				-- Remove from creature's equipped items
				creature.EquippedItems[slot] = nil
			end
		end
	end
	
	-- Equip the new item
	item.Equipped = true
	item.EquippedTo = creatureUUID
	creature.EquippedItems[slot] = itemUUID
	
	return true
end

function DataStoreManager.UnequipItem(player, itemUUID)
	local data = DataStoreManager.GetData(player)
	if not data then return false end
	
	for _, inv in ipairs(data.Inventory) do
		if inv.UUID == itemUUID then
			if inv.Equipped and inv.EquippedTo then
				local creature = DataStoreManager.GetCreatureByUUID(player, inv.EquippedTo)
				if creature then
					local itemConfig = GameConfig.GetEquipmentById(inv.Id)
					if itemConfig then
						creature.EquippedItems[itemConfig.Slot] = nil
					end
				end
			end
			inv.Equipped = false
			inv.EquippedTo = nil
			return true
		end
	end
	
	return false
end

-- ============================================================
-- EVOLUTION / TRAINING
-- ============================================================
function DataStoreManager.AddXP(player, creatureUUID, xpAmount)
	local data = DataStoreManager.GetData(player)
	if not data then return false end
	
	local creature, creatureType = DataStoreManager.GetCreatureByUUID(player, creatureUUID)
	if not creature then return false end
	
	creature.XP = creature.XP + xpAmount
	local levelsGained = 0
	
	while creature.Level < GameConfig.Evolution.MaxLevel do
		local required = GameConfig.CalculateXPForLevel(creature.Level)
		if creature.XP >= required then
			creature.XP = creature.XP - required
			creature.Level = creature.Level + 1
			levelsGained = levelsGained + 1
			
			-- Apply stat gains
			if creatureType == "Monkey" then
				local gains = GameConfig.Evolution.StatGainPerLevel
				creature.Stats.HP = creature.Stats.HP + gains.HP
				creature.Stats.Attack = creature.Stats.Attack + gains.Attack
				creature.Stats.Defense = creature.Stats.Defense + gains.Defense
				creature.Stats.Speed = creature.Stats.Speed + gains.Speed
			else
				creature.Stats.Speed = creature.Stats.Speed + 0.5
				creature.Stats.Stamina = creature.Stats.Stamina + 2
				creature.Stats.Acceleration = creature.Stats.Acceleration + 0.3
			end
		else
			break
		end
	end
	
	return true, levelsGained
end

function DataStoreManager.TrainCreature(player, creatureUUID)
	local data = DataStoreManager.GetData(player)
	if not data then return false, "No data" end
	
	local creature = DataStoreManager.GetCreatureByUUID(player, creatureUUID)
	if not creature then return false, "Creature not found" end
	
	local cost = GameConfig.CalculateTrainingCost(creature.Level)
	if data.Money < cost then return false, "Not enough money" end
	
	data.Money = data.Money - cost
	local xpGain = math.floor(GameConfig.CalculateXPForLevel(creature.Level) * 0.3)
	local success, levelsGained = DataStoreManager.AddXP(player, creatureUUID, xpGain)
	
	return success, levelsGained, cost, xpGain
end

-- ============================================================
-- SET ACTIVE CREATURE
-- ============================================================
function DataStoreManager.SetActiveCreature(player, creatureUUID, creatureType)
	local data = DataStoreManager.GetData(player)
	if not data then return false end
	
	-- Verify creature exists
	local creature = DataStoreManager.GetCreatureByUUID(player, creatureUUID)
	if not creature then return false end
	
	local activeKey = "Active" .. creatureType
	data[activeKey] = creatureUUID
	
	return true
end

-- ============================================================
-- CLEANUP ON PLAYER LEAVE
-- ============================================================
function DataStoreManager.OnPlayerRemoving(player)
	local userId = tostring(player.UserId)
	
	DataStoreManager.SavePlayerData(player)
	
	-- Release session lock
	pcall(function()
		sessionLockStore:RemoveAsync(userId)
	end)
	
	playerDataCache[userId] = nil
end

-- ============================================================
-- AUTO-SAVE LOOP
-- ============================================================
function DataStoreManager.StartAutoSave()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Timing.AutoSaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					DataStoreManager.SavePlayerData(player)
				end)
			end
		end
	end)
end

return DataStoreManager
