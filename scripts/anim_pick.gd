extends RefCounted
class_name AnimPick

## Blender rarely hands you actions named exactly idle / walk / run. You get
## walk_001, walk_002, Armature|Walk, and usually a one-frame stray left over
## from experimenting. So match on prefix rather than equality, and among the
## matches take the LONGEST — which reliably skips the stray.

## Letters and digits only, lowercased, so separators stop mattering.
##
## Godot's glTF importer runs every animation name through
## validate_node_name(), which DELETES the characters that are illegal in node
## names — and "." is one of them. A Blender action called attack.thrust
## therefore arrives in the AnimationPlayer as "attackthrust", so asking for
## it by its Blender name finds nothing, while idle and walk work perfectly
## because they have no punctuation to lose. That is a genuinely baffling
## failure to sit and stare at, so absorb it here: attack.thrust,
## attack_thrust, attack-thrust and attackThrust all normalise to the same
## thing and all match.
static func _norm(s: String) -> String:
	var out := ""
	for c in s.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


static func find(ap: AnimationPlayer, want: String) -> String:
	if ap == null:
		return ""
	if ap.has_animation(want):
		return want
	var best := ""
	var best_len := -1.0
	var target := _norm(want)
	for name: String in ap.get_animation_list():
		# tolerate Blender's "Armature|Walk" style as well as "walk_002"
		var tail := name.get_slice("|", name.get_slice_count("|") - 1)
		if not (_norm(name).begins_with(target) or _norm(tail).begins_with(target)):
			continue
		var a := ap.get_animation(name)
		var dur := a.length if a else 0.0
		if dur > best_len:
			best_len = dur
			best = name
	return best


## Make an animation loop. Imported clips default to no looping, so a walk
## cycle plays once and freezes on the last frame.
static func loop(ap: AnimationPlayer, name: String) -> void:
	set_loop(ap, name, true)


## Explicit loop control. Cycles loop; one-shots like a jump or a landing must
## not, or the character bounces on the spot for as long as it is in the air.
static func set_loop(ap: AnimationPlayer, name: String, on: bool) -> void:
	if ap == null or name == "":
		return
	var a := ap.get_animation(name)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR if on else Animation.LOOP_NONE
