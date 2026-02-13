local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Automation = VesperGuild:NewModule("Automation", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

local ILVL_PREFIX = "VGiLvl"
local SYNC_COOLDOWN = 30 -- seconds between broadcasts to avoid spam
local lastBroadcast = 0

function Automation:OnInitialize()
    self:RegisterEvent("PLAYER_LOGIN")
end

function Automation:OnEnable()
    -- Register comm prefix for ilvl sync
    self:RegisterComm(ILVL_PREFIX, "OnIlvlReceived")

    -- Listen for addon open to trigger sync
    self:RegisterMessage("VESPERGUILD_ADDON_OPENED", "BroadcastIlvl")

    -- Listen for M+ completion
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnMPlusCompleted")
end

function Automation:PLAYER_LOGIN()
    self:RegisterChatCommand("vespertest", "TestKeyReminder")

    -- Clean up stale ilvl entries on login
    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:CleanupStaleIlvl()
    end
end

function Automation:TestKeyReminder()
    self:ShowKeyReminder()
end

-- Broadcast player's ilvl to guild as addon message
function Automation:BroadcastIlvl()
    if not IsInGuild() then return end

    -- Cooldown check
    local now = GetTime()
    if (now - lastBroadcast) < SYNC_COOLDOWN then return end
    lastBroadcast = now

    local _, ilvl = GetAverageItemLevel()
    ilvl = math.floor(ilvl)

    local _, _, classID = UnitClass("player")

    local payload = string.format("%d:%d", ilvl, classID)
    self:SendCommMessage(ILVL_PREFIX, payload, "GUILD")
end

-- Handle incoming ilvl messages from guild members
function Automation:OnIlvlReceived(prefix, message, distribution, sender)
    if prefix ~= ILVL_PREFIX then return end
    if distribution ~= "GUILD" then return end

    -- Normalize sender (add realm if missing)
    if not string.find(sender, "-") then
        sender = sender .. "-" .. GetNormalizedRealmName()
    end

    local ilvlStr, classIDStr = strsplit(":", message)
    local ilvl = tonumber(ilvlStr)
    local classID = tonumber(classIDStr)

    if not ilvl then return end

    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreIlvl(sender, ilvl, classID)
        VesperGuild:SendMessage("VESPERGUILD_ILVL_UPDATE", sender)
    end
end

-- M+ end reminder (only if timed and current key level <= completed level)
function Automation:OnMPlusCompleted()
    local _, level, _, onTime = C_ChallengeMode.GetCompletionInfo()

    -- Only fire if the run was in time
    if not onTime then return end

    -- Only fire if current keystone level is lower or equal to the completed key
    local ownedLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if ownedLevel and ownedLevel > level then return end

    self:ShowKeyReminder()
end

function Automation:ShowKeyReminder()
    if not self.keyReminderFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints()
        f:SetFrameStrata("FULLSCREEN_DIALOG")

        local text = f:CreateFontString(nil, "OVERLAY")
        text:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 60, "OUTLINE")
        text:SetPoint("CENTER", 0, 200)
        text:SetText("|cffFFFF00DID YOU WANT TO CHANGE KEYS?|r")
        f.text = text

        f:Hide()
        self.keyReminderFrame = f
    end

    self.keyReminderFrame:Show()
    C_Timer.After(10, function()
        if self.keyReminderFrame then
            self.keyReminderFrame:Hide()
        end
    end)
end

-- Manual sync (call from a button or slash command)
function Automation:ManualSync()
    lastBroadcast = 0 -- reset cooldown so it fires immediately
    self:BroadcastIlvl()
    VesperGuild:Print("iLvl sync broadcasted to guild.")
end
