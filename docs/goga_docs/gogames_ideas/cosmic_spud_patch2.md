# COSMIC SPUD — v0.3.4 PATCH 2 (the owner's locked-out round)

The owner's patch-1 test ended AT THE DOOR: "i was not even able to pass
through the optionals menu". Every word is law. This doc is the tracker.

## THE REPORT (the defects)

1. The start cards' text is OUT-OF-BOX — make the box dynamically fit
   the text ("make a proper scale").
2. Tapping NIGHT on the worn theme: nothing happened.
3. The armory button — "i am not sure what the armory button do, i tapped
   that green button and nothing run".
4. The optionals has an X in the upper right — "why could someone close
   the important window?"
5. The second place (ABANDONED PARK) was buyable with GAME currency —
   the owner's first message "clearly listed exactly what to be bought
   using gogacoins": the universal shop's places.
6. The Android back button closed the optionals → ABSOLUTE FREEZE (no
   way to set the game). Back + the HUD back must work like every other
   game.
7. "since i spotted that text bug, it may exist in other areas."
8. Patch 2 = fast double-check that enemies/bosses/skill system/merging
   are real, then he tests for real.

## ROOT CAUSES FOUND (the audit)

- **THE SHEET LIFE LAW (defects 2, 3, 8 — THE KILLER)**: every CS sheet
  pauses the tree (`get_tree().paused = true`), and the sheet chain
  inherited PROCESS_MODE_INHERIT → PAUSABLE. A paused tree eats EVERY
  tap aimed at a pausable Control — the NIGHT chip, DROP IN, THE ARMORY,
  SKILL TREE, the X: ALL dead on device. Headless probes never saw it
  because they call the functions directly, and the Xvfb rigs only
  eyeball screenshots — nobody ever TAPPED. The box's own `sheet_push`
  has dressed its chain PROCESS_MODE_ALWAYS since v0.3.3-p2 (game_base
  124-134); the CS kit skipped the crown.
- **THE DOOR LAW (defects 4, 6)**: the optionals was a closable sheet
  with an X, and `_back_pressed` closed the top sheet blindly. Back
  closed THE DOOR → the game sat unpaused in a run that never began →
  the freeze, with no way back in.
- **THE TEXT-FIT LAW (defects 1, 7)**: `_start_card` (230x148),
  `_draft_card` (240x130), `_tree_node` (180x68) all GUESSED fixed sizes
  under autowrapped text. Long perks/reasons overflowed. The perk text
  alone could need more than 148px.
- **THE ECONOMY BORDER LAW (defect 5)**: patch 1 priced the park at 800
  cosmic coins. The owner's brief: the universal shop (GOGABox wallet)
  sells the places. matcher's skins already obeyed (Box.spend 220).
- **THE HUG LAW (found in QA)**: sheets sized their scrolls at a fixed
  viewport fraction — the themes tab showed a huge empty gray void under
  two cards.

## THE PATCH (the work)

- `_cs_open`: the sheet chain wears PROCESS_MODE_ALWAYS (the one-crown
  fix) + a `closable` argument — the door passes `false` and renders NO X.
- `_back_pressed`: during boot, back over the door SPEAKS (a red hint
  line inside the sheet: "the door is locked - pick a start, then DROP
  IN") and never closes it; an armory/tree sheet over the door closes
  normally; over a running game the old law stands (top sheet → close,
  else the box pause). Same behavior for the HUD "<" and Android back —
  both land in `_back_pressed`.
- THE CS FONT: the kit loads Kenney_Mini explicitly and every CS label
  and button wears it — the kit now MEASURES what it renders.
- `_cs_text_w` / `_cs_text_h` / `_cs_fit_label`: the measurement engine.
  `_start_card` sizes itself from the measured stats width + wrapped
  perk height (+ PICKED tag); `_draft_card` and `_tree_node` grow past
  their floors to their wrapped text; theme/shop titles shrink-to-fit.
- `_fit_scroll` (THE HUG LAW): the optionals/armory/shop/tree scrolls
  hug their shelf's measured minimum, capped at the viewport fraction.
- THE ECONOMY BORDER LAW: THEMES carry `gogacoins` (park 400, desert 0
  free-default). The optionals card + the armory themes tab say "BUY 400
  GOGACOINS" in full words; `_armory_buy_theme` pays `Box.spend` (the
  BOX wallet), records `Box.buy_item(game_id, "theme", ...)`; cosmic
  coins NEVER pay for a place. The armory themes tab wears a green
  GOGACoin wallet chip + the border note; the optionals wallet line
  names BOTH currencies.
- Scatter sweep: the dead double-condition in `_scatter_props` deleted.
- cs_probe 72 → 89 checks: THE DOOR LAW (no X; back on the door speaks;
  back over the door closes the top only), THE SHEET LIFE LAW (the
  DROP IN tap ANSWERS under the paused tree — the owner's freeze,
  replayed as a regression test), THE BORDER LAW (GOGACOINS wording,
  the box wallet drains, the cosmic wallet untouched, the buy reopens
  the door, NIGHT chips appear after owning), THE TEXT-FIT LAW (the
  cards grow to their measured text).
- qa_v034p1 rigs: + themes (the border tab) + doorhint (the speaking
  door); option/themes/tree/shop re-shot and eyeballed — boxes hug,
  nothing overflows.

## THE DOUBLE-CHECK (defect 8 — asked for explicitly)

- 16 creatures + 3 bosses spawn, move (node-sync law), and fight:
  qa rigs + probes still green.
- The skill system: 18 nodes, chains, LV gates, lock reasons,
  level drafts + wave drafts with rerolls — probe green.
- Merging: the merge bench (shop) + the WEAPON LAB tree node, half-price
  law — probe green.
- Luck/dodge/reroll: still in the stats table, luck bends the store
  rolls — probe green.
- The gogacoin rider (every 5th wave), kills widget, /200 bonus,
  invisible stick: patch-1 checks all still pass (89/89).
