-- ============================================================
-- Meridian -- Database Module (100% Native)
-- ZoneProfile (densite figee Phase 1), cumul journalier, cache oracle
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon

local Database = {}
ns.Database = Database

local pairs      = pairs
local time       = time
local math_floor = math.floor

-- Zones de farming autorisees (filtrage loot strict)
Database.FARM_ZONES = {
    [2395] = "Bois des Chants eternels",
    [2405] = "Tempete du Vide",
}

-- ============================================================
-- Defaults SavedVariables
-- ============================================================
local defaults = {
    minimap = {
        hide  = false,
        angle = 220,
    },
    -- Profil de densite par zone -- noeuds recoltes Phase 1, figes
    -- [mapID] = { [itemID] = count, ... }
    zoneProfile = {
        [2395] = {
            [236761]=75,  -- Tranquillette T1
            [236767]=4,   -- Tranquillette T2
            [236770]=25,  -- Sanguironce T1
            [236774]=11,  -- Azeracine T1
            [236775]=2,   -- Azeracine T2
            [236776]=13,  -- Feuille-d'argent T1
            [236777]=3,   -- Feuille-d'argent T2
            [236778]=22,  -- Lys de mana T1
            [236780]=1,   -- Lotus nocturne
            [236949]=4,   -- Particule de Lumiere
            [237359]=70,  -- Cuivre eclatant T1
            [237361]=4,   -- Cuivre eclatant T2
            [237362]=14,  -- Etain ombreux T1
            [237364]=42,  -- Argent brillant T1
            [237365]=1,   -- Argent brillant T2
            [237366]=1,   -- Thorium eblouissant
        },
        [2405] = {
            [236761]=86,  -- Tranquillette T1
            [236767]=6,   -- Tranquillette T2
            [236770]=27,  -- Sanguironce T1
            [236771]=3,   -- Sanguironce T2
            [236774]=8,   -- Azeracine T1
            [236775]=1,   -- Azeracine T2
            [236776]=12,  -- Feuille-d'argent T1
            [236777]=2,   -- Feuille-d'argent T2
            [236778]=8,   -- Lys de mana T1
            [236779]=1,   -- Lys de mana T2
            [236780]=2,   -- Lotus nocturne
            [236952]=4,   -- Particule de Vide pur
            [237359]=37,  -- Cuivre eclatant T1
            [237361]=12,  -- Cuivre eclatant T2
            [237362]=26,  -- Etain ombreux T1
            [237363]=7,   -- Etain ombreux T2
            [237364]=17,  -- Argent brillant T1
            [237365]=4,   -- Argent brillant T2
        },
    },
    -- Cache du dernier calcul Oracle
    oracle = {
        recommendedZone = nil,
        scores          = {},
        priceDate       = nil,
    },
    -- Cumul journalier
    today = {
        date             = "",   -- "YYYY-MM-DD" du dernier farm
        goldHerb         = 0,    -- cuivres herbes du jour (brut)
        goldOre          = 0,    -- cuivres minerais du jour (brut)
        resetOffsetHerb  = 0,    -- offset reset visuel herbes
        resetOffsetOre   = 0,    -- offset reset visuel minerais
    },
}
Database.defaults = defaults

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    Database.db = Meridian.db
    Database:CheckDayRollover()
end)

Meridian:RegisterCallback("RESET_ALL", function()
    Database:ResetVisual()
    Database:ResetOracle()
end)

-- ============================================================
-- ZoneProfile -- lecture seule
-- ============================================================
function Database:GetZoneProfile(mapID)
    return self.db.zoneProfile[mapID] or {}
end

-- ============================================================
-- Oracle cache
-- ============================================================
function Database:SaveOracleResult(recommendedZone, scores, timestamp)
    self.db.oracle.recommendedZone = recommendedZone
    self.db.oracle.scores          = scores
    self.db.oracle.priceDate       = timestamp or time()
end

function Database:GetOracleResult()
    return self.db.oracle
end

function Database:ResetOracle()
    self.db.oracle.recommendedZone = nil
    self.db.oracle.scores          = {}
    self.db.oracle.priceDate       = nil
end

-- ============================================================
-- Cumul journalier
-- ============================================================

-- Verifie si le jour a change et remet a zero si necessaire
function Database:CheckDayRollover()
    local t = self.db.today
    local currentDate = date("%Y-%m-%d")
    if t.date ~= currentDate then
        t.date            = currentDate
        t.goldHerb        = 0
        t.goldOre         = 0
        t.resetOffsetHerb = 0
        t.resetOffsetOre  = 0
    end
end

-- Ajoute une valeur au cumul du jour
function Database:AddLoot(resType, value)
    self:CheckDayRollover()
    local t = self.db.today
    if resType == "HERB" then
        t.goldHerb = t.goldHerb + value
    else
        t.goldOre = t.goldOre + value
    end
end

-- Retourne les valeurs affichees (brut - offset reset visuel)
-- Retourne deux valeurs : goldHerb_display, goldOre_display
function Database:GetDisplayTotals()
    local t = self.db.today
    return
        math_floor(math.max(0, t.goldHerb - t.resetOffsetHerb)),
        math_floor(math.max(0, t.goldOre  - t.resetOffsetOre))
end

-- Reset visuel : l'affichage repart a zero, le brut en DB est conserve
function Database:ResetVisual()
    local t = self.db.today
    t.resetOffsetHerb = t.goldHerb
    t.resetOffsetOre  = t.goldOre
end
