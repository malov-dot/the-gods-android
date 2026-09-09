# People and touch interface update

Current user asks for creative understandable phone-friendly UI, explanations for all actions, faction/leader stats, every person selectable with identity/stats, and direct interventions whose community impact depends on standing/role.

## Ownership for this update (supersedes prior contracts)
- Root owns main.gd, new UI helper modules, project/export settings, packaging, UI acceptance.
- People agent owns simulation.gd, new citizen registry if useful, new population/individual consequence tests. Coordinate existing content.gd if needed.
- Powers agent owns powers.gd, save_manager.gd, new personal intervention/save tests. Coordinate sim API below.
- Architecture agent owns world_view.gd, people_painter.gd, new touch/person picking tests. Do not edit main.

Preserve existing game modes, world powers, saves, maps, era renderer and actual wars. All existing public APIs remain. No invented individual UI stats that cannot persist or influence state. Every living population member must be accessible by identity in a paginated directory; the renderer can bound visible people for phone performance. Compact deterministic identity batches plus per-person overrides are acceptable; no identity reuse, no ghost living people after mortality, and migrations must preserve identity. Old saves should gain a valid roster. Long-world save size and stepping must stay practical.

## Agreed additional simulation API
- `resident_page(town_id:int, offset:int=0, limit:int=24, query:String="") -> Dictionary`: `{people:Array,total:int,offset:int}`; read only. Include surface/orbital location. Search by name, role or identity. Clamp limits.
- `get_individual(key:String) -> Dictionary`: read-only resolved persistent person, empty if unknown. Dictionary fields: key(String),name,age,alive,settlement(int),nation(int),role,traits(Array),health,happiness,faith,corruption,loyalty,ambition,standing,leadership,wisdom,strength (all normalized0..1), influence0..1,goal(String),history(Array),portrait_seed(int), location("surface"/"orbit"). Legacy named people may use `p:<id>`; ordinary residents `c:<id>`.
- `individual_keys(town_id:int,limit:int=24,selected_key:String="") -> Array[String]`: representative actual residents, include selected living surface person and ruler/prophet. Read only, fast enough for rendering. Every returned key resolves. Dead/orbit people not pictured on streets.
- `apply_person_influence(key:String,action:String,side:String) -> Dictionary`: simulation owns actual role/standing dependent personal and community consequences, timed effects, history and event causality. Returns `{ok,message}`; caller powers validates deity/budget/turn before calling. Unknown/dead/out-of-range must return failure without mutation. Actions agreed: heal_person, inspire_person, bless_person (god); tempt_person, corrupt_person, incite_person (devil). Heal improves individualhealth and communitymedicine forhealer; inspire builds individualwisdom and role-based research/production; bless improves loyalty/standing/faith; tempt boosts ambition/wealth/corruption; corrupt alters faith/loyalty; incite empowers aggression/unrest, especially military/rulers. Keep economic and belief effects bounded; no one-click inevitable conquest. Persistent cumulative effects should visibly change civilization course over years. An ordinary person matters modestly; established community figures have wider reach.
- `faction_summary(nation_id:int) -> Dictionary`: name,id,color,population,settlements,total wealth,food,highest era,faith,corruption,stability,aggression,leaders(Array of individual dictionaries),wars(Array),direction(String). Read-only aggregation.

## Powers API additions
- `const PERSON_CATALOG` dictionaries id,name,description,cost,side,consequence explaining role/standing effects and duration.
- `apply_to_person(sim,action_id:String,key:String,side:String="god") -> Dictionary`: all same restrictions as world powers (sandboxunlimited,versusdeity/mana/finished/hotseat), exact once charge onlysuccess, rejectedstateimmutable. Main decrements hotseat action aftersuccess consistent worldapply.
- `preview_person(sim,action_id:String,key:String,side:String="god") -> Dictionary` {ok,message,cost,description,consequence}; read-only honest preview, usable UIbeforeintervention.
- Validate optional citizen schema in save_manager; preserveversion1 existing saves. Do not request permission for schema additions already authorized.

## World view additions
- `signal person_clicked(key:String)` and `selected_person_key:String=""`.
- Inspect pointer/touch taps hit-test actual pictured individual before settlement. Picking only in Observe; powers must retain world targeting. Minimum touch radius screen-space~20px; nearest visible person wins. Selected person highlight/name, `focus_person(key)` zoom/center host and guarantee displayed via individual_keys.
- Touch: one finger drag pans; tap selects/casts once onrelease (dragnevercasts); twofingerpinch zoom/pan withnoaccidentalcast, desktop gestures retained. Account cancellation and touch indices, minimum targetslop, multipointer ends. Keep touchscreen and mouseemulation fromdoubleactivation; use project settings rootcoordinates.
- people_painter citizens resolve sim.individual_keys/get_individual; actual portrait/name/role/key replace fabricateddisplaypeople. Fallback only for tests/legacyviewssimwithoutnewAPIs, not normal game.

## UI
Creative celestial dark navy/lilac/gold visual identity, readable text, generous touch targets. Atphone widths mapfills background, compactheader andbottomnavigation (World,Powers,People,Realms,Menu); drawers/sheets withexplicitback, scroll, persistentexplanations rather than hoveronly. Desktopusesmappluscontextpanel, compacttoolbar. Portraitandlandscapetested, nofixed1180minwidth. Everypower hasnameanddescription visiblebeforenormalcasting. Everyperson hasportrait/stats/role/influence/explanations+personalactions withconcretepreviewandCastbutton. Allresidentssearchablepaged. Realmleaderandfactionstatsreachable.

## Verify
Independent meaningful tests: complete rostercoverage/identitystability/aging/migration/mortality/savecontinuation,roleweightedactionconsequencesandrejectedimmutable, touchgestures/personpicking, responsive390x844and844x390plusdesktop actualgraphicalcaptures, accessiblemenuactionsandtooltips/explanations. Preserveplayer'ssaves; teststorageisolated.
