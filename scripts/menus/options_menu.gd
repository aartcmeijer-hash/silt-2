extends Control
## Options Menu Controller
## Handles audio and display settings.

@onready var master_slider: HSlider = $VBoxContainer/MasterVolume/MasterSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicVolume/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXVolume/SFXSlider
@onready var fullscreen_check: CheckBox = $VBoxContainer/Fullscreen/FullscreenCheck


func _ready() -> void:
	# Load current settings
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	$VBoxContainer/BackButton.grab_focus()


func _on_master_volume_changed(value: float) -> void:
	# TODO: Implement audio bus volume control
	var db := linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _on_music_volume_changed(value: float) -> void:
	# TODO: Implement music bus volume control
	pass


func _on_sfx_volume_changed(value: float) -> void:
	# TODO: Implement SFX bus volume control
	pass


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
