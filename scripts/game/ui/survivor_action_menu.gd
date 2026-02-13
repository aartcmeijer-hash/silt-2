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
	set_process(is_visible_in_tree() and _camera != null)


func setup(camera: Camera3D, position_3d: Vector3, subviewport_container: SubViewportContainer = null) -> void:
	_camera = camera
	_target_3d_position = position_3d
	_subviewport_container = subviewport_container
	set_process(_camera != null)


func update_button_states(has_moved: bool, has_activated: bool) -> void:
	move_button.disabled = has_moved
	attack_button.disabled = has_activated
	# End Turn always enabled


func _process(_delta: float) -> void:
	if _camera and is_inside_tree() and _subviewport_container:
		# camera.unproject_position returns SubViewport-local coordinates
		var subviewport_pos := _camera.unproject_position(_target_3d_position)
		# Scale from SubViewport size to the container's actual rendered size
		var subviewport_size := Vector2(_camera.get_viewport().size)
		var container_rect := _subviewport_container.get_global_rect()
		var scale := container_rect.size / subviewport_size
		var screen_pos := container_rect.position + subviewport_pos * scale
		# Convert from global screen position to local position within parent
		var parent_ctrl := get_parent_control()
		if parent_ctrl:
			position = screen_pos - parent_ctrl.global_position + Vector2(20, -50)
	elif _camera and is_inside_tree():
		# Fallback: no container reference, use SubViewport coords directly
		var screen_pos := _camera.unproject_position(_target_3d_position)
		position = screen_pos + Vector2(20, -50)


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
