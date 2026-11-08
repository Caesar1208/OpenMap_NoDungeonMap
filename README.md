# OpenMap - No Dungeon Map

A small WoW Forever addon that makes [OpenMap](https://github.com/openmap-world/openmap) and
Dungeon Journal (ForeverDungeonJournal) play nicely together.

- Turns off OpenMap's own dungeon map, so it no longer takes over the world map inside a dungeon
  (Dungeon Journal's map shows there instead).
- Keeps OpenMap's dungeon entrance icons. Clicking one shows Dungeon Journal's map of that dungeon
  on the world map. Right-click, its "World Map" button or Esc goes back.
- Several dungeons at one entrance (Scarlet Monastery, Stratholme, Blackrock Spire): pick from a list.
- No Dungeon Journal map for a dungeon: its journal page opens instead.

Dungeons are matched by name, so new ones connect automatically. If a name differs completely
between the two addons, add it to the `ALIAS` table in `NoDungeonMap.lua`.

## Install

Copy this folder into `World of Warcraft/_forever_/Interface/AddOns/` (the folder must be named
`OpenMap_NoDungeonMap`). Requires OpenMap; Dungeon Journal is optional (without it, entrance clicks
do nothing).
