class_name MonsterAIController
extends Node
## Orchestrates monster AI turn execution.
## Handles targeting, pathfinding, movement animation, and survivor displacement.

signal turn_completed

var grid: IsometricGrid
var entities: Dictionary
var pathfinder: GridPathfinder
var targeting_strategy: TargetingStrategy
var monster_decks: Dictionary = {}  # monster_id -> MonsterDeck
var deck_ui = null  # Reference to UI component (will be set later)

const MOVE_ANIMATION_DURATION := 0.2
const MAX_MOVE_DISTANCE := 6


func _init(grid_ref: IsometricGrid, entities_ref: Dictionary) -> void:
	grid = grid_ref
	entities = entities_ref
	pathfinder = GridPathfinder.new(grid.grid_width, grid.grid_height)
	targeting_strategy = RandomSurvivorTargeting.new()


func execute_monster_turn() -> void:
	var monsters: Dictionary = _get_monsters()
	var survivors: Dictionary = _get_survivors()

	for monster_id in monsters:
		# Check if monster has a deck
		if not monster_decks.has(monster_id):
			push_warning("Monster %s has no deck, skipping turn" % monster_id)
			continue

		var deck: MonsterDeck = monster_decks[monster_id]

		# Shuffle if needed
		if deck.needs_shuffle():
			# TODO: Add shuffle animation when UI is ready
			deck.shuffle_discard_into_deck()

		# Check for completely empty deck (initialization error)
		if deck.get_draw_pile_count() == 0 and deck.get_discard_pile_count() == 0:
			push_error("Monster %s has completely empty deck (no cards at all)" % monster_id)
			continue

		# Draw card
		var card: MonsterActionCard = deck.draw_card()
		if not card:
			push_warning("Failed to draw card for monster %s" % monster_id)
			continue

		# TODO: Add card flip animation when UI is ready

		# Resolve targeting
		var target_id: String = _resolve_targeting(card, monster_id, monsters, survivors)
		if target_id.is_empty():
			deck.discard_card(card)
			continue

		# Execute action
		await _execute_card_action(monsters[monster_id], card, target_id)

		# Discard card
		deck.discard_card(card)
		# TODO: Add discard animation when UI is ready

	turn_completed.emit()


func _execute_monster_action(monster: EntityPlaceholder, target_id: String) -> void:
	if not entities.has(target_id):
		return

	var target: EntityPlaceholder = entities[target_id]
	var monster_grid_pos: Vector2i = grid.world_to_grid(monster.global_position)
	var target_grid_pos: Vector2i = grid.world_to_grid(target.global_position)

	# Find path (up to MAX_MOVE_DISTANCE spaces)
	var path: Array[Vector2i] = pathfinder.find_path(monster_grid_pos, target_grid_pos, MAX_MOVE_DISTANCE)

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
		var world_pos: Vector3 = grid.grid_to_world(grid_pos.x, grid_pos.y)
		var tween: Tween = create_tween()
		tween.tween_property(monster, "global_position", world_pos, MOVE_ANIMATION_DURATION)
		await tween.finished


func _handle_displacement_at(grid_pos: Vector2i, moving_monster: EntityPlaceholder) -> void:
	# Check if any survivor is at this position
	for entity_id in entities:
		var entity: EntityPlaceholder = entities[entity_id]
		if entity.entity_type != EntityPlaceholder.EntityType.SURVIVOR:
			continue

		var entity_grid_pos: Vector2i = grid.world_to_grid(entity.global_position)
		if entity_grid_pos == grid_pos:
			_displace_survivor(entity, moving_monster)


func _displace_survivor(survivor: EntityPlaceholder, monster: EntityPlaceholder) -> void:
	var survivor_pos: Vector2i = grid.world_to_grid(survivor.global_position)
	var monster_pos: Vector2i = grid.world_to_grid(monster.global_position)

	# Calculate movement direction
	var direction := survivor_pos - monster_pos

	# Get perpendicular directions (rotate 90° left and right)
	var perp_dirs: Array[Vector2i] = [
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
		var entity: EntityPlaceholder = entities[entity_id]
		var entity_grid_pos: Vector2i = grid.world_to_grid(entity.global_position)
		if entity_grid_pos == grid_pos:
			return false

	return true


func _move_entity_to(entity: EntityPlaceholder, grid_pos: Vector2i) -> void:
	var world_pos: Vector3 = grid.grid_to_world(grid_pos.x, grid_pos.y)
	entity.global_position = world_pos


func _get_monsters() -> Dictionary:
	var monsters: Dictionary = {}
	for entity_id in entities:
		var entity: EntityPlaceholder = entities[entity_id]
		if entity.entity_type == EntityPlaceholder.EntityType.MONSTER:
			monsters[entity_id] = entity
	return monsters


func _get_survivors() -> Dictionary:
	var survivors: Dictionary = {}
	for entity_id in entities:
		var entity: EntityPlaceholder = entities[entity_id]
		if entity.entity_type == EntityPlaceholder.EntityType.SURVIVOR:
			survivors[entity_id] = entity
	return survivors


func initialize_monster_deck(monster_id: String, deck_config: MonsterDeckConfig) -> void:
	if not deck_config:
		push_error("MonsterAIController: null deck_config for monster %s" % monster_id)
		return

	var deck: MonsterDeck = deck_config.create_deck()
	monster_decks[monster_id] = deck


func _resolve_targeting(card: MonsterActionCard, monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
	# For now, only implement RANDOM_SURVIVOR
	# Future: extend to support other targeting types
	match card.targeting_type:
		MonsterActionCard.TargetingType.RANDOM_SURVIVOR:
			return targeting_strategy.pick_target(monster_id, monsters, survivors)
		_:
			push_warning("Targeting type not yet implemented: %d" % card.targeting_type)
			return ""


func _execute_card_action(monster: EntityPlaceholder, card: MonsterActionCard, target_id: String) -> void:
	# For now, only implement MOVE_TOWARDS
	# Future: extend to support other action types
	match card.action_type:
		MonsterActionCard.ActionType.MOVE_TOWARDS:
			await _execute_move_action(monster, target_id, card.max_distance)
		_:
			push_warning("Action type not yet implemented: %d" % card.action_type)


func _execute_move_action(monster: EntityPlaceholder, target_id: String, max_distance: int) -> void:
	if not entities.has(target_id):
		return

	var target: EntityPlaceholder = entities[target_id]
	var monster_grid_pos: Vector2i = grid.world_to_grid(monster.global_position)
	var target_grid_pos: Vector2i = grid.world_to_grid(target.global_position)

	# Find path (using card's max_distance instead of hardcoded MAX_MOVE_DISTANCE)
	var path: Array[Vector2i] = pathfinder.find_path(monster_grid_pos, target_grid_pos, max_distance)

	if path.size() <= 1:
		return

	path.remove_at(0)
	await _animate_movement(monster, path)
