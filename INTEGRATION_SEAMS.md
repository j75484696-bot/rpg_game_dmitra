`Combat.melee/spell/item/ultimate/heal/ult_gain(...)` | `int` |# 🔌 Integration Seams — The Public API

**What this is:** every function, signal and field the rest of the game can call on the shared systems in `core/`. If you need to know how two halves of the project connect, this is the file.

**How to read it:** each entry has the **signature**, what it **returns**, and a short example.

**Status markers:**
- (unmarked) — live in `core/` today, safe to call
- ⏳ — **agreed here, not built yet.** The signature is locked; don't call it until the marker goes
- 🚧 — built, but something it depends on is missing, so it can't do its whole job

**Keeping this file honest:** any file may edit any other. That freedom only works if this doc is updated in the same commit as the code. A signature that isn't here is a signature nobody else can rely on.

> ### The one hard rule
> **All damage and healing math lives in `core/Combat.gd`.** Call `Combat.melee()` / `spell()` / `item()` / `heal()`. Never recompute a number anywhere else — the moment two places calculate damage, the UI and the fight disagree and the bug is nearly invisible.

---

## 📍 Where things live

**Autoloads** — call them by name from anywhere. Registered in this order, and the order matters:

```
Elements → Party → Inventory → Targeting → Transitions → Combat → Actions → EnemyAI
```

`Party` builds its roster using `Elements`. `EnemyAI` delegates its action-count formula to `Actions`. `Inventory` has no dependencies but sits early, since anything consuming an item wants it already up.

**`class_name` classes** — not autoloaded, globally available, you instance them:

| Class | What it is |
|---|---|
| `Character` | One hero's data + progression. Instances come from `Party.members` |
| `CreatureRating` | One enemy's identity as ratings. Instances are `data/enemies/*.tres` |
| `BattleState` | One fight, start to finish. One instance per battle |
| `ActionBudget` | One combatant's actions for one turn |

---

## 🧬 The combatant dictionary

Combat runs on **dictionaries**, not objects, so heroes and enemies feed the same functions without translation. **This is the canonical shape** — build one and every system below will read it.

```gdscript
{
    "name": String,        "element": int,      "pos": int,
    "hp": int,             "max_hp": int,       "def": int,
    "att": int,            "mag": int,          "spd": int,
    "sta": int,            "max_actions": int,  "alive": bool,
    "budget": ActionBudget,
}
```

Enemies carry two more, from `CreatureRating.build()`:

```gdscript
    "xp_value": int,       "overwhelm": bool
```

**Who reads what:**

| System | Keys it needs |
|---|---|
| `Combat` | `att`, `mag`, `def`, `element` |
| `Targeting` | `pos`, `def`, `hp`, `alive` |
| `EnemyAI` | `sta`, `hp`, `max_hp`, plus everything `Combat` needs |
| `BattleState` | all of them |

**Don't hand-build these.** Use `Combat.from_character()` for a hero or `CreatureRating.build()` for an enemy, then let `BattleState.setup()` fill in the rest. The key is spelled **`def`**, not `defense`.

---

## 🧑‍🤝‍🧑 Party (autoload)

The 4-hero roster. **Three fight at a time**; the fourth sits on the bench at `Targeting.POS.BACK2` and is swapped in between fights.

### `Party.members`
- **Type:** `Array[Character]` — 4 heroes, index 0–3 (Ignis, Aria, Zeph, Craig). Order is load-bearing.
- Loaded from `data/heroes/*.tres` at startup and **duplicated**, so the on-disk resources are never mutated.
- **Example:**
  ```gdscript
  var hero = Party.members[0]        # Ignis
  var count = Party.members.size()   # 4 — the roster, not the fighting three
  ```

### ⏳ `Party.member_at_position(pos: int) -> Character`
- **Returns:** the hero in that slot, or `null` if empty. Pass a `Targeting.POS` value.
- **For:** laying out the battle screen by slot instead of by roster index. `battle.gd._refresh_panels()` is waiting on this.

### Changing who fights
There is no `Party.swap_positions()`. Two different jobs, two different places:

| Job | How |
|---|---|
| Reorder the three fighters **during a battle's prep phase** | `BattleState.set_position()` / `swap_positions()` |
| Substitute a bench hero **between fights** | assign `character.position` directly |

> ⚠️ **Caller-enforced invariant.** Exactly one hero must sit in each of `FRONT`, `CENTER`, `BACK1`; everyone else on `BACK2`. Nothing checks this today. Two heroes in one slot skews threat weighting; an empty slot loses a fighter. A `Party` helper that enforces it would be a reasonable addition.

---

## 👛 Inventory (autoload)

**One inventory, shared by the whole party, with no capacity limit.** Items are stored as `item_id → count`, using the ids from `COMBAT_DATA.md`. An id the party doesn't hold is **absent, not zero**.

### Signals
| Signal | Arguments |
|---|---|
| `gold_changed` | `(amount: int)` — the new total |
| `items_changed` | none |

The shop and the HUD connect to these rather than polling.

### Gold
| Call | Returns |
|---|---|
| `gold: int` | Current total. Read freely |
| `add_gold(amount: int)` | nothing. Ignores non-positive amounts |
| `spend_gold(amount: int) -> bool` | `false` and **spends nothing** if unaffordable |
| `can_afford(amount: int) -> bool` | — |

### Items
| Call | Returns |
|---|---|
| `add_item(item_id: String, count := 1)` | nothing |
| `remove_item(item_id: String, count := 1) -> bool` | `false` and **removes nothing** if the party doesn't have that many |
| `count_of(item_id: String) -> int` | `0` when absent |
| `has_item(item_id: String) -> bool` | — |
| `held_ids() -> Array` | Every id currently held, for listing in a menu |
| `reset()` | Back to the starting loadout. New game only |

```gdscript
if Inventory.can_afford(price) and Inventory.spend_gold(price):
    Inventory.add_item("item_potion")
```

`spend_gold()` and `remove_item()` both return `false` and change nothing when they can't complete, so a Buy button's disabled state can come from the same call that pays.

> **Not here:** revive counters. Each hero can be revived **three times per dungeon**, tracked per hero. That's per-**run** state — keeping it in a persistent singleton would let it survive leaving the dungeon. It belongs to the M2 dungeon manager.

> 🚧 `STARTING_GOLD` and `STARTING_ITEMS` are placeholders. Real numbers are **TBD** — see `COMBAT_DATA.md`.

---

## 🧍 Character (class)

One hero's data and progression.

### `stat(stat_index: int) -> int`
- **Returns:** the FINAL value — `base + growth × (level − 1) + spent points × PER_POINT`. Use `Elements.STAT` for the index.
  ```gdscript
  var atk = Party.members[0].stat(Elements.STAT.ATT)
  ```

### `max_hp() -> int`
- Shortcut for `stat(Elements.STAT.HP)`.

### `max_actions() -> int`
- **Returns:** `2 + int(STA / 30)`. The hero floor is 2; enemies floor at 1 via `Actions.max_for_enemy()`.

### `level_up() -> void`
- Raises level by 1, grants +1 unspent point, re-derives known spells. **Caps at level 60.**

### `spend_point_on_stat(stat_index: int) -> bool`
- **Returns:** `true` if spent, `false` if no unspent points. No per-stat cap.

### `unlock_skill(skill_id: String) -> bool`
- **Returns:** `true` if unlocked, `false` if no points left or already taken.
- 🚧 **No prerequisite logic.** The skill tree enforces prereqs UI-side, which means the rule isn't where the other rules are. Needs either prereq checking in here or a `can_unlock(skill_id)` seam. Open decision.

### `equip_spell(spell_id: String) -> bool` / `unequip_spell(spell_id: String) -> bool`
- Equip fails if the spell isn't known, is already equipped, or the **3-slot limit** is full.

### `refresh_spells() -> void`
- Re-derives `known_spells` as `<element>_1 … <element>_n` where `n = 1 + int(level / 3)`, capped at 20. **Clears and rebuilds the array**, then silently unequips anything no longer known.
- 🚧 Generates IDs the spell table doesn't define — at level 3 Zeph learns `wind_2` and Craig `earth_2`, neither of which exists. Deferred, not fixed.

### ⏳ Ultimate meter
| Signature | Returns |
|---|---|
| `is_ult_ready() -> bool` | `true` once `ult_meter` hits 100 |
| `spend_ult() -> bool` | `true` if it was full and is now 0; `false` changes nothing |
| `gain_ult(dealt: int, taken: int) -> void` | nothing |
| `ult_meter: int` | `0`–`100`, drives the bar |

> `gain_ult()` **must** call `Combat.ult_gain(dealt, taken)` and then clamp to 100. It owns the clamp; `Combat` owns the formula. Don't reimplement `+1 per 2 dealt / +1 per 4 taken` here.

### ⏳ `has_skill(skill_id: String) -> bool`
- For drawing a skill node lit or dim without reading the array yourself.

### Read-only fields
Safe to display; change them through the functions above.
- `char_name: String`, `element: int` (an `Elements.E` value), `level: int`, `unspent_points: int`
- `known_spells` / `equipped_spells` / `unlocked_skills`: `Array[String]`
- `position: int` — `0` Front, `1` Center, `2` Back1, `3` **Back2 = bench**

### Constants
`MAX_LEVEL = 60` · `MAX_EQUIPPED_SPELLS = 3` · `PER_POINT = [3, 15, 3, 3, 3, 3]`

---

## 🌊 Elements (autoload)

### `matchup(attacker_element: int, defender_element: int) -> float`
- **Returns:** `1.5` super effective, `0.5` not effective, `1.0` neutral. The full type chart is in `COMBAT_DATA.md`.

### `name_of(element: int) -> String`
- e.g. `"Water"`. Lowercased, this is also the spell-ID prefix.

### `base_stat(element: int, stat: int) -> int`
- **Returns:** the raw number behind an element's letter grade, e.g. `base_stat(E.WATER, STAT.HP)` → `170`.

### `rated_stat(element: int, stat: int, rating: int, tier_scale: float = 1.0) -> int`
- **Returns:** `round(base_stat × rating / RATING_BASELINE × tier_scale)`.
- **This is the only place an enemy stat is computed.** Rating `10` = exactly the element's base.

### Enums and constants
```gdscript
Elements.E     # WATER 0, FIRE 1, WIND 2, EARTH 3, ICE 4,
               # LIGHTNING 5, LAVA 6, SAND 7, DARK 8, LIGHT 9
Elements.STAT  # STA 0, HP 1, DEF 2, ATT 3, MAG 4, SPD 5
Elements.RATING_BASELINE   # 10
```

---

## 🎯 Targeting (autoload)

Decides who enemies attack, and resolves Guard.

### Slots
```gdscript
Targeting.POS       # FRONT 0, CENTER 1, BACK1 2, BACK2 3
Targeting.ACTIVE    # [FRONT, CENTER, BACK1] — the three that fight
```

### `is_active(pos: int) -> bool`
- **Returns:** `true` for the three fighting slots. **BACK2 is the bench** — zero threat, never a target.
- Iterate `ACTIVE` rather than hardcoding the list anywhere.

### `threat_of(member: Dictionary) -> float`
- **Returns:** how attention-grabbing a member is:
  ```
  positional base + def + (hp / 10)
  ```
  Positional base is `FRONT 50 · CENTER 30 · BACK1 10 · BACK2 0`. Returns `0.0` if dead or benched.

### `pick_target(party: Array) -> int`
- **Returns:** the **index** of who gets attacked — weighted random by threat, so tanks are hit most but nobody is safe. Returns `-1` if there's nobody left to hit.

### `pick_overwhelm(party: Array) -> int`
- **Returns:** the **lowest-HP alive active** member. Ignores threat and Guard entirely. This is Ashfang's below-50%-HP behaviour, not a stretch feature.

### `resolve_guard(target_index: int, damage: float, guardians: Dictionary) -> Dictionary`
- **Returns:** `{ "target": int, "damage": float }`. If the targeted ally is guarded, the hit redirects to the guardian at **−40%**; otherwise it passes through untouched.
- `guardians` maps `guardian_index → guarded_ally_index`.
- ⚠️ The damage was already computed against the **original target's** DEF. Redirecting doesn't recompute, so a high-DEF guardian gets no benefit from their own armour. Deliberate for now — flag it if playtesting hates it.

### `GUARD_REDUCTION`
- `0.40`.

---

## ⚔️ Combat (autoload)

Pure functions. No state, no scene tree. **The only place damage is calculated.**

Every formula has the same shape — **DEF first, then matchup**:

```
(raw − target DEF) × element matchup
```

| Call | Returns |
|---|---|
| `melee(attacker, target) -> int` | raw = attacker's ATT |
| `spell(attacker, target, multiplier: float) -> int` | raw = attacker's MAG × multiplier |
| `item(target, value: int, element: int, use_matchup: bool) -> int` | raw = the item's flat value; thrower's ATT ignored |
| `heal(value, current_hp, max_hp) -> int` | HP **actually** restored, capped to missing HP |
| `ult_gain(dealt: int, taken: int) -> int` | `+1 per 2 dealt, +1 per 4 taken`. **Unclamped** |
| `from_character(c: Character) -> Dictionary` | `{ att, mag, def, element }` |

- Damage **floors** and never drops below `MIN_DAMAGE = 1`.
- `heal()` returns the real amount, so the floating number matches the bar.
- `ult_gain()` returns a gain, not a meter value — the caller clamps.

```gdscript
var dealt := Combat.melee(attacker_dict, target_dict)
var restored := Combat.heal(60, hero["hp"], hero["max_hp"])
```

---

## 🎬 Actions (autoload) + ActionBudget (class)

### `Actions.TYPE`
`MELEE`, `SPELL`, `ITEM`, `GUARD`, `ULT`. **All cost 1** (`Actions.COST`). Split them apart if a spell should ever cost two.

`ULT` costs an action **and** a full meter — the meter is the gate, but a free ult would mean ulting *and* attacking on the same turn. `BattleState` calls `char.spend_ult()`, which gates and spends in one call, and refunds the action if the meter was not full.

### Action counts
| Call | Returns |
|---|---|
| `max_for_hero(c: Character) -> int` | `c.max_actions()` — `2 + int(STA / 30)` |
| `max_for_enemy(stamina: int) -> int` | `1 + int(STA / 30)` |
| `cost_of(type) -> int` / `label_of(type) -> String` | cost, and the button label |

### The guard board
A `Dictionary` mapping `guardian_index → guarded_ally_index`.

| Call | Effect |
|---|---|
| `declare_guard(board, guardian_index, ally_index)` | Arms a guard. **Reassigns** rather than stacking — one guardian protects one ally |
| `clear_guard(board, guardian_index)` | Drops it. Called on the guardian's own turn and on their death |
| `is_guarding(board, guardian_index) -> bool` | — |

Guard **arms**; it resolves later, when a hit lands, via `Targeting.resolve_guard()`.

### `ActionBudget`
One combatant's actions for one turn.

| Call | Returns |
|---|---|
| `reset(max_value: int)` | Starts a fresh turn. Unspent actions **do not bank** |
| `can_spend(type) -> bool` | — |
| `spend(type) -> bool` | `false` and **changes nothing** if unaffordable, so a button's disabled state can come from the same call that spends |
| `refund(type)` | Gives one back, clamped to max |
| `is_spent() -> bool` / `spent_count() -> int` | — |

---

## 👹 EnemyAI (autoload)

### `plan_turn(enemy: Dictionary, party: Array, guardians: Dictionary = {}, overwhelm: bool = false) -> Array`
- **Returns:** one entry per action the enemy gets:
  ```gdscript
  { "target": int, "damage": int, "redirected": bool }
  ```
- `target` is who **actually takes** the hit, after Guard redirection. Empty array if the party is down.
- `overwhelm` only engages if the enemy is **also** below `OVERWHELM_HP_FRACTION` (0.5). Pass `enemy["overwhelm"]`.
- ⚠️ The whole turn is planned **up front** against the party as it stands. A 2-action enemy can be scheduled to hit someone who dies to the first blow; the second lands on a corpse and is absorbed.

### `actions_for(stamina: int) -> int`
- Delegates to `Actions.max_for_enemy()`.

---

## 🐉 CreatureRating (class — `data/enemies/*.tres`)

An enemy's identity as **ratings**, not raw stats. Three independent dials:

| Field | Meaning |
|---|---|
| `ratings: Array` | Six values `[STA,HP,DEF,ATT,MAG,SPD]`, each **0–20**. `10` = the element's base value |
| `stat_element: int` | Which element's numbers the stats scale from. **Fixed**, even for creatures that roll |
| `rolls_element: bool` | `true` rolls a random element on spawn **for the matchup only** |
| `display_name: String`, `xp_value: int` | — |
| `overwhelm: bool` | Boss flag — ignore threat and Guard below 50% HP |

```
stat = round(element base × rating / 10 × tier_scale)
```

Keeping `stat_element` separate from the rolled element is what stops a Wisp that rolls Earth from coming out slow and armoured. Its identity lives in `ratings[]`.

| Call | Returns |
|---|---|
| `stat(stat_index, tier_scale := 1.0) -> int` | One derived stat, rating clamped to 0–20 |
| `max_actions(tier_scale := 1.0) -> int` | Via `Actions.max_for_enemy()` |
| `build(tier_scale := 1.0) -> Dictionary` | A full combatant dict, ready for `BattleState.setup()` |
| `battle_element() -> int` | Rolled fresh each `build()` when `rolls_element` |

```gdscript
var rating: CreatureRating = load("res://data/enemies/mudling.tres")
var enemy := rating.build()          # tier_scale ramps difficulty
```

**`tier_scale` is the difficulty dial.** Ramp a dungeon or scale to party level without touching any creature's identity.

---

## ⚙️ BattleState (class) — one fight

```gdscript
var battle := BattleState.new()
battle.battle_ended.connect(_on_battle_ended)
battle.setup(active_heroes, enemy_dicts)
battle.begin()
```

### Signals — the UI reacts, it never polls

| Signal | Arguments |
|---|---|
| `phase_changed` | `(phase: int)` |
| `turn_started` | `(index: int, is_hero: bool)` |
| `turn_ended` | `(index: int, is_hero: bool)` |
| `action_taken` | `(actor: int, actor_is_hero: bool, type: int, target: int, amount: int)` |
| `combatant_died` | `(index: int, is_hero: bool)` |
| `battle_ended` | `(party_won: bool)` |

`index` is into `battle.heroes` or `battle.enemies` depending on `is_hero`. `type` is an `Actions.TYPE`. Every **enemy** action reports as `MELEE` today.

### Methods

| Call | Returns / effect |
|---|---|
| `setup(heroes_in: Array, enemies_in: Array)` | Builds combatants, enters PREP. **Skips and warns** on any hero not in an active slot |
| `begin()` | Leaves PREP, builds turn order, starts turn 1 |
| `set_position(hero_index, pos) -> bool` | PREP only |
| `swap_positions(a, b) -> bool` | PREP only. Swapping keeps each active slot filled exactly once |
| `act(type, target_index) -> bool` | One hero action. `false` if it wasn't affordable or the target was invalid |
| `end_turn()` | Stop early. Unspent actions are lost |
| `current() -> Dictionary` | `{ index, is_hero }` for whoever is acting |
| `current_combatant() -> Dictionary` | That combatant's dict |

> ### ⚠️ `act()`'s `target_index` lives in two index spaces
> | Action | `target_index` means |
> |---|---|
> | `MELEE`, `SPELL`, `ITEM` | an index into `battle.enemies` |
> | `GUARD` | an index into `battle.heroes` — the ally being protected |
>
> Both paths bounds-check and reject; GUARD also refunds the action.

### Rules it enforces
- Turn order by **Speed, highest first**, rebuilt each round — a SPD change takes effect next round.
- **Speed ties go to the hero.**
- A guardian's **own turn clears** the guard they were holding.
- **Party wipe is checked first**, so a mutual kill is a DEFEAT.
- Enemy turns run automatically inside the state machine; the UI only drives heroes.

### 🚧 Not finished
`SPELL` falls back to a plain melee swing (no spell table) and `ITEM` does nothing (no item table or inventory).

### Fields
`phase`, `heroes`, `enemies`, `guards`, `order`, `turn_cursor` · `PHASE` = `PREP, TURN, VICTORY, DEFEAT`

---

## 🎞️ Transitions (autoload) — the scene stack

Scenes **stack rather than swap**. `push()` leaves the scene below loaded, hidden and paused, so the map keeps the player's position while a fight runs on top. Every screen change goes through here — never `change_scene_to_file()`.

| Call | Effect |
|---|---|
| `push(scene_path, payload := {})` | Add a scene on top. `await` it |
| `pop()` | Drop the top scene; the one beneath resumes untouched. **Refuses to pop the last scene** |
| `replace(scene_path, payload := {})` | Clear the stack and start fresh |
| `current() -> Node` / `depth() -> int` | — |
| `payload() -> Dictionary` | What the current scene was pushed with; `{}` if none |

Signals: `transition_started`, `transition_finished`.

### Passing data to a scene

```gdscript
# pushing
await Transitions.push("res://scenes/battle/battle.tscn", {
    "enemies": [rating.build()],
})

# in the pushed scene's _ready()
var enemies: Array = Transitions.payload().get("enemies", [])
```

The payload is stacked alongside its scene, so popping restores the payload underneath. It's duplicated on the way in, and it's always safe to read — a scene launched directly just gets `{}`.

> **MISSING: the return leg.** A finished battle needs to report whether the party won, what dropped, and how much XP. `push()` carries data in; nothing carries a result out. Options: `pop(result)` plus a getter, a signal on `Transitions`, or the M2 dungeon manager owning the whole sequence. Open decision.

---

## 🎞️ SpriteSheet (class) — art loading

Turns a horizontal strip into `SpriteFrames` at load. Scene code calls this;
nothing else needs to know how art is stored.

### `SpriteSheet.find_idle(display_name: String, prefixes: Array = ["enemy", "boss"]) -> Texture2D`
- **Returns:** the idle strip for a creature of that name, or `null` if no art
  exists for it yet. Callers show a placeholder on `null` rather than erroring.
- **Why prefixes:** `NAMING.md` files bosses under `boss_` and everything else
  under `enemy_`, but a fight only has a *name* — it does not know which kind
  of creature it is holding. Pass `["hero"]` for party members.
- **Example:**
  ```gdscript
  var tex := SpriteSheet.find_idle("Frostbite Imp")   # enemy_frostbite_imp_bidle.png
  ```

### `SpriteSheet.strip_auto(texture: Texture2D, cell: int = 64, fps: float = 12.0) -> SpriteFrames`
- **Returns:** a looping `SpriteFrames` named `bidle`, with the frame count
  **inferred from the texture width**. An 8-frame and a 16-frame strip both
  work with no per-file configuration.
- **Example:**
  ```gdscript
  $Sprite.sprite_frames = SpriteSheet.strip_auto(tex)
  $Sprite.play(SpriteSheet.ANIM)
  ```

### Also available
- `SpriteSheet.strip(texture, cell, count, fps)` — when the count must be
  forced rather than inferred.
- `SpriteSheet.slugify(display_name)` — `"BOSS: Ashfang"` → `"ashfang"`.
- `SpriteSheet.ANIM` — the animation name, `&"bidle"`.

---

## 📏 Quick reference

| Call | Returns |
|---|---|
| `Party.members` | `Array[Character]` (4; three fight) |
| ⏳ `Party.member_at_position(pos)` | `Character` or `null` |
| `char.stat(i)` / `max_hp()` / `max_actions()` | `int` |
| `char.level_up()` | `void` |
| `char.spend_point_on_stat(i)` / `unlock_skill(id)` | `bool` |
| `char.equip_spell(id)` / `unequip_spell(id)` | `bool` |
| ⏳ `char.has_skill(id)` · `char.is_ult_ready()` / `spend_ult()` | `bool` |
| `char.gain_ult(dealt, taken)` | `void` |
| `Elements.matchup(a, d)` | `float` (1.5 / 1.0 / 0.5) |
| `Elements.name_of(e)` | `String` |
| `Elements.base_stat(e, stat)` | `int` |
| `Elements.rated_stat(e, stat, rating, scale)` | `int` |
| `Targeting.is_active(pos)` | `bool` |
| `Targeting.threat_of(member)` | `float` |
| `Targeting.pick_target(party)` / `pick_overwhelm(party)` | `int` (index, or −1) |
| `Targeting.resolve_guard(i, dmg, guardians)` | `{target, damage}` |
| `Combat.melee/spell/item/heal/ult_gain(...)` | `int` |
| `Combat.from_character(c)` | `Dictionary` |
| `Actions.max_for_hero(c)` / `max_for_enemy(sta)` | `int` |
| `Actions.declare_guard/clear_guard/is_guarding(...)` | `void` / `bool` |
| `budget.spend(type)` / `can_spend(type)` / `is_spent()` | `bool` |
| `EnemyAI.plan_turn(enemy, party, guardians, overwhelm)` | `Array` of `{target, damage, redirected}` |
| `rating.build(tier_scale)` | `Dictionary` (combatant) |
| `battle.setup/begin/act/end_turn(...)` | see above |
| `Transitions.push(path, payload)` / `pop()` / `replace(path, payload)` | `void` (await) |
| `Transitions.payload()` | `Dictionary` |
| `SpriteSheet.find_idle(name, prefixes)` | `Texture2D` or `null` |
| `SpriteSheet.strip_auto(tex, cell, fps)` | `SpriteFrames` |
