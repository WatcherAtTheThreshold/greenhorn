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
## How tall a ledge the character will walk up without jumping. This is THE
## number that decides whether stairs work. Godot's CharacterBody3D will not
## climb a vertical riser on its own, so we do it manually below.
const STEP_HEIGHT     := 0.45

# --- camera -----------------------------------------------------------------
const CAM_DISTANCE    := 2.25     ## metres behind the head in third person
const CAM_HEIGHT      := 1.55     ## pivot height — roughly eye level
const CAM_MIN_PITCH   := -1.25    ## radians (looking up)
const CAM_MAX_PITCH   := 1.05     ## radians (looking down)
const CAM_SENS        := 0.0025   ## radians per pixel of mouse movement
const CAM_LAG         := 12.0     ## how quickly the arm settles; higher = tighter
const CAM_PUSH_MARGIN := 0.25     ## keep the camera this far off any wall it hits

## Parts to hide when the camera is inside the character's head — first person,
## and also when a wall shoves the arm all the way in.
##
## Hiding the head rather than the whole body is only possible because Tim is
## 27 separately named objects instead of one skinned mesh. It means first
## person keeps your own arms, torso and the sword swinging in front of you,
## with no second model and no second set of animations. Names that are not in
## the model are simply skipped, so this costs nothing on other characters.
const HEAD_PARTS: Array[String] = ["head", "eye1", "eye2", "mouth"]

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
var _attack := ""          ## clip currently swinging, "" when not attacking
var _attack_left := 0.0    ## seconds of it still to play
var _attack_len := 0.0     ## its full length, for the cancel window
var _idle_held := false
var _airborne := false
var _land_left := 0.0
var _head_parts: Array[Node3D] = []


func _ready() -> void:
	_spawn = global_position
	pivot.position.y = CAM_HEIGHT
	floor_snap_length = 0.6          # keeps us glued going DOWN stairs and ramps
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

	_anim = _find_anim(body)
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

	_equip(weapon_file, WEAPON_BONE)


const MODEL_DIR := "res://assets/blender/"

## Put something in Body, by whichever route is available.
func _adopt_model() -> void:
	if character_scene:
		body.add_child(character_scene.instantiate())
		return

	for c in body.get_children():
		if c != placeholder and c is Node3D and (c as Node3D).visible:
			return                      # already dragged in by hand

	var dir := DirAccess.open(MODEL_DIR)
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
		var res := load(MODEL_DIR + n)
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


## Hang a BoneAttachment3D off a named bone and return it, or null.
##
## This is code rather than a node dragged into player.tscn because the model
## is not in the scene file at all — _adopt_model() loads it at runtime, so
## there is no Skeleton3D to parent anything to until the game is running.
## Same reason the world is built in code: nothing to re-wire when the asset
## changes.
func _socket(bone: String) -> BoneAttachment3D:
	var skels := body.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_warning("greenhorn: no Skeleton3D, so no socket '%s'" % bone)
		return null
	var skel := skels[0] as Skeleton3D

	if skel.find_bone(bone) == -1:
		# Say what IS there. A missing socket bone is nearly always the glTF
		# exporter's Armature > Export Deformation Bones Only, which drops
		# every non-deform bone silently — and a socket bone is non-deform by
		# definition, so that tick removes exactly the bones you added.
		var have: Array[String] = []
		for i in skel.get_bone_count():
			have.append(skel.get_bone_name(i))
		push_warning(("greenhorn: bone '%s' is not in the rig. " % bone)
			+ "If your sockets are missing but the limbs are here, untick "
			+ "Armature > Export Deformation Bones Only and re-export.\n"
			+ "Skeleton has %d bones: %s" % [have.size(), ", ".join(have)])
		return null

	# An unapplied Object Mode scale on the Blender armature rides all the way
	# through to here. The character still looks right, because its meshes are
	# children of that armature and were shrunk by the same amount — but a
	# socketed prop is NOT, so it arrives at true size and is then scaled down
	# with everything else, which reads as "the sword is too small".
	#
	# Report it, do not correct it. A silent counter-scale here would make the
	# weapon wrong again the moment the .blend is fixed properly.
	var s := skel.global_transform.basis.get_scale()
	if not s.is_equal_approx(Vector3.ONE):
		push_warning(("greenhorn: the skeleton carries a scale of %v, so "
			+ "anything on '%s' renders at that fraction of its true size. "
			+ "Fix it in Blender with Ctrl+A > All Transforms on the armature "
			+ "and its meshes, rather than by resizing the weapon.")
			% [s, bone])

	var at := BoneAttachment3D.new()
	at.name = "socket_" + bone.replace(".", "_")  # dots are illegal in node names
	skel.add_child(at)     # must be parented before bone_name can resolve
	at.bone_name = bone
	return at


## Put a model in a socket. No rig, no skinning — it inherits the bone's
## transform every frame, which is the whole trick.
func _equip(file: String, bone: String) -> void:
	if file == "":
		return
	var res := load(MODEL_DIR + file)
	if not (res is PackedScene):
		push_warning("greenhorn: %s is not a scene, cannot equip it" % file)
		return
	var at := _socket(bone)
	if at == null:
		return
	at.add_child((res as PackedScene).instantiate())


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	# Skip anything switched off in the editor. An old hidden copy of the
	# model would otherwise win the search and animate invisibly, while the
	# visible one stood there in its rest pose looking broken.
	if n is Node3D and not (n as Node3D).visible:
		return null
	for c in n.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null


## Start a swing. Silently does nothing if the model has no such clip, so a
## rig with only a thrust still works on left click and right click is simply
## inert rather than an error.
func _swing(clip: String) -> void:
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
	_play(clip, true)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= e.relative.x * CAM_SENS
		_pitch = clamp(_pitch - e.relative.y * CAM_SENS, CAM_MIN_PITCH, CAM_MAX_PITCH)
	elif e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED)
	elif e.is_action_pressed("cam_toggle"):
		_first_person = not _first_person
	elif e.is_action_pressed("respawn"):
		global_position = _spawn
		velocity = Vector3.ZERO
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
	_animate(delta)


func _move(delta: float) -> void:
	# --- input, rotated into camera space so "forward" means "away from me" ---
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
	move_and_slide()

	# face the way we are travelling
	if wish != Vector3.ZERO:
		var want := atan2(-wish.x, -wish.z)
		body.rotation.y = rotate_toward(body.rotation.y, want, TURN_RATE * delta)


## Godot will happily walk you up a 45 degree ramp and then refuse a 10 cm
## step, because a stair riser is a vertical wall as far as the solver is
## concerned. So: if we are grounded and something is blocking us, check
## whether lifting by STEP_HEIGHT clears it. If it does it was a step, not a
## wall — lift, and let floor snapping settle us onto the tread.
func _try_step(delta: float) -> void:
	if not is_on_floor():
		return
	var horiz := Vector3(velocity.x, 0.0, velocity.z) * delta
	if horiz.length_squared() < 1e-8:
		return
	if not test_move(global_transform, horiz):
		return                                   # nothing in the way
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return                                   # no headroom to step into
	if test_move(global_transform.translated(lift), horiz):
		return                                   # still blocked up there: a wall
	global_position += lift


func _update_camera(delta: float) -> void:
	pivot.rotation.y = _yaw
	pivot.rotation.x = _pitch

	var want := 0.0 if _first_person else CAM_DISTANCE
	if not _first_person:
		# Pull the camera in if the wall behind us is closer than the arm.
		# +Z is *behind* the pivot, because Godot faces -Z.
		var from := pivot.global_position
		var to := pivot.global_transform * Vector3(0.0, 0.0, CAM_DISTANCE)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			want = max(0.4, from.distance_to(hit.position) - CAM_PUSH_MARGIN)

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
	var grounded := is_on_floor()

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
