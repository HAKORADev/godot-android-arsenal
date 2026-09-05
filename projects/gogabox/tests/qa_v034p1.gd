extends Node
## qa_v034p1 - the PATCH-1 Xvfb shot driver. Rigs (QA_RIG env):
##   option  - the reborn optionals: the 6 start cards + theme DAY/NIGHT chips
##   shop    - THE SHOP (the store rebuild) at a wave break, merge bench ON
##   armory  - THE ARMORY (the gogashop name is dead)
##   tree    - the skill tree: locks with reasons + owned greens
##   draft   - the wave draft with its REROLL
##   arena   - the desert day run: the new creatures + the HUD widgets
##   night   - the desert night face mid-run
##   boss    - THE PRISM MATRIARCH + the boss bar
##   DISPLAY=:95 QA_RIG=shop godot --path . res://tests/qa_v034p1.tscn

var G: GogaGame

func _ready() -> void:
        process_mode = Node.PROCESS_MODE_ALWAYS
        Box.dev_set_cheat("all_owned", 1)
        var rig := OS.get_environment("QA_RIG")
        if rig.is_empty():
                rig = "arena"
        G = load("res://game/games/cosmic_spud/cosmic_spud.gd").new()
        G.game_id = "cosmic_spud"
        add_child(G)
        await get_tree().create_timer(1.2).timeout
        match rig:
                "option":
                        G.meta.d["tree"] = {"o1": true, "o2": true, "l1": true}
                        G.meta.d["coins"] = 860
                        G._cs_close_all()
                        G._optionals_open()
                        await _settle()
                "themes":
                        # v0.3.4-2: the armory THEMES tab - the GOGACoin wallet
                        # chip + the border note + GOGACOINS prices
                        G._cs_close_all()
                        G._armory_tab = "themes"
                        G._armory_open()
                        await _settle()
                "doorhint":
                        # v0.3.4-2: back on the door - the hint speaks, the door stays
                        G._cs_close_all()
                        G._optionals_open()
                        G._boot_hint = "the door is locked - pick a start, then DROP IN"
                        G._cs_reopen(G._optionals_open)
                        await _settle()
                "armory":
                        G._cs_close_all()
                        G.meta.d["coins"] = 1500
                        G._armory_tab = "weapons"
                        G._armory_open()
                        await _settle()
                "tree":
                        G._cs_close_all()
                        G.meta.d["tree"] = {"o1": true, "o2": true, "d1": true, "u1": true}
                        G.meta.d["coins"] = 640
                        G.meta.d["char_level"] = 4
                        G._tree_open()
                        await _settle()
                "shop":
                        G._cs_close_all()
                        G._start_run()
                        await _wait_frames(20)
                        G.phase = "break"
                        G.run_wave = 6
                        G.run_ccoins = 940
                        G.meta.d["tree"] = {"l3": true}          # the WEAPON LAB teaches merging
                        G.meta.d["armory"] = [["smg", 1], ["smg", 1], ["shotgun", 2]]
                        G.meta.d["owned_allies"] = ["drone"]
                        G._roll_shop_offers()
                        G._shop_open()
                        await _settle()
                "draft":
                        G._cs_close_all()
                        G._start_run()
                        await _wait_frames(10)
                        G.phase = "break"
                        G.run_wave = 4
                        G._wave_draft_open()
                        await _settle()
                "night":
                        G._cs_close_all()
                        G._retheme("desert", true)
                        G._start_run()
                        await _wait_frames(30)
                        G._spawn_enemy("wraith", G.p_pos + Vector2(300, -60))
                        G._spawn_enemy("blab", G.p_pos + Vector2(260, 80))
                        G._spawn_enemy("trishield", G.p_pos + Vector2(-320, 20))
                        G._spawn_enemy("mender", G.p_pos + Vector2(-180, -160))
                        G.goga_carrier_alive = true
                        await _wait_frames(30)
                "boss":
                        G._cs_close_all()
                        G._start_run()
                        await _wait_frames(20)
                        G.enemies.clear()
                        G._spawn_boss(20)
                        await _wait_frames(40)
                _:
                        G._cs_close_all()
                        G._start_run()
                        await _wait_frames(30)
                        G.run_kills = 37
                        G.run_ccoins = 128
                        G._spawn_enemy("sprinter", G.p_pos + Vector2(260, -80))
                        G._spawn_enemy("chunk", G.p_pos + Vector2(-300, 60))
                        G._spawn_enemy("wraith", G.p_pos + Vector2(150, -200))
                        G._spawn_enemy("brood", G.p_pos + Vector2(-220, -160))
                        G._spawn_enemy("boomling", G.p_pos + Vector2(340, 140))
                        G._spawn_enemy("spitter", G.p_pos + Vector2(-140, 260))
                        await _wait_frames(45)
        var shot := OS.get_environment("QA_SHOT")
        if shot.is_empty():
                shot = "/tmp/qa_v034p1_%s.png" % rig
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(shot)
        print("qa_v034p1 shot: ", shot)
        get_tree().quit(0)

func _settle() -> void:
        await _wait_frames(12)

func _wait_frames(n: int) -> void:
        for i in n:
                await get_tree().process_frame
