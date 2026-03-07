local _, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

-- General
L.ADDON_LOADED = "Charg\195\169 \226\128\148 /mer pour ouvrir"
L.NEW_RESOURCE = "Nouvelle ressource : %s (id=%d)"
L.NODE_RECORDED = "%s (%.2f, %.2f) \226\128\148 %d total"
L.SPELL_LEARNED = "Nouveau sort de r\195\169colte appris : spellID %d"

-- UI
L.TAB_ORES = "Minerais"
L.TAB_HERBS = "Plantes"
L.TOTAL_NODES = "%d noeuds"
L.EXPORT_ALL = "Exporter pour Claude"
L.EXPORT_ZONE = "Exporter cette zone"
L.NO_DATA = "Aucune donn\195\169e enregistr\195\169e."
L.EXPORT_TITLE = "Meridian \226\128\148 Export"
L.SELECT_ALL = "Tout s\195\169lectionner"
L.EXPORT_STATUS = "%d lignes \226\128\148 %d caract\195\168res"
L.EXPORT_READY = "Export pr\195\170t \226\128\148 copiez depuis la fen\195\170tre."

-- Commands
L.CMD_HELP = "Commandes : /mer \226\128\148 ouvrir | /mer routes \226\128\148 routes | /mer export \226\128\148 exporter | /mer reset \226\128\148 r\195\169initialiser"
L.CMD_RESET_CONFIRM = "Tapez /mer reset confirm pour effacer toutes les donn\195\169es."
L.CMD_RESET_DONE = "Toutes les donn\195\169es ont \195\169t\195\169 effac\195\169es."

-- Minimap
L.TOOLTIP_NODES = "%d noeuds enregistr\195\169s"
L.TOOLTIP_RESOURCES = "%d minerais, %d plantes"
L.TOOLTIP_HINT = "|cffFFFFFFClic gauche|r ouvrir | |cffFFFFFFClic droit|r tracking"
L.TRACKING_ON = "Tracking activ\195\169"
L.TRACKING_OFF = "Tracking d\195\169sactiv\195\169"

-- Routes
L.TAB_ROUTES = "Routes"
L.ROUTES_TITLE = "Meridian \226\128\148 Routes"
L.NO_ROUTES = "Aucune route sauvegard\195\169e."
L.ROUTES_COUNT = "%d routes"
L.ICON_HERB = "H"
L.ICON_ORE = "M"
L.ICON_ALL = "*"

-- Navigation
L.NAV_START = "D\195\169marrer"
L.NAV_STOP = "Arr\195\170ter"
L.NAV_PREV = "Pr\195\169c"
L.NAV_NEXT = "Suiv"
L.NAV_ACTIVE = "En route"
L.NAV_INACTIVE = "Aucune route active"

-- Import
L.ROUTE_IMPORT = "Importer une route"
L.ROUTE_DELETE = "Supprimer"
L.IMPORT_TITLE = "Meridian \226\128\148 Importer une route"
L.IMPORT_INSTRUCTIONS = "Collez un tableau JSON de waypoints ci-dessous :"
L.IMPORT_NAME = "Nom :"
L.IMPORT_FILTER = "Filtre :"
L.IMPORT_CONFIRM = "Importer"
L.IMPORT_SUCCESS = "Route import\195\169e : %d waypoints."
L.IMPORT_ERR_FORMAT = "Format invalide. Tableau JSON attendu."
L.IMPORT_ERR_EMPTY = "Aucun waypoint trouv\195\169 dans les donn\195\169es."
L.IMPORT_ERR_NAME = "Veuillez entrer un nom de route."
