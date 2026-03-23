local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local GuildLookup = vesperTools:NewModule("GuildLookup", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0")
local L = vesperTools.L

-- Guild lookup adds a guild-only remote search layer on top of BagsStore snapshots.
-- It tracks the active query, throttles requests, and aggregates whisper responses.
local REQUEST_PREFIX = "VTBagsQ"
local RESPONSE_PREFIX = "VTBagsR"
local PROTOCOL_VERSION = "1"
local QUERY_COOLDOWN_SECONDS = 30
local RESPONSE_WINDOW_SECONDS = 4
local MIN_QUERY_LENGTH = 4
local MAX_RESPONSE_ITEMS = 25
local MAX_RESULT_ROWS = 250

-- Cached realm suffix keeps sender normalization consistent across mixed clients.
local cachedRealmName = nil

-- Force a roster refresh so guild-member validation stays current.
local function requestGuildRosterUpdate()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Normalize player names to a stable Name-Realm form for cache keys and comm routing.
local function normalizeSenderName(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalized = strtrim(name)
    if normalized == "" then
        return nil
    end

    if not string.find(normalized, "-", 1, true) then
        cachedRealmName = cachedRealmName or GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
        normalized = normalized .. "-" .. cachedRealmName
    end

    return normalized
end

-- Normalize bag text into a lowercase, markup-free search haystack.
local function normalizeSearchText(text)
    if type(text) ~= "string" then
        return nil
    end

    local normalized = text
    normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|T.-|t", " ")
    normalized = normalized:gsub("|A.-|a", " ")
    normalized = normalized:gsub("[%z\1-\31]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = strtrim(normalized)
    if normalized == "" then
        return nil
    end

    return string.lower(normalized)
end

local function getEffectiveQueryLength(normalizedQuery)
    if type(normalizedQuery) ~= "string" then
        return 0
    end

    local compact = normalizedQuery:gsub("%s+", "")
    return #compact
end

local function buildSearchTokens(normalizedQuery)
    if type(normalizedQuery) ~= "string" or normalizedQuery == "" then
        return nil
    end

    local tokens = {}
    for token in normalizedQuery:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    return #tokens > 0 and tokens or nil
end

local function buildFallbackItemName(itemID)
    return string.format(L["ITEM_FALLBACK_FMT"], tostring(itemID))
end

local function recordMatchesQuery(record, searchTokens)
    if not searchTokens or #searchTokens == 0 then
        return false
    end

    local haystack = type(record) == "table" and record.searchText or nil
    if not haystack then
        haystack = normalizeSearchText(table.concat({
            type(record) == "table" and (record.itemName or "") or "",
            type(record) == "table" and (record.itemDescription or "") or "",
        }, " "))
    end

    if not haystack then
        return false
    end

    for i = 1, #searchTokens do
        if not string.find(haystack, searchTokens[i], 1, true) then
            return false
        end
    end

    return true
end

local function getItemIconFileID(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then
            return icon
        end
    end

    if GetItemInfoInstant then
        local _, _, _, _, icon = GetItemInfoInstant(itemID)
        if icon then
            return icon
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function GuildLookup:OnInitialize()
    self.guildMemberSet = {}
    self.lastAcceptedRequestBySender = {}
    self.lastRequestAt = 0
    self.querySerial = 0
    self.activeQueryID = nil
    self.activeQueryText = nil
    self.activeDisplayQueryText = nil
    self.activeResultsByKey = {}
    self.finalizeTimer = nil
    self.state = {
        visible = false,
        status = "idle",
        queryText = nil,
        displayQueryText = nil,
        results = {},
        truncated = false,
        cooldownRemaining = 0,
        requestSentAt = 0,
    }
end

-- Register comm channels and refresh the guild-member allowlist on enable.
function GuildLookup:OnEnable()
    self:RegisterComm(REQUEST_PREFIX, "OnLookupRequestReceived")
    self:RegisterComm(RESPONSE_PREFIX, "OnLookupResponseReceived")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "RefreshGuildMemberCache")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnGuildMembershipChanged")
    self:RefreshGuildMemberCache()
    if IsInGuild() then
        requestGuildRosterUpdate()
    end
end

function GuildLookup:OnGuildMembershipChanged()
    self:RefreshGuildMemberCache()
    if not IsInGuild() then
        self:ClearResults()
    end
end

function GuildLookup:GetStore()
    return vesperTools:GetModule("BagsStore", true)
end

function GuildLookup:GetProfile()
    return vesperTools:GetBagsProfile()
end

function GuildLookup:IsActive()
    local profile = self:GetProfile()
    return profile and profile.guildLookup and profile.guildLookup.enabled and true or false
end

function GuildLookup:CanAnswerIncomingRequests()
    local profile = self:GetProfile()
    return profile and profile.guildLookup and profile.guildLookup.allowIncomingRequests and true or false
end

-- Persist the active toggle in the bags profile and reset state when disabled.
function GuildLookup:SetActive(isActive)
    local profile = self:GetProfile()
    if not profile then
        return false
    end

    profile.guildLookup = profile.guildLookup or {}
    profile.guildLookup.enabled = isActive and true or false

    if profile.guildLookup.enabled then
        self:RefreshGuildMemberCache()
        if IsInGuild() then
            requestGuildRosterUpdate()
        end
    else
        self:ClearResults()
        return false
    end

    self:NotifyUpdated()
    return true
end

function GuildLookup:ToggleActive()
    return self:SetActive(not self:IsActive())
end

function GuildLookup:GetMinimumQueryLength()
    return MIN_QUERY_LENGTH
end

function GuildLookup:GetRemainingCooldown()
    local remaining = QUERY_COOLDOWN_SECONDS - (GetTime() - (tonumber(self.lastRequestAt) or 0))
    if remaining <= 0 then
        return 0
    end
    return math.ceil(remaining)
end

function GuildLookup:GetDisplayState()
    return self.state
end

function GuildLookup:NotifyUpdated()
    vesperTools:SendMessage("VESPERTOOLS_GUILD_LOOKUP_UPDATED")
end

-- Cancel the delayed finalize step used to collect whisper responses for one query.
function GuildLookup:CancelFinalizeTimer()
    if self.finalizeTimer then
        self:CancelTimer(self.finalizeTimer, true)
        self.finalizeTimer = nil
    end
end

function GuildLookup:ClearResults()
    self:CancelFinalizeTimer()
    self.activeQueryID = nil
    self.activeQueryText = nil
    self.activeDisplayQueryText = nil
    wipe(self.activeResultsByKey)

    self.state.visible = false
    self.state.status = "idle"
    self.state.queryText = nil
    self.state.displayQueryText = nil
    wipe(self.state.results)
    self.state.truncated = false
    self.state.cooldownRemaining = 0
    self.state.requestSentAt = 0

    self:NotifyUpdated()
end

function GuildLookup:RefreshGuildMemberCache()
    wipe(self.guildMemberSet)

    if not IsInGuild() then
        return
    end

    local numMembers = GetNumGuildMembers()
    for index = 1, numMembers do
        local name = GetGuildRosterInfo(index)
        local fullName = normalizeSenderName(name)
        if fullName then
            self.guildMemberSet[fullName] = true
            self.guildMemberSet[fullName:gsub("%s+", "")] = true
        end
    end
end

function GuildLookup:IsKnownGuildMember(fullName)
    if type(fullName) ~= "string" or fullName == "" or not IsInGuild() then
        return false
    end

    if not next(self.guildMemberSet) then
        self:RefreshGuildMemberCache()
    end

    return (self.guildMemberSet[fullName] or self.guildMemberSet[fullName:gsub("%s+", "")]) and true or false
end

function GuildLookup:BuildCurrentCharacterMatches(normalizedQuery, maxItems)
    local searchTokens = buildSearchTokens(normalizedQuery)
    if not searchTokens then
        return {}, false
    end

    local store = self:GetStore()
    if not store then
        return {}, false
    end

    if type(store.CommitPendingBagWork) == "function" then
        store:CommitPendingBagWork()
    end

    local characterKey = store.GetCurrentCharacterKey and store:GetCurrentCharacterKey() or nil
    local snapshot = characterKey and store.GetCharacterBagSnapshot and store:GetCharacterBagSnapshot(characterKey) or nil
    local carried = type(snapshot) == "table" and snapshot.carried or nil
    local bags = type(carried) == "table" and carried.bags or nil
    if type(bags) ~= "table" then
        return {}, false
    end

    local matchesByKey = {}
    local matches = {}

    for _, bag in pairs(bags) do
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemID and recordMatchesQuery(record, searchTokens) then
                    local itemKey = tostring(record.itemID)
                    local entry = matchesByKey[itemKey]
                    if not entry then
                        entry = {
                            itemID = tonumber(record.itemID),
                            hyperlink = record.hyperlink,
                            itemName = record.itemName or buildFallbackItemName(record.itemID),
                            iconFileID = record.iconFileID or getItemIconFileID(record.itemID),
                            count = 0,
                        }
                        matchesByKey[itemKey] = entry
                        matches[#matches + 1] = entry
                    end

                    entry.count = entry.count + math.max(1, tonumber(record.stackCount) or 1)
                    if (not entry.hyperlink or entry.hyperlink == "") and type(record.hyperlink) == "string" and record.hyperlink ~= "" then
                        entry.hyperlink = record.hyperlink
                    end
                    if (not entry.itemName or entry.itemName == "") and record.itemName then
                        entry.itemName = record.itemName
                    end
                    if not entry.iconFileID and record.iconFileID then
                        entry.iconFileID = record.iconFileID
                    end
                end
            end
        end
    end

    table.sort(matches, function(a, b)
        local aName = string.lower(a.itemName or buildFallbackItemName(a.itemID))
        local bName = string.lower(b.itemName or buildFallbackItemName(b.itemID))
        if aName ~= bName then
            return aName < bName
        end
        if tonumber(a.count) ~= tonumber(b.count) then
            return (tonumber(a.count) or 0) > (tonumber(b.count) or 0)
        end
        return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
    end)

    local truncated = false
    if maxItems and #matches > maxItems then
        truncated = true
        for index = #matches, maxItems + 1, -1 do
            matches[index] = nil
        end
    end

    return matches, truncated
end

-- Convert the active response table into stable UI row ordering.
function GuildLookup:SortResults()
    table.sort(self.state.results, function(a, b)
        local aName = string.lower(a.itemName or buildFallbackItemName(a.itemID))
        local bName = string.lower(b.itemName or buildFallbackItemName(b.itemID))
        if aName ~= bName then
            return aName < bName
        end
        if a.sender ~= b.sender then
            return a.sender < b.sender
        end
        return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
    end)

    if #self.state.results > MAX_RESULT_ROWS then
        self.state.truncated = true
        for index = #self.state.results, MAX_RESULT_ROWS + 1, -1 do
            local row = self.state.results[index]
            if row and row.key then
                self.activeResultsByKey[row.key] = nil
            end
            self.state.results[index] = nil
        end
    end
end

function GuildLookup:FinalizeActiveLookup()
    self.finalizeTimer = nil
    if not self.activeQueryID then
        return
    end

    if #self.state.results > 0 then
        self.state.status = "results"
    else
        self.state.status = "no_results"
    end

    self:NotifyUpdated()
end

-- Start a new guild-wide query and reset all active response state.
function GuildLookup:StartLookup(queryText)
    local normalizedQuery = normalizeSearchText(queryText)
    local displayQueryText = type(queryText) == "string" and strtrim(queryText) or ""

    if not self:IsActive() then
        self:ClearResults()
        return false
    end

    if not normalizedQuery then
        self:ClearResults()
        return false
    end

    if getEffectiveQueryLength(normalizedQuery) < MIN_QUERY_LENGTH then
        self:CancelFinalizeTimer()
        self.activeQueryID = nil
        self.activeQueryText = normalizedQuery
        self.activeDisplayQueryText = displayQueryText ~= "" and displayQueryText or normalizedQuery
        wipe(self.activeResultsByKey)
        wipe(self.state.results)
        self.state.visible = true
        self.state.status = "too_short"
        self.state.queryText = normalizedQuery
        self.state.displayQueryText = self.activeDisplayQueryText
        self.state.truncated = false
        self.state.cooldownRemaining = 0
        self.state.requestSentAt = 0
        self:NotifyUpdated()
        return false
    end

    if not IsInGuild() then
        self:CancelFinalizeTimer()
        self.activeQueryID = nil
        self.activeQueryText = normalizedQuery
        self.activeDisplayQueryText = displayQueryText ~= "" and displayQueryText or normalizedQuery
        wipe(self.activeResultsByKey)
        wipe(self.state.results)
        self.state.visible = true
        self.state.status = "not_in_guild"
        self.state.queryText = normalizedQuery
        self.state.displayQueryText = self.activeDisplayQueryText
        self.state.truncated = false
        self.state.cooldownRemaining = 0
        self.state.requestSentAt = 0
        self:NotifyUpdated()
        return false
    end

    requestGuildRosterUpdate()
    self:RefreshGuildMemberCache()

    local remainingCooldown = self:GetRemainingCooldown()
    if remainingCooldown > 0 then
        self:CancelFinalizeTimer()
        self.activeQueryID = nil
        self.activeQueryText = normalizedQuery
        self.activeDisplayQueryText = displayQueryText ~= "" and displayQueryText or normalizedQuery
        wipe(self.activeResultsByKey)
        wipe(self.state.results)
        self.state.visible = true
        self.state.status = "cooldown"
        self.state.queryText = normalizedQuery
        self.state.displayQueryText = self.activeDisplayQueryText
        self.state.truncated = false
        self.state.cooldownRemaining = remainingCooldown
        self.state.requestSentAt = 0
        self:NotifyUpdated()
        return false
    end

    self.lastRequestAt = GetTime()
    self.querySerial = self.querySerial + 1
    self.activeQueryID = string.format("%d-%d", time(), self.querySerial)
    self.activeQueryText = normalizedQuery
    self.activeDisplayQueryText = displayQueryText ~= "" and displayQueryText or normalizedQuery
    wipe(self.activeResultsByKey)
    wipe(self.state.results)
    self.state.visible = true
    self.state.status = "searching"
    self.state.queryText = normalizedQuery
    self.state.displayQueryText = self.activeDisplayQueryText
    self.state.truncated = false
    self.state.cooldownRemaining = 0
    self.state.requestSentAt = self.lastRequestAt
    self:NotifyUpdated()

    self:CancelFinalizeTimer()
    self.finalizeTimer = self:ScheduleTimer("FinalizeActiveLookup", RESPONSE_WINDOW_SECONDS)
    self:SendCommMessage(REQUEST_PREFIX, table.concat({
        "QUERY",
        PROTOCOL_VERSION,
        self.activeQueryID,
        normalizedQuery,
    }, "\t"), "GUILD")

    return true
end

-- Answer a valid guild request with current-character carried-bag matches only.
function GuildLookup:OnLookupRequestReceived(prefix, message, distribution, sender)
    if prefix ~= REQUEST_PREFIX or distribution ~= "GUILD" then
        return
    end

    local messageType, version, queryID, queryText = strsplit("\t", message, 4)
    if messageType ~= "QUERY" or version ~= PROTOCOL_VERSION then
        return
    end

    local senderName = normalizeSenderName(sender)
    local playerName = normalizeSenderName(vesperTools:GetCurrentCharacterFullName())
    if not senderName or not playerName or senderName == playerName then
        return
    end

    if not self:CanAnswerIncomingRequests() then
        return
    end

    if not self:IsKnownGuildMember(senderName) then
        return
    end

    local normalizedQuery = normalizeSearchText(queryText)
    if not normalizedQuery or getEffectiveQueryLength(normalizedQuery) < MIN_QUERY_LENGTH then
        return
    end

    local now = GetTime()
    local lastRequestAt = tonumber(self.lastAcceptedRequestBySender[senderName]) or 0
    if (now - lastRequestAt) < QUERY_COOLDOWN_SECONDS then
        return
    end
    self.lastAcceptedRequestBySender[senderName] = now

    for knownSender, timestamp in pairs(self.lastAcceptedRequestBySender) do
        if (now - (tonumber(timestamp) or 0)) > (QUERY_COOLDOWN_SECONDS * 4) then
            self.lastAcceptedRequestBySender[knownSender] = nil
        end
    end

    local matches, truncated = self:BuildCurrentCharacterMatches(normalizedQuery, MAX_RESPONSE_ITEMS)
    for index = 1, #matches do
        local match = matches[index]
        self:SendCommMessage(RESPONSE_PREFIX, table.concat({
            "ITEM",
            PROTOCOL_VERSION,
            queryID,
            tostring(match.itemID or 0),
            tostring(match.count or 0),
            match.hyperlink or "",
        }, "\t"), "WHISPER", senderName)
    end

    if truncated then
        self:SendCommMessage(RESPONSE_PREFIX, table.concat({
            "META",
            PROTOCOL_VERSION,
            queryID,
            "TRUNCATED",
        }, "\t"), "WHISPER", senderName)
    end
end

-- Merge whisper responses into one visible result set for the current query only.
function GuildLookup:OnLookupResponseReceived(prefix, message, distribution, sender)
    if prefix ~= RESPONSE_PREFIX or distribution ~= "WHISPER" or not self.activeQueryID then
        return
    end

    local senderName = normalizeSenderName(sender)
    if not senderName or not self:IsKnownGuildMember(senderName) then
        return
    end

    local messageType, version, queryID, firstArg, secondArg, thirdArg = strsplit("\t", message, 6)
    if version ~= PROTOCOL_VERSION or queryID ~= self.activeQueryID then
        return
    end

    if messageType == "META" then
        if firstArg == "TRUNCATED" then
            self.state.truncated = true
            self.state.visible = true
            if self.state.status == "idle" then
                self.state.status = "results"
            end
            self:NotifyUpdated()
        end
        return
    end

    if messageType ~= "ITEM" then
        return
    end

    local itemID = tonumber(firstArg)
    local count = tonumber(secondArg)
    local hyperlink = thirdArg
    if not itemID or itemID <= 0 or not count or count <= 0 then
        return
    end

    local itemName = (type(hyperlink) == "string" and hyperlink ~= "" and hyperlink:match("%[(.-)%]")) or (GetItemInfo and GetItemInfo(itemID)) or buildFallbackItemName(itemID)
    local resultKey = string.format("%s|%d", senderName, itemID)
    local row = self.activeResultsByKey[resultKey]
    if not row then
        row = {
            key = resultKey,
            sender = senderName,
            itemID = itemID,
            itemName = itemName,
            hyperlink = hyperlink,
            iconFileID = getItemIconFileID(itemID),
            count = count,
        }
        self.activeResultsByKey[resultKey] = row
        self.state.results[#self.state.results + 1] = row
    else
        row.count = count
        row.itemName = itemName or row.itemName
        if type(hyperlink) == "string" and hyperlink ~= "" then
            row.hyperlink = hyperlink
        end
        row.iconFileID = row.iconFileID or getItemIconFileID(itemID)
    end

    self.state.visible = true
    self.state.status = "results"
    self.state.queryText = self.activeQueryText
    self.state.displayQueryText = self.activeDisplayQueryText
    self:SortResults()
    self:NotifyUpdated()
end
