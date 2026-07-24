CS:GO Gamemode for Garry's Mod

Installation
1. Remove or disable the previous CS:GO autorun scripts to avoid duplicate hooks.
2. Copy the csgo folder into garrysmod/gamemodes.
3. Ensure the SWCS addon and the configured player models are installed.
4. Start the server with +gamemode csgo and a compatible map.

Recommended launch arguments
-tickrate 64 +gamemode csgo +map <map_name>

Configuration
gamemode/sh_config.lua contains round timing, spawn positions, bomb sites, site radius, weapon classes, models, and the base loadout.
