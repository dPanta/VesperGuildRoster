local addonName, addonTable = ...
local VesperGuild = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Roster = VesperGuild:NewModule("Roster", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function Roster:OnInitialize()
    -- Called when the module is initialized
end

function Roster:OnEnable()
    -- Hook into the main slash command logic if needed,
    -- or just expose a function the Core can call.
end

function Roster:OnDisable()
    -- Called when the module is disabled
end

-- --- GUI Creation ---

local frame
local scroll

function Roster:ShowRoster()
    if frame then
        frame:Show()
        Roster:UpdateRosterList()
        return
    end

    -- Create Main Frame
    frame = AceGUI:Create("Window")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) frame = nil end)
    frame:SetTitle("VesperGuild Roster")
    frame:SetLayout("Fill")
    frame:SetWidth(600)
    frame:SetHeight(500)
    frame:EnableResize(true)

    -- Create Scroll Container
    scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow") -- List items vertically
    frame:AddChild(scroll)

    Roster:UpdateRosterList()
end

function Roster:UpdateRosterList()
    if not frame then return end
    scroll:ReleaseChildren() -- Clear existing list

    -- Header Row (Fake it for now with labels, or use a better widget later)
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetLayout("Flow")
    headerGroup:SetFullWidth(true)
    
    local nameHeader = AceGUI:Create("Label")
    nameHeader:SetText("Name")
    nameHeader:SetRelativeWidth(0.3)
    headerGroup:AddChild(nameHeader)

    local zoneHeader = AceGUI:Create("Label")
    zoneHeader:SetText("Zone")
    zoneHeader:SetRelativeWidth(0.3)
    headerGroup:AddChild(zoneHeader)

    local statusHeader = AceGUI:Create("Label")
    statusHeader:SetText("Status")
    statusHeader:SetRelativeWidth(0.2)
    headerGroup:AddChild(statusHeader)
    
    local keyHeader = AceGUI:Create("Label")
    keyHeader:SetText("C. Key")
    keyHeader:SetRelativeWidth(0.2)
    headerGroup:AddChild(keyHeader)

    scroll:AddChild(headerGroup)
    -- Horizontal separator
    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    scroll:AddChild(line)


    -- Iterate Guild Members
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        -- name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(index)
        local name, _, _, level, _, zone, _, _, isOnline, status, classFileName = GetGuildRosterInfo(i)
        
        if isOnline then
            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetFullWidth(true)

            -- Color name by class
            local classColor = C_ClassColor.GetClassColor(classFileName)
            local nameText = name
            if classColor then
                 nameText = string.format("|c%s%s|r", classColor:GenerateHexColor(), name)
            end

            local nameLabel = AceGUI:Create("InteractiveLabel")
            nameLabel:SetText(nameText)
            nameLabel:SetRelativeWidth(0.3)
            -- Highlight on hover to show interactivity
            nameLabel:SetCallback("OnEnter", function(widget) 
                 GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPLEFT")
                 GameTooltip:SetText("Right-click for menu")
                 GameTooltip:Show()
            end)
            nameLabel:SetCallback("OnLeave", function(widget) GameTooltip:Hide() end)
            
            nameLabel:SetCallback("OnClick", function(widget, event, button) 
                if button == "RightButton" then
                    -- Custom Mini-Menu to bypass API issues
                    if Roster.popup then Roster.popup:Hide() end
                    
                    local f = CreateFrame("Frame", "VesperGuildPopup", UIParent, "BackdropTemplate")
                    Roster.popup = f
                    f:SetSize(120, 80)
                    f:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT", 0, 10) -- Position near click
                    f:SetFrameStrata("DIALOG")
                    
                    f:SetBackdrop({
                        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        tile = true, tileSize = 32, edgeSize = 16,
                        insets = { left = 4, right = 4, top = 4, bottom = 4 }
                    })
                    
                    -- Title
                    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    f.title:SetPoint("TOP", 0, -10)
                    f.title:SetText(name)
                    
                    -- Whisper Button
                    local btn1 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                    btn1:SetPoint("TOP", f.title, "BOTTOM", 0, -5)
                    btn1:SetSize(100, 20)
                    btn1:SetText("Whisper")
                    btn1:SetScript("OnClick", function() 
                        ChatFrame_OpenChat("/w " .. name) 
                        f:Hide()
                    end)
                    
                    -- Invite Button
                    local btn2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                    btn2:SetPoint("TOP", btn1, "BOTTOM", 0, -5)
                    btn2:SetSize(100, 20)
                    btn2:SetText("Invite")
                    btn2:SetScript("OnClick", function() 
                        C_PartyInfo.InviteUnit(name) 
                        f:Hide()
                    end)

                    -- Close on global click (roughly)
                    f:SetScript("OnLeave", function() 
                        -- Auto-hide logic could go here, or just a close button
                    end)
                    
                    -- Simple Close Button
                    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
                    close:SetPoint("TOPRIGHT", 0, 0)
                    
                    f:Show()
                end
            end)
            row:AddChild(nameLabel)

            local zoneLabel = AceGUI:Create("Label")
            zoneLabel:SetText(zone or "Unknown")
            zoneLabel:SetRelativeWidth(0.3)
            row:AddChild(zoneLabel)

            -- Format Status
            local statusText = "Online"
            if status == 1 then statusText = "|cffFFFF00AFK|r" end
            if status == 2 then statusText = "|cffFF0000DND|r" end
            
            local statusLabel = AceGUI:Create("Label")
            statusLabel:SetText(statusText)
            statusLabel:SetRelativeWidth(0.2)
            row:AddChild(statusLabel)
            
            -- Placeholder Key Data
            local keyLabel = AceGUI:Create("Label")
            -- We don't have data yet
            keyLabel:SetText("-") 
            keyLabel:SetRelativeWidth(0.2)
            row:AddChild(keyLabel)

            scroll:AddChild(row)
        end
    end
end
