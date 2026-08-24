# Depths Of Ashenveil

2D turn-based RPG vertical slice. **Godot 4.7**, GDScript.

One dungeon, four heroes (three fight at a time), three dungeon enemies, three
random-encounter enemies, and one boss — Ashfang.

---

## Getting the project

Clone it:

```sh
git clone https://gitlab.com/nabiasjones1/rpg_game_dmitra.git
cd rpg_game_dmitra
```

If you already have a local copy pointed at the old namespace, retarget it —
the project moved, and the old URL only resolves via GitLab's redirect:

```sh
git remote set-url origin https://gitlab.com/nabiasjones1/rpg_game_dmitra.git
git remote -v
```

Then open the project folder in Godot 4.7 (`Import` → pick `project.godot`).

### Working on a change

```sh
git switch -c my-branch
# ...edit...
git add -A
git commit -m "short description of what moved"
git push -u origin my-branch
```

Open a merge request from the branch. Add a `CHANGELOG.md` entry in the same
commit — if you push without one, the next person has to read the diff to work
out what changed.

---

## Layout

```
core/      Shared game systems (autoloads + class_name classes)
data/      Authored numbers: heroes, enemies, items, spells, drop tables
scenes/    Gameplay scenes — map, battle
ui/        UI scenes, HUD, menus, themes
assets/    Art and audio
```

Full detail, and which folder a new file belongs in, is in
[`STRUCTURE.md`](STRUCTURE.md).

**Logic in `core/`, numbers in `data/`.** Don't hardcode a stat in a script.

---

## The docs, and which one wins

Where two docs disagree, **the more specific one wins**.

| Doc | Authority over |
|---|---|
| [`INTEGRATION_SEAMS.md`](INTEGRATION_SEAMS.md) | Public function signatures and signals |
| [`COMBAT_DATA.md`](COMBAT_DATA.md) | Stats, growth, enemies, items, spells, drop tables |
| [`NAMING.md`](NAMING.md) | Art and audio filenames + formats |
| [`STRUCTURE.md`](STRUCTURE.md) | Which folder a file belongs in |
| [`CHANGELOG.md`](CHANGELOG.md) | What changed, and the open decisions blocking work |
| [`GITLAB_WORKPLAN.md`](GITLAB_WORKPLAN.md) | Milestones, labels, who owns which task |

All damage and healing math lives in `core/Combat.gd` and nowhere else — call
`Combat.melee()` / `spell()` / `item()` / `heal()` so combat and UI can never
disagree about a number.

---

## Current state

Core systems are in: `Elements`, `Party`, `Targeting`, `Transitions`, `Combat`,
`Actions`, `EnemyAI` (autoloads, in that order), plus `Character`,
`ActionBudget` and `BattleState` as `class_name` classes.

Scene skeletons exist for map, battle, skill tree and main menu — layout only,
gameplay wiring is in progress.

**Before starting work, read the "Open decisions" table at the bottom of
[`CHANGELOG.md`](CHANGELOG.md).** Several tasks are blocked on team calls that
haven't been made yet (base resolution, party leader, what the 5 skill nodes
do), and picking one yourself silently is worse than waiting.
