extends Control
## Reusable choice screen that displays flavor text and navigable choices.
## Content is loaded from ChoiceScreenData resources.

signal choice_selected(choice_id: String, choice_option: ChoiceOption)
signal screen_presented(screen_id: String)

@export var choice_data: ChoiceScreenData

@onready var flavor_text_label: RichTextLabel = $CenterContainer/VBoxContainer/FlavorText
@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var choice_container: VBoxContainer = $CenterContainer/VBoxContainer/ChoiceContainer
@onready var background: ColorRect = $ColorRect

const CHOICE_BUTTON_SCENE := preload("res://scenes/ui/choice_button.tscn")


func _ready() -> void:
	if choice_data:
		setup_screen(choice_data)


func setup_screen(data: ChoiceScreenData) -> void:
	if not data:
		push_error("ChoiceScreen: choice_data is null")
		return

	if data.choices.is_empty():
		push_error("ChoiceScreen '%s': No choices defined" % data.screen_id)
		return

	background.color = data.background_color

	if data.title.is_empty():
		title_label.hide()
	else:
		title_label.text = data.title
		title_label.show()

	flavor_text_label.text = data.flavor_text

	for child in choice_container.get_children():
		child.queue_free()

	var first_enabled_button: Button = null
	for choice in data.choices:
		var button: Button = CHOICE_BUTTON_SCENE.instantiate()
		choice_container.add_child(button)

		button.text = choice.label
		button.disabled = not choice.is_enabled
		button.tooltip_text = choice.description

		button.pressed.connect(_on_choice_pressed.bind(choice))

		if choice.is_enabled and first_enabled_button == null:
			first_enabled_button = button

	if first_enabled_button:
		first_enabled_button.grab_focus()

	screen_presented.emit(data.screen_id)


func _on_choice_pressed(choice: ChoiceOption) -> void:
	choice_selected.emit(choice.choice_id, choice)

	if not choice.choice_id.is_empty():
		GameManager.record_choice(choice.choice_id, choice_data.screen_id, choice.metadata)

	if not choice.destination_scene.is_empty():
		get_tree().change_scene_to_file(choice.destination_scene)
	else:
		push_warning("Choice '%s' has no destination scene" % choice.label)
