# Changelog

All notable changes to the vertical slice. Newest first.

Updated on every push. If you push without adding an entry, the next person
has to read the diff to find out what moved.

---

## 2026-09-18 — hero placeholders in the dungeon scene, hidden during play

`dungeon.tscn` gets a `Heroes` group with three `hero.tscn` instances so the
party's dungeon positions can be laid out by dragging in the editor, the same
way `battle.tscn`'s slot Markers are hand-placed — but with no explore state
yet to show them in, they stay out of the way at runtime.

### Added
- **`Heroes` node2D + `Hero1`/`Hero2`/`Hero3`** — plain instances of
  `scenes/battle/hero.tscn` (the same blue-box placeholder used everywhere
  else pending real art), positioned roughly over the dungeon floor for
  dragging into their final spots by hand.

### Fixed
- **Placeholders showed through the prep menu.** `Heroes` was first given
  `z_index = 1`, copied straight from `battle.tscn` where nothing draws over
  it — but the prep menu is pushed as an overlay that deliberately leaves
  the dungeon visible underneath, so the elevated z_index drew the
  placeholders on top of the menu instead of behind it. Removed; the node
  now sits at the default z_index like the rest of the scene.
- **Belt-and-suspenders: hidden outright at runtime.** `dungeon.gd` sets
  `$Heroes.visible = false` in `_ready()` rather than relying on draw order
  alone — there is no dungeon "explore" state yet where the party should be
  seen standing here, so the group is an editor-only layout aid until one
  exists.

---

## 2026-09-16 — hero/enemy slots follow the background's actual ground line

### Fixed
- **Heroes and enemies floated in dungeon fights.** `battle.tscn`'s three hero
  Markers (and four enemy Markers) were hand-positioned against `bg_field.png`'s
  grass line back on 2026-09-01 and never touched since. `bg_dungeon.png` puts
  its floor about **95px lower** once both are scaled to the 1280×720 viewport
  under `KEEP_ASPECT_COVERED` (grass line y≈320 vs. dungeon floor y≈415,
  measured directly off the two images) — so a dungeon fight was drawing
  combatants standing on where the grass *would* be, which on the dungeon art
  is empty wall above the actual floor.
- **`battle.gd` gains `BACKGROUND_SLOT_OFFSET`** — a background path keyed to a
  flat Y shift, applied to every hero and enemy slot in `_apply_slot_offset()`
  right after the background itself is set. `bg_field.png` (encounters, and
  the standalone/demo case) is unlisted and gets `0.0`, so nothing changed
  there. A fresh scene instance every fight is what makes the shift safe to
  apply unconditionally — there's no authored position to accidentally drift
  from fight to fight.

---

## 2026-09-16 — the dungeon is a real sequence of fights

`dungeon.gd` goes from a bare backdrop to the actual M2 dungeon manager: four
single-enemy fights in a fixed order, the prep menu reopening between them,
and a real ending. "Combat inside it, and everything past START" — left open
on 2026-09-11 — is closed.

### Added
- **`dungeon.gd` sequences `ENEMY_SEQUENCE`** — mudling, frostbite_imp,
  emberhound, ashfang, in that fixed order. Not randomized: this is the
  vertical slice's one dungeon, and a fixed ramp is the simplest thing that
  reads as a difficulty curve. Each level pushes `battle.tscn` with exactly
  **one** enemy (`rating.build()`), against `bg_dungeon.png` — the same fight
  screen `map.gd` already uses for encounters, no dungeon-specific UI.
- **The prep menu reopens after every level clear**, as an overlay over the
  dungeon exactly like the very first one — but with `hide_back: true` in its
  payload, so BACK is gone and there is no way out but forward. Once level 1
  is cleared, the run is committed.
- **`prep_menu.gd` gains the `hide_back` payload key.** `true` hides
  `BackButton`, swaps `StartButton`'s text to **CONTINUE** (START only reads
  right for a run that hasn't begun yet), and makes `ui_cancel` a no-op rather
  than a back exit. `false`/absent — the very first prep screen — is
  unchanged.
- **`ui/menus/dungeon_victory.tscn` + `.gd`** — a new screen, shown once the
  boss falls: "DUNGEON CLEARED", total XP earned across all four fights, and
  a CONTINUE button. Pops itself with `{ "dungeon_cleared_ack": true }`;
  `dungeon.gd` relays one more pop to actually reach the map, the same
  two-pop shape BACK already used to leave from the first prep screen.
- **A wipe ejects immediately.** `dungeon.gd` reads `battle.tscn`'s existing
  `{ "party_won": false, "xp": ... }` pop result and pops itself straight back
  to the map — no victory screen, no further prep, matching
  `COMBAT_DATA.md`'s already-decided rule that a wipe costs every reward
  except XP. XP earned before the wipe is still reported on the way out.

### How the sequencing actually works
`Transitions.scene_resumed` reaches every listener on every pop in the game,
so `dungeon.gd`'s handler tells apart its three possible callers purely from
the shape of `result` — there was no field free to spend on an explicit tag:

| Caller | Result shape |
|---|---|
| `prep_menu` | `{ "prep_started": bool }` |
| `battle` | `{ "party_won": bool, "xp": int }` |
| `dungeon_victory` | `{ "dungeon_cleared_ack": true }` |

### Not done, on purpose
Revive-with-potion and the per-hero revive counter (`COMBAT_DATA.md`: three
per hero per dungeon) are still open — a wipe here is an immediate loss, not
a war of attrition against a shrinking party. `Inventory.md`'s note that
revive counters belong to "the M2 dungeon manager" is only half addressed:
the manager now exists, the counters don't yet.

---

## 2026-09-14 — the dungeon entrance gets its marker (#111)

The arch on the summit now has an icon over it, so the way into the dungeon
can be seen from across the map rather than found by walking into it. Closes
the art side of the entrance; the trigger underneath is unchanged.

### Added
- **`assets/sprites/markers/marker_dungeon.png`** — 32×48, an amber
  down-arrow over a stone-rimmed cave mouth, in the tileset's palette. First
  asset under a new `markers/` folder; `NAMING.md` gains the `marker_<place>`
  row for it.
- **`map.gd` bobs the marker** — `_start_marker_bob()`, a looping sine tween
  of 3px over 1.2s, started in `_ready()`. Bound to the map node, so it
  pauses with the map under a fight or the prep menu. Code motion, not
  frames, per the hover rule in `NAMING.md`.

### Changed
- **`map.tscn`** — the empty `Interactables/DungeonEntrance/Marker` sprite
  now carries the texture, sits at `(0, -56)` so it floats over the arch, and
  is a `%Marker` unique name. `DungeonEntrance` gets `z_index = 30`:
  `Interactables` is at 0, under every band, so anything drawn there was
  invisible behind the Layer1 ground. The `Prompt` child inherits the same
  lift for when it gets content.
- **`MAP.md`** — the entrance paragraph and the test log line say what the
  marker is and why the z_index is there.

### Verified
Headless, not by eye — a throwaway check scene run as the main scene (so the
autoloads `map.gd` needs were up; `--script` mode skips them) instantiated
`map.tscn`, read back `z_index = 30`, the texture path, and the rest position,
then sampled the marker's y at 0.35s (risen ~1.9px) and 1.25s (back within
0.05px of rest). Deleted afterward — not committed. The PNG itself was
eyeballed at 6× before filing.

### Not done, on purpose
`Prompt` is still empty and hidden — what the entrance says on approach, if
anything, is a separate ticket. The entrance is still a plain `Area2D`, not a
`Landmark`.

---

## 2026-09-11 — the dungeon entrance is wired, and the prep menu earns its slide

Walking into the dungeon arch now opens the whole loop: the dungeon goes on
the stack, the prep menu slides in over it, and either button slides it back
out — START straight onto the dungeon underneath, BACK on down to the map.
The dungeon itself is still a bare backdrop with nothing past START; Known
Inconsistencies' "no way to enter the dungeon" line is closed, "a finished
battle has nowhere to pop back to" is not touched by this.

### Added
- **`scenes/dungeon/dungeon.tscn` + `dungeon.gd`** — the dungeon target, still
  a placeholder: the supplied backdrop art, full screen, nothing else. Listens
  for its own `scene_resumed` and pops itself when prep_menu closes with
  `prep_started: false` (BACK), so BACK reaches the map in two pops without
  `map.gd` having to orchestrate the second one.
- **`assets/sprites/backgrounds/bg_dungeon.png`** — the first dungeon interior
  art, filed alongside `bg_field` / `bg_party`.
- **`Transitions.push()` / `pop()` gain `overlay`.** Skips the black fade and,
  on push, leaves the scene below visible but paused instead of hiding it —
  for a scene that wants to animate itself in over what's already on screen
  rather than fade through black. Nothing else in the project uses it yet, so
  no existing transition changed.
- **`Transitions.push()` gains `fade_time`**, a per-call override of the
  default 0.25s — the map's entry into the dungeon fades in 0.12s so the
  prep-menu slide that follows reads as one continuous entrance rather than
  two separate beats, without retuning every other transition in the game.
- **`prep_menu.tscn` slides.** `Frame` — background, pages, bar, both buttons,
  all of it — slides in from the right edge on open and back out on either
  button, tweened, independent of the black-fade system. `map.gd` pushes the
  dungeon first and the prep menu second as an overlay, so the dungeon is
  already sitting there the moment the slide starts.

### Changed
- **`prep_menu.tscn` restructured**: everything but `Scrim` moved under one
  `Frame` node, inset from the screen edge rather than covering it — the
  dungeon shows through at full brightness around it. Resizing `Frame` (by
  hand, in the editor) carries every child — background, pages, bar, both
  buttons — with it.
- **Party, Skills and Inventory now share one frame size (1180×670).** They
  briefly had different sizes — Party fit the original inset, Skills and
  Inventory needed more room and got it dynamically per tab — which read as a
  jump switching tabs. Settled on one static size; Skill and Inventory's
  internal layouts were tightened to actually fit inside it.
- **Skill menu sizes shrunk to fit embedded**: `SKILL_CARD` 120×104→112×100,
  `SPELL_GAP` / `SPELL_MARGIN` trimmed, `HERO_CARD` 286×116→250×116, skill
  grid separation 10→8. Verified with a headless harness that instantiates the
  real scene and measures the grid and spell tree against the panel's actual
  content area (post stylebox-margin) rather than by hand — the first pass
  had the spell tree 4px over on height.
- **Inventory menu sizes shrunk to fit embedded**: `CELL` 144×108→130×96, grid
  separation 8→6.
- **`ui/themes/main.tres` button/panel styles: `axis_stretch` TILE → STRETCH.**
  The shared `ui_panel.png` 9-patch was repeating across every button's width
  instead of stretching to fill it — each repeat redrew the texture's own
  border edge mid-button, which is what read as thin black vertical lines on
  buttons throughout the game, not just the prep menu. One project-wide fix;
  set to TILE deliberately back on 2026-08-31, which was the right call for a
  frame that matched its buttons' width then and stopped matching once button
  sizing moved on.

### Fixed
- **`inventory_menu.gd`'s `embed()` silently discarded the reserve it was
  passed** (`func embed(_bottom_reserve: int)`) — the item grid was never
  actually kept clear of a host's bottom bar, it just hadn't visibly collided
  with one before the frame shrank. Now applies it the same way the other two
  pages do.

### Verified
Headless, not by eye — a throwaway `SceneTree` script run via
`--headless --script` instantiated `prep_menu.tscn`, switched through all
three tabs, and measured the real laid-out sizes against each panel's content
area. Confirmed all three tabs land on frame size 1180×670 and the skill grid,
spell tree and item grid all fit their panels with margin to spare. Deleted
afterward — not committed.

### Not done, on purpose
The dungeon scene has no way out yet beyond the BACK relay in `dungeon.gd` —
no button, no script past that. Combat inside it, and everything past START,
is still open.

---

## 2026-09-10 — the menu set, and one screen that pages between them

Skills, inventory, and a prep screen that shows the party, skill and inventory
screens as three pages over the dungeon you are about to enter. **Nothing opens
any of them yet** — there is no dungeon scene and no menu key on the map. They
are built to be wired, and each one still runs on its own with F6.

### Added
- **`ui/menus/skill_menu.tscn` + `skill_menu.gd`** — SKILLS / SPELLS tabs down
  the left edge switching one pane. Skills are a 9×3 grid: gold is available,
  element-coloured is taken, ghosted is locked. Spells are twenty circles laid
  out serpentine with connector lines, and the lit run of them is exactly how
  far that hero has learned. Below both, the three equipped-spell slots and a
  hero row carrying each character's spare points, which is what every band
  above it redraws for.
- **`ui/menus/inventory_menu.tscn` + `inventory_menu.gd`** — a 6×5 grid of
  stacks over the four heroes and their stat bars, with INVENTORY / PARTY /
  SKILLS tabs along the bottom. Clicking a stack opens the panel of things you
  can do with it. Driven by `Inventory.items_changed` / `gold_changed`, so a
  fight or a shop changing the bag redraws it, not just this screen.
- **`ui/menus/prep_menu.tscn` + `prep_menu.gd`** — the last stop before a run.
  The three screens above are **instanced and embedded as pages**, not copied,
  so anything fixed in one is fixed here for free. Reads its backdrop from
  `Transitions.payload()["background"]`, so one prep screen serves every
  dungeon.
- **`embed(bottom_reserve)` on all three page screens.** Hides that screen's own
  backdrop, BACK button and tab row, lifts its bottom-anchored bands clear of
  the host's bar, and stops it answering `ui_cancel` — otherwise Escape closes
  the page rather than the screen the player is looking at. Opt-in: only the
  prep menu calls it, and all three still stand alone untouched.

### Changed
- **`party_menu` has a BACK button.** It previously emitted `closed` on Escape
  and never popped, relying on a listener nothing provides — so once the
  inventory screen's PARTY tab started pushing it, there was no way out. All
  four screens now share one shape: pop when pushed, emit `closed` when run
  standalone.
- **Skill menu proportions.** Hero cards 150→116, portraits 72→58, equip
  circles 56→48, spell-tree row gap 22→18. Its bottom bands were too tall to
  embed — the pane overflowed by ~50px behind the prep bar. Reads better
  standalone too.

### How START gets wired
`START` **pops** with `{ "prep_started": true }` rather than pushing the dungeon
itself. Pushing would leave prep sitting *under* the fight, so walking out of
the dungeon would drop the player back on a prep screen for a run they already
made. Popping puts the map back on top, and the map opens the dungeon — which
is also where the choice of *which* dungeon already lives. `BACK` pops the same
way with the flag `false`. `map.gd` needs `Transitions.scene_resumed` and three
lines; the shape is written out at the top of `prep_menu.gd`.

### Blocked, and saying so on screen
Rather than fake these, the buttons exist and report why they are dead:
- **Sell** is wired end to end but `SELL_PRICES` is deliberately empty.
  `COMBAT_DATA.md` lists both *Prices* and *Can you sell?* as TBD and says
  outright: "Don't wire a price until it's filled in." Filling that one
  dictionary turns the feature on with no other change.
- **Use** — `Character` has `max_hp()` and no current HP, so outside a fight
  there is nothing for a potion to restore. Same reason the party menu draws
  every HP bar full.
- **Equip** — `Character` has no equipment field and nothing in `stat()` that
  would read one. Needs an equipment seam in `core/`.
- **Skill prerequisites** are enforced UI-side, because `unlock_skill()` checks
  only "has a point" and "not already taken". The same gap `skill_tree.gd`
  already carries; a `can_unlock(skill_id)` seam would fix both screens at once.

### Not done, on purpose
The skill and item catalogues are `const` tables inside their UI scripts. They
belong in `data/` behind a resource class, next to heroes and enemies — there
is no item or skill resource class to author them into yet, and `COMBAT_DATA.md`
has no skill table at all. The item entries are transcribed from its ITEMS
table for **display only**; no number in either file is used to compute
anything, so `core/Combat.gd` stays the only place item math happens.

`ui/menus/skill_tree.tscn` is untouched and still there. The party, skill and
inventory screens are all intended to stay reachable on their own from the
overworld, so none of them were folded into the prep menu.

---

## 2026-09-07 — main menu screen, wired to the map

### Added
- **`ui/menus/main_menu.tscn` + `main_menu.gd`** — title screen with Play,
  Credits, and Options buttons plus a settings gear icon anchored to the
  bottom-right corner. Play calls
  `Transitions.replace("res://scenes/map/map.tscn")` — the exact use
  `Transitions.gd`'s own doc comment names for main menu → map.
- **`icon_settings.svg`** — hand-authored placeholder gear icon (8 teeth +
  a ring), matching the flat `#f2f2f2` style of the existing `icon_fight.svg`
  / `icon_guard.svg` set, since no gear art existed yet.
- **`bg_menu.png`** — the Castletot background art, filling the screen via a
  `TextureRect` with `STRETCH_KEEP_ASPECT_COVERED` so it crops rather than
  distorts at the project's 1280×720 viewport.
- **Hover pop on every button** (Play, Credits, Options, the settings gear).
  Scale tweens up ~8% with a back-out ease on `mouse_entered`, eases back to
  normal on `mouse_exited`. Centers each button's `pivot_offset` first, since
  a `Control` otherwise scales from its top-left corner and reads as a
  lopsided stretch instead of a pop.

### Changed
- **`main_scene` is `ui/menus/main_menu.tscn`.** The game now boots to the
  menu instead of straight to the map.
- **Title font size bumped to 80** (`theme_override_font_sizes` on the
  `RichTextLabel`) and repositioned top-left, so the game's name actually
  reads as a title against the background art instead of getting lost in it.

### Not done, on purpose
Credits and Options/Settings are wired to stub functions
(`_on_credits_pressed`, `_on_options_pressed`) that do nothing yet — no
credits system and no settings scene exist. The corner gear and the Options
button both call the same stub, on the assumption they'll open the same
settings screen once it's built; flagged rather than assumed silently.

---

## 2026-09-04 — the map and the battle are one loop

Walking the overworld rolls for a fight; the fight runs; finishing it puts the
player back on the map exactly where they left. **`MAP.md` carries the full
write-up** — the round trip, the reasoning, and what is deliberately unfinished.
This entry is the summary.

### Added
- **The encounter roll fires** (`map.gd`). 1–3 creatures from the Wisp / Critter
  / Brute pool, each an independent `build()`. Unchanged dials: 240 px walked
  between rolls, 25% each.
- **`Transitions.pop(result)` + `scene_resumed`** — the return leg
  `INTEGRATION_SEAMS.md` had listed as MISSING. Decided in favour of a signal
  over an M2 dungeon manager, so the map and the fight stay ignorant of each
  other. `result()` and `can_pop()` came with it.
- **Stack adoption.** A scene run on its own is in the tree but not on the
  stack; `push()` now adopts it as the bottom entry, so `pop()` can get back to
  it. This is what made the encounter safe to switch on.
- **Directional walk animations.** Eight `Idle_walk_*` sheets, 2×3 grids of 64px
  cells, replacing the eight single-frame stills. Idle is a *stopped* animation
  — frame 0 is the rest pose — so no separate idle animation exists.
- **Critter and Brute idle art**, 12 and 14 frames. Wiring these in was a rename
  to the `NAMING.md` convention; no code changed.

### Fixed
- **Combatants were invisible in a pushed fight.** A `Camera2D` sets the
  viewport's canvas transform and that transform *survives* its scene being
  hidden and paused, so the fight was drawn through the map camera at
  `(-976, -1768)`. `CanvasLayer` content has its own transform, which is why
  background and HUD looked perfectly normal while every combatant sat off
  screen. Fixed in `Transitions` — it is a property of the stack, not of
  `battle.tscn`, which needs no camera and did not get one.
- **Creatures without art could not be attacked.** `Placeholder` is a
  `ColorRect`, and GUI input resolves before physics picking, so the block ate
  the click before `ClickArea` saw it. `mouse_filter = IGNORE` on `Placeholder`
  in `hero.tscn` / `enemy.tscn` and on `HpBar` in `enemy.tscn`.

### Changed
- **Enemy HUD panels are built per fight**, one per enemy, instead of the two
  hardcoded MUDLING / WISP panels — an encounter rolls its own pack. Their
  action bars are live now rather than placeholder values.
- **`main_scene` is `scenes/map/map.tscn`.** The map is where the game starts.
- **Prop tiles carry collision** and `ui/themes/main.tres` retouched (map work
  that predates this loop, folded into the same commit).

### Not done, on purpose
`xp` is reported and dropped — `Character` has no experience pool. Losing costs
nothing, because `BattleState` rebuilds every hero at full HP each fight. Both
are open design decisions, flagged rather than invented. See `MAP.md`.

---

## 2026-09-02 — enemy HUD panel, combat UI sizing

### Added
- **Enemy HUD panel** (`ui/hud/enemy_panel.tscn`) reinstated for Mudling and
  Wisp — name, HP bar (red), and an action-count bar (purple/navy,
  placeholder values). This duplicates the HP info the in-world popups
  already show; kept anyway, at the user's explicit call over that tradeoff.
- **Panel hides on death.** `_refresh_enemies()` now sets that enemy's HUD
  panel `visible = false` the moment its `alive` flag flips, rather than
  leaving it up — the world sprite and hero panels still just dim on death,
  by design; only the enemy panel disappears outright.

### Changed
- **Hero panel bars recolored**: HP green, Action blue, Ult dark red.
- **Enemy HUD panel's HP bar synced to damage taken**, same as the existing
  over-head bar — was previously static.
- **Action menu buttons shrunk** (Fight/Items/Guard/Spell/Ultimate/End Turn:
  180×36 → 136×24, font size 16 → 14), and the `ActionMenu` box resized down
  repeatedly to hug them instead of leaving dead space around the grid.
- **Enemy over-head HP bar resized to match the HUD panel's** (90×15 on
  screen). `Enemy` scales its children ×1.75, so the node's local offsets
  were set to ~51×9 rather than 90×15 directly, to land on the same rendered
  size.

### Known tradeoff
Enemy HP now shows in two places — the HUD panel and the in-world popups.
This reverses part of the same-day HUD redesign that removed the panel for
exactly that redundancy; worth reconciling with that decision later rather
than assuming it was an oversight.

---

## 2026-09-01 — new battle background

### Changed
- **`bg_field.png` replaced** with the new overworld field — 1536×1024, a much
  deeper grass area than the previous art. `battle.tscn` repointed from
  `bg_battle_arena.png` to it.

### Nothing needed moving
Checked rather than assumed. The background is 3:2 against a 16:9 viewport, so
`KEEP_ASPECT_COVERED` scales by 0.833 and crops 67px off the top and bottom.
Detecting the grass line by scanning for the first mostly-green row put it at
**source y=464 → viewport y=320**, and all seven slots already clear it:

	Front   feet 545   Center  feet 609   Back1   feet 492
	Enemy1  feet 454   Enemy2  feet 550   Enemy3  feet 600   Enemy4  feet 635

Every one standing on grass, every head clear of the treeline. The HUD misses
them too: the action menu occupies x 880–1260 / y 533–708, and Enemy1 at
(928, 454) sits entirely above it.

`bg_battle_arena.png` is left in place — nothing references it now, but it is
somebody else's asset to remove.

---

## 2026-09-01 — hero combat sprites

### Added
New battle idles for **Ignis, Aria and Zeph** — 192×192, a **3×3 grid** of
64×64 cells with 8 frames used and the last slot blank.

### Changed
- **`SpriteSheet` now reads grids as well as single rows**, and works the
  layout out itself: columns and rows come from the texture dimensions, frame
  count from how many cells actually have pixels.
- **Fully transparent cells are skipped.** A square grid usually leaves
  trailing slots empty, and a blank frame in a loop reads as a stutter — so the
  9th cell here is dropped rather than played.
- Nothing is configured per file. Grid heroes and single-row enemies coexist,
  and a sheet re-exported with a different number of frames or rows just works.

Verified in-engine — heroes read the grid in the right order and the empty
slot at (128, 128) is absent, while the enemy strips are untouched:

	Zeph / Ignis / Aria   8 frames  (0,0) (64,0) (128,0) (0,64) … (64,128)
	Mudling / Wisp        8 frames  (0,0) (64,0) (128,0) … (448,0)

### Guard against a silent failure
A sheet of entirely blank cells would leave an animation with no frames, which
Godot draws as **nothing at all** — the sprite would vanish with no error. That
case falls back to slicing the whole grid instead.

### Docs
`NAMING.md`'s sheet section now covers grids, the free frame count, and skipped
empty cells.

---

## 2026-09-01 — guard is single use

### Changed
- **A guard is now spent by the first blow it soaks.** It still otherwise lasts
  until the guardian acts again, or until they fall.

This needed more than clearing the guard on a block. **The enemy plans its whole
turn up front**, and guard was being resolved during planning — so a 2-action
enemy resolved the same guard twice before either blow landed, and both hits
would have redirected.

Guard resolution therefore **moved out of `EnemyAI` and into `BattleState`**:

- `EnemyAI.plan_turn()` now returns who the enemy **intends** to hit —
  `{ target, damage, ignores_guard }` — and no longer takes a `guardians`
  argument.
- `BattleState._run_enemy_turn()` calls `Targeting.resolve_guard()` **per blow,
  as it lands**, and clears the guard when it redirects.

That's better separation regardless: `EnemyAI` picks targets, `BattleState`
applies rules.

Verified: Zeph guards Aria, two blows aimed at Aria. First redirects to Zeph
for 12 (20 × 0.6) and empties the guard board; the second lands on Aria for the
full 20.

### Fixed
- **A corrupted first line in `INTEGRATION_SEAMS.md`**, committed back in
  `ea4b462`. A `perl -0pi -e 's|…|…|'` whose replacement contained markdown
  table pipes terminated early and prepended a quick-reference row onto the
  document heading. The heading is restored and the row it was meant to update
  is now correct. Third time that delimiter mistake has bitten — table rows
  need `awk` or a line-addressed `sed`, not pipe-delimited perl.

---

## 2026-09-01 — markers moved onto the click box

### Fixed
Markers were floating **150px above the head**, disconnected from the thing the
player has to click. They now sit **on the click box**:

- the pick marker (dagger / shield) dead centre
- the persistent guard shield tucked into the top-right corner, so both can
  show at once on an already-guarded ally

Positions are **read from the `ClickArea` collision shape at build time**, not
hardcoded — resize the hitbox and the markers follow it instead of being left
behind. Also given `z_index = 10` so they draw over the sprite rather than
behind it.

Verified against the real shape: click box spans y −64..0, pick marker lands at
−32, shield at (17, −50) — both inside, on all three heroes.

---

## 2026-09-01 — target markers

### Changed
Selecting an action now puts a **marker over each valid target** instead of
tinting the whole side:

| Action | Marker | Lifetime |
|---|---|---|
| **FIGHT** / ULT | dagger on every living enemy | until one is chosen |
| **GUARD** | shield on every living ally | until one is chosen |
| **ITEM** | *nothing yet* | — |
| **SPELL** | *nothing yet* | — |

- **The guard shield then persists** on whoever was protected, tinted with the
  **guardian's element colour**, until the guard clears.
- Uses the existing `icon_fight.svg` and `icon_guard.svg`, which are white and
  so tint cleanly.

### Two details worth recording
- **Markers counter the character's scale.** Heroes render at 2.0 and enemies
  at 1.75, so a marker parented to one would inherit that and come out
  different sizes. They are scaled to a fixed 30 on-screen pixels regardless.
- **Persistent shields are read from `battle.guards`, not from events.** An
  event-driven shield can drift out of step with the fight — a guard cleared
  by the guardian's turn or death would leave a shield lying. Syncing from
  state means the display cannot disagree with the truth.

Verified in-engine: FIGHT marks both enemies and no allies, GUARD marks all
three allies and no enemies, ITEM and SPELL mark nothing, and guarding Aria
with Zeph leaves a shield on **Aria** tinted **Wind green** — the guardian's
element, not the guarded hero's.

### Open question
"Persist until the guard is consumed" — currently the guard clears on the
guardian's **next turn** or death, not on the first hit it blocks, so one guard
can soak several hits in a round. If it should be single-use, that is a
`BattleState` rule change, not a display one.

---

## 2026-09-01 — turn cue is an element shine

### Changed
- **Nobody steps forward any more.** The acting combatant's **name shines in
  their element colour** instead — a ping-pong pulse between overbright and
  tinted, so it reads as a shine rather than a flat recolour.
- For heroes it glows **both** labels: the one under the sprite and the one on
  their panel, so the two agree.

Why this is better than the step-forward: **formation is the player's decision
and it drives threat.** Front draws 50, Center 30, Back1 10. Sliding combatants
around to mark a turn was actively fighting the thing the layout exists to
communicate.

### Added
- **`Elements.COLOR` and `Elements.color_of()`** — the ten element colours,
  defined once. The turn glow reads from it, and spell VFX and icons should
  too, so nothing invents its own palette. Chosen to stay legible against the
  gold UI frame.

### Removed
`_step()`, `_reset_heroes()`, `_reset_enemies()`, `_slide()`, the three `STEP_*`
constants, and the `slot_home` / `enemy_home` arrays that existed only to
support stepping. All of it went; no dead code left behind.

Verified: each hero's glow uses their own element colour (Zeph green/Wind,
Ignis orange/Fire, Aria blue/Water), two labels pulsing for the acting hero,
and **nobody moved** across a full glow cycle.

### Docs
`INTEGRATION_SEAMS.md` gains `Elements.color_of()` and a quick-reference row.
`COMBAT_DATA.md` records that element colours live in `Elements.COLOR`.

---

## 2026-09-01 — HUD: information where it happens

The screen carried six boxes and the player had to look away from the fight to
read any of it. Now there are **two**, and everything else appears on the thing
it happened to, then leaves.

### Removed
- **The message log.** Every line it printed now floats over the combatant
  involved.
- **The enemy panel** (top-right). Never wired, and redundant with the HP bars
  already floating above each enemy sprite.
- **`TurnIndicator`** — an empty node no script ever referenced. The
  step-forward has been the turn cue since it was built.

### Added
- **`_popup()`** — floating text over any combatant, staggered vertically so a
  damage number and its tag don't land on top of each other.

| Text | Where | When |
|---|---|---|
| `19` | on the target | every hit |
| `SUPER EFFECTIVE` | above the number | matchup > 1.0 |
| `GUARD` | on the guarding hero | guard declared |
| `GUARDED` | on the guardian | a hit is actually redirected |
| `DOWN` | on the combatant | it dies |

- **`BattleState.guard_blocked(guardian, guarded, damage)`** — a new signal.
  `action_taken` reports only who *finally took* the blow, so the UI could not
  distinguish a guard from a normal hit. Additive; the existing signature is
  unchanged.
- **Target highlighting replaces the prompt text.** Selecting an action pulses
  whichever side is clickable — allies for Guard, enemies for everything else.

### Subtle bit
`_highlight_targets()` and `_hit_feedback()` both write `modulate` on the same
node, and the flash tween ends on `WHITE`. A highlight left standing when a hit
landed would be silently wiped and never restored, so the pulse is cleared
before `act()` rather than after.

Verified in-engine: HUD down to 3 children (one an invisible container), and
all five popup types firing with the right text and colour.

---

## 2026-09-01 — sprite afterimage

### Fixed
- **Animated sprites left a ghost of the next frame behind them.**
  `AtlasTexture.filter_clip` defaults to `false` and `SpriteSheet.strip()`
  never set it. The strips have **no padding between frames**, so sampling at a
  region edge pulled pixels from the neighbouring frame — frame N's right edge
  reading frame N+1's left edge. That sliver is what read as an afterimage.

  Worse on enemies (`scale 1.75`) than heroes (`scale 2.0`): a non-integer
  scale lands sampling between texel centres, where an integer scale mostly
  does not.

  Not an art problem — the sheets are correct, the slicing was.

### Note for future strips
Zero padding between frames is fine **as long as `filter_clip` is on**. If a
sheet ever arrives with padding, the region maths in `strip()` needs the gap
added; it currently assumes cells butt up against each other.

---

## 2026-08-31 — UI frame

### Added
- **`assets/ui/ui_panel.png`** — the 32×32 beveled gold frame, 9-sliced at
  **6, 6, 6, 6**. One file now frames every `PanelContainer`, `Panel` and
  `Button` in the game: hero panels, enemy panel, message log, action menu.
- **`tools/gen_frame.gd`** — the frame arrived as a Piskel browser-console
  script rather than a PNG, so it is ported to GDScript and the image is
  generated from the project. Re-emit with
  `godot --headless --path . --script tools/gen_frame.gd`. The source of truth
  is a file in the repo instead of a snippet in a browser tab.

### Changed
- `ui/themes/main.tres` gains five `StyleBoxTexture`s — one panel, four button
  states. **Edges TILE rather than stretch**: with `Nearest` filtering a
  stretched edge at a non-integer factor produces uneven pixel runs (some 2px,
  some 3px), which reads as wrong even though nothing is blurred.
- **Button states are the same texture re-tinted** — hover brighter, pressed
  darker, disabled dimmed and faded. So `ui_btn_*.png` is now only worth
  drawing if the states should differ in *shape*, not just brightness.

Verified in-engine: a 32×32 source framing a 210×102 panel, margins 6/6/6/6,
both axes TILE, and all four button states resolving with distinct tints.

### Docs
`NAMING.md` gains a 9-slice section with the three rules a frame must satisfy
(corners inside the margin boxes, edges uniform along their stretch axis, flat
centre) and the note about button art. `STRUCTURE.md` gains `tools/`.

---

## 2026-08-28 — damage flash and shake

### Added
- **Hit flash.** The struck combatant overbrights on impact and fades back over
  0.16s. Values above 1.0 blow out rather than merely lighten, which reads as
  impact instead of a colour change.
- **Hit shake.** Three-step displacement, 7px out, 4px back, settle — 0.15s
  total.
- **Super-effective hits flash red-white** instead of white, and the log
  appends `SUPER EFFECTIVE`. The multiplier is read from `Elements.matchup()`
  rather than re-derived, so the tell can never disagree with the damage.
  Nothing else in the game teaches the type chart.

### The thing that made this non-trivial
Both effects act on the **Sprite child**, never on the node or slot that does
the step-forward. Heroes step by moving their *slot* and enemies by moving
*themselves* — so shaking the node would have been safe for heroes and would
have fought the turn cue for enemies. Two tweens on one position property means
the loser's target is where the character stays parked.

Each effect also kills its own previous tween, and the shake resets `x` to 0
before starting, since an interrupted shake can leave the sprite mid-swing.

Verified in-engine, including that the step-forward still lands on its home x
after a shake:

	rest        modulate (1,1,1)        x 0.0
	on hit      modulate (3.0,1.1,1.1)  <- super-effective tint
	mid-shake   x 1.0                   <- displaced
	settled     modulate (1,1,1)        x 0.0
	enemy node  x 890.0 = home 890.0    <- step unaffected

That tint fired because Zeph is Wind and Mudling is Earth — the chart driving
the visual, unprompted.

---

## 2026-08-28 — the ultimate is usable

### Added
- **`Actions.TYPE.ULT`** — a fifth action type, cost 1 like the rest.
- **`Combat.ultimate()`** — the placeholder effect: `ATT × 2.5` through the
  normal damage path, so DEF and the element matchup still apply and no new
  rules enter the game. `COMBAT_DATA.md` asked for a "placeholder ult" and
  never said what it does; this is the simplest thing that reads as heavy.
- **An ULTIMATE button** in the shared action menu. Disabled until charged, and
  labelled with the current percentage while it fills — `ULTIMATE (64%)` — so
  the gate is visible rather than a dead button.

### Fixed
- **The ultimate recharged itself.** `act()` charges the meter from damage
  dealt, and the ult deals ~70, so firing it immediately refunded 35% of the
  bar it had just spent. `ULT` is now excluded from ult gain. Caught by
  probing the meter after firing, not by reading the code.

### Design decisions
- **The ult costs an action as well as the meter.** A free ult would mean
  ulting *and* attacking on the same turn.
- **`spend_ult()` is the gate and the spend in one call** — it returns `false`
  and changes nothing unless the meter is full, so `BattleState` fires and
  checks in one step, refunding the action on failure. A mis-click costs
  nothing.

Verified in-engine:

	empty meter   -> act() returns false, 3 actions still unspent
	charged       -> button enabled, reads "ULTIMATE"
	fired         -> 70 damage where a normal hit did 19; meter 100 -> 0
	normal hit    -> meter charges again

### Docs updated
`COMBAT_DATA.md` (ult rules + placeholder warning), `INTEGRATION_SEAMS.md`
(`ULT` in `Actions.TYPE`, `Combat.ultimate()`, quick reference), `NAMING.md`
(`ui_btn_ult.png`).

---

## 2026-08-28 — ultimate meter

### Added
- **`Character.ult_meter`** plus `is_ult_ready()`, `spend_ult()` and
  `gain_ult()` — built to the signatures locked in `INTEGRATION_SEAMS.md`,
  which have been ⏳ since the project started. `gain_ult()` calls
  `Combat.ult_gain()` and owns only the clamp; the doc is explicit that
  `Combat` owns the rates and they must not be reimplemented.
- **The ult bar is live** in all three hero panels, and glows gold at 100.

### Changed
- **The hero combatant dictionary now carries `source`**, the `Character` it was
  built from. Ult charge has to persist across fights, and the combatant dict
  dies with the battle scene — so the meter is written back to the Character
  rather than held in the fight.
- `BattleState` charges the meter from both directions: the actor gains on
  damage **dealt** in `act()`, the target gains on damage **taken** in
  `_apply_damage()`.

Verified both directions in-engine rather than by inspection:

	Zeph deals 19  -> ult 9    (19 / 2)
	Aria takes 40  -> ult 10   (40 / 4)

Ignis and Aria correctly stayed at 0 while Zeph acted.

### Confirmed working
- **Enemy HP bars render.** `visible=true`, 80×14, on screen above each sprite,
  tracking real HP.

---

## 2026-08-28 — bars drain

### Changed
- **HP and action bars slide to their new value** over 0.25s instead of
  snapping. A 40-damage hit that teleports the bar reads as a glitch; the same
  hit draining reads as a hit. Eased out, so it moves fast then settles.
- Every bar now goes through `_set_bar()`, which **kills any tween already
  running on that bar** first. Two hits landing inside the drain window would
  otherwise leave two tweens fighting over one property, and the bar would
  settle on whichever finished last rather than on the real HP.
- The initial fill passes `animate = false` — bars should start correct, not
  animate up from zero.

Verified by timing an actual hit: full at 70, still 70 the instant the blow
lands, 56.4 mid-drain, settling exactly on the real HP of 51.

### Still not wired
- **The Ult bar.** The node exists in all three hero panels and is never
  updated, because `Character` has no `ult_meter` field — `ult_meter`,
  `is_ult_ready()`, `spend_ult()` and `gain_ult()` are all agreed in
  `INTEGRATION_SEAMS.md` and none are built. `Combat.ult_gain()` computes the
  number; nothing stores it.
- **The enemy panel's HP bar** (top-right). It has no target-tracking to drive
  it — the per-enemy bars above each sprite are the live ones.

---

## 2026-08-28 — UI font

### Added
- **`assets/fonts/alagard.ttf`** — the UI typeface. Every label, button, bar
  and log in the game was Godot's default anti-aliased sans-serif until now,
  which read as placeholder UI against 64×64 pixel art.
- **`ui/themes/main.tres`** — a project-wide theme, registered as
  `gui/theme/custom`. One resource styles every `Label`, `Button`,
  `ProgressBar` and `RichTextLabel` in the game, so nothing sets a font per
  node. It is also the natural home for button styling when
  `ui_btn_*.png` arrives.

### Import settings that matter
Godot defaults **antialiasing on, hinting on, subpixel positioning auto** —
all three blur a pixel font exactly the way linear filtering blurred the
sprites. Set to `0 / 0 / 0`. Used at **16px**; pixel fonts stay crisp only at
their native size or exact integer multiples.

Verified in-engine: labels and buttons both report `Alagard` at 16.

### Fixed
- **`.theme` is Godot's *binary* extension.** A hand-written text resource has
  to be `.tres`, or the project fails to load it —
  `Unrecognized binary resource file`. `STRUCTURE.md` describes
  `ui/themes/` as holding ".theme resources", which is what led me wrong.

### Closed
- ~~No font specified anywhere~~ — `NAMING.md` now has a Fonts section.
  `assets/fonts/` is no longer empty.

---

## 2026-08-27 — doc sync

Docs brought back in step with the code after the art pass. Four drifts, all
introduced by this session's own work.

### Fixed
- **`COMBAT_DATA.md` contradicted `data/heroes/*.tres`.** The positions table
  still showed Craig at Front and Ignis benched; the data holds the inverse
  since the hero-art swap. The table now matches the data and carries a warning
  that the swap is temporary, why it was made, and exactly what to revert.
- **`NAMING.md` had no sprite-sheet convention at all** — it specs individual
  frame files and says nothing about strips, so the rule that actually drives
  art loading lived only in commit messages. Now a section of its own: single
  row, square cells, no padding, free frame count, and the filename-is-the-
  wiring lookup.
- **`bg_field.png` was missing from `NAMING.md`.** Backgrounds listed only
  `bg_dungeon.png`; the field is where overworld encounters happen and is now
  its own slot.
- **`SpriteSheet.gd` was in neither `STRUCTURE.md` nor `INTEGRATION_SEAMS.md`**
  — the only `core/` file with no entry anywhere. Both now cover it, including
  the quick-reference table. `hero.tscn` and `damage_number.tscn` added to the
  scenes listing.

All thirteen `core/` files now appear in both docs — verified by script, not
by eye.

### Also logged
- **`scenes/Main Menu.tscn` resurrected a third time** and was briefly pushed
  in `54ec13a` before removal in `2b42d47`. **Cause found:** a Godot editor
  session left open since before the `docs/spec-reconciliation` merge still
  listed the pre-move path in `.godot/editor/editor_layout.cfg`, and rewrote
  the file with a fresh uid whenever it synced. Closing the editor was not
  enough — the stale `open_scenes` entry had to be cleared, or a restart would
  restore the tab and recreate the file. Fixed at the source.

---

## 2026-08-27 — hero art

### Added
Three 1024×64 strips, 16 frames at 12fps, assigned by their elemental tell:

| Character | Tell |
|---|---|
| **Ignis** | cradling a glowing orange ember — Fire |
| **Aria** | pale blue flames rising — Water |
| **Zeph** | white-blue vortex rings spinning around the body — Wind |

Every combatant in the default fight now has real art. No placeholders on
screen.

### Changed
- **Ignis swapped into the lineup for Craig.** `ignis.tres` position 3 → 0
  (Front), `craig.tres` 0 → 3 (bench). Craig has no art yet, and the point was
  to see the animations.

> ⚠️ **This is a balance change, not just a visual one.** Front draws **50
> threat**, the highest in the game, and Ignis is the glass cannon — 100 HP and
> 16 DEF against Craig's 120/32. He will take the most hits while being the
> least able to survive them. Fine for looking at the art; move him to Back1
> before any balance judgement is made from a playtest.

### Still placeholder
- **Craig** (benched), plus **Critter** and **Brute**.

---

## 2026-08-27 — Mudling art

### Added
- **`enemy_mudling_bidle.png`** — 512×64, 8 frames. Dropped in with **no code
  or scene change**, which is the naming convention paying off. 8- and
  16-frame sheets coexist because `strip_auto()` reads the count from texture
  width.

All four dungeon enemies now animate:

	Mudling           8 frames      Ashfang    16 frames
	Frostbite Imp    16 frames      Wisp        8 frames
	Emberhound       16 frames

### Still placeholder
- **Critter** and **Brute** — the two remaining encounter enemies.
- All four heroes.

---

## 2026-08-27 — battle background

### Added
- **`assets/sprites/backgrounds/bg_field.png`** — 1774×887 outdoor field.
  Filed as the *field* background, not `bg_dungeon`: it is grass and treeline,
  and the game has overworld encounters as well as dungeon fights. `NAMING.md`
  lists only `bg_dungeon.png`, so this is a new slot.

### Changed
- **The background is payload-driven.** `Transitions.push(..., {"background":
  path})` sets it; the field is the default. A dungeon fight passes its own,
  so nothing is hardcoded to one location. A missing path leaves the flat fill
  rather than erroring.
- Background moved into a `CanvasLayer` at `layer = -1` holding a `TextureRect`
  with `KEEP_ASPECT_COVERED`. The art is 2:1 and the viewport is 16:9 — stretch
  would squash the trees, so it covers and crops instead, and works at any
  resolution the team eventually picks.
- **Combatants repositioned onto the grass.** Slots were laid out against a
  flat fill; against real art the back hero and both enemies stood in the
  treeline, floating above the ground. The grass line lands near y=438 once
  cover-scaled, so everyone now sits below it.

---

## 2026-08-27 — dungeon enemy art

### Added
Three 1024×64 strips, 16 frames at 12fps (1.333s loop), mapped to the dungeon
roster by appearance:

| Sheet | Becomes | Why |
|---|---|---|
| `ice_beast_idle` | `enemy_frostbite_imp_bidle.png` | the only Ice enemy |
| `fire_beast_idle` | `enemy_emberhound_bidle.png` | Fire, and a hound is a quadruped |
| `red_knight_idle` | `boss_ashfang_bidle.png` | crimson and armoured — reads as the boss |

All three verified playing in-engine at 16 frames.

### Changed
- **`SpriteSheet.find_idle()` now tries several prefixes**, `enemy_` then
  `boss_`. `NAMING.md` files bosses under `boss_`, but the fight doesn't know
  which kind of creature it is holding — it just has a name. Added `slugify()`
  so a display name like `"BOSS: Ashfang"` still resolves to `ashfang`.

### Still placeholder
- **Mudling** — the only dungeon enemy without art. Earth, the weak warmup.
- All four heroes.

---

## 2026-08-27 — first art

### Added
- **`core/SpriteSheet.gd`** — slices a horizontal strip into `SpriteFrames` at
  runtime. `find_idle()` locates a creature's art **by name**, so dropping
  `assets/sprites/characters/enemy_mudling_bidle.png` into the project is all
  it takes to animate Mudling. No scene editing, no code change, no hand-built
  AtlasTextures. `strip_auto()` infers the frame count from the texture width,
  so a strip can be re-exported with more frames without touching anything.
- **First real art: `enemy_wisp_bidle.png`** — 512×64, 8 frames at 12fps,
  looping. Verified playing in-engine.

### Changed
- **`textures/canvas_textures/default_texture_filter=0` (Nearest).** Godot
  defaults to linear filtering, which blurs pixel art into mush. This had to be
  set before any sprite landed.
- `hero.tscn` / `enemy.tscn` carry an empty `AnimatedSprite2D` plus a
  `Placeholder` ColorRect. Art hides the placeholder; creatures without art keep
  their block. Real and placeholder combatants coexist in the same fight, so art
  can arrive one file at a time.

### Convention set
`NAMING.md` specs individual frame files and says nothing about sheets. Strips
follow the same pattern minus the frame number:

	assets/sprites/characters/<prefix>_<slug>_bidle.png     one row, no padding
	enemy_frostbite_imp_bidle.png                           spaces -> underscores

---

## 2026-08-27

### Added
- **The battle scene runs a real fight.** `battle.gd` now builds a
  `BattleState` from the three active heroes plus the enemies it was handed,
  connects all six signals, and drives the loop end to end. Verified by
  auto-playing it headless: turn order by Speed, damage, deaths, victory.
- **`scenes/battle/hero.tscn`** — heroes had no scene, so there was nothing to
  step forward. Carries a placeholder sprite and a `ClickArea`, which Guard and
  potions need anyway since they target allies.
- **`scenes/battle/damage_number.tscn`** — a Label that floats and fades,
  spawned per hit over the combatant that took it.

### Changed
- **The action menu is now ONE shared menu**, re-pointed at whoever is acting,
  instead of a set per hero. Buttons grey out via `budget.can_spend()` — the
  same call that would spend — so the stamina economy is visible. Dropped 12
  buttons to 4 and matches the team's reference layout.
- **The turn cue is the step-forward**, not an indicator widget. The acting
  character slides toward the enemy while everyone else drifts back. Enemies
  step too, or a 2-action enemy lands two hits with nothing marking who.
- **`TargetPicker` removed.** Click-the-sprite made a central picker
  redundant — each combatant owns its `ClickArea`. What was real is the modal
  "what is clickable now" state, which is two variables in `battle.gd`, not a
  node. Guard flips the valid side from enemies to allies.
- `hero_panel.tscn` is now a pure status display — name, HP, live action
  budget, ult. Its button grid moved to the shared menu.
- Placeholder art throughout: `ColorRect` characters, flat background. Swapping
  in real art means pointing nodes at textures; no logic changes.

### Fixed
- **`combatant_died` fired before the blow that caused it.** `_apply_damage()`
  emitted immediately while `action_taken` came after, so the log read
  "Mudling is down!" *then* "Aria hits Mudling for 13". Deaths are now queued
  and flushed after the action is reported. Found by reading the auto-play
  output rather than by inspection.

---

## 2026-08-24 — Spec reconciliation

A full audit of code against documentation, then a pass to close the gaps.
The docs had drifted far enough that `INTEGRATION_SEAMS.md` documented three
of seven autoloads, and the combatant dictionary it described would crash on
first use — it omitted `element`, which `Combat` dereferences.

### Added
- **`core/CreatureRating.gd`** — enemy stats are now DERIVED, not authored.
  A creature is three independent dials:

	  stat = round(element base x rating / 10 x tier_scale)

  `ratings[]` is what kind of creature it is, `stat_element` is which numbers
  it scales from, `tier_scale` is how hard this particular fight should be.
  Turn one without disturbing the others.

  **`stat_element` is deliberately separate from the rolled battle element.**
  A creature with `rolls_element` computes stats from its fixed element but
  rolls a random one for the matchup only. Without that split, a Wisp that
  rolled Earth would come out slow and armoured — its identity has to live in
  `ratings[]`, not in the dice.

  Ratings are **fractional**, 0–25. Integers would only give 10% steps off the
  element base, far too coarse to tune a 45 HP Wisp, and the boss needs 21.7
  to reach 260 HP off Lava's base of 120. With fractions, **all seven
  creatures reproduce their hand-authored stats exactly** — the system is live
  and balance has not moved a single point.

  `build()` returns the combatant dictionary `BattleState.setup()` expects,
  which is also what closes the enemy-representation decision.
- **`core/Inventory.gd`** — autoload. Party-wide gold and items, no capacity
  limit, `id -> count` with absent-not-zero semantics. `gold_changed` and
  `items_changed` signals. `spend_gold()` and `remove_item()` return false and
  change nothing when they can't complete, so a Buy button's disabled state
  comes from the same call that pays.
- **`data/heroes/*.tres` and `data/enemies/*.tres`** — the numbers finally
  live in `data/`, as `STRUCTURE.md` always claimed they did.
- **`Transitions.push(path, payload)`** — scenes could stack but not talk.
  The payload is appended before the scene is instanced, so it can be read in
  `_ready()`, and it's stacked alongside its scene so popping restores the
  one underneath.
- **Currency and a shop**, scaffolded across `COMBAT_DATA.md`, the workplan,
  `NAMING.md` and `STRUCTURE.md`. Every price and quantity is marked TBD
  rather than invented.
- **`Targeting.ACTIVE` / `is_active()`** — the three-slot rule in one place
  instead of re-derived in five files.

### Changed
- **Enemy sprite work split.** The three encounter enemies were added on
  2026-08-19, after the workplan was written, and the art count was never
  bumped — Designer 1 was briefed for 3 sprites on a game needing 6. Dungeon
  enemies stay must-have in M1; encounter enemies move to M2, alongside the
  item that first needs them.
- **`BACK2` is the bench, not a phantom slot.** It was simultaneously
  documented as "unused", used by `Party.gd` to park the substitute, and
  live in `POS_THREAT` with threat 10 — meaning a substitute built into a
  fight was a legal target. Threat drops to 0, `threat_of()` and
  `pick_overwhelm()` skip inactive slots, and `BattleState.setup()` warns and
  skips. Exactly three heroes are targetable.
- **Zeph SPD 34 → 28, Craig SPD 12 → 13**, so the hero table matches the
  element letter grades it claims to derive from. Zeph stays the fastest hero.
- **Menus moved to `ui/menus/`** — `main_menu.tscn` and the skill tree.
  Settles the contradiction where `STRUCTURE.md` called `scenes/` "map,
  battle, menus" while also defining `ui/menus/` as full-screen screens.
- **The `core/` ownership boundary is gone.** Any file may edit any other,
  provided `INTEGRATION_SEAMS.md` is updated in the same commit. One narrower
  rule survives: all damage and healing math lives in `Combat.gd`.
- **`README.md`** rewritten from the untouched GitLab template. The clone URL
  pointed at the pre-move namespace and only worked via redirect.
- `NAMING.md` — all 6 enemy slugs plus the boss, a slug rule so
  `frostbite_imp` is unambiguous, hurt frames promoted to must-have, and the
  leftover `_walk_` convention corrected to `_ow_`.

### Decided
Answers to nine questions that no document addressed, all of which are now in
`COMBAT_DATA.md` under "Survival and recovery" and "Run structure":
- **HP carries between fights.** No rest, no camp, no auto-heal.
- **Potions are the only healing**, and **level-up raises max HP but not
  current HP**.
- **A downed hero is revived with a potion, mid-battle**, restoring the usual
  +60 and clearing the downed status.
- **Three revives per HERO per dungeon**, not per party. Potions themselves
  are unlimited — the cap stops one fragile hero being farmed back, it isn't
  the resource the player budgets. That resource is potion supply.
- **A hero who dies a fourth time is out for the run.** Four heroes, three
  slots: the first permanent loss is absorbed by the substitute, the second
  leaves the party short-handed.
- **Wiping ejects you from the dungeon and costs every reward except XP.**
- **Ult resets between fights.** **Substitutes swap after every fight.**
- **The shop is on the overworld**, so you cannot restock mid-run.
- Clearing the dungeon ends the demo; the player can still roam to try gear.

Together these make attrition the difficulty curve rather than any single
fight, and point all the pressure at one decision: how many potions you
bought before you went in.

### Fixed
- **`pick_target()` could return a member who was dead or benched.** A
  boundary roll could land on a zero-threat entry, and the fallback
  `return party.size() - 1` returned the last index regardless of state.
- **`act()`'s GUARD path never validated its index.** `target_index` is
  enemy-space for MELEE/SPELL/ITEM but hero-space for GUARD; only the melee
  path bounds-checked. GUARD now rejects and refunds instead of writing a
  bogus entry onto the guard board.
- **`Party.gd` mutating cached resources.** `load()` caches, so spending a
  stat point would have written back into the on-disk hero. `_load_hero()`
  duplicates the resource and its arrays explicitly.
- Removed the "stats don't change mid-fight" comment on the cached
  `max_actions`. `Transitions` keeps a pushed-over scene alive, so a skill
  tree opened above a battle could invalidate it. The cache stays; the false
  reassurance doesn't.
- Documented three behaviours that existed only inside `Targeting.gd` and
  `EnemyAI.gd`: the **threat formula** (`positional base + DEF + HP/10`), the
  fact that a **redirected Guard hit uses the original target's DEF** rather
  than the guardian's, and that **enemy turns are planned up front**, so a
  2-action enemy can be scheduled to hit someone who dies to the first blow.
- Removed the CSV import step from the workplan. `gitlab_issues_import.csv`
  never existed in the repo.

### Superseded
- **`"defense"` is now `"def"` again**, reversing the rename recorded under
  Fixed on this date. `def` is shorter and it's the spelling the team wants;
  nothing reads `"defense"` anywhere in the tree now. The earlier entry stays
  as history rather than being rewritten.

---

## 2026-08-24

### Added
- **`core/Actions.gd`** — autoload holding the action economy rules. The four
  action types (`MELEE` `SPELL` `ITEM` `GUARD`), what each costs, how many
  actions Stamina buys, and the Guard board helpers. Guard *arms* rather than
  resolving: `Targeting.resolve_guard()` consumes the board when a hit lands.
- **`core/ActionBudget.gd`** — `class_name` tracking one combatant's actions for
  one turn. `reset()` `can_spend()` `spend()` `refund()` `is_spent()`. Not an
  autoload — same pattern as `Character`. `spend()` returns false and changes
  nothing when the budget can't cover it, so UI can drive a button's disabled
  state off the same call that spends.

- **`core/BattleState.gd`** — the combat state machine. `class_name`, one
  instance per fight. PREP arranges positions, then a turn loop ordered by
  Speed runs until one side is gone. Emits six signals — `phase_changed`,
  `turn_started`, `turn_ended`, `action_taken`, `combatant_died`,
  `battle_ended` — so the battle UI reacts instead of polling. This is the
  first signal contract in the project.

### Changed
- `EnemyAI.actions_for()` now delegates to `Actions.max_for_enemy()` instead of
  carrying its own copy of `1 + int(STA / 30)`. The formula lives in one place.
- `project.godot` — registered `Actions`, ordered before `EnemyAI` which now
  depends on it.

### Decided in code
`COMBAT_DATA.md` states the 1-action cost only for items. These extend it:
- **All four action types cost 1.** Split `Actions.COST` apart if a spell should
  ever cost two.
- **Actions don't bank** — anything unspent at end of turn is lost.
- **Guard doesn't end your turn.** It's an action like any other, so a 3-action
  hero can guard and still attack twice.
- **One guardian protects one ally.** Declaring again reassigns rather than
  stacking, so a guardian can never soak two allies at once.
- **A mutual kill is a loss.** If the last hero and the last enemy fall on the
  same blow, `_check_end()` tests party wipe first, so the fight is a defeat.
- **Speed ties go to the hero.** The party should not lose a race it drew.
- **Turn order rebuilds each round**, so a SPD change mid-fight takes effect
  next round rather than never.

> ⚠️ **These seven rules now live in `COMBAT_DATA.md` and
> `INTEGRATION_SEAMS.md`**, where they belong. A changelog is a record of
> change, not a source of truth.

### Fixed
- **`Combat` now reads `"defense"`, not `"def"`.** `Targeting` has always used
  `member["defense"]`; `Combat` was written with `"def"`, so a single combatant
  dictionary could not feed both. Aligned on `Targeting`'s spelling since it
  came first. This is what let `BattleState` use one dict shape throughout.

  > ⚠️ **Superseded — see "Spec reconciliation" above.** This was reversed:
  > the project standardised on `"def"`. Kept here because it happened.

---

## 2026-08-21

### Added
- **`core/Combat.gd`** — autoload holding all damage and healing math. Pure
  functions, no state, so combat code and UI get the same number:
  `melee()` `spell()` `item()` `heal()` `ult_gain()` `from_character()`.
  Combatants are dictionaries, matching the convention `Targeting` uses, so
  this works for enemies despite there being no Enemy class.
- **`core/EnemyAI.gd`** — autoload deciding what an enemy does on its turn.
  `plan_turn()` returns one entry per available action, each
  `{ target, damage, redirected }`, where `target` is who *actually* takes the
  hit after Guard redirection. Action count comes from Stamina via
  `actions_for()`. Boss overwhelm is opt-in and fires below 50% HP.
- **`## ⚔️ DAMAGE RULES`** section in `COMBAT_DATA.md`, documenting the shared
  `(raw − DEF) × matchup` shape and why DEF is subtracted first.

### Changed
- **No healing spells — potions only.** `water_2` went from a heal
  (`MAG × 1.5`) to a 1.7-multiplier damage spell, keeping the demo at six
  spells so the icon list is unaffected. Aria is now a Water damage caster
  rather than a support hero.
- **`COMBAT_DATA.md` now reflects the 3-active-hero party.** Positions table
  shows three slots plus a substitute, `Targeting.POS.BACK2` is documented as
  unused, and both balance notes that assumed four heroes were corrected
  ("beatable by the 3 active level-1 heroes", "outnumbers them 3-to-1").
- **Item damage rule is decided**, no longer "pick one rule and note it in
  code": `(item value − target DEF) × matchup`, with `item_bomb` skipping the
  matchup.
- `project.godot` — registered the `Combat` and `EnemyAI` autoloads.

### Decided in code
Neither was specified anywhere, both are single constants in `Combat.gd`:
- **Minimum damage is 1** — stops a bad matchup against a tanky target dealing
  0 and stalling a fight.
- **Damage floors rather than rounds** — DEF is never worth less than its face
  value.

### Fixed
- **Committed the five missing `.gd.uid` files.** Godot 4.4+ writes one next to
  every script and `preload()` resolves against it when a script moves. Five
  were tracked and five were not, purely because of when the editor happened to
  be open. Generated by a headless import so the ids are real.
- **Removed a stray `scenes/Main Menu.tscn`.** The editor still had the scene
  open under its pre-rename path and wrote it back with a fresh uid, leaving two
  identical scenes with different ids. Nothing referenced either.
  `main_menu.tscn` keeps Demeko's original uid.
- **Pointed `git remote` at `nabiasjones1/`.** The project moved namespaces;
  pushes had been working only via GitLab's redirect.

---

## 2026-08-20

### Added
- **`core/Transitions.gd`** — autoload owning the scene stack and fade overlay
  (`077f05a`). Scenes stack rather than swap: `push()` leaves the scene below
  loaded but hidden and paused, so state survives for free. API is
  `push()` / `pop()` / `replace()` / `current()` / `depth()`, plus
  `transition_started` / `transition_finished` signals. Builds its own
  `CanvasLayer` at layer 128 with a black `ColorRect` tweening over 0.25s.
  Registered last in the autoload order.
- **`scenes/map/map.tscn` + `map.gd`** — overworld skeleton (`a89eda8`). Free
  8-directional movement, encounters rolled anywhere off distance walked,
  blocking terrain. `Props` sits inside `Entities` so prop tiles and the player
  share a y-sorted parent — that is what lets the player walk behind a tree.
  Player uses `motion_mode = floating`.
- **`scenes/battle/battle.tscn` + `battle.gd` + `enemy.tscn`**, and
  **`ui/hud/hero_panel.tscn`** — battle skeleton (`c5654b6`). Side-view layout
  from the team reference: heroes left, enemies right, stat panels top, message
  log bottom-left, 2×2 action grid. Three active hero slots
  (Front/Center/Back1); the fourth hero is a prep-menu substitute. Hero panel
  instanced 3×, enemy instanced at runtime since count is dynamic.
- **`scenes/skill_tree/skill_tree.tscn` + `skill_tree.gd`** — skill tree
  skeleton (`c1be49d`). Standalone screen, tabs across all four heroes, points
  spend on five skill nodes or six raw stats. Stat rows preview what the point
  buys (`STA 24 -> 27`) off `Character.PER_POINT`.

### Changed
- `project.godot` — registered the `Transitions` autoload.
- `map.gd` lost its `suspend()` / `resume()` hooks. The transition manager owns
  visibility and pausing, so they were dead code.

---

## 2026-08-19

### Added
- **`scenes/main_menu.tscn`** — main menu blockout by DemekoCole (`3b2b57b`).
  PLAY GAME and OPTIONS buttons, title "Depths Of Ashenveil". No script yet.
- **Encounter enemies** in `COMBAT_DATA.md` — Wisp, Critter, Brute, for random
  map encounters (`ea49934`). Random element rolled on spawn; 8/10/12 XP.

### Changed
- **Enemy actions now derive from Stamina** (`ea49934`). Enemies no longer carry
  a hand-authored action count:

      1 + int(STA / 30)     # enemy
      2 + int(STA / 30)     # hero, unchanged

  The lower floor is deliberate — the party outnumbers enemies 4-to-1, and the
  hero formula would give the two easiest enemies as many actions as the boss.
  **Emberhound STA 24 → 30** so it earns its second action from the formula
  instead of a special case. All other action counts unchanged.
- **XP is awarded per enemy death**, not on dungeon clear (`ea49934`, workplan).
  Heroes can level mid-dungeon, which is why the prep menu now needs a
  spend-your-point screen between fights.
- Renamed `scenes/Main Menu.tscn` → `scenes/main_menu.tscn` (`bc8a42c`).
  `STRUCTURE.md` requires snake_case; the space also needed shell quoting.

### Removed
- **The Dimensions section of `NAMING.md`** (`935082f`) — tile/sprite/icon sizes
  and base resolution, pending a team decision. **Temporary.** Designers
  currently have no authoritative canvas size; this must come back before art
  production continues.

---

## 2026-08-18 and earlier

- Core systems from Coder A: `Elements`, `Party`, `Targeting` autoloads and the
  `Character` class (`6334e9b`, `b4eeb54`).
- `INTEGRATION_SEAMS.md` — the two-coder contract (`b4eeb54`, `050741c`).
- `COMBAT_DATA.md` — hero stats, growth, enemies, drops, items, spells
  (`00b62ca`).
- `NAMING.md` — asset naming spec (`2be22f2`).
- Godot 4 project scaffolding and folder layout (`461f856`, `23f1061`).

---

## Open decisions

Things the code is waiting on. Each one blocks work that is otherwise ready.

| Question | Blocks | Owner |
|---|---|---|
| Tile / sprite / base resolution numbers | Designer 2 can't size tiles; all three collision shapes are null | Team |
| Who is the party leader? | 10 overworld sprite files Designer 1 can't start | Team |
| What do the 5 skill nodes do? | Skill tree can't be wired | Team |
| Prereq logic in `unlock_skill()` | Gated skill tree is enforced UI-side today | Coder A |
| `main_scene` boots straight to `battle.tscn` | Bypasses `Transitions` entirely, so the stack starts empty and `pop()` can never fire | Coder B |
| Aria has no role now healing is gone | Party identity spread is thinner; affects balance pass | Team |
| Is `water_2`'s 1.7 multiplier right? | Chosen to parallel `fire_2` (1.8) — needs sign-off | Team |
| How does a finished battle report its result? | `push()` carries a payload in; nothing carries win/loss, drops or XP back out. May be moot if the M2 dungeon manager owns the whole sequence | Coder A + B |
| Shop stock, prices, sell rate | Shop screen can't be built | Team |
| Starting gold, potion count, and which four starter items | `Inventory.STARTING_*` are placeholders | Team |
| Where does gold come from? | No enemy has a gold value | Team |
| **How many enemies per fight — encounters AND dungeon?** | Undecided for both. The code takes a variable list either way, so nothing is blocked — but XP pacing assumes one enemy per dungeon fight (15+25+30 = the doc's "~70"), and "8–12 XP each" pays triple for a group of three | Team |
| Does a fight run with fewer than three heroes? | `BattleState.setup()` will happily build two. Unclear whether that's intended or should end the run | Coder A |
| Is "all heroes permanently out" a wipe? | Different condition from "all at 0 HP this fight", which is all `_party_wiped()` knows | Coder A |
| `wind_2` / `earth_2` don't exist | `refresh_spells()` generates them at level 3, which is reachable in the demo | Team |

### Closed since the last entry
- ~~Enemy representation (class + seam)~~ — `CreatureRating` + `build()`.
- ~~Combat signals — the seams doc has none~~ — all six documented.
- ~~Ashfang can't reach 260 HP~~ — rating cap raised to 25, ratings made
  fractional. He lands on 260 exactly.

---

## Known inconsistencies

Real, understood, and not yet worth fixing — but don't be surprised by them.

- **Action button text has three sources.** `Actions.LABEL` says
  `Attack/Spell/Item/Guard`, `hero_panel.tscn` says `FIGHT/SPELL/ITEMS/GUARD`,
  and `NAMING.md` names the art `ui_btn_attack/spell/item/guard.png`.
- **Dark and Light are strong against each other**, so that pairing is ×1.5
  both ways and the ×0.5 branch is unreachable for it. Nothing in the demo
  uses either element.
- **`skill_tree.gd`'s back button is still never connected.** There is no way
  to leave the skill tree. (The dungeon entrance is wired as of 2026-09-11; a
  finished battle still has nowhere to pop back to.)
- **`TurnIndicator` is still an empty node no script references.** The turn cue
  is the step-forward instead, so it may simply not be needed.
- The battle reference shows a **global** burst gauge; the build has a per-hero
  ult bar, matching `COMBAT_DATA.md`. The action menu now matches the
  reference (one shared menu).
