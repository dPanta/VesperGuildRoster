local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "zhTW")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild 載入成功！"
L["SLASH_COMMAND_HELP"] = "開啟 VesperGuild 視窗"
