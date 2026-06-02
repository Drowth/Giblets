# Giblets

A dark gothic horror arena survival game built in **Godot 4**. Survive endless waves of demons, collect XP, level up, choose dark gifts — and pray the boss doesn't find you first.

---

## Gameplay

- **Move** with WASD or arrow keys (8 directions)
- **Auto-attack** fires at the nearest enemy automatically — no manual shooting
- **Kill enemies** to drop XP orbs; orbs float toward you when in range
- **Fill the XP bar** to level up and choose 1 of 3 random upgrades
- **Score** = enemy XP value × your current level per kill
- Enemies get faster and tankier the longer you survive
- A **boss** spawns every 60 seconds — slower but far more durable

---

## Boss

Every minute a boss erupts from the edge of the screen:

- 3× the size of a regular enemy, orange-tinted, with its own health bar
- On death drops **6 XP orbs** worth two full levels
- Also drops a **Fire Bomb** pickup

### Fire Bomb

Walk over the glowing orb to detonate it:

- Instantly kills every enemy on screen with a fire explosion
- Triggers a screen-wide orange flash

---

## Upgrades

Chosen at random from the pool below each time you level up. Stackable.

### Common
| Name | Effect |
|---|---|
| **Fleet Feet** | Move speed +20% |
| **Bloodlust** | Projectile damage +5 |
| **Frenzy** | Fire rate +25% |
| **Velocity** | Projectile speed +30% |
| **Soul Draw** | XP magnet range +50% |
| **Iron Flesh** | Max health +25, partial heal |

### Uncommon
| Name | Effect |
|---|---|
| **Shadow Dash** | Move speed +30% |
| **Gore Storm** | Projectile damage +10 |
| **Berserker** | Fire rate +40% |
| **Undying Flesh** | Max health +50, full heal |
| **Banishment** | Knockback force +180 — enemies flung further |

### Rare
| Name | Effect |
|---|---|
| **Twin Barrage** | Fire an extra projectile per shot |
| **Impale** | Projectiles pierce through 1 additional enemy |
| **Soul Repel** | Enables knockback — strikes send enemies reeling |

---

## How to Run

1. Install [Godot 4](https://godotengine.org/download/)
2. Clone this repo
3. Open `project.godot` in the Godot editor
4. Press **F5** (with Godot focused) or click ▶

---

## Project Structure

```
scenes/       — Game scenes (Main, Player, Enemy, Projectile, XPOrb, BombPickup, BloodSplatter)
scripts/      — GDScript logic (GameState autoload, spawning, combat, upgrades, boss, bomb)
ui/           — HUD, level-up upgrade screen
assets/
  music/      — Background track + upgrade screen music
  sfx/        — XP pickup, level-up sting
  enemies/    — Demon sprite
  player/     — Player sprites (levels 1–3)
  pickups/    — Giblet XP orb sprite
```

---

## Tech

- **Engine:** Godot 4.6 (GDScript, GL Compatibility renderer)
- **Resolution:** 1280×720
- **Art:** Mix of sprite assets and procedural `_draw()` shapes
- **Audio:** Background music crossfades out during upgrade selection, fades back in on pick
