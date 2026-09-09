# Game HUD redesign — 1.3

The user's attached Game UI / UX Design Rules are the acceptance brief. The world fills the viewport; UI overlays it. Idle gameplay must leave at least 75% of the world unobstructed. This is a structural redesign, not a smaller desktop layout.

## Information hierarchy

Always: population, era, year, allegiance, pause/speed, menu, six power categories. During targeting: selected ability, real cost, actual radius, explanation access, cancel, map reticle. After selection: a compact person/settlement summary with an expand action. On request: ability palette, detailed resident/faction information, chronicle, overlays, settings and save/load. No permanent chronicle or inspector columns.

## Layouts

- Desktop (1100+ logical pixels): full-screen map; compact upper-left resource strip, upper-right utilities; 56-pixel left vertical category rail; palette extends inward from that rail. Bottom-center selection plaque / active tool controls. Bottom-right time controls. Small lower-left minimap.
- Phone landscape: full-screen map; compact top resources and time controls; six 48+ pixel categories in a centered bottom tray with Observe control. Category abilities expand immediately above. Selected person/town is a small expandable plaque. Detailed information uses a right-side temporary sheet.
- Phone portrait: compact top resources, separate time controls; bottom category dock; ability grid grows upward. Selected-person/town plaque sits above the dock; expanded information uses a bottom sheet. No desktop rail or permanent minimap.

## Power hierarchy

Terrain / Nature / Life / God / Devil / Disasters → ability icon + short name → active tool strip with actual cost and brush radius. Full explanations are available by tap as well as hover. Selecting an ability closes the ability palette and leaves the map ready for immediate use. No fabricated strength or cooldown controls: show only values implemented by the simulation.

## Shared visual rules

Dark translucent charcoal/green metal, muted gold edges, restrained category colors. Compact Inter labels and small serif titles. 4/8/12 pixel spacing; 3–5 pixel corners; 48-pixel touch targets; distinguish selected and disabled states. Use original drawn game icons, not Unicode emoji. Short transitions must not block input. Lists use compact rows and separators, not nested cards. Longer stat explanations are disclosed on request.

## Ownership this turn

- Root: main.gd, interface_shell.gd, hud_powers.gd, general sheets/theme, integration/build/docs.
- Context agent: community_ui.gd (compact profiles, factions, directory; preserve methods and behavior).
- Art agent: interface_art.gd and hud_minimap.gd (icons/portraits/minimap).
- Acceptance agent: test_hud.gd, test_mobile_ui.gd adaptation after integration; no production edits.

## Required visual verification

1920×1080, 2560×1440, 1366×768, 844×390 and 390×844. Inspect idle, selected settlement/person, open power category, active power, expanded profile/faction and save/load. Check world coverage, target size, selected state, click-through prevention, text clipping, high DPI, hotseat budgets and existing controls.
