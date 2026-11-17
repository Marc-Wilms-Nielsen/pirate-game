# Mit Spil

Et 2D-spil lavet i [Godot 4](https://godotengine.org/).

## Kom i gang

1. Installer Godot 4.5 eller nyere (standardversionen, ikke .NET).
2. Klon repoet: `git clone <repo-url>`
3. Åbn Godot → **Import** → vælg `project.godot` i denne mappe.
4. Tryk **F5** for at køre spillet. Bevæg spilleren med WASD eller piletasterne.

## Mappestruktur

```
.
├── project.godot        # Godot-projektfil
├── assets/              # Råt indhold: grafik, lyd, fonte, shaders
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/{music,sfx}/
│   ├── fonts/
│   └── shaders/
├── scenes/              # Scener + deres scripts ligger sammen
│   ├── main/            # Startscenen
│   ├── player/
│   ├── levels/
│   └── ui/
├── scripts/
│   └── autoload/        # Globale singletons (f.eks. Game)
├── addons/              # Godot-plugins
└── docs/                # Game design og konventioner
```

Se [`docs/conventions.md`](docs/conventions.md) for navngivning og arbejdsgang,
og [`docs/game-design.md`](docs/game-design.md) for spillets idé.
