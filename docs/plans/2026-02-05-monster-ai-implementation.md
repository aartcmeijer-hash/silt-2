# Monster AI System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement automated monster AI with targeting strategies, pathfinding, animated movement, and survivor displacement.

**Architecture:** Strategy pattern for targeting behaviors, AStar2D wrapper for pathfinding, MonsterAIController orchestrating turn sequence with tweened animations. UI disabled during automated monster turn.

**Tech Stack:** Godot 4.5, GDScript, AStar2D, Tweens

---

## Task 1: Create AI directory structure

**Files:**
- Create: `scripts/game/ai/` (directory)

**Step 1: Create AI directory**

```bash
mkdir -p scripts/game/ai
```

**Step 2: Verify directory exists**

```bash
ls -la scripts/game/ai
```

Expected: Directory exists

**Step 3: Commit**

```bash
git add scripts/game/ai/.gitkeep
git commit -m "feat: create AI directory structure

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Implement TargetingStrategy base class

**Files:**
- Create: `scripts/game/ai/targeting_strategy.gd`

**Step 1: Write the base class**

Create `scripts/game/ai/targeting_strategy.gd`:

```gdscript
class_name TargetingStrategy
extends Resource
## Abstract base class for monster targeting strategies.
## Subclasses implement pick_target() to define targeting behavior.

## Virtual method - override in subclasses to implement targeting logic.
## Returns the entity_id of the chosen target, or empty string if no valid target.
func pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
	push_error("TargetingStrategy.pick_target() must be implemented in subclass")
	return ""
```

**Step 2: Verify syntax**

```bash
godot --headless --check-only --script scripts/game/ai/targeting_strategy.gd
```

Expected: No syntax errors

**Step 3: Commit**

```bash
git add scripts/game/ai/targeting_strategy.gd
git commit -m "feat: add TargetingStrategy base class

Abstract base for monster targeting behaviors using strategy pattern.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Implement RandomSurvivorTargeting strategy

**Files:**
- Create: `scripts/game/ai/random_survivor_targeting.gd`

**Step 1: Write the implementation**

Create `scripts/game/ai/random_survivor_targeting.gd`:

```gdscript
class_name RandomSurvivorTargeting
extends TargetingStrategy
## Targeting strategy that picks a random survivor from available targets.

func pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
	if survivors.is_empty():
		return ""

	var survivor_ids := survivors.keys()
	return survivor_ids[randi() % survivor_ids.size()]
```

**Step 2: Verify syntax**

```bash
godot --headless --check-only --script scripts/game/ai/random_survivor_targeting.gd
```

Expected: No syntax errors

**Step 3: Commit**

```bash
git add scripts/game/ai/random_survivor_targeting.gd
git commit -m "feat: add RandomSurvivorTargeting strategy

Picks random survivor from available targets.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Implement GridPathfinder

**Files:**
- Create: `scripts/game/grid_pathfinder.gd`

**Step 1: Write the pathfinder implementation**

Create `scripts/game/grid_pathfinder.gd`:

```gdscript
class_name GridPathfinder
extends RefCounted
## Wraps Godot's AStar2D for grid-based pathfinding.
## Provides pathfinding on a 2D grid with configurable dimensions.

var astar: AStar2D
var grid_width: int
var grid_height: int


func _init(width: int, height: int) -> void:
	grid_width = width
	grid_height = height
	astar = AStar2D.new()
	_build_grid()


func _build_grid() -> void:
	# Add all grid points to AStar2D
	for x in range(grid_width):
		for y in range(grid_height):
			var point_id := _get_point_id(x, y)
			astar.add_point(point_id, Vector2(x, y))

	# Connect adjacent cells (8-directional movement)
	for x in range(grid_width):
		for y in range(grid_height):
			_connect_neighbors(x, y)


func _connect_neighbors(x: int, y: int) -> void:
	var current_id := _get_point_id(x, y)

	# 8-directional movement
	var neighbors := [
		Vector2i(x - 1, y),     # Left
		Vector2i(x + 1, y),     # Right
		Vector2i(x, y - 1),     # Up
		Vector2i(x, y + 1),     # Down
		Vector2i(x - 1, y - 1), # Top-left
		Vector2i(x + 1, y - 1), # Top-right
		Vector2i(x - 1, y + 1), # Bottom-left
		Vector2i(x + 1, y + 1), # Bottom-right
	]

	for neighbor in neighbors:
		if _is_valid_cell(neighbor.x, neighbor.y):
			var neighbor_id := _get_point_id(neighbor.x, neighbor.y)
			astar.connect_points(current_id, neighbor_id)


func find_path(from: Vector2i, to: Vector2i, max_distance: int = -1) -> Array[Vector2i]:
	var from_id := _get_point_id(from.x, from.y)
	var to_id := _get_point_id(to.x, to.y)

	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return []

	var path := astar.get_point_path(from_id, to_id)

	# Convert Vector2 path to Vector2i array and limit distance
	var result: Array[Vector2i] = []
	var limit := path.size() if max_distance < 0 else min(path.size(), max_distance + 1)

	for i in range(limit):
		result.append(Vector2i(int(path[i].x), int(path[i].y)))

	return result


func _get_point_id(x: int, y: int) -> int:
	return y * grid_width + x


func _is_valid_cell(x: int, y: int) -> bool:
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height
```

**Step 2: Verify syntax**

```bash
godot --headless --check-only --script scripts/game/grid_pathfinder.gd
```

Expected: No syntax errors

**Step 3: Commit**

```bash
git add scripts/game/grid_pathfinder.gd
git commit -m "feat: add GridPathfinder with AStar2D

Wraps AStar2D for grid-based pathfinding with 8-directional movement
and configurable distance limits.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Implement MonsterAIController

**Files:**
- Create: `scripts/game/monster_ai_controller.gd`

**Step 1: Write the controller implementation**

Create `scripts/game/monster_ai_controller.gd`:

```gdscript
class_name MonsterAIController
extends Node
## Orchestrates monster AI turn execution.
## Handles targeting, pathfinding, movement animation, and survivor displacement.

signal turn_completed

var grid: IsometricGrid
var entities: Dictionary
var pathfinder: GridPathfinder
var targeting_strategy: TargetingStrategy

const MOVE_ANIMATION_DURATION := 0.2
const MAX_MOVE_DISTANCE := 6


func _init(grid_ref: IsometricGrid, entities_ref: Dictionary) -> void:
	grid = grid_ref
	entities = entities_ref
	pathfinder = GridPathfinder.new(grid.grid_width, grid.grid_height)
	targeting_strategy = RandomSurvivorTargeting.new()


func execute_monster_turn() -> void:
	var monsters := _get_monsters()
	var survivors := _get_survivors()

	for monster_id in monsters:
		var target_id := targeting_strategy.pick_target(monster_id, monsters, survivors)
		if target_id.is_empty():
			continue

		await _execute_monster_action(monsters[monster_id], target_id)

	turn_completed.emit()


func _execute_monster_action(monster: EntityPlaceholder, target_id: String) -> void:
	if not entities.has(target_id):
		return

	var target := entities[target_id] as EntityPlaceholder
	var monster_grid_pos := grid.world_to_grid(monster.global_position)
	var target_grid_pos := grid.world_to_grid(target.global_position)

	# Find path (up to MAX_MOVE_DISTANCE spaces)
	var path := pathfinder.find_path(monster_grid_pos, target_grid_pos, MAX_MOVE_DISTANCE)

	if path.size() <= 1:
		# No movement possible
		return

	# Remove first point (current position)
	path.remove_at(0)

	# Animate movement along path
	await _animate_movement(monster, path)


func _animate_movement(monster: EntityPlaceholder, path: Array[Vector2i]) -> void:
	for grid_pos in path:
		# Handle survivor displacement before moving into cell
		_handle_displacement_at(grid_pos, monster)

		# Tween to next position
		var world_pos := grid.grid_to_world(grid_pos.x, grid_pos.y)
		var tween := create_tween()
		tween.tween_property(monster, "global_position", world_pos, MOVE_ANIMATION_DURATION)
		await tween.finished


func _handle_displacement_at(grid_pos: Vector2i, moving_monster: EntityPlaceholder) -> void:
	# Check if any survivor is at this position
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		if entity.entity_type != EntityPlaceholder.EntityType.SURVIVOR:
			continue

		var entity_grid_pos := grid.world_to_grid(entity.global_position)
		if entity_grid_pos == grid_pos:
			_displace_survivor(entity, moving_monster)


func _displace_survivor(survivor: EntityPlaceholder, monster: EntityPlaceholder) -> void:
	var survivor_pos := grid.world_to_grid(survivor.global_position)
	var monster_pos := grid.world_to_grid(monster.global_position)

	# Calculate movement direction
	var direction := survivor_pos - monster_pos

	# Get perpendicular directions (rotate 90° left and right)
	var perp_dirs := [
		Vector2i(-direction.y, direction.x),  # Rotate left
		Vector2i(direction.y, -direction.x)   # Rotate right
	]

	# Try perpendicular spaces first
	for perp_dir in perp_dirs:
		var new_pos := survivor_pos + perp_dir
		if _is_valid_and_empty(new_pos):
			_move_entity_to(survivor, new_pos)
			return

	# Edge case: No perpendicular space available
	# Leave survivor in place (monster moves through)


func _is_valid_and_empty(grid_pos: Vector2i) -> bool:
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= grid.grid_height:
		return false

	# Check if no entity occupies this position
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		var entity_grid_pos := grid.world_to_grid(entity.global_position)
		if entity_grid_pos == grid_pos:
			return false

	return true


func _move_entity_to(entity: EntityPlaceholder, grid_pos: Vector2i) -> void:
	var world_pos := grid.grid_to_world(grid_pos.x, grid_pos.y)
	entity.global_position = world_pos


func _get_monsters() -> Dictionary:
	var monsters := {}
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		if entity.entity_type == EntityPlaceholder.EntityType.MONSTER:
			monsters[entity_id] = entity
	return monsters


func _get_survivors() -> Dictionary:
	var survivors := {}
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		if entity.entity_type == EntityPlaceholder.EntityType.SURVIVOR:
			survivors[entity_id] = entity
	return survivors
```

**Step 2: Verify syntax**

```bash
godot --headless --check-only --script scripts/game/monster_ai_controller.gd
```

Expected: No syntax errors

**Step 3: Commit**

```bash
git add scripts/game/monster_ai_controller.gd
git commit -m "feat: add MonsterAIController

Orchestrates monster turn with targeting, pathfinding, animated
movement, and survivor displacement.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Add UI disable/enable methods

**Files:**
- Modify: `scripts/game/tactical_ui.gd:35` (add after existing methods)

**Step 1: Add set_disabled method**

Add to `scripts/game/tactical_ui.gd` after the existing methods:

```gdscript
func set_disabled(disabled: bool) -> void:
	monster_turn_btn.disabled = disabled
	end_turn_btn.disabled = disabled
```

**Step 2: Verify syntax**

```bash
godot --headless --check-only --script scripts/game/tactical_ui.gd
```

Expected: No syntax errors

**Step 3: Commit**

```bash
git add scripts/game/tactical_ui.gd
git commit -m "feat: add UI disable method for monster turn

Allows disabling all buttons during automated monster actions.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Integrate MonsterAIController into TacticalGameScreen

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd:14` (add after turn_state declaration)
- Modify: `scripts/game/tactical_game_screen.gd:26` (in _ready function)
- Modify: `scripts/game/tactical_game_screen.gd:127-128` (replace _on_monster_turn_pressed)

**Step 1: Add monster_ai variable**

After line 14 in `scripts/game/tactical_game_screen.gd` (after `var turn_state: TurnState`), add:

```gdscript
var monster_ai: MonsterAIController
```

**Step 2: Initialize MonsterAIController in _ready**

After line 26 (after `turn_state.turn_changed.connect(_on_turn_changed)`), add:

```gdscript
	monster_ai = MonsterAIController.new(grid, entities)
	add_child(monster_ai)
	monster_ai.turn_completed.connect(_on_monster_ai_completed)
```

**Step 3: Replace _on_monster_turn_pressed method**

Replace the existing `_on_monster_turn_pressed()` method at line 127-128 with:

```gdscript
func _on_monster_turn_pressed() -> void:
	turn_state.set_turn(TurnState.Turn.MONSTER)
	tactical_ui.set_disabled(true)
	await monster_ai.execute_monster_turn()
```

**Step 4: Add _on_monster_ai_completed handler**

Add after the modified `_on_monster_turn_pressed()` method:

```gdscript
func _on_monster_ai_completed() -> void:
	tactical_ui.set_disabled(false)
	turn_state.set_turn(TurnState.Turn.PLAYER)
```

**Step 5: Verify syntax**

```bash
godot --headless --check-only --script scripts/game/tactical_game_screen.gd
```

Expected: No syntax errors

**Step 6: Commit**

```bash
git add scripts/game/tactical_game_screen.gd
git commit -m "feat: integrate MonsterAIController into game screen

Monster turn now executes automated AI with UI disabled during
animation sequence. Turn automatically returns to player when complete.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Manual testing

**Step 1: Launch the game**

```bash
godot --path . res://scenes/menus/main_menu.tscn
```

**Step 2: Start a tactical game**

- Click "Start Game" from main menu
- Verify tactical screen loads with monster at center and 4 survivors at bottom

**Step 3: Test monster turn**

- Click "Monster Turn" button
- Verify:
  - UI buttons become disabled
  - Monster animates moving toward a random survivor
  - Monster moves up to 6 spaces
  - If monster path crosses survivor, survivor is displaced perpendicular
  - Turn automatically returns to "Player Turn" when animation completes
  - UI buttons become enabled again

**Step 4: Test multiple turns**

- Click "Monster Turn" several times
- Verify monster continues moving toward survivors
- Verify different survivors may be targeted (random selection)

**Step 5: Document any issues**

If any bugs found, document them for fixing:
- Expected behavior
- Actual behavior
- Steps to reproduce

---

## Task 9: Final commit and summary

**Step 1: Review changes**

```bash
git log --oneline -10
git diff main --stat
```

**Step 2: Verify all files committed**

```bash
git status
```

Expected: No uncommitted changes

**Step 3: Create summary document**

Update `docs/plans/2026-02-05-monster-ai-design.md` status to "Implemented".

**Step 4: Final commit**

```bash
git add docs/plans/2026-02-05-monster-ai-design.md
git commit -m "docs: mark monster AI design as implemented

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Testing Strategy

**Manual Testing Focus:**
- Monster movement animation is smooth
- Targeting appears random across multiple turns
- Survivor displacement works when monster crosses path
- UI responsiveness during and after monster turn
- Turn flow works correctly (player → monster → player)

**No automated tests** required for this feature as:
- Godot's AStar2D is well-tested by engine
- Animation and UI interaction testing requires visual verification
- Integration testing would require Godot test framework setup (out of scope)

---

## Success Criteria

✅ Monster AI controller implemented with strategy pattern
✅ Pathfinding using AStar2D with 8-directional movement
✅ Animated movement along path (0.2s per cell)
✅ Survivor displacement perpendicular to monster movement
✅ UI disabled during monster turn
✅ Automatic return to player turn after animation
✅ System extensible for new targeting strategies

---

## Notes

- **DRY:** Pathfinder and targeting are separate reusable components
- **YAGNI:** Deferred complex displacement edge cases, obstacle support, multiple actions
- **TDD:** Not applicable - Godot visual/animation features require manual testing
- **Commits:** Small, focused commits after each component
