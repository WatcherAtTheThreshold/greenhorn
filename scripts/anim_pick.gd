extends RefCounted
class_name AnimPick

## Blender rarely hands you actions named exactly idle / walk / run. You get
## walk_001, walk_002, Armature|Walk, and usually a one-frame stray left over
## from experimenting. So match on prefix rather than equality, and among the
## matches take the LONGEST — which reliably skips the stray.

static func find(ap: AnimationPlayer, want: String) -> String:
	if ap == null:
		return ""
	if ap.has_animation(want):
		return want
	var best := ""
	var best_len := -1.0
	var target := want.to_lower()
	for name: String in ap.get_animation_list():
		var n := name.to_lower()
		# tolerate Blender's "Armature|Walk" style as well as "walk_002"
		var tail := n.get_slice("|", n.get_slice_count("|") - 1)
		if not (n.begins_with(target) or tail.begins_with(target)):
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
