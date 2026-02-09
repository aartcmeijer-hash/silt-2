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
