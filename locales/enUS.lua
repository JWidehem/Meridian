local _, ns = ...

-- Default locale (enUS) — fallback for all languages
local L = {
    -- General
    ADDON_LOADED = "Loaded \226\128\148 /mer to open",
    NEW_RESOURCE = "New resource: %s (id=%d)",
    NODE_RECORDED = "%s (%.2f, %.2f) \226\128\148 %d total",
    SPELL_LEARNED = "New gather spell learned: spellID %d",

    -- UI
    TITLE = "Meridian",
    TAB_ORES = "Ores",
    TAB_HERBS = "Herbs",
    TOTAL_NODES = "%d nodes",
    EXPORT_ALL = "Export for Claude",
    EXPORT_ZONE = "Export this zone",
    NO_DATA = "No data recorded yet.",
    EXPORT_TITLE = "Meridian \226\128\148 Export",
    SELECT_ALL = "Select All",
    EXPORT_STATUS = "%d lines \226\128\148 %d chars",
    EXPORT_READY = "Export ready \226\128\148 copy from the window.",

    CMD_RESET_CONFIRM = "Type /mer reset confirm to erase all data.",
    CMD_RESET_DONE = "All data has been erased.",

    -- Commands
    CMD_HELP = "Commands: /mer \226\128\148 toggle window | /mer routes \226\128\148 routes | /mer export \226\128\148 export | /mer reset \226\128\148 reset data",

    -- Commands
    CMD_HELP = "Commands: /mer \226\128\148 toggle window | /mer routes \226\128\148 routes | /mer export \226\128\148 export | /mer reset \226\128\148 reset data",

    -- Minimap
    TOOLTIP_NODES = "%d nodes recorded",
    TOOLTIP_RESOURCES = "%d ores, %d herbs",
    TOOLTIP_HINT = "|cffFFFFFFLeft-Click|r open | |cffFFFFFFRight-Click|r toggle tracking",
    TRACKING_ON = "Tracking enabled",
    TRACKING_OFF = "Tracking disabled",

    -- Routes
    TAB_ROUTES = "Routes",
    ROUTES_TITLE = "Meridian \226\128\148 Routes",
    NO_ROUTES = "No routes saved.",
    ROUTES_COUNT = "%d routes",
    ICON_HERB = "H",
    ICON_ORE = "M",
    ICON_ALL = "*",

    -- Navigation
    NAV_START = "Start",
    NAV_STOP = "Stop",
    NAV_PREV = "Prev",
    NAV_NEXT = "Next",
    NAV_ACTIVE = "Navigating",
    NAV_INACTIVE = "No active route",

    -- Import
    ROUTE_IMPORT = "Import route",
    ROUTE_DELETE = "Delete",
    IMPORT_TITLE = "Meridian \226\128\148 Import Route",
    IMPORT_INSTRUCTIONS = "Paste a JSON waypoint array below:",
    IMPORT_NAME = "Name:",
    IMPORT_FILTER = "Filter:",
    IMPORT_CONFIRM = "Import",
    IMPORT_SUCCESS = "Route imported: %d waypoints.",
    IMPORT_ERR_FORMAT = "Invalid format. Expected JSON array.",
    IMPORT_ERR_EMPTY = "No waypoints found in data.",
    IMPORT_ERR_NAME = "Please enter a route name.",
}

ns.L = L
ns.defaultLocale = L
