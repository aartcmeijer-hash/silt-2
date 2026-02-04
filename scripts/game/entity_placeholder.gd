class_name EntityPlaceholder
extends Node3D
## Visual placeholder for a game entity (monster or survivor).

enum EntityType { MONSTER, SURVIVOR }

@export var entity_type: EntityType = EntityType.SURVIVOR
@export var entity_color: Color = Color.WHITE
@export var entity_label: String = ""

var entity_id: String = ""

@onready var body: MeshInstance3D = $Body
@onready var label_3d: Label3D = $Label3D


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
	if body:
		var material := StandardMaterial3D.new()
		material.albedo_color = entity_color
		body.set_surface_override_material(0, material)
	if label_3d:
		label_3d.text = entity_label
