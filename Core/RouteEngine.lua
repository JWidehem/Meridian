-- ============================================================
-- Meridian — Route Engine (100% Native)
-- Gestion des routes de farming, progression waypoints,
-- navigation GPS style TomTom
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

local RouteEngine = {}
ns.RouteEngine = RouteEngine

local math_sqrt = math.sqrt
local math_floor = math.floor
local GetTime = GetTime

-- ============================================================
-- Constants
-- ============================================================
local ARRIVAL_RADIUS = 2.5       -- % carte distance pour arriver au waypoint
local UPDATE_INTERVAL = 0.1      -- secondes entre updates de navigation

-- ============================================================
-- State
-- ============================================================
local activeRoute = nil           -- route en cours
local currentWaypointIndex = 0    -- index du waypoint cible
local isNavigating = false        -- navigation GPS active
local navFrame = nil              -- frame de l'update loop

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    if not Meridian.db.routes then
        Meridian.db.routes = {}
    end
    if not Meridian.db.activeRouteName then
        Meridian.db.activeRouteName = nil
    end
end)

-- ============================================================
-- Route CRUD
-- ============================================================
function RouteEngine:SaveRoute(name, mapID, filter, waypoints)
    if not name or not waypoints or #waypoints == 0 then return false end
    Meridian.db.routes[name] = {
        name      = name,
        mapID     = mapID,
        filter    = filter or "ALL",
        created   = time(),
        waypoints = waypoints,
    }
    Meridian:FireCallback("ROUTES_UPDATED")
    return true
end

function RouteEngine:DeleteRoute(name)
    if not Meridian.db.routes[name] then return false end
    if activeRoute and activeRoute.name == name then
        self:StopNavigation()
    end
    Meridian.db.routes[name] = nil
    Meridian:FireCallback("ROUTES_UPDATED")
    return true
end

function RouteEngine:GetRoute(name)
    return Meridian.db.routes[name]
end

function RouteEngine:GetAllRoutes()
    return Meridian.db.routes
end

function RouteEngine:GetRouteNames()
    local names = {}
    for name in pairs(Meridian.db.routes) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

-- ============================================================
-- Navigation
-- ============================================================
function RouteEngine:StartNavigation(routeName)
    local route = Meridian.db.routes[routeName]
    if not route or #route.waypoints == 0 then return false end

    activeRoute = route
    currentWaypointIndex = 1
    isNavigating = true
    Meridian.db.activeRouteName = routeName

    self:StartUpdateLoop()
    Meridian:FireCallback("NAV_STARTED", route)
    Meridian:FireCallback("NAV_WAYPOINT_CHANGED", currentWaypointIndex, route.waypoints[1])
    return true
end

function RouteEngine:StopNavigation()
    isNavigating = false
    activeRoute = nil
    currentWaypointIndex = 0
    Meridian.db.activeRouteName = nil

    self:StopUpdateLoop()
    Meridian:FireCallback("NAV_STOPPED")
end

function RouteEngine:PauseNavigation()
    if not isNavigating then return end
    isNavigating = false
    self:StopUpdateLoop()
    Meridian:FireCallback("NAV_PAUSED")
end

function RouteEngine:ResumeNavigation()
    if not activeRoute then return end
    isNavigating = true
    self:StartUpdateLoop()
    Meridian:FireCallback("NAV_RESUMED")
end

function RouteEngine:NextWaypoint()
    if not activeRoute then return end
    local wps = activeRoute.waypoints
    currentWaypointIndex = currentWaypointIndex + 1
    if currentWaypointIndex > #wps then
        currentWaypointIndex = 1 -- boucle
    end
    Meridian:FireCallback("NAV_WAYPOINT_CHANGED", currentWaypointIndex, wps[currentWaypointIndex])
end

function RouteEngine:PrevWaypoint()
    if not activeRoute then return end
    local wps = activeRoute.waypoints
    currentWaypointIndex = currentWaypointIndex - 1
    if currentWaypointIndex < 1 then
        currentWaypointIndex = #wps
    end
    Meridian:FireCallback("NAV_WAYPOINT_CHANGED", currentWaypointIndex, wps[currentWaypointIndex])
end

function RouteEngine:SetWaypoint(index)
    if not activeRoute then return end
    if index < 1 or index > #activeRoute.waypoints then return end
    currentWaypointIndex = index
    Meridian:FireCallback("NAV_WAYPOINT_CHANGED", currentWaypointIndex, activeRoute.waypoints[index])
end

-- ============================================================
-- Getters
-- ============================================================
function RouteEngine:IsNavigating()
    return isNavigating
end

function RouteEngine:GetActiveRoute()
    return activeRoute
end

function RouteEngine:GetCurrentWaypointIndex()
    return currentWaypointIndex
end

function RouteEngine:GetCurrentWaypoint()
    if not activeRoute or currentWaypointIndex == 0 then return nil end
    return activeRoute.waypoints[currentWaypointIndex]
end

function RouteEngine:GetTotalWaypoints()
    if not activeRoute then return 0 end
    return #activeRoute.waypoints
end

-- ============================================================
-- Player position helper
-- ============================================================
function RouteEngine:GetPlayerMapPos(forMapID)
    local mapID = forMapID or C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    return mapID, pos.x * 100, pos.y * 100
end

-- ============================================================
-- Distance helper (en % carte)
-- ============================================================
function RouteEngine:DistanceTo(wx, wy)
    local routeMapID = activeRoute and activeRoute.mapID or nil
    local mapID, px, py = self:GetPlayerMapPos(routeMapID)
    if not px then return nil, nil end
    local dx = wx - px
    local dy = wy - py
    return math_sqrt(dx * dx + dy * dy), mapID
end

-- Angle from player to waypoint (radians, 0 = north, clockwise)
function RouteEngine:AngleTo(wx, wy)
    local routeMapID = activeRoute and activeRoute.mapID or nil
    local mapID, px, py = self:GetPlayerMapPos(routeMapID)
    if not px then return nil end
    -- En coordonnées carte : Y augmente vers le bas
    local dx = wx - px
    local dy = -(wy - py)
    return math.atan2(dx, dy)
end

-- ============================================================
-- Update loop — check arrival at waypoint
-- ============================================================
function RouteEngine:StartUpdateLoop()
    if not navFrame then
        navFrame = CreateFrame("Frame")
    end
    navFrame.elapsed = 0
    navFrame:SetScript("OnUpdate", function(self, elapsed)
        navFrame.elapsed = navFrame.elapsed + elapsed
        if navFrame.elapsed < UPDATE_INTERVAL then return end
        navFrame.elapsed = 0
        RouteEngine:OnUpdate()
    end)
end

function RouteEngine:StopUpdateLoop()
    if navFrame then
        navFrame:SetScript("OnUpdate", nil)
    end
end

function RouteEngine:OnUpdate()
    if not isNavigating or not activeRoute then return end
    local wps = activeRoute.waypoints
    local wp = wps[currentWaypointIndex]
    if not wp then return end

    local dist = self:DistanceTo(wp.x, wp.y)
    if not dist then return end

    -- Broadcast position info pour Arrow + UI
    Meridian:FireCallback("NAV_UPDATE", currentWaypointIndex, wp, dist)

    -- Auto-advance si on est arrivé
    if dist < ARRIVAL_RADIUS then
        self:NextWaypoint()
        return
    end

    -- Smart re-routing : si le joueur a dévié loin du waypoint actuel,
    -- vérifier s'il est proche d'un autre waypoint de la route
    if dist > ARRIVAL_RADIUS * 3 then
        local routeMapID = activeRoute.mapID
        local _, px, py = self:GetPlayerMapPos(routeMapID)
        if px then
            for i, w in ipairs(wps) do
                if i ~= currentWaypointIndex then
                    local d = math_sqrt((w.x - px) * (w.x - px) + (w.y - py) * (w.y - py))
                    if d < ARRIVAL_RADIUS then
                        currentWaypointIndex = (i % #wps) + 1
                        Meridian:FireCallback("NAV_WAYPOINT_CHANGED", currentWaypointIndex, wps[currentWaypointIndex])
                        return
                    end
                end
            end
        end
    end
end

-- ============================================================
-- Reset callback
-- ============================================================
Meridian:RegisterCallback("RESET_ALL", function()
    RouteEngine:StopNavigation()
end)

-- ============================================================
-- Recherche de route pour la zone actuelle
-- ============================================================
function RouteEngine:FindRouteForZone(mapID)
    if not mapID then return nil end
    local bestName = nil
    for name, route in pairs(Meridian.db.routes) do
        if route.mapID == mapID then
            if not bestName or route.filter == "ALL" then
                bestName = name
            end
        end
    end
    if bestName then return bestName end
    -- Remonter l'arbre des cartes parentes
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
        return self:FindRouteForZone(mapInfo.parentMapID)
    end
    return nil
end

-- ============================================================
-- Démarrage automatique de la navigation
-- ============================================================
function RouteEngine:AutoStart()
    if self:IsNavigating() then return end
    -- Reprendre une route précédemment active
    local saved = Meridian.db.activeRouteName
    if saved and Meridian.db.routes[saved] then
        self:StartNavigation(saved)
        return
    end
    -- Chercher une route pour la zone actuelle
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local routeName = self:FindRouteForZone(mapID)
    if routeName then
        self:StartNavigation(routeName)
    end
end

-- ============================================================
-- Évènements : auto-start au login, changement de zone
-- ============================================================
local autoFrame = CreateFrame("Frame")
autoFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
autoFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
autoFrame:SetScript("OnEvent", function(self, event)
    if not Meridian.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            RouteEngine:AutoStart()
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if RouteEngine:IsNavigating() then
            local route = RouteEngine:GetActiveRoute()
            if route then
                local pos = C_Map.GetPlayerMapPosition(route.mapID, "player")
                if not pos then
                    RouteEngine:StopNavigation()
                    RouteEngine:AutoStart()
                end
            end
        else
            RouteEngine:AutoStart()
        end
    end
end)
