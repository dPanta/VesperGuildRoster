local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local KeystoneSync = VesperGuild:NewModule("KeystoneSync", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Dungeon abbreviation lookup (TWW Season 1 dungeons)
local DUNGEON_ABBREV = {
    -- The War Within Season 3
    [499] = "DZIHAD",               -- Priory of Sacred Flame
    [542] = "ECOJUMP",              -- Eco Dome Almahdani
    [378] = "HALLS",                -- Halls of Atonement
    [525] = "FLOOD",                -- Operation Floodgate
    [503] = "ARA",                  -- Ara-Kara
    [392] = "MRGLGL!",              -- Gambit
    [391] = "STREETS",              -- Ulice hrichu
    [505] = "BUGS",                 -- Dawnbreaker
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

    -- Start repeating timer to sync keystones every minute (only when not in combat)
    self.syncTimer = self:ScheduleRepeatingTimer("TimedBroadcast", 60)
end

function KeystoneSync:DebugDumpKeystones()
    if not VesperGuild.db.global.keystones then
        VesperGuild:Print("Keystone database is empty mon, POPULATE IT!")
        return
    end
    
    VesperGuild:Print("=== Keystone Database ===")
    local count = 0
    for playerName, data in pairs(VesperGuild.db.global.keystones) do
        VesperGuild:Print(string.format("%s: %s +%d (age: %ds)", 
            playerName, 
            self:GetDungeonAbbrev(data.mapID), 
            data.level,
            time() - data.timestamp))
        count = count + 1
    end
    VesperGuild:Print(string.format("Total: %d keystones", count))
end

function KeystoneSync:OnDisable()
    -- Cancel the repeating sync timer
    if self.syncTimer then
        self:CancelTimer(self.syncTimer)
        self.syncTimer = nil
    end

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
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID() -- get mapID of current keystone
    local level = C_MythicPlus.GetOwnedKeystoneLevel() -- get level of current keystone
    
    if mapID and level > 0 then
        return mapID, level
    end
    
    return nil, 0
end

function KeystoneSync:TimedBroadcast()
    -- Skip broadcast if player is in combat
    if InCombatLockdown() then
        return
    end

    self:BroadcastKeystone()
end

function KeystoneSync:BroadcastKeystone()
    local mapID, level = self:ScanKeystone()

    local message
    if mapID and level > 0 then
        message = string.format("%d:%d", mapID, level)
    else
        message = "0:0" -- No keystone
    end

    -- Send to guild channel
    self:SendCommMessage("VesperKey", message, "GUILD")

    -- Also update local database
    local playerName = UnitName("player") .. "-" .. GetNormalizedRealmName()
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
    
    -- Normalize sender name: ensure realm is present
    if not string.find(sender, "-") then
        sender = sender .. "-" .. GetNormalizedRealmName()
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
    
    -- DEBUG: Show what we're looking for
    -- VesperGuild:Print("Looking for keystone: " .. playerName)
    
    local data = VesperGuild.db.global.keystones[playerName]
    if not data then
        -- DEBUG: Show what's in the database
        -- VesperGuild:Print("Not found. Database contains:")
        -- for k, v in pairs(VesperGuild.db.global.keystones) do
        --     VesperGuild:Print("  " .. k .. " -> " .. v.mapID .. ":" .. v.level)
        -- end
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
