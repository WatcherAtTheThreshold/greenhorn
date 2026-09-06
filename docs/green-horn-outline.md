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
| Trees | 300–2,500 | Solid geometry, not cards — see below |
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

### Foliage: geometry, not cards — decided 2026-09-02

Card foliage was the original plan and it is the right advice for a
realistic-stylised tree with an alpha-cut leaf texture. It is the wrong tool
for this project. Cards need a second texture and a second material, which
fights the one-atlas rule everything else follows; and flat quads do not catch
light, which is where this game's mood actually lives.

The first attempt was 33 objects and 33 draw calls. The solid version is one
object, one surface, one material, ~2,400 triangles — over the old budget and
comfortably worth it, because triangles were never the constraint. Scattered
as a `MultiMesh` it is **one draw call for the whole forest**.

The same logic points at geometry rather than texture for stone walls.

---

## 3. Held Items & Attachments

**Never merge weapons into the character mesh.**

### Blender side

1. Add a **socket bone** to the armature — a small bone parented to the hand bone. Name it with the existing convention: `weapon.socket.R`.
2. When animating, parent the weapon object to that bone with `Ctrl+P → Bone`. It follows the hand and you can time swings against it visually.
3. It stays a **separate object** — never skinned to the armature, never joined to the body mesh.
4. Export the robot as one `.glb`. Export each weapon as its own `.glb`.

### Godot side

- `Socket.equip(root, file, bone)` in `scripts/socket.gd`. It builds the
  `BoneAttachment3D`, finds the bone and hangs the model off it.
- Change `weapon_file` to swap weapons — no re-export, no scene edit. It is
  code rather than a node in a `.tscn` because no model is in a scene file:
  they are all loaded at runtime, so there is no `Skeleton3D` to parent to
  until the game is running.

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

## 4. Character Design — Timothy

*Direction set 2026-09-06.*

There are three descriptions of this character in existence: the original 2D
illustration from *Smallish Realms*, the Ash chapters in `docs/`, and the model
currently in the game. The first two agree with each other. The third agrees
with neither, and that is the gap to close.

### The cloak is canon, not nostalgia

It is easy to file the cape under "things the 2D version had that the 3D version
can't afford." The stories say otherwise —
[ash-1-apprentice-to-the-east.md](ash-1-apprentice-to-the-east.md):

> *"It was a robot, unmoving, coated with layers of gray road dust. Its tattered
> cloak flapped in the breeze."*

and [ash-2-echoes-in-the-sub-station.md](ash-2-echoes-in-the-sub-station.md):

> *"At first it appeared to be a cloaked human but as it got closer they saw it
> was a robot."*

That second line is a **reveal that only works if the cloak is there** — the
silhouette has to lie about what he is until you're close. It is written twice.
So the cloak is load-bearing for how Timothy is introduced, not decoration, and
it belongs on the model.

### Take the palette and the silhouette. Leave the rendering.

The original is a 2D illustration: black outlines, flat fills. Reproducing *that*
in 3D means an inverted-hull outline pass — a second material on every object,
which fights the one-atlas, one-draw-call discipline the whole project runs on.
It would also flatten the lighting, and per the art direction the mood lives in
the lighting rather than the models, which is exactly what makes it affordable
for one person.

What transfers is the **colour** and the **shape read at a glance**. Not the line
art.

### Order of work, by value per effort

**1. Palette — first, and nearly free.** The current model is one saturated blue
plus grey, with *no accent colour anywhere*. The original is bone-white head,
gold cloak, blue-grey body, brown leather. The gold is what makes him legible.

Because everything is on the shared palette atlas with UVs collapsed to one pixel
per face, a recolour is *moving UV islands to different swatches*. No repainting,
no re-UV, no new texture, no new material. Largest visual gain available for the
least risk.

**2. Horns — the socket already ships.** `mount.head` and
`props/mandibles.blend` already work. Antlers are the identical pipeline: one
object, no rig, no skinning, a few hundred triangles.

**3. Cloak — last, because it touches the rig.** Unlike the other two it changes
every animation that already exists. Do it once the first two have landed.

### Horns as progression — the title's third job

The title already claims three meanings: novice, returning green, mandible. The
character design can carry the first and third at the same time.

**Start plain. Earn the horns.** The unit is activated bare, and a good run ends
with it standing there looking like the original 2D Timothy. This converts the
original design from a target that was abandoned as too complex into the thing
the *player* is reaching for — and it costs nothing that isn't already built,
because the trophy socket is the mechanic.

### Colour is allocated, not chosen

[ash-3-enter-gloam-knight.md](ash-3-enter-gloam-knight.md) on the Gloam Knight:

> *"All a shiny dark blue purple-ish hue, like an empty night sky after sunset,
> as if there should be stars."*

That is the knight's entire identity in one line. If the protagonist is also the
blue one, the antagonist reads as a darker recolour of the hero and both are
weaker for it. **Blue-purple is spent on the Gloam Knight.** Timothy gets gold
and bone.

Worth generalising: in a small cast with a tiny shared palette, a colour used
twice is a colour wasted. Assign them deliberately, per character, before
painting anything.

### Already correct — don't touch it

The pale ovoid head with two dark eye voids is the original's masked face, same
family, no notes. It is the most character-defining piece in the design and the
model already has it. Move it toward bone-white during the palette pass and
leave the geometry alone.

### Open

**How the cloak is built.** Cloth simulation is out — Godot's is painful and
glTF will not carry it out of Blender regardless. A floor-length cape is also
wrong for a camera sitting 2.25 m behind the head; it would fill the bottom of
the frame. The current best candidate is a **short tattered shoulder mantle**
skinned to two spine bones — nearly rigid, reads fully at silhouette, and a
dust-caked robot in a torn cloak does not need to billow to land. Unproven.

**Proportions.** The current model is longer-limbed and thinner than the
original, which reads sturdier. Probably fine — long limbs and heavy boots are a
good robot silhouette — but it is a rig change if it ever isn't, so it is not a
cheap decision like the others here.

---

## 5. Environment Assets

Yes to trees, rocks, ground, props, and structures — but **not yet**. Building a library before the game is known means building things the game won't use.

When the time comes:

**Modular kits for buildings.** Wall, wall-with-window, corner, doorway, roof section — all built to a consistent grid (2m is standard). Six pieces build a shed or a cottage. Much better return than modeling whole buildings.

**Collision authored in Blender** using Godot's mesh-suffix conventions: `-col`, `-convcol`, `-colonly`, `-noimp`.

---

## 6. Milestone Ladder

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

## 7. Known Costs & Risks

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

## 8. Open Questions

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

## 9. Immediate Next Actions

1. Finish the robot rig — add socket bones before calling it done.
2. Export clean `.glb` to Godot, confirm the import pipeline works end to end.
3. Build M0 in parallel: capsule + third-person camera, no dependency on the rig.
4. Save incrementally (`Ctrl+Shift+S`) at every session.
