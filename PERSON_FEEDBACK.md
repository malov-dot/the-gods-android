# Personal feedback — 1.6.1

Select a resident and open **Influence**. Every action has a short explanation; its preview shows duration and any numerical personal/community effects. Bribery predicts whether that particular official accepts or refuses. After applying an action, the result shows actual before-and-after stats and offers **See change on map**.

The affected person has a colored ground ring and a distinct overhead symbol. Curses add purple particles; possession adds red eyes. The profile spells out the status and remaining years, so color is not the only way to identify it. Multiple effects can coexist. The map displays up to three symbols; the profile lists them all.

| Action | Symbol | Color |
| --- | --- | --- |
| Healing / infernal healing | + | Green / orange |
| Curse | X | Purple |
| Possession | ! | Red |
| Release curse or possession | O | Pale turquoise |
| Bribe / temptation | $ | Gold / amber |
| Pardon | U | Turquoise |
| Expose deeds | ? | Pale gold |
| Comfort | H | Pink |
| Teach | B | Blue |
| Mercy promise / dark bargain | V | Mint / violet |
| Inspiration | * | Blue |
| Blessing | ^ | Gold |
| Corruption | X | Muted violet |
| Incitement | ! | Orange |

Ongoing curse/possession and community influences read their actual expiry. Removing an affliction removes its active marker. Instant interventions are identified as **Last: …, year …**, rather than pretending that a permanent buff is active. Expired effects become a gray historical marker labeled **effect ended**. A refused bribe and a search finding no hidden crime have explicit outcomes. Latest intervention metadata survives saving and loading; old saves without it remain supported.

All personal and world powers have **zero essence charge** in every game mode, including computer actions. Prices and the essence HUD are removed. Three interventions per player remain the shared-PC turn rule. Civilizations still have their own economic consequences, such as the private wealth an official receives from bribery.

Rendering reads only the visible person's current flags, at most six active influences, and one latest-intervention record. It does not search their history or scan every resident. Compact two-line notifications prevent action feedback from covering the person.

Verification: 89 focused checks, 335 personal-power/save checks, 287 power/save checks, native graphical screenshots, and the existing touch, HUD, society, rendering and balance suites. The exported Windows executable also launched and captured successfully. See `test-output/person-feedback-visual.log`, `person-feedback-final-suites.log`, `personal-powers-free.log`, `powers-free.log`, and `pc-1.6.1-smoke.log`.

The previous gameplay's 1,800-year save test completed but failed its exact whole-state continuation hash comparison; population and RNG continuation checks passed. That discrepancy has not yet been diagnosed. It does not count as a passing endurance result for this version, and the full desktop-archive packaging gate remains in place.
