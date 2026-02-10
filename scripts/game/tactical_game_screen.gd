extends Control
## Main tactical game screen controller.
## Manages the isometric grid, entities, and turn-based gameplay.

const ENTITY_PLACEHOLDER_SCENE := preload("res://scenes/game/entity_placeholder.tscn")

@onready var camera: Camera3D = $VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport/GameWorld/Camera3D
@onready var grid: IsometricGrid = $VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport/GameWorld/IsometricGrid
@onready var entity_container: Node3D = $VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport/GameWorld/IsometricGrid/EntityContainer
@onready var tactical_ui: Control = $VBoxContainer/HBoxContainer/TacticalUI
@onready var monster_deck_ui: Control = $VBoxContainer/MonsterDeckUI
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/VBoxContainer/ResumeButton
@onready var subviewport: SubViewport = $VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport
@onready var subviewport_container: SubViewportContainer = $VBoxContainer/HBoxContainer/SubViewportContainer

var turn_state: TurnState
var monster_ai: MonsterAIController
var player_turn_controller: PlayerTurnController
var entities: Dictionary = {}
var is_paused: bool = false

# Camera rotation state
var camera_pivot: Node3D
var current_angle: float = 45.0  # Start at corner angle
var is_rotating: bool = false
var rotation_tween: Tween = null


func _ready() -> void:
	turn_state = TurnState.new()
	turn_state.turn_changed.connect(_on_turn_changed)

	monster_ai = MonsterAIController.new(grid, entities)
	add_child(monster_ai)
	monster_ai.turn_completed.connect(_on_monster_ai_completed)
	monster_ai.deck_ui = monster_deck_ui

	tactical_ui.monster_turn_pressed.connect(_on_monster_turn_pressed)
	tactical_ui.end_turn_pressed.connect(_on_end_turn_pressed)

	_setup_camera()
	pause_menu.hide()
	_spawn_initial_entities()

	player_turn_controller = PlayerTurnController.new()
	add_child(player_turn_controller)
	player_turn_controller.subviewport_container = subviewport_container
	player_turn_controller.subviewport = subviewport
	player_turn_controller.setup(grid, entities, turn_state, camera)
	player_turn_controller.all_survivors_complete.connect(_on_all_survivors_complete)

	_update_ui()


func _input(event: InputEvent) -> void:
	# Block all input during camera rotation
	if is_rotating:
		return

	# Block camera rotation during movement mode
	var in_movement_mode := player_turn_controller and player_turn_controller.movement_mode != null

	if event.is_action_pressed("rotate_left") and not in_movement_mode:
		rotate_camera(-90)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_right") and not in_movement_mode:
		rotate_camera(90)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

	# Entity click detection for survivor selection (player turn only)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and not is_rotating and turn_state.is_player_turn():
		# Convert mouse pos to SubViewport space
		var local_pos := subviewport_container.get_local_mouse_position()
		var sv_size := Vector2(subviewport.size)
		var container_size := subviewport_container.size
		var sv_mouse_pos := local_pos / container_size * sv_size

		# Raycast in SubViewport world
		var ray_origin := camera.project_ray_origin(sv_mouse_pos)
		var ray_dir := camera.project_ray_normal(sv_mouse_pos)
		var space_state := subviewport.world_3d.direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin, ray_origin + ray_dir * 1000.0
		)
		var result := space_state.intersect_ray(query)
		if result:
			for entity_id in entities:
				var entity: Node3D = entities[entity_id]
				if _is_ancestor_of(result.collider, entity):
					player_turn_controller.on_entity_clicked(entity_id)
					get_viewport().set_input_as_handled()
					return


func _spawn_initial_entities() -> void:
	var monster_pos: Vector2i = grid.get_grid_center()
	_spawn_entity("monster_1", monster_pos, EntityPlaceholder.EntityType.MONSTER, "M", Color(0.9, 0.2, 0.2))

	var survivor_positions: Array[Vector2i] = grid.get_bottom_row_positions(4)
	for i in range(survivor_positions.size()):
		var pos: Vector2i = survivor_positions[i]
		var id: String = "survivor_%d" % (i + 1)
		_spawn_entity(id, pos, EntityPlaceholder.EntityType.SURVIVOR, "S%d" % (i + 1), Color(0.2, 0.6, 1.0))


func _spawn_entity(id: String, grid_pos: Vector2i, type: EntityPlaceholder.EntityType, label: String, color: Color) -> void:
	var entity: Node3D = ENTITY_PLACEHOLDER_SCENE.instantiate()
	entity_container.add_child(entity)
	entity.setup(id, type, label, color)
	entity.position = grid.grid_to_world(grid_pos.x, grid_pos.y)
	entities[id] = entity

	# Initialize deck for monsters
	if type == EntityPlaceholder.EntityType.MONSTER:
		_initialize_monster_deck(id)
		monster_deck_ui.create_monster_row(id, label)


func _setup_camera() -> void:
	if camera:
		# Create pivot node at grid center
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		var game_world = $VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport/GameWorld
		game_world.add_child(camera_pivot)
		camera_pivot.position = Vector3.ZERO
		camera_pivot.rotation_degrees.y = 45.0  # Start at corner angle

		# Reparent camera to pivot
		var old_parent = camera.get_parent()
		old_parent.remove_child(camera)
		camera_pivot.add_child(camera)

		# Configure camera
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 400.0
		camera.far = 1500.0

		# Position camera relative to pivot for 30° isometric view
		var camera_distance := 1000.0
		var camera_angle := 30.0  # degrees from horizontal
		var camera_height := camera_distance * tan(deg_to_rad(camera_angle))  # ~577

		camera.position = Vector3(0, camera_height, camera_distance)
		camera.look_at(Vector3.ZERO, Vector3.UP)


func rotate_camera(delta_angle: float) -> void:
	is_rotating = true

	# Don't wrap angle - let it accumulate to avoid wrong-direction tweening
	current_angle += delta_angle

	# Kill existing tween if rotating again
	if rotation_tween:
		rotation_tween.kill()

	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_IN_OUT)
	rotation_tween.set_trans(Tween.TRANS_CUBIC)

	# Rotate the pivot (which orbits the camera around the grid)
	rotation_tween.tween_property(camera_pivot, "rotation_degrees:y", current_angle, 0.25)
	rotation_tween.finished.connect(_on_rotation_complete)

	# Note: current_angle can exceed 360 or go negative - that's okay!
	# Godot handles it correctly and we always rotate in the correct direction


func _on_rotation_complete() -> void:
	is_rotating = false
	rotation_tween = null


func _on_monster_turn_pressed() -> void:
	if not monster_ai:
		push_error("MonsterAIController not initialized")
		return

	turn_state.set_turn(TurnState.Turn.MONSTER)
	tactical_ui.set_disabled(true)
	# AI execution is async; UI re-enabled by _on_monster_ai_completed signal handler
	await monster_ai.execute_monster_turn()


func _on_all_survivors_complete() -> void:
	turn_state.set_turn(TurnState.Turn.MONSTER)
	tactical_ui.set_disabled(true)
	monster_ai.execute_monster_turn()


func _on_monster_ai_completed() -> void:
	player_turn_controller.reset_for_new_turn()
	tactical_ui.set_disabled(false)
	turn_state.set_turn(TurnState.Turn.PLAYER)


func _on_end_turn_pressed() -> void:
	turn_state.set_turn(TurnState.Turn.PLAYER)


func _on_turn_changed(_new_turn: TurnState.Turn) -> void:
	_update_ui()


func _update_ui() -> void:
	tactical_ui.update_for_turn(turn_state.current_turn)


func toggle_pause() -> void:
	is_paused = not is_paused
	pause_menu.visible = is_paused
	get_tree().paused = is_paused

	if is_paused:
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.return_to_menu()


func _is_ancestor_of(node: Node, potential_ancestor: Node) -> bool:
	var current := node
	while current:
		if current == potential_ancestor:
			return true
		current = current.get_parent()
	return false


func _initialize_monster_deck(monster_id: String) -> void:
	var deck_config: MonsterDeckConfig = load("res://data/decks/basic_monster_deck.tres")
	if not deck_config:
		push_error("Failed to load basic_monster_deck.tres")
		return

	monster_ai.initialize_monster_deck(monster_id, deck_config)

	# Update UI with initial deck count
	var deck: MonsterDeck = monster_ai.monster_decks[monster_id]
	monster_deck_ui.update_deck_count(monster_id, deck.get_draw_pile_count())
