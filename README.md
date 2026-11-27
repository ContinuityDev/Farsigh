# Farsigh — Outpost Liberation

Godot **4.3** first-person stealth shooter inspired by Far Cry 5 outpost liberation. Pick an outpost on the Hope County map, customize a **2-slot** firearm loadout (up to 3 carried weapons via the weapon wheel) at the Gunsmith, hire Guns-for-Hire allies, and liberate every outpost stealthily or loud. Runs on **PC** (Windows / Linux / macOS), **mobile** (Android / iOS), and in the **browser** with the **GL Compatibility** renderer and full touch controls.

## Play in browser

**[Play Farsigh](https://continuitydev.github.io/Farsigh/)** — no download required (GitHub Pages Web export, no threads so it works without COOP/COEP headers).

On desktop browsers: click the game once to capture the mouse. On phones: touch controls appear automatically.

## What's inside

### 8 Outposts (Standard → Boss) & Map Select
- **Hope County Compound** — Standard · 8 hostiles.
- **Seed Family Ranch** — Standard · 10 hostiles.
- **Baron Lumber Mill** — Standard · 10 hostiles.
- **Whitetail Bait & Dock** — Standard · 10 hostiles.
- **Jacob's Ridge Bunker** — Hard · 12 hostiles.
- **Eden's Gate Fortress** — Extreme · 13 hostiles · cameras, searchlights, tripwires, keycard doors (unlocks after Compound + Ranch).
- **Holland Valley Labour Camp** — Extreme · 12 hostiles · searchlights & cameras (unlocks after Mill + Dock).
- **Joseph's Cathedral HQ** — Boss · 12 hostiles · elite commander (unlocks after Ridge).
- Difficulty labels on Outpost Select; Hope Dollar clears scale with difficulty (Extreme/Boss pay more). Replay beaten compounds at 50% payout.
- Roles: **heavies**, **officers**, **commanders**, **dogs** + **handlers**, rooftop **snipers**, multi-storey **interior** patrols.
- AI LOD + staged loading screen keep mobile WebGL workable.
- **Hope Dollars** shop: weapons, items, **paid gunsmith attachments** (suppressor free), **persistent armour tiers**, **Guns for Hire** allies, and **buyable consumable supports** (Recon Drone, Mortar, Fangs, EMP, Overwatch, Gunship). Charges save to profile; New Run starts at zero. Free binoculars tagging (+ Pro upgrade in shop).
- Liberation saves per outpost (`user://outpost_save.json`) and resets on **New Run**.
- **Player vitals**: 160 HP with regen after 4s out of combat; armour bar from shop upgrades (DR + capacity). Field Plate Insert remains a one-deploy HP buff.

### Multi-Storey Buildings & Runtime NavMesh
- Multi-room & multi-storey structures with interior partitions, stairs, reachable parapet rooftops, drive-in garages, an underground bunker basement, cutout see-through glass windows, and interactive hinged doors (`E` to toggle, guards auto-open them).
- Synchronous runtime `NavigationMesh` baking per outpost with `NavigationAgent3D` steering so guards patrol, investigate, and flank across rooms and floors.

### Animations & Player Movement
- **Guards**: front & back takedown animations, investigate, look-around, radio-call, and alarm-press animations with smooth `AnimationPlayer` cross-fading.
- **Player**: low-wall vaulting/climbing (`Space` near low cover), wall-safe lean/peek left & right (`Z` / `V`), weapon inspect (`I` / `T`), standing shoulder-carry & crouched body-drag viewmodel motion, and smooth ADS/sway/recoil transitions.

### Aim Down Sights (ADS)
- Hold Aim (RMB / LT / touch Aim) to raise the viewmodel from hip to sights — iron sights by default, or red dot / holo / scope when fitted in the Gunsmith.
- True optic zoom vs hip FOV 70°: **red dot 1.5×** (~46.7°), **holo 2×** (35°), **scope 4×** (17.5°) with sniper Adjust Zoom cycling **4× → 6× → 8×** (mouse wheel / `N` on PC; touch **ZOOM** while ADS).
- Scope overlay + breath-hold sway dampening for magnified scopes. Crosshair hides in ADS. Gunsmith optic choice persists into the field.
- Mobile touch actions are contextual: Takedown / Reload / Use / Rock / ZOOM / Binos only show when usable (no dead buttons).

### Arsenal — 2 Weapon Slots + Weapon Wheel
- Carry up to **3 firearms** in the loadout pool; equip any two into **Slot 1 / Slot 2**.
- Hold **TAB** (long-press **Swap** on mobile) for the radial weapon wheel (slight time slow) — mouse/stick aim, release to assign into the active slot.
- Keys **1 / 2** or short **Swap** switch between the two slots.
- **Gunsmith**: paid attachments locked until bought (🔒 + price). **Suppressor is always free.** Advanced Mod Kit unlocks the full set.
- **Melee**: Kukri / Bat + F takedowns.

### Gadgets & Lethals
- **Gadgets** (Q or T / touch GADGET): rocks, lures, smoke, decoys, alarm jammer — tap to use, hold for mini-wheel.
- **Lethals** (G / touch LETHAL): throwing knives (silent, retrievable, one-shot headshot), frags, molotovs, C4, prox mines, throwing axes — tap to throw, hold for mini-wheel.
- HUD shows selected gadget/lethal and remaining counts. Touch buttons only appear when you own at least one.

## How to run locally

1. Open this folder in Godot **4.3+** (`project.godot`).
2. Press **F5** (or Play). Main menu loads first.
3. Choose **New Run** or **Outpost Map** → open **Gunsmith & Loadout** → **Deploy**.

### Controls (PC)

| Action | Keyboard / Mouse | Gamepad |
|--------|------------------|---------|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Jump / Vault low wall | Space | A |
| Sprint | Shift | L3 |
| Crouch | Ctrl | B |
| Lean / Peek Left & Right | Z / V | — |
| Fire / Throw / Swing | LMB | RT / RB |
| Aim / ADS (iron, optic, or scope) | RMB hold | LT |
| Adjust Zoom (sniper 4/6/8×) | Mouse wheel or N while ADS | — |
| Breath-hold (steady scope) | Shift while ADS | L3 while ADS |
| Reload | R | Y |
| Weapon inspect | I | — |
| Interact / door / body / alarm / revive ally | E | X |
| Takedown (front or back) | F | R3 |
| Lethal (tap throw / hold wheel) | G | Select / Back |
| Gadget (tap use / hold wheel) | Q or T | — |
| Weapon wheel (hold) | Tab | — |
| Switch weapon slot | 1 / 2 or Swap | D-pad right |
| Ally command cycle | H | — |
| Drop carried body | X | — |
| Pause / Gunsmith shortcut | Esc | Start |

### Controls (Mobile / mobile browsers)

Touch controls appear automatically on native mobile and on web builds when a touchscreen is available (preview on desktop with `TOUCH_UI=1 godot --path .`):

- **Left virtual stick** — move
- **Right-side swipe** — look
- **Always-on** — move stick, look, `FIRE`, `AIM`, `JUMP/VLT`, `CROUCH`, `SPRINT`, `PEEK L/R`, `SWAP`
- **Contextual** — `TAKEDOWN` (enemy in range), `RELOAD` (mag not full + reserve), `USE` (interactable/body), `ROCK` (rocks left), `ZOOM` (ADS + variable scope), `BINOS` (hidden while ADS), `INSPECT`
- **Settings** (main menu + pause): separate **Mouse Look** / **Touch Look** sliders with live %, **ADS/Scope** multiplier, optional **4×/6×/8×** scope mults, **Invert Y**, graphics quality, Touch Aim Hold/Toggle, Tap-to-Fire, Fullscreen. Saved to `user://loadout_prefs.json` and applied live.
- **Controls** (Settings → Controls…): full PC rebind list (movement, peek, fire/aim, reload, swap, Tab wheel, Q/T gadget, G lethal, binos, zoom, ally command, use/revive, inspect, takedown…), click-then-press with conflict warnings + Reset Defaults; Mobile/Touch help for contextual buttons; touch button size/opacity + sensitivity sliders. Overrides save to the profile.
- **Foliage**: natural bush clusters (3–8) of crossed alpha-cut leaf cards with grass bases + matching hide zones along fences, building edges, and approach routes (cheap on mobile).
- **Natural sets**: uneven mounds, dirt paths, scattered crates/sandbags/barrels/logs/rocks/debris along routes and yards for stealth cover and firefights.
- **Overlook houses**: every compound has an accessible upper floor/rooftop vantage (stairs) with sandbag nest for scouting/sniping.
- **Day/night cycle**: dynamic sun/moon + sky; configurable cycle length & start time in pause settings. Night cuts guard vision, turns on compound floodlights + player flashlight, and deepens hide shadows.
- **Map border**: dense forest treeline + shrubbery (no edge walls); soft invisible push-back past the trees.
- **Death**: hit-location guard deaths (head / back / explosion / body) + player camera tip-over fade before menu (one-shot `is_down` kept).
- **Iron sights**: rear/front aligned to screen centre at ADS with ~1.2× zoom.

- Look-swipes never fire — mouse-from-touch stays on so menus/gunsmith respond to taps, but fire/aim ignore mouse while the touch UI is up; only the on-screen **FIRE** button shoots (PC LMB unchanged)
- **BINOS** stays tappable while raised (toggle down); pinch or overlay **±** zoom; PC **B** + wheel still work
- Per-guard **?** / **!** awareness meters; hearing → investigate only (never instant spot); delayed interruptible shout/radio (~1.5–3s)
- Crouch in bushes/tall grass → HUD **HIDDEN**; MultiMesh foliage + wind/water/rim shaders on Medium/High quality


## Screenshots

Captured from a running Godot 4.3 session (`AUTO_CAPTURE=1`):

| | |
|--|--|
| Hope County Outpost Select | ![Outpost Select](docs/screenshots/01_map_select.png) |
| 5-Slot Gunsmith & Live 3D Preview | ![Gunsmith Workbench](docs/screenshots/02_gunsmith_workbench.png) |
| Seed Family Ranch (Modded AR-C) | ![Seed Family Ranch](docs/screenshots/03_ranch_redbarn.png) |
| Baron Lumber Mill (Explosive Compound Bow) | ![Baron Lumber Mill](docs/screenshots/04_lumber_mill_bow.png) |
| Whitetail Bait & Dock (Molotov Cocktail) | ![Whitetail Bait & Dock](docs/screenshots/05_river_dock_molotov.png) |
| Jacob's Ridge Bunker (Helipad & Radar) | ![Jacob's Ridge Bunker](docs/screenshots/06_hilltop_bunker.png) |
| Multi-Storey Interior Window & Weapon Inspect | ![Interior Inspect](docs/screenshots/07_interior_inspect.png) |
| Mobile Touch Controls & Kukri Machete | ![Touch Controls](docs/screenshots/08_touch_controls.png) |
| ADS Holo Sight (2×) | ![ADS Holo](docs/screenshots/09_ads_holo.png) |
| ADS Red Dot (1.5×) | ![ADS Red Dot](docs/screenshots/12_ads_red_dot.png) |
| ADS Iron Sights | ![ADS Iron](docs/screenshots/17_ads_iron.png) |
| Sniper Scope 4× | ![Sniper 4x](docs/screenshots/13_sniper_4x.png) |
| Sniper Scope 8× | ![Sniper 8x](docs/screenshots/14_sniper_8x.png) |
| Mobile HUD (decluttered) | ![Mobile HUD](docs/screenshots/15_mobile_hud_no_takedown.png) |
| Mobile HUD + Takedown | ![Mobile Takedown](docs/screenshots/16_mobile_hud_takedown.png) |
| Quality Before (Low) | ![Quality Before](docs/screenshots/20_quality_before_low.png) |
| Quality After (High) | ![Quality After](docs/screenshots/21_quality_after_high.png) |
| Gun Detail + Rim (High) | ![Guns High](docs/screenshots/22_guns_high_quality.png) |
| Per-Guard Alert Meters | ![Alert Meters](docs/screenshots/23_guard_alert_meters.png) |
| Foliage Hide / HIDDEN HUD | ![Foliage Hidden](docs/screenshots/24_foliage_hidden.png) |
| Water Shader (High) | ![Water High](docs/screenshots/25_water_high.png) |
| Bush clusters (before) | ![Bush Before](docs/screenshots/27_bush_before.png) |
| Controls settings (PC rebinds) | ![Controls](docs/screenshots/28_controls_settings.png) |
| Bush clusters (after) | ![Bush After](docs/screenshots/29_bush_clusters_after.png) |
| Ranch bush clusters | ![Ranch Bushes](docs/screenshots/30_ranch_bush_clusters.png) |
| Scaled compound + role guards | ![Scaled Compound](docs/screenshots/31_scaled_compound_guards.png) |
| Natural lived-in courtyard | ![Natural Set](docs/screenshots/32_natural_set_courtyard.png) |
| Overlook rooftop view | ![Overlook](docs/screenshots/33_overlook_house_view.png) |
| Iron sights — Rifle | ![Iron Rifle](docs/screenshots/34_iron_rifle.png) |
| Iron sights — Pistol | ![Iron Pistol](docs/screenshots/35_iron_pistol.png) |
| Iron sights — SMG | ![Iron SMG](docs/screenshots/36_iron_smg.png) |
| Iron sights — Shotgun | ![Iron Shotgun](docs/screenshots/37_iron_shotgun.png) |
| Guard death — headshot | ![Death Head](docs/screenshots/38_death_headshot_frame.png) |
| Guard death — explosion | ![Death Blast](docs/screenshots/39_death_explosion_frame.png) |
| Day compound | ![Day](docs/screenshots/40_day_compound.png) |
| Night compound + lights | ![Night](docs/screenshots/41_night_compound.png) |
| Forest treeline border | ![Treeline](docs/screenshots/42_treeline_border.png) |

```bash
# Automated screenshot capture (needs a display; use OpenGL if Vulkan is unavailable)
AUTO_CAPTURE=1 godot --path . --resolution 1280x720 --rendering-driver opengl3
# Batch 2 (natural / overlook / iron / death / day-night / treeline)
HAYDEN_SNAP2=1 godot --path . --resolution 1280x720 --rendering-driver opengl3
```

## Exporting & GitHub Pages

Presets live in `export_presets.cfg` (including **Web** with `variant/thread_support=false` for GitHub Pages). Every push to `main` runs [`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml) to export and publish the Web build to `docs/`.

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

## License

Prototype code is free to use and extend for learning and game jams.

## Garrison sizes

| Outpost | Hostiles | Difficulty | Entrances |
|---|---|---|---|
| Hope County Compound | 9 | Standard | South Gate, West Breach, North Service Gap, East Culvert |
| Seed Family Ranch | 12 | Standard | South Driveway, East Pasture, West Orchard, North Silo Lane |
| Baron Lumber Mill | 12 | Standard | Main Haul Road, West Timber Trail, East Creek Bank, North Rail Spur |
| Whitetail Dock | 12 | Standard | South Highway Lot, West Riverbank, East Boat Launch, North Pier Crawl |
| Jacob's Ridge Bunker | 14 | Hard | South Switchback, West Cliff Gap, East Trench, North Bunker Rear |
| Eden's Gate Fortress | 13 | Extreme (locked) | South Gatehouse, West Sewer Cut, East Scaffold Breach |
| Labour Camp | 12 | Extreme (locked) | South Prison Gate, East Fence Cut, West Drainage Culvert |
| Joseph's Cathedral HQ | 12 | Boss (locked) | South Processional, West Choir Breach, North Bell Tower |
