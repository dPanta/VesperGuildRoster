local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Automation = VesperGuild:NewModule("Automation", "AceConsole-3.0", "AceEvent-3.0")

function Automation:OnInitialize()
    self:RegisterEvent("PLAYER_LOGIN")
end

function Automation:PLAYER_LOGIN()
end
