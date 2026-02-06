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
    self.VesperPortalsUI = CreateFrame("Frame", "VesperGuildPortalFrame", UIParent, "BackdropTemplate")
    self.VesperPortalsUI:SetSize(300, 160)
    self.VesperPortalsUI:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
    self.VesperPortalsUI:SetFrameStrata("MEDIUM")
    self.VesperPortalsUI:Hide()
    
     self.VesperPortalsUI:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8x8",
         edgeFile = "Interface\\Buttons\\WHITE8x8",
         edgeSize = 1,
     })
     self.VesperPortalsUI:SetBackdropColor(0.07, 0.07, 0.07, 0.95) -- #121212
     self.VesperPortalsUI:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

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
