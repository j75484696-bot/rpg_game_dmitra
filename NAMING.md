# 🏷️ Asset Naming Spec

**Rules:** lowercase · underscores · no spaces · no capitals · zero-padded numbers.
Every asset must map to a slot the code expects. If a name isn't in this file, it isn't agreed — add it here first, then create the asset.

Formats: sprites/UI/icons = **PNG, transparent background**. Audio = **OGG**.

## 🎞️ Animation states at a glance
Every animated character can have these states. `<frame>` is always zero-padded from `01`. If a state has no frames, code falls back (sway/scale) so nothing blocks the build.

| State | Where | Pattern | Directional? |
|---|---|---|---|
| Overworld walk | Map, moving | `hero_<name>_ow_<dir>_<frame>.png` | Yes (down/up/left/right) |
| Overworld idle | Map, standing | `hero_<name>_idle_<dir>_<frame>.png` | Yes |
| Battle idle | Combat, resting | `hero_<name>_bidle_<frame>.png` | No |
| Attack | Combat, attacking | `hero_<name>_atk_<frame>.png` | No |
| Hurt | Combat, hit | `hero_<name>_hurt.png` | No (single frame) |
| Hover | Prep/select menus | code effect (or `hero_<name>_hover_<frame>.png`) | No |

Enemies + bosses use the same `bidle` / `atk` patterns with `enemy_` / `boss_` prefixes.

---

## 🧍 Static sprites

| Type | Pattern | Example |
|---|---|---|
| Hero (combat) | `hero_<name>.png` | `hero_ignis.png` |
| Enemy | `enemy_<name>.png` | `enemy_goblin.png` |
| Boss | `boss_<name>.png` | `boss_ashfang.png` |
| Tile | `tile_<type>.png` | `tile_grass.png` |
| Prop | `prop_<type>.png` | `prop_tree.png` |

---

## 🚶 Overworld walk animations

Direction is part of the name. Directions are always: **down, up, left, right**. Frames are **zero-padded, starting at `01`**.

```
hero_<name>_ow_<dir>_<frame>.png
```

| Piece | Values |
|---|---|
| `<name>` | ignis, aria, zeph, craig |
| `<dir>` | down, up, left, right |
| `<frame>` | 01, 02, 03, 04 … (as many as the cycle has) |

**Examples**
```
hero_craig_ow_down_01.png     ← Craig, walking down, frame 1
hero_craig_ow_down_02.png
hero_craig_ow_up_01.png
hero_craig_ow_left_01.png
hero_craig_ow_right_01.png
```

**Conventions (agree once, never break):**
- `_walk_` frames are the MOVING cycle only. The standing-still pose is the separate **idle** animation below — don't reuse a walk frame as idle.
- Frames play in ascending order then loop back to `01`.
- **Left/right:** if the artist mirrors `left` to make `right` (common + fast), still export BOTH files — don't make the coder flip it in engine.
- **Demo target:** 2-frame walk (`01`, `02`) per direction = 8 files per hero. Full version: 4 frames per direction = 16 per hero.

> Only the **party-leader** hero needs an overworld walk set for the demo (that's the sprite you see on the map). The other three don't need overworld frames this week.

---

## 🌬️ Overworld IDLE animations

Plays when the hero is standing still on the map — a gentle bob/breathe so they're not a frozen statue. Direction-specific (they face where they last walked).

```
hero_<name>_idle_<dir>_<frame>.png
```

**Examples**
```
hero_craig_idle_down_01.png
hero_craig_idle_down_02.png
hero_craig_idle_up_01.png
```

**Conventions:**
- Loops `01 → 02 → …` and back. A slow 2-frame bob reads great.
- If the hero has NO idle frames yet, code just shows `hero_<name>_ow_down_01` standing still — idle is an upgrade, not a blocker.
- **Demo target:** 2 frames, **down direction only** (that's what shows most). Full version: 2 frames × 4 directions.

---

## ⚔️ Attack / battle animations

Battle animations don't need directions (combat is front-facing). Frames zero-padded from `01`.

```
hero_<name>_atk_<frame>.png       ← hero attacking
hero_<name>_hurt.png              ← single flinch frame (optional, code flash covers it)
enemy_<name>_atk_<frame>.png      ← enemy attacking
boss_<name>_atk_<frame>.png       ← boss attacking
```

**Examples**
```
hero_ignis_atk_01.png
hero_ignis_atk_02.png
hero_ignis_atk_03.png
hero_craig_hurt.png
enemy_goblin_atk_01.png
boss_ashfang_atk_01.png
boss_ashfang_atk_02.png
```

**Conventions:**
- The **static combat sprite** (`hero_ignis.png`) is the fallback resting pose. Attack frames are the extra motion on top; the looping breathe is the separate battle idle below.
- **Demo target:** 1–2 attack frames each. Movement (lunge toward enemy, recoil) is done in CODE via tween — the frames are just the pose change (e.g. weapon raised). Deaths + hits = code fade/flash/shake, **no frames needed**.
- If a character has NO attack frames yet, code lunges the static sprite so combat still works. Attack frames are an upgrade, not a blocker.

---

## 😤 Battle IDLE animations (heroes + enemies)

Plays constantly during combat so nobody stands frozen — a subtle breathe/sway loop. Front-facing, no direction.

```
hero_<name>_bidle_<frame>.png      ← hero battle idle
enemy_<name>_bidle_<frame>.png     ← enemy battle idle
boss_<name>_bidle_<frame>.png      ← boss battle idle
```

**Examples**
```
hero_ignis_bidle_01.png
hero_ignis_bidle_02.png
enemy_goblin_bidle_01.png
boss_ashfang_bidle_01.png
boss_ashfang_bidle_02.png
```

**Conventions:**
- `bidle` = "battle idle" (kept short + distinct from overworld `idle`).
- Loops `01 → 02 → …` and back. A slow 2-frame breathe is enough.
- Fallback: if no `bidle` frames exist, code shows the static combat sprite (`hero_ignis.png`) and adds a gentle sway/scale tween — so it still feels alive with zero frames.
- **Demo target:** 2 frames each for the 4 heroes + boss. Normal enemies can rely on the code-sway fallback if art time is short.

---

## ✨ Hover animations (prep + selection screens)

Feedback when the player hovers/highlights a hero card, enemy target, spell, or item in the prep and selection menus. **Most hover feedback should be done in CODE** (scale-up, glow, lift) — only make sprite frames if you want something fancier.

**Preferred (no art needed):** code scales the existing sprite/icon ~110% + adds a glow or outline on hover. Zero files.

**Optional sprite-based hover** (only if a designer wants a custom reaction pose):
```
hero_<name>_hover_<frame>.png      ← e.g. character does a little flourish on hover
```
```
hero_zeph_hover_01.png
hero_zeph_hover_02.png
```

**Conventions:**
- Default to the code effect — it's instant, consistent across every card, and costs no art time.
- Reserve sprite `_hover_` frames for a hero/boss you want to show off. Not a demo must-have.
- Highlight frames/outlines for UI cards use the UI naming instead: `ui_card_highlight.png`.

---

## 🔮 Spell visual effects (VFX)

```
vfx_<element>_<frame>.png         e.g. vfx_fire_01.png, vfx_fire_02.png
```
One effect per element used in the demo (fire, water, wind, earth). 1–3 frames each, or a single frame + code particles.

---

## 🖼️ UI

| Type | Pattern | Example |
|---|---|---|
| UI element | `ui_<element>.png` | `ui_hpbar.png` |
| UI button | `ui_btn_<action>.png` | `ui_btn_attack.png` |

---

## 🎴 Icons

| Type | Pattern | Example |
|---|---|---|
| Spell icon | `icon_spell_<element>_<n>.png` | `icon_spell_fire_1.png` |
| Skill icon | `icon_skill_<n>.png` | `icon_skill_1.png` |
| Item icon | `icon_item_<name>.png` | `icon_item_potion.png` |

---

## 🔊 Audio

| Type | Pattern | Example |
|---|---|---|
| Music | `bgm_<name>.ogg` | `bgm_battle.ogg` |
| Sound effect | `sfx_<name>.ogg` | `sfx_hit.ogg` |

---

# 📋 Exact file list the vertical slice needs

Check these off as they're made. **Bold = must-have; others = nice-to-have.**

### Heroes (Designer 1)
- **`hero_ignis.png`**, **`hero_aria.png`**, **`hero_zeph.png`**, **`hero_craig.png`** (static combat sprite / fallback)
- **`hero_<name>_bidle_01.png`** + `_02` — battle idle breathe, all 4 heroes
- `hero_<name>_atk_01.png` … 1–2 attack frames each
- `hero_<name>_hover_01.png` — optional menu hover pose (code hover preferred, skip unless showing off)
- Party-leader overworld set: **`hero_<leader>_ow_<dir>_01.png`** + `_02` (walk) for down/up/left/right, plus **`hero_<leader>_idle_down_01.png`** + `_02` (map idle bob)

### Enemies + Boss (Designer 1)
- **`enemy_<a>.png`**, **`enemy_<b>.png`**, **`enemy_<c>.png`** (3 normal, static)
- **`boss_ashfang.png`** (rename to your boss)
- **`boss_ashfang_bidle_01.png`** + `_02` — boss battle idle
- `enemy_<x>_bidle_01.png` — enemy battle idle (optional; code-sway fallback if skipped)
- `enemy_<x>_atk_01.png` / `boss_ashfang_atk_01.png` (optional)

### Environment (Designer 2)
- **`tile_grass.png`**, **`tile_path.png`**, **`tile_grass_edge.png`**
- **`prop_tree.png`**, **`prop_bush.png`**
- **`ui_dungeon_marker.png`** (the map entrance icon)
- **`ui_shop_marker.png`** (the shop's spot on the overworld)
- **`bg_dungeon.png`** (single static battle background)
- `bg_menu.png`, `bg_victory.png`, `bg_defeat.png`

### UI · Icons · VFX (Designer 3)
- **`ui_hpbar.png`**, **`ui_stamina.png`**, **`ui_ultmeter.png`**, **`ui_panel.png`**
- **`ui_btn_attack.png`**, **`ui_btn_spell.png`**, **`ui_btn_item.png`**, **`ui_btn_guard.png`**
- **`icon_spell_<element>_<n>.png`** ×6
- **`icon_skill_1.png`** … `icon_skill_5.png`
- **`icon_item_potion.png`**, **`icon_item_molotov.png`**, **`icon_item_bomb.png`**, **`icon_item_grenade.png`**
- **`ui_shop_panel.png`** (shop screen frame), **`icon_gold.png`** (currency)
- `vfx_fire_01.png`, `vfx_water_01.png`, `vfx_wind_01.png`, `vfx_earth_01.png`
- `ui_title_logo.png`

### Audio (Designer 3)
- **`bgm_battle.ogg`**, `bgm_map.ogg`, `bgm_menu.ogg`, `bgm_victory.ogg`
- **`sfx_hit.ogg`**, **`sfx_cast.ogg`**, **`sfx_hurt.ogg`**, **`sfx_button.ogg`**, `sfx_levelup.ogg`, `sfx_victory.ogg`, `sfx_item.ogg`, `sfx_purchase.ogg`
