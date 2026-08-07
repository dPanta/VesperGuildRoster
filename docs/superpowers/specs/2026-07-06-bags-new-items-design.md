# Bags cleanup + "New Items" category — design

Date: 2026-07-06
Status: approved

## Goals

1. Clean up verified dead code and cross-module duplication in the bags implementation.
2. Add a "New Items" category pinned to the top of the bags window, on its own full-width
   row, showing recently looted items. Items live **only** there while new, return to their
   natural category on manual clear or after a 1-hour timeout, and sort newest-first.

Out of scope: splitting BagsWindow.lua into multiple files, localizing the English-only
season/legacy tooltip markers (documented as a known limitation), bank window changes.

## Part 1 — Cleanups

1. Delete dead local `suppressNativeOverlayVisuals` copies in `Modules/BagsWindow.lua`
   (~line 156) and `Modules/BankWindow.lua` (~line 94). The live copy stays in
   `Modules/ContainerItemSupport.lua`.
2. Drop the unused `maxItemCount` return/parameter threading between
   `BagsWindow:BuildLayoutGroups` and `BagsWindow:ResolveAutoLayout`.
3. Remove the dead `record.isNewItem` fallback in `BagsWindow:IsNewItem` (superseded by
   the New Items overlay below).
4. Remove expansion-category remnants in `Modules/BagsStore.lua`: `getExpansionCategoryKey`
   (always returns `past_expansions`) and the always-nil `expansionID` field in
   `GetCharacterCategoryList` entries. Keep `canonicalizeCategoryKey` and
   `getExpansionIDFromCategoryKey` only where needed to migrate legacy `expansion:N` keys.
5. Simplify the tail of `BagsBridge:ResolvePreferredBankViewKey` to a single
   `if warbandIsLive then return "warband" end`.
6. Call `CleanupLegacyScrollArtifacts` once from `CreateWindow` instead of on every
   refresh/show.
7. Hoist duplicated helpers into shared `vesperTools:` methods defined in
   `vesperTools.lua` (loads before all Modules per the TOC):
   - `vesperTools:NormalizeSearchText(text)` (local copies currently in BagsStore,
     BagsWindow, BankStore, BankWindow, GuildLookup, SearchOverlay)
   - `vesperTools:BuildFallbackItemName(itemID)` (those plus ContainerItemSupport)
   All call sites switch to the shared versions; local copies deleted. The
   `suppressNativeOverlayVisuals` copy in ContainerItemSupport stays local — it is the
   only live user.
8. Unify `BagsBridge:HideBagsOpenedForMerchantSession` / `HideBagsOpenedForBankSession`
   into one parameterized helper.

## Part 2 — New Items category

### Data model (BagsStore owns it)

- Per-character persisted map in the bags DB:
  `character.newItems = { [itemGUID] = firstSeenAt (epoch seconds) }`.
- Timeout constant `NEW_ITEM_TIMEOUT_SECONDS = 3600` in BagsStore.
- Ingestion: during bag scans (`BuildSlotRecord` path), when
  `C_NewItems.IsNewItem(bagID, slotID)` is true and the slot's itemGUID is not yet in the
  map, stamp it with `time()`. Records without a resolvable itemGUID are never "new".
- Pruning: after each scan commit, drop entries whose GUID no longer exists in the carried
  snapshot or whose age exceeds the timeout.
- No schema migration: additive field, defensive reads, `schemaVersion` stays 6.

### Read-time overlay (never stored in slot records)

- Slot records keep their natural `categoryKey`; the account index, aggregates, and guild
  lookup are untouched.
- New synthetic category def `{ key = "new", labelKey = "BAGS_CATEGORY_NEW", order = 0 }`.
- Store read APIs apply the overlay for a character view: items with an active (unexpired)
  `newItems` entry are excluded from their natural category and returned under `new`,
  sorted by `firstSeenAt` descending (ties: name, then bag/slot). Natural category counts
  shrink accordingly. The overlay applies to whichever character is being viewed (alts
  included — their entries expire by wall clock).

### Login-noise race fix

- The initial-login `C_NewItems` marker clear currently in
  `BagsWindow:PLAYER_ENTERING_WORLD` moves into `BagsStore:PLAYER_ENTERING_WORLD`, running
  synchronously before `MarkFullCarryRescan`/`CommitPendingBagWork` so spurious login
  flags never enter the map. Persisted timestamps from earlier sessions stay valid until
  expiry (newness survives /reload and relog within the hour).

### Window behavior (BagsWindow)

- The `new` group is pinned first and its span is forced to the full column count, so it
  always occupies its own row with no category beside it; all other categories flow below.
- Excluded from the layout editor: not draggable, never gets a saved order/span entry,
  and is skipped when computing "has custom layout".
- Collapsible per character like any other category.
- Expiry re-render: while the window is shown and the New Items section is non-empty,
  schedule a single `C_Timer` for (earliest `firstSeenAt` + timeout + 1s) to refresh;
  reschedule on each refresh, cancel on hide.
- Glow: `BagsWindow:IsNewItem` consults the store overlay ("record is in New Items")
  instead of calling `C_NewItems.IsNewItem` directly, unifying glow with section
  membership (works for alts too).

### Cleanup button

- Clears the **selected** character's `newItems` map; when the selected character is the
  current one, also removes live `C_NewItems` markers (existing logic). Enabled for any
  selected character that has active entries. Broadcasts the snapshot-updated message so
  open windows refresh.

### Locales

- Add `BAGS_CATEGORY_NEW` to all locale files (enUS/enGB "New Items"; translated where
  confident, English fallback otherwise — matching existing key conventions).

### Accepted quirks

- With Combine Stacks enabled, a new stack and an old stack of the same item render in
  different sections and do not combine with each other.
- Bank withdrawals that the client flags via `C_NewItems` will appear as new (matches
  Blizzard semantics).

## Verification

- `luac -p` (or equivalent) syntax pass over all touched files.
- In-game manual pass: loot an item → appears at top under New Items, newest first, full
  row; Cleanup returns it to its natural category; collapse/expand persists; layout editor
  cannot drag the section; alt view shows overlay; entries age out after timeout.
