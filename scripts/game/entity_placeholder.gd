class_name EntityPlaceholder
extends Node3D
## Visual placeholder for a game entity (monster or survivor).

enum EntityType { MONSTER, SURVIVOR }

@export var entity_type: EntityType = EntityType.SURVIVOR
@export var entity_color: Color = Color.WHITE
@export var entity_label: String = ""

## Emitted by external systems (e.g., TacticalGameScreen) when entity is clicked.
signal clicked()

var entity_id: String = ""
var survivor_data: SurvivorData = null
var is_greyed_out: bool = false
var _original_color: Color = Color.WHITE

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
		var material := body.get_surface_override_material(0)
		if not material or not material is StandardMaterial3D:
			material = StandardMaterial3D.new()
			body.set_surface_override_material(0, material)
		if material is StandardMaterial3D:
			material.albedo_color = entity_color
			_original_color = entity_color  # Store the actual entity color
	if label_3d:
		label_3d.text = entity_label


func set_greyed_out(greyed: bool) -> void:
	is_greyed_out = greyed
	if body and body.get_surface_override_material(0):
		var material := body.get_surface_override_material(0) as StandardMaterial3D
		if material:
			if greyed:
				_original_color = material.albedo_color
				# Desaturate and darken
				var grey_value := (_original_color.r + _original_color.g + _original_color.b) / 3.0
				material.albedo_color = Color(grey_value * 0.5, grey_value * 0.5, grey_value * 0.5)
			else:
				material.albedo_color = _original_color


func restore_color() -> void:
	set_greyed_out(false)
