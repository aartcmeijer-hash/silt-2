extends Node
## GameManager Autoload
## Handles global game state, scene transitions, and save data.

signal game_started
signal game_resumed
signal game_paused

enum GameState { MENU, PLAYING, PAUSED }

var current_state: GameState = GameState.MENU
var has_save_data: bool = false

const SAVE_PATH := "user://savegame.save"


func _ready() -> void:
	_check_save_data()


func _check_save_data() -> void:
	has_save_data = FileAccess.file_exists(SAVE_PATH)


func start_new_game() -> void:
	current_state = GameState.PLAYING
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


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
