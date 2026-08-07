# Bags Cleanup + New Items Category Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove verified dead code / duplication from the bags implementation and add a pinned, full-width "New Items" category showing items looted within the last hour, newest first.

**Architecture:** BagsStore owns a persisted per-character `newItems` map (`itemGUID → firstSeenAt`) ingested from `C_NewItems` during scans and applied as a *read-time overlay* — stored slot records, aggregates, and the account index never change. BagsWindow pins the `new` group first at full column span, excludes it from the layout editor, and drives glow + expiry re-render from the store map.

**Tech Stack:** WoW retail addon, Lua 5.1, Ace3 (AceAddon/AceEvent/AceDB). No automated test harness exists — the test cycle per task is `luac5.1 -p` syntax passes + grep assertions, with an in-game manual checklist at the end.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-06-bags-new-items-design.md` (approved).
- WoW Lua is 5.1: no `goto`, no `//` operator, use `wipe`/`strtrim` globals as the codebase does.
- Timeout constant: `NEW_ITEM_TIMEOUT_SECONDS = 3600` (exactly 1 hour).
- New category key is the string `"new"`, locale key `BAGS_CATEGORY_NEW`, order `0`.
- `schemaVersion` stays `6` — the `newItems` field is additive with defensive reads.
- All file paths relative to the addon root (`.../Interface/AddOns/vesperTools/`).
- Syntax check command for any touched Lua file: `luac5.1 -p <file>` → expected: no output, exit 0.
- Commit after every task; message style matches repo history (short imperative, no scopes required).

---

### Task 1: Hoist shared text helpers into vesperTools.lua

The bodies of `normalizeSearchText` (6 files) and `buildFallbackItemName` (6 files) are byte-identical (verified by md5 of the function blocks) and are only ever *called* — never passed as values (verified by grep). So: add shared methods, delete local copies, mechanically rewrite call sites.

**Files:**
- Modify: `vesperTools.lua` (add two methods near `NormalizePlayerFullName`, ~line 3803)
- Modify: `Modules/BagsStore.lua`, `Modules/BagsWindow.lua`, `Modules/BankStore.lua`, `Modules/BankWindow.lua`, `Modules/GuildLookup.lua`, `Modules/SearchOverlay.lua`, `Modules/ContainerItemSupport.lua`

**Interfaces:**
- Produces: `vesperTools:NormalizeSearchText(text) → string|nil` and `vesperTools:BuildFallbackItemName(itemID) → string`. Later tasks call these.

- [ ] **Step 1: Add the shared methods to `vesperTools.lua`**

Insert immediately above `function vesperTools:NormalizePlayerFullName(name)` (~line 3803):

```lua
-- Shared text helpers used by the bag/bank/search modules.
function vesperTools:NormalizeSearchText(text)
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

function vesperTools:BuildFallbackItemName(itemID)
    return string.format(L["ITEM_FALLBACK_FMT"], tostring(itemID))
end
```

(`L` is the file-local locale table assigned at `vesperTools.lua:12/36`.)

- [ ] **Step 2: Delete the local definitions**

In each module below, delete the whole `local function normalizeSearchText(text) ... end` and/or `local function buildFallbackItemName(itemID) ... end` blocks:

| File | delete `normalizeSearchText` (near line) | delete `buildFallbackItemName` (near line) |
|---|---|---|
| `Modules/BagsStore.lua` | 150 | 170 |
| `Modules/BagsWindow.lua` | 129 | 113 |
| `Modules/BankStore.lua` | 97 | 117 |
| `Modules/BankWindow.lua` | 74 | 70 |
| `Modules/GuildLookup.lua` | 51 | 93 |
| `Modules/SearchOverlay.lua` | 312 | — |
| `Modules/ContainerItemSupport.lua` | — | 11 |

- [ ] **Step 3: Rewrite the call sites mechanically**

```bash
cd "<addon root>"
sed -i 's/\bnormalizeSearchText(/vesperTools:NormalizeSearchText(/g; s/\bbuildFallbackItemName(/vesperTools:BuildFallbackItemName(/g' \
  Modules/BagsStore.lua Modules/BagsWindow.lua Modules/BankStore.lua \
  Modules/BankWindow.lua Modules/GuildLookup.lua Modules/SearchOverlay.lua \
  Modules/ContainerItemSupport.lua
```

- [ ] **Step 4: Verify no leftovers and syntax passes**

```bash
grep -rn "normalizeSearchText\|buildFallbackItemName" Modules/ vesperTools.lua
```
Expected: **zero matches** (the shared methods use capitalized names).

```bash
for f in vesperTools.lua Modules/BagsStore.lua Modules/BagsWindow.lua Modules/BankStore.lua Modules/BankWindow.lua Modules/GuildLookup.lua Modules/SearchOverlay.lua Modules/ContainerItemSupport.lua; do luac5.1 -p "$f" || echo "FAIL $f"; done
```
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor: hoist normalizeSearchText/buildFallbackItemName into shared vesperTools helpers"
```

---

### Task 2: Dead-code cleanup in BagsWindow + BankWindow

**Files:**
- Modify: `Modules/BagsWindow.lua` (dead overlay fn ~156–208; `maxItemCount` at 2564–2586, 2773, 4163–4165; `CleanupLegacyScrollArtifacts` calls at 453 and 4067)
- Modify: `Modules/BankWindow.lua` (dead overlay fn ~94)

**Interfaces:**
- Produces: `BagsWindow:BuildLayoutGroups(store, characterKey, categories, viewSettings) → groups` (single return) and `BagsWindow:ResolveAutoLayout(groups, viewSettings, currencyEntries)` (3 params). Task 5 edits these functions further and relies on these signatures.

- [ ] **Step 1: Delete dead `suppressNativeOverlayVisuals` copies**

Delete the entire `local function suppressNativeOverlayVisuals(overlay) ... end` block in `Modules/BagsWindow.lua` (~lines 156–208) and the identical block in `Modules/BankWindow.lua` (~line 94). The live copy in `Modules/ContainerItemSupport.lua` stays. Verify each file no longer mentions it:

```bash
grep -n "suppressNativeOverlayVisuals" Modules/BagsWindow.lua Modules/BankWindow.lua
```
Expected: zero matches.

- [ ] **Step 2: Remove the unused `maxItemCount` threading**

Replace `BagsWindow:BuildLayoutGroups` (currently ~2564–2586) with:

```lua
function BagsWindow:BuildLayoutGroups(store, characterKey, categories, viewSettings)
    local groups = {}

    for i = 1, #categories do
        local category = categories[i]
        local items = store:GetCharacterCategoryItems(characterKey, category.key)
        if #items > 0 then
            groups[#groups + 1] = {
                category = category,
                items = self:BuildDisplayItems(items, viewSettings),
                hidden = self:IsCategoryCollapsed(characterKey, category.key),
            }
        end
    end

    return groups
end
```

Change the signature at ~2773 from
`function BagsWindow:ResolveAutoLayout(groups, maxItemCount, viewSettings, currencyEntries)` to
`function BagsWindow:ResolveAutoLayout(groups, viewSettings, currencyEntries)` (body unchanged — it never used `maxItemCount`).

In `RefreshWindow` (~4163–4165) replace:

```lua
    local groups, maxItemCount = self:BuildLayoutGroups(store, selectedCharacter.key, categories, viewSettings)
    local currencyEntries = self:GetCurrencyBarEntries(selectedCharacter)
    local layout = self:ResolveAutoLayout(groups, maxItemCount, viewSettings, currencyEntries)
```
with:
```lua
    local groups = self:BuildLayoutGroups(store, selectedCharacter.key, categories, viewSettings)
    local currencyEntries = self:GetCurrencyBarEntries(selectedCharacter)
    local layout = self:ResolveAutoLayout(groups, viewSettings, currencyEntries)
```

- [ ] **Step 3: Run `CleanupLegacyScrollArtifacts` once**

Delete the `self:CleanupLegacyScrollArtifacts()` call lines in `ShowWindow` (~453) and at the top of `RefreshWindow` (~4067). Keep the call at the end of `CreateWindow` (~2561) and keep the function definition.

- [ ] **Step 4: Verify**

```bash
grep -n "maxItemCount" Modules/BagsWindow.lua           # expected: zero matches
grep -c "CleanupLegacyScrollArtifacts" Modules/BagsWindow.lua   # expected: 2 (definition + CreateWindow call)
luac5.1 -p Modules/BagsWindow.lua Modules/BankWindow.lua
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor: remove dead code in bags/bank windows (overlay fn, maxItemCount, repeated legacy cleanup)"
```

---

### Task 3: Dead-code cleanup in BagsStore + BagsBridge

**Files:**
- Modify: `Modules/BagsStore.lua` (expansion remnants: lines ~258–265, 280–292, 500–523, ~1658)
- Modify: `Modules/BagsBridge.lua` (`ResolvePreferredBankViewKey` ~613–640; session-hide unify ~666–695 and callers)

- [ ] **Step 1: Remove expansion-category remnants in BagsStore**

Delete `local function getExpansionCategoryKey(expansionID) ... end` (~258–265) and `local function getExpansionDisplayName(expansionID) ... end` (~280–292). Keep `EXPANSION_CATEGORY_KEY_PREFIX`, `getExpansionIDFromCategoryKey`, and `canonicalizeCategoryKey` — they migrate legacy `expansion:N` keys in saved data.

In `ResolveCategoryKey` (~971–979), replace `return getExpansionCategoryKey(expansionID)` with `return PAST_EXPANSIONS_CATEGORY_KEY`.

Replace `GetCategoryDisplayName` and `GetCategoryOrder` (~500–523) with:

```lua
function BagsStore:GetCategoryDisplayName(categoryKey)
    categoryKey = canonicalizeCategoryKey(categoryKey)
    local labelKey = CATEGORY_LABEL_KEY_BY_ID[categoryKey]
    if labelKey then
        return L[labelKey]
    end

    return L["BAGS_CATEGORY_MISC"]
end

function BagsStore:GetCategoryOrder(categoryKey)
    categoryKey = canonicalizeCategoryKey(categoryKey)
    return CATEGORY_PRIORITY_BY_ID[categoryKey] or 999
end
```

In `GetCharacterCategoryList` (~1650–1660), delete the line `expansionID = getExpansionIDFromCategoryKey(categoryKey),` from the entry constructor (the field is always nil after canonicalization; nothing reads it).

- [ ] **Step 2: Simplify `ResolvePreferredBankViewKey` in BagsBridge**

Replace the function body tail (~613–640) so the whole function reads:

```lua
function BagsBridge:ResolvePreferredBankViewKey()
    local store = self:GetLiveBankStore()
    if not store then
        return nil
    end

    local characterIsLive = type(store.IsCharacterBankLive) == "function" and store:IsCharacterBankLive() or false
    local warbandIsLive = type(store.IsWarbandBankLive) == "function" and store:IsWarbandBankLive() or false

    if characterIsLive then
        return "character"
    end

    if warbandIsLive then
        return "warband"
    end

    return nil
end
```

(The three prior warband branches were mutually redundant; `interactionType` becomes unused and is removed.)

- [ ] **Step 3: Unify the two session-hide methods in BagsBridge**

Replace both `HideBagsOpenedForMerchantSession` (~666–679) and `HideBagsOpenedForBankSession` (~681–695) with:

```lua
-- Close only the bags that were auto-opened by the given session type.
function BagsBridge:HideBagsOpenedForSession(openedFlagKey)
    if not self[openedFlagKey] then
        return
    end

    self[openedFlagKey] = false

    local BagsWindow = vesperTools:GetModule("BagsWindow", true)
    if not BagsWindow or not BagsWindow.frame or not BagsWindow.frame:IsShown() then
        return
    end

    BagsWindow.frame:Hide()
end
```

Update the two callers:
- in `HandleBankSessionClosed`: `self:HideBagsOpenedForBankSession()` → `self:HideBagsOpenedForSession("bankSessionOpenedBags")`
- in `HandleMerchantSessionClosed`: `self:HideBagsOpenedForMerchantSession()` → `self:HideBagsOpenedForSession("merchantSessionOpenedBags")`

- [ ] **Step 4: Verify**

```bash
grep -n "getExpansionCategoryKey\|getExpansionDisplayName" Modules/BagsStore.lua   # expected: zero
grep -n "HideBagsOpenedForMerchantSession\|HideBagsOpenedForBankSession" Modules/BagsBridge.lua  # expected: zero
luac5.1 -p Modules/BagsStore.lua Modules/BagsBridge.lua
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor: drop expansion-category remnants and redundant BagsBridge branches"
```

---

### Task 4: BagsStore — new-item tracking, overlay read APIs, login-noise fix

**Files:**
- Modify: `Modules/BagsStore.lua`

**Interfaces:**
- Produces (Task 5 depends on these exact names):
  - `BagsStore:IsNewItemGUID(characterKey, itemGUID) → boolean`
  - `BagsStore:GetNextNewItemExpiry(characterKey) → epochSeconds|nil`
  - `BagsStore:HasActiveNewItems(characterKey) → boolean`
  - `BagsStore:ClearNewItems(characterKey) → boolean` (wipes map + broadcasts `VESPERTOOLS_BAGS_SNAPSHOT_UPDATED`)
  - `GetCharacterCategoryList` now returns a `{ key = "new", order = 0, ... }` entry first when active new items exist; `GetCharacterCategoryItems(characterKey, "new")` returns those records newest-first; natural categories exclude them.

- [ ] **Step 1: Add constants and the category def**

Below `CURRENT_BAGS_SCHEMA_VERSION` (~line 8) add:

```lua
local NEW_CATEGORY_KEY = "new"
local NEW_ITEM_TIMEOUT_SECONDS = 3600
```

Add as the FIRST entry of `BAG_CATEGORY_DEFS` (line ~10):

```lua
    { key = "new", labelKey = "BAGS_CATEGORY_NEW", order = 0 },
```

(`ResolveCategoryKey` never returns `"new"`, so stored records/aggregates are unaffected; the def only feeds label/order lookups.)

- [ ] **Step 2: Ensure the map exists on the character record**

In `CreateOrUpdateCurrentCharacter` (~562–594), after `character.carried.categoryItems = ...` add:

```lua
    character.newItems = character.newItems or {}
```

- [ ] **Step 3: Add tracking helpers (place after `GetCharacterEmptySlotSummary`, before `GetDisplayCharacters`)**

```lua
-- New-item overlay: BagsStore stamps recently looted item GUIDs and serves the
-- transient "new" category without ever writing it into stored slot records.
function BagsStore:GetNewItemsMap(character, create)
    if type(character) ~= "table" then
        return nil
    end
    if create and type(character.newItems) ~= "table" then
        character.newItems = {}
    end
    return type(character.newItems) == "table" and character.newItems or nil
end

function BagsStore:IsNewItemEntryActive(firstSeenAt, now)
    local seenAt = tonumber(firstSeenAt)
    if not seenAt then
        return false
    end
    return ((now or time()) - seenAt) < NEW_ITEM_TIMEOUT_SECONDS
end

-- Stamp newly looted item GUIDs and drop stale/departed entries after a scan commit.
function BagsStore:UpdateNewItemTracking(character)
    local carried = type(character) == "table" and character.carried or nil
    local bags = type(carried) == "table" and carried.bags or nil
    if type(bags) ~= "table" then
        return
    end

    local newItems = self:GetNewItemsMap(character, true)
    if not newItems then
        return
    end

    local now = time()
    local presentGUIDs = {}
    local canQueryLiveMarkers = C_NewItems and type(C_NewItems.IsNewItem) == "function"

    for i = 1, #TRACKED_BAG_IDS do
        local bag = bags[TRACKED_BAG_IDS[i]]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemGUID then
                    presentGUIDs[record.itemGUID] = true
                    if canQueryLiveMarkers and newItems[record.itemGUID] == nil then
                        local ok, isNewItem = pcall(C_NewItems.IsNewItem, record.bagID, record.slotID)
                        if ok and isNewItem then
                            newItems[record.itemGUID] = now
                        end
                    end
                end
            end
        end
    end

    for itemGUID, firstSeenAt in pairs(newItems) do
        if not presentGUIDs[itemGUID] or not self:IsNewItemEntryActive(firstSeenAt, now) then
            newItems[itemGUID] = nil
        end
    end
end

function BagsStore:IsNewItemGUID(characterKey, itemGUID)
    if not itemGUID then
        return false
    end

    local newItems = self:GetNewItemsMap(self:GetCharacterBagSnapshot(characterKey), false)
    if not newItems then
        return false
    end

    return self:IsNewItemEntryActive(newItems[itemGUID])
end

function BagsStore:GetNextNewItemExpiry(characterKey)
    local newItems = self:GetNewItemsMap(self:GetCharacterBagSnapshot(characterKey), false)
    if not newItems then
        return nil
    end

    local now = time()
    local earliestSeenAt = nil
    for _, firstSeenAt in pairs(newItems) do
        if self:IsNewItemEntryActive(firstSeenAt, now) then
            local seenAt = tonumber(firstSeenAt)
            if not earliestSeenAt or seenAt < earliestSeenAt then
                earliestSeenAt = seenAt
            end
        end
    end

    if not earliestSeenAt then
        return nil
    end

    return earliestSeenAt + NEW_ITEM_TIMEOUT_SECONDS
end

function BagsStore:HasActiveNewItems(characterKey)
    return self:GetNextNewItemExpiry(characterKey) ~= nil
end

function BagsStore:ClearNewItems(characterKey)
    local character = self:GetCharacterBagSnapshot(characterKey)
    if not character then
        return false
    end

    local newItems = self:GetNewItemsMap(character, false)
    if newItems and next(newItems) then
        wipe(newItems)
    end

    vesperTools:SendMessage("VESPERTOOLS_BAGS_SNAPSHOT_UPDATED", characterKey)
    return true
end
```

- [ ] **Step 4: Ingest during scan commits**

In `DoFullCarryRescan` (~1435–1444), after `character.lastSeen = time()` and before `self:RebuildAccountIndex()`, add:

```lua
    self:UpdateNewItemTracking(character)
```

In `CommitPendingBagWork` (~1447–1512), in the `changed` path — after `character.currency = newCurrencySnapshot` / `character.lastSeen = time()` and before `self:RebuildAccountIndex()` — add:

```lua
    self:UpdateNewItemTracking(character)
```

- [ ] **Step 5: Login-noise fix**

Replace `BagsStore:PLAYER_ENTERING_WORLD` (~1373–1382) with:

```lua
-- Login performs a deferred full scan so bag APIs are ready before reading them.
-- On a fresh login the client marks whole bags as "new"; clear that noise
-- BEFORE the first scan so it never enters the new-item overlay map.
function BagsStore:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUI)
    self.pendingInitialScan = true
    local shouldClearLoginMarkers = isInitialLogin and not isReloadingUI
    C_Timer.After(0, function()
        if not self:IsEnabled() then
            return
        end
        if shouldClearLoginMarkers and C_NewItems and C_NewItems.ClearAll then
            pcall(C_NewItems.ClearAll)
        end
        self:MarkFullCarryRescan("initial")
        self:CommitPendingBagWork()
    end)
end
```

- [ ] **Step 6: Apply the overlay in `GetCharacterCategoryItems` (~1575–1610)**

Replace the whole function with:

```lua
function BagsStore:GetCharacterCategoryItems(characterKey, categoryKey)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    if not snapshot or not snapshot.carried or not snapshot.carried.bags then
        return {}
    end

    local newItems = self:GetNewItemsMap(snapshot, false)
    local now = time()
    local wantsNewCategory = categoryKey == NEW_CATEGORY_KEY
    local targetCategoryKey = canonicalizeCategoryKey(categoryKey)
    local items = {}

    for i = 1, #TRACKED_BAG_IDS do
        local bagID = TRACKED_BAG_IDS[i]
        local bag = snapshot.carried.bags[bagID]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" then
                    local isNewRecord = newItems ~= nil
                        and record.itemGUID ~= nil
                        and self:IsNewItemEntryActive(newItems[record.itemGUID], now)

                    if wantsNewCategory then
                        if isNewRecord then
                            items[#items + 1] = record
                        end
                    elseif not isNewRecord and canonicalizeCategoryKey(record.categoryKey) == targetCategoryKey then
                        items[#items + 1] = record
                    end
                end
            end
        end
    end

    table.sort(items, function(a, b)
        if wantsNewCategory then
            local aSeenAt = tonumber(newItems and newItems[a.itemGUID]) or 0
            local bSeenAt = tonumber(newItems and newItems[b.itemGUID]) or 0
            if aSeenAt ~= bSeenAt then
                return aSeenAt > bSeenAt
            end
        end
        if a.sortKey ~= b.sortKey then
            return a.sortKey < b.sortKey
        end
        if a.itemID ~= b.itemID then
            return a.itemID < b.itemID
        end
        if a.bagID ~= b.bagID then
            return a.bagID < b.bagID
        end
        return a.slotID < b.slotID
    end)

    return items
end
```

- [ ] **Step 7: Apply the overlay in `GetCharacterCategoryList` (~1635–1676)**

After the existing `mergedCounts` loop and before the `categories` array is built, insert:

```lua
    -- Pull active new items out of their natural categories into the pinned
    -- "new" overlay category.
    local newItems = self:GetNewItemsMap(snapshot, false)
    if newItems and next(newItems) and type(snapshot.carried.bags) == "table" then
        local now = time()
        for i = 1, #TRACKED_BAG_IDS do
            local bag = snapshot.carried.bags[TRACKED_BAG_IDS[i]]
            if type(bag) == "table" and type(bag.slots) == "table" then
                for slotID = 1, tonumber(bag.size) or 0 do
                    local record = bag.slots[slotID]
                    if type(record) == "table" and record.itemGUID
                        and self:IsNewItemEntryActive(newItems[record.itemGUID], now)
                    then
                        local count = math.max(1, tonumber(record.stackCount) or 1)
                        self:AdjustCount(mergedCounts, canonicalizeCategoryKey(record.categoryKey), -count)
                        self:AdjustCount(mergedCounts, NEW_CATEGORY_KEY, count)
                    end
                end
            end
        end
    end
```

(The rest of the function — building/sorting `categories` — is unchanged; `"new"` picks up label `L["BAGS_CATEGORY_NEW"]` and order `0` from the def added in Step 1.)

- [ ] **Step 8: Verify**

```bash
luac5.1 -p Modules/BagsStore.lua
grep -c "UpdateNewItemTracking" Modules/BagsStore.lua   # expected: 3 (definition + 2 call sites)
```

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat: BagsStore new-item tracking with 1h timeout and read-time category overlay"
```

---

### Task 5: BagsWindow — pinned New Items section, glow, expiry timer, cleanup button

**Files:**
- Modify: `Modules/BagsWindow.lua`

**Interfaces:**
- Consumes from Task 4: `store:IsNewItemGUID(characterKey, itemGUID)`, `store:GetNextNewItemExpiry(characterKey)`, `store:HasActiveNewItems(characterKey)`, `store:ClearNewItems(characterKey)`.
- Consumes from Task 2: `BuildLayoutGroups` single return, `ResolveAutoLayout(groups, viewSettings, currencyEntries)`.

- [ ] **Step 1: Remove the login handler (moved to BagsStore in Task 4)**

In `OnEnable`, delete the line `self:RegisterEvent("PLAYER_ENTERING_WORLD")`. Delete the whole `BagsWindow:PLAYER_ENTERING_WORLD` function (~390–400). In `OnInitialize`, add `self.newItemExpiryTimer = nil` after `self.pendingSecureItemRefresh = false`.

- [ ] **Step 2: Rework glow to use the store overlay**

Replace `BagsWindow:IsNewItem` and keep `ShouldShowNewItemGlow`'s dedup logic, switching both to a `characterKey` parameter (~3979–4019):

```lua
function BagsWindow:IsNewItem(record, characterKey)
    if type(record) ~= "table" then
        return false
    end

    if type(record.combinedRecords) == "table" then
        for i = 1, #record.combinedRecords do
            if self:IsNewItem(record.combinedRecords[i], characterKey) then
                return true
            end
        end
        return false
    end

    local store = self:GetStore()
    if not store or type(store.IsNewItemGUID) ~= "function" then
        return false
    end

    return store:IsNewItemGUID(characterKey, record.itemGUID)
end

function BagsWindow:ShouldShowNewItemGlow(record, characterKey)
    if not self:IsNewItem(record, characterKey) then
        return false
    end

    local glowKey = self:GetCombineRecordKey(record)
    if not glowKey then
        glowKey = string.format("slot:%s:%s", tostring(record and record.bagID or 0), tostring(record and record.slotID or 0))
    end

    self.newItemGlowKeysSeen = self.newItemGlowKeysSeen or {}
    if self.newItemGlowKeysSeen[glowKey] then
        return false
    end

    self.newItemGlowKeysSeen[glowKey] = true
    return true
end
```

In `GetItemInteraction`'s `afterConfigureButton` (~334–352), replace:

```lua
        afterConfigureButton = function(window, button, record, context)
            local isCurrentCharacter = context and context.isCurrentCharacter and true or false

            if window:ShouldShowNewItemGlow(record, isCurrentCharacter) then
```
with:
```lua
        afterConfigureButton = function(window, button, record, context)
            if window:ShouldShowNewItemGlow(record, context and context.characterKey or nil) then
```

- [ ] **Step 3: Rework the Cleanup button for any selected character**

Replace `CanClearNewItemsForSelectedCharacter` and `ClearNewItemMarkers` (~1752–1809); `CanClearCurrentCharacterNewItems` and `ClearCurrentCharacterNewItemMarkers` stay as-is:

```lua
function BagsWindow:CanClearNewItemsForSelectedCharacter()
    local store = self:GetStore()
    if not store then
        return false
    end

    if type(store.HasActiveNewItems) == "function" and store:HasActiveNewItems(self.selectedCharacterKey) then
        return true
    end

    local currentCharacterKey = store.GetCurrentCharacterKey and store:GetCurrentCharacterKey() or nil
    return currentCharacterKey ~= nil
        and currentCharacterKey == self.selectedCharacterKey
        and self:CanClearCurrentCharacterNewItems()
end

function BagsWindow:ClearNewItemMarkers()
    local store = self:GetStore()
    if not store then
        return
    end

    local currentCharacterKey = store.GetCurrentCharacterKey and store:GetCurrentCharacterKey() or nil
    if currentCharacterKey and currentCharacterKey == self.selectedCharacterKey then
        self:ClearCurrentCharacterNewItemMarkers(false)
    end

    if type(store.ClearNewItems) == "function" then
        store:ClearNewItems(self.selectedCharacterKey)
    end
end
```

(`store:ClearNewItems` broadcasts the snapshot message, which triggers `OnBagDataChanged → RefreshWindow` for the open window.)

In `RefreshWindow`, change `self:UpdateCleanupButtonVisual(selectedCharacter.isCurrent)` to `self:UpdateCleanupButtonVisual(self:CanClearNewItemsForSelectedCharacter())`.

- [ ] **Step 4: Pin the `new` group first at full span, exclude it from the layout editor**

In `PrepareLayoutGroups` (~2648–2684), replace the first per-group loop and add span forcing after the final clamp loop, so the function reads:

```lua
function BagsWindow:PrepareLayoutGroups(groups, columns, viewSettings)
    if type(groups) ~= "table" or #groups == 0 then
        return groups or {}
    end

    for i = 1, #groups do
        local group = groups[i]
        group.sourceOrder = i
        group.isPinnedNewSection = group.category and group.category.key == "new" or false

        local layoutEntry = nil
        if not group.isPinnedNewSection and group.category then
            layoutEntry = self:GetCategoryLayoutEntry(group.category.key, false)
        end

        local minimumSpan = self:GetMinimumSectionSpan(group, columns, viewSettings)
        group.minSpan = minimumSpan
        group.defaultSpan = self:GetDefaultSectionSpan(group, columns, viewSettings, minimumSpan)

        local savedOrder = layoutEntry and math.floor((tonumber(layoutEntry.order) or 0) + 0.5) or nil
        local savedSpan = layoutEntry and math.floor((tonumber(layoutEntry.span) or 0) + 0.5) or nil
        group.layoutOrder = savedOrder and savedOrder > 0 and savedOrder or nil
        group.savedSpan = savedSpan and savedSpan > 0 and savedSpan or nil

        if group.isPinnedNewSection then
            group.layoutOrder = -1
        end
    end

    table.sort(groups, function(a, b)
        local aOrder = a.layoutOrder or (100000 + (a.sourceOrder or 0))
        local bOrder = b.layoutOrder or (100000 + (b.sourceOrder or 0))
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end

        return (a.sourceOrder or 0) < (b.sourceOrder or 0)
    end)

    for i = 1, #groups do
        local group = groups[i]
        group.span = clamp(group.savedSpan or group.defaultSpan or 1, group.minSpan or 1, math.max(1, columns or 1))
        if group.isPinnedNewSection then
            group.span = math.max(1, columns or 1)
        end
    end

    return groups
end
```

(Full span means the next section always wraps to a new row in `BuildSectionLayout` — nothing renders beside New Items.)

- [ ] **Step 5: Exclude `new` from dragging and persistence**

In `StartCategoryDrag` (~3074), change the guard to:

```lua
    if not self.layoutEditMode or type(categoryKey) ~= "string" or categoryKey == "" or categoryKey == "new" then
        return
    end
```

In `RefreshWindow`'s section loop (~4232–4235), replace:

```lua
            if section.dragOverlay then
                section.dragOverlay:EnableMouse(self.layoutEditMode)
                section.dragOverlay:SetShown(self.layoutEditMode)
            end
```
with:
```lua
            if section.dragOverlay then
                local dragEnabled = self.layoutEditMode and category.key ~= "new"
                section.dragOverlay:EnableMouse(dragEnabled)
                section.dragOverlay:SetShown(dragEnabled)
            end
```

In `BuildBestLayoutDropCandidate` (~3001–3050), keep the pinned section fixed at the top while other categories are dragged. Replace the group-partitioning block and candidate loop with:

```lua
    local draggedGroup = nil
    local pinnedGroups = {}
    local baseGroups = {}
    for i = 1, #groups do
        local group = groups[i]
        if group.category and group.category.key == dragState.categoryKey then
            draggedGroup = self:CloneLayoutGroup(group)
        elseif group.isPinnedNewSection then
            pinnedGroups[#pinnedGroups + 1] = self:CloneLayoutGroup(group)
        else
            baseGroups[#baseGroups + 1] = self:CloneLayoutGroup(group)
        end
    end

    if not draggedGroup then
        return nil
    end

    local minimumSpan = math.max(1, draggedGroup.minSpan or 1)
    local bestCandidate = nil
    local bestScore = nil

    for insertIndex = 1, (#baseGroups + 1) do
        for span = minimumSpan, columns do
            local candidateGroups = self:BuildCandidateGroupList(baseGroups, draggedGroup, insertIndex, span)
            for pinnedIndex = #pinnedGroups, 1, -1 do
                table.insert(candidateGroups, 1, pinnedGroups[pinnedIndex])
            end
            local sectionLayout, sectionsHeight = self:BuildSectionLayout(candidateGroups, self.currentContentWidth, columns, viewSettings)
            local placement = sectionLayout[#pinnedGroups + insertIndex]
            local score = self:GetLayoutCandidateScore(placement, cursorX, cursorY)
            if not bestScore or score < bestScore then
                bestScore = score
                bestCandidate = {
                    groups = candidateGroups,
                    placement = placement,
                    sectionsHeight = sectionsHeight,
                    span = span,
                    insertIndex = insertIndex,
                    columns = columns,
                }
            end
        end
    end

    return bestCandidate
```

In `ApplyCategoryLayoutCandidate` (~3052–3072), skip persisting the pinned section — change the inner condition to:

```lua
        if group and not group.isPinnedNewSection and group.category and group.category.key then
```

- [ ] **Step 6: Expiry re-render timer**

Add after `ClearNewItemMarkers`:

```lua
function BagsWindow:CancelNewItemExpiryTimer()
    if self.newItemExpiryTimer then
        self.newItemExpiryTimer:Cancel()
        self.newItemExpiryTimer = nil
    end
end

-- Re-render once the oldest active new item crosses the timeout so it slides
-- back into its natural category while the window is open.
function BagsWindow:ScheduleNewItemExpiryRefresh(characterKey)
    self:CancelNewItemExpiryTimer()

    local store = self:GetStore()
    local expiresAt = store and type(store.GetNextNewItemExpiry) == "function"
        and store:GetNextNewItemExpiry(characterKey) or nil
    if not expiresAt then
        return
    end

    local delay = math.max(1, (expiresAt - time()) + 1)
    self.newItemExpiryTimer = C_Timer.NewTimer(delay, function()
        self.newItemExpiryTimer = nil
        if self:IsEnabled() and self.frame and self.frame:IsShown() then
            self:RefreshWindow()
        end
    end)
end
```

Wire it up:
- Top of `RefreshWindow` (right after the `if not self.frame then return end` guard): add `self:CancelNewItemExpiryTimer()`.
- Very end of `RefreshWindow` (after `self:RefreshGuildLookupPresentation()`): add `self:ScheduleNewItemExpiryRefresh(selectedCharacter.key)`.
- In the frame's `OnHide` script inside `CreateWindow` (~2550–2558), add `self:CancelNewItemExpiryTimer()` as the first line of the handler body.

- [ ] **Step 7: Verify**

```bash
luac5.1 -p Modules/BagsWindow.lua
grep -n "PLAYER_ENTERING_WORLD" Modules/BagsWindow.lua        # expected: zero matches
grep -c "isPinnedNewSection" Modules/BagsWindow.lua            # expected: >= 4
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: pinned full-width New Items section in bags window"
```

---

### Task 6: Locales

**Files:**
- Modify: all 12 locale files: `Locales/enUS.lua`, `enGB.lua`, `deDE.lua`, `esES.lua`, `esMX.lua`, `frFR.lua`, `itIT.lua`, `koKR.lua`, `ptBR.lua`, `ruRU.lua`, `zhCN.lua`, `zhTW.lua`

- [ ] **Step 1: Add `BAGS_CATEGORY_NEW`**

In each file, insert a new line directly after the `BAGS_CATEGORY_MISC = ...` line (keys are kept alphabetical):

| File | Line to insert |
|---|---|
| enUS.lua, enGB.lua | `    BAGS_CATEGORY_NEW = "New Items",` |
| deDE.lua | `    BAGS_CATEGORY_NEW = "Neue Gegenstände",` |
| esES.lua, esMX.lua | `    BAGS_CATEGORY_NEW = "Objetos nuevos",` |
| frFR.lua | `    BAGS_CATEGORY_NEW = "Nouveaux objets",` |
| itIT.lua | `    BAGS_CATEGORY_NEW = "Oggetti nuovi",` |
| koKR.lua | `    BAGS_CATEGORY_NEW = "새로운 아이템",` |
| ptBR.lua | `    BAGS_CATEGORY_NEW = "Itens novos",` |
| ruRU.lua | `    BAGS_CATEGORY_NEW = "Новые предметы",` |
| zhCN.lua | `    BAGS_CATEGORY_NEW = "新物品",` |
| zhTW.lua | `    BAGS_CATEGORY_NEW = "新物品",` |

- [ ] **Step 2: Verify**

```bash
grep -l "BAGS_CATEGORY_NEW" Locales/*.lua | wc -l    # expected: 12
for f in Locales/*.lua; do luac5.1 -p "$f" || echo "FAIL $f"; done   # expected: no FAIL
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: BAGS_CATEGORY_NEW locale strings"
```

---

### Task 7: Version bump, changelog, final verification

**Files:**
- Modify: `vesperTools.toc` (`## Version: 6.9.0` → `## Version: 6.10.0`)
- Modify: `CHANGELOG.md` (prepend entry matching the existing format — inspect the top of the file first)

- [ ] **Step 1: Bump version and add changelog entry**

Set `## Version: 6.10.0` in `vesperTools.toc`. Prepend a `6.10.0` entry to `CHANGELOG.md` in the file's existing style covering: New Items category (top row, 1h timeout, newest first, Cleanup clears it), bags dead-code/duplication cleanup.

- [ ] **Step 2: Full syntax sweep**

```bash
find . -name "*.lua" -not -path "./Libs/*" -exec luac5.1 -p {} \; 2>&1 | head   # expected: no output
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "6.10.0 bags New Items category + bags cleanup"
```

---

## In-game manual verification checklist (after all tasks)

1. `/reload` — no Lua errors on load; bags window opens (keybind + bag button).
2. Loot any item → it appears at the top under "New Items (n)" on its own full-width row; nothing renders beside it; everything else lays out below.
3. Loot a second item → it appears *before* the first (newest first). Its natural category count excludes it.
4. Glow animates on New Items entries; search dims non-matching entries inside the section.
5. Collapse toggle on New Items works and persists per character.
6. Layout edit mode: New Items has no drag overlay; dragging another category never places it above New Items; Shift-right-click reset leaves New Items pinned.
7. Cleanup button: enabled while new items exist; pressing it returns items to natural categories (also on a viewed alt with active entries).
8. Combine Stacks on: a new stack and an old stack of the same item show in their respective sections (accepted quirk).
9. Wait past the timeout (or temporarily set `NEW_ITEM_TIMEOUT_SECONDS = 60` locally) with the window open → the section empties/removes itself without interaction.
10. Vendor + bank flows still auto-open/close bags correctly (BagsBridge changes); bank deposit right-click still routes to the selected bank view.
11. Character dropdown search match counts still render; guild lookup panel still opens.
