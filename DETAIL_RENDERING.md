# Close-up world rendering

Requested direction: visibly recognizable people, age-specific buildings and weapons, actual war formations, and disasters affecting the town view. Existing save format and simulation remain compatible.

## Current ownership (supersedes original architecture ownership for this change)
- Root: world_view.gd integration/camera, main UI, simulation/power event metadata if needed, documentation, packaging and integration tests.
- Architecture agent: new scripts/settlement_painter.gd only (and its own new tests if helpful).
- People agent: new scripts/people_painter.gd only (and its own new tests if helpful).
- Calamity agent: new scripts/calamity_painter.gd only (and its own new tests if helpful).

All painters extend RefCounted, no class_name. They draw on a passed Control named `view`. The view's draw transform is already world-space (world tile = 8 units); do not change draw_set_transform. A 0.5-world-unit grid yields detailed pixels at close zoom. Maximum zoom is 12 and Street View focuses at 4.5. Close-up settlement rendering starts at zoom 3.0; atlas keeps its small icons. Each module draws using view.draw_rect/draw_line/etc, never mutates sim, and uses no random global calls or per-frame Image generation. Tree ellipse masks are cached once per shape. Optional view._detail_owns_position(town,point,margin) keeps plots and effects on their side of a nearby settlement boundary.

## Settlement painter API
- `layout(town:Dictionary)->Array` returns stable building entries `{position:Vector2,kind:String,seed:int}` relative to town center. A standard town spreads over roughly +/-42 world units, with streets between plots. A house spans ~10-16 world units (20-32 detailed pixels); landmarks up to22 units. People are ~4 wide by8 high world units. Do not tightly overlap plots; limit about12-20 buildings. Footprint and scale must stay coherent across eras and zooms.
- `draw_ground(view,town,center:Vector2,flag:Color,time:float)` draws city clearings/plaza, actual roads/paths, fields/wells/walls appropriate to era. Use view._is_land for plot eligibility.
- `draw_building(view,entry:Dictionary,town:Dictionary,center:Vector2,flag:Color,time:float)` draws entry at center+entry.position, anchored at building bottom/feet. Include coherent roofs, doors, masonry/wood/window details, unique silhouette per age, actual landmark types from era/buildings. town.visual_damage optional0..1 causes char/damage/ruins; town.plague/drought existing fields affect visible appearance. The root will depth-sort buildings with citizens by bottom y.
- `era_summary(era:int)->String` short technology description for UI legends.

## People painter API
- `citizens(view,town,center:Vector2,time:float)->Array` returns stable representative citizen entries `{position:Vector2,era:int,flag:Color,seed:int,role:String,direction:float,phase:float,activity:String}`; use actual population to bound8..24 persons, zero if no surface residents. Walk along town streets, not randomcircles through houses; feet paths should stay in horizontal/vertical streets x/y near0, +/-24. Restrict to land. Roles visible (farmers, workers, scholars, guards), named leader/prophet if represented. Read town visual_damage/plague/drought for injury/fleeing; root sim.settings/time not needed. position is absolute world-coordinate, no cached mutable sim state.
- `draw_person(view,p:Vector2,era:int,flag:Color,seed:int,role:String,direction:float,phase:float,activity:String)` recognizable head/hair/face/torso/arms/separate legs, animation. ~4x8 worldunits, detailed pixel0.5 units. Era-appropriate dress and equipment, no generic3pixel blobs. Roles chooseheldtools/weapons; medieval sword/shield/archer, earlymusket, modern rifle/armor, futureplasma. At low zoom view._draw_person legacy may remain.
- `draw_wars(view,sim,time:float,zoom:float)` shows ONLY actual sim.state.wars, nation-specific forces from real participating settlements and technology. Include marching two-sided formations, rangedfire, siege/cannon/tank/drone ageappropriate, navaltransport if path crosseswater. Do not spawn fictional permanent wars or deaths. Geometry may animate representative conflict, actual outcomes remain sim. Cap visibleunits and cull offscreen. Optional war keys `front_a`,`front_b` settlement IDs and `casualties_a`,`casualties_b` provided by root, use ifpresent else nearest living pair. view._nation_colors, _is_land, _visible, _font available.
- `weapon_name(era:int)->String` UI labels.

## Calamity painter API
- `draw_world(view,sim,time:float,zoom:float)` draws actual active effects and settlement conditions. Return/replace existingview._draw_effects for supporteddisasters (fire,meteor,volcano,earthquake,storm,rain,ice,drought,plague,atomic). All others root keeps legacy divine/infernal effects.
- `supports(kind:String)->bool` identifies handled effects.
- `draw_town_conditions(view,town,center:Vector2,time:float,zoom:float)` persistent visible plague, drought, burning/damaged town tied to state, no duplicate massive particles. Flames/smoke should sit on house locations; can preload settlement_painter.layout to align. town.visual_damage optional0..1, visual_disaster String, visual_disaster_until int; root wires mutations/recovery with actual harms.
- Fire: recognizable layered flames/smoke, burned ground. Earthquake cracks and dust. Meteor moving incoming rock/impact/crater phase, not a permanent floating icon. Storm: drivingrain/lightning/clouds. Volcano: lava/mountaineruption. Drought dryground/witheredfields. Plague afflictedtown indicator/miasma without coveringcitizens. Freeze snow/frost. Atomic nuclear flash/smoke ifactualevent.

## Verification
Root will generate close-up captures of ancient, medieval, industrial, modern/space settlements, actual war fixtures, and disasters through real power APIs. Test fixtures are isolated and do not change user saves. No tests needed just to mirror draw calls; verify finite drawing at everyera, gestures/camera, real event linkage, compatibility and boundeddraw costs.
