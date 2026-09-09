# The Gods 1.7.0 — Lives & Stories

The game is now an unrestricted single-player sandbox. The AI opponent, shared-PC turns, victory thresholds, side ownership, and competitive world settings have been removed from runtime behavior and controls. Existing save mode names remain accepted only so those saves can convert automatically. Autonomous wars between civilizations remain part of the sandbox.

This implements the story-continuity portion of the 1.6.2 design review:

- A quiet **Lives & stories** journal links family appeals, actual patients, accepted or resolved promises, resulting laws, favorite people, and recent interventions. Records are bounded, not an unlimited story archive.
- Personal projects persist and advance annually from wellbeing. Illness, curses, prison, and food shortage can stall them. Completion has role-based household or community rewards; deadlines can produce setbacks. They are not a full autonomous planning system.
- Person Overview leads with immediate need and a relevant action. Full biography and fifteen-stat chart are one tap away. Family, Influence, History, and a 48dp favorite control remain available.
- **Return This Soul** restores the actual deceased identity, family, and memories. It splits death ranges correctly, restores membership, respects remarried spouses and inherited property, reconciles a pooled soul, and postpones old age twenty years. Other hazards remain. The older area power is clearly named **Rebirth** and creates new identities.
- The eldest eligible adult child in the same community can inherit leadership, including a child already holding a named office. This is a succession rule, not a complete dynasty/election system.
- Major conflicts and diplomacy take priority over wedding headlines. A community announces at most one royal wedding in ten years; royalty means a current ruler or their child. News stays silent.
- Close-up clothing palettes, hairstyles, and healer/merchant details vary more. The fixed settlement plot layout has not been redesigned.

## Verification

Focused sandbox/story acceptance: **35 checks**, including full family appeal → accepted promise → named child's cure → Common Relief law; role-project completion and illness setback; titled-heir succession; middle-of-range and repeated resurrection; save/load; old versus conversion; wedding throttling; and native UI. The same fixture passed with graphical rendering, and phone/PC captures were inspected.

New project dates exposed an exact JSON continuation difference. They now normalize to integer dates on load. The resident registry suite passes **74 checks**, including exact registry preservation at year 120 and forty more years of continuation. The shorter core simulation passes **47 assertions**. Personal powers/save passes **329 checks** and world powers **267 assertions** without the long-run option.

Other passing suites in this turn: interface **40**, responsive interface **151**, Android time **327**, resident navigation **68**, living world **273**, personal feedback **91**, HUD **1,653**, living society **2,583**, society UI **218**, save compression **8**, touch/people **54**, pictured people **333**, renderer **51**, street detail **100**, architecture **297**, people detail **42**, calamities **10**, and resource behavior. Android updater mocks pass **58** and lifecycle/safe-area fixtures **91**. Obsolete competitive checks were removed, so historical suite totals are not comparable. Living-world test shutdown reports two ObjectDB leaks; its assertions pass. No new physical-phone touch, audio, installer, or performance review is claimed.

Large-population acceptance passes **18 checks** with exact synchronous/asynchronous outcomes. On this Windows host, 12,000 residents used 410 yielded frames (median simulation slice 8.75ms, p95 10.53ms, max 12.70ms); 20,000 used 624 (8.80ms, 10.52ms, 14.74ms). These are simulation work slices, not full rendered frame rates or phone guarantees.

Evidence: `test-output/sandbox-expanded.log`, `sandbox-visual-final.log`, `sandbox-core.log`, `citizens-final.log`, `sandbox-powers.log`, `sandbox-performance.log`, and the final per-suite/regression logs. Failed intermediate runs are retained separately where available.

## Remaining design work and release limits

Tactical battle logic, individual aircraft combat, a deeper resource economy, and less repetitive city construction remain future work. This update does not claim that every system in the design audit has been redesigned.

The earlier 1,800-year whole-state continuation test completed and failed exact equality despite matching population and RNG. That discrepancy remains unresolved; it is not still running, and this turn did not rerun or waive that gate. The new short-registry fix does not establish a fix for the older discrepancy. Full distribution ZIP packaging remains gated; Windows executable, Android APK, and browser exports are the current delivery targets.

## Delivery

Windows `build/The Gods.exe` was rebuilt and launched with exit code 0; `Play The Gods.cmd` opens it. Android 1.7.0 / 10700 is [published](https://github.com/malov-dot/the-gods-android/releases/tag/v1.7.0), with all 46 production-source hashes and the original signing certificate verified. The actual public startup download passes 17 transport checks, including all 54,228,472 APK bytes and the expected SHA-256. Native installation calls are mocked in that host test. Browser files under `build/web` were rebuilt. Standalone ZIPs remain historical.
