-- ============================================================
-- Meridian — Main Addon (100% Native, Zero Dependencies)
-- Lightweight gathering node tracker
-- ============================================================
local addonName, ns = ...

local L = ns.L

-- ============================================================
-- Addon table
-- ============================================================
local Meridian = {}
ns.addon = Meridian

-- Chat prefix
local CHAT_PREFIX = "|cff3498db[Meridian]|r "

function Meridian:Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. text)
end

-- ============================================================
-- Simple callback system (replaces AceEvent messages)
-- ============================================================
local callbacks = {}

function Meridian:RegisterCallback(event, func)
    if not callbacks[event] then callbacks[event] = {} end
    callbacks[event][#callbacks[event] + 1] = func
end

function Meridian:FireCallback(event, ...)
    if not callbacks[event] then return end
    for _, func in ipairs(callbacks[event]) do
        func(...)
    end
end

-- ============================================================
-- Defaults for SavedVariables (Phase 2 — clés minimales)
-- Les vrais defaults sont définis dans Database.lua (Database.defaults)
-- ============================================================
local defaults = {
    minimap = {
        hide  = false,
        angle = 220,
    },
}

-- Deep copy a table
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

-- Merge defaults into saved (only fills missing keys)
local function MergeDefaults(saved, defs)
    for k, v in pairs(defs) do
        if saved[k] == nil then
            saved[k] = DeepCopy(v)
        elseif type(v) == "table" and type(saved[k]) == "table" then
            MergeDefaults(saved[k], v)
        end
    end
end

-- ============================================================
-- Main event frame
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Init SavedVariables
        -- On utilise les defaults de Database.lua qui contient zoneProfile + oracle + sessions
        local db_defaults = ns.Database and ns.Database.defaults or defaults
        if not MeridianDB then
            MeridianDB = DeepCopy(db_defaults)
        else
            MergeDefaults(MeridianDB, db_defaults)
        end
        Meridian.db = MeridianDB

        -- Init modules
        Meridian:FireCallback("INIT")

        -- Done
        Meridian:Msg(L.ADDON_LOADED)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ============================================================
-- Slash commands (native)
-- ============================================================
SLASH_MERIDIAN1 = "/meridian"
SLASH_MERIDIAN2 = "/mer"

SlashCmdList["MERIDIAN"] = function(input)
    local cmd = (input or ""):lower():match("^%s*(.-)%s*$")

    if cmd == "" then
        Meridian:FireCallback("TOGGLE_PANEL")

    elseif cmd == "reset" then
        Meridian:FireCallback("RESET_ALL")
        Meridian:Msg(L.CMD_RESET_DONE)

    else
        Meridian:Msg(L.CMD_HELP)
    end
end
