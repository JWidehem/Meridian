local _, ns = ...

-- Default locale (enUS) -- fallback for all languages
local L = {
    -- General
    ADDON_LOADED = "Loaded -- /mer to open",

    -- Commands
    CMD_HELP       = "Commands: /mer (toggle) | /mer reset (reset display)",
    CMD_RESET_DONE = "Display reset.",

    -- Oracle
    ORACLE_CALCULATE      = "Analyse",
    ORACLE_RECALCULATE    = "Re-analyse",
    ORACLE_CHOOSE_OTHER   = "Other zone",
    ORACLE_NO_AUCTIONATOR = "Auctionator required",
    ORACLE_NOT_CALCULATED = "Not analysed yet",
    ORACLE_NO_PRICES      = "No prices available",
    ORACLE_PRICE_DATE     = "Prices from %s",
    ORACLE_NO_DATA        = "No data to calculate.",

    -- Session
    SESSION_STARTED       = "Tracking started: %s",
    SESSION_WAITING       = "Waiting for zone: %s",
    SESSION_WAITING_SHORT = "Waiting: %s",
    SESSION_NONE          = "No active zone",

    -- Totals
    LABEL_HERB  = "\230\152\191 Herbs",
    LABEL_ORE   = "\226\155\143 Ore",
    RESET_VISUAL = "Reset view",

    -- Minimap tooltip
    TOOLTIP_HINT    = "|cffFFFFFFLeft-click|r open  |cffFFFFFFRight-click|r stop",
    TOOLTIP_WAITING = "Waiting: %s",
}

ns.L = L
ns.defaultLocale = L
