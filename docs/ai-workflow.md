# Sådan bruger vi AI i projektet

## Rollefordeling
| Du (udvikler og spildesigner) | Claude (AI-medudvikler) |
|---|---|
| Beslutter hvad spillet skal være og hvordan det skal føles | Foreslår løsninger, skriver kode og forklarer Godot |
| **Spiller og tester** – AI kan ikke se eller mærke spillet | Skriver GDScript, shaders, systemer og data |
| Bygger og justerer scener visuelt i Godot-editoren | Laver arkitektur, refaktorerer og finder fejl |
| Vælger grafik og lyd | Holder docs og roadmap opdateret |

Den vigtigste regel: **AI'en kan ikke spille spillet.** "Føles det godt?" er dit job.
Fortæl Claude præcist hvad du oplever ("skibet drejer for hurtigt og stopper for brat"),
og send gerne screenshots eller korte optagelser.

## Hvilket værktøj til hvad
- **Claude Code** (i terminalen eller desktop-appen, åbnet i projektmappen på din computer):
  det bedste værktøj til selve kodningen. Det læser `CLAUDE.md` og `docs/`, retter direkte i filerne
  og kan committe. Du har Godot åbent ved siden af og tester med det samme.
- **Claude-chat** (som her): planlægning, design-diskussioner, research, balancering af tal,
  og større ændringer gennem GitHub.

## Arbejdsgangen – én feature ad gangen
1. **Vælg én opgave** fra `docs/roadmap.md` (f.eks. "Skib med inerti").
2. **Lav en branch:** `git switch -c feature/ship-movement`
3. **Bed Claude om en kort plan først** – læs den, ret den, og bed så om koden.
4. **Test i Godot** (F5). Giv konkret feedback. Gentag 3–4 til det føles rigtigt.
5. **Commit** med en god besked og merge til `main`.
6. **Bed Claude opdatere docs** (sæt flueben i roadmap, notér beslutninger i game-design).
7. **Start en ny samtale** til næste feature. Kort, fokuseret kontekst giver bedre resultater.

Hvis AI'en laver noget rod: `git restore .` eller drop branchen. Derfor arbejder vi i små branches.

## Gode prompts
- *"Læs docs/roadmap.md. Vi skal lave M1: skib med inerti. Lav en plan før du skriver kode."*
- *"Skibet føles for let. Det skal accelerere langsommere og glide længere, når sejlet tages ned."*
- *"Forklar hvad denne kode gør, og hvorfor du valgte et CharacterBody2D frem for RigidBody2D."*
- *"Gennemgå scenes/ship/ – er der noget, der bliver svært at udvide, når vi tilføjer kanoner?"*
- *"Lav 5 skib-opgraderinger med pris og stats, der giver en jævn progression over ca. 2 timers spil."*

## Hvad AI er god til her – og hvad den ikke er god til
**God til:** GDScript, bevægelsesfysik, shaders (vand, kølvand, skum), UI-logik, inventar/økonomi,
save/load, fjende-AI, balance-tabeller, at forklare Godot-koncepter.

**Mindre god til:** at tegne færdig grafik og at bygge store `.tscn`-scener i hånden.
Byg scenerne i editoren og lad Claude skrive scripts og systemerne bag.

## Grafik og lyd
- Start med gratis assets, så vi kan teste stemningen tidligt. Prøv f.eks. Kenney.nl
  (pirat- og lydpakker) og Freesound.org (hav, måger, tømmer). Tjek altid licensen.
- Skriv alle kilder og licenser ind i `CREDITS.md`.
- Eget art eller AI-genereret grafik kan erstatte placeholders senere. Systemerne skal ikke ændres.

## Arkitektur, der kan skalere
- **Data i Resources:** varer, opgraderinger og skibstyper er `.tres`-filer. Nye ting = nye filer, ikke ny kode.
- **Komponenter:** genbrugelige noder som `HealthComponent`, `Hurtbox` og `LootDrop`, der bruges af både skibe,
  kaptajn og fjender.
- **Signaler** mellem systemer i stedet for direkte referencer.
- **Få autoloads:** `Game` (state), `Economy` (guld/priser), `SaveSystem`, `AudioManager`.
