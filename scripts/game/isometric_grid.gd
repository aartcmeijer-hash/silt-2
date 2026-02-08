class_name IsometricGrid
extends Node3D
## Renders a 20x20 isometric grid using GridMap and provides coordinate conversion.

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_size: float = 32.0

@onready var grid_map: GridMap = $GridMap

var _gridlines_mesh: MeshInstance3D = null


func _get_grid_offset() -> Vector2i:
	return Vector2i(-int(floor(grid_width / 2.0)), -int(floor(grid_height / 2.0)))


func _ready() -> void:
	_populate_grid()
	_create_gridlines()
	_update_gridlines_visibility()
	SettingsManager.gridlines_changed.connect(_on_gridlines_setting_changed)


func _populate_grid() -> void:
	# Center grid at origin by offsetting
	var offset := _get_grid_offset()

	for x in range(grid_width):
		for z in range(grid_height):
			grid_map.set_cell_item(Vector3i(x + offset.x, 0, z + offset.y), 0)


func grid_to_world(grid_x: int, grid_y: int) -> Vector3:
	var offset := _get_grid_offset()
	return Vector3((grid_x + offset.x) * tile_size, 0, (grid_y + offset.y) * tile_size)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var offset := _get_grid_offset()
	var grid_x := int(round(world_pos.x / tile_size)) - offset.x
	var grid_z := int(round(world_pos.z / tile_size)) - offset.y
	return Vector2i(grid_x, grid_z)


func get_grid_center() -> Vector2i:
	return Vector2i(grid_width / 2, grid_height / 2)


func get_bottom_row_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var start_x := (grid_width - count) / 2
	for i in range(count):
		positions.append(Vector2i(start_x + i, grid_height - 1))
	return positions


func _create_gridlines() -> void:
	# Create MeshInstance3D for gridlines if it doesn't exist
	if _gridlines_mesh == null:
		_gridlines_mesh = MeshInstance3D.new()
		_gridlines_mesh.name = "GridLines"
		add_child(_gridlines_mesh)

	# Create material
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create mesh
	var mesh := ImmediateMesh.new()
	_gridlines_mesh.mesh = mesh
	_gridlines_mesh.material_override = material

	# Draw gridlines
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var offset := _get_grid_offset()
	var y_pos := 0.01  # Slight offset to prevent z-fighting
	var line_color := Color(1.0, 1.0, 1.0, 0.9)  # Bright white, high opacity

	# Draw vertical lines (along Z-axis)
	for x in range(grid_width + 1):
		# Use GridMap.map_to_local() to get actual world positions
		var start_pos := grid_map.map_to_local(Vector3i(x + offset.x, 0, offset.y))
		var end_pos := grid_map.map_to_local(Vector3i(x + offset.x, 0, offset.y + grid_height))

		start_pos.y = y_pos
		end_pos.y = y_pos

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(start_pos)
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(end_pos)

	# Draw horizontal lines (along X-axis)
	for z in range(grid_height + 1):
		# Use GridMap.map_to_local() to get actual world positions
		var start_pos := grid_map.map_to_local(Vector3i(offset.x, 0, z + offset.y))
		var end_pos := grid_map.map_to_local(Vector3i(offset.x + grid_width, 0, z + offset.y))

		start_pos.y = y_pos
		end_pos.y = y_pos

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(start_pos)
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(end_pos)

	mesh.surface_end()


func _update_gridlines_visibility() -> void:
	if _gridlines_mesh != null:
		_gridlines_mesh.visible = SettingsManager.get_gridlines_enabled()


func _on_gridlines_setting_changed(enabled: bool) -> void:
	_update_gridlines_visibility()
