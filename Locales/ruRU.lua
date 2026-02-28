local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "ruRU")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild успешно загружен!"
L["SLASH_COMMAND_HELP"] = "Открыть окно VesperGuild"
