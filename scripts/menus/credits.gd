extends Control
## Credits Screen Controller


func _ready() -> void:
	$VBoxContainer/BackButton.grab_focus()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
