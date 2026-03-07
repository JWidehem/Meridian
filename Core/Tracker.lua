-- ============================================================
-- Meridian — Tracker Module (100% Native)
-- Detection de recolte via approche "sandwich" :
--   UNIT_SPELLCAST_SUCCEEDED -> CHAT_MSG_LOOT
-- Auto-apprentissage des sorts de recolte inconnus
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local Database = ns.Database
local L = ns.L

local Tracker = {}
ns.Tracker = Tracker

-- Cache
local GetTime = GetTime
local time = time
local tonumber = tonumber
local format = string.format
local math_floor = math.floor

-- ============================================================
-- Sorts de recolte connus (seed list)
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

local LEARN_WINDOW = 5
local PENDING_TIMEOUT = 8

-- ============================================================
-- State
-- ============================================================
local pendingGather = nil
local lastSpellCast = nil

-- ============================================================
-- Coordonnees du joueur
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
-- Classification item (herb/ore) via classID
-- ============================================================
function Tracker:ClassifyItem(itemID)
    local classID, subClassID

    if C_Item and C_Item.GetItemInfoInstant then
        local result = C_Item.GetItemInfoInstant(itemID)
        if type(result) == "table" then
            classID = result.classID
            subClassID = result.subClassID
        elseif result then
            _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
        end
    end

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
-- Extraction item depuis message de loot
-- ============================================================
function Tracker:ExtractItemFromLoot(msg)
    local itemID = tonumber(msg:match("|Hitem:(%d+):"))
    if not itemID then return nil, nil end

    local itemName = msg:match("%[(.-)%]")
    return itemID, itemName
end

-- ============================================================
-- Notification de recolte
-- ============================================================
function Tracker:NotifyGather(node, isNew)
    if not Meridian.db.tracking.chatMessages then return end

    local colorHex = node.resourceType == "HERB" and "2ecc71" or "f39c12"
    local total = Database:GetResourceCount(node.itemID)

    if isNew then
        Meridian:Msg(format(
            "|cff00ff00+|r " .. L.NEW_RESOURCE,
            node.itemName, node.itemID
        ))
    end

    Meridian:Msg(format(
        "|cff%s* " .. L.NODE_RECORDED .. "|r",
        colorHex, node.itemName, node.x, node.y, total
    ))
end

-- ============================================================
-- Event frame
-- ============================================================
local eventFrame = CreateFrame("Frame")

Meridian:RegisterCallback("INIT", function()
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("CHAT_MSG_LOOT")
end)

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        Tracker:OnSpellCastSucceeded(...)
    elseif event == "CHAT_MSG_LOOT" then
        Tracker:OnChatMsgLoot(...)
    end
end)

-- ============================================================
-- UNIT_SPELLCAST_SUCCEEDED
-- ============================================================
function Tracker:OnSpellCastSucceeded(unit, castGUID, spellID)
    if unit ~= "player" then return end

    local coords = self:GetPlayerCoords()
    if not coords then return end

    lastSpellCast = {
        spellID = spellID,
        time    = GetTime(),
        coords  = coords,
    }

    local learnedSpells = Meridian.db.learnedSpells
    local resourceType = GATHER_SPELLS[spellID] or learnedSpells[spellID]

    if resourceType then
        local castTime = GetTime()
        pendingGather = {
            resourceType = resourceType,
            coords       = coords,
            time         = castTime,
        }

        C_Timer.After(PENDING_TIMEOUT, function()
            if pendingGather and pendingGather.time == castTime then
                pendingGather = nil
            end
        end)
    end
end

-- ============================================================
-- CHAT_MSG_LOOT
-- ============================================================
function Tracker:OnChatMsgLoot(msg, ...)
    local settings = Meridian.db.tracking
    if not settings or not Meridian.db.enabled then return end

    local itemID, itemName = self:ExtractItemFromLoot(msg)
    if not itemID then return end

    if pendingGather then
        local resourceType = pendingGather.resourceType

        if (resourceType == "HERB" and not settings.trackHerbs)
        or (resourceType == "ORE" and not settings.trackOres) then
            pendingGather = nil
            return
        end

        local node, isNew = Database:RecordNode({
            itemID       = itemID,
            itemName     = itemName,
            resourceType = resourceType,
            mapID        = pendingGather.coords.mapID,
            zoneName     = pendingGather.coords.zoneName,
            subZone      = pendingGather.coords.subZone,
            x            = pendingGather.coords.x,
            y            = pendingGather.coords.y,
            timestamp    = time(),
        })

        pendingGather = nil

        if node then
            self:NotifyGather(node, isNew)
        end

    elseif lastSpellCast and (GetTime() - lastSpellCast.time) < LEARN_WINDOW then
        local resourceType = self:ClassifyItem(itemID)
        if not resourceType then return end

        if (resourceType == "HERB" and not settings.trackHerbs)
        or (resourceType == "ORE" and not settings.trackOres) then
            return
        end

        local spellID = lastSpellCast.spellID
        Meridian.db.learnedSpells[spellID] = resourceType
        Meridian:Msg(format(L.SPELL_LEARNED, spellID))

        local node, isNew = Database:RecordNode({
            itemID       = itemID,
            itemName     = itemName,
            resourceType = resourceType,
            mapID        = lastSpellCast.coords.mapID,
            zoneName     = lastSpellCast.coords.zoneName,
            subZone      = lastSpellCast.coords.subZone,
            x            = lastSpellCast.coords.x,
            y            = lastSpellCast.coords.y,
            timestamp    = time(),
        })

        if node then
            self:NotifyGather(node, isNew)
        end
    end
end
