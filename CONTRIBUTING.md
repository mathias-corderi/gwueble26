# Contributing guide

Everything content-related (chairs, enemies, art, music) is **drop-in**: you add files and set fields in the Godot inspector — no code required. Code contributions are welcome too; the last section covers the common ones.

## Setup

1. Install **Godot 4.7** (standard build, no .NET needed).
2. Clone the repo and open `project.godot` with Godot.
3. Press **F5** to play. Press **R** in game to restart a run.

Work on a branch and open a PR to `main` — never push directly to `main`.

```
git checkout -b my-feature
# ...work...
git push -u origin my-feature
```

## Adding / replacing MUSIC 🎵

Each chair has its own theme that plays while you sit on it (the game crossfades automatically; any track loops by itself, no need to author a seamless loop).

- **Replace a placeholder**: overwrite the matching file in `audio/` keeping the same filename (e.g. `audio/throne.wav`). Done — nothing else to touch.
- **Add a new track**: drop your file anywhere in `audio/` (`.ogg` recommended, `.wav`/`.mp3` also fine), then open the chair's `.tres` in `data/chairs/`, and drag your file into the **Music** field in the inspector.

There is no global/standing music yet — if you compose one, ping the team and we'll wire it into `MusicManager`.

## Adding ART 🎨

Sprites are optional everywhere: if a sprite field is empty, the game draws the colored placeholder shape instead. So you can deliver art incrementally, one PNG at a time.

- **Chairs**: drop your PNG in `art/`, open the chair's `.tres` in `data/chairs/`, and assign it to the **Sprite** field. The sprite is auto-scaled to the chair's footprint (~48×56 px on screen), so any resolution works — roughly square-ish with the backrest at the top reads best.
- **Enemies**: same, on the `.tres` files in `data/enemies/` (**Sprite** field). Auto-scaled to the enemy's `radius`.
- **Weapons**: `.tres` files in `data/weapons/` — **Sprite** (map pickup) and **Projectile Sprite** (authored pointing **right**; projectiles auto-rotate).
- **8-direction animated art** (player body, held weapons, chairs) has its own full spec — see [docs/ANIMATION_GUIDE.md](docs/ANIMATION_GUIDE.md). The single-PNG fields above are quick placeholders; the animation system supersedes them when frames are assigned.

Keep in mind enemies flash white when hit and orange while burning, and chairs blink during burnout — very dark or pure-white sprites make those cues hard to read.

## Creating a CHAIR 🪑

1. In the Godot FileSystem dock, duplicate any `.tres` in `data/chairs/` (Ctrl+D) and rename it.
2. Select it and edit the fields in the inspector. That's it — the spawner scans `data/chairs/` at startup, so your chair is already in the game.

| Field | What it does |
|---|---|
| `display_name` / `color` | Label over the chair; the color tints the placeholder, HUD theme and crosshair |
| `max_hp` | How much enemy punishment the chair takes before breaking |
| `meter_time` | Seconds seated until its passive is granted/refreshed (then the chair burns out) |
| `move_speed` | 0 = static chair; > 0 = it's a **mount** you drive with WASD while seated, at this speed |
| `passive_id` | One of the ids in `RunState.PASSIVES` (`triple_shot`, `homing`, `burn`, `explosive`, `pierce`) |
| `secondary_id` + `secondary_cooldown` / `secondary_uses` / `secondary_power` | Optional right-click ability while seated. Empty id = none. Implemented: `shockwave`. `secondary_uses = -1` means unlimited (cooldown only) |
| `music`, `sprite`, `chair_frames` | Presentation (all optional; `chair_frames` is the 8-direction set, see the animation guide) |

**How passives work now (burning bars)**: filling a chair's meter grants its passive with a decaying timer — when the bar burns out, the passive is lost. Filling another chair of the same type resets the timer and levels the passive up (up to its `max_level` in `RunState.PASSIVES`; e.g. Triple Shot stacks to Lv3, Homing doesn't level). Balance intuition: strong passive or secondary → compensate with low `max_hp`, long `meter_time`, or being static.

Note chairs no longer have a primary attack — that's the weapon's job now.

## Creating a WEAPON 🔫

Duplicate a `.tres` in `data/weapons/` and edit in the inspector: `display_name`, `color`, `handedness` (one/two-handed — only affects animation variants), `max_ammo` (the weapon is discarded at 0; 1 ammo per shot), and the attack params (`fire_rate`, `damage`, `projectile_count`, `spread_degrees`, `projectile_speed/radius/color`). Weapons spawn on the map, are picked up on contact (max 3 carried), and are switched with the mouse wheel. Auto-loaded from the folder, no code needed.

## Creating an ENEMY 👾

Duplicate a `.tres` in `data/enemies/` and edit: `color`, `radius` (visual + hitbox size), `speed`, `max_hp`, `contact_damage`, `attack_interval` (seconds between contact hits), and `unlock_time` (seconds into the run before it starts spawning). Auto-loaded the same way.

## Code contributions

- **New passive**: add its entry (name, duration, max_level) to `PASSIVES` in `scripts/autoload/run_state.gd`, then implement its effect — projectile behaviors go in `scripts/projectile.gd` (see the `burn_level`/`explosive_level`/`pierce` handling), shot-count effects in `Player._fire()` (see `triple_shot`).
- **New chair secondary**: add a case to the `match data.secondary_id` in `Chair.try_secondary()` (`scripts/chair.gd`); `Combat` (`scripts/combat.gd`) has shared helpers like `knockback_enemies`.
- Balance constants live at the top of each script (`STANDING_DRAIN`, `KNOCKBACK_*`, `SHOCKWAVE_*`, spawner ramps, etc.).

## Before opening a PR

Run the game and sanity-check your change, then run the headless test (should print `SMOKE TEST OK`):

```
godot --headless --path . res://test/smoke_test.tscn
```