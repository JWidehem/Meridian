-- ============================================================
-- Meridian — Export Module
-- Génération JSON/CSV et fenêtre de copie
-- ============================================================
local addonName, ns = ...
local Meridian = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Export = Meridian:NewModule("Export")
local L = ns.L

-- Cache
local format = string.format
local tconcat = table.concat
local tinsert = table.insert
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local date = date

-- ============================================================
-- Sérialiseur JSON léger (structure connue, pas générique)
-- ============================================================
local function EscapeJSON(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

local SerializeValue -- forward declaration

local function SerializeTable(t, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent + 1)
    local closing = string.rep("  ", indent)
    local parts = {}

    -- Déterminer si c'est un array (clés numériques consécutives)
    local isArray = true
    local maxN = 0
    for k in pairs(t) do
        if type(k) == "number" then
            if k > maxN then maxN = k end
        else
            isArray = false
            break
        end
    end
    if isArray and maxN ~= #t then isArray = false end

    if isArray then
        for i = 1, #t do
            parts[#parts + 1] = prefix .. SerializeValue(t[i], indent + 1)
        end
        if #parts == 0 then return "[]" end
        return "[\n" .. tconcat(parts, ",\n") .. "\n" .. closing .. "]"
    else
        -- Collecter et trier les clés pour un output déterministe
        local keys = {}
        for k in pairs(t) do
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        for _, k in ipairs(keys) do
            local keyStr = '"' .. EscapeJSON(tostring(k)) .. '"'
            parts[#parts + 1] = prefix .. keyStr .. ": " .. SerializeValue(t[k], indent + 1)
        end
        if #parts == 0 then return "{}" end
        return "{\n" .. tconcat(parts, ",\n") .. "\n" .. closing .. "}"
    end
end

SerializeValue = function(v, indent)
    local t = type(v)
    if t == "string" then
        return '"' .. EscapeJSON(v) .. '"'
    elseif t == "number" then
        -- Éviter la notation scientifique pour les coordonnées
        if v == math.floor(v) then
            return tostring(v)
        end
        return format("%.2f", v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "nil" then
        return "null"
    elseif t == "table" then
        return SerializeTable(v, indent)
    end
    return '"[unsupported]"'
end

-- ============================================================
-- Construction du payload d'export
-- ============================================================
function Export:BuildExportPayload(mapID)
    local Database = Meridian:GetModule("Database")
    local zoneData = Database:GetExportData(mapID)

    -- Construire les zones avec nodes nettoyés (sans données internes)
    local zones = {}
    for zoneKey, zone in pairs(zoneData) do
        local cleanNodes = {}
        for i, node in ipairs(zone.nodes) do
            cleanNodes[#cleanNodes + 1] = {
                id             = i,
                item_id        = node.itemID,
                item_name      = node.itemName,
                resource_type  = node.resourceType,
                x              = node.x,
                y              = node.y,
                sub_zone       = node.subZone,
                timestamp      = node.timestamp,
            }
        end

        zones[zoneKey] = {
            zone_name   = zone.zone_name,
            map_id      = zone.map_id,
            nodes       = cleanNodes,
            summary     = zone.summary,
        }
    end

    local payload = {
        export_version = "1.0",
        addon_version  = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev",
        export_date    = date("!%Y-%m-%dT%H:%M:%SZ"),
        wow_patch      = "12.0.1",
        total_nodes    = Database:GetTotalNodeCount(),
        zones          = zones,
    }

    return payload
end

-- ============================================================
-- Export complet (toutes zones) avec prompt IA
-- ============================================================
function Export:ExportAll()
    local Database = Meridian:GetModule("Database")
    if Database:GetTotalNodeCount() == 0 then
        Meridian:Msg(L["NO_DATA"])
        return
    end

    local payload = self:BuildExportPayload(nil)
    local json = SerializeValue(payload, 0)

    local prompt = [[
--- MERIDIAN EXPORT ---
Voici mes données de farming WoW au format JSON.

Génère une route optimisée de farming en tenant compte de :
- La densité de nodes par zone de la carte
- Un parcours en boucle fermée (départ = arrivée)
- L'évitement des zones sans nodes
- La priorité aux clusters de nodes denses

Retourne la route sous forme d'une liste ordonnée de waypoints :
{ "order": N, "x": XX.XX, "y": XX.XX, "note": "..." }

--- DONNÉES ---
]]

    self:ShowExportFrame(prompt .. json)
end

-- ============================================================
-- Export d'une seule zone
-- ============================================================
function Export:ExportZone(mapID)
    if not mapID then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if not mapID then
        Meridian:Msg(L["NO_DATA"])
        return
    end

    local Database = Meridian:GetModule("Database")
    local zoneNodes = Database:GetNodesByZone(mapID)
    if #zoneNodes == 0 then
        Meridian:Msg(L["NO_DATA"])
        return
    end

    local payload = self:BuildExportPayload(mapID)
    local json = SerializeValue(payload, 0)
    self:ShowExportFrame(json)
end

-- ============================================================
-- Fenêtre d'export (EditBox copiable)
-- ============================================================
function Export:ShowExportFrame(content)
    if not self.exportFrame then
        self:CreateExportFrame()
    end

    self.exportFrame.editBox:SetText(content)
    self.exportFrame:Show()

    -- Sélectionner tout le texte pour faciliter la copie
    C_Timer.After(0.1, function()
        if self.exportFrame and self.exportFrame:IsShown() then
            self.exportFrame.editBox:SetFocus()
            self.exportFrame.editBox:HighlightText()
        end
    end)
end

function Export:CreateExportFrame()
    local frame = CreateFrame("Frame", "MeridianExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 450)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.06, 0.06, 0.10, 0.97)
    frame:SetBackdropBorderColor(0.20, 0.20, 0.25, 1)

    -- Titre
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(L["EXPORT_TITLE"])
    title:SetTextColor(0.20, 0.60, 0.86)

    -- Instructions
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOPRIGHT", -36, -14)
    instructions:SetText(L["EXPORT_INSTRUCTIONS"])
    instructions:SetTextColor(0.6, 0.6, 0.6)

    -- Bouton fermer
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)

    -- ScrollFrame + EditBox
    local scrollFrame = CreateFrame("ScrollFrame", "MeridianExportScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

    local editBox = CreateFrame("EditBox", "MeridianExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() or 540)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox

    -- Échap pour fermer
    tinsert(UISpecialFrames, "MeridianExportFrame")

    frame:Hide()
    self.exportFrame = frame
end
