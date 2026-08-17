local _, addonTable = ...
local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local GroupActionButtons = vesperTools:NewModule("GroupActionButtons", "AceEvent-3.0")
local L = vesperTools.L
local CombatGate = addonTable.CombatGate

-- Base metrics at the default button height; configured sizes scale from these.
local READY_BUTTON_WIDTH = 54
local PULL_BUTTON_WIDTH = 46
local BUTTON_HEIGHT = 20
local BUTTON_GAP = 6
local BAR_OFFSET_Y = 5
local BASE_FONT_SIZE = 11
local MIN_BUTTON_HEIGHT = 14
local MAX_BUTTON_HEIGHT = 32
local PULL_COUNTDOWN_SECONDS = 9

-- First shown frame wins; addon group headers take priority over the Blizzard
-- frames they replace. EllesmereUI's named container is a 1x1 positioning
-- point, so its secure headers are the anchors instead.
local PARTY_PARENT_FRAME_NAMES = {
    "ERFPartyHeader", -- EllesmereUI
    "ElvUF_PartyGroup1", -- ElvUI
    "CompactPartyFrame",
}
local RAID_PARENT_FRAME_NAMES = {
    "ERFGroupHeader1", -- EllesmereUI
    "ERFPartyHeader", -- EllesmereUI running party-style frames in a raid
    "ElvUF_Raid1Group1", -- ElvUI
    "ElvUF_Raid2Group1",
    "ElvUF_Raid3Group1",
    "ElvUF_RaidGroup1",
    "ElvUF_Raid40Group1",
    "CompactRaidFrameContainer",
}

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

local function getConfiguredButtonMetrics()
    local profile = vesperTools.db and vesperTools.db.profile or nil
    local settings = profile and profile.groupActions or nil
    local enabled = not settings or settings.enabled ~= false

    local height = math.floor((tonumber(settings and settings.buttonHeight) or BUTTON_HEIGHT) + 0.5)
    height = math.min(MAX_BUTTON_HEIGHT, math.max(MIN_BUTTON_HEIGHT, height))

    local scale = height / BUTTON_HEIGHT
    local readyWidth = math.floor((READY_BUTTON_WIDTH * scale) + 0.5)
    local pullWidth = math.floor((PULL_BUTTON_WIDTH * scale) + 0.5)
    local fontSize = math.max(8, math.min(18, math.floor((BASE_FONT_SIZE * scale) + 0.5)))

    return enabled, height, readyWidth, pullWidth, fontSize
end

local function resolveParentFrame(candidateNames)
    local firstExisting = nil
    for index = 1, #candidateNames do
        local frame = _G[candidateNames[index]]
        if frame then
            firstExisting = firstExisting or frame
            if frame:IsShown() then
                return frame
            end
        end
    end

    return firstExisting
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
    button.vgLabelText = label

    return button
end

-- The configured font can fail to render at creation time (late-registered
-- shared media); re-assert text and font on every refresh so the label heals
-- without a reload.
local function refreshButtonLabel(button, fontSize)
    local fontString = button and button.vgModernTextLabel
    if not fontString then
        return
    end

    local currentText = fontString:GetText()
    if button.vgLabelText and (currentText == nil or currentText == "") then
        fontString:SetText(button.vgLabelText)
    end

    vesperTools:ApplyConfiguredFont(fontString, fontSize or BASE_FONT_SIZE, "")
    vesperTools:EnsureFontStringRenders(fontString)
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
        READY_CHECK or L["GROUP_ACTION_READY"],
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

function GroupActionButtons:LayoutActionBar(bar, buttonHeight, readyWidth, pullWidth)
    if not bar or not bar.parentFrame then
        return
    end

    local parent = bar.parentFrame
    bar:SetFrameStrata(parent:GetFrameStrata())
    bar:SetFrameLevel((parent:GetFrameLevel() or 0) + 60)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, BAR_OFFSET_Y)
    bar:SetSize(readyWidth + BUTTON_GAP + pullWidth, buttonHeight)
    if bar.ReadyButton then
        bar.ReadyButton:SetSize(readyWidth, buttonHeight)
    end
    if bar.PullButton then
        bar.PullButton:SetSize(pullWidth, buttonHeight)
    end
end

function GroupActionButtons:RefreshKindBar(kind, parent, shouldShow, buttonHeight, readyWidth, pullWidth, fontSize)
    self.activeBars = self.activeBars or {}

    -- The resolved parent can change (ElvUI headers appearing, layout swaps);
    -- hide the bar left behind on the previous parent.
    local previousBar = self.activeBars[kind]
    if previousBar and previousBar.parentFrame ~= parent then
        previousBar:Hide()
        self.activeBars[kind] = nil
    end

    if not parent then
        return
    end

    local bar = self:CreateActionBar(parent, kind)
    if not bar then
        return
    end
    self.activeBars[kind] = bar

    self:LayoutActionBar(bar, buttonHeight, readyWidth, pullWidth)
    refreshButtonLabel(bar.ReadyButton, fontSize)
    refreshButtonLabel(bar.PullButton, fontSize)
    bar:SetShown(shouldShow and parent:IsShown() and true or false)
end

function GroupActionButtons:RefreshBars()
    self.pendingRefresh = false

    local enabled, buttonHeight, readyWidth, pullWidth, fontSize = getConfiguredButtonMetrics()
    local canUseActions = canPlayerUseGroupActions()
    local inRaid = IsInRaid()
    local inParty = IsInGroup() and not inRaid

    self:RefreshKindBar(
        "party",
        resolveParentFrame(PARTY_PARENT_FRAME_NAMES),
        enabled and inParty and canUseActions,
        buttonHeight, readyWidth, pullWidth, fontSize
    )
    self:RefreshKindBar(
        "raid",
        resolveParentFrame(RAID_PARENT_FRAME_NAMES),
        enabled and inRaid and canUseActions,
        buttonHeight, readyWidth, pullWidth, fontSize
    )
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

function GroupActionButtons:OnInitialize()
    self.activeBars = {}
    self.pendingRefresh = false
end

function GroupActionButtons:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN", "RequestRefresh")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestRefresh")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RequestRefresh")
    self:RegisterEvent("PARTY_LEADER_CHANGED", "RequestRefresh")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "RequestRefresh")
    self:RequestRefresh()
end

function GroupActionButtons:ADDON_LOADED(_, addonName)
    if addonName ~= "Blizzard_CompactRaidFrames"
        and addonName ~= "ElvUI"
        and addonName ~= "EllesmereUIRaidFrames"
    then
        return
    end

    self:RequestRefresh()
end
