-- ============================================================
-- Meridian — Navigation Arrow (100% Native)
-- Flèche GPS style TomTom pointant vers le prochain waypoint
-- Affiche distance + nom du waypoint
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local RouteEngine = ns.RouteEngine
local L = ns.L

local NavigationArrow = {}
ns.NavigationArrow = NavigationArrow

local math_deg = math.deg
local math_rad = math.rad
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local format = string.format

-- ============================================================
-- Constants
-- ============================================================
local ARROW_SIZE = 48
local UPDATE_INTERVAL = 0.03   -- ~30 fps pour la rotation fluide

-- ============================================================
-- State
-- ============================================================
local arrowFrame = nil

-- ============================================================
-- Create arrow frame
-- ============================================================
function NavigationArrow:Create()
    if arrowFrame then return arrowFrame end

    arrowFrame = CreateFrame("Frame", "MeridianNavArrow", UIParent)
    arrowFrame:SetSize(ARROW_SIZE + 120, ARROW_SIZE + 50)
    arrowFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    arrowFrame:SetFrameStrata("HIGH")
    arrowFrame:SetMovable(true)
    arrowFrame:EnableMouse(true)
    arrowFrame:RegisterForDrag("LeftButton")
    arrowFrame:SetScript("OnDragStart", arrowFrame.StartMoving)
    arrowFrame:SetScript("OnDragStop", arrowFrame.StopMovingOrSizing)
    arrowFrame:SetClampedToScreen(true)

    -- Background subtle
    local bg = arrowFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)
    arrowFrame.bg = bg

    -- Arrow texture (on utilise la flèche de quête comme base)
    local arrow = arrowFrame:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("CENTER", arrowFrame, "CENTER", 0, 8)
    arrow:SetTexture("Interface\\MINIMAP\\ROTATING-MINIMAPGUIDEARROW")
    arrowFrame.arrow = arrow

    -- Waypoint label (nom)
    local label = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", arrowFrame, "TOP", 0, -2)
    label:SetTextColor(0.9, 0.8, 0.2)
    arrowFrame.label = label

    -- Distance text
    local dist = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dist:SetPoint("BOTTOM", arrowFrame, "BOTTOM", 0, 4)
    dist:SetTextColor(1, 1, 1)
    arrowFrame.dist = dist

    -- Progress text (waypoint X / Y)
    local progress = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progress:SetPoint("BOTTOMRIGHT", arrowFrame, "BOTTOMRIGHT", -4, 4)
    progress:SetTextColor(0.6, 0.6, 0.6)
    arrowFrame.progress = progress

    arrowFrame:Hide()
    return arrowFrame
end

-- ============================================================
-- Update arrow rotation + distance
-- ============================================================
function NavigationArrow:OnUpdate()
    if not arrowFrame or not arrowFrame:IsShown() then return end

    local wp = RouteEngine:GetCurrentWaypoint()
    if not wp then return end

    -- Angle vers le waypoint (en radians, 0 = nord)
    local angle = RouteEngine:AngleTo(wp.x, wp.y)
    if not angle then return end

    -- Facing du joueur
    local facing = 0
    if GetPlayerFacing then
        local ok, f = pcall(GetPlayerFacing)
        if ok and f then facing = f end
    end

    -- Rotation de la flèche relative au facing du joueur
    arrowFrame.arrow:SetRotation(angle - facing)

    -- Distance
    local dist = RouteEngine:DistanceTo(wp.x, wp.y)
    if dist then
        if dist > 10 then
            arrowFrame.dist:SetText(format("%.0f", dist))
        else
            arrowFrame.dist:SetText(format("%.1f", dist))
        end

        -- Couleur selon distance
        if dist < 5 then
            arrowFrame.dist:SetTextColor(0.2, 0.9, 0.4)
        elseif dist < 15 then
            arrowFrame.dist:SetTextColor(0.9, 0.8, 0.2)
        else
            arrowFrame.dist:SetTextColor(1, 1, 1)
        end
    end
end

-- ============================================================
-- Show / Hide
-- ============================================================
function NavigationArrow:Show()
    if not arrowFrame then self:Create() end
    arrowFrame:Show()
    self:StartUpdate()
end

function NavigationArrow:Hide()
    if arrowFrame then arrowFrame:Hide() end
    self:StopUpdate()
end

function NavigationArrow:StartUpdate()
    if not arrowFrame then return end
    arrowFrame.elapsed = 0
    arrowFrame:SetScript("OnUpdate", function(self, elapsed)
        arrowFrame.elapsed = (arrowFrame.elapsed or 0) + elapsed
        if arrowFrame.elapsed < UPDATE_INTERVAL then return end
        arrowFrame.elapsed = 0
        NavigationArrow:OnUpdate()
    end)
end

function NavigationArrow:StopUpdate()
    if arrowFrame then
        arrowFrame:SetScript("OnUpdate", nil)
    end
end

-- ============================================================
-- Update waypoint info display
-- ============================================================
function NavigationArrow:SetWaypointInfo(index, wp)
    if not arrowFrame then self:Create() end
    local total = RouteEngine:GetTotalWaypoints()
    arrowFrame.label:SetText(wp.label or ("Waypoint " .. index))
    arrowFrame.progress:SetText(format("%d/%d", index, total))
end

-- ============================================================
-- Callbacks
-- ============================================================
Meridian:RegisterCallback("NAV_STARTED", function()
    NavigationArrow:Show()
end)

Meridian:RegisterCallback("NAV_STOPPED", function()
    NavigationArrow:Hide()
end)

Meridian:RegisterCallback("NAV_PAUSED", function()
    NavigationArrow:Hide()
end)

Meridian:RegisterCallback("NAV_RESUMED", function()
    NavigationArrow:Show()
end)

Meridian:RegisterCallback("NAV_WAYPOINT_CHANGED", function(index, wp)
    NavigationArrow:SetWaypointInfo(index, wp)
end)
