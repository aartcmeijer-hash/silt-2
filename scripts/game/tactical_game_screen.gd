extends Node3D
## Main tactical game screen controller.
## Manages the isometric grid, entities, and turn-based gameplay.

const ENTITY_PLACEHOLDER_SCENE := preload("res://scenes/game/entity_placeholder.tscn")

@onready var camera: Camera3D = $Camera3D
@onready var grid: IsometricGrid = $IsometricGrid
@onready var entity_container: Node3D = $IsometricGrid/EntityContainer
@onready var tactical_ui: Control = $CanvasLayer/TacticalUI
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var resume_button: Button = $CanvasLayer/PauseMenu/VBoxContainer/ResumeButton

var turn_state: TurnState
var entities: Dictionary = {}
var is_paused: bool = false

# Camera rotation state
var current_angle: float = 0.0
var is_rotating: bool = false
var rotation_tween: Tween = null


func _ready() -> void:
	turn_state = TurnState.new()
	turn_state.turn_changed.connect(_on_turn_changed)

	tactical_ui.monster_turn_pressed.connect(_on_monster_turn_pressed)
	tactical_ui.end_turn_pressed.connect(_on_end_turn_pressed)

	_setup_camera()
	pause_menu.hide()
	_spawn_initial_entities()
	_update_ui()


func _input(event: InputEvent) -> void:
	# Block all input during camera rotation
	if is_rotating:
		return

	if event.is_action_pressed("rotate_left"):
		rotate_camera(-90)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_right"):
		rotate_camera(90)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _spawn_initial_entities() -> void:
	var monster_pos := grid.get_grid_center()
	_spawn_entity("monster_1", monster_pos, EntityPlaceholder.EntityType.MONSTER, "M", Color(0.9, 0.2, 0.2))

	var survivor_positions := grid.get_bottom_row_positions(4)
	for i in range(survivor_positions.size()):
		var pos := survivor_positions[i]
		var id := "survivor_%d" % (i + 1)
		_spawn_entity(id, pos, EntityPlaceholder.EntityType.SURVIVOR, "S%d" % (i + 1), Color(0.2, 0.6, 1.0))


func _spawn_entity(id: String, grid_pos: Vector2i, type: EntityPlaceholder.EntityType, label: String, color: Color) -> void:
	var entity: Node3D = ENTITY_PLACEHOLDER_SCENE.instantiate()
	entity_container.add_child(entity)
	entity.setup(id, type, label, color)
	entity.position = grid.grid_to_world(grid_pos.x, grid_pos.y)
	entities[id] = entity


func _setup_camera() -> void:
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 400.0
		camera.far = 1500.0

		# Position camera for 30° isometric view
		var grid_center := Vector3.ZERO
		var camera_distance := 1000.0
		var camera_angle := 30.0  # degrees from horizontal
		var camera_height := camera_distance * tan(deg_to_rad(camera_angle))  # ~577

		camera.position = Vector3(0, camera_height, camera_distance)
		camera.look_at(grid_center, Vector3.UP)


func rotate_camera(delta_angle: float) -> void:
	is_rotating = true

	var target_angle := fmod(current_angle + delta_angle + 360, 360)

	# Kill existing tween if rotating again
	if rotation_tween:
		rotation_tween.kill()

	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_IN_OUT)
	rotation_tween.set_trans(Tween.TRANS_CUBIC)
	rotation_tween.tween_property(camera, "rotation_degrees:y", target_angle, 0.25)
	rotation_tween.finished.connect(_on_rotation_complete)

	current_angle = target_angle


func _on_rotation_complete() -> void:
	is_rotating = false
	rotation_tween = null


func _on_monster_turn_pressed() -> void:
	turn_state.set_turn(TurnState.Turn.MONSTER)


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
