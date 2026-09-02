# Blender to Godot: the short checklist

The five things that cost an afternoon each if you get them wrong.

## 1. Scale is metres. There are no pixels.

1 Blender unit = 1 metre = 1 Godot unit. Set **Scene Properties -> Units ->
Metric, Unit Scale 1.0** and build at real size. A person is 1.7-1.8 m.
Godot's gravity and character controller both assume metres, so if you build
true to size the physics is free.

The `32 px = 1 m` from Threshold Deep was never world scale. It was **texel
density** — how much pixel art maps onto a metre. That number still applies,
but to your *textures*, not your geometry. Unwrap and texture at 32 texels
per metre and this project will sit in the same visual family.

## 2. Face -Y in Blender.

Godot's convention is that things face **-Z**. glTF converts Blender's Z-up to
Godot's Y-up on the way through, and Blender's -Y comes out as Godot's -Z.

So: model and rig your character facing **-Y**, which is Blender's Front view
(numpad 1). Then it arrives pointing the right way and `look_at` works.

## 3. Apply transforms before you export.

`Ctrl+A -> All Transforms` on meshes and armatures. Unapplied rotation or
non-uniform scale on an armature produces deformation that is genuinely
miserable to diagnose from the Godot side.

## 4. Animate in place.

Blender **Actions** become Godot **Animations** inside an AnimationPlayer.
But do not translate the character forward along the timeline. Godot's
`CharacterBody3D` moves the body; the animation only plays on top. An
animation that also moves gives you moonwalking, or double speed.

To get more than the active action out, push each one down as an **NLA
strip**, or tick *export all actions* on the importer.

The project drives these names automatically, matching on **prefix** and
ignoring case — so `Walk_002` and `Armature|walk` both count as `walk`:

| name | when it plays | loops |
|---|---|---|
| `idle` | standing still | yes |
| `walk` | moving | yes |
| `run` | moving above ~70% of RUN_SPEED | yes |
| `jump` | feet off the ground | no |
| `fall` | *optional* — airborne and descending | yes |
| `land` | *optional* — the moment you touch down | no |

Everything degrades. No `fall` and the jump pose holds; no `land` and you go
straight back to idle; no air clips at all and the ground poses keep running
mid-air. A model with no animations at all costs nothing.

Where several clips match a prefix, the **longest** wins — which reliably
skips the one-frame strays left over from experimenting.

## 5. Procedural materials do not export.

Principled BSDF with plain texture or plain colour inputs survives. Anything
node-driven — noise, gradients, musgrave, geometry nodes feeding a shader —
becomes flat grey. Bake it to an image, or keep materials simple.

Compare whatever you import against the roughness row on the left of the test
plot. That is what it is there for.

---

## Bonus: collision straight from Blender

Godot reads suffixes on mesh names in an imported scene:

| suffix | result |
|---|---|
| `-col` | static trimesh collision, mesh still visible |
| `-convcol` | convex collision, mesh still visible |
| `-colonly` | trimesh collision only, the mesh is discarded |
| `-convcolonly` | convex collision only, the mesh is discarded |
| `-rigid` | becomes a RigidBody3D |
| `-navmesh` | becomes a navigation mesh |

**A suffix Godot does not recognise fails completely silently.** It treats it
as part of the name, imports the mesh perfectly, and gives you no collider —
nothing in the log, nothing visibly different. `-con` instead of `-col` is a
wall you walk straight through. Those four spellings above are the only ones;
anything else is just a name.

**`-convcol` fills in any hole.** A convex hull of a broken wall is a solid
block up to its highest point, so the notch you modelled becomes an invisible
wall. Convex is right — and cheaper — for solid lumps only. Anything with a
gap or an opening in it wants `-col`.

So a wall called `wall-col` arrives already solid. Empties become `Node3D`,
which makes them free spawn points and attachment sockets.

## Bonus: bevel everything

A 1-2 px highlight running along each edge is most of what your eye uses to
decide something is real rather than CG. A Bevel modifier with a small width,
applied to everything, kills the plasticky look faster than any amount of
texturing. Segments 2, width 0.005-0.02 depending on the object.
