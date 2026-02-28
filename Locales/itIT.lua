local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "itIT")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild caricato con successo!"
L["SLASH_COMMAND_HELP"] = "Apri la finestra di VesperGuild"
