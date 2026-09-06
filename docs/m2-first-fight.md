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
| Stairs | manual step-up, `STEP_HEIGHT` 0.28 m — the 40 cm band needs a jump |
| Animation | idle / walk / run / jump, optional fall / land |
| Model loading | drop a `.blend` in `assets/blender/`, it appears |
| Diagnostics | plinth captions report clips, rigs, mesh and vert counts |
| Sockets | `Socket.make()` / `Socket.equip()`, shared by player and bug |
| Attacks | `attack.thrust` on left click, `attack.chop` on right |
| Enemy | `bug.gd` — walks at you, wears its shell on `shell.socket` |
| Hit detection | blade `Area3D` sized off the weapon mesh, `hurt()` on the target |
| Hit feedback | flash, knockback, hitstop |
| The shell | comes off on the second hit, splits, and clatters away as physics |
| Scenery | trees and rocks scattered as MultiMeshes, one draw call each |
| Structures | a shelter band at `z -42` — walls, a doorway, collision from Blender |
| The bite | the tiger beetle rears, opens its mandibles, and bites — frames 12–18 of 24 |
| Mortality | Tim has health, a `hit` clip, a `death` clip, and the plot rebuilds |
| Two species | tiger beetles bite; rain beetles have no `attack` clip and follow |

**Every M2 system is built, and the fight has been won and lost.** What is
left is not construction, it is the gate at the bottom of this document.

**Resolved 2026-09-01.** Tim's armature was carrying an unapplied
`scale 0.2106`, and the sword had a matching 1.8× inflation baked in to cancel
it out. Both are gone — the armature exports clean, and `sword1.blend` now
holds a sword at its honest size. Applying it did shift some animation frames
downward, which was fixed with a Z adjustment; the clips were tidied at the
same time. Metres mean metres on this rig now, which is what makes one shell
asset able to sit on a bug's back *and* on Tim's shoulder.

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

**Godot deletes dots from animation names.** The glTF importer runs every clip
name through `validate_node_name()`, which strips the characters that are
illegal in node names — `.` among them. So a Blender action called
`attack.thrust` arrives in the `AnimationPlayer` as `attackthrust`.

This is a nasty one because it fails *selectively*: `idle` and `walk` have no
punctuation to lose and work perfectly, so the rig looks fine and only the
dotted clips are silently unfindable. It cost an evening of staring at a sword
that sat in Tim's hand doing nothing on every click.

`AnimPick` now compares names with everything but letters and digits stripped,
so `attack.thrust`, `attack_thrust`, `attack-thrust` and `attackThrust` all
match the same clip. **Keep using dots in Blender** — the naming is good and
the lookup no longer cares. And `player.gd` now warns on startup with the full
clip list if a swing resolves to nothing.

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

**There is no socket object in Blender.** Nothing in the menus is called a
socket or an attachment point, and looking for one is the first half-hour
gone. A socket is just a bone that deforms nothing. That is the entire idea.

In Edit Mode on the armature:

1. Select the hand bone, `Shift+S` → **Cursor to Selected**. The 3D cursor is
   now at the bone's head.
2. `Shift+A` for a new bone at the cursor. Do **not** extrude with `E` — that
   makes a *connected* child you then cannot move freely.
3. Rename it `weapon.socket.R` in Bone properties.
4. Bone properties → **Relations** → Parent: the hand bone, **Connected: off**.
5. Bone properties → **Deform: untick.** This is the step that makes it a
   socket rather than a limb: no vertex group, nothing skinned to it.
6. Shrink it to ~0.1 m so it is not a metre-long spike in the viewport. Length
   is cosmetic — only the head position and the rotation matter.

Repeat for every name in the list above while the armature is open.

### Godot side

`BoneAttachment3D` under the `Skeleton3D`, with the weapon as its child — but
**not by dragging nodes in the editor**, because there are no nodes to drag.
The player model is not in `player.tscn` at all; `_adopt_model()` loads it at
runtime, so there is no `Skeleton3D` to parent anything to until the game is
running.

So it is code, in `scripts/socket.gd` — shared, because the sword and the
shell were always going to be the same two functions:

| | |
|---|---|
| `Socket.make(root, bone)` | makes the `BoneAttachment3D` on whatever rig arrived |
| `Socket.equip(root, file, bone)` | loads a `.blend` and hangs it there |
| `WEAPON_BONE`, `weapon_file` | in `player.gd` — which bone, which `.blend` |
| `SHELL_BONE`, `shell_file` | the same two in `bug.gd` |

Swapping weapons is one string. No re-export, no scene edit.

### The five that actually cost time

**1. The attachment lands on the bone's head, +Y toward the tail.**
The child sits at the head — the root end, not the tip — and inherits the
bone's axes, where **+Y runs head to tail**. Blender bones point +Y along
their length, so a weapon modelled pointing Godot-forward (`-Z`) arrives
rotated 90°. Do not try to compute the correction. Model the weapon at the
origin pointing as it should when held, then rotate the *bone* to meet it:
`R` to aim, `Ctrl+R` or the N-panel **Roll** field for the spin around the
blade. Two or three export passes gets it.

To skip the guessing: run the game, find the socket in the editor's **Remote**
scene tree, nudge its child's rotation in the inspector until it looks right,
then apply those numbers to the bone in Blender and zero the child again. The
bone stays the single source of truth, which is what keeps weapon swapping
free.

**2. An unapplied armature scale makes every socketed prop tiny.**
This one cost the most. Tim's armature exported carrying
`"scale":[0.2106, 0.2106, 0.2106]` from an Object Mode resize that was never
applied. Tim himself looked perfect — his meshes are children of that armature
and were shrunk by the same amount. But a socketed prop is **not** a child of
the armature. It arrives at true size and is then scaled by 0.21, so a 1.7 m
sword renders at 36 cm and looks like a letter opener.

The fix is `Ctrl+A` → **All Transforms** in Object Mode, with the armature
**and its meshes selected together**. Applying to the armature alone pushes a
compensating scale onto the children and you end up where you started.

Two warnings. Save a copy first: applying scale to an armature that already
has actions can shift bone *location* channels, so play every clip afterwards.
And `_socket()` now reports this on startup — if a skeleton arrives carrying a
scale, it names the number rather than letting you wonder why the sword is
small.

**3. Apply the weapon's transforms too.**
`sword1.blend` had a 90° rotation and a non-uniform scale sitting on every one
of its nine parts. Until those are applied, "modelled at the origin pointing
the right way" is not actually true of the file, and aiming the socket bone
against it is guesswork. Risk-free to apply — no rig, no actions.

**4. Godot deletes dots from animation names.**
Not strictly a socket problem, but it is what made the finished sword sit in
Tim's hand doing nothing. See [the naming note](#naming--what-the-project-understands).

**5. A socket bone's parent decides what it follows. Its position only
decides where it sits.**

Those two are independent, and that is the trap: get the position right and a
wrong parent is completely invisible until something moves.

The mandibles were modelled on Tim's head, their origin set to the 3D cursor
at the world origin, and saved out — the workflow that had worked for the
shells. They arrived sitting perfectly on his head. And stayed exactly there
while the head turned, because `mount.head` had been *positioned* correctly
without being *parented* to the head bone.

It looks like a placement bug and it is a hierarchy bug. If a socketed prop
sits right in the rest pose and drifts the moment the rig animates, stop
adjusting the position — check the bone's **Relations → Parent**.

The shells got away with it because their socket sat at the bug's own origin
*and* was parented into the thorax chain. Position at the origin is a
convenience; the parent is the thing doing the work.

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

- [x] Tim is rigged, with socket bones, exported clean
- [x] A weapon appears in his hand and follows it through the swing
- [x] One bug walks toward the player
- [x] Attacking connects — hit detection works
- [x] The shell comes off, visibly, and it feels good
- [x] The bug dies
- [x] Hit feedback exists: flash, knockback, hitstop

Beyond the list, because the outline's M2 asked for it and the stage doc
deferred it: **the bug bites back, and it can kill you.** Six beetles, two
species, and the first fight took three attempts to win.

And then the actual gate, which is not a checkbox:

> **Do you want to do it again?**

If yes, M3 and the outline are the plan. If no, the interesting version of
this game is somewhere else and it is worth finding out now.

### What M2 actually answered — 2026-09-02

**Yes.** Not as a decision, but by observation: the fight got played
repeatedly, lost twice, tuned, and played again. That is the answer the gate
was asking for, and it did not need arguing about.

Three things the build turned up that no amount of planning would have:

**The shelter doorway became a bottleneck on its own.** It was built to test
the camera. It turned out to change how a fight goes, because a mixed group
has to funnel through it. Arena geometry is a combat system, not decoration —
worth knowing before M3 designs a room.

**A harmless enemy reads completely differently from a dangerous one.** The
build where the bug could walk at you but neither of you could attack read as
a *follower pet*, not an enemy, and that is now open question 5. The rain beetle still
has no `attack` clip, so it still reads that way standing next to one that
bites — which is the pacifist species from the story doc, arrived at through
asset availability rather than design.

**Feedback beat animation, exactly as predicted.** Flash, knockback and
hitstop were built before any hit-reaction clip existed and carried the whole
fight on their own. The clips came later and improved it; they were never
what made it land. *Do not animate a hit reaction yet* was right.

**The sword's reach reads as accurate, and it was never tuned.** The blade
sliding past a beetle misses; anything that enters its body connects. That
came out of measuring the hitbox off the weapon mesh rather than typing in a
range — the hitbox *is* the blade, so there is no approximation to be
generous or stingy about. Two swings' worth of numbers were guessed on day
one and have survived every playtest since.

---

## Open questions for this stage

Answer as they come up; add to this list rather than starting a new one.

1. **Is Tim the protagonist?** Decide before the rig is finished, since it
   changes how much the topology matters.
2. **Does the shell break in one hit, or take several?** One is simpler and
   answers the question. Several is probably the better game.
3. **Melee or ranged first?** Melee tests the socket and the shell in one go.
   *Answered by building it: melee, and it works.*
6. **Does melee want aim assist?** Raised 2026-09-02, from the swing feeling
   right without any. It currently connects on geometry alone — no snapping,
   no widened arc, no forgiveness cone. That reads as precise rather than
   fussy against a slow beetle you can circle.

   The question is whether it survives contact with faster enemies, several
   at once, or a controller. Assist is easy to add later and very hard to
   remove once players are used to it, so the burden of proof is on adding
   it — and the current answer is *not yet, and possibly never*.
4. **How does the bug telegraph?** *Answered 2026-09-02.* It rears up, lifts
   its legs and antennae, and opens its mandibles wide. The jaws close on
   frames 12–18 of a 24-frame clip, so **half the animation is wind-up** —
   about 0.4 seconds of warning at 30 fps.

   Three things make that warning mean something, and all three are code
   rather than animation:

   - **Range is checked once, at commit.** The beetle bites where you *were*,
     so backing off during the wind-up is a real answer rather than a delay.
     `BITE_REACH` is deliberately shorter than `BITE_RANGE` — that gap is the
     step you can take.
   - **It turns to face you at commit.** A telegraph you cannot see the front
     of is not a telegraph.
   - **A hit cancels a bite in progress.** Otherwise you can read the tell,
     land a clean chop, and get bitten anyway — which teaches the player that
     reading the tell does not work.

   The open question underneath is now a *tuning* one, not a design one: the
   length of that wind-up decides whether this game is about reaction or about
   spacing. It is currently long enough to be about spacing.

   Worth revisiting once the shell means something mechanically: **an
   armoured beetle that cannot be interrupted until you have cracked it** is
   the same system doing thematic work, and it is a one-line change.
5. **Is there a non-combat game in here?** *Noticed 2026-09-01, from the
   build rather than from thinking about it.* For the one session where the
   bug could walk at you but neither of you could attack, it did not read as
   an enemy — it read as a **follower pet**, and that was immediately more
   interesting than it had any right to be. Worth naming now, because it is
   the kind of thing the build shows you once and you never notice again
   after the sword starts connecting.

   This does not change M2. The gate is still whether cracking a shell is
   satisfying, and it needs answering on its own terms. But if that answer
   comes back a lukewarm *yes, sort of*, this is the first place to look
   before concluding the game is somewhere else entirely. A creature that
   follows you, that you can crack open **or not**, is a different and more
   surprising proposition than one that only ever comes at you.

   Nothing to build. Just do not let it evaporate.

## Reference

- [green-horn-outline.md](green-horn-outline.md) — the production plan
- [blender-checklist.md](blender-checklist.md) — export traps, naming, scale
- [../README.md](../README.md) — how the sandbox works, controls, knobs

Current tuning lives as `const` at the top of `scripts/player.gd` — speeds,
camera lag, step height. Plot geometry is in `scripts/world.gd`. All colours
are in `scripts/palette.gd`.
