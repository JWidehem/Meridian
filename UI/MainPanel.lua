-- ============================================================
-- Meridian -- MainPanel (100% Native, Glimmer Glass)
-- 3 etats : idle (oracle) | choose (choix zone) | farming (log + totaux)
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
-- Layout constants
-- ============================================================
local PANEL_W    = 260
local PANEL_H    = 300   -- hauteur etat farming (le plus grand)
local PAD        = 14
local HDR_H      = 26
local LOG_LINES  = 8     -- lignes visibles dans le scroll loot
local LOG_LINE_H = 16    -- hauteur d'une ligne loot

-- Couleurs
local C_BEST  = { 0.25, 0.78, 0.55 }   -- mint    (plantes / meilleure zone)
local C_ORE   = { 0.88, 0.76, 0.28 }   -- ambre   (minerais)
local C_TOTAL = { 0.65, 0.85, 1.00 }   -- bleu    (total)
local C_DIM   = { 0.55, 0.55, 0.60 }   -- gris
local C_WARN  = { 0.90, 0.58, 0.35 }   -- orange
local C_TITLE = { 0.85, 0.78, 0.45 }   -- dore titre
local C_BG    = { 0.03, 0.03, 0.05, 0.84 }

-- Etat courant : "idle" | "choose" | "farming" | "history"
MainPanel.viewState = "idle"

-- ============================================================
-- Helpers visuels
-- ============================================================
local function GlimmerBorder(f)
    local function Edge(a1, a2, w, h)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.10)
        t:SetPoint(a1, f, a1)
        t:SetPoint(a2, f, a2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    Edge("TOPLEFT",    "TOPRIGHT",    nil, 1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT",    "BOTTOMLEFT",  1,   nil)
    Edge("TOPRIGHT",   "BOTTOMRIGHT", 1,   nil)
end

local function FS(parent, text, font, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetText(text or "")
    fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    return fs
end

local function Btn(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 90, h or 20)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.04, 0.04, 0.08, 0.75)
    GlimmerBorder(btn)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints(btn)
    lbl:SetText(text or "")
    lbl:SetTextColor(0.90, 0.90, 0.92)
    btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() lbl:SetTextColor(0.90, 0.90, 0.92) end)
    btn.label = lbl
    return btn
end

local function HLine(parent, yOffset, alpha, r, g, b)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(r or 1, g or 1, b or 1, alpha or 0.07)
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOffset)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    return t
end

local function FormatGold(c) return ORA():FormatGold(c) end

-- ============================================================
-- Sous-frame helper : frame transparente ancree dans content
-- ============================================================
local function SubFrame(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w or 1, h or 1)
    return f
end

-- ============================================================
-- Build : header commun (M barre + close) ancre sur le frame principal
-- ============================================================
local function BuildHeader(frame)
    local logoM = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    logoM:SetText("M")
    logoM:SetTextColor(C_TITLE[1], C_TITLE[2], C_TITLE[3])
    logoM:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -3)

    local logoBar = frame:CreateTexture(nil, "OVERLAY")
    logoBar:SetColorTexture(C_TITLE[1], C_TITLE[2], C_TITLE[3], 0.88)
    logoBar:SetSize(18, 2)
    logoBar:SetPoint("LEFT", logoM, "LEFT", 0, -2)

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

    -- Ligne sous header
    local hdrLine = frame:CreateTexture(nil, "BORDER")
    hdrLine:SetColorTexture(0.56, 0.85, 0.72, 0.15)
    hdrLine:SetHeight(1)
    hdrLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -(HDR_H + 1))
    hdrLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(HDR_H + 1))
end

-- ============================================================
-- BUILD IDLE FRAME (Oracle : Analyser / scores)
-- ============================================================
local function BuildIdleFrame(content)
    local f = SubFrame(content)
    f:SetPoint("TOPLEFT",     content, "TOPLEFT",     0,    0)
    f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0,    0)

    -- Bouton Analyser
    local calcBtn = Btn(f, L.ORACLE_CALCULATE, 110, 22)
    calcBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    -- Date prix (droite, meme ligne)
    local priceDate = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceDate:SetPoint("LEFT",   calcBtn, "RIGHT", 6, 0)
    priceDate:SetPoint("RIGHT",  f,       "RIGHT", 0, 0)
    priceDate:SetPoint("TOP",    calcBtn, "TOP",    0, 0)
    priceDate:SetPoint("BOTTOM", calcBtn, "BOTTOM", 0, 0)
    priceDate:SetJustifyH("RIGHT")
    priceDate:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])

    -- Lignes de score (zone 1 = recommandee, zone 2 = autre)
    local function ScoreRow(yOff)
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, yOff)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, yOff)
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("LEFT",  row, "LEFT",  0,  0)
        name:SetPoint("RIGHT", row, "CENTER", 10, 0)
        name:SetJustifyH("LEFT")
        local gold = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gold:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        gold:SetJustifyH("RIGHT")
        return row, name, gold
    end

    local row1, name1, gold1 = ScoreRow(-32)
    local row2, name2, gold2 = ScoreRow(-50)

    -- Separateur
    HLine(f, -72)

    -- Bouton choisir l'autre zone
    local altBtn = Btn(f, L.ORACLE_CHOOSE_OTHER, 150, 20)
    altBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -80)
    altBtn:Hide()

    return {
        frame     = f,
        calcBtn   = calcBtn,
        priceDate = priceDate,
        row1 = row1, name1 = name1, gold1 = gold1,
        row2 = row2, name2 = name2, gold2 = gold2,
        altBtn    = altBtn,
    }
end

-- ============================================================
-- BUILD CHOOSE FRAME (choix de zone : un bouton par zone)
-- ============================================================
local ZONE_LIST = { 2395, 2405 }   -- ordre fixe pour navigation ‹ ›

local function BuildChooseFrame(content)
    local f = SubFrame(content)
    f:SetPoint("TOPLEFT",     content, "TOPLEFT",     0, 0)
    f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    local title = FS(f, L.CHOOSE_ZONE_TITLE, "GameFontNormal",
        C_DIM[1], C_DIM[2], C_DIM[3])
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    -- Un bouton par zone (construit dynamiquement au Refresh)
    local zoneBtns = {}
    for i, mapID in ipairs(ZONE_LIST) do
        local zb = Btn(f, ORA().ZONE_NAMES[mapID] or tostring(mapID), 220, 24)
        zb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(24 + (i - 1) * 32))
        zb.mapID = mapID
        zb:SetScript("OnClick", function()
            SES():WaitForZone(zb.mapID)
            MainPanel:SwitchState("farming")
        end)
        zoneBtns[i] = zb
    end

    -- Bouton retour Oracle
    local backBtn = Btn(f, L.BTN_BACK_ORACLE, 80, 18)
    backBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    backBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    backBtn:SetScript("OnEnter", function() backBtn.label:SetTextColor(0.80, 0.80, 0.82) end)
    backBtn:SetScript("OnLeave", function() backBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3]) end)
    backBtn:SetScript("OnClick", function() MainPanel:SwitchState("idle") end)

    return {
        frame    = f,
        title    = title,
        zoneBtns = zoneBtns,
        backBtn  = backBtn,
    }
end

-- ============================================================
-- BUILD FARMING FRAME (‹ zone › + log loots + totaux + btns)
-- ============================================================
local function BuildFarmingFrame(content)
    local f = SubFrame(content)
    f:SetPoint("TOPLEFT",     content, "TOPLEFT",     0, 0)
    f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    -- Navigation zone : ‹ label ›
    local prevBtn = CreateFrame("Button", nil, f)
    prevBtn:SetSize(18, 22)
    prevBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local prevTxt = prevBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prevTxt:SetAllPoints(prevBtn)
    prevTxt:SetText("<")
    prevTxt:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    prevBtn:SetScript("OnEnter", function() prevTxt:SetTextColor(1, 1, 1) end)
    prevBtn:SetScript("OnLeave", function() prevTxt:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3]) end)

    local nextBtn = CreateFrame("Button", nil, f)
    nextBtn:SetSize(18, 22)
    nextBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    local nextTxt = nextBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nextTxt:SetAllPoints(nextBtn)
    nextTxt:SetText(">")
    nextTxt:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    nextBtn:SetScript("OnEnter", function() nextTxt:SetTextColor(1, 1, 1) end)
    nextBtn:SetScript("OnLeave", function() nextTxt:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3]) end)

    local zoneLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneLabel:SetPoint("LEFT",  prevBtn, "RIGHT",  4, 0)
    zoneLabel:SetPoint("RIGHT", nextBtn, "LEFT",  -4, 0)
    zoneLabel:SetJustifyH("CENTER")
    zoneLabel:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])

    -- Index local zone (pour ‹ ›)
    MainPanel.zoneIndex = 1
    prevBtn:SetScript("OnClick", function()
        MainPanel.zoneIndex = ((MainPanel.zoneIndex - 2) % #ZONE_LIST) + 1
        local mapID = ZONE_LIST[MainPanel.zoneIndex]
        SES():WaitForZone(mapID)
        MainPanel:RefreshFarming()
    end)
    nextBtn:SetScript("OnClick", function()
        MainPanel.zoneIndex = (MainPanel.zoneIndex % #ZONE_LIST) + 1
        local mapID = ZONE_LIST[MainPanel.zoneIndex]
        SES():WaitForZone(mapID)
        MainPanel:RefreshFarming()
    end)

    -- Separateur sous navigation
    HLine(f, -26, 0.08)

    -- Zone scroll loot
    local logFrame = CreateFrame("Frame", nil, f)
    logFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -32)
    logFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -32)
    logFrame:SetHeight(LOG_LINES * LOG_LINE_H)

    -- Lignes loot (pre-allocees)
    local logLines = {}
    for i = 1, LOG_LINES do
        local line = logFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetPoint("TOPLEFT",  logFrame, "TOPLEFT",  0, -(i - 1) * LOG_LINE_H)
        line:SetPoint("TOPRIGHT", logFrame, "TOPRIGHT", 0, -(i - 1) * LOG_LINE_H)
        line:SetJustifyH("LEFT")
        line:SetHeight(LOG_LINE_H)
        line:SetText("")
        logLines[i] = line
    end

    -- Separateur sous log
    local logSepY = -32 - LOG_LINES * LOG_LINE_H - 4
    HLine(f, logSepY, 0.08)

    -- Totaux : Plantes | Minerais | Total
    local totY = logSepY - 10

    local function TotalRow(yOff, label, colR, colG, colB)
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, yOff)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, yOff)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
        lbl:SetText(label)
        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        val:SetTextColor(colR, colG, colB)
        val:SetJustifyH("RIGHT")
        return lbl, val
    end

    local _, herbVal  = TotalRow(totY,       L.LABEL_HERB,  C_BEST[1],  C_BEST[2],  C_BEST[3])
    local _, oreVal   = TotalRow(totY - 20,  L.LABEL_ORE,   C_ORE[1],   C_ORE[2],   C_ORE[3])
    local _, totalVal = TotalRow(totY - 40,  L.LABEL_TOTAL, C_TOTAL[1], C_TOTAL[2], C_TOTAL[3])

    -- Separateur au dessus des boutons
    local btnSepY = totY - 62
    HLine(f, btnSepY, 0.08)

    -- Bouton Reset (bas gauche)
    local resetBtn = Btn(f, L.RESET_VISUAL, 60, 18)
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    resetBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    resetBtn:SetScript("OnEnter", function() resetBtn.label:SetTextColor(0.80, 0.80, 0.82) end)
    resetBtn:SetScript("OnLeave", function() resetBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3]) end)
    resetBtn:SetScript("OnClick", function()
        DB():ResetVisual()
        MainPanel:RefreshFarming()
    end)

    -- Bouton Historique (bas droite)
    local histBtn = Btn(f, L.BTN_HISTORY, 80, 18)
    histBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    histBtn:SetScript("OnClick", function() MainPanel:SwitchState("history") end)

    return {
        frame     = f,
        zoneLabel = zoneLabel,
        logFrame  = logFrame,
        logLines  = logLines,
        herbVal   = herbVal,
        oreVal    = oreVal,
        totalVal  = totalVal,
        resetBtn  = resetBtn,
        histBtn   = histBtn,
    }
end

-- ============================================================
-- BUILD HISTORY FRAME (log journalier des N derniers jours)
-- ============================================================
local HIST_ROWS = 7

local function BuildHistoryFrame(content)
    local f = SubFrame(content)
    f:SetPoint("TOPLEFT",     content, "TOPLEFT",     0, 0)
    f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    local title = FS(f, L.HISTORY_TITLE, "GameFontNormal",
        C_DIM[1], C_DIM[2], C_DIM[3])
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    HLine(f, -18, 0.08)

    -- En-tetes colonnes
    local hDate = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hDate:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -24)
    hDate:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    hDate:SetText(L.HISTORY_COL_DATE)

    local hHerb = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hHerb:SetPoint("TOP",   f, "TOP", -30, -24)
    hHerb:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])
    hHerb:SetJustifyH("RIGHT")
    hHerb:SetText(L.LABEL_HERB)

    local hOre = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hOre:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -24)
    hOre:SetTextColor(C_ORE[1], C_ORE[2], C_ORE[3])
    hOre:SetJustifyH("RIGHT")
    hOre:SetText(L.LABEL_ORE)

    -- Lignes historique
    local rows = {}
    for i = 1, HIST_ROWS do
        local yOff = -24 - 16 - (i - 1) * 18
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, yOff)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, yOff)

        local d = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        d:SetPoint("LEFT", row, "LEFT", 0, 0)
        d:SetTextColor(0.75, 0.75, 0.78)

        local herb = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        herb:SetPoint("CENTER", row, "CENTER", -30, 0)
        herb:SetJustifyH("RIGHT")
        herb:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])

        local ore = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ore:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        ore:SetJustifyH("RIGHT")
        ore:SetTextColor(C_ORE[1], C_ORE[2], C_ORE[3])

        rows[i] = { date = d, herb = herb, ore = ore }
    end

    -- Bouton retour
    local backBtn = Btn(f, L.BTN_BACK, 70, 18)
    backBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    backBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    backBtn:SetScript("OnEnter", function() backBtn.label:SetTextColor(0.80, 0.80, 0.82) end)
    backBtn:SetScript("OnLeave", function() backBtn.label:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3]) end)
    backBtn:SetScript("OnClick", function() MainPanel:SwitchState("farming") end)

    return {
        frame   = f,
        rows    = rows,
        backBtn = backBtn,
    }
end

-- ============================================================
-- Create : assemble tout
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

    -- Fond + bordure
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(C_BG[1], C_BG[2], C_BG[3], C_BG[4])
    GlimmerBorder(frame)

    BuildHeader(frame)

    -- Content zone (sous header)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",     frame, "TOPLEFT",     PAD,  -(HDR_H + 8))
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 14)
    self.content = content

    -- Construire les 4 sous-frames
    self.idle    = BuildIdleFrame(content)
    self.choose  = BuildChooseFrame(content)
    self.farming = BuildFarmingFrame(content)
    self.history = BuildHistoryFrame(content)

    -- Connecter les boutons Idle
    self.idle.calcBtn:SetScript("OnClick", function() self:OnCalcClick() end)
    self.idle.altBtn:SetScript("OnClick",  function() self:OnAltZoneClick() end)

    -- Adapter la taille du panel selon l'etat visible (hauteurs calculees)
    -- Ces valeurs seront definies dans SwitchState
    self.stateHeights = {
        idle    = 190,
        choose  = 180,
        farming = PANEL_H,
        history = PANEL_H,
    }

    -- Etat initial
    self:SwitchState("idle")
end

-- ============================================================
-- SwitchState : affiche le bon sous-frame, change la hauteur
-- ============================================================
function MainPanel:SwitchState(newState)
    self.viewState = newState
    self.idle.frame:SetShown(newState == "idle")
    self.choose.frame:SetShown(newState == "choose")
    self.farming.frame:SetShown(newState == "farming")
    self.history.frame:SetShown(newState == "history")

    local h = self.stateHeights[newState] or PANEL_H
    self.frame:SetHeight(h)

    if newState == "idle"    then self:RefreshIdle()    end
    if newState == "choose"  then self:RefreshChoose()  end
    if newState == "farming" then self:RefreshFarming() end
    if newState == "history" then self:RefreshHistory() end
end

-- ============================================================
-- RefreshIdle
-- ============================================================
function MainPanel:RefreshIdle()
    local w     = self.idle
    local oracle = DB():GetOracleResult()
    local isAvail = ORA():IsAuctionatorAvailable()

    w.calcBtn.label:SetText(oracle.priceDate and L.ORACLE_RECALCULATE or L.ORACLE_CALCULATE)
    w.priceDate:SetText(ORA():GetPriceDateLabel())

    if oracle.recommendedZone then
        local id1   = oracle.recommendedZone
        local name1 = ORA().ZONE_NAMES[id1] or "?"
        w.name1:SetText(name1)
        w.gold1:SetText(FormatGold(oracle.scores[id1] or 0))
        w.name1:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])
        w.gold1:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])

        local id2
        for mapID in pairs(ORA().ZONE_NAMES) do
            if mapID ~= id1 then id2 = mapID end
        end
        if id2 then
            w.name2:SetText(ORA().ZONE_NAMES[id2] or "?")
            w.gold2:SetText(FormatGold(oracle.scores[id2] or 0))
            w.name2:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
            w.gold2:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
            w.row2:Show()
        else
            w.row2:Hide()
        end
        w.row1:Show()
        w.altBtn:Show()
    elseif not isAvail then
        w.name1:SetText(L.ORACLE_NO_AUCTIONATOR)
        w.gold1:SetText("")
        w.name1:SetTextColor(C_WARN[1], C_WARN[2], C_WARN[3])
        w.gold1:SetTextColor(C_WARN[1], C_WARN[2], C_WARN[3])
        w.row1:Show()
        w.row2:Hide()
        w.altBtn:Hide()
    else
        w.name1:SetText(L.ORACLE_NOT_CALCULATED)
        w.gold1:SetText("")
        w.name1:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
        w.gold1:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
        w.row1:Show()
        w.row2:Hide()
        w.altBtn:Hide()
    end
end

-- ============================================================
-- RefreshChoose : surligne la zone recommandee en mint
-- ============================================================
function MainPanel:RefreshChoose()
    local oracle = DB():GetOracleResult()
    local w = self.choose
    for i, zb in ipairs(w.zoneBtns) do
        local isRec = oracle.recommendedZone == zb.mapID
        local r, g, b = isRec and C_BEST[1] or 0.60,
                         isRec and C_BEST[2] or 0.60,
                         isRec and C_BEST[3] or 0.62
        zb.label:SetTextColor(r, g, b)
    end
end

-- ============================================================
-- RefreshFarming : zone label + log + totaux
-- ============================================================
function MainPanel:RefreshFarming()
    local w   = self.farming
    local ses = SES()

    -- zone label
    if ses:IsActive() then
        w.zoneLabel:SetText(ses.state.zoneName)
        w.zoneLabel:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])
    elseif ses:IsWaiting() then
        local wz = ORA().ZONE_NAMES[ses:GetWaitingZone()] or "?"
        w.zoneLabel:SetText(format(L.SESSION_WAITING_SHORT, wz))
        w.zoneLabel:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    else
        w.zoneLabel:SetText(L.SESSION_NONE)
        w.zoneLabel:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
    end

    -- Log loots
    local log = ses.state.lootLog
    for i = 1, LOG_LINES do
        local entry = log[i]
        if entry then
            local name = entry.itemName
            local qtyStr = entry.qty > 1 and (" x"..entry.qty) or ""
            local valStr = FormatGold(entry.value)
            w.logLines[i]:SetText(format("%s%s  %s", name, qtyStr, valStr))
            if entry.resType == "HERB" then
                w.logLines[i]:SetTextColor(C_BEST[1], C_BEST[2], C_BEST[3])
            else
                w.logLines[i]:SetTextColor(C_ORE[1], C_ORE[2], C_ORE[3])
            end
        else
            w.logLines[i]:SetText("")
        end
    end

    -- Totaux
    local herbVal, oreVal = DB():GetDisplayTotals()
    local total = herbVal + oreVal
    w.herbVal:SetText(herbVal > 0 and FormatGold(herbVal) or "—")
    w.oreVal:SetText(oreVal   > 0 and FormatGold(oreVal)  or "—")
    w.totalVal:SetText(total  > 0 and FormatGold(total)   or "—")
end

-- ============================================================
-- RefreshHistory
-- ============================================================
function MainPanel:RefreshHistory()
    local w = self.history
    local hist = DB():GetHistory(HIST_ROWS)

    for i = 1, HIST_ROWS do
        local entry = hist[i]
        if entry then
            -- Afficher date courte : "12 Mar"
            local y, m, d = entry.date:match("(%d+)-(%d+)-(%d+)")
            local months = { "Jan","Feb","Mar","Apr","May","Jun",
                             "Jul","Aug","Sep","Oct","Nov","Dec" }
            local monthStr = months[tonumber(m)] or m
            w.rows[i].date:SetText(d.." "..monthStr)
            w.rows[i].herb:SetText(entry.goldHerb > 0 and FormatGold(entry.goldHerb) or "—")
            w.rows[i].ore:SetText(entry.goldOre   > 0 and FormatGold(entry.goldOre)  or "—")
        else
            w.rows[i].date:SetText("")
            w.rows[i].herb:SetText("")
            w.rows[i].ore:SetText("")
        end
    end
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
    self:RefreshIdle()
    self:SwitchState("choose")
end

-- ============================================================
-- Bouton Autre zone (idle -> choose)
-- ============================================================
function MainPanel:OnAltZoneClick()
    self:SwitchState("choose")
end

-- ============================================================
-- Toggle / Show
-- ============================================================
function MainPanel:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        if SES():IsActive() or SES():IsWaiting() then
            self:SwitchState("farming")
        else
            self:SwitchState("idle")
        end
        self.frame:Show()
    end
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
    if MainPanel.frame and MainPanel.frame:IsShown() then
        MainPanel:SwitchState("farming")
    end
end)

Meridian:RegisterCallback("SESSION_STOPPED", function()
    if MainPanel.frame and MainPanel.frame:IsShown() then
        MainPanel:SwitchState("idle")
    end
end)

Meridian:RegisterCallback("SESSION_WAITING_CHANGED", function()
    if MainPanel.viewState == "farming" then
        MainPanel:RefreshFarming()
    end
end)

Meridian:RegisterCallback("SESSION_LOOT_ADDED", function()
    if MainPanel.viewState == "farming" then
        MainPanel:RefreshFarming()
    end
end)

Meridian:RegisterCallback("RESET_ALL", function()
    if MainPanel.viewState == "farming" then
        MainPanel:RefreshFarming()
    elseif MainPanel.viewState == "idle" then
        MainPanel:RefreshIdle()
    end
end)
        else
            w.rows[i].date:SetText("")
            w.rows[i].herb:SetText("")
            w.rows[i].ore:SetText("")
        end
    end
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
    self:RefreshIdle()
    -- Transition vers choix de zone
    self:SwitchState("choose")
end

-- ============================================================
-- Bouton Autre zone (idle, clic sur altBtn)
-- ============================================================
function MainPanel:OnAltZoneClick()
    self:SwitchState("choose")
end

-- ============================================================
-- Toggle / Show
-- ============================================================
function MainPanel:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        -- Si session active, aller directement en farming
        if SES():IsActive() or SES():IsWaiting() then
            self:SwitchState("farming")
        else
            self:SwitchState("idle")
        end
        self.frame:Show()
    end
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
    if MainPanel.frame and MainPanel.frame:IsShown() then
        MainPanel:SwitchState("farming")
    end
end)

Meridian:RegisterCallback("SESSION_STOPPED", function()
    if MainPanel.frame and MainPanel.frame:IsShown() then
        MainPanel:SwitchState("idle")
    end
end)

Meridian:RegisterCallback("SESSION_WAITING_CHANGED", function()
    if MainPanel.viewState == "farming" then
        MainPanel:RefreshFarming()
    end
end)

Meridian:RegisterCallback("SESSION_LOOT_ADDED", function()
    if MainPanel.viewState == "farming" then
        MainPanel:RefreshFarming()
    end
end)

Meridian:RegisterCallback("RESET_ALL", function()
    if MainPanel.viewState == "farming" then
        MainPanel:RefreshFarming()
    elseif MainPanel.viewState == "idle" then
        MainPanel:RefreshIdle()
    end
end)

