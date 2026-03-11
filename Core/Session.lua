-- ============================================================
-- Meridian — Session Module (100% Native)
-- Timer de session + tracking or temps réel
-- Détecte l'entrée en zone automatiquement après confirmation Oracle
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local Database = ns.Database
local Oracle   = ns.Oracle
local L = ns.L

local Session = {}
ns.Session = Session

local GetTime    = GetTime
local time       = time
local tonumber   = tonumber
local math_floor = math.floor

-- ============================================================
-- State
-- ============================================================
local state = {
    active        = false,      -- session en cours
    paused        = false,      -- timer pausé
    startTime     = 0,          -- GetTime() au début
    pausedElapsed = 0,          -- secondes accumulées avant la pause
    pauseStart    = 0,          -- GetTime() quand on a pausé

    mapID         = nil,        -- zone de la session
    zoneName      = "",

    goldHerb      = 0,          -- cuivres accumulés herbes
    goldOre       = 0,          -- cuivres accumulés minerais

    -- Zone attendue après confirmation Oracle (mode "en attente")
    waitingForMapID = nil,
}
Session.state = state

-- Items HERB et ORE connus dans les zones de farm — pour filtre strict
-- On accepte tous les items avec un prix Auctionator dans le zoneProfile
-- Détection dynamique via classID (HERB=7/9, ORE=7/7) — pas de liste figée

-- ============================================================
-- Durée de session en secondes (inclut les pauses comptées)
-- ============================================================
function Session:GetElapsed()
    if not state.active then return 0 end
    if state.paused then
        return state.pausedElapsed
    end
    return state.pausedElapsed + (GetTime() - state.startTime)
end

-- ============================================================
-- Démarrage
-- ============================================================
function Session:Start(mapID, zoneName)
    if state.active then self:Stop() end

    state.active        = true
    state.paused        = false
    state.startTime     = GetTime()
    state.pausedElapsed = 0
    state.pauseStart    = 0
    state.mapID         = mapID
    state.zoneName      = zoneName or (Oracle.ZONE_NAMES[mapID] or "Unknown")
    state.goldHerb      = 0
    state.goldOre       = 0
    state.waitingForMapID = nil

    Meridian:FireCallback("SESSION_STARTED", mapID, state.zoneName)
    Meridian:Msg(string.format(L.SESSION_STARTED, state.zoneName))
end

-- ============================================================
-- Pause / Reprise
-- ============================================================
function Session:TogglePause()
    if not state.active then return end

    if state.paused then
        -- Reprise
        state.startTime = GetTime()
        state.paused = false
        Meridian:Msg(L.SESSION_RESUMED)
    else
        -- Pause
        state.pausedElapsed = state.pausedElapsed + (GetTime() - state.startTime)
        state.pauseStart = GetTime()
        state.paused = true
        Meridian:Msg(L.SESSION_PAUSED)
    end

    Meridian:FireCallback("SESSION_STATE_CHANGED")
end

-- ============================================================
-- Arrêt et sauvegarde
-- ============================================================
function Session:Stop()
    if not state.active then return end

    local duration = math_floor(self:GetElapsed())

    local saved = Database:SaveSession({
        mapID    = state.mapID,
        zoneName = state.zoneName,
        duration = duration,
        goldHerb = state.goldHerb,
        goldOre  = state.goldOre,
    })

    state.active = false
    state.paused = false

    Meridian:FireCallback("SESSION_STOPPED", saved)
    Meridian:Msg(string.format(L.SESSION_STOPPED,
        state.zoneName,
        Oracle:FormatGold(saved.goldTotal),
        Oracle:FormatGold(saved.goldPerHour)
    ))
end

-- ============================================================
-- Mode "en attente" — démarre quand on arrive dans la bonne zone
-- ============================================================
function Session:WaitForZone(mapID)
    -- Si le joueur est déjà dans la zone cible, démarrer immédiatement
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if currentMapID == mapID then
        local zoneName = Oracle.ZONE_NAMES[mapID]
        self:Start(mapID, zoneName)
        return
    end
    state.waitingForMapID = mapID
    local zoneName = Oracle.ZONE_NAMES[mapID] or tostring(mapID)
    Meridian:Msg(string.format(L.SESSION_WAITING, zoneName))
end

function Session:CancelWait()
    state.waitingForMapID = nil
end

-- ============================================================
-- Parsing loot — extrait itemID et quantité depuis CHAT_MSG_LOOT
-- Format WoW : "Vous recevez un butin : |Hitem:XXXXX:...|h[Nom]|h x7."
--              "You receive loot: |Hitem:XXXXX:...|h[Name]|h x3."
-- ============================================================
local function ParseLootMessage(msg)
    local itemID = tonumber(msg:match("|Hitem:(%d+):"))
    if not itemID then return nil, 0 end

    -- Quantité : cherche "x<N>" à la fin (avant le point éventuel)
    local qty = tonumber(msg:match(" x(%d+)%.?$") or msg:match(" x(%d+)$")) or 1
    return itemID, qty
end

-- ============================================================
-- Ajout de valeur en session
-- ============================================================
local function GetAuctionatorPrice(itemID)
    if Auctionator and Auctionator.API and Auctionator.API.v1
       and Auctionator.API.v1.GetAuctionPriceByItemID then
        return Auctionator.API.v1.GetAuctionPriceByItemID("Meridian", itemID)
    end
    return nil
end

-- Détermine si un item est HERB ou ORE via classID Blizzard
-- classID 7 = Trade Goods, subClassID 9 = Herbs, 7 = Metal & Stone
local function GetResourceType(itemID)
    local info
    if C_Item and C_Item.GetItemInfoInstant then
        info = C_Item.GetItemInfoInstant(itemID)
    end

    local classID, subClassID
    if type(info) == "table" then
        classID    = info.classID
        subClassID = info.subClassID
    elseif GetItemInfoInstant then
        _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    end

    if classID == 7 then
        if subClassID == 9 then return "HERB" end
        if subClassID == 7 then return "ORE"  end
    end
    return nil
end

-- ============================================================
-- Event frame
-- ============================================================
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    Session:OnEvent(event, ...)
end)

function Session:OnEvent(event, ...)
    if event == "CHAT_MSG_LOOT" then
        self:OnLoot(...)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        self:OnZoneChanged()
    end
end

function Session:OnLoot(msg)
    if not state.active or state.paused then return end

    local itemID, qty = ParseLootMessage(msg)
    if not itemID or qty <= 0 then return end

    local resType = GetResourceType(itemID)
    if not resType then return end -- Filtre strict : HERB et ORE seulement

    local price = GetAuctionatorPrice(itemID)
    if not price then
        -- Prix inconnu : on signale mais sans comptabiliser
        Meridian:FireCallback("SESSION_UNKNOWN_PRICE", itemID, qty)
        return
    end

    local value = price * qty

    if resType == "HERB" then
        state.goldHerb = state.goldHerb + value
    else
        state.goldOre = state.goldOre + value
    end

    Meridian:FireCallback("SESSION_LOOT_ADDED", itemID, qty, resType, value)
end

function Session:OnZoneChanged()
    if not state.waitingForMapID then return end

    local currentMapID = C_Map.GetBestMapForUnit("player")
    if currentMapID == state.waitingForMapID then
        local zoneName = Oracle.ZONE_NAMES[currentMapID]
        self:Start(currentMapID, zoneName)
    end
end

-- ============================================================
-- Accesseurs pour l'UI
-- ============================================================
function Session:IsActive()    return state.active  end
function Session:IsPaused()    return state.paused  end
function Session:IsWaiting()   return state.waitingForMapID ~= nil end
function Session:GetWaitingZone() return state.waitingForMapID end

function Session:GetGoldTotal()
    return state.goldHerb + state.goldOre
end

-- Or/heure glissant (cuivres)
function Session:GetGoldPerHour()
    local elapsed = self:GetElapsed()
    if elapsed < 10 then return 0 end
    return math_floor(self:GetGoldTotal() / elapsed * 3600)
end

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    eventFrame:RegisterEvent("CHAT_MSG_LOOT")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end)
