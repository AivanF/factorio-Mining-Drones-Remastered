# Mining Drones 2.0 Remastered

![icon](/Mining_Drones_Remastered/thumbnail.png)

--------------------------------------

These guys mine for you, based from their mining depot.

Old demonstration video: https://streamable.com/ymk8h

You can mine any ore including modded ones and Uranium, by inputting the required fluid into the back of the depot. The mining area is shown when hovering over a depot, it is a 80x80 area in front of the depot.

## Math
Ore mining rate is about 30 per drone per minute, if ore patch is nearby depot. By default, it's up to 100 drones in a depot, so totally 3000 ore pcs per depot per minute. You will have lower rate if ore patch is farther (which will happen naturally due to its exhaustion) and higher rate if you research mining productivity or drones speed technologies.

# v2.0 Features

## 1. Technology
You need to research a technology to unlock Drones and Depots.

## 2. Editable drones recipe
Drones recipe is customasable by startup settings. There are the following optional ingredients:
- iron stick and gear wheels
- steel plates
- green / red / blue circuits
- heat / electric engine
- battery
- more ingredients from supported overhaul mods!

Some of these will also affect depot's recipe. The cost of science packs and required dependencies of root technology will be updated with startup settings you pick. So, you can make Mining Drones an early-, mid- or late-game technology.

## 3. Pollution
Mining drones produce pollution in accrodance with to vanilla drills. The amount can be adjusted by map settings, whether you prefer more or less pollution.

## 4. Energy
Drones consume electric energy to perform work, so you need to attach a power pole. Default value of required energy usage by a drone is 100 kW, it can be edited with settings, down to 0. Note that depot also consumes energy as 5 drones to maintain their management.

## 5. Depot capacity
Configurable number of drones in a depot, default capacity is 100, but you can set 10-2000. Other forks [have a bug of ore deletion](https://mods.factorio.com/mod/mining_drones_overloaded/discussion/63ebd13d14017a6b19810b41) when there are too many drons, it's solved here.

Also you can change drones' item stack size from 20 to 5-500.

## 6. Drones utlise vanilla Mining Productivity research
I removed additional Productivity research for mining drones, now vanilla one is used. This can be reverted by settings.

## 7. Disableable Drills
Also you can disable Burner or Electric Mining Drills to live with drones only!

## 8. Ore Auto Loading
If you accidentally grab ore from a depot, it will be put back when you open it `:)`

## 9. Migrating from v1.x and forks

I spent several hours to burn my brain, but made migration process from original Mining Drones mod and its forks as smooth and seamless as possible, recreating state management objects and cleaning all the hidden entities to prevent wandering drones, collision with invisible walls and overlapping text labels.

## 10. Mods compatibility

Supported & compatible mods:
- AAI Industry – additional recipe settings for big/small burner/electric motors/engines.
- Space Exploration – new ores & additional settings.
- Tiberian Dawn – new ores & auto rescan on their growth.
- Warptorio2 – everything keep working after warp teleportations; drones benefit from W2 productivity research.
- Deep core mining, Prospector – ignoring their special resources to keep depot's menu clean.
- and many more by default! Any new ore is already supported.

In case you use a mod that performs some complex logic that breaks ore detection by depots (like teleportation or ore growth), you can use manual commands `/mining-depots-rescan` or more cruel `/mining-depots-total-reset`

Skin mods:
- [C&C, Red Alert, Tiberium Dawn](https://mods.factorio.com/mod/Mining_Drones_2_CnC) – replaces depot and miners with refinery and harvesters from the legendary game series
- [AAI Mining Vehicle](https://mods.factorio.com/mod/Mining_Drones_2_AaiMiner)

# Locales

The following languages are supported:

- English 🇬🇧
- German / Deutsch 🇩🇪
- Spanish / Español 🇪🇸
- French / Français 🇫🇷
- Turkish / Türkçe 🇹🇷
- Ukrainian / Український 🇺🇦
- Russian / Русский 🇷🇺
- Chinese / 中文 🇨🇳

# Final notes

Hope you will love my mod 😊 Bug reports are welcome, feature and compatibility requests may be also considered. You can write [in mod's Discussions](https://mods.factorio.com/mod/Mining_Drones_Remastered/discussion) or [in Discord](https://discord.gg/7QCXn35mU5).

The mod is based on [Mining Drones by Klonan](https://mods.factorio.com/mod/Mining_Drones), but I immersed deeply in the code to create the most comprehensive version of original Klonan’s mod providing great balance and many improvements listed above. There was [an interesting discussion on Reddit](https://www.reddit.com/r/factorio/comments/13u2eb6/mining_drones_20_remastered/).

Partially it's similar to my previous mod [Mining Drones improved Tech](https://mods.factorio.com/mod/Mining_Drones_Harder) which was a separate patch with recipe change only, while this one is a fork due to it allowed much more improvements.

For other modders: my goal is to MD2R maximally extensible and compatible. [Check out related FAQ section](https://mods.factorio.com/mod/Mining_Drones_Remastered/faq).

# Marketing!

- To protect and expand your factory, I recommend to use another my mod: [Improved Sniper Rifle and Carbine](https://mods.factorio.com/mod/sniper-rifle-improved)
- To make hunting more fun and profitable, or to make a crude oil supply, check out my mod [Powered by Biters](https://mods.factorio.com/mod/Powered-by-Biters)
