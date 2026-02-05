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

-- Global table for Portals module
VesperPortalsUI = {}

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
            icon = {
                point = "CENTER",
                x = 0,
                y = 0,
            },
        },
        global = {
            keystones = {}, -- Persistent keystone storage
        },
    }, true)

    self:Print(L["ADDON_LOADED_MESSAGE"])
end

function VesperGuild:CreateFloatingIcon()
    local btn = CreateFrame("Button", "VesperGuildIcon", UIParent)
    btn:SetSize(40, 40)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    
    -- Load Saved Position
    local pos = self.db.profile.icon
    btn:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    
    -- Artwork
    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\Spell_Nature_Polymorph")
    btn.texture = tex

    -- Drag Script - only drag if Shift+LeftButton is held
    btn:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        VesperGuild.db.profile.icon.point = point
        VesperGuild.db.profile.icon.x = x
        VesperGuild.db.profile.icon.y = y
    end)
    
    -- Click Script - left click to toggle roster and portals (no shift required)
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and not IsShiftKeyDown() then
            local Roster = VesperGuild:GetModule("Roster", true)
            local Portals = VesperGuild:GetModule("Portals", true)
            if Roster then Roster:Toggle() end
            if Portals then Portals:Toggle() end
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("VesperGuild", 1, 1, 1)
        GameTooltip:AddLine("Left-Click: Toggle Roster", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift+Left-Click & Drag: Move Icon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function VesperGuild:OnEnable()
    -- Called when the addon is enabled
    self:RegisterChatCommand("vesper", "HandleChatCommand")
    self:RegisterChatCommand("vg", "HandleChatCommand")
    
    -- Debug: Check if modules are loaded
    local Roster = self:GetModule("Roster", true)
    local Portals = self:GetModule("Portals", true)
    if not Roster then
        self:Print("WARNING: Roster module not found!")
    end
    if not Portals then
        self:Print("WARNING: Portals module not found!")
    end
    
    self:CreateFloatingIcon()
end

function VesperGuild:OnDisable()
    -- Called when the addon is disabled
end

function VesperGuild:HandleChatCommand(input)
    if not input or input:trim() == "" then
        -- Open the roster window by default
        local Roster = self:GetModule("Roster", true)
        if Roster then
            Roster:ShowRoster()
        else
            self:Print("Roster module not found!")
        end
    elseif input == "debug" or input == "keys" then
        -- Debug: Dump keystone database
        local KeystoneSync = self:GetModule("KeystoneSync", true)
        if KeystoneSync then
            KeystoneSync:DebugDumpKeystones()
        else
            self:Print("KeystoneSync module not found!")
        end
    else
        self:Print("Unknown command: " .. input)
        self:Print("Usage: /vg [debug|keys]")
    end
end
