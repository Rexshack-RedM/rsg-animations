# rsg-animations – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Commands
6. Database
7. Security
8. Server owner how-tos
9. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `oxmysql` |
| `shared/config.lua` | Open command and the animation list |
| `client/client.lua` | NUI bridge, playback, favourites cache, exports |
| `server/server.lua` | Favourites storage and validation |
| `server/versionchecker.lua` | GitHub version check |
| `ui/` | Vue NUI menu (`index.html`, `app.js`, `style.css`, `vendor/vue.js`) |
| `installation/rsg-animations.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- `/anim` opens the menu with category filters (Gestures, Dances, Emotes, Favourites) and live search.
- Three animation types: `Anim` (dictionary), `Emote` (native kit emote), `Scenario` (world scenario).
- Right-click a row or click the star to favourite. Favourites are saved per `citizenid` and cached on the client.
- Playback can be full body or upper body (upper body works on horseback) when played through the export.
- Notifications show when an animation can't play (dead, ragdolled, swimming) or the favourite limit is hit.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `CommandOpen` | `'anim'` | Command that opens the menu |
| `Animations` | list | The animations |

Animation entries:
```lua
{ Label = 'Gentle tip', Category = 'Gestures', Type = 'Anim', Dict = 'mech_loco_m@...', Body = 'idle_b', Flag = 31 },
{ Label = 'Wave', Category = 'Gestures', Type = 'Emote', EmoteType = 'KIT_EMOTE_GREET_GENTLEWAVE_1' },
{ Label = 'Sit', Category = 'Gestures', Type = 'Scenario', Scenario = 'WORLD_HUMAN_SIT_GROUND' },
```
`Label` must be unique (it is the favourite id, export argument and locale key). Optional `Flag`, `FullBodyFlag`, `HalfBodyFlag` set playback flags. Translate names with the key `anim_<label>` (lower-case, non-alphanumerics replaced with `_`), for example `Tip hat` → `anim_tip_hat`.

## 4. Exports and events
| Name | Side | Notes |
|---|---|---|
| `PlayAnimation(label, bodyMode?)` | client export | Play a configured animation by label; `bodyMode` `'full'` or `'upper'`; returns `true` or `false, reason` |
| `StopAnimation()` | client export | Stop the current animation |
| `rsg-animations:server:getFavorites` | callback | Returns the character's favourites |
| `rsg-animations:server:Favorite` | server event | `(label, favorite)`; validated and rate-limited |
| `rsg-animations:client:syncFavorite` | client event | `(label, state)` resync if a change was refused |

## 5. Commands
| Command | Who | What |
|---|---|---|
| `/anim` | everyone | Open the animation menu (name from `Config.CommandOpen`) |

## 6. Database
```sql
CREATE TABLE IF NOT EXISTS `favorites_animations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `favorites` longtext NOT NULL DEFAULT ('[]'),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Import `installation/rsg-animations.sql` if the table isn't created automatically.

## 7. Security
Only labels that exist in the config are stored, capped at 100 per character and rate-limited. The server caches each player's list and resyncs the menu if a change is refused.

## 8. How-tos
- Add an animation: add an entry to `Config.Animations` with a unique `Label`, then add `anim_<label>` to your locale files.
- Play from another script: `exports['rsg-animations']:PlayAnimation('Sit')`.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| Menu doesn't open | Check `CommandOpen` and that the resource started |
| Favourites not saving | Check the table exists and oxmysql is running |
| Name shows as the label | Missing `anim_<label>` locale key |
| Won't play | Player is dead, ragdolled or swimming |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-animations 3.0.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Database

Tables: `favorites_animations`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-animations.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database table automatically on start (set false and import installation/rsg-animations.sql for a ma |
| `Config.CommandOpen` | `'anim'` |  |
| `Config.Animations` | `table` |  |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `PlayAnimation` | `` | `client/client.lua` |
| `StopAnimation` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-animations']:PlayAnimation()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-animations:server:getFavorites` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-animations:server:getFavorites', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-animations:client:syncFavorite` | client | `label, state` | `client/client.lua` |
| `rsg-animations:server:Favorite` | server | `label, favorite` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-animations:server:Favorite', label, favorite)
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerUnload', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
