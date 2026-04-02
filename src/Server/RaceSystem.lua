--[[
    RaceSystem.lua
    AI-controlled race system for Camel and Lobster races.
    Players are spectators only — all race logic is server-side.

    Supports:
      - CamelRace (GameConfig.Camels)
      - LobsterRace (GameConfig.Lobsters)
      - 6 racers per race
      - Physics-based tick simulation (0.5s)
      - Stats: SPD, STA, ACC, LUCK
      - Random events: Speed Burst, Stumble, Second Wind
      - Betting with 1st/2nd/3rd payouts
      - Auto-cycling between race types every 2–3 minutes
]]

local RaceSystem = {}

-- ============================================================
-- Services & Dependencies
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

-- ============================================================
-- Constants (pulled from GameConfig where possible)
-- ============================================================

local TICK_RATE = GameConfig.AI.RaceTickRate           -- 0.5 seconds
local TRACK_LENGTH = GameConfig.AI.RaceTrackLength     -- 100 units
local MAX_RACERS = GameConfig.AI.MaxRacersPerRace      -- 6
local RACE_DURATION_MIN = GameConfig.AI.RaceDuration.Min
local RACE_DURATION_MAX = GameConfig.AI.RaceDuration.Max

local BETTING_WINDOW = 30   -- seconds players can place bets before race starts
local MAX_HISTORY = 50      -- max stored race results
local CYCLE_DELAY_MIN = 120 -- seconds between races (2 min)
local CYCLE_DELAY_MAX = 180 -- seconds between races (3 min)

-- Random‐event tuning
local EVENT_BASE_CHANCE = 0.08           -- 8% base chance per tick per racer
local LUCK_EVENT_SCALE = 0.003           -- extra chance per LUCK point
local SPEED_BURST_MULTIPLIER = 1.20      -- +20% speed
local SPEED_BURST_TICKS = 3
local STUMBLE_MULTIPLIER = 0.50          -- -50% speed
local STUMBLE_TICKS = 2
local SECOND_WIND_STAMINA_RESTORE = 0.30 -- restore 30% of max stamina

-- Stamina thresholds
local STAMINA_LOW_THRESHOLD = 0.30       -- below 30% → speed penalty begins
local STAMINA_SPEED_PENALTY = 0.40       -- max 40% speed reduction at 0 stamina
local STAMINA_DRAIN_BASE = 0.8           -- base stamina drain per tick (% of max STA)

-- Acceleration curve
local ACC_RAMP_TICKS = 10               -- ticks to approach top speed at average ACC

-- ============================================================
-- Module State
-- ============================================================

local Remotes = {}
local currentRace = nil           -- active race state table
local raceHistory = {}            -- array of completed race summaries
local activeBets = {}             -- [userId] = { RacerIndex, Amount }
local isRunning = false           -- module initialised flag
local lastRaceType = nil          -- "CamelRace" or "LobsterRace"

-- ============================================================
-- Remote Event Helpers
-- ============================================================

local function getOrCreateRemote(name)
    local folder = ReplicatedStorage:FindFirstChild("RaceEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RaceEvents"
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

local function broadcast(remoteName, data)
    local remote = Remotes[remoteName]
    if not remote then
        warn("[RaceSystem] Remote not found: " .. tostring(remoteName))
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        remote:FireClient(player, data)
    end
end

-- ============================================================
-- Stat Calculation Helpers
-- ============================================================

local function getRarityMultiplier(rarityName)
    local rarity = GameConfig.Rarities[rarityName]
    if rarity then
        return rarity.Multiplier
    end
    return 1.0
end

local function getEquipmentBonus(equipment, statName)
    local bonus = 0
    if not equipment then return bonus end
    for _, item in ipairs(equipment) do
        if item.Stats and item.Stats[statName] then
            bonus = bonus + item.Stats[statName]
        end
    end
    return bonus
end

--[[
    Build the runtime stat block for a racer.
    racerData expected fields:
        Type        – creature template key (e.g. "dromedary")
        Level       – integer level
        Rarity      – rarity key (e.g. "Rare")
        Equipment   – optional array of equipped items (each with Stats table)
        Name        – display name (optional, falls back to template name)
]]
local function buildRacer(racerData, raceType)
    local pool = raceType == "CamelRace" and GameConfig.Camels or GameConfig.Lobsters
    local template = nil
    for _, t in ipairs(pool) do
        if t.Id == racerData.Type then
            template = t
            break
        end
    end
    if not template then
        warn("[RaceSystem] Unknown creature type: " .. tostring(racerData.Type))
        return nil
    end

    local level = math.clamp(racerData.Level or 1, 1, GameConfig.Evolution.MaxLevel)
    local rarityMul = getRarityMultiplier(racerData.Rarity or "Common")
    local growth = GameConfig.Evolution.StatGrowthPerLevel

    local function calc(base, growthKey)
        local g = growth[growthKey] or 0
        return math.floor((base + g * (level - 1)) * rarityMul)
            + getEquipmentBonus(racerData.Equipment, growthKey)
    end

    local spd = calc(template.Stats.SPD, "SPD")
    local sta = calc(template.Stats.STA, "STA")
    local acc = calc(template.Stats.ACC, "ACC")
    local luck = calc(template.Stats.LUCK, "LUCK")

    return {
        -- Identity
        Id = racerData.Id or template.Id .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(1, 9999)),
        Name = racerData.Name or template.Name,
        Type = template.Id,
        Rarity = racerData.Rarity or "Common",
        Level = level,

        -- Computed stats
        SPD = spd,
        STA = sta,
        ACC = acc,
        LUCK = luck,

        -- Runtime state
        Position = 0,
        CurrentSpeed = 0,
        MaxStamina = sta,
        CurrentStamina = sta,
        TicksElapsed = 0,
        Finished = false,
        FinishTick = nil,
        FinishPlace = nil,

        -- Active effects: { { Type, TicksRemaining } }
        ActiveEffects = {},
    }
end

-- ============================================================
-- Random Event Logic
-- ============================================================

local EVENT_TYPES = { "SpeedBurst", "Stumble", "SecondWind" }

local function rollEvent(racer)
    local chance = EVENT_BASE_CHANCE + racer.LUCK * LUCK_EVENT_SCALE
    if math.random() > chance then
        return nil
    end

    -- Weighted pick — LUCK biases toward positive events
    local positiveWeight = 50 + racer.LUCK * 0.5
    local negativeWeight = math.max(50 - racer.LUCK * 0.3, 10)
    local weights = {
        SpeedBurst = positiveWeight,
        SecondWind = positiveWeight * 0.6,
        Stumble = negativeWeight,
    }

    local totalWeight = 0
    for _, w in pairs(weights) do
        totalWeight = totalWeight + w
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, eventType in ipairs(EVENT_TYPES) do
        cumulative = cumulative + weights[eventType]
        if roll <= cumulative then
            return eventType
        end
    end
    return EVENT_TYPES[1]
end

local function applyEvent(racer, eventType)
    if eventType == "SpeedBurst" then
        table.insert(racer.ActiveEffects, { Type = "SpeedBurst", TicksRemaining = SPEED_BURST_TICKS })
    elseif eventType == "Stumble" then
        table.insert(racer.ActiveEffects, { Type = "Stumble", TicksRemaining = STUMBLE_TICKS })
    elseif eventType == "SecondWind" then
        local restore = math.floor(racer.MaxStamina * SECOND_WIND_STAMINA_RESTORE)
        racer.CurrentStamina = math.min(racer.CurrentStamina + restore, racer.MaxStamina)
    end
end

local function getEffectMultiplier(racer)
    local mul = 1.0
    for _, effect in ipairs(racer.ActiveEffects) do
        if effect.Type == "SpeedBurst" then
            mul = mul * SPEED_BURST_MULTIPLIER
        elseif effect.Type == "Stumble" then
            mul = mul * STUMBLE_MULTIPLIER
        end
    end
    return mul
end

local function tickEffects(racer)
    local i = 1
    while i <= #racer.ActiveEffects do
        racer.ActiveEffects[i].TicksRemaining = racer.ActiveEffects[i].TicksRemaining - 1
        if racer.ActiveEffects[i].TicksRemaining <= 0 then
            table.remove(racer.ActiveEffects, i)
        else
            i = i + 1
        end
    end
end

-- ============================================================
-- Core Tick Simulation
-- ============================================================

local function simulateTick(race)
    race.Tick = race.Tick + 1
    local tickEvents = {}
    local finishedThisTick = {}

    for idx, racer in ipairs(race.Racers) do
        if racer.Finished then continue end

        racer.TicksElapsed = racer.TicksElapsed + 1

        -- 1. Acceleration ramp — approaches top speed over time
        local accFactor = math.min(1.0, racer.TicksElapsed / math.max(1, ACC_RAMP_TICKS - racer.ACC * 0.08))

        -- 2. Base speed with small random variance (±10%) influenced by LUCK
        local variance = 1.0 + (math.random() - 0.5) * 0.20
        local luckSmoothing = 1.0 + racer.LUCK * 0.001  -- tiny consistent bonus
        local baseSpeed = racer.SPD * 0.1 * accFactor * variance * luckSmoothing

        -- 3. Stamina drain
        local drainRate = STAMINA_DRAIN_BASE + racer.SPD * 0.02
        racer.CurrentStamina = math.max(0, racer.CurrentStamina - drainRate)

        -- 4. Stamina penalty on speed
        local staminaRatio = racer.CurrentStamina / math.max(1, racer.MaxStamina)
        local staminaPenalty = 1.0
        if staminaRatio < STAMINA_LOW_THRESHOLD then
            local penaltyFraction = 1 - (staminaRatio / STAMINA_LOW_THRESHOLD)
            staminaPenalty = 1.0 - (STAMINA_SPEED_PENALTY * penaltyFraction)
        end

        -- 5. Random events
        local event = rollEvent(racer)
        if event then
            applyEvent(racer, event)
            table.insert(tickEvents, {
                RacerIndex = idx,
                RacerName = racer.Name,
                EventType = event,
            })
        end

        -- 6. Effect multiplier (speed burst / stumble)
        local effectMul = getEffectMultiplier(racer)

        -- 7. Final speed & position update
        local finalSpeed = math.max(0, baseSpeed * staminaPenalty * effectMul)
        racer.CurrentSpeed = finalSpeed
        racer.Position = racer.Position + finalSpeed

        -- 8. Tick down active effects
        tickEffects(racer)

        -- 9. Finish check
        if racer.Position >= TRACK_LENGTH then
            racer.Position = TRACK_LENGTH
            racer.Finished = true
            racer.FinishTick = race.Tick
            table.insert(finishedThisTick, idx)
        end
    end

    -- Assign places for racers that finished this tick (tie-break: higher position → earlier)
    if #finishedThisTick > 0 then
        table.sort(finishedThisTick, function(a, b)
            return race.Racers[a].Position > race.Racers[b].Position
        end)
        for _, idx in ipairs(finishedThisTick) do
            race.FinishOrder = race.FinishOrder + 1
            race.Racers[idx].FinishPlace = race.FinishOrder
        end
    end

    -- Build state snapshot for broadcast
    local positions = {}
    for idx, racer in ipairs(race.Racers) do
        positions[idx] = {
            Name = racer.Name,
            Position = math.floor(racer.Position * 100) / 100,
            Speed = math.floor(racer.CurrentSpeed * 100) / 100,
            Stamina = math.floor((racer.CurrentStamina / math.max(1, racer.MaxStamina)) * 100),
            Finished = racer.Finished,
            Place = racer.FinishPlace,
            Effects = {},
        }
        for _, eff in ipairs(racer.ActiveEffects) do
            table.insert(positions[idx].Effects, eff.Type)
        end
    end

    broadcast("RaceTickUpdate", {
        Tick = race.Tick,
        Positions = positions,
        Events = tickEvents,
    })

    -- Check if all racers finished or safety timeout
    local allDone = true
    for _, racer in ipairs(race.Racers) do
        if not racer.Finished then
            allDone = false
            break
        end
    end

    local elapsed = race.Tick * TICK_RATE
    if elapsed >= RACE_DURATION_MAX and not allDone then
        -- Force-finish remaining racers by current position
        local unfinished = {}
        for idx, racer in ipairs(race.Racers) do
            if not racer.Finished then
                table.insert(unfinished, idx)
            end
        end
        table.sort(unfinished, function(a, b)
            return race.Racers[a].Position > race.Racers[b].Position
        end)
        for _, idx in ipairs(unfinished) do
            race.FinishOrder = race.FinishOrder + 1
            race.Racers[idx].Finished = true
            race.Racers[idx].FinishPlace = race.FinishOrder
            race.Racers[idx].FinishTick = race.Tick
        end
        allDone = true
    end

    return allDone
end

-- ============================================================
-- Betting
-- ============================================================

local function isValidPlayer(player)
    return player and player:IsA("Player") and player.Parent == Players
end

local function onPlaceBet(player, racerIndex, amount)
    if not isValidPlayer(player) then return end
    if not currentRace or currentRace.Status ~= "Betting" then
        warn("[RaceSystem] No active betting window for " .. player.Name)
        return
    end

    -- Validate racer index
    if type(racerIndex) ~= "number" then return end
    racerIndex = math.floor(racerIndex)
    if racerIndex < 1 or racerIndex > #currentRace.Racers then return end

    -- Validate amount
    if type(amount) ~= "number" then return end
    amount = math.floor(amount)
    if amount < GameConfig.Betting.MinBet or amount > GameConfig.Betting.MaxBet then return end

    -- One bet per player per race
    if activeBets[player.UserId] then
        warn("[RaceSystem] " .. player.Name .. " already placed a bet this race")
        return
    end

    -- Check concurrent bets (shared with FightSystem via DataStore stats)
    -- Simple single-bet-per-race enforced above is sufficient here

    -- Deduct coins
    local success = DataStoreManager.RemoveCoins(player, amount)
    if not success then
        warn("[RaceSystem] " .. player.Name .. " has insufficient coins for bet")
        return
    end

    activeBets[player.UserId] = {
        RacerIndex = racerIndex,
        Amount = amount,
        PlayerName = player.Name,
    }

    broadcast("RaceBetConfirmed", {
        PlayerName = player.Name,
        RacerIndex = racerIndex,
        RacerName = currentRace.Racers[racerIndex].Name,
        Amount = amount,
    })

    print("[RaceSystem] Bet placed: " .. player.Name
        .. " → Racer #" .. racerIndex
        .. " (" .. currentRace.Racers[racerIndex].Name .. ")"
        .. " for " .. amount .. " coins")
end

local function resolveBets(race)
    local raceType = race.RaceType
    local multipliers = GameConfig.Betting.PayoutMultipliers[raceType]
    if not multipliers then
        warn("[RaceSystem] No payout config for race type: " .. tostring(raceType))
        return
    end

    local houseEdge = GameConfig.Betting.HouseEdge
    local payouts = {}

    for userId, bet in pairs(activeBets) do
        local player = Players:GetPlayerByUserId(userId)
        local racerPlace = race.Racers[bet.RacerIndex] and race.Racers[bet.RacerIndex].FinishPlace

        local multiplier = 0
        if racerPlace == 1 then
            multiplier = multipliers.First
        elseif racerPlace == 2 then
            multiplier = multipliers.Second
        elseif racerPlace == 3 then
            multiplier = multipliers.Third
        end

        local payout = 0
        if multiplier > 0 then
            payout = math.floor(bet.Amount * multiplier * (1 - houseEdge))
            if player and isValidPlayer(player) then
                DataStoreManager.AddCoins(player, payout)

                -- Update race-win statistic
                local statKey = raceType == "CamelRace" and "CamelRacesWon" or "LobsterRacesWon"
                if racerPlace == 1 then
                    local data = DataStoreManager.GetPlayerData(player)
                    if data and data.Statistics then
                        DataStoreManager.UpdatePlayerData(player, "Statistics",
                            (function()
                                local stats = data.Statistics
                                stats[statKey] = (stats[statKey] or 0) + 1
                                return stats
                            end)()
                        )
                    end
                end
            end
        end

        table.insert(payouts, {
            UserId = userId,
            PlayerName = bet.PlayerName,
            RacerIndex = bet.RacerIndex,
            BetAmount = bet.Amount,
            Place = racerPlace,
            Payout = payout,
            Won = payout > 0,
        })
    end

    broadcast("RaceBetResults", { Payouts = payouts })
    activeBets = {}
end

-- ============================================================
-- Race Lifecycle
-- ============================================================

local function buildRaceSummary(race)
    local placements = {}
    for idx, racer in ipairs(race.Racers) do
        placements[idx] = {
            Name = racer.Name,
            Type = racer.Type,
            Rarity = racer.Rarity,
            Level = racer.Level,
            Place = racer.FinishPlace,
            FinishTick = racer.FinishTick,
            FinalPosition = racer.Position,
        }
    end
    table.sort(placements, function(a, b)
        return (a.Place or 999) < (b.Place or 999)
    end)

    return {
        RaceId = race.RaceId,
        RaceType = race.RaceType,
        StartTime = race.StartTime,
        EndTime = os.time(),
        TotalTicks = race.Tick,
        Placements = placements,
    }
end

local function recordHistory(summary)
    table.insert(raceHistory, summary)
    if #raceHistory > MAX_HISTORY then
        table.remove(raceHistory, 1)
    end
end

-- Main race coroutine
local function runRace(raceType, racerDataList)
    assert(raceType == "CamelRace" or raceType == "LobsterRace", "Invalid race type")
    assert(#racerDataList >= 2 and #racerDataList <= MAX_RACERS, "Invalid racer count")

    -- Build racers
    local racers = {}
    for _, rd in ipairs(racerDataList) do
        local racer = buildRacer(rd, raceType)
        if racer then
            table.insert(racers, racer)
        end
    end

    if #racers < 2 then
        warn("[RaceSystem] Not enough valid racers to start race")
        return nil
    end

    local raceId = raceType .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))

    currentRace = {
        RaceId = raceId,
        RaceType = raceType,
        Status = "Betting", -- Betting → Racing → Finished
        Racers = racers,
        Tick = 0,
        FinishOrder = 0,
        StartTime = os.time(),
    }
    activeBets = {}

    -- Broadcast race announcement (betting window opens)
    local racerSummaries = {}
    for idx, racer in ipairs(racers) do
        racerSummaries[idx] = {
            Index = idx,
            Name = racer.Name,
            Type = racer.Type,
            Rarity = racer.Rarity,
            Level = racer.Level,
            SPD = racer.SPD,
            STA = racer.STA,
            ACC = racer.ACC,
            LUCK = racer.LUCK,
        }
    end

    broadcast("RaceAnnounced", {
        RaceId = raceId,
        RaceType = raceType,
        Racers = racerSummaries,
        BettingWindowSeconds = BETTING_WINDOW,
    })

    print("[RaceSystem] Race announced: " .. raceId .. " (" .. raceType .. ") — betting open for " .. BETTING_WINDOW .. "s")

    -- Betting window
    task.wait(BETTING_WINDOW)

    -- Transition to racing
    currentRace.Status = "Racing"

    broadcast("RaceStarted", {
        RaceId = raceId,
        RaceType = raceType,
        Racers = racerSummaries,
    })

    print("[RaceSystem] Race started: " .. raceId)

    -- Simulation loop
    while currentRace and currentRace.Status == "Racing" do
        local allDone = simulateTick(currentRace)
        if allDone then
            break
        end
        task.wait(TICK_RATE)
    end

    if not currentRace then return nil end

    -- Race finished
    currentRace.Status = "Finished"

    -- Build results
    local summary = buildRaceSummary(currentRace)
    recordHistory(summary)

    -- Broadcast results
    broadcast("RaceEnded", summary)

    print("[RaceSystem] Race finished: " .. raceId
        .. " — Winner: " .. (summary.Placements[1] and summary.Placements[1].Name or "N/A"))

    -- Resolve bets
    resolveBets(currentRace)

    local result = currentRace
    currentRace = nil
    return result
end

-- ============================================================
-- Auto‐Race Pool Builder
-- ============================================================

local function pickRandomRacers(raceType, count)
    local pool = raceType == "CamelRace" and GameConfig.Camels or GameConfig.Lobsters
    local racerDataList = {}

    -- Shuffle pool copy
    local indices = {}
    for i = 1, #pool do
        indices[i] = i
    end
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    local rarityKeys = {}
    for key, _ in pairs(GameConfig.Rarities) do
        table.insert(rarityKeys, key)
    end

    for i = 1, math.min(count, #pool) do
        local template = pool[indices[i]]
        local level = math.random(1, GameConfig.Evolution.MaxLevel)
        local rarity = rarityKeys[math.random(1, #rarityKeys)]

        -- Optionally attach a random piece of RaceGear
        local equipment = {}
        for _, item in ipairs(GameConfig.Equipment) do
            if item.Type == "RaceGear" and math.random() < 0.3 then
                table.insert(equipment, item)
            end
        end

        table.insert(racerDataList, {
            Type = template.Id,
            Level = level,
            Rarity = rarity,
            Equipment = equipment,
            Name = template.Name,
        })
    end

    -- If pool was smaller than count, duplicate with varied levels/rarities
    while #racerDataList < count do
        local base = racerDataList[math.random(1, #racerDataList)]
        table.insert(racerDataList, {
            Type = base.Type,
            Level = math.random(1, GameConfig.Evolution.MaxLevel),
            Rarity = rarityKeys[math.random(1, #rarityKeys)],
            Equipment = base.Equipment,
            Name = base.Name,
        })
    end

    return racerDataList
end

-- ============================================================
-- Auto‐Cycle Loop
-- ============================================================

local function autoRaceLoop()
    while isRunning do
        -- Alternate race type
        local raceType
        if lastRaceType == "CamelRace" then
            raceType = "LobsterRace"
        else
            raceType = "CamelRace"
        end
        lastRaceType = raceType

        -- Build racer pool
        local racerDataList = pickRandomRacers(raceType, MAX_RACERS)

        -- Run the race (blocking until finished)
        local ok, err = pcall(function()
            runRace(raceType, racerDataList)
        end)

        if not ok then
            warn("[RaceSystem] Race error: " .. tostring(err))
        end

        -- Cooldown before next race
        local delay = math.random(CYCLE_DELAY_MIN, CYCLE_DELAY_MAX)
        print("[RaceSystem] Next race in " .. delay .. " seconds")
        task.wait(delay)
    end
end

-- ============================================================
-- Public API
-- ============================================================

--- Initialise the race system — creates RemoteEvents, wires up
--- bet handler, and starts the auto-cycle loop.
function RaceSystem.Initialize()
    if isRunning then
        warn("[RaceSystem] Already initialised")
        return
    end
    isRunning = true

    -- Create remote events
    local remoteNames = {
        "RaceAnnounced",    -- server → client: new race + betting window
        "RaceStarted",      -- server → client: betting closed, race begins
        "RaceTickUpdate",   -- server → client: per-tick positions & events
        "RaceEnded",        -- server → client: final placements
        "RaceBetConfirmed", -- server → client: bet acknowledgement
        "RaceBetResults",   -- server → client: payout results
        "PlaceRaceBet",     -- client → server: place a bet
    }

    for _, name in ipairs(remoteNames) do
        Remotes[name] = getOrCreateRemote(name)
    end

    -- Listen for bets
    Remotes.PlaceRaceBet.OnServerEvent:Connect(onPlaceBet)

    -- Start auto-cycling
    task.spawn(autoRaceLoop)

    print("[RaceSystem] Initialised — auto-race loop started")
end

--- Manually start a race with specific racer data.
--- @param raceType string "CamelRace" or "LobsterRace"
--- @param racerDataList table array of racer data tables
--- @return table|nil race result or nil on error
function RaceSystem.StartRace(raceType, racerDataList)
    if currentRace then
        warn("[RaceSystem] A race is already in progress")
        return nil
    end

    if raceType ~= "CamelRace" and raceType ~= "LobsterRace" then
        warn("[RaceSystem] Invalid race type: " .. tostring(raceType))
        return nil
    end

    if not racerDataList or #racerDataList < 2 then
        warn("[RaceSystem] Need at least 2 racers")
        return nil
    end

    -- Clamp to max
    if #racerDataList > MAX_RACERS then
        local clamped = {}
        for i = 1, MAX_RACERS do
            clamped[i] = racerDataList[i]
        end
        racerDataList = clamped
    end

    local result
    local ok, err = pcall(function()
        result = runRace(raceType, racerDataList)
    end)

    if not ok then
        warn("[RaceSystem] StartRace error: " .. tostring(err))
        return nil
    end

    return result
end

--- Return a snapshot of the current race state (or nil if no race active).
function RaceSystem.GetCurrentRace()
    if not currentRace then return nil end

    local snapshot = {
        RaceId = currentRace.RaceId,
        RaceType = currentRace.RaceType,
        Status = currentRace.Status,
        Tick = currentRace.Tick,
        StartTime = currentRace.StartTime,
        Racers = {},
    }

    for idx, racer in ipairs(currentRace.Racers) do
        snapshot.Racers[idx] = {
            Name = racer.Name,
            Type = racer.Type,
            Rarity = racer.Rarity,
            Level = racer.Level,
            Position = math.floor(racer.Position * 100) / 100,
            Speed = math.floor(racer.CurrentSpeed * 100) / 100,
            StaminaPercent = math.floor((racer.CurrentStamina / math.max(1, racer.MaxStamina)) * 100),
            Finished = racer.Finished,
            Place = racer.FinishPlace,
            Effects = {},
        }
        for _, eff in ipairs(racer.ActiveEffects) do
            table.insert(snapshot.Racers[idx].Effects, eff.Type)
        end
    end

    return snapshot
end

--- Return the array of completed race summaries (oldest first).
function RaceSystem.GetRaceHistory()
    -- Return a shallow copy to prevent external mutation
    local copy = {}
    for i, entry in ipairs(raceHistory) do
        copy[i] = entry
    end
    return copy
end

return RaceSystem
