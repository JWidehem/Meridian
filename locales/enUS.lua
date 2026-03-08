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
    TAB_ZONE = "Zone",
    NO_DATA_ZONE = "Nothing collected here yet.",
    EXPORT_TITLE = "Meridian \226\128\148 Export",
    SELECT_ALL = "Select All",
    EXPORT_STATUS = "%d lines \226\128\148 %d chars",
    EXPORT_READY = "Export ready \226\128\148 copy from the window.",

    CMD_RESET_CONFIRM = "Type /mer reset confirm to erase all data.",
    CMD_RESET_DONE = "All data has been erased.",

    -- Commands
    CMD_HELP = "Commands: /mer \226\128\148 toggle window | /mer export \226\128\148 export | /mer reset \226\128\148 reset data",

    -- Minimap
    TOOLTIP_NODES = "%d nodes recorded",
    TOOLTIP_RESOURCES = "%d ores, %d herbs",
    TOOLTIP_HINT = "|cffFFFFFFLeft-Click|r open | |cffFFFFFFRight-Click|r toggle tracking",
    TRACKING_ON = "Tracking enabled",
    TRACKING_OFF = "Tracking disabled",

}

ns.L = L
ns.defaultLocale = L
