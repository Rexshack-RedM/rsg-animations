<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 💃 rsg-animations
**Emote & animation menu for RedM (RSG Core).** · v3.2.1 · [Full docs](DOCS.md)

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> A Vue.js animation menu that lets players play gestures, dances, emotes and scenarios, and save their favourites per character.

---

## 🛠️ Dependencies
- **rsg-core** – framework, player data, callbacks, notifications & locales
- **oxmysql** – favourites storage

---

## ✨ Features
- 💃 **NUI menu** in the RDR2 leather & gold style, with category filters (Gestures, Dances, Emotes, Favourites) and live search
- 🔢 **Quick slots** – menu bar, `/animslot`, rebindable keys and an `rsg-radialmenu` submenu
- 💬 **`/e <name>`** – play from chat
- 🕘 **Recent, now playing and a cancel hint** (Backspace by default)
- 🚶 **Walk tab** – uses `rsg-radialmenu` walk styles (optional)
- 🤝 **Shared animations** – ask the closest player; they must accept
- 👮 **Job / gang restrictions** per animation (optional)
- ⭐ **Favourites** – right-click a row or click the star; saved per `citizenid` and cached client-side
- 🎭 **Three animation types** – `Anim` (dictionary), `Emote` (native kit emote), `Scenario` (world scenario)
- 🧍 **Full or upper-body playback** via the menu toggle or export; on a horse or wagon animations are always upper body
- 🔗 **Restraint-safe** – can't be used to escape cuffs, hogties, lassos or escorting
- 🎙️ **Push-to-talk** keeps working while the menu is open
- ⌨️ **Optional keys** to open the menu and stop animations, rebindable in the game's key settings
- 🌍 **Translated** – en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (menu text *and* animation names)
- 🔒 **Server-validated favourites** – only labels from the config are stored, capped at 100 and rate-limited; the server caches each player's list and resyncs the menu if a change is refused
- 🔔 **Feedback** – rsg-core notifications when an animation can't play (dead, restrained, ragdolled, falling, swimming, scenario while mounted) or the favourite limit is hit

---

## 📂 Installation
1. Place `rsg-animations` in your `resources/[rsg]` folder.
2. The database table is created automatically on first start (or set `Config.AutoDatabase = false` and import `installation/rsg-animations.sql`).
3. Add to `server.cfg` (after its dependencies):
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-animations
   ```
4. Restart the server and use `/anim` in-game.

---

## 🌍 Language
Set the rsg-core locale in `server.cfg` (falls back to `ox:locale`, then `en`):
```cfg
setr rsg:locale "en"   # en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru
```
Translations live in `locales/*.json`. Animation names use the key `anim_<label>` (lower-case, non-alphanumerics replaced with `_`), e.g. `Tip hat` → `anim_tip_hat`. If a key is missing the config `Label` is shown.

---

## ⚙️ Configuration (`shared/config.lua`)
```lua
Config.AutoDatabase = true   -- create the table on start
Config.CommandOpen = 'anim'  -- command that opens the menu
Config.UseKeyMapping = true  -- register the two rebindable keys below
Config.OpenKey = ''          -- key name such as 'F6'; '' = unbound until the player sets it
Config.StopKey = ''
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = { 0x4BC9DABB }
Config.CommandPlay = 'e'
Config.CommandSlot = 'animslot'
Config.CommandWith = 'animwith'
Config.QuickSlots = 6
Config.RadialMenu = true
Config.RecentLimit = 10
Config.ShowCancelHint = true
Config.CancelKey = 'BACKSPACE'
Config.EmoteHintSeconds = 8
Config.Walkstyles = { 'normal', 'angry' }                   -- keys from rsg-radialmenu
Config.Shared = { Enabled = true, Distance = 3.0, --[[ see config.lua ]] }
-- per animation (optional): Jobs = { vallaw = 0 }, Gangs = { mygang = 0 }, DutyOnly = true
Config.LabelAliases = { ['Puke'] = 'Throw up' } -- redirect removed or renamed labels

Config.Animations = {
    {
        Label = 'Tip hat',         -- unique id (used for favourites, export & locale key)
        Category = 'Emotes',       -- 'Gestures' | 'Dances' | 'Emotes'
        Type = 'Emote',            -- 'Anim' | 'Emote' | 'Scenario'
        EmoteType = 'KIT_EMOTE_GREET_HAT_TIP_1',
    },
    {
        Label = 'Cross Arms',
        Category = 'Gestures',
        Type = 'Anim',
        Dict = 'mech_skin@buck@butcher',
        Body = 'trans_to_stoic_butcher',
        Flag = 30,                 -- optional; FullBodyFlag / HalfBodyFlag override per mode
    },
    {
        Label = 'Example scenario',
        Category = 'Gestures',
        Type = 'Scenario',
        Scenario = 'WORLD_HUMAN_SIT_GROUND',
    },
}
```
> ⚠️ `Label` must be unique. When renaming or removing one, add it to `Config.LabelAliases` to keep players' favourites.

---

## 🧩 Exports (client)
```lua
-- play by label; body = 'full' (default) or 'upper'
local ok, err = exports['rsg-animations']:PlayAnimation('Tip hat')
exports['rsg-animations']:PlayAnimation('Tip hat', 'upper')

-- stop whatever is playing
exports['rsg-animations']:StopAnimation()
```

---

## 🕹️ Usage
- `/anim` (or your bound key) opens the menu. **Esc** clears the search, then closes. **Enter** plays the first search result.
- Tick **Upper body only** to keep your legs free.
- `/e tip hat`, `/e jig upper`, `/e stop`.
- Press ✚ on an animation, then a slot. Right-click a slot to clear it. Slot keys are unbound until set in the game's key settings.
- **Together** tab, ⇄ or `/animwith hand shake` asks the closest player. They press Enter to accept or Backspace to decline. An ignored or declined request can't be repeated at the same player for 30 seconds (`Config.Shared.DeclineCooldown`).
- Backspace stops the current animation while the hint is showing.
- Left-click a row to play; right-click or click the star to (un)favourite.
- The bottom button stops the current animation.

---

## 💾 Database
```sql
CREATE TABLE IF NOT EXISTS `favorites_animations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `favorites` longtext NOT NULL DEFAULT ('[]'),
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
---

## 🗂️ Files
- `client/client.lua` – menu, NUI callbacks, playback & exports
- `client/extras.lua` – quick slots, recent, cancel hint, walk styles, `/e`, radial menu
- `client/together.lua`, `server/together.lua` – shared animations
- `server/server.lua` – favourites storage & validation
- `server/versionchecker.lua` – GitHub version check
- `shared/config.lua` – options & animation list
- `shared/access.lua` – job / gang rule
- `locales/*.json` – translations
- `ui/` – Vue.js front-end
- `installation/rsg-animations.sql` – table

---

## 💎 Credits
- **XakraD** — original creator · https://github.com/XakraD
- **RSG / Rexshack-RedM** — adaptation & maintenance · https://github.com/Rexshack-RedM
- Community contributors & translators
- License: GPL-3.0

---

Support: https://rexshack.tebex.store
