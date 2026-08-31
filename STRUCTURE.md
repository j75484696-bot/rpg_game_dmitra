# Project Structure

2D RPG, Godot 4.7, GDScript. Vertical slice: one dungeon, four heroes, six
enemies and a boss.

This file describes **where things live**. It does not define signatures, art
filenames, or balance numbers — see [Which doc governs what](#which-doc-governs-what).

## Layout

```
res://
├── core/                     Shared game systems.
│   ├── Elements.gd           (autoload) element rules, type chart, stat grades
│   ├── Party.gd              (autoload) the 4-hero roster, loaded from data/
│   ├── Inventory.gd          (autoload) party-wide gold + items
│   ├── Targeting.gd          (autoload) enemy target selection + Guard
│   ├── Transitions.gd        (autoload) scene stack, fade, push payloads
│   ├── Combat.gd             (autoload) ALL damage and healing math
│   ├── Actions.gd            (autoload) action economy + the guard board
│   ├── EnemyAI.gd            (autoload) what an enemy does on its turn
│   ├── Character.gd          class_name — one hero's data + progression
│   ├── CreatureRating.gd     class_name — one enemy's identity, as ratings
│   ├── ActionBudget.gd       class_name — one combatant's actions, one turn
│   ├── BattleState.gd        class_name — one fight, start to finish
│   └── SpriteSheet.gd        class_name — slices a strip into SpriteFrames
├── tools/                    Editor-run scripts, not shipped
│   └── gen_frame.gd          regenerates assets/ui/ui_panel.png
├── data/                     Authored game data (.tres)
│   ├── heroes/               ignis, aria, zeph, craig — Character instances
│   └── enemies/              7 CreatureRating instances (6 + boss)
├── scenes/                   Gameplay scenes
│   ├── map/                  overworld traversal
│   └── battle/               the fight screen: battle, hero, enemy,
│                              damage_number
├── ui/                       UI scenes and themes
│   ├── hud/                  In-battle overlays (hero_panel.tscn)
│   ├── menus/                Full-screen screens
│   │                         main_menu, skill_tree, shop, prep, victory/defeat
│   └── themes/               .theme resources, shared styleboxes
├── assets/                   All art and audio (see NAMING.md for filenames)
│   ├── sprites/              Characters, props, backgrounds, VFX
│   ├── tilesets/             Tileset images + their configured .tres
│   ├── ui/                   UI chrome and icons
│   ├── audio/music/          bgm_*.ogg
│   ├── audio/sfx/            sfx_*.ogg
│   └── fonts/
└── addons/                   Third-party editor plugins
```

`assets/` is still empty — art production is waiting on the base-resolution
decision.

## Where does a new file go?

**Shared systems go in `core/`.** Anything the whole game calls — combat rules,
progression, party state, inventory, targeting, scene flow — lives here as an
autoload or a `class_name` class.

**Logic in `core/`, numbers in `data/`.** The class defines behaviour; the
authored instances are data files:

```
core/Character.gd            class_name Character extends Resource
data/heroes/ignis.tres       an instance of it

core/CreatureRating.gd       class_name CreatureRating extends Resource
data/enemies/mudling.tres    an instance of it
```

Never hardcode a stat in a script. Hero stat blocks, enemy ratings, item and
spell definitions, shop prices and drop tables all belong in `data/` —
`COMBAT_DATA.md` is the source for their values.

**Gameplay scenes go in `scenes/`; full-screen screens go in `ui/menus/`.**
A scene and its script share a name and sit together:
`scenes/battle/battle.tscn` ↔ `scenes/battle/battle.gd`.

| Kind of screen | Home | Examples |
|---|---|---|
| The player moves or fights in it | `scenes/<feature>/` | map, battle |
| Full-screen menu or management screen | `ui/menus/` | main menu, skill tree, shop, prep menu, victory/defeat |
| Overlay drawn on top of gameplay | `ui/hud/` | hero panel, damage numbers |

The **shop is an overworld location** — the player walks to it on the map, so
it's a full-screen screen pushed from `map.gd`, the same shape as the dungeon
entrance. It lives in `ui/menus/` because it's a screen, not a place you move
around in.

**Art and audio go in `assets/`,** filed by category:

| Filename prefix | Home |
|---|---|
| `hero_` `enemy_` `boss_` | `assets/sprites/characters/` |
| `prop_` | `assets/sprites/props/` |
| `bg_` | `assets/sprites/backgrounds/` |
| `vfx_` | `assets/sprites/vfx/` |
| `tile_` | `assets/tilesets/` |
| `ui_` | `assets/ui/` |
| `icon_` | `assets/ui/icons/` |
| `bgm_` | `assets/audio/music/` |
| `sfx_` | `assets/audio/sfx/` |

Subfolders get created when the first asset of that kind arrives — don't
pre-make empty ones.

## Editing across folders

Any file may edit any other. There is no ownership boundary between `core/`
and the rest of the project.

That only works under one condition: **when you change a public signature,
update `INTEGRATION_SEAMS.md` in the same commit.** That file is how everyone
else finds out what exists. A signature that isn't in it is one nobody can
rely on.

> ### The one hard rule
> **All damage and healing math lives in `core/Combat.gd`.** Call
> `Combat.melee()` / `spell()` / `item()` / `heal()` from both combat code and
> UI. The moment two places calculate damage, they drift, and the resulting
> bug — a number on screen that doesn't match the number applied — is
> miserable to track down.

## Naming

- **`core/` scripts are PascalCase**, named for the autoload or class they
  define (`Elements.gd` → autoload `Elements`). `INTEGRATION_SEAMS.md` and
  `COMBAT_DATA.md` reference these filenames directly, so they're fixed.
- **Scenes, scene scripts, and folders are snake_case**: `battle_hud.tscn`.
- **Data files are snake_case**, named for what they define: `frostbite_imp.tres`.
- **Art and audio follow `NAMING.md`** — lowercase, underscores, zero-padded
  frame numbers. That spec wins for anything under `assets/`.
- `class_name` and scene-tree node names stay PascalCase.

## Autoload order

Registered in `project.godot`, and the order is load-bearing:

```
Elements → Party → Inventory → Targeting → Transitions → Combat → Actions → EnemyAI
```

- `Party` builds its roster using `Elements`, so `Elements` must come first.
- `EnemyAI` delegates its action-count formula to `Actions`, so `Actions` must
  come before it.
- `Inventory` has no dependencies of its own. It sits early because anything
  that consumes an item or spends gold will want it already up.

`Character.gd`, `CreatureRating.gd`, `ActionBudget.gd` and `BattleState.gd` are
deliberately **not** autoloaded — they declare `class_name`, which already
registers them globally, and doing both collides.

## Which doc governs what

| Doc | Authority over |
|---|---|
| `INTEGRATION_SEAMS.md` | Public function signatures, signals, and the combatant dictionary shape. |
| `COMBAT_DATA.md` | Stats, ratings, growth, enemies, items, spells, drop tables, the type chart, prices. |
| `NAMING.md` | Art and audio filenames, formats, dimensions. |
| `STRUCTURE.md` (this) | Which folder a file belongs in. |
| `CHANGELOG.md` | What changed, and the open decisions blocking work. |

Where two disagree, the more specific one wins — this file never overrides a
signature in the seams doc or a number in the combat doc.

> `NAMING.md` currently has no Dimensions section; it was removed pending a
> team decision on tile/sprite/base resolution. It keeps authority over
> dimensions for when that decision lands.

## Leftover scaffolding

`entities/`, `systems/`, `globals/`, `world/`, and `resources/` are from an
earlier layout the project didn't adopt. They're empty and unused; the
`data/` + `core/` split above replaced them. Safe to delete.

`scenes/skill_tree/` is now empty too — the skill tree moved to `ui/menus/`.
