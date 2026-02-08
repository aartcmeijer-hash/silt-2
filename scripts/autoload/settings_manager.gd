extends Node
## SettingsManager Autoload
## Handles game settings persistence and change notifications.

signal gridlines_changed(enabled: bool)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GRAPHICS := "graphics"
const KEY_GRIDLINES := "show_gridlines"

var _config: ConfigFile = ConfigFile.new()
var _gridlines_enabled: bool = true  # Default to enabled


func _ready() -> void:
	_load_settings()


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		# Settings file doesn't exist or is corrupted, use defaults
		_gridlines_enabled = true
		_save_settings()
	else:
		_gridlines_enabled = _config.get_value(SECTION_GRAPHICS, KEY_GRIDLINES, true)


func _save_settings() -> void:
	_config.set_value(SECTION_GRAPHICS, KEY_GRIDLINES, _gridlines_enabled)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save settings: " + str(err))


func get_gridlines_enabled() -> bool:
	return _gridlines_enabled


func set_gridlines_enabled(enabled: bool) -> void:
	if _gridlines_enabled == enabled:
		return

	_gridlines_enabled = enabled
	_save_settings()
	gridlines_changed.emit(enabled)
