-- ============================================================
-- Meridian -- MainPanel (100% Native, Glimmer Glass)
-- Design minimaliste : logo M, Oracle, Totaux du jour
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

-- Resolution differee via ns
local function DB()  return ns.Database end
local function ORA() return ns.Oracle   end
local function SES() return ns.Session  end

local MainPanel = {}
ns.MainPanel = MainPanel

local math_floor = math.floor
local format     = string.format

-- ============================================================
-- Constantes de layout
-- ============================================================
local PANEL_W     = 220
local PANEL_H     = 190
local PAD         = 12
local LINE_H      = 18
local UPDATE_RATE = 1.0

-- Couleurs Glimmer
local COLOR_HERB  = { 0.25, 0.78, 0.55 }  -- mint
local COLOR_ORE   = { 0.88, 0.76, 0.28 }  -- gold
local COLOR_WARN  = { 0.90, 0.58, 0.35 }  -- orange
local COLOR_DIM   = { 0.55, 0.55, 0.60 }
local COLOR_WHITE = { 1.00, 1.00, 1.00 }

-- ============================================================
-- Helpers Glimmer
-- ============================================================
local function GlimmerBorder(frame)
    local function Edge(a1, a2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.10)
        t:SetPoint(a1, frame, a1)
        t:SetPoint(a2, frame, a2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    Edge("TOPLEFT",    "TOPRIGHT",    nil, 1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT",    "BOTTOMLEFT",  1,   nil)
    Edge("TOPRIGHT",   "BOTTOMRIGHT", 1,   nil)
end

local function Label(parent, text, font, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetText(text or "")
    fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    return fs
end

local function GlimmerButton(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 90, h or 20)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.02, 0.02, 0.03, 0.68)
    GlimmerBorder(btn)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints(btn)
    lbl:SetText(text)
    lbl:SetTextColor(1, 1, 1, 0.80)
    btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 1.00) end)
    btn:SetScript("OnLeave", function() lbl:SetTextColor(1, 1, 1, 0.80) end)
    btn.label = lbl
    return btn
end

-- ============================================================
-- Formatage or (cuivres -> lisible)
-- ============================================================
local function FormatGold(copper)
    return ORA():FormatGold(copper)
end

-- ============================================================
-- Creation du panneau
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

    -- Fond Glimmer
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.02, 0.02, 0.03, 0.72)
    GlimmerBorder(frame)

    -- Ligne sous le header
    local topLine = frame:CreateTexture(nil, "BORDER")
    topLine:SetColorTexture(0.56, 0.85, 0.72, 0.20)
    topLine:SetHeight(1)
    topLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -24)
    topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -24)

    -- --------------------------------------------------------
    -- Logo : "M" grand + barre horizontale par-dessus
    -- --------------------------------------------------------
    local logoLetter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    logoLetter:SetText("M")
    logoLetter:SetTextColor(0.85, 0.78, 0.45)
    logoLetter:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -4)
    self.logoLetter = logoLetter

    -- Barre qui traverse le M (texture 1px haute, positionnee au milieu du glyphe)
    local logoBar = frame:CreateTexture(nil, "OVERLAY")
    logoBar:SetColorTexture(0.85, 0.78, 0.45, 0.90)
    logoBar:SetHeight(2)
    logoBar:SetWidth(16)
    logoBar:SetPoint("LEFT", logoLetter, "LEFT", 0, -1)
    self.logoBar = logoBar

    -- Bouton fermer discret (x en haut a droite)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -4)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeTxt:SetAllPoints(closeBtn)
    closeTxt:SetText("x")
    closeTxt:SetTextColor(1, 1, 1, 0.30)
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 1, 1, 0.80) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(1, 1, 1, 0.30) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- --------------------------------------------------------
    -- Contenu (sous le header)
    -- --------------------------------------------------------
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",     frame, "TOPLEFT",     PAD, -28)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
    self.content = content

    -- === Etat ORACLE ===
    -- Date prix (ligne 1)
    local priceDate = Label(content, "", "GameFontNormalSmall",
        COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    priceDate:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    self.priceDate = priceDate

    -- Zone recommandee (ligne 2, grande)
    local recoZone = Label(content, L.ORACLE_NOT_CALCULATED, "GameFontNormal",
        COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    recoZone:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LINE_H)
    self.recoZone = recoZone

    -- Scores des deux zones (ligne 3, petits)
    local recoScore = Label(content, "", "GameFontNormalSmall",
        COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    recoScore:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LINE_H*2 - 2)
    self.recoScore = recoScore

    -- Bouton Analyser / Recalculer
    local calcBtn = GlimmerButton(content, L.ORACLE_CALCULATE, 90, 20)
    calcBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LINE_H*3 - 6)
    calcBtn:SetScript("OnClick", function() MainPanel:OnCalcClick() end)
    self.calcBtn = calcBtn

    -- Bouton Autre zone (meme ligne, a droite)
    local altBtn = GlimmerButton(content, L.ORACLE_CHOOSE_OTHER, 100, 20)
    altBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -LINE_H*3 - 6)
    altBtn:SetScript("OnClick", function() MainPanel:OnAltZoneClick() end)
    altBtn:Hide()
    self.altBtn = altBtn

    -- Separateur entre Oracle et totaux
    local sep = content:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(1, 1, 1, 0.07)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -LINE_H*3 - 32)
    sep:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -LINE_H*3 - 32)
    self.sep = sep

    -- === Totaux du jour ===
    -- Libelle zone active ou "Aucune session"
    local zoneLabel = Label(content, L.SESSION_NONE, "GameFontNormalSmall",
        COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    zoneLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LINE_H*3 - 40)
    self.zoneLabel = zoneLabel

    -- Total herbes (ligne distincte, mint)
    local herbLabel = Label(content, "", "GameFontNormal",
        COLOR_HERB[1], COLOR_HERB[2], COLOR_HERB[3])
    herbLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LINE_H*4 - 40)
    self.herbLabel = herbLabel

    -- Total minerais (ligne distincte, gold)
    local oreLabel = Label(content, "", "GameFontNormal",
        COLOR_ORE[1], COLOR_ORE[2], COLOR_ORE[3])
    oreLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LINE_H*5 - 40)
    self.oreLabel = oreLabel

    -- Bouton reset visuel (tres discret, en bas a droite)
    local resetBtn = GlimmerButton(content, L.RESET_VISUAL, 70, 16)
    resetBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    resetBtn.label:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    resetBtn:SetScript("OnClick", function()
        DB():ResetVisual()
        MainPanel:RefreshTotals()
    end)
    self.resetBtn = resetBtn

    -- --------------------------------------------------------
    -- Timer de mise a jour des totaux
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
-- Refresh complet
-- ============================================================
function MainPanel:Refresh()
    self:RefreshOracle()
    self:RefreshTotals()
end

-- ============================================================
-- Refresh Oracle
-- ============================================================
function MainPanel:RefreshOracle()
    local oracle      = DB():GetOracleResult()
    local isAvailable = ORA():IsAuctionatorAvailable()

    -- Date prix
    self.priceDate:SetText(ORA():GetPriceDateLabel())

    -- Zone recommandee
    if oracle.recommendedZone then
        local zoneName = ORA().ZONE_NAMES[oracle.recommendedZone] or "?"
        self.recoZone:SetText(zoneName)
        self.recoZone:SetTextColor(COLOR_HERB[1], COLOR_HERB[2], COLOR_HERB[3])

        -- Scores : "Tempete 11495g  |  Bois 10086g"
        local parts = {}
        for mapID, score in pairs(oracle.scores) do
            local shortName = (ORA().ZONE_NAMES[mapID] or "?"):match("^(%S+)") or "?"
            parts[#parts + 1] = shortName .. " " .. FormatGold(score)
        end
        self.recoScore:SetText(table.concat(parts, "  |  "))
        self.recoScore:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])

        self.altBtn:SetShown(not SES():IsActive())
    elseif not isAvailable then
        self.recoZone:SetText(L.ORACLE_NO_AUCTIONATOR)
        self.recoZone:SetTextColor(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3])
        self.recoScore:SetText("")
        self.altBtn:Hide()
    else
        self.recoZone:SetText(L.ORACLE_NOT_CALCULATED)
        self.recoZone:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        self.recoScore:SetText("")
        self.altBtn:Hide()
    end

    -- Label bouton
    self.calcBtn.label:SetText(oracle.priceDate and L.ORACLE_RECALCULATE or L.ORACLE_CALCULATE)
end

-- ============================================================
-- Refresh totaux du jour
-- ============================================================
function MainPanel:RefreshTotals()
    local ses = SES()
    if ses:IsActive() then
        self.zoneLabel:SetText(ses.state.zoneName)
        self.zoneLabel:SetTextColor(COLOR_HERB[1], COLOR_HERB[2], COLOR_HERB[3])
    elseif ses:IsWaiting() then
        local waitZone = ORA().ZONE_NAMES[ses:GetWaitingZone()] or "?"
        self.zoneLabel:SetText(format(L.SESSION_WAITING_SHORT, waitZone))
        self.zoneLabel:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    else
        self.zoneLabel:SetText(L.SESSION_NONE)
        self.zoneLabel:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    end

    local herbVal, oreVal = DB():GetDisplayTotals()

    if herbVal > 0 then
        self.herbLabel:SetText(L.LABEL_HERB .. " " .. FormatGold(herbVal))
    else
        self.herbLabel:SetText(L.LABEL_HERB .. " —")
    end

    if oreVal > 0 then
        self.oreLabel:SetText(L.LABEL_ORE .. " " .. FormatGold(oreVal))
    else
        self.oreLabel:SetText(L.LABEL_ORE .. " —")
    end
end

-- ============================================================
-- Actions boutons Oracle
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
    -- Demarrer (ou attendre) la zone recommandee
    SES():WaitForZone(results[1].mapID)
    self:RefreshTotals()
end

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
    self:RefreshOracle()
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
