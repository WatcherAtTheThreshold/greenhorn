extends Node3D
## Builds the whole test plot in code.
##
## Deliberately not authored as a .tscn. Everything here is a tuning constant
## or a loop, so changing the plot means editing a number rather than dragging
## nodes, and there is nothing to merge-conflict.
##
## The plot is laid out in bands running away from the spawn point:
##   z ~   0   the import plinths (whatever you dropped in assets/blender/)
##   z ~ -14   ramps at 15 / 30 / 45 / 60 degrees
##   z ~ -28   stairs at three riser heights
##   z ~ -42   the shelter: walls, a doorway, and what they do to the camera
##   x ~ +15   scale references
##   x ~ -15   material comparison

const IMPORT_DIR := "res://assets/blender/"
const PLAYER := preload("res://scenes/player.tscn")

const GROUND     := 140.0
const SPAWN      := Vector3(0.0, 1.2, 9.0)
## Off the path and clear of the plinth row, so they have to walk to reach you
## and you get to watch them come.
const BUG_SPAWN  := Vector3(9.0, 0.4, 4.0)
## More than one, because everything about the fight has so far been tuned
## against a single target. A swing that sweeps through two of them is the
## first honest test of the hit window, the cancel window and the knockback.
const BUG_COUNT  := 4
## Ring radius at spawn. Far enough apart that they do not start inside each
## other; close enough that they arrive as a group rather than a queue.
const BUG_SPREAD := 2.4
const RAMP_Z     := -14.0
const STAIR_Z    := -28.0
const PLINTH_Z   := 0.0

# --- shelter ----------------------------------------------------------------
## The structure band, and its job is the camera. A spring arm in this project
## has never met a doorway or an enclosure, and that is the biggest untested
## thing in the controller.
##
## Deliberately 6 m across. The camera sits CAM_DISTANCE (2.25 m) behind you,
## so standing in the middle of a room of side S the arm only extends fully if
## S is over about 5 m. Six is the smallest square where third person still
## has room to be third person — which makes this the honest test rather than
## a flattering one.
const SHELTER_Z    := -42.0
const SHELTER_HALF := 3.0
const MODULE       := 2.0        ## the grid the wall pieces are built to
const WALL_FILE    := "wall.blend"
const BROKEN_FILE  := "wall-broken.blend"
const DOOR_FILE    := "door.blend"

# --- scenery ----------------------------------------------------------------
## Scattered as MultiMeshes: any number of instances, one draw call each.
## Godot does not batch MeshInstance3Ds, so placing 34 trees the obvious way
## costs 34 draw calls before a single bug is on screen — and trees are the
## thing there will eventually be hundreds of.
const TREE_FILE  := "tree1.blend"
const ROCK_FILE  := "rock1.blend"
const TREE_COUNT := 34
const ROCK_COUNT := 22
## A tree's collision is a trunk-sized column, not its bounds. The canopy is
## the widest part of the mesh and you are meant to walk under it.
const TRUNK_RADIUS := 0.25

var _sun: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_path()
	_build_ramps()
	_build_stairs()
	_build_scale_refs()
	_build_material_row()
	_build_shelter()
	_build_scenery()
	_mount_imports()

	var p := PLAYER.instantiate()
	p.position = SPAWN
	add_child(p)

	# Placed on a ring rather than scattered, so every restart puts them in the
	# same spots and two attempts are actually comparable — same reason the
	# scenery is seeded.
	for i in BUG_COUNT:
		var a := TAU * float(i) / float(BUG_COUNT)
		var b := Bug.new()
		b.name = "Bug%d" % i
		b.position = BUG_SPAWN + Vector3(cos(a), 0.0, sin(a)) * BUG_SPREAD
		# Handing each one the player directly beats a group lookup: the world
		# already holds both, and there is nothing to go stale.
		b.target = p as Node3D
		add_child(b)


## R rebuilds the whole plot from scratch: player back at spawn, bug alive and
## wearing its shell again, debris gone.
##
## It lives here rather than on the player because none of that is the
## player's business, and because a scene reload is exactly what you want
## between attempts once things can break and stay broken. The scenery is
## seeded, so the world comes back identical rather than reshuffled.
func _unhandled_input(e: InputEvent) -> void:
	if not e.is_action_pressed("respawn"):
		return
	# A hitstop caught mid-flight is awaiting a timer inside a player that is
	# about to be freed, so the line restoring normal speed would never run
	# and the fresh scene would come up in slow motion.
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# --- environment ------------------------------------------------------------
# The whole cheerful look lives here rather than in the models. A sunny scene
# is carried by its lighting, which is exactly why it is cheaper to make than
# a dungeon, where every surface has to hold up close under a torch.
func _build_environment() -> void:
	var env := Environment.new()

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Palette.SKY_TOP
	sky_mat.sky_horizon_color = Palette.SKY_HORIZON
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Palette.GND_HORIZON
	sky_mat.ground_bottom_color = Palette.GND_BOTTOM
	sky_mat.ground_curve = 0.04
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.4

	# Contact shadow in the crevices. This is what makes untextured
	# primitives sit in the world instead of floating on it.
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6

	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.05

	# Distance haze. Cheap, and it turns a flat plane into somewhere with air.
	env.fog_enabled = true
	env.fog_light_color = Palette.FOG
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.35

	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Warm sun, cool sky fill. The warm/cool split does more for "appealing"
	# than any amount of texture detail.
	_sun = DirectionalLight3D.new()
	_sun.light_color = Palette.SUNLIGHT
	_sun.light_energy = 1.3
	_sun.shadow_enabled = true
	_sun.light_angular_distance = 1.2
	_sun.shadow_blur = 1.1
	_sun.directional_shadow_max_distance = 90.0
	_sun.rotation_degrees = Vector3(-46.0, 132.0, 0.0)
	add_child(_sun)


# --- primitive helpers ------------------------------------------------------
func _box(size: Vector3, xf: Transform3D, mat: Material, collide := true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.transform = xf
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
	add_child(sb)
	return sb


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, collide := true) -> Node3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	sb.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		sb.add_child(cs)
	add_child(sb)
	return sb


func _sphere(radius: float, pos: Vector3, mat: Material, squash := 1.0, collide := false) -> Node3D:
	# The squash goes on the MESH, never on the body. Jolt refuses a
	# non-uniform scale on a shape and quietly substitutes a uniform one, so
	# a scaled StaticBody3D gives you a collider that does not match what you
	# can see. Decorative spheres skip the body entirely.
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = mat
	mi.scale = Vector3(1.0, squash, 1.0)

	if not collide:
		mi.position = pos
		add_child(mi)
		return mi

	var sb := StaticBody3D.new()
	sb.position = pos
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# inset horizontally so a rounded rock does not feel square underfoot
	bs.size = Vector3(radius * 1.7, radius * 2.0 * squash, radius * 1.7)
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	return sb


func _label(text: String, pos: Vector3, size := 44, col := Palette.ACCENT) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.position = pos
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0.06, 0.09, 0.07, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	add_child(l)
	return l


# --- the plot ---------------------------------------------------------------
func _build_ground() -> void:
	_box(Vector3(GROUND, 1.0, GROUND), Transform3D(Basis(), Vector3(0.0, -0.5, 0.0)),
		Palette.solid(Palette.GRASS, 0.95))


func _build_path() -> void:
	# A worn strip down the middle, purely so the eye has a line to follow.
	# An empty plane reads as a void; a path reads as a place.
	var mat := Palette.solid(Palette.GRASS_WORN, 0.95)
	_box(Vector3(3.4, 0.06, 46.0), Transform3D(Basis(), Vector3(0.0, 0.02, -12.0)), mat, false)


func _build_ramps() -> void:
	var mat := Palette.solid(Palette.STONE, 0.9)
	var angles := [15.0, 30.0, 45.0, 60.0]
	var length := 6.5
	var x := -13.5
	for deg: float in angles:
		var a := deg_to_rad(deg)
		# Rotating +a about X lifts the -Z end, so the ramp climbs away from
		# the player. Centring at half the rise buries the near lip slightly,
		# which gives a clean step-on instead of a kerb to trip over.
		var pos := Vector3(x, sin(a) * length * 0.5, RAMP_Z - cos(a) * length * 0.5)
		_box(Vector3(3.0, 0.35, length), Transform3D(Basis(Vector3.RIGHT, a), pos), mat)
		_label("%d deg" % int(deg), Vector3(x, 1.1, RAMP_Z + 1.4))
		x += 9.0
	_label("floor_max_angle is 50 deg, so the 60 should refuse you",
		Vector3(0.0, 2.4, RAMP_Z + 3.6), 34, Palette.STONE_LIGHT)


func _build_stairs() -> void:
	var mat := Palette.solid(Palette.STONE_LIGHT, 0.9)
	var risers := [0.15, 0.25, 0.40]
	var x := -9.0
	for riser: float in risers:
		for i in 6:
			var h := riser * float(i + 1)
			var pos := Vector3(x, h * 0.5, STAIR_Z - 0.42 * (float(i) + 0.5))
			_box(Vector3(3.0, h, 0.42), Transform3D(Basis(), pos), mat)
		_label("%d cm risers" % int(riser * 100.0), Vector3(x, 1.1, STAIR_Z + 1.4))
		x += 9.0
	_label("STEP_HEIGHT in player.gd is 28 cm, so the 40 needs a jump.",
		Vector3(0.0, 2.4, STAIR_Z + 3.6), 34, Palette.STONE_LIGHT)


func _build_scale_refs() -> void:
	var x := 15.0
	var wood := Palette.solid(Palette.WOOD, 0.85)
	var stone := Palette.solid(Palette.STONE, 0.9)

	_box(Vector3.ONE, Transform3D(Basis(), Vector3(x, 0.5, 2.0)), stone)
	_label("1 m cube", Vector3(x, 1.5, 2.0), 38)

	_box(Vector3(0.35, 1.8, 0.35), Transform3D(Basis(), Vector3(x, 0.9, -1.0)), wood)
	_label("1.8 m: build your character this tall", Vector3(x, 2.3, -1.0), 34)

	_box(Vector3(0.3, 2.4, 0.3), Transform3D(Basis(), Vector3(x - 0.85, 1.2, -5.0)), wood)
	_box(Vector3(0.3, 2.4, 0.3), Transform3D(Basis(), Vector3(x + 0.85, 1.2, -5.0)), wood)
	_box(Vector3(2.0, 0.3, 0.3), Transform3D(Basis(), Vector3(x, 2.55, -5.0)), wood)
	_label("2 m doorway", Vector3(x, 3.1, -5.0), 38)


func _build_material_row() -> void:
	# The same shape under a sweep of roughness, plus one metal and one
	# emissive. Compare whatever comes out of Blender against these to see
	# what actually survived the trip.
	var x := -15.0
	var z := 1.0
	for i in 5:
		var rough := 0.05 + 0.235 * float(i)
		_sphere(0.55, Vector3(x, 0.55, z - 1.6 * float(i)), Palette.solid(Palette.ACCENT, rough))
	_label("roughness 0.05 to 0.99", Vector3(x, 1.5, z + 1.4), 34)

	var metal := Palette.solid(Color("cfd3d6"), 0.28, 1.0)
	_sphere(0.55, Vector3(x - 2.4, 0.55, z - 3.2), metal)
	_label("metal", Vector3(x - 2.4, 1.4, z - 3.2), 32)

	var glow := Palette.solid(Palette.ACCENT, 0.6)
	glow.emission_enabled = true
	glow.emission = Palette.ACCENT
	glow.emission_energy_multiplier = 2.2
	_sphere(0.55, Vector3(x - 2.4, 0.55, z - 5.4), glow)
	_label("emissive", Vector3(x - 2.4, 1.4, z - 5.4), 32)


func _build_scenery() -> void:
	# None of this is a test. It is here so the plot reads as somewhere,
	# rather than as a grey lab with objects in it.
	# The hills stay primitives — they are terrain, not props, and a squashed
	# sphere at 60 m is doing a job no modelled asset would do better.
	var hill := Palette.solid(Palette.HILL, 0.98)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260824

	# a ring of low hills, so the horizon is not a hard line
	for i in 26:
		var ang := TAU * float(i) / 26.0 + rng.randf_range(-0.06, 0.06)
		var d := rng.randf_range(52.0, 62.0)
		var r := rng.randf_range(7.0, 13.0)
		_sphere(r, Vector3(cos(ang) * d, rng.randf_range(-1.5, 0.5), sin(ang) * d),
			hill, rng.randf_range(0.22, 0.4))

	# trees, kept clear of the test bands
	var trees: Array[Transform3D] = []
	for i in TREE_COUNT:
		var px := rng.randf_range(-45.0, 45.0)
		var pz := rng.randf_range(-46.0, 34.0)
		if abs(px) < 21.0 and pz > -50.0 and pz < 14.0:
			continue
		# One mesh, spun and resized per instance. A forest that reads as a
		# forest out of a single asset — no second tree needed for M3.
		trees.append(_place(rng, Vector3(px, 0.0, pz), 0.75, 1.35))
	_scatter(TREE_FILE, trees, "Trees", true)

	# rocks
	var rocks: Array[Transform3D] = []
	for i in ROCK_COUNT:
		var rx := rng.randf_range(-44.0, 44.0)
		var rz := rng.randf_range(-44.0, 32.0)
		if abs(rx) < 19.0 and rz > -50.0 and rz < 12.0:
			continue
		# Sunk slightly, because a boulder resting exactly on the ground plane
		# reads as dropped there rather than as part of the place.
		rocks.append(_place(rng, Vector3(rx, -0.06, rz), 0.7, 1.8))
	_scatter(ROCK_FILE, rocks, "Rocks", false)


func _build_shelter() -> void:
	var z := SHELTER_Z

	# Back wall, full width.
	for i in 3:
		_piece(WALL_FILE, Vector3((float(i) - 1.0) * MODULE, 0.0, z - SHELTER_HALF), 0.0)

	# Sides, stopping short of the corners. A ruin with gaps in it reads
	# better than a sealed box, and the gaps are what let you find out
	# whether the camera copes with a wall between it and you.
	for i in 2:
		var zz := z + (float(i) - 0.5) * MODULE
		_piece(WALL_FILE, Vector3(-SHELTER_HALF, 0.0, zz), PI * 0.5)
		_piece(BROKEN_FILE, Vector3(SHELTER_HALF, 0.0, zz), PI * 0.5)

	# Front: a doorway with broken wall either side, so there is a way in and
	# a reason to walk through it rather than round.
	_piece(DOOR_FILE, Vector3(0.0, 0.0, z + SHELTER_HALF), 0.0)
	_piece(BROKEN_FILE, Vector3(-MODULE, 0.0, z + SHELTER_HALF), 0.0)
	_piece(BROKEN_FILE, Vector3(MODULE, 0.0, z + SHELTER_HALF), 0.0)

	_label("walk in and watch the camera", Vector3(0.0, 4.2, z + SHELTER_HALF + 2.0),
		36, Palette.STONE_LIGHT)


## Place one imported piece, upright on the ground and spun about Y.
##
## No collision is built here: it arrives with the mesh, generated by Godot
## from the -col and -convcol suffixes on the object names in Blender. That is
## the whole point of authoring it over there.
func _piece(file: String, pos: Vector3, yaw: float) -> void:
	var res := load(IMPORT_DIR + file)
	if not (res is PackedScene):
		push_warning("greenhorn: shelter piece %s did not load" % file)
		return
	var n := (res as PackedScene).instantiate() as Node3D
	if n == null:
		return
	n.position = pos
	n.rotation.y = yaw
	add_child(n)

	# Godot does not warn about a suffix it does not recognise. It treats it
	# as part of the name, imports the mesh, and hands you a wall you walk
	# straight through with nothing in the log to say why — `-con` instead of
	# `-col` costs an evening otherwise.
	if n.find_children("*", "StaticBody3D", true, false).is_empty():
		push_warning(("greenhorn: %s arrived with no collision. The object "
			+ "name in Blender must end in exactly -col, -convcol, -colonly "
			+ "or -convcolonly.") % file)


## One scattered placement: on the ground, spun on Y, uniformly resized.
##
## Uniform on purpose. Jolt refuses a non-uniform scale on a collision shape
## and quietly substitutes a uniform one, so a squashed body would give you a
## collider that does not match what you can see.
func _place(rng: RandomNumberGenerator, pos: Vector3, lo: float, hi: float) -> Transform3D:
	var s := rng.randf_range(lo, hi)
	var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
	return Transform3D(b, pos)


## Draw one mesh at every given transform, in a single draw call, and give
## each instance a static collider.
##
## `tall` picks the collider: a trunk-width column for trees, so you can walk
## under the canopy, or the mesh's own bounds for anything squat.
##
## The colliders are separate bodies because a MultiMesh has no collision —
## that is the trade. They cost physics, not draw calls, and a static body the
## player never touches costs close to nothing.
func _scatter(file: String, xforms: Array[Transform3D], label: String, tall: bool) -> void:
	if xforms.is_empty():
		return
	var res := load(IMPORT_DIR + file)
	if not (res is PackedScene):
		push_warning("greenhorn: no scenery mesh in %s, so no %s" % [file, label])
		return
	var inst: Node = (res as PackedScene).instantiate()
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		found.append(inst)
	if found.is_empty():
		push_warning("greenhorn: %s has no mesh to scatter" % file)
		inst.queue_free()
		return

	if found.size() > 1:
		push_warning(("greenhorn: %s has %d meshes; only the first is "
			+ "scattered. Join them in Blender — a MultiMesh draws one mesh, "
			+ "which is the whole reason this is cheap.") % [file, found.size()])

	# The object's own transform comes along, accumulated to the scene root:
	# rock1 carries an unapplied 0.41 scale, and dropping it would put
	# boulders the size of sheds on the plot.
	var src := found[0] as MeshInstance3D
	var mesh := src.mesh
	var local := Transform3D.IDENTITY
	var up: Node = src
	while up is Node3D:
		local = (up as Node3D).transform * local
		up = up.get_parent()
	inst.queue_free()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	add_child(mmi)

	# Measured off the mesh, so remodelling the tree resizes its collider too.
	var box := local * mesh.get_aabb()
	for xf in xforms:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		if tall:
			var cyl := CylinderShape3D.new()
			cyl.radius = TRUNK_RADIUS
			cyl.height = box.size.y
			cs.shape = cyl
			cs.position = Vector3(0.0, box.position.y + box.size.y * 0.5, 0.0)
		else:
			var bs := BoxShape3D.new()
			# inset horizontally so a rounded rock does not feel square underfoot
			bs.size = Vector3(box.size.x * 0.8, box.size.y, box.size.z * 0.8)
			cs.shape = bs
			cs.position = box.get_center()
		body.add_child(cs)
		add_child(body)
		body.transform = xf


# --- whatever you dropped in ------------------------------------------------
func _mount_imports() -> void:
	var names: Array[String] = []
	var dir := DirAccess.open(IMPORT_DIR)
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir():
				var ext := f.get_extension().to_lower()
				if ext == "blend" or ext == "glb" or ext == "gltf":
					names.append(f)
			f = dir.get_next()
		dir.list_dir_end()
	names.sort()

	if names.is_empty():
		_label("drop a .blend into  assets/blender/  and it appears here",
			Vector3(0.0, 1.9, PLINTH_Z), 40, Palette.ACCENT)
		_label("Godot re-imports it every time you save in Blender",
			Vector3(0.0, 1.45, PLINTH_Z), 30, Palette.STONE_LIGHT)
		return

	var plinth := Palette.solid(Palette.DIRT_DARK, 0.9)
	for i in names.size():
		var px := (float(i) - float(names.size() - 1) * 0.5) * 3.8
		var base := Vector3(px, 0.0, PLINTH_Z)
		_box(Vector3(1.6, 0.3, 1.6),
			Transform3D(Basis(), base + Vector3(0.0, 0.15, 0.0)), plinth)

		var res := load(IMPORT_DIR + names[i])
		var holder := Node3D.new()
		holder.position = base + Vector3(0.0, 0.3, 0.0)
		add_child(holder)

		var note := ""
		if res is PackedScene:
			var inst: Node = (res as PackedScene).instantiate()
			holder.add_child(inst)
			note = _autoplay(inst)
		elif res is Mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = res
			holder.add_child(mi)
			note = "mesh only, no rig"
		else:
			push_warning("greenhorn: could not mount %s" % names[i])
			note = "failed to load"

		# Label goes above whatever actually arrived, not at a guessed height.
		# A 1.7 m character on a 0.3 m plinth put its head exactly where a
		# fixed 2 m label was, and wore the caption like a hat.
		var top: float = maxf(_visual_top(holder), holder.global_position.y + 0.4)
		_label(names[i], Vector3(px, top + 0.62, PLINTH_Z), 32, Palette.STONE_LIGHT)
		_label(note, Vector3(px, top + 0.36, PLINTH_Z), 24, Palette.ACCENT)
		_label(_census(holder), Vector3(px, top + 0.14, PLINTH_Z), 22, Palette.STONE_LIGHT)

	# a 1 m cube beside the row, so a scale mistake is obvious at a glance
	var refx := float(names.size()) * 1.9 + 1.8
	_box(Vector3.ONE, Transform3D(Basis(), Vector3(refx, 0.5, PLINTH_Z)),
		Palette.solid(Palette.STONE_LIGHT, 0.9))
	_label("1 m", Vector3(refx, 1.4, PLINTH_Z), 32)


## Highest point of any geometry under a node, in world space. Used to park a
## caption clear of the model rather than through it.
##
## Meshes only, deliberately. A Light3D is a VisualInstance3D too, and its
## AABB is its whole range — kilometres wide for an imported glTF point light,
## which has no range at all in the spec. Leave Blender's default light in a
## .blend and its captions get flung into the sky, which reads on screen as
## the model simply having no captions.
func _visual_top(n: Node) -> float:
	var best := -INF
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var vi := c as MeshInstance3D
		var ab := vi.get_aabb()
		var xf := vi.global_transform
		for i in 8:
			best = maxf(best, (xf * ab.get_endpoint(i)).y)
	return best


## Loop something on a mounted model so you can see it move, and report what
## came through. If a caption says "no animations" the export is the problem,
## not the engine.
func _autoplay(inst: Node) -> String:
	var ap := AnimPick.find_player(inst)
	if ap == null:
		return "no AnimationPlayer"
	var list := ap.get_animation_list()
	if list.is_empty():
		return "no animations"
	# Idle first. A plinth is a display stand, and a walk cycle running on
	# the spot reads as a treadmill; an idle reads as "here is the character".
	var pick := ""
	for want in ["idle", "walk", "run"]:
		pick = AnimPick.find(ap, want)
		if pick != "":
			break
	if pick == "":
		pick = list[0]
	AnimPick.loop(ap, pick)
	ap.play(pick)
	return "%d anim: %s" % [list.size(), ", ".join(list)]


## What arrived structurally, not just what it can play. Two skeletons in one
## file is the single most common cause of "why is there a man riding my cat" —
## an object you hid in Blender rather than deleted, since hiding does not
## exclude anything from an export.
func _census(inst: Node) -> String:
	var bones: Array[String] = []
	for c in inst.find_children("*", "Skeleton3D", true, false):
		bones.append(str((c as Skeleton3D).get_bone_count()))
	var meshes := 0
	var verts := 0
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var m := (c as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			verts += m.surface_get_array_len(i)
	var rig := "no rig"
	if bones.size() == 1:
		rig = "1 rig (%s bones)" % bones[0]
	elif bones.size() > 1:
		rig = "%d RIGS (%s bones)" % [bones.size(), " + ".join(bones)]
	return "%s - %d mesh, %d verts" % [rig, meshes, verts]
