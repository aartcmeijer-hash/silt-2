# Player Turn System Design

**Date:** 2026-02-09
**Status:** Implemented (2026-02-10)

## Overview

This document describes the design for the player turn system in Silt, enabling tactical turn-based gameplay where survivors can perform actions (move and attack) during the player phase. Each survivor acts once per turn, with visual feedback indicating completed actions.

## Requirements

- Each survivor can act once per player turn
- An "act" consists of a movement action and an activation action
- Movement: Move the survivor up to their movement range
- Activation: Initially a no-op "Attack" button (future: attacks, abilities, etc.)
- Actions can be performed in any order (move then attack, or attack then move)
- Once a survivor starts acting, they're "committed" - switching to another survivor requires confirmation
- Survivors who have completed their turn are greyed out
- When all survivors complete their turns, automatically transition to monster turn

## Architecture

### Core Components

#### 1. SurvivorData (Resource)
Stores persistent survivor stats.

```gdscript
class_name SurvivorData
extends Resource

@export var movement_range: int = 5
# Future: health, attack_damage, abilities, etc.
```

#### 2. SurvivorState (Dictionary/Class)
Tracks runtime state during player turn.

```gdscript
{
  "entity_id": String,               # e.g., "survivor_1"
  "entity_node": EntityPlaceholder,  # Reference to scene node
  "data": SurvivorData,              # Stats resource
  "has_moved": bool,                 # Movement action used
  "has_activated": bool,             # Activation/attack used
  "is_turn_complete": bool,          # Turn ended (greyed out)
  "original_color": Color            # For grey-out restoration
}
```

#### 3. PlayerTurnController
Manages the player turn phase.

**Responsibilities:**
- Tracks all survivor states
- Handles survivor selection/deselection
- Shows confirmation dialog when switching survivors with remaining actions
- Detects when all survivors complete and triggers monster turn
- Owns the active action menu instance

**Key methods:**
```gdscript
func initialize_survivors(entities: Dictionary) -> void
func select_survivor(survivor_id: String) -> void
func deselect_survivor() -> void
func on_move_pressed() -> void
func on_attack_pressed() -> void
func on_end_turn_pressed() -> void
func check_all_survivors_complete() -> bool
func reset_for_new_turn() -> void
```

#### 4. SurvivorActionMenu (Control/UI)
Floating UI panel near selected survivor.

**Features:**
- Three buttons: Move, Attack, End Turn
- Positions itself in 2D screen space to follow 3D survivor position
- Enables/disables buttons based on action state
- Signals button presses to PlayerTurnController

#### 5. MovementCalculator
Core pathfinding logic, reusable for both survivors and monsters.

**Features:**
```gdscript
class_name MovementCalculator

static func calculate_valid_tiles(
  grid: IsometricGrid,
  from: Vector2i,
  range: int,
  blocking_check: Callable
) -> Array[Vector2i]:
  # Flood-fill or Dijkstra up to 'range' steps
  # Skip blocked tiles via blocking_check
  # Returns reachable tile coordinates

static func find_path(
  grid: IsometricGrid,
  from: Vector2i,
  to: Vector2i,
  blocking_check: Callable
) -> Array[Vector2i]:
  # A* pathfinding
  # Returns path as array of coordinates
```

**Movement rules:**
- Movement range: 5 tiles (configurable per survivor)
- Range calculation: Pathfinding distance (actual reachable tiles)
- Blocking: Monsters block movement, survivors don't
- Survivors can move through other survivors but not monsters

#### 6. InteractiveMovementMode
Player-facing movement visualization and input handling.

**Features:**
- Calculates and highlights valid destination tiles
- Shows path preview on hover
- Handles click to move
- Cancellable with ESC/right-click
- Emits signals for completion or cancellation

```gdscript
class_name InteractiveMovementMode
extends Node

signal movement_completed(destination: Vector2i)
signal movement_cancelled()

func start(from: Vector2i, range: int, blocking_check: Callable)
func show_path_preview(from: Vector2i, to: Vector2i, blocking_check: Callable)
func cleanup()
```

## Interaction Flow

### State Machine

#### State: No Selection
- Player clicks on a survivor (not greyed out)
- Transition to "Survivor Selected" state

#### State: Survivor Selected
- Visual feedback: Highlight survivor + ground indicator
- SurvivorActionMenu appears floating near survivor
- Button states:
  - **Move**: Enabled if `!has_moved`
  - **Attack**: Enabled if `!has_activated`
  - **End Turn**: Always enabled

**Player actions:**
- **Click Move** → Enter "Movement Mode"
- **Click Attack** → Execute attack (no-op), set `has_activated = true`, remain in "Survivor Selected"
- **Click End Turn** → Set `is_turn_complete = true`, grey out survivor, hide menu → "No Selection"
- **Click another survivor** → Show confirmation if current has remaining actions
- **Click empty space** → Deselect, hide menu → "No Selection"

#### State: Movement Mode
- Calculate and highlight valid tiles (5 range, pathfinding-based, monsters block)
- On hover over valid tile: Show path preview
- **Click valid tile** → Move survivor, set `has_moved = true` → "Survivor Selected" (menu stays open)
- **ESC/right-click** → Cancel movement mode → "Survivor Selected"
- **Click invalid tile** → No action

### Switching Survivors

**If current survivor has no actions taken:**
- Switch immediately (no confirmation needed)

**If current survivor has actions remaining:**
- Show confirmation dialog: "Survivor X still has actions available. End their turn?"
  - **Yes** → Set `is_turn_complete = true`, grey out, select new survivor
  - **No** → Stay with current survivor

### Auto-Completion

**When both actions used:**
- Automatically set `is_turn_complete = true` and grey out survivor

**When all survivors have `is_turn_complete == true`:**
- Automatically call `turn_state.set_turn(TurnState.Turn.MONSTER)`
- Triggers existing monster turn logic

## Visual Feedback

### Selection State
- **Highlight**: Apply highlight/outline material to survivor mesh
- **Ground indicator**: Show selection ring or marker beneath survivor

### Greyed Out State
- **Method**: Desaturate/darken the survivor's color
- **Implementation**: Modify StandardMaterial3D albedo_color to grey or darker version
- Store `original_color` for restoration on new turn

### Movement Visualization
- **Valid tiles**: Highlight/outline on reachable tiles
- **Path preview**: Highlight path tiles on hover (different color/style from valid tiles)
- **Cancellation feedback**: Clear all highlights when ESC pressed

## Data Structures

### EntityPlaceholder Additions

```gdscript
# Add to existing EntityPlaceholder class
var survivor_data: SurvivorData = null  # For survivors only
var is_greyed_out: bool = false

signal clicked()  # For player interaction

func set_greyed_out(greyed: bool) -> void:
  # Desaturate/darken the color

func restore_color() -> void:
  # Restore original_color
```

### PlayerTurnController State

```gdscript
var survivor_states: Dictionary = {}      # Key: entity_id, Value: SurvivorState
var active_survivor_id: String = ""       # Currently selected survivor ID
var action_menu: SurvivorActionMenu = null
var movement_mode: InteractiveMovementMode = null
```

## Integration with Existing Code

### tactical_game_screen.gd

**Modifications:**

```gdscript
# Add new member variable
var player_turn_controller: PlayerTurnController

func _ready() -> void:
  # ... existing code ...

  # Initialize player turn controller
  player_turn_controller = PlayerTurnController.new()
  add_child(player_turn_controller)
  player_turn_controller.setup(grid, entities, turn_state)
  player_turn_controller.all_survivors_complete.connect(_on_all_survivors_complete)

  # Connect entity clicks to player turn controller
  for entity_id in entities:
    var entity = entities[entity_id]
    if entity.entity_type == EntityPlaceholder.EntityType.SURVIVOR:
      entity.clicked.connect(player_turn_controller.on_entity_clicked.bind(entity_id))

func _on_all_survivors_complete() -> void:
  # Automatically trigger monster turn
  turn_state.set_turn(TurnState.Turn.MONSTER)
  tactical_ui.set_disabled(true)
  await monster_ai.execute_monster_turn()

func _on_monster_ai_completed() -> void:
  # Reset all survivor states for new player turn
  player_turn_controller.reset_for_new_turn()
  tactical_ui.set_disabled(false)
  turn_state.set_turn(TurnState.Turn.PLAYER)
```

### EntityPlaceholder Click Detection

**Options:**
- **Option A**: Add Area3D with input_event handling
- **Option B**: Raycast from camera in tactical_game_screen._input()

Recommended: Option B for centralized input handling.

### Existing UI Buttons

- **"Monster Turn" button**: Can remain as manual override, or hide since turns auto-transition
- **"End Turn" button**: Might be redundant with per-survivor "End Turn" buttons in action menu

## Testing & Edge Cases

### Edge Cases

1. **Clicking greyed-out survivor** → Ignore click (already done)
2. **Both actions used** → Auto-complete turn and grey out
3. **Camera rotation during movement mode** → Ensure highlights update or disable rotation input
4. **Survivor dies during turn** (future) → Remove from survivor_states, check remaining complete
5. **Pathfinding fails** (surrounded) → Show empty valid set, only "End Turn" available
6. **Rapid clicking** → Debounce input during animations/transitions

### Testing Checklist

- [ ] Select survivor, use Move only, select another → confirmation works
- [ ] Select survivor, use Attack only, select another → confirmation works
- [ ] Select survivor, use both actions → auto grey out
- [ ] All survivors complete → monster turn starts automatically
- [ ] Movement mode: ESC cancels, returns to menu with Move enabled
- [ ] Movement mode: hover shows path preview
- [ ] Movement mode: click valid tile moves survivor
- [ ] Monsters block movement, survivors don't
- [ ] Greyed out survivors can't be reselected
- [ ] After monster turn → survivors reset for new player turn

### Visual Polish (Optional Enhancements)

- Smooth movement animation (tween survivor position)
- Button press feedback/hover states
- Sound effects for actions
- Particle effects on action completion

## Implementation Notes

### File Structure

New files to create:
- `scripts/resources/survivor_data.gd` - SurvivorData resource
- `scripts/game/player_turn_controller.gd` - PlayerTurnController
- `scripts/game/survivor_action_menu.gd` - SurvivorActionMenu UI
- `scripts/game/movement_calculator.gd` - MovementCalculator static class
- `scripts/game/interactive_movement_mode.gd` - InteractiveMovementMode
- `scenes/game/survivor_action_menu.tscn` - Action menu UI scene

Modified files:
- `scripts/game/entity_placeholder.gd` - Add survivor_data, clicked signal, grey-out methods
- `scripts/game/tactical_game_screen.gd` - Integrate PlayerTurnController

### Dependencies

- Existing: IsometricGrid, EntityPlaceholder, TurnState, MonsterAIController
- New: Pathfinding algorithm (A*, flood-fill/Dijkstra for range calculation)

### Future Enhancements

- Actual attack implementation with targeting and damage
- Multiple attack types (melee, ranged, AOE)
- Ability system (additional activations beyond basic attack)
- Action points system (variable cost per action)
- Undo/redo action history
- Animation system for movements and attacks
- Status effects and buffs

---

## Implementation Notes (Deviations from Design)

### GridPathfinder Reuse

`MovementCalculator.find_path()` delegates to the existing `GridPathfinder` class rather than implementing A* directly. `GridPathfinder` was extended with `set_point_disabled()` and `apply_blocking_rules(Callable)` to support dynamic blocking checks. This avoids code duplication.

### SubViewport Coordinate Handling

The 3D world renders in a `SubViewport` with `handle_input_events = false`. This required:
- `InteractiveMovementMode` stores a `SubViewport` reference and uses `subviewport.get_mouse_position()` instead of `event.position` for accurate cursor-to-grid projection.
- `SurvivorActionMenu` converts 3D survivor positions to screen space via `SubViewportContainer.get_global_rect()` scaling rather than `camera.unproject_position()` alone.
- Entity click raycasting in `tactical_game_screen.gd` converts mouse position to SubViewport space before projecting rays against `subviewport.world_3d.direct_space_state`.

### Blocking Rules

The design specified "monsters block movement, survivors don't". During implementation, the blocking rule was changed so that **other survivors also block** (the moving survivor does not block itself). This prevents multiple survivors from stacking on the same tile.

### Option B for Click Detection (Raycast)

The design offered Option A (Area3D per entity) or Option B (raycast from camera). Option B was implemented. `entity_placeholder.tscn` was given a `StaticBody3D` + `CapsuleShape3D` for the raycast to detect, rather than an `Area3D`.

### Smooth Movement Animation

Movement uses a 0.3-second tween (`EASE_IN_OUT`, `TRANS_QUAD`) rather than instant position assignment. An `_is_transitioning` flag blocks new survivor selections during the animation.
