class_name MonsterAIController
extends Node
## Orchestrates monster AI turn execution.
## Handles targeting, pathfinding, movement animation, and survivor displacement.

signal turn_completed

var grid: IsometricGrid
var entities: Dictionary
var pathfinder: GridPathfinder
var targeting_strategy: TargetingStrategy

const MOVE_ANIMATION_DURATION := 0.2
const MAX_MOVE_DISTANCE := 6


func _init(grid_ref: IsometricGrid, entities_ref: Dictionary) -> void:
	grid = grid_ref
	entities = entities_ref
	pathfinder = GridPathfinder.new(grid.grid_width, grid.grid_height)
	targeting_strategy = RandomSurvivorTargeting.new()


func execute_monster_turn() -> void:
	var monsters := _get_monsters()
	var survivors := _get_survivors()

	for monster_id in monsters:
		var target_id := targeting_strategy.pick_target(monster_id, monsters, survivors)
		if target_id.is_empty():
			continue

		await _execute_monster_action(monsters[monster_id], target_id)

	turn_completed.emit()


func _execute_monster_action(monster: EntityPlaceholder, target_id: String) -> void:
	if not entities.has(target_id):
		return

	var target := entities[target_id] as EntityPlaceholder
	var monster_grid_pos := grid.world_to_grid(monster.global_position)
	var target_grid_pos := grid.world_to_grid(target.global_position)

	# Find path (up to MAX_MOVE_DISTANCE spaces)
	var path := pathfinder.find_path(monster_grid_pos, target_grid_pos, MAX_MOVE_DISTANCE)

	if path.size() <= 1:
		# No movement possible
		return

	# Remove first point (current position)
	path.remove_at(0)

	# Animate movement along path
	await _animate_movement(monster, path)


func _animate_movement(monster: EntityPlaceholder, path: Array[Vector2i]) -> void:
	for grid_pos in path:
		# Handle survivor displacement before moving into cell
		_handle_displacement_at(grid_pos, monster)

		# Tween to next position
		var world_pos := grid.grid_to_world(grid_pos.x, grid_pos.y)
		var tween := create_tween()
		tween.tween_property(monster, "global_position", world_pos, MOVE_ANIMATION_DURATION)
		await tween.finished


func _handle_displacement_at(grid_pos: Vector2i, moving_monster: EntityPlaceholder) -> void:
	# Check if any survivor is at this position
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		if entity.entity_type != EntityPlaceholder.EntityType.SURVIVOR:
			continue

		var entity_grid_pos := grid.world_to_grid(entity.global_position)
		if entity_grid_pos == grid_pos:
			_displace_survivor(entity, moving_monster)


func _displace_survivor(survivor: EntityPlaceholder, monster: EntityPlaceholder) -> void:
	var survivor_pos := grid.world_to_grid(survivor.global_position)
	var monster_pos := grid.world_to_grid(monster.global_position)

	# Calculate movement direction
	var direction := survivor_pos - monster_pos

	# Get perpendicular directions (rotate 90° left and right)
	var perp_dirs := [
		Vector2i(-direction.y, direction.x),  # Rotate left
		Vector2i(direction.y, -direction.x)   # Rotate right
	]

	# Try perpendicular spaces first
	for perp_dir: Vector2i in perp_dirs:
		var new_pos := survivor_pos + perp_dir
		if _is_valid_and_empty(new_pos):
			_move_entity_to(survivor, new_pos)
			return

	# Edge case: No perpendicular space available
	# Leave survivor in place (monster moves through)


func _is_valid_and_empty(grid_pos: Vector2i) -> bool:
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= grid.grid_height:
		return false

	# Check if no entity occupies this position
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		var entity_grid_pos := grid.world_to_grid(entity.global_position)
		if entity_grid_pos == grid_pos:
			return false

	return true


func _move_entity_to(entity: EntityPlaceholder, grid_pos: Vector2i) -> void:
	var world_pos := grid.grid_to_world(grid_pos.x, grid_pos.y)
	entity.global_position = world_pos


func _get_monsters() -> Dictionary:
	var monsters := {}
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		if entity.entity_type == EntityPlaceholder.EntityType.MONSTER:
			monsters[entity_id] = entity
	return monsters


func _get_survivors() -> Dictionary:
	var survivors := {}
	for entity_id in entities:
		var entity := entities[entity_id] as EntityPlaceholder
		if entity.entity_type == EntityPlaceholder.EntityType.SURVIVOR:
			survivors[entity_id] = entity
	return survivors
