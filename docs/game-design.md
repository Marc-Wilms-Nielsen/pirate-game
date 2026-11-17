# Game Design Document

> Arbejdstitel: **Pirate Game**. Et levende dokument – opdateres ved hver milepæl.

## Idé i én sætning
Et hyggeligt top-down 2D-piratspil, hvor du sejler frit rundt i det blå, går i land og looter strande,
handler i havne og opgraderer dit skib – med kamp, når du selv har lyst.

## Designsøjler
Alle beslutninger testes mod disse tre:

1. **Hyggeligt.** Spillet skal kunne åbnes "bare for at sejle en tur". Intet stress, ingen timere,
   ingen hård straf. Kamp er noget, du opsøger, ikke noget, der jagter dig.
2. **Taktilt og tilfredsstillende.** Skibet skal føles tungt og blødt at styre. Lyd og grafik
   (bølger, måger, knirkende tømmer, sejl der fylder sig) er lige så vigtigt som mekanik.
3. **Synlig fremgang.** Hver tur giver noget med hjem: loot, guld, en opgradering, der kan ses og mærkes.

## Perspektiv og stil
- 2D, set oppefra (top-down).
- Rolig, varm farvepalet. Pixel art eller blød håndtegnet stil (besluttes i milepæl 1).
- Lyd: havets brusen, måger, vind i sejlene, rolig musik der skifter med område (åbent hav / havn / ø).

## Kerne-loop
```
Sejl ud  →  Find ø / vrag / skib  →  Loot (strand, vragrester, kamp)
   ↑                                             ↓
Opgrader hos vendors  ←  Sælg varer og tyvegods i havn
```

## Systemer

### Sejlads
- Skibet har fart og inerti, drejer langsomt. Sejl kan sættes i trin (anker / halv / fuld).
- Vind (senere): giver bonus når man sejler med vinden.
- Kamera zoomer lidt ud ved høj fart.

### På land
- Kaptajnen kan gå i land ved strande og moler.
- Looting: kister, vragrester, skatte, der kan graves op.
- Fjender på øer (banditter, rivaliserende pirater) – nærkamp og ranged (pistol/musket).

### Søkamp
- Kanoner affyres fra siderne (bredside) – kræver at man positionerer sig.
- Skibe har skrog-HP, sejl-skade (påvirker fart) og armor.
- Sænkede skibe efterlader flydende last, der kan samles op.

### Handel og økonomi
- Hver havn har varer med forskellige priser (køb billigt ét sted, sælg dyrt et andet).
- **Tyvegods** (stjålet fra handelsskibe) kan kun sælges hos en hæler / i piratbyer.
- Skibe kan købes (og senere erobres).

### Opgraderinger (vendors)
| Kategori | Påvirker |
|----------|----------|
| Skrog    | Max HP, lastrum |
| Sejl     | Fart, acceleration, drejning |
| Kanoner  | Skade, rækkevidde, genladningstid, antal |
| Armor    | Skadesreduktion (skib og kaptajn) |
| Kaptajn  | HP, våben (sværd, pistol) |

Alle opgraderinger defineres som data (Godot Resources), så de kan balanceres uden at ændre kode.

### Død og straf (holdes mild)
- Sænkes skibet: du vågner i nærmeste havn og mister en del af lasten – aldrig opgraderinger.

## Kontroller (udkast)
| Handling | Tastatur |
|----------|----------|
| Styr skib / gå | WASD / piletaster |
| Sejl op/ned | W / S (på skib) |
| Affyr kanoner (venstre/højre) | Q / E |
| Interager (gå i land, loot, handel) | F |
| Angreb / skyd | Venstre / højre museknap |

## Udenfor scope (indtil videre)
Multiplayer, crew-styring, storyline/quests, procedurelt genereret verden.
Kan blive relevant senere – arkitekturen må gerne gøre det muligt, men vi bygger det ikke nu.
