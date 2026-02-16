class_name InteractiveAttackMode
extends Node
## Handles interactive monster targeting for survivor attacks.
## Highlights monsters within weapon range and emits target_selected when one is clicked.

signal target_selected(monster_id: String)
signal attack_cancelled()

var grid: IsometricGrid
var _camera: Camera3D
var _subviewport: SubViewport
var _entities: Dictionary
var _attacker_pos: Vector2i
var _weapon_range: int
var _valid_target_ids: Array[String] = []
var _saved_colors: Dictionary = {}  # entity_id -> Color


func start(
	p_grid: IsometricGrid,
	p_camera: Camera3D,
	p_subviewport: SubViewport,
	p_entities: Dictionary,
	p_attacker_pos: Vector2i,
	p_weapon_range: int
) -> void:
	grid = p_grid
	_camera = p_camera
	_subviewport = p_subviewport
	_entities = p_entities
	_attacker_pos = p_attacker_pos
	_weapon_range = p_weapon_range

	_find_valid_targets()

	if _valid_target_ids.is_empty():
		attack_cancelled.emit()
		return

	_highlight_targets()
	set_process_input(true)


func cleanup() -> void:
	_unhighlight_targets()
	set_process_input(false)


func _find_valid_targets() -> void:
	_valid_target_ids.clear()
	for entity_id in _entities:
		var entity: EntityPlaceholder = _entities[entity_id]
		if entity.entity_type != EntityPlaceholder.EntityType.MONSTER:
			continue
		var monster_pos: Vector2i = grid.world_to_grid(entity.position)
		var dist: int = abs(_attacker_pos.x - monster_pos.x) + abs(_attacker_pos.y - monster_pos.y)
		if dist <= _weapon_range:
			_valid_target_ids.append(entity_id)


func _highlight_targets() -> void:
	for entity_id in _valid_target_ids:
		var entity: EntityPlaceholder = _entities[entity_id]
		if entity.body and entity.body.get_surface_override_material(0):
			var mat := entity.body.get_surface_override_material(0) as StandardMaterial3D
			if mat:
				_saved_colors[entity_id] = mat.albedo_color
				mat.albedo_color = Color(1.0, 0.5, 0.0)


func _unhighlight_targets() -> void:
	for entity_id in _saved_colors:
		if not _entities.has(entity_id):
			continue
		var entity: EntityPlaceholder = _entities[entity_id]
		if entity.body and entity.body.get_surface_override_material(0):
			var mat := entity.body.get_surface_override_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_color = _saved_colors[entity_id]
	_saved_colors.clear()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		attack_cancelled.emit()
		cleanup()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		attack_cancelled.emit()
		cleanup()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = _subviewport.get_mouse_position() if _subviewport else event.position
		var clicked_id: String = _find_closest_valid_target(mouse_pos)
		if clicked_id != "":
			target_selected.emit(clicked_id)
			cleanup()
			get_viewport().set_input_as_handled()


func _find_closest_valid_target(mouse_pos: Vector2) -> String:
	var closest_id := ""
	var closest_dist_sq := 50.0 * 50.0
	for entity_id in _valid_target_ids:
		var entity: EntityPlaceholder = _entities[entity_id]
		var screen_pos: Vector2 = _camera.unproject_position(entity.global_position)
		var dist_sq: float = (screen_pos - mouse_pos).length_squared()
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_id = entity_id
	return closest_id
