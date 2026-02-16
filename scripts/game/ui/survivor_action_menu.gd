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
var _subviewport_container: SubViewportContainer = null
var _wound_label: Label = null


func _ready() -> void:
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())


func setup(camera: Camera3D, position_3d: Vector3, subviewport_container: SubViewportContainer = null) -> void:
	_camera = camera
	_target_3d_position = position_3d
	_subviewport_container = subviewport_container
	set_process(true)


func update_button_states(has_moved: bool, has_activated: bool) -> void:
	move_button.disabled = has_moved
	attack_button.disabled = has_activated
	# End Turn always enabled


func _process(_delta: float) -> void:
	var margin := Vector2(20.0, 20.0)
	var menu_size: Vector2 = $VBoxContainer.get_combined_minimum_size()
	var parent_ctrl := get_parent_control()
	var parent_offset := Vector2.ZERO
	if parent_ctrl:
		parent_offset = parent_ctrl.global_position
	position = get_viewport_rect().size - menu_size - margin - parent_offset


func _on_move_pressed() -> void:
	move_pressed.emit()


func _on_attack_pressed() -> void:
	attack_pressed.emit()


func _on_end_turn_pressed() -> void:
	end_turn_pressed.emit()


func show_wounds(survivor_data: SurvivorData) -> void:
	if not _wound_label:
		_wound_label = Label.new()
		_wound_label.name = "WoundPanel"
		$VBoxContainer.add_child(_wound_label)

	var lines: Array[String] = []

	if survivor_data.is_knocked_down:
		lines.append("[KNOCKED DOWN]")

	for part in ["head", "arms", "body", "waist", "legs"]:
		var wounds: int = survivor_data.body_part_wounds[part]
		var slot1: String = "●" if wounds >= 1 else "○"
		var slot2: String = "●" if wounds >= 2 else "○"
		var severe: String = "!" if wounds > 2 else ""
		lines.append("%s %s %s%s" % [part.to_upper().lpad(5), slot1, slot2, severe])

	_wound_label.text = "\n".join(lines)
