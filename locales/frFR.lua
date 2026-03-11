local _, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

-- General
L.ADDON_LOADED = "Charge -- /mer pour ouvrir"

-- Commands
L.CMD_HELP       = "Commandes : /mer (ouvrir) | /mer reset (reset affichage)"
L.CMD_RESET_DONE = "Affichage reinitialise."

-- Oracle
L.ORACLE_CALCULATE      = "Analyser"
L.ORACLE_RECALCULATE    = "Re-analyser"
L.ORACLE_CHOOSE_OTHER   = "Autre zone"
L.ORACLE_NO_AUCTIONATOR = "Auctionator requis"
L.ORACLE_NOT_CALCULATED = "Pas encore analyse"
L.ORACLE_NO_PRICES      = "Prix non disponibles"
L.ORACLE_PRICE_DATE     = "Prix du %s"
L.ORACLE_NO_DATA        = "Aucune donnee pour calculer."

-- Session
L.SESSION_STARTED       = "Tracking demarre : %s"
L.SESSION_WAITING       = "En attente de la zone : %s"
L.SESSION_WAITING_SHORT = "En attente : %s"
L.SESSION_NONE          = "Aucune zone active"

-- Totals
L.LABEL_HERB  = "\230\152\191 Plantes"
L.LABEL_ORE   = "\226\155\143 Minerais"
L.RESET_VISUAL = "Reset aff."

-- Minimap tooltip
L.TOOLTIP_HINT    = "|cffFFFFFFClic gauche|r ouvrir  |cffFFFFFFClic droit|r stop"
L.TOOLTIP_WAITING = "En attente : %s"


