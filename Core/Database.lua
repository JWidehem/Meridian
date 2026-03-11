-- ============================================================
-- Meridian â€” Database Module (100% Native)
-- ZoneProfile (densitÃ© figÃ©e Phase 1), sessions historique, cache oracle
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon

local Database = {}
ns.Database = Database

local pairs = pairs
local ipairs = ipairs
local time   = time
local format = string.format
local math_floor = math.floor

-- Palette de couleurs Glimmer (dÃ©saturÃ©e, pastels lisibles sur fond sombre)
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

-- Zones de farming retenues
Database.FARM_ZONES = {
    [2395] = "Bois des Chants Ã©ternels",
    [2405] = "TempÃªte du Vide",
}

-- Nombre max de sessions conservÃ©es
local MAX_SESSIONS = 30

-- ============================================================
-- Defaults SavedVariables
-- ============================================================
local defaults = {
    minimap = {
        hide  = false,
        angle = 220,
    },
    -- Profil de densitÃ© par zone â€” nÅ“uds rÃ©coltÃ©s Phase 1, figÃ©s
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
            [236949]=4,   -- Particule de LumiÃ¨re
            [237359]=70,  -- Cuivre Ã©clatant T1
            [237361]=4,   -- Cuivre Ã©clatant T2
            [237362]=14,  -- Ã‰tain ombreux T1
            [237364]=42,  -- Argent brillant T1
            [237365]=1,   -- Argent brillant T2
            [237366]=1,   -- Thorium Ã©blouissant
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
            [237359]=37,  -- Cuivre Ã©clatant T1
            [237361]=12,  -- Cuivre Ã©clatant T2
            [237362]=26,  -- Ã‰tain ombreux T1
            [237363]=7,   -- Ã‰tain ombreux T2
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
    -- Historique des sessions terminÃ©es
    sessions = {},
}
Database.defaults = defaults

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    Database.db = Meridian.db
end)

Meridian:RegisterCallback("RESET_ALL", function()
    Database:ResetSessions()
    Database:ResetOracle()
end)

-- ============================================================
-- ZoneProfile â€” lecture seule
-- ============================================================

-- Retourne { [itemID] = count } pour une zone, ou {} si inconnue
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
-- Sessions
-- ============================================================

-- Sauvegarde une session terminÃ©e
-- data = { mapID, zoneName, duration (sec), goldHerb, goldOre }
function Database:SaveSession(data)
    local sessions = self.db.sessions
    local goldTotal = (data.goldHerb or 0) + (data.goldOre or 0)
    local goldPerHour = 0
    if data.duration and data.duration > 0 then
        goldPerHour = math_floor(goldTotal / data.duration * 3600)
    end

    local entry = {
        zoneName    = data.zoneName or "",
        mapID       = data.mapID,
        date        = date("%Y-%m-%d"),
        duration    = data.duration or 0,
        goldHerb    = data.goldHerb or 0,
        goldOre     = data.goldOre or 0,
        goldTotal   = goldTotal,
        goldPerHour = goldPerHour,
    }

    sessions[#sessions + 1] = entry

    -- Garde seulement les MAX_SESSIONS derniÃ¨res
    while #sessions > MAX_SESSIONS do
        table.remove(sessions, 1)
    end

    return entry
end

-- Retourne les N derniÃ¨res sessions (du plus rÃ©cent au plus ancien)
function Database:GetRecentSessions(n)
    local sessions = self.db.sessions
    local result = {}
    local start = math.max(1, #sessions - (n or 5) + 1)
    for i = #sessions, start, -1 do
        result[#result + 1] = sessions[i]
    end
    return result
end

-- Moyenne or/heure sur les N derniÃ¨res sessions
function Database:GetAverageGoldPerHour(n)
    local recent = self:GetRecentSessions(n or 5)
    if #recent == 0 then return 0 end
    local total = 0
    for _, s in ipairs(recent) do
        total = total + s.goldPerHour
    end
    return math_floor(total / #recent)
end

function Database:ResetSessions()
    self.db.sessions = {}
end

function Database:GetSessionCount()
    return #self.db.sessions
end
