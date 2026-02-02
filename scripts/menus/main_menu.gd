extends Control
## Main Menu Controller
## Handles main menu button interactions and navigation.

@onready var continue_button: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	# Disable continue button if no save data exists
	continue_button.disabled = not GameManager.has_save_data

	# Focus the play button for keyboard/controller navigation
	$VBoxContainer/PlayButton.grab_focus()


func _on_play_pressed() -> void:
	GameManager.start_new_game()


func _on_continue_pressed() -> void:
	GameManager.continue_game()


func _on_options_pressed() -> void:
	# TODO: Open options menu
	get_tree().change_scene_to_file("res://scenes/menus/options_menu.tscn")


func _on_credits_pressed() -> void:
	# TODO: Open credits screen
	get_tree().change_scene_to_file("res://scenes/menus/credits.tscn")


func _on_quit_pressed() -> void:
	GameManager.quit_game()
