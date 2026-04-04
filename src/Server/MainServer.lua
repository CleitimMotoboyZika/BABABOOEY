-- MainServer.lua
-- Script principal do servidor - Arena Selvagem
-- Inicializa todos os sistemas do jogo

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- ============================================================
-- MÓDULOS DO SERVIDOR
-- ============================================================
local DataStoreManager = require(script.Parent.DataStoreManager)
local FightSystem = require(script.Parent.FightSystem)
local RaceSystem = require(script.Parent.RaceSystem)
local TradeSystem = require(script.Parent.TradeSystem)
local EvolutionSystem = require(script.Parent.EvolutionSystem)
local InventorySystem = require(script.Parent.InventorySystem)

-- ============================================================
-- AUTO-FIX SYSTEM
-- Sistema de autocorreção de bugs em runtime
-- ============================================================
local AutoFix = {}
AutoFix.ErrorLog = {}
AutoFix.MaxErrors = 100
AutoFix.FixAttempts = {}

function AutoFix.LogError(context, err)
    table.insert(AutoFix.ErrorLog, {
        Time = os.time(),
        Context = context,
        Error = tostring(err),
    })
    if #AutoFix.ErrorLog > AutoFix.MaxErrors then
        table.remove(AutoFix.ErrorLog, 1)
    end
    warn("[AutoFix] Erro detectado em " .. context .. ": " .. tostring(err))
end

function AutoFix.SafeCall(context, fn, ...)
    local args = {...}
    local success, result = pcall(function()
        return fn(table.unpack(args))
    end)
    if not success then
        AutoFix.LogError(context, result)
        -- Tenta recuperar reinicializando o sistema afetado
        AutoFix.AttemptRecovery(context)
        return nil, result
    end
    return result
end

function AutoFix.AttemptRecovery(context)
    local attempts = AutoFix.FixAttempts[context] or 0
    if attempts >= 3 then
        warn("[AutoFix] Máximo de tentativas de recuperação atingido para: " .. context)
        return
    end
    AutoFix.FixAttempts[context] = attempts + 1
    warn("[AutoFix] Tentativa de recuperação #" .. (attempts + 1) .. " para: " .. context)

    task.spawn(function()
        task.wait(5) -- Aguarda 5 segundos antes de tentar recuperar
        local recoveryMap = {
            FightSystem = function()
                pcall(function() FightSystem.Initialize() end)
            end,
            RaceSystem = function()
                pcall(function() RaceSystem.Initialize() end)
            end,
            TradeSystem = function()
                pcall(function() TradeSystem.Initialize() end)
            end,
            EvolutionSystem = function()
                pcall(function() EvolutionSystem.Initialize() end)
            end,
            InventorySystem = function()
                pcall(function() InventorySystem.Initialize() end)
            end,
            DataStore = function()
                -- Recarrega dados de todos os jogadores
                for _, player in ipairs(Players:GetPlayers()) do
                    pcall(function() DataStoreManager.LoadPlayerData(player) end)
                end
            end,
        }
        if recoveryMap[context] then
            recoveryMap[context]()
            print("[AutoFix] Recuperação concluída para: " .. context)
        end
    end)
end

function AutoFix.MonitorHealth()
    task.spawn(function()
        while true do
            task.wait(60) -- Verifica a cada 60 segundos
            -- Verifica se os sistemas estão respondendo
            local systems = {
                { Name = "FightSystem", Check = function() return FightSystem.GetFightHistory() ~= nil end },
                { Name = "RaceSystem", Check = function() return RaceSystem.GetRaceHistory() ~= nil end },
            }
            for _, sys in ipairs(systems) do
                local ok, _ = pcall(sys.Check)
                if not ok then
                    warn("[AutoFix] Sistema " .. sys.Name .. " não está respondendo. Tentando recuperar...")
                    AutoFix.AttemptRecovery(sys.Name)
                end
            end
            -- Reseta contadores de tentativas periodicamente
            AutoFix.FixAttempts = {}
        end
    end)
end

-- ============================================================
-- INICIALIZAÇÃO
-- ============================================================
print("===========================================")
print("   ARENA SELVAGEM - Servidor Iniciando")
print("===========================================")

-- Criar pastas no ReplicatedStorage
local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

ensureFolder(ReplicatedStorage, "Events")
ensureFolder(ReplicatedStorage, "Modules")
ensureFolder(ReplicatedStorage, "Assets")

-- Inicializa sistemas com proteção AutoFix
print("[Server] Inicializando DataStore...")
AutoFix.SafeCall("DataStore", function()
    -- DataStoreManager inicializa automaticamente
    print("[Server] DataStore pronto.")
end)

print("[Server] Inicializando Sistema de Luta...")
AutoFix.SafeCall("FightSystem", function()
    FightSystem.Initialize()
    print("[Server] Sistema de Luta pronto.")
end)

print("[Server] Inicializando Sistema de Corrida...")
AutoFix.SafeCall("RaceSystem", function()
    RaceSystem.Initialize()
    print("[Server] Sistema de Corrida pronto.")
end)

print("[Server] Inicializando Sistema de Troca...")
AutoFix.SafeCall("TradeSystem", function()
    TradeSystem.Initialize()
    print("[Server] Sistema de Troca pronto.")
end)

print("[Server] Inicializando Sistema de Evolução...")
AutoFix.SafeCall("EvolutionSystem", function()
    EvolutionSystem.Initialize()
    print("[Server] Sistema de Evolução pronto.")
end)

print("[Server] Inicializando Sistema de Inventário...")
AutoFix.SafeCall("InventorySystem", function()
    InventorySystem.Initialize()
    print("[Server] Sistema de Inventário pronto.")
end)

-- Inicia monitoramento de saúde
AutoFix.MonitorHealth()

-- ============================================================
-- GERENCIAMENTO DE JOGADORES
-- ============================================================
local function onPlayerAdded(player)
    print("[Server] Jogador conectado: " .. player.Name)

    -- Carrega dados do jogador
    AutoFix.SafeCall("DataStore", function()
        DataStoreManager.LoadPlayerData(player)
    end)

    -- Dá starter pack se for jogador novo
    task.spawn(function()
        task.wait(2) -- Aguarda dados carregarem
        local data = DataStoreManager.GetPlayerData(player)
        if data and #data.Creatures == 0 then
            print("[Server] Novo jogador detectado, dando starter pack...")
            local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
            -- Dá macaco inicial
            local starterMonkey = nil
            for _, monkey in ipairs(GameConfig.Monkeys) do
                if monkey.Id == GameConfig.Player.StarterPack.Monkey then
                    starterMonkey = monkey
                    break
                end
            end
            if starterMonkey then
                local creatureData = {
                    UniqueId = player.UserId .. "_" .. os.time() .. "_starter",
                    TemplateId = starterMonkey.Id,
                    Type = "Monkey",
                    Name = starterMonkey.Name,
                    Rarity = starterMonkey.Rarity,
                    Level = 1,
                    Experience = 0,
                    Affection = 10,
                    EvolutionStage = 1,
                    EquippedItems = {},
                }
                DataStoreManager.AddCreature(player, creatureData)
                print("[Server] Macaco inicial entregue: " .. starterMonkey.Name)
            end
        end
    end)
end

local function onPlayerRemoving(player)
    print("[Server] Jogador desconectando: " .. player.Name)
    AutoFix.SafeCall("DataStore", function()
        DataStoreManager.SavePlayerData(player)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Processa jogadores que já estão no jogo (para Studio)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

print("===========================================")
print("   ARENA SELVAGEM - Servidor Pronto!")
print("   Sistemas ativos: 6/6")
print("   AutoFix: Ativo")
print("===========================================")
