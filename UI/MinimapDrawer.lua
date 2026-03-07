-- ============================================================
-- Meridian — Minimap Drawer (100% Native)
-- Dessine la route en pointillés + waypoint actif sur la minimap
-- Utilise des pins rotatifs autour du centre minimap
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local RouteEngine = ns.RouteEngine
local L = ns.L

local MinimapDrawer = {}
ns.MinimapDrawer = MinimapDrawer

local math_cos = math.cos
local math_sin = math.sin
local math_sqrt = math.sqrt
local math_atan2 = math.atan2
local math_pi = math.pi

-- ============================================================
-- Constants
-- ============================================================
local DOT_SIZE = 4
local DOT_ACTIVE_SIZE = 10
local DOT_SPACING = 8          -- espacement entre les pointillés de la ligne
local LINE_DOT_SIZE = 2
local MAX_DOTS = 200           -- max de dots pour les lignes
local UPDATE_INTERVAL = 0.05

-- ============================================================
-- Pin pools
-- ============================================================
local waypointPins = {}        -- pins for waypoints
local lineDots = {}            -- dots for dashed lines
local isShowing = false
local drawFrame = nil

-- ============================================================
-- Create a single dot texture on Minimap
-- ============================================================
local function CreateDot(size, r, g, b, a)
    local dot = Minimap:CreateTexture(nil, "OVERLAY")
    dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    dot:SetSize(size, size)
    dot:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    dot:Hide()
    return dot
end

-- ============================================================
-- Convert world-map coords to minimap pixel offset
-- Returns nil if waypoint is out of minimap range
-- ============================================================
local function WorldToMinimap(wpX, wpY)
    -- wpX, wpY en coordonnées carte (0-100)
    -- On a besoin de la position joueur en coords carte
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil, nil end

    local px, py = pos.x * 100, pos.y * 100

    -- Delta en % carte
    local dx = wpX - px
    local dy = wpY - py

    -- Minimap zoom : le rayon de la minimap couvre environ 3-5% de la carte
    -- selon le zoom. On utilise le yard-based system.
    -- Approche : utiliser les dimensions en yards via C_Map
    local mapWidth, mapHeight
    do
        local _, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
        if topLeft and bottomRight then
            mapWidth = math.abs(bottomRight.x - topLeft.x)
            mapHeight = math.abs(bottomRight.y - topLeft.y)
        end
    end

    if not mapWidth or mapWidth == 0 then return nil, nil end

    -- Delta en yards
    local dxYards = (dx / 100) * mapWidth
    local dyYards = (dy / 100) * mapHeight

    -- Rayon minimap en yards (varie avec le zoom, ~230 yards à zoom normal)
    local minimapRadius = Minimap:GetWidth() / 2
    local minimapYardsRadius = C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
                               or 233

    -- Conversion yards → pixels minimap
    local scale = minimapRadius / minimapYardsRadius
    local pixelX = dxYards * scale
    local pixelY = -dyYards * scale  -- Y inversé

    -- Rotation de la minimap si elle tourne
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    if Minimap:GetSetting and Minimap:GetSetting("rotateMinimap") then
        -- Rotation dans le sens contraire du facing
        local cosF = math_cos(facing)
        local sinF = math_sin(facing)
        pixelX, pixelY = pixelX * cosF - pixelY * sinF,
                          pixelX * sinF + pixelY * cosF
    elseif GetCVar and GetCVar("rotateMinimap") == "1" then
        local cosF = math_cos(facing)
        local sinF = math_sin(facing)
        pixelX, pixelY = pixelX * cosF - pixelY * sinF,
                          pixelX * sinF + pixelY * cosF
    end

    -- Vérifier si dans le rayon de la minimap
    local distPixels = math_sqrt(pixelX * pixelX + pixelY * pixelY)
    if distPixels > minimapRadius - 5 then
        return nil, nil  -- hors de la minimap
    end

    return pixelX, pixelY
end

-- ============================================================
-- Get or create a waypoint pin
-- ============================================================
local function GetWaypointPin(index)
    if not waypointPins[index] then
        waypointPins[index] = CreateDot(DOT_SIZE, 0.9, 0.8, 0.2, 0.9)
    end
    return waypointPins[index]
end

local function GetLineDot(index)
    if not lineDots[index] then
        lineDots[index] = CreateDot(LINE_DOT_SIZE, 0.5, 0.5, 0.6, 0.6)
    end
    return lineDots[index]
end

-- ============================================================
-- Draw all waypoints + dashed lines on minimap
-- ============================================================
local function DrawRoute()
    -- Hide everything first
    for _, pin in pairs(waypointPins) do pin:Hide() end
    for _, dot in pairs(lineDots) do dot:Hide() end

    local route = RouteEngine:GetActiveRoute()
    if not route or not isShowing then return end

    local wps = route.waypoints
    if not wps or #wps == 0 then return end

    local currentIdx = RouteEngine:GetCurrentWaypointIndex()
    local lineDotIdx = 0

    for i, wp in ipairs(wps) do
        local px, py = WorldToMinimap(wp.x, wp.y)
        if px then
            local pin = GetWaypointPin(i)

            if i == currentIdx then
                -- Waypoint actif : plus gros, plus brillant
                pin:SetSize(DOT_ACTIVE_SIZE, DOT_ACTIVE_SIZE)
                pin:SetVertexColor(0.2, 0.9, 0.4, 1)
            else
                pin:SetSize(DOT_SIZE, DOT_SIZE)
                pin:SetVertexColor(0.9, 0.8, 0.2, 0.8)
            end

            pin:ClearAllPoints()
            pin:SetPoint("CENTER", Minimap, "CENTER", px, py)
            pin:Show()
        end

        -- Dashed line to next waypoint
        local nextIdx = (i % #wps) + 1
        local nextWp = wps[nextIdx]
        local p1x, p1y = WorldToMinimap(wp.x, wp.y)
        local p2x, p2y = WorldToMinimap(nextWp.x, nextWp.y)

        if p1x and p2x then
            local segDx = p2x - p1x
            local segDy = p2y - p1y
            local segLen = math_sqrt(segDx * segDx + segDy * segDy)

            if segLen > DOT_SPACING then
                local numDots = math.min(math_floor(segLen / DOT_SPACING), 12)
                for d = 1, numDots do
                    lineDotIdx = lineDotIdx + 1
                    if lineDotIdx > MAX_DOTS then break end

                    local t = d / (numDots + 1)
                    local dotX = p1x + segDx * t
                    local dotY = p1y + segDy * t

                    local dot = GetLineDot(lineDotIdx)
                    -- Couleur plus vive si c'est le segment vers le waypoint actif
                    if i == currentIdx then
                        dot:SetVertexColor(0.2, 0.9, 0.4, 0.8)
                    else
                        dot:SetVertexColor(0.5, 0.5, 0.6, 0.5)
                    end
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", Minimap, "CENTER", dotX, dotY)
                    dot:Show()
                end
            end
        end
    end
end

-- ============================================================
-- Update loop
-- ============================================================
function MinimapDrawer:StartDrawing()
    isShowing = true
    if not drawFrame then
        drawFrame = CreateFrame("Frame")
    end
    drawFrame.elapsed = 0
    drawFrame:SetScript("OnUpdate", function(self, elapsed)
        drawFrame.elapsed = drawFrame.elapsed + elapsed
        if drawFrame.elapsed < UPDATE_INTERVAL then return end
        drawFrame.elapsed = 0
        DrawRoute()
    end)
end

function MinimapDrawer:StopDrawing()
    isShowing = false
    if drawFrame then
        drawFrame:SetScript("OnUpdate", nil)
    end
    for _, pin in pairs(waypointPins) do pin:Hide() end
    for _, dot in pairs(lineDots) do dot:Hide() end
end

function MinimapDrawer:IsShowing()
    return isShowing
end

-- ============================================================
-- Callbacks
-- ============================================================
Meridian:RegisterCallback("NAV_STARTED", function()
    MinimapDrawer:StartDrawing()
end)

Meridian:RegisterCallback("NAV_STOPPED", function()
    MinimapDrawer:StopDrawing()
end)

Meridian:RegisterCallback("NAV_PAUSED", function()
    -- Keep drawing but route stays visible
end)

Meridian:RegisterCallback("NAV_RESUMED", function()
    if not isShowing then
        MinimapDrawer:StartDrawing()
    end
end)
