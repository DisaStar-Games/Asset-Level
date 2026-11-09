extends RefCounted
## Shared grid-layout code. No class_name on purpose: use
##   const Builder = preload("res://scripts/showcase_builder.gd")

const FlyCamera := preload("res://scripts/fly_camera.gd")

const DEFAULTS := {
	"glb_folder": "res://assets/glb",
	"columns": 0,            # 0 = automatic (roughly square)
	"padding": 1.0,          # empty space between cells (m)
	"max_model_size": 0.0,   # scale down models larger than this (0 = never)
	"labels": true,
	"floor": true,
}


## Instances every GLB under `parent` in a grid. `scene_owner` (may be null) is set as owner
## so the result can be packed/saved. Returns the grid size (x = width, y = depth), or ZERO.
static func populate(parent: Node3D, scene_owner: Node, options: Dictionary = {}) -> Vector2:
	var o := DEFAULTS.duplicate()
	o.merge(options, true)

	var paths := find_glbs(o.glb_folder)
	if paths.is_empty():
		push_warning("Showcase: no .glb files found in %s" % o.glb_folder)
		return Vector2.ZERO

	var entries: Array[Dictionary] = []
	for path in paths:
		var res := load(path)
		if not res is PackedScene:
			push_warning("Showcase: could not load %s" % path)
			continue
		var model := (res as PackedScene).instantiate() as Node3D
		if model == null:
			continue
		var holder := Node3D.new()
		holder.name = path.get_file().get_basename()
		holder.add_child(model)
		parent.add_child(holder)
		var aabb := _measure(model, holder)
		if o.max_model_size > 0.0:
			var largest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
			if largest > o.max_model_size:
				model.scale *= o.max_model_size / largest
				aabb = _measure(model, holder)
		entries.append({"holder": holder, "aabb": aabb, "name": holder.name})

	if entries.is_empty():
		return Vector2.ZERO

	# Uniform cell = largest footprint + padding.
	var cell := 0.0
	for e in entries:
		var a: AABB = e.aabb
		cell = maxf(cell, maxf(a.size.x, a.size.z))
	cell = maxf(cell, 0.5) + o.padding

	var count := entries.size()
	var cols: int = o.columns if o.columns > 0 else ceili(sqrt(float(count)))
	var rows := ceili(float(count) / cols)
	var grid_w := cols * cell
	var grid_d := rows * cell

	for i in count:
		var e: Dictionary = entries[i]
		var holder: Node3D = e.holder
		var aabb: AABB = e.aabb
		var center := Vector3(
			(i % cols + 0.5) * cell - grid_w * 0.5,
			0.0,
			(i / cols + 0.5) * cell - grid_d * 0.5)
		# Centre on XZ, sit the bottom of the bounding box on y = 0.
		var model := holder.get_child(0) as Node3D
		model.position -= Vector3(
			aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5)
		holder.position = center
		if o.labels:
			var label := Label3D.new()
			label.name = "Label"
			label.text = e.name
			label.font_size = 64
			label.pixel_size = 0.005
			label.rotation_degrees.x = -90
			label.position = Vector3(0, 0.01, cell * 0.5 - o.padding * 0.25)
			holder.add_child(label)
		if scene_owner:
			holder.owner = scene_owner
			for c in holder.get_children():
				c.owner = scene_owner  # GLB internals stay inside the instance

	if o.floor:
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
		parent.add_child(floor_mesh)
		if scene_owner:
			floor_mesh.owner = scene_owner

	return Vector2(grid_w, grid_d)


## Flyable level: grid + floor + labels + sky + sun + free-look camera.
static func build_fly_level(options: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "ShowcaseLevel"

	var assets := Node3D.new()
	assets.name = "Assets"
	root.add_child(assets)
	assets.owner = root
	var grid := populate(assets, root, options)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.4, 0.62)
	sky_mat.sky_horizon_color = Color(0.65, 0.7, 0.75)
	sky_mat.ground_horizon_color = Color(0.65, 0.7, 0.75)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.position = Vector3(0, 10, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	root.add_child(sun)
	sun.owner = root

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.far = 500.0
	cam.set_script(FlyCamera)
	var extent := maxf(grid.x, grid.y)
	cam.transform = Transform3D(Basis.IDENTITY,
		Vector3(0, extent * 0.6 + 2.0, extent * 0.75 + 3.0)).looking_at(Vector3.ZERO)
	root.add_child(cam)
	cam.owner = root
	return root


## Plain scene for copy/paste: one Node3D per asset (named after the file), no camera,
## lights, floor or labels. Copy nodes from here into your own scenes.
static func build_copy_scene(options: Dictionary = {}) -> Node3D:
	var o := {"labels": false, "floor": false}
	o.merge(options, true)
	var root := Node3D.new()
	root.name = "AssetShowcase"
	populate(root, root, o)
	return root


## Packs `root` into a .tscn at `path` (creating folders) and frees `root`.
static func save_scene(root: Node, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		push_error("Showcase: pack failed (%s)" % error_string(err))
		return err
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Showcase: save failed for %s (%s)" % [path, error_string(err)])
	return err


static func find_glbs(dir_path: String) -> PackedStringArray:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Showcase: cannot open %s" % dir_path)
		return PackedStringArray()
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if not f.begins_with("."):
				result.append_array(find_glbs(dir_path.path_join(f)))
		else:
			# Exported builds list "x.glb.import"/"x.glb.remap" instead of the raw file.
			var n := f.trim_suffix(".import").trim_suffix(".remap")
			if n.get_extension().to_lower() == "glb":
				var p := dir_path.path_join(n)
				if not result.has(p):
					result.append(p)
		f = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return PackedStringArray(result)


## Bounding box of all visuals under `model`, in `holder` space.
static func _measure(model: Node3D, holder: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		var a := _relative_transform(vi, holder) * vi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	return box


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
