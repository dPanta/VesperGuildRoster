# VesperGuildRoster

Simple addon for forming m+ groups in a guild.

# Overview

## Features so-far:
- Guild roster
- M+ key sync and view in roster window (synces out of combat every minute accros people who have the addon, on bag update and on login)
- Ability to invite or whisper from roster
- Portals window.
  - Automatically populates the right portal frame with current season dungeon portals.
  - Shows cooldown, desaturates (and removes ability to click) portals that have not yet been unlocked.
- If you click on a key in roster window, it starts casting dungeon teleport (if you have it unlocked)

## How to use:
- Icon of a sheep will be visible on your screen after logging in. Click on it to view the roster.
- or use /vg chat command
  
# Credits
Thank you to all who use the addon for testing. First time doing this.

## BigWigs - [https://github.com/BigWigsMods/LibKeystone]

LibKeystone for synchronizing keystones across guild members, pulling rating data and such.

## EnhanceQoL - [https://github.com/R41z0r/EnhanceQoL]

Learned how to make clickable dungeon buttons and how to pull data about keys from wowAPI.

## DungeonTeleportButtons - [https://github.com/tadahh/DungeonTeleportButtons]

Learned filtering from his library structure.
