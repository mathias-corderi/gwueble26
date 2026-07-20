# gwueble26 — Chair Survivors (prototype)

Game jam prototype. Themes: **slow burn** + **chair**.

Top-down horde shooter with a twist: **standing slowly drains your HP**. You must find a chair and sit on it. Each chair gives you a unique mouse-aimed attack and a passive. Stay seated to fill the chair's meter — a full meter makes the passive **permanent**, but the chair burns out and breaks shortly after. Chairs also break if enemies damage them enough, or the moment you stand up. Every chair break knocks nearby enemies back, giving you a window to run to the next chair.

Everything is placeholder art (colored shapes) — this build exists to test the idea.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Move (only while standing) |
| Mouse | Aim with the crosshair |
| Left click (hold) | Fire the chair attack (only while seated) |
| E | Sit on a nearby chair / stand up (breaks the chair!) |
| R | Restart the run |

> **Contributing music, art, chairs or enemies?** See [CONTRIBUTING.md](CONTRIBUTING.md) — everything is drop-in, no code required.

## How to add a new chair

1. Duplicate any `.tres` in `data/chairs/` (e.g. `plastic_chair.tres`).
2. Edit its stats in the Godot inspector: name, color, HP, meter time, attack parameters, `passive_id` and music.
3. Done — the chair spawner scans `data/chairs/` at startup, no code changes needed.

Available passives (`passive_id`): `triple_shot`, `homing`, `burn`, `explosive`, `pierce`. To add a new passive, add its id to `RunState.PASSIVE_NAMES` and handle its flag in `scripts/projectile.gd` (and/or `scripts/player.gd` for shot-count style effects). Passives stack across chairs automatically, which is where the synergies come from (e.g. permanent Triple Shot + Musical Chair = three homing notes).

## How to add a new enemy

Same idea: duplicate a `.tres` in `data/enemies/` and tweak its stats. `unlock_time` controls how many seconds into the run it starts spawning.

## Project layout

- `scenes/` — one scene per entity (`main`, `player`, `chair`, `enemy`, `projectile`, `hud`)
- `scripts/` — their scripts, plus the two data resource definitions (`chair_data.gd`, `enemy_data.gd`)
- `scripts/autoload/` — `RunState` (run timer, kills, permanent passives) and `MusicManager` (per-chair music crossfade)
- `data/` — drop-in chair and enemy definitions
- `audio/` — generated placeholder music loops (one per chair)
- `test/` — headless integration test; run it with `godot --headless --path . res://test/smoke_test.tscn` (exit code 0 = all checks pass)
