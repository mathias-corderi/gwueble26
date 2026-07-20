# Animation & Art Guide

How the 8-direction sprite system works and how to deliver art for it. The code is already wired: you author SpriteFrames following the naming below, assign them in the right slot, and everything (facing, mirroring, render order, state switching) happens automatically. Any animation you haven't authored yet simply falls back to the placeholder — you can deliver incrementally.

## The direction system

Facing always follows the **cursor** (twin-stick style) — WASD moves, the mouse aims, and the sprite faces the aim. There are 8 facing directions but you only author **5**; the engine mirrors the 3 west ones with `flip_h`:

| You author | Used for | Mirrored for |
|---|---|---|
| `down` | S | — |
| `down_side` | SE | SW |
| `side` | E | W |
| `up_side` | NE | NW |
| `up` | N | — |

**Author all side-ish directions facing RIGHT.** The engine flips them for left.

## Animation names

Every animation is named `<state>_<direction>`, e.g. `walk_down_side`, `sit_up`, `idle_side`.

### Player body (SpriteFrames on `BodySprite` in `scenes/player.tscn`)

| State | When | Required? |
|---|---|---|
| `idle_<dir>` | Standing still | Yes (also the global fallback) |
| `walk_<dir>` | Moving with WASD | Recommended |
| `shoot_<dir>` | Just fired while standing | Recommended |
| `sit_<dir>` | Seated on a chair | Recommended |
| `sit_shoot_<dir>` | Firing while seated | Optional (falls back to `sit_<dir>`) |
| `<state>_2h_<dir>` | Same states while holding a TWO_HANDED weapon | Optional (falls back to the normal state) |

### Weapon (SpriteFrames in the weapon's `.tres` → `weapon_frames`, `data/weapons/`)

Use the **same names as the body states** (`idle_<dir>`, `walk_<dir>`, `shoot_<dir>`, `sit_<dir>`, …). Body and weapon are separate sprites playing the same animation name in sync, so draw the weapon **as if held by an invisible character** on the same canvas. Missing names fall back to `idle_<dir>` → `idle_down`.

### Chair (SpriteFrames in the chair's `.tres` → `chair_frames`, `data/chairs/`)

| State | When | Required? |
|---|---|---|
| `idle_<dir>` | Always (faces cursor while occupied, `down` when free) | Yes |
| `move_<dir>` | Mount chairs being driven | Optional (falls back to `idle_<dir>`) |

## Consistency rules (important!)

- **Same canvas size and same pivot (centered)** for body, weapon and chair frames. The three sprites are stacked at the same origin — if pivots differ, the weapon will float off the hands.
- Suggested canvas: 64×64 for body and weapon, 64×80 for chairs (backrest room). Any size works if you keep it consistent per set.
- Enemies flash white on hit and orange while burning; chairs blink during burnout. Avoid pure-white / very dark sprites or those cues vanish.

## Render order (automatic — just so you know)

- **Weapon vs body**: aiming `up` or `up_side` → weapon renders **behind** the body; otherwise in front.
- **Chair vs player**: while seated, aiming `up` or `up_side` → chair renders **in front of** the player (the backrest covers the body); otherwise behind.

So: draw the `up` weapon frames knowing they'll sit behind the body, and draw the chair's `up` frames with a full backrest since it will cover the player.

## The passive flame slot

Burning passives show as bars in the HUD (`scenes/ui/passive_bar.tscn`). The `FlameAnchor` node is repositioned by code to the exact burn edge of the bar every frame. To add the flame art: open that scene, delete the `FlamePlaceholder` ColorRect, and add your flame `AnimatedSprite2D` as a child of `FlameAnchor` (centered on it, tip pointing up). Nothing else to touch.

## Walkthrough: adding a weapon

1. Duplicate a `.tres` in `data/weapons/` (Ctrl+D in the FileSystem dock), rename it.
2. Set stats in the inspector: `display_name`, `color`, `handedness`, `max_ammo`, attack params.
3. Art (optional, any time later): `sprite` (map pickup icon), `projectile_sprite` (authored pointing right — projectiles auto-rotate), and `weapon_frames` (the SpriteFrames set above).
4. Done — the weapon spawner scans `data/weapons/` at startup.

## Walkthrough: adding chair art

1. Open the chair's `.tres` in `data/chairs/`.
2. Quick placeholder upgrade: assign a single PNG to `sprite` (auto-scaled, used when there are no frames).
3. Full version: create a SpriteFrames with `idle_<dir>` (+ `move_<dir>` if it's a mount) and assign it to `chair_frames`.
