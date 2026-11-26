# Changelog

All notable changes to rsg-animations. Newest first.

## 3.2.1

### Fixed
- Favourite saves now run one at a time per character, so an update can't overtake the first insert. A failed insert is no longer treated as saved.
- The favourites callback could send an empty list when the player wasn't ready, which the client cached.
- Favourites loaded during a character switch could be applied to the new character.
- `Config.Shared.Distance` above 5 metres had no effect.
- The menu now closes if the player dies or is restrained while it is open.
- Holding Enter in the search box no longer repeats the action.

### Changed
- An ignored or declined shared request can't be repeated at the same player for `Config.Shared.DeclineCooldown` (30 s).
- Invisible players are never picked for shared requests.
- Unknown labels in `Config.Shared.Animations` print a warning.
- The job / gang rule is now in `shared/access.lua`; removed other duplicate code and unused CSS variables.
- Remaining gold-tinted borders now match the monochrome theme.
- DOCS.md rewritten with a full technical reference and examples. README export examples used a label that doesn't exist.

## 3.2.0

### Added
- `/e <name> [upper]` and `/e stop`. Names ignore case, spaces and punctuation, and translated names work.
- Quick slots (6 by default, saved per character on the player's PC): menu bar, `/animslot`, rebindable keys (unbound by default) and an `rsg-radialmenu` submenu.
- Recent tab and a "now playing" line.
- On-screen cancel hint with a fixed key (`Config.CancelKey`, Backspace).
- Walk tab, using `rsg-radialmenu` walk styles (hidden if it isn't running).
- Shared animations with an accept / decline prompt: Together tab, row button and `/animwith`. The server checks distance, routing bucket, restraint, access, cooldown and expiry.
- Optional `Jobs`, `Gangs` and `DutyOnly` restrictions on any animation.
- New files: `client/extras.lua`, `client/together.lua`, `server/together.lua`.

## 3.1.0

### Security
- The menu, Stop button and exports could call `ClearPedTasks` while a player was cuffed, hogtied, lassoed, dragged or dead, which could let them break free. These states are now blocked.

### Fixed
- A favourites request that timed out was cached as an empty list for the whole session.
- Running `/anim` twice while favourites loaded could open the menu twice.
- Two quick favourite events before the first database read finished could insert duplicate rows. Failed reads no longer leave the callback unanswered.
- The menu stayed on screen after a character unload.
- Push-to-talk was blocked while the menu was open.
- Playing or stopping on a horse or wagon could throw the player off: animations now play upper body there and scenarios are refused.
- A bad anim dictionary failed silently; if two animations were loading, the older one could win.
- Locale names: `Injured chest` (head animation) now reads "Injured head"; `Injured brystet` reads "Injured chest". Labels are unchanged.
- Fresh installs now get a `UNIQUE` key on `citizenid`, matching the txAdmin recipe. Existing tables are not altered.

### Added
- "Upper body only" toggle. It and the selected tab are remembered.
- Optional rebindable open and stop keys (`Config.UseKeyMapping`, `Config.OpenKey`, `Config.StopKey`, unbound by default).
- Search also matches the config label; Enter plays the first result; Escape clears the search before closing.
- `Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`, `Config.LabelAliases`.

### Changed
- Removed duplicates `Puke`, `Confident 2` and `Excited tip` (214 animations). Saved favourites and export calls using them are redirected.
- `shared/config.lua` is now one line per animation (about 1,450 lines down to 250). Merge any local additions.
- Client cleanup: the config table is no longer modified at runtime and only the fields the menu needs are sent to it.

## 3.0.2

### Fixed
- The `favorites_animations` table was never created by the resource, so favourites failed on a database without a manual import. It is now created on start.
### Added
- `Config.AutoDatabase` (default `true`); set `false` to import `installation/rsg-animations.sql` manually.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
