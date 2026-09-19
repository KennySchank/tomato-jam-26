@tool
extends ColorRect

@export_category("Cloud Appearance")
@export var shadow_color := Color(0.12, 0.19, 0.16, 1.0):
	set(value):
		shadow_color = value
		_update_shader()

@export_range(0.0, 1.0, 0.01) var shadow_strength := 0.38:
	set(value):
		shadow_strength = value
		_update_shader()

@export_category("Cloud Movement")
@export_range(-0.1, 0.1, 0.001) var horizontal_speed := 0.024:
	set(value):
		horizontal_speed = value
		_update_shader()

@export_range(-0.1, 0.1, 0.001) var vertical_speed := 0.001:
	set(value):
		vertical_speed = value
		_update_shader()

@export_category("Cloud Shape")
@export var cloud_scale := Vector2(3.0, 1.8):
	set(value):
		cloud_scale = value
		_update_shader()

@export_range(0.0, 1.0, 0.01) var edge_start := 0.48:
	set(value):
		edge_start = value
		_update_shader()

@export_range(0.0, 1.0, 0.01) var edge_end := 0.60:
	set(value):
		edge_end = value
		_update_shader()


func _ready() -> void:
	_update_shader()


func _update_shader() -> void:
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		shader_material.set_shader_parameter("shadow_color", shadow_color)
		shader_material.set_shader_parameter("shadow_strength", shadow_strength)
		shader_material.set_shader_parameter("drift", Vector2(horizontal_speed, vertical_speed))
		shader_material.set_shader_parameter("cloud_scale", cloud_scale)
		shader_material.set_shader_parameter("edge_start", edge_start)
		shader_material.set_shader_parameter("edge_end", edge_end)
