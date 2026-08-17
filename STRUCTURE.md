# Project Structure

2D RPG, GDScript, hybrid layout: shared raw assets live centrally, gameplay
things are grouped by feature.

```
res://
├── addons/                 Third-party editor plugins (untouched by us)
├── assets/                 Raw imported media, shared across features
│   ├── audio/
│   │   ├── music/          Looping tracks
│   │   └── sfx/            One-shots
│   ├── fonts/
│   ├── sprites/            Shared/atlas art not owned by one entity
│   └── tilesets/           Tileset images + their configured .tres
├── entities/               Anything that exists in the world and acts
│   ├── enemies/
│   ├── npcs/
│   └── player/
├── globals/                Cross-cutting autoload singletons
├── resources/              Authored data files (.tres instances)
│   ├── items/
│   └── stats/
├── systems/                Self-contained gameplay systems
│   ├── audio/
│   ├── combat/
│   ├── inventory/
│   ├── save/
│   ├── settings/
│   └── stats/
├── ui/
│   ├── hud/                In-game overlays
│   ├── menus/              Full-screen screens
│   └── themes/             .theme resources and shared styleboxes
└── world/
    └── levels/             Playable maps
```

## Where does a new file go?

**Entities keep everything together.** A new enemy gets one folder under
`entities/enemies/` holding its scene, script, and its own art:

```
entities/enemies/slime/
├── slime.tscn
├── slime.gd
└── slime.png
```

Art goes in `assets/sprites/` only when more than one entity uses it.

**`systems/` holds logic; `resources/` holds data.** The class definition
lives with its system, the authored instances live in `resources/`:

```
systems/inventory/item.gd          class_name Item extends Resource
resources/items/health_potion.tres   an instance of it
```

**`globals/` vs `systems/`.** If a singleton belongs to one system, it stays
in that system's folder (`systems/audio/audio_manager.gd`). `globals/` is only
for things with no single owner — event bus, scene manager, game state,
constants. When in doubt, start it inside a system and promote it later.

## Conventions

- **snake_case** for all files and folders; `PascalCase` for `class_name` and
  nodes in the scene tree.
- A scene and its script share a name: `player.tscn` ↔ `player.gd`.
- `.gitkeep` files are placeholders — delete one once its folder has real
  content.
