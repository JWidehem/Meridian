-- ============================================================
-- Meridian â€” Oracle Module (100% Native)
-- Calcul du score de rentabilitÃ© par zone via Auctionator
-- Zones retenues : BCE (2395) et TdV (2405)
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

-- Noms des zones affichÃ©s (court)
local ZONE_NAMES = {
    [2395] = "Bois des Chants Ã©ternels",
    [2405] = "TempÃªte du Vide",
}
Oracle.ZONE_NAMES = ZONE_NAMES

-- ============================================================
-- Lecture prix Auctionator (dÃ©pendance optionnelle)
-- ============================================================

-- Retourne le prix en cuivres, ou nil si inconnu / Auctionator absent
local function GetAuctionatorPrice(itemID)
    if Auctionator and Auctionator.API and Auctionator.API.v1
       and Auctionator.API.v1.GetAuctionPriceByItemID then
        return Auctionator.API.v1.GetAuctionPriceByItemID("Meridian", itemID)
    end
    return nil
end

-- Retourne true si Auctionator est disponible
function Oracle:IsAuctionatorAvailable()
    return Auctionator and Auctionator.API and Auctionator.API.v1 ~= nil
end

-- ============================================================
-- Calcul du score par zone
-- ============================================================

-- Retourne un tableau de rÃ©sultats triÃ©s, du plus rentable au moins rentable :
-- { { mapID, zoneName, score, missingPrices, itemsScored } }
-- score est en cuivres
function Oracle:Calculate()
    local results = {}

    for mapID, zoneName in pairs(ZONE_NAMES) do
        local profile     = DB():GetZoneProfile(mapID)
        local score       = 0
        local itemsScored = 0
        local missing     = {}

        for itemID, count in pairs(profile) do
            local price = GetAuctionatorPrice(itemID)
            if price and price > 0 then
                score = score + price * count
                itemsScored = itemsScored + 1
            else
                missing[#missing + 1] = itemID
            end
        end

        results[#results + 1] = {
            mapID         = mapID,
            zoneName      = zoneName,
            score         = score,
            itemsScored   = itemsScored,
            missingPrices = missing,
        }
    end

    -- Trier du plus rentable au moins rentable
    table.sort(results, function(a, b) return a.score > b.score end)

    -- Sauvegarder et retourner
    local scores = {}
    for _, r in pairs(results) do
        scores[r.mapID] = r.score
    end

    local recommended = results[1] and results[1].mapID
    DB():SaveOracleResult(recommended, scores, time())

    return results
end

-- ============================================================
-- Formatage de l'Ã¢ge des prix pour l'affichage
-- ============================================================

-- Retourne une chaÃ®ne lisible : "Prix du 11/03" ou "Prix non disponibles"
function Oracle:GetPriceDateLabel()
    local oracle = DB():GetOracleResult()
    if not oracle.priceDate then
        return L.ORACLE_NO_PRICES
    end
    return string.format(L.ORACLE_PRICE_DATE, date("%d/%m", oracle.priceDate))
end

-- ============================================================
-- Formatage or pour affichage (cuivres â†’ "X 987g 65a 43c")
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
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    -- Rien Ã  initialiser â€” Oracle calcule Ã  la demande
end)
