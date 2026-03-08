-- ============================================================
-- Meridian — Stats Panel (100% Native)
-- Design language: Google Glimmer — gradient translucent surface,
-- luminous white content, glow-trail bars, depth via hierarchy.
-- WoW API 12.0.1 (Midnight). No external libs.
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
-- Layout constants
-- ============================================================
local PANEL_WIDTH   = 310
local PANEL_HEIGHT  = 400
local BAR_HEIGHT    = 22
local BAR_SPACING   = 6
local BAR_INSET     = 14
local HEADER_HEIGHT = 50
local TAB_HEIGHT    = 30
local FOOTER_HEIGHT = 54

-- ============================================================
-- Glimmer palette — desaturated, readable on gradient darks
-- ============================================================
local COLOR_PALETTE = {
    { 0.25, 0.78, 0.55 },  -- mint
    { 0.88, 0.62, 0.28 },  -- amber
    { 0.35, 0.62, 0.88 },  -- sky
    { 0.85, 0.38, 0.38 },  -- rose
    { 0.60, 0.42, 0.78 },  -- lavender
    { 0.22, 0.72, 0.68 },  -- teal
    { 0.88, 0.76, 0.28 },  -- gold
    { 0.82, 0.42, 0.62 },  -- dusty pink
}

-- ============================================================
-- State
-- ============================================================
local panel       = nil
local activeTab   = "ORE"
local scrollContent = nil
local barFrames   = {}

-- ============================================================
-- Bar widget
-- ============================================================
local function CreateBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(BAR_HEIGHT)

    -- Track: almost invisible, just enough to hint at the full width
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.05)
    bar.bg = bg

    -- Glimmer fill: solid color on left → transparent on right (glow trail)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetHeight(BAR_HEIGHT)
    bar.fill = fill

    -- Label: bright white, primary hierarchy
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 8, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(1, 1, 1, 0.92)
    bar.label = label

    -- Count: dim, secondary hierarchy
    local count = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("RIGHT", -8, 0)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(0.60, 0.60, 0.65, 1)
    bar.count = count

    return bar
end

local function SetBarData(bar, name, value, maxValue, colorIndex)
    local c = COLOR_PALETTE[((colorIndex - 1) % #COLOR_PALETTE) + 1]
    bar.label:SetText(name)
    bar.count:SetText(tostring(value))

    local pct = maxValue > 0 and (value / maxValue) or 0
    local w   = math_max(4, (bar:GetWidth() or (PANEL_WIDTH - BAR_INSET * 2)) * pct)
    bar.fill:SetWidth(w)
    -- Glimmer glow trail: full color → almost transparent
    bar.fill:SetGradient("HORIZONTAL",
        CreateColor(c[1], c[2], c[3], 0.75),
        CreateColor(c[1], c[2], c[3], 0.08)
    )
    bar:Show()
end

-- ============================================================
-- Panel creation
-- ============================================================
function StatsPanel:CreatePanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "MeridianStatsPanel", UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)

    -- ── Glimmer background ─────────────────────────────────
    -- Primary gradient: deep purple left → dark navy right
    local bgTex = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bgTex:SetAllPoints()
    bgTex:SetGradient("HORIZONTAL",
        CreateColor(0.14, 0.09, 0.22, 0.91),
        CreateColor(0.05, 0.06, 0.13, 0.93)
    )
    -- Secondary vignette: slightly brighter at top, fading down
    local vignette = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    vignette:SetPoint("TOPLEFT")
    vignette:SetPoint("TOPRIGHT")
    vignette:SetHeight(PANEL_HEIGHT * 0.45)
    vignette:SetGradient("VERTICAL",
        CreateColor(1, 1, 1, 0.04),
        CreateColor(1, 1, 1, 0.00)
    )

    -- ── 1px border (Glimmer: barely-there, just defines shape) ─
    local function MakeBorder(point1, point2, isHoriz)
        local t = panel:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.10)
        if isHoriz then
            t:SetHeight(1)
            t:SetPoint(point1)
            t:SetPoint(point2)
        else
            t:SetWidth(1)
            t:SetPoint(point1)
            t:SetPoint(point2)
        end
    end
    MakeBorder("TOPLEFT",    "TOPRIGHT",    true)
    MakeBorder("BOTTOMLEFT", "BOTTOMRIGHT", true)
    MakeBorder("TOPLEFT",    "BOTTOMLEFT",  false)
    MakeBorder("TOPRIGHT",   "BOTTOMRIGHT", false)

    -- ── Header ─────────────────────────────────────────────
    local headerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitle:SetPoint("TOPLEFT", 16, -14)
    headerTitle:SetText("Meridian")
    headerTitle:SetTextColor(1, 1, 1, 1)
    panel.headerTitle = headerTitle

    local headerSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSub:SetPoint("TOPRIGHT", -36, -18)
    headerSub:SetTextColor(0.48, 0.48, 0.54, 1)
    panel.headerSub = headerSub

    -- Header separator
    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT",  0, -HEADER_HEIGHT)
    headerLine:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT)
    headerLine:SetGradient("HORIZONTAL",
        CreateColor(1, 1, 1, 0.00),
        CreateColor(1, 1, 1, 0.12)
    )

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(22, 22)

    -- ── Tabs (ORE / HERB only) ──────────────────────────────
    local tabWidth = (PANEL_WIDTH - BAR_INSET * 2 - 2) / 2
    local tabY     = -(HEADER_HEIGHT + 1)

    local function CreateTab(text, xOff, tabKey)
        local tab = CreateFrame("Button", nil, panel)
        tab:SetSize(tabWidth, TAB_HEIGHT)
        tab:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, tabY)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        tab.bg = bg

        -- Glimmer focus underline
        local line = tab:CreateTexture(nil, "ARTWORK")
        line:SetHeight(2)
        line:SetPoint("BOTTOMLEFT",  3, 0)
        line:SetPoint("BOTTOMRIGHT", -3, 0)
        tab.focusLine = line

        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER", 0, 1)
        label:SetText(text)
        tab.label = label

        tab:SetScript("OnClick", function()
            activeTab = tabKey
            StatsPanel:UpdateTabs()
            StatsPanel:RefreshBars()
        end)

        tab.tabKey = tabKey
        return tab
    end

    panel.tabOre  = CreateTab(L.TAB_ORES,  BAR_INSET,                   "ORE")
    panel.tabHerb = CreateTab(L.TAB_HERBS, BAR_INSET + tabWidth + 2,    "HERB")

    -- Tab separator line
    local tabLine = panel:CreateTexture(nil, "ARTWORK")
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT",  0, -(HEADER_HEIGHT + TAB_HEIGHT + 1))
    tabLine:SetPoint("TOPRIGHT", 0, -(HEADER_HEIGHT + TAB_HEIGHT + 1))
    tabLine:SetColorTexture(1, 1, 1, 0.07)

    -- ── Scroll area ─────────────────────────────────────────
    local scrollFrame = CreateFrame("ScrollFrame", "MeridianStatsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     BAR_INSET,      -(HEADER_HEIGHT + TAB_HEIGHT + 8))
    scrollFrame:SetPoint("BOTTOMRIGHT", -BAR_INSET - 18,  FOOTER_HEIGHT)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(PANEL_WIDTH - BAR_INSET * 2 - 18)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollContent = scrollContent

    -- ── Footer ──────────────────────────────────────────────
    local footerLine = panel:CreateTexture(nil, "ARTWORK")
    footerLine:SetHeight(1)
    footerLine:SetPoint("BOTTOMLEFT",  0, FOOTER_HEIGHT)
    footerLine:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)
    footerLine:SetGradient("HORIZONTAL",
        CreateColor(1, 1, 1, 0.12),
        CreateColor(1, 1, 1, 0.00)
    )

    local btnW = (PANEL_WIDTH - BAR_INSET * 2 - 6) / 2

    local btnAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAll:SetSize(btnW, 26)
    btnAll:SetPoint("BOTTOMLEFT", BAR_INSET, 14)
    btnAll:SetText(L.EXPORT_ALL)
    btnAll:SetScript("OnClick", function()
        if ns.Export then ns.Export:ExportAll() end
    end)

    local btnZone = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnZone:SetSize(btnW, 26)
    btnZone:SetPoint("BOTTOMRIGHT", -BAR_INSET, 14)
    btnZone:SetText(L.EXPORT_ZONE)
    btnZone:SetScript("OnClick", function()
        if ns.Export then ns.Export:ExportZone() end
    end)

    table.insert(UISpecialFrames, "MeridianStatsPanel")

    self:UpdateTabs()
    panel:Hide()
    return panel
end

-- ============================================================
-- Tab visual state (Glimmer: focus gains depth + underline)
-- ============================================================
function StatsPanel:UpdateTabs()
    if not panel then return end

    local function setActive(tab, c)
        tab.bg:SetGradient("HORIZONTAL",
            CreateColor(c[1], c[2], c[3], 0.18),
            CreateColor(c[1], c[2], c[3], 0.04)
        )
        tab.focusLine:SetGradient("HORIZONTAL",
            CreateColor(c[1], c[2], c[3], 1.00),
            CreateColor(c[1], c[2], c[3], 0.25)
        )
        tab.label:SetTextColor(1, 1, 1, 1)
    end

    local function setInactive(tab)
        tab.bg:SetColorTexture(1, 1, 1, 0.00)
        tab.focusLine:SetColorTexture(1, 1, 1, 0.00)
        tab.label:SetTextColor(0.42, 0.42, 0.48, 1)
    end

    if activeTab == "ORE" then
        setActive(panel.tabOre,  { 0.88, 0.62, 0.28 })  -- amber
        setInactive(panel.tabHerb)
    else
        setActive(panel.tabHerb, { 0.25, 0.78, 0.55 })  -- mint
        setInactive(panel.tabOre)
    end
end

-- ============================================================
-- Refresh bars
-- ============================================================
function StatsPanel:RefreshBars()
    if not panel or not panel:IsShown() then return end
    if not Database then return end

    local resources = Database:GetKnownResourcesByType(activeTab)

    for _, bar in ipairs(barFrames) do bar:Hide() end

    if #resources == 0 then
        panel.headerSub:SetText(L.NO_DATA)
        return
    end

    table.sort(resources, function(a, b) return a.count > b.count end)

    local maxCount = resources[1].count
    panel.headerSub:SetText(format(L.TOTAL_NODES, Database:GetTotalNodeCount()))

    local contentWidth = scrollContent:GetWidth()

    for i, res in ipairs(resources) do
        if not barFrames[i] then
            barFrames[i] = CreateBar(scrollContent)
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
    if not panel then self:CreatePanel() end
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
-- Callbacks
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
local PANEL_WIDTH  = 320
local PANEL_HEIGHT = 420
local BAR_HEIGHT   = 20
local BAR_SPACING  = 5
local BAR_INSET    = 14
local HEADER_HEIGHT = 52
local TAB_HEIGHT   = 28
local FOOTER_HEIGHT = 56

-- ============================================================
-- Glimmer palette — desaturated, pastel-shifted for readability
-- on transparent AR-style backgrounds
-- ============================================================
local COLOR_PALETTE = {
    { 0.25, 0.78, 0.55 },  -- mint green
    { 0.88, 0.62, 0.28 },  -- warm amber
    { 0.35, 0.62, 0.88 },  -- soft blue
    { 0.85, 0.38, 0.38 },  -- muted red
    { 0.60, 0.42, 0.78 },  -- lavender
    { 0.22, 0.72, 0.68 },  -- teal
    { 0.88, 0.76, 0.28 },  -- soft gold
    { 0.82, 0.42, 0.62 },  -- dusty rose
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
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(BAR_HEIGHT)

    -- Glimmer: dark translucent track
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.04)
    bar.bg = bg

    -- Glimmer: luminous fill, softly saturated
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", 0, 0)
    fill:SetHeight(BAR_HEIGHT)
    bar.fill = fill

    -- Glimmer: white content on dark surface
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 8, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.95, 0.95, 0.95, 1)
    bar.label = label

    local count = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("RIGHT", -8, 0)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(0.65, 0.65, 0.70, 1)
    bar.count = count

    return bar
end

local function SetBarData(bar, name, value, maxValue, colorIndex)
    local color = COLOR_PALETTE[((colorIndex - 1) % #COLOR_PALETTE) + 1]
    bar.label:SetText(name)
    bar.count:SetText(tostring(value))

    local pct = maxValue > 0 and (value / maxValue) or 0
    bar.fill:SetWidth(math_max(1, (bar:GetWidth() or (PANEL_WIDTH - BAR_INSET * 2)) * pct))
    -- Glimmer: fill color with moderate alpha so the dark surface shows through
    bar.fill:SetColorTexture(color[1], color[2], color[3], 0.55)
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
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    -- Glimmer: near-black, high-alpha translucent surface
    panel:SetBackdropColor(0.04, 0.04, 0.07, 0.85)
    -- Glimmer: very subtle 1px border, just enough to define the shape
    panel:SetBackdropBorderColor(1, 1, 1, 0.06)

    -- Glimmer: thin luminous separator under the header
    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", 0, -(HEADER_HEIGHT))
    headerLine:SetPoint("TOPRIGHT", 0, -(HEADER_HEIGHT))
    headerLine:SetColorTexture(1, 1, 1, 0.08)

    -- Header — title: bright white, high weight
    local headerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitle:SetPoint("TOPLEFT", 16, -15)
    headerTitle:SetText("Meridian")
    headerTitle:SetTextColor(1, 1, 1, 1)
    panel.headerTitle = headerTitle

    -- Header — subtitle: dim, secondary hierarchy
    local headerSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSub:SetPoint("TOPRIGHT", -36, -18)
    headerSub:SetTextColor(0.50, 0.50, 0.55, 1)
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

        -- Glimmer: dark surface tab, gains depth on focus
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        tab.bg = bg

        -- Glimmer: bottom border line to signal focus
        local focusLine = tab:CreateTexture(nil, "ARTWORK")
        focusLine:SetHeight(2)
        focusLine:SetPoint("BOTTOMLEFT", 4, 0)
        focusLine:SetPoint("BOTTOMRIGHT", -4, 0)
        focusLine:SetColorTexture(1, 1, 1, 0)
        tab.focusLine = focusLine

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
    -- Footer — thin separator + Export buttons
    -- ============================================================
    local footerLine = panel:CreateTexture(nil, "ARTWORK")
    footerLine:SetHeight(1)
    footerLine:SetPoint("BOTTOMLEFT", 0, FOOTER_HEIGHT)
    footerLine:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)
    footerLine:SetColorTexture(1, 1, 1, 0.08)

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
    local ore   = panel.tabOre
    local herb  = panel.tabHerb
    local routes = panel.tabRoutes

    -- Glimmer: active tab → surface gains depth (brighter bg), bright label, luminous underline
    -- Inactive tabs → near-invisible bg, dim label
    local function setActive(tab, color)
        tab.bg:SetColorTexture(color[1], color[2], color[3], 0.15)
        tab.focusLine:SetColorTexture(color[1], color[2], color[3], 0.9)
        tab.label:SetTextColor(1, 1, 1, 1)
    end
    local function setInactive(tab)
        tab.bg:SetColorTexture(1, 1, 1, 0.02)
        tab.focusLine:SetColorTexture(1, 1, 1, 0)
        tab.label:SetTextColor(0.45, 0.45, 0.50, 1)
    end

    -- Routes tab: always soft blue, unfocused
    setInactive(routes)
    routes.bg:SetColorTexture(0.35, 0.62, 0.88, 0.08)
    routes.focusLine:SetColorTexture(0.35, 0.62, 0.88, 0.5)
    routes.label:SetTextColor(0.55, 0.72, 0.92, 1)

    if activeTab == "ORE" then
        setActive(ore,  { 0.88, 0.62, 0.28 })  -- amber
        setInactive(herb)
    else
        setActive(herb, { 0.25, 0.78, 0.55 })  -- mint
        setInactive(ore)
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
