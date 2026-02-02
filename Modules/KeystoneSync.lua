local addonName = ...
local VesperGuild = LibStub("AceAddon-3.0"):GetAddon(addonName)
local KeystoneSync = VesperGuild:NewModule("KeystoneSync", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Dungeon abbreviation lookup (TWW Season 1 dungeons)
local DUNGEON_ABBREV = {
    -- The War Within Season 1
    [353] = "BRH",      -- Brackenhide Hollow (DF)
    [375] = "MISTS",    -- Mists of Tirna Scithe (SL)
    [376] = "NW",       -- Necrotic Wake (SL)
    [399] = "RUBY",     -- Ruby Life Pools (DF)
    [400] = "NOK",      -- Nokhud Offensive (DF)
    [401] = "AV",       -- Azurevault (DF)
    [507] = "GB",       -- Grim Batol (Cata)
    [353] = "SOB",      -- Siege of Boralus (BFA)
    -- Add more as needed for current season
}

function KeystoneSync:OnEnable()
    -- Register AceComm prefix
    self:RegisterComm("VesperKey", "OnKeystoneReceived")
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdate")
    
    -- Clean up old entries on login
    self:CleanupStaleEntries()
    
    -- Broadcast our keystone
    self:ScheduleTimer("BroadcastKeystone", 2) -- Delay to let other systems initialize
end

function KeystoneSync:OnDisable()
    self:UnregisterAllComm()
    self:UnregisterAllEvents()
end

function KeystoneSync:OnPlayerEnteringWorld()
    self:ScheduleTimer("BroadcastKeystone", 3)
end

function KeystoneSync:OnBagUpdate()
    -- Delay broadcast to avoid spam during multiple bag operations
    if not self.broadcastTimer then
        self.broadcastTimer = self:ScheduleTimer(function()
            self:BroadcastKeystone()
            self.broadcastTimer = nil
        end, 1)
    end
end

function KeystoneSync:ScanKeystone()
    -- Try modern API first (available if player has a keystone)
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    
    if mapID and level and level > 0 then
        return mapID, level
    end
    
    return nil, 0
end

function KeystoneSync:BroadcastKeystone()
    local mapID, level = self:ScanKeystone()
    
    local message
    if mapID and level > 0 then
        message = string.format("%d:%d", mapID, level)
        VesperGuild:Print(string.format("Broadcasting keystone: %s +%d", self:GetDungeonAbbrev(mapID), level))
    else
        message = "0:0" -- No keystone
        VesperGuild:Print("Broadcasting: No keystone")
    end
    
    -- Send to guild channel
    self:SendCommMessage("VesperKey", message, "GUILD")
    
    -- Also update our own database
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    VesperGuild:Print("Storing keystone for: " .. playerName) -- Debug
    self:StoreKeystone(playerName, mapID or 0, level or 0)
end

function KeystoneSync:OnKeystoneReceived(prefix, message, distribution, sender)
    -- Parse message: "mapID:level"
    local mapID, level = string.match(message, "(%d+):(%d+)")
    mapID = tonumber(mapID)
    level = tonumber(level)
    
    if not mapID or not level then
        return -- Invalid message
    end
    
    -- Store in database
    self:StoreKeystone(sender, mapID, level)
    
    -- Fire custom event to update roster if it's open
    VesperGuild:SendMessage("VESPERGUILD_KEYSTONE_UPDATE", sender)
end

function KeystoneSync:StoreKeystone(playerName, mapID, level)
    if not VesperGuild.db.global.keystones then
        VesperGuild.db.global.keystones = {}
    end
    
    if mapID == 0 or level == 0 then
        -- Player has no keystone
        VesperGuild.db.global.keystones[playerName] = nil
    else
        VesperGuild.db.global.keystones[playerName] = {
            mapID = mapID,
            level = level,
            timestamp = time()
        }
    end
end

function KeystoneSync:GetKeystoneForPlayer(playerName)
    if not VesperGuild.db.global.keystones then
        return nil
    end
    
    local data = VesperGuild.db.global.keystones[playerName]
    if not data then
        return nil
    end
    
    -- Check if data is too old (>48 hours)
    local age = time() - data.timestamp
    if age > (48 * 3600) then
        VesperGuild.db.global.keystones[playerName] = nil
        return nil
    end
    
    -- Check if data is "stale" (>2 hours) for visual indicator
    local isStale = age > (2 * 3600)
    
    local abbrev = self:GetDungeonAbbrev(data.mapID)
    local display = string.format("%s +%d", abbrev, data.level)
    
    if isStale then
        display = display .. " ⏰"
    end
    
    return display
end

function KeystoneSync:GetDungeonAbbrev(mapID)
    -- Try lookup table first
    if DUNGEON_ABBREV[mapID] then
        return DUNGEON_ABBREV[mapID]
    end
    
    -- Fallback to API
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        -- Try to create abbreviation from first letters
        local abbrev = ""
        for word in string.gmatch(name, "%S+") do
            abbrev = abbrev .. string.sub(word, 1, 1):upper()
        end
        return abbrev
    end
    
    return "???" -- Unknown dungeon
end

function KeystoneSync:CleanupStaleEntries()
    if not VesperGuild.db.global.keystones then
        return
    end
    
    local now = time()
    local removed = 0
    
    for playerName, data in pairs(VesperGuild.db.global.keystones) do
        local age = now - data.timestamp
        if age > (48 * 3600) then
            VesperGuild.db.global.keystones[playerName] = nil
            removed = removed + 1
        end
    end
    
    if removed > 0 then
        VesperGuild:Print(string.format("Cleaned up %d stale keystone entries", removed))
    end
end
