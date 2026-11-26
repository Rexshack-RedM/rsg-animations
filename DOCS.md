# rsg-animations – Docs (v3.2.1)

Technical reference for server owners and developers. Player-facing overview and install steps: [README.md](README.md).

## Contents
1. [Dependencies](#1-dependencies)
2. [Files and load order](#2-files-and-load-order)
3. [How it works](#3-how-it-works)
4. [Configuration](#4-configuration)
5. [Animation entries](#5-animation-entries)
6. [Commands and keys](#6-commands-and-keys)
7. [Exports](#7-exports)
8. [Events and callbacks](#8-events-and-callbacks)
9. [NUI protocol](#9-nui-protocol)
10. [Integrations](#10-integrations)
11. [Saving and database](#11-saving-and-database)
12. [Security model](#12-security-model)
13. [Performance](#13-performance)
14. [Locales](#14-locales)
15. [How-tos](#15-how-tos)
16. [Troubleshooting](#16-troubleshooting)

## 1. Dependencies
| Resource | Required | Used for |
|---|---|---|
| `rsg-core` 3.5.0+ | yes | Player data, callbacks, notifications, locales, `RegisterKey` |
| `oxmysql` | yes | Favourites |
| `rsg-radialmenu` | no | Walk tab and quick slot submenu |

Shared animations use server-side `GetPlayerPed` and `GetEntityCoords`, so the server needs OneSync.

## 2. Files and load order
| File | Side | Purpose |
|---|---|---|
| `shared/config.lua` | shared | All options and the animation list |
| `shared/access.lua` | shared | `HasAnimationAccess`, the job / gang rule |
| `client/client.lua` | client | Lookup, playback, exports, menu, favourites cache |
| `client/extras.lua` | client | Quick slots, recent, cancel hint, walk styles, `/e`, radial menu |
| `client/together.lua` | client | Shared animation requests and prompt |
| `server/server.lua` | server | Favourites table, validation and saving |
| `server/together.lua` | server | Shared animation invites and validation |
| `server/versionchecker.lua` | server | Compares the version with `rsg-versioncheckers` on start |
| `ui/` | NUI | Vue 3 menu and HUD cards (`vendor/vue.js` is bundled). Roboto loads from Google Fonts |
| `locales/*.json` | shared | Text and animation names |
| `installation/rsg-animations.sql` | | Manual database install |

`client/client.lua` creates the global table `RSGAnims`, which the other two client files use and extend, so it must stay first in `client_scripts`. It is internal to this resource; other resources use the [exports](#7-exports).

## 3. How it works

### Playback
Every route (menu, quick slot, `/e`, export, shared animation) goes through one function, which:
1. Finds the animation by label, alias or translated name.
2. Checks job / gang access.
3. Refuses if the player is dead, in last stand, cuffed, escorted, hogtied, lassoed, ragdolled, falling or swimming.
4. Applies the seated rule: on a horse or wagon, `Anim` and `Emote` are forced to upper body and `Scenario` is refused.
5. For `Anim`, loads the dictionary (1.5 s limit), then checks again. A newer play or stop cancels an older one that is still loading.
6. Clears the secondary task, and the primary task too for full body, then starts the animation.

| Type | How it is started |
|---|---|
| `Anim` | `TaskPlayAnim`, looped for as long as the flags say |
| `Emote` | `TASK_PLAY_EMOTE_WITH_HASH` (`0xB31A277C1AC7B7FF`) |
| `Scenario` | `TaskStartScenarioInPlace` |

Stopping is refused while restrained, because clearing tasks would let the player break free. On a horse or wagon only the secondary task is cleared, so the player isn't thrown off.

### Name matching
`/e`, `/animwith` and the export ignore case, spaces, underscores, hyphens, brackets and apostrophes. `Tip hat`, `tip_hat` and `TIPHAT` match the same entry. Labels, `Config.LabelAliases` and the translated name in the server's language all work.

### Menu
- Tabs: All, Gestures, Dances, Emotes, Favourites, Recent, Together, Walk. Together and Walk are hidden when they have nothing to show.
- **Esc** cancels slot assignment, then clears the search, then closes. **Enter** with search text uses the first result.
- Restricted animations are left out of the list for players without access.
- The menu won't open while dead or restrained, and closes within about half a second if that happens while it is open.
- With `AllowPushToTalkWhileOpen`, input is passed to the game and every control except those in `PushToTalkControls` is disabled while the menu is open.

### Now playing and cancel hint
The cancel key is read only while an animation from this resource is playing. It is a fixed key rather than a key mapping, so the hint always names the right one. The game's own action on that key is not blocked.

| Type | The hint clears when |
|---|---|
| `Anim` | the animation is no longer playing (checked after 1.5 s) |
| `Scenario` | the ped is no longer using a scenario (checked after 5 s) |
| `Emote` | `EmoteHintSeconds` have passed |

It also clears on stop, restraint or character unload.

### Shared animations
1. Player A uses the Together tab, the ⇄ button or `/animwith <name>`. The client picks the closest **visible** player within `Config.Shared.Distance`.
2. The server validates the request, stores an invite with a one-use token and sends it to player B.
3. B presses the accept or decline key within `Timeout` seconds. The keys are ignored while any NUI has focus or the game is paused.
4. On accept the server checks both players again and tells both clients to play.
5. Each client turns to face the other (unless seated) and plays the animation with its usual checks.

Positions aren't snapped together, so contact such as a handshake may not line up. After an ignored or declined request, A can't ask the same character again for `DeclineCooldown` seconds. B sees nothing in that time and A is told the player can't join.

## 4. Configuration
All in `shared/config.lua`. Restart the resource after changes.

| Option | Default | Meaning |
|---|---|---|
| `AutoDatabase` | `true` | Create the table on start |
| `CommandOpen` | `'anim'` | Command that opens the menu |
| `CommandPlay` | `'e'` | Play-by-name command; `''` disables |
| `CommandSlot` | `'animslot'` | Quick slot command |
| `CommandWith` | `'animwith'` | Shared request command; `''` disables the command only |
| `QuickSlots` | `6` | Slots per character, limited to 1-8 |
| `RadialMenu` | `true` | Add an Animations submenu to rsg-radialmenu |
| `RecentLimit` | `10` | Entries in the Recent tab |
| `ShowCancelHint` | `true` | Show the stop hint and read `CancelKey` while playing. `false` turns off both |
| `CancelKey` | `'BACKSPACE'` | Key name from `RSGCore.Shared.Keybinds`. An unknown name disables the hint and prints a warning |
| `EmoteHintSeconds` | `8` | How long an emote counts as playing |
| `Walkstyles` | 7 keys | Walk tab entries, in order |
| `UseKeyMapping` | `true` | Register rebindable keys through rsg-core `RegisterKey`. `false` means commands only |
| `OpenKey` | `''` | Default open key; `''` = unbound |
| `StopKey` | `''` | Default stop key; `''` = unbound |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the menu is open |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the menu is open |
| `LabelAliases` | 3 entries | `['Old label'] = 'New label'` |
| `Animations` | 214 entries | See [section 5](#5-animation-entries) |

### `Config.Shared`
| Option | Default | Meaning |
|---|---|---|
| `Enabled` | `true` | Turns shared animations on or off |
| `Distance` | `3.0` | Metres. The server allows 1 m extra for sync delay |
| `Timeout` | `15` | Seconds to answer. The server allows 1 s extra |
| `Cooldown` | `5` | Seconds between requests from one player |
| `DeclineCooldown` | `30` | Seconds before the same player can be asked again after no or a negative answer |
| `AcceptKey` | `'ENTER'` | Key name from `RSGCore.Shared.Keybinds` |
| `DeclineKey` | `'BACKSPACE'` | Key name from `RSGCore.Shared.Keybinds`. If either key name is unknown, no prompt is shown |
| `Animations` | 10 labels | Exact labels from `Config.Animations`. Unknown ones print a warning on start |

```lua
Config.Shared = {
    Enabled = true,
    Distance = 3.0,
    Timeout = 15,
    Cooldown = 5,
    DeclineCooldown = 30,
    AcceptKey = 'ENTER',
    DeclineKey = 'BACKSPACE',
    Animations = { 'Hand shake', 'Tip hat', 'Jig' },
}
```

## 5. Animation entries
The default list has 214 entries.

| Category | `Anim` | `Emote` | `Scenario` |
|---|---|---|---|
| Gestures | 67 | 0 | 18 |
| Dances | 13 | 12 | 0 |
| Emotes | 0 | 104 | 0 |

### Fields
| Field | Types | Required | Meaning |
|---|---|---|---|
| `Label` | all | yes | Unique id: favourites, slots, exports and the locale key |
| `Category` | all | yes | `'Gestures'`, `'Dances'` or `'Emotes'` |
| `Type` | all | yes | `'Anim'`, `'Emote'` or `'Scenario'` |
| `Dict` | Anim | yes | Animation dictionary |
| `Body` | Anim | yes | Clip name |
| `Flag` | Anim | no | Full body flag (default `0`). Not used for upper body |
| `FullBodyFlag` | Anim | no | Full body flag; takes priority over `Flag` |
| `HalfBodyFlag` | Anim | no | Upper body flag (default `31`) |
| `EmoteType` | Emote | yes | Kit emote name |
| `Scenario` | Scenario | yes | Scenario name |
| `Jobs` | all | no | `{ jobname = minimumGrade }` |
| `Gangs` | all | no | `{ gangname = minimumGrade }` |
| `DutyOnly` | all | no | The matching job must be on duty |

`DisplayName` is added at runtime; don't set it.

### One example of each type
```lua
{ Label = 'Gentle tip', Category = 'Gestures', Type = 'Anim', Dict = 'mech_loco_m@character@dutch@fancy@unarmed@idle@_variations', Body = 'idle_b' },
{ Label = 'Awkward', Category = 'Dances', Type = 'Emote', EmoteType = 'KIT_EMOTE_DANCE_AWKWARD_A_1' },
{ Label = 'Sit', Category = 'Gestures', Type = 'Scenario', Scenario = 'WORLD_HUMAN_SIT_GROUND' },
```
Only add dictionaries, clips, emotes and scenarios you have checked exist, for example in [rdr3_discoveries](https://github.com/femga/rdr3_discoveries).

### Job and gang restrictions
Add the fields to any entry. This example limits the existing `Guard` entry; keep its other fields as they are.
```lua
Jobs = { vallaw = 0, medic = 2 },  -- job name = minimum grade level
Gangs = { mygang = 0 },            -- gang name = minimum grade level
DutyOnly = true,                   -- applies to the job match only
```
Matching one job **or** one gang is enough. Only the character's active job and gang count. No entries are restricted by default.

The rule lives in `shared/access.lua`:
```lua
HasAnimationAccess(animation, playerData) -- truthy if allowed; playerData has .job and .gang
```

## 6. Commands and keys
| Command | What it does |
|---|---|
| `/anim` | Open the menu |
| `/e` | Open the menu |
| `/e <name> [upper]` | Play by name, for example `/e tip hat` or `/e jig upper` |
| `/e stop` | Stop the current animation |
| `/animslot <number>` | Play a quick slot |
| `/animwith <name>` | Ask the closest player to join, for example `/animwith hand shake` |

All commands are available to everyone; names come from the config.

| Key mapping | Default | Action |
|---|---|---|
| `rsganimations_open` | unbound | Open the menu |
| `rsganimations_stop` | unbound | Stop the current animation |
| `rsganimations_slot1` … `slotN` | unbound | Play a quick slot |

Players bind these in the game's key settings. They are ignored while the game is paused. Set a server default for open and stop:
```lua
Config.OpenKey = 'F6'
Config.StopKey = 'X' -- any key name your rsg-core RegisterKey accepts; check it isn't already in use
```

## 7. Exports
Both are **client** exports.

### `PlayAnimation(name, bodyMode)`
| Parameter | Type | Notes |
|---|---|---|
| `name` | string | Label, alias or translated name |
| `bodyMode` | string, table or nil | `'upper'` or `{ body = 'upper' }` for upper body; anything else is full body. Scenarios are always full body |

| Return | Meaning |
|---|---|
| `true` | Started |
| `false, reason` | Refused; `reason` is translated text |
| `false` (no reason) | Cancelled while loading: a newer play or stop arrived, or the player's state changed |

The export doesn't show a notification, so the caller decides what to do. It does update Recent and the now playing hint. The first use of an `Anim` can yield while the dictionary loads, so call it from a thread or event handler.

```lua
CreateThread(function()
    local ok, reason = exports['rsg-animations']:PlayAnimation('Tip hat', 'upper')
    if not ok and reason then
        RSGCore.Functions.Notify({ title = 'Animations', description = reason, type = 'error' })
    end
end)
```

### `StopAnimation()`
Returns `true` if tasks were cleared, or `false` if the player is restrained. It clears the ped's tasks even if this resource didn't start them, so don't call it during another script's task.
```lua
if not exports['rsg-animations']:StopAnimation() then
    -- the player is restrained
end
```

### Playing for a player from your server script
There are no server exports. Send your own event and use the export on the client:
```lua
-- your server script
TriggerClientEvent('myresource:client:celebrate', src)

-- your client script
RegisterNetEvent('myresource:client:celebrate', function()
    exports['rsg-animations']:PlayAnimation('Jig')
end)
```

## 8. Events and callbacks
These are internal. They are listed for debugging; use the exports from other resources.

### Callback
`rsg-animations:server:getFavorites` (server). No arguments. Returns an array of labels, or `false` if the character or database isn't available (the client retries on the next menu open).
```lua
-- client, inside a thread or event handler
local list = RSGCore.Functions.AwaitCallback('rsg-animations:server:getFavorites', 5000)
if type(list) == 'table' then
    print(('%d favourites'):format(#list))
end
```

### Server events
| Event | Arguments | Checks |
|---|---|---|
| `rsg-animations:server:Favorite` | `label, favorite` | Player, configured label, 100 limit, 100 ms between changes |
| `rsg-animations:server:invite` | `targetServerId, label` | See [section 12](#12-security-model) |
| `rsg-animations:server:respond` | `token, accepted` | Pending invite for the sender with that token |

It also listens for `playerDropped` and `RSGCore:Server:OnPlayerUnload` to clear its caches.

### Client events
| Event | Arguments | Sent by | Purpose |
|---|---|---|---|
| `rsg-animations:client:syncFavorite` | `label, state` | server | Restore a star after a refused change |
| `rsg-animations:client:invited` | `token, fromName, label` | server | Show the accept / decline prompt |
| `rsg-animations:client:together` | `partnerServerId, label` | server | Play an accepted shared animation |
| `rsg-animations:client:radialOpen` | none | rsg-radialmenu (local) | Open the menu |
| `rsg-animations:client:radialStop` | none | rsg-radialmenu (local) | Stop |
| `rsg-animations:client:radialSlot` | menu item with `.slot` | rsg-radialmenu (local) | Play a slot |

The client also handles `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `onClientResourceStart` and `onResourceStop`.

## 9. NUI protocol
For anyone restyling or replacing the UI.

### Lua to NUI (`SendNUIMessage`, by `type`)
| `type` | Fields |
|---|---|
| `Open` | `Animations` (`Label`, `DisplayLabel`, `Category`, `Type`, `Shared`), `Favorites`, `Locale`, `Slots`, `Recent`, `Walkstyles` (`key`, `label`), `CurrentWalk` |
| `Close` | none |
| `Slots` | `Slots`: one string per slot, `''` = empty |
| `Recent` | `Recent`: labels, newest first |
| `Walk` | `Current` |
| `NowPlaying` | `Name`, `Hint`; empty strings clear it |
| `Invite` | `Text`, `Hint`; empty strings clear it |
| `SetFavorite` | `label`, `favorite` |

### NUI to Lua
| Callback | Body |
|---|---|
| `Play` | `{ label, upper }` |
| `StopAnim` | `{}` |
| `Close` | `{}` |
| `Favorite` | `{ label, favorite }` |
| `SetSlot` | `{ slot, label }`; no `label` clears the slot |
| `Walk` | `{ key }` |
| `Invite` | `{ label }` |

## 10. Integrations

### rsg-radialmenu: quick slots
With `Config.RadialMenu = true`, the resource calls `exports['rsg-radialmenu']:AddOption(data, 'rsg-animations')` to add Open, Stop and each filled slot. It refreshes when a slot changes, a character loads or either resource starts, and removes the entry on unload or stop.

### rsg-radialmenu: walk styles
The Walk tab fires the local event below, so rsg-radialmenu validates, saves and syncs the style. The tab is hidden when that resource isn't started.
```lua
TriggerEvent('rsg-radialmenu:client:setWalkstyle', 'angry')
```
To add a style:
1. Add it to `Config.Walkstyles` in **rsg-radialmenu**.
2. Add the same key to `Config.Walkstyles` here.
3. Add `walk_<key>` to the locale files here.

rsg-radialmenu ignores changes made within its `WalkstyleCooldown`. This resource waits 2.1 s between changes to match its 2 s default; if you raise that value, update the check in `client/extras.lua` too.

## 11. Saving and database
| Data | Where | Per |
|---|---|---|
| Favourites | SQL table `favorites_animations` | character, follows the player |
| Quick slots, recent | client KVP `data_<citizenid>` | character, on that PC only |
| Selected tab, upper body toggle | NUI `localStorage` | PC |
| Walk style | saved by rsg-radialmenu | character |

No server-side KVP is used.

```sql
CREATE TABLE IF NOT EXISTS `favorites_animations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `favorites` longtext NOT NULL DEFAULT ('[]'),
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
`favorites` is a JSON array of labels, for example `["Tip hat","Jig"]`.

With `AutoDatabase = true` the table is created if missing. Existing tables are never altered or dropped, so a table made by an older version may not have the unique key. For a manual install, set it to `false` and import `installation/rsg-animations.sql`.

The server reads each character's row once and caches it. Writes for a character run one at a time and always save the latest list; a failed write is logged and retried with the next change. If your character deletion script cleans up related tables, include this one:
```sql
DELETE FROM `favorites_animations` WHERE `citizenid` = ?;
```

## 12. Security model
The resource never gives or takes money or items.

**Checked on the server**
- Favourites: only configured labels are stored, at most 100 per character, with a rate limit. Queries use `?` parameters. A load result is discarded if the character changed while it ran.
- Shared requests: feature enabled, integer target that isn't the sender, label in `Config.Shared.Animations`, sender cooldown, both characters exist, same routing bucket, distance, job / gang access for both, restraint metadata for both, no invite already pending for the target, and the per-pair `DeclineCooldown`.
- Accepting: the token must match the sender's pending invite, both citizen IDs must be unchanged, the invite must not have expired, and restraint and distance are checked again.

**Checked only on the client**
- All solo playback, including job and gang restrictions. A modified client can play any animation without this resource, so don't use restrictions as security.
- Native restraint states (cuffed, hogtied, lassoed). The server only sees metadata: `isdead`, `inlaststand`, `ishandcuffed`, `isescorted`.
- Visibility of the chosen partner.

The restraint checks stop the menu, keys, commands and exports being used to escape. They are not an anti-cheat.

**For other scripts:** if your script restrains players in its own way, set one of those metadata values or use the native cuff, hogtie or lasso states. Otherwise this resource can't tell the player is restrained.

## 13. Performance
There are no permanent loops.

| Loop | Runs while | Rate |
|---|---|---|
| Push-to-talk control filter | menu open, option on | every frame |
| Death / restraint watch | menu open | 500 ms |
| Cancel key and finish check | an animation is playing | every frame with the hint (state checked every 500 ms); 500 ms without it |
| Invite prompt | an invite is waiting | every frame |

Animation lookups and the menu list are built once when the resource starts.

## 14. Locales
11 languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. Set one in `server.cfg`:
```cfg
setr rsg:locale "en"
```
| Prefix | Used for |
|---|---|
| `anim_` | Animation names |
| `walk_` | Walk style names |
| `ui_` | Menu text |
| `err_` | Error notifications |
| `cmd_` | Chat suggestions |
| `key_` | Key setting names |
| `invite_` | Shared requests |
| `ver_` | Version checker |

Other keys: `hint_cancel` and `radial_open`.

To make an animation key, lower-case the label, replace each run of other characters with `_`, and trim `_` from both ends: `Tip hat` → `anim_tip_hat`. Without a key, the label is shown. Keep `%s` and `%d` placeholders in the same order in every file.

## 15. How-tos

### Add an animation
1. Add an entry with a unique `Label` to `Config.Animations`.
2. Add `anim_<label>` to the locale files.
3. Run `restart rsg-animations`.

### Rename or remove one
Add an alias so favourites, slots and export calls keep working:
```lua
Config.LabelAliases = {
    ['Old label'] = 'New label',
}
```
Keep the existing aliases. Rename the `anim_` locale key too, and update `Config.Shared.Animations` if the label is listed there. Recent entries under an old label are not shown until the animation is used again.

### Make an animation shareable
Add its exact label to `Config.Shared.Animations`. Test it with two players.

### Play an animation from an rsg-target option
```lua
exports['rsg-target']:addSphereZone({
    coords = vec3(0.0, 0.0, 0.0), -- your coordinates
    radius = 1.5,
    options = {{
        name = 'myresource:sit',
        icon = 'fa-solid fa-chair',
        label = 'Sit down', -- use locale() in a real script
        onSelect = function() exports['rsg-animations']:PlayAnimation('Sit') end,
    }},
})
```
Remember to remove the zone when your resource stops.

### Disable features
```lua
Config.CommandPlay = ''        -- no /e
Config.RadialMenu = false      -- no radial submenu
Config.ShowCancelHint = false  -- no hint and no cancel key
Config.Shared.Enabled = false  -- no shared animations
Config.Walkstyles = {}         -- no Walk tab
```

## 16. Troubleshooting
| Problem | Cause and fix |
|---|---|
| Menu doesn't open | Check the resource started and `CommandOpen`. It also won't open while dead or restrained |
| Menu closed by itself | The player died or was restrained |
| Animation won't play | Player is restrained, ragdolled, falling or swimming; scenarios don't work while mounted |
| "Not found" from `/e` or the export | Check the label or translated name in `Config.Animations` |
| Animation missing from the list | It has `Jobs` / `Gangs` restrictions the character doesn't meet |
| Favourites not saving | Check the table exists, oxmysql is running and the server console |
| Slots missing on another PC | Expected: they are stored on the player's PC |
| Name shows as the label | Missing `anim_<label>` locale key |
| Key does nothing | Unbound by default: set it in the config or the game's key settings |
| Changed default key has no effect | A player's saved binding takes priority over a new default |
| No Walk tab | rsg-radialmenu isn't started, or `Config.Walkstyles` is empty |
| No radial Animations entry | Check `Config.RadialMenu` and that rsg-radialmenu started |
| "No one close enough" | Stand within `Config.Shared.Distance`; invisible players are skipped |
| "Player can't join" | They are restrained, lack access, have a request waiting, or recently ignored or declined yours |
| No prompt appears | Check `AcceptKey` and `DeclineKey` are in `RSGCore.Shared.Keybinds` |
| Cancel hint stays after an emote | Lower `EmoteHintSeconds` |

Support: https://rexshack.tebex.store
