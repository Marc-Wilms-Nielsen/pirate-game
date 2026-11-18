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
- Movement happens in `_physics_process`; visuals are interpolated in `_process` (see ship.gd) to avoid stutter.
- Game state (gold, cargo, ships, captains, harbor friendship) lives in the `Game` autoload (`scripts/autoload/game.gd`); sounds play via the `Sfx` autoload.
- Log lines (loot, events) go through `Game.log_line()` / `Game.notify()` and show in the log bottom-left (L toggles it).
- Ships are drawn in code by `scenes/ship/ship_drawer.gd` from `look` in the catalog. `tests/ship_lineup.tscn` shows all types side by side.
- Melee weapons are drawn by `scenes/player/weapon_art.gd` from their `look` (type, length, width, color).
- Music is generated with `python3 tools/generate_music.py` (needs numpy and ffmpeg); sounds with `tools/generate_audio.py`.
- `WorldSky` (scenes/world/sky.gd) runs day/night, weather and lanterns; `MusicDirector` (scenes/main/music.gd) the music.
- `tests/visual_check.tscn` and `tests/ui_check.tscn` take quick screenshots (castle, beasts, night, menus, home island).
- The world is streamed: anything placed in the world must be registered with `WorldStreamer` (`add` / `add_wide`), or it will never sleep.
- `tests/perf_check.tscn` measures frame time per setting; `tests/perf_parts.tscn` measures CPU per subsystem.
- Run `tests/smoke_test.tscn` after bigger changes – it exercises every system and saves screenshots to user://test_shots/.
- Use static typing and Godot 4 syntax (not Godot 3).
- Don't edit the `.godot/` folder.
- The developer is a software engineer but new to Godot: briefly explain Godot-specific choices.
- Update `docs/roadmap.md` when a task is done.
