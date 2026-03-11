-- ============================================================
-- Meridian — MainPanel (100% Native, Glimmer Glass)
-- Panneau principal : Oracle → Session → Historique
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local Database = ns.Database
local Oracle   = ns.Oracle
local Session  = ns.Session
local L = ns.L

local MainPanel = {}
ns.MainPanel = MainPanel

local math_floor = math.floor
local format     = string.format

-- ============================================================
-- Constantes de layout
-- ============================================================
local PANEL_W     = 320
local PANEL_H     = 320
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
    return Oracle:FormatGold(copper)
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
    -- Section ORACLE
    -- --------------------------------------------------------
    local oracleSection = CreateFrame("Frame", nil, frame)
    oracleSection:SetPoint("TOPLEFT",  frame, "TOPLEFT",  SECTION_PAD, -32)
    oracleSection:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SECTION_PAD, -32)
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
    local sep1 = frame:CreateTexture(nil, "BORDER")
    sep1:SetColorTexture(1, 1, 1, 0.07)
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT",  oracleSection, "BOTTOMLEFT",  0, -6)
    sep1:SetPoint("TOPRIGHT", oracleSection, "BOTTOMRIGHT", 0, -6)

    -- --------------------------------------------------------
    -- Section SESSION
    -- --------------------------------------------------------
    local sessionSection = CreateFrame("Frame", nil, frame)
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
    pauseBtn:SetScript("OnClick", function() Session:TogglePause() end)
    self.pauseBtn = pauseBtn

    -- Bouton Stop
    local stopBtn = GlimmerButton(sessionSection, L.SESSION_STOP, 90, 22)
    stopBtn:SetPoint("BOTTOMRIGHT", sessionSection, "BOTTOMRIGHT", 0, 0)
    stopBtn:SetScript("OnClick", function()
        Session:Stop()
        MainPanel:Refresh()
    end)
    self.stopBtn = stopBtn

    -- --------------------------------------------------------
    -- Séparateur
    -- --------------------------------------------------------
    local sep2 = frame:CreateTexture(nil, "BORDER")
    sep2:SetColorTexture(1, 1, 1, 0.07)
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT",  sessionSection, "BOTTOMLEFT",  0, -6)
    sep2:SetPoint("TOPRIGHT", sessionSection, "BOTTOMRIGHT", 0, -6)

    -- --------------------------------------------------------
    -- Section HISTORIQUE
    -- --------------------------------------------------------
    local histSection = CreateFrame("Frame", nil, frame)
    histSection:SetPoint("TOPLEFT",  sessionSection, "BOTTOMLEFT",  0, -14)
    histSection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SECTION_PAD, SECTION_PAD)
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
    -- Timer de mise à jour
    -- --------------------------------------------------------
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < UPDATE_RATE then return end
        elapsed = 0
        MainPanel:RefreshSession()
    end)

    self:Refresh()
    return frame
end

-- ============================================================
-- Refresh complet
-- ============================================================
function MainPanel:Refresh()
    self:RefreshOracle()
    self:RefreshSession()
    self:RefreshHistory()
end

-- ============================================================
-- Refresh section Oracle
-- ============================================================
function MainPanel:RefreshOracle()
    local oracle = Database:GetOracleResult()
    local isAvailable = Oracle:IsAuctionatorAvailable()

    if oracle.recommendedZone then
        local zoneName = Oracle.ZONE_NAMES[oracle.recommendedZone] or "?"
        self.recoZone:SetText("→ " .. zoneName)
        self.recoZone:SetTextColor(COLOR_HERB[1], COLOR_HERB[2], COLOR_HERB[3])

        -- Scores des deux zones
        local scoreParts = {}
        for mapID, score in pairs(oracle.scores) do
            local name = (Oracle.ZONE_NAMES[mapID] or "?"):match("^(.-)%s") or "?"
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

    self.priceDate:SetText(Oracle:GetPriceDateLabel())
    self.calcBtn.label:SetText(oracle.priceDate and L.ORACLE_RECALCULATE or L.ORACLE_CALCULATE)

    -- Bouton "autre zone" visible seulement si une reco existe et session non démarrée
    local showAlt = oracle.recommendedZone ~= nil and not Session:IsActive()
    self.altBtn:SetShown(showAlt)
end

-- ============================================================
-- Refresh section Session
-- ============================================================
function MainPanel:RefreshSession()
    local isActive  = Session:IsActive()
    local isPaused  = Session:IsPaused()
    local isWaiting = Session:IsWaiting()

    if isWaiting then
        local waitZone = Oracle.ZONE_NAMES[Session:GetWaitingZone()] or "?"
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

    -- Session active
    local elapsed  = Session:GetElapsed()
    local gph      = Session:GetGoldPerHour()
    local goldHerb = Session.state.goldHerb
    local goldOre  = Session.state.goldOre
    local zoneName = Session.state.zoneName

    self.sessionHeader:SetText(format(L.SESSION_IN_ZONE, zoneName))
    self.timerLabel:SetText(FormatDuration(elapsed) .. (isPaused and " (" .. L.SESSION_PAUSED_SHORT .. ")" or ""))
    self.gphLabel:SetText(FormatGold(gph) .. "/h")
    self.breakdownLabel:SetText(
        "|cff" .. string.format("%02x%02x%02x", COLOR_HERB[1]*255, COLOR_HERB[2]*255, COLOR_HERB[3]*255)
        .. "🌿|r " .. FormatGold(goldHerb)
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
    local sessions = Database:GetRecentSessions(5)
    local avg      = Database:GetAverageGoldPerHour(5)

    -- Noms courts
    local SHORT = {
        [2395] = "BCE",
        [2405] = "TdV",
    }

    for i = 1, 5 do
        local s = sessions[i]
        if s then
            local shortName = SHORT[s.mapID] or s.zoneName:sub(1, 3)
            local line = format("%s · %s · 🌿%s ⛏%s",
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
    if not Oracle:IsAuctionatorAvailable() then
        Meridian:Msg(L.ORACLE_NO_AUCTIONATOR)
        return
    end
    local results = Oracle:Calculate()
    if not results or #results == 0 then
        Meridian:Msg(L.ORACLE_NO_DATA)
        return
    end
    self:RefreshOracle()
    -- Passer en mode attente pour la zone recommandée
    local recommended = results[1].mapID
    Session:WaitForZone(recommended)
    self:RefreshSession()
end

-- L'utilisateur choisit l'autre zone (la moins bien recommandée)
function MainPanel:OnAltZoneClick()
    local oracle = Database:GetOracleResult()
    if not oracle.recommendedZone then return end

    -- Trouver l'autre mapID
    local altMapID
    for mapID in pairs(Oracle.ZONE_NAMES) do
        if mapID ~= oracle.recommendedZone then
            altMapID = mapID
            break
        end
    end
    if not altMapID then return end

    Session:WaitForZone(altMapID)
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
