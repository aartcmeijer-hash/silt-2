class_name PlayerTurnController
extends Node
## Manages player turn phase, survivor selection, and action coordination.

signal all_survivors_complete()

const SURVIVOR_ACTION_MENU_SCENE := preload("res://scenes/game/ui/survivor_action_menu.tscn")

var grid: IsometricGrid
var entities: Dictionary
var turn_state: TurnState
var camera: Camera3D
var subviewport: SubViewport = null
var subviewport_container: SubViewportContainer = null

var survivor_states: Dictionary = {}  # entity_id -> SurvivorState
var active_survivor_id: String = ""
var _is_transitioning: bool = false: set = _set_transitioning

var action_menu: SurvivorActionMenu = null
var movement_mode: InteractiveMovementMode = null

# Selection visuals
var _selection_highlight: MeshInstance3D = null
var _ground_indicator: MeshInstance3D = null


func _set_transitioning(value: bool) -> void:
	_is_transitioning = value


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
	# Ignore during transitions (e.g. movement animation)
	if _is_transitioning:
		return

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
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "Survivor still has actions available. End their turn?"
	dialog.ok_button_text = "Yes"
	dialog.add_cancel_button("No")

	var survivor_to_complete := active_survivor_id  # Fix 3: capture by value
	dialog.confirmed.connect(func():
		_complete_survivor_turn(survivor_to_complete)
		select_survivor(new_entity_id)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

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
	action_menu.setup(camera, entity.position, subviewport_container)
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

	var moving_entity_id := active_survivor_id
	var blocking_check := func(tile: Vector2i) -> bool:
		return _is_tile_blocked(tile, moving_entity_id)

	movement_mode.movement_completed.connect(_on_movement_completed)
	movement_mode.movement_cancelled.connect(_on_movement_cancelled)
	movement_mode.start(grid, camera, grid_pos, state.data.movement_range, blocking_check, subviewport)


func _on_movement_completed(destination: Vector2i) -> void:
	var moving_id := active_survivor_id
	if moving_id == "":
		return

	var state = survivor_states[moving_id]
	var entity: EntityPlaceholder = state.entity_node

	# Move entity with tween
	_set_transitioning(true)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(entity, "position", grid.grid_to_world(destination.x, destination.y), 0.3)
	await tween.finished
	_set_transitioning(false)

	# Guard: survivor may have been deselected or switched during animation
	if not moving_id in survivor_states:
		return

	# Update state
	state.has_moved = true

	# Update selection visuals only if this survivor is still active
	if active_survivor_id == moving_id:
		_update_selection_visuals(entity.position)

	# Show menu again and update buttons
	if action_menu and active_survivor_id == moving_id:
		action_menu.setup(camera, entity.position, subviewport_container)
		action_menu.update_button_states(state.has_moved, state.has_activated)
		action_menu.show()

	# Cleanup movement mode
	if movement_mode:
		movement_mode.queue_free()
		movement_mode = null

	# Check if turn complete
	_check_auto_complete_turn(moving_id)


func _on_movement_cancelled() -> void:
	_is_transitioning = false

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


func _is_tile_blocked(tile: Vector2i, moving_entity_id: String) -> bool:
	for entity_id in entities:
		var entity: EntityPlaceholder = entities[entity_id]
		# Monsters always block
		if entity.entity_type == EntityPlaceholder.EntityType.MONSTER:
			var entity_grid_pos := grid.world_to_grid(entity.position)
			if entity_grid_pos == tile:
				return true
		# Other survivors block (but not the moving survivor itself)
		if entity.entity_type == EntityPlaceholder.EntityType.SURVIVOR and entity_id != moving_entity_id:
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
