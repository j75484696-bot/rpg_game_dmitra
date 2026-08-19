# Project Structure

2D RPG, Godot 4.7, GDScript. Vertical slice: one dungeon, four heroes, three
enemies and a boss.

This file describes where things live. It does **not** define signatures, art
filenames, or balance numbers — see [Which doc governs what](#which-doc-governs-what).

## Layout

```
res://
├── core/                   Shared game systems. The Coder A / Coder B boundary.
│   ├── Elements.gd         (autoload) element rules, type chart, stat grades
│   ├── Party.gd            (autoload) the 4-hero roster
│   ├── Targeting.gd        (autoload) enemy target selection + Guard
│   └── Character.gd        class_name — one combatant's data + progression
├── data/                   Authored game data (.tres / .json): heroes,
│                           enemies, items, spells, drop tables
├── scenes/                 Gameplay scenes — map, battle, menus
├── ui/                     UI scenes and themes
│   ├── hud/                In-battle overlays
│   ├── menus/              Full-screen screens
│   └── themes/             .theme resources, shared styleboxes
├── assets/                 All art and audio (see NAMING.md for filenames)
│   ├── sprites/            Characters, props, backgrounds, VFX
│   ├── tilesets/           Tileset images + their configured .tres
│   ├── ui/                 UI chrome and icons
│   ├── audio/music/        bgm_*.ogg
│   ├── audio/sfx/          sfx_*.ogg
│   └── fonts/
└── addons/                 Third-party editor plugins
```

Only `core/` has files today. Everything else is scaffolding waiting on its
first real file.

## Where does a new file go?

**Shared systems go in `core/`.** Anything the whole game calls — combat rules,
progression, party state, targeting — lives here as an autoload or a
`class_name` class. This folder is a contract boundary, not just a folder; see
below.

**Logic in `core/`, numbers in `data/`.** The class defines behaviour; the
authored instances are data files:

```
core/Character.gd            class_name Character extends Resource
data/heroes/ignis.tres       an instance of it
```

Hero stat blocks, enemy stat blocks, item and spell definitions, and drop
tables all belong in `data/` — `COMBAT_DATA.md` is the source for their values.

**Scenes go in `scenes/`, UI scenes in `ui/`.** A scene and its script share a
name and sit together: `scenes/battle/battle.tscn` ↔ `scenes/battle/battle.gd`.
Group by feature, so everything about the battle screen is in one folder.

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

## The `core/` boundary

`core/` is where the two halves of the project meet, and it has a rule that
matters more than any layout choice here:

> **UI/scene code CALLS into `core/` but NEVER edits files in it.** New shared
> functions get added to `INTEGRATION_SEAMS.md` first, agreed, then built.

So `core/` is Coder A's; `scenes/`, `ui/`, and `assets/` are Coder B's. If
scene code needs something `core/` doesn't expose, that's a doc change first,
not a quiet edit. `INTEGRATION_SEAMS.md` is the full list of what's callable.

## Naming

- **`core/` scripts are PascalCase**, named for the autoload or class they
  define (`Elements.gd` → autoload `Elements`). `INTEGRATION_SEAMS.md` and
  `COMBAT_DATA.md` reference these filenames directly, so they're fixed.
- **Scenes, scene scripts, and folders are snake_case**: `battle_hud.tscn`.
- **Art and audio follow `NAMING.md`** — lowercase, underscores, zero-padded
  frame numbers. That spec wins for anything under `assets/`.
- `class_name` and scene-tree node names stay PascalCase.

## Autoload order

Registered in `project.godot`, and the order is load-bearing:

```
Elements → Party → Targeting
```

`Party` builds its roster using `Elements`, so `Elements` must come first.
`Character.gd` is deliberately **not** autoloaded — it declares `class_name`,
which already registers it globally, and doing both collides.

## Which doc governs what

| Doc | Authority over |
|---|---|
| `INTEGRATION_SEAMS.md` | Public function signatures. The two-coder contract. |
| `COMBAT_DATA.md` | Stats, growth, enemies, items, spells, drop tables. |
| `NAMING.md` | Art and audio filenames, formats, dimensions. |
| `STRUCTURE.md` (this) | Which folder a file belongs in. |

Where two disagree, the more specific one wins — this file never overrides a
signature in the seams doc or a number in the combat doc.

## Leftover scaffolding

`entities/`, `systems/`, `globals/`, `world/`, and `resources/` are from an
earlier layout that the project didn't adopt. They're empty and unused; the
`data/` + `core/` split above replaced them. Safe to delete.
