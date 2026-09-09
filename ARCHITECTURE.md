# The Gods — implementation contract

Native Windows, Godot 4, 2D top-down simulation game. All artwork drawn by the renderer; no external service required at runtime. Project title: THE GODS — A world of consequence.

## Conventions

Use explicit preload paths. Simulation state owns gameplay; UI inspection must not mutate it. Deterministic yearly work can yield across frames, while preserving synchronous outcomes. Projects and resurrection extend the same resident registry instead of inventing parallel identities.

## Simulation API
`simulation.gd extends RefCounted`. Public `state: Dictionary`. `new_world(config: Dictionary)`, `step(years: int = 1)`, `add_event(title: String, detail: String, kind: String = "world", x: int = -1, y: int = -1, causes: Array = [])`, `get_settlement(id: int) -> Dictionary`, `get_tile(x: int,y: int) -> Dictionary`, `nearest_settlement(x: int,y: int,radius: float = 12.0) -> Dictionary`, `refresh_totals()`, `restore(data: Dictionary)`.

Config: seed, dimensions, nation count, scenario (`genesis`, `fractured`, `dying`, `enlightenment`), and difficulty (`gentle`, `normal`, `harsh`). `new_world` and `restore` force sandbox mode. There is no computer deity, network multiplayer, turn economy, or winning condition. Old competitive mode names are accepted only by save validation for migration. Keep autonomous diplomacy and wars between civilizations.


State keys: `version` int=1, `seed` string, `year` int, `width`,`height`, `tiles` Array[Dictionary], `settlements` Array[Dictionary], `nations` Array[Dictionary], `people` Array[Dictionary], `events` Array[Dictionary], `effects` Array[Dictionary], `wars` Array[Dictionary], `artifacts` Array[Dictionary], `agents` Array[Dictionary], `afterlife` Dictionary (`heaven`,`hell`,`wandering` totals), `mana` Dictionary (`god`,`devil` floats), `stats` Dictionary (`population`,`god`,`devil`,`neutral`,`settlements`,`deaths`,`births`), `mode`,`player_side`,`active_side` strings, `victory` compatibility string always empty, `settings` config, `next_id` int, `rng_state` string, `doctrine` Dictionary (`god`,`devil` strings), `achievements` Array[String]. Additional internal keys allowed; consumers use .get fallbacks.

Tiles are row-major dictionaries: `elevation` float 0..1 (`<0.36` water), `moisture` float 0..1, `temperature` float 0..1, `fertility` float 0..1, `forest` float 0..1, `ore` float 0..1, `biome` string (`ocean`,`coast`,`grass`,`forest`,`desert`,`mountain`,`snow`,`marsh`), `owner` nation id or -1. Terrain is rebuilt visually using a dirty signature; expose `state.terrain_revision` counter and increment on changes.

Settlements: `id`,`name`,`x`,`y`,`nation` ints (except name string), `population`,`food`,`wealth`,`health`,`happiness`,`faith`,`corruption`,`fear`,`knowledge` floats. faith and corruption 0..1 with sum<=1. `era` int indexes content.ERAS, `research` float, `plague`,`drought`,`blessing`,`protection` int years remaining, `leader` int person id, `founded` int, `history` Array, `religion` string, `buildings` Array[String]. Extra fields allowed.

Nations: `id`,`name`,`color` HTML hex String, `aggression` float, `allies` Array[int], `doctrine` string. People: `id`,`name`,`role`,`settlement` id, `age`,`lifespan`,`alive` bool, `traits` Array[String], `alignment` string. Events: `id`,`year`,`title`,`detail`,`kind`,`x`,`y`,`causes` Array[String]. Effects: `type` string, `x`,`y`,`radius`,`until` year, `side` optional. Wars: `a`,`b` nation ids, `since` year, `reason` string.

`content.gd` defines fourteen eras and both divine teaching sets. `refresh_totals` calculates population-weighted belief and living population, including orbit. Faith is a world statistic, not a victory score. Extinction leaves the sandbox editable and time available. `mana` is retained as inert save compatibility metadata; all powers are free.


## Powers API
`powers.gd extends RefCounted`; `const CATALOG` Array[Dictionary] with `id`,`name`,`category` (`world`,`life`,`divine`,`infernal`,`disaster`), `cost` number, `description`, `icon` short ASCII text, `radius` int. `apply(sim, power_id: String, x: int,y: int,radius: int = 3,side: String = "god") -> Dictionary` returns `{ok:bool,message:String}`. Both divine traditions and world editing are always available. Validate coordinates and target eligibility. There is no `ai_turn` entry point. `set_doctrine(sim,side,doctrine)->Dictionary` optional. Power effects must last/change simulation state rather than only append narrative. Use sim helpers. `SaveManager` static methods `save_game(state:Dictionary,slot:int=0)->Dictionary`, `load_game(slot:int=0)->Dictionary` returning `{ok,message,state?}`, `list_saves()->Array`, `save_settings(settings)`, `load_settings()->Dictionary`. 3 manual slots and autosave slot 9. Atomic writes, version validation, helpful error results.

## Renderer API
`world_view.gd extends Control`, signals `tile_clicked(x:int,y:int,button:int)`, `tile_hovered(x:int,y:int)`. Public `sim` object, `overlay` string (`terrain`,`nations`,`belief`,`fertility`,`technology`), `selected_id` int=-1, `brush_radius` int=3, `active_power` string=`inspect`. `reset_camera()`, `invalidate_terrain()`, `center_on_tile(x,y)`, `set_zoom(value)`. Mouse left click/drag emits tile_clicked (renderer handles gesture only), middle/right drag pan (no powers); wheel zoom around cursor. It draws terrain, coasts, trees, buildings by age, roads/trade, moving people/ships, disasters, borders, selection, brush. UI calls queue_redraw each frame. World view fills available center panel and clips contents. No dependency on root main.

## Release expectations
Executable, source project, controls/help, intro tutorial, new-world settings, four scenarios, saves, manual pause/speeds, autosave, map inspection, timeline and causes, civilization and character information, real age progression, both divine traditions in an unlimited single-player sandbox. Acceptance includes sustained simulation, save round-trip, power invariants, era effects, legacy-save conversion, and captured UI review.

## Personal stories

`personal_projects.gd` owns saved yearly goals under `citizens.overrides[key].life.project`; load normalizes date fields. `story_journal.gd` derives quiet cards from promises, laws, favorites, recent intervention targets, and personal histories. `resurrection.gd` removes exactly one identity from deceased intervals and restores that ID to living membership. Family links survive; property and remarried spouses are respected. All changes must remain valid under `save_manager.gd` and deterministic across JSON continuation.
