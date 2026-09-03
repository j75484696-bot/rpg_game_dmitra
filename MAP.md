# The overworld map

`scenes/map/map.tscn` + `map.gd`. A walled hilltop settlement, **100 × 80 tiles
at 32px** (3200 × 2560 px), around 15,000 painted cells across three elevation
bands. Built from the `TX` tileset pack in the style of the team's
`Scene Overview.png` reference.

This doc has authority over **how the map scene is put together** — the bands,
what draws over what, and how the player moves between levels. Where it
disagrees with a screenshot, the scene wins.

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

Spawn is tile **(50, 66)**, on the southern approach. The camera is limited to
the map bounds.

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

`DungeonEntrance` still needs nothing further; `Interactables/DungeonEntrance`
has its shape.

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

Four things that fail **silently**, so they cost an afternoon each.

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
| The dungeon entrance | `battle.gd` driving a `BattleState` and popping on `battle_ended` |
| The encounter roll | The same — pushing now strands the player in a screen with no way home |
| Shrine and Kneeling Stones | Nothing. They open nothing by design; they are places to walk to |

The project's main scene is still `scenes/battle/battle.tscn`, so open
`scenes/map/map.tscn` and press **F6** to walk the map.
