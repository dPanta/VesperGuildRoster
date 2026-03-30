local _, addonTable = ...
local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local GroupActionButtons = vesperTools:NewModule("GroupActionButtons", "AceEvent-3.0")
local L = vesperTools.L
local CombatGate = addonTable.CombatGate

local READY_BUTTON_WIDTH = 54
local PULL_BUTTON_WIDTH = 46
local BUTTON_HEIGHT = 20
local BUTTON_GAP = 6
local BAR_OFFSET_Y = 5
local PULL_COUNTDOWN_SECONDS = 9

local READY_BACKGROUND_COLOR = { 0.06, 0.13, 0.08 }
local READY_BORDER_COLOR = { 0.38, 0.88, 0.54 }
local PULL_BACKGROUND_COLOR = { 0.14, 0.09, 0.05 }
local PULL_BORDER_COLOR = { 0.96, 0.70, 0.28 }

local function isPlayerGroupLeader()
    return UnitIsGroupLeader and UnitIsGroupLeader("player") or false
end

local function isPlayerRaidAssistant()
    return UnitIsGroupAssistant and UnitIsGroupAssistant("player") or false
end

local function canPlayerUseGroupActions()
    if IsInRaid() then
        return isPlayerGroupLeader() or isPlayerRaidAssistant()
    end

    if IsInGroup() then
        return isPlayerGroupLeader()
    end

    return false
end

local function startReadyCheck()
    if type(DoReadyCheck) ~= "function" then
        return
    end

    pcall(DoReadyCheck)
end

local function startPullCountdown()
    if C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function" then
        local ok = pcall(C_PartyInfo.DoCountdown, PULL_COUNTDOWN_SECONDS)
        if ok then
            return true
        end
    end

    return false
end

local function createActionButton(parent, label, backgroundColor, borderColor, onClick, onEnter)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:RegisterForClicks("LeftButtonUp")
    button:SetSize(READY_BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetScript("OnClick", onClick)
    if type(onEnter) == "function" then
        button:SetScript("OnEnter", onEnter)
    end
    button:SetScript("OnLeave", GameTooltip_Hide)

    vesperTools:ApplyModernTextButtonStyle(button, {
        text = label,
        fontSize = 11,
        backgroundColor = backgroundColor,
        backgroundAlpha = 0.94,
        borderColor = borderColor,
        borderAlpha = 0.26,
        hoverAlpha = 0.06,
        pressedAlpha = 0.10,
    })

    return button
end

function GroupActionButtons:CreateActionBar(parent, kind)
    if not parent then
        return nil
    end

    local existingBar = parent.vgGroupActionBar
    if existingBar then
        return existingBar
    end

    local bar = CreateFrame("Frame", nil, parent)
    bar.kind = kind
    bar.parentFrame = parent
    bar:SetSize(READY_BUTTON_WIDTH + BUTTON_GAP + PULL_BUTTON_WIDTH, BUTTON_HEIGHT)
    bar:SetFrameStrata(parent:GetFrameStrata())
    bar:SetFrameLevel((parent:GetFrameLevel() or 0) + 60)

    local readyButton = createActionButton(
        bar,
        READY_CHECK or "Ready",
        READY_BACKGROUND_COLOR,
        READY_BORDER_COLOR,
        function()
            startReadyCheck()
        end,
        function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
            GameTooltip:SetText(L["GROUP_ACTION_READY_TOOLTIP"])
            GameTooltip:Show()
        end
    )
    readyButton:SetPoint("LEFT", bar, "LEFT", 0, 0)
    readyButton:SetSize(READY_BUTTON_WIDTH, BUTTON_HEIGHT)

    local pullButton = createActionButton(
        bar,
        L["GROUP_ACTION_PULL"],
        PULL_BACKGROUND_COLOR,
        PULL_BORDER_COLOR,
        function()
            if not startPullCountdown() then
                vesperTools:Print(L["GROUP_ACTION_PULL_FAILED"])
            end
        end,
        function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
            GameTooltip:SetText(string.format(L["GROUP_ACTION_PULL_TOOLTIP_FMT"], PULL_COUNTDOWN_SECONDS))
            GameTooltip:Show()
        end
    )
    pullButton:SetPoint("LEFT", readyButton, "RIGHT", BUTTON_GAP, 0)
    pullButton:SetSize(PULL_BUTTON_WIDTH, BUTTON_HEIGHT)

    bar.ReadyButton = readyButton
    bar.PullButton = pullButton
    parent.vgGroupActionBar = bar

    parent:HookScript("OnShow", function()
        self:RequestRefresh()
    end)

    return bar
end

function GroupActionButtons:LayoutActionBar(bar)
    if not bar or not bar.parentFrame then
        return
    end

    local parent = bar.parentFrame
    bar:SetFrameStrata(parent:GetFrameStrata())
    bar:SetFrameLevel((parent:GetFrameLevel() or 0) + 60)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, BAR_OFFSET_Y)
    bar:SetSize(READY_BUTTON_WIDTH + BUTTON_GAP + PULL_BUTTON_WIDTH, BUTTON_HEIGHT)
end

function GroupActionButtons:RefreshActionBar(bar, shouldShow)
    if not bar then
        return
    end

    self:LayoutActionBar(bar)
    bar:SetShown(shouldShow and true or false)
end

function GroupActionButtons:RefreshBars()
    self.pendingRefresh = false

    local canUseActions = canPlayerUseGroupActions()
    local inRaid = IsInRaid()
    local inParty = IsInGroup() and not inRaid

    if self.partyParent then
        local partyBar = self:CreateActionBar(self.partyParent, "party")
        self:RefreshActionBar(partyBar, inParty and canUseActions and self.partyParent:IsShown())
    end

    if self.raidParent then
        local raidBar = self:CreateActionBar(self.raidParent, "raid")
        self:RefreshActionBar(raidBar, inRaid and canUseActions and self.raidParent:IsShown())
    end
end

function GroupActionButtons:RequestRefresh()
    if CombatGate then
        local executedNow = CombatGate:RunNamed(self, "group-action-buttons-refresh", function()
            self:RefreshBars()
        end)
        self.pendingRefresh = not executedNow
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingRefresh = true
        return
    end

    self:RefreshBars()
end

function GroupActionButtons:TryAttachToGroupFrames()
    self.partyParent = self.partyParent or _G.CompactPartyFrame
    self.raidParent = self.raidParent or _G.CompactRaidFrameContainer

    if self.partyParent then
        self:CreateActionBar(self.partyParent, "party")
    end

    if self.raidParent then
        self:CreateActionBar(self.raidParent, "raid")
    end

    self:RequestRefresh()
end

function GroupActionButtons:OnInitialize()
    self.partyParent = nil
    self.raidParent = nil
    self.pendingRefresh = false
end

function GroupActionButtons:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestRefresh")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RequestRefresh")
    self:RegisterEvent("PARTY_LEADER_CHANGED", "RequestRefresh")

    if _G.CompactPartyFrame or _G.CompactRaidFrameContainer then
        self:TryAttachToGroupFrames()
    end
end

function GroupActionButtons:PLAYER_LOGIN()
    self:TryAttachToGroupFrames()
end

function GroupActionButtons:ADDON_LOADED(_, addonName)
    if addonName ~= "Blizzard_CompactRaidFrames" then
        return
    end

    self:TryAttachToGroupFrames()
end
