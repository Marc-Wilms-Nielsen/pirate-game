# Roadmap

Princip: **byg en lille, spilbar udgave først, og udvid den.** Hver milepæl slutter med noget,
man kan åbne og spille. Vi går ikke videre, før det føles godt.

## Version 0.1 – "En tur i det blå" (den lille udgave)
Målet er at bevise, at kernen er hyggelig: sejle, gå i land, loote, sælge, opgradere.

### M1 – Sejlads og stemning ⭐ (vigtigst)
- [x] Skib med inerti, langsom drejning og sejltrin
- [x] Hav: animeret vand-shader (bølger, glimt, kølvand)
- [x] Kamera, der følger blødt med, zoomer ud ved fart og kigger frem
- [x] Lydkulisse: hav, måger, vind, knirken – vindstyrke følger fart (syntetiske placeholders)
- [x] Procedurelle øer med strand, skum, palmer og måger (4 stk.)
- [x] Anker: kast/hæv med Mellemrum (reb og mærke i vandet, kædelyd)
- [x] Glattere grafik: fuld opløsning, anti-aliasing, realistisk belyst hav
- [x] Hav med dybde ("Crystal tropics"): klart vand med synlig sandbund, store stille laguner (ca. 6x øens radius) og blød overgang til åbent hav
- [ ] **Spiltest og justering** (fart, drejning, lyd, farver)
- **Test:** Er det rart bare at sejle i 5 minutter? Hvis nej → justér, før vi går videre.

### M2 – I land og loot
- [x] Hop i vandet, når skibet ligger stille (F), og gå om bord igen tæt på skibet
- [x] Kaptajn (placeholder) går på land og svømmer i vandet
- [ ] Ting at samle: kister, vragrester, flaskepost
- [ ] Simpelt inventar og lastrum på skibet

### M3 – Havn og handel
- [ ] Én havn med en købmand (køb/sælg varer)
- [ ] Guld og prisforskelle (to havne eller én havn + én hæler)
- [ ] Gem/indlæs spillet (save/load)

### M4 – Opgraderinger
- [ ] Skibsværft-vendor: skrog, sejl, kanoner, armor
- [ ] Opgraderinger som data (`Resource`-filer), synlige på skibet hvor muligt

➡️ **Efter M4 har vi version 0.1.** Spil den, få venner til at prøve den, og justér.

## Version 0.2 – Kamp
### M5 – Søkamp
- [ ] Bredside-kanoner (Q/E), kugler, rækkevidde
- [ ] Fjendtlige skibe med simpel AI (patruljér, angrib, flygt)
- [ ] Skade på skrog og sejl, sænkning, flydende last
- [ ] Handelsskibe → tyvegods

### M6 – Kamp på land
- [ ] Nærkamp (sværd) og ranged (pistol)
- [ ] Banditter, der vogter skatte
- [ ] Kaptajn-HP og armor

## Version 0.3 – Verden og økonomi
### M7 – Tyvegods og skibe
- [ ] Hæler / piratby, der køber tyvegods
- [ ] Køb flere skibe (forskellige typer: hurtig, tung, lastskib)
- [ ] Flere havne med egne varer og priser

## Senere (idéer)
Vind og vejr, dag/nat, erobring af skibe, crew, quests, flere øer og biomer, fiskeri.


## Status november 2026 – stort spring frem
Bygget på én gang (kan nu spilles fra ende til anden):
- [x] 13 procedurelle øer (fast seed), 5 havne (3 handelshavne, 2 piratehavne)
- [x] ESC-menu med kort (øer, havne, kister, vraggods, fjender, dit skib), last, skib og styring. M åbner kortet direkte
- [x] Fjendeskibe: handelsskibe (flygter) og pirater (angriber), sænkes og efterlader vraggods
- [x] Kanoner: Q/E bredsider, kanonkugler som forsyning, ladetid, røg, skade, synkning og genopstandelse i havn
- [x] Dyr: krabber (fredelige, giver mad), slanger (angriber på land), hajer (angriber svømmere)
- [x] Loot: skattekister på øerne, flydende tønder, vraggods, dyr – alt styret af loot-tabeller
- [x] Havnemenu: marked (køb/salg, tyvegods kun i piratehavne), forsyninger (kugler, mad, reparation),
      værft (køb/sælg/skift skibe: Slup, Brigantine, Galeon), opgraderinger (skrog, panser, sejl, kanonkraft,
      skudvidde, ladetid, lastrum, kanoner pr. side) og udseende (sejl, skrog, flag, pynt)
- [x] Kaptajnen har liv, sværd og regenererer langsomt
- [x] Automatisk test (`tests/smoke_test.tscn`) der prøver alle systemer igennem

### Næste oplagte skridt
- [x] Gem/indlæs spillet (automatisk hvert minut, i havn og ved lukning)
- [ ] Rigtige lyde og grafik i stedet for placeholders
- [ ] Balancering af priser, skade og hvor ofte fjender dukker op
- [ ] Vind og vejr, dag/nat

## Runde 3
- [x] Zoom langt ud (musehjul eller + / –), deles mellem skib og kaptajn
- [x] 3 store fastlande med bugter, skov og klipper (verden udvidet)
- [x] 16 skibstyper med eget udseende (tegnes procedurelt i `ship_drawer.gd`) og forhåndsvisning i værftet
- [x] Besætning: hyr sømænd i havnen, max pr. skibstype, flere folk spiser mere
- [x] Entring: sejl op ad et skib og tryk F. Terningkamp vægtet efter besætning, moral kan knække.
      Vind: plyndr skibet eller tag det som prise (kommer i din flåde)
- [x] Pirater kan selv forsøge at entre dig

## Runde 4
- [x] Indstillinger i ESC-menuen: lydstyrke (samlet / hav / effekter), skærm, V-Sync, FPS-loft, vandkvalitet, effekter, FPS-tæller
- [x] Skydevåben: pistol, muskedonner, musket (krudt og kugler). Kan ikke skyde mens man svømmer
- [x] Granater: sprængning, brand, gift (gør dyr langsomme), blænd (lammer dyr). Våbenbutik i havnene
- [x] Hakken: skib, fjender og kaptajn tegnes nu glat mellem fysik-skridt; havet er 2-6x billigere at tegne

## Runde 5
- [x] Gem/indlæs (user://save.dat) + "Ny rejse" og "Gem og afslut" i ESC-menuen
- [x] Kanonskud dræber besætning; besætningstal vises over skibe når man er tæt på
- [x] Pirater entrer dig, hvis de har flere folk
- [x] Slæb: tag erobrede skibe på slæb (pladser efter skibsstørrelse + opgradering "Slæbegrej"), sælg dem på værftet
- [x] 5 flagtyper til prestige: lille flag, splitflag, langt standerflag, kongeflag, legendarisk banner
- [x] Udstyr: hatte (held), trøjer/frakker (panser), sværd (skade/fart/rækkevidde) – vises på kaptajnen
- [x] Erhverv: fæld træer (økse), hak sten og malm (hakke), pluk urter, fisk fra skib eller strand (fiskestang)
- [x] Hjemø: køb øen, marker der vokser i rigtig tid, hønsehus/fiskehytte/skovhugger/stenbrud der producerer
      mens spillet er lukket (max 12 timer), lager og værksted med 18 opskrifter (ammunition, mad, granater, udstyr)
- [x] Reparationssæt (R til søs)
- [x] Piratlejre på land med banditter (sabel og pistol), der vogter en skattekiste

## Runde 6
- [x] Større verden: ~30 øer (op til 32 i hav-shaderen), større småøer
- [x] 3 kæmpe fastlande med bjergkæder, jaguarer, vildsvin, krokodiller og junglegolemer
- [x] 3 kongeriger med slotte (Aurelia, Valdora, Nerath). Udfordr dem til duel ved slotsporten:
      animeret slagmark, taktik mellem runderne (Storm frem / Hold linjen / Kaptajnens råb), udstyrsbonus,
      stort engangsbytte fra skatkammeret. Kongeriget samler nye tropper (20 min) og bliver stærkere for hver sejr
- [x] Opgraderinger har 100 små trin (+1 / +10). Gamle gemte spil omregnes automatisk
- [x] Døgn (12 min) med lanterner, fakler og selvlysende plankton i vandet om natten. Flere pirater om natten
- [x] Vejr: klart, regn, tåge og storm (bølger, vind der skubber skibet, lyn og torden)
- [x] Musik komponeret i kode: dag, nat, havn og kamp, med bløde overgange (tools/generate_music.py)
- [x] Fredeligt strandvand: pirater angriber ikke i det lave, stille vand (skjold-ikon øverst til venstre),
      medmindre du selv skyder på dem

## Runde 7
- [x] Ikoner i butikker, last, bytte og HUD; kort med zoom og træk; ingen tastevejledning på skærmen
- [x] Alle skibe har 2 kanonpladser mere pr. side
- [x] Ankersving: kast ankeret i fart og styr – skibet svinger hurtigt rundt og glider sidelæns
- [x] Blød strandkant: sandet toner ud i vandet (skumlinjen lå langt ude på de store øer)
- [x] Venskab med havnene (5 niveauer efter salg): bedre priser og kasser med mange ting
      (forsyningskasse, handelskasse, stor forsyningskasse)
- [x] Kaptajner: ansæt i havnen (fanen Kaptajner), køb flere pladser, opgradér sejlads/kanoner/mod.
      De fører dine andre skibe som eskorte, sejler i formation og angriber pirater

## Round 8 (English from here on)
- [x] All in-game text in US English
- [x] Anchor drop sounds like a bump, not a long chain
- [x] Half as much glow in the water at night; softer lanterns; ships have several small, long lights
- [x] Log window bottom-left (like a chat): loot with icons and events. L toggles the full log
- [x] Bigger home island with a build grid: pick the square for each building in the Build tab, move things around
- [x] Workers: hire them (beds in the house and workers' cottages), assign one per building level; they eat food from storage
- [x] Kingdoms: bigger castles with a town around them – houses, market stalls, a well, chimney smoke, villagers and guards
- [x] Ships look more like ships: shading, rails, planks with seams, hatch, barrels, rigging, bowsprit and jib, sail seams
- [x] 23 melee weapons (sabers, scimitars, katana, axes, maces, morning star, hammer, spear, harpoon, trident, flail, hook, anchor ...)
- [x] Sharper and shinier captain and gear (outline, highlights, blade shine)
- [x] Rename your own ships in the shipyard; NPC ships get random names shown with their crew when close

## Round 9
- [x] Broadsides fire cannon by cannon with a short, uneven delay after the key press
- [x] Cannonball hits and sinking ships explode (fireball, splinters, smoke, several blasts along the hull)
- [x] Escort captains sail over and pick up flotsam
- [x] Crew on escort ships (move from your ship or hire directly) – they join you when you challenge a kingdom
- [x] Boxes: mark goods in home storage and pack them into small/medium/large boxes (take less cargo space),
      boxes are visible on deck, and "Sell all boxes" at any harbor market

## Round 10
- [x] Open sea is transparent dark blue: a seabed (dunes, ~900 rock clusters, ~70 shipwrecks) shows through,
      with slight parallax and sway so it feels deep (scenes/world/seabed.gd)
- [x] Upgrades tab: choose which of your ships to upgrade, not only the one you sail
- [x] Rare and epic drops (8 treasures worth 750–9500 gold), rolled on top of every loot table
- [x] Cannonballs leave a smoke trail that hangs in the air and drifts with the wind
- [x] V-shaped Kelvin wake behind ships instead of foam bubbles (scenes/ship/wake.gd)
- [x] Cannons in a broadside fire in random order

## Round 11
- [x] Market lists only goods you carry for selling; goods for sale sit behind a "Buy goods" toggle
- [x] Reputation per faction (Aurelia, Valdora, Nerath, Free Traders' League, Smugglers' Brotherhood), shared by all their harbors
- [x] 10x world area: 300 islands, 6 mainlands (3 kingdoms + 3 wild), 39 harbors, 45 fishing villages, 40 pirate camps
- [x] World streaming (scenes/main/world_streamer.gd): far things sleep, island contents are built when you get close
- [x] Island lookups through a grid in Game; the water shader only gets islands near the camera
- [x] Map: faction colours, villages, starts zoomed on your ship, cached island shapes
- [x] Performance measurements (tests/perf_check.tscn, tests/perf_parts.tscn) – see the FPS plan

### Ideas for next round
- [ ] Missioner/opgaver fra havnene (leveringer, dusører)
- [ ] Bosse-monstre (kraken) og omdømme hos kongerigerne
- [ ] Rigtige lyde, musik og grafik
