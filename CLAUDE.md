# Instructions for Claude

**Pirate Game** – a cozy top-down 2D pirate game in **Godot 4.5+** with **GDScript**.

## Read first
- `docs/game-design.md` – vision, design pillars and systems
- `docs/roadmap.md` – what we are building now (only work on the current milestone)
- `docs/conventions.md` – naming and Git
- `docs/ai-workflow.md` – how we work together

## Rules
- All in-game text is US English. (Older code comments and some docs are still in Danish.)
- The game should feel relaxing: prefer a soft, calm "game feel" over fast and hectic.
- Propose a short plan before big changes and wait for approval.
- Scenes and their scripts live together under `scenes/<feature>/`.
- Gameplay data (items, prices, ships, upgrades, weapons, loot tables, harbors, kingdoms, buildings) lives in `scripts/data/catalog.gd`. Add new content there.
- The home island (build grid, fields, buildings, workers, storage, workshop) lives in the `Homestead` autoload; production is computed from real time (unix time), and workers eat food from storage.
- The game is saved by `Game.save_game()` (user://save.dat). New systems can save via `Game.register_save_hooks`.
- Settings live in the `Settings` autoload (saved to user://settings.cfg). Sounds must use the "SFX", "Ambience" or "Music" bus.
- Look: `UiTheme` (scenes/ui/ui_theme.gd) holds the colours, fonts and text scale; use `UiTheme.label` / `UiTheme.button` so text gets the right font and size. Labels of size 12+ use the Pirata One heading font.
- Movement happens in `_physics_process`; visuals are interpolated in `_process` (see ship.gd) to avoid stutter.
- Game state (gold, cargo, ships, captains, harbor friendship) lives in the `Game` autoload (`scripts/autoload/game.gd`); sounds play via the `Sfx` autoload.
- Log lines (loot, events) go through `Game.log_line()` / `Game.notify()` and show in the log bottom-left (L toggles it).
- Ships are drawn in code by `scenes/ship/ship_drawer.gd` from `look` in the catalog. `tests/ship_lineup.tscn` shows all types side by side.
- Customization: parts and palettes are `Catalog.SHIP_STYLE_PARTS` and `Catalog.CAPTAIN_STYLE_PARTS` (first option free, the rest bought once). A ship's choices live in its config and are turned into colours by `ShipDrawer.style_of(config)`; the captain's live in `Game.captain_look` and are drawn by `CaptainDrawer` (on land, at the helm and in the Tailor). The Looks and Tailor tabs use `StyleEditor` (scenes/ui/style_editor.gd). `tests/style_check.tscn` tests it.
- Melee weapons are drawn by `scenes/player/weapon_art.gd` from their `look` (type, length, width, color).
- Music is generated with `python3 tools/generate_music.py` (needs numpy and ffmpeg); sounds with `tools/generate_audio.py`.
- `WorldSky` (scenes/world/sky.gd) runs day/night, weather and lanterns; `MusicDirector` (scenes/main/music.gd) the music.
- `tests/visual_check.tscn` and `tests/ui_check.tscn` take quick screenshots (castle, beasts, night, menus, home island).
- The world is streamed: anything placed in the world must be registered with `WorldStreamer` (`add` / `add_wide`), or it will never sleep.
- `tests/perf_check.tscn` measures frame time per setting; `tests/perf_parts.tscn` measures CPU per subsystem.
- The ocean shader reads pre-baked noise textures (`scenes/world/water_noise.gd`) – don't add per-pixel noise functions to full-screen shaders. The seabed's rocks/wrecks and the "Water resolution" setting go through `WaterLayers` (`scenes/world/water_layers.gd`).
- After touching the water, fog or seabed, run `tests/water_bench.tscn` at 1920x1080: it fails if the water got more than 10 % slower than `tests/perf_budget.cfg`. Use `-- --update-budget` only for intended changes.
- Main quest line ("The Sun King's Crown"): quests and quest givers are data in `Catalog.QUESTS` / `Catalog.QUEST_PEOPLE`; progress and saving live in the `Quests` autoload; `QuestWorld` (`scenes/quests/quest_world.gd`) draws the ! / ? marks and spawns bosses near their spot; `QuestDialog` + `Portrait` (`scenes/ui/`) are the chat window. `tests/quest_check.tscn` plays the whole line.
- Fast travel (`scenes/main/fast_travel.gd`): from the map to harbors in `Game.visited_harbors` (set when docking), for gold by distance; the fleet sinks and rises at the destination. `tests/travel_check.tscn` tests it. `Settings.developer_mode` (Settings menu) opens every harbor for free and keeps `Game.gold` at 1,000,000 (`Game.dev_top_up`).
- Named areas: `WorldZones` (scenes/world/world_zones.gd) builds them from the world (a weighted Voronoi of Sunhaven, the mainlands and open-sea points), `zone_at(pos)` gives the area at a spot, and `ZoneBanner` shows the name when you enter one. Names are in `Catalog.ZONE_*`. `tests/zone_check.tscn` tests it.
- The canal city: `BigCity` (scenes/world/big_city.gd) builds Lanternmouth (`Catalog.CITY`) on its own island round its Harbor (local +x = sea, x = 0 = the straight waterfront; the island is cut straight there by `Island.front_dist`, mirrored in ocean.gdshader). The static town is drawn once (`_draw` and chunk nodes); only moving parts go in `_draw_animated` – keep it that way. Houses, canal water and the old town's wall are solid on physics layer 4 (`BUILDING_LAYER`, the captain collides with it); quay, piers and moles are walkable through `Game.is_walkable`. `tests/city_check.tscn` tests it.
- Menus are laid out in the 640 x 360 base resolution. `tests/ui_fit.tscn` opens every menu tab and fails if a panel sticks out (usually a long line of text or a wide row). `UiTheme.label` wraps text longer than 60 characters for this reason.
- Tests that call `Game.delete_save()` delete the real save in the user data folder: back it up first when running them on the developer's machine.
- Run `tests/smoke_test.tscn` after bigger changes – it exercises every system and saves screenshots to user://test_shots/.
- Use static typing and Godot 4 syntax (not Godot 3).
- Don't edit the `.godot/` folder.
- The developer is a software engineer but new to Godot: briefly explain Godot-specific choices.
- Update `docs/roadmap.md` when a task is done.
