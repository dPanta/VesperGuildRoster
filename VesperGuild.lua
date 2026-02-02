local addonName, addonTable = ...

-- Helper to safely get locale
local L = addonTable.L or {}
setmetatable(L, { __index = function(t, k) return k end })

-- Check dependencies
if not LibStub or not LibStub("AceAddon-3.0", true) then
    print("|cffFF0000" .. addonName .. ":|r Ace3 libraries not found. Please install Ace3 in the Libs/ folder.")
    
    -- Fallback simple slash command to prove the addon is actually loaded
    SLASH_VESPERGUILD1 = "/vg"
    SLASH_VESPERGUILD2 = "/vesper"
    SlashCmdList["VESPERGUILD"] = function(msg)
        print("|cffFF0000" .. addonName .. ":|r Running in No-Lib mode. Please install Ace3.")
    end
    return
end

-- Global Addon Object
VesperGuild = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
-- Re-fetch locale via Ace if available, though our fallback L above is fine too
local AceLocale = LibStub("AceLocale-3.0", true)
if AceLocale then
    L = AceLocale:GetLocale(addonName)
end


function VesperGuild:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("VesperGuildDB", {
        profile = {
            minimap = {
                hide = false,
            },
        },
    }, true)

    self:Print(L["ADDON_LOADED_MESSAGE"])
end

function VesperGuild:OnEnable()
    -- Called when the addon is enabled
    self:RegisterChatCommand("vesper", "HandleChatCommand")
    self:RegisterChatCommand("vg", "HandleChatCommand")
end

function VesperGuild:OnDisable()
    -- Called when the addon is disabled
end

function VesperGuild:HandleChatCommand(input)
    if not input or input:trim() == "" then
        -- Open the roster window by default
        local Roster = self:GetModule("Roster")
        if Roster then
            Roster:ShowRoster()
        else
            self:Print("Roster module not found!")
        end
    else
        self:Print("Unknown command: " .. input)
    end
end
