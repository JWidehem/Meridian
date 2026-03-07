-- ============================================================
-- Meridian — Default Routes (Test Data)
-- Routes pré-calculées pour Bois des Chants éternels (mapID 2395)
-- Générées à partir de 249 nodes collectés
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local RouteEngine = ns.RouteEngine

local DefaultRoutes = {}
ns.DefaultRoutes = DefaultRoutes

-- ============================================================
-- Route Combinée (Herbs + Ores) — 22 waypoints
-- ============================================================
local ROUTE_COMBINED = {
    name      = "Eversong - All",
    mapID     = 2395,
    filter    = "ALL",
    created   = 1741300000,
    waypoints = {
        { order = 1,  x = 37.50, y = 19.00, label = "Île de Haut-Soleil W" },
        { order = 2,  x = 43.00, y = 19.00, label = "Île de Haut-Soleil E" },
        { order = 3,  x = 58.50, y = 16.00, label = "Côte nord" },
        { order = 4,  x = 63.30, y = 15.80, label = "Côte nord-est" },
        { order = 5,  x = 64.00, y = 28.00, label = "Côte de Brise-d'Azur" },
        { order = 6,  x = 62.50, y = 34.00, label = "Domaine Luisaile" },
        { order = 7,  x = 62.00, y = 39.00, label = "Est central" },
        { order = 8,  x = 62.50, y = 48.00, label = "Tor'Watha (dense)" },
        { order = 9,  x = 63.50, y = 52.50, label = "Tor'Watha sud" },
        { order = 10, x = 61.50, y = 56.00, label = "Luméclat Lash'Ra" },
        { order = 11, x = 58.50, y = 61.00, label = "Lac Elrendar" },
        { order = 12, x = 61.00, y = 66.50, label = "Flèche d'Aubétoile" },
        { order = 13, x = 60.50, y = 73.50, label = "Sud-est" },
        { order = 14, x = 56.50, y = 83.00, label = "Zeb'Nowa" },
        { order = 15, x = 48.50, y = 86.00, label = "Passe Thalassienne" },
        { order = 16, x = 44.00, y = 84.50, label = "Ruines de Mortholme" },
        { order = 17, x = 38.00, y = 83.00, label = "Chaîne Thalassienne" },
        { order = 18, x = 35.00, y = 75.00, label = "Coursevent" },
        { order = 19, x = 37.00, y = 65.00, label = "Aire des Daguéchines" },
        { order = 20, x = 36.00, y = 55.00, label = "Brume-d'Or" },
        { order = 21, x = 35.50, y = 45.00, label = "Grève du Couchant" },
        { order = 22, x = 38.00, y = 35.00, label = "Nord-ouest" },
    },
}

-- ============================================================
-- Route Herbs Only — 18 waypoints
-- ============================================================
local ROUTE_HERBS = {
    name      = "Eversong - Herbs",
    mapID     = 2395,
    filter    = "HERB",
    created   = 1741300000,
    waypoints = {
        { order = 1,  x = 37.50, y = 19.00, label = "Île de Haut-Soleil" },
        { order = 2,  x = 42.50, y = 19.00, label = "Île de Haut-Soleil E" },
        { order = 3,  x = 59.00, y = 14.50, label = "Côte nord (Sanguironce)" },
        { order = 4,  x = 63.00, y = 34.00, label = "Domaine Luisaile" },
        { order = 5,  x = 61.50, y = 40.50, label = "Est (Sanguironce)" },
        { order = 6,  x = 62.50, y = 48.00, label = "Tor'Watha (Feuille-d'argent)" },
        { order = 7,  x = 61.50, y = 52.50, label = "Tor'Watha S (Azeracine)" },
        { order = 8,  x = 60.00, y = 57.00, label = "Luméclat (Azeracine)" },
        { order = 9,  x = 57.50, y = 61.50, label = "Lac Elrendar" },
        { order = 10, x = 55.50, y = 68.00, label = "Centre-sud" },
        { order = 11, x = 56.50, y = 85.00, label = "Zeb'Nowa (Sanguironce)" },
        { order = 12, x = 52.50, y = 87.50, label = "Zeb'Nowa S (Azeracine)" },
        { order = 13, x = 46.50, y = 86.50, label = "Chaîne Thalassienne" },
        { order = 14, x = 42.00, y = 79.00, label = "Sud-ouest" },
        { order = 15, x = 34.50, y = 77.50, label = "Coursevent (Lys mana)" },
        { order = 16, x = 36.50, y = 64.00, label = "Daguéchines (Lys mana)" },
        { order = 17, x = 35.50, y = 50.00, label = "Ouest (Sanguironce)" },
        { order = 18, x = 37.00, y = 37.00, label = "Nord-ouest" },
    },
}

-- ============================================================
-- Route Ores Only — 16 waypoints
-- ============================================================
local ROUTE_ORES = {
    name      = "Eversong - Ores",
    mapID     = 2395,
    filter    = "ORE",
    created   = 1741300000,
    waypoints = {
        { order = 1,  x = 37.50, y = 19.50, label = "Île Haut-Soleil (cuivre)" },
        { order = 2,  x = 43.00, y = 19.00, label = "Île Haut-Soleil E" },
        { order = 3,  x = 60.00, y = 15.00, label = "Nord-est (cuivre)" },
        { order = 4,  x = 63.50, y = 24.00, label = "Côte E (argent)" },
        { order = 5,  x = 62.50, y = 35.00, label = "Luisaile (cuivre+argent)" },
        { order = 6,  x = 62.00, y = 48.00, label = "Tor'Watha (dense)" },
        { order = 7,  x = 63.50, y = 52.50, label = "Tor'Watha S (étain)" },
        { order = 8,  x = 60.00, y = 61.50, label = "Lac Elrendar (argent)" },
        { order = 9,  x = 61.00, y = 66.50, label = "Est (étain)" },
        { order = 10, x = 56.50, y = 84.00, label = "Zeb'Nowa (argent+étain)" },
        { order = 11, x = 45.50, y = 85.00, label = "Mortholme (cuivre+étain)" },
        { order = 12, x = 38.00, y = 83.00, label = "Chaîne Thalass. (argent)" },
        { order = 13, x = 37.00, y = 76.50, label = "Coursevent (argent+cuivre)" },
        { order = 14, x = 38.00, y = 57.00, label = "Daguéchines (cuivre+argent)" },
        { order = 15, x = 36.00, y = 47.50, label = "Grève Couchant (cuivre+étain)" },
        { order = 16, x = 38.00, y = 40.00, label = "Sanctum Occ. (cuivre)" },
    },
}

-- ============================================================
-- Install default routes if not already present
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    local routes = Meridian.db.routes
    if not routes then
        Meridian.db.routes = {}
        routes = Meridian.db.routes
    end

    local defaults = { ROUTE_COMBINED, ROUTE_HERBS, ROUTE_ORES }
    local installed = 0

    for _, route in ipairs(defaults) do
        if not routes[route.name] then
            routes[route.name] = {
                name      = route.name,
                mapID     = route.mapID,
                filter    = route.filter,
                created   = route.created,
                waypoints = route.waypoints,
            }
            installed = installed + 1
        end
    end

    if installed > 0 then
        Meridian:FireCallback("ROUTES_UPDATED")
    end
end)
