-- GameConfig.lua
-- Configuração compartilhada do jogo Arena Selvagem
-- Módulo de configuração central para todas as mecânicas do jogo

local GameConfig = {}

-- ============================================================
-- RARIDADES
-- ============================================================
GameConfig.Rarities = {
    Common = { Name = "Comum", Color = Color3.fromRGB(200, 200, 200), Multiplier = 1.0, Weight = 50 },
    Uncommon = { Name = "Incomum", Color = Color3.fromRGB(30, 200, 30), Multiplier = 1.2, Weight = 30 },
    Rare = { Name = "Raro", Color = Color3.fromRGB(30, 100, 255), Multiplier = 1.5, Weight = 13 },
    Epic = { Name = "Épico", Color = Color3.fromRGB(160, 30, 255), Multiplier = 2.0, Weight = 5 },
    Legendary = { Name = "Lendário", Color = Color3.fromRGB(255, 200, 0), Multiplier = 3.0, Weight = 1.8 },
    Mythic = { Name = "Mítico", Color = Color3.fromRGB(255, 50, 50), Multiplier = 5.0, Weight = 0.2 },
}

-- ============================================================
-- MACACOS (Lutadores)
-- ============================================================
GameConfig.Monkeys = {
    {
        Id = "capuchin",
        Name = "Macaco-Prego",
        Rarity = "Common",
        BaseStats = { HP = 100, ATK = 15, DEF = 10, SPD = 12, CRIT = 5 },
        Skills = {"Soco Rápido", "Mordida"},
        EvolutionChain = {"capuchin", "capuchin_alpha", "capuchin_prime"},
        Description = "Um macaco ágil e esperto, ótimo para iniciantes."
    },
    {
        Id = "gorilla",
        Name = "Gorila",
        Rarity = "Rare",
        BaseStats = { HP = 200, ATK = 30, DEF = 25, SPD = 6, CRIT = 8 },
        Skills = {"Soco Devastador", "Rugido Intimidante", "Esmagar"},
        EvolutionChain = {"gorilla", "gorilla_silverback", "gorilla_king"},
        Description = "Um bruto poderoso com força descomunal."
    },
    {
        Id = "mandrill",
        Name = "Mandril",
        Rarity = "Uncommon",
        BaseStats = { HP = 130, ATK = 22, DEF = 15, SPD = 10, CRIT = 10 },
        Skills = {"Garra Afiada", "Grito de Guerra"},
        EvolutionChain = {"mandrill", "mandrill_elder", "mandrill_sage"},
        Description = "Colorido e perigoso, equilibra ataque e defesa."
    },
    {
        Id = "orangutan",
        Name = "Orangotango",
        Rarity = "Uncommon",
        BaseStats = { HP = 170, ATK = 18, DEF = 22, SPD = 7, CRIT = 6 },
        Skills = {"Abraço Esmagador", "Defesa Natural"},
        EvolutionChain = {"orangutan", "orangutan_wise", "orangutan_ancient"},
        Description = "Sábio e resistente, excelente tanque."
    },
    {
        Id = "spider_monkey",
        Name = "Macaco-Aranha",
        Rarity = "Common",
        BaseStats = { HP = 85, ATK = 12, DEF = 8, SPD = 18, CRIT = 12 },
        Skills = {"Ataque Aéreo", "Esquiva Ágil"},
        EvolutionChain = {"spider_monkey", "spider_monkey_phantom", "spider_monkey_shadow"},
        Description = "Extremamente rápido, mestre da esquiva."
    },
    {
        Id = "golden_tamarin",
        Name = "Mico-Leão-Dourado",
        Rarity = "Epic",
        BaseStats = { HP = 120, ATK = 25, DEF = 18, SPD = 15, CRIT = 15 },
        Skills = {"Brilho Dourado", "Fúria Solar", "Golpe Reluzente"},
        EvolutionChain = {"golden_tamarin", "golden_tamarin_radiant", "golden_tamarin_celestial"},
        Description = "Raro e brilhante, combina velocidade com poder."
    },
    {
        Id = "baboon_king",
        Name = "Rei Babuíno",
        Rarity = "Legendary",
        BaseStats = { HP = 250, ATK = 35, DEF = 30, SPD = 10, CRIT = 12 },
        Skills = {"Comando Real", "Fúria do Rei", "Escudo Tribal", "Rugido Ancestral"},
        EvolutionChain = {"baboon_king", "baboon_emperor", "baboon_god"},
        Description = "O rei dos primatas, lidera com força e sabedoria."
    },
    {
        Id = "shadow_chimp",
        Name = "Chimpanzé das Sombras",
        Rarity = "Mythic",
        BaseStats = { HP = 180, ATK = 40, DEF = 20, SPD = 20, CRIT = 25 },
        Skills = {"Golpe Sombrio", "Teleporte Noturno", "Fúria das Trevas", "Eclipse Total"},
        EvolutionChain = {"shadow_chimp", "shadow_chimp_void", "shadow_chimp_abyss"},
        Description = "Uma lenda viva, manipula as sombras em combate."
    },
}

-- ============================================================
-- CAMELOS (Corredores do Deserto)
-- ============================================================
GameConfig.Camels = {
    {
        Id = "dromedary",
        Name = "Dromedário",
        Rarity = "Common",
        BaseStats = { SPD = 10, STA = 15, ACC = 8, LUCK = 5 },
        Description = "Um camelo confiável para corridas curtas."
    },
    {
        Id = "bactrian",
        Name = "Camelo Bactriano",
        Rarity = "Common",
        BaseStats = { SPD = 8, STA = 20, ACC = 7, LUCK = 5 },
        Description = "Resistente e estável, bom para longas distâncias."
    },
    {
        Id = "racing_camel",
        Name = "Camelo de Corrida",
        Rarity = "Uncommon",
        BaseStats = { SPD = 14, STA = 12, ACC = 12, LUCK = 7 },
        Description = "Treinado especificamente para velocidade."
    },
    {
        Id = "desert_wind",
        Name = "Vento do Deserto",
        Rarity = "Rare",
        BaseStats = { SPD = 18, STA = 14, ACC = 15, LUCK = 10 },
        Description = "Rápido como o vento das dunas."
    },
    {
        Id = "sandstorm",
        Name = "Tempestade de Areia",
        Rarity = "Epic",
        BaseStats = { SPD = 22, STA = 18, ACC = 18, LUCK = 13 },
        Description = "Uma força da natureza nas pistas."
    },
    {
        Id = "golden_hump",
        Name = "Corcova Dourada",
        Rarity = "Legendary",
        BaseStats = { SPD = 25, STA = 22, ACC = 20, LUCK = 18 },
        Description = "Lendário corredor do deserto, quase imbatível."
    },
    {
        Id = "phantom_camel",
        Name = "Camelo Fantasma",
        Rarity = "Mythic",
        BaseStats = { SPD = 30, STA = 25, ACC = 25, LUCK = 22 },
        Description = "Dizem que ele é apenas uma miragem... até cruzar a linha de chegada."
    },
}

-- ============================================================
-- LAGOSTINS (Corredores Aquáticos)
-- ============================================================
GameConfig.Lobsters = {
    {
        Id = "red_claw",
        Name = "Garra Vermelha",
        Rarity = "Common",
        BaseStats = { SPD = 8, STA = 10, ACC = 6, LUCK = 5 },
        Description = "Um lagostim comum, mas determinado."
    },
    {
        Id = "blue_shell",
        Name = "Carapaça Azul",
        Rarity = "Common",
        BaseStats = { SPD = 7, STA = 12, ACC = 7, LUCK = 6 },
        Description = "Resistente e constante na corrida."
    },
    {
        Id = "swift_pincer",
        Name = "Pinça Veloz",
        Rarity = "Uncommon",
        BaseStats = { SPD = 12, STA = 9, ACC = 11, LUCK = 8 },
        Description = "Surpreendentemente rápido para seu tamanho."
    },
    {
        Id = "coral_runner",
        Name = "Corredor de Coral",
        Rarity = "Rare",
        BaseStats = { SPD = 15, STA = 13, ACC = 14, LUCK = 11 },
        Description = "Criado entre corais, navega com precisão."
    },
    {
        Id = "electric_lobster",
        Name = "Lagostim Elétrico",
        Rarity = "Epic",
        BaseStats = { SPD = 19, STA = 15, ACC = 17, LUCK = 14 },
        Description = "Emite descargas que o impulsionam à frente."
    },
    {
        Id = "golden_lobster",
        Name = "Lagostim Dourado",
        Rarity = "Legendary",
        BaseStats = { SPD = 23, STA = 20, ACC = 20, LUCK = 18 },
        Description = "Extremamente raro, brilha nas corridas."
    },
    {
        Id = "abyssal_king",
        Name = "Rei Abissal",
        Rarity = "Mythic",
        BaseStats = { SPD = 28, STA = 24, ACC = 24, LUCK = 22 },
        Description = "Das profundezas do oceano, uma criatura lendária."
    },
}

-- ============================================================
-- EQUIPAMENTOS
-- ============================================================
GameConfig.Equipment = {
    -- Luvas de combate (Macacos)
    { Id = "basic_gloves", Name = "Luvas Básicas", Type = "Weapon", Slot = "Hands", Rarity = "Common", Stats = { ATK = 3 }, Price = 100 },
    { Id = "iron_gloves", Name = "Luvas de Ferro", Type = "Weapon", Slot = "Hands", Rarity = "Uncommon", Stats = { ATK = 7, DEF = 2 }, Price = 350 },
    { Id = "steel_gauntlets", Name = "Manoplas de Aço", Type = "Weapon", Slot = "Hands", Rarity = "Rare", Stats = { ATK = 12, DEF = 5, CRIT = 3 }, Price = 800 },
    { Id = "golden_fists", Name = "Punhos Dourados", Type = "Weapon", Slot = "Hands", Rarity = "Epic", Stats = { ATK = 20, DEF = 8, CRIT = 7 }, Price = 2000 },
    { Id = "shadow_claws", Name = "Garras Sombrias", Type = "Weapon", Slot = "Hands", Rarity = "Legendary", Stats = { ATK = 35, CRIT = 15, SPD = 5 }, Price = 5000 },
    -- Armaduras (Macacos)
    { Id = "leather_vest", Name = "Colete de Couro", Type = "Armor", Slot = "Body", Rarity = "Common", Stats = { DEF = 5, HP = 10 }, Price = 120 },
    { Id = "chain_mail", Name = "Cota de Malha", Type = "Armor", Slot = "Body", Rarity = "Uncommon", Stats = { DEF = 12, HP = 25 }, Price = 400 },
    { Id = "plate_armor", Name = "Armadura de Placas", Type = "Armor", Slot = "Body", Rarity = "Rare", Stats = { DEF = 22, HP = 50, SPD = -2 }, Price = 950 },
    { Id = "royal_armor", Name = "Armadura Real", Type = "Armor", Slot = "Body", Rarity = "Epic", Stats = { DEF = 35, HP = 80 }, Price = 2500 },
    -- Acessórios para corrida (Camelos/Lagostins)
    { Id = "basic_saddle", Name = "Sela Básica", Type = "RaceGear", Slot = "Saddle", Rarity = "Common", Stats = { SPD = 2, STA = 1 }, Price = 80 },
    { Id = "racing_saddle", Name = "Sela de Corrida", Type = "RaceGear", Slot = "Saddle", Rarity = "Uncommon", Stats = { SPD = 5, ACC = 3 }, Price = 300 },
    { Id = "champion_saddle", Name = "Sela do Campeão", Type = "RaceGear", Slot = "Saddle", Rarity = "Rare", Stats = { SPD = 8, ACC = 5, STA = 4 }, Price = 750 },
    { Id = "lucky_horseshoe", Name = "Ferradura da Sorte", Type = "Accessory", Slot = "Accessory", Rarity = "Uncommon", Stats = { LUCK = 5 }, Price = 250 },
    { Id = "speed_charm", Name = "Amuleto de Velocidade", Type = "Accessory", Slot = "Accessory", Rarity = "Rare", Stats = { SPD = 6, ACC = 4 }, Price = 600 },
    { Id = "golden_charm", Name = "Amuleto Dourado", Type = "Accessory", Slot = "Accessory", Rarity = "Epic", Stats = { SPD = 10, LUCK = 8, ACC = 6 }, Price = 1800 },
}

-- ============================================================
-- EVOLUÇÃO INCREMENTAL
-- ============================================================
GameConfig.Evolution = {
    MaxLevel = 100,
    ExpPerLevel = function(level)
        return math.floor(100 * (level ^ 1.5))
    end,
    StatGrowthPerLevel = {
        HP = 2,
        ATK = 1,
        DEF = 1,
        SPD = 0.5,
        CRIT = 0.3,
        STA = 0.8,
        ACC = 0.4,
        LUCK = 0.2,
    },
    EvolutionLevels = { 30, 60 }, -- Níveis em que o animal evolui
    TrainingCostPerSession = function(level)
        return math.floor(50 * (1 + level * 0.15))
    end,
    TrainingExpGain = function(level)
        return math.floor(30 + level * 2)
    end,
}

-- ============================================================
-- APOSTAS
-- ============================================================
GameConfig.Betting = {
    MinBet = 10,
    MaxBet = 10000,
    HouseEdge = 0.05, -- 5% de margem da casa
    PayoutMultipliers = {
        MonkeyFight = { Win = 1.8, Draw = 3.0 },
        CamelRace = { First = 2.5, Second = 1.5, Third = 1.1 },
        LobsterRace = { First = 2.5, Second = 1.5, Third = 1.1 },
    },
    MaxConcurrentBets = 3,
}

-- ============================================================
-- CONFIGURAÇÕES DA IA
-- ============================================================
GameConfig.AI = {
    FightDuration = { Min = 30, Max = 90 }, -- segundos
    RaceDuration = { Min = 20, Max = 60 }, -- segundos
    FightTickRate = 1.0, -- segundos entre ações
    RaceTickRate = 0.5, -- segundos entre atualizações
    RaceTrackLength = 100, -- unidades
    MaxFightersPerMatch = 2,
    MaxRacersPerRace = 6,
    FightActions = {"attack", "defend", "special", "dodge"},
    ActionWeights = {
        attack = 40,
        defend = 20,
        special = 25,
        dodge = 15,
    },
}

-- ============================================================
-- TROCAS
-- ============================================================
GameConfig.Trading = {
    MaxItemsPerTrade = 6,
    TradeCooldown = 30, -- segundos entre trocas
    MinLevelToTrade = 5, -- nível mínimo do jogador
    TaxRate = 0.02, -- 2% de taxa em trocas de dinheiro
}

-- ============================================================
-- CONFIGURAÇÕES DO JOGADOR
-- ============================================================
GameConfig.Player = {
    StartingCoins = 500,
    MaxInventorySlots = 50,
    MaxCreatures = 20,
    DailyLoginReward = 100,
    StarterPack = {
        Monkey = "capuchin",
        Coins = 500,
    },
}

-- ============================================================
-- MAPA
-- ============================================================
GameConfig.Map = {
    Areas = {
        {
            Name = "Pista do Deserto",
            Description = "Uma pista de corrida de camelos em um vasto deserto",
            Type = "CamelRace",
            Position = Vector3.new(0, 0, 0),
            Size = Vector3.new(400, 50, 200),
        },
        {
            Name = "Sala dos Aquários",
            Description = "Uma sala temática de aquários com mesa de corrida de lagostins",
            Type = "LobsterRace",
            Position = Vector3.new(500, 0, 0),
            Size = Vector3.new(150, 30, 150),
        },
        {
            Name = "Ringue dos Primatas",
            Description = "Um ringue improvisado para rinha de macacos",
            Type = "MonkeyFight",
            Position = Vector3.new(-300, 0, 0),
            Size = Vector3.new(100, 30, 100),
        },
        {
            Name = "Sala de Apostas",
            Description = "Uma sala vintage de apostas inspirada em corridas de cavalos",
            Type = "BettingRoom",
            Position = Vector3.new(0, 0, -300),
            Size = Vector3.new(200, 25, 200),
        },
    },
}

return GameConfig
