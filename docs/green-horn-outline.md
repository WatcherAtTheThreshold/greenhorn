# Green Horn — Production Outline

*Working title. Third-person action rogue-lite. Godot + Blender.*

---

## 1. Premise

Humans are gone. Robots are executing a long-term plan to re-establish the biosphere. The plan is working, but unevenly — arthropods recover fastest after mass extinction events, and with no predators and no competition, they've established first and grown large. You are a unit sent out into that gap.

Set in the same world as *Subtle Spirits*.

**Why the premise holds up:** insects and arthropods genuinely are the first complex life to rebound after extinction events. The fictional leap is the gigantism, and that can be hung on atmospheric composition if it ever needs justifying — real Carboniferous giant insects were an oxygen story.

**Title:** "Green Horn" is doing three jobs at once — greenhorn as novice, green as returning plant life, horn as mandible. Worth keeping.

**Death is diegetic.** You're a robot. Robots have backups. A failed run isn't a game over, it's a unit being reactivated with what the last one learned. Rogue-lite meta-progression stops being a genre concession and becomes the story.

**Augments are physical.** Items bolt onto the robot — shoulder mount, back rack, forearm swap, head module. The fiction, the mechanic, and the technical implementation are all the same thing.

---

## 2. Poly Budgets

"Low-poly" is relative to target hardware and how many of a thing appear on screen at once. Working budgets for a stylized game targeting web + desktop Godot:

| Asset type | Triangles | Notes |
|---|---|---|
| Player robot | 3,000–6,000 | Always on screen, gets camera-close |
| Bug enemies | 400–1,500 | Many at once — the number that actually bites |
| Held weapons / tools | 200–800 | Small but near camera |
| Small props (chair, crate, barrel) | 100–400 | |
| Rocks, ground clutter | 50–250 | |
| Trees | 300–1,000 | Leaves as flat cards, never modeled |
| Small structures (shed) | 500–1,500 | |
| Cottage with interior | 2,000–5,000 | Interior roughly doubles cost |

**Reference points:** PS1 characters were 300–800 tris. PS2 characters were 3,000–5,000. You are not poly-limited the way those were.

### What actually costs you

Draw calls and materials, not vertices. Fifty rocks with fifty materials is far more expensive than one rock mesh at 2,000 tris.

- **Use a texture atlas.** One small palette image (even 64×64) that every asset UV-maps onto. All props share one material.
- This connects to the known constraint that procedural shader nodes don't survive glTF export — bake once to a palette, and everything downstream is cheap.
- **Reuse aggressively.** One rock, scaled and rotated five ways, reads as five rocks.

### Where to spend polys

Silhouette, not surface. A shape that reads at a glance from the 3/4 rear view is worth more than geometric detail on a flat panel. Surface detail lives in the texture. This is the same judgment call as where to spend paint.

---

## 3. Held Items & Attachments

**Never merge weapons into the character mesh.**

### Blender side

1. Add a **socket bone** to the armature — a small bone parented to the hand bone. Name it with the existing convention: `weapon.socket.R`.
2. When animating, parent the weapon object to that bone with `Ctrl+P → Bone`. It follows the hand and you can time swings against it visually.
3. It stays a **separate object** — never skinned to the armature, never joined to the body mesh.
4. Export the robot as one `.glb`. Export each weapon as its own `.glb`.

### Godot side

- Add a `BoneAttachment3D` node, point it at the hand bone.
- Add the weapon mesh as its child.
- Swap the child at runtime to swap weapons — no re-export needed.

This is exactly what a rogue-lite requires, since item pickups have to change equipment on the fly.

### Socket bones to add now

While the rig is still open, add empty socket bones even if nothing attaches yet:

- `weapon.socket.R` / `weapon.socket.L` (hands)
- `mount.shoulder.R` / `mount.shoulder.L`
- `mount.back`
- `mount.forearm.R` / `mount.forearm.L`
- `mount.head`

Costs nothing now. Saves a re-rig later.

### Animate by weapon class, not by weapon

One "one-handed swing," one "two-handed swing," one "ranged aim." Fifteen swords share three animations. Otherwise animation workload scales with item count, which is unsustainable.

Weapons with their own moving parts (recoil, a spinning drill) get a tiny armature of their own, played in sync. Rare early — don't design for it yet.

---

## 4. Environment Assets

Yes to trees, rocks, ground, props, and structures — but **not yet**. Building a library before the game is known means building things the game won't use.

When the time comes:

**Modular kits for buildings.** Wall, wall-with-window, corner, doorway, roof section — all built to a consistent grid (2m is standard). Six pieces build a shed or a cottage. Much better return than modeling whole buildings.

**Collision authored in Blender** using Godot's mesh-suffix conventions: `-col`, `-convcol`, `-colonly`, `-noimp`.

---

## 5. Milestone Ladder

Threshold Deep–style: one clear goal at a time, milestoned before the next is set.

### M0 — Camera and controller
Third person, capsule placeholder, **no art**. Movement, run, camera follow with collision so it doesn't clip through geometry.

*Done when:* it feels good to move with a featureless capsule. If walking around isn't satisfying, no amount of art fixes it.

### M1 — The robot lives in Godot
The current rig exported as `.glb`, replacing the capsule, playing idle and walk.

*Note:* this is already the existing sandbox goal. Green Horn's first art milestone is work already in progress.

### M2 — One bug, one fight
One enemy that walks toward you. One attack from you that kills it. One attack from it that kills you. Ugly is fine.

### M3 — One room
An arena you enter, clear, and exit. This is the first point at which there is a loop.

### M4 — Three rooms and a run
Sequenced, with an ending state (win or die). This is the rogue-lite skeleton. Everything after this is content rather than structure.

### M5 — One item that changes the run
Not a system — one item. Then a second. The augment system emerges from having two things that must coexist.

### Vertical slice
One room, one enemy, one weapon, one item. Prove that's fun; the rest is production.

---

## 6. Known Costs & Risks

**Third person raises the animation burden significantly.** First person needs arms. Third person needs idle, walk, run, turn, attack, hit-reaction, and death before the character stops looking broken. This is the real price of seeing the robot — budget for it.

**Minimum animation set for M1–M2:**
- Idle
- Walk
- Run
- Attack (one)
- Hit reaction
- Death

**Enemy count is the performance risk**, not player detail. Bug tri-count and shared materials matter more than anything on the robot.

**Keep the sandbox separate from Threshold Deep.** Sandbox conventions (unit scale, naming rules, material approach) should mirror what the real project will need — sandbox as living spec.

---

## 7. Open Questions

- Is the robot currently being rigged **the protagonist**? It changes how much the topology matters, and it's better decided before the rig is finished.
- What locomotion foundation does the sandbox use — standard `CharacterBody3D` with `RayCast3D` nodes, or something else?
- Bug variety: how many enemy types before the vertical slice reads as a game? (Probably one. Possibly two.)
- Does the run structure use hand-authored rooms, or procedural assembly from room pieces?

- **Should there be small structures, and is one of them a shop?** *Raised
  2026-09-02.* Two separate questions wearing one coat, and they want pulling
  apart:

  **A shop is a UI problem, not an architecture problem.** Whatever it looks
  like, it is a trigger, a list and a currency. The building around it is
  decoration, so "should a building be a shop" should not be what decides
  whether structures get built. The story doc's lab station already implies a
  return destination, and that is M4 territory — probably a scene change
  rather than a hut on the field.

  **Structures are worth testing anyway, for reasons that have nothing to do
  with shops.** The untested risks are:

  - **The camera.** The spring arm pulls in on walls, and has never met a
    doorway, a low roof or an interior. Third person in a small building is
    where third-person cameras go to die. This is the biggest unknown in the
    project right now.
  - **Occlusion.** Bugs behind a wall, the player losing sight of a fight.
  - **Blender-authored collision** via the `-col` / `-convcol` / `-colonly`
    mesh suffixes — the pipeline supports it and the project has never used
    it once.
  - Whether the 2 m modular grid in §4 is the right module size.

  **The cheap way to find out:** the plot is already organised as test bands —
  ramps at `z -14`, stairs at `z -28`. Add a **shelter band**: one wall, one
  doorway, one roofed corner. Walk into it and watch the camera. That answers
  the architecture questions without deciding anything about the game, which
  is exactly what the sandbox is for.

---

## 8. Immediate Next Actions

1. Finish the robot rig — add socket bones before calling it done.
2. Export clean `.glb` to Godot, confirm the import pipeline works end to end.
3. Build M0 in parallel: capsule + third-person camera, no dependency on the rig.
4. Save incrementally (`Ctrl+Shift+S`) at every session.
