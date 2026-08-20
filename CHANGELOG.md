# Changelog

All notable changes to the vertical slice. Newest first.

Updated on every push. If you push without adding an entry, the next person
has to read the diff to find out what moved.

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
| Tile / sprite / base resolution numbers | Designer 2 can't size tiles; collision shapes left null | Team |
| Who is the party leader? | 10 overworld sprite files Designer 1 can't start | Team |
| What do the 5 skill nodes do? | Skill tree can't be wired | Team |
| Enemy representation (class + seam) | `_roll_encounter()`, `_build_enemies()` | Coder A |
| Combat signals — the seams doc has none | All battle UI turn/damage/death reactions | Coder A + B |
| Prereq logic in `unlock_skill()` | Gated skill tree is enforced UI-side today | Coder A |
| `main_scene` is unset in `project.godot` | Nothing bootstraps the transition stack | Coder B |

### Known inconsistencies
- `STRUCTURE.md` contradicts itself on menus: `scenes/` is labelled "map, battle,
  menus" while `ui/menus/` is "Full-screen screens".
- `.gd.uid` files are committed for `core/` and `map.gd` but not the three newest
  scripts — the editor generates them on open. Either commit all or ignore all.
- The battle reference shows one shared action menu and a global burst gauge;
  the build uses per-hero menus and a per-hero ult bar (matching
  `COMBAT_DATA.md`).
- `git remote` still points at `nabiasjones/` — the project moved to
  `nabiasjones1/`. Pushes work via redirect for now.
