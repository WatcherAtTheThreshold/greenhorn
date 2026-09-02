extends RefCounted
class_name Socket

## Hanging an unrigged prop off a bone.
##
## The sword in Tim's hand and the shell on the bug's back are the same
## technique pointed in opposite directions, so it lives in one place rather
## than being written twice. Nothing socketed is ever skinned or rigged: it
## inherits the bone's transform every frame, and that is the whole trick.
##
## This is code rather than a BoneAttachment3D dragged into a scene because no
## model is in a .tscn at all — every one of them is loaded at runtime, so
## there is no Skeleton3D to parent anything to until the game is running.

const MODEL_DIR := "res://assets/blender/"


## The combined bounds of everything visible under a node, in that node's own
## local space. Size stays zero if there was nothing to measure.
##
## Used to fit a hitbox to a weapon and a collider to a broken-off shell —
## measured off the mesh rather than typed in, so a bigger prop is a bigger
## shape with no number to keep in sync. Same instinct as the plinth captions
## counting vertices instead of trusting a table.
static func local_aabb(root: Node3D) -> AABB:
	var parts := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		parts.append(root)          # a single-mesh .blend imports as one node
	var inv := root.global_transform.affine_inverse()
	var box := AABB()
	var got := false
	for c in parts:
		var mi := c as MeshInstance3D
		# Relative to root, so this does not care where the bone happens to be
		# posed on the frame we measure.
		var ab := (inv * mi.global_transform) * mi.get_aabb()
		box = ab if not got else box.merge(ab)
		got = true
	return box


## Hang a BoneAttachment3D off a named bone somewhere under `root`, and return
## it, or null. `root` is whatever node the model was mounted under.
static func make(root: Node, bone: String) -> BoneAttachment3D:
	var skels := root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_warning("greenhorn: nothing rigged under %s, so no socket '%s'"
			% [root.name, bone])
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
	# prop wrong again the moment the .blend is fixed properly.
	var s := skel.global_transform.basis.get_scale()
	if not s.is_equal_approx(Vector3.ONE):
		push_warning(("greenhorn: the skeleton under %s carries a scale of %v, "
			+ "so anything on '%s' renders at that fraction of its true size. "
			+ "Fix it in Blender with Ctrl+A > All Transforms on the armature "
			+ "and its meshes, rather than by resizing the prop.")
			% [root.name, s, bone])

	var at := BoneAttachment3D.new()
	at.name = "socket_" + bone.replace(".", "_")  # dots are illegal in node names
	skel.add_child(at)     # must be parented before bone_name can resolve
	at.bone_name = bone
	return at


## Put a model from assets/blender/ into a socket. Returns the instance so the
## caller can keep hold of it — breaking the shell later means reparenting
## exactly this node onto a RigidBody3D.
static func equip(root: Node, file: String, bone: String) -> Node:
	if file == "":
		return null
	var res := load(MODEL_DIR + file)
	if not (res is PackedScene):
		push_warning("greenhorn: %s is not a scene, cannot equip it" % file)
		return null
	var at := make(root, bone)
	if at == null:
		return null
	var inst: Node = (res as PackedScene).instantiate()
	at.add_child(inst)
	return inst
