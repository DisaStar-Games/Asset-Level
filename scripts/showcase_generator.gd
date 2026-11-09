@tool
extends Node3D
## Builds an asset showcase: every .glb in `glb_folder` is placed in a grid.

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

const CONTAINER_NAME := "Generated"


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
	if Engine.is_editor_hint():
		container.owner = get_tree().edited_scene_root

	var paths := _find_glbs(glb_folder)
	if paths.is_empty():
		push_warning("Showcase: no .glb files found in %s" % glb_folder)
		return

	# Instance everything and measure it.
	var entries: Array[Dictionary] = []
	for path in paths:
		var res := load(path)
		if not res is PackedScene:
			push_warning("Showcase: could not load %s" % path)
			continue
		var model: Node3D = (res as PackedScene).instantiate() as Node3D
		if model == null:
			continue
		var holder := Node3D.new()  # holder keeps model centred; cell positions the holder
		holder.name = path.get_file().get_basename()
		holder.add_child(model)
		container.add_child(holder)
		var aabb := _measure(model, holder)
		if max_model_size > 0.0:
			var largest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
			if largest > max_model_size:
				var s := max_model_size / largest
				model.scale *= s
				aabb = _measure(model, holder)
		entries.append({"holder": holder, "aabb": aabb, "name": holder.name})

	if entries.is_empty():
		return

	# Uniform cell size = largest footprint + padding.
	var cell := 0.0
	for e in entries:
		var a: AABB = e.aabb
		cell = maxf(cell, maxf(a.size.x, a.size.z))
	cell = maxf(cell, 0.5) + padding

	var count := entries.size()
	var cols := columns if columns > 0 else ceili(sqrt(float(count)))
	var rows := ceili(float(count) / cols)
	var grid_w := cols * cell
	var grid_d := rows * cell

	for i in count:
		var e: Dictionary = entries[i]
		var holder: Node3D = e.holder
		var aabb: AABB = e.aabb
		var cx := i % cols
		var cz := i / cols
		var center := Vector3(
			(cx + 0.5) * cell - grid_w * 0.5,
			0.0,
			(cz + 0.5) * cell - grid_d * 0.5)
		# Centre on XZ, sit bottom of bounding box on y = 0.
		var model := holder.get_child(0) as Node3D
		model.position -= Vector3(
			aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5)
		holder.position = center
		if show_labels:
			var label := Label3D.new()
			label.name = "Label"
			label.text = e.name
			label.font_size = 64
			label.pixel_size = 0.005
			label.rotation_degrees.x = -90
			label.position = Vector3(0, 0.01, cell * 0.5 - padding * 0.25)
			label.no_depth_test = false
			holder.add_child(label)
		_set_owner_shallow(holder)

	if show_floor:
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.name = "Floor"
		var plane := PlaneMesh.new()
		plane.size = Vector2(grid_w + cell, grid_d + cell)
		floor_mesh.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.23, 0.26)
		mat.roughness = 0.9
		floor_mesh.material_override = mat
		floor_mesh.position.y = -0.001
		container.add_child(floor_mesh)
		if Engine.is_editor_hint():
			floor_mesh.owner = get_tree().edited_scene_root

	_frame_camera(grid_w, grid_d)


func _find_glbs(dir_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Showcase: cannot open %s" % dir_path)
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if not f.begins_with("."):
				result.append_array(_find_glbs(dir_path.path_join(f)))
		else:
			# Exported builds list "x.glb.import"/"x.glb.remap" instead of the raw file.
			var name := f.trim_suffix(".import").trim_suffix(".remap")
			if name.get_extension().to_lower() == "glb":
				var p := dir_path.path_join(name)
				if not result.has(p):
					result.append(p)
		f = dir.get_next()
	dir.list_dir_end()
	var sorted := Array(result)
	sorted.sort()
	return PackedStringArray(sorted)


## Bounding box of all meshes under `model`, expressed in `model`'s parent (holder) space.
func _measure(model: Node3D, holder: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "VisualInstance3D", true, false):
		var vi := mi as VisualInstance3D
		var local_xf := _relative_transform(vi, holder)
		var a := local_xf * vi.get_aabb()
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	if first:
		box = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	return box


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _set_owner_shallow(holder: Node3D) -> void:
	if not Engine.is_editor_hint():
		return
	var root := get_tree().edited_scene_root
	holder.owner = root
	for c in holder.get_children():
		c.owner = root  # instanced GLB root + label; GLB internals stay inside the instance


func _frame_camera(grid_w: float, grid_d: float) -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null or Engine.is_editor_hint():
		return
	var extent := maxf(grid_w, grid_d)
	cam.position = Vector3(0, extent * 0.6 + 2.0, extent * 0.75 + 3.0)
	cam.look_at(Vector3.ZERO)
