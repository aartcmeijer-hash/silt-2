class_name EntityPlaceholder
extends Node2D
## Visual placeholder for a game entity (monster or survivor).

enum EntityType { MONSTER, SURVIVOR }

@export var entity_type: EntityType = EntityType.SURVIVOR
@export var entity_color: Color = Color.WHITE
@export var entity_label: String = ""

var entity_id: String = ""

@onready var color_rect: ColorRect = $ColorRect
@onready var label: Label = $Label


func _ready() -> void:
	_update_visuals()


func setup(id: String, type: EntityType, display_label: String, color: Color) -> void:
	entity_id = id
	entity_type = type
	entity_label = display_label
	entity_color = color
	if is_inside_tree():
		_update_visuals()


func _update_visuals() -> void:
	if color_rect:
		color_rect.color = entity_color
	if label:
		label.text = entity_label
