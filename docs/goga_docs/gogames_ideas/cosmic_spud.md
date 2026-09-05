# COSMIC SPUD — the GDD (v0.3.4, the Brotato-competitor)

> The owner's brief, distilled: a real rogue-like TOP-DOWN SHOOTER inside
> GOGABox. Endless, progressively harder, per-wave drafts, an XP skill tree,
> one hero with six starting builds, weapons + merging, allies, themes,
> a real economy, high-grade VFX/SFX/music — and the landscape camera law:
> the ground is BIGGER than the screen; the character walking to the edges
> expands the world. Auto-shoot + an invisible analog stick. "Build a real
> brotato-competitor."

## 0. IDENTITY

- **Game**: COSMIC SPUD (the PGB v1.3.8 name survives — it is good and it
  is the owner's).
- **Hero**: **SPUDNIK** — the potato cosmonaut. One character, always.
- **The 6 STARTS** (the game optionals menu offers ALL SIX every game start;
  each is a different base-stat set + a perk; pick exactly one):
  1. **THE SOLDIER** — the balanced spud. 100 HP, 1.0 everything. Perk:
     +10% damage with every weapon.
  2. **THE RANGER** — 70 HP, speed 115%, range 130%, attack speed 110%.
     Perk: +15% crit chance.
  3. **THE BRAWLER** — 140 HP, damage 130%, range 65%, speed 105%. Perk:
     +2 armor and contact damage taken -20%.
  4. **THE ENGINEER** — 90 HP, damage 85%. Perk: starts every run with a
     free DRONE BUDDY ally and +25% ally damage.
  5. **THE PYRO** — 85 HP, damage 110%. Perk: every hit applies BURN
     (2 dmg/s for 3s, stacks refresh).
  6. **THE FROSTBITE** — 95 HP, damage 95%. Perk: every hit CHILLS
     (-20% enemy speed for 1.5s; chilled enemies take +10% damage).

## 1. THE CAMERA LAW (the owner's catch)

- Landscape. The ARENA is a bounded field ~2400x1350 — much bigger than the
  screen. The CAMERA follows Spudnik (smoothed, lerp ~8/s) and CLAMPS to the
  arena bounds; walking to any edge only reveals more ground — the view is
  never the whole world.
- The GROUND PAINT extends ~300 px past the playable bounds on every side
  (decor, props, shade) so the world feels endless to the eye while the
  playable box stays fair. Enemies spawn off the CAMERA view, not just off
  the arena.
- A soft vignette + a subtle camera KICK on explosions (2-6 px, decays
  fast). Screen shake exists and is USED (the python file never fired it —
  we do).

## 2. CONTROLS (the owner's law)

- **Invisible analog stick**: touch anywhere on the ground = the stick is
  BORN under the finger; drag = direction + magnitude (dead zone 8 px, max
  70 px); lift = the stick dies. No sprite is required — a faint ghost ring
  fades in while active. Left or right thumb, anywhere.
- **Auto-shoot**: weapons fire on their own at the nearest enemy in range
  (target priority: elite > boss > closest). No fire button. Ever.

## 3. THE RUN LOOP

- Waves of 25s (+5s boss waves). Spawns stream in from the camera edges.
- Between waves: the WAVE SHOP + the wave draft. Death = the death menu
  (GOGABox law), run ends, coins bank, XP banks.
- **Endless**: no final wave. Difficulty scales forever; bosses every 10
  waves (10/20/30...) get harder each visit.

### 3.1 Spawn & difficulty laws (the python game's math, extended)
- Spawn interval: `max(0.30, 1.6 - wave*0.08)` s per spawn, PLUS a wave
  budget burst every 5s (`3 + wave/2` enemies). Enemy HP scale:
  `1 + wave*0.12` (+1.5% per wave compounding past wave 20). Enemy damage
  scale: `1 + wave*0.04`. Speed scale: `min(1.35, 1 + wave*0.015)`.
- Type unlocks (append to pool): w2 sprinter, w3 chunk, w4 spitter, w5
  aura wraith, w6 broodmother, w7 tri-shield, w8 mender, w9 charger,
  w10 boomling, w11 splitter, w12 orbiter. Elites from w6 (8% +1%/wave).
- Wave clear heals +15 HP (the python +20 law, tuned down for endless).

## 4. THE ENEMIES (the python complex logic preserved + MORE)

Every chaser uses the python base law: chase along angle_to(player), hit
flash, HP bar when damaged, and the O(n^2) FLOCKING separation (100 px,
force (1-d/100)*0.5 + jitter) so hordes read as a swarm, not a stack.

| Enemy | HP | Spd | Dmg | XP | Behavior |
|---|---|---|---|---|---|
| BLAB | 30 | 2.0 | 10 | +1 | the basic chaser (RED) |
| SPRINTER | 15 | 4.0 | 8 | +1 | fast, fragile (ORANGE) |
| CHUNK | 80 | 1.0 | 20 | +2 | the tank (PURPLE) |
| SPITTER | 25 | 1.5 | 15 | +2 | KEEPS DISTANCE ~260px and actually SHOOTS (the python's ranged never fired — fixed) |
| AURA WRAITH | 100 | 0.5 | 10 | +4 | **250 px damage aura**, 15 dmg/s tick while inside (ms-gated); translucent glow |
| BROODMOTHER | 50 | 1.0 | 10 | +3 | death-split: 2 MINIONS (15 HP, 3.0 spd) |
| TRI-SHIELD | 300 | 1.2 | 20 | +6 | **THE SIGNATURE**: 3 counter-rotating rings (r 90/70/50, 8 px thick, 0.05/0.03/0.01 rad/frame). Bullets carve CRACKS stored as angular intervals in each ring's LOCAL rotating frame; a fully-carved window lets bullets through to the next ring; the core sits at r<46. The player is PHYSICALLY PUSHED out of any ring. Interval math is wrap-safe. |
| MENDER | 1000 | 0.8 | 10 | +8 | **500 px heal aura**: +10 HP to ALL enemies every 0.5s. Kill it first or the horde out-sustains you |
| CHARGER | 45 | 2.2 | 18 | +2 | wind-up 0.6s (telegraph line) then a 3x-speed dash; overshoots and recovers |
| BOOMLING | 20 | 2.6 | 5 | +1 | suicide bomber: flashes 0.7s then detonates (60 px, 25 dmg, friendly-fire on enemies) |
| SPLITTER | 40 | 1.8 | 12 | +2 | on death splits into 2 halves (60% HP, +10% speed, split once more at half-size) |
| ORBITER | 35 | 3.0 | 10 | +2 | circles the player at 180 px for 3-5s then DIVES through the center, re-orbits |

- **CONTACT DAMAGE = the enemy's remaining HP** (the python law, kept — a
  chipped tank is safer to hug than a fresh one).
- **ELITES** (w6+): any type, 1 affix — FRENZIED (+40% spd/atkspeed),
  ARMORED (-30% taken, min 1), COLOSSAL (+50% size/HP, +50% dmg),
  VAMPIRIC (heals 20% of damage dealt). Purple glow ring + name tag.
  Score +3 flat bonus.
- **BOSSES** (every 10th wave, +25s wave): three matriarchs cycle and scale.
  Each has a health bar on the HUD, a roar, a pattern set, and big score.
  - **THE HEAP** (w10, +50 score): giant CHUNK — ground-slam AoE rings,
    summons 4 broods at 66%/33% HP, charges when cornered.
  - **THE PRISM MATRIARCH** (w20, +100 score): TRI-SHIELD grown up — FOUR
    rings (110/90/70/50), radial bullet bursts through her own cracks, the
    mender aura on herself.
  - **SPUD REAPER** (w30, +80 score): the reaper — aura trails (the wraith
    law at 160 px), triple-charge combos, teleports behind the player on
    every 4th charge.
  Past w30 they repeat, +25% stats per cycle, score +20 per cycle.

## 5. WEAPONS & MERGING

- 12 weapons, 3 TIERS each (T1 buyable, T2 = merge or late shop, T3 = merge
  only past char level 4). The run starts with the 3 OWNED weapons equipped
  (from the GogaShop loadout) — the rest are shop-bought one by one, HIGH
  prices (the owner's law: "starts with only 3 weapons").
- Weapons auto-fire at their own cadence; up to **6 slots** (4 free + 2
  tree-unlocked).
- **MERGING** (the owner's law): a SKILL on the tree (**WEAPON LAB** — a
  bought node). Once learned: two SAME weapon, SAME tier merge into the
  next tier. **Merge price = 50% of the next tier's shop price** + the two
  weapons are consumed. Merging is offered in both shops.
- SELL: any weapon/ally sells for 40% of its buy price (everything is
  bought AND sold for the game coins — the owner's law).

| Weapon | Family | T1 flavor |
|---|---|---|
| SPUD SMG | bullet | steady peashooter, 4/s |
| SCATTER SPUD | shotgun | 5 pellets, wide cone |
| RUSTY RIFLE | bullet | slow, pierces 1 |
| LASER PEELER | energy | instant beam line, 1.5/s |
| SPUD CANNON | explosive | lobbed bomb, AoE 60 px |
| FROST BLOOMER | frost | slows 20% for 1s |
| FLAME TATER | fire | short cone, applies BURN |
| RAIL TATER | energy | charged piercing rail, 0.8/s |
| BOOMERANG PEEL | odd | flies out, returns, hits twice |
| PRICKLY MINIGUN | bullet | 9/s spin-up, spread grows |
| ORBITAL FRYER | energy | satellite beam every 3s on a random enemy |
| GRAVITY WELL | odd | slow orb that PULLS enemies 2s then pops |

## 6. ALLIES (the brotato-style companions)

- 6 allies, GogaShop-only purchases at the HIGHEST prices (the owner's
  law). Owned allies APPEAR IN THE IN-RUN wave shop for deploy / level-up /
  merge. Two same-level same-kind allies merge into level+1 (merge law:
  50% of the next level's effective price).
- DRONE BUDDY — orbits, shoots 2/s (lv+ dmg). TATER TURRET — static, plants
  near the player, 360 sweep. GUARD SPUD — bodyblocks, taunts (enemies in
  140 px prefer it), 3 HP hearts. MEDIC SPROUT — heals the player 2 HP/s
  and +1 per level. BOMBER CHIP — kamikaze dive every 8s, respawns in 5s.
  SCOUT FRY — marks enemies (+15% damage taken from anything) in 300 px.
- Max deployed allies: 2 (3 with the tree node). Ally tiers gate by
  character level like weapons.

## 7. DRAFTS (the two roguelite mouths)

- **PER WAVE — "select one of three" WITH TEETH** (the owner's law: offer
  things AND take things): 3 cards, every card carries a BUFF and most
  carry a TRADEOFF. Examples: "+20% damage / -20% speed", "+30 max HP /
  -8% attack speed", "+1 projectile / -15% range", "+25% move speed /
  -10 max HP", pure "+15% crit" appears rarely (weight 1 in 5). Skip
  button always present (nothing taken). Reroll costs in-run coins (tree
  node for a free one).
- **PER XP LEVEL — the skill-tree pick**: leveling up pauses the run and
  offers 3 NODES drawn from the tree's IN-RUN branch (pure buffs, no
  tradeoffs): damage, attack speed, armor, regen, max HP, speed, crit,
  pickup magnet, projectile, pierce, lifesteal... Some nodes stack
  (ranked), one-shot uniques (PIERCE ALL, +1 projectile) are rare-weighted.
- The XP curve: `100 * 1.2^(level-1)` per level (the python's exact
  compounding law, kept).

## 8. THE SKILL TREE (meta, Ubisoft-style)

- A constellation of **18 nodes** across 4 branches, rendered as a real
  graph (lines light up as chains unlock). EVERYTHING starts locked; nodes
  unlock ONE BY ONE for COSMIC COINS (the owner: "like advanced ubisoft
  games"); each node lists its prerequisite chain and its character-level
  gate.
- OFFENSE branch: +8% run damage x2 → +1 weapon slot → +10% crit →
  CRIT MASTERY (crits x3).
- DEFENSE branch: +20 run HP → +2 armor → REGEN ROOT (+1/s) → SECOND WIND
  (one revive per run at 50% HP).
- UTILITY branch: +30% magnet → +10% coins → WAVE REROLL (1 free reroll) →
  SHOP DISCOUNT (10% off wave shop).
- LAB branch: +1 ally slot → ALLY POWER (+25%) → **WEAPON LAB (merging
  learned)** → FOUNDRY (merge price -25%).
- Character-level gates: OFFENSE/UTILITY tier 2 need level 3, tier 3 need
  level 6; LAB tier 2 (WEAPON LAB) needs level 4, FOUNDRY needs 8.

## 9. THE ECONOMY (the owner's ledger — "manage this thing")

Three currencies, three jobs, one law: EVERYTHING is bought and sold for
the game's coins.

1. **SCORE** — kills are the score (the owner: basic +1, most +2, bosses
   +20..+100; elites +3). Score is NOT spendable. It feeds the GOGABox
   death-menu bonus at **/200** (the owner's kill-bonus law) and the
   achievement tables.
2. **XP** — gems drop from every kill (values per the enemy table). XP does
   DOUBLE DUTY (the owner: "XP points levels the character up so it can
   open or acquire higher weapons or allies or skills — manage this"):
   - in-run: fills the run level → the per-XP-level draft;
   - meta: 100% of gem XP ALSO banks into SPUDNIK's persistent character
     XP bar. Character level gates the SHOPS and the TREE (weapon tier
     cap = 1 + char_level/3 rounded up, max 3; allies gate the same; tree
     gates per §8). A run of 10 waves ≈ 1 early character level; the curve
     is `80 * 1.35^(char_level-1)`.
3. **COSMIC COINS** — the game's OWN currency (the owner: "the game has
   it's own currency"). Earned: enemy drops (8% of kills, elites always,
   bosses 15-40), wave-clear bonuses (10 + wave*2), and the run-end bank.
   Spent: the GogaShop (weapons high, allies highest, themes), the tree,
   merges (50% law), wave-shop rerolls. Everything sellable (40% law).

## 10. THE GOGASHOP (the universal shop, this game's shelf)

- **The META GogaShop** (from the run-start menu + the death menu): tabs
  WEAPONS / ALLIES / THEMES / LOADOUT. Weapons one-by-one at high prices
  (T1 250-900 CC), allies at the highest prices (1200-2600 CC), themes at
  800 CC. The LOADOUT tab picks which 3 owned weapons start equipped.
- **The WAVE SHOP** (between waves, in-run coins): 4 offers (weapons of
  owned types, consumables: heal 30 / armor plate / bomb crate, reroll,
  ally deploy + level-up + merge rows when owned, weapon merges when the
  LAB is learned). Brotato cadence, GOGA money law.
- **THEMES** (the owner's law): **DECAYED DESERT** (free, the first theme)
  and **ABANDONED PARK** (bought, 800 CC). Each theme ships DAY and NIGHT
  variants (picked in the shop, re-pickable at run start). Night variants
  darken the palette, add glows/fireflies and a +5% XP flavor perk —
  cosmetic + a whisper of function, never pay-to-win.
  - Decayed Desert day: bleached ochre, cracked clay tiles, dead shrubs,
    half-buried ribs of machinery. Night: indigo cold, cyan mineral glints.
  - Abandoned Park day: soft sad green, mown paths, broken benches, a dead
    ferris wheel on the horizon. Night: fireflies, warm lamp ghosts.

## 11. VFX / SFX / MUSIC (the "not poor" law)

- **VFX**: every enemy dies into a radial burst (the python 8-particle law,
  grown: 12-20 particles + a shockwave ring + a ground scorch decal that
  fades). Bullets impact with sparks; crits get a gold star pop; burn/chill
  own colored status sprites; the aura wraith breathes (sin alpha); the
  tri-shield rings GLOW and shatter arc-by-arc with glass tinks; bosses
  telegraph every pattern with ground lines; level-ups ring-burst the
  player; the camera kicks on every explosion and rolls +6 px on boss
  spawns. Damage numbers float (white, crits gold, burns orange).
- **SFX**: ~24 synthesized-and-processed sounds (the box's numpy pipeline):
  per-family shots, impacts, crits, kills (pitch by enemy size), XP pick,
  coin pick, level-up chime, draft card slide, shop buy/sell/error, aura
  hum (looped, distance-mixed), shield crack tinks, boss roar, wave horn,
  death sting.
- **MUSIC**: 4 looping tracks — desert day (dusty west-ambient), desert
  night (cold drones), park day (melancholy music-box), park night
  (fireflies synth), + a boss layer (percussion stem that ducks in). Hunt
  CC0 first (OGA/Kenney); synthesize the remainder with the box's pipeline.
  Music crossfades between day/night at run start and ducks under bosses.

## 12. THE DEATH MENU & THE BOX

- GOGABox death menu law: score, the /200 bonus, coins banked, XP banked,
  character level progress bar, achievements toasts, RETRY / SHOP / BOX.
- Achievements (~12): first blood, 100/1000 kills, boss slayer, reach w20 /
  w30, first merge, first level-3 weapon, 2 allies deployed, night owl
  (a night run), six-pack (all 6 starts played), untouchable (clear a wave
  without damage), millionaire (bank 5000 CC lifetime).
- Registry: `id: "cosmic_spud"`, landscape, coin_div 200 (the owner's
  law), price 500, fee 50, shop true, reveal chain after matcher.

## 13. ASSET & BUILD ORDER

1. Hunt: CC0 top-down shooter packs (Kenney), potato hero candidates,
   creature sprites, terrain tiles, CC0 music/SFX packs; verify licenses,
   record provenance in assets.manifest.json. Risky-but-good assets are
   acceptable (the owner's explicit law) — flagged in the manifest.
2. Whatever hunting cannot cover, the box's PIL pipeline draws (the hero,
   the enemies, weapons, VFX frames) — same quality bar as the matcher art.
3. Build: cs_meta.gd (the ledger/save) → cosmic_spud.gd (arena, camera,
   stick, combat, enemies, bosses, waves) → drafts/shops/tree UIs →
   themes → VFX/SFX/music → probes (cs_probe.gd: deterministic model
   tests) → flow_test wiring → thumbs → v0.3.4.

---

## 14. PATCH 1 (v0.3.4-1, the owner's playtest round — the law)

The owner's v0.3.4 verdict: 0.5/10. The full defect list + the fixes live in
`cosmic_spud_patch1.md` (the tracker). The standing laws this patch added:

- **THE NODE-SYNC LAW** — every entity's sprite follows its logical body
  EVERY tick (v0.3.4 shipped frozen sprites + invisible walkers). The probe
  asserts it, the flocking pass included.
- **THE GAME'S OWN FACE** — gray field, black inner boxes, text only in
  white/green/red/blue/yellow. The CSUI kit builds every game screen; the
  GOGABox ui_kit renders NOTHING inside this game. (The box's top bar +
  pause stay box chrome - that is the frame, not the game.)
- **THE CS SHEET STACK** — the game owns its modal system (dim + gray panel
  + black boxes + X). Android back closes the top sheet first.
- **THE STAY-INVISIBLE STICK** — the ghost drawing is deleted. Born under
  any touch, nothing ever renders.
- **THE STORE SHAPE** — THE SHOP (in-run) and THE ARMORY (meta) both follow
  the owner's example HTML: fat balance header, stat chips, rarity-bordered
  cards, loadout with SELL, REROLL + START actions. "GOGASHOP" is a dead
  name.
- **THE RARITY LAW** — common/uncommon/rare/epic/legendary price mults +
  weights; LUCK bends the roll (and the elite chance + the drops).
- **THE DODGE LAW** — a real no-hit chance, capped 60%, a blue DODGE!
  floater when it fires.
- **THE REROLL LAW** — the shop reroll (8 + 6n) and the draft reroll
  (6 + 6n, one FREE per break with the u3 node).
- **THE GOGACOIN RIDER** — every 5th wave one random enemy carries the box's
  REAL gogacoin (gold glint + CARRIER! chip + banner). It drops on death
  (even a contact splatter coughs it up) and collecting pays +1 to the
  GOGABox wallet via add_run_coins. A carrier alive at the wave end re-hides
  its coin in the next wave's swarm.
- **THE ART REBIRTH** — tools/v034p1_art.py: a real lumpy potato with six
  geared starts + a 4-frame boot walk; 16 creatures (no more circles with
  googly eyes); 512px seamless grounds x4; readable guns; THE COSMIC COIN
  (gold, potato embossed) distinct from the gogacoin. The owner's uploaded
  Twin_Stick_Shooter_Template.zip donates the fireball + 3 crystals
  (provenance in assets.manifest.json).

## 15. THE PATCH-2 LAWS (v0.3.4-2 — the owner's locked-out round)

- **THE SHEET LIFE LAW** — every CS sheet pauses the tree, so the sheet
  chain wears PROCESS_MODE_ALWAYS (the box's own sheet_push crown).
  A paused tree eats every tap aimed at a PAUSABLE control; the kit's
  buttons must always answer. Probe: emit `pressed` on DROP IN under the
  paused tree — the run starts.
- **THE DOOR LAW** — the optionals is THE DOOR: no X (`closable=false`),
  and back (HUD "<" and Android, both landing in `_back_pressed`) never
  closes it during boot. Back over the door speaks the red hint
  ("the door is locked - pick a start, then DROP IN"); back closes only
  sheets stacked OVER the door. Over a running game: top sheet → close,
  else the box pause — the same law as every other game.
- **THE TEXT-FIT LAW** — the CSUI measures what it renders (Kenney_Mini
  loaded explicitly; `_cs_text_w/_cs_text_h/_cs_fit_label`). No CSUI box
  may guess a fixed size under autowrapped text: start/draft/tree cards
  grow past their floors to their measured content.
- **THE HUG LAW** — a sheet's scroll hugs its shelf's measured minimum
  (`_fit_scroll`), capped at the viewport fraction. No tall empty gray
  voids.
- **THE ECONOMY BORDER LAW** — PLACES (themes) are GOGACoin purchases
  from the BOX wallet (`Box.spend` + `Box.buy_item`, priced in the
  THEMES data as `gogacoins`: park 400, desert free-default). Guns,
  allies and everything in-run cost COSMIC coins. Both wallets are named
  in the optionals line; the armory themes tab wears the green GOGACoin
  chip and says which side of the border each currency owns.
