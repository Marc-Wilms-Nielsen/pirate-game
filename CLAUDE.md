# Instruktioner til Claude

**Pirate Game** – et hyggeligt top-down 2D-piratspil i **Godot 4.5+** med **GDScript**.

## Læs først
- `docs/game-design.md` – vision, designsøjler og systemer
- `docs/roadmap.md` – hvad vi bygger nu (arbejd kun på den aktuelle milepæl)
- `docs/conventions.md` – navngivning og Git
- `docs/ai-workflow.md` – hvordan vi samarbejder

## Regler
- Spillet skal være afslappende: vælg blød, rolig "game feel" frem for hurtig og hektisk.
- Foreslå en kort plan før større ændringer, og vent på godkendelse.
- Scener og deres scripts ligger sammen under `scenes/<feature>/`.
- Gameplay-tal (fart, priser, skade, opgraderinger) skal ligge i `@export`-variabler eller `Resource`-filer, ikke hardcodes.
- Brug statisk typning og Godot 4-syntaks (ikke Godot 3).
- Rediger ikke `.godot/`-mappen.
- Udvikleren er softwareingeniør, men ny til Godot: forklar Godot-specifikke valg kort.
- Opdater `docs/roadmap.md` når en opgave er færdig.
