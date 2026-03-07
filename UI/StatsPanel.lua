-- ============================================================
-- Meridian — Stats Panel (100% Native)
-- Dark macOS-style window : Ores/Herbs tabs, colored bars,
-- export buttons. Design reference: user mockup image.
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local Database = ns.Database
local L = ns.L

local StatsPanel = {}
ns.StatsPanel = StatsPanel

local format = string.format
local math_max = math.max

-- ============================================================
-- Constants
-- ============================================================
local PANEL_WIDTH = 320
local PANEL_HEIGHT = 420
local BAR_HEIGHT = 22
local BAR_SPACING = 4
local BAR_INSET = 12
local HEADER_HEIGHT = 50
local TAB_HEIGHT = 30
local FOOTER_HEIGHT = 56

-- ============================================================
-- Color palette (matches Database.lua)
-- ============================================================
local COLOR_PALETTE = {
    { 0.18, 0.80, 0.44 },  -- emerald
    { 0.95, 0.61, 0.07 },  -- orange
    { 0.20, 0.60, 0.86 },  -- blue
    { 0.91, 0.30, 0.24 },  -- red
    { 0.61, 0.35, 0.71 },  -- purple
    { 0.10, 0.74, 0.61 },  -- teal
    { 0.94, 0.76, 0.06 },  -- yellow
    { 0.83, 0.33, 0.42 },  -- pink
}

-- ============================================================
-- State
-- ============================================================
local panel = nil
local activeTab = "ORE"
local scrollContent = nil
local barFrames = {}

-- ============================================================
-- CreatePanel
-- ============================================================
local function CreateBar(parent, index)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetHeight(BAR_HEIGHT)

    -- Background bar
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.20, 0.8)
    bar.bg = bg

    -- Colored fill
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", 0, 0)
    fill:SetHeight(BAR_HEIGHT)
    bar.fill = fill

    -- Name text
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(1, 1, 1)
    bar.label = label

    -- Count text
    local count = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("RIGHT", -6, 0)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(0.8, 0.8, 0.8)
    bar.count = count

    return bar
end

local function SetBarData(bar, name, value, maxValue, colorIndex)
    local color = COLOR_PALETTE[((colorIndex - 1) % #COLOR_PALETTE) + 1]
    bar.label:SetText(name)
    bar.count:SetText(tostring(value))

    local pct = maxValue > 0 and (value / maxValue) or 0
    bar.fill:SetWidth(math_max(1, (bar:GetWidth() or (PANEL_WIDTH - BAR_INSET * 2)) * pct))
    bar.fill:SetColorTexture(color[1], color[2], color[3], 0.7)
    bar:Show()
end

function StatsPanel:CreatePanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "MeridianStatsPanel", UIParent, "BackdropTemplate")
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
    headerTitle:SetText("Meridian")
    headerTitle:SetTextColor(0.9, 0.8, 0.2)
    panel.headerTitle = headerTitle

    local headerSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSub:SetPoint("TOPRIGHT", -14, -18)
    headerSub:SetTextColor(0.6, 0.6, 0.6)
    panel.headerSub = headerSub

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(22, 22)

    -- ============================================================
    -- Tabs
    -- ============================================================
    local tabWidth = (PANEL_WIDTH - BAR_INSET * 2 - 4) / 3

    local function CreateTab(parent, text, xOff, tabKey)
        local tab = CreateFrame("Button", nil, parent)
        tab:SetSize(tabWidth, TAB_HEIGHT)
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, -(HEADER_HEIGHT + 2))

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        tab.bg = bg

        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetText(text)
        tab.label = label

        tab:SetScript("OnClick", function()
            if tabKey == "ROUTES" then
                if ns.RoutePanel then
                    ns.RoutePanel:Toggle()
                end
                return
            end
            activeTab = tabKey
            StatsPanel:UpdateTabs()
            StatsPanel:RefreshBars()
        end)

        tab.tabKey = tabKey
        return tab
    end

    local x0 = BAR_INSET
    local tabOre = CreateTab(panel, L.TAB_ORES, x0, "ORE")
    local tabHerb = CreateTab(panel, L.TAB_HERBS, x0 + tabWidth + 2, "HERB")
    local tabRoutes = CreateTab(panel, L.TAB_ROUTES, x0 + (tabWidth + 2) * 2, "ROUTES")
    panel.tabOre = tabOre
    panel.tabHerb = tabHerb
    panel.tabRoutes = tabRoutes

    -- ============================================================
    -- Scroll area for bars
    -- ============================================================
    local scrollFrame = CreateFrame("ScrollFrame", "MeridianStatsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", BAR_INSET, -(HEADER_HEIGHT + TAB_HEIGHT + 8))
    scrollFrame:SetPoint("BOTTOMRIGHT", -BAR_INSET - 18, FOOTER_HEIGHT)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(PANEL_WIDTH - BAR_INSET * 2 - 18)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollContent = scrollContent

    -- ============================================================
    -- Footer — Export buttons
    -- ============================================================
    local btnWidth = (PANEL_WIDTH - BAR_INSET * 2 - 6) / 2

    local btnExportAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnExportAll:SetSize(btnWidth, 26)
    btnExportAll:SetPoint("BOTTOMLEFT", BAR_INSET, 14)
    btnExportAll:SetText(L.EXPORT_ALL)
    btnExportAll:SetScript("OnClick", function()
        if ns.Export then ns.Export:ExportAll() end
    end)

    local btnExportZone = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnExportZone:SetSize(btnWidth, 26)
    btnExportZone:SetPoint("BOTTOMRIGHT", -BAR_INSET, 14)
    btnExportZone:SetText(L.EXPORT_ZONE)
    btnExportZone:SetScript("OnClick", function()
        if ns.Export then ns.Export:ExportZone() end
    end)

    table.insert(UISpecialFrames, "MeridianStatsPanel")

    self:UpdateTabs()
    panel:Hide()
    return panel
end

-- ============================================================
-- Tab highlight
-- ============================================================
function StatsPanel:UpdateTabs()
    if not panel then return end
    local ore = panel.tabOre
    local herb = panel.tabHerb
    local routes = panel.tabRoutes

    -- Routes tab always same style (toggle button)
    routes.bg:SetColorTexture(0.20, 0.60, 0.86, 0.2)
    routes.label:SetTextColor(0.20, 0.60, 0.86)

    if activeTab == "ORE" then
        ore.bg:SetColorTexture(0.95, 0.61, 0.07, 0.3)
        ore.label:SetTextColor(0.95, 0.61, 0.07)
        herb.bg:SetColorTexture(0.15, 0.15, 0.20, 0.5)
        herb.label:SetTextColor(0.5, 0.5, 0.5)
    else
        herb.bg:SetColorTexture(0.18, 0.80, 0.44, 0.3)
        herb.label:SetTextColor(0.18, 0.80, 0.44)
        ore.bg:SetColorTexture(0.15, 0.15, 0.20, 0.5)
        ore.label:SetTextColor(0.5, 0.5, 0.5)
    end
end

-- ============================================================
-- Refresh bars with current data
-- ============================================================
function StatsPanel:RefreshBars()
    if not panel or not panel:IsShown() then return end
    if not Database then return end

    local resources = Database:GetKnownResourcesByType(activeTab)

    -- Hide all existing bars
    for _, bar in ipairs(barFrames) do
        bar:Hide()
    end

    if #resources == 0 then
        panel.headerSub:SetText(L.NO_DATA)
        return
    end

    -- Sort by count desc
    table.sort(resources, function(a, b) return a.count > b.count end)

    local maxCount = resources[1].count
    local totalNodes = Database:GetTotalNodeCount()
    panel.headerSub:SetText(format(L.TOTAL_NODES, totalNodes))

    local contentWidth = scrollContent:GetWidth()

    for i, res in ipairs(resources) do
        if not barFrames[i] then
            barFrames[i] = CreateBar(scrollContent, i)
        end

        local bar = barFrames[i]
        bar:SetWidth(contentWidth)
        bar:SetPoint("TOPLEFT", 0, -((i - 1) * (BAR_HEIGHT + BAR_SPACING)))
        SetBarData(bar, res.name, res.count, maxCount, i)
    end

    scrollContent:SetHeight(#resources * (BAR_HEIGHT + BAR_SPACING))
end

-- ============================================================
-- Show / Hide / Toggle
-- ============================================================
function StatsPanel:Show()
    if not panel then self:CreatePanel() end
    self:RefreshBars()
    panel:Show()
end

function StatsPanel:Hide()
    if panel then panel:Hide() end
end

function StatsPanel:Toggle()
    if not panel then
        self:CreatePanel()
    end
    if panel:IsShown() then
        panel:Hide()
    else
        self:RefreshBars()
        panel:Show()
    end
end

function StatsPanel:IsShown()
    return panel and panel:IsShown()
end

-- ============================================================
-- Auto-refresh on data changes
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    StatsPanel:CreatePanel()
end)

Meridian:RegisterCallback("TOGGLE_PANEL", function()
    StatsPanel:Toggle()
end)

Meridian:RegisterCallback("NODE_RECORDED", function()
    StatsPanel:RefreshBars()
end)

Meridian:RegisterCallback("RESOURCE_DISCOVERED", function()
    StatsPanel:RefreshBars()
end)

Meridian:RegisterCallback("DATA_RESET", function()
    StatsPanel:RefreshBars()
end)
