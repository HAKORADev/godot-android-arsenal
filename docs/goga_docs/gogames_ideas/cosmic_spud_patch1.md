# COSMIC SPUD — v0.3.4 PATCH 1 (the owner's playtest round)

The owner's verdict on v0.3.4: 0.5/10 — "this is not a real game at all".
Every word of the report is law. This doc is the patch-1 tracker.

## THE REPORT (the defects, verbatim-spirited)

1. Red enemies spawn but do not move.
2. Some enemies move but are INVISIBLE — the asset stays frozen at the spawn
   point while the object moves away (the owner guessed the exact bug).
3. "you called the universal shop as gogashop???" — naming dead.
4. The optionals menu is FUCKING WEIRD / BAD — redesign it completely.
5. Cannot change theme; never saw the day/night variants.
6. The shop button must open the FULL shop described in the brief (weapons
   one by one at high prices, allies, merging, ...).
7. No weapon merging UI anywhere.
8. The example HTML had a good store-like layout — the in-game shop is
   totally broken; rebuild it on that shape.
9. Tree button feels weird; skill tree upgrade display is bad; locked
   skills show NO locked sign.
10. The analog stick must be TRULY invisible (something showed on tap).
11. The currency reuses the gogacoin look — make a distinct coin (a yellow
    thing with something in the middle).
12. The money widget is bad; ADD a kills widget; the /200 score bonus needs
    verifying.
13. NEW FEATURE: every 5 waves (5/10/15/...) one GOGACoin spawns INSIDE a
    random enemy; it drops when that enemy dies; collect it.
14. Brotato stuff missing: luck, dodging, re-rolling, more — no shortcuts.
15. NO REAL ASSETS (only some SFX) — visuals "totally shit", the character
    is an ugly potato, the enemies are geometric shapes. The whole UI/game
    setting/themes need a real rework. Design a REAL potato via code (then
    legs + animation); make the enemies the same way; the uploaded assets
    zip may help; UIs must look like polished commercial games.
16. THE GAME'S OWN DESIGN LANGUAGE: gray background, black internal boxes,
    text in white/green/red/blue/yellow. STOP reusing GOGABox UI code
    inside the game. (GOGABox/GOGACoins screens keep their own design.)

## ROOT CAUSES FOUND (the audit)

- **THE FROZEN-SPRITE LAW (defects 1+2)**: `_tick_enemies` moved the
  logical `e["pos"]` every frame but NEVER wrote `e["node"].position`.
  Every enemy sprite sat frozen at its spawn point (the "red enemies that
  don't move") while the real bodies roamed invisible around them (the
  "invisible moving enemies"). Bullets hit the invisible bodies.
- **THE ASSET LIE (defect 15)**: assets DID exist on disk (hero, 16
  enemies/bosses, grounds, props, guns, bullets) but they were
  low-effort generated blobs — flat circles with googly eyes, 640x360
  noise grounds, 30x14 gray nub guns. Wired in, and still 0.5/10.
- **THE TINT THAT NEVER WAS (defect 5)**: `_build_ground` computed the
  day/night tint and passed it to `_scatter_props(theme, _tint)` — which
  ignored it. Night read as "a slightly different tile", easy to miss.
  The GogaShop themes tab DISABLED owned themes (can't switch there); the
  optionals chips re-ran the whole boot setup (heavy, fragile).
- **THE GOGASHOP SHAME (defects 3, 6, 7, 8)**: the "GOGASHOP" was a grid
  of disabled text buttons. No merge UI reachable (the wave shop hid it
  behind the WEAPON LAB + pairs), no sell, no reroll, no loadout sell.
- **THE STICK GHOST (defect 10)**: the "invisible" stick drew a 34px ring
  + a 16px knob on every touch. The opposite of the law.

## THE PATCH (the work)

### A. THE ART REBIRTH (tools/v034p1_art.py)
- SPUDNIK reborn: a real potato — lumpy shaded body, potato eyes/spots,
  glossy highlight, dark outline, roots, a glass cosmonaut dome; SIX start
  variants (soldier bandana, ranger hood, brawler wraps, engineer goggles,
  pyro scarf, frostbite rim) + a 4-frame LEG WALK cycle (boots) per frame
  set. 128px canvases.
- 13 enemies + 3 bosses reborn as CREATURES (silhouette first, then base
  + shade + light + rim + outline + eyes + personality): the blab slime
  with a drippy skirt, the sprinter lizard lean, the chunk stone brute,
  the spitter's jaw-barrel, the wraith's tattered shroud, the brood's egg
  sac, the tri-shield's armored core, the mender's medic crest, the
  charger's horn wedge, the boomling's lit fuse, the splitter's mitosis
  lobes, the orbiter's saucer, the minion tad, THE HEAP junk golem, THE
  PRISM MATRIARCH crystal crown, SPUD REAPER hooded scythe.
- Grounds: 512px SEAMLESS day/night x desert/park (sand rippling + cracks
  + pebbles + bones / moon-lit sand; mowed grass stripes + clover +
  fallen leaves + path stones / night grass + fireflies dots).
- Props redone with baked ground shadows; the ferris wheel silhouettes
  stay for the park.
- Guns reborn READABLE (per-type silhouettes: smg boxy, shotgun twin,
  rifle long, laser coil, cannon fat, frost crystal, flame tank, rail
  rails, boomerang curved, minigun barrels, fryer dish, gravity ring).
- THE COSMIC COIN: a fat gold coin with a POTATO EMBOSSED in the middle
  (the owner's "yellow thing with something in the middle") — clearly not
  the box's gogacoin.
- Bullets redone (tracer streaks, shells, crystals, the rail lance).
- XP gem + heart redone; pickups get shadows.
- THE ZIP'S PARTS: spr_enemy_fireball (orange) = the spitter's spit and
  boom bursts; the 3 purple obstacle crystals = rare desert-night props;
  provenance into assets.manifest.json.

### B. THE CODE (cosmic_spud.gd rework)
- THE NODE-SYNC LAW: every entity's node follows its logical pos EVERY
  tick (enemies finally walk) + a walk wiggle/squash + spawn poof.
- CSUI: the game's OWN UI kit — gray field, BLACK inner boxes, 2px
  charcoal edges, text ONLY in white/green/red/blue/yellow. No GOGABox
  ui_kit calls, no box styling anywhere in game screens.
- CS sheets: the game's own overlay stack (dim + black panel + title
  bar); Android back closes the top CS sheet, else the pause.
- OPTIONALS REBORN: the six start cards wear the NEW start art + clean
  stat chips; theme select = two theme cards each with DAY/NIGHT toggle
  chips (the state VISIBLE); THE ARMORY + TREE + DROP IN.
- THE ARMORY (the meta shop, "gogashop" name DEAD): weapons one by one
  at high prices (12, all purchasable, owned stamps), allies at the
  highest prices, themes, SELL duplicates (the 40% law), loadout picker.
- THE SHOP (the wave shop, the HTML store layout): header = coin + fat
  balance; stat chips row; WEAPONS = 4 rotating offers with RARITY
  borders; ITEMS = stat-item offers with rarity; SUPPLIES; ALLY DEPLOY;
  THE MERGE BENCH (two same-kind same-tier -> next tier, half the next
  price — visible even before the LAB teaches it, locked with a reason);
  YOUR LOADOUT with SELL; REROLL (escalating price) + START WAVE.
- THE TREE REBORN: 4 branch columns joined by connector lines; every node
  a black box: name colored by state, desc, cost, and a real state
  language: OWNED (green + check), CAN BUY (yellow border), LOCKED
  (grayed + a padlock + the reason: the chain node or the LV gate).
- THE HUD: HP bar + armor pips, XP bar + LV, WAVE + the time bar (the
  HTML's orange drain), the KILLS widget (new), the COSMIC COINS widget
  with the NEW coin art, weapon slots bottom-left with cooldown fills,
  the boss bar top-center. All gray/black/colored.
- THE STICK: TRULY invisible — the ghost drawing is deleted; born under
  any touch, nothing ever renders.
- LUCK (new stat): rolls into elite chance, item rarity, coin/heart
  drops, draft quality. DODGE (new stat): a chance to no-hit any incoming
  damage (capped 60%), a "DODGE!" floater when it fires. REROLL: the
  shop reroll + a draft reroll button (paid, escalating; 1 free with the
  u3 node).
- THE GOGACOIN RIDER (the new feature): on waves 5/10/15/... one random
  enemy is BORN CARRYING the box's real gogacoin (gold sparkle + a "COIN
  CARRIER" tag). It drops on death and collecting pays +1 REAL GOGACoin
  to the GOGABox wallet (add_run_coins -> finish_run). The HUD shows a
  gogacoin chip while a carrier lives.
- THE THEME FIX: day/night = two real states with a night ambience layer
  (the tint finally APPLIED to the world + a vignette), the optionals
  chips switch instantly (re-paint in place, no boot re-run), the ARMORY
  buys themes, both re-verify in the probe.

### C. THE DATA (cs_data.gd)
- ITEMS table (stat items with tiers), RARITY table (common..legendary,
  price mults, colors), reroll pricing, luck/dodge stat plumbing, draft
  reroll cost law.

### D. THE PROOF
- cs_probe grows: the node-sync law (an enemy walks -> its node follows),
  luck math (seeded), dodge math, reroll costs, the gogacoin rider law
  (wave 5 births a carrier, the drop pays the wallet), the coin-distinct
  law (the cosmic coin is NOT the gogacoin pixels), the tree locked
  language, the day/night ground files differ, the armory/shop laws.
- qa_v034p1 Xvfb shots: optionals, the shop, the merge bench, the tree
  with locks, combat HUD with kills widget, night desert vs day park.

### E. THE SHIP-OUT
- version_name 0.3.4-1 (the naming law: no PATCH words), version_code
  base 30480. Push, CI green, worklog. NO RELEASE (the law).

## STATUS

- [x] The audit (root causes above)
- [x] A. The art rebirth
- [x] B. The code rework
- [x] C. The data
- [x] D. The probe + QA shots
- [x] E. Version + push + CI
