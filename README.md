# gwueble26 — Chair Survivors (prototype)

Game jam prototype. Themes: **slow burn** + **chair**.

Top-down horde shooter with a twist: **standing slowly drains your HP**. You must find chairs to sit on — and weapons to shoot with. **Weapons** spawn on the map, have limited ammo (discarded when empty) and provide your mouse-aimed attack in any state. **Chairs** provide everything else: a passive, an optional right-click secondary attack, HP regen, and their own music. Some chairs are **mounts** you drive with WASD while seated. Stay seated to fill the chair's meter — a full meter grants its passive as a **burning bar** that decays over time (refresh it with another chair of the same type to reset it and level it up), and the chair burns out shortly after. Chairs also break if enemies damage them enough, or the moment you stand up. Every chair break knocks nearby enemies back.

Everything is placeholder art (colored shapes) — this build exists to test the idea.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Move (standing) / drive a mount chair (seated) |
| Mouse | Aim with the crosshair (facing always follows it) |
| Left click (hold) | Fire the current weapon (any state) |
| Right click | Chair secondary attack (while seated, if the chair has one) |
| Mouse wheel | Switch between carried weapons |
| E | Sit on a nearby chair / stand up (breaks the chair!) |
| R | Restart the run |

> **Contributing music, art, chairs or enemies?** See [CONTRIBUTING.md](CONTRIBUTING.md) — everything is drop-in, no code required.

## How to add a new chair

1. Duplicate any `.tres` in `data/chairs/` (e.g. `plastic_chair.tres`).
2. Edit its stats in the Godot inspector: name, color, HP, meter time, `move_speed` (mounts), `passive_id`, the optional secondary attack, and music.
3. Done — the chair spawner scans `data/chairs/` at startup, no code changes needed.

Available passives (`passive_id`): `triple_shot`, `homing`, `burn`, `explosive`, `pierce` — defined in `RunState.PASSIVES` with their burn duration and max level. Passives are temporary **burning bars** that decay; refreshing one with another chair of the same type levels it up. Active passives apply to every weapon's shots automatically, which is where the synergies come from.

## How to add a new enemy or weapon

Same idea: duplicate a `.tres` in `data/enemies/` or `data/weapons/` and tweak its stats. For enemies, `unlock_time` controls how many seconds into the run it starts spawning. For weapons, see the walkthrough in [docs/ANIMATION_GUIDE.md](docs/ANIMATION_GUIDE.md).

## Project layout

- `scenes/` — one scene per entity (`main`, `player`, `chair`, `enemy`, `projectile`, `weapon_pickup`, `hud`, `ui/passive_bar`)
- `scripts/` — their scripts, plus the data resource definitions (`chair_data.gd`, `enemy_data.gd`, `weapon_data.gd`)
- `scripts/autoload/` — `RunState` (run timer, kills, burning passives) and `MusicManager` (per-chair music crossfade)
- `data/` — drop-in chair, enemy and weapon definitions
- `audio/` — generated placeholder music loops (one per chair)
- `docs/` — [ANIMATION_GUIDE.md](docs/ANIMATION_GUIDE.md): the 8-direction art/animation spec
- `test/` — headless integration test; run it with `godot --headless --path . res://test/smoke_test.tscn` (exit code 0 = all checks pass)
