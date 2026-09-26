# MauGuildMap — guide for future work

Complete reference for the MauGuildMap addon: what it does, how it is built, why, and what was verified. Read it before changing anything. The target client, install loop, syntax check and Blizzard source branch are the same as for MauUndercut; see `../MauUndercut/CLAUDE.md` sections 2 and 3 (including the 2026-09 SavedVariables client bug).

## 1. What it is

Guild members running the addon broadcast their position, level and (unless they opt out) health, power and experience on the guild addon channel; everyone with the addon draws them as race icons with a class-coloured ring on Blizzard's world map (zone, continent and world views), optionally with a name label. Hovering shows name, level, race, class, the shared stats, zone and the age of the update. Members in an instance are drawn at the entrance (their last outdoor position), dimmed; dead members get a skull and stay where they died. No minimap. Members disappear on logout ("bye" message and guild presence), when they turn off sending, or after `NS.TIMEOUT` seconds without a message. All switches are in the game's Settings > AddOns panel (0.2.0); `/mgm` opens it.

## 2. Files and load order

| File | Role |
|---|---|
| `MauGuildMap.toc` | Load order: MauGuildMap.lua, Roster.lua, Comm.lua, MapPins.lua, Options.lua, MauGuildMap.xml, Test.lua. |
| `MauGuildMap.lua` | Namespace `NS` (also `_G.MauGuildMap`), constants (`SEND_INTERVAL` 2 s, `HEARTBEAT` 20 s, `TIMEOUT` 60 s), `NS.DEFAULTS` (every setting with its default), background detection, helpers (short names, class colours, race names, race atlas, ages, numbers, map names, `MaxLevel`, `SafeNumber` for protected values, `PowerInfo`, `HealthColor`), saved variables, event frame (login/logout), `/mgm` (opens the options; `test` and `list` are unannounced development commands). |
| `Options.lua` | `NS.Options`: the Settings > AddOns category (`Register` at `PLAYER_LOGIN`, `Open`, `OnChanged`). |
| `Roster.lua` | `NS.Roster`: members keyed by short name; `Update`, `Remove`, `Expire` (5 s ticker), `GetPositionOnMap`, `PrintList`, `CLUB_MEMBER_PRESENCE_UPDATED` handler. |
| `Comm.lua` | `NS.Comm`: wire format (`Encode`/`Decode`), position and stats sampling (`SampleOutdoor`, `FindEntrance`, `CurrentState`), send loop (`Tick`/`Send`/`ForceSend`/`SendBye`), receive (`OnMessage`, `OnForeground`, `CHAT_MSG_ADDON`). |
| `MapPins.lua` | `NS.Map`: data provider + pin mixin (icon, ring, label, skull, tooltip), `TryInit` (adds the provider to `WorldMapFrame`), `RequestRefresh`. Fills the global mixin tables the XML refers to. |
| `MauGuildMap.xml` | `MauGuildMapPinTemplate`: a 22×22 Frame with a 22×22 class-coloured `Ring` (white texture clipped by `RingMask`) under a 20×20 `Icon` texture clipped round by `CircleMask`, an 18×18 `Skull` overlay (`Interface\TargetingFrame\UI-TargetingFrame-Skull`, hidden by default) and a `Label` font string under the frame, `enableMouseMotion="true"`, `mixin="MauGuildMapPinMixin"`. |
| `Test.lua` | `NS.Test`: `/mgm test` simulation. |

### Settings (`MauGuildMapDB.settings`, defaults in `NS.DEFAULTS`)

| Key | Default | Meaning |
|---|---|---|
| `broadcast` | true | send my position at all |
| `shareHealth` / `sharePower` / `shareXP` | true | include those stats in what I send |
| `display` | true | draw the others on the map |
| `labels` | false | name labels under the icons |
| `ring` | true | class-coloured ring |
| `deathMarkers` | true | skull on dead members |
| `pinScale` | 1.0 | icon size, 0.6–1.6 |
| `showHealth` / `showPower` / `showXP` | true | what the tooltip shows (of what the other side shares) |

The settings table is passed to the Settings panel by reference (`Settings.RegisterAddOnSetting(category, "MauGuildMap_<key>", key, settingsTbl, VarType, name, default)` binds a checkbox straight to `settingsTbl[key]`), so `InitDB` creates it once and never replaces it. `Options:OnChanged(key)`: `broadcast` off → `SendBye`, on → `ForceSend`; `share*` → `ForceSend`; everything else → `Map:RequestRefresh`. Verified against `Blizzard_Settings_Shared/Blizzard_Setting.lua` (`AddOnSettingMixin`) and `Blizzard_SettingsDefinitions_Frame` (slider with `Settings.CreateSliderOptions` + `MinimalSliderWithSteppersMixin.Label.Right` formatter, `CreateSettingsListSectionHeaderInitializer` headers). `Settings.OpenToCategory(category:GetID())` opens it.

All files share `local _, NS = ...`. No libraries. Tabs.

## 3. Wire format and cadence

- Prefix `MauGuildMap` (registered with `C_ChatInfo.RegisterAddonMessagePrefix` at `PLAYER_LOGIN`), channel `"GUILD"`.
- Position message (0.2.0, version `3`): `3:<token>:<mapID>:<x>:<y>:<level>:<raceFile>:<sex>:<classFile>:<flags>:<hp>:<hpMax>:<power>:<powerMax>:<powerType>:<xp>:<xpMax>:<instanceName>`; `token` is a random hex id chosen at login (`Comm.token`; test members use `0`), x/y are map coordinates × 10000; `flags` is `O` (outdoors) or `I` (in an instance: position = entrance) plus `D` when dead (position = where they died, frozen in `Comm.deathPos` until alive); the seven stat fields are whole numbers or empty (not shared, at max level, or protected), `powerType` is the `Enum.PowerType` number; the instance name is last so it may contain anything. `B` alone = goodbye. Typical length 70–90 bytes (limit 255). Older versions are rejected by the decoder.
- **Protected values**: `UnitHealth` is documented `SecretReturns = true` and `UnitHealthMax`/`UnitPower`/`UnitPowerMax` `SecretWhen...Restricted` on this client, i.e. they can return secret values (in combat / restricted situations) that cannot be formatted, compared or sent. `NS.SafeNumber` returns nil for those (`issecretvalue` check, type check, `pcall(math.floor)`), and nil is sent as an empty field, so the tooltip simply omits the line while the value is protected. `UnitXP`/`UnitXPMax` carry no secret flag.
- Change detection (`Changed`): flags, map, level, instance, position by more than 0.0005, or health by ten percentage points (`HEALTH_EPSILON`). Power and experience changes ride along with the next send and do not trigger one. `PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST` force the next tick to send.
- Own messages: the guild channel echoes them back. 0.1.0 compared the short sender name with `UnitName("player")` and the user still saw their own pin; 0.1.1 adds the token, which is compared first, and the name comparison is case-insensitive as a second net.
- Every `SEND_INTERVAL` (2 s) `Comm:Tick` samples the state and sends when something changed (see "Change detection" below), or when `HEARTBEAT` (20 s) has passed. `PLAYER_LOGOUT` and switching "Send my position" off send `B`. Not sent when `IsInGuild()` is false or `settings.broadcast` is false.
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
- Pin: `SetScalingLimits(1, 1.0, 1.0)` gives a constant on-screen size at any zoom (`ApplyCurrentScale` = 1 / canvas scale × global pin scale). Frame level `PIN_FRAME_LEVEL_AREA_POI`: Blizzard's world map registers its pin levels in ascending order in `Blizzard_WorldMap.lua` (dungeon entrances, flight points, ..., area POIs, gossip, ..., quest offers, world quests, active quests, ..., group members, corpse), and the user wants quest markers always in front, so member pins sit at the area-POI level: above entrances and flight points, below everything quest-related (2026-09-25). `PIN_FRAME_LEVEL_GROUP_MEMBER` was the original choice. Icon via `GetRaceAtlas(lowercase raceFile, "male"|"female")` → `raceicon-<race>-<gender>` (`scourge` is mapped to `undead` by Blizzard's helper), checked with `C_Texture.GetAtlasInfo`, question-mark icon as fallback. The icon is 20 px in a 22 px pin and is drawn zoomed in by 30% (`ICON_ZOOM`): the atlas region's texture coordinates from `GetAtlasInfo` (`file`/`filename`, `left/right/top/bottomTexCoord`) are shrunk 15% on every side and applied with `SetTexture` + `SetTexCoord`, so the rim of Blizzard's round icon stays out of the picture (user request 2026-09-25). The icon is clipped to a circle by a `MaskTexture` (`Interface\CharacterFrame\TempPortraitAlphaMask`, CLAMPTOBLACKADDITIVE wrap, `MaskedTexture childKey="Icon"`), the same construct Blizzard's Communities portraits use. Behind it a 22 px `Ring` texture (`Interface\Buttons\WHITE8X8`, clipped by its own copy of the circular mask, tinted with the member's class colour in `OnAcquired`) shows as a 1 px class-coloured border; the pin frame is 22 px. In-instance members are desaturated and at 80% alpha.
- Data provider: `RefreshAllData` releases all pins of the template and re-acquires one per placeable member (cheap for guild sizes); with `settings.display` false it stops after releasing, so turning the display off clears the map while the roster keeps running and turning it on is instant.
- Per-pin settings (0.2.0) are applied in `OnAcquired`, which runs on every refresh: `SetScalingLimits(1, pinScale, pinScale)` then `ApplyCurrentScale()`, `Ring:SetShown(ring)`, `Label` (name in class colour, `labels`), `Skull:SetShown(dead and deathMarkers)` with the icon desaturated. Tooltip lines for health (coloured by `HealthColor`), power (`PowerInfo` name and `PowerBarColor`) and experience (plus "N to level L+1") appear only when the entry has the values and the viewer's `show*` setting is on. It runs on map change/show (Blizzard), on every roster change while the map is shown (`Map:RequestRefresh`, coalesced to 0.25 s) and every 5 s while shown (ages, timeouts).

## 5b. Background handling (0.1.1)

- There is no focus API in this client (checked the API docs for focus/background/foreground events and functions). The client caps the frame rate while the window is in the background ("Max Background FPS", 8 by default), so `MauGuildMap.lua` keeps an exponentially smoothed frame time (factor 0.1) in an OnUpdate and calls it background when the average exceeds 0.1 s (under 10 fps). Single hitches do not flip it; a real background cap does within ~2 s, and it flips back within a few frames of returning. `NS.IsBackground()` exposes it.
- While in the background: `Comm:Tick` samples nothing and only sends the last state as a heartbeat every `HEARTBEAT` (so guild mates keep the pin); `Comm:OnMessage` stores the latest message per sender in `Comm.queue` instead of decoding it; `Roster:Expire` does nothing; the map's 5 s refresh ticker and `Map:RequestRefresh` do nothing. On return `Comm:OnForeground` replays the queue and forces a send.
- Also in 0.1.1: the encounter journal entrance lookup (`FindEntrance`) runs once per instance (`entranceLookedUpFor`), not every tick.
- Background context: the user reported lag and even client crashes while alt-tabbed, at roughly the addon's 2 s tick. Not proven to be the addon (the Forever beta client has its own crash history), but the addon now does close to nothing while the window is in the background.

## 6. Roster

- Keys are short names (`Ambiguate(name, "short")`) for both `CHAT_MSG_ADDON` senders ("Name-Realm") and club member names.
- Removal: `B` message; `CLUB_MEMBER_PRESENCE_UPDATED(clubId, memberId, presence)` with `presence == Enum.ClubMemberPresence.Offline` and `clubId == C_Club.GetGuildClubId()` (name from `C_Club.GetMemberInfo`); `Expire` every 5 s drops entries older than `TIMEOUT`.
- Test entries carry `entry.test = true`; removal reasons are printed only for those.

## 7. Test mode (`/mgm test`)

Eight fake members (races by the player's faction) spread over the Eastern Kingdoms, fed through `Comm:OnMessage(text, name, true)` so decoding, roster, pins on zone/continent/world maps, tooltips, entrance display, goodbye and timeout all use the production path. Since 0.2.0 each has health, power (type by class: warriors rage, rogues energy, the rest mana) and experience that move about (`UpdateStats`); Testfrank shares no health or power, Testdave no experience, Testcarol is level 60 (no experience by rule); Testgwen dies at 45 s (flag `D`, frozen position, skull) and gets up at 75 s. `/mgm test` is not mentioned in the options or the README's command list on purpose. Everything is looked up from map data at start: the continent by name among `C_Map.GetMapChildrenInfo(947, Continent)` (fallback 1415), its zones via `GetMapChildrenInfo(continent, Zone)`, cities and wander zones by English name with any other zone as fallback, dungeon entrances from `C_EncounterJournal.GetDungeonEntrancesForMap` over all zones (preferred names first; if the journal has nothing, zone centres with made-up names and a chat note). Roles: 2 `city` idlers (heartbeat every `HEARTBEAT`), 3 `dungeon` (flag `I`, real entrance name, heartbeats), 3 `wander` (random walk of 0.4% per second in zone coordinates, sent every `SEND_INTERVAL`). At 60 s Testcarol sends goodbye and Testalice goes silent (dropped at 60 + `TIMEOUT`); the test stops itself 8 s later; `/mgm test` again stops early.

## 8. Decisions made with the user (2026-09-25)

- Guild-wide addon messages, no proximity needed; world map only, no minimap.
- Members in a dungeon are shown at the entrance.
- Near-realtime updates (2 s while moving), removal on logout and after a timeout without updates.
- `/mgm test` simulation because no second tester was available.
- Broadcasting can be switched off since positions go to the whole guild.
- 2026-09-26: all switches moved to the game's Settings > AddOns panel; `/mgm` opens it and no chat command list is printed any more (`test`/`list` stay as unannounced development commands). Health, power and experience are shared and shown by default, each side can opt out per stat (privacy switches). Death markers wanted. Name labels default off.

## 9. How to verify

1. Syntax: node + luaparse over every `.lua`; XML well-formed.
2. `/mgm test` outdoors, open the map: three icons near you, moving; hover for tooltips; at 20 s Testbob dims and stops; at 30 s Testcarol vanishes; at 90 s Testalice vanishes; ~98 s "Test finished".
3. With a guild mate: both log in, `/mgm` shows 1 member, icon on the map moves with them; they enter a dungeon → icon at the portal, tooltip says the instance; they log out → icon gone within a few seconds.
4. If Blizzard's UI changes, re-check the `forever` branch (Blizzard_MapCanvas, Blizzard_SharedMapDataProviders, API docs) before assuming anything.
