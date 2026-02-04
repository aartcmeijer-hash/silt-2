class_name IsometricGrid
extends Node3D
## Renders a 20x20 isometric grid using GridMap and provides coordinate conversion.

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_size: float = 32.0

@onready var grid_map: GridMap = $GridMap


func _ready() -> void:
	_populate_grid()


func _populate_grid() -> void:
	# Center grid at origin by offsetting
	var offset_x := -grid_width / 2
	var offset_z := -grid_height / 2

	for x in range(grid_width):
		for z in range(grid_height):
			grid_map.set_cell_item(Vector3i(x + offset_x, 0, z + offset_z), 0)


func grid_to_world(grid_x: int, grid_y: int) -> Vector3:
	var offset_x := -grid_width / 2
	var offset_z := -grid_height / 2
	return Vector3((grid_x + offset_x) * tile_size, 0, (grid_y + offset_z) * tile_size)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var offset_x := -grid_width / 2
	var offset_z := -grid_height / 2
	var grid_x := int(round(world_pos.x / tile_size)) - offset_x
	var grid_z := int(round(world_pos.z / tile_size)) - offset_z
	return Vector2i(grid_x, grid_z)


func get_grid_center() -> Vector2i:
	return Vector2i(grid_width / 2, grid_height / 2)


func get_bottom_row_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var start_x := (grid_width - count) / 2
	for i in range(count):
		positions.append(Vector2i(start_x + i, grid_height - 1))
	return positions
