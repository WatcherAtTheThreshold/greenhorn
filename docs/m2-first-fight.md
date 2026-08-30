# M2 — First Fight

*Stage reference for Green Horn. Written 2026-08-30.*

The question this stage exists to answer:

> **Is cracking a bug's shell open satisfying?**

Not "can I build combat." Whether the *specific* thing that makes this game
not-generic actually feels good in the hand. If it does, the rest of the
outline becomes a plan. If it doesn't, better to know after two days than
after two months.

Everything below is in service of that one question. Anything that isn't, is
out of scope for M2.

---

## Where we are

**M0 (camera and controller) and M1 (robot lives in Godot) are done.** The
sandbox already has:

| System | State |
|---|---|
| Third-person camera | spring arm with wall pull-in, `C` toggles first person |
| Movement | camera-relative, acceleration + friction, sprint, jump |
| Stairs | manual step-up, `STEP_HEIGHT` 0.45 m |
| Animation | idle / walk / run / jump, optional fall / land |
| Model loading | drop a `.blend` in `assets/blender/`, it appears |
| Diagnostics | plinth captions report clips, rigs, mesh and vert counts |

Not built yet, and needed for M2:

- Socket / `BoneAttachment3D` system (weapons in hands, shells on bugs)
- Any enemy at all
- Damage, hit detection, hit feedback

---

## Scope

**In:**

- One player attack
- One bug that walks at you
- One breakable shell
- Enough feedback that a hit reads as a hit

**Out** — deliberately, until the question is answered:

- Rooms, runs, doors, progression
- Items, augments, inventory
- A second enemy, a second weapon
- Sound (worth adding right after, not during)
- Any optimisation whatsoever

---

## The three assets

### 1. Player — Tim

Already modelled. **Not yet rigged.** Rigging him is the gate on everything
else in this stage.

| | |
|---|---|
| Triangles | 2,924 |
| Meshes / surfaces | 27 / 28 |
| Materials | 2 |
| Height | 1.59 m |
| Rig | none yet |

Sits squarely inside the player budget. Two materials and 28 surfaces is
lean. Twenty-seven rigid parts means **no weight painting and no deformation
problems** — the joints stay crisp and there are no collapsing elbows.

**Decide before rigging:** if augments bolt onto shoulder, back, forearm and
head, is there room on this body for them to sit? A pauldron over a sphere is
a different modelling problem than a pauldron over a flat plate.

### 2. Weapon

One. Any one. It exists to prove the socket works and to have something to
swing.

| | |
|---|---|
| Triangles | 200–800 |
| Materials | 1 |
| Rig | none — it rides a bone, it is never skinned |

Model it at the origin, pointing the way it should point when held, then
position the *socket bone* to meet it rather than moving the weapon.

### 3. Bug

The one asset that has to be new work. Start with a beetle — a hard shell is
the whole point.

| | |
|---|---|
| Triangles | 400–1,500 |
| Surfaces | **keep under ~8** |
| Materials | 1–2 |
| Rig | yes, minimal — see below |
| Shell | a **separate mesh**, not part of the body |

Surfaces matter more than triangles here, because there will eventually be a
dozen of these on screen at once and each surface is a draw call. This is the
number that actually binds.

---

## Budgets — measured, not guessed

These are the actual numbers from the project, so they calibrate against
something real rather than against a table on the internet.

| Asset | Tris | Meshes | Surfaces | Materials | Verdict |
|---|---|---|---|---|---|
| Tim | 2,924 | 27 | 28 | 2 | in budget, lean |
| gears_and_stardust | 17,054 | 28 | 55 | 5 | 3x over on tris, 2x on draw calls |

**Triangles are not the constraint.** A 1660 SUPER does not care about 17,000
triangles on one character. Your outline says as much and it is right.

**Surfaces and materials are the constraint**, because each surface is
roughly a draw call and enemies come in numbers. The rule of thumb:

| | Tris | Surfaces | Why |
|---|---|---|---|
| Player | 3,000–8,000 | up to ~30 | one on screen, gets camera-close |
| Bug | 400–1,500 | **under 8** | a dozen on screen at once |
| Weapon | 200–800 | 1–3 | small, near camera |
| Prop | 100–400 | 1–2 | many, reused |

**Where to spend it:** silhouette, not surface. Tim's dark joints against
pale panels is the right instinct — that read survives being small, distant
or backlit, and it costs one extra material rather than geometry.

---

## Animation set

### Minimum for M2 — three new clips

| Character | Clip | Notes |
|---|---|---|
| Tim | `attack` | one swing. Name it `attack`, see naming below |
| Bug | `walk` | it only needs to come at you |
| Bug | `death` | the payoff |

Tim already has `idle`, `walk`, `run`, `jump` from gears_and_stardust — those
transfer as an approach, not as files.

The bug does **not** need an attack yet. If it cannot hurt you, you can still
find out whether hitting it feels good. Add the attack once you know the
hitting is worth defending against.

### Do not animate a hit reaction yet

Hit feedback is mostly **code**, not animation:

- a material flash for ~0.06 s
- a small knockback
- hitstop — freeze both parties for 40–80 ms on impact

Those three do more than a hit-reaction clip, and they are a few lines each.
Build them first. If it still feels limp, *then* make the clip.

### Naming — what the project understands

Matched on **prefix**, case-insensitive, so `Walk_002` and `Armature|walk`
both count as `walk`. Where several match, the **longest** wins, which skips
the one-frame strays left over from experimenting.

| Name | When | Loops |
|---|---|---|
| `idle` | standing still | yes |
| `walk` | moving | yes |
| `run` | above ~70% of `RUN_SPEED` | yes |
| `jump` | feet off the ground | no |
| `fall` | optional, airborne and descending | yes |
| `land` | optional, on touchdown | no |
| `attack` | *to be wired this stage* | no |
| `death` | *to be wired this stage* | no |

Everything degrades. A model with only an idle still works.

---

## Sockets and attachments

**The weapon in the hand and the shell on the bug are the same technique.**
Learn it once, use it twice. Neither is skinned; both just ride a bone.

### Bone naming

Add these to Tim's armature while it is open. Empty sockets cost nothing now
and save a re-rig later.

```
weapon.socket.R      weapon.socket.L
mount.shoulder.R     mount.shoulder.L
mount.back
mount.forearm.R      mount.forearm.L
mount.head
```

On the bug: `shell.socket` on the thorax.

### Blender side

1. In Edit Mode on the armature, add a bone, parent it to the hand bone.
2. **Untick Deform.** It should not create a vertex group or skin anything.
3. Position it where the grip sits; rotate it so the weapon's local axes line
   up with how it should be held.
4. Export the robot as one `.glb`. Export each weapon as its own `.glb`.

### Godot side

1. `BoneAttachment3D` under the `Skeleton3D`, set `bone_name`.
2. Add the weapon mesh as its child.
3. Swap the child at runtime to swap weapons — no re-export.

### The shell, specifically

Same thing pointed the other way:

- Shell is a separate mesh on `shell.socket`.
- On break: unparent it, hand it a `RigidBody3D`, let it clatter off.
- Underneath is a differently-materialled soft body that now takes damage.

No skinning, no shape keys, no second animation. The cheapest possible
version of the most interesting idea in the outline.

### The export trap

The glTF exporter has **Armature → Export Deformation Bones Only**. If that
is ever ticked, every socket bone silently vanishes and the weapon has
nothing to attach to.

Same family as the two that have already cost a morning each: *Limit to →
Visible Objects* (hiding does not exclude from export) and *Limit to →
Selected Objects* (which produced a 132-byte empty file). See
[blender-checklist.md](blender-checklist.md).

---

## Done when

- [ ] Tim is rigged, with socket bones, exported clean
- [ ] A weapon appears in his hand and follows it through the swing
- [ ] One bug walks toward the player
- [ ] Attacking connects — hit detection works
- [ ] The shell comes off, visibly, and it feels good
- [ ] The bug dies
- [ ] Hit feedback exists: flash, knockback, hitstop

And then the actual gate, which is not a checkbox:

> **Do you want to do it again?**

If yes, M3 and the outline are the plan. If no, the interesting version of
this game is somewhere else and it is worth finding out now.

---

## Open questions for this stage

Answer as they come up; add to this list rather than starting a new one.

1. **Is Tim the protagonist?** Decide before the rig is finished, since it
   changes how much the topology matters.
2. **Does the shell break in one hit, or take several?** One is simpler and
   answers the question. Several is probably the better game.
3. **Melee or ranged first?** Melee tests the socket and the shell in one go.
4. **How does the bug telegraph?** Nothing to answer yet — it does not
   attack in M2 — but it is the next question after.

## Reference

- [green-horn-outline.md](green-horn-outline.md) — the production plan
- [blender-checklist.md](blender-checklist.md) — export traps, naming, scale
- [../README.md](../README.md) — how the sandbox works, controls, knobs

Current tuning lives as `const` at the top of `scripts/player.gd` — speeds,
camera lag, step height. Plot geometry is in `scripts/world.gd`. All colours
are in `scripts/palette.gd`.
