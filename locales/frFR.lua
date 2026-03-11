local _, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

-- General
L.ADDON_LOADED = "Charg\195\169 \226\128\148 /mer pour ouvrir"

-- Commands
L.CMD_HELP          = "Commandes : /mer \226\128\148 ouvrir | /mer session \226\128\148 arr\195\170ter session | /mer reset \226\128\148 r\195\169initialiser"
L.CMD_RESET_CONFIRM = "Tapez /mer reset confirm pour effacer l'historique des sessions."
L.CMD_RESET_DONE    = "Historique effac\195\169."
L.CMD_SESSION_HINT  = "Utilisez le panneau Oracle pour d\195\169marrer une session."

-- Oracle
L.ORACLE_RECOMMENDATION = "Zone recommand\195\169e :"
L.ORACLE_CALCULATE      = "Calculer"
L.ORACLE_RECALCULATE    = "Recalculer"
L.ORACLE_CHOOSE_OTHER   = "Choisir l'autre zone"
L.ORACLE_NO_AUCTIONATOR = "Auctionator requis"
L.ORACLE_NOT_CALCULATED = "Pas encore calcul\195\169"
L.ORACLE_NO_PRICES      = "Prix non disponibles"
L.ORACLE_PRICE_DATE     = "Prix du %s"
L.ORACLE_NO_DATA        = "Aucune donn\195\169e pour calculer."

-- Session
L.SESSION_STARTED       = "Session d\195\169marr\195\169e : %s"
L.SESSION_STOPPED       = "Session termin\195\169e : %s \226\128\148 %s (%s/h)"
L.SESSION_PAUSED        = "Session mise en pause."
L.SESSION_RESUMED       = "Session reprise."
L.SESSION_WAITING       = "En attente de la zone : %s \226\128\148 la session d\195\169marrera automatiquement."
L.SESSION_WAITING_SHORT = "En attente : %s"
L.SESSION_IN_PROGRESS   = "Session en cours"
L.SESSION_IN_ZONE       = "Farming : %s"
L.SESSION_NONE          = "Aucune session active"
L.SESSION_PAUSE         = "Pause"
L.SESSION_RESUME        = "Reprendre"
L.SESSION_STOP          = "Arr\195\170ter"
L.SESSION_PAUSED_SHORT  = "en pause"

-- History
L.HISTORY_TITLE = "Derni\195\168res sessions :"
L.HISTORY_AVG   = "Moy. : %s/h"

-- Minimap
L.TOOLTIP_HINT    = "|cffFFFFFFClic gauche|r ouvrir | |cffFFFFFFClic droit|r pause session"
L.TOOLTIP_WAITING = "En attente : %s"


