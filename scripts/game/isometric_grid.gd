class_name IsometricGrid
extends Node2D
## Renders a 20x20 isometric grid and provides coordinate conversion.

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_width: int = 32
@export var tile_height: int = 16
@export var line_color: Color = Color(0.3, 0.35, 0.4, 0.5)


func _draw() -> void:
	_draw_grid()


func _draw_grid() -> void:
	for x in range(grid_width + 1):
		var start := grid_to_world(x, 0)
		var end := grid_to_world(x, grid_height)
		draw_line(start, end, line_color)

	for y in range(grid_height + 1):
		var start := grid_to_world(0, y)
		var end := grid_to_world(grid_width, y)
		draw_line(start, end, line_color)


func grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var world_x := (grid_x - grid_y) * (tile_width / 2)
	var world_y := (grid_x + grid_y) * (tile_height / 2)
	return Vector2(world_x, world_y)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var half_tile_w := tile_width / 2.0
	var half_tile_h := tile_height / 2.0
	var grid_x := int((world_pos.x / half_tile_w + world_pos.y / half_tile_h) / 2.0)
	var grid_y := int((world_pos.y / half_tile_h - world_pos.x / half_tile_w) / 2.0)
	return Vector2i(grid_x, grid_y)


func get_grid_center() -> Vector2i:
	return Vector2i(grid_width / 2, grid_height / 2)


func get_bottom_row_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var start_x := (grid_width - count) / 2
	for i in range(count):
		positions.append(Vector2i(start_x + i, grid_height - 1))
	return positions
