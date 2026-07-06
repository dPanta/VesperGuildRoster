local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local DataHandle = vesperTools:NewModule("DataHandle")

-- DataHandle responsibilities:
-- 1) Static dungeon metadata lookup (mapID -> portal spell/name).
-- 2) Shared color helpers for key level and rating text.
-- 3) Persistent data accessors for ilvl sync + best-key sync stores.
-- Runtime indexes built once from the static dungeon catalog below.
local dungListDB = nil
local dungNameDB = nil
local DUNGEON_PORTAL_SPELL_OPTIONS = {
    allowSessionCache = true,
    rememberSession = true,
    sessionScope = "dungeonPortal",
}

local function normalizeDungeonName(dungeonName)
    if type(dungeonName) ~= "string" or dungeonName == "" then
        return nil
    end

    return string.lower(dungeonName)
end

-- Canonical dungeon catalog used by portal and roster modules.
-- Note: some dungeons intentionally appear twice with different portal spell IDs.
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
        { exp = "BfA", mapID = 249, spellID = 1286831, dungeonName = "Kings' Rest" },
        { exp = "BfA", mapID = 250, spellID = 1286828, dungeonName = "Temple of Sethraliss" },
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
        
        -- Midnight (Mid) - Season 1 portal catalog
        -- Skyreach has both a Midnight Keystone Hero teleport and the older Warlords Challenge Mode teleport.
        { exp = "Mid", mapID = 161, spellID = 1254557, dungeonName = "Skyreach" },
        { exp = "Mid", mapID = 161, spellID = 159898, dungeonName = "Skyreach" },
        { exp = "Mid", mapID = 239, spellID = 1254551, dungeonName = "Seat of the Triumvirate" },
        { exp = "Mid", mapID = 556, spellID = 1254555, dungeonName = "Pit of Saron" },
        { exp = "Mid", mapID = 557, spellID = 1254400, dungeonName = "Windrunner Spire" },
        { exp = "Mid", mapID = 558, spellID = 1254572, dungeonName = "Magisters' Terrace" },
        { exp = "Mid", mapID = 559, spellID = 1254563, dungeonName = "Nexus-Point Xenas" },
        { exp = "Mid", mapID = 560, spellID = 1254559, dungeonName = "Maisara Caverns" },

        -- Midnight (Mid) - Season 2 portal catalog
        { exp = "Mid", mapID = 584, spellID = 1286801, dungeonName = "The Blinding Vale" },
        { exp = "Mid", mapID = 585, spellID = 1286804, dungeonName = "Voidscar Arena" },
        { exp = "Mid", mapID = 586, spellID = 1286807, dungeonName = "Den of Nalorakk" },
        { exp = "Mid", mapID = 587, spellID = 1286809, dungeonName = "Murder Row" },
        { exp = "Mid", mapID = 588, spellID = 1286812, dungeonName = "Altar of Fangs" },
    }

function DataHandle:OnInitialize()
    -- Initialize the local database
    dungListDB = {}
    dungNameDB = {}

    -- Build mapID index for O(1) lookup in runtime UI code.
    for _, dungInfo in ipairs(dungList) do
        -- Keep list shape to preserve multiple entries for same mapID if needed.
        if not dungListDB[dungInfo.mapID] then
            dungListDB[dungInfo.mapID] = {}
        end
        table.insert(dungListDB[dungInfo.mapID], dungInfo)

        local normalizedName = normalizeDungeonName(dungInfo.dungeonName)
        if normalizedName then
            if not dungNameDB[normalizedName] then
                dungNameDB[normalizedName] = {}
            end
            table.insert(dungNameDB[normalizedName], dungInfo)
        end
    end
end

function DataHandle:OnEnable()
    -- Module is enabled
end

function DataHandle:GetDungeonList()
    return dungList
end

function DataHandle:GetDungeonsByMapID(mapID)
    if dungListDB and dungListDB[mapID] then
        return dungListDB[mapID]
    end

    return nil
end

function DataHandle:GetDungeonsByDungeonName(dungeonName)
    local normalizedName = normalizeDungeonName(dungeonName)
    if normalizedName and dungNameDB and dungNameDB[normalizedName] then
        return dungNameDB[normalizedName]
    end

    return nil
end

function DataHandle:GetDungeonsByMapIDOrDungeonName(mapID, dungeonName)
    return self:GetDungeonsByMapID(mapID) or self:GetDungeonsByDungeonName(dungeonName)
end

function DataHandle:GetDefaultDungeonByMapID(mapID)
    local entries = self:GetDungeonsByMapID(mapID)
    if type(entries) == "table" and #entries > 0 then
        return entries[1]
    end
    return nil
end

-- Return the configured dungeon record for this character, preferring a known portal variant.
function DataHandle:GetDungeonByMapID(mapID)
    local entries = self:GetDungeonsByMapID(mapID)
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end

    for i = 1, #entries do
        local dungInfo = entries[i]
        if dungInfo and vesperTools:IsSpellKnownForPlayer(dungInfo.spellID, DUNGEON_PORTAL_SPELL_OPTIONS) then
            return dungInfo
        end
    end

    -- Return first configured record as default for consumers expecting one entry.
    return entries[1]
end

function DataHandle:GetKnownDungeonByMapID(mapID)
    local entries = self:GetDungeonsByMapID(mapID)
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end

    for i = 1, #entries do
        local dungInfo = entries[i]
        if dungInfo and vesperTools:IsSpellKnownForPlayer(dungInfo.spellID, DUNGEON_PORTAL_SPELL_OPTIONS) then
            return dungInfo
        end
    end

    return nil
end

function DataHandle:GetSpellIDByMapID(mapID)
    local dungInfo = self:GetDungeonByMapID(mapID)
    return dungInfo and dungInfo.spellID or nil
end

-- Report unknown mapIDs so seasonal metadata gaps are easy to spot.
function DataHandle:GetMissingDungeonsForMapIDs(mapIDs)
    local missing = {}
    if type(mapIDs) ~= "table" then
        return missing
    end

    for i = 1, #mapIDs do
        local mapID = tonumber(mapIDs[i])
        if mapID and not self:GetDungeonsByMapID(mapID) then
            missing[#missing + 1] = mapID
        end
    end

    return missing
end

function DataHandle:GetDB()
    return dungListDB
end

-- M+ key level coloring (Blizzard API, auto-updates each season)
function DataHandle:GetKeyColor(level)
    local ok, color = false, nil
    if C_ChallengeMode and type(C_ChallengeMode.GetKeystoneLevelRarityColor) == "function" then
        ok, color = pcall(C_ChallengeMode.GetKeystoneLevelRarityColor, level)
    end
    color = ok and color or nil
    if color then
        -- Convert float color components [0..1] to integer hex for "|cffRRGGBB".
        local r = math.floor((color.r or 0) * 255 + 0.5)
        local g = math.floor((color.g or 0) * 255 + 0.5)
        local b = math.floor((color.b or 0) * 255 + 0.5)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cff9d9d9d"
end

-- M+ rating coloring (Blizzard API, auto-updates each season)
function DataHandle:GetRatingColor(rating)
    local ok, color = false, nil
    if C_ChallengeMode and type(C_ChallengeMode.GetDungeonScoreRarityColor) == "function" then
        ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, rating)
    end
    color = ok and color or nil
    if color then
        -- Convert float color components [0..1] to integer hex for "|cffRRGGBB".
        local r = math.floor((color.r or 0) * 255 + 0.5)
        local g = math.floor((color.g or 0) * 255 + 0.5)
        local b = math.floor((color.b or 0) * 255 + 0.5)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cff9d9d9d"
end

-- ilvl Sync DB accessors (persistent via AceDB global)
function DataHandle:GetIlvlDB()
    return vesperTools.db.global.ilvlSync
end

-- Store one guild member's synced item level payload.
function DataHandle:StoreIlvl(playerName, ilvl, classID)
    if not vesperTools.db.global.ilvlSync then
        vesperTools.db.global.ilvlSync = {}
    end
    -- Timestamp supports stale-data cleanup and optional freshness UI.
    vesperTools.db.global.ilvlSync[playerName] = {
        ilvl = ilvl,
        classID = classID,
        timestamp = time(),
    }
end

function DataHandle:GetIlvlForPlayer(playerName)
    local db = vesperTools.db.global.ilvlSync
    if not db or not db[playerName] then
        return nil
    end
    return db[playerName]
end

-- Prune old ilvl entries so long-lived SavedVariables do not keep dead data forever.
function DataHandle:CleanupStaleIlvl(maxAge)
    local db = vesperTools.db.global.ilvlSync
    if not db then return end
    maxAge = maxAge or (7 * 24 * 3600) -- default 7 days
    local now = time()
    -- In-place prune to keep SavedVariables bounded over long play sessions.
    for name, data in pairs(db) do
        if not data.timestamp or (now - data.timestamp) > maxAge then
            db[name] = nil
        end
    end
end

-- Mythic+ rating-run selection shared by the portals Best Runs frame and the
-- best-keys broadcast, so every surface shows the score-contributing run.
local function getRatingRunDurationSeconds(run)
    local durationSec = tonumber(run and run.durationSec)
    if durationSec then
        return math.max(0, math.floor(durationSec + 0.5))
    end

    local durationMS = tonumber(run and (run.bestRunDurationMS or run.durationMS))
    if durationMS then
        return math.max(0, math.floor((durationMS / 1000) + 0.5))
    end

    return 0
end

local function normalizeRatingRun(run)
    if type(run) ~= "table" then
        return nil
    end

    local mapID = tonumber(run.challengeModeID or run.mapChallengeModeID or run.mapID)
    local level = tonumber(run.bestRunLevel or run.level)
    if not mapID or mapID <= 0 or not level or level <= 0 then
        return nil
    end

    return {
        mapID = math.floor(mapID + 0.5),
        level = math.floor(level + 0.5),
        duration = getRatingRunDurationSeconds(run),
        inTime = run.finishedSuccess == true or run.inTime == true or run.onTime == true,
        score = tonumber(run.mapScore or run.runScore or run.dungeonScore or run.score) or 0,
    }
end

local function isBetterRatingRun(left, right)
    if not right then
        return true
    end

    if left.score ~= right.score then
        return left.score > right.score
    end
    if left.level ~= right.level then
        return left.level > right.level
    end

    local leftTimed = left.inTime and 1 or 0
    local rightTimed = right.inTime and 1 or 0
    if leftTimed ~= rightTimed then
        return leftTimed > rightTimed
    end

    local leftDuration = tonumber(left.duration) or math.huge
    local rightDuration = tonumber(right.duration) or math.huge
    return leftDuration < rightDuration
end

function DataHandle:GetPlayerMythicPlusRatingSummary()
    if C_PlayerInfo and type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) == "function" then
        local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if ok and type(summary) == "table" then
            return summary
        end
    end

    return nil
end

-- Per-map run that contributes the player's Mythic+ rating (score first, then
-- level, timed, duration as tiebreaks).
function DataHandle:GetBestRatingRunsByMap(summary)
    summary = summary or self:GetPlayerMythicPlusRatingSummary()
    local runs = type(summary) == "table" and summary.runs or nil
    if type(runs) ~= "table" then
        return {}
    end

    local bestRuns = {}
    for _, run in ipairs(runs) do
        local normalized = normalizeRatingRun(run)
        if normalized and isBetterRatingRun(normalized, bestRuns[normalized.mapID]) then
            bestRuns[normalized.mapID] = normalized
        end
    end

    return bestRuns
end

-- Best Keys Sync DB accessors (persistent via AceDB global)
function DataHandle:GetBestKeysDB()
    return vesperTools.db.global.bestKeys
end

-- Store one guild member's best-key snapshot with shared metadata fields.
function DataHandle:StoreBestKeys(playerName, bestKeysData, classID)
    if not vesperTools.db.global.bestKeys then
        vesperTools.db.global.bestKeys = {}
    end
    -- Store metadata on the same object to simplify downstream display logic.
    bestKeysData.timestamp = time()
    bestKeysData.classID = classID
    vesperTools.db.global.bestKeys[playerName] = bestKeysData
end

function DataHandle:GetBestKeysForPlayer(playerName)
    local db = vesperTools.db.global.bestKeys
    if not db or not db[playerName] then
        return nil
    end
    return db[playerName]
end

-- Prune old best-key snapshots once they are outside the freshness window.
function DataHandle:CleanupStaleBestKeys(maxAge)
    local db = vesperTools.db.global.bestKeys
    if not db then return end
    maxAge = maxAge or (7 * 24 * 3600) -- default 7 days
    local now = time()
    -- Remove outdated rows so guild-best tooltips prioritize recent season data.
    for name, data in pairs(db) do
        if data.timestamp and (now - data.timestamp) > maxAge then
            db[name] = nil
        end
    end
end
