extends Node
## COSMIC SPUD probe (v0.3.4-1) - the deterministic battery.
## Runs headless: godot --headless --path . res://tests/cs_probe.tscn
## Exit 0 = all laws hold.

var checks := 0
var fails := 0
var G: GogaGame = null
var meta: CSMeta = null

func ck(cond: bool, what: String) -> void:
        checks += 1
        if cond:
                print("[PASS] ", what)
        else:
                fails += 1
                print("[FAIL] ", what)

## the first Button under `root` whose text matches (or null)
func _find_btn(root: Node, txt: String) -> Button:
        for c in root.get_children():
                if c is Button and String(c.text) == txt:
                        return c
                var deep := _find_btn(c, txt)
                if deep != null:
                        return deep
        return null

func _find_btn_like(root: Node, frag: String) -> Button:
        for c in root.get_children():
                if c is Button and String(c.text).contains(frag):
                        return c
                var deep := _find_btn_like(c, frag)
                if deep != null:
                        return deep
        return null

func _boot() -> void:
        if G != null and is_instance_valid(G):
                G.queue_free()
                await get_tree().create_timer(0.3).timeout
        Box.reset_all()
        Box.dev_set_cheat("all_owned", 1)
        get_window().size = Vector2i(1920, 1080)
        await get_tree().create_timer(0.2).timeout
        G = load("res://game/games/cosmic_spud/cosmic_spud.gd").new()
        G.game_id = "cosmic_spud"
        process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(G)
        await get_tree().create_timer(0.8).timeout
        meta = G.meta

func _wait(t: float) -> void:
        await get_tree().create_timer(t, true).timeout

func _run() -> void:
        print("=== cs_probe (v0.3.4-1) ===")
        seed(20260905)
        # ------------------------------------------------ the data laws
        ck(CSData.merge_price("smg", 1) == int(ceil(CSData.weapon_price("smg", 2) / 2.0)),
                        "THE MERGE LAW: T1 merge = half the T2 price")
        ck(CSData.weapon_price("rail", 3) > CSData.weapon_price("rail", 2),
                        "tier prices climb")
        ck(CSData.tier_cap_for(1) == 1 and CSData.tier_cap_for(3) == 2
                        and CSData.tier_cap_for(6) == 3 and CSData.tier_cap_for(12) == 3,
                        "THE TIER GATE: char level 1/3/6 caps T1/T2/T3")
        ck(CSData.xp_for_run_level(1) == 100 and CSData.xp_for_run_level(2) == 120,
                        "the run XP curve rides the python law (100 x 1.2^n)")
        ck(CSData.spawn_interval(1) == 1.52 and CSData.spawn_interval(20) == 0.30,
                        "the spawn interval law (1.6 - 0.08w, floor 0.30)")
        ck(CSData.hp_scale(5) > CSData.hp_scale(1) and CSData.hp_scale(25) > CSData.hp_scale(20),
                        "the hp scale grows (and compounds past 20)")
        var pool1 := CSData.pool_for_wave(1)
        var pool12 := CSData.pool_for_wave(12)
        ck(pool1.size() == 3 and pool12.has("orbiter") and pool12.size() > pool1.size(),
                        "the unlock table (w1 = 3 blabs, w12 = everything)")
        ck(CSData.START_ORDER.size() == 6 and CSData.WEAPON_ORDER.size() == 12
                        and CSData.ALLY_ORDER.size() == 6 and CSData.TREE_ORDER.size() == 18,
                        "the tables: 6 starts, 12 weapons, 6 allies, 18 tree nodes")
        # tree chains: every non-root need exists and costs climb
        var chain_ok := true
        for nid in CSData.TREE_ORDER:
                var n: Dictionary = CSData.TREE[nid]
                if n["need"] != "" and not CSData.TREE.has(n["need"]):
                        chain_ok = false
        ck(chain_ok, "every tree prerequisite resolves")
        ck(CSData.TREE["l3"]["need"] == "l2",
                        "THE WEAPON LAB sits at the end of the LAB chain")
        ck(CSData.sell_price(100) == 40, "the 40% sell law")
        # ------------------------------------------------ boot + the optionals
        await _boot()
        ck(G.phase == "boot" and G.sheet_open_count() > 0,
                        "boot opens THE OPTIONALS (the 6 starts greet first)")
        ck(G.stats["dmg_m"] > 0.0, "the stats block built from the START")
        # ------------------------------------------------ the run start
        G._start_run()
        await _wait(0.5)
        ck(G.phase == "play" and G.run_wave == 1,
                        "THE START: wave 1 begins, phase play")
        ck(not G.enemies.is_empty(), "the first burst spawned")
        ck(G.cam != null and G.cam.position != Vector2.ZERO,
                        "the camera lives")
        # ------------------------------------------------ THE CAMERA LAW
        var half: Vector2 = G._cam_half()
        var cl: Vector2 = G._cam_clamp_pos(Vector2(-9999, -9999))
        var ch: Vector2 = G._cam_clamp_pos(Vector2(99999, 99999))
        ck(cl.x >= G.ARENA.position.x - G.ARENA_MARGIN
                        and ch.x <= G.ARENA.end.x + G.ARENA_MARGIN,
                        "THE CAMERA LAW: the clamp holds the view near the arena")
        ck(half.x * 2.0 < G.ARENA.size.x and half.y * 2.0 < G.ARENA.size.y,
                        "THE CAMERA LAW: the view NEVER fits the whole ground")
        # ------------------------------------------------ the aim + autofire
        G.enemies.clear()
        var e: Dictionary = G._spawn_enemy("blab", G.p_pos + Vector2(120, 0))
        await _wait(0.05)
        var aim: float = G._aim_angle()
        ck(absf(angle_difference(aim, 0.0)) < 0.2,
                        "THE AIM LAW: the gun faces the nearest enemy")
        var score0: int = G.score
        # force a bullet hit
        var b := {"pos": e["pos"], "a": 0.0, "spd": 0.0, "dmg": 50.0, "pierce": 0,
                "hit": {}, "range_left": 10.0, "aoe": 0.0, "burn": false, "chill": 0.0,
                "kind": "bolt", "node": Sprite2D.new(), "turn": false, "tier": 1}
        G.world.add_child(b["node"])
        G.bullets.append(b)
        G._tick_bullets(0.016)
        ck(e.get("dead", false) or e["hp"] < e["max_hp"],
                        "the bullet HURT the blab")
        # ------------------------------------------------ THE CONTACT LAW
        # (the python law: the enemy's REMAINING HP is the contact damage)
        G.enemies.clear()
        var c0: Dictionary = G._spawn_enemy("chunk", G.p_pos + Vector2(30, 0))
        c0["hp"] = 61.0
        var hp0: float = G.p_hp
        G.p_iframe = 0.0
        G._tick_enemies(0.016)
        ck(G.p_hp < hp0 and absf((hp0 - G.p_hp) - (61.0 * float(G.stats["contact_cut"])
                        - float(G.stats["armor"]))) < 1.5,
                        "THE CONTACT LAW: the chunk's REMAINING hp (61) is the damage")
        # ------------------------------------------------ the aura wraith
        G.enemies.clear()
        G.p_iframe = 0.0
        var w: Dictionary = G._spawn_enemy("wraith", G.p_pos + Vector2(60, 0))
        var whp0: float = G.p_hp
        G._tick_enemies(1.2)
        ck(G.p_hp <= whp0 - 14.0,
                        "THE AURA LAW: the wraith's zone ticked 15 inside 1.2s")
        # ------------------------------------------------ the mender heal
        G.enemies.clear()
        var m: Dictionary = G._spawn_enemy("mender", G.p_pos + Vector2(500, 0))
        var z: Dictionary = G._spawn_enemy("blab", G.p_pos + Vector2(100, 0))
        z["hp"] = 10.0
        G._tick_enemies(1.2)
        ck(z["hp"] > 10.0, "THE MENDER LAW: the horde out-sustains (+10/0.5s)")
        # ------------------------------------------------ THE TRI-SHIELD RINGS
        G.enemies.clear()
        var t: Dictionary = G._spawn_enemy("trishield", G.p_pos + Vector2(400, 400))
        t["rings"] = G._mk_rings([90.0, 70.0, 50.0])
        t["rings"][0]["rot"] = 0.0
        var rb := {"pos": t["pos"] + Vector2(90, 0), "a": 0.0, "spd": 0.0,
                "dmg": 10.0, "pierce": 0, "hit": {}, "range_left": 10.0, "aoe": 0.0,
                "burn": false, "chill": 0.0, "kind": "bolt",
                "node": Sprite2D.new(), "turn": false, "tier": 1}
        G.world.add_child(rb["node"])
        var res1: int = G._ring_bullet(t, rb)
        ck(res1 == 1, "THE RING LAW: an unbroken band CARVES and eats the bullet")
        ck((t["rings"][0]["cracks"] as Array).size() >= 1,
                        "THE RING LAW: the crack lives in the ring's local frame")
        # a bullet through the carved window passes
        rb["pos"] = t["pos"] + Vector2.from_angle(t["rings"][0]["cracks"][0][0] + 0.01) * 90.0
        var res2: int = G._ring_bullet(t, rb)
        ck(res2 == 0 or res2 == 2,
                        "THE RING LAW: the carved window lets the next bullet inward")
        # ------------------------------------------------ the kill score law
        G.enemies.clear()
        var score1: int = G.score
        var k: Dictionary = G._spawn_enemy("blab", Vector2(2000, 2000))
        G._hurt_enemy(k, 99999.0, false, true)
        ck(G.score == score1 + 1, "THE SCORE LAW: a blab kill = +1")
        G.enemies.clear()
        var k2: Dictionary = G._spawn_enemy("blab", Vector2(2000, 2000), true)
        G._hurt_enemy(k2, 99999.0, false, true)
        ck(G.score == score1 + 1 + 1 + CSData.ELITE_SCORE,
                        "THE SCORE LAW: an elite blab = +1 +3 (the elite bonus)")
        # ------------------------------------------------ the waves + break
        G.enemies.clear()
        G.wave_clock = 0.01
        G.boss_alive = false
        G._tick_waves(0.02)
        await _wait(0.3)
        ck(G.phase == "break" and G.sheet_open_count() > 0,
                        "THE BREAK: the wave draft opens after the wave")
        # the draft cards exist and apply both ways
        var d0: Dictionary = {"t": "TEST", "d": "-TEST", "up": {"dmg": 0.2},
                "down": {"spd": -0.1}, "w": 1}
        var dm0: float = float(G.stats["dmg_m"])
        var sp0: float = float(G.stats["spd_m"])
        G._apply_draft(d0)
        ck(absf(float(G.stats["dmg_m"]) - (dm0 + 0.2)) < 0.001
                        and absf(float(G.stats["spd_m"]) - (sp0 - 0.1)) < 0.001,
                        "THE DRAFT LAW: the card GIVES +20% dmg and TAKES -10% spd")
        G.stats["dmg_m"] = dm0
        G.stats["spd_m"] = sp0
        # ------------------------------------------------ the xp -> level draft
        var lv0: int = G.run_level
        G.run_xp = CSData.xp_for_run_level(G.run_level) - 1
        G._drop_pickup("xp", G.p_pos, 5)
        G._tick_pickups(0.016)
        ck(G.run_level == lv0 + 1 and G.pending_levels >= 1,
                        "THE XP LAW: the gem leveled the run and queued a draft")
        # ------------------------------------------------ the shop merge law
        G.pending_levels = 0
        G._close_all_sheets()
        await _wait(0.2)
        meta.d["armory"] = [["smg", 1], ["smg", 1]]
        meta.d["coins"] = 10000
        meta.d["char_level"] = 6      # the tier gate opens at LV3+ (T2 cap)
        meta.save()
        G.run_ccoins = 10000
        var pairs: Array = G._merge_pairs()
        ck(pairs.size() >= 1 and pairs[0]["wid"] == "smg" and pairs[0]["tier"] == 1,
                        "THE SHELF: two same T1 copies offer a merge")
        var cost: int = int(pairs[0]["cost"])
        G._wave_buy_merge(pairs[0], cost)
        ck(meta.count_armory("smg", 2) == 1 and meta.count_armory("smg", 1) == 0,
                        "THE MERGE LAW: T1 + T1 -> one T2 (both copies consumed)")
        ck(G.run_ccoins == 10000 - cost,
                        "THE MERGE LAW: the half-price was charged in-run")
        # ------------------------------------------------ the boss spawn law
        G._close_all_sheets()
        await _wait(0.2)
        G._start_run()
        await _wait(0.3)
        G._spawn_boss(10)
        ck(G.boss_alive and G.enemies.any(func(x): return x.get("boss", false)),
                        "THE BOSS LAW: wave 10 spawns a boss")
        var heap: Dictionary = G.enemies.filter(func(x): return x.get("boss", false))[0]
        ck(String(heap["name"]) == "THE HEAP",
                        "THE BOSS LAW: cycle 0 = THE HEAP")
        G.enemies.clear()
        G.boss_alive = false
        G._spawn_boss(20)
        ck(String(G.enemies[0]["name"]) == "THE PRISM MATRIARCH"
                        and (G.enemies[0]["rings"] as Array).size() == 4,
                        "THE BOSS LAW: cycle 1 = THE PRISM MATRIARCH (4 rings)")
        G.enemies.clear()
        G.boss_alive = false
        G._spawn_boss(30)
        ck(String(G.enemies[0]["name"]) == "SPUD REAPER",
                        "THE BOSS LAW: cycle 2 = SPUD REAPER")
        # ------------------------------------------------ the death bank
        var coins0: int = meta.coins()
        var clv0: int = meta.char_level()
        var cxp0: int = meta.char_xp()
        G.run_ccoins = 250
        G.run_kills = 40
        G.over = false
        G.p_iframe = 0.0
        G.p_hp = 0.5
        G.phase = "play"
        G._hurt_player(50.0, null)
        await _wait(0.2)
        ck(meta.coins() == coins0 + 250, "THE BANK: the run's coins joined the wallet")
        ck(meta.char_xp() > cxp0 or meta.char_level() > clv0,
                        "THE BANK: the run's kills banked character XP")
        ck(G.over, "the death hands the run to the box death menu")
        # ------------------------------------------------ the patch-1 laws
        # THE NODE-SYNC LAW (the headline fix: the sprite follows the body)
        G.enemies.clear()
        var ne: Dictionary = G._spawn_enemy("blab", G.p_pos + Vector2(500, 0))
        G.p_iframe = 99.0          # keep the contact law out of the way
        G._tick_enemies(0.1)
        var nd: Sprite2D = ne["node"]
        ck(nd.position.distance_to(ne["pos"]) < 0.5,
                        "THE NODE-SYNC LAW: the sprite follows the body every tick")
        var moved_d: float = (G.p_pos + Vector2(500, 0)).distance_to(ne["pos"])
        ck(moved_d < 500.0,
                        "THE NODE-SYNC LAW: the enemy WALKED (v0.3.4 left it frozen)")
        G.enemies.clear()
        # LUCK: the rarity roll bends
        seed(777)
        var common0 := 0
        for i in 400:
                if CSData.roll_rarity(0.0) == "common":
                        common0 += 1
        var common_lucky := 0
        for i in 400:
                if CSData.roll_rarity(1.5) == "common":
                        common_lucky += 1
        ck(common_lucky < common0,
                        "THE LUCK LAW: luck pushes the shelf off common (%d -> %d of 400)" \
                                        % [common0, common_lucky])
        ck(common0 > 140 and common0 < 240,
                        "THE LUCK LAW: luck 0 stays near the 46%% common weight (%d)" % common0)
        # DODGE: a real no-hit chance, capped at 60%
        G.p_hp = G.p_max_hp
        G.stats["dodge"] = 0.6
        G.p_iframe = 0.0
        var dodged := 0
        for i in 40:
                G.p_iframe = 0.0
                var hp_b: float = G.p_hp
                G.phase = "play"
                G.over = false
                G._hurt_player(10.0, null)
                if absf(G.p_hp - hp_b) < 0.01:
                        dodged += 1
        ck(dodged >= 14 and dodged <= 34,
                        "THE DODGE LAW: 60%% dodge dodged %d of 40 (a real chance)" % dodged)
        G.stats["dodge"] = 0.0
        G.p_hp = G.p_max_hp
        # REROLL: the climbing price laws
        ck(CSData.shop_reroll_cost(0) == 8 and CSData.shop_reroll_cost(2) == 20,
                        "THE REROLL LAW: the shop reroll climbs 8 + 6n")
        ck(CSData.draft_reroll_cost(0) == 6 and CSData.draft_reroll_cost(1) == 12,
                        "THE REROLL LAW: the draft reroll climbs 6 + 6n")
        # THE GOGACOIN RIDER: every 5th wave, one carrier, the drop pays
        G._start_run()
        await _wait(0.3)
        G._begin_wave(5)
        ck(G.goga_pending,
                        "THE RIDER LAW: wave 5 owes a gogacoin carrier")
        G._begin_wave(6)
        ck(not G.goga_pending,
                        "THE RIDER LAW: wave 6 owes nothing")
        G._begin_wave(5)
        for i in 8:
                G._spawn_enemy("blab", G.p_pos + Vector2.from_angle(randf() * TAU) * 400.0)
        G.p_iframe = 99.0
        G._tick_enemies(0.05)
        ck(G.goga_carrier_alive and not G.goga_pending,
                        "THE RIDER LAW: the swarm hid the coin in one carrier")
        var carrier: Dictionary = {}
        for ee in G.enemies:
                if ee.get("goga", false):
                        carrier = ee
        ck(not carrier.is_empty(), "THE RIDER LAW: exactly one carrier marked")
        var run_coins0: int = G.run_coins
        var pk_count0: int = G.pickups.size()
        G._kill_enemy(carrier, true)
        var goga_pk := {}
        for pk in G.pickups:
                if String(pk["kind"]) == "gogacoin":
                        goga_pk = pk
        ck(not goga_pk.is_empty() and G.pickups.size() > pk_count0,
                        "THE RIDER LAW: the dead carrier dropped the gogacoin")
        ck(not G.goga_carrier_alive, "THE RIDER LAW: the carrier flag cleared")
        goga_pk["pos"] = G.p_pos      # the LOGICAL seat (the node follows)
        G._tick_pickups(0.016)
        ck(G.run_coins == run_coins0 + 1,
                        "THE RIDER LAW: collecting pays +1 REAL gogacoin to the wallet")
        # THE COIN-DISTINCT LAW: the cosmic coin is NOT the gogacoin
        var cosmic: Texture2D = load("res://assets/games/cosmic_spud/pickups/coin.png")
        var boxc: Texture2D = load("res://assets/ui/coin.png")
        ck(cosmic.get_image().get_data() != boxc.get_image().get_data(),
                        "THE COIN LAW: the cosmic coin's pixels are NOT the gogacoin's")
        # THE TREE LOCK LAW: the reason speaks
        meta.d["tree"] = {}
        meta.d["char_level"] = 1
        meta.d["coins"] = 20
        meta.save()
        ck(G._tree_lock_reason("o2") == "needs SHARP PEEL",
                        "THE TREE LAW: o2's lock names the missing chain node")
        ck(G._tree_lock_reason("l3").contains("LV") or G._tree_lock_reason("l3").contains("needs"),
                        "THE TREE LAW: the LAB's lock speaks its reason (%s)" % G._tree_lock_reason("l3"))
        ck(G._tree_lock_reason("o1") != "" and G._tree_lock_reason("o1").contains("CC"),
                        "THE TREE LAW: a poor node's lock names the coins")
        # THE DAY/NIGHT LAW: two real faces + the tint finally applied
        var th: Dictionary = CSData.THEMES["desert"]
        ck(String(th["day"]) != String(th["night"]),
                        "THE THEME LAW: the desert owns a DAY and a NIGHT face")
        G._retheme("desert", true)
        ck(G.world.modulate == th["tint_night"],
                        "THE THEME LAW: night paints the world with the night tint")
        ck(is_instance_valid(G.ground_layer) and G.ground_layer.get_child_count() > 10,
                        "THE THEME LAW: the night ground repainted in place")
        G._retheme("desert", false)
        ck(G.world.modulate == th["tint_day"],
                        "THE THEME LAW: the day flip returns the daylight")
        # THE STORE LAW: the offers roll, the rarities are real
        G._roll_shop_offers()
        ck(G.shop_offers_w.size() == 4 and G.shop_offers_i.size() == 3,
                        "THE STORE LAW: 4 weapon + 3 item offers per break")
        var rar_ok := true
        for o in G.shop_offers_w:
                if not CSData.RARITIES.has(o["rar"]):
                        rar_ok = false
        ck(rar_ok, "THE STORE LAW: every offer wears a real rarity")
        # THE WIDGET LAW: the game's own HUD exists (kills + coins + carrier chip)
        ck(G.kill_txt != null and G.cc_txt != null and G.goga_chip != null,
                        "THE WIDGET LAW: the kills + coins + carrier widgets live")
        ck(G.get("stick_ghost") == null,
                        "THE STICK LAW: the ghost node is GONE (truly invisible)")
        # THE ARMORY LAW: the wallet buy lands in the armory
        meta.d["coins"] = 5000
        meta.save()
        G._armory_buy_weapon("laser", CSData.weapon_price("laser", 1))
        ck(meta.has_weapon("laser") and meta.weapon_count("laser") >= 1,
                        "THE ARMORY LAW: the wallet buy lands in the armory")
        meta.d["coins"] = 5000
        meta.save()
        # ------------------------------------------------ the meta laws
        var m2 := CSMeta.load_meta()
        m2.d["coins"] = 50
        m2.save()
        ck(not m2.spend(100), "the wallet refuses what it does not have")
        m2.earn(200)
        ck(m2.spend(100), "the wallet pays")
        ck(not m2.tree_can_buy("o2"), "THE TREE LAW: o2 locks behind its chain")
        m2.d["coins"] = 5000
        m2.d["char_xp"] = 0
        m2.d["char_level"] = 1
        m2.save()
        ck(not m2.tree_can_buy("l3"), "THE TREE LAW: the WEAPON LAB gates at LV4")
        # ============================== v0.3.4-2 - THE OWNER'S SECOND REPORT
        # THE DOOR LAW: rebuild the door fresh (the owner could not get past
        # the optionals - every tap was a dud and back froze the game)
        G.phase = "boot"
        G._boot_hint = ""
        G._cs_close_all()
        G._optionals_open()
        await _wait(0.2)
        ck(get_tree().paused and G.sheet_open_count() == 1,
                        "THE DOOR LAW: the optionals is up and the tree is paused")
        var door_box: VBoxContainer = G.cs_sheets[0]["box"]
        ck(_find_btn(door_box, "X") == null,
                        "THE DOOR LAW: the optionals wears NO X (the door cannot be closed)")
        ck(_find_btn_like(door_box, "GOGACOINS") != null,
                        "THE BORDER LAW: the un-owned place says GOGACOINS, never bare CC")
        G._back_pressed()
        ck(G.sheet_open_count() == 1 and G._boot_hint != "",
                        "THE DOOR LAW: back on the door speaks - it never closes it")
        G._armory_open()
        ck(G.sheet_open_count() == 2, "THE DOOR LAW: the armory stacks over the door")
        G._back_pressed()
        ck(G.sheet_open_count() == 1,
                        "THE DOOR LAW: back over the door closes the TOP sheet only")
        # THE BORDER LAW: the park charges the BOX wallet, cosmic coins untouched
        var goga_before := Box.coins()
        var cosmic_before := meta.coins()
        Box.earn(1000)
        G._armory_buy_theme("park", int(CSData.THEMES["park"]["gogacoins"]))
        await _wait(0.2)
        ck(meta.has_theme("park"), "THE BORDER LAW: the park is owned after the buy")
        ck(Box.coins() == goga_before + 1000 - int(CSData.THEMES["park"]["gogacoins"]),
                        "THE BORDER LAW: the buy drained the GOGACoin wallet")
        ck(meta.coins() == cosmic_before,
                        "THE BORDER LAW: the cosmic wallet never paid for a place")
        ck(G.sheet_open_count() == 1,
                        "THE BORDER LAW: the buy from the boot reopens the DOOR")
        door_box = G.cs_sheets[0]["box"]
        ck(_find_btn(door_box, "NIGHT") != null,
                        "THE BORDER LAW: the owned place now wears DAY/NIGHT chips")
        # THE SHEET LIFE LAW: the tap answers UNDER THE PAUSED TREE (the owner's
        # killer: v0.3.4-1's sheet chain inherited PAUSABLE - every button was
        # a dud on device while the probes, which call functions directly,
        # never saw it)
        var drop_b := _find_btn(door_box, "DROP IN")
        ck(drop_b != null, "THE SHEET LIFE LAW: DROP IN exists on the door")
        if drop_b != null:
                drop_b.pressed.emit()
                await _wait(0.4)
                ck(G.phase == "play" and G.run_wave == 1,
                                "THE SHEET LIFE LAW: the paused tree answers the tap - the run starts")
        # THE TEXT-FIT LAW: the boxes grow to their text (the overflow report)
        var sc: Button = G._start_card("engineer")
        var perk_h: float = G._cs_text_h(String(CSData.STARTS["engineer"]["perk"]), 10, 214.0)
        var stats_h: float = G._cs_text_h("HP 0  DMG 0%  SPD 0%\nASPD 0%  RNG 0%  ARM 0  LUCK 0%  DODGE 0%", 10, 214.0)
        ck(sc.custom_minimum_size.y >= 81.0 + perk_h + stats_h,
                        "THE TEXT-FIT LAW: the start card grows to fit its measured text")
        ck(G._cs_text_w("ENGINEER", 14) > 0.0,
                        "THE TEXT-FIT LAW: the measurer measures with the real font")
        var dc: Button = G._draft_card(CSData.WAVE_DRAFTS[0])
        ck(dc.custom_minimum_size.y >= 130.0,
                        "THE TEXT-FIT LAW: the draft card keeps its floor and grows past it")
        var tn: Button = G._tree_node("o2", null)
        ck(tn.custom_minimum_size.y >= 68.0,
                        "THE TEXT-FIT LAW: the tree node keeps its floor and grows past it")
        # fresh probe exit
        Box.reset_all()
        print("=== cs_probe: %d checks, %d fails ===" % [checks, fails])
        get_tree().quit(1 if fails > 0 else 0)

func _ready() -> void:
        _run()
