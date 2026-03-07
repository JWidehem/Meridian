-- ============================================================
-- Meridian — StatsPanel Module
-- Fenêtre principale avec onglets Minerais/Plantes
-- Style sombre inspiré du mockup macOS
-- ============================================================
local addonName, ns = ...
local Meridian = LibStub("AceAddon-3.0"):GetAddon(addonName)
local StatsPanel = Meridian:NewModule("StatsPanel", "AceEvent-3.0")
local L = ns.L

-- Cache
local pairs = pairs
local ipairs = ipairs
local format = string.format
local math_max = math.max

-- Dimensions
local FRAME_WIDTH = 320
local FRAME_MIN_HEIGHT = 300
local ROW_HEIGHT = 38
local MAX_VISIBLE_ROWS = 8

-- Couleurs UI
local BG_COLOR     = { 0.06, 0.06, 0.10, 0.95 }
local BORDER_COLOR = { 0.18, 0.18, 0.22, 0.80 }
local TAB_ACTIVE   = { 0.14, 0.14, 0.20, 1.00 }
local TAB_INACTIVE = { 0.08, 0.08, 0.12, 1.00 }
local TITLE_COLOR  = { 0.20, 0.60, 0.86 }
local TEXT_DIM     = { 0.50, 0.50, 0.55 }

-- ============================================================
-- Lifecycle
-- ============================================================
function StatsPanel:OnEnable()
    self:RegisterMessage("MERIDIAN_NODE_RECORDED", "OnNodeRecorded")
    self:RegisterMessage("MERIDIAN_RESOURCE_DISCOVERED", "OnResourceDiscovered")
    self:RegisterMessage("MERIDIAN_DATA_RESET", "OnDataReset")
    self.activeTab = "ORE"
end

function StatsPanel:OnNodeRecorded()
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

function StatsPanel:OnResourceDiscovered()
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

function StatsPanel:OnDataReset()
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

-- ============================================================
-- Toggle / Show / Hide
-- ============================================================
function StatsPanel:Toggle()
    if not self.frame then
        self:CreateFrame()
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Refresh()
        self.frame:Show()
    end
end

function StatsPanel:Show()
    if not self.frame then
        self:CreateFrame()
    end
    self:Refresh()
    self.frame:Show()
end

-- ============================================================
-- Création de la fenêtre principale
-- ============================================================
function StatsPanel:CreateFrame()
    local frame = CreateFrame("Frame", "MeridianStatsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_MIN_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
    end)

    -- Backdrop sombre
    frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], BG_COLOR[4])
    frame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])

    -- ========================
    -- Barre de titre
    -- ========================
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(40)

    -- Titre "Meridian"
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 16, 0)
    title:SetText(L["TITLE"])
    title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])

    -- Compteur de nodes (à droite du titre)
    local nodeCount = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nodeCount:SetPoint("RIGHT", -14, 0)
    nodeCount:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    frame.nodeCountText = nodeCount

    -- Bouton fermer (discret, coin supérieur droit)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetNormalFontObject("GameFontNormalSmall")

    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    closeTex:SetVertexColor(0.4, 0.4, 0.45, 0.6)

    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeLabel:SetPoint("CENTER", 0, 0)
    closeLabel:SetText("x")
    closeLabel:SetTextColor(0.6, 0.6, 0.6)

    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(0.8, 0.2, 0.2, 0.8)
        closeLabel:SetTextColor(1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(0.4, 0.4, 0.45, 0.6)
        closeLabel:SetTextColor(0.6, 0.6, 0.6)
    end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Séparateur sous le titre
    local sep1 = frame:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 12, -40)
    sep1:SetPoint("TOPRIGHT", -12, -40)
    sep1:SetHeight(1)
    sep1:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sep1:SetVertexColor(0.20, 0.20, 0.25, 0.6)

    -- ========================
    -- Onglets
    -- ========================
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 0, -44)
    tabBar:SetPoint("TOPRIGHT", 0, -44)
    tabBar:SetHeight(32)

    frame.tabOre = self:CreateTab(tabBar, "\226\155\143 " .. L["TAB_ORES"], "LEFT", 12, function()
        self.activeTab = "ORE"
        self:RefreshTabs()
        self:RefreshList()
    end)

    frame.tabHerb = self:CreateTab(tabBar, "\240\159\140\191 " .. L["TAB_HERBS"], "LEFT", FRAME_WIDTH / 2 + 2, function()
        self.activeTab = "HERB"
        self:RefreshTabs()
        self:RefreshList()
    end)

    -- ========================
    -- Zone de contenu (liste scrollable)
    -- ========================
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", 8, -80)
    contentFrame:SetPoint("BOTTOMRIGHT", -8, 80)
    frame.contentFrame = contentFrame

    -- Message "pas de données"
    local emptyText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    emptyText:SetText(L["NO_DATA"])
    frame.emptyText = emptyText

    -- Pool de rows
    frame.rows = {}

    -- ========================
    -- Boutons d'export
    -- ========================
    local btnExportAll = self:CreateButton(frame, L["EXPORT_CLAUDE"], TITLE_COLOR, function()
        local Export = Meridian:GetModule("Export", true)
        if Export then Export:ExportAll() end
    end)
    btnExportAll:SetPoint("BOTTOMLEFT", 12, 42)
    btnExportAll:SetPoint("BOTTOMRIGHT", -12, 42)
    btnExportAll:SetHeight(30)

    local btnExportZone = self:CreateButton(frame, L["EXPORT_ZONE"], TEXT_DIM, function()
        local Export = Meridian:GetModule("Export", true)
        if Export then Export:ExportZone() end
    end)
    btnExportZone:SetPoint("BOTTOMLEFT", 12, 8)
    btnExportZone:SetPoint("BOTTOMRIGHT", -12, 8)
    btnExportZone:SetHeight(30)

    -- Échap pour fermer
    tinsert(UISpecialFrames, "MeridianStatsFrame")

    frame:Hide()
    self.frame = frame
end

-- ============================================================
-- Création d'un onglet
-- ============================================================
function StatsPanel:CreateTab(parent, text, anchorSide, xOffset, onClick)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(FRAME_WIDTH / 2 - 14, 28)
    tab:SetPoint(anchorSide, xOffset, 0)

    tab:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })

    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    tab.label = label

    tab:SetScript("OnClick", onClick)

    tab:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(0.12, 0.12, 0.18, 1)
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(TAB_INACTIVE[1], TAB_INACTIVE[2], TAB_INACTIVE[3], TAB_INACTIVE[4])
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end)

    return tab
end

-- ============================================================
-- Création d'un bouton d'export
-- ============================================================
function StatsPanel:CreateButton(parent, text, color, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")

    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.10, 0.10, 0.16, 1)
    btn:SetBackdropBorderColor(color[1], color[2], color[3], 0.5)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("\226\134\151 " .. text)
    label:SetTextColor(color[1], color[2], color[3])
    btn.label = label

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, 1)
        btn:SetBackdropBorderColor(color[1], color[2], color[3], 0.9)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.10, 0.10, 0.16, 1)
        btn:SetBackdropBorderColor(color[1], color[2], color[3], 0.5)
    end)

    return btn
end

-- ============================================================
-- Refresh complet
-- ============================================================
function StatsPanel:Refresh()
    if not self.frame then return end

    local Database = Meridian:GetModule("Database")
    local total = Database:GetTotalNodeCount()

    -- Mise à jour du compteur de nodes
    self.frame.nodeCountText:SetText(format(L["NODES_COUNT"], total))

    self:RefreshTabs()
    self:RefreshList()
end

-- ============================================================
-- Refresh des onglets (état actif/inactif)
-- ============================================================
function StatsPanel:RefreshTabs()
    if not self.frame then return end

    local tabOre = self.frame.tabOre
    local tabHerb = self.frame.tabHerb

    if self.activeTab == "ORE" then
        tabOre.isActive = true
        tabOre:SetBackdropColor(TAB_ACTIVE[1], TAB_ACTIVE[2], TAB_ACTIVE[3], TAB_ACTIVE[4])
        tabOre:SetBackdropBorderColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], 0.6)
        tabOre.label:SetTextColor(1, 1, 1)

        tabHerb.isActive = false
        tabHerb:SetBackdropColor(TAB_INACTIVE[1], TAB_INACTIVE[2], TAB_INACTIVE[3], TAB_INACTIVE[4])
        tabHerb:SetBackdropBorderColor(0, 0, 0, 0)
        tabHerb.label:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    else
        tabHerb.isActive = true
        tabHerb:SetBackdropColor(TAB_ACTIVE[1], TAB_ACTIVE[2], TAB_ACTIVE[3], TAB_ACTIVE[4])
        tabHerb:SetBackdropBorderColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], 0.6)
        tabHerb.label:SetTextColor(1, 1, 1)

        tabOre.isActive = false
        tabOre:SetBackdropColor(TAB_INACTIVE[1], TAB_INACTIVE[2], TAB_INACTIVE[3], TAB_INACTIVE[4])
        tabOre:SetBackdropBorderColor(0, 0, 0, 0)
        tabOre.label:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    end
end

-- ============================================================
-- Refresh de la liste de ressources
-- ============================================================
function StatsPanel:RefreshList()
    if not self.frame then return end

    local Database = Meridian:GetModule("Database")
    local resources = Database:GetKnownResourcesByType(self.activeTab)

    -- Cacher toutes les rows existantes
    for _, row in ipairs(self.frame.rows) do
        row:Hide()
    end

    -- Construire les données triées par nombre de nodes (desc)
    local sorted = {}
    for itemID, info in pairs(resources) do
        local count = Database:GetResourceCount(itemID)
        sorted[#sorted + 1] = {
            itemID = itemID,
            name   = info.name,
            count  = count,
            color  = Database:GetResourceColor(itemID),
        }
    end

    table.sort(sorted, function(a, b)
        return a.count > b.count
    end)

    -- Afficher le message vide si pas de données
    if #sorted == 0 then
        self.frame.emptyText:Show()
        self:ResizeFrame(0)
        return
    end
    self.frame.emptyText:Hide()

    -- Trouver le max pour normaliser les barres
    local maxCount = 1
    for _, data in ipairs(sorted) do
        if data.count > maxCount then maxCount = data.count end
    end

    -- Créer / réutiliser les rows
    local contentFrame = self.frame.contentFrame
    for i, data in ipairs(sorted) do
        local row = self.frame.rows[i]
        if not row then
            row = self:CreateRow(contentFrame, i)
            self.frame.rows[i] = row
        end

        -- Positionner
        row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

        -- Mise à jour des données
        local c = data.color
        row.indicator:SetVertexColor(c[1], c[2], c[3], 1)
        row.bar:SetMinMaxValues(0, maxCount)
        row.bar:SetValue(data.count)
        row.bar:SetStatusBarColor(c[1], c[2], c[3], 0.25)
        row.name:SetText(data.name)
        row.count:SetText(format("%d", data.count))
        row.count:SetTextColor(c[1], c[2], c[3])

        row:Show()
    end

    self:ResizeFrame(#sorted)
end

-- ============================================================
-- Création d'une row de ressource
-- ============================================================
function StatsPanel:CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    -- Indicateur coloré (barre verticale gauche)
    row.indicator = row:CreateTexture(nil, "ARTWORK")
    row.indicator:SetPoint("LEFT", 4, 0)
    row.indicator:SetSize(3, 26)
    row.indicator:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")

    -- Background de la row (hover)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    row.bg:SetVertexColor(1, 1, 1, 0)

    -- Barre de progression (behind le texte)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("LEFT", row.indicator, "RIGHT", 6, 0)
    row.bar:SetPoint("RIGHT", -8, 0)
    row.bar:SetHeight(26)
    row.bar:SetStatusBarTexture("Interface\\ChatFrame\\ChatFrameBackground")

    -- Fond de la barre
    local barBg = row.bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    barBg:SetVertexColor(0.10, 0.10, 0.15, 0.5)

    -- Nom de la ressource
    row.name = row.bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetTextColor(0.92, 0.92, 0.92)
    row.name:SetJustifyH("LEFT")

    -- Compteur
    row.count = row.bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.count:SetPoint("RIGHT", -8, 0)
    row.count:SetJustifyH("RIGHT")

    -- Hover effect
    row:EnableMouse(true)
    row:SetScript("OnEnter", function()
        row.bg:SetVertexColor(1, 1, 1, 0.04)
    end)
    row:SetScript("OnLeave", function()
        row.bg:SetVertexColor(1, 1, 1, 0)
    end)

    return row
end

-- ============================================================
-- Redimensionnement dynamique de la fenêtre
-- ============================================================
function StatsPanel:ResizeFrame(numRows)
    if not self.frame then return end

    -- Header (titre + tabs) = ~80px + rows + boutons (2x30+gaps) = ~80px
    local contentHeight = math_max(numRows * ROW_HEIGHT, 40)
    local totalHeight = 80 + contentHeight + 80

    totalHeight = math_max(totalHeight, FRAME_MIN_HEIGHT)
    self.frame:SetHeight(totalHeight)
end
