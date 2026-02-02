class_name ChoiceOption extends Resource
## Represents a single selectable choice with its destination and effects.

@export var label: String = ""
@export var description: String = ""
@export_file("*.tscn") var destination_scene: String = ""
@export var choice_id: String = ""
@export var is_enabled: bool = true
@export var metadata: Dictionary = {}
