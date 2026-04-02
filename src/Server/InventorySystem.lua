--[[
    InventorySystem.lua
    Server-side inventory management, equip/unequip, shop buy/sell, and
    consumable usage for Arena Selvagem.

    All operations are server-validated to prevent exploits.
    Communicates with clients via RemoteEvents / RemoteFunctions.

    Public API (returned table):
        Initialize()
        BuyItem(player, itemId)
        SellItem(player, inventorySlotIndex)
        EquipItem(player, creatureId, itemId)
        UnequipItem(player, creatureId, slotName)
        GetInventory(player)
        GetEquippedItems(player, creatureId)
        UseItem(player, itemId, targetCreatureId)
        GetShopItems()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GameConfig       = require(script.Parent.Parent.Shared.GameConfig)
local DataStoreManager = require(script.Parent.DataStoreManager)

-- ============================================================
-- Constants
-- ============================================================

local MAX_INVENTORY_SLOTS = GameConfig.Player.MaxInventorySlots -- 50
local SELL_MULTIPLIER     = 0.5  -- sell items at 50% of purchase price
local MAX_STACK_SIZE      = 99

local VALID_SLOTS = {
    Hands     = true,
    Body      = true,
    Saddle    = true,
    Accessory = true,
}

-- Equipment type → creature type compatibility
-- Weapons and Armor are for monkeys only; RaceGear is for camels/lobsters
local EQUIPMENT_TYPE_COMPATIBILITY = {
    Weapon    = { Monkey = true },
    Armor     = { Monkey = true },
    RaceGear  = { Camel = true, Lobster = true },
    Accessory = { Monkey = true, Camel = true, Lobster = true },
}

-- Item types that can be stacked (consumables)
local STACKABLE_TYPES = {
    Consumable = true,
    Potion     = true,
    Food       = true,
}

-- ============================================================
-- Remote Events / Functions
-- ============================================================

local function getOrCreateFolder(name)
    local folder = ReplicatedStorage:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = ReplicatedStorage
    end
    return folder
end

local function getOrCreateRemote(folder, name, className)
    className = className or "RemoteEvent"
    local remote = folder:FindFirstChild(name)
    if not remote then
        remote = Instance.new(className)
        remote.Name = name
        remote.Parent = folder
    end
    return remote
end

local Remotes = {}

-- ============================================================
-- Module table
-- ============================================================

local InventorySystem = {}

-- ============================================================
-- Lookup caches (built once during Initialize)
-- ============================================================

local equipmentById = {}   -- itemId → equipment config entry
local shopItemList  = {}   -- ordered list for client display

local function buildEquipmentLookup()
    equipmentById = {}
    shopItemList  = {}
    for _, item in ipairs(GameConfig.Equipment) do
        equipmentById[item.Id] = item
        table.insert(shopItemList, {
            Id     = item.Id,
            Name   = item.Name,
            Type   = item.Type,
            Slot   = item.Slot,
            Rarity = item.Rarity,
            Stats  = item.Stats,
            Price  = item.Price,
        })
    end
end

-- ============================================================
-- Validation helpers
-- ============================================================

local function isValidPlayer(player)
    return typeof(player) == "Instance"
        and player:IsA("Player")
        and player:IsDescendantOf(Players)
end

local function getPlayerDataDirect(player)
    -- We need the live cache reference, not a copy, so we can mutate it.
    -- DataStoreManager.GetPlayerData returns a deep copy, which we cannot
    -- use for writes.  We rely on the internal cache via a known pattern:
    -- load it once, then read back the reference.  For safety we always
    -- go through the official getter and accept the copy for read-only ops.
    return DataStoreManager.GetPlayerData(player)
end

--- Find an item config definition by its Id.
local function getItemConfig(itemId)
    return equipmentById[itemId]
end

--- Locate an inventory entry by item Id inside a player's inventory.
--- Returns (index, entry) or (nil, nil).
local function findInventoryEntry(inventory, itemId)
    for i, entry in ipairs(inventory) do
        if entry.Id == itemId then
            return i, entry
        end
    end
    return nil, nil
end

--- Find creature data by Id in the player's creature list.
local function findCreature(creatures, creatureId)
    for i, creature in ipairs(creatures) do
        if creature.Id == creatureId then
            return i, creature
        end
    end
    return nil, nil
end

--- Determine the creature "type" (Monkey, Camel, Lobster) from its species Id.
local function getCreatureType(creatureData)
    if creatureData and creatureData.Type then
        return creatureData.Type
    end
    return nil
end

--- Verify that an equipment type is compatible with a given creature type.
local function isCompatible(equipmentType, creatureType)
    local compat = EQUIPMENT_TYPE_COMPATIBILITY[equipmentType]
    if not compat then
        return false
    end
    return compat[creatureType] == true
end

--- Count total occupied inventory slots (stacked items count as 1 slot).
local function countInventorySlots(inventory)
    return #inventory
end

-- ============================================================
-- Internal data mutation helpers
-- These use DataStoreManager's public API to persist changes.
-- ============================================================

--- Add an item to the player's inventory, stacking if applicable.
--- Returns true/false and an optional error string.
local function addItemToInventory(player, itemConfig, quantity)
    quantity = quantity or 1
    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return false, "NO_DATA"
    end

    local isStackable = STACKABLE_TYPES[itemConfig.Type] == true

    if isStackable then
        -- Check if the player already has this item; if so, increase quantity
        for _, entry in ipairs(data.Inventory) do
            if entry.Id == itemConfig.Id then
                local newQty = math.min((entry.Quantity or 1) + quantity, MAX_STACK_SIZE)
                entry.Quantity = newQty
                -- Persist the updated inventory
                DataStoreManager.UpdatePlayerData(player, "Inventory", data.Inventory)
                return true
            end
        end
    end

    -- Not stackable or not yet in inventory — add as new slot
    if countInventorySlots(data.Inventory) >= MAX_INVENTORY_SLOTS then
        return false, "INVENTORY_FULL"
    end

    local ok = DataStoreManager.AddInventoryItem(player, {
        Id       = itemConfig.Id,
        Name     = itemConfig.Name,
        Type     = itemConfig.Type,
        Quantity = quantity,
    })

    if not ok then
        return false, "ADD_FAILED"
    end
    return true
end

--- Remove an item from inventory by slot index.
--- Returns the removed entry or nil.
local function removeItemFromInventoryByIndex(player, slotIndex)
    local data = DataStoreManager.GetPlayerData(player)
    if not data or not data.Inventory then
        return nil
    end

    local entry = data.Inventory[slotIndex]
    if not entry then
        return nil
    end

    local ok = DataStoreManager.RemoveInventoryItem(player, entry.Id)
    if ok then
        return entry
    end
    return nil
end

--- Remove one quantity of a stackable item by Id.
--- If quantity reaches 0 the slot is removed entirely.
--- Returns true on success.
local function consumeItemById(player, itemId)
    local data = DataStoreManager.GetPlayerData(player)
    if not data or not data.Inventory then
        return false
    end

    for i, entry in ipairs(data.Inventory) do
        if entry.Id == itemId then
            local qty = entry.Quantity or 1
            if qty <= 1 then
                DataStoreManager.RemoveInventoryItem(player, itemId)
            else
                entry.Quantity = qty - 1
                DataStoreManager.UpdatePlayerData(player, "Inventory", data.Inventory)
            end
            return true
        end
    end
    return false
end

-- ============================================================
-- Equipped-items helpers
-- EquippedItems is stored as a dictionary:
--   { [creatureId] = { Hands = itemId, Body = itemId, ... } }
-- ============================================================

local function getEquippedMap(data)
    if type(data.EquippedItems) ~= "table" then
        data.EquippedItems = {}
    end
    return data.EquippedItems
end

local function getCreatureEquipment(data, creatureId)
    local map = getEquippedMap(data)
    if type(map[creatureId]) ~= "table" then
        map[creatureId] = {}
    end
    return map[creatureId]
end

local function saveEquippedItems(player, equippedMap)
    DataStoreManager.UpdatePlayerData(player, "EquippedItems", equippedMap)
end

-- ============================================================
-- Stat bonus calculation
-- ============================================================

--- Calculate total stat bonuses from all equipped items on a creature.
function InventorySystem.CalculateEquipmentBonuses(player, creatureId)
    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return {}
    end

    local creatureEquip = getCreatureEquipment(data, creatureId)
    local totalBonuses = {}

    for _, itemId in pairs(creatureEquip) do
        local config = getItemConfig(itemId)
        if config and config.Stats then
            for stat, value in pairs(config.Stats) do
                totalBonuses[stat] = (totalBonuses[stat] or 0) + value
            end
        end
    end

    return totalBonuses
end

-- ============================================================
-- Public API
-- ============================================================

--- Initialise remotes and build lookup tables.
function InventorySystem.Initialize()
    buildEquipmentLookup()

    local folder = getOrCreateFolder("InventoryEvents")

    Remotes.BuyItem          = getOrCreateRemote(folder, "BuyItem")
    Remotes.SellItem         = getOrCreateRemote(folder, "SellItem")
    Remotes.EquipItem        = getOrCreateRemote(folder, "EquipItem")
    Remotes.UnequipItem      = getOrCreateRemote(folder, "UnequipItem")
    Remotes.UseItem          = getOrCreateRemote(folder, "UseItem")
    Remotes.InventoryUpdated = getOrCreateRemote(folder, "InventoryUpdated")
    Remotes.EquipUpdated     = getOrCreateRemote(folder, "EquipUpdated")
    Remotes.ShopError        = getOrCreateRemote(folder, "ShopError")

    -- RemoteFunctions for synchronous queries from the client
    Remotes.GetInventory     = getOrCreateRemote(folder, "GetInventory", "RemoteFunction")
    Remotes.GetEquippedItems = getOrCreateRemote(folder, "GetEquippedItems", "RemoteFunction")
    Remotes.GetShopItems     = getOrCreateRemote(folder, "GetShopItems", "RemoteFunction")

    -- --------------------------------------------------------
    -- Wire up client → server communication
    -- --------------------------------------------------------

    Remotes.BuyItem.OnServerEvent:Connect(function(player, itemId)
        if type(itemId) ~= "string" then return end
        local success, err = InventorySystem.BuyItem(player, itemId)
        if not success then
            Remotes.ShopError:FireClient(player, "BuyItem", err)
        end
    end)

    Remotes.SellItem.OnServerEvent:Connect(function(player, slotIndex)
        if type(slotIndex) ~= "number" then return end
        local success, err = InventorySystem.SellItem(player, slotIndex)
        if not success then
            Remotes.ShopError:FireClient(player, "SellItem", err)
        end
    end)

    Remotes.EquipItem.OnServerEvent:Connect(function(player, creatureId, itemId)
        if type(creatureId) ~= "string" or type(itemId) ~= "string" then return end
        local success, err = InventorySystem.EquipItem(player, creatureId, itemId)
        if not success then
            Remotes.ShopError:FireClient(player, "EquipItem", err)
        end
    end)

    Remotes.UnequipItem.OnServerEvent:Connect(function(player, creatureId, slotName)
        if type(creatureId) ~= "string" or type(slotName) ~= "string" then return end
        local success, err = InventorySystem.UnequipItem(player, creatureId, slotName)
        if not success then
            Remotes.ShopError:FireClient(player, "UnequipItem", err)
        end
    end)

    Remotes.UseItem.OnServerEvent:Connect(function(player, itemId, targetCreatureId)
        if type(itemId) ~= "string" then return end
        if targetCreatureId ~= nil and type(targetCreatureId) ~= "string" then return end
        local success, err = InventorySystem.UseItem(player, itemId, targetCreatureId)
        if not success then
            Remotes.ShopError:FireClient(player, "UseItem", err)
        end
    end)

    Remotes.GetInventory.OnServerInvoke = function(player)
        return InventorySystem.GetInventory(player)
    end

    Remotes.GetEquippedItems.OnServerInvoke = function(player, creatureId)
        if type(creatureId) ~= "string" then return nil end
        return InventorySystem.GetEquippedItems(player, creatureId)
    end

    Remotes.GetShopItems.OnServerInvoke = function(_player)
        return InventorySystem.GetShopItems()
    end

    print("[InventorySystem] Initialized – " .. tostring(#shopItemList) .. " shop items loaded.")
end

--- Purchase an item from the shop.
--- Returns (true) on success or (false, errorCode) on failure.
function InventorySystem.BuyItem(player, itemId)
    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end
    if type(itemId) ~= "string" then
        return false, "INVALID_ITEM_ID"
    end

    local itemConfig = getItemConfig(itemId)
    if not itemConfig then
        print(string.format("[InventorySystem] BuyItem: unknown item '%s'.", itemId))
        return false, "ITEM_NOT_FOUND"
    end

    local price = itemConfig.Price
    if not price or price <= 0 then
        return false, "ITEM_NOT_PURCHASABLE"
    end

    -- Check player can afford it
    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return false, "NO_DATA"
    end

    if data.Coins < price then
        print(string.format(
            "[InventorySystem] BuyItem: %s cannot afford '%s' (%d < %d).",
            player.Name, itemId, data.Coins, price
        ))
        return false, "INSUFFICIENT_COINS"
    end

    -- Check inventory space
    if countInventorySlots(data.Inventory) >= MAX_INVENTORY_SLOTS then
        return false, "INVENTORY_FULL"
    end

    -- Deduct coins first (atomic-ish)
    local coinsRemoved = DataStoreManager.RemoveCoins(player, price)
    if not coinsRemoved then
        return false, "COIN_DEDUCTION_FAILED"
    end

    -- Add item to inventory
    local added, addErr = addItemToInventory(player, itemConfig, 1)
    if not added then
        -- Refund coins on failure
        DataStoreManager.AddCoins(player, price)
        print(string.format(
            "[InventorySystem] BuyItem: failed to add '%s' for %s – refunding %d coins. Reason: %s",
            itemId, player.Name, price, tostring(addErr)
        ))
        return false, addErr or "ADD_FAILED"
    end

    print(string.format(
        "[InventorySystem] %s bought '%s' for %d coins.",
        player.Name, itemConfig.Name, price
    ))

    -- Notify client
    local updatedData = DataStoreManager.GetPlayerData(player)
    if Remotes.InventoryUpdated then
        Remotes.InventoryUpdated:FireClient(player, {
            Action    = "BuyItem",
            ItemId    = itemId,
            Coins     = updatedData and updatedData.Coins or 0,
            Inventory = updatedData and updatedData.Inventory or {},
        })
    end

    return true
end

--- Sell an item from inventory by slot index.
--- Player receives 50% of the item's shop price.
function InventorySystem.SellItem(player, inventorySlotIndex)
    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end
    if type(inventorySlotIndex) ~= "number"
        or inventorySlotIndex < 1
        or inventorySlotIndex ~= math.floor(inventorySlotIndex) then
        return false, "INVALID_SLOT"
    end

    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return false, "NO_DATA"
    end

    local entry = data.Inventory[inventorySlotIndex]
    if not entry then
        return false, "SLOT_EMPTY"
    end

    -- Verify item is not currently equipped on any creature
    local equippedMap = getEquippedMap(data)
    for creatureId, slots in pairs(equippedMap) do
        for slotName, equippedItemId in pairs(slots) do
            if equippedItemId == entry.Id then
                print(string.format(
                    "[InventorySystem] SellItem: '%s' is equipped on creature '%s' slot '%s'; unequip first.",
                    entry.Id, creatureId, slotName
                ))
                return false, "ITEM_EQUIPPED"
            end
        end
    end

    -- Calculate sell price
    local itemConfig = getItemConfig(entry.Id)
    local sellPrice = 0
    if itemConfig and itemConfig.Price then
        sellPrice = math.floor(itemConfig.Price * SELL_MULTIPLIER)
    end

    -- Remove item
    local removed = removeItemFromInventoryByIndex(player, inventorySlotIndex)
    if not removed then
        return false, "REMOVE_FAILED"
    end

    -- Add coins
    if sellPrice > 0 then
        DataStoreManager.AddCoins(player, sellPrice)
    end

    print(string.format(
        "[InventorySystem] %s sold '%s' for %d coins.",
        player.Name, entry.Id, sellPrice
    ))

    -- Notify client
    local updatedData = DataStoreManager.GetPlayerData(player)
    if Remotes.InventoryUpdated then
        Remotes.InventoryUpdated:FireClient(player, {
            Action    = "SellItem",
            ItemId    = entry.Id,
            SellPrice = sellPrice,
            Coins     = updatedData and updatedData.Coins or 0,
            Inventory = updatedData and updatedData.Inventory or {},
        })
    end

    return true
end

--- Equip an item from inventory onto a creature's appropriate slot.
--- Performs full server-side validation:
---   1. Player owns the item
---   2. Player owns the creature
---   3. Item fits a valid slot
---   4. Item is compatible with the creature type
---   5. Auto-unequips any existing item in the same slot
---   6. Persists via DataStoreManager
function InventorySystem.EquipItem(player, creatureId, itemId)
    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end
    if type(creatureId) ~= "string" or type(itemId) ~= "string" then
        return false, "INVALID_ARGS"
    end

    -- 1. Verify player owns the item
    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return false, "NO_DATA"
    end

    local _, invEntry = findInventoryEntry(data.Inventory, itemId)
    if not invEntry then
        print(string.format(
            "[InventorySystem] EquipItem: %s does not own item '%s'.",
            player.Name, itemId
        ))
        return false, "ITEM_NOT_OWNED"
    end

    -- 2. Verify player owns the creature
    local _, creature = findCreature(data.Creatures, creatureId)
    if not creature then
        print(string.format(
            "[InventorySystem] EquipItem: %s does not own creature '%s'.",
            player.Name, creatureId
        ))
        return false, "CREATURE_NOT_OWNED"
    end

    -- 3. Verify item has a valid slot
    local itemConfig = getItemConfig(itemId)
    if not itemConfig then
        return false, "ITEM_CONFIG_NOT_FOUND"
    end

    local slot = itemConfig.Slot
    if not slot or not VALID_SLOTS[slot] then
        print(string.format(
            "[InventorySystem] EquipItem: item '%s' has invalid slot '%s'.",
            itemId, tostring(slot)
        ))
        return false, "INVALID_SLOT"
    end

    -- 4. Verify compatibility with creature type
    local creatureType = getCreatureType(creature)
    if not creatureType then
        return false, "UNKNOWN_CREATURE_TYPE"
    end

    if not isCompatible(itemConfig.Type, creatureType) then
        print(string.format(
            "[InventorySystem] EquipItem: '%s' (type=%s) not compatible with creature type '%s'.",
            itemId, itemConfig.Type, creatureType
        ))
        return false, "INCOMPATIBLE"
    end

    -- Check if item is already equipped on another creature
    local equippedMap = getEquippedMap(data)
    for otherCreatureId, slots in pairs(equippedMap) do
        for slotName, equippedItemId in pairs(slots) do
            if equippedItemId == itemId and otherCreatureId ~= creatureId then
                print(string.format(
                    "[InventorySystem] EquipItem: '%s' already equipped on creature '%s'.",
                    itemId, otherCreatureId
                ))
                return false, "ITEM_EQUIPPED_ELSEWHERE"
            end
        end
    end

    -- 5. Auto-unequip existing item in the same slot
    local creatureSlots = getCreatureEquipment(data, creatureId)
    local previousItemId = creatureSlots[slot]
    if previousItemId and previousItemId ~= itemId then
        print(string.format(
            "[InventorySystem] EquipItem: auto-unequipping '%s' from slot '%s' on creature '%s'.",
            previousItemId, slot, creatureId
        ))
    end

    -- 6. Set the new item and persist
    creatureSlots[slot] = itemId
    equippedMap[creatureId] = creatureSlots
    saveEquippedItems(player, equippedMap)

    print(string.format(
        "[InventorySystem] %s equipped '%s' on creature '%s' slot '%s'.",
        player.Name, itemId, creatureId, slot
    ))

    -- Notify client
    if Remotes.EquipUpdated then
        Remotes.EquipUpdated:FireClient(player, {
            Action     = "Equip",
            CreatureId = creatureId,
            Slot       = slot,
            ItemId     = itemId,
            PreviousItemId = previousItemId,
            Bonuses    = InventorySystem.CalculateEquipmentBonuses(player, creatureId),
        })
    end

    return true
end

--- Unequip an item from a creature's slot and return it to inventory.
function InventorySystem.UnequipItem(player, creatureId, slotName)
    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end
    if type(creatureId) ~= "string" or type(slotName) ~= "string" then
        return false, "INVALID_ARGS"
    end
    if not VALID_SLOTS[slotName] then
        return false, "INVALID_SLOT"
    end

    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return false, "NO_DATA"
    end

    -- Verify player owns the creature
    local _, creature = findCreature(data.Creatures, creatureId)
    if not creature then
        return false, "CREATURE_NOT_OWNED"
    end

    local equippedMap = getEquippedMap(data)
    local creatureSlots = getCreatureEquipment(data, creatureId)
    local equippedItemId = creatureSlots[slotName]

    if not equippedItemId then
        return false, "SLOT_EMPTY"
    end

    -- Clear the slot and persist
    creatureSlots[slotName] = nil

    -- Clean up empty creature entries
    local hasAny = false
    for _, _ in pairs(creatureSlots) do
        hasAny = true
        break
    end
    if not hasAny then
        equippedMap[creatureId] = nil
    else
        equippedMap[creatureId] = creatureSlots
    end

    saveEquippedItems(player, equippedMap)

    print(string.format(
        "[InventorySystem] %s unequipped '%s' from creature '%s' slot '%s'.",
        player.Name, equippedItemId, creatureId, slotName
    ))

    -- Notify client
    if Remotes.EquipUpdated then
        Remotes.EquipUpdated:FireClient(player, {
            Action     = "Unequip",
            CreatureId = creatureId,
            Slot       = slotName,
            ItemId     = equippedItemId,
            Bonuses    = InventorySystem.CalculateEquipmentBonuses(player, creatureId),
        })
    end

    return true
end

--- Return the full inventory for a player (read-only copy).
function InventorySystem.GetInventory(player)
    if not isValidPlayer(player) then
        return nil
    end

    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return nil
    end

    -- Enrich each entry with config data for client display
    local enriched = {}
    for i, entry in ipairs(data.Inventory) do
        local config = getItemConfig(entry.Id)
        enriched[i] = {
            SlotIndex = i,
            Id        = entry.Id,
            Name      = entry.Name or (config and config.Name) or "Unknown",
            Type      = entry.Type or (config and config.Type) or "Unknown",
            Quantity  = entry.Quantity or 1,
            Rarity    = config and config.Rarity or "Common",
            Stats     = config and config.Stats or {},
            Slot      = config and config.Slot or nil,
            Price     = config and config.Price or 0,
        }
    end

    return {
        Items     = enriched,
        UsedSlots = #enriched,
        MaxSlots  = MAX_INVENTORY_SLOTS,
        Coins     = data.Coins,
    }
end

--- Return equipped items for a specific creature (read-only copy).
function InventorySystem.GetEquippedItems(player, creatureId)
    if not isValidPlayer(player) then
        return nil
    end
    if type(creatureId) ~= "string" then
        return nil
    end

    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return nil
    end

    local creatureSlots = getCreatureEquipment(data, creatureId)
    local result = {}

    for slotName, itemId in pairs(creatureSlots) do
        local config = getItemConfig(itemId)
        result[slotName] = {
            ItemId = itemId,
            Name   = config and config.Name or "Unknown",
            Type   = config and config.Type or "Unknown",
            Rarity = config and config.Rarity or "Common",
            Stats  = config and config.Stats or {},
        }
    end

    return {
        CreatureId = creatureId,
        Slots      = result,
        Bonuses    = InventorySystem.CalculateEquipmentBonuses(player, creatureId),
    }
end

--- Use a consumable item on a target creature.
function InventorySystem.UseItem(player, itemId, targetCreatureId)
    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end
    if type(itemId) ~= "string" then
        return false, "INVALID_ITEM_ID"
    end

    local data = DataStoreManager.GetPlayerData(player)
    if not data then
        return false, "NO_DATA"
    end

    -- Verify player owns the item
    local _, invEntry = findInventoryEntry(data.Inventory, itemId)
    if not invEntry then
        return false, "ITEM_NOT_OWNED"
    end

    -- Only consumable types can be "used"
    local itemConfig = getItemConfig(itemId)
    local itemType = (itemConfig and itemConfig.Type) or invEntry.Type
    if not STACKABLE_TYPES[itemType] then
        return false, "NOT_CONSUMABLE"
    end

    -- If a target creature is specified, verify ownership
    if targetCreatureId then
        local _, creature = findCreature(data.Creatures, targetCreatureId)
        if not creature then
            return false, "CREATURE_NOT_OWNED"
        end
    end

    -- Consume one unit
    local consumed = consumeItemById(player, itemId)
    if not consumed then
        return false, "CONSUME_FAILED"
    end

    -- Apply consumable effects (extensible via itemConfig or a separate table)
    -- For now, log the usage. Specific effects would be handled per item type.
    print(string.format(
        "[InventorySystem] %s used consumable '%s'%s.",
        player.Name, itemId,
        targetCreatureId and (" on creature '" .. targetCreatureId .. "'") or ""
    ))

    -- Notify client
    local updatedData = DataStoreManager.GetPlayerData(player)
    if Remotes.InventoryUpdated then
        Remotes.InventoryUpdated:FireClient(player, {
            Action           = "UseItem",
            ItemId           = itemId,
            TargetCreatureId = targetCreatureId,
            Inventory        = updatedData and updatedData.Inventory or {},
        })
    end

    return true
end

--- Return the list of items available in the shop.
function InventorySystem.GetShopItems()
    return shopItemList
end

return InventorySystem
