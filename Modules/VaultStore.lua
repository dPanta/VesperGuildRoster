local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local VaultStore = vesperTools:NewModule("VaultStore", "AceEvent-3.0")

local DEFAULT_SNAPSHOT_LIFETIME = 7 * 24 * 3600
local WEEKLY_REWARDS_INTERACTION_TYPE = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.WeeklyRewards or 49
local RAID_DIFFICULTY_RANKS = {
    [17] = 1, -- Raid Finder
    [14] = 2, -- Normal
    [15] = 3, -- Heroic
    [16] = 4, -- Mythic
}
local DELVE_MAP_ITEM_IDS = {
    233071, -- Delver's Bounty
    235628, -- Delver's Bounty with upgrade data
}
local DELVE_MAP_ACTIVE_AURA_SPELL_ID = 473218
local DELVE_MAP_WEEKLY_ACQUIRED_QUEST_ID = 86371

local function buildRewardTypeOrder()
    local order = {}
    local seen = {}
    local thresholdType = Enum and Enum.WeeklyRewardChestThresholdType or nil

    local function add(value)
        if type(value) ~= "number" or seen[value] then
            return
        end
        seen[value] = true
        order[#order + 1] = value
    end

    if thresholdType then
        add(thresholdType.Activities)
        add(thresholdType.Raid)
        add(thresholdType.World)
    end

    return order
end

local REWARD_TYPE_ORDER = buildRewardTypeOrder()

local function normalizeLink(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function deepCopySimpleTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = deepCopySimpleTable(value)
        else
            copy[key] = value
        end
    end

    return copy
end

local function resolveRewardItemDBID(rewardInfo)
    if type(rewardInfo) ~= "table" then
        return nil
    end

    local candidate = rewardInfo.itemDBID
        or rewardInfo.itemDbID
        or rewardInfo.itemGUID
        or rewardInfo.itemGuid
        or rewardInfo.id

    if candidate == nil then
        return nil
    end

    local numeric = tonumber(candidate)
    if numeric then
        return tostring(math.floor(numeric + 0.5))
    end

    if type(candidate) == "string" and candidate ~= "" then
        return candidate
    end

    return nil
end

local function resolveActualRewardLinks(rewards)
    if type(rewards) ~= "table" then
        return nil, nil, nil
    end

    local getItemHyperlink = C_WeeklyRewards and C_WeeklyRewards.GetItemHyperlink or nil
    local actualItemLink = nil
    local actualUpgradeItemLink = nil
    local rewardItemDBID = nil

    for i = 1, #rewards do
        local rewardInfo = rewards[i]
        if type(rewardInfo) == "table" then
            actualItemLink = actualItemLink
                or normalizeLink(rewardInfo.itemLink)
                or normalizeLink(rewardInfo.itemHyperlink)
                or nil

            actualUpgradeItemLink = actualUpgradeItemLink
                or normalizeLink(rewardInfo.upgradeItemLink)
                or normalizeLink(rewardInfo.upgradeItemHyperlink)
                or nil

            local itemDBID = resolveRewardItemDBID(rewardInfo)
            if itemDBID and type(getItemHyperlink) == "function" then
                local hyperlink = normalizeLink(getItemHyperlink(itemDBID))
                if hyperlink and not actualItemLink then
                    actualItemLink = hyperlink
                    rewardItemDBID = itemDBID
                elseif hyperlink and not rewardItemDBID then
                    rewardItemDBID = itemDBID
                end
            end

            if actualItemLink and (actualUpgradeItemLink or rewardItemDBID) then
                break
            end
        end
    end

    return actualItemLink, actualUpgradeItemLink, rewardItemDBID
end

local function getRaidDifficultyRank(difficultyID)
    local numeric = tonumber(difficultyID)
    if not numeric then
        return 0
    end

    return RAID_DIFFICULTY_RANKS[math.floor(numeric + 0.5)] or 0
end

local function resolveRaidSourceDifficultyID(encounterInfo, threshold)
    if type(encounterInfo) ~= "table" then
        return nil
    end

    local difficulties = {}
    for index = 1, #encounterInfo do
        local difficultyID = tonumber(encounterInfo[index] and encounterInfo[index].bestDifficulty)
        local rounded = difficultyID and math.floor(difficultyID + 0.5) or nil
        if rounded and getRaidDifficultyRank(rounded) > 0 then
            difficulties[#difficulties + 1] = rounded
        end
    end

    if #difficulties == 0 then
        return nil
    end

    table.sort(difficulties, function(left, right)
        return getRaidDifficultyRank(left) > getRaidDifficultyRank(right)
    end)

    local pickIndex = math.min(math.max(1, tonumber(threshold) or 1), #difficulties)
    return difficulties[pickIndex]
end

local function getCurrentDelveMapItemCount()
    local getItemCount = C_Item and C_Item.GetItemCount or GetItemCount
    if type(getItemCount) ~= "function" then
        return 0
    end

    local total = 0
    for i = 1, #DELVE_MAP_ITEM_IDS do
        total = total + math.max(0, tonumber(getItemCount(DELVE_MAP_ITEM_IDS[i], true)) or 0)
    end

    return total
end

local function hasPlayerAuraBySpellID(spellID)
    if C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
    end

    if AuraUtil and type(AuraUtil.FindAuraBySpellID) == "function" then
        return AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL") ~= nil
    end

    return false
end

local function isQuestCompleted(questID)
    if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
        return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
    end

    if type(IsQuestFlaggedCompleted) == "function" then
        return IsQuestFlaggedCompleted(questID) and true or false
    end

    return false
end

local function getCurrentWeekStartTime()
    if C_DateAndTime and type(C_DateAndTime.GetWeeklyResetStartTime) == "function" then
        local resetStartTime = tonumber(C_DateAndTime.GetWeeklyResetStartTime())
        if resetStartTime and resetStartTime > 0 then
            return math.floor(resetStartTime + 0.5)
        end
    end

    return nil
end

local function getRunHistory()
    if not C_MythicPlus or type(C_MythicPlus.GetRunHistory) ~= "function" then
        return {}
    end

    local attempts = {
        { true, true, true },
        {},
    }

    for index = 1, #attempts do
        local ok, runs = pcall(C_MythicPlus.GetRunHistory, unpack(attempts[index]))
        if ok and type(runs) == "table" then
            return runs
        end
    end

    return {}
end

local function getRunCompletionTimestamp(completionDate)
    if type(completionDate) ~= "table" then
        return nil
    end

    local year = tonumber(completionDate.year)
    local month = tonumber(completionDate.month)
    local day = tonumber(completionDate.day)
    if year == nil or month == nil or day == nil then
        return nil
    end

    local timestamp = time({
        year = year + 2000,
        month = month + 1,
        day = day + 1,
        hour = 12,
    })

    local numeric = tonumber(timestamp)
    if numeric and numeric > 0 then
        return math.floor(numeric + 0.5)
    end

    return nil
end

local function isRunFromCurrentWeek(run, weekStartAt)
    if type(run) ~= "table" then
        return false
    end

    if run.thisWeek ~= nil then
        return run.thisWeek and true or false
    end

    local completionTimestamp = getRunCompletionTimestamp(run.completionDate)
    if completionTimestamp and weekStartAt and weekStartAt > 0 then
        return completionTimestamp >= weekStartAt
    end

    return false
end

local function compareDungeonRuns(left, right)
    local leftLevel = tonumber(left and left.level) or 0
    local rightLevel = tonumber(right and right.level) or 0
    if leftLevel ~= rightLevel then
        return leftLevel > rightLevel
    end

    local leftScore = tonumber(left and left.runScore) or 0
    local rightScore = tonumber(right and right.runScore) or 0
    if leftScore ~= rightScore then
        return leftScore > rightScore
    end

    local leftCompleted = left and left.completed and 1 or 0
    local rightCompleted = right and right.completed and 1 or 0
    if leftCompleted ~= rightCompleted then
        return leftCompleted > rightCompleted
    end

    local leftDuration = tonumber(left and left.durationSec) or math.huge
    local rightDuration = tonumber(right and right.durationSec) or math.huge
    if leftDuration ~= rightDuration then
        return leftDuration < rightDuration
    end

    local leftMapID = tonumber(left and left.mapChallengeModeID) or 0
    local rightMapID = tonumber(right and right.mapChallengeModeID) or 0
    if leftMapID ~= rightMapID then
        return leftMapID < rightMapID
    end

    return false
end

local function areDelveMapStatesEqual(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    return (tonumber(left.mapItemCount) or 0) == (tonumber(right.mapItemCount) or 0)
        and (left.hasMapItem and true or false) == (right.hasMapItem and true or false)
        and (left.hasPendingBuff and true or false) == (right.hasPendingBuff and true or false)
        and (left.weeklyMapAcquired and true or false) == (right.weeklyMapAcquired and true or false)
        and (left.usedThisWeek and true or false) == (right.usedThisWeek and true or false)
        and (tonumber(left.weekStartAt) or 0) == (tonumber(right.weekStartAt) or 0)
end

function VaultStore:OnInitialize()
    self.pendingCaptureToken = 0
end

function VaultStore:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    self:RegisterEvent("WEEKLY_REWARDS_ITEM_CHANGED")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("UNIT_AURA")
end

function VaultStore:GetDB()
    return vesperTools:GetBagsDB()
end

function VaultStore:GetProfile()
    return vesperTools:GetBagsProfile()
end

function VaultStore:GetGlobalDB()
    local db = self:GetDB()
    if not db then
        return nil
    end

    local global = db.global or {}
    db.global = global
    global.schemaVersion = tonumber(global.schemaVersion) or 1
    global.vault = global.vault or {}
    global.vault.charactersByGUID = global.vault.charactersByGUID or {}

    return global
end

function VaultStore:GetVaultRoot()
    local global = self:GetGlobalDB()
    return global and global.vault or nil
end

function VaultStore:GetCurrentCharacterKey()
    return vesperTools:GetCurrentCharacterGUID()
end

function VaultStore:CreateOrUpdateCurrentCharacter()
    local root = self:GetVaultRoot()
    if not root then
        return nil, nil
    end

    local characterKey = self:GetCurrentCharacterKey()
    local character = root.charactersByGUID[characterKey]
    if not character then
        character = {}
        root.charactersByGUID[characterKey] = character
    end

    local name = UnitName("player") or UNKNOWN
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
    local _, _, classID = UnitClass("player")
    local faction = UnitFactionGroup("player") or UNKNOWN

    character.guid = characterKey
    character.name = name
    character.realm = realm
    character.fullName = string.format("%s-%s", name, realm)
    character.classID = classID
    character.faction = faction
    character.lastSeen = time()

    return characterKey, character
end

function VaultStore:GetCurrentWeekExpiration(now)
    local resolvedNow = tonumber(now) or time()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secondsUntilReset = tonumber(C_DateAndTime.GetSecondsUntilWeeklyReset())
        if secondsUntilReset and secondsUntilReset > 0 then
            return resolvedNow + secondsUntilReset
        end
    end

    return resolvedNow + DEFAULT_SNAPSHOT_LIFETIME
end

function VaultStore:BuildCurrentCharacterDelveMapState(now)
    local resolvedNow = tonumber(now) or time()
    local mapItemCount = getCurrentDelveMapItemCount()
    local hasMapItem = mapItemCount > 0
    local hasPendingBuff = hasPlayerAuraBySpellID(DELVE_MAP_ACTIVE_AURA_SPELL_ID)
    local weeklyMapAcquired = isQuestCompleted(DELVE_MAP_WEEKLY_ACQUIRED_QUEST_ID)

    return {
        capturedAt = resolvedNow,
        expiresAt = self:GetCurrentWeekExpiration(resolvedNow),
        weekStartAt = getCurrentWeekStartTime(),
        mapItemCount = mapItemCount,
        hasMapItem = hasMapItem,
        hasPendingBuff = hasPendingBuff,
        weeklyMapAcquired = weeklyMapAcquired,
        usedThisWeek = hasPendingBuff or (weeklyMapAcquired and not hasMapItem),
    }
end

function VaultStore:BuildCurrentCharacterWeeklyDungeonRuns()
    local runs = getRunHistory()
    local weekStartAt = getCurrentWeekStartTime()
    local weeklyRuns = {}

    for index = 1, #runs do
        local run = runs[index]
        local mapChallengeModeID = tonumber(run and (run.mapChallengeModeID or run.challengeModeID))
        local level = tonumber(run and (run.level or run.bestRunLevel))
        if mapChallengeModeID
            and mapChallengeModeID > 0
            and level
            and level > 0
            and isRunFromCurrentWeek(run, weekStartAt)
        then
            weeklyRuns[#weeklyRuns + 1] = {
                mapChallengeModeID = math.floor(mapChallengeModeID + 0.5),
                level = math.floor(level + 0.5),
                completed = run.completed and true or false,
                durationSec = tonumber(run.durationSec) or nil,
                runScore = tonumber(run.runScore or run.mapScore) or 0,
            }
        end
    end

    table.sort(weeklyRuns, compareDungeonRuns)
    return weeklyRuns
end

function VaultStore:GetStoredCharacterDelveMapItemCount(characterKey)
    if type(characterKey) ~= "string" or characterKey == "" then
        return 0
    end

    local total = 0
    for i = 1, #DELVE_MAP_ITEM_IDS do
        total = total + math.max(0, tonumber(vesperTools:GetCharacterItemCount(characterKey, DELVE_MAP_ITEM_IDS[i])) or 0)
    end

    return total
end

function VaultStore:UpdateCurrentCharacterDelveMapState()
    local now = time()
    self:CleanupExpiredSnapshots(now)

    local characterKey, character = self:CreateOrUpdateCurrentCharacter()
    if not characterKey or not character then
        return false
    end

    local nextState = self:BuildCurrentCharacterDelveMapState(now)
    local previousState = type(character.delveMap) == "table" and character.delveMap or nil
    local changed = previousState == nil or not areDelveMapStatesEqual(previousState, nextState)

    character.delveMap = nextState
    character.lastSeen = now

    if changed then
        vesperTools:SendMessage("VESPERTOOLS_VAULT_CHARACTER_UPDATED", characterKey)
    end

    return true
end

function VaultStore:CleanupExpiredSnapshots(now)
    local root = self:GetVaultRoot()
    if not root then
        return false
    end

    local resolvedNow = tonumber(now) or time()
    local removedAny = false

    for _, data in pairs(root.charactersByGUID) do
        if type(data) == "table" then
            local snapshot = type(data.vault) == "table" and data.vault or nil
            local expiresAt = tonumber(snapshot and snapshot.expiresAt) or 0
            if snapshot and expiresAt > 0 and expiresAt <= resolvedNow then
                data.vault = nil
                removedAny = true
            end

            local delveMap = type(data.delveMap) == "table" and data.delveMap or nil
            local delveMapExpiresAt = tonumber(delveMap and delveMap.expiresAt) or 0
            if delveMap and delveMapExpiresAt > 0 and delveMapExpiresAt <= resolvedNow then
                data.delveMap = nil
                removedAny = true
            end
        end
    end

    if removedAny then
        vesperTools:SendMessage("VESPERTOOLS_VAULT_SNAPSHOT_UPDATED")
        vesperTools:SendMessage("VESPERTOOLS_VAULT_CHARACTER_UPDATED")
    end

    return removedAny
end

function VaultStore:QueueCapture(delaySeconds)
    self.pendingCaptureToken = (tonumber(self.pendingCaptureToken) or 0) + 1
    local token = self.pendingCaptureToken
    local delay = math.max(0, tonumber(delaySeconds) or 0)

    if not C_Timer or not C_Timer.After then
        self:CaptureCurrentCharacterSnapshot()
        return
    end

    C_Timer.After(delay, function()
        if self.pendingCaptureToken ~= token then
            return
        end
        self:CaptureCurrentCharacterSnapshot()
    end)
end

function VaultStore:PLAYER_ENTERING_WORLD()
    self:CreateOrUpdateCurrentCharacter()
    self:CleanupExpiredSnapshots()
    self:UpdateCurrentCharacterDelveMapState()
    self:QueueCapture(1.0)
end

function VaultStore:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(_, interactionType)
    if interactionType ~= WEEKLY_REWARDS_INTERACTION_TYPE then
        return
    end

    self:QueueCapture(0)
end

function VaultStore:WEEKLY_REWARDS_UPDATE()
    self:QueueCapture(0)
end

function VaultStore:WEEKLY_REWARDS_ITEM_CHANGED()
    self:QueueCapture(0)
end

function VaultStore:CHALLENGE_MODE_COMPLETED()
    self:QueueCapture(1.5)
end

function VaultStore:BAG_UPDATE_DELAYED()
    self:UpdateCurrentCharacterDelveMapState()
end

function VaultStore:QUEST_LOG_UPDATE()
    self:UpdateCurrentCharacterDelveMapState()
end

function VaultStore:UNIT_AURA(_, unitTarget)
    if unitTarget ~= "player" then
        return
    end

    self:UpdateCurrentCharacterDelveMapState()
end

function VaultStore:BuildActivitySnapshot(rewardType, activity, index)
    if type(activity) ~= "table" then
        return nil
    end

    local threshold = tonumber(activity.threshold) or 0
    local exampleItemLink, exampleUpgradeItemLink = nil, nil
    if C_WeeklyRewards and C_WeeklyRewards.GetExampleRewardItemHyperlinks and activity.id then
        exampleItemLink, exampleUpgradeItemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
    end

    local actualItemLink, actualUpgradeItemLink, rewardItemDBID = resolveActualRewardLinks(activity.rewards)
    local raidEncounterInfo = nil
    local sourceDifficultyID = nil
    local thresholdType = Enum and Enum.WeeklyRewardChestThresholdType or nil

    if thresholdType
        and rewardType == thresholdType.Raid
        and C_WeeklyRewards
        and type(C_WeeklyRewards.GetActivityEncounterInfo) == "function"
    then
        raidEncounterInfo = C_WeeklyRewards.GetActivityEncounterInfo(rewardType, index)
        sourceDifficultyID = resolveRaidSourceDifficultyID(raidEncounterInfo, threshold)
    end

    return {
        index = tonumber(index) or 0,
        id = activity.id,
        threshold = threshold,
        progress = tonumber(activity.progress) or 0,
        level = tonumber(activity.level) or 0,
        claimID = activity.claimID,
        raidString = type(activity.raidString) == "string" and activity.raidString or nil,
        sourceDifficultyID = sourceDifficultyID,
        rewards = deepCopySimpleTable(activity.rewards),
        rewardItemDBID = rewardItemDBID,
        actualItemLink = normalizeLink(actualItemLink),
        actualUpgradeItemLink = normalizeLink(actualUpgradeItemLink),
        exampleItemLink = normalizeLink(exampleItemLink),
        exampleUpgradeItemLink = normalizeLink(exampleUpgradeItemLink),
        itemLink = normalizeLink(actualItemLink) or normalizeLink(exampleItemLink),
        upgradeItemLink = normalizeLink(actualUpgradeItemLink) or normalizeLink(exampleUpgradeItemLink),
    }
end

function VaultStore:BuildLaneSnapshot(rewardType)
    if not C_WeeklyRewards or type(C_WeeklyRewards.GetActivities) ~= "function" then
        return {}
    end

    local activities = C_WeeklyRewards.GetActivities(rewardType)
    if type(activities) ~= "table" then
        return {}
    end

    local rows = {}
    for index = 1, #activities do
        local row = self:BuildActivitySnapshot(rewardType, activities[index], index)
        if row then
            rows[#rows + 1] = row
        end
    end

    return rows
end

function VaultStore:CaptureCurrentCharacterSnapshot()
    if not C_WeeklyRewards or type(C_WeeklyRewards.GetActivities) ~= "function" then
        return false
    end

    local now = time()
    self:CleanupExpiredSnapshots(now)

    local characterKey, character = self:CreateOrUpdateCurrentCharacter()
    if not characterKey or not character then
        return false
    end

    local snapshot = {
        capturedAt = now,
        expiresAt = self:GetCurrentWeekExpiration(now),
        isCurrentRewardPeriod = type(C_WeeklyRewards.AreRewardsForCurrentRewardPeriod) == "function"
            and C_WeeklyRewards.AreRewardsForCurrentRewardPeriod() ~= false
            or true,
        canClaimRewards = type(C_WeeklyRewards.CanClaimRewards) == "function"
            and C_WeeklyRewards.CanClaimRewards() and true or false,
        hasGeneratedRewards = type(C_WeeklyRewards.HasGeneratedRewards) == "function"
            and C_WeeklyRewards.HasGeneratedRewards() and true or false,
        activities = {},
        weeklyDungeonRuns = self:BuildCurrentCharacterWeeklyDungeonRuns(),
    }

    local totalActivityCount = 0
    for i = 1, #REWARD_TYPE_ORDER do
        local rewardType = REWARD_TYPE_ORDER[i]
        local rows = self:BuildLaneSnapshot(rewardType)
        if #rows > 0 then
            snapshot.activities[rewardType] = rows
            totalActivityCount = totalActivityCount + #rows

            for rowIndex = 1, #rows do
                if rows[rowIndex].actualItemLink or rows[rowIndex].actualUpgradeItemLink then
                    snapshot.hasGeneratedRewards = true
                    break
                end
            end
        end
    end

    if totalActivityCount == 0 and not snapshot.canClaimRewards and not snapshot.hasGeneratedRewards then
        return false
    end

    character.vault = snapshot
    character.lastSeen = now

    vesperTools:SendMessage("VESPERTOOLS_VAULT_SNAPSHOT_UPDATED", characterKey)
    vesperTools:SendMessage("VESPERTOOLS_VAULT_CHARACTER_UPDATED", characterKey)
    return true
end

function VaultStore:GetCharacterRecord(characterKey)
    local root = self:GetVaultRoot()
    if not root or type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    return root.charactersByGUID[characterKey]
end

function VaultStore:GetCharacterVaultSnapshot(characterKey)
    self:CleanupExpiredSnapshots()

    local record = self:GetCharacterRecord(characterKey)
    return record and record.vault or nil
end

function VaultStore:GetCharacterDelveMapState(characterKey)
    self:CleanupExpiredSnapshots()

    local record = self:GetCharacterRecord(characterKey)
    if record and type(record.delveMap) == "table" then
        return record.delveMap
    end

    local mapItemCount = self:GetStoredCharacterDelveMapItemCount(characterKey)
    if mapItemCount > 0 then
        return {
            mapItemCount = mapItemCount,
            hasMapItem = true,
            hasPendingBuff = false,
            weeklyMapAcquired = false,
            usedThisWeek = false,
            isFallback = true,
        }
    end

    return nil
end

function VaultStore:GetCurrentCharacterSnapshot()
    local currentKey = self:GetCurrentCharacterKey()
    return currentKey and self:GetCharacterVaultSnapshot(currentKey) or nil
end

function VaultStore:GetDisplayCharacters()
    self:CleanupExpiredSnapshots()

    local root = self:GetVaultRoot()
    if not root then
        return {}
    end

    local currentKey = self:GetCurrentCharacterKey()
    local characters = {}
    local currentPlaceholder = nil

    for characterKey, data in pairs(root.charactersByGUID) do
        if type(data) == "table" then
            local snapshot = type(data.vault) == "table" and data.vault or nil
            local delveMap = type(data.delveMap) == "table" and data.delveMap or nil
            local hasSnapshot = snapshot and true or false
            local hasDelveMapState = delveMap and true or false
            local entry = {
                key = characterKey,
                fullName = data.fullName or characterKey,
                classID = data.classID,
                faction = data.faction,
                lastSeen = math.max(
                    tonumber(data.lastSeen) or 0,
                    tonumber(snapshot and snapshot.capturedAt) or 0,
                    tonumber(delveMap and delveMap.capturedAt) or 0
                ),
                hasSnapshot = hasSnapshot,
                hasDelveMapState = hasDelveMapState,
                isCurrent = characterKey == currentKey,
                isLive = characterKey == currentKey,
            }

            if hasSnapshot or hasDelveMapState then
                characters[#characters + 1] = entry
            elseif entry.isCurrent then
                currentPlaceholder = entry
            end
        end
    end

    if #characters == 0 and currentPlaceholder then
        characters[#characters + 1] = currentPlaceholder
    elseif currentPlaceholder then
        characters[#characters + 1] = currentPlaceholder
    end

    table.sort(characters, function(a, b)
        if a.isCurrent ~= b.isCurrent then
            return a.isCurrent
        end
        if a.hasSnapshot ~= b.hasSnapshot then
            return a.hasSnapshot
        end
        if a.hasDelveMapState ~= b.hasDelveMapState then
            return a.hasDelveMapState
        end
        return a.fullName < b.fullName
    end)

    return characters
end
