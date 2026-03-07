-- ============================================================
-- Meridian — Minimap Icon (100% Native, zero-lib)
-- Bouton draggable autour du Minimap, cos/sin positioning
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

local MinimapIcon = {}
ns.MinimapIcon = MinimapIcon

local math_cos = math.cos
local math_sin = math.sin
local math_rad = math.rad
local math_atan2 = math.atan2
local math_deg = math.deg

local ICON_SIZE = 32
local MINIMAP_RADIUS = 80

-- ============================================================
-- Position helpers
-- ============================================================
local function UpdatePosition(button, angle)
    button:ClearAllPoints()
    local x = math_cos(math_rad(angle)) * MINIMAP_RADIUS
    local y = math_sin(math_rad(angle)) * MINIMAP_RADIUS
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function GetCursorAngle()
    local cx, cy = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    mx, my = mx / scale, my / scale
    return math_deg(math_atan2(my - cy, mx - cx))
end

-- ============================================================
-- Create button
-- ============================================================
function MinimapIcon:Create()
    local button = CreateFrame("Button", "MeridianMinimapButton", Minimap)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\MINIMAP\\TRACKING\\None")
    button.icon = icon

    -- Overlay (highlight circle)
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(ICON_SIZE, ICON_SIZE)
    overlay:SetPoint("CENTER")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.overlay = overlay

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(ICON_SIZE, ICON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Meridian", 0.9, 0.8, 0.2)

        local Database = ns.Database
        if Database then
            local totalNodes = Database:GetTotalNodeCount()
            local ores = Database:GetKnownResourcesByType("ORE")
            local herbs = Database:GetKnownResourcesByType("HERB")
            GameTooltip:AddLine(string.format(L.TOOLTIP_NODES, totalNodes), 1, 1, 1)
            GameTooltip:AddLine(string.format(L.TOOLTIP_RESOURCES, #ores, #herbs), 0.7, 0.7, 0.7)
        end

        local enabled = Meridian.db and Meridian.db.enabled
        local status = enabled and ("|cff2ecc71" .. L.TRACKING_ON .. "|r")
                                or ("|cffe74c3c" .. L.TRACKING_OFF .. "|r")
        GameTooltip:AddLine(status)
        GameTooltip:AddLine(L.TOOLTIP_HINT, 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Clicks
    button:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then
            Meridian.db.enabled = not Meridian.db.enabled
            local state = Meridian.db.enabled and L.TRACKING_ON or L.TRACKING_OFF
            Meridian:Msg(state)
        else
            if ns.StatsPanel then
                ns.StatsPanel:Toggle()
            end
        end
    end)

    -- Drag (circular around minimap)
    local isDragging = false

    button:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function()
            local angle = GetCursorAngle()
            Meridian.db.minimap.angle = angle
            UpdatePosition(self, angle)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    self.button = button
    return button
end

-- ============================================================
-- Show / Hide / Toggle
-- ============================================================
function MinimapIcon:UpdateVisibility()
    if not self.button then return end
    if Meridian.db.minimap.hide then
        self.button:Hide()
    else
        self.button:Show()
    end
end

function MinimapIcon:Toggle()
    Meridian.db.minimap.hide = not Meridian.db.minimap.hide
    self:UpdateVisibility()
end

-- ============================================================
-- Init
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    MinimapIcon:Create()
    local angle = Meridian.db.minimap.angle or 220
    UpdatePosition(MinimapIcon.button, angle)
    MinimapIcon:UpdateVisibility()
end)
