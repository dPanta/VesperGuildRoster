local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "frFR")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild charge avec succes !"
L["SLASH_COMMAND_HELP"] = "Ouvrir la fenetre VesperGuild"
