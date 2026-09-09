# The Gods

**A world of consequence.** A single-player sandbox god game for Windows, Android, and browsers, built with Godot 4.7.2. Release **1.7.1 — Cast & See** removes computer opponents, shared-PC turns, victory conditions, and deity restrictions. Civilizations still form alliances and fight each other autonomously. You control both benevolent and destructive powers, freely.

## Play

**Windows:** [Download The-Gods-Windows.exe](https://github.com/malov-dot/the-gods-android/releases/latest/download/The-Gods-Windows.exe) and double-click it. The executable contains the game and needs no Godot installation, account, or internet connection. In a built development checkout, **Play The Gods.cmd** runs **build/The Gods.exe**.

**Android:** download **The-Gods-Android.apk** from the [latest release](https://github.com/malov-dot/the-gods-android/releases/latest). Install over the existing app to retain local saves. On a cold launch, the app checks the public update page and downloads an available update. Android confirms installation. If offline or an update fails, **Play offline** opens the installed game. See [ANDROID.md](ANDROID.md).

<a id="install"></a>
On Android, open the downloaded APK, allow your browser or file manager to install apps from this source if prompted, and confirm installation. The APK supports Android 7.0 or later on ARM64 and x86_64.

The [GitHub repository](https://github.com/malov-dot/the-gods-android) contains the game source, assets, tests, build tools, and documentation for both platforms. Ready-to-play builds are under **Releases**; downloading the repository alone does not include the Windows executable or Android APK.

**Browser:** run **Play on Phone.ps1** on the Windows host, then open the address it prints on a phone using the same Wi-Fi. Keep the host running. The exported files are in `build/web`; serve them over HTTP, rather than opening `index.html` directly. The standalone distribution ZIPs are historical; use the rebuilt executable or browser folder.

Choose a scenario, world size, difficulty, and seed. **Play** starts time. **Observe** lets you select people and communities. There is no opponent setup, turn handoff, winning threshold, or game-over lock. Older versus saves automatically open as unrestricted sandbox worlds, retaining their people, families, and history.

## Follow a life

Click a pictured person, or open **Menu → People**. The directory offers Community, Leaders, and Favorites views, plus search. Leaders are labeled clearly. Tap a star to keep following someone across communities and generations.

A person's **Overview** shows their immediate need, health, influence, current project, and a relevant action. **Show full stats & biography** opens the complete chart. **Family** links to spouses, parents, and children; **Influence** previews specific personal actions; **History** records their life. Profiles include age, gender, adult orientation, job, honor, conditions, standing, abilities, beliefs, and wealth.

Personal actions are free. Their previews describe the target, immediate changes, duration, conditions, and community consequences. A healer, scholar, farmer, official, or ruler can affect their community differently. Curses and possession have visible markers; recent interventions remain labeled on the person.

**Menu → Lives & stories** is a quiet journal of family appeals, favorite people, and your latest 32 intervention targets. It links directly to the actual people involved. Accept an official's promise, visit the named sick relative, and heal that person. The journal records whether the promise was kept and the resulting law while that record remains available. An unaccepted appeal is an opportunity, not a requirement.

People now pursue saved projects. Health, happiness, and wisdom affect yearly progress. Illness, imprisonment, curses, and food shortages slow it. Completed projects improve the household or community according to the project's role; failed attempts leave a recorded setback. Projects have an eighteen-year deadline and a three-year break after completion or failure. This is a bounded work-and-wellbeing system, not a full individual planning AI.

To restore a deceased person, open their profile through a family link, Favorites, or the journal and select **Return This Soul**. Their identity, memories, and family links return. Existing marriages and inherited property are respected; former rulers return as elders when a successor holds office. Old age is postponed for twenty years, but other hazards remain. The area power **Rebirth** instead creates new lives with new identities from pooled souls.

## Shape the world

Six visual categories—**Terrain, Nature, Life, God, Devil, Disasters**—open compact power trays. Select a power, read **Info**, adjust its brush where applicable, and click or touch the map. Selection responds immediately even while a simulation year is busy. Pending casts keep their original power and location; Observe or Escape cancels them. **Cancel** returns to Observe. Personal powers arm person selection: touch a pictured person, or touch a community to choose a resident. Preview and cast on that person. The camera focuses them and shows the actual result while time stays paused. Close the result and press Play to continue. Area powers show impact feedback for four real seconds, independent of simulation speed.

- Editable terrain, climates, forests, resources, and four starting scenarios.
- Fourteen researched eras, from Stone through Space, with changing houses, landmarks, weapons, and transport.
- Food, work, migration, expansion, beliefs, trade, war, conquest, and revolt.
- Persistent resident identities, families, births, aging, illness, inheritance, crime, prison, laws, opposition, and civil war.
- Rulers, prophets, religion, artifacts, supernatural agents, and inhabited orbital communities.
- Faction statistics, laws and justice, a Chronicle, atlas, technology reference, overlays, and achievements.
- Detailed procedural pixel people, era-appropriate battle sounds, and spoken introductions using installed English device voices.

World news is silent. Wars, peace, alliances, and revolutions appear ahead of weddings. At most one royal wedding per community is announced in ten years; ordinary weddings stay in personal histories. News cards open their events and participants. The Chronicle retains broader world events within its history limit.

## Controls

PC has a left power rail, a minimap, and bottom time controls. Phones use a bottom tray with top time controls; portrait uses a bottom sheet and landscape a side sheet. Controls use logical touch sizing rather than simply shrinking the PC interface.

| Input | Action |
|---|---|
| Tap / left click | Select a person or settlement, or apply the active power |
| One-finger drag | Pan; dragging does not cast |
| Two-finger pinch | Zoom and pan |
| Right / middle drag | Pan on PC |
| Left drag with terrain brush | Paint on PC |
| Wheel / zoom buttons | Zoom |
| Streets / double-click a settlement | Enter close-up Street View |
| Home / Fit | Fit the world |
| Space | Pause / resume |
| 1, 2, 3, 4 | Select 1×, 5×, 20×, 100× time |
| Android Back / Escape | Close the current sheet or return to Observe |
| Ctrl+S / Ctrl+O | Save / load |
| H / F11 | Chronicle / Windows fullscreen |

Fast-forward now counts time spent completing a simulation year, and avoids rebuilding the HUD for every accelerated year. Rates are targets: simulation work shares time with rendering, so larger worlds and longer histories can reach the device's processing limit. Back or Observe can cancel an inspection waiting for a year to finish.

## Saves and scope

Three manual slots and a separate autosave include validation and backup recovery. Autosave runs every 90 seconds when enabled. Loaded worlds start paused. Windows saves are under `%APPDATA%\Godot\app_userdata\The Gods\saves`. Android saves remain in private app storage. Updating preserves them; uninstalling or clearing app data can remove them. Browser saves belong to that browser profile and site address. Saves do not sync between devices. Save explicitly before leaving an important world.

Every whole resident has an identity and individual statistics. Street View draws a bounded selection of real people. Shared harvests, trade, battles, and disaster casualties also use settlement calculations; soldiers do not each have projectile collision simulation. Fishing produces food and ships move on water routes. Air traffic is era-dependent atmosphere, not individual tactical air combat. Space includes orbital habitats, not explorable planets.

Family links persist, while personal histories and civic records are bounded. Routine records are condensed after a person has been dead for 25 years. The journal is a way to revisit current stories, not an unlimited archive. Afterlife realms are pooled counts rather than playable maps.

## Development and verification

Open `project.godot` in Godot **4.7.2**. Build scripts are under `tools`; Android signing and update contracts are documented in [ANDROID.md](ANDROID.md) and [android-updater/README.md](android-updater/README.md). Keep the original signing key outside the project.

`tests/test_sandbox_stories.gd` exercises legacy-save conversion, personal projects, family promises and laws, succession, real resurrection, journal persistence, and native profile UI. `tools/validate.ps1` runs the wider acceptance suite, including long-running simulation and save checks. Use `tests/test_simulation.gd -- --bounded` for the shorter core checks; it does not replace endurance validation.

See [CASTING_UPDATE.md](CASTING_UPDATE.md), [SANDBOX_UPDATE.md](SANDBOX_UPDATE.md), and [RELEASE_NOTES.md](RELEASE_NOTES.md) for current results and limits. An earlier 1,800-year exact-state continuation discrepancy remains unresolved. That is why full archive packaging remains gated; short tests and prior releases are not substitutes for a passing current endurance run. Browser/device fixtures on this PC do not prove performance or sound quality on the actual phone.

## Credits

Game implementation, procedural art, interface design, and synthesized music created for this project. Runtime: Godot Engine, under the MIT license; see [GODOT_LICENSE.txt](GODOT_LICENSE.txt).

The interface bundles **Inter** by the Inter Project Authors and **Cormorant Garamond** by the Cormorant Project Authors, both under the **SIL Open Font License 1.1**. Font files and full notices are in `assets/fonts`; see [Inter's license](assets/fonts/inter-OFL.txt) and [Cormorant's license](assets/fonts/cormorantgaramond-OFL.txt).
