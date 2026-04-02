--[[
    EvolutionSystem.lua
    Server-side incremental evolution, training, feeding, and affection system
    for all creature types (Monkeys, Camels, Lobsters).

    Handles levelling, stat growth, evolution chain progression, training
    sessions with cooldowns, item-based feeding, and a musume-style bonding /
    affection system.  All mutations are validated server-side with anti-exploit
    checks before being persisted through DataStoreManager.

    Public API (returned table):
        Initialize()
        TrainCreature(player, creatureId)
        FeedCreature(player, creatureId, itemId)
        AddExperience(player, creatureId, amount)
        CheckEvolution(player, creatureId)
        GetCreatureStats(player, creatureId)
        GetEvolutionInfo(creatureId)
        CalculateEffectiveStats(creatureData)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GameConfig       = require(script.Parent.Parent.Shared.GameConfig)
local DataStoreManager = require(script.Parent.DataStoreManager)

-- ============================================================
-- Module table
-- ============================================================
local EvolutionSystem = {}

-- ============================================================
-- Constants
-- ============================================================
local MAX_LEVEL            = GameConfig.Evolution.MaxLevel           -- 100
local EVOLUTION_LEVELS     = GameConfig.Evolution.EvolutionLevels    -- {30, 60}
local STAT_GROWTH          = GameConfig.Evolution.StatGrowthPerLevel
local EVOLUTION_STAT_BOOST = 0.20 -- 20 % base-stat increase on evolution
local TRAINING_COOLDOWN    = 300  -- 5 minutes in seconds

local MAX_AFFECTION        = 100
local AFFECTION_PER_TRAIN  = 3
local AFFECTION_PER_FEED   = 5
local AFFECTION_PER_BATTLE = 2
local MAX_AFFECTION_BONUS  = 0.10 -- up to 10 % stat bonus at max affection

-- Anti-exploit caps – no single server action may grant more than these.
local MAX_SINGLE_XP_GAIN   = 5000
local MAX_SINGLE_AFFECTION = 20

-- Per-creature training cooldown tracker: [UserId] = { [creatureId] = tick }
local trainingCooldowns = {}

-- ============================================================
-- Remote Events
-- ============================================================
local Remotes = {}

local function getOrCreateRemote(name)
    local folder = ReplicatedStorage:FindFirstChild("EvolutionEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "EvolutionEvents"
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

-- ============================================================
-- Creature-type stat growth multipliers
-- Monkeys  -> ATK / HP heavy
-- Camels   -> SPD / STA heavy
-- Lobsters -> ACC / LUCK heavy
-- ============================================================
local TYPE_GROWTH_MULTIPLIERS = {
    Monkey = {
        HP = 1.5, ATK = 1.4, DEF = 1.0, SPD = 0.8, CRIT = 1.0,
        STA = 0.6, ACC = 0.6, LUCK = 0.5,
    },
    Camel = {
        HP = 0.6, ATK = 0.5, DEF = 0.6, SPD = 1.5, CRIT = 0.5,
        STA = 1.4, ACC = 1.0, LUCK = 0.8,
    },
    Lobster = {
        HP = 0.6, ATK = 0.5, DEF = 0.6, SPD = 1.0, CRIT = 0.8,
        STA = 0.8, ACC = 1.5, LUCK = 1.4,
    },
}

-- ============================================================
-- Feed-item definitions (could move to GameConfig later)
-- ============================================================
local FEED_ITEMS = {
    xp_fruit_small   = { XP = 50,  Affection = 1,  Name = "Fruta Pequena" },
    xp_fruit_medium  = { XP = 150, Affection = 2,  Name = "Fruta Média" },
    xp_fruit_large   = { XP = 400, Affection = 3,  Name = "Fruta Grande" },
    affection_treat   = { XP = 10,  Affection = 10, Name = "Petisco Especial" },
    affection_premium = { XP = 25,  Affection = 20, Name = "Petisco Premium" },
    super_berry       = { XP = 800, Affection = 5,  Name = "Super Fruta" },
}

-- ============================================================
-- Creature config look-up helpers
-- ============================================================

--- Merged creature list with type tag for fast Id look-up.
local creatureById = {} -- [Id] = { config, Type }

local function rebuildCreatureLookup()
    creatureById = {}
    for _, m in ipairs(GameConfig.Monkeys) do
        creatureById[m.Id] = { Config = m, Type = "Monkey" }
    end
    for _, c in ipairs(GameConfig.Camels) do
        creatureById[c.Id] = { Config = c, Type = "Camel" }
    end
    for _, l in ipairs(GameConfig.Lobsters) do
        creatureById[l.Id] = { Config = l, Type = "Lobster" }
    end
end

--- Equipment look-up for stat bonuses.
local equipmentById = {}
local function rebuildEquipmentLookup()
    equipmentById = {}
    for _, equip in ipairs(GameConfig.Equipment) do
        equipmentById[equip.Id] = equip
    end
end

-- ============================================================
-- Internal validation helpers
-- ============================================================

local function isValidPlayer(player)
    return typeof(player) == "Instance"
        and player:IsA("Player")
        and player:IsDescendantOf(Players)
end

local function getPlayerData(player)
    if not isValidPlayer(player) then
        return nil
    end
    return DataStoreManager:GetData(player)
end

--- Locate a creature record in the player's Creatures array by Id.
--- Returns (creatureData, index) or (nil, nil).
local function findCreature(playerData, creatureId)
    if not playerData or not playerData.Creatures then
        return nil, nil
    end
    for i, creature in ipairs(playerData.Creatures) do
        if creature.Id == creatureId then
            return creature, i
        end
    end
    return nil, nil
end

--- Determine the creature type (Monkey / Camel / Lobster) for a given Id,
--- walking the full config and all evolution chain entries.
local function getCreatureType(creatureId)
    -- Direct match
    local entry = creatureById[creatureId]
    if entry then
        return entry.Type
    end
    -- Walk evolution chains for evolved Ids not in the base list
    for _, m in ipairs(GameConfig.Monkeys) do
        if m.EvolutionChain then
            for _, chainId in ipairs(m.EvolutionChain) do
                if chainId == creatureId then
                    return "Monkey"
                end
            end
        end
    end
    for _, c in ipairs(GameConfig.Camels) do
        if c.EvolutionChain then
            for _, chainId in ipairs(c.EvolutionChain) do
                if chainId == creatureId then
                    return "Camel"
                end
            end
        end
    end
    for _, l in ipairs(GameConfig.Lobsters) do
        if l.EvolutionChain then
            for _, chainId in ipairs(l.EvolutionChain) do
                if chainId == creatureId then
                    return "Lobster"
                end
            end
        end
    end
    return nil
end

--- Retrieve the base config entry that owns an evolution chain containing
--- the given creatureId.  Returns (baseConfig, chainIndex) or (nil, nil).
local function getBaseConfigForId(creatureId)
    local lists = { GameConfig.Monkeys, GameConfig.Camels, GameConfig.Lobsters }
    for _, list in ipairs(lists) do
        for _, cfg in ipairs(list) do
            if cfg.EvolutionChain then
                for idx, chainId in ipairs(cfg.EvolutionChain) do
                    if chainId == creatureId then
                        return cfg, idx
                    end
                end
            end
            if cfg.Id == creatureId then
                return cfg, 1
            end
        end
    end
    return nil, nil
end

-- ============================================================
-- Core XP / Level Calculations
-- ============================================================

--- Experience required to go from (level) to (level + 1).
local function xpForLevel(level)
    return GameConfig.Evolution.ExpPerLevel(level)
end

--- Total cumulative XP needed to reach a given level (from level 1).
local function totalXpForLevel(level)
    local total = 0
    for lv = 1, level - 1 do
        total = total + xpForLevel(lv)
    end
    return total
end

--- Given current cumulative XP, compute the effective level (capped at MAX_LEVEL).
local function levelFromXp(totalXp)
    local lv = 1
    local accumulated = 0
    while lv < MAX_LEVEL do
        local needed = xpForLevel(lv)
        if accumulated + needed > totalXp then
            break
        end
        accumulated = accumulated + needed
        lv = lv + 1
    end
    return lv
end

-- ============================================================
-- Stat Calculation
-- ============================================================

--- Compute type-adjusted stat growth for one level-up.
local function statGrowthForType(creatureType)
    local multipliers = TYPE_GROWTH_MULTIPLIERS[creatureType]
    if not multipliers then
        multipliers = { HP = 1, ATK = 1, DEF = 1, SPD = 1, CRIT = 1,
                        STA = 1, ACC = 1, LUCK = 1 }
    end
    local growth = {}
    for stat, baseGrowth in pairs(STAT_GROWTH) do
        local mult = multipliers[stat] or 1
        growth[stat] = baseGrowth * mult
    end
    return growth
end

--- Compute the number of evolution boosts already applied based on current
--- chain index (0 for base form, 1 after first evo, 2 after second).
local function evolutionBoostCount(creatureId)
    local _, chainIdx = getBaseConfigForId(creatureId)
    if not chainIdx then
        return 0
    end
    return math.max(0, chainIdx - 1)
end

--- Pure calculation: given a creature data table, return effective stats
--- (base + level growth + evolution boosts + equipment + affection bonus).
function EvolutionSystem.CalculateEffectiveStats(creatureData)
    if not creatureData or not creatureData.Id then
        return nil
    end

    local baseCfg = getBaseConfigForId(creatureData.Id)
    if not baseCfg then
        return nil
    end

    local creatureType = getCreatureType(creatureData.Id)
    local growth = statGrowthForType(creatureType)
    local level = creatureData.Level or 1
    local affection = creatureData.Affection or 0

    -- Start from the BASE-form stats (evolution chain root).
    local stats = {}
    for stat, value in pairs(baseCfg.BaseStats) do
        stats[stat] = value
    end

    -- Apply evolution boosts (20 % compound per evolution).
    local evoCount = evolutionBoostCount(creatureData.Id)
    for _ = 1, evoCount do
        for stat in pairs(stats) do
            stats[stat] = stats[stat] * (1 + EVOLUTION_STAT_BOOST)
        end
    end

    -- Apply per-level growth.
    for stat in pairs(stats) do
        local g = growth[stat] or 0
        stats[stat] = stats[stat] + g * (level - 1)
    end

    -- Apply equipment bonuses.
    if creatureData.Equipment then
        for _, equipId in ipairs(creatureData.Equipment) do
            local equip = equipmentById[equipId]
            if equip and equip.Stats then
                for stat, bonus in pairs(equip.Stats) do
                    if stats[stat] then
                        stats[stat] = stats[stat] + bonus
                    end
                end
            end
        end
    end

    -- Apply affection bonus (linear scale, max 10 %).
    local affectionMult = 1 + (math.clamp(affection, 0, MAX_AFFECTION) / MAX_AFFECTION) * MAX_AFFECTION_BONUS
    for stat in pairs(stats) do
        stats[stat] = math.floor(stats[stat] * affectionMult)
    end

    return stats
end

-- ============================================================
-- Evolution Chain
-- ============================================================

--- Return information about a creature's evolution chain.
function EvolutionSystem.GetEvolutionInfo(creatureId)
    local baseCfg, chainIdx = getBaseConfigForId(creatureId)
    if not baseCfg or not baseCfg.EvolutionChain then
        return nil
    end

    local chain = baseCfg.EvolutionChain
    local canEvolve = false
    local nextFormId = nil
    local requiredLevel = nil

    if chainIdx and chainIdx < #chain then
        local evoIdx = chainIdx -- which evolution is next (1 → 2 = first evo)
        if evoIdx <= #EVOLUTION_LEVELS then
            requiredLevel = EVOLUTION_LEVELS[evoIdx]
        end
        nextFormId = chain[chainIdx + 1]
        canEvolve = true
    end

    return {
        Chain = chain,
        CurrentIndex = chainIdx or 1,
        CurrentFormId = creatureId,
        NextFormId = nextFormId,
        RequiredLevel = requiredLevel,
        CanEvolve = canEvolve,
        TotalForms = #chain,
    }
end

-- ============================================================
-- Server-validated XP addition with level-up processing
-- ============================================================

--- Internal: process level-ups after XP changes.  Returns the number of
--- levels gained so the caller can decide whether to fire events.
local function processLevelUps(creatureData)
    local oldLevel = creatureData.Level or 1
    local newLevel = levelFromXp(creatureData.Experience or 0)
    newLevel = math.clamp(newLevel, 1, MAX_LEVEL)
    creatureData.Level = newLevel
    return newLevel - oldLevel
end

--- Add experience to a creature with full server-side validation.
--- Returns (success: boolean, message: string).
function EvolutionSystem.AddExperience(player, creatureId, amount)
    if not isValidPlayer(player) then
        return false, "Invalid player"
    end
    if type(amount) ~= "number" or amount ~= amount then
        return false, "Invalid amount"
    end
    amount = math.floor(amount)
    if amount <= 0 then
        return false, "Amount must be positive"
    end
    if amount > MAX_SINGLE_XP_GAIN then
        warn(string.format(
            "[EvolutionSystem] Anti-exploit: player %s tried to add %d XP (max %d)",
            player.Name, amount, MAX_SINGLE_XP_GAIN
        ))
        return false, "XP gain exceeds server maximum"
    end

    local playerData = getPlayerData(player)
    if not playerData then
        return false, "Player data not loaded"
    end

    local creature = findCreature(playerData, creatureId)
    if not creature then
        return false, "Creature not found"
    end

    if (creature.Level or 1) >= MAX_LEVEL then
        return false, "Creature is already max level"
    end

    creature.Experience = (creature.Experience or 0) + amount
    local levelsGained = processLevelUps(creature)

    DataStoreManager:SaveData(player)

    if levelsGained > 0 and Remotes.LevelUp then
        Remotes.LevelUp:FireClient(player, {
            CreatureId = creatureId,
            NewLevel = creature.Level,
            LevelsGained = levelsGained,
        })
    end

    return true, "OK"
end

-- ============================================================
-- Evolution
-- ============================================================

--- Check and perform evolution if the creature meets the requirements.
--- Returns (success, message).
function EvolutionSystem.CheckEvolution(player, creatureId)
    if not isValidPlayer(player) then
        return false, "Invalid player"
    end

    local playerData = getPlayerData(player)
    if not playerData then
        return false, "Player data not loaded"
    end

    local creature, creatureIdx = findCreature(playerData, creatureId)
    if not creature then
        return false, "Creature not found"
    end

    local evoInfo = EvolutionSystem.GetEvolutionInfo(creature.Id)
    if not evoInfo or not evoInfo.CanEvolve then
        return false, "No further evolution available"
    end

    local level = creature.Level or 1
    if not evoInfo.RequiredLevel or level < evoInfo.RequiredLevel then
        return false, string.format(
            "Level %d required for evolution (current: %d)",
            evoInfo.RequiredLevel or 0, level
        )
    end

    -- Perform evolution: update Id to next form.
    local oldId = creature.Id
    creature.Id = evoInfo.NextFormId

    DataStoreManager:SaveData(player)

    if Remotes.Evolution then
        Remotes.Evolution:FireClient(player, {
            CreatureId = oldId,
            NewFormId = creature.Id,
            Level = creature.Level,
            EvolutionIndex = evoInfo.CurrentIndex + 1,
        })
    end

    return true, "Evolved to " .. creature.Id
end

-- ============================================================
-- Training
-- ============================================================

--- Train a creature.  Costs coins, grants XP, increases affection, and
--- respects a per-creature cooldown.
--- Returns (success, message).
function EvolutionSystem.TrainCreature(player, creatureId)
    if not isValidPlayer(player) then
        return false, "Invalid player"
    end

    local playerData = getPlayerData(player)
    if not playerData then
        return false, "Player data not loaded"
    end

    local creature = findCreature(playerData, creatureId)
    if not creature then
        return false, "Creature not found"
    end

    -- Cooldown check
    local userId = tostring(player.UserId)
    trainingCooldowns[userId] = trainingCooldowns[userId] or {}
    local lastTrain = trainingCooldowns[userId][creatureId] or 0
    local now = tick()
    if now - lastTrain < TRAINING_COOLDOWN then
        local remaining = math.ceil(TRAINING_COOLDOWN - (now - lastTrain))
        return false, string.format("Training on cooldown (%d s remaining)", remaining)
    end

    -- Level cap check
    local level = creature.Level or 1
    if level >= MAX_LEVEL then
        return false, "Creature is already max level"
    end

    -- Coin cost
    local cost = GameConfig.Evolution.TrainingCostPerSession(level)
    if (playerData.Coins or 0) < cost then
        return false, string.format("Not enough coins (need %d, have %d)", cost, playerData.Coins or 0)
    end

    -- Deduct coins
    playerData.Coins = playerData.Coins - cost
    if playerData.Statistics then
        playerData.Statistics.TotalCoinsSpent = (playerData.Statistics.TotalCoinsSpent or 0) + cost
    end

    -- Grant XP
    local xpGain = GameConfig.Evolution.TrainingExpGain(level)
    creature.Experience = (creature.Experience or 0) + xpGain
    local levelsGained = processLevelUps(creature)

    -- Increase affection
    creature.Affection = math.clamp(
        (creature.Affection or 0) + AFFECTION_PER_TRAIN,
        0, MAX_AFFECTION
    )

    -- Set cooldown
    trainingCooldowns[userId][creatureId] = now

    DataStoreManager:SaveData(player)

    -- Notify client
    if Remotes.TrainResult then
        Remotes.TrainResult:FireClient(player, {
            CreatureId = creatureId,
            XPGained = xpGain,
            CoinsCost = cost,
            NewLevel = creature.Level,
            LevelsGained = levelsGained,
            Affection = creature.Affection,
            CoinsRemaining = playerData.Coins,
        })
    end

    -- Auto-check evolution after level-up
    if levelsGained > 0 then
        EvolutionSystem.CheckEvolution(player, creature.Id)
    end

    return true, "OK"
end

-- ============================================================
-- Feeding
-- ============================================================

--- Feed a creature with an item from the player's inventory.
--- Returns (success, message).
function EvolutionSystem.FeedCreature(player, creatureId, itemId)
    if not isValidPlayer(player) then
        return false, "Invalid player"
    end
    if type(itemId) ~= "string" then
        return false, "Invalid item id"
    end

    local feedConfig = FEED_ITEMS[itemId]
    if not feedConfig then
        return false, "Unknown feed item: " .. tostring(itemId)
    end

    local playerData = getPlayerData(player)
    if not playerData then
        return false, "Player data not loaded"
    end

    local creature = findCreature(playerData, creatureId)
    if not creature then
        return false, "Creature not found"
    end

    -- Check inventory for the item
    local inventory = playerData.Inventory
    if not inventory then
        return false, "No inventory"
    end

    local itemIndex = nil
    for i, entry in ipairs(inventory) do
        -- Support both flat string ids and { Id = ..., Quantity = ... } tables
        local entryId = type(entry) == "table" and entry.Id or entry
        if entryId == itemId then
            itemIndex = i
            break
        end
    end

    if not itemIndex then
        return false, "Item not in inventory"
    end

    -- Consume item
    local entry = inventory[itemIndex]
    if type(entry) == "table" and entry.Quantity then
        entry.Quantity = entry.Quantity - 1
        if entry.Quantity <= 0 then
            table.remove(inventory, itemIndex)
        end
    else
        table.remove(inventory, itemIndex)
    end

    -- Apply XP (capped per action)
    local xpGain = math.min(feedConfig.XP or 0, MAX_SINGLE_XP_GAIN)
    local levelsGained = 0
    if xpGain > 0 and (creature.Level or 1) < MAX_LEVEL then
        creature.Experience = (creature.Experience or 0) + xpGain
        levelsGained = processLevelUps(creature)
    end

    -- Apply affection (capped)
    local affectionGain = math.min(feedConfig.Affection or 0, MAX_SINGLE_AFFECTION)
    creature.Affection = math.clamp(
        (creature.Affection or 0) + affectionGain,
        0, MAX_AFFECTION
    )

    DataStoreManager:SaveData(player)

    -- Notify client
    if Remotes.FeedResult then
        Remotes.FeedResult:FireClient(player, {
            CreatureId = creatureId,
            ItemId = itemId,
            XPGained = xpGain,
            AffectionGained = affectionGain,
            NewLevel = creature.Level,
            LevelsGained = levelsGained,
            Affection = creature.Affection,
        })
    end

    -- Auto-check evolution
    if levelsGained > 0 then
        EvolutionSystem.CheckEvolution(player, creature.Id)
    end

    return true, "OK"
end

-- ============================================================
-- Battle affection hook (called by FightSystem after a fight)
-- ============================================================

--- Increase affection for a creature after participating in a battle.
--- Intended to be called by other server systems, not by clients.
function EvolutionSystem.AddBattleAffection(player, creatureId)
    if not isValidPlayer(player) then
        return
    end
    local playerData = getPlayerData(player)
    if not playerData then
        return
    end
    local creature = findCreature(playerData, creatureId)
    if not creature then
        return
    end
    creature.Affection = math.clamp(
        (creature.Affection or 0) + AFFECTION_PER_BATTLE,
        0, MAX_AFFECTION
    )
    DataStoreManager:SaveData(player)
end

-- ============================================================
-- Stat Query
-- ============================================================

--- Return the full effective stats for a player's creature.
function EvolutionSystem.GetCreatureStats(player, creatureId)
    if not isValidPlayer(player) then
        return nil
    end
    local playerData = getPlayerData(player)
    if not playerData then
        return nil
    end
    local creature = findCreature(playerData, creatureId)
    if not creature then
        return nil
    end

    local stats = EvolutionSystem.CalculateEffectiveStats(creature)
    if not stats then
        return nil
    end

    return {
        Id = creature.Id,
        Level = creature.Level or 1,
        Experience = creature.Experience or 0,
        Affection = creature.Affection or 0,
        NextLevelXP = xpForLevel(creature.Level or 1),
        Stats = stats,
        EvolutionInfo = EvolutionSystem.GetEvolutionInfo(creature.Id),
    }
end

-- ============================================================
-- Remote Event Handlers
-- ============================================================

local function onTrainRequest(player, creatureId)
    if type(creatureId) ~= "string" then
        return
    end
    EvolutionSystem.TrainCreature(player, creatureId)
end

local function onFeedRequest(player, creatureId, itemId)
    if type(creatureId) ~= "string" or type(itemId) ~= "string" then
        return
    end
    EvolutionSystem.FeedCreature(player, creatureId, itemId)
end

local function onStatsRequest(player, creatureId)
    if type(creatureId) ~= "string" then
        return
    end
    local info = EvolutionSystem.GetCreatureStats(player, creatureId)
    if info and Remotes.StatsResponse then
        Remotes.StatsResponse:FireClient(player, info)
    end
end

local function onEvolveRequest(player, creatureId)
    if type(creatureId) ~= "string" then
        return
    end
    EvolutionSystem.CheckEvolution(player, creatureId)
end

-- ============================================================
-- Cleanup on player leave
-- ============================================================

local function onPlayerRemoving(player)
    local userId = tostring(player.UserId)
    trainingCooldowns[userId] = nil
end

-- ============================================================
-- Initialize
-- ============================================================

function EvolutionSystem.Initialize()
    -- Build look-up caches
    rebuildCreatureLookup()
    rebuildEquipmentLookup()

    -- Create remote events
    Remotes.TrainRequest  = getOrCreateRemote("TrainRequest")
    Remotes.TrainResult   = getOrCreateRemote("TrainResult")
    Remotes.FeedRequest   = getOrCreateRemote("FeedRequest")
    Remotes.FeedResult    = getOrCreateRemote("FeedResult")
    Remotes.EvolveRequest = getOrCreateRemote("EvolveRequest")
    Remotes.Evolution     = getOrCreateRemote("Evolution")
    Remotes.StatsRequest  = getOrCreateRemote("StatsRequest")
    Remotes.StatsResponse = getOrCreateRemote("StatsResponse")
    Remotes.LevelUp       = getOrCreateRemote("LevelUp")

    -- Bind client → server events
    Remotes.TrainRequest.OnServerEvent:Connect(onTrainRequest)
    Remotes.FeedRequest.OnServerEvent:Connect(onFeedRequest)
    Remotes.StatsRequest.OnServerEvent:Connect(onStatsRequest)
    Remotes.EvolveRequest.OnServerEvent:Connect(onEvolveRequest)

    -- Cleanup cooldowns on leave
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    print("[EvolutionSystem] Initialized")
end

return EvolutionSystem
