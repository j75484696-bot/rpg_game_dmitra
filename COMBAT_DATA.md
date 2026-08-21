# 🎲 Combat Data Tables (Vertical Slice)

Starting numbers so coders **wire data, not guesses**. These are tuned to make the 3 dungeon fights winnable and the boss a real threat. **Everything here is meant to be tuned in playtesting (Day 5)** — they're starting values, not sacred.

Stat order everywhere: **STA, HP, DEF, ATT, MAG, SPD**.
Elements: Water, Fire, Wind, Earth, Ice, Lightning, Lava, Sand, Dark, Light.

---

## 🧑‍🤝‍🧑 HERO STATS

### Level-1 base stats
These match each hero's element identity (glass-cannon Fire, tanky Water, fast Wind, wall Earth). If they differ from what `Elements.gd` computes, **this table wins** — update the scale or per-hero overrides to match.

| Hero | Element | STA | HP | DEF | ATT | MAG | SPD |
|---|---|---|---|---|---|---|---|
| **Ignis** | 🔥 Fire | 24 | 100 | 16 | 34 | 28 | 23 |
| **Aria** | 💧 Water | 30 | 170 | 16 | 23 | 23 | 18 |
| **Zeph** | 🌪️ Wind | 36 | 100 | 16 | 23 | 23 | 34 |
| **Craig** | 🪨 Earth | 30 | 120 | 32 | 18 | 18 | 12 |

### Growth per level (auto-applied on level up, before spent points)
Add this each level. Kept simple + flat for the demo (no curves).

| Hero | STA | HP | DEF | ATT | MAG | SPD |
|---|---|---|---|---|---|---|
| **Ignis** | +1 | +8 | +1 | +4 | +3 | +2 |
| **Aria** | +2 | +14 | +2 | +2 | +2 | +1 |
| **Zeph** | +2 | +8 | +1 | +2 | +2 | +4 |
| **Craig** | +2 | +11 | +3 | +2 | +1 | +1 |

> Note: a manually **spent** point uses the `PER_POINT` array in `Character.gd` (STA+3, HP+15, DEF+3, ATT+3, MAG+3, SPD+3). Growth-per-level above is separate and automatic.

### Derived values (computed, don't hand-enter)
- **Max actions/turn** = `2 + floor(STA / 30)` → Ignis 2, Aria 3, Zeph 3, Craig 3 at level 1.
- **Ult meter**: fills 0→100 on damage dealt + taken. Suggested: `+1 per 2 damage dealt`, `+1 per 4 damage taken`. Tune in playtest.

### Default combat positions (prep-phase starting layout)
Only **three heroes fight at a time**. The fourth is a substitute, swapped in the
prep menu between fights — never mid-battle. `Targeting.POS.BACK2` is unused.

| Position | Hero | Why |
|---|---|---|
| Front | **Craig** | Wall — highest DEF+HP, draws aggro, guards |
| Center | **Zeph** | Fast melee |
| Back 1 | **Aria** | Water caster, stays safe |
| — | **Ignis** | **Substitute** by default — glass cannon, swap him in when Fire helps |

### Starting spells equipped (max 3)
Demo spell IDs follow `<element>_<n>` (see spell list at bottom).
| Hero | Equipped at level 1 |
|---|---|
| Ignis | `fire_1` |
| Aria | `water_1` |
| Zeph | `wind_1` |
| Craig | `earth_1` |

(Heroes learn 1 spell every 3rd level; by the demo's level range they'll have a couple to choose from.)

---

## 👹 ENEMY STATS

Enemies do **not** have a hand-authored action count. Like heroes, they act off **Stamina** — see [Actions per turn](#actions-per-turn) below.

### Encounter enemies

3 lightweight enemies for random map encounters. Roll a random element on spawn — the stats below are fixed, the element only drives the damage matchup.

| Enemy | STA | HP | DEF | ATT | MAG | SPD | XP | Notes |
|---|---|---|---|---|---|---|---|---|
| **Wisp** | 18 | 45 | 6 | 10 | 12 | 20 | 8 | Fast, fragile, dies quick |
| **Critter** | 24 | 60 | 10 | 14 | 8 | 14 | 10 | Basic melee filler |
| **Brute** | 28 | 80 | 14 | 18 | 6 | 8 | 12 | Slow, chunky, the "tough" encounter |

### Dungeon enemies

3 normal enemies (fought in order) + 1 boss. Normal enemies are beatable by the 3 active level-1 heroes; difficulty ramps across the three.

| Enemy | Element | STA | HP | DEF | ATT | MAG | SPD | XP | Notes |
|---|---|---|---|---|---|---|---|---|---|
| **Mudling** | 🪨 Earth | 20 | 70 | 10 | 14 | 6 | 10 | 15 | Weak warmup. Weak to Wind. |
| **Frostbite Imp** | ❄️ Ice | 24 | 85 | 14 | 16 | 18 | 16 | 25 | Casts. Weak to Fire → Ignis shines. |
| **Emberhound** | 🔥 Fire | 30 | 95 | 12 | 20 | 14 | 22 | 30 | Fast, hits twice (STA 30 → 2 actions). Weak to Water → Aria. |
| **BOSS: Ashfang** | 🌋 Lava | 30 | 260 | 20 | 26 | 20 | 18 | 120 | Real threat. Weak to Water. Strong vs Fire (careful, Ignis) + Wind. |

### Actions per turn

**Derived — never hand-enter this.** Same shape as `Character.max_actions()`, with a lower floor:

```gdscript
# enemy
1 + int(stat(Elements.STAT.STA) / 30)
# hero (existing, unchanged in Character.gd)
2 + int(stat(Elements.STAT.STA) / 30)
```

Enemies floor at **1** because the party outnumbers them 3-to-1 — giving enemies the hero floor of 2 doubles incoming damage in every fight and makes the warmup encounters harder than the boss.

STA is now the **single dial** for enemy action economy. The next breakpoint is **STA 30**, so nudging a normal enemy from 28 to 30 buys it a second action:

| STA range | Actions | Who |
|---|---|---|
| 0–29 | 1 | Wisp, Critter, Brute, Mudling, Frostbite Imp |
| 30–59 | 2 | Emberhound, Ashfang |
| 60+ | 3 | *(nobody in the slice — headroom for later)* |

> ⚠️ **One stat changed to make this work:** Emberhound's STA went **24 → 30**. It was flagged as a 2-action enemy but its Stamina didn't support that. Raising the stat earns the second action instead of special-casing it in code. Every other enemy's action count is identical to the old hand-authored column.

**XP notes:** `xp_value` is awarded the moment the enemy dies (per-fight, see [Progression]). Rough level pacing: clearing the 3 normal enemies (~70 XP) + boss (120) ≈ enough for **1–2 level-ups** across a dungeon run. Random map **encounters** award a small flat **8–12 XP** each — see the Encounter enemies table above. Level thresholds: start simple — **level N needs `N × 50` XP** — and tune in playtest.

### Enemy AI (simple, for the demo)
- Implemented in `core/EnemyAI.gd`. `EnemyAI.plan_turn()` returns one action per available action, each `{ target, damage, redirected }`.
- Each enemy picks a target via `Targeting.pick_target` (threat-weighted) and does a basic attack.
- Enemies whose STA derives **2+ actions** (**Emberhound**, **Ashfang**) can hit two targets or one target twice.
- Ashfang uses `pick_overwhelm` below 50% HP to punish a hidden low-HP hero — pass `overwhelm: true` to `plan_turn()`. It ignores threat AND Guard by design.

---

## 💰 DROP TABLE

Rolled **on dungeon clear** (not per enemy). Each enemy contributes to a pooled roll; the boss guarantees a reward.

| Source | Drop pool (roll one unless noted) |
|---|---|
| Mudling | 60% `item_potion`, 40% nothing |
| Frostbite Imp | 50% `item_potion`, 50% `item_grenade` |
| Emberhound | 50% `item_molotov`, 50% `item_bomb` |
| **Ashfang (boss)** | **Guaranteed:** `item_bomb` ×2 + one equippable (`equip_emberband` 70% / `equip_stoneplate` 30%) |

> Keep drop logic dead simple for the demo: on clear, loop each defeated enemy, roll its pool, add results to party inventory. Show the list on the victory screen.

---

## 🧪 ITEM TABLE

### Consumables (usable in battle, cost 1 action)
| ID | Name | Effect | Value | Element |
|---|---|---|---|---|
| `item_potion` | Potion | Heal one hero (**the only healing in the game**) | +60 HP | — |
| `item_molotov` | Molotov | Damage one enemy | 40 dmg | Fire (uses matchup) |
| `item_bomb` | Bomb | Damage one enemy | 45 dmg | Neutral (no matchup) |
| `item_grenade` | Elemental Grenade | Damage one enemy | 35 dmg | Element chosen on use (uses matchup) |

- Item damage ignores the thrower's ATT entirely. **Decided rule:** `(item value − target DEF) × element matchup`. `item_bomb` is Neutral and skips the matchup. Implemented in `Combat.item()`.

### Equippables (grant stat bonus; some have a requirement)
| ID | Name | Bonus | Requirement |
|---|---|---|---|
| `equip_emberband` | Emberband | +6 MAG, +2 ATT | None |
| `equip_stoneplate` | Stoneplate | +8 DEF, +20 HP | STA ≥ 28 (tanks only) |

- Requirement check: if the hero's stat is below the requirement, block the equip and show a message. `equip_stoneplate` is meant for Craig/Aria, not Ignis.

---

## ⚔️ DAMAGE RULES

Implemented in `core/Combat.gd` — combat code and UI both call it, so both get
the same number. Everything follows one shape:

```
(raw − target DEF) × element matchup
```

**Order matters.** DEF comes off *first*, then the matchup multiplies. The other
way round lets a super-effective hit punch through armour far harder than
intended.

| Source | Raw value | Matchup applies? |
|---|---|---|
| Melee | attacker's ATT | yes |
| Spell | attacker's MAG × spell multiplier | yes |
| Item | the item's flat value (thrower's ATT ignored) | yes, except `item_bomb` |

**Two rules decided in code, not previously specified here:**
- **Minimum damage is 1.** Stops a bad matchup against a tanky target dealing 0
  and stalling the fight.
- **Results floor, they don't round.** DEF is never worth less than face value.

Both are single constants — change them if playtesting disagrees.

**Guard** applies after, via `Targeting.resolve_guard()`: the hit redirects to
the guardian at −40%.

**Healing** is flat and item-only — `Combat.heal()` caps to the target's missing
HP, so a potion can't overheal. The return value is the amount actually
restored, which is what the floating number should show.

**Ult meter** — `Combat.ult_gain()`: `+1 per 2 damage dealt`, `+1 per 4 taken`.

---

## 🔮 DEMO SPELL LIST (6 total)

Spell damage = `MAG × multiplier − target DEF`, then × element matchup. IDs use `<element>_<n>`.

| ID | Name | Element | MAG multiplier | Learned at level | Notes |
|---|---|---|---|---|---|
| `fire_1` | Ember | Fire | 1.2 | 1 | Ignis starter |
| `fire_2` | Flame Burst | Fire | 1.8 | 3 | Higher tier |
| `water_1` | Splash | Water | 1.1 | 1 | Aria starter |
| `water_2` | Tide | Water | 1.7 | 3 | Higher tier |
| `wind_1` | Gust | Wind | 1.2 | 1 | Zeph starter |
| `earth_1` | Pebble | Earth | 1.1 | 1 | Craig starter |

> **All six spells are single-target damage.** There are no healing spells — potions are the only way to restore HP. Aria is a Water damage caster, not a support hero.

---

## ✅ How coders use this
1. Put heroes, enemies, items, spells into `data/` files (`.tres` resources or `.json`).
2. Wire hero base stats to match the Hero table (override `Elements.gd` scale if needed).
3. Enemy stats from the Enemy tables. **Do not author an action count** — derive it as `1 + int(STA / 30)` (see Actions per turn). Encounter enemies roll a random element on spawn; dungeon enemies use their fixed element.
4. Drop logic from the Drop table (roll on clear).
5. Item + spell effects from those tables. **Do not write your own damage math** — call `Combat.melee()`, `Combat.spell()`, `Combat.item()` so the UI and combat agree.
6. Enemy turns come from `EnemyAI.plan_turn()`; it drives `Targeting` and `Combat` for you.
7. Hand any balance complaints to the Playtester — these numbers are the **starting point**, not the final tuning.
