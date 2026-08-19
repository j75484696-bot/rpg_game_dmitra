# 🔌 Integration Seams — The Coder Contract

**What this is:** the list of public functions the UI/scene code (Coder B) is allowed to call on the core systems (Coder A). Agree on these, and both coders build in parallel without ever opening each other's files.

**How to read it:** each entry has the **signature**, what it **returns**, and a **one-line example**.

**Status:** entries marked ⏳ are **agreed here but not implemented yet** — the signature is locked, Coder A still has to build it. Don't call one until it loses the ⏳. Everything unmarked is live in `core/` today.

**Where things live:**
- `Elements`, `Party`, `Targeting` are **autoload singletons** — call them by name from anywhere (`Elements.matchup(...)`).
- `Character` is a **class** — you get instances out of `Party.members`, then call methods on them (`Party.members[0].max_hp()`).

---

## 🧑‍🤝‍🧑 Party (autoload)

Holds the 4 active party members.

### `Party.members`
- **Type:** `Array[Character]` — the 4 heroes, index 0–3 (Ignis, Aria, Zeph, Craig).
- **Returns:** the array of Character instances.
- **Example:**
  ```gdscript
  var hero = Party.members[0]        # Ignis
  var count = Party.members.size()   # 4
  ```

### ⏳ `Party.swap_positions(index_a: int, index_b: int) -> bool`
- **Returns:** `true` if both indices are valid and the two heroes traded combat slots; `false` otherwise. Swapping rather than assigning keeps all four slots filled exactly once, which the threat calculation assumes.
- **For:** the prep menu's reorder control. This is the ONLY supported way to move a hero — don't write `character.position` directly.
- **Example:**
  ```gdscript
  if Party.swap_positions(0, 3):      # Ignis and Craig trade places
      refresh_prep_layout()
  ```

### ⏳ `Party.member_at_position(pos: int) -> Character`
- **Returns:** the hero standing in that slot, or `null` if the slot is empty. Pass a `Targeting.POS` value.
- **For:** laying out the battle screen by slot instead of by roster index.
- **Example:**
  ```gdscript
  var front = Party.member_at_position(Targeting.POS.FRONT)
  front_portrait.text = front.char_name    # "Craig"
  ```

---

## 🧍 Character (class — instances come from `Party.members`)

A single party member's data + progression.

### `stat(stat_index: int) -> int`
- **Returns:** the character's FINAL value for a stat (element base + invested points). Use the `Elements.STAT` enum for the index.
- **Example:**
  ```gdscript
  var atk = Party.members[0].stat(Elements.STAT.ATT)
  ```

### `max_hp() -> int`
- **Returns:** the character's maximum HP (shortcut for `stat(Elements.STAT.HP)`).
- **Example:**
  ```gdscript
  hp_bar.max_value = Party.members[3].max_hp()
  ```

### `max_actions() -> int`
- **Returns:** how many actions this character gets per turn (driven by Stamina).
- **Example:**
  ```gdscript
  var actions_left = Party.members[2].max_actions()
  ```

### `level_up() -> void`
- **Returns:** nothing. Raises level by 1, grants +1 unspent point, and auto-learns any new spell for that level. Caps at level 60.
- **Example:**
  ```gdscript
  Party.members[0].level_up()
  ```

### `spend_point_on_stat(stat_index: int) -> bool`
- **Returns:** `true` if a point was spent, `false` if the character had no unspent points. Pass an `Elements.STAT` value.
- **Example:**
  ```gdscript
  if Party.members[3].spend_point_on_stat(Elements.STAT.DEF):
      refresh_stat_display()
  ```

### `unlock_skill(skill_id: String) -> bool`
- **Returns:** `true` if the skill was unlocked, `false` if no points left or already unlocked.
- **Example:**
  ```gdscript
  if Party.members[1].unlock_skill("node_3"):
      mark_node_unlocked()
  ```

### `equip_spell(spell_id: String) -> bool`
- **Returns:** `true` if equipped, `false` if the spell isn't known, is already equipped, or the 3-slot limit is full.
- **Example:**
  ```gdscript
  if not Party.members[0].equip_spell("fire_2"):
      show_message("Can't equip — 3 spells max.")
  ```

### `unequip_spell(spell_id: String) -> bool`
- **Returns:** `true` if it was equipped and got removed, `false` otherwise.
- **Example:**
  ```gdscript
  Party.members[0].unequip_spell("fire_2")
  ```

### ⏳ `has_skill(skill_id: String) -> bool`
- **Returns:** `true` if that skill-tree node is already unlocked. Pairs with `unlock_skill()`.
- **For:** drawing a skill-tree node lit or dim without reading the array yourself.
- **Example:**
  ```gdscript
  node_icon.modulate = Color.WHITE if Party.members[0].has_skill("node_3") else Color.DIM_GRAY
  ```

### ⏳ `is_ult_ready() -> bool`
- **Returns:** `true` once `ult_meter` has reached 100.
- **For:** enabling the Ultimate button in the action menu.
- **Example:**
  ```gdscript
  ult_button.disabled = not Party.members[0].is_ult_ready()
  ```

### ⏳ `spend_ult() -> bool`
- **Returns:** `true` if the meter was full and has now been reset to 0; `false` if it wasn't ready (nothing changes).
- **Example:**
  ```gdscript
  if Party.members[0].spend_ult():
      play_ultimate_animation()
  ```

### ⏳ `gain_ult(damage_dealt: int, damage_taken: int) -> void`
- **Returns:** nothing. Fills the meter per COMBAT_DATA.md — **+1 per 2 damage dealt**, **+1 per 4 damage taken** — clamped to 100.
- **Note:** combat-side, called by Coder A. Listed so both halves agree on the name and the fill rates; UI never calls this.

### Read-only fields you can display
These are safe to READ for UI (don't write them directly — use the functions above):
- `char_name: String` — e.g. `"Ignis"`
- `element: int` — an `Elements.E` value; pass to `Elements.name_of()` to show text
- `level: int`
- `unspent_points: int`
- `known_spells: Array[String]` — all spells learned so far
- `equipped_spells: Array[String]` — the (max 3) currently equipped
- `unlocked_skills: Array[String]` — skill-tree nodes taken so far, e.g. `["node_1", "node_3"]`
- `position: int` — combat slot: `0` Front, `1` Center, `2` Back1, `3` Back2. Matches `Targeting.POS`. Read freely; change it only via `Party.swap_positions()`
- ⏳ `ult_meter: int` — `0`–`100`, drives the ultimate bar

- **Example:**
  ```gdscript
  var c = Party.members[0]
  name_label.text = c.char_name
  element_label.text = Elements.name_of(c.element)
  points_label.text = "Points: %d" % c.unspent_points
  ```

---

## 🌊 Elements (autoload)

Element rules, stat scale, and the type chart.

### `matchup(attacker_element: int, defender_element: int) -> float`
- **Returns:** the damage multiplier — `1.5` (super effective), `0.5` (not effective), or `1.0` (neutral). Pass `Elements.E` values.
- **Example:**
  ```gdscript
  var mult = Elements.matchup(Elements.E.WATER, Elements.E.FIRE)  # 1.5
  var final_damage = base_damage * mult
  ```

### `name_of(element: int) -> String`
- **Returns:** the readable element name, e.g. `"Water"`. Pass an `Elements.E` value.
- **Example:**
  ```gdscript
  tooltip.text = Elements.name_of(enemy.element)  # "Fire"
  ```

### Enums you'll reference constantly
- `Elements.E` → `WATER, FIRE, WIND, EARTH, ICE, LIGHTNING, LAVA, SAND, DARK, LIGHT`
- `Elements.STAT` → `STA, HP, DEF, ATT, MAG, SPD`
- **Example:**
  ```gdscript
  var spd = Party.members[2].stat(Elements.STAT.SPD)
  ```

---

## 🎯 Targeting (autoload)

Decides who enemies attack, and resolves Guard.

> A `member` here is a small **dictionary**, not a Character: `{ "pos": int, "defense": int, "hp": int, "alive": bool }`. Combat code builds these from the real Characters each turn. Use `Targeting.POS` for the `pos` value: `FRONT, CENTER, BACK1, BACK2`.

### `pick_target(party: Array) -> int`
- **Returns:** the **index** of the member the enemy attacks (weighted-random by threat — tanks get hit most, but nobody is 100% safe). Returns `-1` if everyone is down.
- **Example:**
  ```gdscript
  var i = Targeting.pick_target(combat_members)
  if i != -1:
      deal_damage_to(i)
  ```

### `resolve_guard(target_index: int, damage: float, guardians: Dictionary) -> Dictionary`
- **Returns:** a dictionary `{ "target": int, "damage": float }` — if the targeted ally is being guarded, the hit is redirected to the guardian at −40% damage; otherwise it passes through unchanged. `guardians` maps `guardian_index -> guarded_ally_index`.
- **Example:**
  ```gdscript
  var result = Targeting.resolve_guard(i, raw_damage, active_guards)
  apply_damage(result["target"], result["damage"])
  ```

### Also available
- `Targeting.pick_overwhelm(party: Array) -> int` — boss-only: ignores threat + guard, hits the **lowest-HP** alive member. (Stretch feature — wire only if the boss uses it.)
- `Targeting.POS_THREAT` — the base threat per position, if UI wants to show it.

---

## 📏 Quick reference — signatures at a glance

| Call | Returns |
|---|---|
| `Party.members` | `Array[Character]` |
| ⏳ `Party.swap_positions(a, b)` | `bool` |
| ⏳ `Party.member_at_position(pos)` | `Character` or `null` |
| `char.stat(stat_index)` | `int` |
| `char.max_hp()` | `int` |
| `char.max_actions()` | `int` |
| `char.level_up()` | `void` |
| `char.spend_point_on_stat(stat)` | `bool` |
| `char.unlock_skill(id)` | `bool` |
| `char.equip_spell(id)` | `bool` |
| `char.unequip_spell(id)` | `bool` |
| ⏳ `char.has_skill(id)` | `bool` |
| ⏳ `char.is_ult_ready()` | `bool` |
| ⏳ `char.spend_ult()` | `bool` |
| `Elements.matchup(atk_el, def_el)` | `float` (1.5 / 1.0 / 0.5) |
| `Elements.name_of(el)` | `String` |
| `Targeting.pick_target(party)` | `int` (index, or -1) |
| `Targeting.resolve_guard(target, dmg, guardians)` | `Dictionary` `{target, damage}` |

---

## 📜 THE RULE

**UI/scene code CALLS these functions but NEVER edits files in `core/`. New shared functions get added to this list first, then built.**

If Coder B needs something the core doesn't expose yet, don't reach into `core/` and change it — add the new function to this doc, agree on its signature, then Coder A builds it. This list is the single source of truth for how the two halves connect.
