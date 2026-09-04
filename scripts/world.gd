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
##
## With `diagnostics` off none of that is built. You get the run instead —
## same ground, same light, same scatter, different furniture:
##   (0, -9)     the first ring — walk in and it starts
##   (-23, -31)  the compound — walls and a doorway, both species
##   (2, -40)    the shelter — the only place damage comes back
##   (17, -51)   the deep ring — the big one
##
## Nothing between those places is a corridor in the level-design sense. It is
## just ground, and crossing it is the cost.

const IMPORT_DIR := "res://assets/blender/"
const PLAYER := preload("res://scenes/player.tscn")

## Sandbox or arena. One flag rather than a second world script: the ground,
## the lighting, the scatter and the primitives are the same either way, and
## only the furniture differs.
##
## On: plinths, ramps, stairs, scale refs, the material row, the shelter — the
## apparatus that tells you whether an import and the controller are behaving.
## Off: a ring of standing stones and a fight. You cannot judge whether a
## fight is any good while standing in a laboratory.
@export var diagnostics := true

# --- standing stones --------------------------------------------------------
## Metres between stones in a ring. The count follows from the radius, so a
## bigger room is not a sparser one.
##
## Close enough that a ring reads as a wall from inside, far enough apart to
## walk between. The gaps are deliberate: a gap is better than a wall for the
## camera, which is the whole reason the arm sweep is a sphere now.
const STONE_SPACING := 2.9
const PILLAR_FILE   := "pillar.blend"

# --- waves ------------------------------------------------------------------
## Seconds between clearing a wave and the next one arriving. Long enough to
## notice you won.
const WAVE_GAP := 2.5

# --- the boss ---------------------------------------------------------------
## Waves survived before it turns up. Beating it ends the run — that is the
## "exit" half of enter/clear/exit, and the reason a wave counter alone is a
## treadmill rather than a loop.
const WAVES_TO_BOSS := 1
## The same beetle with bigger numbers, which is the whole point of trying it
## this way: no new model, no new script, no new animations. If a big slow one
## is a good fight, that is worth knowing before anything gets sculpted.
##
## Size scales its reach too, so those jaws genuinely arrive from further out.
const BOSS_SIZE       := 2.2
const BOSS_HEALTH     := 12
const BOSS_SHELL_HITS := 6     ## the shell comes off halfway through
const BOSS_BITE       := 2     ## the player has five, so three bites end it
const BOSS_SPEED      := 1.2   ## slower than the small ones, and it has to be

## The prize, and it is the title: a robot wearing beetle jaws on its head.
const TROPHY_FILE := "mandibles.blend"
const TROPHY_BONE := "mount.head"

# --- the run: rooms and the ground between them --------------------------
## Three rooms and the ground between them.
##
## A room is a place, a shape and a fight. Walking into one starts it; nothing
## happens until you do, so the corridors are somewhere you travel rather than
## somewhere you are shepherded through.
##
## They must be taken in order. Wandering into the third does nothing — the
## sequence is the point, and "three fights available at once" is a different
## game from "three fights in a row".
##
## Note what is NOT here: no health reset, no scene change, no state to carry.
## One world, three regions, one script — so a run is a walk, and the damage
## you took in room one is still on you in room three. That is the entire
## reason this stage exists.
const ROOMS := [
	{
		"name": "the first ring",
		"at": Vector3(0.0, 0.0, -9.0),
		"radius": 13.0,
		"walled": false,
		"bugs": 3,
	},
	{
		"name": "the compound",
		"at": Vector3(-23.0, 0.0, -31.0),
		"radius": 11.0,
		"walled": true,       ## the doorway that already proved itself
		"bugs": 6,
	},
	{
		"name": "the deep ring",
		"at": Vector3(17.0, 0.0, -51.0),
		"radius": 16.0,
		"walled": false,
		"bugs": 0,            ## the big one, alone
		"boss": true,
	},
]

## Off the direct line between rooms two and three, on purpose. Reaching it
## costs you distance you could have spent arriving at the boss intact — which
## is the whole decision this stage is trying to provoke.
const SHELTER_AT   := Vector3(2.0, 0.0, -40.0)
const SHELTER_SIZE := 4.0    ## half-width, so an 8 m square
## Health per second, standing inside. Nothing out in the open gives any back.
const MEND_RATE    := 0.5

## Survives `reload_current_scene()`, so it survives dying and it survives R.
## Not a save file — quitting clears it — but enough to find out whether
## knowing you got further last time changes how you play.
static var furthest := 0

# --- spawn and layout -------------------------------------------------------
const GROUND     := 140.0
const SPAWN      := Vector3(0.0, 1.2, 9.0)
## Off the path and clear of the plinth row, so they have to walk to reach you
## and you get to watch them come.
const BUG_SPAWN  := Vector3(9.0, 0.4, 4.0)
## More than one, because everything about the fight has so far been tuned
## against a single target. A swing that sweeps through two of them is the
## first honest test of the hit window, the cancel window and the knockback.
const BUG_COUNT  := 6
## The roster: a model, its carapace, and the bone that carapace rides. Spawns
## cycle through it, so two species arrive mixed rather than in blocks.
##
## bug2 has no `attack` clip, so it cannot bite — everything degrades, and it
## simply walks at you while bug3 does the damage. That is the pacifist
## species from the story doc, arrived at by accident rather than by design.
const BUG_KINDS := [
	{"model": "bug3.blend", "shell": "shell2.blend", "bone": "shell2.socket"},
	{"model": "bug2.blend", "shell": "shell.blend",  "bone": "shell.socket"},
]
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
var _player: Node3D = null
var _banner: Label3D = null
var _wave := 0
var _standing := 0            ## hostiles still up in this wave or room
var _spawned: Array[Bug] = []
var _room := -1               ## the room being fought, -1 between them
var _next_room := 0           ## the only one that will trigger
var _sheltered := false
var _mend := 0.0
var _rings := 0               ## MultiMesh names have to be unique


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_scenery()
	if diagnostics:
		_build_path()
		_build_ramps()
		_build_stairs()
		_build_scale_refs()
		_build_material_row()
		_build_shelter()
		_mount_imports()
	else:
		_build_run()

	_player = PLAYER.instantiate()
	_player.position = SPAWN
	add_child(_player)

	_banner = _label("", SPAWN + Vector3(0.0, 4.6, -6.0), 56, Palette.STONE_LIGHT)
	if diagnostics:
		_spawn_wave()
	else:
		_show_run()


# --- walking the run --------------------------------------------------------
## Build all three rooms and the shelter between them. No fights start here —
## every one waits for you to walk in.
func _build_run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260904

	for i in ROOMS.size():
		var room: Dictionary = ROOMS[i]
		var at: Vector3 = room["at"]
		if room["walled"]:
			_compound(at, room["radius"] * 0.62)
		else:
			_ring(at, room["radius"], rng)
		_label(room["name"], at + Vector3(0.0, 5.0, 0.0), 40, Palette.STONE_LIGHT)
		_trigger(at, room["radius"], "Room%d" % i, _on_room_entered.bind(i),
			_on_room_left.bind(i))

	# The shelter. Four walls and a door, same kit as the compound, small
	# enough that the camera collapses inside it — which is the point. It
	# should feel like ducking in, not like another arena.
	_compound(SHELTER_AT, SHELTER_SIZE)
	_label("shelter", SHELTER_AT + Vector3(0.0, 4.4, 0.0), 36, Palette.ACCENT)
	_trigger(SHELTER_AT, SHELTER_SIZE, "Shelter",
		_on_shelter_entered, _on_shelter_left)


## A cylinder you can walk into. Masks CHARACTER, so only bodies trip it, and
## the callbacks sort out whether it was the player.
func _trigger(at: Vector3, radius: float, label: String,
		on_in: Callable, on_out: Callable) -> void:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 8.0
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position.y = 4.0
	var area := Area3D.new()
	area.name = label
	area.collision_mask = Layers.CHARACTER
	area.add_child(cs)
	area.position = at
	add_child(area)
	area.body_entered.connect(on_in)
	area.body_exited.connect(on_out)


func _on_room_entered(body: Node3D, index: int) -> void:
	# Only the player, only the next one, and only once. Beetles wander into
	# these all the time.
	if body != _player or index != _next_room or _room >= 0:
		return
	_room = index
	_standing = 0
	var room: Dictionary = ROOMS[index]
	var at: Vector3 = room["at"]
	var radius: float = room["radius"]
	if room.get("boss", false):
		# Deep in, so you have to come to it rather than meeting it at the edge.
		_spawn_boss(at + Vector3(0.0, 0.0, -radius * 0.5))
	else:
		_spawn_group(int(room["bugs"]), at, 3.4)
	_show_run()


## Leaving a fight does not end it. Walking out is allowed — it just means
## they follow you out, which is the only retreat this stage offers.
func _on_room_left(_body: Node3D, _index: int) -> void:
	pass


func _on_shelter_entered(body: Node3D) -> void:
	if body == _player:
		_sheltered = true


func _on_shelter_left(body: Node3D) -> void:
	if body == _player:
		_sheltered = false


## Damage only comes back inside. That single asymmetry is what turns the
## detour into a decision instead of a formality.
func _process(delta: float) -> void:
	if not _sheltered or _player == null or not _player.has_method("heal"):
		return
	_mend += delta * MEND_RATE
	if _mend >= 1.0:
		_mend -= 1.0
		_player.heal(1)


func _room_cleared() -> void:
	_next_room = _room + 1
	furthest = maxi(furthest, _next_room)
	_room = -1
	if _next_room >= ROOMS.size():
		_show_run()
		if _player != null and _player.has_method("wear"):
			_player.wear(TROPHY_FILE, TROPHY_BONE)
		return
	_show_run()


func _show_run() -> void:
	if _banner == null:
		return
	if _next_room >= ROOMS.size():
		_banner.text = "the horn is yours"
	elif _room >= 0:
		_banner.text = "%s  —  %d left" % [ROOMS[_room]["name"], _standing]
	else:
		_banner.text = "find %s" % ROOMS[_next_room]["name"]
		if furthest > _next_room:
			_banner.text += "      (best: %d of %d)" % [furthest, ROOMS.size()]


# --- the sandbox loop -------------------------------------------------------
## Spawn a wave, one bigger than the last.
##
## Placed on a ring rather than scattered, so every restart puts them in the
## same spots and two attempts are actually comparable — same reason the
## scenery is seeded.
func _spawn_wave() -> void:
	_wave += 1
	_standing = 0

	# Clear the previous wave's bodies. They are worth leaving on the grass
	# while the wave lasts — a corpse is feedback — but not stacking up.
	for old in _spawned:
		if is_instance_valid(old):
			old.queue_free()
	_spawned.clear()

	if _wave > WAVES_TO_BOSS:
		_spawn_boss(BUG_SPAWN)
	else:
		_spawn_group(BUG_COUNT + _wave - 1, BUG_SPAWN, BUG_SPREAD)
	_show_wave()


## A ring of beetles, alternating species, around a point. Shared by the
## sandbox's waves and the run's rooms — the only difference between them is
## who decides when to call it.
##
## Placed on a ring rather than scattered, so every restart puts them in the
## same spots and two attempts are actually comparable — same reason the
## scenery is seeded.
func _spawn_group(count: int, at: Vector3, spread: float) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var kind: Dictionary = BUG_KINDS[i % BUG_KINDS.size()]
		var b := Bug.new()
		b.model_file = kind["model"]
		b.shell_file = kind["shell"]
		b.shell_bone = kind["bone"]
		b.position = at + Vector3(cos(a), 0.0, sin(a)) * spread
		# Handing each one the player directly beats a group lookup: the world
		# already holds both, and there is nothing to go stale.
		b.target = _player
		b.died.connect(_on_bug_died)
		add_child(b)
		_spawned.append(b)
		# is_hostile only answers once the model is mounted, which happens on
		# add_child. Asking earlier gets you a lie.
		if b.is_hostile():
			_standing += 1


## One beetle, alone. No adds: the question this is asking is whether a big
## slow one is a fight on its own terms, and a crowd around it would make that
## impossible to read either way.
func _spawn_boss(at: Vector3) -> void:
	var b := Bug.new()
	b.name = "Boss"
	b.model_file = "bug3.blend"
	b.shell_file = "shell2.blend"
	b.shell_bone = "shell2.socket"
	b.size = BOSS_SIZE
	b.max_health = BOSS_HEALTH
	b.shell_hits = BOSS_SHELL_HITS
	b.bite_damage = BOSS_BITE
	b.walk_speed = BOSS_SPEED
	b.position = at
	b.target = _player
	b.died.connect(_on_bug_died)
	add_child(b)
	_spawned.append(b)
	_standing += 1


## Only the things that can bite gate a wave.
##
## This is the pacifist species question from the story doc, as a line of
## code. Requiring every beetle dead would force the player to kill the docile
## ones, and the doc is explicit that the moment the game demands it, it stops
## being a choice. Sparing them now costs nothing but the time you did not
## spend — which is exactly the shape the doc argues for.
func _on_bug_died(b: Bug) -> void:
	if not b.is_hostile():
		return
	_standing -= 1
	if diagnostics:
		_show_wave()
		if _standing <= 0:
			_cleared()
	else:
		_show_run()
		if _standing <= 0 and _room >= 0:
			_room_cleared()


func _show_wave() -> void:
	if _banner == null:
		return
	if _wave > WAVES_TO_BOSS:
		_banner.text = "the big one" if _standing > 0 else ""
	elif _standing <= 0:
		_banner.text = "wave %d cleared" % _wave
	else:
		_banner.text = "wave %d  —  %d left" % [_wave, _standing]


func _cleared() -> void:
	# The boss is the end of the run, not another wave. Enter, clear, exit —
	# and this is the exit.
	if _wave > WAVES_TO_BOSS:
		_banner.text = "the horn is yours"
		if _player != null and _player.has_method("wear"):
			_player.wear(TROPHY_FILE, TROPHY_BONE)
		return

	await get_tree().create_timer(WAVE_GAP).timeout
	if is_inside_tree():
		_spawn_wave()


## R rebuilds the whole plot from scratch: player back at spawn, bugs alive and
## wearing their shells again, debris gone.
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
	#
	# The ring of low hills that used to sit at 52-62 m is gone, deliberately,
	# to find out what wants to be there instead. Its job was stopping the
	# horizon being a hard line, and nothing has taken that over yet — so
	# expect a flat edge in the distance until something does.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260824

	# trees, kept clear of whatever is standing in the middle
	var trees: Array[Transform3D] = []
	for i in TREE_COUNT:
		var px := rng.randf_range(-45.0, 45.0)
		var pz := rng.randf_range(-46.0, 34.0)
		if not _open_ground(px, pz):
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
		if not _open_ground(rx, rz):
			continue
		# Sunk slightly, because a boulder resting exactly on the ground plane
		# reads as dropped there rather than as part of the place.
		rocks.append(_place(rng, Vector3(rx, -0.06, rz), 0.7, 1.8))
	_scatter(ROCK_FILE, rocks, "Rocks", false)


func _build_shelter() -> void:
	_compound(Vector3(0.0, 0.0, SHELTER_Z), SHELTER_HALF)
	_label("walk in and watch the camera",
		Vector3(0.0, 4.2, SHELTER_Z + SHELTER_HALF + 2.0), 36, Palette.STONE_LIGHT)


## Four walls and a doorway around a point, on the 2 m grid.
##
## The corners are left open. A ruin with gaps reads better than a sealed box,
## and the gaps are also what let the camera arm breathe — a solid enclosure
## pins it, which the shelter band demonstrated.
func _compound(at: Vector3, half: float) -> void:
	var n := maxi(2, int(round(half * 2.0 / MODULE)))
	var door := n / 2
	for i in n:
		var t := (float(i) - float(n - 1) * 0.5) * MODULE
		_piece(WALL_FILE, at + Vector3(t, 0.0, -half), 0.0)           # back
		_piece(WALL_FILE, at + Vector3(-half, 0.0, t), PI * 0.5)      # left
		_piece(BROKEN_FILE, at + Vector3(half, 0.0, t), PI * 0.5)     # right
		# Front: one doorway, broken wall either side of it, so there is a way
		# in and a reason to walk through rather than round.
		if i == door:
			_piece(DOOR_FILE, at + Vector3(t, 0.0, half), 0.0)
		else:
			_piece(BROKEN_FILE, at + Vector3(t, 0.0, half), 0.0)


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


## Where scenery may land. The middle is spoken for either way — by the test
## bands in the sandbox, by the fight in the arena — and a tree in the middle
## of a stone circle is scenery in the way of the game.
func _open_ground(x: float, z: float) -> bool:
	if diagnostics:
		return not (abs(x) < 21.0 and z > -50.0 and z < 14.0)
	var p := Vector3(x, 0.0, z)
	for room: Dictionary in ROOMS:
		if p.distance_to(room["at"]) < float(room["radius"]) + 4.0:
			return false
	return p.distance_to(SHELTER_AT) > SHELTER_SIZE + 5.0


## A ring of standing stones: the horizon, the arena wall and the cover, out
## of one asset.
##
## Gaps are deliberate. A solid wall pins the camera arm against it from the
## inside; a gap lets the sphere sweep through and the arm breathe. It also
## means the ring reads as a boundary without being a cage, which is the right
## answer before there is anything as formal as a door.
## A ring of standing stones around a point. Stone count scales with the
## radius so a bigger room is not a sparser one.
func _ring(at: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var n := maxi(12, int(round(TAU * radius / STONE_SPACING)))
	var stones: Array[Transform3D] = []
	for i in n:
		var ang := TAU * float(i) / float(n) + rng.randf_range(-0.04, 0.04)
		var d := radius + rng.randf_range(-1.1, 1.1)
		var s := rng.randf_range(0.85, 1.3)
		# A little lean. A ring of perfectly upright stones reads as a fence;
		# a few degrees of settle reads as something that has been standing a
		# long time. Small enough that none of them looks knocked over.
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		b *= Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06))
		b = b.scaled(Vector3(s, s, s))
		# Sunk, so the base is buried rather than resting on the grass.
		stones.append(Transform3D(b, at + Vector3(cos(ang) * d, -0.2, sin(ang) * d)))
	_scatter(PILLAR_FILE, stones, "Stones%d" % _rings, false, 1.0)
	_rings += 1


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
func _scatter(file: String, xforms: Array[Transform3D], label: String, tall: bool,
		inset := 0.8) -> void:
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
			# Inset horizontally so a rounded rock does not feel square underfoot.
			# A standing stone passes 1.0 — it IS square, and clipping its
			# corners would let you walk into one.
			bs.size = Vector3(box.size.x * inset, box.size.y, box.size.z * inset)
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
