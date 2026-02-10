class_name SurvivorActionMenu
extends Control
## Floating action menu for selected survivor.

signal move_pressed()
signal attack_pressed()
signal end_turn_pressed()

@onready var move_button: Button = $VBoxContainer/MoveButton
@onready var attack_button: Button = $VBoxContainer/AttackButton
@onready var end_turn_button: Button = $VBoxContainer/EndTurnButton

var _target_3d_position: Vector3 = Vector3.ZERO
var _camera: Camera3D = null


func _ready() -> void:
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree() and _camera != null)


func setup(camera: Camera3D, position_3d: Vector3) -> void:
	_camera = camera
	_target_3d_position = position_3d
	set_process(_camera != null)


func update_button_states(has_moved: bool, has_activated: bool) -> void:
	move_button.disabled = has_moved
	attack_button.disabled = has_activated
	# End Turn always enabled


func _process(_delta: float) -> void:
	if _camera and is_inside_tree():
		var screen_pos := _camera.unproject_position(_target_3d_position)
		position = screen_pos + Vector2(20, -50)  # Offset from entity


func _on_move_pressed() -> void:
	move_pressed.emit()


func _on_attack_pressed() -> void:
	attack_pressed.emit()


func _on_end_turn_pressed() -> void:
	end_turn_pressed.emit()
