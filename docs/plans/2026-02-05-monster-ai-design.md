# Monster AI System Design

**Date:** 2026-02-05
**Status:** Approved

## Overview

Implement a monster AI system that executes automated actions during the monster turn. When the player presses "monster turn", each monster will:
1. Select a target using a configurable targeting strategy
2. Calculate a path to the target using A* pathfinding
3. Move up to 6 spaces along that path with animation
4. Displace survivors that are in the movement path
5. Automatically return to player turn when complete

## Goals

- Create extensible targeting system supporting multiple AI behaviors
- Implement smooth animated movement along pathfinding paths
- Handle survivor displacement when monster moves through their space
- Future-proof for multiple monsters and obstacles

## System Architecture

### Component Overview

**1. MonsterAIController** (`scripts/game/monster_ai_controller.gd`)
- Orchestrates the entire monster turn sequence
- Holds references to grid, entities, and targeting strategy
- Main entry point: `execute_monster_turn()` method
- Emits `turn_completed` signal when all monsters finish

**2. TargetingStrategy** (base: `scripts/game/ai/targeting_strategy.gd`)
- Abstract base class defining targeting interface
- Virtual method: `pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String`
- Returns entity ID of chosen target or empty string if none

**3. RandomSurvivorTargeting** (`scripts/game/ai/random_survivor_targeting.gd`)
- First concrete targeting implementation
- Picks random survivor from available targets
- Simple and stateless

**4. GridPathfinder** (`scripts/game/grid_pathfinder.gd`)
- Wraps Godot's `AStar2D` for grid pathfinding
- Initialized with grid dimensions
- Method: `find_path(from: Vector2i, to: Vector2i, max_distance: int) -> Array[Vector2i]`
- Returns path limited to max_distance steps

## Detailed Design

### Targeting System

```gdscript
# Base class
class_name TargetingStrategy
extends Resource

func pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
    push_error("Must override in subclass")
    return ""
```

The strategy pattern allows easy addition of new targeting behaviors:
- `RandomSurvivorTargeting`: Pick any random survivor
- Future: `ClosestTargeting`, `LowestHealthTargeting`, `LastAttackerTargeting`, etc.

### Pathfinding Integration

Uses Godot's built-in `AStar2D`:
- Build complete grid graph during initialization
- Connect cells with 4-directional or 8-directional movement
- All cells walkable by default (obstacle support deferred)
- Path limited to specified max distance (6 spaces for monsters)

### Movement & Animation

Movement executes sequentially along the path:
1. Get path from pathfinder (excluding starting position)
2. For each grid position in path:
   - Check for survivor displacement at that position
   - Tween monster to world position over 0.2 seconds
   - Wait for tween completion before next step
3. Total animation time: ~1.2 seconds for 6-space move

### Survivor Displacement

When monster moves into occupied cell:
1. Detect survivor at destination before tween
2. Calculate perpendicular directions to monster's movement
3. Try placing survivor in perpendicular spaces (left/right of path)
4. If both perpendicular spaces occupied, leave survivor in place (edge case)

Perpendicular calculation:
- Movement direction: `direction = survivor_pos - monster_pos`
- Perpendicular vectors: Rotate 90° left and right
- Check validity and emptiness of candidate positions

**Edge cases deferred:**
- Cascade pushing (survivors pushing other survivors)
- Placing survivor behind monster when no perpendicular space
- These situations unlikely with current 20x20 grid and few entities

### Turn Flow Integration

**TacticalGameScreen changes:**
```gdscript
func _ready():
    monster_ai = MonsterAIController.new(grid, entities)
    add_child(monster_ai)
    monster_ai.turn_completed.connect(_on_monster_ai_completed)

func _on_monster_turn_pressed():
    turn_state.set_turn(TurnState.Turn.MONSTER)
    tactical_ui.set_disabled(true)
    await monster_ai.execute_monster_turn()

func _on_monster_ai_completed():
    tactical_ui.set_disabled(false)
    turn_state.set_turn(TurnState.Turn.PLAYER)
```

UI disabled during monster turn to prevent player interference with animation sequence.

**MonsterAIController execution:**
```gdscript
signal turn_completed

func execute_monster_turn():
    var monsters = _get_monsters()

    for monster_id in monsters:
        var target_id = targeting_strategy.pick_target(monster_id, monsters, _get_survivors())
        if target_id.is_empty():
            continue

        await _execute_monster_action(monsters[monster_id], target_id)

    turn_completed.emit()
```

Multiple monsters act sequentially, each completing animation before next begins.

## Future Extensibility

This design supports future enhancements:
- **Multiple targeting strategies:** Just create new `TargetingStrategy` subclasses
- **Monster types:** Different monsters can use different strategies
- **Obstacles:** GridPathfinder can mark cells as blocked
- **Complex displacement:** Can enhance `_displace_survivor()` for edge cases
- **Multiple actions:** Add attack/ability phase after movement
- **AI decision trees:** Replace simple targeting with behavior trees

## Implementation Notes

- Keep pathfinder stateless for simplicity (recalculate paths each turn)
- Use `await` for animation sequencing rather than callbacks
- Displacement happens instantly before tween to cell (not animated)
- Entity positions tracked in `entities` dictionary, indexed by string ID
- Grid coordinates are `Vector2i`, world coordinates are `Vector3`

## Success Criteria

- Pressing "monster turn" triggers automated monster movement
- Monster visibly moves along path with smooth animation
- Movement limited to 6 spaces maximum
- Survivors displaced when monster moves through them
- Turn automatically returns to player when complete
- System extensible for new targeting strategies
