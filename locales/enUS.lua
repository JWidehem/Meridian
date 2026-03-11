local _, ns = ...

-- Default locale (enUS) — fallback for all languages
local L = {
    -- General
    ADDON_LOADED   = "Loaded \226\128\148 /mer to open",

    -- Commands
    CMD_HELP          = "Commands: /mer \226\128\148 toggle | /mer session \226\128\148 stop session | /mer reset \226\128\148 reset history",
    CMD_RESET_CONFIRM = "Type /mer reset confirm to erase session history.",
    CMD_RESET_DONE    = "Session history erased.",
    CMD_SESSION_HINT  = "Use the Oracle panel to start a session.",

    -- Oracle
    ORACLE_RECOMMENDATION = "Recommended zone:",
    ORACLE_CALCULATE      = "Calculate",
    ORACLE_RECALCULATE    = "Recalculate",
    ORACLE_CHOOSE_OTHER   = "Choose other zone",
    ORACLE_NO_AUCTIONATOR = "Auctionator required",
    ORACLE_NOT_CALCULATED = "Not calculated yet",
    ORACLE_NO_PRICES      = "No prices available",
    ORACLE_PRICE_DATE     = "Prices from %s",
    ORACLE_NO_DATA        = "No data to calculate.",

    -- Session
    SESSION_STARTED      = "Session started: %s",
    SESSION_STOPPED      = "Session ended: %s \226\128\148 %s (%s/h)",
    SESSION_PAUSED       = "Session paused.",
    SESSION_RESUMED      = "Session resumed.",
    SESSION_WAITING      = "Waiting for zone: %s \226\128\148 session will start automatically.",
    SESSION_WAITING_SHORT = "Waiting: %s",
    SESSION_IN_PROGRESS  = "Session in progress",
    SESSION_IN_ZONE      = "Farming: %s",
    SESSION_NONE         = "No active session",
    SESSION_PAUSE        = "Pause",
    SESSION_RESUME       = "Resume",
    SESSION_STOP         = "Stop",
    SESSION_PAUSED_SHORT = "paused",

    -- History
    HISTORY_TITLE = "Last sessions:",
    HISTORY_AVG   = "Avg: %s/h",

    -- Tabs
    TAB_ORACLE_SESSION = "Oracle \194\183 Session",
    TAB_HISTORY        = "History",

    -- Minimap
    TOOLTIP_HINT    = "|cffFFFFFFLeft-Click|r open | |cffFFFFFFRight-Click|r pause session",
    TOOLTIP_WAITING = "Waiting for: %s",
}

ns.L = L
ns.defaultLocale = L
