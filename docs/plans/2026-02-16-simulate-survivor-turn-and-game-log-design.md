# Simulate Survivor Turn & Game Log Design

**Date:** 2026-02-16

## Overview

Two related features:

1. **Simulate Survivors button** — a testing convenience that auto-resolves the player phase by moving each survivor toward the nearest monster and marking them as having acted.
2. **Game log panel** — a visible, properly positioned unified log for both monster attack results and simulated survivor actions. Fixes the existing invisible attack log.

---

## Feature 1: Simulate Survivors Button

### Purpose

Reduce manual clicking during testing. Instead of clicking each survivor and manually selecting Move + End Turn, a single button resolves the entire player phase automatically.

### Behavior

When clicked during the player turn:

1. Iterate all survivors that are not knocked down
2. For each survivor:
   - Find the nearest monster by Manhattan distance
   - Call `MovementCalculator.calculate_valid_tiles()` to get reachable tiles
   - Pick the valid tile closest to the target monster
   - Move the survivor to that tile (reposition entity on grid, update grid occupancy)
   - Mark `has_moved = true` and `has_activated = true`
   - Append a log entry: `"[S1] moves toward [M], attacks (unresolved)"`
3. After all survivors are processed, trigger `_check_all_survivors_complete()` so the turn transitions naturally to the monster phase

### Implementation

**`PlayerTurnController`** — new method:
```gdscript
func simulate_all_survivors() -> void
```
- Emits new signal `simulation_log_updated(lines: Array)` (same shape as `MonsterAIController.attack_log_updated`)

**`TacticalUI`** — new button:
- Name: `SimulateSurvivorsButton`
- Text: `"Simulate Survivors"`
- Enabled only during player turn (same rules as `MonsterTurnButton`)
- Emits existing signal pattern: `simulate_survivors_pressed`

**`TacticalGameScreen`** — wires `simulate_survivors_pressed` → `player_turn_controller.simulate_all_survivors()`

---

## Feature 2: Game Log Panel

### Purpose

A visible, bottom-left anchored log that shows game events during play. Replaces the current `_attack_log_label` which is invisible because it is incorrectly parented inside the small `TacticalUI` panel.

### Behavior

- Displays up to ~8 lines of recent game events
- Cleared at the start of each player turn (existing behavior)
- Receives entries from two sources:
  - Monster attack results via `MonsterAIController.attack_log_updated`
  - Simulated survivor actions via `PlayerTurnController.simulation_log_updated`

### Implementation

**`TacticalGameScreen`** — replaces the existing `_attack_log_label` setup:
- Create `RichTextLabel` as a direct child of `TacticalGameScreen` (not `TacticalUI`)
- Anchor: `PRESET_BOTTOM_LEFT`
- Size: `400×150px` minimum
- `scroll_active = false`
- New method: `append_log(line: String)` — both signals connect to this

---

## Signal Flow

```
PlayerTurnController.simulation_log_updated(lines) ──┐
                                                      ├──> TacticalGameScreen.append_log()
MonsterAIController.attack_log_updated(lines) ────────┘
```

---

## Files to Change

| File | Change |
|------|--------|
| `scripts/game/player_turn_controller.gd` | Add `simulate_all_survivors()`, emit `simulation_log_updated` |
| `scripts/game/tactical_ui.gd` | Add `SimulateSurvivorsButton`, emit `simulate_survivors_pressed` |
| `scenes/game/tactical_ui.tscn` | Add button node |
| `scripts/game/tactical_game_screen.gd` | Fix log panel parenting, add `append_log()`, wire new signals |

---

## Out of Scope

- Actual survivor attack resolution (attack is logged as "unresolved")
- Targeting strategies beyond "nearest monster by Manhattan distance"
- Persistent log across turns
- Log scrolling
