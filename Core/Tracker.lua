-- ============================================================
-- Meridian — Tracker Module
-- Détection de récolte via approche "sandwich" :
--   UNIT_SPELLCAST_SUCCEEDED → CHAT_MSG_LOOT
-- Auto-apprentissage des sorts de récolte inconnus
-- ============================================================
local addonName, ns = ...
local Meridian = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Tracker = Meridian:NewModule("Tracker", "AceEvent-3.0")
local L = ns.L

-- Cache de fonctions globales
local GetTime = GetTime
local time = time
local tonumber = tonumber
local format = string.format
local math_floor = math.floor

-- ============================================================
-- Sorts de récolte connus (seed list — IDs stables)
-- Le système d'apprentissage complète cette liste dynamiquement
-- ============================================================
local GATHER_SPELLS = {
    -- Herb Gathering
    [2366]   = "HERB",
    [2368]   = "HERB",
    [3570]   = "HERB",
    [11993]  = "HERB",
    [28695]  = "HERB",
    [50300]  = "HERB",
    [74519]  = "HERB",
    [110413] = "HERB",
    [158745] = "HERB",
    [195114] = "HERB",
    [265819] = "HERB",
    [309780] = "HERB",
    [366252] = "HERB",
    [423397] = "HERB",
    -- Mining
    [2575]   = "ORE",
    [2576]   = "ORE",
    [3564]   = "ORE",
    [10248]  = "ORE",
    [29354]  = "ORE",
    [50310]  = "ORE",
    [74517]  = "ORE",
    [102161] = "ORE",
    [158754] = "ORE",
    [195122] = "ORE",
    [265853] = "ORE",
    [309786] = "ORE",
    [366260] = "ORE",
    [423399] = "ORE",
}

-- Fenêtre temporelle pour l'apprentissage automatique (secondes)
local LEARN_WINDOW = 5
-- Timeout pour annuler un pending gather (secondes)
local PENDING_TIMEOUT = 8

-- ============================================================
-- Lifecycle
-- ============================================================
function Tracker:OnEnable()
    self.pendingGather = nil
    self.lastSpellCast = nil

    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("CHAT_MSG_LOOT")
end

function Tracker:OnDisable()
    self:UnregisterAllEvents()
    self.pendingGather = nil
    self.lastSpellCast = nil
end

-- ============================================================
-- Coordonnées du joueur
-- ============================================================
function Tracker:GetPlayerCoords()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end

    local mapInfo = C_Map.GetMapInfo(mapID)

    return {
        mapID    = mapID,
        x        = math_floor(pos.x * 10000 + 0.5) / 100,
        y        = math_floor(pos.y * 10000 + 0.5) / 100,
        zoneName = mapInfo and mapInfo.name or "Unknown",
        subZone  = GetSubZoneText() or "",
    }
end

-- ============================================================
-- Classification d'un item (herb/ore) via classID/subClassID
-- ============================================================
function Tracker:ClassifyItem(itemID)
    local classID, subClassID

    -- API moderne (C_Item namespace)
    if C_Item and C_Item.GetItemInfoInstant then
        local result = C_Item.GetItemInfoInstant(itemID)
        if type(result) == "table" then
            classID = result.classID
            subClassID = result.subClassID
        elseif result then
            -- Si ça retourne des valeurs multiples (legacy behavior)
            _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
        end
    end

    -- Fallback API globale
    if not classID and GetItemInfoInstant then
        _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    end

    if classID == 7 then -- Trade Goods
        if subClassID == 9 then return "HERB" end
        if subClassID == 7 then return "ORE" end
    end

    return nil
end

-- ============================================================
-- Extraction d'un item depuis un message de loot
-- ============================================================
function Tracker:ExtractItemFromLoot(msg)
    -- Format WoW : "... |cffQUALITY|Hitem:ITEMID:...|h[Nom]|h|r ..."
    local itemID = tonumber(msg:match("|Hitem:(%d+):"))
    if not itemID then return nil, nil end

    local itemName = msg:match("%[(.-)%]")
    return itemID, itemName
end

-- ============================================================
-- Event : Sort lancé avec succès
-- ============================================================
function Tracker:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if unit ~= "player" then return end

    local coords = self:GetPlayerCoords()
    if not coords then return end

    -- Toujours mémoriser le dernier sort (pour l'apprentissage)
    self.lastSpellCast = {
        spellID = spellID,
        time    = GetTime(),
        coords  = coords,
    }

    -- Vérifier si c'est un sort de récolte connu
    local learnedSpells = Meridian.db.global.learnedSpells
    local resourceType = GATHER_SPELLS[spellID] or learnedSpells[spellID]

    if resourceType then
        -- Sort de récolte reconnu → préparer l'enregistrement
        self.pendingGather = {
            resourceType = resourceType,
            coords       = coords,
            time         = GetTime(),
        }

        -- Auto-annuler si pas de loot dans PENDING_TIMEOUT secondes
        C_Timer.After(PENDING_TIMEOUT, function()
            if self.pendingGather and self.pendingGather.time == self.lastSpellCast.time then
                self.pendingGather = nil
            end
        end)
    end
end

-- ============================================================
-- Event : Loot reçu
-- ============================================================
function Tracker:CHAT_MSG_LOOT(event, msg, ...)
    local settings = Meridian.db.profile.tracking
    if not settings or not Meridian.db.profile.enabled then return end

    local itemID, itemName = self:ExtractItemFromLoot(msg)
    if not itemID then return end

    local Database = Meridian:GetModule("Database")

    if self.pendingGather then
        -- Sort de récolte reconnu → enregistrer directement
        local resourceType = self.pendingGather.resourceType

        -- Vérifier que le tracking est activé pour ce type
        if (resourceType == "HERB" and not settings.trackHerbs)
        or (resourceType == "ORE" and not settings.trackOres) then
            self.pendingGather = nil
            return
        end

        local node, isNew = Database:RecordNode({
            itemID       = itemID,
            itemName     = itemName,
            resourceType = resourceType,
            mapID        = self.pendingGather.coords.mapID,
            zoneName     = self.pendingGather.coords.zoneName,
            subZone      = self.pendingGather.coords.subZone,
            x            = self.pendingGather.coords.x,
            y            = self.pendingGather.coords.y,
            timestamp    = time(),
        })

        self.pendingGather = nil

        if node then
            self:NotifyGather(node, isNew)
        end

    elseif self.lastSpellCast and (GetTime() - self.lastSpellCast.time) < LEARN_WINDOW then
        -- Sort inconnu mais loot d'un herb/ore → apprentissage
        local resourceType = self:ClassifyItem(itemID)
        if not resourceType then return end

        -- Vérifier le tracking
        if (resourceType == "HERB" and not settings.trackHerbs)
        or (resourceType == "ORE" and not settings.trackOres) then
            return
        end

        -- Apprendre le sort
        local spellID = self.lastSpellCast.spellID
        Meridian.db.global.learnedSpells[spellID] = resourceType
        Meridian:Msg(format(L["SPELL_LEARNED"], spellID))

        -- Enregistrer le node
        local node, isNew = Database:RecordNode({
            itemID       = itemID,
            itemName     = itemName,
            resourceType = resourceType,
            mapID        = self.lastSpellCast.coords.mapID,
            zoneName     = self.lastSpellCast.coords.zoneName,
            subZone      = self.lastSpellCast.coords.subZone,
            x            = self.lastSpellCast.coords.x,
            y            = self.lastSpellCast.coords.y,
            timestamp    = time(),
        })

        if node then
            self:NotifyGather(node, isNew)
        end
    end
end

-- ============================================================
-- Notification de récolte (chat + feedback)
-- ============================================================
function Tracker:NotifyGather(node, isNew)
    if not Meridian.db.profile.tracking.chatMessages then return end

    local colorHex = node.resourceType == "HERB" and "2ecc71" or "f39c12"
    local total = Meridian:GetModule("Database"):GetResourceCount(node.itemID)

    if isNew then
        Meridian:Msg(format(
            "|cff00ff00\226\156\166|r " .. L["NEW_RESOURCE"],
            node.itemName, node.itemID
        ))
    end

    Meridian:Msg(format(
        "|cff%s\226\128\162 " .. L["NODE_RECORDED"] .. "|r",
        colorHex, node.itemName, node.x, node.y, total
    ))
end
