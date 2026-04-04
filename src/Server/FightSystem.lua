--[[
    FightSystem.lua
    Server-side AI-controlled monkey fight system for Arena Selvagem.

    Players are spectators only — the AI decides every combat action for both
    fighters.  All damage, crits, dodges, and special-move calculations happen
    on the server; clients only receive broadcast events for rendering.

    Public API (returned table):
        Initialize()                        – start the auto-fight loop
        StartFight(monkey1Data, monkey2Data) – begin a single match
        GetCurrentFight()                    – snapshot of the active fight
        GetFightHistory()                    – ordered list of past results
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GameConfig        = require(script.Parent.Parent.Shared.GameConfig)
local DataStoreManager  = require(script.Parent.DataStoreManager)

-- ============================================================
-- Remote Events (created once, reused every fight)
-- ============================================================
local function getOrCreateRemote(name)
    local folder = ReplicatedStorage:FindFirstChild("FightEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "FightEvents"
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
-- Module table
-- ============================================================
local FightSystem = {}

local fightHistory    = {} -- ordered list of FightResult tables
local currentFight    = nil -- nil when idle
local activeBets      = {} -- [UserId] = { MonkeyIndex = 1|2, Amount = n }
local autoFightActive = false

local MAX_HISTORY     = 50
local AUTO_FIGHT_MIN  = 120 -- seconds between auto-fights
local AUTO_FIGHT_MAX  = 180

-- Lazy-initialised remotes (populated in Initialize)
local Remotes = {}

-- ============================================================
-- Equipment helpers
-- ============================================================

--- Build a lookup table { [equipId] = equipConfig } for O(1) access.
local equipmentById = {}
for _, equip in ipairs(GameConfig.Equipment) do
    equipmentById[equip.Id] = equip
end

--- Given a list of equipment IDs, accumulate stat bonuses.
local function computeEquipmentBonuses(equipIds)
    local bonuses = { HP = 0, ATK = 0, DEF = 0, SPD = 0, CRIT = 0 }
    if not equipIds then
        return bonuses
    end
    for _, id in ipairs(equipIds) do
        local equip = equipmentById[id]
        if equip and equip.Stats then
            for stat, value in pairs(equip.Stats) do
                if bonuses[stat] ~= nil then
                    bonuses[stat] = bonuses[stat] + value
                end
            end
        end
    end
    return bonuses
end

-- ============================================================
-- Fighter construction
-- ============================================================

--- Resolve the full effective stats for a fighter.
--- `monkeyData` is expected to carry at minimum:
---     .Id           – monkey template id (e.g. "gorilla")
---     .Level        – current level (default 1)
---     .Equipment    – optional list of equipped item ids
---     .Nickname     – optional display name override
--- The base template is looked up from GameConfig.Monkeys.
local monkeyTemplateById = {}
for _, m in ipairs(GameConfig.Monkeys) do
    monkeyTemplateById[m.Id] = m
end

local function buildFighter(monkeyData)
    local template = monkeyTemplateById[monkeyData.Id]
    assert(template, "Unknown monkey id: " .. tostring(monkeyData.Id))

    local level = monkeyData.Level or 1
    local rarity = GameConfig.Rarities[template.Rarity] or GameConfig.Rarities.Common
    local growth = GameConfig.Evolution.StatGrowthPerLevel

    -- Base + per-level growth, scaled by rarity multiplier
    local stats = {}
    for stat, base in pairs(template.BaseStats) do
        local perLevel = growth[stat] or 0
        stats[stat] = math.floor((base + perLevel * (level - 1)) * rarity.Multiplier)
    end

    -- Equipment bonuses (additive, after rarity scaling)
    local bonuses = computeEquipmentBonuses(monkeyData.Equipment)
    for stat, bonus in pairs(bonuses) do
        if stats[stat] then
            stats[stat] = stats[stat] + bonus
        end
    end

    -- Ensure HP floor
    stats.HP = math.max(stats.HP, 1)

    return {
        Id            = template.Id,
        Name          = monkeyData.Nickname or template.Name,
        Rarity        = template.Rarity,
        Level         = level,
        Skills        = template.Skills,
        Stats         = stats,
        MaxHP         = stats.HP,
        CurrentHP     = stats.HP,
        SpecialCooldown = 0, -- turns remaining until special is available
    }
end

-- ============================================================
-- AI action selection
-- ============================================================

local BASE_WEIGHTS = GameConfig.AI.ActionWeights -- { attack, defend, special, dodge }
local ACTIONS      = GameConfig.AI.FightActions   -- {"attack","defend","special","dodge"}

--- Return a weighted-random action for `fighter` given opponent state.
--- Weights are influenced by the fighter's own stats and cooldown state.
local function pickAction(fighter, opponent)
    -- Start from a copy of base weights
    local weights = {}
    for _, action in ipairs(ACTIONS) do
        weights[action] = BASE_WEIGHTS[action] or 0
    end

    -- Stat-based adjustments --------------------------------------------------

    -- High-ATK fighters lean towards attacking
    weights.attack = weights.attack + fighter.Stats.ATK * 0.5

    -- High-DEF fighters are more defensive
    weights.defend = weights.defend + fighter.Stats.DEF * 0.4

    -- High-SPD fighters dodge more
    weights.dodge = weights.dodge + fighter.Stats.SPD * 0.6

    -- High-CRIT fighters like specials (big-damage opportunity)
    weights.special = weights.special + fighter.Stats.CRIT * 0.5

    -- Situational adjustments -------------------------------------------------

    -- Low HP? favour defence & dodge
    local hpRatio = fighter.CurrentHP / fighter.MaxHP
    if hpRatio < 0.3 then
        weights.defend = weights.defend * 1.5
        weights.dodge  = weights.dodge  * 1.4
    end

    -- Opponent low HP? favour attack / special for the finish
    local oppHpRatio = opponent.CurrentHP / opponent.MaxHP
    if oppHpRatio < 0.25 then
        weights.attack  = weights.attack * 1.6
        weights.special = weights.special * 1.4
    end

    -- If special is on cooldown, zero its weight
    if fighter.SpecialCooldown > 0 then
        weights.special = 0
    end

    -- Weighted random selection ------------------------------------------------
    local totalWeight = 0
    for _, action in ipairs(ACTIONS) do
        totalWeight = totalWeight + weights[action]
    end
    if totalWeight <= 0 then
        return "attack"
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, action in ipairs(ACTIONS) do
        cumulative = cumulative + weights[action]
        if roll <= cumulative then
            return action
        end
    end
    return "attack" -- fallback
end

-- ============================================================
-- Damage & combat resolution helpers
-- ============================================================

local SPECIAL_DAMAGE_MULT = 2.0
local SPECIAL_COOLDOWN    = 3  -- turns

--- Calculate raw damage before defence.
local function calcBaseDamage(attackerStats, isSpecial)
    local base = attackerStats.ATK
    -- Add ±15 % variance so fights aren't deterministic
    local variance = base * (math.random(-15, 15) / 100)
    local dmg = base + variance
    if isSpecial then
        dmg = dmg * SPECIAL_DAMAGE_MULT
    end
    return math.max(math.floor(dmg), 1)
end

--- Apply defence reduction.  DEF softcap: each point of DEF reduces damage by
--- roughly 0.7 %, capped at 70 % reduction.
local function applyDefence(rawDamage, defenderDEF, isDefending)
    local effectiveDEF = defenderDEF
    if isDefending then
        effectiveDEF = effectiveDEF * 1.5 -- defending stance boosts DEF 50 %
    end
    local reduction = math.min(effectiveDEF * 0.007, 0.70)
    return math.max(math.floor(rawDamage * (1 - reduction)), 1)
end

--- Roll a critical hit.  Returns true with probability = CRIT %.
local function rollCrit(critStat)
    local chance = math.min(critStat, 80) -- hard cap 80 %
    return math.random(1, 100) <= chance
end

--- Roll a dodge.  Dodge chance = SPD * 0.8 %, capped at 40 %.
local function rollDodge(spdStat)
    local chance = math.min(spdStat * 0.8, 40)
    return math.random(1, 100) <= chance
end

local CRIT_DAMAGE_MULT = 1.5

-- ============================================================
-- Broadcast helpers
-- ============================================================

local function broadcast(eventName, ...)
    local remote = Remotes[eventName]
    if not remote then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        remote:FireClient(player, ...)
    end
end

-- ============================================================
-- Betting
-- ============================================================

local function clearBets()
    activeBets = {}
end

--- Validate and record a bet. Called via RemoteEvent from clients.
local function onPlaceBet(player, monkeyIndex, amount)
    if not currentFight or currentFight.State ~= "BettingOpen" then
        return
    end
    if activeBets[player.UserId] then
        return -- one bet per fight
    end
    if type(monkeyIndex) ~= "number" or (monkeyIndex ~= 1 and monkeyIndex ~= 2) then
        return
    end
    if type(amount) ~= "number" then
        return
    end

    local cfg = GameConfig.Betting
    amount = math.floor(amount)
    if amount < cfg.MinBet or amount > cfg.MaxBet then
        return
    end

    -- Deduct coins via DataStoreManager (validates balance internally)
    local success = DataStoreManager.RemoveCoins(player, amount)
    if not success then
        return
    end

    activeBets[player.UserId] = {
        MonkeyIndex = monkeyIndex,
        Amount = amount,
    }

    broadcast("BetConfirmed", player.UserId, monkeyIndex, amount)
end

--- Pay out winning bets after a fight finishes.
local function resolveBets(winnerIndex)
    local multiplier = GameConfig.Betting.PayoutMultipliers.MonkeyFight
    local houseEdge  = GameConfig.Betting.HouseEdge

    local payouts = {} -- { { UserId, Amount } }

    for userId, bet in pairs(activeBets) do
        local payout = 0
        if winnerIndex == 0 then
            -- Draw: return stake × draw multiplier minus house edge
            payout = math.floor(bet.Amount * multiplier.Draw * (1 - houseEdge))
        elseif bet.MonkeyIndex == winnerIndex then
            payout = math.floor(bet.Amount * multiplier.Win * (1 - houseEdge))
        end
        -- else: player loses stake (already deducted)

        if payout > 0 then
            -- Look up the Player instance; they may have disconnected
            local player = Players:GetPlayerByUserId(userId)
            if player then
                DataStoreManager.AddCoins(player, payout)
            end
        end

        table.insert(payouts, { UserId = userId, Payout = payout, Bet = bet.Amount, Won = (payout > 0) })
    end

    broadcast("BetResults", payouts)
    clearBets()
end

-- ============================================================
-- Monkey pool for auto-matching
-- ============================================================

--- Pick two distinct random monkeys from the GameConfig pool, assigning
--- random levels so each auto-fight feels different.
local function pickRandomPair()
    local pool = GameConfig.Monkeys
    local count = #pool
    assert(count >= 2, "Need at least 2 monkey templates for auto-fights")

    local i = math.random(1, count)
    local j
    repeat
        j = math.random(1, count)
    until j ~= i

    local function randomMonkeyData(template)
        return {
            Id    = template.Id,
            Level = math.random(1, GameConfig.Evolution.MaxLevel),
        }
    end

    return randomMonkeyData(pool[i]), randomMonkeyData(pool[j])
end

-- ============================================================
-- Core fight loop
-- ============================================================

--- Resolve a single turn.  Returns a `turnLog` table describing what happened.
local function resolveTurn(fighter1, fighter2, turnNumber)
    -- Determine action order by SPD (faster acts first)
    local first, second
    if fighter1.Stats.SPD >= fighter2.Stats.SPD then
        first, second = fighter1, fighter2
    else
        first, second = fighter2, fighter1
    end

    -- Tiebreaker: if SPD equal, randomise
    if fighter1.Stats.SPD == fighter2.Stats.SPD and math.random() < 0.5 then
        first, second = second, first
    end

    local log = {
        Turn = turnNumber,
        Events = {},
    }

    local function resolveAction(attacker, defender)
        if attacker.CurrentHP <= 0 then
            return
        end

        local action = pickAction(attacker, defender)
        local event = {
            Fighter  = attacker.Name,
            Action   = action,
            Damage   = 0,
            IsCrit   = false,
            IsDodged = false,
            IsDefending = false,
            HPAfter  = defender.CurrentHP,
        }

        if action == "defend" then
            event.IsDefending = true
            -- Defending is passive; its effect applies when *receiving* damage
            -- (handled below).  We record the stance so the next incoming hit
            -- sees it.
            attacker._defending = true

        elseif action == "dodge" then
            -- Dodge is an offensive-turn skip; fighter focuses on evasion.
            attacker._dodging = true

        elseif action == "attack" or action == "special" then
            local isSpecial = (action == "special")

            -- Check if defender dodges
            if defender._dodging and rollDodge(defender.Stats.SPD) then
                event.IsDodged = true
                event.Damage   = 0
            else
                local raw  = calcBaseDamage(attacker.Stats, isSpecial)
                local crit = rollCrit(attacker.Stats.CRIT)
                if crit then
                    raw = math.floor(raw * CRIT_DAMAGE_MULT)
                    event.IsCrit = true
                end
                local dmg = applyDefence(raw, defender.Stats.DEF, defender._defending)
                defender.CurrentHP = math.max(defender.CurrentHP - dmg, 0)
                event.Damage  = dmg
                event.HPAfter = defender.CurrentHP
            end

            if isSpecial then
                attacker.SpecialCooldown = SPECIAL_COOLDOWN
            end
        end

        table.insert(log.Events, event)
    end

    -- Clear transient flags before the turn
    first._defending  = false
    second._defending = false
    first._dodging    = false
    second._dodging   = false

    -- First fighter acts
    resolveAction(first, second)

    -- Second fighter acts (only if still alive)
    resolveAction(second, first)

    -- Tick cooldowns down at end of turn
    for _, f in ipairs({fighter1, fighter2}) do
        if f.SpecialCooldown > 0 then
            f.SpecialCooldown = f.SpecialCooldown - 1
        end
    end

    return log
end

--- Run a complete fight and return the result table.
--- This function yields (calls task.wait) and should be called inside
--- task.spawn.
local function executeFight(fighter1, fighter2)
    local tickRate = GameConfig.AI.FightTickRate
    local maxTurns = GameConfig.AI.FightDuration.Max -- safety cap
    local turnNumber = 0
    local turnLogs = {}

    while fighter1.CurrentHP > 0 and fighter2.CurrentHP > 0 and turnNumber < maxTurns do
        turnNumber = turnNumber + 1
        local log = resolveTurn(fighter1, fighter2, turnNumber)
        table.insert(turnLogs, log)

        -- Broadcast the turn to all spectators
        broadcast("FightTurnUpdate", {
            Turn   = turnNumber,
            Events = log.Events,
            Fighter1HP = fighter1.CurrentHP,
            Fighter2HP = fighter2.CurrentHP,
        })

        -- Tick delay
        task.wait(tickRate)
    end

    -- Determine winner
    local winnerIndex = 0 -- 0 = draw
    local winnerName  = "Draw"
    if fighter1.CurrentHP > 0 and fighter2.CurrentHP <= 0 then
        winnerIndex = 1
        winnerName  = fighter1.Name
    elseif fighter2.CurrentHP > 0 and fighter1.CurrentHP <= 0 then
        winnerIndex = 2
        winnerName  = fighter2.Name
    elseif fighter1.CurrentHP > fighter2.CurrentHP then
        winnerIndex = 1
        winnerName  = fighter1.Name
    elseif fighter2.CurrentHP > fighter1.CurrentHP then
        winnerIndex = 2
        winnerName  = fighter2.Name
    end

    local result = {
        WinnerIndex  = winnerIndex,
        WinnerName   = winnerName,
        TotalTurns   = turnNumber,
        Fighter1     = {
            Name  = fighter1.Name,
            FinalHP = fighter1.CurrentHP,
            MaxHP   = fighter1.MaxHP,
        },
        Fighter2     = {
            Name  = fighter2.Name,
            FinalHP = fighter2.CurrentHP,
            MaxHP   = fighter2.MaxHP,
        },
        TurnLogs     = turnLogs,
        Timestamp    = os.time(),
    }

    return result, winnerIndex
end

-- ============================================================
-- Public API
-- ============================================================

--- Start a single fight between two monkey data tables.
--- Returns immediately; the fight runs asynchronously.
function FightSystem.StartFight(monkey1Data, monkey2Data)
    if currentFight and currentFight.State == "InProgress" then
        warn("[FightSystem] A fight is already in progress.")
        return nil
    end

    local fighter1 = buildFighter(monkey1Data)
    local fighter2 = buildFighter(monkey2Data)

    currentFight = {
        State    = "BettingOpen",
        Fighter1 = fighter1,
        Fighter2 = fighter2,
        StartedAt = os.clock(),
        Result   = nil,
    }

    -- Broadcast fight announcement so clients can place bets
    broadcast("FightAnnounced", {
        Fighter1 = { Name = fighter1.Name, Rarity = fighter1.Rarity, Level = fighter1.Level, Stats = fighter1.Stats },
        Fighter2 = { Name = fighter2.Name, Rarity = fighter2.Rarity, Level = fighter2.Level, Stats = fighter2.Stats },
    })

    -- Allow 15 seconds for betting, then start
    task.spawn(function()
        task.wait(15)

        if not currentFight then
            return
        end

        currentFight.State = "InProgress"
        broadcast("FightStarted", {
            Fighter1 = fighter1.Name,
            Fighter2 = fighter2.Name,
        })

        local result, winnerIndex = executeFight(fighter1, fighter2)
        currentFight.State  = "Finished"
        currentFight.Result = result

        -- Record in history
        table.insert(fightHistory, result)
        if #fightHistory > MAX_HISTORY then
            table.remove(fightHistory, 1)
        end

        broadcast("FightEnded", result)

        -- Resolve bets
        resolveBets(winnerIndex)

        -- Clear fight state after a short cooldown so spectators can read the
        -- result before the next fight is announced.
        task.wait(10)
        currentFight = nil
    end)

    return currentFight
end

--- Return a read-only snapshot of the current fight, or nil if idle.
function FightSystem.GetCurrentFight()
    if not currentFight then
        return nil
    end
    return {
        State    = currentFight.State,
        Fighter1 = {
            Name      = currentFight.Fighter1.Name,
            Rarity    = currentFight.Fighter1.Rarity,
            Level     = currentFight.Fighter1.Level,
            CurrentHP = currentFight.Fighter1.CurrentHP,
            MaxHP     = currentFight.Fighter1.MaxHP,
            Stats     = currentFight.Fighter1.Stats,
        },
        Fighter2 = {
            Name      = currentFight.Fighter2.Name,
            Rarity    = currentFight.Fighter2.Rarity,
            Level     = currentFight.Fighter2.Level,
            CurrentHP = currentFight.Fighter2.CurrentHP,
            MaxHP     = currentFight.Fighter2.MaxHP,
            Stats     = currentFight.Fighter2.Stats,
        },
        Result = currentFight.Result,
    }
end

--- Return the ordered list of past fight results (newest last).
function FightSystem.GetFightHistory()
    -- Return a shallow copy so callers can't mutate internal state
    local copy = {}
    for i, entry in ipairs(fightHistory) do
        copy[i] = entry
    end
    return copy
end

--- Wire up RemoteEvents, connect the bet listener, and start the auto-fight
--- loop that picks random monkeys every 2-3 minutes.
function FightSystem.Initialize()
    if autoFightActive then
        warn("[FightSystem] Already initialized.")
        return
    end
    autoFightActive = true

    -- Create / fetch remotes
    local remoteNames = {
        "FightAnnounced",
        "FightStarted",
        "FightTurnUpdate",
        "FightEnded",
        "BetConfirmed",
        "BetResults",
        "PlaceBet",
    }
    for _, name in ipairs(remoteNames) do
        Remotes[name] = getOrCreateRemote(name)
    end

    -- Listen for incoming bets (server → client direction is handled by
    -- broadcast; client → server comes through PlaceBet).
    Remotes.PlaceBet.OnServerEvent:Connect(function(player, monkeyIndex, amount)
        onPlaceBet(player, monkeyIndex, amount)
    end)

    -- Auto-fight loop
    task.spawn(function()
        while autoFightActive do
            -- Wait until no fight is active
            while currentFight do
                task.wait(1)
            end

            -- Random delay between fights
            local delay = math.random(AUTO_FIGHT_MIN, AUTO_FIGHT_MAX)
            task.wait(delay)

            -- Pick two random monkeys and start a fight
            local m1, m2 = pickRandomPair()
            FightSystem.StartFight(m1, m2)
        end
    end)
end

return FightSystem
