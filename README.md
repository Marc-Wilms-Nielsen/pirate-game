# Pirate Game

A cozy top-down 2D pirate game made in [Godot 4](https://godotengine.org/).

## Getting started

1. Install Godot 4.5 or newer (the standard version, not .NET).
2. Clone the repo: `git clone <repo-url>`
3. Open Godot → **Import** → pick `project.godot` in this folder.
4. Press **F5** to run the game. Esc → Controls shows all keys.

## Folder structure

```
.
├── project.godot        # Godot project file
├── assets/              # Raw content: graphics, sound, fonts, shaders
│   ├── sprites/
│   ├── audio/{ambience,music,sfx}/
│   └── shaders/
├── scenes/              # Scenes and their scripts live together
│   ├── main/            # The start scene, music
│   ├── player/          # The captain on foot, weapon drawing
│   ├── ship/            # Player ship, enemies, escorts, ship drawing
│   ├── world/           # Islands, harbors, castles, towns, ocean, sky and weather
│   ├── creatures/       # Animals, monsters, bandits
│   └── ui/              # HUD, menus, map, icons
├── scripts/
│   ├── autoload/        # Global singletons (Game, Settings, Sfx, Homestead)
│   └── data/catalog.gd  # All game data
├── tests/               # Smoke test and screenshot checks
├── tools/               # Sound and music generators (Python)
└── docs/                # Game design and conventions
```

See [`docs/conventions.md`](docs/conventions.md) for naming and workflow,
[`docs/game-design.md`](docs/game-design.md) for the idea of the game,
[`docs/roadmap.md`](docs/roadmap.md) for the plan and [`docs/ai-workflow.md`](docs/ai-workflow.md) for how we use AI.
