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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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

Support: https://buymeacoffee.com/rexshack
