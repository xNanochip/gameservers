## Creators.TF Server Repository
This is the repository that contains all of the code, configs, and content for the Creators.TF Servers. Creators.TF Servers have a lot of custom content such as custom weapons, cosmetics, strange parts, campaigns, just to name a few. A lot of this repository is the economy code (usually starting in `cecon_` or `ce_`), which is responsible for all of the previously mentioned custom features.

The CI/CD scripts will automatically manage deployment out to all game servers when a commit is pushed.

## SourcePawn Development File Structure
File Structure: `<root install> / servers / tf / addons / sourcemod`
- ∟ **scripting** - All raw Sourcepawn files. All files ending in .sp that have been changed will be compiled into .smx files when a commit is pushed. They will then be automatically deployed onto game servers. 
    - ∟ attributes - Sourcepawn files that relate to custom weapon, item, or object attributes. Also includes specific provider economy features (e.g Creators.TF Strange’s).
    - ∟ disabled - Sourcepawn files that are compiled and are immediately moved to /disabled on compile.
    - ∟ discord - Files required for the Seed bot on the Creators.TF Discord.
    - ∟ external - Sourcepawn files that are not made by the team.
    - ∟ fixes - Sourcepawn files that have quality of life changes to TF2’s gameplay.
    - ∟ include - Sourcepawn include files.
    - ∟ sbpp - Sourcepawn files required for SourceBans++.
- ∟ **plugins** - Sourcemod plugins which are developed by us are auto recompiled on each server instance. So there is no need to store their compiled versions on the repo. However, if we want to keep some compiled plugins that aren't managed by us and we don't expect them to be updated so often -- we should keep them in the external folder. That folder is not ignored and git tracks all changes that were made in that folder.
- ∟ **configs** - All of the config files required for our plugins.
    - ∟ cecon_items - See [Injecting Custom Items](https://gitlab.com/creators_tf/servers/-/wikis/Injecting-Custom-Items).
    - ∟ regextriggers - Config files required for the regex triggers plugin. Do not touch unless you know what you’re doing. 
    - ∟ sourcebans - Config files for SourceBans.
    - ∟ economy_$x.cfg - These config files are loaded in by cecon_core.smx  when it’s loaded so backend HTTP requests can go through. Do not touch these unless you have permission from a Core Developer.

## Game Server Configuration
There are three types of `.cfg` files to worry about:
- `quickplay/base` - All game servers will execute this first to setup the basic gameplay and necessary convars.
- `quickplay/$x00` - Depending on the region the server is in, this file will get executed to set the IP for the calladmin command.

---

The game server regions are as follows:
- 100 - West Europe
- 200 - East US (Virginia)
- 300 - West US (LA)
- 400 - West US (Chicago)
- 500 - Brazil
- 600 - Australia (Sydney)
- 700 - Singapore
- 800 - Maryland (Potato's Custom MvM Servers)
- 850 - Europe (Potato's Custom MvM Servers)

---

- `quickplay/server-$xxx` - Each individual game server has it's own config file so it can set it's hostname and server index number. This config file will call the other two files previously mentioned.
