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
    ORACLE_CHOOSE_OTHER   = "Choose other zone",
    ORACLE_NO_AUCTIONATOR = "Auctionator required",
    ORACLE_NOT_CALCULATED = "Not analysed yet",
    ORACLE_NO_PRICES      = "No price data",
    ORACLE_PRICE_DATE     = "Prices from %s",
    ORACLE_NO_DATA        = "No data to calculate.",

    -- Session
    SESSION_STARTED       = "Tracking: %s",
    SESSION_WAITING       = "Waiting for zone: %s",
    SESSION_WAITING_SHORT = "Waiting: %s",
    SESSION_NONE          = "No active zone",

    -- Farm totals
    LABEL_HERB  = "Herbs",
    LABEL_ORE   = "Ore",
    LABEL_TOTAL = "Total",
    RESET_VISUAL = "Reset",

    -- Zone choice screen
    CHOOSE_ZONE_TITLE = "Choose a zone",

    -- Farming screen buttons
    BTN_HISTORY    = "History",
    BTN_BACK       = "Back",
    BTN_BACK_ORACLE = "Oracle",

    -- History screen
    HISTORY_TITLE    = "Daily History",
    HISTORY_COL_DATE = "Date",

    -- Minimap tooltip
    TOOLTIP_HINT    = "|cffFFFFFFLeft-click|r open  |cffFFFFFFRight-click|r stop",
    TOOLTIP_WAITING = "Waiting: %s",
}

ns.L = L
ns.defaultLocale = L
