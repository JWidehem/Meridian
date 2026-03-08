-- ============================================================
-- Meridian — Database Module (100% Native)
-- Stockage des nodes, ressources connues, statistiques
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

local Database = {}
ns.Database = Database

-- Cache
local pairs = pairs
local ipairs = ipairs
local time = time
local math_abs = math.abs
local format = string.format

-- Palette de couleurs — Glimmer (désaturée, pastels lisibles sur fond sombre)
local COLOR_PALETTE = {
    { 0.25, 0.78, 0.55 }, -- mint green
    { 0.88, 0.62, 0.28 }, -- warm amber
    { 0.35, 0.62, 0.88 }, -- soft blue
    { 0.85, 0.38, 0.38 }, -- muted red
    { 0.60, 0.42, 0.78 }, -- lavender
    { 0.22, 0.72, 0.68 }, -- teal
    { 0.88, 0.76, 0.28 }, -- soft gold
    { 0.82, 0.42, 0.62 }, -- dusty rose
}
Database.COLOR_PALETTE = COLOR_PALETTE

-- Dedup
local DEDUP_DISTANCE = 0.5
local DEDUP_TIME = 15

-- ============================================================
-- Init (called via callback after ADDON_LOADED)
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    Database.db = Meridian.db
end)

Meridian:RegisterCallback("RESET_ALL", function()
    Database:ResetAll()
end)

-- ============================================================
-- Enregistrement d'un node
-- ============================================================
function Database:RecordNode(data)
    if not data or not data.itemID or not data.mapID then return end
    if self:IsDuplicate(data) then return end

    if not self.db.nodes[data.mapID] then
        self.db.nodes[data.mapID] = {}
    end

    local node = {
        itemID       = data.itemID,
        itemName     = data.itemName,
        resourceType = data.resourceType,
        mapID        = data.mapID,
        zoneName     = data.zoneName,
        subZone      = data.subZone or "",
        x            = data.x,
        y            = data.y,
        timestamp    = data.timestamp or time(),
    }

    local zoneNodes = self.db.nodes[data.mapID]
    zoneNodes[#zoneNodes + 1] = node

    local isNew = self:RegisterResource(data.itemID, data.itemName, data.resourceType)

    Meridian:FireCallback("NODE_RECORDED", node, isNew)

    return node, isNew
end

-- ============================================================
-- Deduplication
-- ============================================================
function Database:IsDuplicate(data)
    local zoneNodes = self.db.nodes[data.mapID]
    if not zoneNodes then return false end

    local now = data.timestamp or time()

    for i = #zoneNodes, 1, -1 do
        local existing = zoneNodes[i]
        if (now - existing.timestamp) > DEDUP_TIME then break end

        if existing.itemID == data.itemID then
            local dx = math_abs(existing.x - data.x)
            local dy = math_abs(existing.y - data.y)
            if dx < DEDUP_DISTANCE and dy < DEDUP_DISTANCE then
                return true
            end
        end
    end

    return false
end

-- ============================================================
-- Auto-decouverte des ressources
-- ============================================================
function Database:RegisterResource(itemID, itemName, resourceType)
    if self.db.knownResources[itemID] then
        return false
    end

    local colorIndex = self.db.nextColorIndex
    self.db.nextColorIndex = (colorIndex % #COLOR_PALETTE) + 1

    self.db.knownResources[itemID] = {
        type       = resourceType,
        name       = itemName,
        firstSeen  = time(),
        colorIndex = colorIndex,
    }

    Meridian:FireCallback("RESOURCE_DISCOVERED", itemID, self.db.knownResources[itemID])
    return true
end

-- ============================================================
-- Requetes
-- ============================================================
function Database:GetNodesByZone(mapID)
    return self.db.nodes[mapID] or {}
end

function Database:GetResourceCount(itemID)
    local count = 0
    for _, zoneNodes in pairs(self.db.nodes) do
        for _, node in ipairs(zoneNodes) do
            if node.itemID == itemID then
                count = count + 1
            end
        end
    end
    return count
end

function Database:GetTotalNodeCount()
    local count = 0
    for _, zoneNodes in pairs(self.db.nodes) do
        count = count + #zoneNodes
    end
    return count
end

function Database:GetKnownResourcesByType(resourceType)
    local result = {}
    for itemID, info in pairs(self.db.knownResources) do
        if info.type == resourceType then
            result[#result + 1] = {
                itemID     = itemID,
                name       = info.name,
                count      = self:GetResourceCount(itemID),
                colorIndex = info.colorIndex,
            }
        end
    end
    return result
end

-- Returns zones sorted by total node count desc.
-- Each zone: { mapID, zoneName, totalCount, resources = [{itemID,name,count,colorIndex}] }
-- Resources within each zone are sorted by count desc.
-- Uses C_Map.GetBestMapForUnit("player") to flag the current zone.
function Database:GetZoneBreakdownByType(resourceType)
    local zones = {}

    for mapID, zoneNodes in pairs(self.db.nodes) do
        local byItem   = {}
        local total    = 0
        local zoneName = ""

        for _, node in ipairs(zoneNodes) do
            if node.resourceType == resourceType then
                local id = node.itemID
                if not byItem[id] then
                    local info = self.db.knownResources[id]
                    byItem[id] = {
                        itemID     = id,
                        name       = node.itemName,
                        count      = 0,
                        colorIndex = info and info.colorIndex or 1,
                    }
                end
                byItem[id].count = byItem[id].count + 1
                total    = total + 1
                zoneName = node.zoneName or zoneName
            end
        end

        if total > 0 then
            local resArray = {}
            for _, r in pairs(byItem) do resArray[#resArray + 1] = r end
            table.sort(resArray, function(a, b) return a.count > b.count end)

            zones[#zones + 1] = {
                mapID      = mapID,
                zoneName   = zoneName,
                totalCount = total,
                resources  = resArray,
            }
        end
    end

    table.sort(zones, function(a, b) return a.totalCount > b.totalCount end)
    return zones
end

function Database:GetKnownResources()
    return self.db.knownResources
end

function Database:GetResourceInfo(itemID)
    return self.db.knownResources[itemID]
end

function Database:GetResourceColor(itemID)
    local info = self.db.knownResources[itemID]
    if info and info.colorIndex then
        return COLOR_PALETTE[info.colorIndex] or COLOR_PALETTE[1]
    end
    return COLOR_PALETTE[1]
end

function Database:GetExportData(mapID)
    local data = {}
    local nodes

    if mapID then
        nodes = { [mapID] = self.db.nodes[mapID] or {} }
    else
        nodes = self.db.nodes
    end

    for zoneMapID, zoneNodes in pairs(nodes) do
        if #zoneNodes > 0 then
            local zoneName = zoneNodes[1].zoneName or tostring(zoneMapID)
            local byResource = {}

            for _, node in ipairs(zoneNodes) do
                local key = tostring(node.itemID)
                if not byResource[key] then
                    byResource[key] = {
                        name = node.itemName,
                        type = node.resourceType,
                        count = 0,
                    }
                end
                byResource[key].count = byResource[key].count + 1
            end

            data[tostring(zoneMapID)] = {
                zone_name = zoneName,
                map_id = zoneMapID,
                nodes = zoneNodes,
                summary = {
                    total_nodes = #zoneNodes,
                    by_resource = byResource,
                },
            }
        end
    end

    return data
end

-- ============================================================
-- Reset
-- ============================================================
function Database:ResetAll()
    wipe(self.db.nodes)
    wipe(self.db.knownResources)
    wipe(self.db.learnedSpells)
    self.db.nextColorIndex = 1
    Meridian:FireCallback("DATA_RESET")
end
