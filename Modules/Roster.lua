local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
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

function Roster:ShowRoster()
    if self.frame then
        self.frame:Show()
        self.dungeonPanel:Show()
        self:UpdateRosterList()
        return
    end

    -- Create Custom Frame (MATERIAL DESIGN)
    self.frame = CreateFrame("Frame", "VesperGuildRosterFrame", UIParent, "BackdropTemplate" )
    self.frame:SetSize(600, 250)

    -- Restore saved position or use default
    if VesperGuild.db.profile.rosterPosition then
        local pos = VesperGuild.db.profile.rosterPosition
        self.frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        self.frame:SetPoint("RIGHT", UIParent, "CENTER", -250, 0)
    end

    self.frame:SetFrameStrata("MEDIUM")
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetResizable(true)
    self.frame:SetResizeBounds(600, 250)
    
--   Background
     self.frame:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8x8",
         edgeFile = "Interface\\Buttons\\WHITE8x8",
         edgeSize = 1,
     })
     self.frame:SetBackdropColor(0.07, 0.07, 0.07, 0.95) -- #121212
     self.frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
--   Titlebar
    local titlebar = CreateFrame("Frame", nil, self.frame)
    titlebar:SetHeight(32)
    titlebar:SetPoint("TOPLEFT")
    titlebar:SetPoint("TOPRIGHT")
    
    local titlebg = titlebar:CreateTexture(nil, "BACKGROUND")
    titlebg:SetAllPoints()
    titlebg:SetColorTexture(0.1, 0.1, 0.1, 1) -- #1A1A1A
    
    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("VesperGuild Roster")
    
    -- Make draggable via titlebar
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")
    titlebar:SetScript("OnDragStart", function() self.frame:StartMoving() end)
    titlebar:SetScript("OnDragStop", function()
        self.frame:StopMovingOrSizing()
        -- Save position to database
        local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
        VesperGuild.db.profile.rosterPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)
    
    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -5, 0)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function()
        -- Clean up portal buttons before closing
        if self.portalButtons then
            for _, btn in ipairs(self.portalButtons) do
                btn:Hide()
                btn:SetParent(nil)
            end
            self.portalButtons = nil
        end

        self.frame:Hide()
        self.frame = nil
        self.scroll = nil
        if self.dungeonPanel then
            self.dungeonPanel:Hide()
            self.dungeonPanel = nil
        end
        -- Also hide the Portals frame
        local Portals = VesperGuild:GetModule("Portals", true)
        if Portals and Portals.VesperPortalsUI then
            Portals.VesperPortalsUI:Hide()
        end
    end)
    
    -- Resize Grip
    local resizeBtn = CreateFrame("Button", nil, self.frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT")
    resizeBtn:EnableMouse(true)
    resizeBtn:RegisterForDrag("LeftButton")
    
    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    
    resizeBtn:SetScript("OnDragStart", function() self.frame:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnDragStop", function() self.frame:StopMovingOrSizing() end)
    
    -- Sync Button
    local syncBtn = CreateFrame("Button", nil, titlebar, "UIPanelButtonTemplate")
    syncBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    syncBtn:SetSize(80, 22)
    syncBtn:SetText("Sync")
    syncBtn:SetScript("OnClick", function()
        local KeystoneSync = VesperGuild:GetModule("KeystoneSync", true)
        if KeystoneSync then
            KeystoneSync:RequestGuildKeystones()
            self:UpdateRosterList()
        end

    end)
    
    -- Content Container
    local contentFrame = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("BOTTOMRIGHT", -5, 20)
    
    self.scroll = AceGUI:Create("ScrollFrame")
    self.scroll:SetLayout("Flow")
    self.scroll.frame:SetParent(contentFrame)
    self.scroll.frame:SetAllPoints()
    self.scroll.frame:Show()



    self:UpdateRosterList()
end

function Roster:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        self.frame = nil
        self.scroll = nil
    else
        self:ShowRoster()
    end
end

-- M+ rating coloring
local function GetRatingColor(rating)
    if rating >= 3000 then
        return "|cffe268a8" -- Pink (Thunderpaw)
    elseif rating >= 2500 then
        return "|cffff8000" -- Orange (Legendary)
    elseif rating >= 2000 then
        return "|cffa335ee" -- Purple (Epic)
    elseif rating >= 1500 then
        return "|cff0070dd" -- Blue (Rare)
    elseif rating >= 100 then
        return "|cff1eff00" -- Green (Uncommon)
    else
        return "|cff9d9d9d" -- Gray (Poor)
    end
end

function Roster:UpdateRosterList()
    if not self.frame then return end

    -- Clean up any existing portal buttons
    if self.portalButtons then
        for _, btn in ipairs(self.portalButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
    end
    self.portalButtons = {}

    self.scroll:ReleaseChildren() -- Clear existing list

    -- Header only
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetLayout("Flow")
    headerGroup:SetFullWidth(true)

    -- Name
    local nameHeader = AceGUI:Create("Label")
    nameHeader:SetText("Name")
    nameHeader:SetRelativeWidth(0.15)
    headerGroup:AddChild(nameHeader)

    -- Faction
    local factionHeader = AceGUI:Create("Label")
    factionHeader:SetText("F")
    factionHeader:SetRelativeWidth(0.05)
    headerGroup:AddChild(factionHeader)

    -- Current Zone
    local zoneHeader = AceGUI:Create("Label")
    zoneHeader:SetText("Zone")
    zoneHeader:SetRelativeWidth(0.25)
    headerGroup:AddChild(zoneHeader)

    -- Status
    local statusHeader = AceGUI:Create("Label")
    statusHeader:SetText("Status")
    statusHeader:SetRelativeWidth(0.15)
    headerGroup:AddChild(statusHeader)

    -- M+ Rating
    local ratingHeader = AceGUI:Create("Label")
    ratingHeader:SetText("R")
    ratingHeader:SetRelativeWidth(0.1)
    headerGroup:AddChild(ratingHeader)

    -- Keystone
    local keyHeader = AceGUI:Create("Label")
    keyHeader:SetText("KEY")
    keyHeader:SetRelativeWidth(0.2)
    headerGroup:AddChild(keyHeader)

    -- Set header background to prevent it from being colored
    local headerFrame = headerGroup.frame
    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.1, 0.1, 0.1, 1) -- Dark gray, matches titlebar

    self.scroll:AddChild(headerGroup)
    -- Horizontal separator
    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    self.scroll:AddChild(line)


    -- Iterate Guild Members
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        -- name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(index)
        local name, _, _, level, _, zone, _, _, isOnline, status, classFileName = GetGuildRosterInfo(i)
        
        if isOnline then
            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetFullWidth(true)

            -- Extract short name (without realm) for display
            local displayName = name:match("([^-]+)") or name

            -- Color name by class
            local classColor = C_ClassColor.GetClassColor(classFileName)
            local nameText = displayName
            if classColor then
                 nameText = string.format("|c%s%s|r", classColor:GenerateHexColor(), displayName)
            end

            -- Make name clickable with many, many options...maybe
            local nameLabel = AceGUI:Create("InteractiveLabel")
            nameLabel:SetText(nameText)
            nameLabel:SetRelativeWidth(0.15)
            nameLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
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
                     -- Add more in future TBD
                     if MenuUtil then
                         MenuUtil.CreateContextMenu(widget.frame, function(owner, rootDescription)
                            rootDescription:CreateTitle(displayName)
                            
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

            -- Faction
            local factionText = "Unknown"
            local factionColor = "|cffFFFFFF"
            if UnitFactionGroup("player") == "Alliance" then
                factionText = "A"
                factionColor = "|cff0070DD"
            elseif UnitFactionGroup("player") == "Horde" then
                factionText = "H"
                factionColor = "|cffA335EE"
            end
            
            local factionLabel = AceGUI:Create("Label")
            factionLabel:SetText(factionColor .. factionText .. "|r")
            factionLabel:SetRelativeWidth(0.05)
            factionLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
            row:AddChild(factionLabel)

            -- Where are you?
            local zoneLabel = AceGUI:Create("Label")
            zoneLabel:SetText(zone or "Unknown")
            zoneLabel:SetRelativeWidth(0.25)
            zoneLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
            row:AddChild(zoneLabel)

            -- Format Status
            local statusText = "Online"
            if status == 1 then statusText = "|cffFFFF00AFK|r" end
            if status == 2 then statusText = "|cffFF0000DND|r" end
            
            local statusLabel = AceGUI:Create("Label")
            statusLabel:SetText(statusText)
            statusLabel:SetRelativeWidth(0.15)
            statusLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
            row:AddChild(statusLabel)

            -- Rating with Raider.IO-style coloring
            local ratingText = "-"
            if VesperGuild.db.global.keystones and VesperGuild.db.global.keystones[name] and VesperGuild.db.global.keystones[name].rating then
                local rating = VesperGuild.db.global.keystones[name].rating
                if rating > 0 then
                    local colorCode = GetRatingColor(rating)
                    ratingText = string.format("%s%d|r", colorCode, rating)
                end
            end
            local ratingLabel = AceGUI:Create("Label")
            ratingLabel:SetText(ratingText)
            ratingLabel:SetRelativeWidth(0.1)
            ratingLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
            row:AddChild(ratingLabel)
            
            -- Keystone Data from KeystoneSync
            local KeystoneSync = VesperGuild:GetModule("KeystoneSync", true)
            local keystoneMapID = nil
            local keystoneText = "-"

            if KeystoneSync then
                -- Normalize player name: remove realm if it's the same realm
                local playerRealm = GetRealmName()
                local fullName = name
                -- If name doesn't have realm, add it
                if not string.find(name, "-") then
                    fullName = name .. "-" .. playerRealm
                end

                keystoneText = KeystoneSync:GetKeystoneForPlayer(fullName) or "-"

                -- Get the actual mapID from the database for portal casting
                if VesperGuild.db.global.keystones and VesperGuild.db.global.keystones[fullName] then
                    keystoneMapID = VesperGuild.db.global.keystones[fullName].mapID
                end
            end

            -- Create AceGUI Label...to not have 200px wide rows :)
            local keyLabel = AceGUI:Create("Label")
            keyLabel:SetText(keystoneText)
            keyLabel:SetRelativeWidth(0.2)
            keyLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
            row:AddChild(keyLabel)

            -- Create secure button overlay for portal casting (only if player has a keystone)
            if keystoneMapID then
                local DataHandle = VesperGuild:GetModule("DataHandle", true)
                if DataHandle then
                    local dungInfo = DataHandle:GetDungeonByMapID(keystoneMapID)
                    if dungInfo then
                        local spellInfo = C_Spell.GetSpellInfo(dungInfo.spellID)
                        local spellName = spellInfo and spellInfo.name
                        local hasPortal = C_SpellBook.IsSpellInSpellBook(dungInfo.spellID)

                        if spellName and hasPortal then
                            -- Parent outside ACE! Breaks secure functions if I parent it to ACE container...my god.
                            local keyBtn = CreateFrame("Button", nil, contentFrame, "InsecureActionButtonTemplate")

                            -- Position it to match by SetPoint
                            keyBtn:SetPoint("TOPLEFT", keyLabel.frame, "TOPLEFT")
                            keyBtn:SetPoint("BOTTOMRIGHT", keyLabel.frame, "BOTTOMRIGHT")
                            keyBtn:SetFrameLevel(row.frame:GetFrameLevel() + 20)

                            keyBtn:SetAttribute("type1", "spell")
                            keyBtn:SetAttribute("spell1", spellName)
                            keyBtn:RegisterForClicks("AnyUp", "AnyDown")

                            -- Add tooltip
                            keyBtn:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                                GameTooltip:SetText("Click to cast portal: " .. spellName)
                                GameTooltip:Show()
                            end)
                            keyBtn:SetScript("OnLeave", function(self)
                                GameTooltip:Hide()
                            end)

                            -- Track button for cleanup
                            table.insert(self.portalButtons, keyBtn)
                        end
                    end
                end
            end

            -- MATERIAL SKINNING: Row Background
            local rowFrame = row.frame
            local bg = rowFrame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            
            -- Check if player is in group
            local isInGroup = false
            for j = 1, (IsInRaid() and GetNumGroupMembers() or 5) do
                local groupUnit = IsInRaid() and ("raid" .. j) or (j == 1 and "player" or ("party" .. (j - 1)))
                local groupName = UnitName(groupUnit)
                -- Compare using displayName (without realm) since UnitName returns short names
                if groupName == displayName then
                    isInGroup = true
                    break
                end
            end
            
            -- Determine base color: teal tint if in group, zebra stripes otherwise
            local baseColorR, baseColorG, baseColorB
            if isInGroup then
                baseColorR, baseColorG, baseColorB = 0.12, 0.24, 0.24 -- Teal tint
            elseif (i % 2 == 0) then
                baseColorR, baseColorG, baseColorB = 0.17, 0.17, 0.17 -- #2C2C2C
            else
                baseColorR, baseColorG, baseColorB = 0.12, 0.12, 0.12 -- #1E1E1E
            end
            
            bg:SetColorTexture(baseColorR, baseColorG, baseColorB, 1)
            
            -- Hover Effect
            rowFrame:SetScript("OnEnter", function() 
                bg:SetColorTexture(0.24, 0.24, 0.24, 1) -- #3D3D3D (Highlight)
            end)
            rowFrame:SetScript("OnLeave", function() 
                -- Restore original color
                bg:SetColorTexture(baseColorR, baseColorG, baseColorB, 1)
            end)
            
            self.scroll:AddChild(row)
        end
    end
end
