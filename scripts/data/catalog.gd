class_name Catalog
## Alle spillets data samlet ét sted: varer, skibstyper, opgraderinger, udseende og loot-tabeller.
## Vil du tilføje en ny vare, et nyt skib eller ændre priser, er det her du gør det.

# --- Varer ---------------------------------------------------------------
# category: "trade" (handelsvare), "stolen" (tyvegods – kun piratehavne køber), "treasure"
# weight: hvor meget plads varen fylder i lastrummet
const ITEMS := {
	"rum": {"name": "Rum", "category": "trade", "price": 14, "weight": 1},
	"sugar": {"name": "Sugar", "category": "trade", "price": 8, "weight": 1},
	"tobacco": {"name": "Tobacco", "category": "trade", "price": 16, "weight": 1},
	"spices": {"name": "Spices", "category": "trade", "price": 24, "weight": 1},
	"silk": {"name": "Silk", "category": "trade", "price": 38, "weight": 1},
	"snake_skin": {"name": "Snake skin", "category": "trade", "price": 20, "weight": 1},
	"shark_tooth": {"name": "Shark tooth", "category": "trade", "price": 30, "weight": 1},
	"jaguar_pelt": {"name": "Jaguar pelt", "category": "trade", "price": 55, "weight": 1},
	"boar_tusk": {"name": "Boar tusk", "category": "trade", "price": 22, "weight": 1},
	"croc_leather": {"name": "Crocodile hide", "category": "trade", "price": 48, "weight": 1},
	"golem_core": {"name": "Golem core", "category": "treasure", "price": 240, "weight": 1},
	"royal_seal": {"name": "Royal seal", "category": "treasure", "price": 320, "weight": 1},
	"pearls": {"name": "Pearls", "category": "treasure", "price": 60, "weight": 1},
	"jewels": {"name": "Gemstones", "category": "treasure", "price": 110, "weight": 1},
	"stolen_cargo": {"name": "Stolen cargo", "category": "stolen", "price": 45, "weight": 2},
	"stolen_jewels": {"name": "Stolen jewelry", "category": "stolen", "price": 95, "weight": 1},
	# Materialer – samles, dyrkes eller fremstilles. Kan sælges eller bruges i værkstedet.
	"wood": {"name": "Wood", "category": "material", "price": 4, "weight": 1},
	"coconut": {"name": "Coconut", "category": "material", "price": 3, "weight": 1},
	"stone": {"name": "Stone", "category": "material", "price": 3, "weight": 1},
	"iron_ore": {"name": "Iron ore", "category": "material", "price": 9, "weight": 1},
	"gold_ore": {"name": "Gold ore", "category": "material", "price": 32, "weight": 1},
	"fish": {"name": "Fish", "category": "material", "price": 5, "weight": 1},
	"rare_fish": {"name": "Rare fish", "category": "material", "price": 45, "weight": 1},
	"wheat": {"name": "Wheat", "category": "material", "price": 4, "weight": 1},
	"hemp": {"name": "Hemp", "category": "material", "price": 6, "weight": 1},
	"herbs": {"name": "Herbs", "category": "material", "price": 7, "weight": 1},
	"rope": {"name": "Rope", "category": "material", "price": 16, "weight": 1},
	"canvas": {"name": "Sailcloth", "category": "material", "price": 24, "weight": 1},
	"iron_bar": {"name": "Iron bar", "category": "material", "price": 34, "weight": 1},
	"gold_bar": {"name": "Gold bar", "category": "treasure", "price": 150, "weight": 1},
	# Sjældne og episke fund – dukker op en sjælden gang i alt bytte og er meget værd i havnene
	"ancient_coin": {"name": "Ancient doubloon", "category": "treasure", "rarity": "rare", "price": 750, "weight": 1},
	"golden_compass": {"name": "Golden compass", "category": "treasure", "rarity": "rare", "price": 950, "weight": 1},
	"silver_chalice": {"name": "Silver chalice", "category": "treasure", "rarity": "rare", "price": 1100, "weight": 1},
	"pearl_necklace": {"name": "Black pearl necklace", "category": "treasure", "rarity": "rare", "price": 1300, "weight": 1},
	"jade_idol": {"name": "Jade idol", "category": "treasure", "rarity": "epic", "price": 4500, "weight": 2},
	"cursed_skull": {"name": "Cursed gold skull", "category": "treasure", "rarity": "epic", "price": 5500, "weight": 1},
	"kraken_eye": {"name": "Kraken's eye", "category": "treasure", "rarity": "epic", "price": 7000, "weight": 1},
	"sun_crown": {"name": "Crown of the Sun King", "category": "treasure", "rarity": "epic", "price": 9500, "weight": 2},
}

const RARITY_COLORS := {"rare": Color(0.45, 0.72, 1.0), "epic": Color(0.86, 0.5, 1.0)}
## Chance for et sjældent / episk ekstrafund pr. bytte-tabel: [sjælden, episk]. Ukendte tabeller bruger "default".
const RARE_DROPS := {
	"default": [0.04, 0.008],
	"crab": [0.01, 0.001], "snake": [0.015, 0.002], "bandit": [0.02, 0.003], "boar": [0.015, 0.002],
	"floating_barrel": [0.03, 0.005],
	"merchant_wreck": [0.08, 0.015], "pirate_wreck": [0.10, 0.02],
	"camp_chest": [0.18, 0.04], "golem": [0.15, 0.04],
	"kingdom_treasury": [0.7, 0.3],
}

# --- Indsamling ----------------------------------------------------------------
# Ressourcer på øerne. tool: værktøj der kræves. yields: [id, min, max, chance]
const RESOURCE_NODES := {
	"tree": {"name": "Wood", "verb": "Chop the tree", "tool": "axe", "hits": 3, "time": 1.2, "respawn": 300.0,
		"yields": [["wood", 2, 4, 1.0], ["coconut", 1, 2, 0.35]]},
	"rock": {"name": "Rock", "verb": "Mine the rock", "tool": "pickaxe", "hits": 3, "time": 1.5, "respawn": 360.0,
		"yields": [["stone", 2, 4, 1.0], ["iron_ore", 1, 2, 0.4], ["gold_ore", 1, 1, 0.05]]},
	"ore": {"name": "Ore vein", "verb": "Mine ore", "tool": "pickaxe", "hits": 4, "time": 1.8, "respawn": 480.0,
		"yields": [["iron_ore", 2, 4, 1.0], ["gold_ore", 1, 2, 0.18], ["stone", 1, 2, 0.5]]},
	"herb": {"name": "Herb bush", "verb": "Pick herbs", "tool": "", "hits": 2, "time": 0.8, "respawn": 240.0,
		"yields": [["herbs", 1, 3, 1.0]]},
}
const TOOLS := {
	"axe": {"name": "Axe", "price": 150},
	"pickaxe": {"name": "Pickaxe", "price": 220},
	"rod": {"name": "Fishing rod", "price": 120},
}
const FISHING := {"bite_min": 2.0, "bite_max": 5.0, "window": 1.3, "catches_per_shoal": 4,
	"yields": [["fish", 1, 3, 1.0], ["rare_fish", 1, 1, 0.08]]}

# --- Hjemøen ------------------------------------------------------------------
const HOME_PRICE := 600
const START_PLOTS := 2
# Afgrøder vokser i rigtig tid (også når spillet er lukket). grow: minutter
const CROPS := {
	"herbs": {"name": "Herbs", "seed_price": 5, "grow": 8.0, "yield": ["herbs", 3]},
	"wheat": {"name": "Wheat", "seed_price": 6, "grow": 15.0, "yield": ["wheat", 6]},
	"hemp": {"name": "Hemp", "seed_price": 10, "grow": 20.0, "yield": ["hemp", 5]},
	"sugar": {"name": "Sugar cane", "seed_price": 12, "grow": 25.0, "yield": ["sugar", 6]},
	"tobacco": {"name": "Tobacco", "seed_price": 20, "grow": 40.0, "yield": ["tobacco", 5]},
}
# Bygninger producerer i rigtig tid. per_hour pr. niveau. Lageret fyldes max op til CAP_HOURS.
const BUILDING_CAP_HOURS := 12.0
const BUILDINGS := {
	"fields": {"name": "More fields", "desc": "+2 fields per level", "costs": [300, 700, 1500], "produce": {}, "placeable": false},
	"cottage": {"name": "Workers' cottage", "desc": "Beds for 3 more workers per level", "costs": [200, 500, 1100, 2400], "produce": {}},
	"workshop": {"name": "Workshop", "desc": "Unlocks more recipes", "costs": [250, 800, 2000], "produce": {}},
	"chickens": {"name": "Chicken coop", "desc": "Food for the crew", "costs": [300, 700, 1500], "produce": {"food": 8.0}},
	"fishery": {"name": "Fishing hut", "desc": "Catches fish while you're away", "costs": [400, 900, 1800], "produce": {"fish": 4.0}},
	"lumber": {"name": "Lumber camp", "desc": "Chops wood while you're away", "costs": [400, 900, 1800], "produce": {"wood": 6.0}},
	"quarry": {"name": "Quarry", "desc": "Stone and some iron ore", "costs": [600, 1300, 2600], "produce": {"stone": 5.0, "iron_ore": 1.5}},
}
# Kasser: pak varer fra hjemøens lager i kasser. En kasse fylder meget mindre i lastrummet
# end varerne hver for sig, og alle kasser kan sælges på én gang hos en handelsmand.
const BOXES := {
	"small_box": {"name": "Small box", "capacity": 20, "weight": 5, "price": 30},
	"medium_box": {"name": "Medium box", "capacity": 60, "weight": 12, "price": 80},
	"large_box": {"name": "Large box", "capacity": 150, "weight": 25, "price": 180},
}
# Arbejdere: bor i huset og i arbejderhytter, arbejder i bygningerne og spiser mad fra lageret.
# En bygning skal have én arbejder pr. niveau for at producere fuldt ud.
const HOUSE_BEDS := 2
const BEDS_PER_COTTAGE := 3
const WORKER_PRICE := 150
const WORKER_FOOD_PER_HOUR := 2.0
# Byggefeltet på hjemøen (felter i bredden og højden og størrelsen af ét felt i pixels)
const HOME_GRID := Vector2i(13, 11)
const HOME_CELL := 40.0
# Værkstedets opskrifter. level: krævet værkstedsniveau. output: [id, antal] eller gear-id
const RECIPES := [
	{"name": "Cannonballs", "level": 1, "inputs": {"iron_ore": 2, "stone": 2}, "output": ["cannonball", 20]},
	{"name": "Powder and shot", "level": 1, "inputs": {"iron_ore": 1, "wood": 2}, "output": ["shot", 30]},
	{"name": "Bread (food)", "level": 1, "inputs": {"wheat": 4}, "output": ["food", 20]},
	{"name": "Smoked fish (food)", "level": 1, "inputs": {"fish": 3, "wood": 1}, "output": ["food", 20]},
	{"name": "Repair kit", "level": 1, "inputs": {"wood": 4, "hemp": 2}, "output": ["repair_kit", 1]},
	{"name": "Rope", "level": 1, "inputs": {"hemp": 2}, "output": ["rope", 2]},
	{"name": "Grenades", "level": 1, "inputs": {"iron_ore": 2, "wood": 1}, "output": ["grenade", 2]},
	{"name": "Sailcloth", "level": 2, "inputs": {"hemp": 3, "rope": 1}, "output": ["canvas", 1]},
	{"name": "Iron bar", "level": 2, "inputs": {"iron_ore": 3, "wood": 2}, "output": ["iron_bar", 1]},
	{"name": "Firebombs", "level": 2, "inputs": {"wood": 2, "rum": 1}, "output": ["firebomb", 2]},
	{"name": "Poison bombs", "level": 2, "inputs": {"herbs": 3, "snake_skin": 1}, "output": ["poison", 2]},
	{"name": "Flash grenades", "level": 2, "inputs": {"stone": 2, "herbs": 1}, "output": ["flash", 2]},
	{"name": "Leather coat", "level": 2, "inputs": {"snake_skin": 4, "hemp": 2}, "gear": "leather"},
	{"name": "Rapier", "level": 2, "inputs": {"iron_bar": 2, "wood": 1}, "gear": "rapier"},
	{"name": "Gold bar", "level": 3, "inputs": {"gold_ore": 3, "wood": 2}, "output": ["gold_bar", 1]},
	{"name": "Broadsword", "level": 3, "inputs": {"iron_bar": 3, "wood": 2}, "gear": "broadsword"},
	{"name": "Plumed captain's hat", "level": 3, "inputs": {"gold_bar": 1, "canvas": 1}, "gear": "captain_hat"},
	{"name": "Golden saber", "level": 3, "inputs": {"gold_bar": 3, "iron_bar": 2}, "gear": "gold_sabre"},
]
const REPAIR_KIT_HEAL := 0.3 ## andel af skroget et reparationssæt reparerer (tast R til søs)

# Forsyninger fylder ikke i lastrummet og købes i havnenes forsyningsbutik.
const SUPPLIES := {
	"cannonball": {"name": "Cannonballs", "price": 2},
	"food": {"name": "Food", "price": 1},
	"shot": {"name": "Powder and shot", "price": 1},
}
const REPAIR_KIT_PRICE := 120 ## bruges til at regne kassernes værdi

# --- Skibsnavne ------------------------------------------------------------------
const PIRATE_NAME_A := ["Black", "Bloody", "Crimson", "Grim", "Howling", "Wicked", "Rotten", "Salty", "Cursed", "Silent",
	"Iron", "Drunken", "Savage", "Midnight", "Hungry", "Scarlet", "Thundering", "Mad", "Jolly", "Ghostly"]
const PIRATE_NAME_B := ["Gull", "Kraken", "Revenge", "Shark", "Widow", "Serpent", "Skull", "Raven", "Barracuda", "Fury",
	"Cutlass", "Marauder", "Harpy", "Dagger", "Moray", "Corsair", "Wraith", "Jackal", "Squall", "Mermaid"]
const MERCHANT_NAMES := ["Fair Wind", "Golden Hind", "Morning Star", "Prosperity", "Good Fortune", "Sea Lily", "Sweet Clover",
	"Silver Cod", "Spice Maiden", "Lucky Penny", "Patience", "Sunrise", "Blue Heron", "Gentle Breeze", "Saint Anne",
	"Merry Trader", "Honest John", "Calm Waters", "Cinnamon", "Rosalind"]

static func random_ship_name(faction: String) -> String:
	if faction == "pirate":
		return "The %s %s" % [PIRATE_NAME_A.pick_random(), PIRATE_NAME_B.pick_random()]
	return MERCHANT_NAMES.pick_random()


# --- Kaptajner -------------------------------------------------------------------
# Ansatte kaptajner sejler dine andre skibe som eskorte. De følger dig og kæmper mod pirater.
const CAPTAIN_NAMES := ["Anne Bonny", "Jack Rackham", "Mary Read", "Sam Saltwater", "Greta Grog", "Diego Velasco",
	"Henry Seahawk", "Rosa Morales", "Ollie Anchorstock", "Isabel Cruz", "Tom Tar", "Mary Gullcry",
	"Captain Coconut", "Elena Brisa", "Bjorn Breakwater", "Lucia Fuego", "Nils Navigator", "Ines Marea"]
const CAPTAIN_SKILLS := {
	"sailing": {"name": "Seamanship", "text": "+4 % speed and turning per level"},
	"gunnery": {"name": "Gunnery", "text": "+8 % damage and -3 % reload time per level"},
	"courage": {"name": "Courage", "text": "+6 % hull and +2 % armor per level"},
}
const CAPTAIN_MAX_LEVEL := 10
const CAPTAIN_START_SLOTS := 1
const CAPTAIN_SLOT_PRICES := [3000, 8000, 20000, 50000] ## plads 2, 3, 4 og 5
const CAPTAIN_HIRE_BASE := 500

static func captain_upgrade_price(level: int) -> int:
	return -1 if level >= CAPTAIN_MAX_LEVEL else roundi(250.0 * pow(level + 1.0, 1.6) / 10.0) * 10

static func captain_hire_price(captain: Dictionary) -> int:
	return CAPTAIN_HIRE_BASE + 200 * (int(captain["sailing"]) + int(captain["gunnery"]) + int(captain["courage"]))


# --- Venskab med havnene -----------------------------------------------------
# Jo mere du sælger i en havn, jo bedre venner bliver I. need: samlet salg i guld.
const FRIEND_LEVELS := [
	{"name": "Stranger", "need": 0},
	{"name": "Familiar face", "need": 800},
	{"name": "Friend", "need": 3000},
	{"name": "Good friend", "need": 9000},
	{"name": "Honorary citizen", "need": 25000},
]
const FRIEND_PRICE_STEP := 0.04 ## pr. niveau: køb billigere og sælg dyrere
# Kasser med mange ting på én gang (låses op af venskab). discount: rabat i forhold til at købe enkeltvis
const CRATES := [
	{"id": "supply_crate", "name": "Supply crate", "level": 2, "discount": 0.15,
		"contents": {"cannonball": 50, "food": 40, "shot": 40, "repair_kit": 1}},
	{"id": "trade_crate", "name": "Trade crate", "level": 3, "discount": 0.15,
		"contents": {"rum": 4, "sugar": 4, "tobacco": 4, "spices": 4, "silk": 4}},
	{"id": "big_supply_crate", "name": "Large supply crate", "level": 4, "discount": 0.25,
		"contents": {"cannonball": 150, "food": 120, "shot": 120, "repair_kit": 3, "grenade": 3}},
]

# --- Kaptajnens våben (taster 1-8) --------------------------------------------
# gun: damage pr. kugle, pellets = antal hagl pr. skud, ammo = krudt og kugler pr. skud
# grenade: effect "explosive", "fire", "poison" eller "flash"
const WEAPONS := {
	"sword": {"name": "Melee", "kind": "melee", "price": 0, "short": "Melee"},
	"pistol": {"name": "Pistol", "kind": "gun", "price": 250, "short": "Pistol",
		"damage": 14.0, "range": 220.0, "reload": 0.9, "pellets": 1, "spread": 0.04, "ammo": 1},
	"blunderbuss": {"name": "Blunderbuss", "kind": "gun", "price": 600, "short": "Blunder",
		"damage": 7.0, "range": 140.0, "reload": 1.6, "pellets": 6, "spread": 0.35, "ammo": 2},
	"musket": {"name": "Musket", "kind": "gun", "price": 900, "short": "Musket",
		"damage": 32.0, "range": 380.0, "reload": 2.4, "pellets": 1, "spread": 0.01, "ammo": 1},
	"grenade": {"name": "Grenade", "kind": "grenade", "price": 35, "short": "Grenade",
		"effect": "explosive", "damage": 30.0, "radius": 45.0},
	"firebomb": {"name": "Firebomb", "kind": "grenade", "price": 45, "short": "Fire",
		"effect": "fire", "damage": 8.0, "radius": 40.0, "duration": 4.0},
	"poison": {"name": "Poison bomb", "kind": "grenade", "price": 40, "short": "Poison",
		"effect": "poison", "damage": 5.0, "radius": 55.0, "duration": 6.0},
	"flash": {"name": "Flash grenade", "kind": "grenade", "price": 30, "short": "Flash",
		"effect": "flash", "damage": 0.0, "radius": 70.0, "stun": 3.5},
}
# --- Udstyr til kaptajnen ---------------------------------------------------
# slot: "hat", "coat" eller "sword". Stats:
#   luck: mere guld og bedre chance for loot · armor: mindre skade · damage/cooldown/reach: sværdet
# look: farver og form til tegningen af kaptajnen
const GEAR := {
	"tricorn": {"slot": "hat", "name": "Tricorn hat", "price": 0, "luck": 0.0, "look": {"shape": "tricorn", "color": Color(0.28, 0.18, 0.12)}},
	"straw": {"slot": "hat", "name": "Straw hat", "price": 80, "luck": 0.03, "look": {"shape": "straw", "color": Color(0.92, 0.82, 0.5)}},
	"bandana": {"slot": "hat", "name": "Bandana", "price": 140, "luck": 0.06, "look": {"shape": "bandana", "color": Color(0.8, 0.15, 0.15)}},
	"bicorne": {"slot": "hat", "name": "Bicorne hat", "price": 450, "luck": 0.09, "look": {"shape": "bicorne", "color": Color(0.12, 0.12, 0.16)}},
	"captain_hat": {"slot": "hat", "name": "Plumed captain's hat", "price": 1300, "luck": 0.15, "look": {"shape": "feather", "color": Color(0.15, 0.1, 0.08), "accent": Color(0.95, 0.3, 0.3)}},
	"shirt": {"slot": "coat", "name": "Red shirt", "price": 0, "armor": 0.0, "look": {"shape": "plain", "color": Color(0.72, 0.2, 0.2)}},
	"striped": {"slot": "coat", "name": "Striped shirt", "price": 160, "armor": 0.05, "look": {"shape": "striped", "color": Color(0.92, 0.92, 0.95), "accent": Color(0.2, 0.3, 0.6)}},
	"leather": {"slot": "coat", "name": "Leather coat", "price": 550, "armor": 0.14, "look": {"shape": "coat", "color": Color(0.45, 0.28, 0.15), "accent": Color(0.3, 0.18, 0.1)}},
	"captain_coat": {"slot": "coat", "name": "Captain's coat", "price": 1600, "armor": 0.22, "look": {"shape": "buttons", "color": Color(0.12, 0.18, 0.4), "accent": Color(0.95, 0.8, 0.3)}},
	"admiral": {"slot": "coat", "name": "Admiral's coat", "price": 4200, "armor": 0.3, "look": {"shape": "epaulettes", "color": Color(0.7, 0.1, 0.12), "accent": Color(0.95, 0.8, 0.3)}},
	"cutlass": {"slot": "sword", "name": "Cutlass", "price": 0, "damage": 10.0, "cooldown": 0.45, "reach": 20.0, "look": {"type": "saber", "length": 10.0, "width": 1.6, "color": Color(0.86, 0.88, 0.92)}},
	"belaying_pin": {"slot": "sword", "name": "Belaying pin", "price": 40, "damage": 8.0, "cooldown": 0.4, "reach": 16.0, "look": {"type": "club", "length": 8.0, "width": 1.4, "color": Color(0.6, 0.42, 0.25)}},
	"machete": {"slot": "sword", "name": "Machete", "price": 90, "damage": 9.0, "cooldown": 0.38, "reach": 18.0, "look": {"type": "machete", "length": 9.0, "width": 1.8, "color": Color(0.78, 0.8, 0.84)}},
	"dagger": {"slot": "sword", "name": "Dagger", "price": 120, "damage": 7.0, "cooldown": 0.25, "reach": 15.0, "look": {"type": "dagger", "length": 6.0, "width": 1.3, "color": Color(0.82, 0.84, 0.88)}},
	"hook": {"slot": "sword", "name": "Pirate hook", "price": 180, "damage": 9.0, "cooldown": 0.28, "reach": 14.0, "look": {"type": "hook", "length": 7.0, "width": 1.2, "color": Color(0.75, 0.77, 0.82)}},
	"boarding_axe": {"slot": "sword", "name": "Boarding axe", "price": 300, "damage": 14.0, "cooldown": 0.5, "reach": 19.0, "look": {"type": "axe", "length": 10.0, "width": 1.4, "color": Color(0.75, 0.77, 0.8)}},
	"spear": {"slot": "sword", "name": "Spear", "price": 450, "damage": 12.0, "cooldown": 0.5, "reach": 30.0, "look": {"type": "spear", "length": 17.0, "width": 1.2, "color": Color(0.82, 0.84, 0.88)}},
	"scimitar": {"slot": "sword", "name": "Scimitar", "price": 520, "damage": 13.0, "cooldown": 0.38, "reach": 21.0, "look": {"type": "scimitar", "length": 11.0, "width": 1.8, "color": Color(0.9, 0.9, 0.95)}},
	"mace": {"slot": "sword", "name": "Mace", "price": 600, "damage": 17.0, "cooldown": 0.6, "reach": 18.0, "look": {"type": "mace", "length": 9.0, "width": 1.4, "color": Color(0.62, 0.62, 0.68)}},
	"rapier": {"slot": "sword", "name": "Rapier", "price": 650, "damage": 12.0, "cooldown": 0.3, "reach": 25.0, "look": {"type": "rapier", "length": 14.0, "width": 0.9, "color": Color(0.92, 0.94, 0.97)}},
	"falchion": {"slot": "sword", "name": "Falchion", "price": 700, "damage": 15.0, "cooldown": 0.45, "reach": 20.0, "look": {"type": "falchion", "length": 10.0, "width": 2.0, "color": Color(0.8, 0.82, 0.86)}},
	"harpoon": {"slot": "sword", "name": "Harpoon", "price": 800, "damage": 15.0, "cooldown": 0.55, "reach": 32.0, "look": {"type": "harpoon", "length": 18.0, "width": 1.2, "color": Color(0.7, 0.72, 0.78)}},
	"broadsword": {"slot": "sword", "name": "Broadsword", "price": 950, "damage": 19.0, "cooldown": 0.6, "reach": 22.0, "look": {"type": "straight", "length": 12.0, "width": 2.4, "color": Color(0.78, 0.8, 0.84)}},
	"morning_star": {"slot": "sword", "name": "Morning star", "price": 1100, "damage": 20.0, "cooldown": 0.65, "reach": 20.0, "look": {"type": "morning_star", "length": 10.0, "width": 1.4, "color": Color(0.55, 0.55, 0.6)}},
	"flail": {"slot": "sword", "name": "Flail", "price": 1200, "damage": 21.0, "cooldown": 0.6, "reach": 22.0, "look": {"type": "flail", "length": 11.0, "width": 1.4, "color": Color(0.5, 0.5, 0.56)}},
	"war_hammer": {"slot": "sword", "name": "War hammer", "price": 1300, "damage": 23.0, "cooldown": 0.75, "reach": 19.0, "look": {"type": "hammer", "length": 10.0, "width": 1.4, "color": Color(0.6, 0.6, 0.66)}},
	"battle_axe": {"slot": "sword", "name": "Battle axe", "price": 1500, "damage": 24.0, "cooldown": 0.7, "reach": 21.0, "look": {"type": "great_axe", "length": 12.0, "width": 1.4, "color": Color(0.74, 0.76, 0.8)}},
	"trident": {"slot": "sword", "name": "Trident", "price": 1600, "damage": 18.0, "cooldown": 0.5, "reach": 30.0, "look": {"type": "trident", "length": 17.0, "width": 1.2, "color": Color(0.95, 0.8, 0.35)}},
	"katana": {"slot": "sword", "name": "Katana", "price": 2200, "damage": 19.0, "cooldown": 0.32, "reach": 24.0, "look": {"type": "katana", "length": 14.0, "width": 1.4, "color": Color(0.93, 0.95, 0.98)}},
	"claymore": {"slot": "sword", "name": "Claymore", "price": 2600, "damage": 27.0, "cooldown": 0.8, "reach": 27.0, "look": {"type": "claymore", "length": 16.0, "width": 2.4, "color": Color(0.8, 0.82, 0.88)}},
	"gold_sabre": {"slot": "sword", "name": "Golden saber", "price": 3200, "damage": 24.0, "cooldown": 0.4, "reach": 23.0, "look": {"type": "saber", "length": 12.0, "width": 1.9, "color": Color(0.97, 0.8, 0.32)}},
	"anchor": {"slot": "sword", "name": "Ship's anchor", "price": 4000, "damage": 32.0, "cooldown": 0.9, "reach": 24.0, "look": {"type": "anchor", "length": 13.0, "width": 1.6, "color": Color(0.42, 0.42, 0.48)}},
	"kraken_saber": {"slot": "sword", "name": "Kraken-tooth saber", "price": 5500, "damage": 30.0, "cooldown": 0.42, "reach": 25.0, "look": {"type": "scimitar", "length": 13.0, "width": 2.0, "color": Color(0.55, 0.95, 0.88), "glow": Color(0.3, 1.0, 0.85)}},
}
const GEAR_SLOTS := {"hat": "Hat", "coat": "Shirt / coat", "sword": "Melee weapon"}

const WEAPON_ORDER := ["sword", "pistol", "blunderbuss", "musket", "grenade", "firebomb", "poison", "flash"]
const GRENADE_THROW_RANGE := 170.0
const REPAIR_PRICE_PER_HP := 2

# --- Skibstyper ----------------------------------------------------------
# Værdierne er bevidst simple – det vigtigste er variation i udseende og pris.
# look: hvordan skibet tegnes (se ship_drawer.gd)
#   length/beam: længde og bredde i pixels · bow: 0 = buttet, 1 = spids stævn
#   stern: "square", "round" eller "pointed" · masts: placering langs skibet (-0.5 agter .. 0.5 for)
#   sails: sejltype pr. mast: "square", "lateen", "junk", "viking", "tattered"
#   hull/deck: grundfarver · cabin: kahyt agter · oars: årer langs siden
# crew: max besætning (betyder noget ved entring)
const SHIPS := {
	"dinghy": {
		"name": "Dinghy", "price": 300, "description": "Small open boat. Cheap and nimble.",
		"max_hp": 50, "speed": 105.0, "acceleration": 20.0, "turn": 1.3, "cargo": 8, "max_cannons": 3, "crew": 4,
		"look": {"length": 34, "beam": 9, "bow": 0.4, "stern": "square", "masts": [0.08], "sails": ["lateen"],
			"hull": Color(0.62, 0.45, 0.28), "deck": Color(0.78, 0.62, 0.42), "cabin": false, "oars": true},
	},
	"sloop": {
		"name": "Sloop", "price": 900, "description": "Small, fast and easy to handle.",
		"max_hp": 100, "speed": 115.0, "acceleration": 17.0, "turn": 1.05, "cargo": 20, "max_cannons": 4, "crew": 10,
		"look": {"length": 58, "beam": 12, "bow": 0.7, "stern": "square", "masts": [0.05], "sails": ["square"],
			"hull": Color(0.42, 0.26, 0.15), "deck": Color(0.66, 0.46, 0.25), "cabin": true, "oars": false},
	},
	"cutter": {
		"name": "Cutter", "price": 1300, "description": "Slim and fast with one big gaff sail.",
		"max_hp": 110, "speed": 125.0, "acceleration": 18.0, "turn": 1.1, "cargo": 18, "max_cannons": 4, "crew": 12,
		"look": {"length": 62, "beam": 11, "bow": 0.85, "stern": "round", "masts": [0.1], "sails": ["lateen"],
			"hull": Color(0.20, 0.30, 0.42), "deck": Color(0.72, 0.58, 0.40), "cabin": false, "oars": false},
	},
	"dhow": {
		"name": "Dhow", "price": 1500, "description": "Arabian trading ship with two lateen sails.",
		"max_hp": 120, "speed": 112.0, "acceleration": 15.0, "turn": 1.0, "cargo": 32, "max_cannons": 4, "crew": 12,
		"look": {"length": 66, "beam": 12, "bow": 0.95, "stern": "round", "masts": [0.18, -0.15], "sails": ["lateen", "lateen"],
			"hull": Color(0.55, 0.40, 0.25), "deck": Color(0.82, 0.68, 0.45), "cabin": false, "oars": false},
	},
	"longship": {
		"name": "Longship", "price": 1800, "description": "Viking ship with oars – room for a big boarding party.",
		"max_hp": 130, "speed": 120.0, "acceleration": 19.0, "turn": 1.0, "cargo": 16, "max_cannons": 3, "crew": 30,
		"look": {"length": 78, "beam": 10, "bow": 1.0, "stern": "pointed", "masts": [0.0], "sails": ["viking"],
			"hull": Color(0.40, 0.28, 0.18), "deck": Color(0.60, 0.44, 0.28), "cabin": false, "oars": true},
	},
	"schooner": {
		"name": "Schooner", "price": 2400, "description": "Two masts with gaff sails. Elegant and fast.",
		"max_hp": 150, "speed": 122.0, "acceleration": 15.0, "turn": 0.95, "cargo": 30, "max_cannons": 5, "crew": 16,
		"look": {"length": 74, "beam": 12, "bow": 0.8, "stern": "round", "masts": [0.18, -0.15], "sails": ["lateen", "lateen"],
			"hull": Color(0.18, 0.35, 0.30), "deck": Color(0.75, 0.62, 0.42), "cabin": true, "oars": false},
	},
	"caravel": {
		"name": "Caravel", "price": 2600, "description": "The explorers' ship – square and lateen sails.",
		"max_hp": 160, "speed": 105.0, "acceleration": 14.0, "turn": 0.95, "cargo": 40, "max_cannons": 5, "crew": 18,
		"look": {"length": 70, "beam": 14, "bow": 0.6, "stern": "square", "masts": [0.2, 0.0, -0.22], "sails": ["square", "lateen", "lateen"],
			"hull": Color(0.50, 0.33, 0.20), "deck": Color(0.70, 0.52, 0.32), "cabin": true, "oars": false},
	},
	"junk": {
		"name": "Junk", "price": 3000, "description": "East Asian ship with battened sails and a big hold.",
		"max_hp": 180, "speed": 98.0, "acceleration": 13.0, "turn": 0.9, "cargo": 55, "max_cannons": 5, "crew": 20,
		"look": {"length": 72, "beam": 16, "bow": 0.25, "stern": "square", "masts": [0.25, 0.0, -0.25], "sails": ["junk", "junk", "junk"],
			"hull": Color(0.55, 0.22, 0.15), "deck": Color(0.72, 0.55, 0.32), "cabin": true, "oars": false},
	},
	"brigantine": {
		"name": "Brigantine", "price": 3200, "description": "Versatile – good cargo and more cannons.",
		"max_hp": 190, "speed": 100.0, "acceleration": 13.0, "turn": 0.85, "cargo": 45, "max_cannons": 6, "crew": 24,
		"look": {"length": 76, "beam": 15, "bow": 0.7, "stern": "square", "masts": [0.15, -0.15], "sails": ["square", "lateen"],
			"hull": Color(0.38, 0.24, 0.14), "deck": Color(0.66, 0.46, 0.26), "cabin": true, "oars": false},
	},
	"brig": {
		"name": "Brig", "price": 4200, "description": "Two masts with square sails. A reliable warship.",
		"max_hp": 230, "speed": 104.0, "acceleration": 13.0, "turn": 0.85, "cargo": 50, "max_cannons": 7, "crew": 30,
		"look": {"length": 82, "beam": 16, "bow": 0.75, "stern": "square", "masts": [0.18, -0.12], "sails": ["square", "square"],
			"hull": Color(0.25, 0.20, 0.18), "deck": Color(0.66, 0.48, 0.28), "cabin": true, "oars": false},
	},
	"fluyt": {
		"name": "Fluyt", "price": 4500, "description": "Dutch cargo ship – huge hold, few cannons.",
		"max_hp": 200, "speed": 92.0, "acceleration": 11.0, "turn": 0.8, "cargo": 85, "max_cannons": 4, "crew": 22,
		"look": {"length": 84, "beam": 18, "bow": 0.45, "stern": "round", "masts": [0.22, 0.0, -0.22], "sails": ["square", "square", "lateen"],
			"hull": Color(0.48, 0.36, 0.22), "deck": Color(0.74, 0.58, 0.36), "cabin": true, "oars": false},
	},
	"corvette": {
		"name": "Corvette", "price": 5800, "description": "Fast three-masted warship.",
		"max_hp": 260, "speed": 112.0, "acceleration": 13.0, "turn": 0.85, "cargo": 40, "max_cannons": 7, "crew": 40,
		"look": {"length": 86, "beam": 15, "bow": 0.85, "stern": "round", "masts": [0.22, -0.02, -0.25], "sails": ["square", "square", "square"],
			"hull": Color(0.15, 0.18, 0.24), "deck": Color(0.70, 0.55, 0.35), "cabin": true, "oars": false},
	},
	"galleon": {
		"name": "Galleon", "price": 7500, "description": "Heavy floating fortress with a big hold.",
		"max_hp": 320, "speed": 85.0, "acceleration": 9.5, "turn": 0.65, "cargo": 90, "max_cannons": 8, "crew": 50,
		"look": {"length": 96, "beam": 20, "bow": 0.55, "stern": "square", "masts": [0.25, 0.03, -0.22], "sails": ["square", "square", "lateen"],
			"hull": Color(0.45, 0.28, 0.15), "deck": Color(0.68, 0.48, 0.26), "cabin": true, "oars": false},
	},
	"frigate": {
		"name": "Frigate", "price": 9500, "description": "Fast and heavily armed.",
		"max_hp": 360, "speed": 108.0, "acceleration": 11.0, "turn": 0.75, "cargo": 60, "max_cannons": 9, "crew": 60,
		"look": {"length": 100, "beam": 18, "bow": 0.8, "stern": "square", "masts": [0.25, 0.02, -0.23], "sails": ["square", "square", "square"],
			"hull": Color(0.20, 0.17, 0.15), "deck": Color(0.70, 0.52, 0.30), "cabin": true, "oars": false},
	},
	"ghost": {
		"name": "Ghost ship", "price": 12000, "description": "Tattered and eerie. The crew doesn't eat.",
		"max_hp": 280, "speed": 118.0, "acceleration": 14.0, "turn": 0.85, "cargo": 40, "max_cannons": 7, "crew": 35,
		"look": {"length": 88, "beam": 16, "bow": 0.7, "stern": "square", "masts": [0.18, -0.15], "sails": ["tattered", "tattered"],
			"hull": Color(0.30, 0.36, 0.34), "deck": Color(0.45, 0.50, 0.46), "cabin": true, "oars": false},
		"no_food": true,
	},
	"man_o_war": {
		"name": "Ship of the line", "price": 15000, "description": "King of the seas. Slow, but nearly unsinkable.",
		"max_hp": 500, "speed": 88.0, "acceleration": 9.0, "turn": 0.6, "cargo": 70, "max_cannons": 11, "crew": 90,
		"look": {"length": 116, "beam": 22, "bow": 0.7, "stern": "square", "masts": [0.27, 0.03, -0.22], "sails": ["square", "square", "square"],
			"hull": Color(0.18, 0.16, 0.14), "deck": Color(0.72, 0.55, 0.32), "cabin": true, "oars": false},
	},
}

# Fjender vælger mellem disse typer
const MERCHANT_SHIPS := ["sloop", "dhow", "junk", "fluyt", "caravel", "schooner", "galleon"]
const PIRATE_SHIPS := ["sloop", "cutter", "longship", "brig", "brigantine", "corvette", "frigate", "ghost"]

const CREW_PRICE := 20 ## pris for at hyre én sømand
const START_CREW := 6

# Fælles kanonværdier (påvirkes af opgraderinger)
const CANNON_BASE := {"damage": 12.0, "range": 380.0, "reload": 3.0, "ball_speed": 260.0}
const CANNON_PRICE := 300 ## pris for én ekstra kanon pr. side

# --- Opgraderinger (3 niveauer hver) ----------------------------------------
# per_level: hvor meget stat'en ændres pr. niveau (0.2 = +20 %)
# Hver opgradering har 100 små trin (tow har få, store trin).
# Prisen for trin n er base_cost * growth^n, så de første trin er billige og de sidste dyre.
const UPGRADE_MAX_LEVEL := 100
const UPGRADES := {
	"hull": {"name": "Hull", "stat": "max_hp", "per_level": 0.015, "base_cost": 30, "growth": 1.045, "text": "+1.5 % hull per step"},
	"armor": {"name": "Armor", "stat": "armor", "per_level": 0.006, "base_cost": 35, "growth": 1.045, "text": "-0.6 % damage taken per step"},
	"sails": {"name": "Sails", "stat": "speed", "per_level": 0.005, "base_cost": 28, "growth": 1.045, "text": "+0.5 % speed per step"},
	"cannon_power": {"name": "Cannon power", "stat": "damage", "per_level": 0.015, "base_cost": 30, "growth": 1.045, "text": "+1.5 % damage per step"},
	"cannon_range": {"name": "Cannon range", "stat": "range", "per_level": 0.008, "base_cost": 26, "growth": 1.045, "text": "+0.8 % range per step"},
	"reload": {"name": "Reload", "stat": "reload", "per_level": -0.005, "base_cost": 28, "growth": 1.045, "text": "-0.5 % reload time per step"},
	"cargo": {"name": "Cargo hold", "stat": "cargo", "per_level": 0.015, "base_cost": 22, "growth": 1.045, "text": "+1.5 % space per step"},
	"tow": {"name": "Towing gear", "stat": "tow", "per_level": 1, "costs": [450, 1400, 3500], "text": "+1 ship in tow per step"},
}

## Højeste trin for en opgradering.
static func upgrade_max(id: String) -> int:
	var up: Dictionary = UPGRADES[id]
	return (up["costs"] as Array).size() if up.has("costs") else UPGRADE_MAX_LEVEL

## Pris for at gå fra trin `level` til `level + 1` (-1 = allerede på max).
static func upgrade_price(id: String, level: int) -> int:
	if level >= upgrade_max(id):
		return -1
	var up: Dictionary = UPGRADES[id]
	if up.has("costs"):
		return int(up["costs"][level])
	return roundi(float(up["base_cost"]) * pow(float(up["growth"]), level) / 5.0) * 5

## Hvor mange erobrede skibe et skib kan slæbe uden opgraderinger (efter længde)
static func base_tow_slots(type: String) -> int:
	var length: float = SHIPS[type]["look"]["length"]
	return 0 if length < 50.0 else (1 if length < 85.0 else 2)

const TOW_SPEED_PENALTY := 0.12 ## fartnedsættelse pr. slæbt skib (ganget med dets størrelse)
const TOW_SELL_FACTOR := 0.45 ## et slæbt skib sælges for denne andel af nyprisen (ganget med skrogets stand)

# Flag i flere udgaver – de lange og bølgende er til prestige
# length/width i pixels, shape: "rect", "swallowtail", "pennant", "royal", "legend"
const FLAG_STYLES := [
	{"id": "small", "name": "Small flag", "price": 0, "length": 9.0, "width": 5.0, "shape": "rect"},
	{"id": "swallow", "name": "Swallowtail", "price": 250, "length": 13.0, "width": 6.0, "shape": "swallowtail"},
	{"id": "long", "name": "Long pennant", "price": 700, "length": 24.0, "width": 4.5, "shape": "pennant"},
	{"id": "royal", "name": "Royal flag", "price": 1800, "length": 18.0, "width": 9.0, "shape": "royal"},
	{"id": "legend", "name": "Legendary banner", "price": 6000, "length": 38.0, "width": 7.0, "shape": "legend"},
]

# --- Udseende -------------------------------------------------------------
const SAIL_COLORS := [
	{"id": "canvas", "name": "Canvas", "color": Color(1, 1, 1), "price": 0},
	{"id": "crimson", "name": "Crimson", "color": Color(0.95, 0.45, 0.42), "price": 150},
	{"id": "ocean", "name": "Ocean blue", "color": Color(0.55, 0.75, 1.0), "price": 150},
	{"id": "sun", "name": "Sun yellow", "color": Color(1.0, 0.88, 0.45), "price": 150},
	{"id": "black", "name": "Black", "color": Color(0.32, 0.32, 0.34), "price": 300},
]
const HULL_PAINTS := [
	{"id": "oak", "name": "Oak", "color": Color(1, 1, 1), "price": 0},
	{"id": "dark", "name": "Dark tar", "color": Color(0.55, 0.5, 0.48), "price": 200},
	{"id": "red", "name": "Red paint", "color": Color(1.0, 0.65, 0.6), "price": 200},
	{"id": "teal", "name": "Turquoise", "color": Color(0.6, 0.95, 0.9), "price": 200},
]
const FLAG_COLORS := [
	{"id": "black", "name": "Black", "color": Color(0.12, 0.12, 0.12), "price": 0},
	{"id": "red", "name": "Red", "color": Color(0.8, 0.15, 0.15), "price": 80},
	{"id": "green", "name": "Green", "color": Color(0.2, 0.6, 0.3), "price": 80},
	{"id": "gold", "name": "Gold", "color": Color(0.95, 0.75, 0.2), "price": 120},
]
const DECORATIONS := {
	"flag": {"name": "Masthead flag", "price": 100},
	"lanterns": {"name": "Lanterns", "price": 180},
	"figurehead": {"name": "Figurehead", "price": 450},
	"crows_nest": {"name": "Crow's nest", "price": 250},
}

# --- Kongeriger -------------------------------------------------------------
# Hvert kæmpe fastland har et kongerige med et slot. Du kan udfordre det til duel:
# din besætning og du mod slottets garnison. Vinder du, får du skatkammerets bytte.
# garrison: soldater ved første duel (+ garrison_growth for hver sejr) · strength: hvor godt de kæmper
const KINGDOMS := [
	{"id": "aurelia", "name": "Kingdom of Aurelia", "king": "King Alfonso", "color": Color(0.85, 0.2, 0.22), "accent": Color(0.98, 0.82, 0.3),
		"garrison": 14, "strength": 1.05, "loot_rolls": 1},
	{"id": "valdora", "name": "Kingdom of Valdora", "king": "Queen Isabella", "color": Color(0.2, 0.35, 0.8), "accent": Color(0.95, 0.95, 0.95),
		"garrison": 24, "strength": 1.2, "loot_rolls": 2},
	{"id": "nerath", "name": "Kingdom of Nerath", "king": "King Ottokar", "color": Color(0.18, 0.55, 0.3), "accent": Color(0.9, 0.75, 0.35),
		"garrison": 36, "strength": 1.35, "loot_rolls": 3},
]
const GARRISON_GROWTH := 4 ## flere soldater for hver gang du har slået kongeriget
const DUEL_COOLDOWN_MIN := 20.0 ## minutter (rigtig tid) før kongeriget kan udfordres igen

# --- Loot-tabeller --------------------------------------------------------
# gold: [min, max]. items: [id, min, max, chance 0-1]
const LOOT := {
	"beach_chest": {"gold": [25, 90], "items": [["rum", 1, 3, 0.5], ["pearls", 1, 2, 0.35], ["jewels", 1, 1, 0.12], ["spices", 1, 3, 0.4], ["cannonball", 5, 15, 0.4], ["shot", 5, 12, 0.4], ["grenade", 1, 2, 0.25], ["firebomb", 1, 1, 0.12]]},
	"floating_barrel": {"gold": [0, 20], "items": [["rum", 1, 2, 0.5], ["sugar", 1, 3, 0.5], ["food", 4, 10, 0.5], ["cannonball", 3, 8, 0.3]]},
	"merchant_wreck": {"gold": [40, 120], "items": [["stolen_cargo", 1, 3, 0.9], ["silk", 1, 2, 0.4], ["stolen_jewels", 1, 1, 0.25], ["food", 5, 12, 0.6]]},
	"pirate_wreck": {"gold": [60, 160], "items": [["stolen_jewels", 1, 2, 0.5], ["rum", 1, 3, 0.6], ["cannonball", 10, 25, 0.8], ["jewels", 1, 1, 0.15], ["shot", 6, 15, 0.5], ["grenade", 1, 3, 0.4], ["poison", 1, 1, 0.15]]},
	"crab": {"gold": [0, 0], "items": [["food", 2, 4, 1.0], ["pearls", 1, 1, 0.08]]},
	"snake": {"gold": [3, 12], "items": [["snake_skin", 1, 1, 0.9]]},
	"jaguar": {"gold": [0, 10], "items": [["jaguar_pelt", 1, 1, 0.9], ["food", 3, 6, 0.6]]},
	"boar": {"gold": [0, 0], "items": [["food", 6, 12, 1.0], ["boar_tusk", 1, 2, 0.7]]},
	"croc": {"gold": [0, 20], "items": [["croc_leather", 1, 2, 0.9], ["food", 4, 8, 0.5], ["pearls", 1, 1, 0.1]]},
	"golem": {"gold": [60, 180], "items": [["golem_core", 1, 1, 0.8], ["stone", 4, 8, 1.0], ["gold_ore", 1, 3, 0.6], ["jewels", 1, 2, 0.3]]},
	"kingdom_treasury": {"gold": [900, 1800], "items": [["royal_seal", 1, 2, 1.0], ["gold_bar", 2, 5, 0.9], ["jewels", 2, 5, 0.9], ["silk", 2, 6, 0.6], ["spices", 3, 8, 0.6], ["cannonball", 20, 40, 0.7], ["grenade", 2, 5, 0.5], ["katana", 1, 1, 0.15], ["claymore", 1, 1, 0.1], ["kraken_saber", 1, 1, 0.04]]},
	"shark": {"gold": [0, 0], "items": [["shark_tooth", 1, 2, 0.9], ["food", 4, 8, 0.6]]},
	"bandit": {"gold": [10, 35], "items": [["shot", 3, 8, 0.5], ["rum", 1, 1, 0.3], ["grenade", 1, 1, 0.1]]},
	"camp_chest": {"gold": [120, 320], "items": [["jewels", 1, 2, 0.5], ["stolen_jewels", 1, 2, 0.5], ["shot", 10, 25, 0.7],
		["grenade", 1, 3, 0.5], ["firebomb", 1, 2, 0.3], ["iron_bar", 1, 2, 0.3], ["bandana", 1, 1, 0.15], ["bicorne", 1, 1, 0.08],
		["rapier", 1, 1, 0.06], ["leather", 1, 1, 0.05], ["scimitar", 1, 1, 0.08], ["boarding_axe", 1, 1, 0.1], ["hook", 1, 1, 0.1]]},
}

# --- Havne ---------------------------------------------------------------
# kind: "trade" (køber ikke tyvegods) eller "pirate" (køber tyvegods, men har dyrere varer)
## Fraktioner: hver ejer flere havne. Omdømme (venskab) deles af alle fraktionens havne.
## kind: "trade" = lovlig handel, "pirate" = køber tyvegods.
const FACTIONS := {
	"aurelia": {"name": "Kingdom of Aurelia", "short": "Aurelia", "kind": "trade", "color": Color(0.85, 0.25, 0.25), "harbors": 7},
	"valdora": {"name": "Kingdom of Valdora", "short": "Valdora", "kind": "trade", "color": Color(0.3, 0.45, 0.9), "harbors": 7},
	"nerath": {"name": "Kingdom of Nerath", "short": "Nerath", "kind": "trade", "color": Color(0.25, 0.65, 0.35), "harbors": 7},
	"free": {"name": "Free Traders' League", "short": "Free Traders", "kind": "trade", "color": Color(0.95, 0.75, 0.3), "harbors": 10},
	"smugglers": {"name": "Smugglers' Brotherhood", "short": "Smugglers", "kind": "pirate", "color": Color(0.6, 0.35, 0.7), "harbors": 8},
}
## Havnenavne pr. fraktion. Den første frie havn er starthavnen midt i verden.
const HARBOR_NAMES := {
	"free": ["Sunhaven", "Pearl Bay", "Goldsand", "Driftwood Landing", "Saltmarsh", "Coral Point", "Windward Wharf", "Lantern Quay", "Mariner's Rest", "Seaglass Harbor"],
	"aurelia": ["Port Aurel", "Crimson Bay", "Kingsmouth", "Redcliff", "Sant Alfonso", "Ember Cove", "Rosewater"],
	"valdora": ["Valmar", "Azure Haven", "Queensport", "Bluestone", "Isabella's Rest", "Silverbay", "Tidewall"],
	"nerath": ["Nerholm", "Greenwater", "Ottokar's Pier", "Mosshaven", "Oakharbor", "Fernport", "Ironwood Quay"],
	"smugglers": ["Skeleton Cove", "Rum Bay", "Blackwater", "Cutthroat Creek", "Hangman's Hook", "Bilgerat Den", "Shadow Inlet", "Dead Man's Drop"],
}
const HARBORS := [ # bruges af gamle tests: de første fem havne
	{"name": "Sunhaven", "kind": "trade"},
	{"name": "Pearl Bay", "kind": "trade"},
	{"name": "Skeleton Cove", "kind": "pirate"},
	{"name": "Goldsand", "kind": "trade"},
	{"name": "Rum Bay", "kind": "pirate"},
]
const ISLAND_NAMES := [
	"Palm Isle", "Gull Rock", "Crab Reef", "Fog Isle", "Snake Isle", "Shark Fin", "Wind Isle", "Coconut Key", "Turtle Island", "The Lagoon",
	"Mango Key", "Parrot Isle", "Whale Rock", "Bone Key", "Cutlass Isle", "Moon Reef", "Sandpiper", "Hermit Isle", "Lost Key", "Barracuda Reef",
	"Pelican Isle", "Saltspray", "Rattlesnake Key", "Ghost Isle", "Iguana Key", "Starfish Reef", "Driftwood Isle", "Seahorse Key", "Copper Isle", "Brimstone",
	"Marooner's Isle", "Thunder Key", "Kelp Isle", "Lobster Rock", "Flamingo Key", "Smuggler's Rock", "Squall Isle", "Little Tortuga", "Jade Key", "Rumrunner Isle",
]
const VILLAGE_NAMES := ["Fisher's Nook", "Netmend", "Shellby", "Little Harbor", "Saltwick", "Oyster Row", "Gullcroft", "Reedmoor", "Cockle Cove", "Tidewick",
	"Mussel Point", "Sandy Hollow", "Driftby", "Herring Hut", "Kelpwick", "Crabbe", "Wavecrest", "Seabright", "Pebblebay", "Old Pier"]

# --- Main quest line: "The Sun King's Crown" -----------------------------------
# A treasure hunt across the world, one quest at a time. The Quests autoload
# (scripts/autoload/quests.gd) tracks progress; harbors, camps and boss spots are picked
# from the generated world the first time the quest line starts (see Quests.resolve_spots).

## The people who hand out quests. "look" is drawn by Portrait (scenes/ui/portrait.gd).
const QUEST_PEOPLE := {
	"maren": {"name": "Old Maren", "title": "Cartographer", "look": {"skin": Color(0.96, 0.8, 0.68), "hair": Color(0.82, 0.82, 0.85),
		"hair_style": "bun", "hat": "none", "beard": "none", "glasses": true, "coat": Color(0.35, 0.45, 0.55)}},
	"tobias": {"name": "Tobias Quill", "title": "Harbor master", "look": {"skin": Color(0.9, 0.72, 0.58), "hair": Color(0.45, 0.3, 0.18),
		"hair_style": "short", "hat": "cap", "hat_color": Color(0.2, 0.3, 0.5), "beard": "mustache", "coat": Color(0.25, 0.32, 0.55)}},
	"vex": {"name": "\"Silent\" Vex", "title": "Smugglers' Brotherhood", "look": {"skin": Color(0.78, 0.6, 0.45), "hair": Color(0.12, 0.1, 0.1),
		"hair_style": "long", "hat": "hood", "hat_color": Color(0.32, 0.2, 0.4), "beard": "none", "eyepatch": true, "earring": true, "coat": Color(0.25, 0.16, 0.3)}},
	"ruben": {"name": "Old Salt Ruben", "title": "Smuggler captain", "look": {"skin": Color(0.88, 0.66, 0.52), "hair": Color(0.7, 0.7, 0.7),
		"hair_style": "bald", "hat": "bandana", "hat_color": Color(0.75, 0.2, 0.18), "beard": "full", "beard_color": Color(0.75, 0.75, 0.75), "earring": true, "coat": Color(0.4, 0.3, 0.2)}},
	"ilsa": {"name": "Ilsa Brandt", "title": "Scholar of old runes", "look": {"skin": Color(0.5, 0.34, 0.24), "hair": Color(0.1, 0.08, 0.07),
		"hair_style": "long", "hat": "none", "beard": "none", "glasses": true, "coat": Color(0.2, 0.35, 0.6)}},
	"celestine": {"name": "Lady Celestine", "title": "Envoy of Aurelia", "look": {"skin": Color(0.98, 0.85, 0.75), "hair": Color(0.95, 0.8, 0.45),
		"hair_style": "long", "hat": "feather", "hat_color": Color(0.75, 0.15, 0.2), "beard": "none", "earring": true, "coat": Color(0.7, 0.15, 0.2)}},
}

## The quest line, in order. Fields:
##   type: "gather" (bring items), "delivery" (carry something to another harbor) or "boss"
##   giver / turn_in: person id; turn_in defaults to the giver
##   at / turn_in_at / target: where, resolved once from the world:
##     "start" = Sunhaven, "<quest id>.giver" / ".turn_in" = same harbor as an earlier quest,
##     {"faction": f, "near": ref, "dist": d} = that faction's harbor closest to d px from ref,
##     {"sea": ref, "dist": d} = open water, {"camp": ref, "dist": d} = a pirate camp,
##     {"wild_mainland": ref} = a mainland without a kingdom, {"islet": ref, "dist": d} = a small island
##   boss: {"kind": "ship"/"beast"/"bandit", "name", ...}; treasure: dig up a chest after the boss
##   %s in offer lines is replaced by the turn-in harbor's name.
const QUESTS := [
	{"id": "ink", "title": "Ink and Parchment", "type": "gather", "giver": "maren", "at": "start",
		"items": {"wood": 8, "herbs": 3},
		"offer": ["Ah, a new captain! That old scrap of map you carry... may I see it?",
			"By the tides – this is the Sun King's hand! I must copy it before it falls apart.",
			"Bring me 8 Wood for a drawing board and 3 Herbs for ink. Trees and herb bushes grow on the islands."],
		"done": ["Splendid. Now look closely: the map is torn, and three pieces are missing.",
			"The Sun King's Crown is real, captain. And you hold the first clue."],
		"reward": {"gold": 300, "rep": 150}},
	{"id": "letter", "title": "The Sealed Letter", "type": "delivery", "giver": "maren", "at": "start",
		"turn_in": "tobias", "turn_in_at": {"faction": "free", "near": "start", "dist": 2600.0},
		"offer": ["An old friend of mine, Tobias Quill, keeps the harbor at %s.",
			"He hears every rumour on the sea. Take him this letter about your map.",
			"It's light – it won't take any room in your hold."],
		"done": ["A letter from Maren? Let me read... The Sun King's map! Keep your voice down, captain.",
			"I know who has the first missing piece. You won't like the answer."],
		"reward": {"gold": 400, "rep": 250}},
	{"id": "gull", "title": "The Black Gull", "type": "boss", "giver": "tobias", "at": "letter.turn_in",
		"target": {"sea": "letter.turn_in", "dist": 1100.0},
		"boss": {"kind": "ship", "name": "the Black Gull", "ship": "cutter", "hp": 3.0},
		"offer": ["A pirate ship, the Black Gull, robbed a scholar last month and took a piece of old map.",
			"She lurks in the waters nearby – I've marked the spot on your map.",
			"Sink her, and the map piece floats up with the wreck."],
		"done": ["You sank the Black Gull? The whole harbor heard the cannons!",
			"And there's the map piece – a little wet, but readable. One of three."],
		"reward": {"gold": 1200, "rep": 500}},
	{"id": "nerve", "title": "Proof of Nerve", "type": "gather", "giver": "vex", "at": {"faction": "smugglers", "near": "gull.giver", "dist": 2600.0},
		"items": {"shark_tooth": 3, "jaguar_pelt": 2},
		"offer": ["...",
			"Tobias sent you. The Brotherhood knows where the second piece is.",
			"But we don't talk to soft hands. Bring me 3 Shark teeth and 2 Jaguar pelts."],
		"done": ["Hm. You have teeth yourself, captain.", "Fine. The Brotherhood will talk – after one more favour."],
		"reward": {"gold": 800, "rep": 600}},
	{"id": "tarp", "title": "Under the Tarp", "type": "delivery", "giver": "vex", "at": "nerve.giver",
		"turn_in": "ruben", "turn_in_at": {"faction": "smugglers", "near": "nerve.giver", "dist": 2600.0},
		"offer": ["Four crates. Don't ask what's inside, and don't open them.",
			"Bring them to Old Salt Ruben in %s. He knows about your map.",
			"They ride under a tarp on deck – no room needed in your hold."],
		"done": ["Vex's crates, all four, and not one opened. An honest smuggler!",
			"Now, about your map piece. I know exactly where it is – and I hate the man who has it."],
		"reward": {"gold": 1000, "rep": 700}},
	{"id": "redbeard", "title": "Redbeard's Camp", "type": "boss", "giver": "ruben", "at": "tarp.turn_in",
		"target": {"camp": "tarp.turn_in", "dist": 1400.0},
		"boss": {"kind": "bandit", "name": "Chief Redbeard", "hp": 260.0, "guards": 3},
		"offer": ["Redbeard runs a camp of cutthroats on an island close by. I've marked it on your map.",
			"He wears the second map piece around his neck like a medal. The fool.",
			"Go ashore with your pistol loaded. He doesn't fight alone."],
		"done": ["Redbeard is gone? Ha! I'll drink to that tonight.", "Here – the piece is yours. Two of three, captain."],
		"reward": {"gold": 2000, "rep": 900}},
	{"id": "runes", "title": "Runes in Stone", "type": "gather", "giver": "ilsa", "at": {"faction": "valdora", "near": "redbeard.giver", "dist": 0.0},
		"items": {"golem_core": 2},
		"offer": ["You have two pieces of the Sun King's map? May I... oh. Oh my.",
			"These runes are old Solari script. I can read them, but only by the light of a golem core.",
			"Golems roam the big wild mainlands. Bring me 2 Golem cores."],
		"done": ["The cores glow... and the runes appear! \"Where the jungle king sleeps, the third path begins.\"",
			"The jungle king – it must be a beast. A very, very large one."],
		"reward": {"gold": 1500, "rep": 900}},
	{"id": "jungle", "title": "The Jungle King", "type": "boss", "giver": "ilsa", "at": "runes.giver",
		"target": {"wild_mainland": "runes.giver"},
		"boss": {"kind": "beast", "beast": "jaguar", "name": "the Jungle King", "hp": 8.0, "size": 1.9, "damage": 1.6},
		"offer": ["The hunters speak of a jaguar twice the size of a man, ruling a wild mainland.",
			"I've marked its hunting ground on your map. The last map piece lies in its den.",
			"Please be careful. Bring food, and a strong blade."],
		"done": ["You faced the Jungle King and lived? And the last piece!",
			"With all three... the map points to a small island in the waters of Aurelia."],
		"reward": {"gold": 3000, "rep": 1200}},
	{"id": "petition", "title": "Royal Permission", "type": "delivery", "giver": "ilsa", "at": "jungle.giver",
		"turn_in": "celestine", "turn_in_at": {"faction": "aurelia", "near": "jungle.giver", "dist": 0.0},
		"offer": ["The waters around that island belong to the Kingdom of Aurelia. Nobody sails there without permission.",
			"I've written a petition, sealed by the university. Take it to Lady Celestine in %s.",
			"She is strict, but fair."],
		"done": ["A petition... for the Sun King's island? You are either brave or mad, captain.",
			"Very well. Aurelia grants you passage. But you are not the only one who wants that crown."],
		"reward": {"gold": 1500, "rep": 1500}},
	{"id": "crown", "title": "The Drowned Crown", "type": "boss", "giver": "celestine", "at": "petition.turn_in",
		"turn_in": "maren", "turn_in_at": "start",
		"target": {"islet": "petition.turn_in", "dist": 2200.0},
		"boss": {"kind": "ship", "name": "the Barracuda", "ship": "brig", "hp": 4.0}, "treasure": true,
		"offer": ["Captain Barracuda – the worst pirate on these seas – guards the Sun King's island.",
			"Sink his ship, then go ashore and dig where the map shows. The spot is marked.",
			"Then bring the crown home to Old Maren, who started you on this path."],
		"done": ["Is that... the Crown of the Sun King. In my little shop.",
			"You did it, captain. Every sailor from here to Aurelia will know your name.",
			"Keep the crown – but promise me you'll let me draw it first."],
		"reward": {"gold": 10000, "rep": 2500}},
]

## Loot from quest bosses and the final treasure (merged into LOOT by Game.give_loot).
const QUEST_LOOT := {
	"quest_boss": {"gold": [400, 900], "items": [["jewels", 2, 4, 1.0], ["stolen_jewels", 1, 3, 0.8], ["pearls", 2, 4, 0.8], ["ancient_coin", 1, 1, 0.5]]},
	"sun_treasure": {"gold": [3000, 5000], "items": [["sun_crown", 1, 1, 1.0], ["gold_bar", 3, 6, 1.0], ["jewels", 4, 8, 1.0], ["ancient_coin", 1, 3, 1.0]]},
}
