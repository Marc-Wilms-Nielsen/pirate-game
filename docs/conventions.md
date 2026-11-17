# Konventioner

## Navngivning
- **Filer og mapper:** `snake_case` (f.eks. `player_controller.gd`, `level_01.tscn`)
- **Noder i scener:** `PascalCase` (f.eks. `Player`, `HealthBar`)
- **GDScript:** variabler og funktioner i `snake_case`, konstanter i `UPPER_CASE`,
  klasser (`class_name`) i `PascalCase`
- **Signaler:** datid, f.eks. `died`, `score_changed`

## Organisering
- En scene og dens script ligger i **samme mappe** (`scenes/player/player.tscn` + `player.gd`).
- `scripts/` bruges kun til kode, der ikke hører til én bestemt scene (autoloads, hjælpeklasser).
- Rå assets ligger i `assets/`, aldrig spredt i `scenes/`.
- Brug statisk typning i GDScript (`var speed: float = 100.0`).

## Git-arbejdsgang
- `main` skal altid kunne køre.
- Lav en branch pr. feature: `feature/player-jump`, `fix/collision-bug`.
- Små commits med beskrivende beskeder: "Tilføj hop til spilleren".
- Commit aldrig `.godot/`-mappen (den er i `.gitignore`).
- Store binære filer (musik, store sprite sheets): overvej Git LFS.
