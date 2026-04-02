-- AutoFixSystem: Self-healing server system that monitors and fixes common issues
-- Runs diagnostics and applies patches automatically during runtime

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoFix = {}
AutoFix.__index = AutoFix

local fixLog = {}
local diagnosticInterval = 30 -- Run diagnostics every 30 seconds
local lastDiagnostic = 0

-- ============================================================
-- DIAGNOSTIC CHECKS
-- ============================================================
local diagnostics = {}

-- Check 1: Verify all RemoteEvents exist
diagnostics.RemoteEvents = function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		AutoFix._Log("Created missing Remotes folder")
		return true
	end
	
	local requiredRemotes = {
		"PlaceBet", "GetBettingInfo", "EventUpdate", "FightUpdate",
		"RaceUpdate", "TradeRequest", "TradeUpdate", "TradeAction",
		"EquipItem", "UnequipItem", "SetActiveCreature", "TrainCreature",
		"BuyItem", "PlayerDataUpdate", "Notification", "GetPlayerData",
		"GetShopItems", "GetCreatureInfo",
	}
	
	local fixed = false
	for _, remoteName in ipairs(requiredRemotes) do
		if not remotes:FindFirstChild(remoteName) then
			-- Determine if it should be an Event or Function
			local isFunction = remoteName == "GetPlayerData" 
				or remoteName == "GetShopItems"
				or remoteName == "GetCreatureInfo"
				or remoteName == "GetBettingInfo"
			
			if isFunction then
				local rf = Instance.new("RemoteFunction")
				rf.Name = remoteName
				rf.Parent = remotes
			else
				local re = Instance.new("RemoteEvent")
				re.Name = remoteName
				re.Parent = remotes
			end
			AutoFix._Log("Created missing remote: " .. remoteName)
			fixed = true
		end
	end
	return fixed
end

-- Check 2: Verify player data integrity
diagnostics.PlayerData = function()
	local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
	local fixed = false
	
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataStoreManager.GetData(player)
		if not data then
			-- Attempt to reload data
			pcall(function()
				DataStoreManager.LoadPlayerData(player)
				AutoFix._Log("Reloaded data for " .. player.Name)
				fixed = true
			end)
		else
			-- Check for corrupted values
			if type(data.Money) ~= "number" or data.Money ~= data.Money then
				data.Money = 500
				AutoFix._Log("Fixed corrupted money for " .. player.Name)
				fixed = true
			end
			
			if data.Money < 0 then
				data.Money = 0
				AutoFix._Log("Fixed negative money for " .. player.Name)
				fixed = true
			end
			
			-- Ensure tables exist
			if type(data.Monkeys) ~= "table" then
				data.Monkeys = {}
				AutoFix._Log("Fixed missing Monkeys table for " .. player.Name)
				fixed = true
			end
			if type(data.Camels) ~= "table" then
				data.Camels = {}
				AutoFix._Log("Fixed missing Camels table for " .. player.Name)
				fixed = true
			end
			if type(data.Lobsters) ~= "table" then
				data.Lobsters = {}
				AutoFix._Log("Fixed missing Lobsters table for " .. player.Name)
				fixed = true
			end
			if type(data.Inventory) ~= "table" then
				data.Inventory = {}
				AutoFix._Log("Fixed missing Inventory for " .. player.Name)
				fixed = true
			end
			if type(data.Stats) ~= "table" then
				data.Stats = {
					TotalBetsPlaced = 0, TotalBetsWon = 0,
					TotalMoneyWon = 0, TotalMoneyLost = 0,
					TotalFightsWatched = 0, TotalRacesWatched = 0,
					TotalTradesCompleted = 0,
				}
				AutoFix._Log("Fixed missing Stats for " .. player.Name)
				fixed = true
			end
		end
	end
	return fixed
end

-- Check 3: Verify workspace objects
diagnostics.Workspace = function()
	local fixed = false
	
	-- Check spawn location exists
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if not spawn then
		local part = Instance.new("SpawnLocation")
		part.Name = "SpawnLocation"
		part.Size = Vector3.new(20, 1, 20)
		part.Position = Vector3.new(250, 5, 250)
		part.Anchored = true
		part.Material = Enum.Material.SmoothPlastic
		part.BrickColor = BrickColor.new("Medium stone grey")
		part.Parent = workspace
		AutoFix._Log("Created missing SpawnLocation")
		fixed = true
	end
	
	return fixed
end

-- Check 4: Memory leak detection
diagnostics.MemoryCheck = function()
	local fixed = false
	
	-- Clean up any orphaned instances in ReplicatedStorage
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		for _, child in ipairs(remotes:GetChildren()) do
			if not child:IsA("RemoteEvent") and not child:IsA("RemoteFunction") then
				child:Destroy()
				AutoFix._Log("Cleaned orphaned instance in Remotes: " .. child.Name)
				fixed = true
			end
		end
	end
	
	return fixed
end

-- Check 5: Creature data integrity
diagnostics.CreatureIntegrity = function()
	local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
	local fixed = false
	
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataStoreManager.GetData(player)
		if data then
			-- Fix creatures with invalid levels
			local function fixCreatures(list, maxLevel)
				for _, creature in ipairs(list) do
					if type(creature.Level) ~= "number" or creature.Level < 1 then
						creature.Level = 1
						fixed = true
						AutoFix._Log("Fixed invalid creature level for " .. player.Name)
					end
					if creature.Level > maxLevel then
						creature.Level = maxLevel
						fixed = true
						AutoFix._Log("Capped creature level for " .. player.Name)
					end
					if type(creature.XP) ~= "number" or creature.XP < 0 then
						creature.XP = 0
						fixed = true
					end
					if not creature.UUID then
						creature.UUID = game:GetService("HttpService"):GenerateGUID(false)
						fixed = true
						AutoFix._Log("Generated missing UUID for creature of " .. player.Name)
					end
				end
			end
			
			fixCreatures(data.Monkeys, GameConfig.Evolution.MaxLevel)
			fixCreatures(data.Camels, GameConfig.Evolution.MaxLevel)
			fixCreatures(data.Lobsters, GameConfig.Evolution.MaxLevel)
		end
	end
	
	return fixed
end

-- ============================================================
-- LOGGING
-- ============================================================
function AutoFix._Log(message)
	local entry = {
		Time = os.time(),
		Message = message,
	}
	table.insert(fixLog, entry)
	print("[AutoFix] " .. message)
	
	-- Keep log size manageable
	while #fixLog > 200 do
		table.remove(fixLog, 1)
	end
end

-- ============================================================
-- RUN DIAGNOSTICS
-- ============================================================
function AutoFix.RunDiagnostics()
	local totalFixes = 0
	
	for name, check in pairs(diagnostics) do
		local success, result = pcall(check)
		if success and result then
			totalFixes = totalFixes + 1
		elseif not success then
			AutoFix._Log("Diagnostic '" .. name .. "' failed: " .. tostring(result))
		end
	end
	
	if totalFixes > 0 then
		AutoFix._Log("Diagnostics complete. Applied " .. totalFixes .. " fixes.")
	end
	
	return totalFixes
end

-- ============================================================
-- START AUTO-FIX LOOP
-- ============================================================
function AutoFix.Start()
	AutoFix._Log("AutoFix system initialized")
	
	-- Run initial diagnostics
	AutoFix.RunDiagnostics()
	
	-- Periodic diagnostics
	task.spawn(function()
		while true do
			task.wait(diagnosticInterval)
			AutoFix.RunDiagnostics()
		end
	end)
end

-- ============================================================
-- GET FIX LOG
-- ============================================================
function AutoFix.GetLog()
	return fixLog
end

return AutoFix
