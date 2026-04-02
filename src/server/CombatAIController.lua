-- CombatAIController: AI system for monkey fights
-- Controls both fighters independently, makes decisions based on stats and strategy
-- No player input during fights - players are spectators only

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

local CombatAI = {}
CombatAI.__index = CombatAI

-- ============================================================
-- FIGHT STATE
-- ============================================================
local activeFight = nil
local fightHistory = {}

function CombatAI.CreateFight(monkey1Data, monkey2Data)
	local fight = {
		Id = game:GetService("HttpService"):GenerateGUID(false),
		Status = "Preparing", -- Preparing, InProgress, Finished
		Round = 0,
		MaxRounds = GameConfig.Timing.FightMaxRounds,
		
		Fighter1 = CombatAI._CreateFighter(monkey1Data, "Fighter 1"),
		Fighter2 = CombatAI._CreateFighter(monkey2Data, "Fighter 2"),
		
		Log = {},
		Winner = nil,
		StartTime = os.time(),
	}
	
	activeFight = fight
	return fight
end

function CombatAI._CreateFighter(monkeyData, label)
	local configData = GameConfig.GetMonkeyById(monkeyData.BaseId)
	if not configData then return nil end
	
	-- Calculate total stats including equipment bonuses
	local totalAttack = monkeyData.Stats.Attack
	local totalDefense = monkeyData.Stats.Defense
	local totalSpeed = monkeyData.Stats.Speed
	local totalHP = monkeyData.Stats.HP
	local totalCrit = monkeyData.Stats.CritChance
	
	-- Apply rarity multiplier
	local rarityData = GameConfig.Rarities[monkeyData.Rarity]
	if rarityData then
		totalAttack = math.floor(totalAttack * rarityData.Multiplier)
		totalDefense = math.floor(totalDefense * rarityData.Multiplier)
		totalHP = math.floor(totalHP * rarityData.Multiplier)
	end
	
	return {
		Label = label,
		BaseId = monkeyData.BaseId,
		Name = monkeyData.Nickname or configData.Name,
		Level = monkeyData.Level,
		Rarity = monkeyData.Rarity,
		Moves = configData.Moves,
		
		-- Current stats (can change during fight)
		MaxHP = totalHP,
		CurrentHP = totalHP,
		Attack = totalAttack,
		Defense = totalDefense,
		Speed = totalSpeed,
		CritChance = totalCrit,
		
		-- Status effects
		Buffs = {},
		Debuffs = {},
		Cooldowns = {},
		
		-- AI state
		Aggression = 0.5 + math.random() * 0.3, -- Random personality
		Caution = 0.3 + math.random() * 0.4,
		LastMove = nil,
	}
end

-- ============================================================
-- AI DECISION MAKING
-- ============================================================
function CombatAI._ChooseMove(fighter, opponent)
	local availableMoves = {}
	
	for _, moveName in ipairs(fighter.Moves) do
		local moveData = GameConfig.GetMoveData(moveName)
		if moveData then
			local cooldown = fighter.Cooldowns[moveName] or 0
			if cooldown <= 0 then
				table.insert(availableMoves, {Name = moveName, Data = moveData})
			end
		end
	end
	
	if #availableMoves == 0 then
		-- All on cooldown, use basic punch
		return "Punch", GameConfig.GetMoveData("Punch")
	end
	
	-- AI Strategy based on situation
	local hpPercent = fighter.CurrentHP / fighter.MaxHP
	local opponentHpPercent = opponent.CurrentHP / opponent.MaxHP
	
	-- Weight each available move
	local weights = {}
	local totalWeight = 0
	
	for _, move in ipairs(availableMoves) do
		local weight = 1.0
		
		if move.Data.Type == "Buff" then
			-- Prefer buffs when healthy and early in fight
			if hpPercent > 0.6 then
				weight = weight * (1 + fighter.Caution)
			else
				weight = weight * 0.3
			end
		elseif move.Data.Type == "Debuff" then
			-- Prefer debuffs against strong opponents
			if opponentHpPercent > 0.5 then
				weight = weight * 1.5
			end
		else
			-- Damage moves
			local expectedDamage = move.Data.Damage * move.Data.Accuracy
			weight = weight * (expectedDamage / 10)
			
			-- Prefer high damage when opponent is low
			if opponentHpPercent < 0.3 then
				weight = weight * (1 + fighter.Aggression)
			end
			
			-- Cautious fighters prefer accurate moves
			weight = weight * (move.Data.Accuracy ^ fighter.Caution)
		end
		
		-- Don't repeat same move twice (AI variety)
		if fighter.LastMove == move.Name then
			weight = weight * 0.5
		end
		
		weights[move.Name] = weight
		totalWeight = totalWeight + weight
	end
	
	-- Weighted random selection
	local roll = math.random() * totalWeight
	local cumulative = 0
	
	for _, move in ipairs(availableMoves) do
		cumulative = cumulative + (weights[move.Name] or 0)
		if roll <= cumulative then
			return move.Name, move.Data
		end
	end
	
	-- Fallback
	local choice = availableMoves[math.random(#availableMoves)]
	return choice.Name, choice.Data
end

-- ============================================================
-- EXECUTE A ROUND
-- ============================================================
function CombatAI._ExecuteRound(fight)
	fight.Round = fight.Round + 1
	
	local f1 = fight.Fighter1
	local f2 = fight.Fighter2
	
	-- Determine turn order by speed (with some randomness)
	local speed1 = f1.Speed + math.random(-2, 2)
	local speed2 = f2.Speed + math.random(-2, 2)
	
	local first, second
	if speed1 >= speed2 then
		first, second = f1, f2
	else
		first, second = f2, f1
	end
	
	-- First fighter acts
	local log1 = CombatAI._ExecuteTurn(first, second, fight)
	table.insert(fight.Log, log1)
	
	-- Check if second fighter is KO
	if second.CurrentHP <= 0 then
		fight.Status = "Finished"
		fight.Winner = first.Label
		table.insert(fight.Log, {
			Round = fight.Round,
			Event = "KO",
			Message = second.Name .. " has been knocked out! " .. first.Name .. " wins!",
		})
		return
	end
	
	-- Second fighter acts
	local log2 = CombatAI._ExecuteTurn(second, first, fight)
	table.insert(fight.Log, log2)
	
	-- Check if first fighter is KO
	if first.CurrentHP <= 0 then
		fight.Status = "Finished"
		fight.Winner = second.Label
		table.insert(fight.Log, {
			Round = fight.Round,
			Event = "KO",
			Message = first.Name .. " has been knocked out! " .. second.Name .. " wins!",
		})
		return
	end
	
	-- Update cooldowns
	for moveName, cd in pairs(f1.Cooldowns) do
		f1.Cooldowns[moveName] = math.max(0, cd - 1)
	end
	for moveName, cd in pairs(f2.Cooldowns) do
		f2.Cooldowns[moveName] = math.max(0, cd - 1)
	end
	
	-- Check max rounds
	if fight.Round >= fight.MaxRounds then
		fight.Status = "Finished"
		-- Winner is whoever has more HP percentage
		local hp1Pct = f1.CurrentHP / f1.MaxHP
		local hp2Pct = f2.CurrentHP / f2.MaxHP
		if hp1Pct > hp2Pct then
			fight.Winner = f1.Label
		elseif hp2Pct > hp1Pct then
			fight.Winner = f2.Label
		else
			fight.Winner = "Draw"
		end
		table.insert(fight.Log, {
			Round = fight.Round,
			Event = "TimeOut",
			Message = "Fight went to decision! Winner: " .. fight.Winner,
		})
	end
end

function CombatAI._ExecuteTurn(attacker, defender, fight)
	local moveName, moveData = CombatAI._ChooseMove(attacker, defender)
	attacker.LastMove = moveName
	
	-- Set cooldown
	if moveData.Cooldown then
		attacker.Cooldowns[moveName] = moveData.Cooldown
	end
	
	local logEntry = {
		Round = fight.Round,
		Attacker = attacker.Name,
		Defender = defender.Name,
		Move = moveName,
	}
	
	-- Check if move hits
	local accuracy = moveData.Accuracy
	
	-- Check evasion buff
	if defender.Buffs.Evasion and defender.Buffs.Evasion > 0 then
		accuracy = accuracy * 0.5
		defender.Buffs.Evasion = defender.Buffs.Evasion - 1
	end
	
	-- Check invisible buff
	if attacker.Buffs.Invisible and attacker.Buffs.Invisible > 0 then
		accuracy = math.min(1.0, accuracy + 0.2) -- Higher accuracy when invisible
		attacker.Buffs.Invisible = attacker.Buffs.Invisible - 1
	end
	
	local hitRoll = math.random()
	
	if hitRoll > accuracy then
		logEntry.Result = "Miss"
		logEntry.Message = attacker.Name .. " used " .. moveName .. " but missed!"
		return logEntry
	end
	
	-- Handle buff/debuff moves
	if moveData.Type == "Buff" then
		local effect = moveData.Effect
		if effect == "Evasion" then
			attacker.Buffs.Evasion = (attacker.Buffs.Evasion or 0) + 2
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! Evasion increased!"
		elseif effect == "AttackUp" then
			attacker.Attack = attacker.Attack + 3
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! Attack power increased!"
		elseif effect == "DefenseUp" then
			attacker.Defense = attacker.Defense + 3
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! Defense increased!"
		elseif effect == "Invisible" then
			attacker.Buffs.Invisible = 2
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! Vanished into shadows!"
		elseif effect == "AllStatsUp" then
			attacker.Attack = attacker.Attack + 2
			attacker.Defense = attacker.Defense + 2
			attacker.Speed = attacker.Speed + 2
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! All stats boosted!"
		elseif effect == "Shield" then
			attacker.Buffs.Shield = 20
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! A protective shield forms!"
		end
		logEntry.Result = "Buff"
		return logEntry
	end
	
	if moveData.Type == "Debuff" then
		local effect = moveData.Effect
		if effect == "AttackDown" then
			defender.Attack = math.max(1, defender.Attack - 3)
			logEntry.Message = attacker.Name .. " uses " .. moveName .. "! " .. defender.Name .. "'s attack decreased!"
		end
		logEntry.Result = "Debuff"
		return logEntry
	end
	
	-- Calculate damage
	local baseDamage = moveData.Damage
	local attackStat = attacker.Attack
	local defenseStat = defender.Defense
	
	-- Ignore defense for certain moves
	if moveData.Effect == "IgnoreDefense" then
		defenseStat = 0
	end
	
	-- Shield absorption
	if defender.Buffs.Shield and defender.Buffs.Shield > 0 then
		local absorbed = math.min(defender.Buffs.Shield, baseDamage * 0.5)
		defender.Buffs.Shield = defender.Buffs.Shield - absorbed
		baseDamage = baseDamage - absorbed
	end
	
	local damage = math.max(1, math.floor(baseDamage * (attackStat / (attackStat + defenseStat)) * (0.85 + math.random() * 0.3)))
	
	-- Critical hit check
	local isCrit = false
	local critChance = attacker.CritChance + (moveData.CritBonus or 0)
	if math.random() < critChance then
		damage = math.floor(damage * 1.5)
		isCrit = true
	end
	
	defender.CurrentHP = math.max(0, defender.CurrentHP - damage)
	
	logEntry.Damage = damage
	logEntry.IsCrit = isCrit
	logEntry.Result = "Hit"
	logEntry.DefenderHP = defender.CurrentHP
	logEntry.DefenderMaxHP = defender.MaxHP
	
	local critText = isCrit and " CRITICAL HIT!" or ""
	logEntry.Message = attacker.Name .. " uses " .. moveName .. "! Deals " .. damage .. " damage!" .. critText
	
	return logEntry
end

-- ============================================================
-- RUN COMPLETE FIGHT
-- ============================================================
function CombatAI.RunFight(monkey1Data, monkey2Data)
	local fight = CombatAI.CreateFight(monkey1Data, monkey2Data)
	fight.Status = "InProgress"
	
	local rounds = {}
	
	while fight.Status == "InProgress" do
		CombatAI._ExecuteRound(fight)
		-- Collect round data for replay
		table.insert(rounds, {
			Round = fight.Round,
			F1HP = fight.Fighter1.CurrentHP,
			F1MaxHP = fight.Fighter1.MaxHP,
			F2HP = fight.Fighter2.CurrentHP,
			F2MaxHP = fight.Fighter2.MaxHP,
			Events = {},
		})
		-- Copy recent log entries to this round
		for _, entry in ipairs(fight.Log) do
			if entry.Round == fight.Round then
				table.insert(rounds[#rounds].Events, entry)
			end
		end
	end
	
	-- Store in history
	table.insert(fightHistory, {
		Id = fight.Id,
		Winner = fight.Winner,
		Rounds = fight.Round,
		Fighter1 = fight.Fighter1.Name,
		Fighter2 = fight.Fighter2.Name,
		Time = os.time(),
	})
	
	-- Keep only last 50 fights
	while #fightHistory > 50 do
		table.remove(fightHistory, 1)
	end
	
	return {
		FightId = fight.Id,
		Winner = fight.Winner,
		TotalRounds = fight.Round,
		Fighter1 = {
			Name = fight.Fighter1.Name,
			BaseId = fight.Fighter1.BaseId,
			Level = fight.Fighter1.Level,
			Rarity = fight.Fighter1.Rarity,
			FinalHP = fight.Fighter1.CurrentHP,
			MaxHP = fight.Fighter1.MaxHP,
		},
		Fighter2 = {
			Name = fight.Fighter2.Name,
			BaseId = fight.Fighter2.BaseId,
			Level = fight.Fighter2.Level,
			Rarity = fight.Fighter2.Rarity,
			FinalHP = fight.Fighter2.CurrentHP,
			MaxHP = fight.Fighter2.MaxHP,
		},
		Rounds = rounds,
		Log = fight.Log,
	}
end

function CombatAI.GetActiveFight()
	return activeFight
end

function CombatAI.GetFightHistory()
	return fightHistory
end

return CombatAI
