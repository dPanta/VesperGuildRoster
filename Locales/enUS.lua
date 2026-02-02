local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)
end

if not L then
    -- Fallback if AceLocale is not present, simple table
    L = {}
    addonTable.L = L
    -- Mocking __index to return key if not found
    setmetatable(L, {
        __index = function(t, k) return k end
    })
    -- If we returned here, we wouldn't be able to add keys below easily without checking again
    -- so we just continue using 'L' which is now a table.
end

-- Translations go here
L["ADDON_LOADED_MESSAGE"] = "VesperGuild loaded successfully!"
L["SLASH_COMMAND_HELP"] = "Open VesperGuild window"
