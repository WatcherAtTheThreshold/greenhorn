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
const CAM_DISTANCE    := 4.5      ## metres behind the head in third person
const CAM_HEIGHT      := 1.55     ## pivot height — roughly eye level
const CAM_MIN_PITCH   := -1.25    ## radians (looking up)
const CAM_MAX_PITCH   := 1.05     ## radians (looking down)
const CAM_SENS        := 0.0025   ## radians per pixel of mouse movement
const CAM_LAG         := 12.0     ## how quickly the arm settles; higher = tighter
const CAM_PUSH_MARGIN := 0.25     ## keep the camera this far off any wall it hits

## Drop a rigged model here in the inspector and it replaces the placeholder.
## Anything with an AnimationPlayer gets driven automatically (see _animate).
@export var character_scene: PackedScene

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

	if character_scene:
		var inst := character_scene.instantiate()
		body.add_child(inst)
		placeholder.visible = false
		_anim = _find_anim(inst)
		_clip_idle = AnimPick.find(_anim, "idle")
		_clip_walk = AnimPick.find(_anim, "walk")
		_clip_run  = AnimPick.find(_anim, "run")
		# no walk but a run? use it for both rather than standing frozen
		if _clip_walk == "":
			_clip_walk = _clip_run
		if _clip_run == "":
			_clip_run = _clip_walk
		for c in [_clip_idle, _clip_walk, _clip_run]:
			AnimPick.loop(_anim, c)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null


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
	elif e is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if global_position.y < -12.0:          # walked off the edge of the world
		global_position = _spawn
		velocity = Vector3.ZERO
	_move(delta)
	_update_camera(delta)
	_animate()


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
	body.visible = not _first_person or _arm > 0.5


## If the model you dropped in has animations called idle / walk / run, they
## get driven here. Names that do not exist are simply skipped, so a model
## with no AnimationPlayer costs nothing.
func _animate() -> void:
	if _anim == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var want := _clip_idle
	if planar > RUN_SPEED * 0.7:
		want = _clip_run
	elif planar > 0.35:
		want = _clip_walk
	if want == "":
		# nothing suitable — hold the rest pose rather than a frozen frame
		if _anim.is_playing():
			_anim.stop()
		return
	if _anim.current_animation != want:
		_anim.play(want)
