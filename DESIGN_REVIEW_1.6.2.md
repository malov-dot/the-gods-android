**The Gods — design review of version 1.6.2, September 9, 2026**

The concept makes sense: shape a world, become interested in its people, intervene in their lives, and watch the consequences spread through families and civilizations. The current game contains functioning foundations for that experience. Its depth, presentation and pacing do not yet consistently deliver it. My assessment is that this is a promising playable game with substantial unfinished design work, rather than a polished completion of the original vision.

This review used the production source, desktop and phone-sized game captures, three seeded 200-year simulations, and controlled experiments with personal powers, computer decisions and resurrection. No production gameplay was changed or new release published for this review. These observations do not establish how a broad group of players will enjoy the game or how this build feels on the physical Fold.

**Does it make sense?**

The relationship between environment, food, health, population, research, belief and conflict is coherent. People really contribute to production and care. Marriage, bereavement, crimes, imprisonment, official misconduct, family bargains and laws retain named participants and can affect other residents. Healing an official's relative can genuinely produce public relief. These are useful foundations for the intended game.

Some names and visuals suggest more than the systems provide. Residents' stated goals come from a short list selected by age, role and stat thresholds; the goals are not tracked personal projects with plans, progress, obstacles and completion. The same resident can express a desire to challenge power, but no goal object coordinates that ambition. Civic behavior separately reads character statistics. Source: [goal descriptions](scripts/citizen_registry.gd:567), [civic behavior](scripts/civic_story.gd:155).

Royalty currently means rulers and children of people recorded as rulers. Succession promotes an available resident; there is no hereditary claim, inheritance-of-office contest or marriage negotiation determining succession. Marriage has meaningful family effects, but a royal marriage does not itself negotiate an alliance, territory or succession agreement. Calling an event a royal wedding therefore promises more political importance than it reliably has. Sources: [royal marriage](scripts/life_society.gd:204), [succession](scripts/simulation.gd:692), [promotion](scripts/citizen_registry.gd:180).

Return the Lost draws from afterlife totals and increases a settlement's population. In the controlled experiment it created four new identities; the dead person remained dead. This is materially different from bringing back a favorite character with their relationships intact. The wording and intended resurrection behavior need an explicit decision. Sources: [resurrection](scripts/powers.gd:200), [experiment evidence](test-output/design-audit-evidence.json).

The tutorial still describes Bless as an area miracle applied to a settlement, although the current shortcut targets a person. The guide and README retain statements about essence payments despite free powers. These inconsistencies undermine learning and trust. Sources: [tutorial](scripts/main.gd:108), [guide](scripts/main.gd:1496), [README](README.md).

**Does it seem fun?**

The best opportunities for enjoyment are watching a civilization grow, choosing a person to protect or corrupt, creating a crisis, and recognizing a later consequence. A distinctive loop would be: discover a specific human problem, choose an intervention, observe a visible response, then follow how relationships or institutions change. The current interface often requires the player to search profiles and histories to assemble that story.

The news changes improved sound and reduced categories, but category filtering is insufficient. Across three 200-year Genesis runs, 551 of 579 qualifying news events were royal weddings: about 95%. The runs began with three towns and ended with 17–20. Royalty is common enough that its weddings can still overwhelm the feed at high speed. Meanwhile a plea to save an official's child is a personal event excluded from news, so an especially relevant opportunity can be hard to discover. Sources: [news selection](scripts/world_stories.gd:8), [family pleas](scripts/civic_story.gd:85), [run evidence](test-output/design-audit-evidence.json).

Keep global news quiet and selective. Add a separate, optional place to follow favorites and unresolved personal stories, with links to the involved people and a clear outcome. Its purpose is continuity, without making every ordinary life event a global interruption. News needs significance and repetition handling: a wedding that changes a succession or alliance deserves more attention than another marriage with no public consequence.

Unlimited powers fit the sandbox. They currently weaken the computer contest because the player can act repeatedly while paused and the AI normally acts once per five simulated years. Ten consecutive Gift of Learning casts were accepted at year zero, raising a ruler's wisdom from 59.5 to 100 and leadership from 78 to 100; no AI action occurred. This is direct evidence of trivial stat maximization, not proof that every complete match is automatically winnable. Shared-PC play already has a three-action turn budget. Sources: [experiment](test-output/design-audit-evidence.json), [computer cadence](scripts/main.gd:262), [authorization](scripts/powers.gd:150).

The AI also contains stale assumptions: it tests a town's blessing timer, then casts the personal blessing that does not set that timer. In a controlled sequence of ten AI calls with no intervening years, all ten actions were personal blessings. This isolates action selection; it is not a simulated fifty-year match. The old condition makes repeated blessing a persistent priority in otherwise healthy towns. Source: [computer selection](scripts/powers.gd:586).

Keep powers free. Make competitive action opportunities fair, and make the computer evaluate current personal effects and meaningful needs. For sandbox, distinct consequences and human reactions should provide interest; a currency grind is unnecessary.

Technology advances through one fixed sequence. Eras have actual economic, health, pollution, trade and military differences, but every civilization follows the same order. In the three unattended runs, the most advanced settlements reached Renaissance or Exploration by year 200. This small sample suggests steady growth; it does not establish late-game balance. More meaningful variation would come from local priorities, institutions, resource constraints and responses to crises. Space already has surviving orbital residents and an economy, but it offers limited new interaction once reached. Sources: [era definitions](scripts/content.gd:3), [research and advancement](scripts/simulation.gd:332), [orbital society](scripts/simulation.gd:413).

**Does it look appealing?**

The map has an identifiable palette, readable water and coastlines, and a consistent dark-and-gold HUD. The full-width world and compact controls are useful improvements. Close-up residents have recognizable heads, clothing and poses, and eras have different architecture. These are good starting points.

The current aesthetic still looks procedural and repetitive. The overview gives grass and trees almost as much visual emphasis as settlements and people, making the places worth inspecting harder to spot. At maximum zoom, repeated body silhouettes, hats and building arrangements become conspicuous. Buildings and people frequently overlap in the reviewed Space Age street capture. A repeated 9–16-plot settlement illustration cannot convey the scale or layout differences of a village and a large city very convincingly. Source: [settlement layout](scripts/settlement_painter.gd:18).

Phone profiles devote substantial space to the favorite action, tabs, introduction text and replay-voice button before showing the chart. The many equally styled rows and buttons make it harder to identify the most useful next action. Keeping all the requested statistics is compatible with first showing the person's main need, most important relationships, and current effects, then making the full chart easy to expand.

The visual priorities should be distinct silhouettes by age, role and era; better streets and building spacing; recognizable cultural architecture and landmarks; clearer separation of terrain from important actors; and a profile whose focal point is the selected person. More pixels alone will not produce the desired detailed 16-bit appearance. The work needs deliberate composition, animation and asset variation.

Images reviewed: [desktop overview](test-output/pc-1.6.2.png), [Space Age street](test-output/living-world-spaceport-street.png), [phone profile](test-output/living-world-introduction-phone.png), [personal consequence feedback](test-output/person-feedback-profile.png).

**Does everything serve a purpose?**

A valid purpose can be agency, understanding, atmosphere, identity or convenience. Every detail does not need to alter a win condition. The problem is an element that is redundant, confusing, or suggests an interaction that does not exist.

| System | Present purpose | Assessment |
|---|---|---|
| Terrain, fertility, moisture, ore | Settlement viability, food, research and wealth | Meaningful. Connections should be more visible on the map. |
| Food, health, population, pollution | Survival, expansion and industrial consequences | Core systems worth keeping. |
| Individual work and abilities | People contribute to food, wealth, research, care and security | Real effects. Individual importance is difficult to see at city scale. |
| Gender, orientation, age, families | Identity, compatible marriages, generations, grief and gratitude | Legitimate social and character purpose; every biographical detail need not be a strategic advantage. |
| Stated wants | Voice and profile characterization | Mostly descriptive. Needs a persistent goal system to support the requested personal agency. |
| Honor, crimes, justice, laws, rebellion | Named actions change victims, institutions and power | Among the strongest systems; story discovery and longer consequences need attention. |
| Royal weddings | Household ties and recognition of a ruling family | Weak political purpose today; too dominant in filtered news. |
| Faith, doctrines, religions | Belief pressure, civic differences and versus victory | Mechanically relevant. Many results converge on shifts to two allegiance values. |
| Artifacts, prophets and demons | Continuing local belief, health, food or research pressure | Functional, but largely passive modifiers with overlapping roles. |
| Personal interventions | Immediate changes plus some lasting family/civic effects | Useful core. Learning/inspiration and several belief actions need clearer experiential differences. |
| Buildings and eras | Communicate advancement; some buildings have explicit rules | Many structures visualize era-wide bonuses rather than operating as individual facilities. |
| Trade and fishing | Food, wealth, contact and research diffusion | Real economy. Boat arrival does not cause delivery; annual accounting happens separately. |
| Naval and land battles | Casualties, conquest, damaged towns and diplomatic change | Real war outcomes. Individual weapon/unit tactics are mostly illustrative; the military formula uses population, era, health and a castle modifier. |
| Aircraft and flying rockets | Show the era and animate the world | Mainly atmosphere. They do not individually transport people, conduct air missions or trigger orbital migration. |
| Orbital residents | Survival after surface loss and continued society/economy | Real purpose, limited player-facing space gameplay. |
| Afterlife | Death accounting and a pool for Return the Lost | Partial purpose. Hell is chiefly a persistent total; favorite people cannot be individually restored. |
| Essence/mana state | Legacy replenishing counter | No current spending purpose. Stale explanations should be removed; compatibility data can remain internal. |
| Favorites, histories, overlays, saves | Navigation, continuity, understanding and persistence | Essential supporting features. Favorites need stronger story continuity. |

Transport and aircraft observations come from [world_transport.gd](scripts/world_transport.gd), [trade](scripts/simulation.gd:443), and [combat](scripts/simulation.gd:488). The world can use aggregate simulation for performance; visible activity should still correspond to understandable causes and outcomes.

**Recommended order of work**

1. Correct misleading behavior and explanations: AI priorities/action parity, obsolete costs and tutorial instructions, explicit resurrection semantics, and news significance. Keep free sandbox powers and quiet news.
2. Make one personal story compelling from beginning to end: discover a sick child and an official's appeal, choose a response, see the treatment, follow a kept or broken promise, observe the resulting law, and recognize its effect on that family years later. Use existing systems and expose their connections clearly.
3. Give people persistent goals and consequential relationships. Track intent, progress, setbacks and completion. Tie marriages and succession to actual political outcomes when they merit royal news.
4. Improve art direction and profile hierarchy. Refine a small set of early, middle and late era scenes before multiplying variants across every age. Validate desktop and phone composition separately.
5. Deepen the existing economy, war and late-game activities where their visuals currently promise more than their mechanics deliver. Prefer useful connections over adding another independent feature category.

Design acceptance should include observed player behavior. Can a new player find someone worth caring about, understand why an action matters, identify its consequences later, and explain what they want to do next without instructions? Can they distinguish key units and landmarks at normal play zoom? Do they choose to keep following the world after the first novelty wears off? Automated correctness checks cannot answer those questions.

Release confidence also has a separate unresolved limit: the earlier 1,800-year whole-state continuation comparison failed while population and RNG matched. That issue remains open. This review did not rerun or resolve it; a long-lived family sandbox needs dependable persistence.
