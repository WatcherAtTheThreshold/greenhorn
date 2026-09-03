extends CharacterBody3D
## Third-person character controller with a first-person toggle.
##
## First person here is not a separate mode — it is the same rig with the
## camera arm shortened to zero and the body hidden. One variable, not a fork.
##
## Every feel value is a const at the top, so playtest feedback is a
## one-number change.

# --- movement ---------------------------------------------------------------
const WALK_SPEED      := 3.2      ## m/s — a relaxed amble
const RUN_SPEED       := 6.0      ## m/s — holding Shift
const ACCEL           := 14.0     ## m/s^2 toward target velocity
const FRICTION        := 18.0     ## m/s^2 when no input; high = not slidey
const AIR_CONTROL     := 0.35     ## fraction of ACCEL that applies mid-air
const JUMP_SPEED      := 5.0      ## m/s upward impulse
const GRAVITY         := 18.0     ## m/s^2 — heavier than real, feels better
const TURN_RATE       := 12.0     ## how fast the body swings to face travel

# --- stepping ---------------------------------------------------------------
## How tall a ledge the character will walk up without jumping. Godot's
## CharacterBody3D will not climb a vertical riser on its own, so we do it
## manually below.
##
## This is the line between *incidental* elevation and *deliberate* elevation,
## and it wants to sit low. Curbs, thresholds, the lip where a ramp meets the
## ground, the edge of a rock — those must not stop you dead, or the game
## feels broken in a way that is very hard to point at. Anything someone
## placed on purpose to be climbed reads better jumped.
##
## At 0.28: the 15 and 25 cm stair bands walk, the 40 cm band and the 0.3 m
## plinths need a jump.
const STEP_HEIGHT     := 0.28
## How fast the view catches up after a step-up. The collision body has to go
## up — physics needs it there — but the camera and the model do not have to
## follow in the same frame, and them doing so is what reads as a jerk. Both
## get held back and eased in. Higher is tighter; 0 would leave them behind
## permanently.
const STEP_SMOOTH     := 14.0
## How far ahead to look when hunting for a tread. Must exceed the collision
## capsule's radius (0.35), or the probe never gets the body's axis past the
## riser and finds the floor you are already standing on instead of the step.
##
## One frame of walking is about 5 cm, which is nowhere near enough — using
## that made shallow stairs climbable only at a run, because running happened
## to double the reach.
const STEP_PROBE      := 0.45
## How far ahead counts as "in the way". Fixed, never one frame of movement:
## at low speed a frame is smaller than the physics margin and the collision
## test stops giving a stable answer.
const STEP_CONTACT    := 0.08
## How fast the body is allowed to climb, in metres per second. THE knob for
## how a staircase feels.
##
## Without this the body covers the whole riser in one frame, so a 40 cm step
## is nearly three times the jolt of a 15 cm one — which is exactly why the
## jerk got worse as the stairs got taller. Capping the rate makes every step
## climb at the same speed regardless of its height; a tall one simply takes
## more frames.
##
## It has a floor, though. To keep up with a staircase you must climb at least
## `riser / tread * speed`. The steepest band STEP_HEIGHT still allows is 25 cm
## over a 42 cm tread, so running it needs about 3.6 m/s of climb — go below
## that and you stall partway up instead of jerking up. There is plenty of
## headroom here, and it still spreads a 25 cm riser over two frames.
const STEP_RATE       := 7.0
## How long a step-up may take before we give up on it. Once one starts the
## body commits: no gravity, no floor snapping, until it is over the edge or
## this runs out. Without the commit the lift is undone the same frame it
## happens and you buzz against the step instead of climbing it.
const STEP_COMMIT     := 0.3
## Normal floor snapping, restored the moment a step finishes. Keeps us glued
## going DOWN stairs and ramps.
const FLOOR_SNAP      := 0.6

# --- camera -----------------------------------------------------------------
const CAM_DISTANCE    := 2.25     ## metres behind the head in third person
const CAM_HEIGHT      := 1.55     ## pivot height — roughly eye level
const CAM_MIN_PITCH   := -1.25    ## radians (looking up)
const CAM_MAX_PITCH   := 1.05     ## radians (looking down)
const CAM_SENS        := 0.0025   ## radians per pixel of mouse movement
const CAM_LAG         := 12.0     ## how quickly the arm settles; higher = tighter
## The camera is a volume, not a point. This is the sphere swept back from the
## head to find where the arm can actually reach, and it doubles as the
## standoff from whatever it lands against.
const CAM_RADIUS      := 0.22

## Parts to hide when the camera is inside the character's head — first person,
## and also when a wall shoves the arm all the way in.
##
## Hiding the head rather than the whole body is only possible because Tim is
## 27 separately named objects instead of one skinned mesh. It means first
## person keeps your own arms, torso and the sword swinging in front of you,
## with no second model and no second set of animations. Names that are not in
## the model are simply skipped, so this costs nothing on other characters.
const HEAD_PARTS: Array[String] = ["head", "eye1", "eye2", "mouth", "neck"]

# --- sockets ----------------------------------------------------------------
## The bone a held weapon rides. Add it in Blender parented to the hand bone
## with **Deform unticked**, so it skins nothing and makes no vertex group.
## Aim the bone at the weapon rather than moving the weapon to the bone: the
## weapon is modelled at the origin pointing the way it should point when
## held, and the socket rotates to meet it.
const WEAPON_BONE := "weapon.socket.R"

# --- attacks ----------------------------------------------------------------
## A swing is held for the length of its own clip, so retiming the chop in
## Blender retimes the commitment in game and there is no number here to keep
## in sync. This is the fraction of the swing you are locked into before the
## next one may start: 1.0 means you must watch every recovery frame, lower
## lets a second click cut them short and feels prompter in the hand.
const ATTACK_CANCEL := 0.75

# --- hitting ----------------------------------------------------------------
## When in the swing the blade is live, as a fraction of the clip. Only the
## motion should connect, not the poses held at either end, or the sword reads
## as damaging things by resting against them.
##
## These started as a deliberately wide guess, because the importer samples
## every frame and the export cannot say where in a clip the fast part is.
##
## **Played and kept, 2026-09-02.** The blade sliding past a beetle misses;
## anything that actually enters its body connects. That reads as accurate
## rather than generous, and it is worth understanding why: the hitbox is
## measured off the weapon mesh itself, so it *is* the blade — there is no
## approximation to be forgiving or stingy about. Widening these would start
## connecting on the held poses at either end, which reads as the sword
## damaging things by resting against them.
##
## No aim assist, deliberately. Whether melee wants some is an open question,
## not an omission — see m2-first-fight.md.
const HIT_FROM   := 0.1
const HIT_TO     := 0.7
const HIT_DAMAGE := 1

## Hitstop: both parties nearly freeze for a moment on impact. This is the
## cheapest trick in the book and it does more for weight than any animation —
## the swing appears to meet resistance rather than pass through. Not quite
## zero, because a dead-stopped frame reads as a stutter rather than a hit.
const HITSTOP_TIME  := 0.06
const HITSTOP_SCALE := 0.05

# --- being hit --------------------------------------------------------------
## Bites you survive. Low on purpose: the question a fight has to answer is
## whether you are willing to commit to a swing, and that only means something
## if being wrong is expensive.
const MAX_HEALTH   := 5
## The same feedback trio that goes out, coming back in. A flash you can see
## from behind your own shoulder, a shove that interrupts what you were doing,
## and the hitstop already used for landing blows.
const HURT_FLASH   := 0.08
const HURT_SHOVE   := 5.0
## Seconds of stagger when there is no `hit` clip. With one, its own length
## wins — the same contract the swings use.
const HURT_HOLD    := 0.3
## How long the corpse lies there before the plot rebuilds itself.
const DEATH_HOLD   := 1.6

## Which model to wear. Three ways, in priority order:
##   1. character_scene, if you set it in the inspector
##   2. anything already dragged into Body in the editor
##   3. otherwise, a rigged model found in assets/blender/
##
## Case 3 loads by PATH at runtime rather than holding a reference in the
## scene file. That matters: a .tscn that references an asset by UID breaks
## the moment you rename or replace that asset, and then keeps rendering the
## old one out of the import cache, which is genuinely hard to diagnose. This
## way you can swap the contents of assets/blender/ freely and nothing here
## needs touching.
@export var character_scene: PackedScene
## Leave blank to wear the first rigged model found. Set e.g. "cat.blend" to
## pin it to one file.
@export var character_file := ""
## Which weapon to hold. Blank means empty-handed. The weapon is never skinned
## and never rigged — it hangs off WEAPON_BONE, so changing this one string
## swaps the weapon with no re-export and no scene edit.
@export var weapon_file := "sword1.blend"

var _yaw := 0.0
var _pitch := -0.15
var _arm := CAM_DISTANCE
var _first_person := false
## Body faces the camera instead of its direction of travel — Roblox shift-lock
## rather than an over-the-shoulder framing. The camera itself does not move.
var _cam_lock := false
var _spawn := Vector3.ZERO

@onready var body: Node3D = $Body
@onready var placeholder: Node3D = $Body/Placeholder
@onready var pivot: Node3D = $CamPivot
@onready var camera: Camera3D = $CamPivot/Camera

var _anim: AnimationPlayer = null
var _clip_idle := ""
var _clip_walk := ""
var _clip_run := ""
var _clip_jump := ""
var _clip_fall := ""
var _clip_land := ""
var _clip_thrust := ""
var _clip_chop := ""
var _clip_hurt := ""
var _clip_death := ""
var _health := MAX_HEALTH
var _hurt_left := 0.0        ## staggered: no input, so the shove reads
var _flash_left := 0.0
var _dead := false
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D = null
var _attack := ""          ## clip currently swinging, "" when not attacking
var _attack_left := 0.0    ## seconds of it still to play
var _attack_len := 0.0     ## its full length, for the cancel window
var _idle_held := false
var _airborne := false
var _land_left := 0.0
var _head_parts: Array[Node3D] = []
var _step_offset := 0.0     ## how far the view is still behind after a step
var _stepping := 0.0        ## seconds left of a committed step-up
var _blade: Area3D = null
var _struck: Array[Node] = []   ## already hit by THIS swing, so each lands once
var _stopping := false          ## a hitstop is already running


func _ready() -> void:
	_spawn = global_position
	pivot.position.y = CAM_HEIGHT
	collision_layer = Layers.CHARACTER
	collision_mask = Layers.SOLID
	floor_snap_length = FLOOR_SNAP   # keeps us glued going DOWN stairs and ramps
	floor_max_angle = deg_to_rad(50) # matches the 45 deg ramp being walkable
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# The placeholder is a capsule with a nose so you can see which way you
	# are facing. Set character_scene in the inspector and it steps aside.
	var tint := Palette.solid(Palette.ACCENT, 0.7)
	for c in placeholder.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = tint

	# A model can arrive two ways: dragged into Body in the editor, or set on
	# character_scene in the inspector. Dragging it in is the obvious gesture
	# in Godot and it is what a person actually does, so search Body for a rig
	# regardless of how it got there. The export is just a convenience.
	_adopt_model()

	var has_model := false
	for c in body.get_children():
		if c != placeholder and c is Node3D and (c as Node3D).visible:
			has_model = true
	placeholder.visible = not has_model

	_anim = AnimPick.find_player(body)
	if _anim:
		_clip_idle = AnimPick.find(_anim, "idle")
		_clip_walk = AnimPick.find(_anim, "walk")
		_clip_run  = AnimPick.find(_anim, "run")
		_clip_jump = AnimPick.find(_anim, "jump")
		_clip_fall = AnimPick.find(_anim, "fall")
		_clip_land = AnimPick.find(_anim, "land")
		# Ask for the full names, not "attack". Both swings share that prefix,
		# so a prefix search would match either and hand back whichever clip
		# happens to be longer — the two buttons would do the same thing.
		_clip_thrust = AnimPick.find(_anim, "attack.thrust")
		_clip_chop   = AnimPick.find(_anim, "attack.chop")
		_clip_hurt   = AnimPick.find(_anim, "hit")
		_clip_death  = AnimPick.find(_anim, "death")
		AnimPick.set_loop(_anim, _clip_hurt, false)
		AnimPick.set_loop(_anim, _clip_death, false)
		# A swing that resolves to "" is silent — the button does nothing at
		# all and there is nothing on screen to tell you why. Say so, and say
		# what the model actually brought, which is usually the whole answer.
		if _clip_thrust == "" or _clip_chop == "":
			push_warning("greenhorn: thrust=%s chop=%s. Clips in this model: %s"
				% [_clip_thrust, _clip_chop, ", ".join(_anim.get_animation_list())])
		# no walk but a run? use it for both rather than standing frozen
		if _clip_walk == "":
			_clip_walk = _clip_run
		if _clip_run == "":
			_clip_run = _clip_walk
		for clip in [_clip_idle, _clip_walk, _clip_run, _clip_fall]:
			AnimPick.loop(_anim, clip)
		# a jump, a landing or a swing that loops repeats on the spot
		for once in [_clip_jump, _clip_land, _clip_thrust, _clip_chop]:
			AnimPick.set_loop(_anim, once, false)

	for part in HEAD_PARTS:
		for c in body.find_children(part, "VisualInstance3D", true, false):
			_head_parts.append(c as Node3D)

	for c in body.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(c as MeshInstance3D)

	_blade = _build_blade(Socket.equip(body, weapon_file, WEAPON_BONE))


## Put something in Body, by whichever route is available.
func _adopt_model() -> void:
	if character_scene:
		body.add_child(character_scene.instantiate())
		return

	for c in body.get_children():
		if c != placeholder and c is Node3D and (c as Node3D).visible:
			return                      # already dragged in by hand

	var dir := DirAccess.open(Socket.MODEL_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	for f in dir.get_files():
		var e := f.get_extension().to_lower()
		if e == "blend" or e == "glb" or e == "gltf":
			names.append(f)
	names.sort()

	for n in names:
		if character_file != "" and n != character_file:
			continue
		var res := load(Socket.MODEL_DIR + n)
		if not (res is PackedScene):
			continue
		var inst: Node = (res as PackedScene).instantiate()
		# only wear something with a skeleton — otherwise the first thing in
		# the folder might be a table, and you would be wearing the table
		if inst.find_children("*", "Skeleton3D", true, false).is_empty():
			inst.queue_free()
			continue
		body.add_child(inst)
		return


## A hitbox shaped like whatever weapon actually arrived.
##
## Measured off the mesh rather than typed in as numbers, so a longer sword is
## a longer reach with nothing to keep in sync — the same reason the plinth
## captions count vertices instead of trusting a table.
##
## It covers the whole blade, not a point at the tip. A swing throws the tip
## several metres in a handful of frames, and a point would sail clean through
## a bug between two of them.
func _build_blade(weapon: Node) -> Area3D:
	var root := weapon as Node3D
	if root == null:
		return null

	var box := Socket.local_aabb(root)
	if box.size.length() <= 0.0:
		push_warning("greenhorn: %s has no meshes, so it cannot hit anything"
			% weapon_file)
		return null

	var shape := BoxShape3D.new()
	shape.size = box.size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = box.get_center()

	# Left monitoring the whole time and gated by the swing window below.
	# Toggling monitoring costs a physics frame to take effect, and losing the
	# first frame of a fast swing is exactly the frame that mattered.
	var area := Area3D.new()
	area.name = "Blade"
	area.collision_mask = Layers.CHARACTER   # things that can be hurt, not scenery
	area.add_child(cs)
	root.add_child(area)
	return area


## Damage whatever the blade is touching, but only during the live stretch of
## a swing. Anything with a hurt() takes it, so this does not need to know
## what a bug is — and the next enemy needs no changes here.
func _strike() -> void:
	if _blade == null or _attack == "" or _attack_len <= 0.0:
		return
	var t := 1.0 - (_attack_left / _attack_len)   # 0 at the wind-up, 1 at the end
	if t < HIT_FROM or t > HIT_TO:
		return
	var landed := false
	for b in _blade.get_overlapping_bodies():
		if b == self or _struck.has(b) or not b.has_method("hurt"):
			continue
		_struck.append(b)
		b.hurt(HIT_DAMAGE, global_position)
		landed = true
	if landed:
		_hitstop()


## Slow the world to a crawl for a few frames. Lives here rather than on the
## target because there is one attacker and there will be many bugs, and two
## of them stopping time at once would fight over restoring it.
func _hitstop() -> void:
	if _stopping:
		return
	_stopping = true
	Engine.time_scale = HITSTOP_SCALE
	# The last argument is ignore_time_scale — without it this timer is slowed
	# by the very thing it is waiting to undo, and the game never speeds up.
	await get_tree().create_timer(HITSTOP_TIME, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


## Take a bite. Same signature the bugs answer to, so nothing needs to know
## which way round a fight is pointed.
func hurt(amount: int, from: Vector3) -> void:
	if _dead:
		return
	_health -= amount

	_flash_left = HURT_FLASH
	_set_flash(true)

	# Shove, flat. Vertical knockback on the player is worse than on a bug —
	# it takes away your footing and the ground under you decides where you
	# land, which reads as the game taking the controls off you.
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.001:
		velocity += away.normalized() * HURT_SHOVE

	# A bite interrupts a swing. That is the entire reason to care about
	# ATTACK_CANCEL — committing to a chop is only a decision if something can
	# punish you for it.
	_attack = ""
	_hurt_left = HURT_HOLD
	if _clip_hurt != "" and _anim != null:
		var a := _anim.get_animation(_clip_hurt)
		if a != null:
			_hurt_left = a.length
		_play(_clip_hurt, true)

	_hitstop()

	if _health <= 0:
		die(from)


## Stop, fall over, and let the world put itself back.
func die(from: Vector3) -> void:
	if _dead:
		return
	_dead = true
	_hurt_left = 0.0
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _clip_death != "" and _anim != null:
		_play(_clip_death, true)
	# Reload rather than respawn: a run that ends should end. R does the same
	# thing on demand, and world.gd owns it for the same reason.
	await get_tree().create_timer(DEATH_HOLD).timeout
	if is_inside_tree():
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _set_flash(on: bool) -> void:
	if on and _flash_mat == null:
		_flash_mat = Palette.unshaded(Palette.HIT_FLASH)
	for mi in _meshes:
		mi.material_override = _flash_mat if on else null


## Start a swing. Silently does nothing if the model has no such clip, so a
## rig with only a thrust still works on left click and right click is simply
## inert rather than an error.
func _swing(clip: String) -> void:
	if _dead or _hurt_left > 0.0:
		return
	if _anim == null or clip == "":
		return
	var a := _anim.get_animation(clip)
	if a == null:
		return
	# Committed until the recovery frames. Without this a held or mashed
	# button restarts the wind-up every frame and the sword never leaves the
	# start of the swing.
	if _attack != "" and _attack_left > _attack_len * (1.0 - ATTACK_CANCEL):
		return
	_attack = clip
	_attack_len = a.length
	_attack_left = a.length
	_struck.clear()          # a new swing may hit the same bug again
	_play(clip, true)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= e.relative.x * CAM_SENS
		_pitch = clamp(_pitch - e.relative.y * CAM_SENS, CAM_MIN_PITCH, CAM_MAX_PITCH)
	elif e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED)
	elif e.is_action_pressed("cam_lock"):
		_cam_lock = not _cam_lock
	elif e.is_action_pressed("cam_toggle"):
		_first_person = not _first_person
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and e.is_action_pressed("attack_thrust"):
		_swing(_clip_thrust)
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and e.is_action_pressed("attack_chop"):
		_swing(_clip_chop)
	elif e is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		# The click that grabs the mouse back must not also swing the sword,
		# which is why both branches above check for a captured mouse first.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if global_position.y < -12.0:          # walked off the edge of the world
		global_position = _spawn
		velocity = Vector3.ZERO
	_move(delta)
	_update_camera(delta)
	_strike()          # before _animate, which is what advances the swing clock
	_animate(delta)


func _move(delta: float) -> void:
	# --- input, rotated into camera space so "forward" means "away from me" ---
	var raw := Vector2.ZERO
	if not _dead and _hurt_left <= 0.0:
		raw = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3.ZERO
	if raw != Vector2.ZERO:
		var basis_yaw := Basis(Vector3.UP, _yaw)
		wish = (basis_yaw * Vector3(raw.x, 0.0, raw.y)).normalized()

	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var target := wish * speed

	var rate := ACCEL if wish != Vector3.ZERO else FRICTION
	if not is_on_floor():
		rate *= AIR_CONTROL

	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta

	_try_step(delta)

	# A step in progress owns the vertical. Floor snapping would otherwise
	# find the lower ground still sitting under us — our axis has not cleared
	# the edge yet — and pull us straight back down, every frame, which is the
	# buzzing you get against a plinth instead of a climb.
	if _stepping > 0.0:
		_stepping -= delta
		velocity.y = 0.0
		floor_snap_length = 0.0
	else:
		floor_snap_length = FLOOR_SNAP
	move_and_slide()

	# Which way to face.
	#
	# Locked, or mid-swing, that is wherever the camera is looking: you hit
	# what you are aiming at rather than what you happen to be walking
	# towards. Circling a bug is otherwise nearly impossible to land a hit
	# from, because strafing turns your shoulders away from it.
	#
	# The mid-swing case is free — an attack clip is a one-shot, so nothing
	# about the locomotion animation has to agree with the new facing.
	var want := body.rotation.y
	if _cam_lock or _attack != "":
		want = _yaw
	elif wish != Vector3.ZERO:
		want = atan2(-wish.x, -wish.z)
	body.rotation.y = rotate_toward(body.rotation.y, want, TURN_RATE * delta)


## Godot will happily walk you up a 45 degree ramp and then refuse a 10 cm
## step, because a stair riser is a vertical wall as far as the solver is
## concerned. So: if we are grounded and something is blocking us, check
## whether lifting by STEP_HEIGHT clears it. If it does it was a step, not a
## wall — lift, and let floor snapping settle us onto the tread.
func _try_step(delta: float) -> void:
	# Mid-step we are technically airborne, so the commit has to keep us in
	# here or the climb abandons itself halfway up.
	if not is_on_floor() and _stepping <= 0.0:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 1e-8:
		_stepping = 0.0
		return
	var dir := flat.normalized()

	# Ask "is something in the way" over a fixed distance, never over one
	# frame of travel. A frame is 5 cm at a walk and sub-millimetre at a
	# crawl — below test_move's own margin — so against something you are
	# already touching the answer flickered between blocked and clear, and
	# every clear frame cancelled the climb and started it again. That is why
	# the buzz got faster the slower you went.
	if not test_move(global_transform, dir * STEP_CONTACT):
		_stepping = 0.0                          # over the edge; nothing in the way
		return

	# Reach ahead by a full stride. Everything below asks "what is over
	# there", and one frame is not over there yet.
	var probe := dir * maxf(flat.length() * delta, STEP_PROBE)

	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return                                   # no headroom to step into
	if test_move(global_transform.translated(lift), probe):
		return                                   # still blocked up there: a wall

	# How far up do we ACTUALLY need to go? Cast back down from the lifted,
	# advanced position to find the tread.
	#
	# This used to lift the full STEP_HEIGHT every time, which threw you 30 cm
	# into the air for a 15 cm riser and dropped you again — once per step, and
	# continuously against anything you could not really climb. That was the
	# jerking.
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform.translated(lift + probe), -lift, hit):
		return                                   # nothing to land on: a gap, not a step

	# Only step onto something you could have stood on anyway.
	if hit.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return
	# And only onto things that hold still. Stepping onto a bug half works and
	# then it walks out from under you, which is its own kind of jerk. Bumping
	# into one is the more honest result.
	if not (hit.get_collider() is StaticBody3D):
		return

	var rise := STEP_HEIGHT + hit.get_travel().y   # travel.y is negative
	if rise <= 0.0:
		return
	# Climb at a fixed rate rather than teleporting the whole riser at once.
	# A tall step takes more frames instead of landing a bigger blow, so all
	# three stair heights feel the same going up.
	rise = minf(rise, STEP_RATE * delta)
	global_position.y += rise
	_step_offset = minf(_step_offset + rise, STEP_HEIGHT)
	_stepping = STEP_COMMIT


func _update_camera(delta: float) -> void:
	pivot.rotation.y = _yaw
	pivot.rotation.x = _pitch

	# Only the step-up is smoothed, never ordinary vertical motion. Damping
	# jumps and falls the same way would feel floaty and would leave the
	# camera behind exactly when you most need it with you.
	#
	# The offset goes on the model as well as the camera. The collision body
	# has to be up there — physics needs it — but nothing you actually look at
	# does, and smoothing the camera alone just detaches it from a robot that
	# is still popping.
	_step_offset = lerpf(_step_offset, 0.0, 1.0 - pow(0.5, delta * STEP_SMOOTH))
	pivot.position.y = CAM_HEIGHT - _step_offset
	body.position.y = -_step_offset

	var want := 0.0 if _first_person else CAM_DISTANCE
	if not _first_person:
		# Pull the camera in if the wall behind us is closer than the arm.
		# +Z is *behind* the pivot, because Godot faces -Z.
		var from := pivot.global_position
		var to := pivot.global_transform * Vector3(0.0, 0.0, CAM_DISTANCE)

		# A sphere, not a ray. A ray is infinitely thin, so it slides straight
		# through the gap between two wall segments and leaves the camera
		# parked inside the wall beside it — which is how you end up staring
		# at masonry with the game happening somewhere behind it.
		var ball := SphereShape3D.new()
		ball.radius = CAM_RADIUS
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ball
		q.transform = Transform3D(Basis(), from)
		q.motion = to - from
		q.exclude = [get_rid()]
		# World only. A bug walking behind you must not shove the view into
		# the back of your own head at the exact moment you need to see it.
		q.collision_mask = Layers.WORLD

		# cast_motion returns [safe, unsafe] as fractions of the motion.
		var hit := get_world_3d().direct_space_state.cast_motion(q)
		if hit.size() == 2:
			want = CAM_DISTANCE * hit[0]

	# Snap in instantly when something intrudes, ease back out when it clears —
	# a camera that lerps *into* a wall clips through it for a few frames.
	if want < _arm:
		_arm = want
	else:
		_arm = lerp(_arm, want, 1.0 - pow(0.5, delta * CAM_LAG))

	camera.position = Vector3(0.0, 0.0, _arm)
	_set_inside_view(_arm <= 0.5)


## Hide as little as the model allows. If we found a head, hide only that and
## you keep your body and your weapon in view from inside. If we did not — the
## placeholder capsule, or a character whose parts are named differently, or
## one skinned mesh that cannot be split at all — fall back to hiding
## everything, which is what this used to do unconditionally.
func _set_inside_view(inside: bool) -> void:
	if _head_parts.is_empty():
		body.visible = not inside
		return
	body.visible = true
	for p in _head_parts:
		p.visible = not inside


## If the model you dropped in has animations called idle / walk / run, they
## get driven here. Names that do not exist are simply skipped, so a model
## with no AnimationPlayer costs nothing.
## Ground poses, plus an air state. Everything degrades: a model with only
## an idle still works, a model with jump but no fall holds the jump, and one
## with no air clips at all just keeps using the ground poses mid-air.
const LAND_HOLD := 0.22   ## seconds the landing clip is protected for

func _animate(delta: float) -> void:
	if _anim == null:
		return

	# Death outranks everything and never releases.
	if _dead:
		return
	# Being bitten outranks a swing, which outranks locomotion. Without the
	# hold the walk stamps on the hit clip the frame after it starts.
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	if _hurt_left > 0.0:
		_hurt_left -= delta
		if _hurt_left > 0.0:
			return
	# Mid-step we are off the floor by construction, so without this a stair
	# climb plays as a jump.
	var grounded := is_on_floor() or _stepping > 0.0

	# --- touchdown. Hold the landing briefly or the walk that follows stamps
	# on it the very next frame and you never see it.
	if grounded and _airborne:
		_airborne = false
		if _attack == "" and _clip_land != "":
			_land_left = LAND_HOLD
			_play(_clip_land)
			return
	_airborne = not grounded

	if _land_left > 0.0:
		_land_left -= delta
		if _land_left > 0.0:
			return

	# --- mid-swing. Outranks walking and outranks the air poses, because the
	# locomotion below would otherwise stamp on the attack the frame after it
	# starts and you would never see the swing at all. Same reason the landing
	# clip is held above.
	if _attack != "":
		_attack_left -= delta
		if _attack_left > 0.0:
			return
		_attack = ""

	# --- in the air
	if not grounded:
		var air := _clip_jump
		if velocity.y < 0.0 and _clip_fall != "":
			air = _clip_fall
		if air != "":
			_play(air)
			return
		# nothing airborne to play: fall through and keep the ground pose

	# --- on the ground
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var want := _clip_idle
	if planar > RUN_SPEED * 0.7:
		want = _clip_run
	elif planar > 0.35:
		want = _clip_walk

	if want == "":
		# No idle clip in this model. Holding the first frame of the walk
		# reads far better than the rest pose, which for a rigged character
		# is a T-pose. Make an idle action in Blender and this goes away.
		if _clip_walk == "":
			return
		if not _idle_held:
			# speed_scale rather than pause(): a paused player reports itself
			# as not playing and drops current_animation, which makes this
			# state impossible to reason about. Frozen-but-playing is honest.
			_anim.play(_clip_walk)
			_anim.seek(0.0, true)
			_anim.speed_scale = 0.0
			_idle_held = true
		return
	_play(want)


## restart forces the clip back to frame 0 even if it is already the current
## one. Swinging twice in a row needs that; without it the second thrust is
## swallowed because the AnimationPlayer is already playing "attack.thrust".
func _play(clip: String, restart := false) -> void:
	if _idle_held:
		_anim.speed_scale = 1.0
		_idle_held = false
	if restart:
		_anim.play(clip)
		_anim.seek(0.0, true)
	elif _anim.current_animation != clip:
		_anim.play(clip)
