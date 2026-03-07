-- ============================================================
-- Meridian — Route Panel (100% Native)
-- Panneau de gestion des routes : liste, sélection,
-- démarrage/arrêt navigation, import de routes
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local RouteEngine = ns.RouteEngine
local L = ns.L

local RoutePanel = {}
ns.RoutePanel = RoutePanel

local format = string.format

-- ============================================================
-- Constants
-- ============================================================
local PANEL_WIDTH = 320
local PANEL_HEIGHT = 420
local BAR_HEIGHT = 26
local BAR_SPACING = 3
local BAR_INSET = 12
local HEADER_HEIGHT = 50
local FOOTER_HEIGHT = 80

-- ============================================================
-- State
-- ============================================================
local panel = nil
local routeButtons = {}
local selectedRoute = nil
local scrollContent = nil

-- ============================================================
-- Route color by filter
-- ============================================================
local FILTER_COLORS = {
    ALL  = { 0.9, 0.8, 0.2 },
    HERB = { 0.18, 0.80, 0.44 },
    ORE  = { 0.95, 0.61, 0.07 },
}

-- ============================================================
-- Create a route list button
-- ============================================================
local function CreateRouteButton(parent, index)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(BAR_HEIGHT)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.20, 0.8)
    btn.bg = bg

    local icon = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon:SetPoint("LEFT", 6, 0)
    btn.icon = icon

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 22, 0)
    label:SetPoint("RIGHT", -50, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(1, 1, 1)
    label:SetWordWrap(false)
    btn.label = label

    local info = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("RIGHT", -6, 0)
    info:SetJustifyH("RIGHT")
    info:SetTextColor(0.6, 0.6, 0.6)
    btn.info = info

    -- Highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    btn:SetScript("OnClick", function(self)
        selectedRoute = self.routeName
        RoutePanel:RefreshList()
    end)

    return btn
end

-- ============================================================
-- CreatePanel
-- ============================================================
function RoutePanel:CreatePanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "MeridianRoutePanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)

    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
    panel:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)

    -- Header
    local headerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitle:SetPoint("TOPLEFT", 14, -14)
    headerTitle:SetText(L.ROUTES_TITLE)
    headerTitle:SetTextColor(0.9, 0.8, 0.2)

    local headerSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSub:SetPoint("TOPRIGHT", -14, -18)
    headerSub:SetTextColor(0.6, 0.6, 0.6)
    panel.headerSub = headerSub

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(22, 22)

    -- ============================================================
    -- Navigation status bar
    -- ============================================================
    local navStatus = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    navStatus:SetHeight(26)
    navStatus:SetPoint("TOPLEFT", BAR_INSET, -(HEADER_HEIGHT + 2))
    navStatus:SetPoint("TOPRIGHT", -BAR_INSET, -(HEADER_HEIGHT + 2))
    local navBg = navStatus:CreateTexture(nil, "BACKGROUND")
    navBg:SetAllPoints()
    navBg:SetColorTexture(0.12, 0.12, 0.16, 0.9)
    local navText = navStatus:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    navText:SetPoint("CENTER")
    navText:SetTextColor(0.5, 0.5, 0.5)
    navText:SetText(L.NAV_INACTIVE)
    panel.navText = navText
    panel.navStatus = navStatus

    -- ============================================================
    -- Scroll area for route list
    -- ============================================================
    local scrollFrame = CreateFrame("ScrollFrame", "MeridianRouteScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", BAR_INSET, -(HEADER_HEIGHT + 34))
    scrollFrame:SetPoint("BOTTOMRIGHT", -BAR_INSET - 18, FOOTER_HEIGHT)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(PANEL_WIDTH - BAR_INSET * 2 - 18)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollContent = scrollContent

    -- ============================================================
    -- Footer — Navigation buttons
    -- ============================================================
    local btnWidth = (PANEL_WIDTH - BAR_INSET * 2 - 12) / 3

    -- Start / Stop button
    local btnStart = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnStart:SetSize(btnWidth, 26)
    btnStart:SetPoint("BOTTOMLEFT", BAR_INSET, 44)
    btnStart:SetText(L.NAV_START)
    btnStart:SetScript("OnClick", function()
        if RouteEngine:IsNavigating() then
            RouteEngine:StopNavigation()
        elseif selectedRoute then
            RouteEngine:StartNavigation(selectedRoute)
        end
        RoutePanel:RefreshList()
    end)
    panel.btnStart = btnStart

    -- Prev waypoint
    local btnPrev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnPrev:SetSize(btnWidth, 26)
    btnPrev:SetPoint("BOTTOM", panel, "BOTTOM", 0, 44)
    btnPrev:SetText("<< " .. L.NAV_PREV)
    btnPrev:SetScript("OnClick", function()
        RouteEngine:PrevWaypoint()
    end)
    panel.btnPrev = btnPrev

    -- Next waypoint
    local btnNext = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnNext:SetSize(btnWidth, 26)
    btnNext:SetPoint("BOTTOMRIGHT", -BAR_INSET, 44)
    btnNext:SetText(L.NAV_NEXT .. " >>")
    btnNext:SetScript("OnClick", function()
        RouteEngine:NextWaypoint()
    end)
    panel.btnNext = btnNext

    -- Import button
    local btnImport = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnImport:SetSize((PANEL_WIDTH - BAR_INSET * 2 - 6) / 2, 26)
    btnImport:SetPoint("BOTTOMLEFT", BAR_INSET, 14)
    btnImport:SetText(L.ROUTE_IMPORT)
    btnImport:SetScript("OnClick", function()
        RoutePanel:ShowImportWindow()
    end)

    -- Delete button
    local btnDelete = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDelete:SetSize((PANEL_WIDTH - BAR_INSET * 2 - 6) / 2, 26)
    btnDelete:SetPoint("BOTTOMRIGHT", -BAR_INSET, 14)
    btnDelete:SetText(L.ROUTE_DELETE)
    btnDelete:SetScript("OnClick", function()
        if selectedRoute then
            RouteEngine:DeleteRoute(selectedRoute)
            selectedRoute = nil
            RoutePanel:RefreshList()
        end
    end)

    table.insert(UISpecialFrames, "MeridianRoutePanel")

    panel:Hide()
    return panel
end

-- ============================================================
-- Refresh route list
-- ============================================================
function RoutePanel:RefreshList()
    if not panel or not panel:IsShown() then return end

    local names = RouteEngine:GetRouteNames()

    -- Hide all
    for _, btn in ipairs(routeButtons) do btn:Hide() end

    if #names == 0 then
        panel.headerSub:SetText(L.NO_ROUTES)
    else
        panel.headerSub:SetText(format(L.ROUTES_COUNT, #names))
    end

    local contentWidth = scrollContent:GetWidth()
    local isNav = RouteEngine:IsNavigating()
    local activeRoute = RouteEngine:GetActiveRoute()

    for i, name in ipairs(names) do
        if not routeButtons[i] then
            routeButtons[i] = CreateRouteButton(scrollContent, i)
        end

        local btn = routeButtons[i]
        local route = RouteEngine:GetRoute(name)
        btn.routeName = name
        btn:SetWidth(contentWidth)
        btn:SetPoint("TOPLEFT", 0, -((i - 1) * (BAR_HEIGHT + BAR_SPACING)))

        -- Filter icon
        local fc = FILTER_COLORS[route.filter] or FILTER_COLORS.ALL
        if route.filter == "HERB" then
            btn.icon:SetText("|cff2ecc71" .. L.ICON_HERB .. "|r")
        elseif route.filter == "ORE" then
            btn.icon:SetText("|cfff39c12" .. L.ICON_ORE .. "|r")
        else
            btn.icon:SetText("|cffe6cb32" .. L.ICON_ALL .. "|r")
        end

        btn.label:SetText(name)
        btn.info:SetText(format("%dpts", #route.waypoints))

        -- Selection / active highlight
        if isNav and activeRoute and activeRoute.name == name then
            btn.bg:SetColorTexture(0.2, 0.9, 0.4, 0.2)
            btn.label:SetTextColor(0.2, 0.9, 0.4)
        elseif selectedRoute == name then
            btn.bg:SetColorTexture(fc[1], fc[2], fc[3], 0.15)
            btn.label:SetTextColor(fc[1], fc[2], fc[3])
        else
            btn.bg:SetColorTexture(0.15, 0.15, 0.20, 0.8)
            btn.label:SetTextColor(1, 1, 1)
        end

        btn:Show()
    end

    scrollContent:SetHeight(#names * (BAR_HEIGHT + BAR_SPACING))

    -- Update nav buttons
    if isNav then
        panel.btnStart:SetText(L.NAV_STOP)
        local wp = RouteEngine:GetCurrentWaypoint()
        local idx = RouteEngine:GetCurrentWaypointIndex()
        local total = RouteEngine:GetTotalWaypoints()
        panel.navText:SetText(format("|cff2ecc71" .. L.NAV_ACTIVE .. "|r  %d/%d", idx, total))
    else
        panel.btnStart:SetText(L.NAV_START)
        panel.navText:SetText(L.NAV_INACTIVE)
    end
end

-- ============================================================
-- Import Window
-- ============================================================
local importFrame = nil

function RoutePanel:ShowImportWindow()
    if not importFrame then
        importFrame = CreateFrame("Frame", "MeridianImportFrame", UIParent, "BackdropTemplate")
        importFrame:SetSize(500, 400)
        importFrame:SetPoint("CENTER")
        importFrame:SetFrameStrata("DIALOG")
        importFrame:SetMovable(true)
        importFrame:EnableMouse(true)
        importFrame:RegisterForDrag("LeftButton")
        importFrame:SetScript("OnDragStart", importFrame.StartMoving)
        importFrame:SetScript("OnDragStop", importFrame.StopMovingOrSizing)

        importFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        importFrame:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        importFrame:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)

        -- Title
        local title = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText(L.IMPORT_TITLE)
        title:SetTextColor(0.9, 0.8, 0.2)

        -- Instructions
        local instr = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instr:SetPoint("TOPLEFT", 16, -36)
        instr:SetPoint("TOPRIGHT", -16, -36)
        instr:SetText(L.IMPORT_INSTRUCTIONS)
        instr:SetTextColor(0.7, 0.7, 0.7)
        instr:SetJustifyH("LEFT")

        -- Close button
        local closeBtn = CreateFrame("Button", nil, importFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)

        -- Name input
        local nameLabel = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLabel:SetPoint("TOPLEFT", 16, -64)
        nameLabel:SetText(L.IMPORT_NAME)
        nameLabel:SetTextColor(0.8, 0.8, 0.8)

        local nameBox = CreateFrame("EditBox", nil, importFrame, "InputBoxTemplate")
        nameBox:SetSize(200, 22)
        nameBox:SetPoint("TOPLEFT", 100, -60)
        nameBox:SetAutoFocus(false)
        importFrame.nameBox = nameBox

        -- Filter dropdown label
        local filterLabel = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        filterLabel:SetPoint("TOPLEFT", 310, -64)
        filterLabel:SetText(L.IMPORT_FILTER)
        filterLabel:SetTextColor(0.8, 0.8, 0.8)

        -- Simple filter cycle button
        local filterBtn = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
        filterBtn:SetSize(60, 22)
        filterBtn:SetPoint("TOPLEFT", 360, -60)
        filterBtn:SetText("ALL")
        importFrame.filterBtn = filterBtn
        importFrame.filterValue = "ALL"
        filterBtn:SetScript("OnClick", function(self)
            if importFrame.filterValue == "ALL" then
                importFrame.filterValue = "HERB"
            elseif importFrame.filterValue == "HERB" then
                importFrame.filterValue = "ORE"
            else
                importFrame.filterValue = "ALL"
            end
            self:SetText(importFrame.filterValue)
        end)

        -- Scroll area for JSON
        local scrollFrame = CreateFrame("ScrollFrame", "MeridianImportScroll", importFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 12, -90)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 44)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetWidth(scrollFrame:GetWidth() or 440)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        importFrame.editBox = editBox

        -- Import button
        local importBtn = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
        importBtn:SetSize(160, 26)
        importBtn:SetPoint("BOTTOM", 0, 12)
        importBtn:SetText(L.IMPORT_CONFIRM)
        importBtn:SetScript("OnClick", function()
            RoutePanel:DoImport()
        end)

        -- Status
        local status = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("BOTTOMLEFT", 16, 16)
        status:SetTextColor(0.6, 0.6, 0.6)
        importFrame.status = status

        table.insert(UISpecialFrames, "MeridianImportFrame")
    end

    importFrame.editBox:SetText("")
    importFrame.nameBox:SetText("")
    importFrame.filterValue = "ALL"
    importFrame.filterBtn:SetText("ALL")
    importFrame.status:SetText("")
    importFrame:Show()
end

-- ============================================================
-- JSON Parser (minimal, pour les waypoints)
-- ============================================================
local function ParseWaypointsJSON(text)
    -- Nettoyer le texte
    text = text:match("%[.-%]")
    if not text then return nil, L.IMPORT_ERR_FORMAT end

    local waypoints = {}
    -- Pattern pour chaque waypoint object
    for obj in text:gmatch("{(.-)}") do
        local wp = {}
        wp.order = tonumber(obj:match('"order"%s*:%s*(%d+)'))
        wp.x = tonumber(obj:match('"x"%s*:%s*([%d%.]+)'))
        wp.y = tonumber(obj:match('"y"%s*:%s*([%d%.]+)'))
        wp.label = obj:match('"label"%s*:%s*"(.-)"')
                or obj:match('"note"%s*:%s*"(.-)"')
                or ("WP" .. (#waypoints + 1))

        if wp.x and wp.y then
            waypoints[#waypoints + 1] = wp
        end
    end

    if #waypoints == 0 then
        return nil, L.IMPORT_ERR_EMPTY
    end

    -- Sort by order if present
    table.sort(waypoints, function(a, b)
        return (a.order or 0) < (b.order or 0)
    end)

    return waypoints
end

-- ============================================================
-- Do the import
-- ============================================================
function RoutePanel:DoImport()
    if not importFrame then return end

    local name = importFrame.nameBox:GetText()
    if not name or name:match("^%s*$") then
        importFrame.status:SetText("|cffff0000" .. L.IMPORT_ERR_NAME .. "|r")
        return
    end

    local text = importFrame.editBox:GetText()
    if not text or text:match("^%s*$") then
        importFrame.status:SetText("|cffff0000" .. L.IMPORT_ERR_FORMAT .. "|r")
        return
    end

    local waypoints, err = ParseWaypointsJSON(text)
    if not waypoints then
        importFrame.status:SetText("|cffff0000" .. (err or L.IMPORT_ERR_FORMAT) .. "|r")
        return
    end

    -- mapID courant du joueur
    local mapID = C_Map.GetBestMapForUnit("player") or 0
    local filter = importFrame.filterValue

    RouteEngine:SaveRoute(name, mapID, filter, waypoints)

    importFrame.status:SetText(format("|cff2ecc71" .. L.IMPORT_SUCCESS .. "|r", #waypoints))
    Meridian:Msg(format(L.IMPORT_SUCCESS, #waypoints))

    C_Timer.After(1.0, function()
        importFrame:Hide()
        selectedRoute = name
        RoutePanel:RefreshList()
    end)
end

-- ============================================================
-- Show / Hide / Toggle
-- ============================================================
function RoutePanel:Show()
    if not panel then self:CreatePanel() end
    self:RefreshList()
    panel:Show()
end

function RoutePanel:Hide()
    if panel then panel:Hide() end
end

function RoutePanel:Toggle()
    if not panel then self:CreatePanel() end
    if panel:IsShown() then
        panel:Hide()
    else
        self:RefreshList()
        panel:Show()
    end
end

function RoutePanel:IsShown()
    return panel and panel:IsShown()
end

-- ============================================================
-- Callbacks
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    RoutePanel:CreatePanel()
end)

Meridian:RegisterCallback("TOGGLE_ROUTES", function()
    RoutePanel:Toggle()
end)

Meridian:RegisterCallback("NAV_STARTED", function()
    RoutePanel:RefreshList()
end)

Meridian:RegisterCallback("NAV_STOPPED", function()
    RoutePanel:RefreshList()
end)

Meridian:RegisterCallback("NAV_WAYPOINT_CHANGED", function()
    RoutePanel:RefreshList()
end)

Meridian:RegisterCallback("ROUTES_UPDATED", function()
    RoutePanel:RefreshList()
end)

Meridian:RegisterCallback("DATA_RESET", function()
    selectedRoute = nil
    RoutePanel:RefreshList()
end)
