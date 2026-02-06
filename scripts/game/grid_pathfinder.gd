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
	var neighbors: Array[Vector2i] = [
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
	if not _is_valid_cell(from.x, from.y) or not _is_valid_cell(to.x, to.y):
		return []

	var from_id := _get_point_id(from.x, from.y)
	var to_id := _get_point_id(to.x, to.y)

	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return []

	var path: PackedVector2Array = astar.get_point_path(from_id, to_id)

	# Convert Vector2 path to Vector2i array and limit distance
	var result: Array[Vector2i] = []
	var limit: int = path.size() if max_distance < 0 else min(path.size(), max_distance + 1)

	for i in range(limit):
		result.append(Vector2i(int(path[i].x), int(path[i].y)))

	return result


func _get_point_id(x: int, y: int) -> int:
	return y * grid_width + x


func _is_valid_cell(x: int, y: int) -> bool:
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height
