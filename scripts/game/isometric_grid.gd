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
	# Use GridMap.map_to_local() to get accurate cell center position
	return grid_map.map_to_local(Vector3i(grid_x + offset.x, 0, grid_y + offset.y))


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var offset := _get_grid_offset()
	# Use GridMap.local_to_map() to get accurate grid position
	var map_pos := grid_map.local_to_map(world_pos)
	return Vector2i(map_pos.x - offset.x, map_pos.z - offset.y)


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
	var y_top := 0.5  # Top of grid board
	var y_bottom := -25.0  # Bottom of grid board (medium thickness)
	var line_color := Color(1.0, 1.0, 1.0, 0.9)  # Bright white, high opacity

	# Get half cell size for positioning lines at cell edges
	var half_cell_x := grid_map.cell_size.x / 2.0
	var half_cell_z := grid_map.cell_size.z / 2.0

	# Draw top horizontal lines (along Z-axis) at cell edges
	for x in range(grid_width + 1):
		var cell_center := grid_map.map_to_local(Vector3i(x + offset.x, 0, offset.y))
		var line_x := cell_center.x - half_cell_x

		var start_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y))
		var end_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y + grid_height - 1))
		var start_z := start_cell.z - half_cell_z
		var end_z := end_cell.z + half_cell_z

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_top, start_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_top, end_z))

	# Draw bottom horizontal lines (along Z-axis) at cell edges
	for x in range(grid_width + 1):
		var cell_center := grid_map.map_to_local(Vector3i(x + offset.x, 0, offset.y))
		var line_x := cell_center.x - half_cell_x

		var start_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y))
		var end_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y + grid_height - 1))
		var start_z := start_cell.z - half_cell_z
		var end_z := end_cell.z + half_cell_z

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_bottom, start_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_bottom, end_z))

	# Draw top horizontal lines (along X-axis) at cell edges
	for z in range(grid_height + 1):
		var cell_center := grid_map.map_to_local(Vector3i(offset.x, 0, z + offset.y))
		var line_z := cell_center.z - half_cell_z

		var start_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y))
		var end_cell := grid_map.map_to_local(Vector3i(offset.x + grid_width - 1, 0, offset.y))
		var start_x := start_cell.x - half_cell_x
		var end_x := end_cell.x + half_cell_x

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(start_x, y_top, line_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(end_x, y_top, line_z))

	# Draw bottom horizontal lines (along X-axis) at cell edges
	for z in range(grid_height + 1):
		var cell_center := grid_map.map_to_local(Vector3i(offset.x, 0, z + offset.y))
		var line_z := cell_center.z - half_cell_z

		var start_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y))
		var end_cell := grid_map.map_to_local(Vector3i(offset.x + grid_width - 1, 0, offset.y))
		var start_x := start_cell.x - half_cell_x
		var end_x := end_cell.x + half_cell_x

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(start_x, y_bottom, line_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(end_x, y_bottom, line_z))

	# Draw vertical edge lines connecting top and bottom around perimeter
	# Small offset to prevent z-fighting with box sides
	var edge_offset := 0.5

	# Left and right edges (along Z)
	for z in range(grid_height + 1):
		var cell_center := grid_map.map_to_local(Vector3i(offset.x, 0, z + offset.y))
		var line_z := cell_center.z - half_cell_z

		# Left edge (offset outward in -X direction)
		var left_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y))
		var left_x := left_cell.x - half_cell_x - edge_offset

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(left_x, y_top, line_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(left_x, y_bottom, line_z))

		# Right edge (offset outward in +X direction)
		var right_cell := grid_map.map_to_local(Vector3i(offset.x + grid_width - 1, 0, offset.y))
		var right_x := right_cell.x + half_cell_x + edge_offset

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(right_x, y_top, line_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(right_x, y_bottom, line_z))

	# Top and bottom edges (along X)
	for x in range(grid_width + 1):
		var cell_center := grid_map.map_to_local(Vector3i(x + offset.x, 0, offset.y))
		var line_x := cell_center.x - half_cell_x

		# Top edge (offset outward in -Z direction)
		var top_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y))
		var top_z := top_cell.z - half_cell_z - edge_offset

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_top, top_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_bottom, top_z))

		# Bottom edge (offset outward in +Z direction)
		var bottom_cell := grid_map.map_to_local(Vector3i(offset.x, 0, offset.y + grid_height - 1))
		var bottom_z := bottom_cell.z + half_cell_z + edge_offset

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_top, bottom_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(line_x, y_bottom, bottom_z))

	mesh.surface_end()


func _update_gridlines_visibility() -> void:
	if _gridlines_mesh != null:
		_gridlines_mesh.visible = SettingsManager.get_gridlines_enabled()


func _on_gridlines_setting_changed(enabled: bool) -> void:
	_update_gridlines_visibility()
