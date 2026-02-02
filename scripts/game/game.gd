extends Node2D
## Main Game Scene Controller
## Handles pause functionality and game state.

@onready var pause_menu: Control = $CanvasLayer/PauseMenu

var is_paused: bool = false


func _ready() -> void:
	pause_menu.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	is_paused = not is_paused
	pause_menu.visible = is_paused
	get_tree().paused = is_paused

	if is_paused:
		$CanvasLayer/PauseMenu/VBoxContainer/ResumeButton.grab_focus()


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.return_to_menu()
