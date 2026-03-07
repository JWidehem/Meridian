-- ============================================================
-- Meridian — Export Module (100% Native)
-- Serialisation JSON personnalisee + fenetre de copie
-- ============================================================
local addonName, ns = ...
local Meridian = ns.addon
local Database = ns.Database
local L = ns.L

local Export = {}
ns.Export = Export

local format = string.format

-- ============================================================
-- JSON Serializer
-- ============================================================
local function EscapeJSON(str)
    if type(str) ~= "string" then return tostring(str) end
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

local SerializeValue, SerializeTable

SerializeValue = function(val, indent)
    local t = type(val)
    if t == "string" then
        return '"' .. EscapeJSON(val) .. '"'
    elseif t == "number" then
        if val == math.floor(val) then
            return tostring(math.floor(val))
        end
        return format("%.4f", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        return SerializeTable(val, indent)
    else
        return "null"
    end
end

SerializeTable = function(tbl, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local padInner = string.rep("  ", indent + 1)

    -- Array detection : consecutive integer keys starting at 1
    local isArray = true
    local maxN = 0
    for k in pairs(tbl) do
        if type(k) == "number" and k == math.floor(k) and k > 0 then
            if k > maxN then maxN = k end
        else
            isArray = false
            break
        end
    end
    if maxN == 0 then isArray = false end

    local parts = {}
    if isArray then
        for i = 1, maxN do
            parts[#parts + 1] = padInner .. SerializeValue(tbl[i], indent + 1)
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    else
        local keys = {}
        for k in pairs(tbl) do
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = padInner .. '"' .. EscapeJSON(tostring(k)) .. '": '
                .. SerializeValue(tbl[k], indent + 1)
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
    end
end

function Export:ToJSON(data)
    return SerializeValue(data, 0)
end

-- ============================================================
-- AI Prompt Template
-- ============================================================
local AI_PROMPT_TEMPLATE = [[
## Meridian — Gathering Data Export
### Addon: %s | Date: %s | Character: %s - %s

You are an AI assistant specialized in World of Warcraft route optimization.
Below is a JSON dataset of gathering nodes collected by the Meridian addon.

Each node contains:
- **itemID** / **itemName**: the resource gathered
- **resourceType**: "HERB" or "ORE"
- **mapID** / **zoneName** / **subZone**: location identifiers
- **x**, **y**: coordinates (0-100 scale)
- **count**: number of times gathered at this location
- **firstSeen** / **lastSeen**: unix timestamps

### Instructions:
1. Analyze node density and distribution per zone
2. Identify clusters (nodes within 2%% distance)
3. Suggest an optimal circular route minimizing travel distance
4. Highlight high-yield zones and rare resources
5. Estimate route completion time based on mount speed

### Data:
```json
%s
```
]]

-- ============================================================
-- Build export string
-- ============================================================
function Export:BuildExport(zoneOnly)
    local mapID = nil
    if zoneOnly then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    local data = Database:GetExportData(mapID)
    if not data or not next(data) then
        return nil, L.NO_DATA
    end

    local json = self:ToJSON(data)
    local playerName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    local dateStr = date("%Y-%m-%d %H:%M:%S")

    local output = format(AI_PROMPT_TEMPLATE,
        addonName, dateStr, playerName, realmName, json)

    return output
end

-- ============================================================
-- Export Frame (native ScrollFrame + EditBox pour copier)
-- ============================================================
local exportFrame = nil

function Export:ShowExportWindow(text)
    if not exportFrame then
        exportFrame = CreateFrame("Frame", "MeridianExportFrame", UIParent, "BackdropTemplate")
        exportFrame:SetSize(700, 500)
        exportFrame:SetPoint("CENTER")
        exportFrame:SetFrameStrata("DIALOG")
        exportFrame:SetMovable(true)
        exportFrame:EnableMouse(true)
        exportFrame:RegisterForDrag("LeftButton")
        exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
        exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)

        exportFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        exportFrame:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        exportFrame:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)

        -- Title
        local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText(L.EXPORT_TITLE)
        title:SetTextColor(0.9, 0.8, 0.2)

        -- Close button
        local closeBtn = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)

        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", "MeridianExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 12, -40)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        -- EditBox
        local editBox = CreateFrame("EditBox", "MeridianExportEditBox", scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetWidth(scrollFrame:GetWidth() or 640)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)

        exportFrame.editBox = editBox

        -- Select All button
        local selectBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
        selectBtn:SetSize(140, 24)
        selectBtn:SetPoint("BOTTOMLEFT", 12, 10)
        selectBtn:SetText(L.SELECT_ALL)
        selectBtn:SetScript("OnClick", function()
            exportFrame.editBox:SetFocus()
            exportFrame.editBox:HighlightText()
        end)

        -- Status
        local status = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("BOTTOM", 0, 14)
        status:SetTextColor(0.6, 0.6, 0.6)
        exportFrame.status = status

        table.insert(UISpecialFrames, "MeridianExportFrame")
    end

    exportFrame.editBox:SetText(text)
    local lineCount = select(2, text:gsub("\n", "")) + 1
    local charCount = #text
    exportFrame.status:SetText(format(L.EXPORT_STATUS, lineCount, charCount))
    exportFrame:Show()

    C_Timer.After(0.1, function()
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end)
end

-- ============================================================
-- Public API
-- ============================================================
function Export:ExportAll()
    local text, err = self:BuildExport(false)
    if not text then
        Meridian:Msg(err or L.NO_DATA)
        return
    end
    self:ShowExportWindow(text)
    Meridian:Msg(L.EXPORT_READY)
end

function Export:ExportZone()
    local text, err = self:BuildExport(true)
    if not text then
        Meridian:Msg(err or L.NO_DATA)
        return
    end
    self:ShowExportWindow(text)
    Meridian:Msg(L.EXPORT_READY)
end

-- Register slash command callbacks
Meridian:RegisterCallback("EXPORT_ALL", function()
    Export:ExportAll()
end)

Meridian:RegisterCallback("EXPORT_ZONE", function()
    Export:ExportZone()
end)
