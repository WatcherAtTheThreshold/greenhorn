# Greenhorn

A small sunlit test world for Blender-to-Godot work. Godot 4.7, Forward+,
Jolt. Not a game — a place to stand your models up in and find out whether
they are the right size, the right way round, and whether their materials and
animations survived the trip.

Rename it freely; it is one line in `project.godot` and a folder rename.

## Run it

Open the folder in Godot 4.7 and press F5.

| key | |
|---|---|
| `WASD` | move, relative to where the camera is looking |
| `Shift` | run |
| `Space` | jump |
| mouse | look |
| left click | thrust — plays `attack.thrust` |
| right click | chop — plays `attack.chop` |
| `C` | toggle first / third person |
| `R` | respawn at the start |
| `Esc` | release the mouse |

## Drop a model in

Put a `.blend` (or `.glb`) into **`assets/blender/`**. That is the whole
process — it appears on a plinth in front of the spawn point, next to a 1 m
reference cube, labelled with its filename.

Point Godot at your Blender install once, first: **Project Settings ->
Filesystem -> Import -> Blender -> Blender Path**. After that Godot
re-imports every time you hit save in Blender, so the loop is: save in
Blender, alt-tab, it is already updated.

The player wears the first **rigged** model it finds in that folder, so
usually there is nothing else to do. To pin it to one file, set
**Character File** on the root of `scenes/player.tscn` (e.g. `cat.blend`).

Animations get driven automatically if their names *start with* `idle`,
`walk`, `run`, `jump`, `fall` or `land` — case-insensitive, so `walk_002` and
`Armature|Walk` both work. Only the first three are needed; the rest are
optional and degrade gracefully. Plinth models play their `idle` (a walk
cycle on a display stand reads as a treadmill). The plinth caption tells you
what actually arrived.

### Swapping models

Delete the old file **from inside Godot** (FileSystem dock, right-click ->
Delete), not from Explorer. Godot removes the source, its `.import` sidecar
and the cached copy together, and fixes up references.

Deleting the source but leaving the `.import` behind is the one thing to
avoid. The `.import` is not a cache, it is a *pointer* to the imported copy
in `.godot/` — orphan it and Godot happily goes on rendering a file you
deleted, which is very hard to diagnose from the inside.

Better still: **pick a filename and save over it.** Every rename mints a new
UID and orphans every reference to the old name. Nothing in this project
references your assets by name any more, so overwriting in place is free.

## What is out there

Bands running away from where you spawn:

- **straight ahead** — the import plinths, plus a 1 m cube for scale
- **-14 m** — ramps at 15 / 30 / 45 / 60 degrees. `floor_max_angle` is 50, so
  the 60 should refuse you. That is the number to change if it should not.
- **-28 m** — stairs at 15 / 25 / 40 cm risers. Godot will not climb a
  vertical riser on its own, so `player.gd` does it manually; `STEP_HEIGHT`
  decides how tall a step you can walk up.
- **right** — a 1 m cube, a 1.8 m post to build characters against, a 2 m
  doorway to check nothing is too fat to fit through
- **left** — a roughness sweep plus a metal and an emissive sphere, to
  compare imported materials against

See [docs/blender-checklist.md](docs/blender-checklist.md) for the five things
that go wrong on the way out of Blender.

## Green Horn

The sandbox is feeding a game. Planning lives in `docs/`:

- [green-horn-outline.md](docs/green-horn-outline.md) — premise, budgets, milestone ladder
- [m2-first-fight.md](docs/m2-first-fight.md) — **the current stage**: one bug, one hit, one shell

## Where things live

```
scenes/main.tscn     empty node; world.gd builds everything
scenes/player.tscn   CharacterBody3D + camera rig
scripts/world.gd     the plot, the lighting, the import mount
scripts/player.gd    controller, camera arm, stair stepping
scripts/palette.gd   every colour in the project
assets/blender/      drop .blend files here
```

The world is built in code rather than authored as a scene, so changing it is
editing a number instead of dragging nodes, and there is nothing to
merge-conflict. Every feel value is a `const` at the top of its script.

## Knobs worth knowing

- `player.gd` — `WALK_SPEED`, `RUN_SPEED`, `ACCEL`, `FRICTION` for how it
  feels to move; `STEP_HEIGHT` for stairs; `CAM_DISTANCE` and `CAM_LAG` for
  the camera.
- `world.gd` — `_build_environment()` is the entire cheerful look. Sun colour
  and angle, sky colours, fog density, saturation. A sunny scene is carried
  by its lighting rather than its textures, which is most of why it is
  cheaper to make than a dungeon.
- `palette.gd` — re-grade the whole world by editing one file.
- Want bounce light? `env.sdfgi_enabled = true` in `_build_environment()`.
  It looks lovely outdoors and costs real frame time.

## Experimenting

This is a scratchpad — poke at it. It is in git precisely so that nothing you
try is permanent:

```
git commit -am "wip"      before you start pulling things apart
git diff                  what have I actually changed
git checkout -- .         put it all back
```

The one operation worth doing carefully is **deleting or renaming assets**,
and only because Godot keeps hidden state: a `.blend` has an `.import`
sidecar pointing at a cached copy inside `.godot/`. Remove the source but
leave the sidecar, and Godot will go on happily rendering the file you
deleted. Do those two operations in Godot's FileSystem dock, which removes
all three pieces together and fixes up references.

Everything else — edit the constants, break the shaders, drag nodes about —
is one `git checkout` from undone.
