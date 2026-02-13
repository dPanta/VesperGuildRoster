local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Portals = VesperGuild:NewModule("Portals", "AceConsole-3.0", "AceEvent-3.0")

function Portals:OnInitialize()
    self:RegisterEvent("PLAYER_LOGIN")
end

function Portals:PLAYER_LOGIN()
    self:RegisterChatCommand("vesperportals", "Toggle")
    self:CreatePortalFrame()
end

function Portals:CreatePortalFrame()
    local _, englishClass = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(englishClass)
    self.classColor = classColor

    self.VesperPortalsUI = CreateFrame("Frame", "VesperGuildPortalFrame", UIParent, "BackdropTemplate")
    self.VesperPortalsUI:SetSize(300, 160)

    -- Restore saved position or use default
    if VesperGuild.db.profile.portalsPosition then
        local pos = VesperGuild.db.profile.portalsPosition
        self.VesperPortalsUI:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        self.VesperPortalsUI:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
    end

    self.VesperPortalsUI:SetFrameStrata("MEDIUM")
    self.VesperPortalsUI:SetMovable(true)
    self.VesperPortalsUI:EnableMouse(true)
    self.VesperPortalsUI:RegisterForDrag("LeftButton")
    self.VesperPortalsUI:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    self.VesperPortalsUI:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        VesperGuild.db.profile.portalsPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end)
    self.VesperPortalsUI:Hide()
    
     self.VesperPortalsUI:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8x8",
         edgeFile = "Interface\\Buttons\\WHITE8x8",
         edgeSize = 1,
     })
     self.VesperPortalsUI:SetBackdropColor(0.07, 0.07, 0.07, 0.95) -- #121212
     self.VesperPortalsUI:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if not DataHandle then
        print("ERROR: DataHandle module not found!")
        return
    end

    local curSeason = C_ChallengeMode.GetMapTable()
    local curSeasonDungs = {}
    for _, id in ipairs(curSeason) do
        local dungInfo = DataHandle:GetDungeonByMapID(id)
        if dungInfo then
            table.insert(curSeasonDungs, dungInfo)
        end
    end

    local index = 1
    for _, dungInfo in ipairs(curSeasonDungs) do
            local spellInfo = C_Spell.GetSpellInfo(dungInfo.spellID)
            local spellName = spellInfo and spellInfo.name
            local iconFileID = spellInfo and (spellInfo.iconID or spellInfo.originalIconID)
            local known = C_SpellBook.IsSpellInSpellBook(dungInfo.spellID)
            local btn = CreateFrame("Button", "PortalButton" .. index, self.VesperPortalsUI, "InsecureActionButtonTemplate")
                btn:SetSize(52, 52)
                
                -- Arrange in 4x2 grid (4 columns, 2 rows)
                local col = (index - 1) % 4
                local row = math.floor((index - 1) / 4)
                btn:SetPoint("TOPLEFT", self.VesperPortalsUI, "TOPLEFT", 20 + col * 70, -20 - row * 70)

            -- Background
            local tex = btn:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints(btn)
                tex:SetColorTexture(0, 0, 0, 0.8)
            
            -- Highlight on mouseover
            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
			    highlight:SetAllPoints(btn)
			    highlight:SetColorTexture(1, 1, 0, 0.4)
			    btn:SetHighlightTexture(highlight)

            -- Dungeon Icon Overlay
            local icon = btn:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(btn)
                icon:SetTexture(iconFileID or "Interface\\ICONS\\INV_Misc_QuestionMark")
                btn.icon = icon

            -- CD
            btn.cooldownFrame = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
			btn.cooldownFrame:SetAllPoints(btn)

            -- Check if player unlocked the portal 
            if not known == true then
				icon:SetDesaturated(true)
				icon:SetAlpha(0.5)
				btn:EnableMouse(false)
			else
				icon:SetDesaturated(false)
				icon:SetAlpha(1)
				btn:EnableMouse(true)
			end

            -- Tooltip
            btn.dungeonName = dungInfo.dungeonName
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.dungeonName, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            -- Clickitty Click
            btn:SetAttribute("type1", "spell")
            btn:SetAttribute("spell1", spellName)
            btn:RegisterForClicks("AnyUp", "AnyDown")

            index = index + 1
        end

    self:CreateVaultFrame()
    self:CreateMPlusProgFrame(curSeason)
end

function Portals:CreateVaultFrame()
    self.vaultFrame = CreateFrame("Frame", "VesperGuildVaultFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.vaultFrame:SetSize(72, 72)
    self.vaultFrame:SetPoint("TOP", self.VesperPortalsUI, "BOTTOM", 0, -10)
    self.vaultFrame:SetFrameStrata("MEDIUM")

    self.vaultFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.vaultFrame:SetBackdropColor(0.07, 0.07, 0.07, 0.95)
    self.vaultFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local btn = CreateFrame("Button", nil, self.vaultFrame)
    btn:SetSize(52, 52)
    btn:SetPoint("CENTER")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider")

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 0, 0.4)
    btn:SetHighlightTexture(highlight)

    btn:SetScript("OnClick", function()
        if WeeklyRewards_ShowUI then
            WeeklyRewards_ShowUI()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Great Vault", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Portals:CreateMPlusProgFrame(curSeason)
    local rowHeight = 18
    local headerHeight = 22
    local padding = 10
    local bestColWidth = 40 -- space for "+XX" text
    local timeColWidth = 55 -- space for "mm:ss" text
    local gap = 10 -- gap between columns
    local numDungeons = #curSeason
    local frameHeight = headerHeight + (numDungeons * rowHeight) + (padding * 2)

    -- Measure widest dungeon name to size frame dynamically
    local measure = UIParent:CreateFontString(nil, "OVERLAY")
    measure:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
    local maxNameWidth = 0
    for _, mapID in ipairs(curSeason) do
        local dungName = C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown"
        measure:SetText(dungName)
        local w = measure:GetStringWidth()
        if w > maxNameWidth then maxNameWidth = w end
    end
    measure:Hide()

    local frameWidth = math.ceil(maxNameWidth) + bestColWidth + timeColWidth + (gap * 2) + (padding * 2)

    self.mplusProgFrame = CreateFrame("Frame", "VesperGuildMPlusProgFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.mplusProgFrame:SetSize(frameWidth, frameHeight)
    self.mplusProgFrame:SetPoint("LEFT", self.VesperPortalsUI, "RIGHT", 10, 0)
    self.mplusProgFrame:SetFrameStrata("MEDIUM")

    self.mplusProgFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.mplusProgFrame:SetBackdropColor(0.07, 0.07, 0.07, 0.95)
    self.mplusProgFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local timeColRight = -padding
    local bestColRight = timeColRight - timeColWidth - gap

    -- Header
    local nameHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    nameHeader:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
    nameHeader:SetPoint("TOPLEFT", padding, -padding)
    nameHeader:SetText("|cffFFFFFFDungeon|r")

    local keyHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    keyHeader:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
    keyHeader:SetPoint("TOPRIGHT", bestColRight, -padding)
    keyHeader:SetText("|cffFFFFFFBest|r")

    local timeHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    timeHeader:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
    timeHeader:SetPoint("TOPRIGHT", timeColRight, -padding)
    timeHeader:SetText("|cffFFFFFFTime|r")

    -- Rows
    for i, mapID in ipairs(curSeason) do
        local rowTop = -(padding + headerHeight + (i - 1) * rowHeight)
        local rowCenter = rowTop - (rowHeight / 2)

        -- Zebra stripe background
        if i % 2 == 0 then
            local stripe = self.mplusProgFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
            stripe:SetPoint("TOPLEFT", self.mplusProgFrame, "TOPLEFT", 1, rowTop)
            stripe:SetPoint("TOPRIGHT", self.mplusProgFrame, "TOPRIGHT", -1, rowTop)
            stripe:SetHeight(rowHeight)
            stripe:SetColorTexture(0.17, 0.17, 0.17, 1)
        end

        -- Dungeon name
        local dungName = C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown"
        local nameText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        nameText:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
        nameText:SetPoint("LEFT", self.mplusProgFrame, "TOPLEFT", padding, rowCenter)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(dungName)

        -- Best key level
        local bestLevel = 0
        local bestDuration = 0
        local wasInTime = false
        local inTimeInfo, overTimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
        if inTimeInfo and inTimeInfo.level then
            bestLevel = inTimeInfo.level
            bestDuration = inTimeInfo.durationSec
            wasInTime = true
        end
        if overTimeInfo and overTimeInfo.level and overTimeInfo.level > bestLevel then
            bestLevel = overTimeInfo.level
            bestDuration = overTimeInfo.durationSec
            wasInTime = false
        end

        local levelText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        levelText:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
        levelText:SetPoint("RIGHT", self.mplusProgFrame, "TOPRIGHT", bestColRight, rowCenter)
        levelText:SetJustifyH("RIGHT")

        local timeText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        timeText:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 11, "")
        timeText:SetPoint("RIGHT", self.mplusProgFrame, "TOPRIGHT", timeColRight, rowCenter)
        timeText:SetJustifyH("RIGHT")

        if bestLevel > 0 then
            local DataHandle = VesperGuild:GetModule("DataHandle", true)
            local color = DataHandle and DataHandle:GetKeyColor(bestLevel) or "|cff9d9d9d"
            levelText:SetText(color .. "+" .. bestLevel .. "|r")

            local mins = math.floor(bestDuration / 60)
            local secs = bestDuration % 60
            local timeStr = string.format("%d:%02d", mins, secs)
            if wasInTime then
                timeText:SetText("|cff81c784" .. timeStr .. "|r") -- Material light green
            else
                timeText:SetText("|cffe57373" .. timeStr .. "|r") -- Material light red
            end
        else
            levelText:SetText("|cff9d9d9d-|r")
            timeText:SetText("|cff9d9d9d-|r")
        end
    end
end

function Portals:Toggle()
    if InCombatLockdown() then
        print("Can't toggle UI during combat.")
        return
    end

    if not VesperPortalsUI then
        print("Portal UI not initialized yet.")
        return
    end

    if self.VesperPortalsUI and self.VesperPortalsUI:IsShown() then
        self.VesperPortalsUI:Hide()
    elseif self.VesperPortalsUI then
        self.VesperPortalsUI:Show()
    end
end
