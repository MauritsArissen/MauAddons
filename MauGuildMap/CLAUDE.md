# MauGuildMap — guide for future work

Complete reference for the MauGuildMap addon: what it does, how it is built, why, and what was verified. Read it before changing anything. The target client, install loop, syntax check and Blizzard source branch are the same as for MauUndercut; see `../MauUndercut/CLAUDE.md` sections 2 and 3 (including the 2026-09 SavedVariables client bug).

## 1. What it is

Guild members running the addon broadcast their position on the guild addon channel; everyone with the addon draws them as race icons on Blizzard's world map (zone, continent and world views). Hovering shows name, level, race, class, zone and the age of the update. Members in an instance are drawn at the entrance (their last outdoor position), dimmed. No minimap. Members disappear on logout ("bye" message and guild presence), when they hide themselves, or after `NS.TIMEOUT` seconds without a message.

## 2. Files and load order

| File | Role |
|---|---|
| `MauGuildMap.toc` | Load order: MauGuildMap.lua, Roster.lua, Comm.lua, MapPins.lua, MauGuildMap.xml, Test.lua. |
| `MauGuildMap.lua` | Namespace `NS` (also `_G.MauGuildMap`), constants (`SEND_INTERVAL` 2 s, `HEARTBEAT` 20 s, `TIMEOUT` 60 s), helpers (short names, class colours, race names, race atlas, ages, map names), saved variables (`MauGuildMapDB.settings.broadcast` = send my position, `settings.display` = draw the others; both default true), event frame (login/logout), `/mgm` (plain `/mgm` prints status plus the command list: hide/show toggle `broadcast`, disable/enable toggle `display`, list, test). |
| `Roster.lua` | `NS.Roster`: members keyed by short name; `Update`, `Remove`, `Expire` (5 s ticker), `GetPositionOnMap`, `PrintList`, `CLUB_MEMBER_PRESENCE_UPDATED` handler. |
| `Comm.lua` | `NS.Comm`: wire format (`Encode`/`Decode`), position sampling (`SampleOutdoor`, `FindEntrance`, `CurrentState`), send loop (`Tick`/`Send`/`ForceSend`/`SendBye`), receive (`OnMessage`, `CHAT_MSG_ADDON`). |
| `MapPins.lua` | `NS.Map`: data provider + pin mixin, `TryInit` (adds the provider to `WorldMapFrame`), `RequestRefresh`. Fills the global mixin tables the XML refers to. |
| `MauGuildMap.xml` | `MauGuildMapPinTemplate`: a 24×24 Frame with a 24×24 class-coloured `Ring` (white texture clipped by `RingMask`) under a 20×20 `Icon` texture clipped round by `CircleMask`, `enableMouseMotion="true"`, `mixin="MauGuildMapPinMixin"`. |
| `Test.lua` | `NS.Test`: `/mgm test` simulation. |

All files share `local _, NS = ...`. No libraries. Tabs.

## 3. Wire format and cadence

- Prefix `MauGuildMap` (registered with `C_ChatInfo.RegisterAddonMessagePrefix` at `PLAYER_LOGIN`), channel `"GUILD"`.
- Position message: `1:<mapID>:<x>:<y>:<level>:<raceFile>:<sex>:<classFile>:<flag>:<instanceName>`; x/y are map coordinates × 10000; `flag` is `O` (outdoors) or `I` (in an instance: position = entrance); the instance name is last so it may contain anything. `B` alone = goodbye. Typical length 45–60 bytes (limit 255).
- Every `SEND_INTERVAL` (2 s) `Comm:Tick` samples the state and sends when flag, map, level, instance or position (by more than 0.0005) changed, or when `HEARTBEAT` (20 s) has passed. `PLAYER_ENTERING_WORLD` and `PLAYER_LEVEL_UP` force the next tick to send. `PLAYER_LOGOUT` and `/mgm hide` send `B`. Not sent when `IsInGuild()` is false or `settings.broadcast` is false.
- `C_ChatInfo.SendAddonMessage` returns `Enum.SendAddonMessageResult` (Success = 0; also AddonMessageThrottle, ChannelThrottle, NotInGroup...). Only a success updates `lastSent`, so a throttled message is retried on the next tick.
- Own messages come back through `CHAT_MSG_ADDON` too; they are dropped by comparing the short sender name with the player's.
- Rate reasoning: one ~50-byte message every 2 s per moving member is far under the server throttle (roughly one message per second sustained per sender). Receiving is not throttled; 50 members → at most ~25 tiny messages per second.

## 4. Positions

- Outdoors: `C_Map.GetBestMapForUnit("player")` + `C_Map.GetPlayerMapPosition(mapID, "player")` (documented "only works for the player and party members"; returns nil inside instances). The last valid sample is kept in `Comm.lastOutdoor`.
- In an instance (`IsInInstance()`): the message carries `lastOutdoor` with flag `I` and `GetInstanceInfo()`'s name. The last sample is at most `SEND_INTERVAL` old, i.e. taken standing at the portal, which is the entrance. If the addon loaded while already inside, `Comm:FindEntrance()` walks up from `GetBestMapForUnit("player")` through `C_Map.GetMapInfo(...).parentMapID` calling `C_EncounterJournal.GetDungeonEntrancesForMap(mapID)` and matching `journalInstanceID` with `C_EncounterJournal.GetInstanceForGameMap(instanceMapID)` (8th return of `GetInstanceInfo`). All verified in the `forever` branch API docs; whether the journal has entrance data for Classic dungeons on Forever is untested.
- Receivers store the sender's map + position and also a world position: `C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))` → `continentID, worldPosition`. Placement on the viewed map: same map → the raw coordinates; otherwise `C_Map.GetMapPosFromWorldPos(continentID, worldPosition, viewedMapID)` and keep it only if inside 0..1. Zone/continent maps additionally require the same game continent as the viewed map (probed once per map by converting its centre with `GetWorldPosFromMapPos`, cached); the world/cosmic maps (`UIMapType` ≤ World) skip that check.

## 5. Map pins

- `Blizzard_WorldMap` is not load-on-demand on this client (TOC has no `LoadOnDemand`), so `WorldMapFrame` exists at `PLAYER_LOGIN`; `Map:TryInit` runs there.
- The XML template's `mixin="MauGuildMapPinMixin"` is resolved when a pin frame is created, so `MauGuildMapPinMixin` is an empty global at load time and filled in `TryInit` with `Mixin(MauGuildMapPinMixin, MapCanvasPinMixin, Pin)`; same for the data provider. This avoids depending on Blizzard load order.
- `MapCanvasMixin:AcquirePin(template, ...)` creates a frame pool from the XML template (`C_XMLUtil.GetTemplateInfo`), calls `OnLoad` once per new frame, sets the `OnEnter`/`OnLeave` scripts to the mixin's `OnMouseEnter`/`OnMouseLeave` when the template has mouse motion enabled (the template must not define OnEnter/OnLeave itself), then `OnAcquired(...)`. Verified in `Blizzard_MapCanvas/Blizzard_MapCanvas.lua`.
- Pin: `SetScalingLimits(1, 1.0, 1.0)` gives a constant on-screen size at any zoom (`ApplyCurrentScale` = 1 / canvas scale × global pin scale). Frame level `PIN_FRAME_LEVEL_AREA_POI`: Blizzard's world map registers its pin levels in ascending order in `Blizzard_WorldMap.lua` (dungeon entrances, flight points, ..., area POIs, gossip, ..., quest offers, world quests, active quests, ..., group members, corpse), and the user wants quest markers always in front, so member pins sit at the area-POI level: above entrances and flight points, below everything quest-related (2026-09-25). `PIN_FRAME_LEVEL_GROUP_MEMBER` was the original choice. Icon via `GetRaceAtlas(lowercase raceFile, "male"|"female")` → `raceicon-<race>-<gender>` (`scourge` is mapped to `undead` by Blizzard's helper), checked with `C_Texture.GetAtlasInfo`, question-mark icon as fallback. The icon is 20 px in a 22 px pin and is drawn zoomed in by 30% (`ICON_ZOOM`): the atlas region's texture coordinates from `GetAtlasInfo` (`file`/`filename`, `left/right/top/bottomTexCoord`) are shrunk 15% on every side and applied with `SetTexture` + `SetTexCoord`, so the rim of Blizzard's round icon stays out of the picture (user request 2026-09-25). The icon is clipped to a circle by a `MaskTexture` (`Interface\CharacterFrame\TempPortraitAlphaMask`, CLAMPTOBLACKADDITIVE wrap, `MaskedTexture childKey="Icon"`), the same construct Blizzard's Communities portraits use. Behind it a 24 px `Ring` texture (`Interface\Buttons\WHITE8X8`, clipped by its own copy of the circular mask, tinted with the member's class colour in `OnAcquired`) shows as a 2 px class-coloured border; the pin frame is 24 px. In-instance members are desaturated and at 80% alpha.
- Data provider: `RefreshAllData` releases all pins of the template and re-acquires one per placeable member (cheap for guild sizes); with `settings.display` false it stops after releasing, so `/mgm disable` clears the map while the roster keeps running and `/mgm enable` is instant. It runs on map change/show (Blizzard), on every roster change while the map is shown (`Map:RequestRefresh`, coalesced to 0.25 s) and every 5 s while shown (ages, timeouts).

## 6. Roster

- Keys are short names (`Ambiguate(name, "short")`) for both `CHAT_MSG_ADDON` senders ("Name-Realm") and club member names.
- Removal: `B` message; `CLUB_MEMBER_PRESENCE_UPDATED(clubId, memberId, presence)` with `presence == Enum.ClubMemberPresence.Offline` and `clubId == C_Club.GetGuildClubId()` (name from `C_Club.GetMemberInfo`); `Expire` every 5 s drops entries older than `TIMEOUT`.
- Test entries carry `entry.test = true`; removal reasons are printed only for those.

## 7. Test mode (`/mgm test`)

Three fake members (races by the player's faction) are placed 3% of the map around the player's last outdoor position and fed through `Comm:OnMessage(text, name, true)` every second, so decoding, roster, pins, tooltips, entrance display (Testbob, flag `I` at 20 s), goodbye (Testcarol at 30 s) and timeout (Testalice silent from 30 s, dropped at 30 + `TIMEOUT`) all use the production path. The test stops itself 8 s after the timeout and removes its entries; `/mgm test` again stops early.

## 8. Decisions made with the user (2026-09-25)

- Guild-wide addon messages, no proximity needed; world map only, no minimap.
- Members in a dungeon are shown at the entrance.
- Near-realtime updates (2 s while moving), removal on logout and after a timeout without updates.
- `/mgm test` simulation because no second tester was available.
- Broadcasting can be switched off (`/mgm hide`) since positions go to the whole guild.

## 9. How to verify

1. Syntax: node + luaparse over every `.lua`; XML well-formed.
2. `/mgm test` outdoors, open the map: three icons near you, moving; hover for tooltips; at 20 s Testbob dims and stops; at 30 s Testcarol vanishes; at 90 s Testalice vanishes; ~98 s "Test finished".
3. With a guild mate: both log in, `/mgm` shows 1 member, icon on the map moves with them; they enter a dungeon → icon at the portal, tooltip says the instance; they log out → icon gone within a few seconds.
4. If Blizzard's UI changes, re-check the `forever` branch (Blizzard_MapCanvas, Blizzard_SharedMapDataProviders, API docs) before assuming anything.
