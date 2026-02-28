local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "zhCN")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild加载成功！"
L["SLASH_COMMAND_HELP"] = "打开VesperGuild窗口"
