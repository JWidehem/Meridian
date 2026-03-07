-- ============================================================
-- Meridian — MinimapIcon Module
-- Icône minimap via LibDataBroker + LibDBIcon
-- ============================================================
local addonName, ns = ...
local Meridian = LibStub("AceAddon-3.0"):GetAddon(addonName)
local MinimapButton = Meridian:NewModule("MinimapButton")
local L = ns.L

function MinimapButton:OnEnable()
    local ldb = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")

    local dataObj = ldb:NewDataObject("Meridian", {
        type = "data source",
        text = "Meridian",
        icon = "Interface\\Icons\\INV_Misc_Map_01",

        OnClick = function(_, button)
            if button == "LeftButton" then
                local StatsPanel = Meridian:GetModule("StatsPanel", true)
                if StatsPanel then StatsPanel:Toggle() end
            elseif button == "RightButton" then
                local enabled = Meridian.db.profile.enabled
                Meridian.db.profile.enabled = not enabled
                if Meridian.db.profile.enabled then
                    Meridian:Msg(L["TRACKING_ENABLED"])
                else
                    Meridian:Msg(L["TRACKING_DISABLED"])
                end
            end
        end,

        OnTooltipShow = function(tooltip)
            local Database = Meridian:GetModule("Database", true)
            local total = Database and Database:GetTotalNodeCount() or 0

            tooltip:AddLine("Meridian", 0.20, 0.60, 0.86)
            tooltip:AddLine(format(L["NODES_COUNT"], total), 1, 1, 1)
            tooltip:AddLine(" ")
            tooltip:AddLine(L["MINIMAP_LEFT"], 0.8, 0.8, 0.8)
            tooltip:AddLine(L["MINIMAP_RIGHT"], 0.8, 0.8, 0.8)
        end,
    })

    icon:Register("Meridian", dataObj, Meridian.db.profile.minimap)
end
