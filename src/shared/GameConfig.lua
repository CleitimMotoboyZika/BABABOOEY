-- GameConfig: Central configuration for Arena Bestial
-- All game constants, creature data, item data, and balancing

local GameConfig = {}

-- ============================================================
-- CURRENCY & ECONOMY
-- ============================================================
GameConfig.Currency = {
	StartingMoney = 500,
	MaxMoney = 999999999,
	MinBet = 10,
	MaxBet = 10000,
	BetPayoutMultiplier = 2.5,
	TradeEnabled = true,
	TradeTax = 0.05, -- 5% tax on trades
}

-- ============================================================
-- CREATURE RARITIES
-- ============================================================
GameConfig.Rarities = {
	Common   = { Color = Color3.fromRGB(200, 200, 200), Multiplier = 1.0,  Weight = 50 },
	Uncommon = { Color = Color3.fromRGB(30, 200, 30),   Multiplier = 1.25, Weight = 25 },
	Rare     = { Color = Color3.fromRGB(30, 100, 255),  Multiplier = 1.5,  Weight = 15 },
	Epic     = { Color = Color3.fromRGB(180, 30, 255),  Multiplier = 2.0,  Weight = 7  },
	Legendary= { Color = Color3.fromRGB(255, 200, 0),   Multiplier = 3.0,  Weight = 2.5},
	Mythic   = { Color = Color3.fromRGB(255, 50, 50),   Multiplier = 5.0,  Weight = 0.5},
}

-- ============================================================
-- MONKEY DATA (Combat Creatures)
-- ============================================================
GameConfig.Monkeys = {
	{
		Id = "capuchin",
		Name = "Capuchin",
		BaseHP = 100,
		BaseAttack = 15,
		BaseDefense = 10,
		BaseSpeed = 12,
		BaseCritChance = 0.05,
		Rarity = "Common",
		Description = "A scrappy little fighter with quick jabs.",
		Moves = {"Punch", "Scratch", "Dodge"},
	},
	{
		Id = "howler",
		Name = "Howler Monkey",
		BaseHP = 130,
		BaseAttack = 18,
		BaseDefense = 8,
		BaseSpeed = 10,
		BaseCritChance = 0.08,
		Rarity = "Common",
		Description = "Loud and intimidating, shakes opponents with war cries.",
		Moves = {"Punch", "WarCry", "Slam"},
	},
	{
		Id = "spider_monkey",
		Name = "Spider Monkey",
		BaseHP = 90,
		BaseAttack = 20,
		BaseDefense = 7,
		BaseSpeed = 18,
		BaseCritChance = 0.12,
		Rarity = "Uncommon",
		Description = "Incredibly agile, strikes from unexpected angles.",
		Moves = {"Scratch", "AerialStrike", "Dodge"},
	},
	{
		Id = "mandrill",
		Name = "Mandrill",
		BaseHP = 160,
		BaseAttack = 25,
		BaseDefense = 15,
		BaseSpeed = 8,
		BaseCritChance = 0.06,
		Rarity = "Rare",
		Description = "A powerful brute with colorful war paint.",
		Moves = {"Slam", "Intimidate", "CrushingBlow"},
	},
	{
		Id = "golden_tamarin",
		Name = "Golden Lion Tamarin",
		BaseHP = 80,
		BaseAttack = 22,
		BaseDefense = 6,
		BaseSpeed = 20,
		BaseCritChance = 0.15,
		Rarity = "Rare",
		Description = "A golden blur of claws and fury.",
		Moves = {"GoldenSlash", "Dodge", "FlurryOfBlows"},
	},
	{
		Id = "silverback",
		Name = "Silverback Gorilla",
		BaseHP = 250,
		BaseAttack = 35,
		BaseDefense = 25,
		BaseSpeed = 5,
		BaseCritChance = 0.04,
		Rarity = "Epic",
		Description = "The undisputed king of raw power.",
		Moves = {"CrushingBlow", "GroundPound", "ChestPound"},
	},
	{
		Id = "shadow_chimp",
		Name = "Shadow Chimpanzee",
		BaseHP = 140,
		BaseAttack = 30,
		BaseDefense = 12,
		BaseSpeed = 16,
		BaseCritChance = 0.18,
		Rarity = "Epic",
		Description = "Moves like a phantom, strikes like lightning.",
		Moves = {"ShadowStrike", "Vanish", "CriticalHit"},
	},
	{
		Id = "inferno_baboon",
		Name = "Inferno Baboon",
		BaseHP = 200,
		BaseAttack = 40,
		BaseDefense = 18,
		BaseSpeed = 12,
		BaseCritChance = 0.10,
		Rarity = "Legendary",
		Description = "Wreathed in flame, this beast knows no mercy.",
		Moves = {"FirePunch", "Eruption", "InfernalRage"},
	},
	{
		Id = "cosmic_orangutan",
		Name = "Cosmic Orangutan",
		BaseHP = 300,
		BaseAttack = 45,
		BaseDefense = 30,
		BaseSpeed = 10,
		BaseCritChance = 0.20,
		Rarity = "Legendary",
		Description = "An ancient primate touched by the cosmos.",
		Moves = {"CosmicPunch", "GravitySlam", "StarShield"},
	},
	{
		Id = "void_ape",
		Name = "Void Ape",
		BaseHP = 350,
		BaseAttack = 55,
		BaseDefense = 35,
		BaseSpeed = 14,
		BaseCritChance = 0.25,
		Rarity = "Mythic",
		Description = "Born from nothingness. Unmatched in combat.",
		Moves = {"VoidStrike", "Oblivion", "DimensionalRift"},
	},
}

-- ============================================================
-- CAMEL DATA (Desert Racing)
-- ============================================================
GameConfig.Camels = {
	{
		Id = "dromedary",
		Name = "Dromedary",
		BaseSpeed = 10,
		BaseStamina = 100,
		BaseAcceleration = 5,
		BaseLuck = 0.05,
		Rarity = "Common",
		Description = "A reliable one-humped racer.",
	},
	{
		Id = "bactrian",
		Name = "Bactrian Camel",
		BaseSpeed = 9,
		BaseStamina = 130,
		BaseAcceleration = 4,
		BaseLuck = 0.06,
		Rarity = "Common",
		Description = "Two humps, double the endurance.",
	},
	{
		Id = "sand_sprinter",
		Name = "Sand Sprinter",
		BaseSpeed = 14,
		BaseStamina = 80,
		BaseAcceleration = 8,
		BaseLuck = 0.08,
		Rarity = "Uncommon",
		Description = "Built for speed over short distances.",
	},
	{
		Id = "dune_runner",
		Name = "Dune Runner",
		BaseSpeed = 12,
		BaseStamina = 110,
		BaseAcceleration = 7,
		BaseLuck = 0.10,
		Rarity = "Rare",
		Description = "Glides over dunes like water.",
	},
	{
		Id = "golden_hump",
		Name = "Golden Hump",
		BaseSpeed = 16,
		BaseStamina = 120,
		BaseAcceleration = 9,
		BaseLuck = 0.12,
		Rarity = "Epic",
		Description = "A prize camel with a golden sheen.",
	},
	{
		Id = "phantom_camel",
		Name = "Phantom Camel",
		BaseSpeed = 20,
		BaseStamina = 100,
		BaseAcceleration = 12,
		BaseLuck = 0.18,
		Rarity = "Legendary",
		Description = "Appears as a mirage, finishes before you blink.",
	},
	{
		Id = "celestial_dromedary",
		Name = "Celestial Dromedary",
		BaseSpeed = 25,
		BaseStamina = 150,
		BaseAcceleration = 15,
		BaseLuck = 0.25,
		Rarity = "Mythic",
		Description = "A camel blessed by desert gods.",
	},
}

-- ============================================================
-- LOBSTER DATA (Aquarium Racing)
-- ============================================================
GameConfig.Lobsters = {
	{
		Id = "american_lobster",
		Name = "American Lobster",
		BaseSpeed = 8,
		BaseStamina = 100,
		BaseAcceleration = 4,
		BaseLuck = 0.05,
		Rarity = "Common",
		Description = "A classic red racer from the Atlantic.",
	},
	{
		Id = "blue_lobster",
		Name = "Blue Lobster",
		BaseSpeed = 10,
		BaseStamina = 90,
		BaseAcceleration = 6,
		BaseLuck = 0.08,
		Rarity = "Uncommon",
		Description = "Rare coloring with surprising speed.",
	},
	{
		Id = "rock_lobster",
		Name = "Rock Lobster",
		BaseSpeed = 7,
		BaseStamina = 140,
		BaseAcceleration = 3,
		BaseLuck = 0.06,
		Rarity = "Common",
		Description = "Tough as nails, never gives up.",
	},
	{
		Id = "mantis_shrimp",
		Name = "Mantis Shrimp",
		BaseSpeed = 15,
		BaseStamina = 70,
		BaseAcceleration = 10,
		BaseLuck = 0.12,
		Rarity = "Rare",
		Description = "Not a lobster, but nobody dares tell it.",
	},
	{
		Id = "golden_claw",
		Name = "Golden Claw Lobster",
		BaseSpeed = 13,
		BaseStamina = 110,
		BaseAcceleration = 8,
		BaseLuck = 0.14,
		Rarity = "Epic",
		Description = "Gilded claws that gleam under water.",
	},
	{
		Id = "abyssal_lobster",
		Name = "Abyssal Lobster",
		BaseSpeed = 18,
		BaseStamina = 120,
		BaseAcceleration = 11,
		BaseLuck = 0.20,
		Rarity = "Legendary",
		Description = "From the deepest trenches, unstoppable.",
	},
	{
		Id = "kraken_spawn",
		Name = "Kraken Spawn",
		BaseSpeed = 22,
		BaseStamina = 150,
		BaseAcceleration = 14,
		BaseLuck = 0.28,
		Rarity = "Mythic",
		Description = "A tiny terror born of the legendary Kraken.",
	},
}

-- ============================================================
-- COMBAT MOVES
-- ============================================================
GameConfig.Moves = {
	Punch       = { Damage = 10, Accuracy = 0.95, Type = "Physical", Cooldown = 1 },
	Scratch     = { Damage = 8,  Accuracy = 0.98, Type = "Physical", Cooldown = 1 },
	Slam        = { Damage = 18, Accuracy = 0.80, Type = "Physical", Cooldown = 2 },
	Dodge       = { Damage = 0,  Accuracy = 1.00, Type = "Buff",     Cooldown = 2, Effect = "Evasion" },
	WarCry      = { Damage = 0,  Accuracy = 1.00, Type = "Buff",     Cooldown = 3, Effect = "AttackUp" },
	Intimidate  = { Damage = 0,  Accuracy = 0.90, Type = "Debuff",   Cooldown = 3, Effect = "AttackDown" },
	AerialStrike= { Damage = 22, Accuracy = 0.75, Type = "Physical", Cooldown = 2 },
	CrushingBlow= { Damage = 30, Accuracy = 0.70, Type = "Physical", Cooldown = 3 },
	GoldenSlash = { Damage = 15, Accuracy = 0.92, Type = "Physical", Cooldown = 1 },
	FlurryOfBlows={ Damage = 25, Accuracy = 0.85, Type = "Physical", Cooldown = 2 },
	GroundPound = { Damage = 35, Accuracy = 0.65, Type = "Physical", Cooldown = 3 },
	ChestPound  = { Damage = 0,  Accuracy = 1.00, Type = "Buff",     Cooldown = 3, Effect = "DefenseUp" },
	ShadowStrike= { Damage = 28, Accuracy = 0.88, Type = "Shadow",   Cooldown = 2 },
	Vanish      = { Damage = 0,  Accuracy = 1.00, Type = "Buff",     Cooldown = 3, Effect = "Invisible" },
	CriticalHit = { Damage = 20, Accuracy = 0.90, Type = "Physical", Cooldown = 1, CritBonus = 0.5 },
	FirePunch   = { Damage = 32, Accuracy = 0.82, Type = "Fire",     Cooldown = 2 },
	Eruption    = { Damage = 45, Accuracy = 0.60, Type = "Fire",     Cooldown = 4 },
	InfernalRage= { Damage = 0,  Accuracy = 1.00, Type = "Buff",     Cooldown = 4, Effect = "AllStatsUp" },
	CosmicPunch = { Damage = 38, Accuracy = 0.80, Type = "Cosmic",   Cooldown = 2 },
	GravitySlam = { Damage = 50, Accuracy = 0.55, Type = "Cosmic",   Cooldown = 4 },
	StarShield  = { Damage = 0,  Accuracy = 1.00, Type = "Buff",     Cooldown = 3, Effect = "Shield" },
	VoidStrike  = { Damage = 55, Accuracy = 0.75, Type = "Void",     Cooldown = 3 },
	Oblivion    = { Damage = 70, Accuracy = 0.50, Type = "Void",     Cooldown = 5 },
	DimensionalRift = { Damage = 40, Accuracy = 0.85, Type = "Void", Cooldown = 3, Effect = "IgnoreDefense" },
}

-- ============================================================
-- EQUIPMENT DATA
-- ============================================================
GameConfig.Equipment = {
	-- Monkey Equipment
	{
		Id = "leather_gloves",
		Name = "Leather Gloves",
		Slot = "Hands",
		Type = "Monkey",
		AttackBonus = 3,
		DefenseBonus = 1,
		SpeedBonus = 0,
		Rarity = "Common",
		Price = 100,
	},
	{
		Id = "iron_knuckles",
		Name = "Iron Knuckles",
		Slot = "Hands",
		Type = "Monkey",
		AttackBonus = 8,
		DefenseBonus = 2,
		SpeedBonus = -1,
		Rarity = "Uncommon",
		Price = 300,
	},
	{
		Id = "fighter_vest",
		Name = "Fighter Vest",
		Slot = "Body",
		Type = "Monkey",
		AttackBonus = 0,
		DefenseBonus = 8,
		SpeedBonus = 0,
		Rarity = "Common",
		Price = 150,
	},
	{
		Id = "champion_belt",
		Name = "Champion Belt",
		Slot = "Body",
		Type = "Monkey",
		AttackBonus = 5,
		DefenseBonus = 5,
		SpeedBonus = 2,
		Rarity = "Rare",
		Price = 800,
	},
	{
		Id = "speed_bandana",
		Name = "Speed Bandana",
		Slot = "Head",
		Type = "Monkey",
		AttackBonus = 0,
		DefenseBonus = 0,
		SpeedBonus = 5,
		Rarity = "Uncommon",
		Price = 250,
	},
	{
		Id = "berserker_helm",
		Name = "Berserker Helm",
		Slot = "Head",
		Type = "Monkey",
		AttackBonus = 10,
		DefenseBonus = -2,
		SpeedBonus = 0,
		Rarity = "Rare",
		Price = 600,
	},
	{
		Id = "void_gauntlets",
		Name = "Void Gauntlets",
		Slot = "Hands",
		Type = "Monkey",
		AttackBonus = 20,
		DefenseBonus = 10,
		SpeedBonus = 5,
		Rarity = "Legendary",
		Price = 5000,
	},
	-- Camel Equipment
	{
		Id = "basic_saddle",
		Name = "Basic Saddle",
		Slot = "Body",
		Type = "Camel",
		SpeedBonus = 2,
		StaminaBonus = 10,
		Rarity = "Common",
		Price = 120,
	},
	{
		Id = "racing_saddle",
		Name = "Racing Saddle",
		Slot = "Body",
		Type = "Camel",
		SpeedBonus = 5,
		StaminaBonus = 20,
		Rarity = "Rare",
		Price = 700,
	},
	{
		Id = "desert_shoes",
		Name = "Desert Shoes",
		Slot = "Feet",
		Type = "Camel",
		SpeedBonus = 3,
		StaminaBonus = 5,
		Rarity = "Common",
		Price = 100,
	},
	-- Lobster Equipment
	{
		Id = "shell_polish",
		Name = "Shell Polish",
		Slot = "Body",
		Type = "Lobster",
		SpeedBonus = 2,
		StaminaBonus = 10,
		Rarity = "Common",
		Price = 80,
	},
	{
		Id = "turbo_tail",
		Name = "Turbo Tail",
		Slot = "Tail",
		Type = "Lobster",
		SpeedBonus = 6,
		StaminaBonus = -5,
		Rarity = "Rare",
		Price = 500,
	},
	{
		Id = "golden_shell",
		Name = "Golden Shell",
		Slot = "Body",
		Type = "Lobster",
		SpeedBonus = 8,
		StaminaBonus = 20,
		Rarity = "Legendary",
		Price = 4000,
	},
}

-- ============================================================
-- EVOLUTION / TRAINING
-- ============================================================
GameConfig.Evolution = {
	MaxLevel = 100,
	BaseXPRequired = 100,
	XPScaling = 1.15, -- Each level requires 15% more XP
	TrainingCostBase = 50,
	TrainingCostScaling = 1.10,
	StatGainPerLevel = {
		HP = 5,
		Attack = 2,
		Defense = 1,
		Speed = 1,
	},
	-- Milestone evolutions (visual upgrades at these levels)
	Milestones = {10, 25, 50, 75, 100},
}

-- ============================================================
-- MAP AREAS
-- ============================================================
GameConfig.Areas = {
	{
		Id = "desert_track",
		Name = "Desert Race Track",
		Description = "A scorching desert track for camel racing",
		Position = Vector3.new(0, 0, 0),
		Size = Vector3.new(400, 10, 400),
		Theme = "Desert",
	},
	{
		Id = "aquarium_room",
		Name = "Aquarium Racing Hall",
		Description = "A themed aquarium room with lobster racing table",
		Position = Vector3.new(500, 0, 0),
		Size = Vector3.new(200, 50, 200),
		Theme = "Aquarium",
	},
	{
		Id = "monkey_arena",
		Name = "Monkey Fight Ring",
		Description = "An improvised fighting ring for monkey brawls",
		Position = Vector3.new(0, 0, 500),
		Size = Vector3.new(200, 50, 200),
		Theme = "Arena",
	},
	{
		Id = "betting_room",
		Name = "Vintage Betting Parlor",
		Description = "An old-school betting parlor with horse racing decor",
		Position = Vector3.new(500, 0, 500),
		Size = Vector3.new(200, 50, 200),
		Theme = "Vintage",
	},
}

-- ============================================================
-- GAME TIMING
-- ============================================================
GameConfig.Timing = {
	RaceDuration = 30,        -- seconds for a race
	FightMaxRounds = 20,      -- max rounds in a fight
	FightRoundDelay = 2,      -- seconds between rounds
	BettingWindowDuration = 30, -- seconds to place bets
	TimeBetweenEvents = 15,   -- seconds between events
	AutoSaveInterval = 60,    -- seconds between auto-saves
}

-- ============================================================
-- ANTI-EXPLOIT SETTINGS
-- ============================================================
GameConfig.Security = {
	MaxRequestsPerSecond = 10,
	MaxMoneyPerTransaction = 50000,
	SuspiciousActivityThreshold = 5,
	BanDuration = 3600, -- 1 hour in seconds
	ValidateAllRemotes = true,
}

-- ============================================================
-- STARTER PACK (What new players get)
-- ============================================================
GameConfig.StarterPack = {
	Monkeys = {"capuchin"},
	Camels = {"dromedary"},
	Lobsters = {"american_lobster"},
	Equipment = {"leather_gloves", "fighter_vest", "basic_saddle", "shell_polish"},
}

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
function GameConfig.GetMonkeyById(id)
	for _, monkey in ipairs(GameConfig.Monkeys) do
		if monkey.Id == id then return monkey end
	end
	return nil
end

function GameConfig.GetCamelById(id)
	for _, camel in ipairs(GameConfig.Camels) do
		if camel.Id == id then return camel end
	end
	return nil
end

function GameConfig.GetLobsterById(id)
	for _, lobster in ipairs(GameConfig.Lobsters) do
		if lobster.Id == id then return lobster end
	end
	return nil
end

function GameConfig.GetEquipmentById(id)
	for _, eq in ipairs(GameConfig.Equipment) do
		if eq.Id == id then return eq end
	end
	return nil
end

function GameConfig.GetMoveData(moveName)
	return GameConfig.Moves[moveName]
end

function GameConfig.CalculateXPForLevel(level)
	return math.floor(GameConfig.Evolution.BaseXPRequired * (GameConfig.Evolution.XPScaling ^ (level - 1)))
end

function GameConfig.CalculateTrainingCost(level)
	return math.floor(GameConfig.Evolution.TrainingCostBase * (GameConfig.Evolution.TrainingCostScaling ^ (level - 1)))
end

function GameConfig.RollRarity()
	local totalWeight = 0
	for _, data in pairs(GameConfig.Rarities) do
		totalWeight = totalWeight + data.Weight
	end
	local roll = math.random() * totalWeight
	local cumulative = 0
	for rarity, data in pairs(GameConfig.Rarities) do
		cumulative = cumulative + data.Weight
		if roll <= cumulative then
			return rarity
		end
	end
	return "Common"
end

return GameConfig
