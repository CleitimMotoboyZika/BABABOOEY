-- BettingManager: Server-side betting system with full validation
-- Manages betting pools for fights and races

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

local BettingManager = {}
BettingManager.__index = BettingManager

local activeBets = {} -- eventId -> { bets = {}, status = "open"/"closed"/"resolved" }

-- ============================================================
-- CREATE BETTING POOL
-- ============================================================
function BettingManager.OpenBettingPool(eventId, eventType, options)
	-- options: list of things you can bet on (e.g., fighter names, racer lanes)
	activeBets[eventId] = {
		EventId = eventId,
		EventType = eventType, -- "Fight", "CamelRace", "LobsterRace"
		Options = options,     -- {id, name} pairs
		Status = "Open",
		Bets = {},             -- {playerId, optionId, amount}
		TotalPool = 0,
		OpenedAt = os.time(),
		ClosedAt = nil,
		ResolvedAt = nil,
		WinningOption = nil,
	}
	return true
end

-- ============================================================
-- PLACE BET (with server-side validation)
-- ============================================================
function BettingManager.PlaceBet(playerId, eventId, optionId, amount, playerData)
	-- Validate event exists and is open
	local pool = activeBets[eventId]
	if not pool then
		return false, "No active betting pool found"
	end
	if pool.Status ~= "Open" then
		return false, "Betting is closed for this event"
	end
	
	-- Validate option exists
	local validOption = false
	for _, opt in ipairs(pool.Options) do
		if opt.Id == optionId then
			validOption = true
			break
		end
	end
	if not validOption then
		return false, "Invalid betting option"
	end
	
	-- Validate amount
	if type(amount) ~= "number" or amount ~= amount then
		return false, "Invalid bet amount"
	end
	amount = math.floor(amount)
	if amount < GameConfig.Currency.MinBet then
		return false, "Minimum bet is " .. GameConfig.Currency.MinBet
	end
	if amount > GameConfig.Currency.MaxBet then
		return false, "Maximum bet is " .. GameConfig.Currency.MaxBet
	end
	
	-- Check if player already bet on this event
	for _, bet in ipairs(pool.Bets) do
		if bet.PlayerId == playerId then
			return false, "You already placed a bet on this event"
		end
	end
	
	-- Validate player has enough money (checked by caller, but double-check)
	if not playerData or playerData.Money < amount then
		return false, "Insufficient funds"
	end
	
	-- Place the bet
	table.insert(pool.Bets, {
		PlayerId = playerId,
		OptionId = optionId,
		Amount = amount,
		PlacedAt = os.time(),
	})
	
	pool.TotalPool = pool.TotalPool + amount
	
	return true, "Bet placed successfully"
end

-- ============================================================
-- CLOSE BETTING (no more bets allowed)
-- ============================================================
function BettingManager.CloseBetting(eventId)
	local pool = activeBets[eventId]
	if not pool then return false end
	
	pool.Status = "Closed"
	pool.ClosedAt = os.time()
	return true
end

-- ============================================================
-- RESOLVE BETS (determine winners and payouts)
-- ============================================================
function BettingManager.ResolveBets(eventId, winningOptionId)
	local pool = activeBets[eventId]
	if not pool then return nil end
	
	pool.Status = "Resolved"
	pool.ResolvedAt = os.time()
	pool.WinningOption = winningOptionId
	
	local results = {
		EventId = eventId,
		WinningOption = winningOptionId,
		TotalPool = pool.TotalPool,
		Winners = {},
		Losers = {},
	}
	
	-- Calculate total amount bet on winning option
	local winningBetsTotal = 0
	local winningBets = {}
	local losingBets = {}
	
	for _, bet in ipairs(pool.Bets) do
		if bet.OptionId == winningOptionId then
			winningBetsTotal = winningBetsTotal + bet.Amount
			table.insert(winningBets, bet)
		else
			table.insert(losingBets, bet)
		end
	end
	
	-- Calculate payouts
	if winningBetsTotal > 0 then
		for _, bet in ipairs(winningBets) do
			-- Payout proportional to bet size relative to winning pool
			local share = bet.Amount / winningBetsTotal
			local payout = math.floor(pool.TotalPool * share * GameConfig.Currency.BetPayoutMultiplier)
			payout = math.max(payout, bet.Amount) -- At minimum, get your bet back
			
			table.insert(results.Winners, {
				PlayerId = bet.PlayerId,
				BetAmount = bet.Amount,
				Payout = payout,
			})
		end
	end
	
	for _, bet in ipairs(losingBets) do
		table.insert(results.Losers, {
			PlayerId = bet.PlayerId,
			BetAmount = bet.Amount,
			Payout = 0,
		})
	end
	
	return results
end

-- ============================================================
-- GET CURRENT BETTING INFO
-- ============================================================
function BettingManager.GetBettingInfo(eventId)
	local pool = activeBets[eventId]
	if not pool then return nil end
	
	local info = {
		EventId = pool.EventId,
		EventType = pool.EventType,
		Status = pool.Status,
		Options = pool.Options,
		TotalPool = pool.TotalPool,
		BetCount = #pool.Bets,
		-- Don't reveal individual bets to prevent cheating
	}
	
	-- Calculate odds for each option
	info.Odds = {}
	for _, opt in ipairs(pool.Options) do
		local optionTotal = 0
		for _, bet in ipairs(pool.Bets) do
			if bet.OptionId == opt.Id then
				optionTotal = optionTotal + bet.Amount
			end
		end
		info.Odds[opt.Id] = {
			TotalBet = optionTotal,
			Odds = optionTotal > 0 and (pool.TotalPool / optionTotal) or 0,
		}
	end
	
	return info
end

-- ============================================================
-- GET PLAYER'S BET FOR AN EVENT
-- ============================================================
function BettingManager.GetPlayerBet(playerId, eventId)
	local pool = activeBets[eventId]
	if not pool then return nil end
	
	for _, bet in ipairs(pool.Bets) do
		if bet.PlayerId == playerId then
			return bet
		end
	end
	
	return nil
end

-- ============================================================
-- CLEANUP OLD POOLS
-- ============================================================
function BettingManager.Cleanup()
	local now = os.time()
	for eventId, pool in pairs(activeBets) do
		if pool.Status == "Resolved" and now - pool.ResolvedAt > 300 then
			activeBets[eventId] = nil
		end
	end
end

return BettingManager
