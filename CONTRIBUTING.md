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
- **Weapons**: `.tres` files in `data/weapons/` — **Sprite** (map pickup) and **Projectile Sprite** (authored pointing **right**; projectiles auto-rotate). For **BEAM** weapons the projectile sprite is a horizontally-tileable strip instead — see the weapon section below.
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
| `passive_id` | One of the ids in `RunState.PASSIVES` — see the list below |
| `secondary_id` + `secondary_cooldown` / `secondary_uses` / `secondary_power` | Optional right-click ability while seated. Empty id = none. `secondary_uses = -1` means unlimited (cooldown only). Implemented: `shockwave`, `musical_wave` (push + slow), `eye_burst` (8 big bullets mimicking your weapon), `dash` (charge forward, invulnerable, damaging contacts), `missiles` (10 homing missiles), `charge_laser` (1 s wind-up, then a giant beam), `spear` (wide short lunge) |
| `break_effect_id` + `break_effect_power` | Optional blast fired whenever the chair breaks — from enemy damage, burnout, *or* standing up voluntarily, so popping your own chair is a tactic. Empty id = none (every break already knocks enemies back). Implemented: `electric_burst`, `shatter` (damaging seat fragments), `blast` (wide damaging shove), `spear_burst` (spears in the 4 cardinal directions). `break_effect_power` scales radius and damage |
| `music`, `sprite`, `chair_frames` | Presentation (all optional; `chair_frames` is the 8-direction set, see the animation guide) |

**How passives work now (burning bars)**: filling a chair's meter grants its passive with a decaying timer — when the bar burns out, the passive is lost. Filling another chair of the same type resets the timer and levels the passive up (up to its `max_level` in `RunState.PASSIVES`; e.g. Triple Shot stacks to Lv3, Homing doesn't level). Sitting on a chair whose passive you already own keeps that passive's bar **pinned at full** while you stay seated — it only starts burning down again when you stand up. Balance intuition: strong passive or secondary → compensate with low `max_hp`, long `meter_time`, or being static.

Note chairs no longer have a primary attack — that's the weapon's job now. Unoccupied chairs are recycled after 2 minutes, but only while off-camera, so one never vanishes in front of the player.

**Passive ids** (in `RunState.PASSIVES`): `triple_shot` (extra bullets), `pierce` (bullets pass through enemies; also makes the laser wider), `homing` (bullets/laser curve toward enemies), `arc` (chain lightning on hit — see below), `split` (bullets scatter into fragments on hit, +1 per level; the laser instead forks `1 + level` branch beams at every enemy it pierces), `knockback` (bullets shove enemies), `poison` (a % of max HP per second, green — the current fire/DoT), `sonic` (small AoE that damages + slows on hit), `bounce` (plain bullets ricochet off enemies to the next one; pierce bullets and the laser instead reflect off the **camera edge**, as if the screen border were a wall). `burn`, `explosive` and the `shockwave` secondary stay defined as reusable mechanics but no default chair grants them.

**Laser feel**: the beam has mass. The near end tracks the cursor while the far end trails a smoothed, time-lagged history of recent aim, and each segment's heading is curvature-capped, so sweeping it ripples outward like a water jet instead of snapping (a laser pointer) or coiling (a rope). Homing settles gradually — a slow exit turn plus a wide curve radius weaves S curves between enemies on either side rather than snapping onto them. The thickness also grows in from a hairline when firing starts and shrinks back out when it stops. All tuned in `laser_beam.gd` via `SEGMENTS` / `HISTORY_SPAN` / `BEAM_CURVE_RADIUS` (wave), `AIM_TURN_RATE` / `CURVE_RADIUS` (homing) and `WIDTH_ANIM_SPEED` (grow/shrink). All three laser sources — the Laser Gun, the Mech laser and the Atomic Throne's `charge_laser` — share this one `LaserBeam` node, so every change applies to all of them.

**Laser glow & rendering**: laser cores are pushed into HDR (colour components past 1.0) so they **bloom** under the additive-glow `WorldEnvironment` that `main.gd` builds in code, and each beam sprays colour-matched impact sparks (in a cone opposite its travel) plus `PointLight2D`s that tint nearby objects. The bloom needs the **Forward+ / Mobile** renderer and `rendering/viewport/hdr_2d` (both set in `project.godot`); the older GL Compatibility renderer has no 2D glow, so **web export is no longer supported**.

**The `arc` passive (Electric Arc)**: every bullet that hits an enemy fires a chain of lightning to the nearest enemies within a large radius, and each passive level adds one more jump. The laser triggers it too, with the cooldown tracked **per hit enemy** — a beam crossing three enemies throws three independent arcs.

**Testing everything at once**: open `scenes/sandbox.tscn` in Godot and press **F6** — it lays out one of every chair and weapon (each respawns 2 s after use) and spawns enemies normally. To build the Mech, farm parts fast: seat a chair and press **E**, which fills its meter and breaks it (dropping a part) in one go, then haul the parts to the central **station** (carrying is uncapped here) and board the assembled Mech. It's editor-only; the game still starts from `main.tscn`.

## Creating a WEAPON 🔫

Duplicate a `.tres` in `data/weapons/` and edit in the inspector. Weapons spawn on the map, are picked up on contact (max 3 carried), and are switched with the mouse wheel. Auto-loaded from the folder, no code needed.

Special-case fields: `max_ammo = -1` means **infinite ammo** (never spent, never discarded), `reload_interval` refills the weapon to full every N seconds (0 = never), and `spawns_on_map = false` keeps it out of the world spawner — that's how the Mech's built-in weapons stay exclusive to the Mech.

`energy_seconds` + `energy_recharge_time` add a **fuel gauge** for continuous (BEAM) weapons, shown as a % in the HUD. Firing drains it in real time; **it does not recharge while you hold a reserve**. Only when it hits 0% does the weapon lock and start refilling, and it stays locked until back at 100%. So you can fire measured bursts indefinitely, but emptying it costs you the full cooldown — see the Mech laser (10 s of fire, 30 s recharge).

There is no inventory cap — the player carries as many weapons as they find. Walking over a weapon **already carried** restocks its ammo instead of duplicating it, up to **2× its `max_ammo`**; at that cap the pickup is left on the map for later.

Common fields: `display_name`, `color`, `handedness` (one/two-handed — only affects animation variants), `max_ammo` (the weapon is discarded at 0). `attack_type` decides how the attack fields are read:

- **`PROJECTILE`** (bullets — Pistol, Assault Rifle, Shotgun): `fire_rate`, `damage`, `projectile_count`, `spread_degrees`, `projectile_speed/radius/color`, and `projectile_lifetime` (seconds before a bullet despawns — short values make short-range weapons like the Shotgun). 1 ammo per shot/volley.
- **`BEAM`** (continuous laser, channeled while holding fire — Laser Gun): the same fields are reinterpreted. `fire_rate` = damage ticks per second, `damage` = damage per tick, **1 ammo per tick** (so `max_ammo / fire_rate` = seconds of total beam time), `projectile_count` + `spread_degrees` = fan of simultaneous beams, `projectile_radius` = beam half-width, `projectile_color` = beam tint. The ray visually extends past the screen edge (only enemies on camera are hit), is stopped by walls, and innately pierces everything it crosses. Passives adapt automatically: Triple Shot adds beams, Homing curves the beam smoothly through nearby enemies (it always leaves along the aim, then continues straight after the last target), Burn ignites everything touched, Explosive pops periodic mini-explosions on the enemies being hit, and Pierce widens the beam.

**Beam art**: on a BEAM weapon, `projectile_sprite` is a **horizontally-tileable grayscale strip** (see `art/fx/laser_beam.png`, 16×16): its width tiles along the ray, its height stretches to the beam thickness, and the game tints it with `projectile_color`. Replace the PNG and the art updates itself; leave the field empty for a flat colored line placeholder.

**Lightning art (Electric Arc)**: the arcs are generated procedurally — the game builds a zig-zagging path and re-rolls it several times per second, so the chaotic motion is already there and **no sprite is required**. To upgrade the look, drop a file at exactly `res://art/fx/lightning_bolt.png` and every arc picks it up automatically, with no field to assign. Author it like the laser strip (horizontally tileable, grayscale — the game tints it), but with a **spikier, noisier profile**: hard bright core, ragged edges, a few stray pixels off to the sides. A short tile (~8–16 px wide) reads best, since it repeats many times along a jittering path.

## The MECH 🤖

The run's long-term goal. Every chair that **fills its meter** and then breaks ejects a robotic **part** that stays on the map forever. The player carries up to **3 parts** at a time and delivers them to the station at the centre of the arena; at **10 delivered parts** the Mech is assembled and can be boarded with E.

Boarding it **clears and closes the map**: every remaining chair, weapon pickup and loose part is removed, their spawners stop, and the mech-gated enemies (the Sentry) wake up. The robot itself is indestructible, but it is **not** a shield — everything that hits it is passed straight to the pilot's HP, and in the Mech you only start healing after 4 seconds without taking a hit.

The Mech is permanent: it never breaks, has no meter, is driven with WASD, and you can't get off. It carries **the passive of every chair that contributed a part** — parts from the same chair type stack into higher levels, exactly like sitting on that chair again — and those passives **never burn out**. It brings its own weapons (an infinite-ammo chaingun and a laser that auto-reloads) plus a shockwave on right click.

Balance knobs live in `RunState` (`MECH_PARTS_REQUIRED`, `MAX_CARRIED_PARTS`) and `data/chairs/mech.tres` (speed, secondary). The Mech is a normal `ChairData` with `spawns_on_map = false`, so it never appears as a random chair.

### Mech ART 🎨

The station shows **one build stage per delivered part**, from bare frame to finished robot. To add the art:

1. Author **10 PNGs**, one per stage — the same robot growing piece by piece. Use a **consistent canvas size and pivot** across all 10 so the silhouette builds up in place instead of jumping around; the game scales each one to fit and grows the footprint as the stages advance.
2. Drop them in `art/`, select the `MechStation` node in `scenes/main.tscn`, and assign them **in order** to the `Build Stage Sprites` array.
3. Put the 10th (finished robot) into `data/chairs/mech.tres`'s `sprite` field, so the Mech the player boards matches the last build stage.

Partial deliveries are fine — assign whatever stages exist and the station shows the highest one authored so far. Until any art lands, a placeholder silhouette gains a visible piece per stage (feet → legs → hips → torso → core → arms → head → optics → cannons).

## Creating an ENEMY 👾

Duplicate a `.tres` in `data/enemies/` and edit: `color`, `radius` (visual + hitbox size), `speed`, `max_hp`, `contact_damage`, `attack_interval` (seconds between contact hits), and `unlock_time` (seconds into the run before it starts spawning). Auto-loaded the same way.

Two optional behaviours turn a charger into something else — see `data/enemies/sentry.tres`, which uses both:

| Field | What it does |
|---|---|
| `preferred_distance` | > 0 makes it a **kiter**: it backs away when the player is closer than this and closes in when further. Keep `speed` below the Mech's (220) so the player can always run it down |
| `shot_interval` + `shot_speed` / `shot_radius` / `shot_damage` / `shot_sprite` | > 0 makes it **shoot**. The projectile flies straight, **passes through other enemies**, and dies on hitting the player or leaving the arena |
| `requires_mech` | Holds the type back until the player boards the Mech; from then on it joins the normal spawn draw like any other unlocked enemy |

## Code contributions

- **New passive**: add its entry (name, duration, max_level) to `PASSIVES` in `scripts/autoload/run_state.gd`, then implement its effect — projectile behaviors go in `scripts/projectile.gd` (see the `burn_level`/`explosive_level`/`pierce` handling), shot-count effects in `Player._fire()` (see `triple_shot`).
- **New chair secondary**: add a case to the `match data.secondary_id` in `Chair.try_secondary()` (`scripts/chair.gd`); `Combat` (`scripts/combat.gd`) has shared helpers like `knockback_enemies`.
- Balance constants live at the top of each script (`STANDING_DRAIN`, `KNOCKBACK_*`, `SHOCKWAVE_*`, spawner ramps, etc.).

## Before opening a PR

Run the game and sanity-check your change, then run the headless test (should print `SMOKE TEST OK`):

```
godot --headless --path . res://test/smoke_test.tscn
```
