# Living world update — 1.6.0

Residents introduce themselves with their real name, community, role, age, current condition and wants. The same words appear in the profile, with a button to repeat them. Speech uses an installed English text-to-speech voice; availability and naturalness depend on the device and installed voice. It does not require a paid voice service. Settings independently control voices, ambient music, effects and story notices.

Battle Foley changes with technology and becomes audible as the camera approaches a battle. Four simultaneous voices and a precomputed stereo sound bank bound mixing work. Original synthesized sounds cover steel, bows, hooves, catapults, muskets, cannon, rifles, engines, plasma, water and bells. The earlier inclusive WAV-loop crash fix remains in place.

Clickable notices surface weddings, wars, peace treaties, alliances and other important world events. Event details link to their actual participants. Public wedding notices are limited to three per year to avoid overwhelming the HUD; individual marriage and family records remain complete. Dismissed notices remain in the Chronicle. Loading a save does not replay its old notifications.

Coastal settlements gather food with fishing boats. Overseas food trade produces cargo voyages. Opposing coastal nations fight naval wars with actual casualties and water-only routes. Peace treaties temporarily prevent renewed war; compatible trading nations can form alliances that improve trade. Planes begin in the aviation era, followed by helicopters and Space Age rockets at spaceports. These aircraft show civilization activity and patrols; separate aerial combat, fuel and aircraft casualties are not simulated.

Close zoom uses original 32×48 source-pixel people with four walking frames, faces, clothing, armor, tools and weapons. Technology determines spears, swords, bows, firearms and future weapons. Mounted soldiers and horses appear in appropriate eras, and catapults throw animated stones. Lower zoom retains the cheaper renderer. The high-detail sprite cache is bounded at 512 textures.

## Large-population performance

The simulation retains each person's identity, family links, life history and personal consequences. It does not replace residents with anonymous population counters to reach a performance target.

- Birth processing stops searching households once it has enough eligible parents for the births that can actually occur that year. The chosen families and their order are unchanged.
- Active personal effects and deceased records awaiting archival have dedicated indexes, rebuilt on load. Annual work no longer scans every historic override for those operations.
- Mortality and family consequences, marriage searches, laws, civic appointments, archival and sea-route searches cooperate with the frame budget. Main-thread work yields after an 8 ms budget check. This is a target, not a hard execution-time guarantee.
- Old simulation services stay alive until suspended work exits after a world replacement. Generation checks prevent it from changing the new world.
- Annual HUD updates avoid rebuilding power controls and laying out the entire interface every accelerated tick.
- Sea searches are capped at twelve per year, including at most six naval searches, with 12,000 explored tiles per route and 96 displayed transport missions.

Measured on the development PC, not the phone: over six simulated years, 12,000 residents had median 8.66 ms, p95 10.36 ms and maximum 12.32 ms work batches; 20,000 residents had median 8.58 ms, p95 10.27 ms and maximum 15.12 ms. Before mortality batching, the maxima were about 64 ms and 128 ms. These are simulation work intervals, not GPU frame rates. Exact-state comparison against the full household search passed at both populations, including RNG, families, events and resources.

Birth-search CPU over the same five-year 12,000-person profiling fixture dropped from 0.938 s to 0.041 s. The overview drawing fixture measured a 7.27 ms median on the development PC. Performance still depends on device, map, world age, visible detail and simulation speed. Loading and saving very large histories remain separate operations; these measurements do not promise hitch-free performance on every device or world.

Reproduce with `tests/test_population_performance.gd`, `tests/profile_citizens.gd -- --society`, `tests/profile_world_frames.gd`, `tests/test_simulation_frames.gd` and `tests/test_living_world.gd`. Raw measurements are in `test-output/population-trace-v2.log` and the `performance-12000-*.log` files. Prior 1,800-year endurance evidence belongs to its own source fingerprint and must not be attributed to this release.
