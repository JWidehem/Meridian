-- ============================================================
-- Meridian — Database Module
-- Stockage des nodes, ressources connues, statistiques
-- ============================================================
local addonName, ns = ...
local Meridian = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Database = Meridian:NewModule("Database", "AceEvent-3.0")
local L = ns.L

-- Cache
local pairs = pairs
local ipairs = ipairs
local time = time
local math_abs = math.abs
local format = string.format

-- Palette de couleurs pour les ressources (cycling)
local COLOR_PALETTE = {
    { 0.18, 0.80, 0.44 }, -- vert émeraude
    { 0.95, 0.77, 0.06 }, -- jaune soleil
    { 0.20, 0.60, 0.86 }, -- bleu
    { 0.91, 0.30, 0.24 }, -- rouge
    { 0.56, 0.27, 0.68 }, -- violet
    { 0.10, 0.74, 0.61 }, -- turquoise
    { 0.90, 0.49, 0.13 }, -- orange
    { 0.83, 0.33, 0.55 }, -- rose
}
Database.COLOR_PALETTE = COLOR_PALETTE

-- Déduplication : distance min entre deux nodes du même itemID (en coords carte)
local DEDUP_DISTANCE = 0.5
local DEDUP_TIME = 15 -- secondes

-- ============================================================
-- Lifecycle
-- ============================================================
function Database:OnEnable()
    self.db = Meridian.db.global
end

-- ============================================================
-- Enregistrement d'un node
-- ============================================================
function Database:RecordNode(data)
    -- data = { itemID, itemName, resourceType, mapID, zoneName, subZone, x, y, timestamp }
    if not data or not data.itemID or not data.mapID then return end

    -- Déduplication : même item, même zone, très proche, dans les N dernières secondes
    if self:IsDuplicate(data) then return end

    -- Initialiser la zone si nécessaire
    if not self.db.nodes[data.mapID] then
        self.db.nodes[data.mapID] = {}
    end

    -- Créer l'entrée node
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

    -- Auto-découvrir la ressource si nouvelle
    local isNew = self:RegisterResource(data.itemID, data.itemName, data.resourceType)

    -- Notifier les autres modules
    Meridian:SendMessage("MERIDIAN_NODE_RECORDED", node, isNew)

    return node, isNew
end

-- ============================================================
-- Déduplication
-- ============================================================
function Database:IsDuplicate(data)
    local zoneNodes = self.db.nodes[data.mapID]
    if not zoneNodes then return false end

    local now = data.timestamp or time()

    -- Parcourir les nodes récents (en partant de la fin pour performance)
    for i = #zoneNodes, 1, -1 do
        local existing = zoneNodes[i]
        -- Arrêter si on dépasse la fenêtre de temps
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
-- Auto-découverte des ressources
-- ============================================================
function Database:RegisterResource(itemID, itemName, resourceType)
    if self.db.knownResources[itemID] then
        return false -- déjà connu
    end

    local colorIndex = self.db.nextColorIndex
    self.db.nextColorIndex = (colorIndex % #COLOR_PALETTE) + 1

    self.db.knownResources[itemID] = {
        type       = resourceType,
        name       = itemName,
        firstSeen  = time(),
        colorIndex = colorIndex,
    }

    Meridian:SendMessage("MERIDIAN_RESOURCE_DISCOVERED", itemID, self.db.knownResources[itemID])
    return true
end

-- ============================================================
-- Requêtes
-- ============================================================

-- Tous les nodes d'une zone
function Database:GetNodesByZone(mapID)
    return self.db.nodes[mapID] or {}
end

-- Tous les nodes d'une ressource spécifique
function Database:GetNodesByResource(itemID)
    local result = {}
    for _, zoneNodes in pairs(self.db.nodes) do
        for _, node in ipairs(zoneNodes) do
            if node.itemID == itemID then
                result[#result + 1] = node
            end
        end
    end
    return result
end

-- Nombre de nodes pour un itemID (toutes zones)
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

-- Nombre total de nodes (toutes zones, toutes ressources)
function Database:GetTotalNodeCount()
    local count = 0
    for _, zoneNodes in pairs(self.db.nodes) do
        count = count + #zoneNodes
    end
    return count
end

-- Ressources connues, filtrées par type
function Database:GetKnownResourcesByType(resourceType)
    local result = {}
    for itemID, info in pairs(self.db.knownResources) do
        if info.type == resourceType then
            result[itemID] = info
        end
    end
    return result
end

-- Toutes les ressources connues
function Database:GetKnownResources()
    return self.db.knownResources
end

-- Info d'une ressource
function Database:GetResourceInfo(itemID)
    return self.db.knownResources[itemID]
end

-- Couleur d'une ressource
function Database:GetResourceColor(itemID)
    local info = self.db.knownResources[itemID]
    if info and info.colorIndex then
        return COLOR_PALETTE[info.colorIndex] or COLOR_PALETTE[1]
    end
    return COLOR_PALETTE[1]
end

-- Toutes les zones qui ont des données
function Database:GetRecordedZones()
    local zones = {}
    for mapID, zoneNodes in pairs(self.db.nodes) do
        if #zoneNodes > 0 then
            zones[mapID] = zoneNodes[1].zoneName or tostring(mapID)
        end
    end
    return zones
end

-- Stats résumées pour l'export
function Database:GetExportData(mapID)
    local data = {}
    local nodes

    if mapID then
        -- Export d'une seule zone
        nodes = { [mapID] = self.db.nodes[mapID] or {} }
    else
        -- Export de toutes les zones
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
    Meridian:SendMessage("MERIDIAN_DATA_RESET")
end
