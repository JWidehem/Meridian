-- ============================================================
-- Meridian -- Oracle Module (100% Native)
-- Calcul du score de rentabilite par zone via Auctionator
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

-- Resolution differee
local function DB() return ns.Database end

local Oracle = {}
ns.Oracle = Oracle

local pairs      = pairs
local math_floor = math.floor
local time       = time
local date       = date

-- Noms des zones -- initialises via C_Map.GetMapInfo au INIT
-- Fallback : bytes UTF-8 echappes (e = \195\169, e-circ = \195\170)
local ZONE_NAMES = {
    [2395] = "Bois des Chants \195\169ternels",
    [2405] = "Temp\195\170te du Vide",
}
Oracle.ZONE_NAMES = ZONE_NAMES

-- ============================================================
-- Lecture prix Auctionator (dependance optionnelle)
-- ============================================================
local function GetAuctionatorPrice(itemID)
    if Auctionator and Auctionator.API and Auctionator.API.v1
       and Auctionator.API.v1.GetAuctionPriceByItemID then
        return Auctionator.API.v1.GetAuctionPriceByItemID("Meridian", itemID)
    end
    return nil
end

function Oracle:IsAuctionatorAvailable()
    return Auctionator and Auctionator.API and Auctionator.API.v1 ~= nil
end

-- ============================================================
-- Calcul du score par zone
-- Retourne tableau trie : { { mapID, zoneName, score, itemsScored } }
-- ============================================================
function Oracle:Calculate()
    local results = {}

    for mapID, zoneName in pairs(ZONE_NAMES) do
        local profile     = DB():GetZoneProfile(mapID)
        local score       = 0
        local itemsScored = 0

        for itemID, count in pairs(profile) do
            local price = GetAuctionatorPrice(itemID)
            if price and price > 0 then
                score = score + price * count
                itemsScored = itemsScored + 1
            end
        end

        results[#results + 1] = {
            mapID       = mapID,
            zoneName    = zoneName,
            score       = score,
            itemsScored = itemsScored,
        }
    end

    table.sort(results, function(a, b) return a.score > b.score end)

    local scores = {}
    for _, r in pairs(results) do
        scores[r.mapID] = r.score
    end

    local recommended = results[1] and results[1].mapID
    DB():SaveOracleResult(recommended, scores, time())

    return results
end

-- ============================================================
-- Label date des prix
-- ============================================================
function Oracle:GetPriceDateLabel()
    local oracle = DB():GetOracleResult()
    if not oracle.priceDate then
        return L.ORACLE_NO_PRICES
    end
    return string.format(L.ORACLE_PRICE_DATE, date("%d/%m", oracle.priceDate))
end

-- ============================================================
-- Formatage or : cuivres -> "Xg Ys Zc" colore
-- ============================================================
function Oracle:FormatGold(copper)
    if not copper or copper == 0 then return "0g" end
    copper = math_floor(copper)
    local g = math_floor(copper / 10000)
    local s = math_floor((copper % 10000) / 100)
    local c = copper % 100

    local parts = {}
    if g > 0 then parts[#parts + 1] = string.format("|cffffd700%dg|r", g) end
    if s > 0 then parts[#parts + 1] = string.format("|cffc0c0c0%ds|r", s) end
    if c > 0 or #parts == 0 then parts[#parts + 1] = string.format("|cffb87333%dc|r", c) end
    return table.concat(parts, " ")
end

-- ============================================================
-- Init : mise a jour des noms de zone depuis l'API WoW (locale native)
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    for mapID in pairs(ZONE_NAMES) do
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if info and info.name and info.name ~= "" then
            ZONE_NAMES[mapID] = info.name
        end
    end
end)
