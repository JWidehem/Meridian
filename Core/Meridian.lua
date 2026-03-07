-- ============================================================
-- Meridian — Main Addon Init
-- Lightweight gathering node tracker for farming route optimization
-- ============================================================
local addonName, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
ns.L = L

-- Couleur du préfixe chat
local CHAT_PREFIX = "|cff3498db[Meridian]|r "

-- ============================================================
-- Création de l'addon AceAddon
-- ============================================================
local Meridian = LibStub("AceAddon-3.0"):NewAddon(
    addonName,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0"
)
ns.addon = Meridian
Meridian.ns = ns

-- ============================================================
-- Defaults AceDB
-- ============================================================
local defaults = {
    profile = {
        enabled = true,
        tracking = {
            trackHerbs = true,
            trackOres = true,
            chatMessages = true,
        },
        minimap = {
            hide = false,
        },
    },
    global = {
        -- Nodes par zone : [mapID] = { {node}, {node}, ... }
        nodes = {},
        -- Ressources auto-découvertes : [itemID] = { type, name, firstSeen, colorIndex }
        knownResources = {},
        -- Sorts de récolte appris dynamiquement : [spellID] = "HERB"|"ORE"
        learnedSpells = {},
        -- Prochain index de couleur à attribuer
        nextColorIndex = 1,
    },
}

-- ============================================================
-- Lifecycle
-- ============================================================
function Meridian:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MeridianDB", defaults, true)

    self:RegisterChatCommand("meridian", "HandleCommand")
    self:RegisterChatCommand("mer", "HandleCommand")
end

function Meridian:OnEnable()
    self:Msg(L["ADDON_LOADED"])
end

function Meridian:OnDisable()
end

-- ============================================================
-- Message helper (préfixé [Meridian])
-- ============================================================
function Meridian:Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. text)
end

-- ============================================================
-- Commandes slash
-- ============================================================
function Meridian:HandleCommand(input)
    local cmd = (input or ""):lower():trim()

    if cmd == "" then
        -- Toggle la fenêtre principale
        local StatsPanel = self:GetModule("StatsPanel", true)
        if StatsPanel then
            StatsPanel:Toggle()
        end

    elseif cmd == "export" then
        local Export = self:GetModule("Export", true)
        if Export then Export:ExportAll() end

    elseif cmd == "reset confirm" then
        local Database = self:GetModule("Database", true)
        if Database then
            Database:ResetAll()
            self:Msg(L["CMD_RESET_DONE"])
        end

    elseif cmd == "reset" then
        self:Msg(L["CMD_RESET_CONFIRM"])

    else
        self:Msg(L["CMD_HELP"])
    end
end
