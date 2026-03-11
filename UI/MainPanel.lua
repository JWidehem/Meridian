-- ============================================================
-- Meridian — MainPanel (100% Native, Glimmer Glass)
-- Panneau principal : Oracle → Session → Historique
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local L = ns.L

-- Résolution différée via ns — les modules sont enregistrés après le chargement
local function DB()      return ns.Database end
local function ORA()     return ns.Oracle   end
local function SES()     return ns.Session  end

local MainPanel = {}
ns.MainPanel = MainPanel

local math_floor = math.floor
local format     = string.format

-- ============================================================
-- Constantes de layout
-- ============================================================
local PANEL_W     = 320
local PANEL_H     = 270
local SECTION_PAD = 12
local LINE_H      = 18
local UPDATE_RATE = 0.5   -- rafraîchissement du timer (secondes)

-- Couleurs Glimmer
local COLOR_HERB    = { 0.25, 0.78, 0.55 }  -- mint
local COLOR_ORE     = { 0.88, 0.76, 0.28 }  -- gold
local COLOR_WARN    = { 0.90, 0.58, 0.35 }  -- orange
local COLOR_DIM     = { 0.55, 0.55, 0.60 }
local COLOR_WHITE   = { 1.00, 1.00, 1.00 }
local COLOR_TITLE   = { 0.85, 0.78, 0.45 }

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

local function GlimmerCloseButton(frame)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(20, 20)
    btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetAllPoints(btn)
    txt:SetText("×")
    txt:SetTextColor(1, 1, 1, 0.45)
    btn:SetScript("OnEnter", function() txt:SetTextColor(1, 1, 1, 0.90) end)
    btn:SetScript("OnLeave", function() txt:SetTextColor(1, 1, 1, 0.45) end)
    btn:SetScript("OnClick", function() frame:Hide() end)
    return btn
end

local function GlimmerButton(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 120, h or 22)
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
-- Formatage or (cuivres → lisible)
-- ============================================================
local function FormatGold(copper)
    return ORA():FormatGold(copper)
end

-- Durée (secondes) → "Xh Ym" ou "Ym Zs"
local function FormatDuration(sec)
    sec = math_floor(sec or 0)
    if sec >= 3600 then
        return format("%dh %dm", math_floor(sec/3600), math_floor((sec%3600)/60))
    elseif sec >= 60 then
        return format("%dm %ds", math_floor(sec/60), sec%60)
    else
        return format("%ds", sec)
    end
end

-- ============================================================
-- Création du panneau principal
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
    bg:SetColorTexture(0.02, 0.02, 0.03, 0.68)

    -- Séparateur haut
    local topLine = frame:CreateTexture(nil, "BORDER")
    topLine:SetColorTexture(0.56, 0.85, 0.72, 0.30)
    topLine:SetHeight(1)
    topLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -26)
    topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -26)

    GlimmerBorder(frame)
    GlimmerCloseButton(frame)

    -- Titre
    local title = Label(frame, "Meridian", "GameFontNormalLarge",
        COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", SECTION_PAD, -8)
    self.title = title

    -- --------------------------------------------------------
    -- Onglets
    -- --------------------------------------------------------
    local function MakeTab(text, anchorX)
        local btn = CreateFrame("Button", nil, frame)
        btn:SetSize(140, 19)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", anchorX, -27)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", btn, "LEFT", 4, 0)
        lbl:SetText(text)
        lbl:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        btn.label = lbl
        local ind = btn:CreateTexture(nil, "BORDER")
        ind:SetColorTexture(0.56, 0.85, 0.72, 0)
        ind:SetHeight(1)
        ind:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  4, 1)
        ind:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 1)
        btn.indicator = ind
        btn:SetScript("OnEnter", function()
            if btn ~= MainPanel.activeTabBtn then lbl:SetTextColor(0.80, 0.80, 0.82) end
        end)
        btn:SetScript("OnLeave", function()
            if btn ~= MainPanel.activeTabBtn then lbl:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3]) end
        end)
        return btn
    end
    local tab1Btn = MakeTab(L.TAB_ORACLE_SESSION, SECTION_PAD)
    local tab2Btn = MakeTab(L.TAB_HISTORY, SECTION_PAD + 144)
    self.tab1Btn = tab1Btn
    self.tab2Btn = tab2Btn

    -- Séparateur sous les onglets
    local tabLine = frame:CreateTexture(nil, "BORDER")
    tabLine:SetColorTexture(1, 1, 1, 0.07)
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -46)
    tabLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -46)

    -- --------------------------------------------------------
    -- Conteneurs d'onglets
    -- --------------------------------------------------------
    local mainContent = CreateFrame("Frame", nil, frame)
    mainContent:SetPoint("TOPLEFT",     frame, "TOPLEFT",     SECTION_PAD, -50)
    mainContent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SECTION_PAD, SECTION_PAD)
    self.mainContent = mainContent

    local histContent = CreateFrame("Frame", nil, frame)
    histContent:SetPoint("TOPLEFT",     frame, "TOPLEFT",     SECTION_PAD, -50)
    histContent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SECTION_PAD, SECTION_PAD)
    histContent:Hide()
    self.histContent = histContent

    -- --------------------------------------------------------
    -- Section ORACLE (dans mainContent)
    -- --------------------------------------------------------
    local oracleSection = CreateFrame("Frame", nil, mainContent)
    oracleSection:SetPoint("TOPLEFT",  mainContent, "TOPLEFT",  0, 0)
    oracleSection:SetPoint("TOPRIGHT", mainContent, "TOPRIGHT", 0, 0)
    oracleSection:SetHeight(90)
    self.oracleSection = oracleSection

    -- Recommandation principale
    local recoLabel = Label(oracleSection, L.ORACLE_RECOMMENDATION,
        "GameFontNormalSmall", COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    recoLabel:SetPoint("TOPLEFT", oracleSection, "TOPLEFT", 0, 0)
    self.recoLabel = recoLabel

    local recoZone = Label(oracleSection, "—", "GameFontNormalLarge",
        COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3])
    recoZone:SetPoint("TOPLEFT", oracleSection, "TOPLEFT", 0, -LINE_H)
    self.recoZone = recoZone

    local recoScore = Label(oracleSection, "", "GameFontNormalSmall",
        COLOR_HERB[1], COLOR_HERB[2], COLOR_HERB[3])
    recoScore:SetPoint("TOPLEFT", oracleSection, "TOPLEFT", 0, -LINE_H*2 - 2)
    self.recoScore = recoScore

    local priceDate = Label(oracleSection, "", "GameFontNormalSmall",
        COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    priceDate:SetPoint("TOPRIGHT", oracleSection, "TOPRIGHT", 0, -LINE_H*2 - 2)
    self.priceDate = priceDate

    -- Bouton Calculer / Recalculer
    local calcBtn = GlimmerButton(oracleSection, L.ORACLE_CALCULATE, 130, 22)
    calcBtn:SetPoint("BOTTOMLEFT", oracleSection, "BOTTOMLEFT", 0, 0)
    calcBtn:SetScript("OnClick", function() MainPanel:OnCalcClick() end)
    self.calcBtn = calcBtn

    -- Bouton "Choisir l'autre zone"
    local altBtn = GlimmerButton(oracleSection, L.ORACLE_CHOOSE_OTHER, 150, 22)
    altBtn:SetPoint("BOTTOMRIGHT", oracleSection, "BOTTOMRIGHT", 0, 0)
    altBtn:SetScript("OnClick", function() MainPanel:OnAltZoneClick() end)
    self.altBtn = altBtn

    -- --------------------------------------------------------
    -- Séparateur
    -- --------------------------------------------------------
    local sep1 = mainContent:CreateTexture(nil, "BORDER")
    sep1:SetColorTexture(1, 1, 1, 0.07)
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT",  oracleSection, "BOTTOMLEFT",  0, -6)
    sep1:SetPoint("TOPRIGHT", oracleSection, "BOTTOMRIGHT", 0, -6)

    -- --------------------------------------------------------
    -- Section SESSION (dans mainContent)
    -- --------------------------------------------------------
    local sessionSection = CreateFrame("Frame", nil, mainContent)
    sessionSection:SetPoint("TOPLEFT",  oracleSection, "BOTTOMLEFT",  0, -14)
    sessionSection:SetPoint("TOPRIGHT", oracleSection, "BOTTOMRIGHT", 0, -14)
    sessionSection:SetHeight(80)
    self.sessionSection = sessionSection

    local sessionHeader = Label(sessionSection, L.SESSION_IN_PROGRESS,
        "GameFontNormalSmall", COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    sessionHeader:SetPoint("TOPLEFT", sessionSection, "TOPLEFT", 0, 0)
    self.sessionHeader = sessionHeader

    local timerLabel = Label(sessionSection, "—", "GameFontNormal",
        COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3])
    timerLabel:SetPoint("TOPLEFT", sessionSection, "TOPLEFT", 0, -LINE_H)
    self.timerLabel = timerLabel

    local gphLabel = Label(sessionSection, "", "GameFontNormalSmall",
        COLOR_ORE[1], COLOR_ORE[2], COLOR_ORE[3])
    gphLabel:SetPoint("TOPLEFT", sessionSection, "TOPLEFT", 0, -LINE_H*2)
    self.gphLabel = gphLabel

    local breakdownLabel = Label(sessionSection, "", "GameFontNormalSmall",
        COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    breakdownLabel:SetPoint("TOPRIGHT", sessionSection, "TOPRIGHT", 0, -LINE_H*2)
    self.breakdownLabel = breakdownLabel

    -- Bouton Pause/Reprendre
    local pauseBtn = GlimmerButton(sessionSection, L.SESSION_PAUSE, 120, 22)
    pauseBtn:SetPoint("BOTTOMLEFT", sessionSection, "BOTTOMLEFT", 0, 0)
    pauseBtn:SetScript("OnClick", function() SES():TogglePause() end)
    self.pauseBtn = pauseBtn

    -- Bouton Stop
    local stopBtn = GlimmerButton(sessionSection, L.SESSION_STOP, 90, 22)
    stopBtn:SetPoint("BOTTOMRIGHT", sessionSection, "BOTTOMRIGHT", 0, 0)
    stopBtn:SetScript("OnClick", function()
        SES():Stop()
        MainPanel:Refresh()
    end)
    self.stopBtn = stopBtn

    -- --------------------------------------------------------
    -- Section HISTORIQUE (dans histContent)
    -- --------------------------------------------------------
    local histSection = CreateFrame("Frame", nil, histContent)
    histSection:SetPoint("TOPLEFT",     histContent, "TOPLEFT",     0, 0)
    histSection:SetPoint("BOTTOMRIGHT", histContent, "BOTTOMRIGHT", 0, 0)
    self.histSection = histSection

    local histHeader = Label(histSection, L.HISTORY_TITLE,
        "GameFontNormalSmall", COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
    histHeader:SetPoint("TOPLEFT", histSection, "TOPLEFT", 0, 0)
    self.histHeader = histHeader

    -- 5 lignes d'historique
    self.histLines = {}
    for i = 1, 5 do
        local line = Label(histSection, "", "GameFontNormalSmall",
            COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        line:SetPoint("TOPLEFT", histSection, "TOPLEFT", 0, -(i) * LINE_H)
        self.histLines[i] = line
    end

    local avgLabel = Label(histSection, "", "GameFontNormalSmall",
        COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3])
    avgLabel:SetPoint("TOPLEFT", histSection, "TOPLEFT", 0, -6 * LINE_H)
    self.avgLabel = avgLabel

    -- --------------------------------------------------------
    -- Initialisation des onglets
    -- --------------------------------------------------------
    self.activeTab = 1
    self.activeTabBtn = tab1Btn
    tab1Btn.label:SetTextColor(1, 1, 1, 0.90)
    tab1Btn.indicator:SetVertexColor(0.56, 0.85, 0.72, 0.70)
    tab1Btn:SetScript("OnClick", function() MainPanel:SwitchTab(1) end)
    tab2Btn:SetScript("OnClick", function() MainPanel:SwitchTab(2) end)

    -- --------------------------------------------------------
    -- Timer de mise à jour
    -- --------------------------------------------------------
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < UPDATE_RATE then return end
        elapsed = 0
        if MainPanel.activeTab ~= 2 then
            MainPanel:RefreshSession()
        end
    end)

    self:Refresh()
    return frame
end

-- ============================================================
-- Refresh complet
-- ============================================================
function MainPanel:Refresh()
    if self.activeTab == 2 then
        self:RefreshHistory()
    else
        self:RefreshOracle()
        self:RefreshSession()
    end
end

-- ============================================================
-- Commutation d'onglet
-- ============================================================
function MainPanel:SwitchTab(n)
    self.activeTab = n
    if n == 1 then
        self.mainContent:Show()
        self.histContent:Hide()
        self.activeTabBtn = self.tab1Btn
        self.tab1Btn.label:SetTextColor(1, 1, 1, 0.90)
        self.tab1Btn.indicator:SetVertexColor(0.56, 0.85, 0.72, 0.70)
        self.tab2Btn.label:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        self.tab2Btn.indicator:SetVertexColor(0.56, 0.85, 0.72, 0)
        self:RefreshOracle()
        self:RefreshSession()
    else
        self.mainContent:Hide()
        self.histContent:Show()
        self.activeTabBtn = self.tab2Btn
        self.tab1Btn.label:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        self.tab1Btn.indicator:SetVertexColor(0.56, 0.85, 0.72, 0)
        self.tab2Btn.label:SetTextColor(1, 1, 1, 0.90)
        self.tab2Btn.indicator:SetVertexColor(0.56, 0.85, 0.72, 0.70)
        self:RefreshHistory()
    end
end

-- ============================================================
-- Refresh section Oracle
-- ============================================================
function MainPanel:RefreshOracle()
    local oracle = DB():GetOracleResult()
    local isAvailable = ORA():IsAuctionatorAvailable()

    if oracle.recommendedZone then
        local zoneName = ORA().ZONE_NAMES[oracle.recommendedZone] or "?"
        self.recoZone:SetText(zoneName)
        self.recoZone:SetTextColor(COLOR_HERB[1], COLOR_HERB[2], COLOR_HERB[3])

        local scoreParts = {}
        for mapID, score in pairs(oracle.scores) do
            local name = (ORA().ZONE_NAMES[mapID] or "?"):match("^(.-)%s") or "?"
            scoreParts[#scoreParts + 1] = name .. " " .. FormatGold(score)
        end
        self.recoScore:SetText(table.concat(scoreParts, "  |  "))
    elseif not isAvailable then
        self.recoZone:SetText(L.ORACLE_NO_AUCTIONATOR)
        self.recoZone:SetTextColor(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3])
        self.recoScore:SetText("")
    else
        self.recoZone:SetText(L.ORACLE_NOT_CALCULATED)
        self.recoZone:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        self.recoScore:SetText("")
    end

    self.priceDate:SetText(ORA():GetPriceDateLabel())
    self.calcBtn.label:SetText(oracle.priceDate and L.ORACLE_RECALCULATE or L.ORACLE_CALCULATE)

    local showAlt = oracle.recommendedZone ~= nil and not SES():IsActive()
    self.altBtn:SetShown(showAlt)
end

-- ============================================================
-- Refresh section Session
-- ============================================================
function MainPanel:RefreshSession()
    local isActive  = SES():IsActive()
    local isPaused  = SES():IsPaused()
    local isWaiting = SES():IsWaiting()

    if isWaiting then
        local waitZone = ORA().ZONE_NAMES[SES():GetWaitingZone()] or "?"
        self.sessionHeader:SetText(format(L.SESSION_WAITING_SHORT, waitZone))
        self.timerLabel:SetText("—")
        self.gphLabel:SetText("")
        self.breakdownLabel:SetText("")
        self.pauseBtn:Hide()
        self.stopBtn:Hide()
        return
    end

    if not isActive then
        self.sessionHeader:SetText(L.SESSION_NONE)
        self.timerLabel:SetText("—")
        self.gphLabel:SetText("")
        self.breakdownLabel:SetText("")
        self.pauseBtn:Hide()
        self.stopBtn:Hide()
        return
    end

    local elapsed  = SES():GetElapsed()
    local gph      = SES():GetGoldPerHour()
    local goldHerb = SES().state.goldHerb
    local goldOre  = SES().state.goldOre
    local zoneName = SES().state.zoneName

    self.sessionHeader:SetText(format(L.SESSION_IN_ZONE, zoneName))
    self.timerLabel:SetText(FormatDuration(elapsed) .. (isPaused and " (" .. L.SESSION_PAUSED_SHORT .. ")" or ""))
    self.gphLabel:SetText(FormatGold(gph) .. "/h")
    self.breakdownLabel:SetText(
        "|cff" .. string.format("%02x%02x%02x", COLOR_HERB[1]*255, COLOR_HERB[2]*255, COLOR_HERB[3]*255)
        .. "☕|r " .. FormatGold(goldHerb)
        .. "  |cff" .. string.format("%02x%02x%02x", COLOR_ORE[1]*255, COLOR_ORE[2]*255, COLOR_ORE[3]*255)
        .. "⛏|r " .. FormatGold(goldOre)
    )

    self.pauseBtn:Show()
    self.stopBtn:Show()
    self.pauseBtn.label:SetText(isPaused and L.SESSION_RESUME or L.SESSION_PAUSE)
end

-- ============================================================
-- Refresh section Historique
-- ============================================================
function MainPanel:RefreshHistory()
    local sessions = DB():GetRecentSessions(5)
    local avg      = DB():GetAverageGoldPerHour(5)

    local SHORT = { [2395] = "BCE", [2405] = "TdV" }

    for i = 1, 5 do
        local s = sessions[i]
        if s then
            local shortName = SHORT[s.mapID] or s.zoneName:sub(1, 3)
            local line = format("%s · %s · ☕%s ⛏%s",
                shortName,
                FormatDuration(s.duration),
                FormatGold(s.goldHerb),
                FormatGold(s.goldOre)
            )
            self.histLines[i]:SetText(line)
            self.histLines[i]:SetTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3])
        else
            self.histLines[i]:SetText("")
        end
    end

    if avg > 0 then
        self.avgLabel:SetText(format(L.HISTORY_AVG, FormatGold(avg)))
        self.avgLabel:SetTextColor(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3])
    else
        self.avgLabel:SetText("")
    end
end

-- ============================================================
-- Actions boutons
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
    local recommended = results[1].mapID
    SES():WaitForZone(recommended)
    self:RefreshSession()
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
    self:RefreshSession()
end

-- ============================================================
-- Toggle
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

Meridian:RegisterCallback("SESSION_STATE_CHANGED", function()
    MainPanel:RefreshSession()
end)
