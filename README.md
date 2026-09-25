# MauAddons

A collection of World of Warcraft addons by Maurits Arissen. Each addon lives in its own folder at the root of this repository and can be installed on its own.

## Addons

| Addon | Description | Game |
|---|---|---|
| [MauUndercut](MauUndercut/) | Bulk auction posting with automatic lowest-price lookup and undercut, plus a full auction house scanner that lists every item's lowest price and highlights items listed below vendor price. | World of Warcraft: Forever (`_classic_beta_`, interface `16001`) |
| [MauGuildMap](MauGuildMap/) | Shows guild members who run the addon on the world map: race icon, name and level on hover, dungeon-goers at the entrance. | World of Warcraft: Forever (`_classic_beta_`, interface `16001`) |

Each addon folder has its own `README.md` with usage, slash commands and known limits, and a `CLAUDE.md` with the full technical documentation.

## Installation

The game must see an addon folder under the exact name of its `.toc` file, for example `MauUndercut`. Either copy the addon folder into the game's `AddOns` directory, or keep this repository where it is and link the folder in with a directory junction so edits show up in game after `/reload`.

Copy:

```
<WoW install>\_classic_beta_\Interface\AddOns\MauUndercut
```

Junction (PowerShell, adjust the paths to your setup):

```powershell
New-Item -ItemType Junction `
  -Path "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\MauUndercut" `
  -Target "<path to this repo>\MauUndercut"
```

Then enable the addon in the AddOns list at the character screen.

## Development

There is no build step. Edit the Lua files in place and run `/reload` in game. See the `CLAUDE.md` inside each addon folder for the target client, the APIs used, and how to verify changes.
