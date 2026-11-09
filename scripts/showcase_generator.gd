@tool
extends Node3D
## Live version used by showcase.tscn: builds the grid when the scene runs.
## (For baked, saved scenes see the scripts in res://tools/.)

const Builder = preload("res://scripts/showcase_builder.gd")
const CONTAINER_NAME := "Generated"

@export_dir var glb_folder: String = "res://assets/glb"
## Columns in the grid. 0 = automatic (roughly square).
@export_range(0, 50) var columns: int = 0
## Empty space between cells (metres).
@export var padding: float = 1.0
## Models are scaled down to fit this size if larger (0 = never scale).
@export var max_model_size: float = 0.0
@export var show_labels: bool = true
@export var show_floor: bool = true
## Click to (re)build the grid in the editor.
@export_tool_button("Generate", "Reload") var _generate_btn = generate


func _ready() -> void:
	if not Engine.is_editor_hint():
		generate()


func generate() -> void:
	var old := get_node_or_null(CONTAINER_NAME)
	if old:
		remove_child(old)
		old.free()
	var container := Node3D.new()
	container.name = CONTAINER_NAME
	add_child(container)
	var scene_owner: Node = null
	if Engine.is_editor_hint():
		scene_owner = get_tree().edited_scene_root
		container.owner = scene_owner

	var grid := Builder.populate(container, scene_owner, {
		"glb_folder": glb_folder, "columns": columns, "padding": padding,
		"max_model_size": max_model_size, "labels": show_labels, "floor": show_floor,
	})

	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam and not Engine.is_editor_hint() and grid != Vector2.ZERO:
		var extent := maxf(grid.x, grid.y)
		cam.position = Vector3(0, extent * 0.6 + 2.0, extent * 0.75 + 3.0)
		cam.look_at(Vector3.ZERO)
