-- ============================================================
-- Meridian -- Session Module (100% Native)
-- Tracking zone active + loot HERB/ORE dans les zones de farm uniquement
-- Pas de timer, pas de g/heure -- cumul journalier via Database
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

local Session = {}
ns.Session = Session

local tonumber = tonumber

-- ============================================================
-- State
-- ============================================================
local state = {
    active              = false,   -- dans une zone de farm trackee
    mapID               = nil,     -- zone active
    zoneName            = "",
    waitingForMapID     = nil,     -- zone attendue apres choix Oracle
}
Session.state = state

-- Accesseur lazy pour eviter les problemes d'ordre de chargement
local function DB()  return ns.Database end
local function ORA() return ns.Oracle   end

-- ============================================================
-- Zones autorisees (filtrage loot)
-- ============================================================
local FARM_MAP_IDS = { [2395] = true, [2405] = true }

-- ============================================================
-- Demarrage
-- ============================================================
function Session:Start(mapID, zoneName)
    state.active            = true
    state.mapID             = mapID
    state.zoneName          = zoneName or (ORA().ZONE_NAMES[mapID] or "?")
    state.waitingForMapID   = nil

    Meridian:FireCallback("SESSION_STARTED", mapID, state.zoneName)
    Meridian:Msg(string.format(L.SESSION_STARTED, state.zoneName))
end

-- ============================================================
-- Arret
-- ============================================================
function Session:Stop()
    if not state.active then return end
    state.active  = false
    state.mapID   = nil
    state.zoneName = ""
    Meridian:FireCallback("SESSION_STOPPED")
end

-- ============================================================
-- Mode "en attente" -- demarre quand on arrive dans la bonne zone
-- ============================================================
function Session:WaitForZone(mapID)
    -- Si le joueur est deja dans la zone, demarrer immediatement
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if currentMapID == mapID then
        self:Start(mapID, ORA().ZONE_NAMES[mapID])
        return
    end
    state.waitingForMapID = mapID
    local zoneName = ORA().ZONE_NAMES[mapID] or tostring(mapID)
    Meridian:Msg(string.format(L.SESSION_WAITING, zoneName))
    Meridian:FireCallback("SESSION_WAITING_CHANGED")
end

function Session:CancelWait()
    state.waitingForMapID = nil
    Meridian:FireCallback("SESSION_WAITING_CHANGED")
end

-- ============================================================
-- Parsing loot
-- Format WoW : "|Hitem:XXXXX:...|h[Nom]|h x7."
-- ============================================================
local function ParseLootMessage(msg)
    local itemID = tonumber(msg:match("|Hitem:(%d+):"))
    if not itemID then return nil, 0 end
    local qty = tonumber(msg:match(" x(%d+)%.?$") or msg:match(" x(%d+)$")) or 1
    return itemID, qty
end

-- ============================================================
-- Identification HERB / ORE via classID Blizzard
-- classID 7 = Trade Goods, subClassID 9 = Herbs, 7 = Metal & Stone
-- ============================================================
local function GetResourceType(itemID)
    local classID, subClassID

    if C_Item and C_Item.GetItemInfoInstant then
        local info = C_Item.GetItemInfoInstant(itemID)
        if type(info) == "table" then
            classID    = info.classID
            subClassID = info.subClassID
        end
    end

    if not classID and GetItemInfoInstant then
        _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    end

    if classID == 7 then
        if subClassID == 9 then return "HERB" end
        if subClassID == 7 then return "ORE"  end
    end
    return nil
end

-- ============================================================
-- Prix Auctionator
-- ============================================================
local function GetAuctionatorPrice(itemID)
    if Auctionator and Auctionator.API and Auctionator.API.v1
       and Auctionator.API.v1.GetAuctionPriceByItemID then
        return Auctionator.API.v1.GetAuctionPriceByItemID("Meridian", itemID)
    end
    return nil
end

-- ============================================================
-- Event handlers
-- ============================================================
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        Session:OnLoot(...)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        Session:OnZoneChanged()
    end
end)

function Session:OnLoot(msg)
    if not state.active then return end

    -- Filtrage zone : on ne compte que BCE et TdV
    if not FARM_MAP_IDS[state.mapID] then return end

    local itemID, qty = ParseLootMessage(msg)
    if not itemID or qty <= 0 then return end

    local resType = GetResourceType(itemID)
    if not resType then return end

    local price = GetAuctionatorPrice(itemID)
    if not price or price <= 0 then return end

    local value = price * qty
    DB():AddLoot(resType, value)

    Meridian:FireCallback("SESSION_LOOT_ADDED", resType, value)
end

function Session:OnZoneChanged()
    local currentMapID = C_Map.GetBestMapForUnit("player")

    -- Mode attente : zone cible atteinte
    if state.waitingForMapID and currentMapID == state.waitingForMapID then
        self:Start(currentMapID, ORA().ZONE_NAMES[currentMapID])
        return
    end

    -- Session active : on a quitte la zone de farm
    if state.active and not FARM_MAP_IDS[currentMapID] then
        self:Stop()
    end
end

-- ============================================================
-- Accesseurs
-- ============================================================
function Session:IsActive()       return state.active end
function Session:IsWaiting()      return state.waitingForMapID ~= nil end
function Session:GetWaitingZone() return state.waitingForMapID end

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    eventFrame:RegisterEvent("CHAT_MSG_LOOT")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end)
