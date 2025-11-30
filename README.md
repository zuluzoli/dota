# Example Addon Setup Guide

## Steps

1. **Download** the `example` directory.
2. **Copy** the `example` directory to your Dota 2 folder:  
   `C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota_addons\example`
3. **Launch** Dota 2.
4. **Enable** the console in the _Settings_ menu.
5. **Open** the console and type:  
   `dota_launch_custom_game example dota`

## Notes on the Command

The command `dota_launch_custom_game example dota` takes **two parameters**:

- **First parameter** → the **addon name** (`example`)
- **Second parameter** → the **map name** (`dota`)

## Expected result

After running the `dota_launch_custom_game example dota` command, you should see the message in the console:

## Our goal

Our goal is to create a single draft mode where:

1. Everybody receives 3 random heroes from the full pool (exactly like in Single Draft mode).
2. A specific Steam account ID receives only a few predefined heroes, such as Chen. This effectively reduces the advantage of high-MMR accounts.
3. **Optional**: We can additionally give that specific Steam account ID 30% less gold and XP.

# Duna

Another attempt at making the limited hero selection from scratch.

Currently, it loads the heroes from the `herolist.txt` file, but the dynamic hero selection is not implemented. Seems like it would require creating a new, custom GUI for picking heroes. Which wouldn't be a problem, but I can't find a way (yet) to prevent Dota from showing the default hero selection user interface.

There are two folders:

- `content/duna`: put this into `dota 2 beta/content/dota_addons/duna`
  - The source files for resources are in the `content` folder
  - When the addon is loaded, Dota automatically builds these files into the `game` folder
- `game/duna`: put this into `dota 2 beta/game/dota_addons/duna`
  - Contains built resources
  - Contains the LUA scripts that are to be executed as well
