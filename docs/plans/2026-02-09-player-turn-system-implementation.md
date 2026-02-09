# Player Turn System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement tactical turn-based player phase where survivors can move and attack with visual feedback and auto-transition to monster turn.

**Architecture:** Component-based system with PlayerTurnController managing survivor states, InteractiveMovementMode handling player input, MovementCalculator for pathfinding logic, and SurvivorActionMenu for UI. Entity selection via raycasting, visual feedback via material modification.

**Tech Stack:** Godot 4.5, GDScript, GridMap for grid system, raycast-based click detection, A* pathfinding

---

## Task 1: SurvivorData Resource

**Files:**
- Create: `scripts/resources/survivor_data.gd`

**Step 1: Create SurvivorData resource class**

Create the file with this content:

```gdscript
class_name SurvivorData
extends Resource
## Stores persistent survivor stats.

@export var movement_range: int = 5

func _init(p_movement_range: int = 5) -> void:
	movement_range = p_movement_range
```

**Step 2: Verify resource loads in Godot**

Run: Open Godot editor, check for script errors in Output panel
Expected: No errors, class_name registered

**Step 3: Commit**

```bash
git add scripts/resources/survivor_data.gd
git commit -m "feat: add SurvivorData resource for survivor stats

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: EntityPlaceholder Click Detection

**Files:**
- Modify: `scripts/game/entity_placeholder.gd`

**Step 1: Add click signal and survivor data fields**

Add to the class (after existing exports):

```gdscript
signal clicked()

var survivor_data: SurvivorData = null
var is_greyed_out: bool = false
var _original_color: Color = Color.WHITE
```

**Step 2: Add grey-out methods**

Add these methods at the end of the class:

```gdscript
func set_greyed_out(greyed: bool) -> void:
	is_greyed_out = greyed
	if body and body.get_surface_override_material(0):
		var material := body.get_surface_override_material(0) as StandardMaterial3D
		if material:
			if greyed:
				_original_color = material.albedo_color
				# Desaturate and darken
				var grey_value := (_original_color.r + _original_color.g + _original_color.b) / 3.0
				material.albedo_color = Color(grey_value * 0.5, grey_value * 0.5, grey_value * 0.5)
			else:
				material.albedo_color = _original_color


func restore_color() -> void:
	set_greyed_out(false)
```

**Step 3: Verify no script errors**

Run: Open Godot editor, check Output panel
Expected: No errors

**Step 4: Commit**

```bash
git add scripts/game/entity_placeholder.gd
git commit -m "feat: add click signal and grey-out support to EntityPlaceholder

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: MovementCalculator Core Logic

**Files:**
- Create: `scripts/game/movement_calculator.gd`

**Step 1: Create MovementCalculator with flood-fill algorithm**

Create the file with this content:

```gdscript
class_name MovementCalculator
## Static pathfinding utilities for grid-based movement.

## Calculate all tiles reachable within 'range' steps using flood-fill.
## blocking_check(Vector2i) -> bool returns true if tile is blocked.
static func calculate_valid_tiles(
	grid: IsometricGrid,
	from: Vector2i,
	range: int,
	blocking_check: Callable
) -> Array[Vector2i]:
	var valid_tiles: Array[Vector2i] = []
	var visited: Dictionary = {}  # Vector2i -> int (distance)
	var queue: Array = [[from, 0]]  # [position, distance]

	visited[from] = 0

	while queue.size() > 0:
		var current = queue.pop_front()
		var pos: Vector2i = current[0]
		var dist: int = current[1]

		if dist > 0:  # Don't include starting position
			valid_tiles.append(pos)

		if dist >= range:
			continue

		# Check 4 adjacent tiles
		var neighbors: Array[Vector2i] = [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]

		for neighbor in neighbors:
			# Check bounds
			if neighbor.x < 0 or neighbor.x >= grid.grid_width:
				continue
			if neighbor.y < 0 or neighbor.y >= grid.grid_height:
				continue

			# Skip if already visited
			if neighbor in visited:
				continue

			# Skip if blocked
			if blocking_check.call(neighbor):
				continue

			visited[neighbor] = dist + 1
			queue.append([neighbor, dist + 1])

	return valid_tiles


## Find shortest path from 'from' to 'to' using A*.
## Returns array of Vector2i coordinates forming the path (excluding 'from', including 'to').
## Returns empty array if no path exists.
static func find_path(
	grid: IsometricGrid,
	from: Vector2i,
	to: Vector2i,
	blocking_check: Callable
) -> Array[Vector2i]:
	# A* implementation
	var open_set: Array = [[from, 0, _heuristic(from, to)]]  # [pos, g_score, f_score]
	var came_from: Dictionary = {}  # Vector2i -> Vector2i
	var g_scores: Dictionary = {from: 0}

	while open_set.size() > 0:
		# Find node with lowest f_score
		var current_idx := 0
		var current_f := open_set[0][2]
		for i in range(1, open_set.size()):
			if open_set[i][2] < current_f:
				current_idx = i
				current_f = open_set[i][2]

		var current: Vector2i = open_set[current_idx][0]

		if current == to:
			# Reconstruct path
			return _reconstruct_path(came_from, current, from)

		open_set.remove_at(current_idx)

		# Check 4 adjacent tiles
		var neighbors: Array[Vector2i] = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]

		for neighbor in neighbors:
			# Check bounds
			if neighbor.x < 0 or neighbor.x >= grid.grid_width:
				continue
			if neighbor.y < 0 or neighbor.y >= grid.grid_height:
				continue

			# Skip if blocked (unless it's the destination)
			if neighbor != to and blocking_check.call(neighbor):
				continue

			var tentative_g := g_scores[current] + 1

			if not neighbor in g_scores or tentative_g < g_scores[neighbor]:
				came_from[neighbor] = current
				g_scores[neighbor] = tentative_g
				var f_score := tentative_g + _heuristic(neighbor, to)

				# Add to open set if not already there
				var in_open := false
				for item in open_set:
					if item[0] == neighbor:
						in_open = true
						break

				if not in_open:
					open_set.append([neighbor, tentative_g, f_score])

	return []  # No path found


static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


static func _reconstruct_path(came_from: Dictionary, current: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while current in came_from:
		current = came_from[current]
		if current != start:
			path.insert(0, current)
	return path
```

**Step 2: Verify no script errors**

Run: Open Godot editor, check Output panel
Expected: No errors, class_name registered

**Step 3: Commit**

```bash
git add scripts/game/movement_calculator.gd
git commit -m "feat: add MovementCalculator with A* pathfinding and flood-fill

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: InteractiveMovementMode Scaffold

**Files:**
- Create: `scripts/game/interactive_movement_mode.gd`

**Step 1: Create basic InteractiveMovementMode structure**

Create the file with this content:

```gdscript
class_name InteractiveMovementMode
extends Node
## Handles interactive movement visualization and input for player-controlled entities.

signal movement_completed(destination: Vector2i)
signal movement_cancelled()

var grid: IsometricGrid
var valid_tiles: Array[Vector2i] = []
var current_position: Vector2i
var blocking_check: Callable

var _highlight_meshes: Array[MeshInstance3D] = []
var _path_preview_meshes: Array[MeshInstance3D] = []
var _camera: Camera3D

# Visual materials
var _valid_tile_material: StandardMaterial3D
var _path_preview_material: StandardMaterial3D


func _ready() -> void:
	_setup_materials()


func _setup_materials() -> void:
	_valid_tile_material = StandardMaterial3D.new()
	_valid_tile_material.albedo_color = Color(0.2, 1.0, 0.2, 0.3)
	_valid_tile_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_path_preview_material = StandardMaterial3D.new()
	_path_preview_material.albedo_color = Color(1.0, 1.0, 0.2, 0.4)
	_path_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func start(
	p_grid: IsometricGrid,
	p_camera: Camera3D,
	from: Vector2i,
	range: int,
	p_blocking_check: Callable
) -> void:
	grid = p_grid
	_camera = p_camera
	current_position = from
	blocking_check = p_blocking_check

	# Calculate valid tiles
	valid_tiles = MovementCalculator.calculate_valid_tiles(grid, from, range, blocking_check)

	# Create visual indicators
	_create_tile_highlights()

	set_process_input(true)


func cleanup() -> void:
	_clear_highlights()
	_clear_path_preview()
	set_process_input(false)


func _create_tile_highlights() -> void:
	_clear_highlights()

	for tile in valid_tiles:
		var mesh_instance := MeshInstance3D.new()
		var quad_mesh := QuadMesh.new()
		quad_mesh.size = Vector2(grid.tile_size * 0.9, grid.tile_size * 0.9)

		mesh_instance.mesh = quad_mesh
		mesh_instance.material_override = _valid_tile_material
		mesh_instance.position = grid.grid_to_world(tile.x, tile.y) + Vector3(0, 0.5, 0)
		mesh_instance.rotation_degrees.x = -90

		grid.add_child(mesh_instance)
		_highlight_meshes.append(mesh_instance)


func _clear_highlights() -> void:
	for mesh in _highlight_meshes:
		mesh.queue_free()
	_highlight_meshes.clear()


func _clear_path_preview() -> void:
	for mesh in _path_preview_meshes:
		mesh.queue_free()
	_path_preview_meshes.clear()


func _show_path_preview(to: Vector2i) -> void:
	_clear_path_preview()

	var path := MovementCalculator.find_path(grid, current_position, to, blocking_check)
	if path.is_empty():
		return

	for tile in path:
		var mesh_instance := MeshInstance3D.new()
		var quad_mesh := QuadMesh.new()
		quad_mesh.size = Vector2(grid.tile_size * 0.7, grid.tile_size * 0.7)

		mesh_instance.mesh = quad_mesh
		mesh_instance.material_override = _path_preview_material
		mesh_instance.position = grid.grid_to_world(tile.x, tile.y) + Vector3(0, 0.6, 0)
		mesh_instance.rotation_degrees.x = -90

		grid.add_child(mesh_instance)
		_path_preview_meshes.append(mesh_instance)


func _process(_delta: float) -> void:
	if not _camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_pos)
	var ray_direction := _camera.project_ray_normal(mouse_pos)

	# Raycast to grid plane (y=0)
	var t := -ray_origin.y / ray_direction.y
	if t < 0:
		_clear_path_preview()
		return

	var world_pos := ray_origin + ray_direction * t
	var grid_pos := grid.world_to_grid(world_pos)

	# Show path preview if hovering over valid tile
	if grid_pos in valid_tiles:
		_show_path_preview(grid_pos)
	else:
		_clear_path_preview()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		movement_cancelled.emit()
		cleanup()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		movement_cancelled.emit()
		cleanup()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos := event.position
		var ray_origin := _camera.project_ray_origin(mouse_pos)
		var ray_direction := _camera.project_ray_normal(mouse_pos)

		var t := -ray_origin.y / ray_direction.y
		if t < 0:
			return

		var world_pos := ray_origin + ray_direction * t
		var grid_pos := grid.world_to_grid(world_pos)

		if grid_pos in valid_tiles:
			movement_completed.emit(grid_pos)
			cleanup()
			get_viewport().set_input_as_handled()
```

**Step 2: Verify no script errors**

Run: Open Godot editor, check Output panel
Expected: No errors, class_name registered

**Step 3: Commit**

```bash
git add scripts/game/interactive_movement_mode.gd
git commit -m "feat: add InteractiveMovementMode for player movement input

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: SurvivorActionMenu Scene and Script

**Files:**
- Create: `scenes/game/ui/survivor_action_menu.tscn`
- Create: `scripts/game/ui/survivor_action_menu.gd`

**Step 1: Create SurvivorActionMenu script**

Create `scripts/game/ui/survivor_action_menu.gd`:

```gdscript
class_name SurvivorActionMenu
extends Control
## Floating action menu for selected survivor.

signal move_pressed()
signal attack_pressed()
signal end_turn_pressed()

@onready var move_button: Button = $VBoxContainer/MoveButton
@onready var attack_button: Button = $VBoxContainer/AttackButton
@onready var end_turn_button: Button = $VBoxContainer/EndTurnButton

var _target_3d_position: Vector3 = Vector3.ZERO
var _camera: Camera3D = null


func _ready() -> void:
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)


func setup(camera: Camera3D, position_3d: Vector3) -> void:
	_camera = camera
	_target_3d_position = position_3d


func update_button_states(has_moved: bool, has_activated: bool) -> void:
	move_button.disabled = has_moved
	attack_button.disabled = has_activated
	# End Turn always enabled


func _process(_delta: float) -> void:
	if _camera:
		# Convert 3D position to 2D screen space
		var screen_pos := _camera.unproject_position(_target_3d_position)
		position = screen_pos + Vector2(20, -50)  # Offset from entity


func _on_move_pressed() -> void:
	move_pressed.emit()


func _on_attack_pressed() -> void:
	attack_pressed.emit()


func _on_end_turn_pressed() -> void:
	end_turn_pressed.emit()
```

**Step 2: Create SurvivorActionMenu scene**

Instructions for manual scene creation:
1. In Godot, create new scene with Control node as root
2. Name it "SurvivorActionMenu"
3. Attach script: `scripts/game/ui/survivor_action_menu.gd`
4. Add child: VBoxContainer (name: "VBoxContainer")
5. Add 3 Button children to VBoxContainer:
   - "MoveButton" with text "Move"
   - "AttackButton" with text "Attack"
   - "EndTurnButton" with text "End Turn"
6. Set VBoxContainer theme separation to 4
7. Set each Button min_size to (100, 30)
8. Save as: `scenes/game/ui/survivor_action_menu.tscn`

**Step 3: Verify scene loads**

Run: Open Godot editor, open the scene, check for errors
Expected: Scene opens without errors

**Step 4: Commit**

```bash
git add scripts/game/ui/survivor_action_menu.gd scenes/game/ui/survivor_action_menu.tscn
git commit -m "feat: add SurvivorActionMenu UI for action selection

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: PlayerTurnController Core Structure

**Files:**
- Create: `scripts/game/player_turn_controller.gd`

**Step 1: Create PlayerTurnController with state management**

Create the file:

```gdscript
class_name PlayerTurnController
extends Node
## Manages player turn phase, survivor selection, and action coordination.

signal all_survivors_complete()

const SURVIVOR_ACTION_MENU_SCENE := preload("res://scenes/game/ui/survivor_action_menu.tscn")

var grid: IsometricGrid
var entities: Dictionary
var turn_state: TurnState
var camera: Camera3D

var survivor_states: Dictionary = {}  # entity_id -> SurvivorState
var active_survivor_id: String = ""

var action_menu: SurvivorActionMenu = null
var movement_mode: InteractiveMovementMode = null

# Selection visuals
var _selection_highlight: MeshInstance3D = null
var _ground_indicator: MeshInstance3D = null


func setup(p_grid: IsometricGrid, p_entities: Dictionary, p_turn_state: TurnState, p_camera: Camera3D) -> void:
	grid = p_grid
	entities = p_entities
	turn_state = p_turn_state
	camera = p_camera

	_create_selection_visuals()
	initialize_survivors()


func initialize_survivors() -> void:
	for entity_id in entities:
		var entity: EntityPlaceholder = entities[entity_id]
		if entity.entity_type == EntityPlaceholder.EntityType.SURVIVOR:
			# Create survivor data
			var survivor_data := SurvivorData.new(5)
			entity.survivor_data = survivor_data

			# Create survivor state
			survivor_states[entity_id] = {
				"entity_id": entity_id,
				"entity_node": entity,
				"data": survivor_data,
				"has_moved": false,
				"has_activated": false,
				"is_turn_complete": false,
				"original_color": entity.entity_color
			}


func reset_for_new_turn() -> void:
	# Reset all survivor states
	for entity_id in survivor_states:
		var state = survivor_states[entity_id]
		state.has_moved = false
		state.has_activated = false
		state.is_turn_complete = false

		var entity: EntityPlaceholder = state.entity_node
		entity.restore_color()

	# Clear selection
	if active_survivor_id != "":
		deselect_survivor()


func on_entity_clicked(entity_id: String) -> void:
	# Ignore if not player turn
	if not turn_state.is_player_turn():
		return

	# Ignore if not a survivor or already greyed out
	if not entity_id in survivor_states:
		return

	var state = survivor_states[entity_id]
	if state.is_turn_complete:
		return

	# Handle switching survivors
	if active_survivor_id != "" and active_survivor_id != entity_id:
		_handle_survivor_switch(entity_id)
	else:
		select_survivor(entity_id)


func _handle_survivor_switch(new_entity_id: String) -> void:
	var current_state = survivor_states[active_survivor_id]

	# If no actions taken, switch immediately
	if not current_state.has_moved and not current_state.has_activated:
		deselect_survivor()
		select_survivor(new_entity_id)
		return

	# Show confirmation dialog
	_show_switch_confirmation(new_entity_id)


func _show_switch_confirmation(new_entity_id: String) -> void:
	# Create simple confirmation dialog
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "Survivor still has actions available. End their turn?"
	dialog.ok_button_text = "Yes"

	# Add Cancel button
	dialog.add_cancel_button("No")

	dialog.confirmed.connect(func():
		_complete_survivor_turn(active_survivor_id)
		select_survivor(new_entity_id)
	)

	add_child(dialog)
	dialog.popup_centered()


func select_survivor(survivor_id: String) -> void:
	active_survivor_id = survivor_id
	var state = survivor_states[survivor_id]
	var entity: EntityPlaceholder = state.entity_node

	# Show selection visuals
	_update_selection_visuals(entity.position)

	# Create and show action menu
	if action_menu:
		action_menu.queue_free()

	action_menu = SURVIVOR_ACTION_MENU_SCENE.instantiate()
	add_child(action_menu)
	action_menu.setup(camera, entity.position)
	action_menu.update_button_states(state.has_moved, state.has_activated)

	action_menu.move_pressed.connect(_on_move_pressed)
	action_menu.attack_pressed.connect(_on_attack_pressed)
	action_menu.end_turn_pressed.connect(_on_end_turn_pressed)


func deselect_survivor() -> void:
	active_survivor_id = ""

	_hide_selection_visuals()

	if action_menu:
		action_menu.queue_free()
		action_menu = null


func _on_move_pressed() -> void:
	if active_survivor_id == "":
		return

	var state = survivor_states[active_survivor_id]
	var entity: EntityPlaceholder = state.entity_node
	var grid_pos := grid.world_to_grid(entity.position)

	# Hide action menu during movement
	if action_menu:
		action_menu.hide()

	# Create movement mode
	movement_mode = InteractiveMovementMode.new()
	add_child(movement_mode)

	var blocking_check := func(tile: Vector2i) -> bool:
		return _is_tile_blocked_by_monster(tile)

	movement_mode.movement_completed.connect(_on_movement_completed)
	movement_mode.movement_cancelled.connect(_on_movement_cancelled)
	movement_mode.start(grid, camera, grid_pos, state.data.movement_range, blocking_check)


func _on_movement_completed(destination: Vector2i) -> void:
	if active_survivor_id == "":
		return

	var state = survivor_states[active_survivor_id]
	var entity: EntityPlaceholder = state.entity_node

	# Move entity
	entity.position = grid.grid_to_world(destination.x, destination.y)

	# Update state
	state.has_moved = true

	# Update selection visuals
	_update_selection_visuals(entity.position)

	# Show menu again and update buttons
	if action_menu:
		action_menu.setup(camera, entity.position)
		action_menu.update_button_states(state.has_moved, state.has_activated)
		action_menu.show()

	# Cleanup movement mode
	if movement_mode:
		movement_mode.queue_free()
		movement_mode = null

	# Check if turn complete
	_check_auto_complete_turn(active_survivor_id)


func _on_movement_cancelled() -> void:
	# Show menu again
	if action_menu:
		action_menu.show()

	# Cleanup movement mode
	if movement_mode:
		movement_mode.queue_free()
		movement_mode = null


func _on_attack_pressed() -> void:
	if active_survivor_id == "":
		return

	var state = survivor_states[active_survivor_id]

	# No-op for now
	print("Attack pressed for ", active_survivor_id)

	# Update state
	state.has_activated = true

	# Update button states
	if action_menu:
		action_menu.update_button_states(state.has_moved, state.has_activated)

	# Check if turn complete
	_check_auto_complete_turn(active_survivor_id)


func _on_end_turn_pressed() -> void:
	if active_survivor_id == "":
		return

	_complete_survivor_turn(active_survivor_id)
	deselect_survivor()


func _complete_survivor_turn(survivor_id: String) -> void:
	var state = survivor_states[survivor_id]
	state.is_turn_complete = true

	var entity: EntityPlaceholder = state.entity_node
	entity.set_greyed_out(true)

	# Check if all survivors complete
	if _check_all_survivors_complete():
		all_survivors_complete.emit()


func _check_auto_complete_turn(survivor_id: String) -> void:
	var state = survivor_states[survivor_id]
	if state.has_moved and state.has_activated:
		_complete_survivor_turn(survivor_id)
		deselect_survivor()


func _check_all_survivors_complete() -> bool:
	for entity_id in survivor_states:
		var state = survivor_states[entity_id]
		if not state.is_turn_complete:
			return false
	return true


func _is_tile_blocked_by_monster(tile: Vector2i) -> bool:
	for entity_id in entities:
		var entity: EntityPlaceholder = entities[entity_id]
		if entity.entity_type == EntityPlaceholder.EntityType.MONSTER:
			var entity_grid_pos := grid.world_to_grid(entity.position)
			if entity_grid_pos == tile:
				return true
	return false


func _create_selection_visuals() -> void:
	# Create highlight mesh
	_selection_highlight = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(grid.tile_size * 1.2, grid.tile_size * 1.5, grid.tile_size * 1.2)
	_selection_highlight.mesh = box_mesh

	var highlight_mat := StandardMaterial3D.new()
	highlight_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3)
	highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selection_highlight.material_override = highlight_mat

	grid.add_child(_selection_highlight)
	_selection_highlight.hide()

	# Create ground indicator
	_ground_indicator = MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(grid.tile_size * 0.8, grid.tile_size * 0.8)
	_ground_indicator.mesh = quad_mesh

	var indicator_mat := StandardMaterial3D.new()
	indicator_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.5)
	indicator_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_indicator.material_override = indicator_mat
	_ground_indicator.rotation_degrees.x = -90

	grid.add_child(_ground_indicator)
	_ground_indicator.hide()


func _update_selection_visuals(position_3d: Vector3) -> void:
	_selection_highlight.position = position_3d
	_selection_highlight.show()

	_ground_indicator.position = position_3d + Vector3(0, 0.1, 0)
	_ground_indicator.show()


func _hide_selection_visuals() -> void:
	if _selection_highlight:
		_selection_highlight.hide()
	if _ground_indicator:
		_ground_indicator.hide()
```

**Step 2: Verify no script errors**

Run: Open Godot editor, check Output panel
Expected: No errors, class_name registered

**Step 3: Commit**

```bash
git add scripts/game/player_turn_controller.gd
git commit -m "feat: add PlayerTurnController for survivor turn management

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Integrate PlayerTurnController into TacticalGameScreen

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd`

**Step 1: Add PlayerTurnController member variable**

Add after existing member variables (around line 18):

```gdscript
var player_turn_controller: PlayerTurnController
```

**Step 2: Initialize PlayerTurnController in _ready()**

Add after `_setup_camera()` call (around line 42):

```gdscript
	# Initialize player turn controller
	player_turn_controller = PlayerTurnController.new()
	add_child(player_turn_controller)
	player_turn_controller.setup(grid, entities, turn_state, camera)
	player_turn_controller.all_survivors_complete.connect(_on_all_survivors_complete)
```

**Step 3: Add entity click detection in _input()**

Add at the end of `_input()` function (before the closing brace):

```gdscript
	# Handle entity clicks for survivor selection
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not turn_state.is_player_turn():
			return

		var mouse_pos := event.position
		var ray_origin := camera.project_ray_origin(mouse_pos)
		var ray_direction := camera.project_ray_normal(mouse_pos)

		# Check if we hit any entity
		var space_state := get_viewport().world_3d.direct_space_state
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000)
		var result := space_state.intersect_ray(query)

		if result:
			# Find entity by checking all entities
			for entity_id in entities:
				var entity: Node3D = entities[entity_id]
				if _is_ancestor_of(result.collider, entity):
					player_turn_controller.on_entity_clicked(entity_id)
					get_viewport().set_input_as_handled()
					return
```

**Step 4: Add helper function for entity detection**

Add at the end of the class:

```gdscript
func _is_ancestor_of(node: Node, potential_ancestor: Node) -> bool:
	var current := node
	while current:
		if current == potential_ancestor:
			return true
		current = current.get_parent()
	return false
```

**Step 5: Modify _on_all_survivors_complete()**

Add new function (or modify if it exists):

```gdscript
func _on_all_survivors_complete() -> void:
	# Automatically trigger monster turn
	turn_state.set_turn(TurnState.Turn.MONSTER)
	tactical_ui.set_disabled(true)
	await monster_ai.execute_monster_turn()
```

**Step 6: Modify _on_monster_ai_completed()**

Update existing function to reset survivors:

```gdscript
func _on_monster_ai_completed() -> void:
	# Reset all survivor states for new player turn
	player_turn_controller.reset_for_new_turn()
	tactical_ui.set_disabled(false)
	turn_state.set_turn(TurnState.Turn.PLAYER)
```

**Step 7: Add collision shapes to entities for raycasting**

Instructions for manual scene modification:
1. Open `scenes/game/entity_placeholder.tscn`
2. Add child node: StaticBody3D
3. Add child to StaticBody3D: CollisionShape3D
4. Set CollisionShape3D shape to BoxShape3D
5. Set BoxShape3D size to (30, 40, 30) approximately
6. Save scene

**Step 8: Test in Godot editor**

Run: Launch the tactical game scene, try clicking survivors
Expected: Should be able to select survivors and see action menu

**Step 9: Commit**

```bash
git add scripts/game/tactical_game_screen.gd scenes/game/entity_placeholder.tscn
git commit -m "feat: integrate PlayerTurnController with click detection

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Manual Testing and Bug Fixes

**Testing Checklist:**

Test each scenario:

1. **Select survivor, no actions taken, select another**
   - Expected: Should switch immediately without confirmation

2. **Select survivor, use Move only, select another**
   - Expected: Confirmation dialog appears

3. **Select survivor, use Attack only, select another**
   - Expected: Confirmation dialog appears

4. **Select survivor, use both actions**
   - Expected: Survivor auto-greys out, deselects

5. **All survivors complete**
   - Expected: Monster turn automatically starts

6. **Movement mode: ESC cancels**
   - Expected: Returns to action menu, Move still enabled

7. **Movement mode: hover shows path preview**
   - Expected: Yellow path tiles appear

8. **Movement mode: click valid tile moves survivor**
   - Expected: Survivor moves to clicked tile

9. **Monsters block movement**
   - Expected: Can't move through/onto monster tiles

10. **After monster turn**
    - Expected: All survivors reset (colors restored, not greyed)

**Step 1: Run tests manually**

For each test case, document the result. If any fail, investigate and fix.

**Step 2: Fix any issues found**

Common issues to watch for:
- Camera reference not passed correctly
- Raycast not hitting collision shapes
- Menu positioning incorrect
- Path preview not clearing
- Grey-out not working

**Step 3: Commit fixes**

```bash
git add <fixed-files>
git commit -m "fix: resolve player turn system issues from testing

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Polish and Edge Cases

**Files:**
- Modify: `scripts/game/player_turn_controller.gd`
- Modify: `scripts/game/interactive_movement_mode.gd`

**Step 1: Add input debouncing during transitions**

In `PlayerTurnController`, add:

```gdscript
var _is_transitioning: bool = false

func _set_transitioning(value: bool) -> void:
	_is_transitioning = value

# Add check to on_entity_clicked:
func on_entity_clicked(entity_id: String) -> void:
	if _is_transitioning:
		return
	# ... rest of function
```

**Step 2: Disable camera rotation during movement mode**

In `tactical_game_screen.gd`, modify `_input()`:

```gdscript
func _input(event: InputEvent) -> void:
	# Block input during camera rotation
	if is_rotating:
		return

	# Block camera rotation during movement mode
	if player_turn_controller and player_turn_controller.movement_mode:
		# Allow only movement-related input
		if not (event is InputEventMouseButton or event.is_action("ui_cancel")):
			return

	# ... rest of function
```

**Step 3: Handle empty movement range (surrounded by monsters)**

In `InteractiveMovementMode.start()`, add check:

```gdscript
	valid_tiles = MovementCalculator.calculate_valid_tiles(grid, from, range, blocking_check)

	if valid_tiles.is_empty():
		print("No valid moves - surrounded!")
		# Don't create highlights, immediately cancel
		movement_cancelled.emit()
		return
```

**Step 4: Add smooth movement animation (optional polish)**

In `PlayerTurnController._on_movement_completed()`, replace direct position assignment:

```gdscript
	# Move entity with tween
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(entity, "position", grid.grid_to_world(destination.x, destination.y), 0.3)
	await tween.finished
```

**Step 5: Test edge cases**

Test:
- Rapid clicking during movement
- Camera rotation attempt during movement
- Surrounded survivor (no valid moves)
- Movement animation interruption

**Step 6: Commit polish**

```bash
git add scripts/game/player_turn_controller.gd scripts/game/interactive_movement_mode.gd scripts/game/tactical_game_screen.gd
git commit -m "polish: add input debouncing and movement animation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Documentation Update

**Files:**
- Modify: `docs/plans/2026-02-09-player-turn-system-implementation.md`

**Step 1: Mark design as implemented**

Update the status in the design document header to "Implemented".

**Step 2: Document any deviations from design**

Add a section at the end noting any changes made during implementation.

**Step 3: Commit documentation**

```bash
git add docs/plans/2026-02-09-player-turn-system-design.md
git commit -m "docs: mark player turn system as implemented

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

**Total Tasks:** 10
**Estimated Time:** 2-3 hours for implementation + testing

**Key Components Created:**
1. SurvivorData - Resource for stats
2. MovementCalculator - A* pathfinding
3. InteractiveMovementMode - Player input handling
4. SurvivorActionMenu - UI for actions
5. PlayerTurnController - Core turn management

**Integration Points:**
- tactical_game_screen.gd
- entity_placeholder.gd
- Collision shapes for click detection

**Testing Focus:**
- Action confirmation dialogs
- Movement pathfinding with blocking
- Auto-completion and turn transitions
- Visual feedback (selection, grey-out, path preview)
