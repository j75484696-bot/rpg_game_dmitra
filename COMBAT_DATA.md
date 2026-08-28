# 🎲 Combat Data (Vertical Slice)

Every number the game runs on. Coders **wire data, not guesses** — if a value
isn't here, it isn't decided.

**Stat order everywhere: STA, HP, DEF, ATT, MAG, SPD.**

**Everything here is tuned in playtesting (Day 5).** These are starting values.

---

## 🧑‍🤝‍🧑 HERO STATS

### Level-1 base stats

These are derived from each element's letter grades in `Elements.gd`, so the
table and the code agree by construction.

| Hero | Element | STA | HP | DEF | ATT | MAG | SPD |
|---|---|---|---|---|---|---|---|
| **Ignis** | 🔥 Fire | 24 | 100 | 16 | 34 | 28 | 23 |
| **Aria** | 💧 Water | 30 | 170 | 16 | 23 | 23 | 18 |
| **Zeph** | 🌪️ Wind | 36 | 100 | 16 | 23 | 23 | 28 |
| **Craig** | 🪨 Earth | 30 | 120 | 32 | 18 | 18 | 13 |

Authored in `data/heroes/*.tres` and loaded by `Party.gd`. Edit the `.tres`,
not the script.

### Growth per level (automatic, before spent points)

| Hero | STA | HP | DEF | ATT | MAG | SPD |
|---|---|---|---|---|---|---|
| **Ignis** | +1 | +8 | +1 | +4 | +3 | +2 |
| **Aria** | +2 | +14 | +2 | +2 | +2 | +1 |
| **Zeph** | +2 | +8 | +1 | +2 | +2 | +4 |
| **Craig** | +2 | +11 | +3 | +2 | +1 | +1 |

A manually **spent** point uses `Character.PER_POINT`: STA+3, HP+15, DEF+3,
ATT+3, MAG+3, SPD+3. Growth and spent points are separate and independent.

```
final stat = level-1 base + growth x (level - 1) + spent points x PER_POINT
```

### Derived values — computed, never hand-entered
- **Max actions/turn** = `2 + int(STA / 30)` → Ignis 2, Aria 3, Zeph 3, Craig 3.
- **Ult meter** fills 0→100: `+1 per 2 damage dealt`, `+1 per 4 damage taken`.
  Starting values, tuned in playtest.

### Combat positions

**Only three heroes fight at a time.** The fourth is a substitute.

| Slot | Threat | Hero | Why |
|---|---|---|---|
| Front | 50 | **Ignis** | ⚠️ TEMPORARY — see below |
| Center | 30 | **Zeph** | Fast melee |
| Back 1 | 10 | **Aria** | Water caster, stays safe |
| **Back 2 — the bench** | **0** | **Craig** | ⚠️ TEMPORARY — see below |

> ⚠️ **Front and bench are currently swapped from the intended design.** Craig
> belongs at Front — wall, highest DEF+HP, draws aggro, guards — with Ignis
> benched as the substitute. Ignis was moved in on 2026-08-27 only because
> Craig has no sprite yet and the art needed viewing.
>
> **This is a balance change, not a cosmetic one.** Front draws the highest
> threat in the game while Ignis is the glass cannon (100 HP, 16 DEF vs
> Craig's 120/32), so he takes the most hits while least able to survive them.
> Revert `ignis.tres` to `position = 3` and `craig.tres` to `position = 0`
> before any playtest that judges balance.

`BACK2` is the **bench**, not a fourth combat slot. A benched hero generates
zero threat and is never built into a fight, so exactly three heroes are
targetable at any moment.

**Threat formula** — who the enemy is likely to hit:

```
threat = positional base + DEF + (HP / 10)
```

Weighted random, so tanks absorb most attacks but nobody is ever fully safe.
Dead and benched heroes score 0.

### Starting spells (max 3 equipped)

| Hero | Equipped at level 1 |
|---|---|
| Ignis | `fire_1` |
| Aria | `water_1` |
| Zeph | `wind_1` |
| Craig | `earth_1` |

Heroes learn one spell every 3rd level.

---

## 🌊 ELEMENT TYPE CHART

Ten elements. A matchup is **×1.5** super effective, **×0.5** not effective, or
**×1.0** neutral. Attacking is checked first: if A is strong against B, it's
×1.5; otherwise if B is strong against A, it's ×0.5.

| Attacker | Strong against (×1.5) |
|---|---|
| **Water** | Fire, Lava |
| **Fire** | Ice |
| **Wind** | Earth |
| **Earth** | Lightning, Light |
| **Ice** | Water, Wind, Dark |
| **Lightning** | Water, Sand |
| **Lava** | Fire, Wind |
| **Sand** | Dark, Light |
| **Dark** | Light |
| **Light** | Dark |

Every other pairing is neutral.

> ⚠️ **Dark and Light are strong against each other**, so that pairing is ×1.5
> in both directions and never ×0.5. Nothing in the demo uses either element,
> so it's harmless today — but it's the one asymmetry in the chart.

**What this means for the demo:** Zeph shreds Mudling (Wind→Earth). Ignis
shreds Frostbite Imp (Fire→Ice). Aria shreds Emberhound and Ashfang
(Water→Fire, Water→Lava). Ashfang resists Ignis and Zeph (Lava is strong
against Fire and Wind, so their hits land at ×0.5). Frostbite Imp is strong
against **both** Aria and Zeph — the sneakiest fight in the dungeon.

---

## 👹 ENEMIES

### Enemy stats are DERIVED, not authored

An enemy is three independent dials, stored in `data/enemies/*.tres` as a
`CreatureRating`:

```
stat = round(element base x rating / 10 x tier_scale)
```

| Dial | Answers | Range |
|---|---|---|
| **`ratings[]`** | What kind of creature is this? | 0–25 per stat, **fractional**. `10` = the element's base value |
| **`stat_element`** | Which element's numbers does it scale from? | Fixed per creature |
| **`tier_scale`** | How hard is this particular fight? | float, default `1.0` |

**`stat_element` is not the same as the battle element.** A creature with
`rolls_element = true` computes its stats from its fixed `stat_element` but
rolls a random element on spawn **for the damage matchup only**. That's what
keeps a Wisp fast and fragile no matter what element it rolls — its identity
lives in `ratings[]`, not in the roll.

**To retune an enemy, change its ratings.** Never hand-write a stat.

### Encounter enemies

Random overworld fights. Each rolls a random element on spawn for the matchup.

| Enemy | `stat_element` | Ratings (STA/HP/DEF/ATT/MAG/SPD) | Resulting stats | XP | Role |
|---|---|---|---|---|---|
| **Wisp** | Lightning | 10 / 4.5 / 3.75 / 4.35 / 4.29 / 5.88 | 18/45/6/10/12/20 | 8 | Fast, fragile, dies quick |
| **Critter** | Sand | 8 / 5 / 4.76 / 5 / 6.15 / 5 | 24/60/10/14/8/14 | 10 | Basic melee filler |
| **Brute** | Earth | 9.33 / 6.67 / 4.375 / 10 / 3.33 / 6.15 | 28/80/14/18/6/8 | 12 | Slow, chunky |

### Dungeon enemies

Fought in order. Difficulty ramps. Beatable by three level-1 heroes.

| Enemy | Element | Ratings | Resulting stats | XP | Notes |
|---|---|---|---|---|---|
| **Mudling** | 🪨 Earth | 6.67 / 5.83 / 3.125 / 7.78 / 3.33 / 7.69 | 20/70/10/14/6/10 | 15 | Weak warmup. Weak to Wind |
| **Frostbite Imp** | ❄️ Ice | 8 / 8.5 / 5.38 / 6.96 / 10 / 8.89 | 24/85/14/16/18/16 | 25 | Casts. Weak to Fire → Ignis shines |
| **Emberhound** | 🔥 Fire | 12.5 / 9.5 / 7.5 / 5.88 / 5 / 9.57 | 30/95/12/20/14/22 | 30 | Fast, hits twice. Weak to Water → Aria |
| **BOSS: Ashfang** | 🌋 Lava | 10 / 21.7 / 9.5 / 11.3 / 8.7 / 10 | 30/260/20/26/20/18 | 120 | Real threat. Weak to Water. Resists Fire and Wind |

### Actions per turn

**Derived — never hand-enter this.**

```gdscript
1 + int(STA / 30)     # enemy
2 + int(STA / 30)     # hero
```

Enemies floor at **1** and heroes at **2**, because the party outnumbers a
lone enemy. Giving enemies the hero floor doubles incoming damage in every
fight and makes the warmup encounters harder than the boss.

| STA range | Actions | Who |
|---|---|---|
| 0–29 | 1 | Wisp, Critter, Brute, Mudling, Frostbite Imp |
| 30–59 | 2 | Emberhound, Ashfang |
| 60+ | 3 | *(nobody yet — headroom)* |

**STA is the single dial for action economy.** To give an enemy another
action, raise its STA rating until it crosses 30. Never special-case a count
in code.

### Enemy AI

- `EnemyAI.plan_turn()` returns one action per available action, each
  `{ target, damage, redirected }`.
- Targets come from `Targeting.pick_target` (threat-weighted). Never pick
  ad-hoc per enemy.
- Enemies with 2+ actions can hit two targets or one target twice.
- **Ashfang** has `overwhelm = true`: below **50% HP** he switches to
  `pick_overwhelm`, hunting the lowest-HP hero and **ignoring both threat and
  Guard**. Driven by the flag on his `CreatureRating`, not a hardcoded branch.
- The whole turn is planned up front, so a 2-action enemy can be scheduled to
  hit someone who dies to the first blow.

---

## ❤️ SURVIVAL AND RECOVERY

**This is what makes the dungeon a run rather than four separate fights.**

| Rule | Detail |
|---|---|
| **HP carries between fights** | There is no rest, no auto-heal, no camp |
| **Potions are the only healing** | No healing spells exist. `item_potion` is the entire recovery system |
| **Level-up raises max HP, not current HP** | Levelling mid-dungeon makes a hero tougher going forward; it does **not** patch them up now |
| **A downed hero is revived with a potion** | **Mid-battle**, as a normal 1-action item use. Restores the potion's usual **+60 HP** and clears the downed status. There is no separate revive value |
| **Three revives per hero, per dungeon** | Each hero has their **own** counter. Ignis three, Aria three, and so on — spending one does not cost anyone else theirs |
| **A hero who dies a fourth time is out for the run** | Permanently downed. Can't be revived, can't be swapped back in |
| **Ult meter resets between fights** | It does not carry over |
| **Substitutes swap after every fight** | Any fight, not just at the entrance |

**The revive cap is not a potion cap.** Potions can be used as often as the
party can carry them, for healing or reviving. What's limited is how many
times any *one* hero can come back. The cap exists to stop a single fragile
hero being farmed back into the fight indefinitely — it isn't the resource the
player budgets.

That resource is **potion supply**. Attrition is the difficulty curve: HP
carries between fights, level-ups don't restore it, and the shop is on the
overworld, so a party that burns its potions on the warmup fight arrives at
Ashfang with nothing left. That's the intended tension.

**Reviving mid-battle makes the potion a real tactical decision.** The same
1-action potion that tops Craig up can instead bring Aria back from zero.

**Losing a hero permanently costs a slot.** Four heroes, three combat slots —
exactly one spare. The first hero lost for good is absorbed by the substitute;
the second leaves an empty slot and the party fights short-handed for the rest
of the run.

**The revive counters belong to the dungeon manager (M2)**, keyed per hero and
reset on entering a dungeon. They're per-run state, so they don't live on
`Character` or in `Inventory` — both of those persist.

---

## 🗺️ RUN STRUCTURE

**A dungeon run:** enter → three normal fights in order, with a prep menu
between each → Ashfang → clear.

**XP is awarded the moment an enemy dies**, not on clear, so heroes can level
mid-dungeon. That's why the prep menu needs a spend-your-point screen.

- Level **N** needs `N × 50` XP. Start simple, tune in playtest.
- Clearing the three normal enemies is ~70 XP, plus 120 for the boss ≈ **1–2
  level-ups** per run.
- Map encounters award a small flat **8–12 XP** each.

### Wiping

If the party is wiped — or the last hero falls with no revives left — you are
**ejected from the dungeon and lose every reward gathered on that run**:
items, gold, drops.

**XP is kept.** A failed run still makes the party stronger, so retrying is
progress rather than a pure reset.

### Ending the demo

Clearing the dungeon completes the vertical slice. The player can keep
roaming the overworld afterwards to try out gear and items they earned, but
there is **no further content** — no second dungeon, no endgame.

---

## 💰 DROPS

Rolled **on dungeon clear**, not per enemy. Each defeated enemy contributes to
a pooled roll; the boss guarantees a reward. Show the list on the victory
screen.

| Source | Drop pool |
|---|---|
| Mudling | 60% `item_potion`, 40% nothing |
| Frostbite Imp | 50% `item_potion`, 50% `item_grenade` |
| Emberhound | 50% `item_molotov`, 50% `item_bomb` |
| **Ashfang (boss)** | **Guaranteed:** `item_bomb` ×2 + one equippable (`equip_emberband` 70% / `equip_stoneplate` 30%) |

**Encounter enemies drop nothing.** Wisp, Critter and Brute award XP only.
They're fought on the overworld, where there is no "clear" event to roll
against.

---

## 💰 CURRENCY AND THE SHOP

> 🚧 **Scaffolded, not costed.** The system is agreed; every number below is
> **TBD** and needs a design pass. Don't wire a price until it's filled in.

**Gold** is the single currency. It lives with items in `Inventory`, the
party-wide autoload — one shared pool, **no capacity limit** on anything.

### Starting loadout

The party begins with healing potions, some gold, and **one starter item per
character** — four consumables dropped into the shared pool, not an equippable
each. No new equippables need designing.

| What | Amount |
|---|---|
| `item_potion` | **TBD** (currently 3 as a placeholder) |
| Gold | **TBD** (currently 0) |
| Four starter items, one per character | **TBD** — which four, from the consumable list |

### The shop

**The shop is an overworld location.** The player walks to it on the map, the
same way they walk to the dungeon entrance, and it opens as a full-screen
screen pushed from `map.gd`.

That placement has a real design consequence: **you cannot shop mid-run.**
Restocking happens between dungeon runs, so what you carry in is what you
have. It keeps the dungeon a closed attrition test and makes the pre-run
potion purchase a genuine decision.

| Question | Status |
|---|---|
| Where is it? | **Overworld map.** Pushed scene, `ui/menus/shop.tscn` |
| What does it stock? | **TBD** — presumably the four consumables; equippables unclear |
| Prices | **TBD** |
| Can you sell? | **TBD** — and at what rate |
| Where does gold come from? | **TBD** — enemy drops, a flat clear reward, or both. No enemy currently has a gold value |

---

## 🧪 ITEMS

### Consumables — usable in battle, cost 1 action

| ID | Name | Effect | Value | Element |
|---|---|---|---|---|
| `item_potion` | Potion | Heal one hero, or revive a downed one (**the only healing in the game**) | +60 HP | — |
| `item_molotov` | Molotov | Damage one enemy | 40 | Fire (matchup applies) |
| `item_bomb` | Bomb | Damage one enemy | 45 | Neutral (**no matchup**) |
| `item_grenade` | Elemental Grenade | Damage one enemy | 35 | Chosen on use (matchup applies) |

Item damage **ignores the thrower's ATT**: `(item value - target DEF) × matchup`.

### Equippables

| ID | Name | Bonus | Requirement |
|---|---|---|---|
| `equip_emberband` | Emberband | +6 MAG, +2 ATT | None |
| `equip_stoneplate` | Stoneplate | +8 DEF, +20 HP | STA ≥ 28 |

If the stat is below the requirement, block the equip and show a message.

---

## ⚔️ DAMAGE RULES

Implemented in `core/Combat.gd`. **Combat code and UI both call it**, so both
get the same number. One shape:

```
(raw - target DEF) x element matchup
```

**Order matters.** DEF comes off *first*, then the matchup multiplies. The
other way round lets a super-effective hit punch through armour far harder
than intended.

| Source | Raw value | Matchup? |
|---|---|---|
| Melee | attacker's ATT | yes |
| Spell | attacker's MAG × spell multiplier | yes |
| Item | the item's flat value | yes, except `item_bomb` |

- **Minimum damage is 1.** Stops a bad matchup against a tanky target dealing
  0 and stalling the fight.
- **Results floor, they don't round.** DEF is never worth less than face value.

**Guard** resolves after, via `Targeting.resolve_guard()`: the hit redirects to
the guardian at **−40%**.

> ⚠️ The damage was already computed against the **original target's** DEF.
> Redirecting doesn't recompute, so a high-DEF guardian gains nothing from
> their own armour when soaking. Flag it if playtesting hates it.

**Healing** is flat and item-only. `Combat.heal()` caps to missing HP, so a
potion can't overheal. It returns the amount **actually** restored — that's
the number the floating text should show.

**Ult meter** — `Combat.ult_gain()`: `+1 per 2 damage dealt, +1 per 4 taken`,
clamped to 100 by the caller.

### Action rules

| Rule | Why |
|---|---|
| **All four action types cost 1** | Split `Actions.COST` apart if a spell should ever cost two |
| **Actions don't bank** | Anything unspent at end of turn is lost |
| **Guard doesn't end your turn** | A 3-action hero can guard and still attack twice |
| **One guardian protects one ally** | Declaring again reassigns rather than stacking |
| **A guardian's own turn clears their guard** | It lasts until they act again |
| **Speed ties go to the hero** | The party shouldn't lose a race it drew |
| **Turn order rebuilds each round** | A SPD change mid-fight takes effect next round, not never |
| **A mutual kill is a loss** | Party wipe is tested first, so a wiped party never sees the victory screen |

---

## 🔮 SPELLS (6 total)

All six are **single-target damage**. There are no healing spells. IDs are
`<element>_<n>`.

```
damage = (MAG x multiplier - target DEF) x matchup
```

| ID | Name | Element | Multiplier | Learned |
|---|---|---|---|---|
| `fire_1` | Ember | Fire | 1.2 | 1 |
| `fire_2` | Flame Burst | Fire | 1.8 | 3 |
| `water_1` | Splash | Water | 1.1 | 1 |
| `water_2` | Tide | Water | 1.7 | 3 |
| `wind_1` | Gust | Wind | 1.2 | 1 |
| `earth_1` | Pebble | Earth | 1.1 | 1 |

> 🚧 **Wind and Earth have no tier-2 spell**, but `Character.refresh_spells()`
> generates `wind_2` and `earth_2` at level 3 regardless. Level 3 is reachable
> inside the demo, so this will fire. Deferred, not fixed.

> ❓ `water_2`'s **1.7** was chosen to parallel `fire_2`'s 1.8. Needs sign-off.

---

## ✅ How coders use this

1. **Heroes** are `data/heroes/*.tres`; **enemies** are `data/enemies/*.tres`.
   Retune by editing the resource, never the script.
2. **Never author a stat or an action count.** Enemy stats come from
   `CreatureRating.build()`; action counts come from STA.
3. **Never write your own damage math.** Call `Combat.melee()` / `spell()` /
   `item()` / `heal()` so the UI and the fight can't disagree.
4. Enemy turns come from `EnemyAI.plan_turn()`; it drives `Targeting` and
   `Combat` for you.
5. Gold and items go through `Inventory`.
6. Hand balance complaints to the Playtester — these are the **starting
   point**, not final tuning.
