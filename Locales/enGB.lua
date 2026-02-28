local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enGB")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild loaded successfully!"
L["SLASH_COMMAND_HELP"] = "Open VesperGuild window"
