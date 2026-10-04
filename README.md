<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 💃 rsg-animations
**Emote & animation menu for RedM (RSG Core).**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> A Vue.js animation menu that lets players play gestures, dances, emotes and scenarios, and save their favourites per character.

---

## 🛠️ Dependencies
- **rsg-core** – framework & player data
- **ox_lib** – locales, callbacks, anim dict loading
- **oxmysql** – favourites storage

---

## ✨ Features
- 💃 **NUI menu** in the RDR2 leather & gold style, with category filters (Gestures, Dances, Emotes, Favourites) and live search
- ⭐ **Favourites** – right-click a row or click the star; saved per `citizenid` and cached client-side
- 🎭 **Three animation types** – `Anim` (dictionary), `Emote` (native kit emote), `Scenario` (world scenario)
- 🧍 **Full or upper-body playback** via the export (upper body works on horseback)
- 🌍 **Translated** – en, de, el, es, fr, ja, nl, pl, pt-br, ro (menu text *and* animation names)
- 🔒 **Server-validated favourites** – only labels from the config are stored, capped and rate-limited

---

## 📂 Installation
1. Place `rsg-animations` in your `resources/[rsg]` folder.
2. Import `installation/rsg-animations.sql`.
3. Add to `server.cfg` (after its dependencies):
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-animations
   ```
4. Restart the server and use `/anim` in-game.

---

## 🌍 Language
Set the ox_lib locale in `server.cfg`:
```cfg
setr ox:locale "en"   # en, de, el, es, fr, ja, nl, pl, pt-br, ro
```
Translations live in `locales/*.json`. Animation names use the key `anim_<label>` (lower-case, non-alphanumerics replaced with `_`), e.g. `Tip hat` → `anim_tip_hat`. If a key is missing the config `Label` is shown.

---

## ⚙️ Configuration (`shared/config.lua`)
```lua
Config.CommandOpen = 'anim' -- command that opens the menu

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
> ⚠️ `Label` must be unique. Renaming a label removes it from players' saved favourites.

---

## 🧩 Exports (client)
```lua
-- play by label; body = 'full' (default) or 'upper'
local ok, err = exports['rsg-animations']:PlayAnimation('Wave')
exports['rsg-animations']:PlayAnimation('Wave', 'upper')

-- stop whatever is playing
exports['rsg-animations']:StopAnimation()
```

---

## 🕹️ Usage
- `/anim` opens the menu, **Esc** closes it.
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
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Existing installs can add the index with:
```sql
ALTER TABLE `favorites_animations` ADD INDEX `citizenid` (`citizenid`);
```

---

## 🗂️ Files
- `client/client.lua` – menu, NUI callbacks, playback & exports
- `server/server.lua` – favourites storage & validation
- `server/versionchecker.lua` – GitHub version check
- `shared/config.lua` – command & animation list
- `locales/*.json` – translations
- `ui/` – Vue.js front-end
- `installation/rsg-animations.sql` – table

---

## 💎 Credits
- **XakraD** — original creator · https://github.com/XakraD
- **RSG / Rexshack-RedM** — adaptation & maintenance · https://github.com/Rexshack-RedM
- Community contributors & translators
- License: GPL-3.0
