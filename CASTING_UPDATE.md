# The Gods 1.7.1 — Cast & See

The reported problem was on desktop. This update fixes the shared desktop/touch controls, with graphical desktop mouse verification. No phone connection or device installation was used.

## Changes

- The time accumulator now counts elapsed time while an asynchronous year is processing. Previously that time was discarded, making faster settings less effective. The HUD is refreshed at a bounded rate instead of after every fast year. World years remain readable rather than being rounded to thousands on smaller displays.
- Category and power selection happen immediately even during a busy year. Up to sixteen pending casts retain the exact power, position, radius, side, and world generation requested. The game acknowledges clicks immediately, applies casts at safe year boundaries, and explicitly reports a full queue. Changing the selected tool cannot turn an earlier click into a different power. Observe, Cancel, Escape, and Back cancel pending casts; canceled markers disappear too.
- Area powers show a named impact at the clicked location. Presentation lasts four real seconds, independent of pause and fast-forward, and includes actual disaster animation. Failed targets show red feedback and a reason. Effects are capped at sixteen and culled outside the viewport; they never change saved simulation outcomes or RNG.
- Healing, blessings, curses, possession, and similar powers still act on an individual. Choosing a personal shortcut arms map selection: click a person for their preview, or click a community to choose a resident. This replaces the unsolicited directory/old-target preview when merely choosing a power. The tray explains whether a power expects land, a community, or a person.
- Personal casting focuses the actual person, adds an eight-second named animation, and opens a compact consequence panel. The panel shows real before/after stats, changed conditions, and the actual outcome (including refusal or no immediate stat change). Time stays paused so the player can inspect the result; close the panel and press Play to resume. Existing saved status markers and family/community consequences remain.
- Meteor impacts can deepen water without creating accidental land. Rain, storms, and earthquakes can also act over water. Fire and population-dependent powers still require appropriate targets, with clear failure feedback.
- Removed an accidental non-stat row from community Overview and leftover competitive UI restrictions.

## Verification

`tests/test_casting_flow.gd` passes **30 checks** in both headless and graphical runs. It operates real category buttons, ability buttons, and map input using mouse and native touch events. Coverage includes busy-year selection, multiple queued casts, actual cult/damage changes, ocean meteor impacts, personal target selection and casting, named visual feedback, and immediate Observe/Escape cancellation. Captures of the desktop meteor, curse result, and close-up affected person were inspected.

The scheduler fixture inserts a fixed three-frame delay into each year, then supplies three seconds of elapsed frame time. At 1×, 5×, 20×, and 100× it completes **3, 15, 60, and 60 years**. The last two saturate the fixture's processing capacity. These are controlled scheduler measurements, not a promised frame rate or real-world benchmark; mature worlds can still be limited by CPU work.

Simulation-frame acceptance passes **12 checks**, preserving exact state across forty synchronous/cooperative years and confirming safe interruption. Power/save acceptance passes **267 assertions** without `--long`. The interface-through-resources regression run passes, including interface 40, responsive UI 151, time/touch 327, resident navigation 68, living world 273, personal feedback 91, HUD 1,653, identity 74, society 2,583, society UI 218, personal powers/save 329, and rendering/resource suites.

Evidence is under `test-output/casting-flow-final.log`, `casting-visual-final.log`, `casting-simulation-frames.log`, `casting-powers.log`, `casting-regressions-2.log`, and the corresponding captures. Failed intermediate runs remain separate. The earlier long-history whole-state save-continuation discrepancy remains unresolved and was not rerun or waived; standalone ZIP packaging remains gated.

## Delivery

Windows `build/The Gods.exe` was rebuilt (110,991,344 bytes) and launched with exit code 0 and no stderr errors. `Play The Gods.cmd` starts this current build; close older game windows first. Browser files under `build/web` were refreshed. Android 1.7.1 / 10701 is published with 47 production-source hashes and the original signing certificate verified, and the live public update download passes 17 checks. No physical-phone installation is claimed.
