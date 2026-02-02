class_name ChoiceScreenData extends Resource
## Defines all content for a choice screen including text and options.

@export_multiline var flavor_text: String = ""
@export var title: String = ""
@export var choices: Array[ChoiceOption] = []
@export var background_color: Color = Color(0.118, 0.129, 0.18, 1)
@export var screen_id: String = ""
