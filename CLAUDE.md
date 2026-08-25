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

- Godot's `CharacterBody3D` will walk up a 45 degree ramp and then refuse a
  10 cm step, because a riser is a vertical wall to the solver. `player.gd`
  implements step-up manually in `_try_step()`.
- The camera arm snaps in instantly and eases back out. Lerping *into* a wall
  clips through it for a few frames.
- `+Z` is behind a node in Godot; forward is `-Z`. The camera sits at
  `Vector3(0, 0, _arm)` for that reason.
