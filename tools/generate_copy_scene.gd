@tool
extends EditorScript
## In the Godot editor: open this file, then File > Run (Ctrl+Shift+X).
## Bakes every GLB in res://assets/glb into a plain scene to copy/paste from:
## one Node3D per asset, no camera/lights/floor/labels.
## Output: res://levels/generated/showcase_copy.tscn (overwritten on every run).

const Builder = preload("res://scripts/showcase_builder.gd")
const OUT := "res://levels/generated/showcase_copy.tscn"


func _run() -> void:
	if Builder.save_scene(Builder.build_copy_scene(), OUT) == OK:
		print("Saved ", OUT)
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(OUT)
