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

    -- Glimmer: dark translucent background circle
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(ICON_SIZE, ICON_SIZE)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.04, 0.04, 0.07, 0.80)
    button.bg = bg

    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\MINIMAP\\TRACKING\\None")
    button.icon = icon

    -- Glimmer: subtle ring border (1px, very dim white)
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(ICON_SIZE, ICON_SIZE)
    overlay:SetPoint("CENTER")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetVertexColor(1, 1, 1, 0.35)
    button.overlay = overlay

    -- Glimmer: bright ADD highlight on hover
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(ICON_SIZE, ICON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 1, 1, 0.6)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Meridian", 0.9, 0.8, 0.2)

        local ses = ns.Session
        local ora = ns.Oracle
        local db  = ns.Database

        if ses and ses:IsActive() then
            GameTooltip:AddLine(ses.state.zoneName, 0.56, 0.85, 0.72)
            if db and ora then
                local h, o = db:GetDisplayTotals()
                if h > 0 then
                    GameTooltip:AddLine("Herbes : " .. ora:FormatGold(h), 0.25, 0.78, 0.55)
                end
                if o > 0 then
                    GameTooltip:AddLine("Minerais : " .. ora:FormatGold(o), 0.88, 0.76, 0.28)
                end
            end
        elseif ses and ses:IsWaiting() and ora then
            local waitZone = ora.ZONE_NAMES[ses:GetWaitingZone()] or "?"
            GameTooltip:AddLine(L.TOOLTIP_WAITING:format(waitZone), 0.7, 0.7, 0.7)
        elseif db and ora then
            local oracle = db:GetOracleResult()
            if oracle and oracle.recommendedZone then
                local zoneName = ora.ZONE_NAMES[oracle.recommendedZone] or "?"
                GameTooltip:AddLine(zoneName, 0.56, 0.85, 0.72)
            end
        end

        GameTooltip:AddLine(L.TOOLTIP_HINT, 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Clicks
    button:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then
            -- clic droit : stop session active
            local ses = ns.Session
            if ses and ses:IsActive() then
                ses:Stop()
            end
        else
            if ns.MainPanel then
                ns.MainPanel:Toggle()
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
