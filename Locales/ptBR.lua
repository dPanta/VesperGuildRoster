local addonName = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "ptBR")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "VesperGuild carregado com sucesso!"
L["SLASH_COMMAND_HELP"] = "Abrir janela do VesperGuild"
