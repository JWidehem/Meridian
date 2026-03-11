-- ============================================================
-- Meridian -- MainPanel (100% Native, Glimmer Glass)
-- Design minimaliste deux sections : Oracle | Farm
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

local function DB()  return ns.Database end
local function ORA() return ns.Oracle   end
local function SES() return ns.Session  end

local MainPanel = {}
ns.MainPanel = MainPanel

local math_floor = math.floor
local format     = string.format

-- ============================================================
-- Layout
-- ============================================================
local PANEL_W     = 250
local PANEL_H     = 244
local PAD         = 14     -- padding horizontal
local HDR_H       = 24     -- hauteur zone header
local UPDATE_RATE = 1.0    -- refresh totaux (secondes)

-- Y-offsets des elements depuis le haut du content frame
local Y_CALC   =   0    -- bouton Analyser + date prix
local Y_S1     = -28    -- score zone 1
local Y_S2     = -46    -- score zone 2
local Y_ALT    = -72    -- bouton autre zone
local Y_SEP    = -100   -- separateur Oracle / Farm
local Y_ZONE   = -110   -- label zone active
local Y_HERB   = -132   -- ligne herbes
local Y_ORE    = -158   -- ligne minerais
-- resetBtn ancre BOTTOMRIGHT du content frame

-- Couleurs
local C_BEST  = { 0.25, 0.78, 0.55 }   -- mint  (meilleure zone)
local C_DIM   = { 0.55, 0.55, 0.60 }   -- gris  (autre zone / labels)
local C_HERB  = { 0.25, 0.78, 0.55 }   -- mint  (plantes)
local C_ORE   = { 0.88, 0.76, 0.28 }   -- gold  (minerais)
local C_WARN  = { 0.90, 0.58, 0.35 }   -- orange
local C_TITLE = { 0.85, 0.78, 0.45 }   -- doré titre

-- ============================================================
-- Helpers
-- ============================================================
local function GlimmerBorder(f)
    local function Edge(a1, a2, w, h)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.10)
        t:SetPoint(a1, f, a1)
        t:SetPoint(a2, f, a2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    Edge("TOPLEFT", "TOPRIGHT",    nil, 1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT", "BOTTOMLEFT",  1, nil)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

local function FS(parent, text, font, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetText(text or "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
end

-- Petit bouton Glimmer
local function Btn(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 90, h or 18)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.04, 0.04, 0.07, 0.72)
    GlimmerBorder(btn)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints(btn)
    lbl:SetText(text or "")
    lbl:SetTextColor(1, 1, 1, 0.72)
    btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnLeave", function() lbl:SetTextColor(1, 1, 1, 0.72) end)
    btn.label = lbl
    return btn
end

-- Ligne separatrice
local function HLine(parent, yOffset, alpha)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(1, 1, 1, alpha or 0.07)
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOffset)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    return t
end

-- Frame-ligne : name LEFT + gold RIGHT (pour scores et totaux)
local function TwoColRow(parent, yOffset, rowH, nameFont, goldFont)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowH or 16)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    local lfs = row:CreateFontString(nil, "OVERLAY", nameFont or "GameFontNormalSmall")
    lfs:SetPoint("LEFT",  row, "LEFT",  0, 0)
    lfs:SetPoint("RIGHT", row, "CENTER", 10, 0)
    lfs:SetJustifyH("LEFT")
    local rfs = row:CreateFontString(nil, "OVERLAY", goldFont or "GameFontNormalSmall")
    rfs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    rfs:SetJustifyH("RIGHT")
    return row, lfs, rfs
end

local function FormatGold(c) return ORA():FormatGold(c) end

-- ============================================================
-- Create
-- ============================================================
function MainPanel:Create()
    local frame = CreateFrame("Frame", "MeridianMainPanel", UIParent)
    frame:SetSize(PANEL_W, PANEL_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:Hide()
    self.frame = frame

    -- Fond sombre + bordure
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.03, 0.03, 0.05, 0.84)
    GlimmerBorder(frame)

    -- --------------------------------------------------------
    -- HEADER : logo M barre + close
    -- --------------------------------------------------------
    local logoM = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    logoM:SetText("M")
    logoM:SetTextColor(C_TITLE[1], C_TITLE[2], C_TITLE[3])
    logoM:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -3)

    -- Barre qui barre le M horizontalement (texture 2px au milieu du glyphe)
    local logoBar = frame:CreateTexture(nil, "OVERLAY")
    logoBar:SetColorTexture(C_TITLE[1], C_TITLE[2], C_TITLE[3], 0.88)
    logoBar:SetSize(18, 2)
    logoBar:SetPoint("LEFT", logoM, "LEFT", 0, -2)

    -- Bouton fermer (x discret)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeTxt:SetAllPoints(closeBtn)
    closeTxt:SetText("x")
    closeTxt:SetTextColor(0.50, 0.50, 0.50)
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(0.90, 0.90, 0.90) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(0.50, 0.50, 0.50) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Ligne sous le header (mint, subtile)
    local hdrLine = frame:CreateTexture(nil, "BORDER")
    hdrLine:SetColorTexture(0.56, 0.85, 0.72, 0.15)
    hdrLine:SetHeight(1)
    hdrLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -(HDR_H + 1))
    hdrLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(HDR_H + 1))

    -- --------------------------------------------------------
    -- CONTENT FRAME
    -- content top = -(HDR_H + 8) = -32 depuis le haut du frame
    -- --------------------------------------------------------
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",     frame, "TOPLEFT",     PAD,  -(HDR_H + 8))
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 14)
    self.content = content

    -- --------------------------------------------------------
    -- ORACLE : Row 1 -- bouton Analyser (LEFT) + date prix (RIGHT)
    -- --------------------------------------------------------
    local calcBtn = Btn(content, L.ORACLE_CALCULATE, 100, 20)
    calcBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, Y_CALC)
    calcBtn:SetScript("OnClick", function() MainPanel:OnCalcClick() end)
    self.calcBtn = calcBtn

    local priceDate = FS(content, "", "GameFontNormalSmall",
        C_DIM[1], C_DIM[2], C_DIM[3])
    priceDate:SetPoint("LEFT",   calcBtn, "RIGHT",   6, 0)
    priceDate:SetPoint("RIGHT",  content, "RIGHT",   0, 0)
    priceDate:SetPoint("TOP",    calcBtn, "TOP",      0, 0)
    priceDate:SetPoint("BOTTOM", calcBtn, "BOTTOM",   0, 0)
    priceDate:SetJustifyH("RIGHT")
    self.priceDate = priceDate

    -- --------------------------------------------------------
    -- ORACLE : Score rows (deux zones, trie meilleure en premier)
    -- --------------------------------------------------------
    local scoreRow1, scoreName1, scoreGold1 = TwoColRow(content, Y_S1, 16)
    local scoreRow2, scoreName2, scoreGold2 = TwoColRow(content, Y_S2, 16)
    self.scoreRow1, self.scoreName1, self.scoreGold1 = scoreRow1, scoreName1, scoreGold1
    self.scoreRow2, self.scoreName2, self.scoreGold2 = scoreRow2, scoreName2, scoreGold2

    -- --------------------------------------------------------
    -- ORACLE : Bouton autre zone (RIGHT, toujours visible si oracle calcule)
    -- --------------------------------------------------------
    local altBtn = Btn(content, L.ORACLE_CHOOSE_OTHER, 140, 18)
    altBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, Y_ALT)
    altBtn:SetScript("OnClick", function() MainPanel:OnAltZoneClick() end)
    altBtn:Hide()
    self.altBtn = altBtn

    -- --------------------------------------------------------
    -- Separateur Oracle / Farm
    -- --------------------------------------------------------
    HLine(content, Y_SEP)

    -- --------------------------------------------------------
    -- FARM : label zone active
    -- --------------------------------------------------------
    local zoneLabel = FS(content, L.SESSION_NONE, "GameFontNormalSmall",
        C_DIM[1], C_DIM[2], C_DIM[3])
    zoneLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, Y_ZONE)
    self.zoneLabel = zoneLabel

    -- --------------------------------------------------------
    -- FARM : ligne herbes (label LEFT, gold RIGHT)
    -- --------------------------------------------------------
    local herbRow, herbName, herbGold = TwoColRow(content, Y_HERB, 20,
        "GameFontNormalSmall", "GameFontNormal")
    herbName:SetText(L.LABEL_HERB)
    herbName:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    herbGold:SetTextColor(C_HERB[1], C_HERB[2], C_HERB[3])
    herbGold:SetText("—")
    self.herbGold = herbGold

    -- --------------------------------------------------------
    -- FARM : ligne minerais (label LEFT, gold RIGHT)
    -- --------------------------------------------------------
    local oreRow, oreName, oreGold = TwoColRow(content, Y_ORE, 20,
        "GameFontNormalSmall", "GameFontNormal")
    oreName:SetText(L.LABEL_ORE)
    oreName:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    oreGold:SetTextColor(C_ORE[1], C_ORE[2], C_ORE[3])
    oreGold:SetText("—")
    self.oreGold = oreGold

    -- --------------------------------------------------------
    -- FARM : bouton reset (tres discret, bas droite)
    -- --------------------------------------------------------
    local resetBtn = Btn(content, L.RESET_VISUAL, 52, 15)
    resetBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    resetBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    resetBtn:SetScript("OnEnter", function()
        resetBtn.label:SetTextColor(0.80, 0.80, 0.82)
    end)
    resetBtn:SetScript("OnLeave", function()
        resetBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    end)
    resetBtn:SetScript("OnClick", function()
        DB():ResetVisual()
        MainPanel:RefreshTotals()
    end)
    self.resetBtn = resetBtn

    -- --------------------------------------------------------
    -- OnUpdate : refresh totaux
    -- --------------------------------------------------------
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < UPDATE_RATE then return end
        elapsed = 0
        MainPanel:RefreshTotals()
    end)

    self:Refresh()
    return frame
end

-- ============================================================
-- Refresh
-- ============================================================
function MainPanel:Refresh()
    self:RefreshOracle()
    self:RefreshTotals()
end

-- ============================================================
-- RefreshOracle
-- ============================================================
function MainPanel:RefreshOracle()
    local oracle  = DB():GetOracleResult()
    local isAvail = ORA():IsAuctionatorAvailable()

    -- Bouton et date
    self.calcBtn.label:SetText(oracle.priceDate and L.ORACLE_RECALCULATE or L.ORACLE_CALCULATE)
    self.priceDate:SetText(ORA():GetPriceDateLabel())

    if oracle.recommendedZone then
        -- Zone 1 : recommandee (mint)
        local id1   = oracle.recommendedZone
        local name1 = ORA().ZONE_NAMES[id1] or "?"
        self.scoreName1:SetText(name1)
        self.scoreGold1:SetText(FormatGold(oracle.scores[id1] or 0))
        self.scoreName1:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])
        self.scoreGold1:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])

        -- Zone 2 : autre (dim)
        local id2
        for mapID in pairs(ORA().ZONE_NAMES) do
            if mapID ~= id1 then id2 = mapID end
        end
        if id2 then
            local name2 = ORA().ZONE_NAMES[id2] or "?"
            self.scoreName2:SetText(name2)
            self.scoreGold2:SetText(FormatGold(oracle.scores[id2] or 0))
            self.scoreName2:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
            self.scoreGold2:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
            self.scoreRow2:Show()
        else
            self.scoreRow2:Hide()
        end
        self.scoreRow1:Show()
        self.altBtn:Show()

    elseif not isAvail then
        self.scoreName1:SetText(L.ORACLE_NO_AUCTIONATOR)
        self.scoreGold1:SetText("")
        self.scoreName1:SetTextColor(C_WARN[1], C_WARN[2], C_WARN[3])
        self.scoreGold1:SetTextColor(C_WARN[1], C_WARN[2], C_WARN[3])
        self.scoreRow1:Show()
        self.scoreRow2:Hide()
        self.altBtn:Hide()
    else
        self.scoreName1:SetText(L.ORACLE_NOT_CALCULATED)
        self.scoreGold1:SetText("")
        self.scoreName1:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
        self.scoreGold1:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
        self.scoreRow1:Show()
        self.scoreRow2:Hide()
        self.altBtn:Hide()
    end
end

-- ============================================================
-- RefreshTotals
-- ============================================================
function MainPanel:RefreshTotals()
    local ses = SES()

    if ses:IsActive() then
        self.zoneLabel:SetText(ses.state.zoneName)
        self.zoneLabel:SetTextColor(C_HERB[1], C_HERB[2], C_HERB[3])
    elseif ses:IsWaiting() then
        local wz = ORA().ZONE_NAMES[ses:GetWaitingZone()] or "?"
        self.zoneLabel:SetText(format(L.SESSION_WAITING_SHORT, wz))
        self.zoneLabel:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    else
        self.zoneLabel:SetText(L.SESSION_NONE)
        self.zoneLabel:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    end

    local herbVal, oreVal = DB():GetDisplayTotals()
    self.herbGold:SetText(herbVal > 0 and FormatGold(herbVal) or "—")
    self.oreGold:SetText(oreVal  > 0 and FormatGold(oreVal)  or "—")
end

-- ============================================================
-- Bouton Analyser
-- ============================================================
function MainPanel:OnCalcClick()
    if not ORA():IsAuctionatorAvailable() then
        Meridian:Msg(L.ORACLE_NO_AUCTIONATOR)
        return
    end
    local results = ORA():Calculate()
    if not results or #results == 0 then
        Meridian:Msg(L.ORACLE_NO_DATA)
        return
    end
    self:RefreshOracle()
    SES():WaitForZone(results[1].mapID)
    self:RefreshTotals()
end

-- ============================================================
-- Bouton Autre zone
-- ============================================================
function MainPanel:OnAltZoneClick()
    local oracle = DB():GetOracleResult()
    if not oracle.recommendedZone then return end

    local altMapID
    for mapID in pairs(ORA().ZONE_NAMES) do
        if mapID ~= oracle.recommendedZone then
            altMapID = mapID
            break
        end
    end
    if not altMapID then return end

    SES():WaitForZone(altMapID)
    self:RefreshTotals()
end

-- ============================================================
-- Toggle / Show
-- ============================================================
function MainPanel:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Refresh()
        self.frame:Show()
    end
end

function MainPanel:Show()
    self:Refresh()
    self.frame:Show()
end

-- ============================================================
-- Callbacks
-- ============================================================
Meridian:RegisterCallback("INIT", function()
    MainPanel:Create()
end)

Meridian:RegisterCallback("TOGGLE_PANEL", function()
    MainPanel:Toggle()
end)

Meridian:RegisterCallback("SESSION_STARTED", function()
    MainPanel:Refresh()
end)

Meridian:RegisterCallback("SESSION_STOPPED", function()
    MainPanel:Refresh()
end)

Meridian:RegisterCallback("SESSION_WAITING_CHANGED", function()
    MainPanel:RefreshTotals()
end)

Meridian:RegisterCallback("SESSION_LOOT_ADDED", function()
    MainPanel:RefreshTotals()
end)

Meridian:RegisterCallback("RESET_ALL", function()
    MainPanel:Refresh()
end)
