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

- **Chairs**: drop your PNG in `art/`, open the chair's `.tres` in `data/chairs/`, and assign it to the **Sprite** field (and optionally **Projectile Sprite** for its shots). The sprite is auto-scaled to the chair's footprint (~48×56 px on screen), so any resolution works — roughly square-ish with the backrest at the top reads best.
- **Enemies**: same, on the `.tres` files in `data/enemies/` (**Sprite** field). Auto-scaled to the enemy's `radius`.
- **Player**: open `scenes/player.tscn`, select the root node, assign **Sprite** in the inspector (~30×30 px on screen).
- Projectiles auto-rotate to face their direction of travel — author them pointing **right**.

Keep in mind enemies flash white when hit and orange while burning, and chairs blink during burnout — very dark or pure-white sprites make those cues hard to read.

## Creating a CHAIR 🪑

1. In the Godot FileSystem dock, duplicate any `.tres` in `data/chairs/` (Ctrl+D) and rename it.
2. Select it and edit the fields in the inspector. That's it — the spawner scans `data/chairs/` at startup, so your chair is already in the game.

| Field | What it does |
|---|---|
| `display_name` / `color` | Label over the chair; the color tints the placeholder, HUD theme and crosshair |
| `max_hp` | How much enemy punishment the chair takes before breaking |
| `meter_time` | Seconds seated until its passive becomes **permanent** (then the chair burns out) |
| `fire_rate`, `damage`, `projectile_count`, `spread_degrees`, `projectile_speed/radius/color` | The attack. With 1 projectile, spread = random jitter; with several, spread = fan width |
| `passive_id` | One of `triple_shot`, `homing`, `burn`, `explosive`, `pierce` — active while seated, permanent once the meter fills |
| `music`, `sprite`, `projectile_sprite` | Presentation (all optional) |

Balance intuition: strong attack or passive → compensate with low `max_hp` or long `meter_time`. Passives stack across a run, so late-game synergy is the fun part — think about how your chair feels once the player already owns other passives.

## Creating an ENEMY 👾

Duplicate a `.tres` in `data/enemies/` and edit: `color`, `radius` (visual + hitbox size), `speed`, `max_hp`, `contact_damage`, `attack_interval` (seconds between contact hits), and `unlock_time` (seconds into the run before it starts spawning). Auto-loaded the same way.

## Code contributions

- **New passive**: add its id + display name to `PASSIVE_NAMES` in `scripts/autoload/run_state.gd`, then implement its effect — projectile behaviors go in `scripts/projectile.gd` (see the `homing`/`burn`/`explosive`/`pierce` flags), shot-count/volley effects in `Player._fire()` (see `triple_shot`).
- **Exotic chair attacks** (lasers, orbiting shields…): `ChairData.custom_attack_scene` is reserved for this but not wired up yet — talk to the team before building on it.
- Balance constants live at the top of each script (`STANDING_DRAIN`, `KNOCKBACK_*`, spawner ramps, etc.).

## Before opening a PR

Run the game and sanity-check your change, then run the headless test (should print `SMOKE TEST OK`):

```
godot --headless --path . res://test/smoke_test.tscn
```