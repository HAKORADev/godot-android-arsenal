class_name CSData
## COSMIC SPUD - the data tables (the GDD's numbers, frozen).
## Every price in COSMIC COINS (the game's own currency). Every law the
## probe asserts lives here as data.

# ================================================================== STARTS
## the 6 STARTS (the owner: "each game start it gives 6 options in the game
## optionals menu while each one of them has different base skills set")
const STARTS := {
        "soldier": {"name": "THE SOLDIER", "hp": 100.0, "dmg": 1.00, "spd": 1.00,
                "aspeed": 1.00, "range": 1.00, "armor": 0, "crit": 0.00, "regen": 0.0,
                "perk": "+10% damage with every weapon", "tint": Color(1, 1, 1)},
        "ranger": {"name": "THE RANGER", "hp": 70.0, "dmg": 1.00, "spd": 1.15,
                "aspeed": 1.10, "range": 1.30, "armor": 0, "crit": 0.15, "regen": 0.0,
                "perk": "+15% crit chance, +10% luck", "tint": Color(0.8, 1, 0.85),
                "luck": 0.10},
        "brawler": {"name": "THE BRAWLER", "hp": 140.0, "dmg": 1.30, "spd": 1.05,
                "aspeed": 1.00, "range": 0.65, "armor": 2, "crit": 0.00, "regen": 0.0,
                "perk": "+2 armor, contact damage -20%", "tint": Color(1, 0.85, 0.8)},
        "engineer": {"name": "THE ENGINEER", "hp": 90.0, "dmg": 0.85, "spd": 1.00,
                "aspeed": 1.00, "range": 1.00, "armor": 0, "crit": 0.05, "regen": 0.0,
                "perk": "starts with a free DRONE BUDDY, +25% ally damage",
                "tint": Color(0.85, 0.9, 1), "ally": "drone"},
        "pyro": {"name": "THE PYRO", "hp": 85.0, "dmg": 1.10, "spd": 1.00,
                "aspeed": 1.00, "range": 1.00, "armor": 0, "crit": 0.00, "regen": 0.0,
                "perk": "every hit applies BURN (2/s for 3s)", "tint": Color(1, 0.8, 0.6)},
        "frostbite": {"name": "THE FROSTBITE", "hp": 95.0, "dmg": 0.95, "spd": 1.00,
                "aspeed": 1.00, "range": 1.05, "armor": 0, "crit": 0.05, "regen": 0.0,
                "perk": "every hit CHILLS (-20% enemy speed, +10% taken), 5% dodge",
                "tint": Color(0.8, 0.92, 1), "dodge": 0.05},
}
const START_ORDER := ["soldier", "ranger", "brawler", "engineer", "pyro", "frostbite"]

# ================================================================== WEAPONS
## 12 weapons x 3 tiers. price = the T1 GogaShop price (high, the owner's
## law); t2/t3 derive: t2 = t1*2.2, t3 = t1*3.8 (rounded to 10). Merging
## two same-tier copies costs HALF the next tier's price (the owner's law).
const WEAPONS := {
        "smg":       {"name": "SPUD SMG",       "dmg": 8.0,  "cad": 0.25, "rng": 300.0,
                "pspd": 640.0, "count": 1, "spread": 0.06, "pierce": 0, "price": 250,
                "shot": "cs_shot_smg", "proj": "bolt"},
        "shotgun":   {"name": "SCATTER SPUD",   "dmg": 5.0,  "cad": 0.90, "rng": 240.0,
                "pspd": 560.0, "count": 5, "spread": 0.42, "pierce": 0, "price": 320,
                "shot": "cs_shot_shotgun", "proj": "pellet"},
        "rifle":     {"name": "RUSTY RIFLE",    "dmg": 20.0, "cad": 1.10, "rng": 420.0,
                "pspd": 820.0, "count": 1, "spread": 0.02, "pierce": 1, "price": 380,
                "shot": "cs_shot_rifle", "proj": "slug"},
        "laser":     {"name": "LASER PEELER",   "dmg": 14.0, "cad": 0.65, "rng": 380.0,
                "pspd": 980.0, "count": 1, "spread": 0.0, "pierce": 2, "price": 460,
                "shot": "cs_shot_laser", "proj": "lance"},
        "cannon":    {"name": "SPUD CANNON",    "dmg": 30.0, "cad": 1.40, "rng": 340.0,
                "pspd": 480.0, "count": 1, "spread": 0.04, "pierce": 0, "price": 520,
                "shot": "cs_boom", "proj": "bomb", "aoe": 60.0},
        "frost":     {"name": "FROST BLOOMER",  "dmg": 10.0, "cad": 0.80, "rng": 300.0,
                "pspd": 600.0, "count": 2, "spread": 0.18, "pierce": 0, "price": 480,
                "shot": "cs_frost", "proj": "shard", "chill": 1.5},
        "flame":     {"name": "FLAME TATER",    "dmg": 6.0,  "cad": 0.13, "rng": 170.0,
                "pspd": 380.0, "count": 1, "spread": 0.22, "pierce": 9, "price": 500,
                "shot": "cs_burn", "proj": "flamepuff", "burn": true},
        "rail":      {"name": "RAIL TATER",     "dmg": 45.0, "cad": 1.60, "rng": 560.0,
                "pspd": 1400.0, "count": 1, "spread": 0.0, "pierce": 99, "price": 720,
                "shot": "cs_rail", "proj": "rail"},
        "boomerang": {"name": "BOOMERANG PEEL", "dmg": 16.0, "cad": 1.10, "rng": 330.0,
                "pspd": 520.0, "count": 1, "spread": 0.0, "pierce": 99, "price": 560,
                "shot": "cs_flash", "proj": "boomerang"},
        "minigun":   {"name": "PRICKLY MINIGUN", "dmg": 5.0, "cad": 0.11, "rng": 280.0,
                "pspd": 700.0, "count": 1, "spread": 0.14, "pierce": 0, "price": 640,
                "shot": "cs_shot_minigun", "proj": "tracer"},
        "fryer":     {"name": "ORBITAL FRYER",  "dmg": 35.0, "cad": 3.00, "rng": 900.0,
                "pspd": 0.0, "count": 1, "spread": 0.0, "pierce": 0, "price": 820,
                "shot": "cs_boom", "proj": "strike", "aoe": 70.0},
        "gravity":   {"name": "GRAVITY WELL",   "dmg": 18.0, "cad": 2.20, "rng": 420.0,
                "pspd": 260.0, "count": 1, "spread": 0.0, "pierce": 0, "price": 900,
                "shot": "cs_boom", "proj": "orb", "aoe": 90.0, "pull": 2.0},
}
const WEAPON_ORDER := ["smg", "shotgun", "rifle", "laser", "cannon", "frost",
        "flame", "rail", "boomerang", "minigun", "fryer", "gravity"]
## the 3 weapons every new player owns (the owner: "starts with only 3")
const START_WEAPONS := ["smg", "shotgun", "rifle"]

static func tier_mult(tier: int) -> Dictionary:
        # T1 = the table; T2 = x1.6 dmg / x0.9 cad; T3 = x2.4 dmg / x0.8 cad +1 proj
        match tier:
                2: return {"dmg": 1.6, "cad": 0.9, "count": 0}
                3: return {"dmg": 2.4, "cad": 0.8, "count": 1}
        return {"dmg": 1.0, "cad": 1.0, "count": 0}

static func weapon_price(wid: String, tier: int) -> int:
        var base: int = int(WEAPONS[wid]["price"])
        var p := base
        if tier == 2:
                p = int(round(base * 2.2 / 10.0)) * 10
        elif tier >= 3:
                p = int(round(base * 3.8 / 10.0)) * 10
        return p

static func merge_price(wid: String, from_tier: int) -> int:
        # THE MERGE LAW: half of the NEXT tier's buy price
        return int(ceil(weapon_price(wid, from_tier + 1) / 2.0))

# ================================================================== ENEMIES
## the python v1.3.8 numbers preserved (hp/spd/dmg/xp) + the new six.
## score = the kill score law (the owner: basic +1, most +2, bosses big).
const ENEMIES := {
        "blab":     {"name": "BLAB", "hp": 30.0, "spd": 80.0, "dmg": 10.0, "size": 22.0,
                "xp": 1, "score": 1, "tex": "blab", "from": 1},
        "sprinter": {"name": "SPRINTER", "hp": 15.0, "spd": 160.0, "dmg": 8.0, "size": 17.0,
                "xp": 1, "score": 1, "tex": "sprinter", "from": 2},
        "chunk":    {"name": "CHUNK", "hp": 80.0, "spd": 40.0, "dmg": 20.0, "size": 30.0,
                "xp": 2, "score": 2, "tex": "chunk", "from": 3},
        "spitter":  {"name": "SPITTER", "hp": 25.0, "spd": 60.0, "dmg": 15.0, "size": 23.0,
                "xp": 2, "score": 2, "tex": "spitter", "from": 4, "shoot": true,
                "keep": 260.0},
        "wraith":   {"name": "AURA WRAITH", "hp": 100.0, "spd": 30.0, "dmg": 10.0, "size": 30.0,
                "xp": 4, "score": 4, "tex": "wraith", "from": 5, "aura": 250.0,
                "aura_dps": 15.0},
        "brood":    {"name": "BROODMOTHER", "hp": 50.0, "spd": 45.0, "dmg": 10.0, "size": 26.0,
                "xp": 3, "score": 3, "tex": "brood", "from": 6, "split": ["minion", "minion"]},
        "trishield": {"name": "TRI-SHIELD", "hp": 300.0, "spd": 50.0, "dmg": 20.0, "size": 30.0,
                "xp": 6, "score": 6, "tex": "trishield", "from": 7, "rings": true},
        "mender":   {"name": "MENDER", "hp": 1000.0, "spd": 35.0, "dmg": 10.0, "size": 30.0,
                "xp": 8, "score": 8, "tex": "mender", "from": 8, "heal": 500.0},
        "charger":  {"name": "CHARGER", "hp": 45.0, "spd": 95.0, "dmg": 18.0, "size": 26.0,
                "xp": 2, "score": 2, "tex": "charger", "from": 9, "charge": true},
        "boomling": {"name": "BOOMLING", "hp": 20.0, "spd": 115.0, "dmg": 5.0, "size": 20.0,
                "xp": 1, "score": 1, "tex": "boomling", "from": 10, "bomb": true},
        "splitter": {"name": "SPLITTER", "hp": 40.0, "spd": 80.0, "dmg": 12.0, "size": 22.0,
                "xp": 2, "score": 2, "tex": "splitter", "from": 11, "split_gen": 2},
        "orbiter":  {"name": "ORBITER", "hp": 35.0, "spd": 135.0, "dmg": 10.0, "size": 24.0,
                "xp": 2, "score": 2, "tex": "orbiter", "from": 12, "orbit": true},
        "minion":   {"name": "MINION", "hp": 15.0, "spd": 140.0, "dmg": 8.0, "size": 13.0,
                "xp": 1, "score": 1, "tex": "minion", "from": 99},
}
const SPAWN_POOL := ["blab", "blab", "blab", "sprinter"]  # wave 1

const ELITE_AFFIX := {
        "frenzied": {"name": "FRENZIED", "spd": 1.4, "hurt": 1.0},
        "armored":  {"name": "ARMORED", "spd": 1.0, "hurt": 0.7},
        "colossal": {"name": "COLOSSAL", "spd": 1.0, "hurt": 1.0, "hp": 1.5,
                "scale": 1.5, "dmg": 1.5},
        "vampiric": {"name": "VAMPIRIC", "spd": 1.0, "hurt": 1.0},
}
const ELITE_SCORE := 3

# =================================================================== BOSSES
const BOSSES := {
        "heap": {"name": "THE HEAP", "hp": 2600.0, "spd": 42.0, "dmg": 30.0,
                "size": 56.0, "score": 50, "xp": 40, "coins": 30, "tex": "boss_heap",
                "slam": true, "summon": "brood", "summon_n": 4, "charge": true},
        "prism": {"name": "THE PRISM MATRIARCH", "hp": 5200.0, "spd": 34.0, "dmg": 26.0,
                "size": 56.0, "score": 100, "xp": 80, "coins": 55, "tex": "boss_prism",
                "rings": [110.0, 90.0, 70.0, 50.0], "burst": true, "self_mend": 12.0},
        "reaper": {"name": "SPUD REAPER", "hp": 7400.0, "spd": 105.0, "dmg": 34.0,
                "size": 56.0, "score": 80, "xp": 60, "coins": 45, "tex": "boss_reaper",
                "triple_charge": true, "aura": 160.0, "aura_dps": 18.0, "teleport": 4},
}
const BOSS_CYCLE := 10          # a boss every 10 waves
const BOSS_ORDER := ["heap", "prism", "reaper"]
const BOSS_CYCLE_MULT := 1.25   # per cycle stats
const BOSS_CYCLE_SCORE := 20

# =================================================================== ALLIES
const ALLIES := {
        "drone":  {"name": "DRONE BUDDY", "price": 1200, "tex": "orbiter",
                "desc": "orbits you, shoots 2/s (damage grows with level)"},
        "turret": {"name": "TATER TURRET", "price": 1500, "tex": "boomling",
                "desc": "plants near you, sweeps 360"},
        "guard":  {"name": "GUARD SPUD", "price": 1800, "tex": "chunk",
                "desc": "bodyblocks and taunts nearby enemies"},
        "medic":  {"name": "MEDIC SPROUT", "price": 2000, "tex": "mender",
                "desc": "heals you 2 HP/s (+1 per level)"},
        "bomber": {"name": "BOMBER CHIP", "price": 2300, "tex": "boomling",
                "desc": "kamikaze dives every 8s, respawns in 5s"},
        "scout":  {"name": "SCOUT FRY", "price": 2600, "tex": "orbiter",
                "desc": "marks enemies in 300px: +15% damage taken"},
}
const ALLY_ORDER := ["drone", "turret", "guard", "medic", "bomber", "scout"]
const ALLY_MAX_LEVEL := 3

static func ally_level_price(aid: String, level: int) -> int:
        # the price to DEPLOY/RAISE an owned ally to `level` in the wave shop
        var base: int = int(ALLIES[aid]["price"])
        return int(round(base * 0.28 * level / 10.0)) * 10

static func ally_merge_price(aid: String, level: int) -> int:
        # merging two level `level` allies -> level+1: HALF the next level price
        return int(ceil(ally_level_price(aid, level + 1) / 2.0))

# ==================================================================== TREE
## 18 nodes, 4 branches, chains unlock ONE BY ONE for cosmic coins
## (the owner: "like advanced ubisoft games"). `need` = the prerequisite
## node id ("" = root). `clv` = the character level gate.
const TREE := {
        "o1": {"name": "SHARP PEEL", "branch": "OFFENSE", "cost": 120, "need": "",
                "clv": 1, "desc": "+8% run damage"},
        "o2": {"name": "HOT STARCH", "branch": "OFFENSE", "cost": 260, "need": "o1",
                "clv": 1, "desc": "+8% more run damage"},
        "o3": {"name": "THIRD HOLSTER", "branch": "OFFENSE", "cost": 520, "need": "o2",
                "clv": 3, "desc": "+1 weapon slot (5 total)"},
        "o4": {"name": "EYE OF THE SPUD", "branch": "OFFENSE", "cost": 640, "need": "o3",
                "clv": 6, "desc": "+10% crit chance"},
        "o5": {"name": "CRIT MASTERY", "branch": "OFFENSE", "cost": 980, "need": "o4",
                "clv": 9, "desc": "crits deal x3 (was x2)"},
        "d1": {"name": "THICK SKIN", "branch": "DEFENSE", "cost": 120, "need": "",
                "clv": 1, "desc": "+20 run max HP"},
        "d2": {"name": "IRON PEEL", "branch": "DEFENSE", "cost": 300, "need": "d1",
                "clv": 2, "desc": "+2 armor"},
        "d3": {"name": "REGEN ROOT", "branch": "DEFENSE", "cost": 560, "need": "d2",
                "clv": 4, "desc": "+1 HP/s regen"},
        "d4": {"name": "SECOND WIND", "branch": "DEFENSE", "cost": 1100, "need": "d3",
                "clv": 7, "desc": "one revive per run at 50% HP"},
        "u1": {"name": "MAGNET MASH", "branch": "UTILITY", "cost": 100, "need": "",
                "clv": 1, "desc": "+30% pickup magnet"},
        "u2": {"name": "GOLDEN DRIP", "branch": "UTILITY", "cost": 240, "need": "u1",
                "clv": 1, "desc": "+10% cosmic coins earned"},
        "u3": {"name": "FATE REROLL", "branch": "UTILITY", "cost": 480, "need": "u2",
                "clv": 3, "desc": "1 free wave-draft reroll each break"},
        "u4": {"name": "MARKET TONGUE", "branch": "UTILITY", "cost": 760, "need": "u3",
                "clv": 6, "desc": "wave shop prices -10%"},
        "l1": {"name": "EXTRA LEASH", "branch": "LAB", "cost": 340, "need": "",
                "clv": 2, "desc": "+1 deployed ally (3 total)"},
        "l2": {"name": "ALLY POWER", "branch": "LAB", "cost": 620, "need": "l1",
                "clv": 4, "desc": "+25% ally damage"},
        "l3": {"name": "WEAPON LAB", "branch": "LAB", "cost": 900, "need": "l2",
                "clv": 4, "desc": "LEARN WEAPON MERGING (the owner's law)"},
        "l4": {"name": "FOUNDRY", "branch": "LAB", "cost": 1200, "need": "l3",
                "clv": 8, "desc": "merge prices -25%"},
        "l5": {"name": "SIXTH SLOT", "branch": "LAB", "cost": 1400, "need": "l4",
                "clv": 10, "desc": "+1 weapon slot (6 total)"},
}
const TREE_ORDER := ["o1", "o2", "o3", "o4", "o5", "d1", "d2", "d3", "d4",
        "u1", "u2", "u3", "u4", "l1", "l2", "l3", "l4", "l5"]

# =================================================================== THEMES
const THEMES := {
        "desert": {"name": "DECAYED DESERT", "price": 0,
                "day": "res://assets/games/cosmic_spud/ground/desert_day.png",
                "night": "res://assets/games/cosmic_spud/ground/desert_night.png",
                "day_music": "res://assets/audio/music/cs_desert_day.ogg",
                "night_music": "res://assets/audio/music/cs_desert_night.ogg",
                "props": ["rock", "skull", "crate", "barrel", "shrub"],
                "night_props": ["rock", "skull", "barrel"],
                "tint_day": Color(1, 1, 1), "tint_night": Color(0.62, 0.66, 0.95)},
        "park": {"name": "ABANDONED PARK", "price": 800,
                "day": "res://assets/games/cosmic_spud/ground/park_day.png",
                "night": "res://assets/games/cosmic_spud/ground/park_night.png",
                "day_music": "res://assets/audio/music/cs_park_day.ogg",
                "night_music": "res://assets/audio/music/cs_park_night.ogg",
                "props": ["tree", "bench", "fence", "shrub", "crate"],
                "night_props": ["tree", "bench", "fence"],
                "tint_day": Color(1, 1, 1), "tint_night": Color(0.6, 0.7, 0.9)},
}
const THEME_ORDER := ["desert", "park"]

# =============================================================== WAVE DRAFTS
## per-wave drafts WITH TEETH (the owner: "offer things and take things,
## like +20 damage and -20 speed"). Each card: an UP and most a DOWN.
const WAVE_DRAFTS := [
        {"t": "+20% DAMAGE", "d": "-10% move speed", "up": {"dmg": 0.20},
                "down": {"spd": -0.10}, "w": 10},
        {"t": "+25% ATTACK SPEED", "d": "-8% damage", "up": {"aspeed": 0.25},
                "down": {"dmg": -0.08}, "w": 10},
        {"t": "+30 MAX HP", "d": "-5% move speed", "up": {"hp": 30},
                "down": {"spd": -0.05}, "w": 10},
        {"t": "+15% MOVE SPEED", "d": "-10 max HP", "up": {"spd": 0.15},
                "down": {"hp": -10}, "w": 10},
        {"t": "+1 PROJECTILE", "d": "-15% range", "up": {"proj": 1},
                "down": {"range": -0.15}, "w": 5},
        {"t": "+20% RANGE", "d": "-8% attack speed", "up": {"range": 0.20},
                "down": {"aspeed": -0.08}, "w": 10},
        {"t": "+2 ARMOR", "d": "-6% move speed", "up": {"armor": 2},
                "down": {"spd": -0.06}, "w": 8},
        {"t": "+1 HP/S REGEN", "d": "-10% damage", "up": {"regen": 1.0},
                "down": {"dmg": -0.10}, "w": 8},
        {"t": "+10% CRIT", "d": "-5% max HP", "up": {"crit": 0.10},
                "down": {"hp": -5}, "w": 6},
        {"t": "PURE POWER", "d": "no catch - rare", "up": {"dmg": 0.12}, "down": {},
                "w": 2},
        {"t": "PURE SWIFTNESS", "d": "no catch - rare", "up": {"spd": 0.12},
                "down": {}, "w": 2},
]

# ============================================================ XP-LEVEL DRAFTS
## the per-XP-level picks: pure buffs drawn from the tree's in-run branch
const LEVEL_DRAFTS := [
        {"t": "DAMAGE +12%", "k": "dmg", "v": 0.12, "stack": true},
        {"t": "ATTACK SPEED +10%", "k": "aspeed", "v": 0.10, "stack": true},
        {"t": "MAX HP +20", "k": "hp", "v": 20, "stack": true},
        {"t": "MOVE SPEED +8%", "k": "spd", "v": 0.08, "stack": true},
        {"t": "RANGE +10%", "k": "range", "v": 0.10, "stack": true},
        {"t": "ARMOR +1", "k": "armor", "v": 1, "stack": true},
        {"t": "REGEN +1 HP/S", "k": "regen", "v": 1.0, "stack": true},
        {"t": "CRIT +8%", "k": "crit", "v": 0.08, "stack": true},
        {"t": "MAGNET +25%", "k": "magnet", "v": 0.25, "stack": true},
        {"t": "PIERCE ALL", "k": "pierce_all", "v": 1, "stack": false},
        {"t": "LIFESTEAL 3%", "k": "lifesteal", "v": 0.03, "stack": true},
]

# ==================================================================== SHOP
## the wave shop consumables (in-run coins)
const CONSUMABLES := {
        "heal30": {"name": "MASH PATCH", "desc": "heal 30 HP now", "price": 45},
        "plate":  {"name": "ARMOR PLATE", "desc": "+1 armor this run", "price": 70},
        "crate":  {"name": "BOMB CRATE", "desc": "blast every enemy on screen", "price": 120},
}

# ============================================================== RARITIES
## the store's colored cards (the example HTML's shape): the price mult and
## the weight both live here. LUCK bends the roll (roll_rarity).
const RARITIES := {
        "common":    {"name": "COMMON",    "pm": 1.0,  "w": 46,
                "col": Color(0.72, 0.73, 0.75), "blurb": "the honest shelf"},
        "uncommon":  {"name": "UNCOMMON",  "pm": 1.35, "w": 28,
                "col": Color(0.44, 0.88, 0.5), "blurb": "a good find"},
        "rare":      {"name": "RARE",      "pm": 1.8,  "w": 17,
                "col": Color(0.46, 0.68, 1.0), "blurb": "the swarm will hate this"},
        "epic":      {"name": "EPIC",      "pm": 2.4,  "w": 7,
                "col": Color(0.78, 0.55, 1.0), "blurb": "the shelf sparkles"},
        "legendary": {"name": "LEGENDARY", "pm": 3.2,  "w": 2,
                "col": Color(1.0, 0.83, 0.3), "blurb": "take it and run"},
}

static func roll_rarity(luck: float) -> String:
        # luck SHIFTs the weights toward the shine (1.0 luck = x2 on epics+)
        var ids := RARITIES.keys()
        var total := 0.0
        for k in ids:
                var boost := 1.0 + maxf(0.0, luck) * (0.0 if k == "common" \
                                else (0.3 if k == "uncommon" else 0.8))
                total += float(RARITIES[k]["w"]) * boost
        var r := randf() * total
        for k2 in ids:
                var boost2 := 1.0 + maxf(0.0, luck) * (0.0 if k2 == "common" \
                                else (0.3 if k2 == "uncommon" else 0.8))
                r -= float(RARITIES[k2]["w"]) * boost2
                if r <= 0.0:
                        return String(k2)
        return "common"

# ================================================================= ITEMS
## the wave shop's stat items (the Brotato shelf). `stat` + `v` ride the
## same _apply_stat law as the drafts.
const ITEMS := {
        "spikeplate": {"name": "SPIKE PLATE",   "stat": "armor",  "v": 1,
                "desc": "+1 armor", "price": 55},
        "coffee":     {"name": "SPUD COFFEE",   "stat": "aspeed", "v": 0.08,
                "desc": "+8% attack speed", "price": 40},
        "clover":     {"name": "LUCKY CLOVER",  "stat": "luck",   "v": 0.15,
                "desc": "+15% luck (rarer shelves, fatter drops)", "price": 45},
        "rabbit":     {"name": "RABBIT FOOT",   "stat": "dodge",  "v": 0.08,
                "desc": "+8% dodge (cap 60%)", "price": 60},
        "protein":    {"name": "PROTEIN MASH",  "stat": "dmg",    "v": 0.10,
                "desc": "+10% damage", "price": 50},
        "boots":      {"name": "SWIFT BOOTS",   "stat": "spd",    "v": 0.08,
                "desc": "+8% move speed", "price": 40},
        "magnetring": {"name": "MAGNET RING",   "stat": "magnet", "v": 0.3,
                "desc": "+30% pickup range", "price": 30},
        "lens":       {"name": "FOCUS LENS",    "stat": "crit",   "v": 0.06,
                "desc": "+6% crit", "price": 45},
        "salve":      {"name": "ROOT SALVE",    "stat": "regen",  "v": 0.8,
                "desc": "+0.8 HP/s regen", "price": 50},
        "leech":      {"name": "LEECH FANG",    "stat": "lifesteal", "v": 0.02,
                "desc": "+2% lifesteal", "price": 70},
        "scope":      {"name": "LONG SCOPE",    "stat": "range",  "v": 0.10,
                "desc": "+10% range", "price": 40},
        "battery":    {"name": "SPARE BATTERY", "stat": "proj",   "v": 1,
                "desc": "+1 projectile on every gun", "price": 90},
}
const ITEM_ORDER := ["spikeplate", "coffee", "clover", "rabbit", "protein",
        "boots", "magnetring", "lens", "salve", "leech", "scope", "battery"]

## the reroll laws (the Brotato mouthful #3): the shop reroll climbs, the
## draft reroll too (the u3 tree node owns one free draft shuffle per break)
static func shop_reroll_cost(n: int) -> int:
        return 8 + n * 6

static func draft_reroll_cost(n: int) -> int:
        return 6 + n * 6

# =================================================================== WAVES
const WAVE_SECS := 25.0
const BOSS_WAVE_SECS := 30.0
const WAVE_HEAL := 15.0
const WAVE_COINS := 10          # + 2*wave (the GDD law)

## the difficulty laws (the python's math, extended - see the GDD 3.1)
static func spawn_interval(wave: int) -> float:
        return maxf(0.30, 1.60 - float(wave) * 0.08)

static func burst_size(wave: int) -> int:
        return 3 + int(wave / 2.0)

static func hp_scale(wave: int) -> float:
        var base := 1.0 + float(wave) * 0.12
        if wave > 20:
                base *= pow(1.015, float(wave - 20))
        return base

static func dmg_scale(wave: int) -> float:
        return 1.0 + float(wave) * 0.04

static func spd_scale(wave: int) -> float:
        return minf(1.35, 1.0 + float(wave) * 0.015)

static func elite_chance(wave: int) -> float:
        if wave < 6:
                return 0.0
        return minf(0.25, 0.08 + 0.01 * float(wave - 6))

## the unlock table (the GDD: w2 sprinter ... w12 orbiter)
static func pool_for_wave(wave: int) -> Array:
        var pool: Array = ["blab", "blab", "blab"]
        var unlock := {"sprinter": 2, "chunk": 3, "spitter": 4, "wraith": 5,
                "brood": 6, "trishield": 7, "mender": 8, "charger": 9, "boomling": 10,
                "splitter": 11, "orbiter": 12}
        for k in unlock:
                if wave >= int(unlock[k]):
                        pool.append(k)
                        if wave >= int(unlock[k]) + 4:
                                pool.append(k)   # older types weigh more over time
        return pool

# =================================================================== ECONOMY
static func xp_for_run_level(level: int) -> int:
        return int(100.0 * pow(1.2, float(level - 1)))

static func xp_for_char_level(level: int) -> int:
        return int(80.0 * pow(1.35, float(level - 1)))

static func tier_cap_for(char_level: int) -> int:
        return clampi(1 + int(char_level / 3), 1, 3)

static func sell_price(kind_price: int) -> int:
        return int(floor(kind_price * 0.4))   # the 40% sell law
