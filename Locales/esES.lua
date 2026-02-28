local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "esES")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild se ha cargado correctamente."
L["SLASH_COMMAND_HELP"] = "Abrir la ventana de VesperGuild"
