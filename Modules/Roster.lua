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

    -- Create Custom Frame (MATERIAL DESIGN)
    frame = CreateFrame("Frame", "VesperGuildRosterFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(400, 300)
    
    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.07, 0.07, 0.07, 0.95) -- #121212
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    -- Titlebar
    local titlebar = CreateFrame("Frame", nil, frame)
    titlebar:SetHeight(32)
    titlebar:SetPoint("TOPLEFT")
    titlebar:SetPoint("TOPRIGHT")
    
    local titlebg = titlebar:CreateTexture(nil, "BACKGROUND")
    titlebg:SetAllPoints()
    titlebg:SetColorTexture(0.1, 0.1, 0.1, 1) -- #1A1A1A
    
    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("VesperGuild Roster")
    
    -- Make draggable via titlebar
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")
    titlebar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titlebar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -5, 0)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function() 
        frame:Hide()
        frame = nil
        scroll = nil
    end)
    
    -- Resize Grip
    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT")
    resizeBtn:EnableMouse(true)
    resizeBtn:RegisterForDrag("LeftButton")
    
    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    
    resizeBtn:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    -- Sync Button
    local syncBtn = CreateFrame("Button", nil, titlebar, "UIPanelButtonTemplate")
    syncBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    syncBtn:SetSize(80, 22)
    syncBtn:SetText("Sync")
    syncBtn:SetScript("OnClick", function()
        local KeystoneSync = VesperGuild:GetModule("KeystoneSync", true)
        if KeystoneSync then
            KeystoneSync:BroadcastKeystone()
            Roster:UpdateRosterList()
            VesperGuild:Print("Keystone sync requested")
        end
    end)
    
    -- Content Container (using AceGUI ScrollFrame inside our custom frame)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("BOTTOMRIGHT", -5, 20)
    
    scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll.frame:SetParent(contentFrame)
    scroll.frame:SetAllPoints()
    scroll.frame:Show()

    Roster:UpdateRosterList()
end

function Roster:Toggle()
    if frame and frame:IsShown() then
        AceGUI:Release(frame)
        frame = nil
    else
        Roster:ShowRoster()
    end
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
                     -- Using modern MenuUtil
                     if MenuUtil then
                         MenuUtil.CreateContextMenu(widget.frame, function(owner, rootDescription)
                            rootDescription:CreateTitle(name)
                            
                            rootDescription:CreateButton("Whisper", function() 
                                ChatFrame_OpenChat("/w " .. name .. " ") 
                            end)
                            
                            rootDescription:CreateButton("Invite", function() 
                                C_PartyInfo.InviteUnit(name) 
                            end)

                            rootDescription:CreateButton("Cancel", function() end)
                        end)
                     else
                        print("MenuUtil not found.")
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
            
            -- Keystone Data from KeystoneSync
            local keyLabel = AceGUI:Create("Label")
            local KeystoneSync = VesperGuild:GetModule("KeystoneSync", true)
            if KeystoneSync then
                -- Normalize player name: remove realm if it's the same realm
                local playerRealm = GetRealmName()
                local fullName = name
                -- If name doesn't have realm, add it
                if not string.find(name, "-") then
                    fullName = name .. "-" .. playerRealm
                end
                -- DEBUG: Show what we're searching for (only for our own character)
                if name == UnitName("player") then
                    VesperGuild:Print("Roster lookup for: [" .. fullName .. "]")
                end
                local keystoneText = KeystoneSync:GetKeystoneForPlayer(fullName) or "-"
                keyLabel:SetText(keystoneText)
            else
                keyLabel:SetText("-")
            end
            keyLabel:SetRelativeWidth(0.2)
            row:AddChild(keyLabel)

            -- MATERIAL SKINNING: Row Background
            local rowFrame = row.frame
            local bg = rowFrame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            -- Zebra Striping
            if (i % 2 == 0) then
                bg:SetColorTexture(0.17, 0.17, 0.17, 1) -- #2C2C2C
            else
                bg:SetColorTexture(0.12, 0.12, 0.12, 1) -- #1E1E1E
            end
            
            -- Hover Effect
            rowFrame:SetScript("OnEnter", function() 
                bg:SetColorTexture(0.24, 0.24, 0.24, 1) -- #3D3D3D (Highlight)
            end)
            rowFrame:SetScript("OnLeave", function() 
                -- Restore original color
                if (i % 2 == 0) then
                    bg:SetColorTexture(0.17, 0.17, 0.17, 1)
                else
                    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
                end
            end)
            
            scroll:AddChild(row)
        end
    end
end
