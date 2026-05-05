## 6.1.0 - 2026-05-05

### Fixed
- Right-clicking a bag item with vesperTools' warband bank view selected now deposits into the warband bank instead of the character bank. The native `ContainerFrameItemButton` overlay used to route right-clicks through Blizzard's `UseContainerItem`, which always honors `BankFrame.activeBankType` (defaulting to character) regardless of which view vesperTools displays. The native overlay is now suppressed whenever a writable bank is live; the secure overlay underneath fires a `macrotext2` that calls `vesperTools:DepositBagItemToActiveBank(bag, slot)`, which routes through vesperTools' selected character/warband view and recomputes the target slot at click time.

### Changed
- `BagsWindow:TryDepositItemIntoActiveBank` extracted into a new public `BagsWindow:DepositBagItemToActiveBankAt(bagID, slotID)` helper so the deposit routing can be invoked from a macrotext without going through a button reference. The button-driven path now thin-wraps the helper.
- `vesperTools:DepositBagItemToActiveBank(bagID, slotID)` exposed as a top-level entry point, callable from `/run` macros and the secure overlay's `macrotext2` attribute.

### Notes
- This fix is fully taint-free: `BankFrame.activeBankType` is never written from addon code, Blizzard's protected `UseContainerItem` is never invoked, and the macrotext runs from a hardware-event-triggered SecureActionButton click. Left-click pickup, modifier-click hyperlinks, drag-and-drop, and consumable use outside the bank context are unaffected.

## 6.0.0 - 2026-05-05

### Fixed
- Dungeon portals owned account-wide are now detected reliably. The spell-known cascade in `vesperTools:GetPlayerSpellKnownState` previously short-circuited to `false` as soon as any `C_SpellBook` API existed (always true on retail), making the legacy `IsPlayerSpell` probe unreachable — the only check that surfaces account-wide spells the active spec doesn't expose. Every probe now runs in order; first hit wins.
- Portal availability no longer flips to "locked" when `C_Spell.GetSpellInfo` returns nil right after login. The `known` flag in `Portals:ApplyDungeonPortalButtonState` is now decided purely by `IsSpellKnownForPlayer`; the spell name is only required to wire the secure cast attribute, so a brief cache miss leaves the portal visually-known but click-disabled until the next refresh instead of reporting it as missing.
- Manual spellbook scan now accepts both `Spell` and `Flyout` itemTypes, so account-wide unlocks delivered as flyout entries no longer escape the scan.
- The `/vg` macro no longer stops working after another addon's chat-command lifecycle clears the slash entry. Slash commands moved off the shared `ACECONSOLE_*` namespace into a private `VESPERTOOLS_*` namespace, the slash hash is primed at registration time so the cache can never be empty when invoked, the slash dispatcher resolves the target method once at registration instead of per-call, and `PLAYER_ENTERING_WORLD` re-asserts the registrations so any post-load clobber self-heals on the next loading screen.
- `Roster:HandleCloseRequest` no longer touches `Portals.VesperPortalsUI` during combat lockdown (the portals UI hosts secure-template children). Closing the roster mid-combat now leaves portals open until lockdown ends instead of risking a taint error that would abort the slash/macro dispatch.

### Changed
- Dungeon portal buttons are now created with the `vesperToolsPortalButton<n>` global frame name instead of the unprefixed `PortalButton<n>`, removing a cross-addon collision vector.
- `/vg portalspells` debug now iterates every catalog entry per mapID and prints a per-mapID summary line showing which spellID the live UI would actually use. Users with multi-variant dungeons (e.g. Skyreach Midnight + Warlords) can see which alternates were tried and which API path detected each one.

### Added
- `/vg diag` (alias `/vg diagslash`) reports whether the live `SlashCmdList`, `SLASH_*1` global, and `hash_SlashCmdList` entries for `/vg` and `/vesper` are intact. Affected users can confirm slash health in one message.

### Notes
- Major bump because the slash command namespace migrates from `ACECONSOLE_*` to `VESPERTOOLS_*` and the dungeon-portal frame names migrate from `PortalButton<n>` to `vesperToolsPortalButton<n>`. Anything reaching into vesperTools through those globals (custom WeakAuras, third-party scripts) needs to update its references.

## 5.3.0 - 2026-05-04

### Added
- Roster window now auto-sizes vertically based on the number of online guildmates. Expands symmetrically up and down to keep its visual center fixed, clamped between the existing 250px minimum and 70% of the screen height.
- Roster window listens for `OnSizeChanged` and re-lays out columns and rows during live resize drags, so the layout no longer freezes mid-drag until the resize grip is released.
- Roster header sort indicators are now drawn as a separate icon texture anchored to the right of each column, so they stay visible even when a long localized label truncates.

### Changed
- Roster row, header, titlebar, and titlebar-action-button heights now scale with the configured roster font size, so larger fonts no longer clip the row text vertically.
- Roster titlebar action buttons (`Sync`, `Cnf`, `Bags`, `Blizz`, `Bank`) now resize to fit their localized text under the current font instead of using fixed pixel widths.
- Roster title text now anchors against the leftmost titlebar action button, preventing long guild names from drawing through the action buttons.
- Roster scrollbar now appears only when row content exceeds the auto-sized window height (capped at 70% of the screen).
- Roster column viewport width is now derived arithmetically from `contentFrame:GetWidth()` instead of the still-stale `scrollFrame:GetWidth()`, eliminating the first-paint flicker that occurred when the scrollbar visibility toggled.
- Roster sync-driven refresh requests are now coalesced through a single `C_Timer.After(0)` window, so bursts of `VESPERTOOLS_*_UPDATE` messages trigger one rebuild per frame instead of one per message.
- Roster resize grip now controls width only; vertical bounds are locked to the auto-sized height on every refresh.
- Roster window is now `SetClampedToScreen(true)` and uses dynamic max resize bounds derived from `UIParent` dimensions, so it can no longer be dragged or resized fully off-screen.

### Fixed
- Double-clicking on the keyLevel column of a roster row now triggers the row's primary action (invite / request to join) in addition to firing the secure portal cast.
- Roster row backgrounds are now reset when rows are recycled, so a row that was hovered when the data refreshed no longer keeps its hover tint.

### Notes
- This minor release focuses entirely on the roster window: a vertical auto-sizing pass and a sweep over the layout pipeline's visible-bug weak spots (title clipping, sort-arrow truncation, font-size-aware row heights, live-resize column relayout, and others).

## 5.2.1 - 2026-05-04

### Fixed
- Added an auto-discovery blacklist so the `Autographed Hearthstone Card` (item 118427) — a Hearthstone-the-game promo toy that matches the hearthstone name token but is not a teleport — no longer leaks into the hearthstone catalog.

## 5.2.0 - 2026-05-04

### Changed
- Hearthstone catalog now auto-discovers toys whose localized name contains the hearthstone token, so newly added hearthstone toys appear without a code patch. The previous curated list still seeds canonical IDs for exotically-named variants (Innkeeper's Daughter, Dark Portal, etc.).
- Hearthstone availability check for the physical hearthstone (item 6948) now considers bags + bank + reagent bank instead of bags only, so alts that park their stone in the bank still get the button.
- `SPELLS_CHANGED` is now coalesced through a single 0.15s debounce window. Login, spec switches, and talent loads stop running the spellbook waterfall dozens of times in a row.
- Login refresh path runs through the same coalesce, eliminating the duplicate spellbook scan from the old 0.25s pre-warm.

### Added
- Periodic sanity sweep (every 5 minutes, skipped during combat) that re-runs portal, mage travel, hearthstone, and toy refreshes. Catches state we'd otherwise miss if `TOYS_UPDATED`/`SPELLS_CHANGED` ever drops.
- `TOYS_UPDATED` invalidates the cached merged hearthstone catalog so newly learned hearthstone toys are picked up immediately.

## 5.1.4 - 2026-05-02

### Changed
- Made the roster Sync button clear and rebuild dungeon portal availability from the current season catalog and current character spellbook state.

### Fixed
- Removed protected pass-through button calls from bag and bank item overlays to prevent action-blocked errors when opening the replacement bag window.

## 5.1.3 - 2026-05-02

### Notes
- Hotfix version bump for gitsync.

## 5.1.2 - 2026-05-02

### Fixed
- Added the Midnight Keystone Hero Skyreach teleport spell ID and kept the older Warlords Challenge Mode Skyreach teleport as a fallback variant.

### Notes
- This hotfix restores Skyreach portal detection for characters whose spellbook contains the current `Path of the Crowning Pinnacle` unlock.

## 5.1.1 - 2026-05-01

### Changed
- Moved the current character's Mythic+ rating to the bottom of the Best Runs panel while keeping it centered and rating-colored.

### Notes
- This hotfix follows up on `5.1.0` with a small layout adjustment for the new Best Runs rating readout.

## 5.1.0 - 2026-05-01

### Changed
- Added the current character's Mythic+ rating to the Best Runs panel, centered and colored with Blizzard's usual Mythic+ rating rarity color.
- Updated dungeon metadata lookups to prefer the current character's known portal variant when multiple spell IDs exist for the same challenge map.

### Fixed
- Added a spellbook-scan fallback to the shared current-character spell knowledge check so portal buttons can recover when direct spell-known APIs report unavailable even though the spell is visible in the player's spellbook.
- Let existing portal buttons switch to a known map variant during availability refreshes, including refreshes from login retries, `SPELLS_CHANGED`, portal-window open, and manual sync.

### Notes
- This minor release improves confidence in the portal frame by checking the character's actual player spellbook and adds a quick rating readout to the Best Runs panel.

## 5.0.0 - 2026-04-28

### Changed
- Bumped the supported retail interface to `120005` so the TOC matches the live `12.0.5` client and dropped the older dual-interface tag.
- Reworked the mage portal and teleport quick-cast buttons so left-click now casts the currently selected travel spell directly through a secure action button, while right-click opens the picker menu.
- Added a persistent per-character selection for the mage portal and teleport quick-cast buttons, with the picker menu marking the active choice with a `*` prefix and the button icon, name, and cooldown sourcing from that selection.
- Migrated the mage travel spellbook scan off the removed `GetNumSpellTabs`, `GetSpellTabInfo`, `GetSpellBookItemInfo`, and `BOOKTYPE_SPELL` paths to the modern `C_SpellBook` skill-line API and `C_Spell.GetSpellInfo` lookups.
- Routed the launcher search talent-loadout activation through a new helper that prefers `C_ClassTalents.SwitchToLoadoutByIndex`, falls back to `ClassTalentHelper.SwitchToLoadoutByIndex`, and finally calls `C_ClassTalents.LoadConfig` with auto-apply, so loadout selection actually loads the talents instead of only marking them active.

### Fixed
- Fixed the bank window so opening it now defaults to the currently logged-in character's bank view whenever that live bank is available, instead of restoring the last manually viewed character or the warband view.
- Fixed the bags-to-bank bridge view resolution so the current character's bank consistently wins over the previous interaction type, instead of only winning when the open interaction was a normal banker.
- Hardened the portal-window cooldown lookup with a `pcall` around `C_Spell.GetSpellCooldownDuration` so utility buttons no longer break if the new retail signature errors on certain spells.
- Deferred mage travel button refreshes scheduled during combat through the existing pending-utility-refresh flag so secure-action attribute updates do not trigger taint while in combat lockdown.
- Added the new `MAGE_TRAVEL_TOOLTIP` locale string to `enUS` and supplemental fallbacks so the rebuilt mage travel buttons show their `Left-click: Cast / Right-click: Choose` hint correctly.

### Notes
- This major release brings vesperTools current with the `12.0.5` retail client: secure left-click casting for mage travel buttons, the modern spellbook and talent-loadout APIs, and bank views that reliably anchor on the active character.

## 4.6.1 - 2026-04-27

### Fixed
- Routed right-click bank deposits from the replacement bags window through the active vesperTools bank view, so Warbound items now go to the Warband bank when that view is open instead of falling through to the character bank.
- Let the native live-container item overlay pass right-clicks through during writable bank sessions so vesperTools can choose the correct character or Warband destination.
- Fixed a stack-size lookup error in the manual bank deposit slot search that could throw when depositing certain items.

### Notes
- This hotfix follows up on `4.6.0` by tightening the replacement-bag bank deposit path after restoring native right-click item behavior.

## 4.6.0 - 2026-04-27

### Changed
- Added a shared current-character spell knowledge check for dungeon portals and roster key portal casts, using the modern spellbook APIs first so portal availability is less likely to bleed between characters.
- Wired the roster Sync button, `/vg sync`, and launcher-open refresh path to also refresh current-character keystone data, guild keystone requests, and dungeon portal spell availability.
- Added `Blizz` buttons in the bags window and next to the roster Bags button that open Blizzard's default bags without routing back into the replacement window.
- Reworked replacement-bag item activation to follow Blizzard's native live container item button flow, matching the safer pattern used by established bag addons.

### Fixed
- Fixed dungeon portal buttons staying disabled after login or spellbook updates by rechecking portal spell availability on delayed login retries, `SPELLS_CHANGED`, portal-window open, and manual sync.
- Restored replacement-bag right-click item use through Blizzard's native container item button path, with left-click and drag behavior still passing through to vesperTools.
- Kept secure item attributes only as a fallback when the native container item button template is unavailable.
- Stopped syncing the replacement bank view by calling Blizzard's bank tab setter and removed direct bank-deposit `UseContainerItem` calls, avoiding a retail bankType taint path that can break native bag item use.
- Updated current-character keystone refreshes to store the local roster keystone snapshot directly instead of depending on receiving a guild echo.

### Notes
- This minor release focuses on alt-correct portal availability and safer bag item interactions after the retail protected-action changes around container item use.

## 4.5.0 - 2026-04-23

### Changed
- Added live bank deposit routing to the bags window so left-clicking or dragging items while a writable bank is open now deposits them into the active character or warband bank view.
- Synced the vesperTools bank view back to Blizzard's native bank tabs so direct deposits and manual bank interactions stay pointed at the same live destination.
- Extended the bags overlay interaction rules so those bank-deposit clicks can pass through the custom item overlay instead of being swallowed before the deposit logic runs.

### Fixed
- Fixed bank deposit targeting so items that can only go into one bank type no longer attempt to route into an invalid character or warband destination.
- Fixed the fallback deposit path so stackable items still merge into partial stacks and otherwise choose a compatible empty bank bag slot when the direct bank API deposit path is unavailable.

### Notes
- This minor release is focused on making bank cleanup faster from the bags window, especially while switching between live character-bank and warband-bank views.

## 4.4.0 - 2026-04-20

### Changed
- Moved the roster window close button to the left side of the titlebar while `Apple Fan` is enabled, keeping the normal right-side layout when the style toggle is off.
- Realigned the alt-character keys frame so it is horizontally centered beneath the Best Runs frame instead of inheriting the left edge alignment.
- Turned the `Apple Fan` confetti burst into a much more excessive spread, with many more pieces, wider travel, and longer visible motion.

### Fixed
- Fixed the roster window titlebar layout so its square top strip no longer peeks through the rounded upper corners as tiny dark triangles while `Apple Fan` mode is active.
- Fixed the `Apple Fan` confetti burst so pieces spawn from an inner edge band and spread more naturally instead of appearing as cramped straight lines from outside the configuration window.

### Notes
- This minor release is a follow-up polish pass on the `4.3.0` Apple Fan presentation, focused on layout cleanup and pushing the visual joke further.

## 4.3.0 - 2026-04-20

### Changed
- Added a global `Apple Fan` style toggle to the configuration window so all vesperTools windows can switch between rounded and classic square corners from one place.
- Added a custom rainbow bitten-apple icon beside the `Apple Fan` toggle and styled the configuration window border with the player's class color to match the rest of the rounded-window treatment.
- Added an intentionally over-the-top confetti burst around the configuration window when `Apple Fan` is enabled.

### Fixed
- Reworked the shared rounded-window backdrop helper so toggling between rounded and square corners preserves the intended dark fills and class-colored borders instead of losing or whitening frame styling.
- Cleaned up the rounded corner rendering so larger-radius corners stay crisper and avoid the dark pixel gaps, jagged cutouts, and uneven border thickness seen during the earlier corner-art iterations.
- Fixed the new `Apple Fan` confetti overlay so it uses valid texture sublevels and spreads from the window edge band instead of clipping from outside the panel.

### Notes
- This minor release is focused on visual polish and playful configuration flair, centered on the new global rounded-corner style toggle and its Apple-themed presentation.

## 4.2.2 - 2026-04-17

### Fixed
- Fixed the account-keystone snapshot refresh so characters without a fully initialized Mythic+ keystone yet no longer trip a startup Lua error when Blizzard's keystone APIs return no value.

### Notes
- This hotfix hardens the new account-keystone tracking added in `4.2.0`, especially for freshly progressed level-80 characters who have not fully entered the Mythic+ flow yet.

## 4.2.1 - 2026-04-16

### Fixed
- Colored character names in the account keystone panel by class so the new alt-key list is easier to scan at a glance.
- Added a bags-cache fallback when resolving stored account keystones, so alt keys still appear when the active keystone cache is missing the direct current-name match.

### Notes
- This hotfix tightens up the new alt-key panel added in `4.2.0` without changing its layout or behavior beyond more reliable character resolution.

## 4.2.0 - 2026-04-16

### Changed
- Added an account keystone list below the Best Runs panel in the portals window so you can quickly see which alts currently hold a stored key.
- Added per-character keystone snapshot storage and refresh hooks so the account keystone list stays current from login, bag updates, and Mythic+ completion.
- Filled missing locale keys across all shipped locales so the newer vault and account-keystone UI strings are available everywhere, preserving existing translations and falling back to English where needed.

### Fixed
- Great Vault reward-row tooltips now show the current week's Mythic+ runs that count toward each reward slot, including dungeon names and key levels.
- Vault snapshots now store the current week's Mythic+ dungeon history so those tooltip details are available while reviewing other characters.

### Notes
- This release is focused on making weekly account planning easier by surfacing both stored keystones and vault-progress context in the addon's existing planning windows.

## 4.1.0 - 2026-04-12

### Changed
- Added a roster double-left-click group action so clicking a guild member row twice now invites them, or requests to join their group when Blizzard exposes that join path.
- Split roster row interactions so the row itself handles menu and invite actions while the keystone column remains the dedicated portal-cast target.

### Fixed
- Fixed the roster keystone column so left-clicking the key once again casts the mapped seasonal dungeon portal after the new double-click invite flow was added.
- Updated the roster tooltip hints to reflect the new double-left-click invite action and the separate left-click key portal behavior.

### Notes
- This minor release focuses on polishing roster interactions after the larger `4.0.0` launcher-search update.

## 4.0.0 - 2026-04-12

### Changed
- Added a centered launcher search overlay with a separate search bar and results panel styled to match the existing vesperTools window borders.
- Added dynamic full-text search across vesperTools actions and config tabs, Blizzard settings categories and setting rows, toys, spells, talent loadouts, carried bags, character bank, and warband bank.
- Added a fixed-height scrollable results list capped at 30 entries, with prioritization that favors the current character's carried bags first, then the current character's bank, then other stored inventories.

### Fixed
- Fixed the launcher search flow so results only appear after at least three typed characters, hide completely when the query is empty or unmatched, and no longer auto-focus the search box when the launcher opens.
- Fixed result activation for bag and bank hits so selecting an item opens the correct vesperTools window, switches to the right character or bank view, expands the right category, and seeds the internal item search/highlight.
- Fixed Blizzard settings indexing so retail settings rows are harvested from the live `SettingsPanel` layout instead of only indexing top-level categories.
- Fixed Click Cast Bindings discoverability by exposing it as an explicit searchable launcher action, since it is opened through Blizzard's standalone click-binding UI toggle rather than the normal settings category tree.

### Notes
- This major release turns the launcher into a Spotlight-style search surface for Midnight retail, with broader Blizzard integration and direct navigation into addon windows, bags, bank views, and supported Blizzard configuration surfaces.

## 3.2.7 - 2026-04-09

### Changed
- Added a carried-bag `Season` category so seasonal items are grouped separately from the normal reagent and misc buckets.

### Fixed
- Added current seasonal spark reagents such as `Spark of ...` and `Fractured Spark of ...` to the carried-bag `Season` category instead of leaving them in `Crafting Reagents`.
- Added a bags data migration so existing saved bag snapshots are recategorized into `Season` immediately after update instead of waiting for each character to rescan those items.

### Notes
- This hotfix finishes the new bag-season grouping by making the category visible, catching the common spark crafting reagents automatically, and backfilling already-saved bag data on reload.

## 3.2.6 - 2026-04-08

### Fixed
- Added `Lightcalled Hearthstone` to the portals hearthstone catalog so owned copies now appear in the per-character hearthstone selection list.

### Notes
- This hotfix restores another missing hearthstone variant in the portals selection flow without changing any existing hearthstone behavior.

## 3.2.5 - 2026-04-08

### Fixed
- Added `Preyseeker's Hearthstone` to the portals hearthstone catalog so owned copies now appear in the per-character hearthstone selection list.

### Notes
- This hotfix restores the missing hearthstone variant in the portals selection flow without changing any existing hearthstone behavior.

## 3.2.4 - 2026-04-07

### Changed
- Replaced the roster's faction column with a sortable character level column so the guild list surfaces player level directly.

### Fixed
- Updated the roster right-click action so guild members who are already in a joinable group show `Request to Join Group` instead of always showing a plain invite.

### Notes
- This hotfix keeps the roster focused on more immediately useful character info while making the group-forming flow behave more like Blizzard's own context menus.

## 3.2.3 - 2026-04-03

### Fixed
- Extended the carried-bag `Gear` exemption for past-expansion items so Timewalking-scaled equippable gear stays grouped with current equipment when it requires the current expansion's max level, even without a modern upgrade-track tooltip line.
- Added a bags data migration so previously saved carried snapshots are recategorized immediately instead of waiting for each character to rescan those items.

### Notes
- This keeps current-level Timewalking and other current-scaled legacy equipment out of `Past Expansions` while preserving the existing seasonal dungeon upgrade-track exemption.

## 3.2.2 - 2026-04-01

### Fixed
- Fixed Midnight lure world-map pin startup so the custom map-pin provider is only attached after the Blizzard world map is actually shown, reducing the `Blizzard_MapCanvas.lua:280` assertion seen during early map initialization and parent-map navigation.
- Fixed Midnight lure map-pin rendering so the custom pins no longer style Blizzard map-canvas frames with the shared modern button helper, reducing taint leaking into Area POI tooltip widget layout and `Blizzard_UIWidgetTemplateTextWithState`.

### Notes
- This hotfix is focused on stabilizing the world-map Midnight lure integration after the `3.2.0` map-marker feature release.

## 3.2.1 - 2026-03-31

### Fixed
- Fixed the Midnight lure world-map pins so clicking the knife markers now correctly places Blizzard's built-in user waypoint and enables the navigation arrow.
- Fixed the Midnight lure pin integration so opening the world map or navigating between parent and child maps no longer trips the `Blizzard_MapCanvas` assertion caused by pre-attached pin mouse scripts.

### Notes
- This hotfix is focused on stabilizing the new Midnight lure map markers after the larger `3.2.0` feature release.
