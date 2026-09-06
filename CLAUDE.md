# Greenhorn — Claude Code guide

A sunlit 3D test world in **Godot 4.7** (GDScript, Forward+, Jolt). Its job is
validating a Blender-to-Godot pipeline, not being a game. Bias every decision
toward "does this help you see whether the model is right."

## Working style

- The world is **built in code** (`scripts/world.gd`), not authored as a
  `.tscn`. Keep it that way: constants and loops, no node-dragging, nothing to
  merge-conflict.
- Balance and feel values live as `const` at the top of the script that uses
  them, so playtest feedback is a one-number change.
- Typed GDScript. `:=` cannot infer from untyped sources — type loop
  variables explicitly (`for deg: float in angles`).
- Every colour comes from `Palette` (`scripts/palette.gd`). Never hardcode a
  colour anywhere else; the whole point is being able to re-grade in one file.
- Commit `.uid` and `.import` sidecars. Never commit `.godot/`.

## Naming assets

**A filename names the thing, never the version.** Git holds versions. A
`Tim2.blend` next to an archived `Tim.blend` is doing by hand what the repo
does for free, and it leaks: one shell version produced a bone called
`shell2.socket`, coupling a rig to a filename.

**Number the interchangeable, name the distinguished.** `tree1` and `rock1`
are fine — they are slots, more are coming, and nobody looks at a tree and
cares which. Anything the player tells apart gets a real name: species,
weapons, characters.

**Pair by name, not by number.** `tiger-beetle` wears `tiger-beetle-shell`.
The roster in `world.gd` is the actual pairing; matching numbers would be a
second convention saying the same thing, free to drift from the first.

Renaming in place is cheap — it does not touch a `.blend`'s relative texture
paths. *Moving* a file does, and breaks them silently.

## Art direction

Bright, earthy, upbeat. Not pastel, not candy. Warm sun, cool sky fill, soft
shadows, gentle distance fog. The mood lives in the **lighting**, not in the
models — which is what makes it affordable for one person.

Imported assets should be beveled (a small Bevel modifier on everything) and,
if textured, at roughly **32 texels per metre** to match Threshold Deep's
family.

## Scale

1 Blender unit = 1 metre = 1 Godot unit. Characters 1.7-1.8 m. There are no
pixels-per-metre in 3D geometry; that idea only applies to texture density.

## Gotchas already paid for

- `+Z` is behind a node in Godot; forward is `-Z`. The camera sits at
  `Vector3(0, 0, _arm)` for that reason.

### Blender to Godot

- **Godot deletes dots from animation names.** The glTF importer runs them
  through `validate_node_name()`, which strips the characters illegal in node
  names. `attack.thrust` arrives as `attackthrust`. It fails *selectively* —
  `idle` and `walk` are fine, so the rig looks healthy and only the dotted
  clips vanish. `AnimPick` normalises both sides now; keep using dots.
- **An unapplied Object Mode scale on an armature shrinks everything
  socketed to it.** The character still looks right, because its meshes are
  children of that armature. A weapon is not. Cost most of a day: `Ctrl+A →
  All Transforms` on the armature *and* its meshes. `Socket.make()` warns
  when a skeleton arrives carrying a scale.
- **An unrecognised collision suffix fails completely silently.** `-con`
  instead of `-col` imports the mesh perfectly and gives you no collider,
  with nothing in the log. Only `-col`, `-convcol`, `-colonly` and
  `-convcolonly` are real. `world.gd` `_piece()` now warns on a piece that
  arrives with no `StaticBody3D`.
- **`-convcol` fills in any hole.** A convex hull of a broken wall is a solid
  block. Anything with a gap in it wants `-col`.
- **A socket bone's parent decides what it follows; its position only decides
  where it sits.** Independent, so a correct position hides a wrong parent
  entirely until the rig animates. A prop that sits right in the rest pose
  and then drifts is a hierarchy bug, not a placement one — check the bone's
  Relations → Parent before touching its position.

### Controller

- Godot's `CharacterBody3D` will walk up a 45 degree ramp and then refuse a
  10 cm step, because a riser is a vertical wall to the solver. `player.gd`
  implements step-up manually in `_try_step()`, and every part of it was paid
  for separately:
  - Lift only as far as the tread actually is, never the full `STEP_HEIGHT`.
  - Probe over a **fixed** distance, never one frame of travel — a frame is
    5 cm at a walk and below the physics margin at a crawl, so the collision
    test stops giving a stable answer and the climb stutters.
  - **Commit** the step. Floor snapping otherwise finds the lower ground
    still under you and undoes the lift the same frame, so you buzz against
    a step instead of climbing it.
  - Rate-limit the climb, or a tall riser is a bigger jolt than a short one.
  - Hold the camera *and the model* back and ease them in. Smoothing the
    camera alone just detaches it from a character that is still popping.
- **The camera collision is a shape cast, not a ray.** A ray is infinitely
  thin and slides through the gap between two wall segments, leaving the
  camera parked inside the wall beside it. It also masks `Layers.WORLD` only
  — an enemy walking behind you must never shove the view into the back of
  your own head.
- The camera arm snaps in instantly and eases back out. Lerping *into* a wall
  clips through it for a few frames.

### Physics layers

`Layers` (`scripts/layers.gd`) is a contract, not a convenience: `WORLD`,
`CHARACTER`, `DEBRIS`. It exists so the camera can collide with the world
alone. Getting a mask wrong fails quietly — a blade whose mask drops
`CHARACTER` simply stops hitting things, with no error.
