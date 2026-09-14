# The overworld map

`scenes/map/map.tscn` + `map.gd`. A walled hilltop settlement, **100 × 80 tiles
at 32px** (3200 × 2560 px), around 15,000 painted cells across three elevation
bands. Built from the `TX` tileset pack in the style of the team's
`Scene Overview.png` reference.

This doc has authority over **how the map scene is put together** — the bands,
what draws over what, and how the player moves between levels — and over **the
handoff to the battle screen**: the encounter roll, the scene stack, and the way
back. Where it disagrees with a screenshot, the scene wins.

> The encounter work is written up in full at [Random encounters and the battle
> handoff](#random-encounters-and-the-battle-handoff). It touches
> `core/Transitions.gd` and `scenes/battle/battle.gd` as well as `map.gd`.
> `INTEGRATION_SEAMS.md` carries the `Transitions` signatures, as the seams doc
> should; the round trip, the reasoning and what is deliberately unfinished are
> here. `CHANGELOG.md` was left alone.

> **Before you regenerate anything, read [Do not regenerate the
> scene](#do-not-regenerate-the-scene) at the bottom.**

---

## The three bands

The map fakes elevation with **sorting bands**, the Godot equivalent of Unity's
sorting layer / order-in-layer arrangement in `MapLayers.jpg`.

`Layer1`, `Layer2` and `Layer3` are plain `Node2D`s spaced **10 apart in
`z_index`**. `z_as_relative` is on by default, so a child's order *adds* to its
band: a higher band always draws over a lower one whatever the y, and inside a
band the orders decide.

Each band holds the same six tilemaps:

| Layer | Order | Y-sorted | What goes on it |
|---|---|---|---|
| `Ground` | 0 | no | Base terrain, and paving — the paving tiles have grass baked in |
| `Grass` | 1 | no | Scattered flowers and pebbles on top of the ground |
| `Stairs` | 2 | no | Staircases. Walked **on**, so it must never sort in front of the player |
| `Shadow` | 3 | no | Drop shadows: above the ground, under everything that casts them |
| `Walls` | 4 | **yes** | Wall rings, arches, ruins |
| `Props` | 4 | **yes** | Trees, bushes, crates, monuments |

`Entities` (the player) lives **inside `Layer1`** at order 4, alongside `Walls`
and `Props`. That shared order is what lets the player walk behind a tree.

**Y-sorting only works within a band.** A sprite cannot sort against another
band's props — which is the whole point. Walk onto a terrace and you are in
front of everything below it, permanently.

### Terraces

A terrace is a **plot**: a rectangle whose wall ring is drawn on the band it
belongs to, so its south face hangs over the band below.

| Plot | Band | Tiles (x0, y0, x1, y1) |
|---|---|---|
| Map boundary | 1 | `1, 1, 98, 78` |
| Waystone Supply (the shop) | 1 | `24, 64, 34, 71` |
| North terrace | 2 | `18, 3, 81, 30` |
| West court | 2 | `4, 40, 22, 58` |
| East court | 2 | `76, 40, 94, 58` |
| Summit | 3 | `38, 6, 62, 22` |

The ring is not decoration you draw freehand — the wall sheet has one prefab
and it dictates the shape:

```
  y0     NW   N N N N N   NE      thin cap, one row
  ...    W               E        thin side rims
  y1-1   SW  cap cap cap SE       the top of the south wall
  y1     SW  face face   SE       the brick face you actually see
```

So the walkable surface of a plot is `y0 .. y1-2`, and the south edge always
costs two rows. Nested plots step up toward the top of the screen, the way the
reference does.

---

## Getting between bands

`scenes/map/stair_link.gd` — `class_name StairLink`, an `Area2D` with one
exported field, `to_band` (0 = `Layer1`, 1 = `Layer2`, 2 = `Layer3`).

A staircase is **a gap cut in the wall ring** with the stair art painted into it
and a link at each end. `map.gd` connects every link under `StairLinks` and
reparents `Entities` into the target band when the player crosses one.

| Stair | Columns | Rows | Connects | Art ascends |
|---|---|---|---|---|
| `StairA` | 34–37 | 29–31 | ground ⇄ north terrace | right |
| `StairB` | 10–13 | 57–59 | ground ⇄ west court | right |
| `StairC` | 84–87 | 57–59 | ground ⇄ east court | left |
| `StairSummit` | 48–51 | 21–23 | north terrace ⇄ summit | right |

Three rules that are easy to get wrong:

- **`StairLinks` sits outside the bands**, as a direct child of `Map`. The
  triggers have to stay put while `Entities` moves between bands under them.
- **`set_entity_band()` is called deferred.** `body_entered` arrives while the
  physics server is walking its queries, and reparenting a body mid-flush fails
  with `Can't change this state while flushing queries` plus a few hundred
  `index_in_parent unset` errors.
- **`map.gd` addresses its nodes through `%` unique names.** A plain
  `$Entities/Player` path does not survive the reparent.

---

## Landmarks

`scenes/map/landmark.gd` — `class_name Landmark`, an `Area2D` with `label`
(what people call the place) and `opens` (the scene it pushes, or `""`).

| Node | Label | Band | Tile | Opens |
|---|---|---|---|---|
| `Shop` | Waystone Supply | 1 | 29, 72 | `res://ui/menus/shop.tscn` |
| `Shrine` | Shrine of the Ten | 3 | 49, 15 | — |
| `KneelingStones` | The Kneeling Stones | 2 | 26, 18 | — |

`map.gd:landmark_underfoot()` returns whichever one the player is standing on,
or `null`, tracked off `body_entered` / `body_exited`. A prompt or an input
handler reads that rather than testing positions itself.

**The shop is a building, not a yard.** Its wall ring has no gap: you stand at
the door and it opens a screen. That is what `COMBAT_DATA.md` specifies — "an
overworld location ... opens as a full-screen screen pushed from `map.gd`" — so
its trigger sits in the street outside the door, not inside the walls.

The **dungeon entrance** is separate, under `Interactables`, and is still a bare
`Area2D` rather than a `Landmark`. It sits under the arch in the summit's north
wall, two flights up from spawn. It could adopt the same script; nobody has
needed it to yet.

Its `Marker` child shows `marker_dungeon.png` (an amber arrow over a cave
mouth) 56px above the trigger, so it floats over the arch rather than sitting
in the doorway. `map.gd` bobs it 3px on a looping tween. `DungeonEntrance`
carries `z_index = 30` for this: `Interactables` is at 0, below every band, so
without it the marker would draw under the Layer1 ground.

Spawn is tile **(50, 66)**, on the southern approach. The camera is limited to
the map bounds.

---

## The player's walk cycle

Eight directional sheets, `Idle_walk_<facing>.png`, one per compass point. Each
is **128 × 192 — a 2 × 3 grid of 64px cells, six frames**, read left-to-right
then top-to-bottom.

| | |
|---|---|
| Frame 0 | The **rest** pose — the `Idle_` half of the filename |
| Frames 1–5 | The stride |
| Playback | 10 fps, looping, `WALK_FPS` in `map.gd` |

These replaced eight single-frame stills (`south.png`, `east.png` and friends).
Those files are **still on disk and no longer referenced by anything** — left
alone rather than deleted, since removing art is not a call this side should
make. Delete them whenever you like.

**How the eight sheets become one animation set.** An `AnimatedSprite2D` selects
an animation *by name*, so all eight directions have to live in a single
`SpriteFrames`. `SpriteSheet.strip_auto()` hands back a `SpriteFrames` of its own
holding one animation, so `map.gd` slices each sheet and lifts its frames across
under the direction's name. The grid maths and the blank-cell skipping stay in
`SpriteSheet` rather than being owned in two places.

**Idle is a stopped animation, not a separate one.** `stop()` rewinds to frame 0,
which is the rest pose — so releasing the keys settles the character instead of
freezing them mid-stride, and no "idle" animation has to exist. Moving off again
calls `play()`, which resumes from that frame.

The direction names are load-bearing three times over: they are the keys of
`FACING_SHEETS`, the animation names in the `SpriteFrames`, and the order
`_facing_from()` returns sectors in. They also match the filenames. Renaming one
means renaming all four.

---

## Collision

Walls block. The ring tiles, the windowed wall run and the ruin blocks each
carry a full-tile polygon on `physics_layer_0` of `TileSet_struct`. Stairs and
the arches deliberately carry none — those are the ways through.

The player finally has a collision shape too: a 20 × 12 box at the feet. It had
none at all before, which meant no `Area2D` could ever have noticed it.

Verified by walking, not by reading:

```
StairA/B/C:   Layer1 <-> Layer2       terrace face:  stopped at y=990  (face 960-992)
StairSummit:  Layer2 <-> Layer3       map boundary:  stopped at y=2449
Shop/Shrine/Stones: underfoot yes -> null on walking off
shop wall:    stopped at y=2302 (face 2272-2304)      dungeon arch: overlapping = true
```

`Interactables/DungeonEntrance` has its shape and its marker; `Prompt` is
still an empty, hidden `Node2D`.

---

## The tilesets

Four, all built in the scene rather than as `.tres` files:

| TileSet | Sources | Used by |
|---|---|---|
| `TileSet_ground` | TX Tileset Grass, TX Tileset Stone Ground | `Ground`, `Grass` |
| `TileSet_struct` | TX Tileset Wall, TX Struct — **has the physics layer** | `Walls`, `Stairs` |
| `TileSet_shadow` | TX Shadow, TX Shadow Plant | `Shadow` |
| `TileSet_props` | TX Plant, TX Props, TX Plant with Shadow, TX Props with Shadow | `Props` |

Two things they all do:

- **Only cells the sheet actually draws are tiles.** Enumerating a full 16×16
  grid over a sheet with gaps makes Godot print `Cannot create tile` on every
  single load — the old props tileset was doing that ~120 times.
- **Tall objects carry `y_sort_origin`.** A tile at row *r* of an object whose
  base is row *R* gets `(R - r) * 32`, so a 5-tile tree sorts from its trunk as
  one object instead of row by row.

---

## Reading the sheets

Recorded here because nothing else records it, and measuring it again is an
afternoon. All coordinates are 32px tile cells.

**TX Tileset Grass** (8×8) — rows 0–3 are grass, columns 0–3 plain and 4–7 with
flowers or pebbles. Rows 4–7 are paving on a grass backing, which is why paving
goes straight onto `Ground` rather than a layer of its own:

| Cells | Meaning |
|---|---|
| `(0,4) (1,4) (0,5) (1,5) (0,6) (1,6)` | Full paving, four slabs |
| `(2,4-6)` / `(3,4-6)` | Slabs on the east / west half — grass to the west / east |
| `(4-7,4)` / `(4-7,5)` | Slabs low / high — grass to the north / south |
| `(4-7,6)` | One or two loose slabs, for fraying an edge |

**TX Tileset Wall** — the ring prefab is `(1,1)`–`(3,4)`, laid out as the
diagram above. A wall run with a barred window is at `(6,6)`, two tiles tall,
and drops straight over a ring's cap and face rows.

**TX Struct** — stairs ascending right at `(1,9)` and `(5,9)`, ascending left at
`(1,12)` and `(5,12)`, all 4 × 3. The tall archway is `(12,0)` 4 × 3, with the
opening centred between its middle two columns; the short one is `(13,4)` 2 × 2.
Ruined wall blocks sit at `(1,1)`, `(4,1)`, `(7,1)`, `(1,5)`, `(4,5)`, `(7,5)`.

**TX Plant** — three trees at `(0,0)` 5 × 5, `(5,0)` and `(9,0)` 3 × 5, trunk on
the bottom row. Bushes run along rows 5–7.

**TX Props** — **column 8 is the sheet's own blue labels, not art.** Never paint
from it. Everything else is a discrete object: chests, crates, barrels, benches,
altars, statues, rune tablets, graves, urns, a circular dais at `(11,8)` and a
broken stone ring at `(13,11)`.

**The shadow sheets line up cell-for-cell with the object sheets** — TX Shadow
against TX Props, TX Shadow Plant against TX Plant. Stamp a prop's own cells
from the shadow sheet at the same position and its shadow lands correctly. Do
*not* stamp cells the object sheet leaves empty: the shadow sheets cover a wider
area than the objects, and you get shadows stranded on bare grass.

---

## Godot traps this cost time on

Seven things that fail **silently**, so they cost an afternoon each.

**Tile collision polygons have a specific property name.**

```
0:0/0/physics_layer_0/polygons/0/points  = ignored, tile never blocks
0:0/0/physics_layer_0/polygons_count     = 1        <- both of these
0:0/0/physics_layer_0/polygon_0/points   = Packed…  <- are required
```

Any other spelling is dropped without an error. The walls looked fully
configured and blocked nothing.

**Linear texture filtering bleeds across atlas cells.** At the default filter,
the props sheet's own blue labels leak onto the art in the neighbouring column.
The map root sets `texture_filter = 1` (nearest) and children inherit it. If
anything ever looks softly wrong, check this first.

**`class_name` is registered by the editor, not by the file.** A script with a
fresh `class_name` will not resolve in a headless run until the project has been
opened in Godot once — the parse error is `Could not find type "X" in the
current scope`, which reads like a typo and is not one.

**Hand-measured atlas rects are wrong sooner or later.** A rect one row too tall
drags an unrelated fragment along with it and you get mystery artifacts on the
map. Object footprints in this scene were derived by flood-filling the opaque
pixels of each sheet, which is also how we learned the big tree is 5 tiles wide
and not 3.

**A `Camera2D` does not let go of the viewport when its scene is hidden and
paused.** It sets the viewport's canvas transform, and that transform *survives*
— a paused camera stops **updating** the transform, it does not surrender it. So
a scene pushed on top of the map gets drawn through the map camera's offset.

This one is nastier than the rest because of what it *doesn't* break:
`CanvasLayer` content carries its own transform, so backgrounds and HUD look
completely normal while every world-space node is off screen. The battle screen
appeared to lose its characters and enemies entirely. It cost an afternoon and
it will cost another one if it is ever undone — see
[The camera handoff](#the-camera-handoff) for the fix.

**A `Control` drawn on a clickable object eats the click.** GUI input is
resolved *before* physics picking, so any `Control` sitting over an `Area2D`
swallows the event and `input_event` never fires. `mouse_filter` defaults to
`STOP` on most Controls — including `ColorRect` and `ProgressBar`.

This bit the battle screen: `Placeholder` is a `ColorRect`, so **any creature
without idle art could not be attacked**. `_dress()` hides the placeholder when
art *is* found, which is why the bug tracked the art rather than the code and
looked like "the red blocks aren't clickable". `Placeholder` in `hero.tscn` and
`enemy.tscn`, and `HpBar` in `enemy.tscn`, are now `mouse_filter = 2`
(`MOUSE_FILTER_IGNORE`).

Every encounter creature has art now, so the placeholder no longer shows up in
a rolled fight — but the fix stays load-bearing for the next creature added
before its sheet is.

The rule: **anything drawn on a combatant must be mouse-transparent.** `Label`
already defaults to `IGNORE`; nothing else does.

**A PNG that Godot has not imported is invisible to `ResourceLoader.exists()`.**
Running the project from the command line does **not** run the import pipeline —
only the editor does. So a newly dropped sprite reads as *absent*, not as
broken: `SpriteSheet.find_idle()` returns null and `_dress()` shows the
placeholder, which looks exactly like art that was never added.

Symptom to recognise: the file is plainly sitting in
`assets/sprites/characters/` and the game insists there is nothing there. Check
for the sibling **`.png.import`** file — if it is missing, open the project in
the editor once and it will appear within a few seconds. Renaming an asset
invalidates its old `.import`, so a rename needs the same treatment.

---

## Do not regenerate the scene

The first version of this map was produced by a generator — a hand-placed
skeleton of plots, routes and prop clusters, with trees and clutter scattered by
seeded random. **That generator has been retired and is not in the repo.**

The scene has been hand-edited in Godot since: a stone-ground tileset added to
`TileSet_ground`, two "with Shadow" sheets added to `TileSet_props`, and tiles
repainted. Regenerating would silently throw all of that away — it very nearly
did, and the only reason it did not is that a copy happened to be sitting
alongside.

**`scenes/map/map.tscn` is now the source of truth. Edit it in the Godot
editor.** If you want a generated pass over it again, say so first and expect to
merge by hand.

---

## Not wired yet

Deliberate, not forgotten. Each of these is waiting on something that does not
exist.

| What | Waiting on |
|---|---|
| Acting on a landmark | `ui/menus/shop.tscn`. `map.gd` carries the four lines it needs in a comment |
| The dungeon entrance | Nothing technical any more — it just has no destination scene. The encounter path below is its template |
| Shrine and Kneeling Stones | Nothing. They open nothing by design; they are places to walk to |

The project's main scene is now **`scenes/map/map.tscn`**, so **F5** walks the
map. It used to be `scenes/battle/battle.tscn`; the map is where the game
starts, and the battle is somewhere it goes.

---

# Random encounters and the battle handoff

**Wired and live.** Walking rolls for a fight; the fight runs on the battle
screen; the player comes back standing exactly where they left.

This section records the whole of that work, including the parts that live
outside `scenes/map/`.

## The roll

| Dial | Value | Constant in `map.gd` |
|---|---|---|
| Distance between rolls | 240 px walked | `ENCOUNTER_CHECK_DISTANCE` |
| Chance per roll | 25% | `ENCOUNTER_CHANCE` |
| Pack size | 1–3 | `MIN_ENCOUNTER_SIZE` / `MAX_ENCOUNTER_SIZE` |
| Who shows up | Wisp, Critter, Brute | `ENCOUNTER_POOL` |
| Backdrop the fight is handed | `bg_field.png` | `ENCOUNTER_BACKGROUND` |

The odometer only advances while the player is actually **moving**, so standing
still is safe and there is no timer running behind the map. It resets after
every fight, so the party always gets a clear stretch of ground rather than
walking two steps into another ambush.

Each pack member is an independent `CreatureRating.build()`, and `build()` rolls
the battle element fresh on every call — so two Brutes in one fight are two
different matchups.

`_in_encounter` guards the roll. The map is paused once the fight is up, so
`_physics_process` cannot fire again — but the quarter-second fade happens while
this scene is still live, and without the flag a fast walk can roll twice into
the same transition.

The map names the background rather than letting `battle.tscn` keep its own
default. Nothing changes visually today — it is the same art — but it is what
lets a dungeon fight later name a different backdrop without `battle.gd` needing
to know where the party is standing.

## The round trip

```
map.gd  _roll_encounter()
        └─ Transitions.push(battle.tscn, { enemies, background })
              map is hidden and paused — its state survives untouched

battle.gd  on_battle_ended(party_won)
        └─ VICTORY / DEFEAT banner, held 1.6s
        └─ Transitions.pop({ party_won, xp })

map.gd  _on_scene_resumed(result)
        └─ map visible and running again, player unmoved
```

Nothing is saved and restored on the way through. `push()` leaves the map
loaded, so the player's position, facing, terrace band and the landmark under
their feet are all simply still there.

---

## What this needed from `core/Transitions.gd`

Three changes. All of them are general to the scene stack rather than special
cases for the map, which is the point — the dungeon will push the same battle
scene later and needs none of this rebuilt.

### The return leg

`push()` carried a payload in; nothing carried a result out. `INTEGRATION_SEAMS.md`
had this listed as **MISSING** with the options open. **Decided: `pop(result)`
plus a signal**, over the other candidate on the table (an M2 dungeon manager
owning the whole sequence). This way the map and the fight stay ignorant of each
other.

| Added | What it does |
|---|---|
| `pop(result := {})` | Carries a dictionary down to the scene underneath |
| `scene_resumed(result: Dictionary)` | Signal, emitted after the pop completes |
| `result() -> Dictionary` | The last result, for anything not connected at the time |
| `can_pop() -> bool` | Whether there is anything underneath to go back to |

```gdscript
# the leaving scene
Transitions.pop({ "party_won": true, "xp": 30 })

# the scene underneath, connected once in _ready()
Transitions.scene_resumed.connect(_on_scene_resumed)

func _on_scene_resumed(result: Dictionary) -> void:
    if Transitions.current() != self:
        return          # a different scene resumed, not us
```

**Connect; do not `await push()`.** `push()` returns as soon as the pushed scene
is *up*, not when it is over — so the line after an awaited push runs while the
fight is still on screen. This is the one seam that reads wrong at a glance.

The identity check is not optional either: `scene_resumed` reaches every
listener on every pop, so a scene that stacks more than one thing has to confirm
the pop was its own.

**The battle result shape:** `{ "party_won": bool, "xp": int }`, where `xp` is
the sum of `xp_value` over the enemies that died.

### Stack adoption

A scene run on its own — **F6** in the editor, or as `main_scene` — is in the
tree but *not* on the stack. Its first `push()` therefore landed on top of a
scene the stack had never heard of, and `pop()` then refused to leave it, because
it refuses to pop the last entry.

`push()` now **adopts** the running scene as the bottom entry. It is not
reparented: hiding and pausing work wherever it sits, and moving it would reset
it.

This is what made the encounter safe to switch on at all. The comment that used
to sit in `map.gd` — that pushing "would strand the player in a screen with no
way home" — was exactly right, and adoption is what retired it.

### The camera handoff

**The bug that made characters and enemies invisible in the battle scene.**

A `Camera2D` sets the viewport's canvas transform, and that transform survives
its scene being hidden and paused. The map camera stayed current with the
viewport offset at `(-976, -1768)`, so the fight was drawn through it:

```
                         world          on screen (viewport is 1280x720)
    hero0   Zeph        (460, 468)      (-516, -1300)
    hero1   Ignis       (295, 588)      (-681, -1180)
    hero2   Aria        (287, 395)      (-689, -1373)
    enemy0              (859, 412)      (-117, -1356)
```

Every combatant off screen, up and to the left. Background and HUD were fine
throughout, because both are `CanvasLayer`s and carry their own transform —
which is why the symptom pointed at the sprites and not at the camera.

Fixed in `Transitions`, **not** by adding a `Camera2D` to `battle.tscn`, because
it is a property of the stack rather than of one scene: anything pushed over a
scene with a camera would have hit it.

- `push()` releases the viewport — disables the current camera and resets the
  canvas transform to identity — **before** the incoming scene is instanced. The
  order matters: a `Camera2D` only claims a *free* viewport, so a scene bringing
  its own camera would otherwise never get to use it.
- `pop()` hands it back, then calls `force_update_scroll()` so the restored
  scene is correct on the *first* frame. A camera that is not moving may have no
  next update, which would otherwise leave the uncovered map drawn at identity.
- Cameras are tracked in an array kept parallel to the scene stack, alongside
  the payloads.

A pushed scene still needs no code of its own: with no camera it draws at its
authored coordinates, which is exactly how it looks run standalone. `battle.tscn`
has no camera and did not get one.

---

## What this needed from the battle screen

### It ends, and it leaves

`on_battle_ended()` shows a **VICTORY** / **DEFEAT** banner, holds it 1.6 s, then
pops with the result. A fight launched on its own has nothing underneath, so it
checks `Transitions.can_pop()` and holds the banner instead — **F6** on
`battle.tscn` still works exactly as it did.

### Placeholder creatures are clickable

A creature with no idle art keeps its red `Placeholder` block — and that block,
being a `ColorRect`, was swallowing every click before the `ClickArea` under it
could hear one. **Critter and Brute could not be attacked at all**; Wisp could,
purely because it has art and `_dress()` therefore hides its placeholder.

Fixed with `mouse_filter = MOUSE_FILTER_IGNORE` on `Placeholder` in `hero.tscn`
and `enemy.tscn`, and on `HpBar` in `enemy.tscn`. Full explanation under
[Godot traps this cost time on](#godot-traps-this-cost-time-on).

Verified by pushing a fight containing one creature with art and one without,
firing a real `InputEventMouseButton` at the centre of each collision box and
watching for `ClickArea.input_event`: before, `art=true placeholder=false`;
after, both true.

### Enemy HUD panels are built per fight

`battle.tscn` had exactly **two**, hardcoded as `MudlingPanel` and `WispPanel`
with static action bars. Fine for a fixed demo; wrong the moment an encounter
rolls its own pack.

`battle.gd` now instances `ui/hud/enemy_panel.tscn` once per enemy and fills in
the name. The two authored panels and their two `StyleBoxFlat` sub-resources are
gone from the scene, and the `EnemyPanels` column was grown (bottom offset
193 → 375) since it was sized around exactly two.

The panel's action bar is live now rather than a placeholder, matching the HP bar
that was already wired. Before an enemy's first turn its budget is still empty,
so the bar shows **full** rather than `0/0` — which would read as a stunned enemy
instead of a waiting one.

---

## What a fight does not do yet

All deliberate, all noted in `map.gd` where the result comes back.

- **`xp` is reported and dropped.** `Character` has no experience pool —
  `level_up()` is called outright — so there is nowhere to put it. The number is
  already in the result, so levelling will find it waiting.
- **Losing costs nothing.** `BattleState` rebuilds every hero at full HP from
  `Character.max_hp()` at the start of each fight, so damage does not survive a
  battle. A defeat is a delay, not a setback. Whether that becomes a game over,
  a respawn point, or wounds that persist is an open design decision — flagged
  rather than invented.

## Encounter art

All three encounter creatures are dressed. No placeholders left in a rolled
fight.

| Creature | Sheet | Grid | Frames |
|---|---|---|---|
| Wisp | `enemy_wisp_bidle.png` | 512 × 64, one row | 8 |
| Critter | `enemy_critter_bidle.png` | 192 × 256, 3 × 4 | 12 |
| Brute | `enemy_brute_bidle.png` | 256 × 256, 4 × 4 | **14** — two blank cells skipped |

**Wiring art in is a rename, not a code change.** `SpriteSheet.find_idle()`
resolves a creature's display name to `<prefix>_<slug>_bidle.png` — the
convention in `NAMING.md` — so the Critter and Brute sheets only had to be
renamed from their generator filenames. `_dress()` then slices them with
`strip_auto()` and hides the placeholder. Nothing in `battle.gd`, `enemy.tscn`
or the encounter pool was touched.

The Brute's sheet is the case `strip_auto()` exists for: a 4 × 4 grid holding 14
poses, the last two cells empty. Those are skipped rather than played as a
two-frame stutter, and the count comes from the art rather than from a number
written down anywhere.

The three heroes who actually fight are **Zeph** (Front), **Ignis** (Center) and
**Aria** (Back1); Craig is benched at `BACK2`. All three have art, which is why
only the enemy side shows placeholders.

---

## Verified

Combat needs a human at the action menu, so the loop was driven through a
throwaway harness rather than played:

- Adoption put the caller at the bottom of the stack; it was hidden while the
  fight was up; `battle.gd` popped itself on victory; the result arrived as
  `{ party_won: true, xp: 30 }` — 10 + 12 + 8, the `xp_value` of the Critter,
  Brute and Wisp that had been rolled.
- Re-run through the **real map** after the camera fix: every combatant inside
  the 1280 × 720 viewport during the fight, and on the way back the map's camera
  current again with its transform bit-identical to before the push — the player
  still dead centre at (640, 360).
- All three encounter creatures come up in real art and take a click:
  `Critter dressed=true frames=12`, `Brute dressed=true frames=14`,
  `Wisp dressed=true frames=8`, all three `clickable=true`.
- No new engine warnings; the five pre-existing integer-division warnings are
  unchanged.

The first harness could **not** have caught the camera bug: it had no camera of
its own, so it ran at identity transform and everything looked correct. That was
a real gap, and it is why the second pass went through the actual map scene.
