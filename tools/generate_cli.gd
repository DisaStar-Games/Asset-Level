extends SceneTree
## Command line: godot --headless --path . --script res://tools/generate_cli.gd -- [fly] [copy]
## No argument = both.

const Builder = preload("res://scripts/showcase_builder.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var both := args.is_empty()
	if both or "fly" in args:
		Builder.save_scene(Builder.build_fly_level(), "res://levels/generated/showcase_fly.tscn")
		print("Saved showcase_fly.tscn")
	if both or "copy" in args:
		Builder.save_scene(Builder.build_copy_scene(), "res://levels/generated/showcase_copy.tscn")
		print("Saved showcase_copy.tscn")
	quit()
