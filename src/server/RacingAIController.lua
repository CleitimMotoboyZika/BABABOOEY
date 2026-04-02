-- RacingAIController: AI system for camel and lobster races
-- Each racer has independent AI with stamina management and random events
-- Players are spectators only - AI controls all racers

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

local RacingAI = {}
RacingAI.__index = RacingAI

local activeRace = nil
local raceHistory = {}

-- ============================================================
-- RACE CREATION
-- ============================================================
function RacingAI.CreateRace(raceType, racerDataList)
	-- raceType: "Camel" or "Lobster"
	-- racerDataList: list of creature data from players or NPC
	
	local trackLength
	if raceType == "Camel" then
		trackLength = 1000 -- meters
	else
		trackLength = 100 -- table-top meters for lobsters
	end
	
	local race = {
		Id = game:GetService("HttpService"):GenerateGUID(false),
		Type = raceType,
		Status = "Preparing",
		TrackLength = trackLength,
		ElapsedTime = 0,
		MaxTime = GameConfig.Timing.RaceDuration,
		
		Racers = {},
		Log = {},
		Winner = nil,
		Positions = {},
		StartTime = os.time(),
	}
	
	-- Create racer instances
	for i, data in ipairs(racerDataList) do
		local racer = RacingAI._CreateRacer(data, raceType, i)
		if racer then
			table.insert(race.Racers, racer)
		end
	end
	
	-- Fill empty lanes with NPC racers
	local minRacers = raceType == "Camel" and 6 or 8
	while #race.Racers < minRacers do
		local npcRacer = RacingAI._CreateNPCRacer(raceType, #race.Racers + 1)
		table.insert(race.Racers, npcRacer)
	end
	
	activeRace = race
	return race
end

function RacingAI._CreateRacer(creatureData, raceType, lane)
	local configData
	if raceType == "Camel" then
		configData = GameConfig.GetCamelById(creatureData.BaseId)
	else
		configData = GameConfig.GetLobsterById(creatureData.BaseId)
	end
	
	if not configData then return nil end
	
	local rarityData = GameConfig.Rarities[creatureData.Rarity]
	local multiplier = rarityData and rarityData.Multiplier or 1.0
	
	return {
		Lane = lane,
		Name = creatureData.Nickname or configData.Name,
		BaseId = creatureData.BaseId,
		Rarity = creatureData.Rarity,
		Level = creatureData.Level or 1,
		IsNPC = false,
		UUID = creatureData.UUID,
		
		-- Racing stats
		MaxSpeed = creatureData.Stats.Speed * multiplier,
		CurrentSpeed = 0,
		Acceleration = creatureData.Stats.Acceleration * multiplier,
		Stamina = creatureData.Stats.Stamina * multiplier,
		MaxStamina = creatureData.Stats.Stamina * multiplier,
		Luck = creatureData.Stats.Luck,
		
		-- Position tracking
		Position = 0, -- distance traveled
		Finished = false,
		FinishTime = nil,
		
		-- AI personality (affects racing style)
		Personality = {
			BurstChance = 0.1 + math.random() * 0.2,
			StaminaConservation = 0.3 + math.random() * 0.4,
			RecoveryRate = 0.5 + math.random() * 0.5,
		}
	}
end

function RacingAI._CreateNPCRacer(raceType, lane)
	local creatures
	if raceType == "Camel" then
		creatures = GameConfig.Camels
	else
		creatures = GameConfig.Lobsters
	end
	
	-- Pick a random creature, weighted toward common
	local rarity = GameConfig.RollRarity()
	local candidates = {}
	for _, c in ipairs(creatures) do
		if c.Rarity == rarity then
			table.insert(candidates, c)
		end
	end
	if #candidates == 0 then
		candidates = {creatures[1]} -- fallback to first
	end
	
	local chosen = candidates[math.random(#candidates)]
	local level = math.random(1, 30)
	
	local npcNames = {
		"Thunder", "Lightning", "Storm", "Blaze", "Shadow",
		"Rocket", "Bullet", "Flash", "Nitro", "Turbo",
		"Phantom", "Ghost", "Spirit", "Fury", "Rage",
	}
	
	return {
		Lane = lane,
		Name = npcNames[math.random(#npcNames)] .. " " .. chosen.Name,
		BaseId = chosen.Id,
		Rarity = chosen.Rarity,
		Level = level,
		IsNPC = true,
		UUID = "NPC_" .. lane,
		
		MaxSpeed = chosen.BaseSpeed + (level * 0.5),
		CurrentSpeed = 0,
		Acceleration = chosen.BaseAcceleration + (level * 0.3),
		Stamina = chosen.BaseStamina + (level * 2),
		MaxStamina = chosen.BaseStamina + (level * 2),
		Luck = chosen.BaseLuck,
		
		Position = 0,
		Finished = false,
		FinishTime = nil,
		
		Personality = {
			BurstChance = 0.1 + math.random() * 0.2,
			StaminaConservation = 0.3 + math.random() * 0.4,
			RecoveryRate = 0.5 + math.random() * 0.5,
		}
	}
end

-- ============================================================
-- RACE SIMULATION (tick-based)
-- ============================================================
function RacingAI._SimulateTick(race, dt)
	race.ElapsedTime = race.ElapsedTime + dt
	
	local allFinished = true
	
	for _, racer in ipairs(race.Racers) do
		if not racer.Finished then
			allFinished = false
			RacingAI._UpdateRacer(racer, race, dt)
		end
	end
	
	-- Update positions/rankings
	RacingAI._UpdatePositions(race)
	
	-- Check if race is over
	if allFinished or race.ElapsedTime >= race.MaxTime then
		race.Status = "Finished"
		RacingAI._DetermineResults(race)
	end
end

function RacingAI._UpdateRacer(racer, race, dt)
	-- AI decision: how hard to push
	local pushFactor = 0.7 -- default moderate push
	
	-- Check stamina situation
	local staminaPercent = racer.Stamina / racer.MaxStamina
	
	if staminaPercent < 0.2 then
		-- Low stamina, conserve
		pushFactor = 0.3
	elseif staminaPercent > 0.6 and racer.Position / race.TrackLength < 0.7 then
		-- Good stamina, early/mid race, moderate push
		pushFactor = 0.6 + racer.Personality.StaminaConservation * 0.2
	elseif racer.Position / race.TrackLength > 0.8 then
		-- Final stretch! Go all out
		pushFactor = 0.9 + math.random() * 0.1
	end
	
	-- Burst of speed (random event)
	if math.random() < racer.Personality.BurstChance * dt then
		pushFactor = 1.0
		table.insert(race.Log, {
			Time = race.ElapsedTime,
			Racer = racer.Name,
			Event = "Burst",
			Message = racer.Name .. " surges forward with a burst of speed!",
		})
	end
	
	-- Lucky event
	if math.random() < racer.Luck * dt then
		racer.CurrentSpeed = racer.CurrentSpeed + racer.MaxSpeed * 0.1
		table.insert(race.Log, {
			Time = race.ElapsedTime,
			Racer = racer.Name,
			Event = "Lucky",
			Message = racer.Name .. " gets a lucky boost!",
		})
	end
	
	-- Stumble event (bad luck)
	if math.random() < 0.02 * dt then
		racer.CurrentSpeed = racer.CurrentSpeed * 0.5
		table.insert(race.Log, {
			Time = race.ElapsedTime,
			Racer = racer.Name,
			Event = "Stumble",
			Message = racer.Name .. " stumbles!",
		})
	end
	
	-- Calculate target speed
	local targetSpeed = racer.MaxSpeed * pushFactor
	
	-- Accelerate toward target speed
	if racer.CurrentSpeed < targetSpeed then
		racer.CurrentSpeed = math.min(targetSpeed,
			racer.CurrentSpeed + racer.Acceleration * dt * pushFactor)
	else
		racer.CurrentSpeed = math.max(targetSpeed,
			racer.CurrentSpeed - racer.Acceleration * 0.5 * dt)
	end
	
	-- Stamina consumption
	local staminaDrain = (racer.CurrentSpeed / racer.MaxSpeed) * 3 * dt
	racer.Stamina = math.max(0, racer.Stamina - staminaDrain)
	
	-- Stamina recovery when going slow
	if pushFactor < 0.5 then
		racer.Stamina = math.min(racer.MaxStamina,
			racer.Stamina + racer.Personality.RecoveryRate * dt)
	end
	
	-- If stamina is 0, severe speed penalty
	if racer.Stamina <= 0 then
		racer.CurrentSpeed = racer.MaxSpeed * 0.2
	end
	
	-- Update position
	racer.Position = racer.Position + racer.CurrentSpeed * dt
	
	-- Check if finished
	if racer.Position >= race.TrackLength then
		racer.Position = race.TrackLength
		racer.Finished = true
		racer.FinishTime = race.ElapsedTime
		table.insert(race.Log, {
			Time = race.ElapsedTime,
			Racer = racer.Name,
			Event = "Finish",
			Message = racer.Name .. " crosses the finish line!",
		})
	end
end

function RacingAI._UpdatePositions(race)
	-- Sort racers by position (descending)
	local sorted = {}
	for i, racer in ipairs(race.Racers) do
		sorted[i] = racer
	end
	
	table.sort(sorted, function(a, b)
		if a.Finished and b.Finished then
			return (a.FinishTime or 999) < (b.FinishTime or 999)
		elseif a.Finished then
			return true
		elseif b.Finished then
			return false
		else
			return a.Position > b.Position
		end
	end)
	
	race.Positions = {}
	for i, racer in ipairs(sorted) do
		race.Positions[racer.Lane] = i
	end
end

function RacingAI._DetermineResults(race)
	RacingAI._UpdatePositions(race)
	
	-- Find winner
	for _, racer in ipairs(race.Racers) do
		if race.Positions[racer.Lane] == 1 then
			race.Winner = racer
			break
		end
	end
	
	if not race.Winner and #race.Racers > 0 then
		-- Nobody finished, closest to finish wins
		local bestRacer = race.Racers[1]
		for _, racer in ipairs(race.Racers) do
			if racer.Position > bestRacer.Position then
				bestRacer = racer
			end
		end
		race.Winner = bestRacer
	end
end

-- ============================================================
-- RUN COMPLETE RACE
-- ============================================================
function RacingAI.RunRace(raceType, racerDataList)
	local race = RacingAI.CreateRace(raceType, racerDataList)
	race.Status = "InProgress"
	
	local tickRate = 0.1 -- 10 ticks per second
	local snapshots = {}
	
	while race.Status == "InProgress" do
		RacingAI._SimulateTick(race, tickRate)
		
		-- Create snapshot every 0.5 seconds for replay
		if math.floor(race.ElapsedTime / 0.5) > math.floor((race.ElapsedTime - tickRate) / 0.5) then
			local snapshot = {
				Time = race.ElapsedTime,
				Racers = {},
			}
			for _, racer in ipairs(race.Racers) do
				table.insert(snapshot.Racers, {
					Lane = racer.Lane,
					Name = racer.Name,
					Position = racer.Position,
					Speed = racer.CurrentSpeed,
					Stamina = racer.Stamina,
					MaxStamina = racer.MaxStamina,
					Finished = racer.Finished,
				})
			end
			table.insert(snapshots, snapshot)
		end
	end
	
	-- Build results
	local results = {
		RaceId = race.Id,
		Type = race.Type,
		TotalTime = race.ElapsedTime,
		TrackLength = race.TrackLength,
		
		Winner = race.Winner and {
			Lane = race.Winner.Lane,
			Name = race.Winner.Name,
			BaseId = race.Winner.BaseId,
			Rarity = race.Winner.Rarity,
			UUID = race.Winner.UUID,
			IsNPC = race.Winner.IsNPC,
			FinishTime = race.Winner.FinishTime,
		} or nil,
		
		FinalStandings = {},
		Snapshots = snapshots,
		Log = race.Log,
	}
	
	-- Sort racers by final position
	local sorted = {}
	for _, racer in ipairs(race.Racers) do
		table.insert(sorted, racer)
	end
	table.sort(sorted, function(a, b)
		return (race.Positions[a.Lane] or 999) < (race.Positions[b.Lane] or 999)
	end)
	
	for i, racer in ipairs(sorted) do
		table.insert(results.FinalStandings, {
			Place = i,
			Lane = racer.Lane,
			Name = racer.Name,
			BaseId = racer.BaseId,
			Rarity = racer.Rarity,
			UUID = racer.UUID,
			IsNPC = racer.IsNPC,
			FinishTime = racer.FinishTime,
			FinalPosition = racer.Position,
		})
	end
	
	-- Store in history
	table.insert(raceHistory, {
		Id = race.Id,
		Type = race.Type,
		Winner = race.Winner and race.Winner.Name or "Unknown",
		Time = os.time(),
	})
	while #raceHistory > 50 do
		table.remove(raceHistory, 1)
	end
	
	return results
end

function RacingAI.GetActiveRace()
	return activeRace
end

function RacingAI.GetRaceHistory()
	return raceHistory
end

return RacingAI
