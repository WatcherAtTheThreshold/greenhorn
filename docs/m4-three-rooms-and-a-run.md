# M4 — Three Rooms and a Run

*Stage reference for Green Horn. Written 2026-09-04.*

The question this stage exists to answer:

> **Does a sequence of fights produce a decision the player can get wrong?**

Not "can I build three arenas." Three is the smallest number where attrition
exists. One room is a test. Two is a pair. In room three, at 40% hull, the
player has to decide whether to push on — and *that decision* is the thing M4
is checking for. If the rooms don't produce it, you have three arenas rather
than a run.

Everything below serves that. Anything that doesn't is out of scope, same as
M2.

---

## Where we are

M0–M3 systems exist and the fight has been proven ([m2-first-fight.md](m2-first-fight.md),
gate answered 2026-09-02). Carried forward:

| System | State |
|---|---|
| Camera, movement, stairs | done, tuned |
| Attacks, hit detection, feedback | done — flash, knockback, hitstop |
| Two bug species | bug3 bites; bug2 follows and never attacks |
| The shell | breaks, splits, clatters, exposes a soft body |
| Sockets | shared by player and bug, one string to swap |
| Scenery | trees and rocks as MultiMeshes, one draw call each |
| Structures | shelter band at `z -42` — walls, doorway, Blender collision |
| Mortality | Tim has health, `hit`, `death`, and the plot rebuilds |

What is missing is not combat. It is **sequence, state, and an ending.**

---

## The fiction is already written

[*Echoes in the Sub-Station*](ash-2-echoes-in-the-sub-station.md) is not a
different world from Green Horn. It is the same plan read at a different point
on the clock: in the story the re-seeding is working — chickadees, deer,
beavers, a village. In the game it has gone wrong in one direction.

The relationship is written up properly in [shared-world.md](shared-world.md),
including the part that matters most and is easy to miss: **Timothy is this
game's protagonist at the end of his run.** Same role, thousands of
reactivations later, copied from a copy, still walking his route. Which means
Green Horn can be as bleak as it likes, because the world it belongs to has
somewhere gentle to land.

Three things fall out of that for free, and they are worth taking rather than
reinventing:

**The node network is the run structure.** Foundry-node 47, sub-station-node
50, and a shutdown cascade that propagates between them. A technician crossing
open country to reach the next node before his power core dies is already a
run, with the rust clock from [green-horn-story-fragments.md](green-horn-story-fragments.md)
as the reason not to dawdle.

**The maintenance chamber is the shop.** Timothy steps into a cabinet, the
doors close, the station replicates what he needs. No currency, no merchant,
no economy in a world that has none. Bring carapace, get plating. This is
"you wear what you kill" with a machine attached.

**The steward is the theme, already stated.** *"The longer I go without
maintenance, the more bugs I get... the more I want to live."* Degradation
producing a will to live — the Miscalculation section's copy-of-a-copy drift,
written as a character. Keep that line somewhere.

Also worth naming: the peccaries are driven mad by a failing sensor on a robot
nobody suspects. Everyone assumes demons.

That is the **fourth** instance of one shape — Grimelda, the peccaries, the
pacifist bugs, and the oxygen itself. The peccary story is the game's premise
at village scale: *a broken machine makes creatures behave in a way that reads
as malice, everyone blames the creatures, and the fix is to shut the machine
down.* Counted out in [shared-world.md](shared-world.md).

It is not a coincidence to be pleased about, it is a spine — and it answers a
question this stage was going to have to face anyway: **what is at the end of
the run?** Not a boss. The thing that made the beetles.

---

## The inversion — stations are rooms, outside is the corridor

The obvious build is a dungeon: interiors connected by hallways. Invert it.

**Shelter is where rust stops. Open ground is the pressure.**

This falls straight out of the oxygen premise, it uses the shelter band that
already exists, and it converts three separate problems into one:

- *Enclosing the level* stops being a fence problem and becomes a routing
  problem.
- *Why go inside* answers itself.
- *Why leave* answers itself too.

A "room" for M4 purposes is therefore a bounded engagement space, not
necessarily an interior. But at least one should be, because the shelter
doorway already proved geometry is a combat system.

### The gate, the inversion and the clock are one mechanism

Worth being blunt about, because the first draft of this doc separated them
and they do not separate.

The gate asks whether you ever **pushed on when you should have stopped**.
That requires a *stop* to exist. A run whose only options are "continue" and
"die" cannot produce the moment — that is attrition, not a decision.

The inversion supplies the stop: shelter is where you break off. But shelter
is only worth walking to if standing outside costs something, which is the
clock. Take the clock out and the inversion has no work to do, and without the
inversion the gate has no answer available.

So: **either a clock runs in M4, or the gate question changes.** It does not
have to be rust — the honest cheap version is that damage does not heal on
its own and shelter is the only place it does. That is one number and a
trigger volume, and it makes "should I go in or press on" a real question
without committing to a corrosion system.

Rust proper, with hull ticking down in the open air, stays M4b.

---

## What a "room" is, technically

The M2 doc was specific about implementation and this one was not. The
decision matters because everything in this project is code-built, and it gets
expensive to change once M5 hangs items off it.

**Recommended: one scene, three regions, one script.**

`world.gd` already builds an arena from constants and a loop, and already
switches its whole contents on one exported flag. Three rooms is that again:
a `ROOMS` table of position, radius, composition and geometry, and a builder
that walks it. No scene loading, no transition, no state to serialise between
scenes — the run is a walk across one world.

Reasons, in order:

- **Health carrying between rooms is free.** The player node never gets torn
  down, so nothing has to be saved and restored.
- **Death already works.** `reload_current_scene()` rebuilds the whole run,
  which is exactly what dying should do.
- **The corridors are real.** If outside is the pressure, the space between
  rooms has to be somewhere you actually walk. Separate scenes would make the
  gaps into loading screens, which is the opposite of the inversion.
- It stays honest about scale. Three regions on a 140 m plot is nothing.

Separate scenes become right at the point there is a *hub* to return to, which
is past M5. Not now.

---

## Scope

**In:**

- Three sequenced spaces with an entrance and an exit
- Health that carries between them
- One ending state — cleared, or dead
- One thing that persists to the next attempt

**Out** — until the question is answered:

- A hub, a map, branching routes
- Currency, inventory, an item system (M5 owns that)
- Procedural assembly — hand-author all three
- More than two enemy species
- Any optimisation

---

## Room composition

Purpose per room, not difficulty per room:

| Room | Job | Composition |
|---|---|---|
| 1 | Teach and warm up | 2–3 bug3, open ground, no geometry tricks |
| 2 | Introduce the mixed group | bug3 + bug2 together, the doorway/chokepoint |
| 3 | Cost the decision | enough to threaten a damaged player |

Room 2 is where the docile species earns rule 2 from the story doc — they are
in the way, they can be cover, they can trap you. That is already emergent
from collision and needs no support.

**No healing between rooms in the first build.** Add it only once the run has
been lost a few times, and then as a station rather than a pickup — it should
mean going *inside*.

---

## Set and setting — ranked by return per hour

The current plot is not ugly. It reads as a test plot because it is one. In
order of what buys the most:

1. **Lighting, before any asset.** Drop the sun angle, warm it, let shadows
   run long, add fog. The outline says the mood lives in how light catches
   geometry — this is a `WorldEnvironment` and a rotation, and it changes more
   than a week of modelling.
2. **Break up the ground.** The single flat green is what reads hardest as
   sandbox. One darker tone, blotchy, no detail. Vertex colours on a
   subdivided plane will do it.
3. **Topology, gently.** A rise that hides a beetle, a slope that changes a
   fight. Keep grades under `STEP_HEIGHT` 0.28 m or terrain becomes a fight
   with the controller.
4. **Scrub, MultiMeshed, low.** One draw call like the trees. Keep it **below
   beetle height** — clutter that occludes an enemy mid-telegraph undoes the
   work of open question 4.
5. **Barrier.** Fog + treeline + routing beats a wall, and once rooms exist
   the problem mostly dissolves.

**Day/night: no.** Not as a system. A fixed hour is an authored choice; a
cycle is a commitment to making every asset work under two lighting conditions
and doubles playtesting. One excellent time of day is worth more now.

---

## Shops, and the Kithren

**A merchant with money does not make sense here. A fabricator does**, and it
is already written (above). Whatever the building looks like, the shop is a
trigger, a list and a currency — the outline is right that it is a UI problem.
Defer it to M5, where items exist to be traded for.

**On the Kithren:** a friendly village would cost the loneliness the whole
theme rests on. But **one** Kithren, met once, late, who does not explain
themselves, is a different proposition. The story fragments already allow that
humans are a step rather than a destination. The Kithren are that with a face
on it: life came back, it made *people*, they are simply not the ones on the
specification the robot is executing.

That is the twist standing in front of the player in a hood, requiring no
dialogue. **Not M4.** Recorded here so it doesn't evaporate.

---

## Rogue-lite: keep it

Death-as-backup and reactivation-drift are load-bearing for the theme in a way
that is genuinely rare — the genre structure and the story are the same
object. And practically, the rogue-lite is the cheapest available route to an
*ending*, which is what turns a sandbox into a game. Not the place to
reconsider.

**But run the free test.** Open question 5 keeps refusing to die. Put one bug2
in the run and let it follow across all three rooms. Existing systems, no new
assets, no design decisions. It answers whether the follower reading survives
contact with real combat — during M4 rather than instead of it.

---

## Done when

- [ ] Three spaces exist, entered and exited in sequence
- [ ] Health carries between them
- [ ] The run can be won and can be lost
- [ ] Death returns you to the start with *something* retained
- [ ] Room 2 mixes both species and has a chokepoint
- [ ] Lighting and ground pass done — it no longer reads as a test plot
- [ ] One bug2 followed you the whole way, and you noticed how that felt

And the actual gate, which is not a checkbox:

> **Did you ever push on when you should have stopped?**

If yes, the loop works and M5 has something to hang items on. If the run is
just three fights in a row with no moment of doubt, the problem is pacing or
persistence, not content — and adding a fourth room will not fix it.

### First run — 2026-09-04

The rooms exist and have been played. The gate itself is **not answered yet**;
what follows is what the first pass turned up.

**The fight has a skill gradient, and it holds under a run.** Running in
swinging blind gets you killed. Kiting and reading the wind-up wins — *and is
still not a guarantee.* That combination is the hard one to get and it is
worth naming precisely, because it is easy to lose while tuning:

- the telegraph is **legible** — there is a pattern to watch
- reading it is **rewarded** — kiting works
- and it is **not solved** — knowing what to do is not the same as doing it

Four separate decisions are producing that between them, and none of them
should be touched casually: the bite is a wedge rather than a sphere, so the
flank is real; the beetle commits to a direction and does not track, so
backing off is real; a hit cancels a wind-up, so attacking is *also* an
answer; and `ATTACK_CANCEL` finally costs something now that being wrong is
punished.

**Navigation is unclear, and paths are the wrong fix.** *"Which direction do I
go next"* was the first thing the run raised. The reflex is a path and hard
barriers, but that fights the inversion — if open ground is the pressure, then
being lost is a *tax*, and railing it removes the travel the fiction wants.

The real problem is that **the rooms are not landmarks yet**. Stones are 3.5 m;
trees are 3.6 m. A ring reads as more scenery at exactly the moment it should
read as a destination. Make the deep ring's stones visibly taller than the
treeline and it becomes something you steer by — one number, no barriers, and
it turns "where do I go" into "over there".

The world-space room captions are a debug aid, not a design. They should come
out when the landmarks go in.

**Exploration already has its first reward, and it is the shelter.** It is off
the path, it is optional, and choosing it costs and gives something. Whatever
else gets scattered off-route later, that shape is already working — worth
noticing before inventing a collectible.

---

## Open questions for this stage

1. **What persists between runs?** Something must, or death is only a reset.
   Cheapest candidate: the shell you were wearing when you died.

   But the better one is already written. Ash 2 has Timothy upload the
   steward's chip into a station console — *"You would persist but without
   your physical body to perform maintenance the facility will fail."*
   **You persist, and the place holding you degrades for it.** That is
   meta-progression with a price attached, in the fiction the story doc
   already committed to, and it beats a retained item. Not necessarily M4,
   but it is what M4 should leave room for.
2. **Does rust run during M4, or is health enough?** Answered above, at least
   in part: *something* has to run, or the gate question has no answer. The
   cheap version is that damage never heals except inside. Rust proper is
   M4b.
3. **Hand-authored or assembled rooms?** Hand-authored for M4, definitively.
   The question is whether room 3 reveals a natural module size.
4. **Does the 2 m modular grid survive an actual room?** Untested since the
   shelter band.
5. **Where does the run end — a door, a station, or a boss?** A station is
   the fiction's own answer and needs no new asset type.
6. **Does the follower read differently across three rooms than across one?**
   The free test above. Add the answer here.

---

## Reference

- [m2-first-fight.md](m2-first-fight.md) — the stage this builds on
- [shared-world.md](shared-world.md) — the clock, the canon, what the stories supply
- [green-horn-outline.md](green-horn-outline.md) — the production plan
- [green-horn-story-fragments.md](green-horn-story-fragments.md) — theme, rust, pacifists
- [blender-checklist.md](blender-checklist.md) — export traps, naming, scale
- [ash-2-echoes-in-the-sub-station.md](ash-2-echoes-in-the-sub-station.md) — nodes, the fabricator, the steward
- [ash-3-enter-gloam-knight.md](ash-3-enter-gloam-knight.md) — drift, and what a technician becomes
