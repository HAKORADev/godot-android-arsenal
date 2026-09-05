extends GogaGame
## COSMIC SPUD (v0.3.4-1) - the Brotato-competitor, PATCH 1.
## THE GDD: docs/goga_docs/gogames_ideas/cosmic_spud.md + cosmic_spud_patch1.md.
## PATCH 1 LAWS (the owner's playtest round):
##   THE NODE-SYNC LAW: every enemy's sprite follows its body EVERY tick
##   (v0.3.4 shipped the frozen sprites - the "invisible enemies" lie).
##   THE GAME'S OWN FACE: gray field, black inner boxes, text only in
##   white/green/red/blue/yellow. NO GOGABox ui code renders a game screen.
##   THE STAY-INVISIBLE STICK: born under any touch, nothing ever draws.
##   LUCK / DODGE / REROLL: the Brotato mouthfuls, real stats.
##   THE GOGACOIN RIDER: every 5th wave one enemy carries the box's real
##   gogacoin - it drops on death and pays the GOGABox wallet.

const ARENA := Rect2(0, 0, 2400, 1350)
const ARENA_MARGIN := 90.0        # the ground paints past the bounds
const PLAYER_SPD := 210.0
const PLAYER_R := 22.0
const STICK_DEAD := 8.0
const STICK_MAX := 70.0
const IFRAME := 0.6
const MAGNET_BASE := 150.0

# ===================================================== THE GAME'S OWN COLORS
## the owner's design language: a gray field, BLACK inner boxes, text in
## white/green/red/blue/yellow only.
const CS_BG := Color(0.41, 0.42, 0.44)          # the gray field
const CS_BOX := Color(0.05, 0.05, 0.065)        # the black inner boxes
const CS_BOX2 := Color(0.1, 0.1, 0.12)          # the lighter black (hover)
const CS_EDGE := Color(0.18, 0.18, 0.21)        # the box edges
const CS_WHITE := Color(0.93, 0.94, 0.95)
const CS_GREEN := Color(0.44, 0.88, 0.5)
const CS_RED := Color(0.96, 0.38, 0.35)
const CS_BLUE := Color(0.46, 0.68, 1.0)
const CS_YELLOW := Color(1.0, 0.83, 0.3)

var meta: CSMeta
var world: Node2D
var ground_layer: Node2D         # the repaintable dress (grounds + props)
var fx: Node2D                   # the _draw overlay (rings, auras, beams)
var cam: Camera2D

var phase := "boot"               # boot | play | break | dead
var theme_id := "desert"
var night := false
var start_id := "soldier"

# the run's numbers
var run_wave := 1
var wave_clock := 0.0
var wave_spawning := true
var run_xp := 0
var run_level := 1
var run_ccoins := 0               # in-run cosmic coins (bank at the end)
var run_kills := 0
var run_merges := 0
var pending_levels := 0
var second_wind_used := false
var boss_alive := false

# the player
var p_pos := Vector2(1200, 675)
var p_hp := 100.0
var p_max_hp := 100.0
var p_aim := 0.0
var p_iframe := 0.0
var p_walk := 0.0
var p_node: Sprite2D
var stats := {}                   # the live stat block (see _base_stats)

# the entities
var enemies: Array = []
var bullets: Array = []
var ebullets: Array = []
var pickups: Array = []
var allies: Array = []
var props: Array = []             # [{c: Vector2, r: float}] the solid decor
var zones: Array = []             # gravity wells / telegraphs
var weapons_run: Array = []       # [{id, tier, cd}]

# the stick (TRULY invisible - no ghost node exists at all)
var stick_active := false
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO

# THE GOGACOIN RIDER (every 5th wave)
var goga_pending := false         # the wave owes a coin carrier
var goga_carry := false           # a living carrier rolled into the next wave
var goga_carrier_alive := false
var goga_chip: PanelContainer     # the HUD chip while a carrier lives

# THE SHOP's live state (the offers roll once per break)
var shop_offers_w: Array = []     # [{wid, tier, rar, price, sold}]
var shop_offers_i: Array = []     # [{iid, rar, price, sold}]
var shop_rerolls := 0
var draft_rerolls := 0
var draft_reroll_free := false

# hud widgets (all CS-styled)
var hp_fill: ColorRect
var hp_txt: Label
var arm_txt: Label
var xp_fill: ColorRect
var lvl_txt: Label
var wave_txt: Label
var wave_fill: ColorRect
var kill_txt: Label
var cc_txt: Label
var boss_bar: Control
var boss_fill: ColorRect
var boss_txt: Label
var slot_row: HBoxContainer
var _slot_widgets: Array = []     # [{box, cd, tier_txt}]
var _tex: Dictionary = {}
var _hud_built := false

# ================================================================ textures
func _t(key: String) -> Texture2D:
        if not _tex.has(key):
                var base := "res://assets/games/cosmic_spud/"
                var paths := {
                        "xp": base + "pickups/xp.png", "coin": base + "pickups/coin.png",
                        "heart": base + "pickups/heart.png",
                        "gogacoin": "res://assets/ui/coin.png",
                        "rock": base + "props/rock.png", "skull": base + "props/skull.png",
                        "crate": base + "props/crate.png", "barrel": base + "props/barrel.png",
                        "tree": base + "props/tree.png", "bench": base + "props/bench.png",
                        "fence": base + "props/fence.png", "shrub": base + "props/shrub.png",
                        "ferris": base + "props/ferris.png",
                        "crystal1": base + "props/crystal_1.png",
                        "crystal2": base + "props/crystal_2.png",
                        "crystal3": base + "props/crystal_3.png",
                        "circle": base + "fx/circle.png", "circle_soft": base + "fx/circle_soft.png",
                        "smoke": base + "fx/smoke.png", "star": base + "fx/star.png",
                        "flare": base + "fx/flare.png", "light": base + "fx/light.png",
                        "muzzle": base + "fx/muzzle.png", "dirt": base + "fx/dirt.png",
                        "fire": base + "fx/fire.png", "flame": base + "fx/flame.png",
                }
                for sid in CSData.START_ORDER:
                        for k in 4:
                                paths["hero_" + sid + "_f" + str(k)] = \
                                                base + "hero/hero_" + sid + "_f" + str(k) + ".png"
                for eid in CSData.ENEMIES:
                        paths[String(CSData.ENEMIES[eid]["tex"])] = \
                                        base + "enemies/" + String(CSData.ENEMIES[eid]["tex"]) + ".png"
                for bid in CSData.BOSSES:
                        paths[String(CSData.BOSSES[bid]["tex"])] = \
                                        base + "enemies/" + String(CSData.BOSSES[bid]["tex"]) + ".png"
                for wid in CSData.WEAPON_ORDER:
                        paths["icon_" + wid] = base + "weapons/icon_" + wid + ".png"
                        paths["gun_" + wid] = base + "weapons/gun_" + wid + ".png"
                for proj in ["bolt", "pellet", "slug", "lance", "bomb", "shard",
                                "rail", "spit", "orb", "boomerang", "tracer"]:
                        paths["proj_" + proj] = base + "bullets/" + proj + ".png"
                _tex[key] = load(paths[key])
        return _tex[key]

# ===================================================== THE CSUI (the kit)
## the game's own UI kit. NOTHING here touches the box's ui_kit.
func _cs_box_style(edge := CS_EDGE, bg := CS_BOX) -> StyleBoxFlat:
        var st := StyleBoxFlat.new()
        st.bg_color = bg
        st.border_color = edge
        st.set_border_width_all(2)
        st.corner_radius_top_left = 8
        st.corner_radius_top_right = 8
        st.corner_radius_bottom_left = 8
        st.corner_radius_bottom_right = 8
        st.content_margin_left = 8
        st.content_margin_right = 8
        st.content_margin_top = 6
        st.content_margin_bottom = 6
        return st

func _cs_panel_style() -> StyleBoxFlat:
        # the gray FIELD the boxes sit on
        var st := StyleBoxFlat.new()
        st.bg_color = CS_BG
        st.border_color = CS_EDGE
        st.set_border_width_all(2)
        st.corner_radius_top_left = 12
        st.corner_radius_top_right = 12
        st.corner_radius_bottom_left = 12
        st.corner_radius_bottom_right = 12
        st.content_margin_left = 10
        st.content_margin_right = 10
        st.content_margin_top = 8
        st.content_margin_bottom = 10
        return st

func _cs_label(txt: String, sz: int, col: Color, parent: Node = null) -> Label:
        var l := Label.new()
        l.text = txt
        l.add_theme_font_size_override("font_size", sz)
        l.add_theme_color_override("font_color", col)
        if parent != null:
                parent.add_child(l)
        return l

func _cs_button(txt: String, sz: int, col: Color, cb: Callable) -> Button:
        var b := Button.new()
        b.text = txt
        b.add_theme_font_size_override("font_size", sz)
        b.add_theme_color_override("font_color", col)
        b.add_theme_color_override("font_hover_color", col.lightened(0.25))
        b.add_theme_color_override("font_pressed_color", col.darkened(0.2))
        b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
        b.add_theme_stylebox_override("normal", _cs_box_style())
        var hov := _cs_box_style(CS_EDGE, CS_BOX2)
        b.add_theme_stylebox_override("hover", hov)
        var pr := _cs_box_style(CS_YELLOW.darkened(0.2), CS_BOX)
        b.add_theme_stylebox_override("pressed", pr)
        var dis := _cs_box_style(Color(0.13, 0.13, 0.15), Color(0.08, 0.08, 0.09))
        b.add_theme_stylebox_override("disabled", dis)
        b.pressed.connect(cb)
        return b

func _cs_black_box(parent: Node, min_size: Vector2) -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", _cs_box_style())
        p.custom_minimum_size = min_size
        parent.add_child(p)
        return p

func _cs_title_bar(box: VBoxContainer, title: String, col: Color) -> void:
        var bar := _cs_black_box(box, Vector2(0, 40))
        var h := HBoxContainer.new()
        bar.add_child(h)
        var t := _cs_label(title, 20, col)
        t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(t)

# ============================================== THE CS SHEETS (the stack)
## the game's own modal system - a dim + a gray panel wearing black boxes.
## The base game sheets are NOT used for this game's screens anymore.
var cs_sheets: Array = []         # [{dim, panel, box, id}]

func sheet_open_count() -> int:
        return cs_sheets.size()

func _cs_open(title: String, build: Callable, col: Color = CS_YELLOW) -> VBoxContainer:
        get_tree().paused = true
        paused = true
        var root := _overlay_root_ref()
        var vp := get_viewport_rect().size
        var dim := ColorRect.new()
        dim.color = Color(0, 0, 0, 0.52)
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(dim)
        var center := CenterContainer.new()
        center.set_anchors_preset(Control.PRESET_FULL_RECT)
        center.offset_top = 112.0   # the sheet clears the box's top bar
        center.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dim.add_child(center)
        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", _cs_panel_style())
        panel.custom_minimum_size = Vector2(vp.x * 0.96, 0)   # the height hugs the content
        center.add_child(panel)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 6)
        panel.add_child(box)
        # the title bar with the X
        var bar := PanelContainer.new()
        bar.add_theme_stylebox_override("panel", _cs_box_style(CS_EDGE, CS_BOX))
        box.add_child(bar)
        var bh := HBoxContainer.new()
        bar.add_child(bh)
        var tl := _cs_label(title, 19, col)
        tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bh.add_child(tl)
        var x := _cs_button("X", 16, CS_RED, func(): _cs_close_top())
        bh.add_child(x)
        var sheet := {"dim": dim, "panel": panel, "box": box, "id": "cs"}
        cs_sheets.append(sheet)
        build.call(box)
        return box

func _cs_close_top() -> void:
        if cs_sheets.is_empty():
                return
        var s: Dictionary = cs_sheets.pop_back()
        (s["dim"] as Control).queue_free()
        if cs_sheets.is_empty():
                get_tree().paused = false
                paused = false
        Jukebox.sfx("ui_click", -10.0)

func _cs_close_all() -> void:
        while not cs_sheets.is_empty():
                var s: Dictionary = cs_sheets.pop_back()
                (s["dim"] as Control).queue_free()
        get_tree().paused = false
        paused = false

## the old name lives on (the probe + any old callers)
func _close_all_sheets() -> void:
        _cs_close_all()

func _cs_reopen(build: Callable) -> void:
        # pop the top sheet and rebuild it (the live-state refresh)
        if not cs_sheets.is_empty():
                var s: Dictionary = cs_sheets.pop_back()
                (s["dim"] as Control).queue_free()
                if cs_sheets.is_empty():
                        get_tree().paused = false
                        paused = false
        build.call()

## the back law: a CS sheet closes first, else the box pause takes it
func _back_pressed() -> void:
        if not cs_sheets.is_empty():
                _cs_close_top()
                return
        super._back_pressed()

# ================================================================ setup
func _exit_tree() -> void:
        get_tree().paused = false     # THE UNFREEZE LAW

func _goga_setup() -> void:
        meta = CSMeta.load_meta()
        theme_id = meta.theme()
        night = meta.is_night()
        start_id = String(meta.d.get("last_start", "soldier"))
        if not CSData.STARTS.has(start_id):
                start_id = "soldier"
        bonus_div_override = 200      # THE OWNER'S KILL-BONUS LAW (/200)
        world = Node2D.new()
        add_child(world)
        _apply_ambience()
        _build_ground()
        _build_camera()
        fx = FxLayer.new()
        fx.game = self
        world.add_child(fx)
        _build_player()
        _build_hud()
        add_hud_button("SHOP", func(): _shop_button())
        add_hud_button("TREE", func(): _tree_open())
        var theme: Dictionary = CSData.THEMES[theme_id]
        Jukebox.music(theme["night_music"] if night else theme["day_music"])
        _optionals_open()

# ------------------------------------------------------------------ ground
func _build_ground() -> void:
        if ground_layer != null and is_instance_valid(ground_layer):
                ground_layer.queue_free()
        ground_layer = Node2D.new()
        ground_layer.z_index = -30
        world.add_child(ground_layer)
        var theme: Dictionary = CSData.THEMES[theme_id]
        var tex_path: String = theme["night"] if night else theme["day"]
        var gt: Texture2D = load(tex_path)
        var gw := gt.get_width()
        var gh := gt.get_height()
        for gy in range(-1, int((ARENA.size.y + ARENA_MARGIN * 2) / gh) + 1):
                for gx in range(-1, int((ARENA.size.x + ARENA_MARGIN * 2) / gw) + 1):
                        var cell := Sprite2D.new()
                        cell.texture = gt
                        cell.centered = false
                        cell.position = Vector2(gx * gw, gy * gh) - Vector2(ARENA_MARGIN, ARENA_MARGIN)
                        ground_layer.add_child(cell)
        # the park's dead ferris wheel watches from the top edge
        if theme_id == "park":
                var ferris := Sprite2D.new()
                ferris.texture = _t("ferris")
                ferris.position = Vector2(ARENA.size.x * 0.72, -30)
                ferris.modulate = Color(1, 1, 1, 0.55)
                ground_layer.add_child(ferris)
        _scatter_props(theme)
        _apply_ambience()

func _scatter_props(theme: Dictionary) -> void:
        props.clear()
        var rng := RandomNumberGenerator.new()
        rng.seed = int(hash(theme_id) + (911 if night else 313))  # per-theme+time
        var kinds: Array = theme["night_props"] if night else theme["props"]
        if night:
                kinds = kinds.duplicate()
                kinds.append_array(["crystal1", "crystal2"])  # the zip's crystals glow at night
        var n := 30
        for i in n:
                var k: String = kinds[rng.randi() % kinds.size()]
                if not _tex.has(k) and not _tex.has(k):
                        pass
                var tex: Texture2D = _t(k) if k in ["rock", "skull", "crate", "barrel",
                                "tree", "bench", "fence", "shrub", "ferris",
                                "crystal1", "crystal2", "crystal3"] else _t(String(k))
                var spr := Sprite2D.new()
                spr.texture = tex
                spr.position = Vector2(rng.randf_range(60, ARENA.size.x - 60),
                                rng.randf_range(60, ARENA.size.y - 60))
                spr.scale = Vector2.ONE * rng.randf_range(0.8, 1.5)
                spr.rotation = rng.randf_range(-0.2, 0.2)
                spr.z_index = -5
                ground_layer.add_child(spr)
                # big props are SOLID: a soft circle the units slide around
                var r := tex.get_width() * spr.scale.x * 0.35
                if k in ["rock", "crate", "tree", "barrel", "crystal1", "crystal2", "crystal3"]:
                        props.append({"c": spr.position, "r": r})

## the day/night ambience: the tint finally APPLIED (v0.3.4 computed it
## and dropped it on the floor - the patch-1 audit)
func _apply_ambience() -> void:
        var theme: Dictionary = CSData.THEMES[theme_id]
        world.modulate = theme["tint_night"] if night else theme["tint_day"]

## the theme flip repaints the dress in place - the run is never rebooted
func _retheme(tid: String, nite: bool) -> void:
        theme_id = tid
        night = nite
        meta.set_theme(theme_id, night)
        _build_ground()
        var theme: Dictionary = CSData.THEMES[theme_id]
        Jukebox.music(theme["night_music"] if night else theme["day_music"])

# ------------------------------------------------------------------ camera
func _build_camera() -> void:
        cam = Camera2D.new()
        cam.position = p_pos
        cam.make_current()
        add_child(cam)
        _apply_cam_zoom()

## THE ZOOM LAW: on huge logical viewports the camera zooms OUT so the
## visible world never exceeds ~1700x1000 - the view must never fit the
## whole ground (the camera law's guarantee, at any resolution).
func _apply_cam_zoom() -> void:
        var view := get_viewport_rect().size
        var z: float = maxf(maxf(1.0, view.x / 1700.0), view.y / 1000.0)
        cam.zoom = Vector2.ONE * z

func _cam_half() -> Vector2:
        return get_viewport_rect().size * 0.5 / (cam.zoom if cam != null else Vector2.ONE)

func _cam_clamp_pos(target: Vector2) -> Vector2:
        # the camera law: clamp to the arena + margin so the view NEVER fits the
        # whole ground - the edges always hold more world
        var half := _cam_half()
        var lo := Vector2(ARENA.position.x - ARENA_MARGIN, ARENA.position.y - ARENA_MARGIN) + half
        var hi := Vector2(ARENA.end.x + ARENA_MARGIN, ARENA.end.y + ARENA_MARGIN) - half
        if lo.x > hi.x:
                var mx := (ARENA.position.x + ARENA.end.x) * 0.5
                lo.x = mx
                hi.x = mx
        if lo.y > hi.y:
                var my := (ARENA.position.y + ARENA.end.y) * 0.5
                lo.y = my
                hi.y = my
        return Vector2(clampf(target.x, lo.x, hi.x), clampf(target.y, lo.y, hi.y))

# ------------------------------------------------------------------ player
func _build_player() -> void:
        p_pos = ARENA.get_center()
        p_node = Sprite2D.new()
        p_node.texture = _t("hero_" + start_id + "_f0")
        p_node.z_index = 10
        world.add_child(p_node)
        stats = _base_stats()
        p_max_hp = _max_hp()
        p_hp = p_max_hp
        _rebuild_weapons()

func _rebuild_weapons() -> void:
        weapons_run.clear()
        for wid in meta.loadout():
                weapons_run.append({"id": wid, "tier": 1, "cd": 0.0})
        _rebuild_slots()

# ================================================================ the stats
## the live stat block: START base x tree meta x run drafts x level picks.
## PATCH 1: LUCK and DODGE join the block (the Brotato mouthfuls).
func _base_stats() -> Dictionary:
        var s: Dictionary = CSData.STARTS[start_id]
        var st := {
                "dmg_m": float(s["dmg"]), "spd_m": float(s["spd"]),
                "aspeed_m": float(s["aspeed"]), "range_m": float(s["range"]),
                "armor": int(s["armor"]), "crit": float(s["crit"]),
                "regen": float(s["regen"]), "magnet": 1.0,
                "proj_add": 0, "pierce_all": 0, "lifesteal": 0.0,
                "burn_hit": start_id == "pyro", "chill_hit": start_id == "frostbite",
                "ally_dmg": 1.0, "contact_cut": 1.0,
                "crit_mult": 2.0, "coin_m": 1.0,
                "luck": float(s.get("luck", 0.0)),
                "dodge": float(s.get("dodge", 0.0)),
        }
        if start_id == "soldier":
                st["dmg_m"] += 0.10
        if start_id == "brawler":
                st["contact_cut"] = 0.8
        if start_id == "engineer":
                st["ally_dmg"] = 1.25
        # THE TREE (meta perks)
        if meta.tree_node("o1"):
                st["dmg_m"] += 0.08
        if meta.tree_node("o2"):
                st["dmg_m"] += 0.08
        if meta.tree_node("o4"):
                st["crit"] += 0.10
        if meta.tree_node("o5"):
                st["crit_mult"] = 3.0
        if meta.tree_node("d1"):
                st["hp_bonus"] = 20.0
        if meta.tree_node("d2"):
                st["armor"] += 2
        if meta.tree_node("d3"):
                st["regen"] += 1.0
        if meta.tree_node("u1"):
                st["magnet"] += 0.30
        if meta.tree_node("u2"):
                st["coin_m"] += 0.10
        if meta.tree_node("l2"):
                st["ally_dmg"] += 0.25
        return st

func _max_hp() -> float:
        var base: float = float(CSData.STARTS[start_id]["hp"])
        var bonus := 0.0
        if meta.tree_node("d1"):
                bonus += 20.0
        # the run's accumulated +max_hp (drafts + level picks live in stats.hp_add)
        bonus += float(stats.get("hp_add", 0.0))
        return base + bonus

# ================================================================ the tick
func _goga_tick(delta: float) -> void:
        if phase != "play" and phase != "break":
                return
        _tick_player(delta)
        _tick_weapons(delta)
        _tick_allies(delta)
        _tick_bullets(delta)
        _tick_ebullets(delta)
        _tick_enemies(delta)
        _tick_zones(delta)
        _tick_pickups(delta)
        _tick_waves(delta)
        _tick_fx(delta)
        _tick_camera(delta)
        fx.queue_redraw()
        _refresh_hud()

func _tick_player(delta: float) -> void:
        # the regen law
        if p_hp < p_max_hp and stats["regen"] > 0:
                p_hp = minf(p_max_hp, p_hp + stats["regen"] * delta)
        if p_iframe > 0:
                p_iframe -= delta
        var moving := false
        # the stick move
        if stick_active and stick_vec.length() > 0.01:
                var v := stick_vec * PLAYER_SPD * float(stats["spd_m"])
                p_pos += v * delta
                p_walk += delta * 10.0
                moving = true
        else:
                p_walk = 0.0
        # solid props: slide out of the circles
        for pr in props:
                var d: Vector2 = p_pos - pr["c"]
                var dist := d.length()
                var rmin: float = float(pr["r"]) + PLAYER_R
                if dist < rmin and dist > 0.01:
                        p_pos = pr["c"] + d.normalized() * rmin
        p_pos.x = clampf(p_pos.x, ARENA.position.x + PLAYER_R, ARENA.end.x - PLAYER_R)
        p_pos.y = clampf(p_pos.y, ARENA.position.y + PLAYER_R, ARENA.end.y - PLAYER_R)
        # THE WALK THEATRE: the legs answer the stick, the body never rotates
        # (Brotato's body faces the camera; the GUN does the aiming)
        var frame := 0
        if moving:
                frame = int(p_walk * 4.0) % 4
        p_node.texture = _t("hero_" + start_id + "_f" + str(frame))
        p_node.flip_h = absf(fposmod(p_aim + PI, TAU) - PI) > PI * 0.5
        p_node.position = p_pos + Vector2(0, sin(p_walk * TAU) * 1.5)
        var flash := 1.0 if p_iframe <= 0 else (0.5 + 0.5 * absf(sin(p_iframe * 30.0)))
        p_node.modulate = Color(1, flash, flash)

func _tick_camera(delta: float) -> void:
        var target := _cam_clamp_pos(p_pos)
        cam.position = cam.position.lerp(target, clampf(8.0 * delta, 0.0, 1.0))

# ================================================================ the stick
func _goga_input(event: InputEvent) -> void:
        if event is InputEventScreenTouch or event is InputEventMouseButton:
                var pressed: bool = event.pressed if event is InputEventScreenTouch \
                                else (event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
                var p := (event as InputEventScreenTouch).position \
                                if event is InputEventScreenTouch else (event as InputEventMouseButton).position
                if pressed and not stick_active:
                        # THE INVISIBLE STICK is born under ANY finger, anywhere.
                        # NOTHING renders - not a ring, not a knob, not a whisper.
                        if sheet_open_count() == 0 and not over and phase == "play":
                                stick_active = true
                                stick_origin = p
                                stick_vec = Vector2.ZERO
                elif not pressed and stick_active:
                        stick_active = false
                        stick_vec = Vector2.ZERO
        elif event is InputEventScreenDrag or event is InputEventMouseMotion:
                var p2 := (event as InputEventScreenDrag).position \
                                if event is InputEventScreenDrag else (event as InputEventMouseMotion).position
                if stick_active:
                        var d := p2 - stick_origin
                        if d.length() < STICK_DEAD:
                                stick_vec = Vector2.ZERO
                        else:
                                stick_vec = d.limit_length(STICK_MAX) / STICK_MAX

# ================================================================ the HUD
## THE GAME'S OWN WIDGETS: black boxes, colored text. HP green/red, XP blue,
## wave yellow, KILLS red, coins yellow, boss red. The money widget wears
## the NEW cosmic coin (a potato embossed in gold - never the gogacoin).
func _build_hud() -> void:
        if _hud_built:
                return
        _hud_built = true
        # the box chrome FIRST (its canvas layer + overlay root + back button),
        # then the game's own widgets on top - the box labels hide after
        super._build_hud()
        var sl := _score_label_ref()
        var cl := _coins_label_ref()
        if sl != null:
                sl.visible = false
        if cl != null:
                cl.visible = false
        if _hud_row != null and is_instance_valid(_hud_row):
                _hud_row.offset_top = 44.0
                _hud_row.offset_bottom = 104.0
        var root := _overlay_root_ref()
        # ---- the left stack (HP / XP / wave)
        var left := VBoxContainer.new()
        left.position = Vector2(12, 116)
        left.custom_minimum_size = Vector2(300, 0)
        left.add_theme_constant_override("separation", 4)
        root.add_child(left)
        var hp_box := _cs_black_box(left, Vector2(300, 26))
        hp_fill = ColorRect.new()
        hp_fill.color = CS_GREEN
        hp_fill.position = Vector2(2, 2)
        hp_fill.size = Vector2(296, 22)
        hp_box.add_child(hp_fill)
        hp_txt = _cs_label("", 12, CS_WHITE)
        hp_box.add_child(hp_txt)
        var sub := HBoxContainer.new()
        left.add_child(sub)
        arm_txt = _cs_label("ARM 0", 12, CS_BLUE)
        sub.add_child(arm_txt)
        lvl_txt = _cs_label("LV 1", 12, CS_BLUE)
        lvl_txt.custom_minimum_size = Vector2(64, 0)
        sub.add_child(lvl_txt)
        kill_txt = _cs_label("KILLS 0", 12, CS_RED)
        sub.add_child(kill_txt)
        # the XP bar
        var xp_box := _cs_black_box(left, Vector2(300, 12))
        xp_fill = ColorRect.new()
        xp_fill.color = CS_BLUE
        xp_fill.position = Vector2(2, 2)
        xp_fill.size = Vector2(296, 8)
        xp_box.add_child(xp_fill)
        # the wave box with its time bar
        var wave_box := _cs_black_box(left, Vector2(300, 30))
        var wv := VBoxContainer.new()
        wave_box.add_child(wv)
        wave_txt = _cs_label("WAVE 1", 12, CS_YELLOW)
        wv.add_child(wave_txt)
        wave_fill = ColorRect.new()
        wave_fill.color = Color(1.0, 0.62, 0.26)
        wave_fill.custom_minimum_size = Vector2(280, 4)
        wv.add_child(wave_fill)
        # ---- the money widget (top right, under the chrome band)
        var cc := _cs_black_box(root, Vector2(128, 30))
        cc.position = Vector2(get_viewport_rect().size.x - 140, 116)
        var h := HBoxContainer.new()
        cc.add_child(h)
        var ic := TextureRect.new()
        ic.texture = _t("coin")
        ic.custom_minimum_size = Vector2(20, 20)
        ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        h.add_child(ic)
        cc_txt = _cs_label("0", 15, CS_YELLOW)
        h.add_child(cc_txt)
        # ---- the gogacoin chip (hidden unless a carrier lives)
        goga_chip = _cs_black_box(root, Vector2(190, 30))
        goga_chip.position = Vector2(get_viewport_rect().size.x - 140, 152)
        var h2 := HBoxContainer.new()
        goga_chip.add_child(h2)
        var ic2 := TextureRect.new()
        ic2.texture = _t("gogacoin")
        ic2.custom_minimum_size = Vector2(20, 20)
        ic2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ic2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        h2.add_child(ic2)
        _cs_label("CARRIER!", 12, CS_GREEN, h2)
        goga_chip.visible = false
        # ---- the boss bar (top center)
        boss_bar = _cs_black_box(root, Vector2(430, 20))
        boss_bar.position = Vector2((get_viewport_rect().size.x - 430) * 0.5, 116)
        boss_fill = ColorRect.new()
        boss_fill.color = CS_RED
        boss_fill.position = Vector2(2, 2)
        boss_fill.size = Vector2(426, 16)
        boss_bar.add_child(boss_fill)
        boss_txt = _cs_label("", 11, CS_WHITE)
        boss_bar.add_child(boss_txt)
        boss_bar.visible = false
        # ---- the weapon slots (bottom left)
        slot_row = HBoxContainer.new()
        slot_row.position = Vector2(12, get_viewport_rect().size.y - 66)
        slot_row.add_theme_constant_override("separation", 6)
        root.add_child(slot_row)
        _rebuild_slots()

func _rebuild_slots() -> void:
        if slot_row == null or not is_instance_valid(slot_row):
                return
        for w in _slot_widgets:
                (w["box"] as Control).queue_free()
        _slot_widgets.clear()
        for wr in weapons_run:
                var box := PanelContainer.new()
                box.add_theme_stylebox_override("panel", _cs_box_style())
                box.custom_minimum_size = Vector2(46, 46)
                slot_row.add_child(box)
                var vb := VBoxContainer.new()
                vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
                box.add_child(vb)
                var ic := TextureRect.new()
                ic.texture = _t("icon_" + String(wr["id"]))
                ic.custom_minimum_size = Vector2(40, 30)
                ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                vb.add_child(ic)
                var tt := _cs_label("T%d" % int(wr["tier"]), 10, CS_YELLOW)
                tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                vb.add_child(tt)
                var cd := ColorRect.new()
                cd.color = Color(0, 0, 0, 0.55)
                cd.position = Vector2(2, 2)
                cd.size = Vector2(0, 42)
                box.add_child(cd)
                _slot_widgets.append({"box": box, "cd": cd, "id": wr["id"]})

func _refresh_hud() -> void:
        if hp_fill != null and is_instance_valid(hp_fill):
                var f := clampf(p_hp / p_max_hp, 0.0, 1.0)
                hp_fill.size.x = 296.0 * f
                hp_fill.color = CS_GREEN if f > 0.35 else CS_RED
                hp_txt.text = "%d / %d" % [int(ceilf(p_hp)), int(p_max_hp)]
                hp_txt.position = Vector2((300 - hp_txt.size.x) * 0.5, 2)
        if arm_txt != null:
                arm_txt.text = "ARM %d" % int(stats.get("armor", 0))
                lvl_txt.text = "LV %d" % run_level
                kill_txt.text = "KILLS %d" % run_kills
        if xp_fill != null:
                var need := CSData.xp_for_run_level(run_level)
                xp_fill.size.x = 296.0 * clampf(float(run_xp) / float(need), 0.0, 1.0)
        if wave_txt != null:
                wave_txt.text = ("BOSS WAVE - SLAY IT" if boss_alive
                                else "WAVE %d" % run_wave)
                wave_txt.add_theme_color_override("font_color", CS_RED if boss_alive else CS_YELLOW)
                var total := CSData.BOSS_WAVE_SECS if (run_wave % CSData.BOSS_CYCLE == 0) \
                                else CSData.WAVE_SECS
                wave_fill.custom_minimum_size.x = 280.0 * clampf(wave_clock / total, 0.0, 1.0)
        if cc_txt != null:
                cc_txt.text = str(run_ccoins)
        if goga_chip != null:
                goga_chip.visible = goga_carrier_alive
        if boss_fill != null:
                var found := false
                for e in enemies:
                        if e.get("boss", false):
                                found = true
                                boss_bar.visible = true
                                boss_fill.size.x = 426.0 * clampf(float(e["hp"]) / float(e["max_hp"]), 0.0, 1.0)
                                boss_txt.text = "%s  %d%%" % [e["name"], int(100.0 * float(e["hp"]) / float(e["max_hp"]))]
                                boss_txt.position = Vector2((430 - boss_txt.size.x) * 0.5, 0)
                                break
                if not found:
                        boss_bar.visible = false
        # the slot cooldown fills
        for i in _slot_widgets.size():
                if i >= weapons_run.size():
                        break
                var wd: Dictionary = CSData.WEAPONS[weapons_run[i]["id"]]
                var mult: Dictionary = CSData.tier_mult(int(weapons_run[i]["tier"]))
                var full: float = float(wd["cad"]) * float(mult["cad"])
                var left2: float = maxf(0.0, float(weapons_run[i]["cd"]))
                (_slot_widgets[i]["cd"] as ColorRect).size.y = 42.0 * clampf(left2 / maxf(0.01, full), 0.0, 1.0)

# ================================================================ weapons
func _tick_weapons(delta: float) -> void:
        # aim: the best target for the FIRST weapon sets Spudnik's facing
        p_aim = _aim_angle()
        for w in weapons_run:
                w["cd"] -= delta * float(stats["aspeed_m"])
                if w["cd"] <= 0.0:
                        if _fire_weapon(w):
                                var mult: Dictionary = CSData.tier_mult(int(w["tier"]))
                                w["cd"] = float(CSData.WEAPONS[w["id"]]["cad"]) * float(mult["cad"])
                        else:
                                w["cd"] = 0.05   # nothing in range - retry soon

func _aim_angle() -> float:
        var best := p_aim
        var best_score := -1.0
        for e in enemies:
                var d: Vector2 = e["pos"] - p_pos
                var dist := d.length()
                if dist > 900.0:
                        continue
                var pr := 1.0
                if e.get("boss", false):
                        pr = 3.0
                elif e.get("elite", false):
                        pr = 2.0
                var sc := pr * 1000.0 - dist
                if sc > best_score:
                        best_score = sc
                        best = d.angle()
        return best

func _fire_weapon(w: Dictionary) -> bool:
        var wid: String = w["id"]
        var wd: Dictionary = CSData.WEAPONS[wid]
        var tier: int = int(w["tier"])
        var mult := CSData.tier_mult(tier)
        var rng: float = float(wd["rng"]) * float(stats["range_m"])
        var count: int = int(wd["count"]) + int(mult["count"]) + int(stats["proj_add"])
        var target: Variant = _pick_target(rng)
        if target == null:
                return false
        var te: Dictionary = target
        var base_a: float = (te["pos"] - p_pos).angle()
        var shot_name: String = wd["shot"]
        var pierce: int = int(wd["pierce"])
        if int(stats["pierce_all"]) > 0:
                pierce = 99
        for i in count:
                var a := base_a
                if count > 1:
                        a += (float(i) - float(count - 1) * 0.5) * float(wd["spread"])
                var dmg: float = float(wd["dmg"]) * float(mult["dmg"]) * float(stats["dmg_m"])
                var kind: String = wd["proj"]
                if kind == "strike":
                        _orbital_strike(te["pos"], dmg, float(wd.get("aoe", 60.0)))
                        continue
                _spawn_bullet(p_pos + Vector2.from_angle(a) * 26.0, a, wd, dmg, pierce, tier)
        Jukebox.sfx(shot_name, -6.0, randf_range(0.94, 1.06))
        # the muzzle kiss at the gun tip
        _parts.append({"pos": p_pos + Vector2.from_angle(base_a) * 30.0, "vel": Vector2.ZERO,
                "t": 0.06, "max": 0.06, "col": Color(1, 0.9, 0.5), "size": 9.0, "tex": "muzzle"})
        return true

func _pick_target(rng: float) -> Variant:
        var best: Variant = null
        var best_score := -1.0
        for e in enemies:
                var d: Vector2 = e["pos"] - p_pos
                var dist := d.length()
                if dist > rng:
                        continue
                var pr := 1.0
                if e.get("boss", false):
                        pr = 3.0
                elif e.get("elite", false):
                        pr = 2.0
                var sc := pr * 1000.0 - dist
                if sc > best_score:
                        best_score = sc
                        best = e
        return best

func _spawn_bullet(pos: Vector2, a: float, wd: Dictionary, dmg: float,
                pierce: int, tier: int) -> void:
        var kind: String = wd["proj"]
        var spr := Sprite2D.new()
        spr.texture = _t("proj_" + kind)
        spr.position = pos
        spr.rotation = a
        spr.z_index = 6
        world.add_child(spr)
        var b := {
                "pos": pos, "a": a, "spd": float(wd["pspd"]), "dmg": dmg,
                "pierce": pierce, "hit": {}, "range_left": float(wd["rng"])
                                * float(stats["range_m"]),
                "aoe": float(wd.get("aoe", 0.0)), "burn": bool(wd.get("burn", false))
                                or bool(stats["burn_hit"]),
                "chill": float(wd.get("chill", 0.0)), "kind": kind,
                "node": spr, "turn": false, "tier": tier,
        }
        if kind == "boomerang":
                b["home"] = null
        bullets.append(b)

func _orbital_strike(at: Vector2, dmg: float, aoe: float) -> void:
        zones.append({"kind": "strike", "pos": at, "t": 0.55, "max": 0.55,
                "dmg": dmg, "aoe": aoe})
        Jukebox.sfx("cs_flash", -8.0)

# ================================================================ allies
func _deploy_ally(aid: String, level: int) -> void:
        var ad: Dictionary = CSData.ALLIES[aid]
        var spr := Sprite2D.new()
        spr.texture = _t(String(ad["tex"]))
        spr.scale = Vector2.ONE * 0.7
        spr.modulate = Color(0.82, 1.0, 0.9)
        spr.z_index = 8
        world.add_child(spr)
        allies.append({"id": aid, "level": level, "pos": p_pos
                        + Vector2.from_angle(randf() * TAU) * 50.0, "node": spr,
                        "cd": 0.0, "state": "", "t": 0.0})

func _ally_cap() -> int:
        return meta.ally_slots()

func _tick_allies(delta: float) -> void:
        for a in allies:
                var aid: String = a["id"]
                var lv: int = int(a["level"])
                a["t"] += delta
                match aid:
                        "drone":
                                var ang: float = float(a["t"]) * 1.6
                                a["pos"] = p_pos + Vector2.from_angle(ang) * 62.0
                                a["cd"] -= delta * float(stats["ally_dmg"])
                                if a["cd"] <= 0.0 and not enemies.is_empty():
                                        a["cd"] = 0.5
                                        var tgt: Dictionary = _nearest_enemy(a["pos"], 520.0)
                                        if tgt != null:
                                                var dir: Vector2 = tgt["pos"] - a["pos"]
                                                _ally_bullet(a["pos"], dir.angle(),
                                                                4.0 + 2.0 * lv * float(stats["ally_dmg"]))
                        "turret":
                                if a["pos"].distance_to(p_pos) > 260.0:
                                        a["state"] = "move"
                                if a["state"] == "move":
                                        a["pos"] = a["pos"].move_toward(p_pos
                                                        + Vector2.from_angle(a["t"]) * 70.0, 190.0 * delta)
                                        if a["pos"].distance_to(p_pos) < 160.0:
                                                a["state"] = ""
                                a["cd"] -= delta * float(stats["ally_dmg"])
                                if a["cd"] <= 0.0:
                                        a["cd"] = 0.42
                                        var tgt2: Dictionary = _nearest_enemy(a["pos"], 440.0)
                                        if tgt2 != null:
                                                var d2: Vector2 = tgt2["pos"] - a["pos"]
                                                _ally_bullet(a["pos"], d2.angle(),
                                                                6.0 + 3.0 * lv * float(stats["ally_dmg"]))
                        "guard":
                                var threat := Vector2.ZERO
                                var tn := 0
                                for e in enemies:
                                        if e["pos"].distance_to(p_pos) < 140.0:
                                                threat += e["pos"]
                                                tn += 1
                                if tn > 0:
                                        a["pos"] = a["pos"].lerp(p_pos + (threat / float(tn) - p_pos).normalized() * 40.0,
                                                        6.0 * delta)
                                else:
                                        a["pos"] = a["pos"].lerp(p_pos + Vector2(40, 40), 4.0 * delta)
                        "medic":
                                a["pos"] = a["pos"].lerp(p_pos + Vector2(-40, -40), 4.0 * delta)
                                p_hp = minf(p_max_hp, p_hp + (2.0 + lv) * delta)
                        "bomber":
                                a["cd"] -= delta
                                if a["state"] == "dive":
                                        var dtgt: Dictionary = a["target"]
                                        if dtgt == null or not is_instance_valid(dtgt.get("node")) \
                                                        or dtgt.get("dead", false):
                                                a["state"] = ""
                                                a["t"] = 0.0
                                        else:
                                                a["pos"] = a["pos"].move_toward(dtgt["pos"], 420.0 * delta)
                                                if a["pos"].distance_to(dtgt["pos"]) < 26.0:
                                                        _boom_at(a["pos"], 70.0, (14.0 + 6.0 * lv)
                                                                        * float(stats["ally_dmg"]), true)
                                                        a["node"].visible = false
                                                        a["state"] = "dead"
                                                        a["t"] = 0.0
                                elif a["state"] == "dead":
                                        if a["t"] >= 5.0:
                                                a["state"] = ""
                                                a["pos"] = p_pos
                                                a["node"].visible = true
                                elif a["cd"] <= 0.0 and not enemies.is_empty():
                                        var tgt3: Dictionary = _nearest_enemy(a["pos"], 400.0)
                                        if tgt3 != null:
                                                a["state"] = "dive"
                                                a["target"] = tgt3
                                                a["cd"] = 8.0
                                elif a["state"] == "":
                                        a["pos"] = a["pos"].lerp(p_pos + Vector2(50, -50), 3.0 * delta)
                        "scout":
                                a["pos"] = a["pos"].lerp(p_pos + Vector2(0, 60), 3.0 * delta)
                                for e in enemies:
                                        if e["pos"].distance_to(p_pos) < 300.0:
                                                e["marked"] = true
                a["node"].position = a["pos"]

func _nearest_enemy(from: Vector2, rng: float) -> Variant:
        var best: Variant = null
        var bd := rng
        for e in enemies:
                var d: float = e["pos"].distance_to(from)
                if d < bd:
                        bd = d
                        best = e
        return best

func _ally_bullet(pos: Vector2, a: float, dmg: float) -> void:
        var spr := Sprite2D.new()
        spr.texture = _t("proj_bolt")
        spr.modulate = Color(0.7, 1, 0.85)
        spr.position = pos
        spr.rotation = a
        spr.z_index = 6
        world.add_child(spr)
        bullets.append({"pos": pos, "a": a, "spd": 620.0, "dmg": dmg, "pierce": 0,
                "hit": {}, "range_left": 420.0, "aoe": 0.0, "burn": false, "chill": 0.0,
                "kind": "bolt", "node": spr, "turn": false, "tier": 1})

# ================================================================ bullets
func _tick_bullets(delta: float) -> void:
        var dead := []
        for b in bullets:
                if b["kind"] == "boomerang":
                        _tick_boomerang(b, delta, dead)
                        continue
                var step: Vector2 = Vector2.from_angle(b["a"]) * float(b["spd"]) * delta
                b["pos"] += step
                b["range_left"] -= step.length()
                b["node"].position = b["pos"]
                if b["kind"] == "orb":
                        # THE GRAVITY WELL: drags enemies while it flies
                        for e in enemies:
                                if e["pos"].distance_to(b["pos"]) < 140.0:
                                        e["pos"] = e["pos"].move_toward(b["pos"], 160.0 * delta)
                if b["range_left"] <= 0.0:
                        if float(b["aoe"]) > 0.0:
                                _boom_at(b["pos"], float(b["aoe"]), float(b["dmg"]), false)
                        dead.append(b)
                        continue
                for e in enemies:
                        var key: int = e["uid"]
                        if b["hit"].has(key):
                                continue
                        var hit_r: float = float(e["size"]) * 0.5 * float(e.get("scale_m", 1.0)) + 6.0
                        if e["pos"].distance_to(b["pos"]) > hit_r:
                                continue
                        # THE TRI-SHIELD LAW: the rings eat the bullet first
                        if e.get("rings", null) != null:
                                var res: int = _ring_bullet(e, b)
                                if res == 1:
                                        b["hit"][key] = true
                                        continue          # carved a ring - the bullet died
                                elif res == 2:
                                        continue          # passed a window - no hit yet
                        b["hit"][key] = true
                        var dmg: float = float(b["dmg"])
                        if e.get("marked", false):
                                dmg *= 1.15
                        if e.get("chill_t", 0.0) > 0.0:
                                dmg *= 1.10
                        dmg *= float(e.get("hurt_m", 1.0))
                        var crit := randf() < float(stats["crit"])
                        if crit:
                                dmg *= float(stats["crit_mult"])
                                Jukebox.sfx("cs_crit", -8.0, 1.2)
                        _hurt_enemy(e, dmg, crit)
                        if b["burn"]:
                                e["burn_t"] = 3.0
                        if float(b["chill"]) > 0.0:
                                e["chill_t"] = float(b["chill"])
                        if float(b["aoe"]) > 0.0:
                                _boom_at(b["pos"], float(b["aoe"]), float(b["dmg"]) * 0.6, false)
                                dead.append(b)
                                break
                        if int(b["pierce"]) <= 0:
                                dead.append(b)
                                break
                        b["pierce"] = int(b["pierce"]) - 1
        for b2 in dead:
                b2["node"].queue_free()
                bullets.erase(b2)

func _tick_boomerang(b: Dictionary, delta: float, dead: Array) -> void:
        if not b["turn"]:
                var step: Vector2 = Vector2.from_angle(b["a"]) * float(b["spd"]) * delta
                b["pos"] += step
                b["range_left"] -= step.length()
                if b["range_left"] <= 0.0:
                        b["turn"] = true
                        b["hit"] = {}       # the return trip hits again
        else:
                var to_p: Vector2 = p_pos - b["pos"]
                if to_p.length() < 18.0:
                        dead.append(b)
                        return
                b["pos"] += to_p.normalized() * float(b["spd"]) * delta
        b["node"].position = b["pos"]
        b["node"].rotation += 14.0 * delta
        for e in enemies:
                var key: int = e["uid"]
                if b["hit"].has(key):
                        continue
                if e["pos"].distance_to(b["pos"]) < float(e["size"]) * 0.5 + 8.0:
                        b["hit"][key] = true
                        _hurt_enemy(e, float(b["dmg"]), false)

# ================================================================ enemies
var _uid := 0

func _spawn_enemy(kind: String, pos: Vector2, elite := false) -> Dictionary:
        var ed: Dictionary = CSData.ENEMIES[kind]
        var hp: float = float(ed["hp"]) * CSData.hp_scale(run_wave)
        var spd: float = float(ed["spd"]) * CSData.spd_scale(run_wave)
        var dmg: float = float(ed["dmg"]) * CSData.dmg_scale(run_wave)
        var scale_m := 1.0
        var affix := ""
        if elite:
                var keys := CSData.ELITE_AFFIX.keys()
                affix = keys[randi() % keys.size()]
                var ax: Dictionary = CSData.ELITE_AFFIX[affix]
                hp *= 1.6 * float(ax.get("hp", 1.0))
                spd *= float(ax.get("spd", 1.0))
                dmg *= 1.3 * float(ax.get("dmg", 1.0))
                scale_m = float(ax.get("scale", 1.35))
        var spr := Sprite2D.new()
        spr.texture = _t(String(ed["tex"]))
        spr.scale = Vector2.ONE * scale_m
        spr.position = pos
        spr.z_index = 5
        world.add_child(spr)
        _uid += 1
        var e := {
                "uid": _uid, "kind": kind, "name": String(ed["name"]),
                "hp": hp, "max_hp": hp, "spd": spd, "dmg": dmg,
                "size": float(ed["size"]), "pos": pos, "node": spr,
                "scale_m": scale_m, "elite": elite, "affix": affix,
                "xp": int(ed["xp"]), "score": int(ed["score"]),
                "burn_t": 0.0, "burn_tick": 0.0, "chill_t": 0.0,
                "marked": false, "hurt_m": 1.0, "flash": 0.0,
                "shoot_cd": randf_range(0.0, 1.0), "state": "walk", "st": 0.0,
                "boss": false, "gen": 0, "anim": randf() * TAU, "goga": false,
        }
        if affix == "armored":
                e["hurt_m"] = CSData.ELITE_AFFIX["armored"]["hurt"]
        if kind == "trishield":
                e["rings"] = _mk_rings([90.0, 70.0, 50.0])
        enemies.append(e)
        # the spawn poof (they ARRIVE, they never blink in)
        _rings.append({"pos": pos, "r": float(e["size"]) * 1.6, "t": 0.3, "max": 0.3,
                "col": Color(0.9, 0.4, 0.4), "w": 3.0})
        return e

## THE GOGACOIN RIDER: one random enemy of the milestone wave swallows the
## box's real gogacoin. It glints, it dies, it pays.
func _plant_goga_carrier() -> void:
        if goga_carrier_alive or enemies.is_empty():
                return
        var cands := []
        for x in enemies:
                if not x.get("boss", false) and not x.get("goga", false):
                        cands.append(x)
        if cands.is_empty():
                return
        var e: Dictionary = cands[randi() % cands.size()]
        e["goga"] = true
        goga_carrier_alive = true
        goga_pending = false
        _banner("A GOGACOIN HIDES IN THE SWARM!", true)
        Jukebox.sfx("cs_coin", -2.0, 1.2)

func _mk_rings(radii: Array) -> Array:
        # the python law: radii, thickness 8, counter-rotating rad/frame speeds,
        # cracks stored as angle intervals in each ring's LOCAL rotating frame
        var arr := []
        var speeds := [0.05, 0.03, 0.01, 0.008]
        for i in radii.size():
                arr.append({"r": float(radii[i]), "rot": randf() * TAU,
                        "spd": float(speeds[i % speeds.size()]) * (1.0 if i % 2 == 0 else -1.0),
                        "cracks": []})
        return arr

## returns 0 = no ring contact, 1 = carved a ring (bullet dies),
## 2 = passed through a window (bullet continues inward)
func _ring_bullet(e: Dictionary, b: Dictionary) -> int:
        var d: float = b["pos"].distance_to(e["pos"])
        var rings: Array = e["rings"]
        for ring in rings:
                var band: float = absf(d - float(ring["r"]))
                if band > 4.0 + 4.0:
                        continue
                var world_a: float = (b["pos"] - e["pos"]).angle()
                var local_a: float = world_a - float(ring["rot"])
                local_a = fposmod(local_a, TAU)
                if _in_crack(ring["cracks"], local_a):
                        continue    # the window is open - the bullet flies inward
                var halfw := atan(6.0 / maxf(10.0, float(ring["r"])))
                ring["cracks"] = _carve(ring["cracks"], local_a - halfw, local_a + halfw)
                Jukebox.sfx("cs_shield_crack", -6.0, randf_range(0.9, 1.2))
                return 1
        if d < float(rings[rings.size() - 1]["r"]) - 4.0:
                return 2    # inside the innermost ring: the core is exposed
        return 0

func _in_crack(cracks: Array, a: float) -> bool:
        for c in cracks:
                if float(c[0]) <= a and a <= float(c[1]):
                        return true
                if float(c[0]) > float(c[1]) and (a >= float(c[0]) or a <= float(c[1])):
                        return true
        return false

func _carve(cracks: Array, a0: float, a1: float) -> Array:
        # add [a0,a1] (wrapped into 0..TAU) and merge overlaps - the python's
        # interval-subtraction law, inverted
        var ivs := []
        for c in cracks:
                ivs.append([float(c[0]), float(c[1])])
        if a0 < 0.0:
                ivs.append([fposmod(a0, TAU), TAU])
                ivs.append([0.0, a1])
        elif a1 > TAU:
                ivs.append([a0, TAU])
                ivs.append([0.0, fposmod(a1, TAU)])
        else:
                ivs.append([a0, a1])
        ivs.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
        var out: Array = []
        for iv in ivs:
                if not out.is_empty() and float(iv[0]) <= float(out[out.size() - 1][1]) + 0.001:
                        out[out.size() - 1][1] = maxf(float(out[out.size() - 1][1]), float(iv[1]))
                else:
                        out.append(iv)
        return out

func _tick_rings(e: Dictionary, delta: float) -> void:
        for ring in e["rings"]:
                ring["rot"] = fposmod(float(ring["rot"]) + float(ring["spd"]) * 60.0
                                * delta, TAU)
        # THE PUSH-OUT LAW: the player cannot stand inside a ring
        var d: float = p_pos.distance_to(e["pos"])
        for ring in e["rings"]:
                var r: float = float(ring["r"])
                if absf(d - r) < 10.0 + PLAYER_R:
                        var away: Vector2 = (p_pos - e["pos"]).normalized()
                        p_pos = e["pos"] + away * (r + 10.0 + PLAYER_R)
                        d = p_pos.distance_to(e["pos"])

func _tick_enemies(delta: float) -> void:
        var to_kill := []
        for e in enemies:
                if e.get("dead", false):
                        continue
                e["st"] += delta
                # statuses
                if e["burn_t"] > 0.0:
                        e["burn_t"] -= delta
                        e["burn_tick"] -= delta
                        if e["burn_tick"] <= 0.0:
                                e["burn_tick"] = 0.5
                                _hurt_enemy(e, 1.0, false, true)
                if e["chill_t"] > 0.0:
                        e["chill_t"] -= delta
                var slow := 0.8 if e["chill_t"] > 0.0 else 1.0
                var spd: float = float(e["spd"]) * slow
                var to_p: Vector2 = p_pos - e["pos"]
                var dist: float = to_p.length()
                var kind: String = e["kind"]
                var moved := false
                # ===== the per-kind AI =====
                if e.get("boss", false):
                        _boss_ai(e, delta, to_p, dist)
                        moved = true
                elif kind == "spitter":
                        var keep: float = 260.0
                        var want: Vector2 = to_p.normalized()
                        if dist > keep + 40.0:
                                e["pos"] += want * spd * delta
                                moved = true
                        elif dist < keep - 40.0:
                                e["pos"] -= want * spd * delta
                                moved = true
                        else:
                                e["pos"] += want.orthogonal() * spd * 0.6 * delta
                                moved = true
                        e["shoot_cd"] -= delta
                        if e["shoot_cd"] <= 0.0:
                                e["shoot_cd"] = 2.2
                                _enemy_bullet(e["pos"], to_p.angle(), float(e["dmg"]))
                elif kind == "charger":
                        if e["state"] == "walk":
                                e["pos"] += to_p.normalized() * spd * delta
                                moved = true
                                if dist < 300.0:
                                        e["state"] = "wind"
                                        e["st"] = 0.0
                        elif e["state"] == "wind":
                                if e["st"] >= 0.6:
                                        e["state"] = "dash"
                                        e["st"] = 0.0
                                        e["dash_dir"] = to_p.normalized()
                        elif e["state"] == "dash":
                                e["pos"] += Vector2(e["dash_dir"]) * spd * 3.0 * delta
                                moved = true
                                if e["st"] >= 0.5:
                                        e["state"] = "rest"
                                        e["st"] = 0.0
                        elif e["state"] == "rest":
                                if e["st"] >= 0.8:
                                        e["state"] = "walk"
                elif kind == "orbiter":
                        if e["state"] == "walk":
                                var ang: float = (e["pos"] - p_pos).angle() + 1.9 * delta
                                e["pos"] = p_pos + Vector2.from_angle(ang) * 180.0
                                moved = true
                                if e["st"] > randf_range(3.0, 5.0):
                                        e["state"] = "dive"
                                        e["st"] = 0.0
                        elif e["state"] == "dive":
                                e["pos"] += to_p.normalized() * spd * 2.4 * delta
                                moved = true
                                if dist < 26.0 or e["st"] > 1.6:
                                        e["state"] = "walk"
                                        e["st"] = 0.0
                elif kind == "boomling":
                        if dist < 90.0 and e["state"] != "fuse":
                                e["state"] = "fuse"
                                e["st"] = 0.0
                        if e["state"] == "fuse":
                                spd = 0.0
                                if e["st"] >= 0.7:
                                        _boom_at(e["pos"], 60.0, 25.0 * CSData.dmg_scale(run_wave), true)
                                        to_kill.append(e)
                                        continue
                        else:
                                e["pos"] += to_p.normalized() * spd * delta
                                moved = true
                else:
                        # the chase law (the python base)
                        e["pos"] += to_p.normalized() * spd * delta
                        moved = true
                # ===== THE NODE-SYNC LAW (the patch-1 headline: the sprite
                # FOLLOWS the body every tick - v0.3.4 left it at the spawn) =====
                var nd: Sprite2D = e["node"]
                nd.position = e["pos"]
                # the walk theatre: a waddle squash + a lean + the flip
                if moved and spd > 0.1:
                        e["anim"] += delta * (4.0 + spd * 0.022)
                var base_s: float = float(e.get("scale_m", 1.0))
                var wob := 0.05 * sin(e["anim"] * TAU)
                nd.scale = Vector2(base_s * (1.0 + wob), base_s * (1.0 - wob))
                if to_p.x != 0.0:
                        nd.flip_h = to_p.x < 0.0
                # ===== the auras =====
                if kind == "wraith" or e.get("aura", 0.0) > 0.0:
                        if dist < float(e.get("aura", 250.0)) and p_iframe <= 0.0:
                                e["aura_tick"] = float(e.get("aura_tick", 0.0)) - delta
                                if e["aura_tick"] <= 0.0:
                                        e["aura_tick"] = 1.0
                                        _hurt_player(float(e.get("aura_dps", 15.0)), e)
                if kind == "mender":
                        e["heal_tick"] = float(e.get("heal_tick", 0.0)) - delta
                        if e["heal_tick"] <= 0.0:
                                e["heal_tick"] = 0.5
                                for o in enemies:
                                        if o == e or o.get("dead", false):
                                                continue
                                        if o["pos"].distance_to(e["pos"]) < 500.0:
                                                o["hp"] = minf(float(o["max_hp"]), float(o["hp"]) + 10.0)
                                                _heal_flash(o)
                if e.get("rings", null) != null:
                        _tick_rings(e, delta)
                # ===== contact (the python law: the enemy's REMAINING HP hits you,
                # then the enemy dies on your skin) =====
                var touch_r: float = float(e["size"]) * 0.5 * float(e.get("scale_m", 1.0)) + PLAYER_R - 6.0
                if e.get("boss", false):
                        touch_r = float(e["size"]) * 0.5 + PLAYER_R - 10.0
                if dist < touch_r and p_iframe <= 0.0:
                        if e.get("boss", false):
                                _hurt_player(float(e["dmg"]), e)
                        else:
                                var raw := float(e["hp"])
                                var contact := clampf(raw, 1.0, 80.0) * float(stats["contact_cut"])
                                _hurt_player(contact, e)
                                to_kill.append(e)   # the splatter kills the enemy too
                                continue
                # the flash decay
                if e["flash"] > 0.0:
                        e["flash"] -= delta
                        nd.modulate = Color(3, 3, 3) if e["flash"] > 0.0 \
                                        else (Color(1.25, 1.2, 0.8) if e.get("goga", false) else Color(1, 1, 1))
                    # the gogacoin glint
                if e.get("goga", false) and e["flash"] <= 0.0:
                        nd.modulate = Color(1.25, 1.2, 0.8)
        # the flocking separation (the python law: 100px, force (1-d/100)*0.5)
        if enemies.size() <= 80:
                for i in enemies.size():
                        var a: Dictionary = enemies[i]
                        if a.get("dead", false) or a.get("boss", false):
                                continue
                        var push := Vector2.ZERO
                        for j in enemies.size():
                                if i == j:
                                        continue
                                var b: Dictionary = enemies[j]
                                var dd: Vector2 = a["pos"] - b["pos"]
                                var dl := dd.length()
                                if dl < 100.0 and dl > 0.01:
                                        push += dd / dl * (100.0 - dl) / 100.0
                        a["pos"] += push * 0.5 * 60.0 * delta
                        a["pos"] += Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * 60.0 * delta
                        # THE NODE-SYNC LAW holds even after the flock nudge
                        (a["node"] as Sprite2D).position = a["pos"]
        for e2 in to_kill:
                # a contact-splattered carrier still coughs up its coin
                if e2.get("goga", false):
                        goga_carrier_alive = false
                        _drop_pickup("gogacoin", e2["pos"], 1)
                        e2["goga"] = false
                        _banner("THE CARRIER DROPPED THE COIN!", true)
                _kill_enemy(e2, false)
        # the milestone owes its carrier - plant it on the living swarm
        if goga_pending and phase == "play":
                _plant_goga_carrier()

func _enemy_bullet(pos: Vector2, a: float, dmg: float) -> void:
        var spr := Sprite2D.new()
        spr.texture = _t("proj_spit")
        spr.position = pos
        spr.rotation = a
        spr.z_index = 6
        world.add_child(spr)
        ebullets.append({"pos": pos, "a": a, "spd": 300.0, "dmg": dmg,
                "node": spr, "life": 3.0})

func _tick_ebullets(delta: float) -> void:
        var dead := []
        for b in ebullets:
                b["pos"] += Vector2.from_angle(b["a"]) * float(b["spd"]) * delta
                b["life"] -= delta
                b["node"].position = b["pos"]
                if b["life"] <= 0.0:
                        dead.append(b)
                        continue
                if b["pos"].distance_to(p_pos) < PLAYER_R + 6.0:
                        _hurt_player(float(b["dmg"]), null)
                        dead.append(b)
        for b2 in dead:
                b2["node"].queue_free()
                ebullets.erase(b2)

func _boss_ai(e: Dictionary, delta: float, to_p: Vector2, dist: float) -> void:
        var b: Dictionary = e["bdata"]
        if b.get("self_mend", 0.0) > 0.0:
                e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(b["self_mend"]) * delta)
        if b.get("burst", false) and e["state"] != "burst":
                e["burst_cd"] = float(e.get("burst_cd", 3.0)) - delta
                if e["burst_cd"] <= 0.0:
                        e["burst_cd"] = 4.0
                        e["state"] = "burst"
                        e["st"] = 0.0
                        var n := 14
                        for i in n:
                                _enemy_bullet(e["pos"], float(i) / float(n) * TAU, float(e["dmg"]) * 0.6)
                        Jukebox.sfx("cs_boom", -8.0, 0.8)
        if b.get("slam", false):
                e["slam_cd"] = float(e.get("slam_cd", 3.5)) - delta
                if e["slam_cd"] <= 0.0 and dist < 260.0:
                        e["slam_cd"] = 5.0
                        zones.append({"kind": "slam", "pos": p_pos, "t": 0.8, "max": 0.8,
                                "dmg": float(e["dmg"]), "aoe": 120.0})
        if b.get("charge", false) or b.get("triple_charge", false):
                e["charge_cd"] = float(e.get("charge_cd", 2.0)) - delta
                if e["state"] == "walk" and e["charge_cd"] <= 0.0 and dist < 500.0:
                        e["state"] = "wind"
                        e["st"] = 0.0
                        e["charges_left"] = 3 if b.get("triple_charge", false) else 1
                elif e["state"] == "wind":
                        e["spd_m"] = 0.0
                        if e["st"] >= 0.55:
                                e["state"] = "dash"
                                e["st"] = 0.0
                                e["dash_dir"] = to_p.normalized()
                elif e["state"] == "dash":
                        e["pos"] += Vector2(e["dash_dir"]) * float(e["spd"]) * 3.4 * delta
                        if e["st"] >= 0.45:
                                e["charges_left"] = int(e.get("charges_left", 1)) - 1
                                e["tp_count"] = int(e.get("tp_count", 0)) + 1
                                if int(e.get("teleport", 0)) > 0 \
                                                and e["tp_count"] % int(e["teleport"]) == 0:
                                        e["pos"] = p_pos - to_p.normalized() * 140.0
                                if int(e["charges_left"]) > 0:
                                        e["state"] = "wind"
                                        e["st"] = 0.4
                                else:
                                        e["state"] = "walk"
                                        e["charge_cd"] = 3.2
        if b.get("summon", "") != "":
                e["summon_cd"] = float(e.get("summon_cd", 8.0)) - delta
                var hp_frac := float(e["hp"]) / float(e["max_hp"])
                if e["summon_cd"] <= 0.0 and (hp_frac < 0.66 or hp_frac < 0.33):
                        e["summon_cd"] = 9.0
                        for i in int(b["summon_n"]):
                                _spawn_enemy(String(b["summon"]), e["pos"]
                                                + Vector2.from_angle(randf() * TAU) * 70.0)
                        Jukebox.sfx("cs_boss_roar", -4.0)
        if e["state"] != "dash" and e["state"] != "wind":
                e["pos"] += to_p.normalized() * float(e["spd"]) * delta
        if e.get("aura", 0.0) > 0.0 and dist < float(e["aura"]) and p_iframe <= 0.0:
                e["aura_tick"] = float(e.get("aura_tick", 0.0)) - delta
                if e["aura_tick"] <= 0.0:
                        e["aura_tick"] = 1.0
                        _hurt_player(float(e["aura_dps"]), e)

func _spawn_boss(wave: int) -> void:
        var cycle := int((wave - 1) / CSData.BOSS_CYCLE)   # 0-based
        var bid: String = CSData.BOSS_ORDER[cycle % CSData.BOSS_ORDER.size()]
        var bd: Dictionary = CSData.BOSSES[bid]
        var m := pow(CSData.BOSS_CYCLE_MULT, float(cycle))
        var e := _spawn_enemy("blab", p_pos + Vector2(0, -420), false)
        e["kind"] = bid
        e["name"] = String(bd["name"])
        e["hp"] = float(bd["hp"]) * m
        e["max_hp"] = e["hp"]
        e["spd"] = float(bd["spd"])
        e["dmg"] = float(bd["dmg"]) * m
        e["size"] = float(bd["size"])
        e["xp"] = int(bd["xp"])
        e["score"] = int(bd["score"]) + cycle * CSData.BOSS_CYCLE_SCORE
        e["coins_drop"] = int(ceil(float(bd["coins"]) * m))
        e["boss"] = true
        e["bdata"] = bd
        e["node"].texture = _t(String(bd["tex"]))
        e["node"].scale = Vector2.ONE * 1.6
        e["scale_m"] = 1.6
        if bd.get("rings", null) != null:
                e["rings"] = _mk_rings(bd["rings"])
        boss_alive = true
        Jukebox.sfx("cs_boss_roar", -2.0)
        Jukebox.music("res://assets/audio/music/cs_boss.ogg")
        _banner("%s ARRIVES!" % String(bd["name"]), false)

# ================================================================ damage
func _hurt_enemy(e: Dictionary, dmg: float, crit := false, silent := false) -> void:
        if e.get("dead", false):
                return
        e["hp"] = float(e["hp"]) - dmg
        e["flash"] = 0.06
        if not silent:
                _dmg_number(e["pos"], dmg, crit)
        if float(stats["lifesteal"]) > 0.0 and not silent:
                p_hp = minf(p_max_hp, p_hp + dmg * float(stats["lifesteal"]))
        if e["hp"] <= 0.0:
                _kill_enemy(e, true)

func _kill_enemy(e: Dictionary, drops: bool) -> void:
        if e.get("dead", false):
                return
        e["dead"] = true
        run_kills += 1
        var sc := int(e["score"])
        if e.get("elite", false):
                sc += CSData.ELITE_SCORE
        add_score(sc)
        _death_burst(e)
        Jukebox.sfx("cs_kill_big" if e.get("boss", false) else "cs_hit", -7.0,
                        randf_range(0.8, 1.3) if not e.get("boss", false) else 0.7)
        if drops:
                _drop_pickup("xp", e["pos"], int(e["xp"]) * 2)
                var coin_m: float = float(stats["coin_m"])
                var luck: float = float(stats.get("luck", 0.0))
                # THE GOGACOIN RIDER drops first (the owner's new feature)
                if e.get("goga", false):
                        goga_carrier_alive = false
                        _drop_pickup("gogacoin", e["pos"], 1)
                        _banner("THE CARRIER DROPPED THE COIN!", true)
                if e.get("coins_drop", 0) > 0:
                        for i in int(e["coins_drop"]):
                                _drop_pickup("coin", e["pos"] + Vector2.from_angle(randf() * TAU) * 20.0,
                                                maxi(1, int(round(coin_m))))
                elif e.get("elite", false):
                        for i in randi_range(3, 6):
                                _drop_pickup("coin", e["pos"] + Vector2.from_angle(randf() * TAU) * 20.0,
                                                maxi(1, int(round(coin_m))))
                elif randf() < 0.08 * (1.0 + luck):
                        _drop_pickup("coin", e["pos"], maxi(1, int(round(1 * coin_m))))
                if randf() < 0.06 * (1.0 + luck):
                        _drop_pickup("heart", e["pos"], 15)
                var kind: String = e["kind"]
                if kind == "brood":
                        for i in 2:
                                _spawn_enemy("minion", e["pos"] + Vector2(-20 + i * 40, 10))
                elif kind == "splitter":
                        var gen: int = int(e.get("gen", 0))
                        if gen < 2:
                                for i in 2:
                                        var s := _spawn_enemy("splitter", e["pos"]
                                                        + Vector2.from_angle(randf() * TAU) * 24.0)
                                        s["hp"] = float(e["max_hp"]) * 0.3
                                        s["max_hp"] = s["hp"]
                                        s["spd"] = float(s["spd"]) * 1.10
                                        s["gen"] = gen + 1
                                        s["size"] = float(s["size"]) * 0.75
                                        s["node"].scale = Vector2.ONE * 0.75
        if e.get("boss", false):
                boss_alive = false
                Jukebox.sfx("cs_boom_big", -2.0)
                var th: Dictionary = CSData.THEMES[theme_id]
                Jukebox.music(th["night_music"] if night else th["day_music"])
        enemies.erase(e)
        e["node"].queue_free()

func _hurt_player(dmg: float, src: Variant) -> void:
        if p_iframe > 0.0 or over or phase != "play":
                return
        # THE DODGE LAW (patch 1): a real chance to no-hit, capped at 60%
        var dodge := clampf(float(stats.get("dodge", 0.0)), 0.0, 0.6)
        if dodge > 0.0 and randf() < dodge:
                _dmg_number(p_pos, 0.0, false, CS_BLUE)
                _floaters[_floaters.size() - 1]["txt"] = "DODGE!"
                Jukebox.sfx("cs_flash", -12.0, 1.6)
                return
        var actual: float = maxf(1.0, dmg - float(stats["armor"]))
        p_hp -= actual
        p_iframe = IFRAME
        _dmg_number(p_pos, actual, false, Color(1, 0.5, 0.5))
        Jukebox.sfx("cs_hurt", -4.0)
        if src != null and src is Dictionary and (src as Dictionary).get("affix", "") == "vampiric":
                var s: Dictionary = src
                s["hp"] = minf(float(s["max_hp"]), float(s["hp"]) + actual * 0.2)
        if p_hp <= 0.0:
                if meta.tree_node("d4") and not second_wind_used:
                        second_wind_used = true
                        p_hp = p_max_hp * 0.5
                        _banner("SECOND WIND!", false)
                        Jukebox.sfx("cs_levelup", -2.0)
                        _boom_at(p_pos, 260.0, 40.0, true)
                        return
                _die()

# ================================================================ pickups
func _drop_pickup(kind: String, pos: Vector2, v: int) -> void:
        var spr := Sprite2D.new()
        spr.texture = _t(kind)
        spr.position = pos
        spr.z_index = 4
        world.add_child(spr)
        pickups.append({"kind": kind, "v": v, "pos": pos, "node": spr, "bob": randf() * TAU})

func _tick_pickups(delta: float) -> void:
        var dead := []
        var magnet: float = MAGNET_BASE * float(stats["magnet"])
        for pk in pickups:
                pk["bob"] += delta * 4.0
                pk["node"].position = pk["pos"] + Vector2(0, sin(pk["bob"]) * 3.0)
                var to_p: Vector2 = p_pos - pk["pos"]
                var d := to_p.length()
                if String(pk["kind"]) == "gogacoin":
                        pass    # the gogacoin waits like a trophy - no magnet chase
                elif d < magnet:
                        pk["pos"] += to_p.normalized() * 340.0 * delta
                if d < PLAYER_R + 12.0:
                        match String(pk["kind"]):
                                "xp":
                                        run_xp += int(pk["v"])
                                        Jukebox.sfx("cs_xp", -10.0, randf_range(0.95, 1.1))
                                        while run_xp >= CSData.xp_for_run_level(run_level):
                                                run_xp -= CSData.xp_for_run_level(run_level)
                                                run_level += 1
                                                pending_levels += 1
                                        if pending_levels > 0:
                                                _level_draft_open()
                                "coin":
                                        run_ccoins += int(pk["v"])
                                        Jukebox.sfx("cs_coin", -8.0)
                                "heart":
                                        p_hp = minf(p_max_hp, p_hp + float(pk["v"]))
                                        Jukebox.sfx("cs_heal", -6.0)
                                "gogacoin":
                                        # THE REAL GOGACOIN: +1 to the GOGABox wallet
                                        add_run_coins(1)
                                        meta.d["gogacoins"] = int(meta.d.get("gogacoins", 0)) + 1
                                        meta.save()
                                        Jukebox.sfx("cs_coin", 0.0, 1.3)
                                        _banner("GOGACOIN +1 (the box wallet)", true)
                        dead.append(pk)
        for pk2 in dead:
                pk2["node"].queue_free()
                pickups.erase(pk2)

func _tick_zones(delta: float) -> void:
        var dead := []
        for z in zones:
                z["t"] -= delta
                if z["t"] <= 0.0:
                        if z["kind"] == "strike":
                                _boom_at(z["pos"], float(z["aoe"]), float(z["dmg"]), true)
                        elif z["kind"] == "slam":
                                if p_pos.distance_to(z["pos"]) < float(z["aoe"]):
                                        _hurt_player(float(z["dmg"]), null)
                                _boom_at(z["pos"], float(z["aoe"]), 0.0, false)
                        dead.append(z)
        for z2 in dead:
                zones.erase(z2)

## the explosion law: damages enemies (and the player when `hits_player`)
func _boom_at(pos: Vector2, r: float, dmg: float, hits_player: bool) -> void:
        for e in enemies.duplicate():
                if e["pos"].distance_to(pos) < r + float(e["size"]) * 0.5:
                        _hurt_enemy(e, dmg)
        if hits_player and p_pos.distance_to(pos) < r + PLAYER_R:
                _hurt_player(dmg * 0.8, null)
        _shockwave(pos, r)
        Jukebox.sfx("cs_boom", -4.0)

# ================================================================ waves
func _tick_waves(delta: float) -> void:
        if phase != "play":
                return
        wave_clock -= delta
        _spawn_stream(delta)
        if wave_clock <= 0.0 and not boss_alive:
                _wave_clear()

var _spawn_clock := 0.0
var _burst_clock := 0.0

func _begin_wave(w: int) -> void:
        run_wave = w
        phase = "play"
        var boss_wave := w % CSData.BOSS_CYCLE == 0
        wave_clock = CSData.BOSS_WAVE_SECS if boss_wave else CSData.WAVE_SECS
        _spawn_clock = 0.0
        _burst_clock = 2.0
        # THE GOGACOIN RIDER: every 5th wave owes one coin carrier (a living
        # carrier from the previous wave keeps the debt alive)
        goga_pending = goga_carry or (w % 5 == 0)
        goga_carry = false
        if boss_wave:
                _spawn_boss(w)
                wave_spawning = true
        else:
                Jukebox.sfx("cs_wave_horn", -4.0)
                _banner("WAVE %d" % w, true)

func _spawn_stream(delta: float) -> void:
        _spawn_clock -= delta
        _burst_clock -= delta
        if _spawn_clock <= 0.0:
                _spawn_clock = CSData.spawn_interval(run_wave)
                _spawn_one()
        if _burst_clock <= 0.0:
                _burst_clock = 5.0
                _spawn_burst(CSData.burst_size(run_wave))

func _spawn_one() -> void:
        var pool := CSData.pool_for_wave(run_wave)
        var kind: String = pool[randi() % pool.size()]
        # LUCK: the elites answer to the clover too
        var elite_p := CSData.elite_chance(run_wave) * (1.0 + float(stats.get("luck", 0.0)) * 0.6)
        _spawn_enemy(kind, _spawn_pos(), randf() < elite_p)

func _spawn_burst(n: int) -> void:
        for i in n:
                _spawn_one()

func _spawn_pos() -> Vector2:
        var a := randf() * TAU
        var r := randf_range(620.0, 780.0)
        var p := p_pos + Vector2.from_angle(a) * r
        return Vector2(clampf(p.x, ARENA.position.x - 80.0, ARENA.end.x + 80.0),
                        clampf(p.y, ARENA.position.y - 80.0, ARENA.end.y + 80.0))

func _wave_clear() -> void:
        # a living carrier re-hides its coin in the NEXT wave's swarm
        if goga_carrier_alive:
                goga_carrier_alive = false
                goga_carry = true
        for e in enemies.duplicate():
                _drop_pickup("xp", e["pos"], int(e["xp"]) * 2)
                e["node"].queue_free()
                enemies.erase(e)
        for b in ebullets:
                b["node"].queue_free()
        ebullets.clear()
        for b2 in bullets:
                b2["node"].queue_free()
        bullets.clear()
        p_hp = minf(p_max_hp, p_hp + CSData.WAVE_HEAL)
        var bonus := maxi(1, int(round((CSData.WAVE_COINS + 2 * run_wave)
                        * float(stats["coin_m"]))))
        run_ccoins += bonus
        phase = "break"
        _banner("WAVE %d CLEAR  +%d CC" % [run_wave, bonus], true)
        Jukebox.sfx("cs_levelup", -4.0)
        run_wave += 1
        _wave_break_open()

# ================================================================ the breaks
## the wave-break flow: clear -> the WAVE DRAFT (1 of 3, with teeth, now
## REROLLABLE) -> THE SHOP (the store-like rebuild) -> the next wave.
var _draft_cards: Array = []
var _break_in_shop := false

func _wave_break_open() -> void:
        _break_in_shop = false
        draft_rerolls = 0
        draft_reroll_free = meta.tree_has("u3")
        shop_rerolls = 0
        _roll_shop_offers()
        if pending_levels > 0:
                _level_draft_open()
                return
        _wave_draft_open()

func _after_draft_or_shop() -> void:
        if pending_levels > 0:
                _level_draft_open()
                return
        if not _break_in_shop:
                _break_in_shop = true
                _shop_open()
                return
        _cs_close_all()
        _begin_wave(run_wave)

# ------------------------------------------------------------- wave draft
func _wave_draft_open() -> void:
        _draft_cards = _roll_wave_drafts(3)
        _cs_open("WAVE %d CLEARED - CHOOSE ONE" % (run_wave - 1), func(box: VBoxContainer):
                _build_draft(box), CS_YELLOW)

func _roll_wave_drafts(n: int) -> Array:
        # weighted pick without repeats
        var pool := []
        for d in CSData.WAVE_DRAFTS:
                pool.append({"d": d, "w": int(d["w"])})
        var out := []
        for i in n:
                var total := 0
                for p in pool:
                        total += int(p["w"])
                var r := randi() % total
                for p in pool:
                        r -= int(p["w"])
                        if r < 0:
                                out.append(p["d"])
                                pool.erase(p)
                                break
        return out

func _draft_reroll_cost() -> int:
        return 6 + draft_rerolls * 6

func _build_draft(box: VBoxContainer) -> void:
        var sub := _cs_label("every card GIVES something - most TAKE something back",
                        12, CS_WHITE)
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(sub)
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 12)
        box.add_child(row)
        for d in _draft_cards:
                row.add_child(_draft_card(d))
        var actions := HBoxContainer.new()
        actions.alignment = BoxContainer.ALIGNMENT_CENTER
        actions.add_theme_constant_override("separation", 14)
        box.add_child(actions)
        # THE REROLL (patch 1): u3 owns one free shuffle per break, then coins
        var rr := _cs_button("REROLL  %s" % ("FREE" if draft_reroll_free
                        else "%d CC" % _draft_reroll_cost()), 14, CS_BLUE, func():
                if draft_reroll_free:
                        draft_reroll_free = false
                elif run_ccoins >= _draft_reroll_cost():
                        run_ccoins -= _draft_reroll_cost()
                        draft_rerolls += 1
                else:
                        Jukebox.sfx("cs_error", -6.0)
                        _toast_show("not enough coins")
                        return
                _draft_cards = _roll_wave_drafts(3)
                Jukebox.sfx("cs_draft", -6.0, 1.2)
                _cs_reopen(func(): _wave_draft_open()))
        actions.add_child(rr)
        var skip := _cs_button("SKIP - take nothing", 14, CS_WHITE, func():
                _after_draft_or_shop())
        actions.add_child(skip)

func _draft_card(d: Dictionary) -> Button:
        var b := Button.new()
        b.custom_minimum_size = Vector2(240, 130)
        var risky: bool = not (d["down"] as Dictionary).is_empty()
        var st := _cs_box_style(CS_GREEN if not risky else CS_RED, CS_BOX)
        st.corner_radius_top_left = 12
        st.corner_radius_top_right = 12
        st.corner_radius_bottom_left = 12
        st.corner_radius_bottom_right = 12
        b.add_theme_stylebox_override("normal", st)
        var hov := _cs_box_style(CS_YELLOW if not risky else CS_RED, CS_BOX2)
        b.add_theme_stylebox_override("hover", hov)
        var vb := VBoxContainer.new()
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.offset_left = 8
        vb.offset_top = 10
        vb.offset_right = -8
        b.add_child(vb)
        var up := _cs_label(String(d["t"]), 17, CS_GREEN)
        up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(up)
        var dn := _cs_label(String(d["d"]), 13, CS_RED if risky else CS_WHITE)
        dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        dn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(dn)
        b.pressed.connect(func():
                _apply_draft(d)
                Jukebox.sfx("cs_draft", -4.0)
                _after_draft_or_shop())
        return b

func _apply_draft(d: Dictionary) -> void:
        for k in d["up"]:
                _apply_stat(String(k), d["up"][k])
        for k2 in d["down"]:
                _apply_stat(String(k2), d["down"][k2])

func _apply_stat(k: String, v: Variant) -> void:
        match k:
                "dmg": stats["dmg_m"] = float(stats["dmg_m"]) + float(v)
                "spd": stats["spd_m"] = float(stats["spd_m"]) + float(v)
                "aspeed": stats["aspeed_m"] = float(stats["aspeed_m"]) + float(v)
                "range": stats["range_m"] = float(stats["range_m"]) + float(v)
                "armor": stats["armor"] = int(stats["armor"]) + int(v)
                "regen": stats["regen"] = float(stats["regen"]) + float(v)
                "crit": stats["crit"] = float(stats["crit"]) + float(v)
                "luck": stats["luck"] = float(stats.get("luck", 0.0)) + float(v)
                "dodge": stats["dodge"] = float(stats.get("dodge", 0.0)) + float(v)
                "magnet": stats["magnet"] = float(stats["magnet"]) + float(v)
                "hp":
                        stats["hp_add"] = float(stats.get("hp_add", 0.0)) + float(v)
                        p_max_hp = _max_hp()
                        p_hp = clampf(p_hp + maxf(0.0, float(v)), 1.0, p_max_hp)
                "proj": stats["proj_add"] = int(stats["proj_add"]) + int(v)

# ------------------------------------------------------------ level draft
func _level_draft_open() -> void:
        _cs_open("LEVEL %d - THE TREE OFFERS" % run_level, func(box: VBoxContainer):
                _build_level_draft(box), CS_BLUE)

func _build_level_draft(box: VBoxContainer) -> void:
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 12)
        box.add_child(row)
        var pool := CSData.LEVEL_DRAFTS.duplicate()
        pool.shuffle()
        var picks := pool.slice(0, 3)
        for d in picks:
                var b := Button.new()
                b.custom_minimum_size = Vector2(220, 96)
                var st := _cs_box_style(CS_BLUE, CS_BOX)
                st.corner_radius_top_left = 12
                st.corner_radius_top_right = 12
                st.corner_radius_bottom_left = 12
                st.corner_radius_bottom_right = 12
                b.add_theme_stylebox_override("normal", st)
                var hov := _cs_box_style(CS_YELLOW, CS_BOX2)
                b.add_theme_stylebox_override("hover", hov)
                var l := _cs_label(String(d["t"]), 15, CS_WHITE)
                l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                l.set_anchors_preset(Control.PRESET_CENTER)
                l.mouse_filter = Control.MOUSE_FILTER_IGNORE
                b.add_child(l)
                var dd: Dictionary = d
                b.pressed.connect(func():
                        _apply_stat(String(dd["k"]), dd["v"])
                        pending_levels -= 1
                        Jukebox.sfx("cs_levelup", -4.0)
                        if phase == "break":
                                _after_draft_or_shop()
                        elif not cs_sheets.is_empty():
                                _cs_close_top())
                row.add_child(b)

# ================================================================ THE SHOP
## THE STORE-LIKE REBUILD (the owner: the example HTML had a good store -
## this is that shape): a header with the fat balance, stat chips, WEAPON
## offers with rarities, ITEMS, SUPPLIES, ALLIES, THE MERGE BENCH, YOUR
## LOADOUT with SELL, and the REROLL + START WAVE actions.
func _shop_button() -> void:
        if phase == "play":
                _toast_show("the shop opens at the wave break - hold on!")
                return
        if phase == "break":
                _break_in_shop = true
                _shop_open()
        else:
                _armory_open()

func _shop_open() -> void:
        _cs_open("THE SHOP", func(box: VBoxContainer): _build_shop(box), CS_YELLOW)

func _roll_shop_offers() -> void:
        # 4 weapon offers + 3 item offers, luck-weighted rarities
        var luck := float(stats.get("luck", 0.0))
        shop_offers_w.clear()
        var used := {}
        var owned_n := meta.armory().size()
        for k in 4:
                var wid := _pick_offer_weapon(used)
                used[wid] = true
                var rar := CSData.roll_rarity(luck)
                var tier := 1
                if meta.char_level() >= 4 and k >= 2 and randf() < 0.35:
                        tier = 2
                var price := int(round(CSData.weapon_price(wid, tier)
                                * CSData.RARITIES[rar]["pm"] * meta.shop_discount()))
                shop_offers_w.append({"wid": wid, "tier": tier, "rar": rar,
                        "price": price, "sold": false})
        shop_offers_i.clear()
        var iused := {}
        for k in 3:
                var iid: String = CSData.ITEM_ORDER[randi() % CSData.ITEM_ORDER.size()]
                if iused.has(iid):
                        k -= 1
                        continue
                iused[iid] = true
                var rar2 := CSData.roll_rarity(luck)
                var it: Dictionary = CSData.ITEMS[iid]
                var base_p := int(it.get("price", 30))
                var price2 := int(round(base_p * float(CSData.RARITIES[rar2]["pm"])
                                + run_wave * 1.5))
                shop_offers_i.append({"iid": iid, "rar": rar2, "price": price2,
                        "sold": false})

func _pick_offer_weapon(used: Dictionary) -> String:
        # prefer owned kinds (the Brotato copy-buy), fall wide otherwise
        var owned := []
        for inst in meta.armory():
                if not used.has(inst[0]) and not owned.has(inst[0]):
                        owned.append(inst[0])
        if not owned.is_empty() and randf() < 0.6:
                return owned[randi() % owned.size()]
        for _try in 20:
                var wid: String = CSData.WEAPON_ORDER[randi() % CSData.WEAPON_ORDER.size()]
                if not used.has(wid):
                        return wid
        return CSData.WEAPON_ORDER[0]

func _stat_chips_row(box: VBoxContainer) -> void:
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 6)
        box.add_child(row)
        var chips := [
                ["DMG +%d%%" % int(round((float(stats["dmg_m"]) - 1.0) * 100)), CS_GREEN],
                ["SPD %d%%" % int(round(float(stats["spd_m"]) * 100)), CS_WHITE],
                ["ASPD %d%%" % int(round(float(stats["aspeed_m"]) * 100)), CS_WHITE],
                ["CRIT %d%%" % int(round(float(stats["crit"]) * 100)), CS_YELLOW],
                ["ARM %d" % int(stats["armor"]), CS_BLUE],
                ["LUCK %d%%" % int(round(float(stats.get("luck", 0.0)) * 100)), CS_GREEN],
                ["DODGE %d%%" % int(round(float(stats.get("dodge", 0.0)) * 100)), CS_BLUE],
        ]
        for c in chips:
                var l := _cs_label(String(c[0]), 11, c[1])
                l.add_theme_stylebox_override("normal", _cs_box_style())
                var pc := PanelContainer.new()
                pc.add_theme_stylebox_override("panel", _cs_box_style())
                pc.add_child(l)
                row.add_child(pc)

func _shop_card(title: String, title_col: Color, body_lines: Array,
                border: Color, btn_txt: String, btn_col: Color,
                cb: Callable, enabled := true) -> PanelContainer:
        var card := PanelContainer.new()
        var st := _cs_box_style(border, CS_BOX)
        st.corner_radius_top_left = 10
        st.corner_radius_top_right = 10
        st.corner_radius_bottom_left = 10
        st.corner_radius_bottom_right = 10
        card.add_theme_stylebox_override("panel", st)
        card.custom_minimum_size = Vector2(196, 0)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 2)
        card.add_child(vb)
        var nm := _cs_label(title, 13, title_col)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(nm)
        for ln in body_lines:
                var l2 := _cs_label(String(ln), 10, CS_WHITE)
                l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                vb.add_child(l2)
        var buy := _cs_button(btn_txt, 12, btn_col, cb)
        buy.disabled = not enabled
        vb.add_child(buy)
        return card

func _cards_row(box: VBoxContainer, cards: Array) -> void:
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 8)
        box.add_child(row)
        for c in cards:
                row.add_child(c)

func _section(box: VBoxContainer, txt: String) -> void:
        var l := _cs_label(txt, 12, CS_BLUE)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(l)

func _build_shop(box: VBoxContainer) -> void:
        # the header: the fat balance + the wave info
        var head := HBoxContainer.new()
        head.alignment = BoxContainer.ALIGNMENT_CENTER
        head.add_theme_constant_override("separation", 8)
        box.add_child(head)
        var ccbox := _cs_black_box(head, Vector2(150, 34))
        var hh := HBoxContainer.new()
        ccbox.add_child(hh)
        var ic := TextureRect.new()
        ic.texture = _t("coin")
        ic.custom_minimum_size = Vector2(22, 22)
        ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hh.add_child(ic)
        var bal := _cs_label(str(run_ccoins), 18, CS_YELLOW)
        hh.add_child(bal)
        var boss_next: bool = (run_wave % CSData.BOSS_CYCLE) == 0
        _cs_label("wave %d cleared - next: %sWAVE %d - LV %d" % [run_wave - 1,
                ("BOSS " if boss_next else ""), run_wave, run_level],
                12, CS_RED if boss_next else CS_WHITE, head)
        _stat_chips_row(box)
        # the scroll holds the shelves
        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.5)
        box.add_child(scroll)
        var shelf := VBoxContainer.new()
        shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        shelf.add_theme_constant_override("separation", 6)
        scroll.add_child(shelf)
        # ---- WEAPONS
        _section(shelf, "- WEAPONS (slots %d/%d) -" % [weapons_run.size(), meta.weapon_slots()])
        var wcards := []
        for o in shop_offers_w:
            var off: Dictionary = o
            if off["sold"]:
                    var soldc := _shop_card("SOLD", Color(0.5, 0.5, 0.55), ["come back next wave"],
                                    CS_EDGE, "-", CS_WHITE, func(): pass, false)
                    wcards.append(soldc)
                    continue
            var wid: String = off["wid"]
            var wd: Dictionary = CSData.WEAPONS[wid]
            var rar: String = off["rar"]
            var rarc: Color = CSData.RARITIES[rar]["col"]
            var lines := [
                    "T%d - %s" % [int(off["tier"]), String(CSData.RARITIES[rar]["name"])],
                    "%d dmg / %.2fs / rng %d" % [int(float(wd["dmg"]) * float(CSData.tier_mult(int(off["tier"]))["dmg"])),
                            float(wd["cad"]) * float(CSData.tier_mult(int(off["tier"]))["cad"]), int(float(wd["rng"]))],
                    String(CSData.RARITIES[rar]["blurb"]),
            ]
            var can := run_ccoins >= int(off["price"]) and weapons_run.size() < meta.weapon_slots() \
                            and int(off["tier"]) <= meta.tier_cap()
            wcards.append(_shop_card(String(wd["name"]), rarc, lines, rarc,
                            "BUY %d CC" % int(off["price"]), CS_YELLOW, func():
                            _shop_buy_weapon(off), can))
        _cards_row(shelf, wcards)
        # ---- ITEMS
        _section(shelf, "- ITEMS -")
        var icards := []
        for o2 in shop_offers_i:
            var off2: Dictionary = o2
            if off2["sold"]:
                    icards.append(_shop_card("SOLD", Color(0.5, 0.5, 0.55), ["gone"],
                                    CS_EDGE, "-", CS_WHITE, func(): pass, false))
                    continue
            var iid: String = off2["iid"]
            var it: Dictionary = CSData.ITEMS[iid]
            var rar2: String = off2["rar"]
            var rarc2: Color = CSData.RARITIES[rar2]["col"]
            var lines2 := [String(CSData.RARITIES[rar2]["name"]), String(it["desc"])]
            var can2 := run_ccoins >= int(off2["price"])
            icards.append(_shop_card(String(it["name"]), rarc2, lines2, rarc2,
                            "BUY %d CC" % int(off2["price"]), CS_YELLOW, func():
                            _shop_buy_item(off2), can2))
        _cards_row(shelf, icards)
        # ---- SUPPLIES
        _section(shelf, "- SUPPLIES -")
        var scards := []
        for cid in CSData.CONSUMABLES:
            var cd: Dictionary = CSData.CONSUMABLES[cid]
            var price := int(round(int(cd["price"]) * meta.shop_discount()))
            var can3 := run_ccoins >= price
            scards.append(_shop_card(String(cd["name"]), CS_WHITE,
                            [String(cd["desc"])], CS_EDGE, "BUY %d CC" % price, CS_YELLOW,
                            func(): _shop_buy_supply(cid, price), can3))
        _cards_row(shelf, scards)
        # ---- ALLIES (deploy / raise)
        if not (meta.d["owned_allies"] as Array).is_empty():
                _section(shelf, "- ALLIES (deploy + raise) -")
                var acards := []
                for aid in meta.d["owned_allies"]:
                    var aid_s: String = aid
                    var deployed := _allies_deployed(aid_s)
                    var at_cap := allies.size() >= _ally_cap() and deployed == 0
                    var price3 := int(round(CSData.ally_level_price(aid_s, deployed + 1) * meta.shop_discount()))
                    var lines3 := [String(CSData.ALLIES[aid_s]["desc"]),
                            "level %d -> %d" % [deployed, deployed + 1]]
                    var can4 := run_ccoins >= price3 and not at_cap
                    acards.append(_shop_card(String(CSData.ALLIES[aid_s]["name"]), CS_GREEN, lines3,
                                    CS_GREEN, "DEPLOY %d CC" % price3, CS_YELLOW, func():
                                    _shop_buy_ally(aid_s, price3), can4))
                _cards_row(shelf, acards)
        # ---- THE MERGE BENCH (the owner's law, always VISIBLE now; locked
        # shows the reason instead of hiding)
        _section(shelf, "- THE MERGE BENCH -")
        if meta.merging_learned():
                var mcards := []
                var pairs := _merge_pairs()
                if pairs.is_empty():
                        var none := _cs_label("no pairs on the bench (two same weapons, same tier)",
                                        11, CS_WHITE)
                        none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                        shelf.add_child(none)
                for pr in pairs.slice(0, 3):
                    var pr_d: Dictionary = pr
                    var cost := int(round(float(pr_d["cost"]) * meta.merge_discount()))
                    var tcap_ok := meta.tier_cap() >= int(pr_d["tier"]) + 1
                    var can5 := run_ccoins >= cost and tcap_ok
                    var why := "" if tcap_ok else " (LV %d gates T%d)" % [meta.char_level(), int(pr_d["tier"]) + 1]
                    mcards.append(_shop_card("MERGE: " + String(CSData.WEAPONS[pr_d["wid"]]["name"]),
                                    CS_YELLOW,
                                    ["T%d + T%d -> T%d" % [int(pr_d["tier"]), int(pr_d["tier"]), int(pr_d["tier"]) + 1],
                                     "two copies consumed" + why],
                                    CS_YELLOW, "MERGE %d CC" % cost, CS_YELLOW, func():
                                    _wave_buy_merge(pr_d, cost), can5))
                _cards_row(shelf, mcards)
        else:
                var locked := _cs_label("LOCKED - the WEAPON LAB (skill tree, LAB branch) teaches merging",
                                11, CS_RED)
                locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                shelf.add_child(locked)
        # ---- YOUR LOADOUT (with SELL)
        _section(shelf, "- YOUR LOADOUT (sell refunds 40%%) -")
        var lcards := []
        for wr in weapons_run:
            var wr_d: Dictionary = wr
            var wid2: String = wr_d["id"]
            var refund := int(CSData.sell_price(CSData.weapon_price(wid2, int(wr_d["tier"]))))
            var keep := weapons_run.size() > 1
            lcards.append(_shop_card("%s T%d" % [String(CSData.WEAPONS[wid2]["name"]), int(wr_d["tier"])],
                            CS_WHITE, ["equipped now"],
                            CS_EDGE, "SELL +%d CC" % refund, CS_RED, func():
                            _shop_sell_weapon(wr_d, refund), keep))
        _cards_row(shelf, lcards)
        # ---- the actions
        var actions := HBoxContainer.new()
        actions.alignment = BoxContainer.ALIGNMENT_CENTER
        actions.add_theme_constant_override("separation", 16)
        box.add_child(actions)
        var rc := 8 + shop_rerolls * 6
        actions.add_child(_cs_button("REROLL OFFERS - %d CC" % rc, 14, CS_BLUE, func():
                if run_ccoins >= rc:
                        run_ccoins -= rc
                        shop_rerolls += 1
                        _roll_shop_offers()
                        Jukebox.sfx("cs_draft", -6.0, 1.2)
                        _cs_reopen(func(): _shop_open())
                else:
                        Jukebox.sfx("cs_error", -6.0)
                        _toast_show("not enough coins")))
        actions.add_child(_cs_button("START WAVE %d >" % run_wave, 16, CS_GREEN, func():
                _after_draft_or_shop()))

func _shop_buy_weapon(off: Dictionary) -> void:
        var price := int(off["price"])
        if run_ccoins < price:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        if int(off["tier"]) > meta.tier_cap():
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("SPUDNIK level %d gates T%d" % [meta.char_level(), int(off["tier"])])
                return
        if weapons_run.size() >= meta.weapon_slots():
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("the holster is full (%d slots)" % meta.weapon_slots())
                return
        run_ccoins -= price
        meta.add_armory(String(off["wid"]), int(off["tier"]))
        weapons_run.append({"id": String(off["wid"]), "tier": int(off["tier"]), "cd": 0.0})
        off["sold"] = true
        Jukebox.sfx("cs_buy", -4.0)
        _rebuild_slots()
        _cs_reopen(func(): _shop_open())

func _shop_buy_item(off: Dictionary) -> void:
        var price := int(off["price"])
        if run_ccoins < price:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        run_ccoins -= price
        var it: Dictionary = CSData.ITEMS[String(off["iid"])]
        _apply_stat(String(it["stat"]), it["v"])
        off["sold"] = true
        Jukebox.sfx("cs_buy", -4.0)
        _cs_reopen(func(): _shop_open())

func _shop_buy_supply(cid: String, price: int) -> void:
        if run_ccoins < price:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        run_ccoins -= price
        match cid:
                "heal30": p_hp = minf(p_max_hp, p_hp + 30.0)
                "plate": stats["armor"] = int(stats["armor"]) + 1
                "crate":
                        for e in enemies.duplicate():
                                _hurt_enemy(e, 60.0)
                        _shockwave(p_pos, 900.0)
        Jukebox.sfx("cs_buy", -4.0)
        _cs_reopen(func(): _shop_open())

func _allies_deployed(aid: String) -> int:
        var n := 0
        for a in allies:
                if a["id"] == aid:
                        n += 1
        return n

func _shop_buy_ally(aid: String, price: int) -> void:
        if run_ccoins < price:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        var deployed := _allies_deployed(aid)
        if deployed == 0 and allies.size() >= _ally_cap():
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("the leash is full (%d allies)" % _ally_cap())
                return
        run_ccoins -= price
        if deployed == 0:
                _deploy_ally(aid, 1)
        else:
                for a in allies:
                        if a["id"] == aid:
                                a["level"] = int(a["level"]) + 1
                                break
        Jukebox.sfx("cs_buy", -4.0)
        _cs_reopen(func(): _shop_open())

func _wave_buy_merge(pr: Dictionary, cost: int) -> void:
        var wid: String = pr["wid"]
        var tier: int = int(pr["tier"])
        if meta.tier_cap() < tier + 1:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("SPUDNIK level %d gates T%d" % [meta.char_level(), tier + 1])
                return
        if run_ccoins < cost:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        if meta.count_armory(wid, tier) < 2:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("the bench needs two T%d copies" % tier)
                return
        meta.remove_armory(wid, tier)
        meta.remove_armory(wid, tier)
        run_ccoins -= cost
        meta.add_armory(wid, tier + 1)
        run_merges += 1
        for w in weapons_run:
                if w["id"] == wid and int(w["tier"]) == tier:
                        w["tier"] = tier + 1
                        break
        Jukebox.sfx("cs_levelup", -3.0)
        _banner("MERGED! %s T%d" % [CSData.WEAPONS[wid]["name"], tier + 1], false)
        _rebuild_slots()
        _cs_reopen(func(): _shop_open())

func _shop_sell_weapon(wr: Dictionary, refund: int) -> void:
        if weapons_run.size() <= 1:
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("SPUDNIK drops in armed - the last gun stays")
                return
        weapons_run.erase(wr)
        meta.remove_armory(String(wr["id"]), int(wr["tier"]))
        run_ccoins += refund
        Jukebox.sfx("cs_sell", -6.0)
        _rebuild_slots()
        _cs_reopen(func(): _shop_open())

func _merge_pairs() -> Array:
        # two same weapons, same tier -> the next tier at half price (the law)
        var out := []
        for wid in CSData.WEAPON_ORDER:
                for tier in [1, 2]:
                        if meta.count_armory(wid, tier) >= 2:
                                out.append({"wid": wid, "tier": tier,
                                        "cost": CSData.merge_price(wid, tier)})
        return out

# ============================================================== THE ARMORY
## the meta shop - "GOGASHOP" is DEAD (the owner's naming law). This is THE
## ARMORY: the 12 weapons one by one at high prices, the allies at the
## HIGHEST prices, the themes, SELL duplicates - all in cosmic coins.
var _armory_tab := "weapons"

func _armory_open() -> void:
        _cs_open("THE ARMORY", func(box: VBoxContainer): _build_armory(box), CS_YELLOW)

func _build_armory(box: VBoxContainer) -> void:
        # the wallet header
        var head := HBoxContainer.new()
        head.alignment = BoxContainer.ALIGNMENT_CENTER
        head.add_theme_constant_override("separation", 8)
        box.add_child(head)
        var ccbox := _cs_black_box(head, Vector2(160, 34))
        var hh := HBoxContainer.new()
        ccbox.add_child(hh)
        var ic := TextureRect.new()
        ic.texture = _t("coin")
        ic.custom_minimum_size = Vector2(22, 22)
        ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hh.add_child(ic)
        hh.add_child(_cs_label(str(meta.coins()), 18, CS_YELLOW))
        _cs_label("SPUDNIK LV %d - tier cap T%d" % [meta.char_level(), meta.tier_cap()],
                        12, CS_BLUE, head)
        # the tabs
        var tabs := HBoxContainer.new()
        tabs.alignment = BoxContainer.ALIGNMENT_CENTER
        tabs.add_theme_constant_override("separation", 6)
        box.add_child(tabs)
        for tab in ["weapons", "allies", "themes", "loadout"]:
                var t_s: String = tab
                var b := _cs_button(t_s.to_upper(), 12,
                                CS_YELLOW if _armory_tab == t_s else CS_WHITE, func():
                        _armory_tab = t_s
                        _cs_reopen(func(): _armory_open()))
                tabs.add_child(b)
        # the shelf scroll
        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.54)
        box.add_child(scroll)
        var shelf := VBoxContainer.new()
        shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        shelf.add_theme_constant_override("separation", 6)
        scroll.add_child(shelf)
        match _armory_tab:
                "weapons": _armory_weapons(shelf)
                "allies": _armory_allies(shelf)
                "themes": _armory_themes(shelf)
                "loadout": _armory_loadout(shelf)
        # the actions
        var actions := HBoxContainer.new()
        actions.alignment = BoxContainer.ALIGNMENT_CENTER
        actions.add_theme_constant_override("separation", 14)
        box.add_child(actions)
        actions.add_child(_cs_button("BACK", 14, CS_WHITE, func():
                _cs_close_top()
                if phase == "boot":
                        _optionals_open()))

func _armory_weapons(shelf: VBoxContainer) -> void:
        var note := _cs_label("every weapon starts T1 - own all 12, merge copies to climb tiers",
                        11, CS_WHITE)
        note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(note)
        var rows := []
        for wid in CSData.WEAPON_ORDER:
            var wid_s: String = wid
            var wd: Dictionary = CSData.WEAPONS[wid_s]
            var owned := meta.has_weapon(wid_s)
            var price := CSData.weapon_price(wid_s, 1)
            var lines := [
                    "%d dmg / %.2fs / rng %d" % [int(wd["dmg"]), float(wd["cad"]), int(wd["rng"])],
                    ("%d copies owned" % meta.weapon_count(wid_s)) if owned else "high price - the one-by-one law",
            ]
            var can := not owned and meta.coins() >= price
            rows.append(_shop_card(String(wd["name"]),
                            CS_GREEN if owned else CS_YELLOW, lines,
                            CS_GREEN if owned else CS_EDGE,
                            "OWNED" if owned else "BUY %d CC" % price,
                            CS_GREEN if owned else CS_YELLOW, func():
                            _armory_buy_weapon(wid_s, price), can))
        _cards_grid(shelf, rows, 3)

func _cards_grid(shelf: VBoxContainer, cards: Array, cols: int) -> void:
        var grid := GridContainer.new()
        grid.columns = cols
        grid.add_theme_constant_override("h_separation", 8)
        grid.add_theme_constant_override("v_separation", 8)
        grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        shelf.add_child(grid)
        for c in cards:
                grid.add_child(c)

func _armory_buy_weapon(wid: String, price: int) -> void:
        if meta.has_weapon(wid):
                return
        if not meta.spend(price):
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        meta.add_armory(wid, 1)
        Jukebox.sfx("cs_buy", -4.0)
        _cs_reopen(func(): _armory_open())

func _armory_allies(shelf: VBoxContainer) -> void:
        var note := _cs_label("allies cost the MOST on purpose - they deploy in the wave shop",
                        11, CS_WHITE)
        note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(note)
        var rows := []
        for aid in CSData.ALLY_ORDER:
            var aid_s: String = aid
            var ad: Dictionary = CSData.ALLIES[aid_s]
            var owned := meta.has_ally(aid_s)
            var price: int = int(ad["price"])
            var lines := [String(ad["desc"])]
            var can := not owned and meta.coins() >= price
            rows.append(_shop_card(String(ad["name"]), CS_GREEN if owned else CS_YELLOW,
                            lines, CS_GREEN if owned else CS_EDGE,
                            "OWNED" if owned else "BUY %d CC" % price,
                            CS_GREEN if owned else CS_YELLOW, func():
                            _armory_buy_ally(aid_s, price), can))
        _cards_grid(shelf, rows, 3)

func _armory_buy_ally(aid: String, price: int) -> void:
        if meta.has_ally(aid):
                return
        if not meta.spend(price):
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        meta.own_ally(aid)
        Jukebox.sfx("cs_buy", -4.0)
        _cs_reopen(func(): _armory_open())

func _armory_themes(shelf: VBoxContainer) -> void:
        var note := _cs_label("each theme wears a DAY and a NIGHT face - switch in the optionals",
                        11, CS_WHITE)
        note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(note)
        var rows := []
        for tid in CSData.THEME_ORDER:
            var tid_s: String = tid
            var th: Dictionary = CSData.THEMES[tid_s]
            var owned := meta.has_theme(tid_s)
            var price: int = int(th["price"])
            var on := theme_id == tid_s
            var lines := ["day + night variants"]
            if on:
                    lines.append("WORN NOW")
            var can := not owned and meta.coins() >= price
            rows.append(_shop_card(String(th["name"]), CS_YELLOW if on else (CS_GREEN if owned else CS_WHITE),
                            lines, CS_YELLOW if on else (CS_GREEN if owned else CS_EDGE),
                            "WORN" if on else ("OWNED" if owned else "BUY %d CC" % price),
                            CS_GREEN if on else CS_YELLOW, func():
                            _armory_buy_theme(tid_s, price), not on and can))
        _cards_grid(shelf, rows, 2)

func _armory_buy_theme(tid: String, price: int) -> void:
        if meta.has_theme(tid):
                _retheme(tid, night)
                _cs_reopen(func(): _armory_open())
                return
        if not meta.spend(price):
                Jukebox.sfx("cs_error", -6.0)
                _toast_show("not enough coins")
                return
        meta.own_theme(tid)
        _retheme(tid, night)
        Jukebox.sfx("cs_buy", -4.0)
        _cs_reopen(func(): _armory_open())

func _armory_loadout(shelf: VBoxContainer) -> void:
        var info := _cs_label("the guns SPUDNIK drops in with (tap to toggle) - %d/%d slots" \
                        % [meta.loadout().size(), meta.weapon_slots()], 11, CS_WHITE)
        info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(info)
        var rows := []
        for inst in meta.armory():
            var inst_d: Array = inst
            var wid: String = inst_d[0]
            var tier: int = int(inst_d[1])
            var lo := meta.loadout()
            var on: bool = lo.has(wid)
            rows.append(_shop_card("%s T%d" % [String(CSData.WEAPONS[wid]["name"]), tier],
                            CS_YELLOW if on else CS_WHITE,
                            ["equipped" if on else "benched"],
                            CS_GREEN if on else CS_EDGE,
                            "UNEQUIP" if on else "EQUIP",
                            CS_BLUE, func(): _armory_toggle(wid, tier)))
        _cards_grid(shelf, rows, 4)
        # the duplicate SELL bench (the 40% law, outside the run)
        var dup_note := _cs_label("SELL a duplicate copy (refunds 40% of its tier price)", 11, CS_WHITE)
        dup_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(dup_note)
        var srows := []
        for inst2 in meta.armory():
            var inst2_d: Array = inst2
            var wid2: String = inst2_d[0]
            var tier2: int = int(inst2_d[1])
            if meta.count_armory(wid2, tier2) < 2:
                    continue
            var refund := CSData.sell_price(CSData.weapon_price(wid2, tier2))
            srows.append(_shop_card("%s T%d x%d" % [String(CSData.WEAPONS[wid2]["name"]), tier2,
                            meta.count_armory(wid2, tier2)], CS_RED,
                            ["a duplicate copy"], CS_EDGE, "SELL +%d CC" % refund, CS_RED,
                            func(): _armory_sell(wid2, tier2, refund)))
        if srows.is_empty():
                var none := _cs_label("no duplicates on the shelf", 11, CS_WHITE)
                none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                shelf.add_child(none)
        else:
                _cards_grid(shelf, srows, 4)

func _armory_toggle(wid: String, _tier: int) -> void:
        var l2 := meta.loadout()
        if l2.has(wid):
                if l2.size() <= 1:
                        _toast_show("SPUDNIK drops in armed")
                        return
                l2.erase(wid)
        elif l2.size() < meta.weapon_slots():
                l2.append(wid)
        else:
                _toast_show("the holster is full (%d slots)" % meta.weapon_slots())
                return
        meta.set_loadout(l2)
        _rebuild_weapons()
        _cs_reopen(func(): _armory_open())

func _armory_sell(wid: String, tier: int, refund: int) -> void:
        if meta.count_armory(wid, tier) < 2:
                return
        meta.remove_armory(wid, tier)
        meta.earn(refund)
        Jukebox.sfx("cs_sell", -6.0)
        _cs_reopen(func(): _armory_open())

# ============================================================== OPTIONALS
## THE BOOT SCREEN, REBORN (the owner: the old one was FUCKING WEIRD):
## the 6 start cards wear the NEW potato art, the themes are two cards with
## real DAY/NIGHT chips, THE ARMORY + THE TREE + DROP IN.
func _optionals_open() -> void:
        _cs_open("COSMIC SPUD", func(box: VBoxContainer): _build_optionals(box),
                        CS_YELLOW)

func _build_optionals(box: VBoxContainer) -> void:
        var sub := _cs_label("pick one of the six starts - SPUDNIK wears every mask", 12, CS_WHITE)
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(sub)
        # the six start cards (2 rows x 3)
        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.5)
        box.add_child(scroll)
        var shelf := VBoxContainer.new()
        shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        shelf.add_theme_constant_override("separation", 8)
        scroll.add_child(shelf)
        var grid := GridContainer.new()
        grid.columns = 3
        grid.add_theme_constant_override("h_separation", 10)
        grid.add_theme_constant_override("v_separation", 10)
        grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        shelf.add_child(grid)
        for sid in CSData.START_ORDER:
                grid.add_child(_start_card(sid))
        # the themes: two cards with DAY / NIGHT chips
        var tsec := _cs_label("- THE GROUNDS -", 12, CS_BLUE)
        tsec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(tsec)
        var trow := HBoxContainer.new()
        trow.alignment = BoxContainer.ALIGNMENT_CENTER
        trow.add_theme_constant_override("separation", 10)
        shelf.add_child(trow)
        for tid in CSData.THEME_ORDER:
                trow.add_child(_theme_card(tid))
        # the wallet line
        var info := _cs_label("SPUDNIK level %d   -   %d cosmic coins   -   weapon tier cap T%d" \
                        % [meta.char_level(), meta.coins(), meta.tier_cap()], 12, CS_YELLOW)
        info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shelf.add_child(info)
        # the actions
        var actions := HBoxContainer.new()
        actions.alignment = BoxContainer.ALIGNMENT_CENTER
        actions.add_theme_constant_override("separation", 14)
        box.add_child(actions)
        actions.add_child(_cs_button("THE ARMORY", 15, CS_YELLOW, func(): _armory_open()))
        actions.add_child(_cs_button("SKILL TREE", 15, CS_BLUE, func(): _tree_open()))
        actions.add_child(_cs_button("DROP IN", 18, CS_GREEN, func(): _start_run()))

func _start_card(sid: String) -> Button:
        var s: Dictionary = CSData.STARTS[sid]
        var b := Button.new()
        b.custom_minimum_size = Vector2(230, 148)
        var picked: bool = sid == start_id
        var st := _cs_box_style(CS_YELLOW if picked else CS_EDGE, CS_BOX)
        st.corner_radius_top_left = 12
        st.corner_radius_top_right = 12
        st.corner_radius_bottom_left = 12
        st.corner_radius_bottom_right = 12
        b.add_theme_stylebox_override("normal", st)
        var hov := _cs_box_style(CS_GREEN if not picked else CS_YELLOW, CS_BOX2)
        b.add_theme_stylebox_override("hover", hov)
        var vb := VBoxContainer.new()
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.add_theme_constant_override("separation", 1)
        vb.offset_left = 8
        vb.offset_top = 6
        vb.offset_right = -8
        b.add_child(vb)
        var hrow := HBoxContainer.new()
        hrow.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(hrow)
        var art := TextureRect.new()
        art.texture = _t("hero_" + sid + "_f0")
        art.custom_minimum_size = Vector2(52, 52)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hrow.add_child(art)
        var nm := _cs_label(String(s["name"]), 14, s["tint"])
        nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hrow.add_child(nm)
        var st_txt := _cs_label("HP %d  DMG %d%%  SPD %d%%\nASPD %d%%  RNG %d%%  ARM %d  LUCK %d%%  DODGE %d%%" % [
                int(s["hp"]), int(s["dmg"] * 100), int(s["spd"] * 100),
                int(s["aspeed"] * 100), int(s["range"] * 100), int(s["armor"]),
                int(round(float(s.get("luck", 0.0)) * 100)), int(round(float(s.get("dodge", 0.0)) * 100))],
                10, CS_WHITE)
        st_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(st_txt)
        var pk := _cs_label(String(s["perk"]), 10, CS_GREEN)
        pk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        pk.custom_minimum_size = Vector2(214, 0)
        vb.add_child(pk)
        if picked:
                var tag := _cs_label("PICKED", 10, CS_YELLOW)
                tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                vb.add_child(tag)
        b.pressed.connect(func():
                start_id = sid
                meta.d["last_start"] = sid
                meta.save()
                Jukebox.sfx("cs_draft", -8.0)
                _cs_reopen(func(): _optionals_open()))
        return b

func _theme_card(tid: String) -> PanelContainer:
        var th: Dictionary = CSData.THEMES[tid]
        var owned := meta.has_theme(tid)
        var worn := theme_id == tid
        var card := PanelContainer.new()
        card.add_theme_stylebox_override("panel",
                        _cs_box_style(CS_YELLOW if worn else (CS_GREEN if owned else CS_EDGE), CS_BOX))
        card.custom_minimum_size = Vector2(300, 84)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 4)
        card.add_child(vb)
        var nm := _cs_label(String(th["name"]) + ("  - WORN" if worn else ""), 13,
                        CS_YELLOW if worn else CS_WHITE)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(nm)
        var chips := HBoxContainer.new()
        chips.alignment = BoxContainer.ALIGNMENT_CENTER
        chips.add_theme_constant_override("separation", 8)
        vb.add_child(chips)
        if owned:
                var day_b := _cs_button("DAY", 12, CS_WHITE if not (worn and not night) else CS_YELLOW,
                                func(): _retheme(tid, false); _cs_reopen(func(): _optionals_open()))
                var nite_b := _cs_button("NIGHT", 12, CS_WHITE if not (worn and night) else CS_YELLOW,
                                func(): _retheme(tid, true); _cs_reopen(func(): _optionals_open()))
                chips.add_child(day_b)
                chips.add_child(nite_b)
        else:
                var buy_b := _cs_button("BUY %d CC" % int(th["price"]), 12, CS_YELLOW,
                                func(): _armory_open(); _armory_tab = "themes")
                chips.add_child(buy_b)
        return card

func _start_run() -> void:
        _cs_close_all()
        _start_id_persist()
        run_wave = 1
        run_xp = 0
        run_level = 1
        run_ccoins = 0
        run_kills = 0
        run_merges = 0
        pending_levels = 0
        second_wind_used = false
        boss_alive = false
        goga_pending = false
        goga_carry = false
        goga_carrier_alive = false
        enemies.clear()
        bullets.clear()
        ebullets.clear()
        pickups.clear()
        allies.clear()
        zones.clear()
        stats = _base_stats()
        p_max_hp = _max_hp()
        p_hp = p_max_hp
        p_pos = ARENA.get_center()
        p_node.texture = _t("hero_" + start_id + "_f0")
        cam.position = _cam_clamp_pos(p_pos)
        _rebuild_weapons()
        if start_id == "engineer":
                _deploy_ally("drone", 1)
        _begin_wave(1)

func _start_id_persist() -> void:
        meta.d["last_start"] = start_id
        meta.save()

# =================================================================== tree
## THE TREE REBORN: four branch columns joined by drawn connectors, every
## node a black box speaking its state: OWNED (green), CAN BUY (yellow),
## LOCKED (a red padlock + the reason - the chain or the level gate).
func _tree_open() -> void:
        _cs_open("THE SKILL TREE", func(box: VBoxContainer): _build_tree(box), CS_BLUE)

func _build_tree(box: VBoxContainer) -> void:
        var sub := _cs_label("SPUDNIK LV %d  -  %d CC  -  everything starts locked, unlock one by one" \
                        % [meta.char_level(), meta.coins()], 12, CS_YELLOW)
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(sub)
        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.48)
        box.add_child(scroll)
        var shelf := VBoxContainer.new()
        shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(shelf)
        var branches := {"OFFENSE": [], "DEFENSE": [], "UTILITY": [], "LAB": []}
        for nid in CSData.TREE_ORDER:
                var n: Dictionary = CSData.TREE[nid]
                branches[n["branch"]].append(nid)
        var cols := HBoxContainer.new()
        cols.alignment = BoxContainer.ALIGNMENT_CENTER
        cols.add_theme_constant_override("separation", 10)
        shelf.add_child(cols)
        for bname in ["OFFENSE", "DEFENSE", "UTILITY", "LAB"]:
                var col := VBoxContainer.new()
                col.add_theme_constant_override("separation", 2)
                var bt := _cs_label(bname, 13, CS_YELLOW)
                bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                col.add_child(bt)
                var prev: Button = null
                for nid in branches[bname]:
                        var nb: Button = _tree_node(nid, prev)
                        col.add_child(nb)
                        prev = nb
                cols.add_child(col)
        var actions := HBoxContainer.new()
        actions.alignment = BoxContainer.ALIGNMENT_CENTER
        box.add_child(actions)
        actions.add_child(_cs_button("BACK", 14, CS_WHITE, func(): _cs_close_top()))

func _tree_lock_reason(nid: String) -> String:
        var n: Dictionary = CSData.TREE[nid]
        if n["need"] != "" and not meta.tree_has(String(n["need"])):
                return "needs " + String(CSData.TREE[String(n["need"])]["name"])
        if meta.char_level() < int(n["clv"]):
                return "needs SPUDNIK LV %d" % int(n["clv"])
        if meta.coins() < int(n["cost"]):
                return "needs %d CC" % int(n["cost"])
        return ""

func _tree_node(nid: String, prev: Button) -> Button:
        var n: Dictionary = CSData.TREE[nid]
        var owned := meta.tree_has(nid)
        var chain_ok: bool = String(n["need"]) == "" or meta.tree_has(String(n["need"]))
        var lv_ok: bool = meta.char_level() >= int(n["clv"])
        var can: bool = chain_ok and lv_ok and meta.coins() >= int(n["cost"])
        var b := Button.new()
        b.custom_minimum_size = Vector2(180, 68)
        var st := _cs_box_style(
                        CS_GREEN if owned else (CS_YELLOW if can else CS_EDGE), CS_BOX)
        b.add_theme_stylebox_override("normal", st)
        var hov := _cs_box_style(
                        CS_GREEN if owned else (CS_YELLOW if can else CS_RED), CS_BOX2)
        b.add_theme_stylebox_override("hover", hov)
        var vb := VBoxContainer.new()
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.offset_left = 5
        vb.offset_top = 4
        vb.offset_right = -5
        b.add_child(vb)
        var head := HBoxContainer.new()
        head.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(head)
        if owned:
                head.add_child(_cs_label("[OWNED]", 10, CS_GREEN))
        elif not (chain_ok and lv_ok):
                head.add_child(_cs_label("[LOCKED]", 10, CS_RED))
        head.add_child(_cs_label(String(n["name"]), 11,
                        CS_GREEN if owned else (CS_WHITE if chain_ok and lv_ok else Color(0.55, 0.55, 0.6))))
        var ds := _cs_label(String(n["desc"]), 9, CS_WHITE)
        ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(ds)
        var foot := HBoxContainer.new()
        foot.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(foot)
        if owned:
                foot.add_child(_cs_label("learned", 9, CS_GREEN))
        elif chain_ok and lv_ok:
                foot.add_child(_cs_label("%d CC" % int(n["cost"]), 10,
                                CS_YELLOW if can else CS_RED))
        else:
                foot.add_child(_cs_label(_tree_lock_reason(nid), 9, CS_RED))
        b.pressed.connect(func():
                if owned:
                        _toast_show("already learned")
                        return
                if not (chain_ok and lv_ok):
                        Jukebox.sfx("cs_error", -6.0)
                        _toast_show("LOCKED: " + _tree_lock_reason(nid))
                        return
                if meta.tree_buy(nid):
                        Jukebox.sfx("cs_levelup", -3.0)
                        _cs_reopen(func(): _tree_open())
                else:
                        Jukebox.sfx("cs_error", -6.0)
                        _toast_show("LOCKED: " + _tree_lock_reason(nid)))
        return b

# =================================================================== death
func _die() -> void:
        if over or phase == "dead":
                return
        phase = "dead"
        Jukebox.sfx("cs_death", -2.0)
        # THE BANK: in-run coins -> the cosmic wallet; XP -> the character level
        meta.earn(run_ccoins)
        var gained := meta.bank_char_xp(int(run_kills * 2 + run_wave * 8))
        meta.record_run(run_wave - 1, score, run_kills, run_merges, start_id)
        achievement_max("cs_kills", int(meta.d["kills"]))
        achievement_max("cs_wave", run_wave - 1)
        achievement_max("cs_score", score)
        if run_merges > 0:
                achievement_count("cs_merge", run_merges)
        achievement_count("cs_runs", 1)
        check_achievements()
        _finish_cs(gained)

func _finish_cs(gained_levels: int) -> void:
        var msg := "wave %d  -  %d kills  -  +%d CC banked" % [run_wave - 1, run_kills, run_ccoins]
        if gained_levels > 0:
                msg += "  -  SPUDNIK leveled up x%d!" % gained_levels
        _banner(msg, false)
        # the box death menu takes it from here (the /200 bonus rides coin_div;
        # the gogacoins ride add_run_coins -> the wallet)
        finish_run(score, run_coins)

# =================================================================== the banner
func _banner(txt: String, good := true) -> void:
        var root := _overlay_root_ref()
        var holder := Control.new()
        holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
        holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
        holder.offset_top = 170.0
        holder.offset_bottom = 252.0
        root.add_child(holder)
        var l := Label.new()
        l.text = txt
        l.add_theme_font_size_override("font_size", 26)
        l.add_theme_color_override("font_color", CS_YELLOW if good else CS_RED)
        l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
        l.add_theme_constant_override("shadow_offset_x", 2)
        l.add_theme_constant_override("shadow_offset_y", 2)
        l.set_anchors_preset(Control.PRESET_FULL_RECT)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        holder.add_child(l)
        l.pivot_offset = Vector2(l.size.x * 0.5, l.size.y * 0.5)
        l.scale = Vector2.ONE * 0.6
        var tw := l.create_tween()
        tw.tween_property(l, "scale", Vector2.ONE, 0.22) \
                        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.tween_interval(1.5)
        tw.tween_property(holder, "modulate:a", 0.0, 0.3)
        tw.tween_callback(holder.queue_free)

# ==================================================================== FX
class FxLayer extends Node2D:
        var game: Node
        func _draw() -> void:
                # the layer passes ITSELF: every draw_* call in _draw_fx must
                # land on the node whose _draw is running (the GDScript
                # receiver trap - self there is the GAME, not this layer)
                game._draw_fx(self)

var _floaters: Array = []    # {pos, txt, col, t, max, size}
var _rings: Array = []       # {pos, r, max, t, col, w}
var _parts: Array = []       # {pos, vel, t, max, col, size, tex}

func _draw_fx(L: CanvasItem) -> void:
        # the auras (under everything)
        for e in enemies:
                if e.get("dead", false):
                        continue
                if e.get("aura", 0.0) > 0.0:
                        var breathe := 0.5 + 0.14 * sin(Time.get_ticks_msec() / 260.0)
                        L.draw_circle(e["pos"], float(e["aura"]),
                                        Color(0.72, 0.42, 1.0, 0.10 * breathe))
                        L.draw_arc(e["pos"], float(e["aura"]), 0, TAU, 48,
                                        Color(0.75, 0.45, 1.0, 0.35), 2.0)
                if e.get("marked", false):
                        L.draw_arc(e["pos"], float(e["size"]) * 0.7, 0, TAU, 24,
                                        Color(1, 0.9, 0.3, 0.5), 2.0)
                # the HP bar under a damaged enemy
                if e["hp"] < e["max_hp"]:
                        var w: float = 34.0 * float(e.get("scale_m", 1.0))
                        var yy: float = e["pos"].y - float(e["size"]) * float(e.get("scale_m", 1.0)) - 10.0
                        L.draw_rect(Rect2(e["pos"].x - w * 0.5, yy, w, 4), Color(0, 0, 0, 0.55))
                        L.draw_rect(Rect2(e["pos"].x - w * 0.5, yy, w * clampf(float(e["hp"]) / float(e["max_hp"]), 0, 1), 4),
                                        CS_RED)
                # the tri-shield rings (the signature)
                if e.get("rings", null) != null:
                        _draw_rings(e, L)
                # the elite ring + tag
                if e.get("elite", false):
                        L.draw_arc(e["pos"], float(e["size"]) * 0.62 * float(e.get("scale_m", 1.0)),
                                        0, TAU, 32, Color(0.8, 0.4, 1.0, 0.8), 2.5)
                        L.draw_string(ThemeDB.fallback_font, e["pos"] + Vector2(-40, -float(e["size"]) - 18),
                                        String(e["affix"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 80, 9,
                                        Color(0.9, 0.6, 1.0))
                # THE CARRIER'S GLINT (the gogacoin rider marks its host)
                if e.get("goga", false):
                        var g := 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() / 200.0))
                        L.draw_arc(e["pos"], float(e["size"]) * 0.7 * (1.0 + 0.08 * g), 0, TAU, 24,
                                        Color(1.0, 0.85, 0.3, 0.5 + 0.3 * g), 2.0)
                # the charger telegraph
                if e.get("state", "") == "wind" and e.get("dash_dir", null) != null:
                        var dd: Vector2 = e["dash_dir"]
                        L.draw_line(e["pos"], e["pos"] + dd * 240.0, Color(1, 0.4, 0.3, 0.5), 3.0)
        # the zones (strike telegraphs / slams)
        for z in zones:
                var f := 1.0 - float(z["t"]) / float(z["max"])
                L.draw_arc(z["pos"], float(z["aoe"]) * (0.4 + 0.6 * f), 0, TAU, 40,
                                Color(1, 0.6, 0.2, 0.7), 3.0)
                L.draw_circle(z["pos"], float(z["aoe"]) * f, Color(1, 0.6, 0.2, 0.10))
        # the aim line (a subtle laser sight)
        if phase == "play":
                L.draw_line(p_pos + Vector2.from_angle(p_aim) * 30.0,
                                p_pos + Vector2.from_angle(p_aim) * (70.0 + 26.0 * sin(Time.get_ticks_msec() / 180.0)),
                                Color(1, 0.9, 0.4, 0.35), 2.0)
        # the gun (rotates with the aim, flips upright when aiming left)
        if p_node != null and is_instance_valid(p_node) and not weapons_run.is_empty():
                var wid: String = String(weapons_run[0]["id"])
                var gt: Texture2D = _t("gun_" + wid)
                var flip: bool = absf(fposmod(p_aim + PI, TAU) - PI) > PI * 0.5
                L.draw_set_transform(p_pos, p_aim, Vector2(1, -1 if flip else 1))
                L.draw_texture(gt, Vector2(12, -5) - Vector2(0, gt.get_height() * 0.5))
                L.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        # the particles + rings + floaters
        for p in _parts:
                var a := float(p["t"]) / float(p["max"])
                if p.get("tex", "") != "":
                        L.draw_texture(_t(String(p["tex"])), p["pos"] - Vector2(16, 16),
                                        Color(1, 1, 1, a))
                else:
                        L.draw_circle(p["pos"], float(p["size"]) * a, Color(p["col"], a))
        for r in _rings:
                var ra := float(r["t"]) / float(r["max"])
                L.draw_circle(r["pos"], float(r["r"]) * (1.0 - ra * 0.4),
                                Color(r["col"], 0.25 * ra))
                L.draw_arc(r["pos"], float(r["r"]) * (1.2 - ra * 0.8), 0, TAU, 40,
                                Color(r["col"], ra), float(r["w"]))
        for f2 in _floaters:
                var fa := float(f2["t"]) / float(f2["max"])
                L.draw_string(ThemeDB.fallback_font, f2["pos"], f2["txt"],
                                HORIZONTAL_ALIGNMENT_CENTER, -1, int(f2["size"]),
                                Color(f2["col"], fa))

func _draw_rings(e: Dictionary, L: CanvasItem) -> void:
        # each ring draws its REMAINING arcs (the carved windows stay open)
        for ring in e["rings"]:
                var cracks: Array = ring["cracks"]
                var arcs := []
                if cracks.is_empty():
                        arcs.append([0.0, TAU])
                else:
                        var sorted := cracks.duplicate()
                        sorted.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
                        var cursor := 0.0
                        for c in sorted:
                                var a0 := fposmod(float(c[0]), TAU)
                                var a1 := float(c[1])
                                if a0 >= cursor:
                                        arcs.append([cursor, a0])
                                cursor = maxf(cursor, a1)
                        if cursor < TAU:
                                arcs.append([cursor, TAU])
                var col := Color(0.35, 0.85, 1.0, 0.85)
                for arc in arcs:
                        var span: float = float(arc[1]) - float(arc[0])
                        if span <= 0.01:
                                continue
                        var segs := maxi(2, int(span / 0.12))
                        var prev := Vector2.ZERO
                        for i in segs + 1:
                                var a: float = float(arc[0]) + span * float(i) / float(segs)
                                var wp: Vector2 = e["pos"] + Vector2.from_angle(a + float(ring["rot"])) * float(ring["r"])
                                if i > 0:
                                        L.draw_line(prev, wp, col, 6.0)
                                prev = wp

# ------------------------------------------------------------ fx helpers
func _dmg_number(pos: Vector2, v: float, crit: bool, col := Color(1, 1, 1)) -> void:
        _floaters.append({"pos": pos + Vector2(randf_range(-10, 10), -18),
                "txt": ("%d!" % int(round(v))) + (" CRIT" if crit else ""),
                "col": CS_YELLOW if crit else col,
                "t": 0.7, "max": 0.7, "size": 18 if crit else 13})

func _shockwave(pos: Vector2, r: float) -> void:
        _rings.append({"pos": pos, "r": r, "t": 0.42, "max": 0.42,
                "col": Color(1, 0.7, 0.35), "w": 6.0})

func _death_burst(e: Dictionary) -> void:
        var n := 12 + (8 if e.get("boss", false) else 0)
        for i in n:
                var a := randf() * TAU
                var sp := randf_range(60.0, 260.0)
                _parts.append({"pos": e["pos"], "vel": Vector2.from_angle(a) * sp,
                        "t": 0.5, "max": 0.5, "col": Color(1, 0.55, 0.3),
                        "size": randf_range(3.0, 7.0), "tex": ""})
        _rings.append({"pos": e["pos"], "r": float(e["size"]), "t": 0.3,
                "max": 0.3, "col": Color(1, 0.6, 0.4), "w": 4.0})

func _heal_flash(e: Dictionary) -> void:
        _parts.append({"pos": e["pos"] + Vector2(randf_range(-14, 14), -10),
                "vel": Vector2(0, -60), "t": 0.4, "max": 0.4,
                "col": Color(0.5, 1, 0.6), "size": 5.0, "tex": ""})

func _tick_fx(delta: float) -> void:
        var dead := []
        for p in _parts:
                p["t"] -= delta
                if p["t"] <= 0.0:
                        dead.append(p)
                        continue
                p["pos"] += Vector2(p["vel"]) * delta
                p["vel"] = Vector2(p["vel"]) * 0.92
        for p2 in dead:
                _parts.erase(p2)
        var dead2 := []
        for r in _rings:
                r["t"] -= delta
                if r["t"] <= 0.0:
                        dead2.append(r)
        for r2 in dead2:
                _rings.erase(r2)
        var dead3 := []
        for f in _floaters:
                f["t"] -= delta
                f["pos"].y -= 40.0 * delta
                if f["t"] <= 0.0:
                        dead3.append(f)
        for f3 in dead3:
                _floaters.erase(f3)



