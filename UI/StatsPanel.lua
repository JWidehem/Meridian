-- ============================================================
-- Meridian â€” Stats Panel (100% Native)
-- Design language: Google Glimmer â€” gradient translucent surface,
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
local FOOTER_HEIGHT = 44

-- ============================================================
-- Glimmer palette â€” desaturated, readable on gradient darks
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

    -- Glimmer fill: solid color on left â†’ transparent on right (glow trail)
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
    -- Glimmer glow trail: full color â†’ almost transparent
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

    -- â”€â”€ Glimmer glass surface â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Near-black, semi-transparent: the game world shows through.
    -- No color â€” Glimmer has no background color of its own.
    -- The "colors" seen in Glimmer screenshots are the environment
    -- bleeding through the translucent surface, not the UI itself.
    local bgTex = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0.02, 0.02, 0.03, 0.68)

    -- â”€â”€ 1px border (Glimmer: barely-there, just defines shape) â”€
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

    -- â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local headerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitle:SetPoint("TOPLEFT", 16, -14)
    headerTitle:SetText("Meridian")
    headerTitle:SetTextColor(1, 1, 1, 1)
    panel.headerTitle = headerTitle

    local headerSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSub:SetPoint("TOPRIGHT", -36, -18)
    headerSub:SetTextColor(0.48, 0.48, 0.54, 1)
    panel.headerSub = headerSub

    -- Header separator: neutral white, very dim
    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT",  0, -HEADER_HEIGHT)
    headerLine:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT)
    headerLine:SetColorTexture(1, 1, 1, 0.10)

    -- Glimmer close: plain × character, no WoW chrome
    local closeBtn = CreateFrame("Button", nil, panel)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    local closeTex = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeTex:SetPoint("CENTER")
    closeTex:SetText("\195\151")  -- × character
    closeTex:SetTextColor(1, 1, 1, 0.45)
    closeBtn:SetScript("OnEnter", function() closeTex:SetTextColor(1, 1, 1, 0.95) end)
    closeBtn:SetScript("OnLeave", function() closeTex:SetTextColor(1, 1, 1, 0.45) end)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- â”€â”€ Tabs (ORE / HERB only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ Scroll area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local scrollFrame = CreateFrame("ScrollFrame", "MeridianStatsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     BAR_INSET,      -(HEADER_HEIGHT + TAB_HEIGHT + 8))
    scrollFrame:SetPoint("BOTTOMRIGHT", -BAR_INSET - 18,  FOOTER_HEIGHT)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(PANEL_WIDTH - BAR_INSET * 2 - 18)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollContent = scrollContent

    -- â”€â”€ Footer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local footerLine = panel:CreateTexture(nil, "ARTWORK")
    footerLine:SetHeight(1)
    footerLine:SetPoint("BOTTOMLEFT",  0, FOOTER_HEIGHT)
    footerLine:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)
    footerLine:SetColorTexture(1, 1, 1, 0.10)

    -- Single centered export button
    local btnAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAll:SetSize(PANEL_WIDTH - BAR_INSET * 4, 26)
    btnAll:SetPoint("BOTTOM", panel, "BOTTOM", 0, 9)
    btnAll:SetText(L.EXPORT_ALL)
    btnAll:SetScript("OnClick", function()
        if ns.Export then ns.Export:ExportAll() end
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

