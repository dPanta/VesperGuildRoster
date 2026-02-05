local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Portals = VesperGuild:NewModule("Portals", "AceConsole-3.0", "AceEvent-3.0")

function Portals:OnInitialize()
    self:RegisterEvent("PLAYER_LOGIN")
end

function Portals:PLAYER_LOGIN()
    self:RegisterChatCommand("vesperportals", "Toggle")
    self:CreatePortalUI()
end

function Portals:CreatePortalUI()
    self.VesperDungeonPanel = CreateFrame("Frame", "VesperGuildDungeonPanel", UIParent, "BackdropTemplate")
    self.VesperDungeonPanel:SetSize(300, 160)
    self.VesperDungeonPanel:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
    self.VesperDungeonPanel:SetFrameStrata("MEDIUM")
    self.VesperDungeonPanel:Hide()

     self.VesperDungeonPanel:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8x8",
         edgeFile = "Interface\\Buttons\\WHITE8x8",
         edgeSize = 1,
     })
     self.VesperDungeonPanel:SetBackdropColor(0.07, 0.07, 0.07, 0.95) -- #121212
     self.VesperDungeonPanel:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local dungList = {
        -- Mists of Pandaria (MoP)
        { exp = "MoP", mapID = 2, spellID = 131204, dungeonName = "Temple of the Jade Serpent" },
        
        -- Cataclysm (Cat)
        { exp = "Cat", mapID = 438, spellID = 410080, dungeonName = "The Vortex Pinnacle" },
        { exp = "Cat", mapID = 456, spellID = 424142, dungeonName = "Throne of the Tides" },
        { exp = "Cat", mapID = 507, spellID = 445424, dungeonName = "Grim Batol" },
        
        -- Warlords of Draenor (WoD)
        { exp = "WoD", mapID = 165, spellID = 159899, dungeonName = "Shadowmoon Burial Grounds" },
        { exp = "WoD", mapID = 168, spellID = 159901, dungeonName = "The Everbloom" },
        { exp = "WoD", mapID = 206, spellID = 410078, dungeonName = "Neltharion's Lair" },
        
        -- Legion (Leg)
        { exp = "Leg", mapID = 199, spellID = 424153, dungeonName = "Black Rook Hold" },
        { exp = "Leg", mapID = 200, spellID = 393764, dungeonName = "Halls of Valor" },
        { exp = "Leg", mapID = 210, spellID = 393766, dungeonName = "Court of Stars" },
        { exp = "Leg", mapID = 198, spellID = 424163, dungeonName = "Darkheart Thicket" },
        
        -- Battle for Azeroth (BfA)
        { exp = "BfA", mapID = 244, spellID = 424187, dungeonName = "Atal'Dazar" },
        { exp = "BfA", mapID = 245, spellID = 410071, dungeonName = "Freehold" },
        { exp = "BfA", mapID = 247, spellID = 467553, dungeonName = "The MOTHERLODE!!" },
        { exp = "BfA", mapID = 247, spellID = 467555, dungeonName = "The MOTHERLODE!!" },
        { exp = "BfA", mapID = 248, spellID = 424167, dungeonName = "Waycrest Manor" },
        { exp = "BfA", mapID = 251, spellID = 410074, dungeonName = "The Underrot" },
        { exp = "BfA", mapID = 353, spellID = 464256, dungeonName = "Siege of Boralus" },
        { exp = "BfA", mapID = 353, spellID = 445418, dungeonName = "Siege of Boralus" },
        { exp = "BfA", mapID = 369, spellID = 373274, dungeonName = "Operation: Mechagon - Junkyard" },
        { exp = "BfA", mapID = 370, spellID = 373274, dungeonName = "Operation: Mechagon - Workshop" },
        
        -- Shadowlands (SL)
        { exp = "SL", mapID = 378, spellID = 354465, dungeonName = "Halls of Atonement" },
        { exp = "SL", mapID = 375, spellID = 354464, dungeonName = "Mists of Tirna Scithe" },
        { exp = "SL", mapID = 382, spellID = 354467, dungeonName = "Theater of Pain" },
        { exp = "SL", mapID = 376, spellID = 354462, dungeonName = "The Necrotic Wake" },
        { exp = "SL", mapID = 391, spellID = 367416, dungeonName = "Tazavesh, Streets of Wonder" },
        { exp = "SL", mapID = 392, spellID = 367416, dungeonName = "Tazavesh, Soleah's Gambit" },
        
        -- Dragonflight (DF)
        { exp = "DF", mapID = 399, spellID = 393256, dungeonName = "Ruby Life Pools" },
        { exp = "DF", mapID = 400, spellID = 393262, dungeonName = "The Nokhud Offensive" },
        { exp = "DF", mapID = 401, spellID = 393279, dungeonName = "The Azure Vault" },
        { exp = "DF", mapID = 402, spellID = 393273, dungeonName = "Algeth'ar Academy" },
        { exp = "DF", mapID = 403, spellID = 393222, dungeonName = "Uldaman: Legacy of Tyr" },
        { exp = "DF", mapID = 404, spellID = 393276, dungeonName = "Neltharus" },
        { exp = "DF", mapID = 405, spellID = 393267, dungeonName = "Brackenhide Hollow" },
        { exp = "DF", mapID = 406, spellID = 393283, dungeonName = "Halls of Infusion" },
        { exp = "DF", mapID = 463, spellID = 424197, dungeonName = "Dawn of the Infinite: Galakrond's Fall" },
        { exp = "DF", mapID = 464, spellID = 424197, dungeonName = "Dawn of the Infinite: Murozond's Rise" },
        
        -- The War Within (TWW)
        { exp = "TWW", mapID = 499, spellID = 445444, dungeonName = "Priory of the Sacred Flame" },
        { exp = "TWW", mapID = 500, spellID = 445443, dungeonName = "The Rookery" },
        { exp = "TWW", mapID = 501, spellID = 445269, dungeonName = "The Stonevault" },
        { exp = "TWW", mapID = 502, spellID = 445416, dungeonName = "City of Threads" },
        { exp = "TWW", mapID = 503, spellID = 445417, dungeonName = "Ara-Kara, City of Echoes" },
        { exp = "TWW", mapID = 504, spellID = 445441, dungeonName = "Darkflame Cleft" },
        { exp = "TWW", mapID = 505, spellID = 445414, dungeonName = "The Dawnbreaker" },
        { exp = "TWW", mapID = 506, spellID = 445440, dungeonName = "Cinderbrew Meadery" },
        { exp = "TWW", mapID = 525, spellID = 1216786, dungeonName = "Operation: Floodgate" },
        { exp = "TWW", mapID = 542, spellID = 1237215, dungeonName = "Eco-Dome Al'dani" },
        
        -- Midnight (Mid) - not yet released
        { exp = "Mid", mapID = 161, spellID = 1254557, dungeonName = "Skyreach" },
        { exp = "Mid", mapID = 239, spellID = 1254551, dungeonName = "Seat of the Triumvirate" },
        { exp = "Mid", mapID = 556, spellID = 1254555, dungeonName = "Pit of Saron" },
        { exp = "Mid", mapID = 557, spellID = 1254400, dungeonName = "Windrunner Spire" },
        { exp = "Mid", mapID = 558, spellID = 1254572, dungeonName = "Magisters' Terrace" },
        { exp = "Mid", mapID = 559, spellID = 1254563, dungeonName = "Nexus-Point Xenas" },
        { exp = "Mid", mapID = 560, spellID = 1254559, dungeonName = "Maisara Caverns" },
    }

    local curSeason = C_ChallengeMode.GetMapTable()
    local curSeasonDungs = {}
    for _, id in ipairs(curSeason) do
        for _, dungInfo in ipairs(dungList) do
            if dungInfo.mapID == id then
                table.insert(curSeasonDungs, dungInfo)
                print("Added dungeon:", dungInfo.dungeonName)
            end
        end
    end

    local index = 1
    for _, dungInfo in ipairs(curSeasonDungs) do
            local spellInfo = C_Spell.GetSpellInfo(dungInfo.spellID)
            local spellName = spellInfo and spellInfo.name
            local iconFileID = spellInfo and (spellInfo.iconID or spellInfo.originalIconID)
            local known = C_SpellBook.IsSpellInSpellBook(dungInfo.spellID)
            local btn = CreateFrame("Button", "PortalButton" .. index, self.VesperDungeonPanel, "InsecureActionButtonTemplate")
                btn:SetSize(52, 52)
                
                -- Arrange in 4x2 grid (4 columns, 2 rows)
                local col = (index - 1) % 4
                local row = math.floor((index - 1) / 4)
                btn:SetPoint("TOPLEFT", self.VesperDungeonPanel, "TOPLEFT", 20 + col * 70, -20 - row * 70)

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

            -- Clickitty Click
            print(spellName)
            btn:SetAttribute("type1", "spell")
            btn:SetAttribute("spell1", spellName)
            btn:RegisterForClicks("AnyUp", "AnyDown")
--            btn:EnableMouse(true)

            index = index + 1
        end
end

function Portals:Toggle()
    if InCombatLockdown() then
        print("Can't toggle UI during combat.")
        return
    end

    if not VesperDungeonPanel then
        print("Portal UI not initialized yet.")
        return
    end

    if self.VesperDungeonPanel:IsShown() then
        self.VesperDungeonPanel:Hide()
    else
        self.VesperDungeonPanel:Show()
    end
end
