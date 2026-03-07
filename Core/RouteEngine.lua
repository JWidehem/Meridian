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
local resolvedMapID = nil         -- mapID vérifié qui fonctionne

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    if not Meridian.db.routes then
        Meridian.db.routes = {}
    end
    Meridian.db.activeRouteName = nil
end)

-- ============================================================
-- Résolution du mapID — trouver un mapID qui fonctionne
-- pour positionner le joueur sur la carte de la route
-- ============================================================
local function ResolveMapID(routeMapID)
    -- 1) Essayer le mapID de la route
    if routeMapID then
        local pos = C_Map.GetPlayerMapPosition(routeMapID, "player")
        if pos then
            return routeMapID
        end
    end

    -- 2) Essayer le mapID actuel du joueur
    local bestMap = C_Map.GetBestMapForUnit("player")
    if bestMap then
        local pos = C_Map.GetPlayerMapPosition(bestMap, "player")
        if pos then
            return bestMap
        end
    end

    -- 3) Remonter la hiérarchie depuis le bestMap
    if bestMap then
        local info = C_Map.GetMapInfo(bestMap)
        while info and info.parentMapID and info.parentMapID > 0 do
            local pos = C_Map.GetPlayerMapPosition(info.parentMapID, "player")
            if pos then
                return info.parentMapID
            end
            info = C_Map.GetMapInfo(info.parentMapID)
        end
    end

    return nil
end

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
    if not route then
        Meridian:Msg("|cffff0000Route introuvable : " .. tostring(routeName) .. "|r")
        return false
    end
    if not route.waypoints or #route.waypoints == 0 then
        Meridian:Msg("|cffff0000Route vide (aucun waypoint)|r")
        return false
    end

    -- Résoudre le mapID
    local mapID = ResolveMapID(route.mapID)
    if not mapID then
        Meridian:Msg("|cffff0000Impossible de localiser le joueur sur la carte (mapID=" .. tostring(route.mapID) .. ")|r")
        Meridian:Msg("Essayez d'ouvrir la carte de la zone d'abord.")
        return false
    end

    -- Si le mapID résolu est différent, mettre à jour la route
    if mapID ~= route.mapID then
        Meridian:Msg("MapID corrigé : " .. tostring(route.mapID) .. " -> " .. tostring(mapID))
        route.mapID = mapID
    end

    resolvedMapID = mapID
    activeRoute = route
    isNavigating = true
    Meridian.db.activeRouteName = routeName

    -- Démarrer au waypoint le plus proche du joueur
    local pos = C_Map.GetPlayerMapPosition(resolvedMapID, "player")
    if pos then
        local px, py = pos.x * 100, pos.y * 100
        local bestIdx = 1
        local bestDist = 99999
        for i, wp in ipairs(route.waypoints) do
            local d = math_sqrt((wp.x - px) * (wp.x - px) + (wp.y - py) * (wp.y - py))
            if d < bestDist then
                bestDist = d
                bestIdx = i
            end
        end
        currentWaypointIndex = bestIdx
    else
        currentWaypointIndex = 1
    end

    self:StartUpdateLoop()
    Meridian:FireCallback("NAV_STARTED", route)
    Meridian:FireCallback("NAV_WAYPOINT_CHANGED", currentWaypointIndex, route.waypoints[currentWaypointIndex])

    Meridian:Msg("|cff2ecc71Navigation active|r : " .. route.name .. " (" .. #route.waypoints .. " pts, départ " .. currentWaypointIndex .. "/" .. #route.waypoints .. ")")
    return true
end

function RouteEngine:StopNavigation()
    local wasNav = isNavigating
    isNavigating = false
    activeRoute = nil
    currentWaypointIndex = 0
    resolvedMapID = nil
    Meridian.db.activeRouteName = nil

    self:StopUpdateLoop()
    Meridian:FireCallback("NAV_STOPPED")

    if wasNav then
        Meridian:Msg("|cffe74c3cNavigation arrêtée|r")
    end
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

function RouteEngine:GetResolvedMapID()
    return resolvedMapID
end

-- ============================================================
-- Player position helper
-- Utilise le resolvedMapID pour rester cohérent avec la route
-- ============================================================
function RouteEngine:GetPlayerMapPos()
    local mapID = resolvedMapID or C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        -- Fallback : essayer le bestMap si resolvedMapID a échoué
        if resolvedMapID then
            mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                pos = C_Map.GetPlayerMapPosition(mapID, "player")
            end
        end
        if not pos then return nil end
    end
    return mapID, pos.x * 100, pos.y * 100
end

-- ============================================================
-- Distance helper (en % carte)
-- ============================================================
function RouteEngine:DistanceTo(wx, wy)
    local mapID, px, py = self:GetPlayerMapPos()
    if not px then return nil, nil end
    local dx = wx - px
    local dy = wy - py
    return math_sqrt(dx * dx + dy * dy), mapID
end

-- ============================================================
-- Angle from player to waypoint (radians)
-- Convention : 0 = nord, croissant sens horaire
-- ============================================================
function RouteEngine:AngleTo(wx, wy)
    local mapID, px, py = self:GetPlayerMapPos()
    if not px then return nil end
    local dx = wx - px
    local dy = -(wy - py)  -- Y inversé (carte : Y bas = sud)
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
        local _, px, py = self:GetPlayerMapPos()
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
