-- ClientMain: Main client script that handles UI, camera, and server communication
-- Players are spectators - they watch events, place bets, manage inventory

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlaceBetEvent = Remotes:WaitForChild("PlaceBet")
local EventUpdateEvent = Remotes:WaitForChild("EventUpdate")
local FightUpdateEvent = Remotes:WaitForChild("FightUpdate")
local RaceUpdateEvent = Remotes:WaitForChild("RaceUpdate")
local TradeRequestEvent = Remotes:WaitForChild("TradeRequest")
local TradeUpdateEvent = Remotes:WaitForChild("TradeUpdate")
local TradeActionEvent = Remotes:WaitForChild("TradeAction")
local EquipItemEvent = Remotes:WaitForChild("EquipItem")
local UnequipItemEvent = Remotes:WaitForChild("UnequipItem")
local SetActiveCreatureEvent = Remotes:WaitForChild("SetActiveCreature")
local TrainCreatureEvent = Remotes:WaitForChild("TrainCreature")
local BuyItemEvent = Remotes:WaitForChild("BuyItem")
local PlayerDataUpdateEvent = Remotes:WaitForChild("PlayerDataUpdate")
local NotificationEvent = Remotes:WaitForChild("Notification")
local GetPlayerDataFunc = Remotes:WaitForChild("GetPlayerData")
local GetBettingInfoFunc = Remotes:WaitForChild("GetBettingInfo")
local GetShopItemsFunc = Remotes:WaitForChild("GetShopItems")

-- ============================================================
-- CLIENT STATE
-- ============================================================
local clientState = {
	PlayerData = nil,
	CurrentUI = "None", -- None, Betting, Inventory, Trade, Shop, Evolution
	CurrentEvent = nil,
	Notifications = {},
}

-- ============================================================
-- UI CREATION HELPERS
-- ============================================================
local function createPixelatedFrame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.Color or Color3.fromRGB(30, 30, 35)
	frame.BorderSizePixel = props.Border or 2
	frame.BorderColor3 = props.BorderColor or Color3.fromRGB(80, 80, 90)
	frame.Size = props.Size or UDim2.new(0, 200, 0, 100)
	frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	
	if props.Parent then
		frame.Parent = props.Parent
	end
	
	return frame
end

local function createPixelatedText(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = props.Color or Color3.fromRGB(220, 220, 200)
	label.Font = Enum.Font.Code -- Pixel-like font
	label.TextSize = props.TextSize or 14
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.new(1, 0, 0, 20)
	label.Position = props.Position or UDim2.new(0, 0, 0, 0)
	label.TextXAlignment = props.Align or Enum.TextXAlignment.Left
	label.TextWrapped = true
	
	if props.Parent then
		label.Parent = props.Parent
	end
	
	return label
end

local function createPixelatedButton(props)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = props.Color or Color3.fromRGB(60, 60, 70)
	btn.BorderSizePixel = 2
	btn.BorderColor3 = props.BorderColor or Color3.fromRGB(100, 100, 110)
	btn.TextColor3 = props.TextColor or Color3.fromRGB(220, 220, 200)
	btn.Font = Enum.Font.Code
	btn.TextSize = props.TextSize or 14
	btn.Text = props.Text or "Button"
	btn.Size = props.Size or UDim2.new(0, 120, 0, 30)
	btn.Position = props.Position or UDim2.new(0, 0, 0, 0)
	btn.AutoButtonColor = true
	
	if props.Parent then
		btn.Parent = props.Parent
	end
	
	return btn
end

-- ============================================================
-- MAIN UI SCREEN
-- ============================================================
local function createMainUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ArenaBestialUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	
	-- =====================
	-- TOP HUD BAR
	-- =====================
	local topBar = createPixelatedFrame({
		Color = Color3.fromRGB(20, 20, 25),
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 0),
		Border = 0,
		Parent = screenGui,
	})
	
	local moneyLabel = createPixelatedText({
		Text = "$ 0",
		Color = Color3.fromRGB(255, 215, 0),
		TextSize = 18,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Parent = topBar,
	})
	moneyLabel.Name = "MoneyLabel"
	
	local eventLabel = createPixelatedText({
		Text = "Waiting for event...",
		Color = Color3.fromRGB(200, 200, 200),
		TextSize = 16,
		Size = UDim2.new(0, 400, 1, 0),
		Position = UDim2.new(0.5, -200, 0, 0),
		Align = Enum.TextXAlignment.Center,
		Parent = topBar,
	})
	eventLabel.Name = "EventLabel"
	
	local titleLabel = createPixelatedText({
		Text = "ARENA BESTIAL",
		Color = Color3.fromRGB(255, 100, 50),
		TextSize = 20,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(1, -210, 0, 0),
		Align = Enum.TextXAlignment.Right,
		Parent = topBar,
	})
	
	-- =====================
	-- BOTTOM MENU BAR
	-- =====================
	local bottomBar = createPixelatedFrame({
		Color = Color3.fromRGB(20, 20, 25),
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 1, -50),
		Border = 0,
		Parent = screenGui,
	})
	
	local menuButtons = {"Inventory", "Shop", "Evolution", "Trade", "Betting"}
	local btnWidth = 1 / #menuButtons
	
	for i, name in ipairs(menuButtons) do
		local btn = createPixelatedButton({
			Text = name,
			Size = UDim2.new(btnWidth, -4, 1, -8),
			Position = UDim2.new(btnWidth * (i - 1), 2, 0, 4),
			Color = Color3.fromRGB(40, 40, 50),
			Parent = bottomBar,
		})
		btn.Name = name .. "Btn"
		
		btn.MouseButton1Click:Connect(function()
			togglePanel(screenGui, name)
		end)
	end
	
	-- =====================
	-- NOTIFICATION AREA
	-- =====================
	local notifArea = Instance.new("Frame")
	notifArea.Name = "NotificationArea"
	notifArea.BackgroundTransparency = 1
	notifArea.Size = UDim2.new(0, 350, 0, 300)
	notifArea.Position = UDim2.new(1, -360, 0, 50)
	notifArea.Parent = screenGui
	
	local notifLayout = Instance.new("UIListLayout")
	notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifLayout.Padding = UDim.new(0, 4)
	notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	notifLayout.Parent = notifArea
	
	-- =====================
	-- EVENT DISPLAY (center)
	-- =====================
	local eventDisplay = createPixelatedFrame({
		Color = Color3.fromRGB(25, 25, 30),
		Size = UDim2.new(0.6, 0, 0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderColor = Color3.fromRGB(100, 70, 30),
		Parent = screenGui,
	})
	eventDisplay.Name = "EventDisplay"
	eventDisplay.Visible = false
	
	local eventTitle = createPixelatedText({
		Text = "EVENT",
		Color = Color3.fromRGB(255, 200, 50),
		TextSize = 24,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 5),
		Align = Enum.TextXAlignment.Center,
		Parent = eventDisplay,
	})
	eventTitle.Name = "EventTitle"
	
	local eventLog = Instance.new("ScrollingFrame")
	eventLog.Name = "EventLog"
	eventLog.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	eventLog.BorderSizePixel = 1
	eventLog.Size = UDim2.new(1, -20, 1, -80)
	eventLog.Position = UDim2.new(0, 10, 0, 40)
	eventLog.ScrollBarThickness = 6
	eventLog.Parent = eventDisplay
	
	local logLayout = Instance.new("UIListLayout")
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Padding = UDim.new(0, 2)
	logLayout.Parent = eventLog
	
	-- =====================
	-- BETTING PANEL
	-- =====================
	local bettingPanel = createPixelatedFrame({
		Color = Color3.fromRGB(35, 25, 15),
		Size = UDim2.new(0, 320, 0, 400),
		Position = UDim2.new(0, 10, 0.5, -200),
		BorderColor = Color3.fromRGB(140, 100, 40),
		Parent = screenGui,
	})
	bettingPanel.Name = "BettingPanel"
	bettingPanel.Visible = false
	
	createPixelatedText({
		Text = "╔══ BETTING PARLOR ══╗",
		Color = Color3.fromRGB(255, 200, 80),
		TextSize = 18,
		Size = UDim2.new(1, -10, 0, 25),
		Position = UDim2.new(0, 5, 0, 5),
		Align = Enum.TextXAlignment.Center,
		Parent = bettingPanel,
	})
	
	local bettingContent = Instance.new("ScrollingFrame")
	bettingContent.Name = "BettingContent"
	bettingContent.BackgroundTransparency = 1
	bettingContent.Size = UDim2.new(1, -10, 1, -40)
	bettingContent.Position = UDim2.new(0, 5, 0, 35)
	bettingContent.ScrollBarThickness = 4
	bettingContent.Parent = bettingPanel
	
	local bettingLayout = Instance.new("UIListLayout")
	bettingLayout.Padding = UDim.new(0, 4)
	bettingLayout.Parent = bettingContent
	
	-- =====================
	-- INVENTORY PANEL
	-- =====================
	local invPanel = createPixelatedFrame({
		Color = Color3.fromRGB(25, 30, 35),
		Size = UDim2.new(0, 450, 0, 500),
		Position = UDim2.new(0.5, -225, 0.5, -250),
		BorderColor = Color3.fromRGB(60, 100, 140),
		Parent = screenGui,
	})
	invPanel.Name = "InventoryPanel"
	invPanel.Visible = false
	
	createPixelatedText({
		Text = "═══ INVENTORY ═══",
		Color = Color3.fromRGB(100, 200, 255),
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.new(0, 0, 0, 5),
		Align = Enum.TextXAlignment.Center,
		Parent = invPanel,
	})
	
	-- Tab buttons for inventory categories
	local invTabs = Instance.new("Frame")
	invTabs.Name = "Tabs"
	invTabs.BackgroundTransparency = 1
	invTabs.Size = UDim2.new(1, -10, 0, 30)
	invTabs.Position = UDim2.new(0, 5, 0, 30)
	invTabs.Parent = invPanel
	
	local tabNames = {"Monkeys", "Camels", "Lobsters", "Equipment"}
	for i, tabName in ipairs(tabNames) do
		local tab = createPixelatedButton({
			Text = tabName,
			Size = UDim2.new(1/#tabNames, -2, 1, 0),
			Position = UDim2.new((i-1)/#tabNames, 1, 0, 0),
			Color = Color3.fromRGB(40, 45, 55),
			TextSize = 12,
			Parent = invTabs,
		})
		tab.Name = tabName .. "Tab"
	end
	
	local invContent = Instance.new("ScrollingFrame")
	invContent.Name = "InvContent"
	invContent.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
	invContent.BorderSizePixel = 1
	invContent.Size = UDim2.new(1, -10, 1, -110)
	invContent.Position = UDim2.new(0, 5, 0, 65)
	invContent.ScrollBarThickness = 4
	invContent.Parent = invPanel
	
	local invLayout = Instance.new("UIListLayout")
	invLayout.Padding = UDim.new(0, 3)
	invLayout.Parent = invContent
	
	-- Close button for inventory
	local closeInv = createPixelatedButton({
		Text = "X",
		Size = UDim2.new(0, 25, 0, 25),
		Position = UDim2.new(1, -30, 0, 5),
		Color = Color3.fromRGB(150, 40, 40),
		Parent = invPanel,
	})
	closeInv.MouseButton1Click:Connect(function()
		invPanel.Visible = false
	end)
	
	-- =====================
	-- SHOP PANEL
	-- =====================
	local shopPanel = createPixelatedFrame({
		Color = Color3.fromRGB(30, 25, 20),
		Size = UDim2.new(0, 400, 0, 450),
		Position = UDim2.new(0.5, -200, 0.5, -225),
		BorderColor = Color3.fromRGB(180, 140, 60),
		Parent = screenGui,
	})
	shopPanel.Name = "ShopPanel"
	shopPanel.Visible = false
	
	createPixelatedText({
		Text = "═══ BLACK MARKET ═══",
		Color = Color3.fromRGB(255, 180, 50),
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.new(0, 0, 0, 5),
		Align = Enum.TextXAlignment.Center,
		Parent = shopPanel,
	})
	
	local shopContent = Instance.new("ScrollingFrame")
	shopContent.Name = "ShopContent"
	shopContent.BackgroundColor3 = Color3.fromRGB(18, 16, 12)
	shopContent.BorderSizePixel = 1
	shopContent.Size = UDim2.new(1, -10, 1, -80)
	shopContent.Position = UDim2.new(0, 5, 0, 35)
	shopContent.ScrollBarThickness = 4
	shopContent.Parent = shopPanel
	
	local shopLayout = Instance.new("UIListLayout")
	shopLayout.Padding = UDim.new(0, 3)
	shopLayout.Parent = shopContent
	
	local closeShop = createPixelatedButton({
		Text = "X",
		Size = UDim2.new(0, 25, 0, 25),
		Position = UDim2.new(1, -30, 0, 5),
		Color = Color3.fromRGB(150, 40, 40),
		Parent = shopPanel,
	})
	closeShop.MouseButton1Click:Connect(function()
		shopPanel.Visible = false
	end)
	
	-- =====================
	-- EVOLUTION PANEL
	-- =====================
	local evoPanel = createPixelatedFrame({
		Color = Color3.fromRGB(20, 30, 20),
		Size = UDim2.new(0, 400, 0, 350),
		Position = UDim2.new(0.5, -200, 0.5, -175),
		BorderColor = Color3.fromRGB(50, 180, 50),
		Parent = screenGui,
	})
	evoPanel.Name = "EvolutionPanel"
	evoPanel.Visible = false
	
	createPixelatedText({
		Text = "═══ TRAINING ═══",
		Color = Color3.fromRGB(100, 255, 100),
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.new(0, 0, 0, 5),
		Align = Enum.TextXAlignment.Center,
		Parent = evoPanel,
	})
	
	local evoContent = Instance.new("ScrollingFrame")
	evoContent.Name = "EvoContent"
	evoContent.BackgroundColor3 = Color3.fromRGB(12, 18, 12)
	evoContent.BorderSizePixel = 1
	evoContent.Size = UDim2.new(1, -10, 1, -80)
	evoContent.Position = UDim2.new(0, 5, 0, 35)
	evoContent.ScrollBarThickness = 4
	evoContent.Parent = evoPanel
	
	local evoLayout = Instance.new("UIListLayout")
	evoLayout.Padding = UDim.new(0, 3)
	evoLayout.Parent = evoContent
	
	local closeEvo = createPixelatedButton({
		Text = "X",
		Size = UDim2.new(0, 25, 0, 25),
		Position = UDim2.new(1, -30, 0, 5),
		Color = Color3.fromRGB(150, 40, 40),
		Parent = evoPanel,
	})
	closeEvo.MouseButton1Click:Connect(function()
		evoPanel.Visible = false
	end)
	
	-- =====================
	-- TRADE PANEL
	-- =====================
	local tradePanel = createPixelatedFrame({
		Color = Color3.fromRGB(30, 25, 30),
		Size = UDim2.new(0, 500, 0, 400),
		Position = UDim2.new(0.5, -250, 0.5, -200),
		BorderColor = Color3.fromRGB(150, 80, 180),
		Parent = screenGui,
	})
	tradePanel.Name = "TradePanel"
	tradePanel.Visible = false
	
	createPixelatedText({
		Text = "═══ TRADE ═══",
		Color = Color3.fromRGB(200, 150, 255),
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.new(0, 0, 0, 5),
		Align = Enum.TextXAlignment.Center,
		Parent = tradePanel,
	})
	
	local closeTrade = createPixelatedButton({
		Text = "X",
		Size = UDim2.new(0, 25, 0, 25),
		Position = UDim2.new(1, -30, 0, 5),
		Color = Color3.fromRGB(150, 40, 40),
		Parent = tradePanel,
	})
	closeTrade.MouseButton1Click:Connect(function()
		tradePanel.Visible = false
		TradeActionEvent:FireServer("Cancel")
	end)
	
	return screenGui
end

-- ============================================================
-- PANEL TOGGLE
-- ============================================================
function togglePanel(screenGui, panelName)
	local panels = {"BettingPanel", "InventoryPanel", "ShopPanel", "EvolutionPanel", "TradePanel"}
	local targetPanel = panelName .. "Panel"
	
	for _, pName in ipairs(panels) do
		local panel = screenGui:FindFirstChild(pName)
		if panel then
			if pName == targetPanel then
				panel.Visible = not panel.Visible
				if panel.Visible then
					-- Refresh panel content
					refreshPanel(screenGui, panelName)
				end
			else
				panel.Visible = false
			end
		end
	end
end

-- ============================================================
-- REFRESH PANEL CONTENT
-- ============================================================
function refreshPanel(screenGui, panelName)
	if panelName == "Inventory" then
		refreshInventory(screenGui)
	elseif panelName == "Shop" then
		refreshShop(screenGui)
	elseif panelName == "Evolution" then
		refreshEvolution(screenGui)
	end
end

function refreshInventory(screenGui)
	local panel = screenGui:FindFirstChild("InventoryPanel")
	if not panel then return end
	
	local content = panel:FindFirstChild("InvContent")
	if not content then return end
	
	-- Clear existing items
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local data = clientState.PlayerData
	if not data then return end
	
	-- Show all creatures
	local function addCreatureItem(creature, creatureType, isActive)
		local item = createPixelatedFrame({
			Color = isActive and Color3.fromRGB(40, 50, 40) or Color3.fromRGB(30, 33, 38),
			Size = UDim2.new(1, -4, 0, 60),
			Border = 1,
			Parent = content,
		})
		
		local nameText = creature.Nickname or creature.BaseId
		local rarityText = creature.Rarity or "Common"
		
		createPixelatedText({
			Text = nameText .. " [" .. rarityText .. "] Lv." .. (creature.Level or 1),
			Color = Color3.fromRGB(220, 220, 200),
			TextSize = 13,
			Size = UDim2.new(0.7, 0, 0, 20),
			Position = UDim2.new(0, 5, 0, 5),
			Parent = item,
		})
		
		local statsText = ""
		if creatureType == "Monkey" and creature.Stats then
			statsText = "HP:" .. (creature.Stats.HP or 0) .. " ATK:" .. (creature.Stats.Attack or 0) .. " DEF:" .. (creature.Stats.Defense or 0)
		elseif creature.Stats then
			statsText = "SPD:" .. string.format("%.1f", creature.Stats.Speed or 0) .. " STA:" .. (creature.Stats.Stamina or 0)
		end
		
		createPixelatedText({
			Text = statsText,
			Color = Color3.fromRGB(160, 160, 150),
			TextSize = 11,
			Size = UDim2.new(0.7, 0, 0, 15),
			Position = UDim2.new(0, 5, 0, 25),
			Parent = item,
		})
		
		if not isActive then
			local setActiveBtn = createPixelatedButton({
				Text = "Set Active",
				Size = UDim2.new(0, 80, 0, 25),
				Position = UDim2.new(1, -90, 0, 18),
				Color = Color3.fromRGB(50, 80, 50),
				TextSize = 11,
				Parent = item,
			})
			setActiveBtn.MouseButton1Click:Connect(function()
				SetActiveCreatureEvent:FireServer(creature.UUID, creatureType)
			end)
		else
			createPixelatedText({
				Text = "★ ACTIVE",
				Color = Color3.fromRGB(255, 200, 50),
				TextSize = 12,
				Size = UDim2.new(0, 80, 0, 25),
				Position = UDim2.new(1, -90, 0, 18),
				Align = Enum.TextXAlignment.Center,
				Parent = item,
			})
		end
	end
	
	for _, monkey in ipairs(data.Monkeys or {}) do
		addCreatureItem(monkey, "Monkey", data.ActiveMonkey == monkey.UUID)
	end
	for _, camel in ipairs(data.Camels or {}) do
		addCreatureItem(camel, "Camel", data.ActiveCamel == camel.UUID)
	end
	for _, lobster in ipairs(data.Lobsters or {}) do
		addCreatureItem(lobster, "Lobster", data.ActiveLobster == lobster.UUID)
	end
	
	-- Show equipment
	for _, item in ipairs(data.Inventory or {}) do
		local eqFrame = createPixelatedFrame({
			Color = item.Equipped and Color3.fromRGB(45, 40, 30) or Color3.fromRGB(30, 30, 35),
			Size = UDim2.new(1, -4, 0, 40),
			Border = 1,
			Parent = content,
		})
		
		createPixelatedText({
			Text = (item.Id or "Unknown") .. (item.Equipped and " [EQUIPPED]" or ""),
			Color = Color3.fromRGB(200, 180, 140),
			TextSize = 12,
			Size = UDim2.new(0.7, 0, 1, 0),
			Position = UDim2.new(0, 5, 0, 0),
			Parent = eqFrame,
		})
		
		if item.Equipped then
			local unequipBtn = createPixelatedButton({
				Text = "Unequip",
				Size = UDim2.new(0, 70, 0, 25),
				Position = UDim2.new(1, -80, 0, 8),
				Color = Color3.fromRGB(100, 50, 50),
				TextSize = 11,
				Parent = eqFrame,
			})
			unequipBtn.MouseButton1Click:Connect(function()
				UnequipItemEvent:FireServer(item.UUID)
			end)
		end
	end
	
	content.CanvasSize = UDim2.new(0, 0, 0, content.UIListLayout.AbsoluteContentSize.Y + 10)
end

function refreshShop(screenGui)
	local panel = screenGui:FindFirstChild("ShopPanel")
	if not panel then return end
	
	local content = panel:FindFirstChild("ShopContent")
	if not content then return end
	
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local success, items = pcall(function()
		return GetShopItemsFunc:InvokeServer()
	end)
	
	if not success or not items then return end
	
	for _, itemConfig in ipairs(items) do
		local shopItem = createPixelatedFrame({
			Color = Color3.fromRGB(35, 30, 22),
			Size = UDim2.new(1, -4, 0, 55),
			Border = 1,
			Parent = content,
		})
		
		createPixelatedText({
			Text = itemConfig.Name .. " [" .. (itemConfig.Rarity or "Common") .. "]",
			Color = Color3.fromRGB(255, 220, 150),
			TextSize = 13,
			Size = UDim2.new(0.6, 0, 0, 20),
			Position = UDim2.new(0, 5, 0, 5),
			Parent = shopItem,
		})
		
		local statText = itemConfig.Type .. " | "
		if itemConfig.AttackBonus then statText = statText .. "ATK+" .. itemConfig.AttackBonus .. " " end
		if itemConfig.DefenseBonus then statText = statText .. "DEF+" .. itemConfig.DefenseBonus .. " " end
		if itemConfig.SpeedBonus then statText = statText .. "SPD+" .. itemConfig.SpeedBonus .. " " end
		
		createPixelatedText({
			Text = statText,
			Color = Color3.fromRGB(150, 140, 120),
			TextSize = 11,
			Size = UDim2.new(0.6, 0, 0, 15),
			Position = UDim2.new(0, 5, 0, 25),
			Parent = shopItem,
		})
		
		local buyBtn = createPixelatedButton({
			Text = "$" .. (itemConfig.Price or 0),
			Size = UDim2.new(0, 80, 0, 30),
			Position = UDim2.new(1, -90, 0, 12),
			Color = Color3.fromRGB(60, 80, 40),
			TextSize = 13,
			Parent = shopItem,
		})
		buyBtn.MouseButton1Click:Connect(function()
			BuyItemEvent:FireServer(itemConfig.Id)
		end)
	end
	
	content.CanvasSize = UDim2.new(0, 0, 0, content.UIListLayout.AbsoluteContentSize.Y + 10)
end

function refreshEvolution(screenGui)
	local panel = screenGui:FindFirstChild("EvolutionPanel")
	if not panel then return end
	
	local content = panel:FindFirstChild("EvoContent")
	if not content then return end
	
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local data = clientState.PlayerData
	if not data then return end
	
	local function addTrainable(creature, creatureType)
		local item = createPixelatedFrame({
			Color = Color3.fromRGB(22, 30, 22),
			Size = UDim2.new(1, -4, 0, 70),
			Border = 1,
			Parent = content,
		})
		
		createPixelatedText({
			Text = (creature.Nickname or creature.BaseId) .. " Lv." .. creature.Level,
			Color = Color3.fromRGB(150, 255, 150),
			TextSize = 14,
			Size = UDim2.new(0.6, 0, 0, 20),
			Position = UDim2.new(0, 5, 0, 5),
			Parent = item,
		})
		
		createPixelatedText({
			Text = "XP: " .. creature.XP .. " | " .. creatureType,
			Color = Color3.fromRGB(120, 180, 120),
			TextSize = 11,
			Size = UDim2.new(0.6, 0, 0, 15),
			Position = UDim2.new(0, 5, 0, 25),
			Parent = item,
		})
		
		local trainBtn = createPixelatedButton({
			Text = "Train",
			Size = UDim2.new(0, 80, 0, 30),
			Position = UDim2.new(1, -90, 0, 20),
			Color = Color3.fromRGB(40, 80, 40),
			TextSize = 13,
			Parent = item,
		})
		trainBtn.MouseButton1Click:Connect(function()
			TrainCreatureEvent:FireServer(creature.UUID)
		end)
	end
	
	for _, m in ipairs(data.Monkeys or {}) do addTrainable(m, "Monkey") end
	for _, c in ipairs(data.Camels or {}) do addTrainable(c, "Camel") end
	for _, l in ipairs(data.Lobsters or {}) do addTrainable(l, "Lobster") end
	
	content.CanvasSize = UDim2.new(0, 0, 0, content.UIListLayout.AbsoluteContentSize.Y + 10)
end

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
local function showNotification(screenGui, data)
	local notifArea = screenGui:FindFirstChild("NotificationArea")
	if not notifArea then return end
	
	local colors = {
		Success = Color3.fromRGB(50, 150, 50),
		Error = Color3.fromRGB(180, 50, 50),
		Info = Color3.fromRGB(50, 100, 180),
		Warning = Color3.fromRGB(180, 150, 30),
		BigWin = Color3.fromRGB(255, 200, 0),
		Loss = Color3.fromRGB(150, 50, 50),
		Welcome = Color3.fromRGB(80, 120, 200),
	}
	
	local color = colors[data.Type] or colors.Info
	
	local notif = createPixelatedFrame({
		Color = color,
		Size = UDim2.new(1, 0, 0, 35),
		Border = 1,
		BorderColor = Color3.fromRGB(200, 200, 200),
		Parent = notifArea,
	})
	
	createPixelatedText({
		Text = data.Message or "",
		Color = Color3.fromRGB(255, 255, 255),
		TextSize = 13,
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		Align = Enum.TextXAlignment.Center,
		Parent = notif,
	})
	
	-- Auto-remove after 4 seconds
	task.delay(4, function()
		if notif and notif.Parent then
			local tween = TweenService:Create(notif, TweenInfo.new(0.5), {
				BackgroundTransparency = 1,
			})
			tween:Play()
			tween.Completed:Wait()
			notif:Destroy()
		end
	end)
end

-- ============================================================
-- EVENT DISPLAY UPDATES
-- ============================================================
local function updateEventDisplay(screenGui, eventData)
	local eventDisplay = screenGui:FindFirstChild("EventDisplay")
	local eventLabel = screenGui:FindFirstChild("TopBar") 
		or screenGui:GetChildren()
	
	-- Find the top bar event label
	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("Frame") and child.Position == UDim2.new(0, 0, 0, 0) then
			local label = child:FindFirstChild("EventLabel")
			if label then
				if eventData.Phase == "Betting" then
					label.Text = "BETTING: " .. (eventData.EventType or "") .. " - Place your bets!"
				elseif eventData.Phase == "Running" then
					label.Text = "IN PROGRESS: " .. (eventData.EventType or "")
				elseif eventData.Phase == "Results" then
					label.Text = "RESULTS - Next event soon..."
				elseif eventData.Phase == "Idle" then
					label.Text = "Next event in " .. (eventData.NextEventIn or "?") .. "s"
				end
			end
			break
		end
	end
	
	if not eventDisplay then return end
	
	if eventData.Phase == "Betting" then
		-- Show betting options
		local bettingPanel = screenGui:FindFirstChild("BettingPanel")
		if bettingPanel then
			local content = bettingPanel:FindFirstChild("BettingContent")
			if content then
				for _, child in ipairs(content:GetChildren()) do
					if child:IsA("Frame") then child:Destroy() end
				end
				
				createPixelatedText({
					Text = "Event: " .. (eventData.EventType or "Unknown"),
					Color = Color3.fromRGB(255, 220, 100),
					TextSize = 14,
					Size = UDim2.new(1, 0, 0, 20),
					Parent = content,
				})
				
				for _, option in ipairs(eventData.Options or {}) do
					local optFrame = createPixelatedFrame({
						Color = Color3.fromRGB(45, 35, 20),
						Size = UDim2.new(1, 0, 0, 70),
						Border = 1,
						Parent = content,
					})
					
					createPixelatedText({
						Text = option.Name,
						Color = Color3.fromRGB(255, 200, 100),
						TextSize = 14,
						Size = UDim2.new(1, -10, 0, 20),
						Position = UDim2.new(0, 5, 0, 5),
						Parent = optFrame,
					})
					
					-- Bet amount buttons
					local amounts = {10, 50, 100, 500, 1000}
					for j, amt in ipairs(amounts) do
						local betBtn = createPixelatedButton({
							Text = "$" .. amt,
							Size = UDim2.new(0, 55, 0, 25),
							Position = UDim2.new(0, 5 + (j-1) * 58, 0, 30),
							Color = Color3.fromRGB(80, 60, 20),
							TextSize = 11,
							Parent = optFrame,
						})
						betBtn.MouseButton1Click:Connect(function()
							PlaceBetEvent:FireServer(option.Id, amt)
						end)
					end
				end
				
				content.CanvasSize = UDim2.new(0, 0, 0, 
					content:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.Y + 10)
			end
			bettingPanel.Visible = true
		end
	end
end

-- ============================================================
-- FIGHT DISPLAY
-- ============================================================
local function displayFight(screenGui, fightData)
	local eventDisplay = screenGui:FindFirstChild("EventDisplay")
	if not eventDisplay then return end
	
	eventDisplay.Visible = true
	
	local title = eventDisplay:FindFirstChild("EventTitle")
	if title then
		title.Text = "⚔ MONKEY FIGHT ⚔"
	end
	
	local log = eventDisplay:FindFirstChild("EventLog")
	if not log then return end
	
	-- Clear existing log
	for _, child in ipairs(log:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	
	-- Display fight info
	createPixelatedText({
		Text = fightData.Fighter1.Name .. " vs " .. fightData.Fighter2.Name,
		Color = Color3.fromRGB(255, 150, 50),
		TextSize = 16,
		Size = UDim2.new(1, -10, 0, 25),
		Parent = log,
	})
	
	-- Animate log entries
	task.spawn(function()
		for _, entry in ipairs(fightData.Log or {}) do
			task.wait(1.5)
			
			local color = Color3.fromRGB(200, 200, 180)
			if entry.Event == "KO" then
				color = Color3.fromRGB(255, 50, 50)
			elseif entry.IsCrit then
				color = Color3.fromRGB(255, 255, 50)
			end
			
			if log.Parent then
				createPixelatedText({
					Text = entry.Message or "",
					Color = color,
					TextSize = 12,
					Size = UDim2.new(1, -10, 0, 20),
					Parent = log,
				})
				
				log.CanvasSize = UDim2.new(0, 0, 0,
					log:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.Y + 10)
				log.CanvasPosition = Vector2.new(0, log.AbsoluteCanvasSize.Y)
			end
		end
		
		task.wait(5)
		if eventDisplay.Parent then
			eventDisplay.Visible = false
		end
	end)
end

-- ============================================================
-- RACE DISPLAY
-- ============================================================
local function displayRace(screenGui, raceData)
	local eventDisplay = screenGui:FindFirstChild("EventDisplay")
	if not eventDisplay then return end
	
	eventDisplay.Visible = true
	
	local title = eventDisplay:FindFirstChild("EventTitle")
	if title then
		local icon = raceData.Type == "Camel" and "🐪" or "🦞"
		title.Text = icon .. " " .. (raceData.Type or "") .. " RACE " .. icon
	end
	
	local log = eventDisplay:FindFirstChild("EventLog")
	if not log then return end
	
	for _, child in ipairs(log:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end
	
	-- Show racers
	createPixelatedText({
		Text = "Track Length: " .. (raceData.TrackLength or 0) .. "m",
		Color = Color3.fromRGB(200, 200, 150),
		TextSize = 14,
		Size = UDim2.new(1, -10, 0, 20),
		Parent = log,
	})
	
	-- Create position bars for each racer
	local racerBars = {}
	for _, standing in ipairs(raceData.FinalStandings or {}) do
		local barFrame = createPixelatedFrame({
			Color = Color3.fromRGB(25, 25, 30),
			Size = UDim2.new(1, -10, 0, 25),
			Border = 1,
			Parent = log,
		})
		
		createPixelatedText({
			Text = standing.Name,
			Color = Color3.fromRGB(180, 180, 160),
			TextSize = 11,
			Size = UDim2.new(0.3, 0, 1, 0),
			Position = UDim2.new(0, 5, 0, 0),
			Parent = barFrame,
		})
		
		local progressBar = createPixelatedFrame({
			Color = Color3.fromRGB(50, 120, 50),
			Size = UDim2.new(0, 0, 0.8, 0),
			Position = UDim2.new(0.32, 0, 0.1, 0),
			Border = 0,
			Parent = barFrame,
		})
		progressBar.Name = "Bar"
		
		racerBars[standing.Lane] = {Frame = barFrame, Bar = progressBar}
	end
	
	-- Animate using snapshots
	task.spawn(function()
		for _, snapshot in ipairs(raceData.Snapshots or {}) do
			task.wait(0.3)
			for _, racer in ipairs(snapshot.Racers) do
				local bar = racerBars[racer.Lane]
				if bar and bar.Bar then
					local pct = math.clamp(racer.Position / (raceData.TrackLength or 1), 0, 1)
					TweenService:Create(bar.Bar, TweenInfo.new(0.25), {
						Size = UDim2.new(0.65 * pct, 0, 0.8, 0),
					}):Play()
				end
			end
		end
		
		-- Show final results
		task.wait(2)
		if raceData.Winner then
			createPixelatedText({
				Text = "🏆 WINNER: " .. raceData.Winner.Name .. " 🏆",
				Color = Color3.fromRGB(255, 215, 0),
				TextSize = 18,
				Size = UDim2.new(1, -10, 0, 30),
				Align = Enum.TextXAlignment.Center,
				Parent = log,
			})
		end
		
		log.CanvasSize = UDim2.new(0, 0, 0,
			log:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.Y + 10)
		
		task.wait(8)
		if eventDisplay.Parent then
			eventDisplay.Visible = false
		end
	end)
end

-- ============================================================
-- INITIALIZE
-- ============================================================
local screenGui = createMainUI()

-- Connect to server events
PlayerDataUpdateEvent.OnClientEvent:Connect(function(data)
	clientState.PlayerData = data
	
	-- Update money display
	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("Frame") then
			local moneyLabel = child:FindFirstChild("MoneyLabel")
			if moneyLabel then
				moneyLabel.Text = "$ " .. tostring(data.Money or 0)
				break
			end
		end
	end
end)

NotificationEvent.OnClientEvent:Connect(function(data)
	showNotification(screenGui, data)
end)

EventUpdateEvent.OnClientEvent:Connect(function(eventData)
	clientState.CurrentEvent = eventData
	updateEventDisplay(screenGui, eventData)
end)

FightUpdateEvent.OnClientEvent:Connect(function(fightData)
	displayFight(screenGui, fightData)
end)

RaceUpdateEvent.OnClientEvent:Connect(function(raceData)
	displayRace(screenGui, raceData)
end)

TradeUpdateEvent.OnClientEvent:Connect(function(tradeData)
	if tradeData.Action == "TradeRequest" then
		showNotification(screenGui, {
			Type = "Info",
			Message = tradeData.FromPlayer .. " wants to trade! Open Trade menu to accept.",
		})
	end
end)

-- Request initial data
task.spawn(function()
	task.wait(2)
	local data = GetPlayerDataFunc:InvokeServer()
	if data then
		clientState.PlayerData = data
	end
end)

-- Keyboard shortcuts
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.I then
		togglePanel(screenGui, "Inventory")
	elseif input.KeyCode == Enum.KeyCode.B then
		togglePanel(screenGui, "Betting")
	elseif input.KeyCode == Enum.KeyCode.T then
		togglePanel(screenGui, "Trade")
	elseif input.KeyCode == Enum.KeyCode.E then
		togglePanel(screenGui, "Evolution")
	elseif input.KeyCode == Enum.KeyCode.P then
		togglePanel(screenGui, "Shop")
	end
end)

print("[Arena Bestial] Client initialized!")
