# 🦊 GitLab Work Plan — Vertical Slice

Everything below maps 1:1 to the production plan. Create the **labels** first, then the **milestones**, then import the issues.

> ⚠️ GitLab's CSV issue import only reads **title** + **description**. So the CSV carries the milestone/labels/assignee *inside each description as text*. After importing, select issues on the board and bulk-apply the real labels + milestone. The full mapping is in the tables here so nothing is lost.


## 🏷️ Labels (create these first)

Labels use `scope::name` grouping. If you're on GitLab Free the `::` is just a naming convention; on Premium they become scoped (one-per-scope enforced). Colors are suggestions — paste the hex into GitLab's label color box.

| Label | Color | Meaning |
| --- | --- | --- |
| type::setup | #6699cc | Project/infra plumbing, no gameplay |
| type::feature | #009966 | New gameplay/system to build |
| type::asset | #cc338b | Art / sprite / background to create |
| type::audio | #f39c12 | Music or SFX to source/create |
| type::bug | #dc143c | Something broken to fix |
| type::qa | #8b0000 | Playtesting / balance / regression |
| type::design | #8e44ad | Data tables, style guide, specs |
| team::code | #1f78d1 | Coder A or Coder B |
| team::art | #e67e22 | Sprite / environment / UI artists |
| team::audio | #c39bd3 | Whoever sources audio |
| team::design | #9b59b6 | Design/spec work |
| team::qa | #16a085 | Playtester |
| area::infra | #95a5a6 | Repo, autoloads, build, transitions |
| area::combat | #e74c3c | The turn-based fight |
| area::dungeon | #d35400 | Encounter sequence + prep menu |
| area::map | #27ae60 | Overworld traversal |
| area::progression | #2980b9 | XP, levels, skill tree, spells |
| area::items | #7f8c8d | Consumables, drops, equipment |
| area::ui | #f1c40f | On-screen panels/buttons/bars |
| area::menu | #34495e | Main menu, victory, defeat screens |
| area::characters | #e84393 | Hero + enemy + boss sprites |
| area::environment | #6ab04c | Tilesets, backgrounds, map build |
| area::audio | #f0932b | BGM + SFX assets |
| priority::must | #cc0000 | P1 — vertical slice fails without it |
| priority::should | #ed9121 | P2 — important, cut only if desperate |
| priority::nice | #808080 | P3 — stretch, skip if short on time |
| status::todo | #c0c0c0 | Not started |
| status::doing | #4caf50 | In progress |
| status::review | #3f51b5 | In merge request / review |
| status::blocked | #000000 | Waiting on something |


## 🎯 Milestones (create these second)

| Milestone | When | Goal |
| --- | --- | --- |
| M0 · Setup | Day 1 | Repo, autoloads, style guide, naming spec, scene skeletons |
| M1 · Core Combat | Day 2-3 | One fully playable fight: positions, guard, elements, actions |
| M2 · Dungeon Loop + Map | Day 3-4 | Walk map, enter dungeon, fight the sequence, reach boss |
| M3 · Content & Progress | Day 5 | XP, skill tree, 6 spells, 4 items, drops — loop closed |
| M4 · Polish & Bug Bash | Day 6 | Full-loop playtest, fixes, juice, menus, victory/defeat |
| M5 · Buffer & Build | Day 7 | Export, final playtest, tag release |


## 📋 Work Items by Milestone


### M0 · Setup

| Work Item | Assignee | Labels |
| --- | --- | --- |
| Create GitLab repo + commit .gitignore first | Coder A | type::setup, team::code, area::infra, priority::must |
| Set folder structure + register autoloads | Coder A | type::setup, team::code, area::infra, priority::must |
| Import core systems (Elements/Character/Party/Targeting) | Coder A | type::setup, team::code, area::infra, priority::must |
| Write Integration Seams doc | Coder A | type::design, team::code, area::infra, priority::must |
| Build empty scene skeletons + transition manager | Coder B | type::feature, team::code, area::infra, priority::must |
| Agree + document style guide | Designers | type::design, team::design, area::infra, priority::must |
| Agree + document asset naming spec | Designers | type::design, team::design, area::infra, priority::must |
| Style-test sprite: Ignis | Designer 1 | type::asset, team::art, area::characters, priority::must |
| Style-test: grass tileset block-out | Designer 2 | type::asset, team::art, area::environment, priority::must |
| Combat screen layout mockup + font pick | Designer 3 | type::design, team::art, area::ui, priority::must |
| Set up GitLab issue board + create labels | Playtester | type::setup, team::qa, area::infra, priority::must |
| Draft enemy + item data tables | Playtester | type::design, team::qa, area::items, priority::should |


### M1 · Core Combat

| Work Item | Assignee | Labels |
| --- | --- | --- |
| Combat state machine (prep -> turns -> win/lose) | Coder A | type::feature, team::code, area::combat, priority::must |
| Turn order by Speed | Coder A | type::feature, team::code, area::combat, priority::must |
| Action system (stamina actions + 4 action types) | Coder A | type::feature, team::code, area::combat, priority::must |
| Damage calc (ATT/MAG - DEF flat x element matchup) | Coder A | type::feature, team::code, area::combat, priority::must |
| Guard action (redirect hit -40%) | Coder A | type::feature, team::code, area::combat, priority::must |
| Enemy AI (threat targeting + attack) | Coder A | type::feature, team::code, area::combat, priority::must |
| Ultimate meter (fills on dealt + taken) + placeholder ult | Coder A | type::feature, team::code, area::combat, priority::should |
| Combat scene layout + hero panels | Coder B | type::feature, team::code, area::ui, priority::must |
| Action menu buttons (melee/spell/item/guard) | Coder B | type::feature, team::code, area::ui, priority::must |
| Target picker | Coder B | type::feature, team::code, area::ui, priority::must |
| Enemy display + HP bars | Coder B | type::feature, team::code, area::ui, priority::must |
| Turn indicator | Coder B | type::feature, team::code, area::ui, priority::should |
| Damage feedback (numbers + flash + shake) | Coder B | type::feature, team::code, area::ui, priority::should |
| 4 hero battle sprites + hurt frames | Designer 1 | type::asset, team::art, area::characters, priority::must |
| 3 enemy sprites | Designer 1 | type::asset, team::art, area::characters, priority::must |
| Finish grass tileset | Designer 2 | type::asset, team::art, area::environment, priority::must |
| Dungeon combat background | Designer 2 | type::asset, team::art, area::environment, priority::must |
| Combat UI frame + bar graphics + action buttons | Designer 3 | type::asset, team::art, area::ui, priority::must |
| Source battle BGM + core SFX | Designer 3 | type::audio, team::audio, area::audio, priority::must |
| Playtest combat build + log bugs/fun notes | Playtester | type::qa, team::qa, area::combat, priority::must |


### M2 · Dungeon Loop + Map

| Work Item | Assignee | Labels |
| --- | --- | --- |
| Dungeon manager (encounter sequence + clear/wipe) | Coder A | type::feature, team::code, area::dungeon, priority::must |
| Prep menu (reorder / swap spells / item / continue) | Coder B | type::feature, team::code, area::dungeon, priority::must |
| Map movement + camera follow | Coder B | type::feature, team::code, area::map, priority::must |
| Dungeon entrance interaction | Coder B | type::feature, team::code, area::map, priority::must |
| Random encounter roll on map | Coder B | type::feature, team::code, area::map, priority::should |
| Boss sprite (+ optional lunge frame) | Designer 1 | type::asset, team::art, area::characters, priority::must |
| Assemble map in Godot (tiles + props + marker) | Designer 2 | type::asset, team::art, area::environment, priority::must |
| Dungeon map marker/icon | Designer 2 | type::asset, team::art, area::environment, priority::must |
| Prep-menu UI | Designer 3 | type::asset, team::art, area::ui, priority::should |
| Source overworld BGM + victory jingle | Designer 3 | type::audio, team::audio, area::audio, priority::should |
| Playtest map + dungeon flow + log | Playtester | type::qa, team::qa, area::dungeon, priority::must |


### M3 · Content & Progress

| Work Item | Assignee | Labels |
| --- | --- | --- |
| XP award + level-up wiring + popup | Coder A | type::feature, team::code, area::progression, priority::must |
| Wire 6 spells (data-driven) + equip up to 3 | Coder A | type::feature, team::code, area::progression, priority::must |
| 4 consumables (potion/molotov/bomb/grenade) | Coder A | type::feature, team::code, area::items, priority::must |
| Enemy drop pool + roll on clear | Coder A | type::feature, team::code, area::items, priority::should |
| 1-2 equippable stat items | Coder A | type::feature, team::code, area::items, priority::nice |
| Skill tree screen (5 nodes) + spend point | Coder B | type::feature, team::code, area::progression, priority::must |
| Show before/after stat number on spend | Coder B | type::feature, team::code, area::progression, priority::should |
| Boss hurt frame + finish | Designer 1 | type::asset, team::art, area::characters, priority::should |
| Menu + victory/defeat backdrops | Designer 2 | type::asset, team::art, area::environment, priority::must |
| Spell icons x6 + skill icons x5 + item icons x4 | Designer 3 | type::asset, team::art, area::ui, priority::must |
| Title logo | Designer 3 | type::asset, team::art, area::menu, priority::should |
| Spell VFX x4 (fire/water/wind/earth) | Designer 3 | type::asset, team::art, area::combat, priority::should |
| Source level-up + victory SFX | Designer 3 | type::audio, team::audio, area::audio, priority::should |
| Balance pass (boss beatable? point feels good?) | Playtester | type::qa, team::qa, area::progression, priority::must |


### M4 · Polish & Bug Bash

| Work Item | Assignee | Labels |
| --- | --- | --- |
| Full-loop team playtest | Everyone | type::qa, team::qa, area::combat, priority::must |
| Fix top bugs from board | Coders | type::bug, team::code, area::combat, priority::must |
| Balance tuning from playtest notes | Coder A | type::bug, team::code, area::combat, priority::should |
| Juice: hover states, transitions, SFX hookups | Coder B | type::feature, team::code, area::ui, priority::should |
| Main menu (new game / quit + bg + bgm) | Coder B | type::feature, team::code, area::menu, priority::must |
| Victory / defeat screens | Coder B | type::feature, team::code, area::menu, priority::must |
| Replace placeholder art + polish menu | Designers | type::asset, team::art, area::ui, priority::should |
| Finalize audio mix | Designer 3 | type::audio, team::audio, area::audio, priority::should |
| Regression pass (verify fixes) | Playtester | type::qa, team::qa, area::combat, priority::must |


### M5 · Buffer & Build

| Work Item | Assignee | Labels |
| --- | --- | --- |
| Export build (target platform) | Coder A | type::setup, team::code, area::infra, priority::must |
| Final playtest on exported build | Everyone | type::qa, team::qa, area::infra, priority::must |
| Fix show-stoppers only | Coders | type::bug, team::code, area::infra, priority::must |
| Tag release in GitLab | Coder A | type::setup, team::code, area::infra, priority::must |
| STRETCH: minimal save/load OR pull 1 Later item | Coders | type::feature, team::code, area::infra, priority::nice |


## 🔁 Suggested Board Columns

`To Do` → `Doing` → `In Review` (open MR) → `Bug` → `Done`. Map these to the `status::` labels or just use list columns.


## 📥 How to load this into GitLab

1. **Create labels** — Project → Manage → Labels → New label. Paste name + hex color from the Labels table.
2. **Create milestones** — Project → Plan → Milestones → New milestone (M0–M5), set the date range.
3. **Import issues** — Project → Plan → Issues → (top-right ⋮) → Import CSV → upload `gitlab_issues_import.csv`.
4. **Apply labels + milestone** — open the Issues list, tick a batch of related issues, use the right-side **Bulk edit** panel to apply the label(s) + milestone shown in this doc's tables.
5. **Assign people** — same bulk-edit panel, or per issue. Swap my role names (Coder A, Designer 1...) for real @usernames.
