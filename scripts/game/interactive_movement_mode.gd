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

var _last_hovered_tile: Vector2i = Vector2i(-1, -1)
var _subviewport: SubViewport


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
	p_blocking_check: Callable,
	p_subviewport: SubViewport = null
) -> void:
	grid = p_grid
	_camera = p_camera
	_subviewport = p_subviewport
	current_position = from
	blocking_check = p_blocking_check

	# Calculate valid tiles
	valid_tiles = MovementCalculator.calculate_valid_tiles(grid, from, range, blocking_check)

	# If no valid moves (surrounded), cancel immediately
	if valid_tiles.is_empty():
		movement_cancelled.emit()
		return

	# Create visual indicators
	_create_tile_highlights()

	set_process_input(true)


func cleanup() -> void:
	_clear_highlights()
	_clear_path_preview()
	_last_hovered_tile = Vector2i(-1, -1)
	set_process_input(false)
	set_process(false)


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

	var mouse_pos := _subviewport.get_mouse_position() if _subviewport else get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_pos)
	var ray_direction := _camera.project_ray_normal(mouse_pos)

	# Raycast to grid plane (y=0)
	if abs(ray_direction.y) < 0.001:
		_clear_path_preview()
		return
	var t := -ray_origin.y / ray_direction.y
	if t < 0:
		_clear_path_preview()
		return

	var world_pos := ray_origin + ray_direction * t
	var grid_pos := grid.world_to_grid(world_pos)

	# Show path preview if hovering over valid tile
	if grid_pos in valid_tiles:
		if grid_pos != _last_hovered_tile:
			_last_hovered_tile = grid_pos
			_show_path_preview(grid_pos)
	else:
		if _last_hovered_tile != Vector2i(-1, -1):
			_last_hovered_tile = Vector2i(-1, -1)
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
		var mouse_pos := _subviewport.get_mouse_position() if _subviewport else event.position
		var ray_origin := _camera.project_ray_origin(mouse_pos)
		var ray_direction := _camera.project_ray_normal(mouse_pos)

		if abs(ray_direction.y) < 0.001:
			return
		var t := -ray_origin.y / ray_direction.y
		if t < 0:
			return

		var world_pos := ray_origin + ray_direction * t
		var grid_pos := grid.world_to_grid(world_pos)

		if grid_pos in valid_tiles:
			movement_completed.emit(grid_pos)
			cleanup()
			get_viewport().set_input_as_handled()
