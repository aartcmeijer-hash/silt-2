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


## Find shortest path from 'from' to 'to' using GridPathfinder.
## Returns array of Vector2i coordinates forming the path (excluding 'from', including 'to').
## Returns empty array if no path exists.
static func find_path(
	grid: IsometricGrid,
	from: Vector2i,
	to: Vector2i,
	blocking_check: Callable
) -> Array[Vector2i]:
	# Create temporary pathfinder with blocking rules applied
	var pathfinder := GridPathfinder.new(grid.grid_width, grid.grid_height)
	pathfinder.apply_blocking_rules(blocking_check)

	# Allow destination even if blocked (for adjacent attacks)
	pathfinder.set_point_disabled(to.x, to.y, false)

	# Get path from GridPathfinder
	var path := pathfinder.find_path(from, to)

	# Remove starting position to match original behavior
	if path.size() > 0 and path[0] == from:
		path.remove_at(0)

	return path
