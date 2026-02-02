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
                     -- Using modern MenuUtil
                     if MenuUtil then
                        if not Roster.menuFrame then
                            Roster.menuFrame = CreateFrame("Frame", "VesperGuildMenuAnchor", UIParent)
                        end
                        MenuUtil.CreateContextMenu(Roster.menuFrame, function(owner, rootDescription)
                            rootDescription:CreateTitle(name)
                            
                            local whisperBtn = rootDescription:CreateButton("Whisper", function() 
                                print("VesperGuild: Whispering " .. name)
                                ChatFrame_OpenChat("/w " .. name) 
                            end)
                            whisperBtn:SetEnabled(true)

                            local inviteBtn = rootDescription:CreateButton("Invite", function() 
                                C_PartyInfo.InviteUnit(name) 
                            end)
                            inviteBtn:SetEnabled(true)

                            rootDescription:CreateButton("Cancel", function() end)
                        end)
                     else
                        -- Fallback for older clients (unlikely given 12.0)
                        print("MenuUtil not found cannot open menu.")
                     end
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
