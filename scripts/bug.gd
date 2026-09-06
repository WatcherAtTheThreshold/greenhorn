extends CharacterBody3D
class_name Bug

## Fired once, when this one goes down. The world counts them to decide when a
## wave is over.
signal died(bug: Bug)

## A beetle that walks at you, wearing its shell on a socket bone.
##
## Built in code and spawned by world.gd rather than authored as a .tscn, for
## the same reason the plot is: there will eventually be a dozen of these, and
## a scene file is a thing to drag rather than a number to change.
##
## It cannot hurt you and you cannot hurt it yet. That is deliberate — M2 asks
## whether cracking a shell is satisfying, and you can answer half of that by
## watching one walk at you wearing the thing you are going to break.

# --- feel -------------------------------------------------------------------
const ACCEL       := 8.0    ## m/s^2 toward target velocity
const FRICTION    := 10.0   ## m/s^2 when it has nowhere to go
const TURN_RATE   := 3.5    ## rad/s — sluggish on purpose, so you can circle it
const GRAVITY     := 18.0   ## matches the player, so falls read the same
const STOP_RANGE  := 1.2    ## metres. It has no attack, so it stops short

# --- body -------------------------------------------------------------------
## The collision capsule, not the model. A tiger beetle measures 1.14 m wide,
## 1.38 long and only 0.49 tall, so this is deliberately smaller than the
## beetle looks — a capsule is a poor fit for something that flat, and one
## sized to the legs would stop you well before you could see yourself reach
## it. It also will not catch on the stair nosings the way a box would.
const BODY_RADIUS := 0.32
const BODY_HEIGHT := 0.7

# --- what makes one beetle different from another ---------------------------
## Exports rather than consts, because a boss is the same beetle with bigger
## numbers. Everything else on this script stays a const: these five are the
## only things a species varies by, and keeping the list short is what stops
## "one enemy type, tuned" turning into a class hierarchy.
##
## Swings it takes to kill, at the player's current damage. Your doc's open
## question is whether a shell should go in one hit or several — one is
## simpler, several is probably the better game.
@export var max_health := 3
## Hits the shell survives. On this one it comes off — so at 3 health and 2
## here, the beetle takes a hit, loses its shell on the second, dies on the
## third.
@export var shell_hits := 2
## Uniform scale of the model and its collision. Reach, stopping distance and
## bite range all scale with it, so a big beetle has genuinely longer jaws
## rather than a big model with a small bite.
@export var size := 1.0
## What one bite costs. The player has five.
@export var bite_damage := 1
## m/s. Well under the player's amble, so you can always leave.
@export var walk_speed := 1.8

# --- being hit --------------------------------------------------------------
## Feedback, in the order it matters. None of this is animation: a flash, a
## shove and a moment of near-frozen time do more for weight than a hit
## reaction clip, and they are a few lines each. If a `hit` clip exists in the
## model it plays on top of these, but nothing here needs one.
const FLASH_TIME := 0.06   ## seconds the model blinks white
const KNOCKBACK  := 4.5    ## m/s shove, straight away from whoever hit it
const HIT_HOLD   := 0.25   ## seconds it stops steering — used if there is no hit clip

## How hard the shell leaves. LIFT is the more important of the three: a shell
## that slides reads as debris, one that tumbles up and over reads as broken.
##
## SPREAD only does anything if the shell is more than one object. Each piece
## is pushed outward from the shell's own middle as well as away from the
## blow, so two halves part company instead of travelling as a pair.
const SHELL_POP    := 3.0
const SHELL_LIFT   := 4.0
const SHELL_SPREAD := 2.0

# --- biting -----------------------------------------------------------------
## Where in the `attack` clip the mandibles are actually closing, as fractions
## of it. Measured, not guessed: the clip is 24 frames and the bite runs 12 to
## 18 — jaws open at 12, shut at 18.
##
## Everything before BITE_FROM is the telegraph: the rear-up, the legs and
## antennae lifting, the jaws opening wide. That half-second is the whole
## fight. Shorten it and this becomes a reaction test you lose by luck;
## lengthen it and the bite is free to walk away from.
const BITE_FROM     := 0.5
const BITE_TO       := 0.75

## How close it has to be to start. Comfortably beyond STOP_RANGE, so it
## commits from where it stands rather than shuffling into contact first.
const BITE_RANGE    := 1.9
## How far the jaws actually reach when they close. Shorter than BITE_RANGE on
## purpose — back off during the telegraph and the bite misses, which is what
## makes the telegraph worth reading.
const BITE_REACH    := 1.5
## Half-angle of the bite, in front of it. Mandibles are on the front of a
## beetle, so the bite is a wedge rather than a sphere.
##
## Without this the bite lands anywhere within reach, including behind — so
## stepping to the flank during the wind-up does nothing and the only escape
## is straight backwards. That is fine on a small beetle you out-reach, and
## unplayable on a big one whose jaws arrive from three metres out, because
## retreating is then the only answer and you can never close again.
##
## With it, a big slow beetle becomes a positioning problem: do not stand in
## front of it. Which is the fight worth having.
const BITE_ARC      := 1.0   ## radians ~ 57 degrees either side of straight ahead
## Seconds between attempts, on top of the clip itself.
const BITE_COOLDOWN := 1.1


@export var model_file := "tiger-beetle.blend"
## The carapace. Never skinned, never rigged — it rides SHELL_BONE, and
## breaking it reparents _shell onto a RigidBody3D.
##
## Two objects in one file, so it breaks into two halves that part company.
@export var shell_file := "props/tiger-beetle-shell.blend"
## The bone that carapace rides. Every rig uses the same name, because it is a
## role rather than a file — which is what lets the roster table drop a column
## and a new species be two strings instead of three.
##
## It briefly was not: one rig called it `shell2.socket`, after the file
## version of the shell it happened to be wearing. That coupled a rig to a
## filename, and rigs are the expensive thing to change.
##
## An export rather than a const anyway, so a species that genuinely needs a
## different mount can have one without a special case.
@export var shell_bone := "shell.socket"

## Who to walk at. world.gd hands us the player. Without one the bug just
## stands there idling, which is a perfectly good way to look at it.
var target: Node3D = null

var _model: Node3D = null
var _shell: Node = null
var _anim: AnimationPlayer = null
var _clip_idle := ""
var _clip_walk := ""
var _clip_death := ""
var _clip_hit := ""
var _clip_attack := ""
var _bite_left := 0.0       ## seconds of the attack clip still to run
var _bite_len := 0.0
var _bite_wait := 0.0       ## cooldown before it may try again
var _bit := false           ## this bite has already landed
var _dead := false
var _health := 0
var _flash_left := 0.0
var _hit_left := 0.0            ## staggered: not steering, so the shove reads
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D = null


func _ready() -> void:
	# Seeded here, not at declaration: world.gd sets max_health after new() and
	# before add_child, so an initialiser would capture the default instead.
	_health = max_health

	# Size goes on the capsule and on the model holder, never on this body.
	# Scaling a CharacterBody3D works with Jolt while the scale stays uniform,
	# but it is one more thing that has to stay uniform forever, and there is
	# nothing to gain from it.
	var cap := CapsuleShape3D.new()
	cap.radius = BODY_RADIUS * size
	cap.height = BODY_HEIGHT * size
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = BODY_HEIGHT * size * 0.5   # the model's origin is at its feet
	add_child(col)

	collision_layer = Layers.CHARACTER
	collision_mask = Layers.SOLID
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)     # same slope tolerance as the player

	_mount_model()
	_wear_shell()


func _mount_model() -> void:
	var res := load(Socket.MODEL_DIR + model_file)
	if not (res is PackedScene):
		push_warning("greenhorn: bug model %s did not load" % model_file)
		return
	# A holder rather than adding the model straight to self, so the shell
	# search and any future material flash have one node to work from.
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3(size, size, size)
	add_child(_model)
	_model.add_child((res as PackedScene).instantiate())

	_anim = AnimPick.find_player(_model)
	if _anim == null:
		return
	_clip_idle  = AnimPick.find(_anim, "idle")
	_clip_walk  = AnimPick.find(_anim, "walk")
	_clip_death = AnimPick.find(_anim, "death")
	# Optional. Make an action called `hit` in Blender and it plays on impact;
	# without one the flash and the shove carry it on their own.
	_clip_hit    = AnimPick.find(_anim, "hit")
	_clip_attack = AnimPick.find(_anim, "attack")
	for cycle: String in [_clip_idle, _clip_walk]:
		AnimPick.loop(_anim, cycle)
	for once: String in [_clip_death, _clip_hit, _clip_attack]:
		AnimPick.set_loop(_anim, once, false)      # dying twice is worse value
	if _clip_death == "":
		push_warning("greenhorn: bug has no death clip. It has: %s"
			% ", ".join(_anim.get_animation_list()))


func _wear_shell() -> void:
	if _model == null:
		return
	_shell = Socket.equip(_model, shell_file, shell_bone)
	_collect_meshes()


## Everything the flash paints. Re-collected when the shell comes off, or the
## flash would keep blinking a carapace that is lying on the grass.
func _collect_meshes() -> void:
	_meshes.clear()
	if _model == null:
		return
	for c in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(c as MeshInstance3D)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	if _hit_left > 0.0:
		_hit_left -= delta

	if _bite_wait > 0.0:
		_bite_wait -= delta
	_bite(delta)

	# Steer flat. Chasing the player's actual position would make it try to
	# climb you when you stand on a plinth.
	var wish := Vector3.ZERO
	if target != null and not _dead and _hit_left <= 0.0 and _bite_left <= 0.0:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > STOP_RANGE * size:
			wish = to.normalized()

	var want := wish * walk_speed
	var rate := ACCEL if wish != Vector3.ZERO else FRICTION
	velocity.x = move_toward(velocity.x, want.x, rate * delta)
	velocity.z = move_toward(velocity.z, want.z, rate * delta)

	move_and_slide()

	# Face the way we are travelling. Blender models are built facing -Y,
	# which arrives as Godot's -Z, so this is the same maths the player uses.
	if wish != Vector3.ZERO:
		rotation.y = rotate_toward(rotation.y, atan2(-wish.x, -wish.z),
			TURN_RATE * delta)

	_animate()


## Commit to a bite, run it, and land it if the jaws close on anything.
##
## Range is checked once, at the start. After that the beetle is committed —
## it does not track you through the swing, so backing off during the
## telegraph is a real answer rather than a delay. That is the whole reason
## the wind-up exists.
func _bite(delta: float) -> void:
	if _dead or target == null or _clip_attack == "" or _anim == null:
		return

	if _bite_left > 0.0:
		var was := _bite_left
		_bite_left -= delta
		# Land it once, the first frame inside the window the jaws are closing.
		var t := 1.0 - (was / _bite_len)
		if not _bit and t >= BITE_FROM and t <= BITE_TO:
			var flat := target.global_position - global_position
			flat.y = 0.0
			if flat.length() <= BITE_REACH * size and flat.length() > 0.001 \
					and target.has_method("hurt"):
				# In front, not merely near. It committed to a direction at the
				# start of the wind-up and does not track, so getting to its
				# flank while the jaws are open is a real answer.
				var facing := -global_transform.basis.z
				facing.y = 0.0
				if facing.angle_to(flat) <= BITE_ARC:
					_bit = true
					target.hurt(bite_damage, global_position)
		return

	if _bite_wait > 0.0 or _hit_left > 0.0:
		return
	var gap := target.global_position - global_position
	gap.y = 0.0
	if gap.length() > BITE_RANGE * size:
		return

	var a := _anim.get_animation(_clip_attack)
	if a == null:
		return
	_bite_len = a.length
	_bite_left = a.length
	_bite_wait = a.length + BITE_COOLDOWN
	_bit = false
	# Face what it is about to bite. A telegraph you cannot see the front of
	# is not a telegraph.
	rotation.y = atan2(-gap.x, -gap.z)
	_anim.play(_clip_attack)
	_anim.seek(0.0, true)


func _animate() -> void:
	# Hold the hit and attack clips, or the walk stamps on them the very next
	# frame — the same trap the player's swings and landings have.
	if _anim == null or _dead or _hit_left > 0.0 or _bite_left > 0.0:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var clip := _clip_walk if planar > 0.15 else _clip_idle
	if clip == "" or _anim.current_animation == clip:
		return
	_anim.play(clip)


## Take a swing. Anything that can be hit answers to this, which is why
## player.gd checks for the method rather than for a Bug — the next enemy
## needs no changes over there. `from` is where the blow came from, so the
## shove and the shell both go the right way.
func hurt(amount: int, from: Vector3) -> void:
	if _dead:
		return
	_health -= amount

	# Flash first: it is the one that tells you the hit registered even when
	# everything else is obscured by the swing itself.
	_flash_left = FLASH_TIME
	_set_flash(true)

	# Shove, straight away and flat. Vertical knockback on a ground enemy just
	# makes it hop, which reads as comic rather than heavy.
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.001:
		velocity += away.normalized() * KNOCKBACK

	# A hit cancels a bite in progress. Without this you can watch the jaws
	# open, land a clean chop, and still get bitten — which teaches the player
	# that reading the telegraph does not work.
	#
	# Worth revisiting once the shell means something: an armoured beetle that
	# cannot be interrupted until you have cracked it is the same mechanic
	# doing thematic work.
	_bite_left = 0.0
	_bit = false

	# Stop steering for a moment, or it walks straight back into you and the
	# shove never reads at all.
	_hit_left = HIT_HOLD
	if _clip_hit != "" and _anim != null:
		var a := _anim.get_animation(_clip_hit)
		if a != null:
			_hit_left = a.length
		_anim.play(_clip_hit)
		_anim.seek(0.0, true)

	if max_health - _health >= shell_hits:
		_break_shell(from)

	if _health <= 0:
		die()


## Take the shell off and let it clatter away.
##
## No animation, no shape keys, no second model: the nodes that were riding
## the bone get reparented onto RigidBody3Ds and pushed. Every break is
## different because it inherits the direction of the blow, which is more than
## a clip could do and costs a fraction of the work.
##
## Every top-level object in shell.blend becomes its own body. One object
## gives one lump; two half-shells give two that part company as they go. How
## many pieces a shell breaks into is decided in Blender, not here.
func _break_shell(from: Vector3) -> void:
	var node := _shell as Node3D
	_shell = null
	if node == null:
		return

	# It leaves mid-flash, and once it is off nothing here holds a reference
	# to clear it again — so give it its own colour back before it goes, or
	# there is a permanently white carapace lying on the grass.
	for c in node.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = null
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = null

	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.001 else Vector3.BACK

	var middle := node.global_transform * Socket.local_aabb(node).get_center()
	var pieces := _shell_pieces(node)
	for piece in pieces:
		_launch(piece, away, middle)

	# The empty holder the pieces hung from is no use to anyone now.
	if not pieces.has(node) and is_instance_valid(node):
		node.queue_free()

	_collect_meshes()


## The independently-flying parts of a shell: the top-level objects in the
## .blend, or the thing itself if it is a single mesh.
func _shell_pieces(root: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if root is MeshInstance3D:
		out.append(root)
		return out
	for c in root.get_children():
		var n := c as Node3D
		if n == null:
			continue
		if n is MeshInstance3D or not n.find_children(
				"*", "MeshInstance3D", true, false).is_empty():
			out.append(n)
	if out.is_empty():
		out.append(root)          # nothing recognisable in there; throw the lot
	return out


## Cut one piece loose onto its own RigidBody3D and shove it.
func _launch(piece: Node3D, away: Vector3, middle: Vector3) -> void:
	var box := Socket.local_aabb(piece)
	if box.size.length() <= 0.0:
		return

	# Measured before the reparent, while the piece still knows where it is.
	var xf := piece.global_transform
	var centre := xf * box.get_center()

	var rb := RigidBody3D.new()
	rb.name = "ShellDebris"
	# Off the world layer on purpose: debris must never shove the camera.
	rb.collision_layer = Layers.DEBRIS
	rb.collision_mask = Layers.WORLD | Layers.CHARACTER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.position = box.get_center()
	rb.add_child(cs)

	# Into the world, not under the bug — a corpse that walks away carrying
	# its own broken shell rather defeats the point.
	get_parent().add_child(rb)
	rb.global_transform = xf
	piece.reparent(rb, true)

	var out := centre - middle
	out.y = 0.0
	out = out.normalized() if out.length() > 0.001 else Vector3.ZERO

	rb.linear_velocity = away * SHELL_POP + out * SHELL_SPREAD + Vector3.UP * SHELL_LIFT
	rb.angular_velocity = Vector3(randf_range(-7.0, 7.0),
		randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))


func _set_flash(on: bool) -> void:
	if on and _flash_mat == null:
		_flash_mat = Palette.unshaded(Palette.HIT_FLASH)
	for mi in _meshes:
		mi.material_override = _flash_mat if on else null


## Stop walking and play the death clip.
func die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	if _anim != null and _clip_death != "":
		_anim.play(_clip_death)
	died.emit(self)


## Whether this one can actually hurt you. It comes down to whether the model
## brought an `attack` clip: rain beetles did not, so one walks at you and
## never bites.
##
## Only answers correctly once the model is mounted, which happens in _ready.
func is_hostile() -> bool:
	return _clip_attack != ""
