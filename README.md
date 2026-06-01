# Giblets

A dark gothic horror arena survival game built in **Godot 4**, inspired by Vampire Survivors. Survive endless waves of enemies, collect XP, level up, and choose upgrades — for as long as you can.

---

## Gameplay

- **Move** with WASD or arrow keys (8 directions)
- **Auto-attack** fires at the nearest enemy every second — no manual shooting
- **Kill enemies** to drop XP orbs; orbs float toward you when in range
- **Fill the XP bar** to level up and choose 1 of 3 random upgrades
- **Score** = enemy XP value × your current level per kill
- Survive as long as possible — enemies get faster and tankier over time

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
| **Iron Flesh** | Max health +25 (partial heal) |

### Uncommon
| Name | Effect |
|---|---|
| **Shadow Dash** | Move speed +30% |
| **Gore Storm** | Projectile damage +10 |
| **Berserker** | Fire rate +40% |
| **Undying Flesh** | Max health +50 (full heal) |

### Rare
| Name | Effect |
|---|---|
| **Twin Barrage** | Fire an extra projectile per shot |
| **Impale** | Projectiles pierce through 1 additional enemy |

---

## How to Run

1. Install [Godot 4](https://godotengine.org/download/)
2. Clone this repo
3. Open `project.godot` in the Godot editor
4. Press **F5** (with Godot focused) or click ▶

---

## Project Structure

```
scenes/       — Game scenes (Main, Player, Enemy, Projectile, XPOrb, BloodSplatter)
scripts/      — GDScript logic (GameState autoload, spawning, combat, upgrades)
ui/           — HUD, level-up screen
assets/music/ — Background track
```

---

## Tech

- **Engine:** Godot 4 (GDScript, GL Compatibility renderer)
- **Resolution:** 1280×720
- **Art:** Procedural shapes via `_draw()` — placeholder until real art is added
- **Audio:** Single looping MP3 background track, fades out on death
