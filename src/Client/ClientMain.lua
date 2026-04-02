-- ClientMain.lua
-- Script principal do cliente - Arena Selvagem
-- Interface do jogador: apostas, inventário, trocas, espectador

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- UTILIDADES DE UI
-- ============================================================
local UIUtils = {}

function UIUtils.CreateScreenGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    return gui
end

function UIUtils.CreateFrame(parent, props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "Frame"
    frame.Size = props.Size or UDim2.new(0, 200, 0, 200)
    frame.Position = props.Position or UDim2.new(0.5, -100, 0.5, -100)
    frame.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Visible = props.Visible ~= false
    frame.Parent = parent

    if props.Corner then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, props.Corner)
        corner.Parent = frame
    end

    return frame
end

function UIUtils.CreateText(parent, props)
    local label = Instance.new("TextLabel")
    label.Name = props.Name or "Label"
    label.Size = props.Size or UDim2.new(1, 0, 0, 30)
    label.Position = props.Position or UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = props.BackgroundTransparency or 1
    label.Text = props.Text or ""
    label.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
    label.TextSize = props.TextSize or 16
    label.Font = props.Font or Enum.Font.GothamBold
    label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
    label.Parent = parent
    return label
end

function UIUtils.CreateButton(parent, props)
    local button = Instance.new("TextButton")
    button.Name = props.Name or "Button"
    button.Size = props.Size or UDim2.new(0, 150, 0, 40)
    button.Position = props.Position or UDim2.new(0.5, -75, 0.5, -20)
    button.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(60, 120, 200)
    button.Text = props.Text or "Button"
    button.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
    button.TextSize = props.TextSize or 16
    button.Font = props.Font or Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent

    if props.Corner then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, props.Corner)
        corner.Parent = button
    end

    -- Hover effect
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = props.HoverColor or Color3.fromRGB(80, 140, 220)
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(60, 120, 200)
        }):Play()
    end)

    if props.Callback then
        button.MouseButton1Click:Connect(props.Callback)
    end

    return button
end

function UIUtils.CreateScrollFrame(parent, props)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = props.Name or "ScrollFrame"
    scroll.Size = props.Size or UDim2.new(1, -20, 1, -60)
    scroll.Position = props.Position or UDim2.new(0, 10, 0, 50)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scroll

    return scroll
end

-- ============================================================
-- HUD PRINCIPAL
-- ============================================================
local function createHUD()
    local gui = UIUtils.CreateScreenGui("HUD")

    -- Barra superior com moedas
    local topBar = UIUtils.CreateFrame(gui, {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(20, 20, 30),
    })

    UIUtils.CreateText(topBar, {
        Name = "GameTitle",
        Text = "🐵 ARENA SELVAGEM 🐵",
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(255, 200, 50),
    })

    local coinsLabel = UIUtils.CreateText(topBar, {
        Name = "CoinsLabel",
        Text = "💰 Moedas: 500",
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(1, -210, 0, 0),
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Color3.fromRGB(255, 215, 0),
    })

    -- Botões de menu lateral
    local menuFrame = UIUtils.CreateFrame(gui, {
        Name = "MenuButtons",
        Size = UDim2.new(0, 50, 0, 260),
        Position = UDim2.new(0, 10, 0.5, -130),
        BackgroundColor3 = Color3.fromRGB(25, 25, 35),
        Corner = 10,
    })

    local menuButtons = {
        { Icon = "🎒", Name = "Inventário", Panel = "InventoryPanel" },
        { Icon = "🐵", Name = "Criaturas", Panel = "CreaturesPanel" },
        { Icon = "🎰", Name = "Apostas", Panel = "BettingPanel" },
        { Icon = "🔄", Name = "Trocas", Panel = "TradePanel" },
        { Icon = "⚔️", Name = "Ringue", Panel = "FightPanel" },
        { Icon = "🏁", Name = "Corridas", Panel = "RacePanel" },
    }

    for i, btn in ipairs(menuButtons) do
        UIUtils.CreateButton(menuFrame, {
            Name = btn.Name,
            Text = btn.Icon,
            Size = UDim2.new(1, -10, 0, 35),
            Position = UDim2.new(0, 5, 0, 5 + (i - 1) * 42),
            BackgroundColor3 = Color3.fromRGB(45, 45, 60),
            HoverColor = Color3.fromRGB(65, 65, 85),
            TextSize = 20,
            Corner = 6,
            Callback = function()
                -- Toggle painéis
                for _, child in ipairs(gui:GetChildren()) do
                    if child.Name:match("Panel$") then
                        child.Visible = (child.Name == btn.Panel)
                    end
                end
            end,
        })
    end

    return gui, coinsLabel
end

-- ============================================================
-- PAINEL DE APOSTAS (Sala Vintage)
-- ============================================================
local function createBettingPanel(gui)
    local panel = UIUtils.CreateFrame(gui, {
        Name = "BettingPanel",
        Size = UDim2.new(0, 500, 0, 400),
        Position = UDim2.new(0.5, -250, 0.5, -200),
        BackgroundColor3 = Color3.fromRGB(45, 25, 15), -- Cor vintage
        Corner = 12,
        Visible = false,
    })

    -- Título vintage
    UIUtils.CreateText(panel, {
        Name = "Title",
        Text = "🎰 SALA DE APOSTAS VINTAGE 🎰",
        Size = UDim2.new(1, 0, 0, 40),
        TextSize = 20,
        TextColor3 = Color3.fromRGB(255, 215, 100),
        Font = Enum.Font.Antique,
    })

    -- Decoração vintage
    local divider = UIUtils.CreateFrame(panel, {
        Name = "Divider",
        Size = UDim2.new(0.9, 0, 0, 2),
        Position = UDim2.new(0.05, 0, 0, 42),
        BackgroundColor3 = Color3.fromRGB(180, 140, 80),
    })

    -- Quadro de próximos eventos
    UIUtils.CreateText(panel, {
        Name = "NextEvent",
        Text = "📋 Próximo Evento:",
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 50),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(200, 180, 120),
    })

    local eventInfo = UIUtils.CreateText(panel, {
        Name = "EventInfo",
        Text = "Aguardando próximo evento...",
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 75),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(255, 255, 200),
    })

    -- Área de competidores
    local competitorsFrame = UIUtils.CreateFrame(panel, {
        Name = "Competitors",
        Size = UDim2.new(1, -20, 0, 150),
        Position = UDim2.new(0, 10, 0, 110),
        BackgroundColor3 = Color3.fromRGB(35, 20, 10),
        Corner = 8,
    })

    UIUtils.CreateText(competitorsFrame, {
        Name = "CompTitle",
        Text = "🏆 Competidores",
        Size = UDim2.new(1, 0, 0, 25),
        TextSize = 14,
        TextColor3 = Color3.fromRGB(200, 180, 120),
    })

    local competitorsList = UIUtils.CreateScrollFrame(competitorsFrame, {
        Name = "List",
        Size = UDim2.new(1, -10, 1, -30),
        Position = UDim2.new(0, 5, 0, 28),
    })

    -- Input de aposta
    UIUtils.CreateText(panel, {
        Name = "BetLabel",
        Text = "Valor da Aposta:",
        Size = UDim2.new(0, 150, 0, 30),
        Position = UDim2.new(0, 10, 0, 270),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(200, 180, 120),
    })

    local betInput = Instance.new("TextBox")
    betInput.Name = "BetInput"
    betInput.Size = UDim2.new(0, 120, 0, 30)
    betInput.Position = UDim2.new(0, 160, 0, 270)
    betInput.BackgroundColor3 = Color3.fromRGB(60, 40, 25)
    betInput.TextColor3 = Color3.fromRGB(255, 215, 100)
    betInput.Text = "100"
    betInput.TextSize = 16
    betInput.Font = Enum.Font.GothamBold
    betInput.PlaceholderText = "10-10000"
    betInput.Parent = panel
    local betCorner = Instance.new("UICorner")
    betCorner.CornerRadius = UDim.new(0, 6)
    betCorner.Parent = betInput

    -- Botão de apostar
    UIUtils.CreateButton(panel, {
        Name = "PlaceBet",
        Text = "💰 APOSTAR",
        Size = UDim2.new(0, 180, 0, 40),
        Position = UDim2.new(0.5, -90, 0, 310),
        BackgroundColor3 = Color3.fromRGB(180, 120, 30),
        HoverColor = Color3.fromRGB(210, 150, 50),
        TextSize = 18,
        Font = Enum.Font.Antique,
        Corner = 8,
        Callback = function()
            local amount = tonumber(betInput.Text)
            if not amount or amount < 10 or amount > 10000 then
                betInput.Text = "Valor inválido!"
                task.wait(1)
                betInput.Text = "100"
                return
            end
            -- Enviar aposta para o servidor
            local events = ReplicatedStorage:FindFirstChild("Events")
            if events then
                local betEvent = events:FindFirstChild("PlaceBet")
                if betEvent then
                    betEvent:FireServer(amount)
                end
            end
        end,
    })

    -- Botão fechar
    UIUtils.CreateButton(panel, {
        Name = "Close",
        Text = "✕",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Color3.fromRGB(150, 30, 30),
        HoverColor = Color3.fromRGB(200, 50, 50),
        TextSize = 16,
        Corner = 15,
        Callback = function()
            panel.Visible = false
        end,
    })

    return panel, eventInfo, competitorsList
end

-- ============================================================
-- PAINEL DE INVENTÁRIO
-- ============================================================
local function createInventoryPanel(gui)
    local panel = UIUtils.CreateFrame(gui, {
        Name = "InventoryPanel",
        Size = UDim2.new(0, 450, 0, 500),
        Position = UDim2.new(0.5, -225, 0.5, -250),
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        Corner = 12,
        Visible = false,
    })

    UIUtils.CreateText(panel, {
        Name = "Title",
        Text = "🎒 INVENTÁRIO",
        Size = UDim2.new(1, 0, 0, 40),
        TextSize = 20,
        TextColor3 = Color3.fromRGB(100, 200, 255),
    })

    local inventoryScroll = UIUtils.CreateScrollFrame(panel, {
        Name = "Items",
        Size = UDim2.new(1, -20, 1, -100),
        Position = UDim2.new(0, 10, 0, 45),
    })

    -- Botão fechar
    UIUtils.CreateButton(panel, {
        Name = "Close",
        Text = "✕",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Color3.fromRGB(150, 30, 30),
        HoverColor = Color3.fromRGB(200, 50, 50),
        TextSize = 16,
        Corner = 15,
        Callback = function() panel.Visible = false end,
    })

    return panel, inventoryScroll
end

-- ============================================================
-- PAINEL DE CRIATURAS
-- ============================================================
local function createCreaturesPanel(gui)
    local panel = UIUtils.CreateFrame(gui, {
        Name = "CreaturesPanel",
        Size = UDim2.new(0, 500, 0, 500),
        Position = UDim2.new(0.5, -250, 0.5, -250),
        BackgroundColor3 = Color3.fromRGB(30, 35, 30),
        Corner = 12,
        Visible = false,
    })

    UIUtils.CreateText(panel, {
        Name = "Title",
        Text = "🐵 MINHAS CRIATURAS",
        Size = UDim2.new(1, 0, 0, 40),
        TextSize = 20,
        TextColor3 = Color3.fromRGB(150, 255, 150),
    })

    -- Tabs: Macacos | Camelos | Lagostins
    local tabFrame = UIUtils.CreateFrame(panel, {
        Name = "Tabs",
        Size = UDim2.new(1, -20, 0, 35),
        Position = UDim2.new(0, 10, 0, 42),
        BackgroundColor3 = Color3.fromRGB(25, 30, 25),
        Corner = 6,
    })

    local tabs = {"🐵 Macacos", "🐫 Camelos", "🦞 Lagostins"}
    for i, tabName in ipairs(tabs) do
        UIUtils.CreateButton(tabFrame, {
            Name = "Tab" .. i,
            Text = tabName,
            Size = UDim2.new(1/3, -4, 1, -4),
            Position = UDim2.new((i-1)/3, 2, 0, 2),
            BackgroundColor3 = i == 1 and Color3.fromRGB(60, 80, 60) or Color3.fromRGB(40, 45, 40),
            HoverColor = Color3.fromRGB(60, 80, 60),
            TextSize = 13,
            Corner = 4,
        })
    end

    local creaturesScroll = UIUtils.CreateScrollFrame(panel, {
        Name = "CreaturesList",
        Size = UDim2.new(1, -20, 1, -140),
        Position = UDim2.new(0, 10, 0, 82),
    })

    -- Botões de ação
    UIUtils.CreateButton(panel, {
        Name = "TrainBtn",
        Text = "🏋️ Treinar",
        Size = UDim2.new(0, 130, 0, 35),
        Position = UDim2.new(0, 10, 1, -45),
        BackgroundColor3 = Color3.fromRGB(60, 130, 60),
        HoverColor = Color3.fromRGB(80, 160, 80),
        TextSize = 14,
        Corner = 6,
        Callback = function()
            local events = ReplicatedStorage:FindFirstChild("Events")
            if events then
                local trainEvent = events:FindFirstChild("TrainCreature")
                if trainEvent then
                    trainEvent:FireServer()
                end
            end
        end,
    })

    UIUtils.CreateButton(panel, {
        Name = "EquipBtn",
        Text = "⚔️ Equipar",
        Size = UDim2.new(0, 130, 0, 35),
        Position = UDim2.new(0.5, -65, 1, -45),
        BackgroundColor3 = Color3.fromRGB(60, 60, 150),
        HoverColor = Color3.fromRGB(80, 80, 180),
        TextSize = 14,
        Corner = 6,
    })

    -- Botão fechar
    UIUtils.CreateButton(panel, {
        Name = "Close",
        Text = "✕",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Color3.fromRGB(150, 30, 30),
        HoverColor = Color3.fromRGB(200, 50, 50),
        TextSize = 16,
        Corner = 15,
        Callback = function() panel.Visible = false end,
    })

    return panel, creaturesScroll
end

-- ============================================================
-- PAINEL DE ESPECTADOR (Lutas/Corridas)
-- ============================================================
local function createSpectatorPanel(gui)
    -- Painel de Luta
    local fightPanel = UIUtils.CreateFrame(gui, {
        Name = "FightPanel",
        Size = UDim2.new(0, 600, 0, 200),
        Position = UDim2.new(0.5, -300, 1, -220),
        BackgroundColor3 = Color3.fromRGB(40, 20, 20),
        Corner = 12,
        Visible = false,
    })

    UIUtils.CreateText(fightPanel, {
        Name = "Title",
        Text = "⚔️ RINHA DE MACACOS ⚔️",
        Size = UDim2.new(1, 0, 0, 35),
        TextSize = 20,
        TextColor3 = Color3.fromRGB(255, 100, 100),
    })

    -- Fighter 1
    local f1Frame = UIUtils.CreateFrame(fightPanel, {
        Name = "Fighter1",
        Size = UDim2.new(0.4, 0, 0, 120),
        Position = UDim2.new(0.02, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(50, 30, 30),
        Corner = 8,
    })
    UIUtils.CreateText(f1Frame, { Name = "Name", Text = "Lutador 1", TextSize = 16, TextColor3 = Color3.fromRGB(255, 150, 150) })
    UIUtils.CreateText(f1Frame, { Name = "HP", Text = "HP: 100/100", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 30), TextSize = 14 })
    UIUtils.CreateText(f1Frame, { Name = "Action", Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 55), TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 100) })

    -- VS
    UIUtils.CreateText(fightPanel, {
        Name = "VS",
        Text = "⚡VS⚡",
        Size = UDim2.new(0.16, 0, 0, 120),
        Position = UDim2.new(0.42, 0, 0, 40),
        TextSize = 24,
        TextColor3 = Color3.fromRGB(255, 200, 50),
    })

    -- Fighter 2
    local f2Frame = UIUtils.CreateFrame(fightPanel, {
        Name = "Fighter2",
        Size = UDim2.new(0.4, 0, 0, 120),
        Position = UDim2.new(0.58, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(30, 30, 50),
        Corner = 8,
    })
    UIUtils.CreateText(f2Frame, { Name = "Name", Text = "Lutador 2", TextSize = 16, TextColor3 = Color3.fromRGB(150, 150, 255) })
    UIUtils.CreateText(f2Frame, { Name = "HP", Text = "HP: 100/100", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 30), TextSize = 14 })
    UIUtils.CreateText(f2Frame, { Name = "Action", Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 55), TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 100) })

    -- Painel de Corrida
    local racePanel = UIUtils.CreateFrame(gui, {
        Name = "RacePanel",
        Size = UDim2.new(0, 600, 0, 250),
        Position = UDim2.new(0.5, -300, 1, -270),
        BackgroundColor3 = Color3.fromRGB(20, 30, 40),
        Corner = 12,
        Visible = false,
    })

    UIUtils.CreateText(racePanel, {
        Name = "Title",
        Text = "🏁 CORRIDA 🏁",
        Size = UDim2.new(1, 0, 0, 35),
        TextSize = 20,
        TextColor3 = Color3.fromRGB(100, 200, 255),
    })

    -- Pistas de corrida visuais
    for i = 1, 6 do
        local lane = UIUtils.CreateFrame(racePanel, {
            Name = "Lane" .. i,
            Size = UDim2.new(0.9, 0, 0, 25),
            Position = UDim2.new(0.05, 0, 0, 35 + (i-1) * 30),
            BackgroundColor3 = Color3.fromRGB(30, 40, 55),
            Corner = 4,
        })

        UIUtils.CreateText(lane, {
            Name = "RacerName",
            Text = "Corredor " .. i,
            Size = UDim2.new(0.25, 0, 1, 0),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local progressBg = UIUtils.CreateFrame(lane, {
            Name = "ProgressBg",
            Size = UDim2.new(0.7, 0, 0.7, 0),
            Position = UDim2.new(0.25, 0, 0.15, 0),
            BackgroundColor3 = Color3.fromRGB(20, 25, 35),
            Corner = 3,
        })

        local progressBar = UIUtils.CreateFrame(progressBg, {
            Name = "Progress",
            Size = UDim2.new(0, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(50, 150, 255),
            Corner = 3,
        })
    end

    -- Botão fechar para ambos
    for _, p in ipairs({fightPanel, racePanel}) do
        UIUtils.CreateButton(p, {
            Name = "Close",
            Text = "✕",
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -35, 0, 5),
            BackgroundColor3 = Color3.fromRGB(150, 30, 30),
            HoverColor = Color3.fromRGB(200, 50, 50),
            TextSize = 16,
            Corner = 15,
            Callback = function() p.Visible = false end,
        })
    end

    return fightPanel, racePanel
end

-- ============================================================
-- PAINEL DE TROCAS
-- ============================================================
local function createTradePanel(gui)
    local panel = UIUtils.CreateFrame(gui, {
        Name = "TradePanel",
        Size = UDim2.new(0, 550, 0, 400),
        Position = UDim2.new(0.5, -275, 0.5, -200),
        BackgroundColor3 = Color3.fromRGB(35, 30, 40),
        Corner = 12,
        Visible = false,
    })

    UIUtils.CreateText(panel, {
        Name = "Title",
        Text = "🔄 SISTEMA DE TROCAS",
        Size = UDim2.new(1, 0, 0, 40),
        TextSize = 20,
        TextColor3 = Color3.fromRGB(200, 150, 255),
    })

    -- Lado do jogador
    local myOfferFrame = UIUtils.CreateFrame(panel, {
        Name = "MyOffer",
        Size = UDim2.new(0.47, 0, 0, 280),
        Position = UDim2.new(0.015, 0, 0, 45),
        BackgroundColor3 = Color3.fromRGB(30, 25, 35),
        Corner = 8,
    })
    UIUtils.CreateText(myOfferFrame, { Name = "Label", Text = "Minha Oferta", TextSize = 14, TextColor3 = Color3.fromRGB(150, 200, 255) })

    -- Lado do outro jogador
    local theirOfferFrame = UIUtils.CreateFrame(panel, {
        Name = "TheirOffer",
        Size = UDim2.new(0.47, 0, 0, 280),
        Position = UDim2.new(0.515, 0, 0, 45),
        BackgroundColor3 = Color3.fromRGB(35, 25, 30),
        Corner = 8,
    })
    UIUtils.CreateText(theirOfferFrame, { Name = "Label", Text = "Oferta do Outro", TextSize = 14, TextColor3 = Color3.fromRGB(255, 150, 150) })

    -- Botões de ação
    UIUtils.CreateButton(panel, {
        Name = "ConfirmTrade",
        Text = "✅ Confirmar",
        Size = UDim2.new(0, 150, 0, 35),
        Position = UDim2.new(0.15, 0, 1, -45),
        BackgroundColor3 = Color3.fromRGB(40, 130, 40),
        HoverColor = Color3.fromRGB(60, 160, 60),
        TextSize = 14,
        Corner = 6,
    })

    UIUtils.CreateButton(panel, {
        Name = "CancelTrade",
        Text = "❌ Cancelar",
        Size = UDim2.new(0, 150, 0, 35),
        Position = UDim2.new(0.6, 0, 1, -45),
        BackgroundColor3 = Color3.fromRGB(150, 40, 40),
        HoverColor = Color3.fromRGB(180, 60, 60),
        TextSize = 14,
        Corner = 6,
    })

    -- Botão fechar
    UIUtils.CreateButton(panel, {
        Name = "Close",
        Text = "✕",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Color3.fromRGB(150, 30, 30),
        HoverColor = Color3.fromRGB(200, 50, 50),
        TextSize = 16,
        Corner = 15,
        Callback = function() panel.Visible = false end,
    })

    return panel
end

-- ============================================================
-- CONEXÕES DE EVENTOS DO SERVIDOR
-- ============================================================
local function setupServerEvents(gui, coinsLabel, fightPanel, racePanel, eventInfo)
    task.spawn(function()
        local events = ReplicatedStorage:WaitForChild("Events", 30)
        if not events then
            warn("[Client] Pasta Events não encontrada!")
            return
        end

        -- Atualizar moedas
        local coinsEvent = events:FindFirstChild("UpdateCoins")
        if coinsEvent then
            coinsEvent.OnClientEvent:Connect(function(amount)
                coinsLabel.Text = "💰 Moedas: " .. tostring(amount)
            end)
        end

        -- Eventos de luta
        local fightFolder = events:FindFirstChild("FightEvents")
        if fightFolder then
            local fightStart = fightFolder:FindFirstChild("FightStarted")
            if fightStart then
                fightStart.OnClientEvent:Connect(function(fightData)
                    fightPanel.Visible = true
                    local f1 = fightPanel:FindFirstChild("Fighter1")
                    local f2 = fightPanel:FindFirstChild("Fighter2")
                    if f1 and fightData.Fighter1 then
                        f1.Name.Text = fightData.Fighter1.Name or "???"
                    end
                    if f2 and fightData.Fighter2 then
                        f2.Name.Text = fightData.Fighter2.Name or "???"
                    end
                    eventInfo.Text = "⚔️ Rinha: " .. (fightData.Fighter1 and fightData.Fighter1.Name or "???") .. " vs " .. (fightData.Fighter2 and fightData.Fighter2.Name or "???")
                end)
            end

            local fightTick = fightFolder:FindFirstChild("FightTick")
            if fightTick then
                fightTick.OnClientEvent:Connect(function(tickData)
                    local f1 = fightPanel:FindFirstChild("Fighter1")
                    local f2 = fightPanel:FindFirstChild("Fighter2")
                    if f1 and tickData.Fighter1 then
                        f1.HP.Text = "HP: " .. tickData.Fighter1.HP .. "/" .. tickData.Fighter1.MaxHP
                        f1.Action.Text = tickData.Fighter1.LastAction or ""
                    end
                    if f2 and tickData.Fighter2 then
                        f2.HP.Text = "HP: " .. tickData.Fighter2.HP .. "/" .. tickData.Fighter2.MaxHP
                        f2.Action.Text = tickData.Fighter2.LastAction or ""
                    end
                end)
            end

            local fightEnd = fightFolder:FindFirstChild("FightEnded")
            if fightEnd then
                fightEnd.OnClientEvent:Connect(function(resultData)
                    eventInfo.Text = "🏆 Vencedor: " .. (resultData.WinnerName or "Empate!")
                    task.wait(10)
                    fightPanel.Visible = false
                end)
            end
        end

        -- Eventos de corrida
        local raceFolder = events:FindFirstChild("RaceEvents")
        if raceFolder then
            local raceStart = raceFolder:FindFirstChild("RaceStarted")
            if raceStart then
                raceStart.OnClientEvent:Connect(function(raceData)
                    racePanel.Visible = true
                    racePanel.Title.Text = raceData.Type == "CamelRace" and "🐫 CORRIDA DE CAMELOS 🐫" or "🦞 CORRIDA DE LAGOSTINS 🦞"
                    eventInfo.Text = (raceData.Type == "CamelRace" and "🐫 Corrida de Camelos" or "🦞 Corrida de Lagostins") .. " começando!"
                    for i = 1, 6 do
                        local lane = racePanel:FindFirstChild("Lane" .. i)
                        if lane and raceData.Racers and raceData.Racers[i] then
                            lane.RacerName.Text = raceData.Racers[i].Name or ("Corredor " .. i)
                        end
                    end
                end)
            end

            local raceTick = raceFolder:FindFirstChild("RaceTick")
            if raceTick then
                raceTick.OnClientEvent:Connect(function(tickData)
                    if tickData.Positions then
                        for i, pos in ipairs(tickData.Positions) do
                            local lane = racePanel:FindFirstChild("Lane" .. i)
                            if lane then
                                local progressBg = lane:FindFirstChild("ProgressBg")
                                if progressBg then
                                    local progress = progressBg:FindFirstChild("Progress")
                                    if progress then
                                        local pct = math.clamp((pos.Position or 0) / 100, 0, 1)
                                        TweenService:Create(progress, TweenInfo.new(0.4), {
                                            Size = UDim2.new(pct, 0, 1, 0)
                                        }):Play()
                                    end
                                end
                            end
                        end
                    end
                end)
            end

            local raceEnd = raceFolder:FindFirstChild("RaceEnded")
            if raceEnd then
                raceEnd.OnClientEvent:Connect(function(resultData)
                    eventInfo.Text = "🏆 1° Lugar: " .. (resultData.FirstPlace or "???")
                    task.wait(10)
                    racePanel.Visible = false
                end)
            end
        end
    end)
end

-- ============================================================
-- INICIALIZAÇÃO DO CLIENTE
-- ============================================================
local gui, coinsLabel = createHUD()
local bettingPanel, eventInfo, competitorsList = createBettingPanel(gui)
local inventoryPanel, inventoryScroll = createInventoryPanel(gui)
local creaturesPanel, creaturesScroll = createCreaturesPanel(gui)
local fightPanel, racePanel = createSpectatorPanel(gui)
local tradePanel = createTradePanel(gui)

setupServerEvents(gui, coinsLabel, fightPanel, racePanel, eventInfo)

print("[Client] Arena Selvagem - UI carregada!")
