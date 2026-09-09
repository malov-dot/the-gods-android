# The Gods — release 1.7.1: Cast & See

Fixed discarded fast-forward time during busy simulation years and delayed power selection. Area clicks queue with their original power and coordinates instead of silently dropping later clicks. Visible impact feedback lasts real seconds, and Observe/Escape cancels pending casts immediately.

Personal powers arm map selection. Casting focuses the actual person, shows their named animated marker and concrete stat/condition changes, and leaves time paused for inspection. Meteor/weather impacts can affect water appropriately. See [CASTING_UPDATE.md](CASTING_UPDATE.md) for verification and limits.

## Release 1.7.0: Lives & Stories

Single-player sandbox only. Old versus saves convert automatically; AI opponents, hotseat turns, winning conditions, and deity restrictions are removed. All powers remain free.

A quiet story journal connects family promises, interventions, and consequences. Residents have saved projects with progress, rewards, and setbacks. Profiles prioritize immediate needs, with full stats one tap away. Resurrection restores the actual person and family; eligible adult heirs can inherit leadership. Wars and diplomacy take priority over royal weddings, and clothing/hairstyles have more variation.

See [SANDBOX_UPDATE.md](SANDBOX_UPDATE.md) for behavior, current test results, and remaining design work. The earlier 1,800-year exact-state discrepancy remains unresolved; historical text below saying it was in progress describes that release's status at the time, not a currently running test. Full ZIP packaging remains gated.

## Release 1.6.2: Quiet News and Moving Boats

Silent, selective world news and longer connected fishing routes, consistent ship motion, and directional wakes. See [NEWS_AND_BOATS.md](NEWS_AND_BOATS.md).

## Release 1.6.1: Visible Personal Consequences

- Every personal action has a distinct map symbol and a readable profile status. Active curses, possession and ongoing influences display their remaining years. Instant actions are labeled as the last intervention; expired effects are marked as ended. Feedback is saved with the person.
- Previews use direct explanations and specific changes. Results display actual before-and-after stats, distinguish a refused bribe from a passed law, and provide a **See change on map** button. Action notices stay compact.
- Removed essence charges from all personal and world powers for human and computer players. Removed cost labels and the essence HUD. Shared-PC turns retain three interventions per player.

## Release 1.6.0: A World Worth Following

- Spoken personal introductions reflect the selected resident's name, role, condition and wants. Profiles display the same words and offer replay. Uses installed English device speech voices.
- Era-specific battle Foley becomes audible near the camera. Detailed close-up people have animated 32×48 source-pixel faces, clothes, armor and weapons; appropriate eras include cavalry and catapults.
- Clickable notices open weddings, wars, treaties, alliances and personal events, with links to the participants. Fishing produces food; overseas trade has cargo voyages; coastal enemies fight naval wars. Later civilizations display planes, helicopters and spaceport rockets.
- Large-world birth searches stop when enough eligible families have been found. Dedicated indexes track active effects and pending historical archival. Smaller simulation batches cover mortality, families, laws, appointments, history and route finding while preserving individual outcomes.
- Exact simulation-state comparisons pass at 12,000 and 20,000 residents. Host measurements and implementation limits are documented in [LIVING_WORLD_UPDATE.md](LIVING_WORLD_UPDATE.md); these are not guaranteed frame rates on every phone.

## Release 1.5.1: Follow Your People

- Native swipe scrolling works in resident lists, profiles, and long choice sheets. A swipe cancels the pending button press so it cannot open a resident or toggle a favorite. Mouse-wheel scrolling remains available on PC.
- Current community leaders appear first with a gold LEADER label. The Leaders tab lists leaders across the world.
- Stars in resident rows and a profile button add or remove favorites. Favorites spans all communities and is stored with each saved world. Deceased favorites retain their identity and history.
- Existing worlds need no conversion for favorites. New worlds start with an empty favorites list.

## Release 1.5.0: Living Society

People now drive the course of their civilization. Click a person to open a stat chart, family, influence options, and history. Profiles show age, gender, adult orientation, job, honor, empathy, courage, resentment, health conditions, wealth, crimes, good deeds, and community contributions.

- Adults form compatible households. Newborns have actual parents; children grow into work. Families persist across migration, bereavement, inheritance, aging, and death, including orbital residents.
- Seventeen personal interventions cover care, character, and politics. Healing, curse, possession, and related powers select one person. The toolbar shortcuts open a person selection or preview.
- Officials can accept or refuse bribes. Laws favor specific groups and change their wealth, wellbeing, education, or resentment.
- Bargain with an adult over a sick relative, then heal that relative. A kept promise can bring public relief or repression; a dishonest adult can break their word.
- Theft and murder have real culprits and victims. Investigation, imprisonment, revelation, pardon, and the victim's response affect lives.
- Opposition has an actual organizer. Tyranny and resentment can lead to deposition, rebellion, and a civil war between rebels and loyalists.
- Overview, Family, Influence, and History tabs keep the profile usable on phone and PC. Society panels expose officials, laws, opposition, and justice.
- Android uses the device's logical display density instead of the engine's reduced scale. On the Fold cover display, a 48dp control becomes 126 physical pixels, up from about 76. Fold and orientation changes recalculate the layout.
- A touch panel replaces the time dropdown with large 1×, 5×, 20×, and 100× choices, explanations, pause, and close. Choosing a speed dismisses its input layer; time and Back remain responsive during a pending simulation year.
- World creation and community selectors also use touch-aware choice sheets. Back and Escape dismiss the choice before the form underneath it, and open choices adapt when the phone rotates.
- Brush size and volume accept native taps and drags, including gesture cancellation, with at least 48dp touch areas. World input still suppresses duplicate mouse events.
- Simulation work is spread across frames in playable builds. Inspections wait for the current year; Back and Observe cancel queued requests. A replaced world cancels its unfinished work.
- Births and migration update only the affected resident lookups. A measured 700-year world ran three years in 16.35 seconds versus 28.69 seconds before this change; its complete world state and inspected profiles matched. Timing is from this Windows test host, not the phone.
- Large saves use compression. Older routine household notices are condensed after death; genealogy, lifetime stats, and recent major events remain.
- Existing saves migrate to the new society system. Personal powers retain versus costs and turn limits. The Android music-loop crash correction remains in place.

This release has bounded mechanics and recent personal histories. Economy and battle totals still combine individual contributions with settlement calculations; Street View depicts a selection of actual residents.

Android 1.5.0, code **10503**, is published and installed over the Fold's existing app without clearing data. Native touch fixtures pass **343 checks**, living society **2,572**, profile/family UI **200**, and the live public download path **17**. The final phone controls and in-app Android installer have not been exercised on unlocked hardware. The extended simulation/save run is still in progress; a 900-year full save/load check passed, and simulation reached 1,100 years. No completed 1,800-year result is claimed yet.

# The Gods — release 1.4.1

September 8, 2026. Fixes the Android crash shortly after the world appears. The ambient WAV loop ended one sample past its audio buffer; its end now stays inside the clip. Music remains enabled.

The old release fails the new audio boundary regression. The correction passes 13 checks and mixes 11,633,400 frames through Godot's native mixer. The same signed 1.4.1 APK was installed over 1.4.0 on a Galaxy Z Fold 8 running Android 17, then checked through repeated music loops, world creation, touch selection, simulation playback, and background/resume. App data was not cleared. The Android in-app permission/installer route remains unverified because this installation used wireless ADB.

Package: `games.thegods.sandbox`, version code **10401**. APK: **54,096,096 bytes**, SHA-256 `410e7ffeaec796ae61b9f54131bec1d16b371afec1ac73a79bc77ae239507b06`.

## Version 1.4.0 — initial Android release (history)

September 8, 2026. Godot 4.7.2. Initial native Android edition; existing Windows and browser packages retain their 1.3 release names.

## Android app and startup updates

The full game is packaged as **The-Gods-Android.apk**, a signed universal build for **ARM64 and x86_64**, targeting **Android 7.0 or later**. Public downloads and update manifests use [The Gods Android releases](https://github.com/malov-dot/the-gods-android/releases). The package is `games.thegods.sandbox`, version **1.4.0**, Android version code **10400**.

Each cold launch checks the stable manifest and automatically downloads a newer release. The updater checks its length, SHA-256, package, version, and signing certificate. Android still requires permission and confirmation to install. Offline use, failed checks, and canceled updates can continue into the installed game. Installing a same-key update retains local worlds; uninstalling or clearing app data can remove them. Saves do not synchronize between Android, Windows, and browsers.

Android display density and safe areas keep controls within usable screen bounds. Back closes the current sheet or palette, cancels an active tool, then opens the game menu. Pause/suspend notifications request autosave when enabled. These changes preserve the existing simulation, citizen identities, personal actions, and versus rules.

## Version 1.4 validation and limits

- Final APK: **54,096,056 bytes**. SHA-256: `a332d93e5e5c756189c829217e48375deb8c6c066dc6dc8fef9ceffb78bbc0f1`.
- Actual publisher preflight verified signature, package/version, both architectures, the durable signing key, and **32 production-source hashes**. Build inspection verified updater/FileProvider registration and the Godot and font license notices inside the APK.
- Controlled updater acceptance passed **61 graphical / 58 headless checks**. These exercise manifest validation, network/download outcomes, update transitions, and the native-interface contract using fixtures. Native validation rules passed **10 JVM tests**.
- Current interface, mobile, HUD, and Android lifecycle suites passed **49, 154, 1,632, and 151 checks**, respectively, with zero failures, warnings, or errors. Lifecycle coverage includes Back priority, unchanged game state, 360-pixel layouts, 3× display density, and simulated safe-area insets.
- **Physical Android hardware installation and a complete permission/installer/update cycle remain unverified.** The available emulator crashed. Build checks and Windows-rendered fixtures do not establish phone compatibility, native lifecycle behavior, or device performance.

The publisher defaults to local preflight. Publication uploads the APK and manifest to an unpublished draft, verifies their downloaded hashes, then makes the complete release public. It rejects stale production sources, reused or lower version codes, and signing-key changes. The public repository contains distribution instructions and release files; signing material and development source remain local. See [ANDROID.md](ANDROID.md) for installation and release procedures.

No new demographic mechanic or simulation endurance run is claimed for 1.4. The earlier results below are retained as historical evidence.

## Version 1.3 — game HUD (history)

September 8, 2026. Godot 4.7.2. Native Windows x86-64 and browser editions.

### Game HUD replacement

The user's review found that the previous interface covered too much of the world and felt like an application dashboard. Version 1.3 replaces that layout with a game HUD organized around direct world interaction. The map fills the viewport, and detailed information opens only when requested.

- **Desktop:** left category rail with an inward-opening ability palette, upper-left resources, upper-right utilities, lower-left minimap, and lower-right time controls. Selected people/towns and active tools use a compact bottom-center strip.
- **Phone portrait:** top resources and time controls, bottom categories with abilities expanding upward, a compact selection summary, and temporary bottom information sheets.
- **Phone landscape:** top resources/time, a bottom category tray, and temporary right-side detail sheets. The phone layout has no desktop rail or permanent minimap.
- **Terrain / Nature / Life / God / Devil / Disasters** lead to ability icons and short names. Selecting an ability closes the palette and arms it immediately. The active tool shows the real cost, implemented radius control, Info, Cancel, and an area preview on the world.
- No permanent inspector or chronicle columns. People, factions, overlays, history, saves, and settings remain accessible through utilities or the menu. Essential touch targets are at least 48 logical pixels; explanations are available by tap.
- Dark translucent metal, muted gold edges, drawn game icons, compact type, and flat list rows replace the former large cards and headings.
- Person sheets use **Overview / Influence / History**; factions use **Overview / Leaders / Towns**. All resident abilities, numeric personal-action forecasts, histories, and selectable leaders remain available. Long explanations expand on request.
- New-world framing fills the window. **Fit / Home** explicitly pulls the camera back to show the complete world.

This is an interface and input update. The four scenarios, 38 world powers, six personal actions, persistent citizen identities, fourteen eras, game modes, and save format continue from 1.2. It adds no demographic or civilization mechanic.

### Version 1.3 validation

The final graphical HUD pass recorded **1,695 checks with zero failures** across **1920×1080, 2560×1440, 1366×768, 844×390, and 390×844**, plus a **3×-density phone viewport**. The corresponding headless HUD pass recorded **1,632 checks**. Broader mobile interface acceptance passed **171 graphical / 154 headless checks**. These runs completed without warnings or errors.

Checks exercise actual category/ability clicks, selection expansion, profile/faction tabs, Info/Cancel, save/load sheets, click-through prevention, and hotseat budgets. Actual End turn clicks verify the active deity, the three-action allowance, and exactly ten years after both players finish. Large-population and long era/year labels fit in both phone orientations and game modes; the portrait resource strip keeps a 13-pixel gap before Menu. Observe and palette highlights follow the selected tool through each input path.

**63 current HUD state captures plus one art contact sheet** cover the required layouts, profiles, numeric forecasts, factions, directory, menu, save/load, and both deities' turn controls. Content-sized portrait and landscape sheets were visually checked. The art/minimap suite passed **13 checks**, rendering **71 icons twice and 20 portraits**.

Measured idle HUD obstruction was **4.3% at 1920×1080, 2.4% at 2560×1440, and 8.4% at 1366×768**. Both phone orientations and the 3×-density phone measured **13.0%**. These figures describe idle controls; an explicitly opened palette or detail sheet covers additional space. Graphical review includes profile, intervention, faction, directory, and narrow-menu captures.

The final HUD runs include the sheet-sizing, world-framing, and touch-preview refinements. No new simulation endurance result is claimed for this interface update; the 1.2 gameplay and persistence evidence below remains historical. Packaged `BUILD_INFO.json` separates those retained baseline logs from current HUD and regression results, records counts directly from completed logs, and includes source, configuration, test, and artifact hashes. Raw reports are included under `verification`.

The native executable and browser package names were unchanged: `build/The Gods.exe`, `dist/The Gods - Windows.zip`, and `dist/The Gods - Browser.zip`. Browser files remained under `build/web`, served locally with `Play on Phone.ps1`. Saves retained their existing Windows or per-device/browser/site storage behavior. At the 1.3 release, actual phone hardware had not been tested, and native Android/iOS packages were not distributed.

## Earlier releases

The following notes preserve the systems and validation delivered by earlier releases. The navigation and appearance described in 1.2 have been replaced by the 1.3 HUD above.

## Version 1.2 — persistent residents (history)

September 8, 2026. Godot 4.7.2. Native Windows x86-64 and browser editions.

### Every resident has an identity

- Every whole surface or orbital resident has a stable, unique identity and an accessible profile. The paginated **People** directory searches by name, role, or identity and covers the complete living roster.
- Profiles expose portraits, age, location, role, traits, health, happiness, beliefs, loyalty, ambition, standing, leadership, wisdom, strength, influence, and recorded personal history.
- Migration, colonization, orbital relocation, promotion, and succession preserve identity. Dead identities are retained and never reused; age at death remains fixed. Named leaders and prophets resolve to the same resident records rather than adding duplicate people.
- The people pictured in Street View are selected real living residents with selectable identities. Rendering remains bounded for performance; residents beyond the visible selection remain available in the directory.
- **Realms** presents faction populations, settlements, wealth, food, eras, beliefs, stability, aggression, current wars, and accessible leader profiles.

### Intervene in a life

Six personal actions join the existing 38 world powers: **Healing Touch, Spark of Insight, Personal Blessing, Private Temptation, Whisper of Doubt, and Feed the Fire**.

Each action presents its calculated personal changes, community contribution, duration, and cost before use. Role and standing determine reach: scholars contribute to research, farmers to production, healers to health, and rulers or military figures can exert wider influence. Personal changes happen immediately; continuing community effects run for **12 simulated years while the person lives**, follow the person's community, and expire. Repeating an action renews its timed effect.

Personal actions enforce deity, essence, finished-contest, and active-player restrictions in versus. Successful interventions count toward the shared-computer three-action turn. Rejected actions leave state unchanged and charge zero; sandbox actions are free. Preview and application share the same calculation. Personal history and the Chronicle record consequences.

The compact citizen registry, personal changes, histories, and effect durations persist through save/load. Existing saves remain compatible and receive a resident registry on restoration. Saves validate issued identities, disjoint living/dead membership, population agreement, personal data, and effect records before loading.

### A responsive divine interface

- New celestial navy, lilac, and gold styling, illustrated portraits, Inter body text, and Cormorant Garamond headings.
- **World / Powers / People / Realms / Menu** navigation, with a map and context panel on desktop and scrollable sheets on narrow screens. Back controls, explanatory text, and larger action targets support touch use.
- Powers show their explanations before targeting. Personal profiles show concrete forecasts and an explicit action button. People and faction leaders are reachable through the main navigation.
- One-finger drag pans, taps inspect or cast once, and two-finger gestures zoom and pan without accidental casting. Observe mode can select a pictured person. Existing mouse, keyboard, and sandbox terrain-painting controls remain available.

### Distribution and saves

The Windows executable runs without Godot or Python. The browser package is **dist/The Gods - Browser.zip**, with exported files under `build/web`. **Play on Phone.ps1** starts a local Python server for devices on the same network; `tools/serve_phone.py` is the manual entry point. The current LAN URL is **http://192.168.1.174:8093** and can change with the host's network address. The Windows host must remain available while serving the browser edition.

Browser saves belong to each device, browser profile, and site address. They do not sync with Windows saves or another device. Save from the game menu before leaving the browser; browser shutdown is not a reliable final-save event.

Responsive layouts and graphical rendering were exercised at desktop and phone portrait/landscape sizes on Windows. **Actual phone hardware has not been tested, and native Android/iOS packages are not distributed.** Browser/device compatibility and performance require broader testing.

### Version 1.2 validation

These results were recorded for version 1.2. They are historical evidence, not new version 1.3 reruns. Each suite is reported separately; overlapping assertions are not combined into a release-wide total.

- Citizen suite: **52 checks**, including complete compact roster coverage, identity conservation through migration and colonization, orbital membership, mortality, frozen death ages, nonreuse, promotion, old-save upgrade, role-dependent consequences, and succession in a one-resident orbital habitat.
- Personal intervention/save suite: **151 checks**, including all six shared previews and applications, exact successful charges, zero-cost immutable rejections, sandbox behavior, hotseat boundaries, registry validation, persisted individual data, and deterministic continuation after loading.
- Touch suite: **54 checks** for gestures, person selection, and settlement double-click priority. Pictured-people suite: **333 checks** connecting visible people to actual living identities.
- Responsive graphical interface suite: **169 checks**, with portrait, landscape, desktop, 3x display density, personal turn budgets, doctrines, technology, and introduction flows.
- Final simulation suite: **73 assertions**, including a 1,800-year world with **127,554 residents in 39 towns**, reaching Space. The final world-power/save suite passed **308 assertions**, including another late-age save round trip at year 1,810 with 99,593 residents.
- Browser interaction checks verified resident selection, a healer's wisdom changing from 66 to 88 after inspiration, and the same value after saving, reloading the browser, and loading the world. Portrait and landscape rendered without browser console errors. The Windows executable rendered a gameplay capture and exited successfully.
- Existing UI checks passed 49 headless / 56 graphical checks; renderer 51, street integration 100, architecture 297, people detail 42, and calamities 10 checks (2,800 fixtures) also passed. Resource outcomes and all 12 competitive starts passed. Two ObjectDB instances were reported at shutdown by the headless UI/detail fixtures; graphical UI and exported-game checks exited without this warning.
- A dedicated citizen-era endurance run completed **1,800 simulated years**, retained **89,381 inhabitants**, and passed validation plus an actual save/load round trip. The complete JSON was **7,473,954 bytes**. That long run passed **144 checks** on the integrated registry implementation before final identity/search, small-habitat succession, and rejected-result refinements. Shorter suites cover the subsequent changes. It is endurance evidence for this update, not a claim that every final UI/export revision repeated that run.
- Performance profiling identified repeated ruler succession and unnecessary registry indexing. Selecting adult successors and preserving indexes for metadata-only changes reduced the measured first 400 simulated years from about 75 seconds to about 6.4 seconds on this machine. This is a desktop simulation benchmark, not a phone frame-rate measurement.

Reproducible scripts are under `tests/` and `tools/`. `tools/validate.ps1` runs the acceptance suites; retained local logs and screenshots are under the ignored `test-output/` directory. Tests use isolated storage rather than player saves.

### Representation and remaining limits

Individual identities, profiles, interventions, and personal history are persistent. Demographic growth, mortality, economics, and combat still use settlement-level calculations. Bounded street and combat renderers display selected residents and actual wars; they do not run an independent daily-life or collision-based battle simulation for every inhabitant.

Heaven, Hell, and wandering souls remain persistent totals. Space includes inhabited orbital habitats supplying research and resources, whose residents remain influenceable after surface loss. Explorable planetary maps, complete family trees, editable holy books, playable afterlife maps, online multiplayer, and 4–8-player pantheons remain outside the delivered scope.

Balance coverage uses a small scripted seed sample. Wider human playtesting, broader hardware coverage, actual phone tests, and commercial-release certification have not been performed. Large mature worlds can advance below the requested fast-forward speed.

### Earlier release history

The evidence below describes the **1.0/1.1 code at the time of those releases**, before the complete citizen registry and responsive interface. It is retained as historical validation and is not a final-current endurance claim.

#### Version 1.1 — Street detail

Street View introduced 450% settlement focus, zoom up to 1200%, fourteen architectural sets, visible clothing and tools, age-specific guards, real war fronts and casualty records, and ten calamity renderers. Roof damage persists and repairs; healing and rain clear related active condition visuals. Coast-aware paths and reserved neighboring plots improve close-up scenes. At that time, most pictured citizens were representative animations rather than the real resident identities introduced in 1.2.

Version 1.1 added **100 detail integration, 297 architecture, 42 people/war, and 10 calamity checks**, including 2,800 disaster fixtures. The original **475** gameplay, persistence, UI, and renderer assertions passed again, bringing the then-reported total to **924**, plus resource and competitive-start comparisons. Graphical captures covered all ages, maximum zoom, wars, disasters, coastlines, neighboring settlements, and a naturally generated world.

#### Original gameplay and validation

The earlier release delivered four scenarios, unlimited sandbox, computer versus, local three-action turns, enforced essence budgets, a sustained-dominion victory condition, extinction handling, 38 world powers, fourteen ages, independent research, beliefs, trade, wars, migration, religions, emissaries, artifacts, orbital habitats, validated saves, and original ambient sound.

- **67 simulation assertions** covered repeatable generation, eras, bounded resources, belief accounting, deterministic continuation, mortality, afterlife, orbital survival, and contest timing.
- The then-current endurance world reached Space after **1,800 years**, retaining **137,208 inhabitants across 42 towns/habitats**. This population is from the earlier simulation, not the 1.2 citizen-era endurance run.
- Eight scenario worlds, covering four scenarios and two seeds each, survived **1,200 years** and reached Space; A Dying World retained an early crisis.
- **308 power/save assertions**, **49 UI checks**, and **51 renderer checks** covered powers, costs, rejection immutability, timed effects, saves, settings, actual interface flows, gesture behavior, and orbital inspection.
- Resource checks verified mineral effects on research/wealth and climate effects on existing farms. Twelve competitive-start comparisons verified equal global starting allegiance across four scenarios and three kingdom counts while preserving local rival faiths.
- The Windows executable launched with the native OpenGL renderer, produced a gameplay screenshot, and exited without script errors or leaked objects.
- A small counterplay sample saw God win two of three worlds against the AI using Sanctuary before cleansing and blessings; repeated unprotected cleansing performed poorly. These results informed the guide and do not establish broad competitive balance.

Historical graphical validation used this Windows machine with an NVIDIA RTX 3080.

### Licenses

Godot Engine uses the MIT license; see `GODOT_LICENSE.txt`. Bundled **Inter** and **Cormorant Garamond** fonts use the **SIL Open Font License 1.1**. Full copyright and license notices are retained in `assets/fonts/inter-OFL.txt` and `assets/fonts/cormorantgaramond-OFL.txt`.
