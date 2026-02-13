# Monster Attack Phase Design

**Date:** 2026-02-13

## Overview

Implement a KDM-inspired monster attack system. Attacks are resolved per-hit against survivor body parts, with wounds accumulating per location. The second wound to any location knocks the survivor down; a third or more triggers a severe injury roll.

---

## Data Model Changes

### New: `MonsterData` resource
Monster-level stats, analogous to `SurvivorData` for survivors.

```gdscript
@export var accuracy: int = 0  # Added to each hit die roll
```

`EntityPlaceholder` gets a `monster_data: MonsterData` property alongside the existing `survivor_data`.

### Extended: `SurvivorData`
```gdscript
@export var evasion: int = 5                    # Hit dice must exceed this to connect
var is_knocked_down: bool = false               # Cleared after skipping a turn
var body_part_wounds: Dictionary = {            # Part -> wound count
    "head": 0, "arms": 0, "body": 0, "waist": 0, "legs": 0
}
```

### Extended: `MonsterActionCard`
Added to ATTACK cards only (ignored on other card types):
```gdscript
@export var dice_count: int = 1   # Number of d10s rolled to-hit
@export var damage: int = 1       # Wounds applied per hit at struck location
```

Accuracy is intentionally **not** on the card — it's a monster-level stat on `MonsterData`.

---

## Attack Resolution Logic

Resolved in `MonsterAIController._execute_attack_action()`:

### 1. Hit Rolls
Roll `dice_count` d10s. Each die where `roll + monster.accuracy > survivor.evasion` = one hit.
Zero hits = miss, no further resolution.

### 2. Location Roll (per hit)
Roll 1d10, map to body part:
| Roll | Location |
|------|----------|
| 1–2  | HEAD     |
| 3–4  | ARMS     |
| 5–6  | BODY     |
| 7–8  | WAIST    |
| 9–10 | LEGS     |

*(Future: replace with a custom "body part dice" mechanic)*

### 3. Damage Application (per hit)
Add `damage` wounds to the struck location as a lump sum. Then check thresholds based on new total:

- **Was 0, now ≥ 1:** No consequence
- **Was 1, now ≥ 2:** Set `is_knocked_down = true`
- **Was already ≥ 2:** Call `_trigger_severe_injury(body_part)` — stub for now (prints warning)

*(Future: armor will reduce `damage` before this step)*

### 4. Knock-Down Effect
`PlayerTurnController` checks `is_knocked_down` at the start of each survivor's turn:
- If true: skip their action, clear the flag, log "Survivor stands up"

---

## UI (Minimal)

### Attack Resolution Log
Text log visible during monster turn. Appended per attack:
```
Antelope attacks!
  Rolls: 7, 3, 9 → 2 hits (evasion 5)
  Hit 1: ARMS — wound 1
  Hit 2: BODY — wound 2 → KNOCKED DOWN
```
Clears at the start of the next turn.

### Body Part Wound Panel
Added to `SurvivorActionMenu` (shown when a survivor is selected).
Read-only, shows per-part wound state:
```
HEAD  ○ ○    ARMS  ● ○
BODY  ● ●!   WAIST ○ ○    LEGS ○ ○
```
- `○` = unwounded slot
- `●` = wound taken
- `!` = severe injury triggered
- Status label: `[KNOCKED DOWN]` when applicable

---

## Implementation Order

Each step is independently testable:

1. **`MonsterData` resource** — create resource, wire `monster_data` onto `EntityPlaceholder`
2. **`SurvivorData` extensions** — add evasion, is_knocked_down, body_part_wounds
3. **`MonsterActionCard` extensions** — add dice_count, damage fields
4. **Attack resolution** — implement `_execute_attack_action()` in `MonsterAIController` (hit rolls, location roll, damage application, severe injury stub)
5. **Knock-down wiring** — check and clear flag in `PlayerTurnController`
6. **UI** — attack log + wound panel in `SurvivorActionMenu`

---

## Out of Scope (Future)

- Armor (reduces damage before wound application)
- Custom body part dice (replaces 1d10 location table)
- Severe injury table (replaces stub)
- Per-location effects (e.g. head wound penalties)
