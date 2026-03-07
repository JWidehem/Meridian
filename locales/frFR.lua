local L = LibStub("AceLocale-3.0"):NewLocale("Meridian", "frFR")
if not L then return end

-- General
L["ADDON_LOADED"] = "Chargé — /mer pour ouvrir"
L["NEW_RESOURCE"] = "Nouvelle ressource : %s (id=%d)"
L["NODE_RECORDED"] = "%s (%.2f, %.2f) — %d total"
L["SPELL_LEARNED"] = "Nouveau sort de récolte appris : spellID %d"

-- UI
L["TITLE"] = "Meridian"
L["TAB_ORES"] = "Minerais"
L["TAB_HERBS"] = "Plantes"
L["NODES_COUNT"] = "%d nœuds"
L["EXPORT_CLAUDE"] = "Exporter pour Claude"
L["EXPORT_ZONE"] = "Exporter cette zone"
L["NO_DATA"] = "Aucune donnée enregistrée."
L["NO_DATA_TAB"] = "Aucun(e) %s enregistré(e)."
L["EXPORT_TITLE"] = "Meridian — Export"
L["EXPORT_INSTRUCTIONS"] = "Faites Ctrl+A puis Ctrl+C pour copier."

-- Commands
L["CMD_HELP"] = "Commandes : /mer — ouvrir | /mer export — exporter | /mer reset — réinitialiser"
L["CMD_RESET_CONFIRM"] = "Tapez /mer reset confirm pour effacer toutes les données."
L["CMD_RESET_DONE"] = "Toutes les données ont été effacées."

-- Minimap
L["MINIMAP_LEFT"] = "|cffFFFFFFClic gauche|r pour ouvrir Meridian"
L["MINIMAP_RIGHT"] = "|cffFFFFFFClic droit|r pour activer/désactiver le tracking"
L["TRACKING_ENABLED"] = "Tracking |cff00ff00activé|r"
L["TRACKING_DISABLED"] = "Tracking |cffff0000désactivé|r"
