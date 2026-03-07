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
local math_floor = math.floor
local math_abs = math.abs
local math_min = math.min

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

-- Cache des dimensions de la carte en yards (ne change pas par zone)
local cachedMapID = nil
local cachedMapWidth = 0
local cachedMapHeight = 0

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
-- Compute & cache map dimensions in yards for a given mapID
-- ============================================================
local function GetMapDimensions(mapID)
    if mapID == cachedMapID and cachedMapWidth > 0 then
        return cachedMapWidth, cachedMapHeight
    end

    -- Try C_Map.GetWorldPosFromMapPos
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local _, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
        if topLeft and bottomRight then
            local w = math_abs(bottomRight.x - topLeft.x)
            local h = math_abs(bottomRight.y - topLeft.y)
            if w > 0 and h > 0 then
                cachedMapWidth = w
                cachedMapHeight = h
                cachedMapID = mapID
                return w, h
            end
        end
    end

    -- Fallback : dimensions typiques d'une zone standard (~2500 x 1667 yards)
    cachedMapWidth = 2500
    cachedMapHeight = 1667
    cachedMapID = mapID
    return cachedMapWidth, cachedMapHeight
end

-- ============================================================
-- Convert waypoint coords to minimap pixel offset
-- All shared parameters pre-computed once per frame
-- ============================================================
local function WorldToMinimap(wpX, wpY, px, py, scale, minimapRadius, facing, isRotating)
    local dx = (wpX - px) / 100  -- delta en fraction de carte
    local dy = (wpY - py) / 100

    local pixelX = dx * cachedMapWidth * scale
    local pixelY = -(dy * cachedMapHeight * scale)  -- Y inversé

    -- Rotation de la minimap si elle tourne
    if isRotating then
        local cosF = math_cos(facing)
        local sinF = math_sin(facing)
        pixelX, pixelY = pixelX * cosF - pixelY * sinF,
                          pixelX * sinF + pixelY * cosF
    end

    -- Hors du rayon visible de la minimap → invisible
    local distPixels = math_sqrt(pixelX * pixelX + pixelY * pixelY)
    if distPixels > minimapRadius - 5 then
        return nil, nil
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

    -- ── Calculs partagés (1× par frame) ──
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end

    local px, py = pos.x * 100, pos.y * 100
    GetMapDimensions(mapID)

    local minimapRadius = Minimap:GetWidth() / 2
    local viewRadius = C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or 233
    local scale = minimapRadius / viewRadius   -- pixels par yard

    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local isRotating = false
    local hasSetting = Minimap.GetSetting
    if hasSetting and Minimap:GetSetting("rotateMinimap") then
        isRotating = true
    elseif GetCVar and GetCVar("rotateMinimap") == "1" then
        isRotating = true
    end

    -- ── Pré-calculer les positions minimap de tous les waypoints ──
    local currentIdx = RouteEngine:GetCurrentWaypointIndex()
    local positions = {}  -- {[i] = {x, y} or false}

    for i, wp in ipairs(wps) do
        local mx, my = WorldToMinimap(wp.x, wp.y, px, py, scale, minimapRadius, facing, isRotating)
        if mx then
            positions[i] = { x = mx, y = my }
        else
            positions[i] = false
        end
    end

    -- ── Dessiner les pins ──
    for i, p in ipairs(positions) do
        if p then
            local pin = GetWaypointPin(i)
            if i == currentIdx then
                pin:SetSize(DOT_ACTIVE_SIZE, DOT_ACTIVE_SIZE)
                pin:SetVertexColor(0.2, 0.9, 0.4, 1)
            else
                pin:SetSize(DOT_SIZE, DOT_SIZE)
                pin:SetVertexColor(0.9, 0.8, 0.2, 0.8)
            end
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", Minimap, "CENTER", p.x, p.y)
            pin:Show()
        end
    end

    -- ── Dessiner les lignes en pointillés ──
    local lineDotIdx = 0
    for i = 1, #wps do
        local nextIdx = (i % #wps) + 1
        local p1 = positions[i]
        local p2 = positions[nextIdx]

        if p1 and p2 then
            local segDx = p2.x - p1.x
            local segDy = p2.y - p1.y
            local segLen = math_sqrt(segDx * segDx + segDy * segDy)

            if segLen > DOT_SPACING then
                local numDots = math_min(math_floor(segLen / DOT_SPACING), 12)
                for d = 1, numDots do
                    lineDotIdx = lineDotIdx + 1
                    if lineDotIdx > MAX_DOTS then break end

                    local t = d / (numDots + 1)
                    local dotX = p1.x + segDx * t
                    local dotY = p1.y + segDy * t

                    local ldot = GetLineDot(lineDotIdx)
                    if i == currentIdx then
                        ldot:SetVertexColor(0.2, 0.9, 0.4, 0.8)
                    else
                        ldot:SetVertexColor(0.5, 0.5, 0.6, 0.5)
                    end
                    ldot:ClearAllPoints()
                    ldot:SetPoint("CENTER", Minimap, "CENTER", dotX, dotY)
                    ldot:Show()
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
