extends Node
## GameManager Autoload
## Handles global game state, scene transitions, and save data.

signal game_started
signal game_resumed
signal game_paused
signal choice_made(choice_id: String, screen_id: String, metadata: Dictionary)

enum GameState { MENU, PLAYING, PAUSED }

var current_state: GameState = GameState.MENU
var has_save_data: bool = false
var choice_history: Array[Dictionary] = []

const SAVE_PATH := "user://savegame.save"


func _ready() -> void:
	_check_save_data()


func _check_save_data() -> void:
	has_save_data = FileAccess.file_exists(SAVE_PATH)


func start_new_game() -> void:
	current_state = GameState.PLAYING
	choice_history.clear()
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/game/intro_choice.tscn")


func continue_game() -> void:
	if not has_save_data:
		push_warning("No save data found")
		return

	current_state = GameState.PLAYING
	game_resumed.emit()
	# TODO: Load save data
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func return_to_menu() -> void:
	current_state = GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


func quit_game() -> void:
	get_tree().quit()


func save_game() -> void:
	# TODO: Implement save system
	has_save_data = true
	pass


func load_game() -> Dictionary:
	# TODO: Implement load system
	return {}


func record_choice(choice_id: String, screen_id: String, metadata: Dictionary = {}) -> void:
	var choice_record := {
		"choice_id": choice_id,
		"screen_id": screen_id,
		"metadata": metadata,
		"timestamp": Time.get_ticks_msec()
	}
	choice_history.append(choice_record)
	choice_made.emit(choice_id, screen_id, metadata)


func get_choice_history() -> Array[Dictionary]:
	return choice_history.duplicate()


func has_made_choice(choice_id: String) -> bool:
	return choice_history.any(func(record): return record.choice_id == choice_id)


func get_choice_metadata(choice_id: String) -> Dictionary:
	for record in choice_history:
		if record.choice_id == choice_id:
			return record.metadata
	return {}
