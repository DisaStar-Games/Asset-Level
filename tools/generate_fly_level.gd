@tool
extends EditorScript
## In the Godot editor: open this file, then File > Run (Ctrl+Shift+X).
## Bakes every GLB in res://assets/glb into a flyable level and opens it.
## Output: res://levels/generated/showcase_fly.tscn (overwritten on every run).

const Builder = preload("res://scripts/showcase_builder.gd")
const OUT := "res://levels/generated/showcase_fly.tscn"


func _run() -> void:
	if Builder.save_scene(Builder.build_fly_level(), OUT) == OK:
		print("Saved ", OUT)
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(OUT)
