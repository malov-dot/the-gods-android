extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Powers = preload("res://scripts/powers.gd")
const Saves = preload("res://scripts/save_manager.gd")
var failures = 0
var assertions = 0
var baseline: Dictionary
var powers = Powers.new()

func _initialize():
	call_deferred("_run")

func _run():
	var simulation = Simulation.new()
	simulation.new_world({"seed":"Power acceptance 427", "width":64, "height":48, "nations":3, "difficulty":"gentle"})
	baseline = simulation.state.duplicate(true)
	_check(baseline.settlements.size() >= 2, "A real generated world has test targets")
	_test_catalog()
	_test_rules()
	_test_consequences()
	_test_saves()
	print("Power/save acceptance: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func _world(mode: String = "sandbox", side: String = "god"):
	var sim = Simulation.new()
	sim.restore(baseline)
	sim.state.mode = "sandbox"
	sim.state.player_side = side
	sim.state.active_side = side
	sim.state.mana = {"god":1000.0,"devil":1000.0}
	return sim

func _test_catalog():
	var ids = {}
	for power in Powers.CATALOG:
		_check(not ids.has(power.id), "Catalog IDs are unique: " + power.id)
		ids[power.id] = true
		var sim = _world()
		if Powers.PERSON_TARGETS.has(power.id):
			var snapshot=JSON.stringify(sim.state)
			_check(not powers.apply(sim,power.id,0,0,3,"god").ok,"Personal powers require a specific resident: "+power.id)
			_check(snapshot==JSON.stringify(sim.state),"A personal power never brushes the town")
			continue
		var town = sim.state.settlements[0]
		var x = int(town.x)
		var y = int(town.y)
		if power.id == "settlement":
			var point = _empty_site(sim)
			x = point.x
			y = point.y
		if power.id == "resurrect": sim.state.afterlife.heaven = 45.0
		var result = powers.apply(sim, power.id, x, y, int(power.radius), "god")
		_check(result.ok, "Catalog power has an executable effect: %s (%s)" % [power.id, result.message])
		_check(float(sim.state.mana.god) == 1000.0 and float(sim.state.mana.devil) == 1000.0, "Sandbox powers are free: " + power.id)
		var valid = Saves.validate_state(sim.state)
		_check(valid.ok, "Power leaves serializable valid simulation: %s (%s)" % [power.id, valid.message])
		if result.ok:
			_check(sim.state.events.back().causes.size() > 0, "Power records explanatory causes: " + power.id)

func _test_rules():
	var sim = _world("versus_ai")
	var town = sim.state.settlements[0]
	var x = int(town.x)
	var y = int(town.y)
	for attempt in [["unknown",x,y,"god"],["heal",-1,y,"god"],["heal",x,sim.state.height,"god"],["heal",x,y,"neutral"],["heal",x,y,"devil"]]:
		var before = JSON.stringify(sim.state)
		var result = powers.apply(sim, attempt[0], attempt[1], attempt[2], 3, attempt[3])
		_check(not result.ok, "Invalid intervention is rejected: " + str(attempt))
		_check(before == JSON.stringify(sim.state), "Rejected intervention has no mutations: " + str(attempt))
	sim.state.mana.god = 1.0
	var before = JSON.stringify(sim.state)
	_check(not powers.apply(sim,"heal",x,y,3,"god").ok, "Map shortcut still requires a selected person")
	_check(before == JSON.stringify(sim.state), "Untargeted personal shortcut leaves the world unchanged")
	sim.state.mana.god = 100.0
	_check(powers.apply_to_person(sim,"heal_person","p:%d"%int(town.leader),"god").ok, "Affordable valid intervention succeeds")
	_check(is_equal_approx(float(sim.state.mana.god),100.0), "Personal interventions leave essence unchanged")
	_check(not powers.apply(sim,"heal",0,0,1,"god").ok, "A settlement power needs a settlement")
	var sandbox = _world()
	var stown = sandbox.state.settlements[0]
	_check(powers.apply(sandbox,"cult",int(stown.x),int(stown.y),3,"god").ok, "Sandbox can use both divine categories")
	var empty_point = _empty_site(sandbox)
	var count = sandbox.state.settlements.size()
	_check(powers.apply(sandbox,"settlement",empty_point.x,empty_point.y,1,"devil").ok, "A new settlement can be founded")
	_check(sandbox.state.settlements.size() == count + 1, "Foundation creates a simulation settlement")
	_check(not powers.apply(sandbox,"settlement",empty_point.x,empty_point.y,1,"god").ok, "Overlapping settlements are rejected")

func _test_consequences():
	var sim = _world()
	var town = sim.state.settlements[0]
	var x = int(town.x)
	var y = int(town.y)
	var original_pop = float(town.population)
	var initial_deaths = float(sim.state.stats.deaths)
	powers.apply(sim,"meteor",x,y,3,"devil")
	_check(float(town.population) < original_pop * 0.4, "Meteor creates actual population loss")
	_check(float(sim.state.stats.deaths) > initial_deaths, "Power deaths reach the persistent death counter")
	_check(float(sim.state.afterlife.heaven) + float(sim.state.afterlife.hell) + float(sim.state.afterlife.wandering) > 0, "Power deaths populate the afterlife")
	var survivor_count = float(town.population)
	_check(powers.apply(sim,"resurrect",x,y,2,"god").ok, "Eligible souls can be resurrected")
	_check(float(town.population) > survivor_count, "Resurrection adds actual people")
	sim.state.afterlife.heaven = 20.75
	sim.state.afterlife.wandering = 30.5
	var souls_before = float(town.population) + float(sim.state.afterlife.heaven) + float(sim.state.afterlife.wandering)
	powers.apply(sim,"resurrect",x,y,2,"god")
	var souls_after = float(town.population) + float(sim.state.afterlife.heaven) + float(sim.state.afterlife.wandering)
	_check(is_equal_approx(souls_before,souls_after), "Resurrection conserves souls including fractional simulation balances")
	var protected = _world()
	var ptown = protected.state.settlements[0]
	powers.apply(protected,"protect",int(ptown.x),int(ptown.y),3,"god")
	powers.apply(protected,"meteor",int(ptown.x),int(ptown.y),3,"devil")
	_check(float(ptown.population) > original_pop * 0.7, "Sanctuary materially reduces hostile casualty losses")
	town = protected.state.settlements[0]
	powers.apply(protected,"cult",int(town.x),int(town.y),3,"devil")
	var target=protected.resident_page(int(town.id),0,1).people[0].key
	powers.apply_to_person(protected,"possess_person",target,"devil")
	_check(town.cult > 0 and protected.get_individual(target).possessed, "Cult affects the community while possession affects its selected person")
	powers.apply_to_person(protected,"purify_person",target,"god")
	_check(not protected.get_individual(target).possessed and town.cult>0, "Purification frees the selected person without rewriting unrelated cults")
	powers.apply(protected,"plague",int(town.x),int(town.y),3,"devil")
	_check(town.plague > 0, "Plague installs a disease duration")
	protected._society.edit_life(protected,target).illness="Plague"
	protected._society.edit_life(protected,target).sick_until=15
	powers.apply_to_person(protected,"heal_person",target,"god")
	_check(protected.get_individual(target).illness.is_empty() and town.plague>0, "Healing cures its recipient while the wider outbreak continues")
	powers.apply(protected,"drought",int(town.x),int(town.y),3,"devil")
	powers.apply(protected,"rain",int(town.x),int(town.y),3,"god")
	_check(town.drought == 0, "Rain ends crop failure")
	town.knowledge = 1000.0
	powers.apply_to_person(protected,"inspire_person",target,"god")
	_check(float(town.knowledge) == 1000.0 and not protected.state.citizens.overrides[target].effects.is_empty(), "Inspiration records the selected person's lasting contribution")
	protected.step()
	_check(float(town.knowledge)>1000.0,"Education and individual contribution advance the settlement over time")
	var emissary_world = _world("versus_ai")
	var etown = emissary_world.state.settlements[0]
	_check(powers.apply(emissary_world,"prophet",int(etown.x),int(etown.y),2,"god").ok, "A persistent prophet is created")
	_check(emissary_world.state.agents.size() == 1, "Prophet exists in simulation agent collection")
	var money = float(emissary_world.state.mana.god)
	_check(not powers.apply(emissary_world,"prophet",int(etown.x),int(etown.y),2,"god").ok, "Duplicate active emissaries are rejected")
	_check(is_equal_approx(float(emissary_world.state.mana.god),money), "Rejected duplicate emissaries cost nothing")
	_check(powers.apply(emissary_world,"relic",int(etown.x),int(etown.y),2,"god").ok, "A permanent relic is created")
	_check(emissary_world.state.artifacts.size() == 1, "Relic exists in simulation artifact collection")
	var war_world = _world()
	var wtown = war_world.state.settlements[0]
	_check(powers.apply(war_world,"discord",int(wtown.x),int(wtown.y),3,"devil").ok, "Discord starts an actual war")
	_check(war_world.state.wars.size() == 1, "War enters simulation state")
	_check(powers.apply(war_world,"peace",int(wtown.x),int(wtown.y),3,"god").ok, "Concord succeeds")
	_check(war_world.state.wars.is_empty(), "Concord removes the war")
	_check(not powers.apply(war_world,"discord",int(wtown.x),int(wtown.y),3,"devil").ok, "A peace treaty prevents immediate reinvasion")
	var terrain = _world()
	var rev = int(terrain.state.terrain_revision)
	powers.apply(terrain,"land",0,0,3,"god")
	_check(float(terrain.get_tile(0,0).elevation) >= 0.36, "Terrain brush creates land on water")
	_check(int(terrain.state.terrain_revision) > rev, "Terrain mutation invalidates rendering cache")
	powers.apply(terrain,"forest",0,0,3,"god")
	_check(float(terrain.get_tile(0,0).forest) >= 0.45, "Forests are actual terrain resources")
	powers.apply(terrain,"water",0,0,3,"god")
	_check(terrain.get_tile(0,0).biome == "ocean", "Submerged terrain becomes ocean")
	var orbital = _world()
	var habitat = orbital.state.settlements[0]
	habitat.population = 0.0
	habitat.orbital_population = 5000.0
	habitat.faith = 0.15
	habitat.corruption = 0.15
	orbital.refresh_totals()
	var resident=orbital.resident_page(int(habitat.id),0,1).people[0]
	_check(powers.apply_to_person(orbital,"bless_person",resident.key,"god").ok, "An orbital resident remains reachable after the surface city dies")
	_check(orbital.get_individual(resident.key).faith>resident.faith,"Belief powers influence the actual orbital resident")
	_check(powers.apply(orbital,"prophet",int(habitat.x),int(habitat.y),2,"god").ok, "Orbital survivors can receive an emissary")
	_check(powers.apply(orbital,"relic",int(habitat.x),int(habitat.y),2,"god").ok, "Orbital survivors can receive an artifact")
	var orbital_before = float(habitat.orbital_population)
	var deaths_before = float(orbital.state.stats.deaths)
	powers.apply(orbital,"meteor",int(habitat.x),int(habitat.y),3,"devil")
	_check(is_equal_approx(float(habitat.orbital_population),orbital_before), "Ground disasters spare orbital residents")
	_check(is_equal_approx(float(orbital.state.stats.deaths),deaths_before), "An empty surface causes no invented casualty deaths")

func _test_saves():
	Saves.storage_directory = "user://acceptance_powers_" + str(Time.get_ticks_usec())
	var sim = _world()
	sim.step(10)
	var valid = Saves.validate_state(sim.state)
	_check(valid.ok, "A running simulation passes save validation: " + valid.message)
	_check(not Saves.save_game(sim.state, 7).ok, "Unsupported slots are rejected")
	_check(not Saves.load_game(7).ok, "Unsupported load slots are rejected")
	_check(not Saves.load_game(0).ok, "Empty saves produce a useful failure")
	for slot in [0,1,2,9]:
		var saved = Saves.save_game(sim.state,slot)
		_check(saved.ok, "Atomic save succeeds in slot %d: %s" % [slot,saved.message])
		var loaded = Saves.load_game(slot)
		_check(loaded.ok, "Saved world loads from slot %d: %s" % [slot,loaded.message])
		if loaded.ok:
			_check(JSON.stringify(loaded.state) == JSON.stringify(JSON.parse_string(JSON.stringify(sim.state))), "Full state survives JSON round-trip in slot %d" % slot)
	var entries = Saves.list_saves()
	_check(entries.size() == 4 and entries[3].slot == 9, "The slot browser includes three manual saves and autosave")
	_check(entries[0].exists and entries[0].ok and entries[0].year == 10, "Slot metadata reports saved state")
	var resumed = Simulation.new()
	resumed.restore(Saves.load_game(0).state)
	sim.step(20)
	resumed.step(20)
	_check(is_equal_approx(float(sim.state.stats.population), float(resumed.state.stats.population)), "RNG and simulation resume deterministically after save/load")
	_check(sim.state.rng_state == resumed.state.rng_state, "Save/load preserves the full random generator state")
	_check(Saves.save_game(sim.state,0).ok, "A second save rotates a valid backup")
	var path = Saves.storage_directory + "/slot_1.godsave"
	_write_text(path,"{incomplete")
	var recovery = Saves.load_game(0)
	_check(recovery.ok and recovery.get("recovered",false), "Corrupt primary automatically recovers the previous generation")
	if recovery.ok: _check(int(recovery.state.year) == 10, "Recovery loads the previous valid world")
	_check(Saves.save_game(sim.state,0).ok, "A damaged primary can be safely replaced")
	_write_text(path,"{incomplete")
	recovery = Saves.load_game(0)
	_check(recovery.ok and recovery.get("recovered",false), "Replacing a damaged primary preserves the valid recovery copy")
	var wrong = sim.state.duplicate(true)
	wrong.version = 999
	_check(not Saves.save_game(wrong,1).ok, "Unsupported world versions cannot overwrite good saves")
	wrong = sim.state.duplicate(true)
	wrong.tiles.pop_back()
	_check(not Saves.validate_state(wrong).ok, "Malformed tile counts are rejected")
	wrong = sim.state.duplicate(true)
	wrong.settlements[0].population = -10.0
	_check(not Saves.validate_state(wrong).ok, "Negative populations are rejected")
	wrong = sim.state.duplicate(true)
	wrong.settlements[0].faith = 0.9
	wrong.settlements[0].corruption = 0.9
	_check(not Saves.validate_state(wrong).ok, "Overlapping belief populations are rejected")
	wrong = sim.state.duplicate(true)
	wrong.tiles[0].fertility = NAN
	_check(not Saves.validate_state(wrong).ok, "Non-finite values cannot enter a save")
	wrong = sim.state.duplicate(true)
	wrong.settlements[0].knowledge = 10000.0
	_check(Saves.validate_state(wrong).ok, "Accumulated civilization knowledge is not wrongly capped")
	var good_envelope = JSON.parse_string(FileAccess.get_file_as_string(Saves.storage_directory + "/slot_2.godsave"))
	good_envelope.payload = str(good_envelope.payload)+"tampered"
	_write_text(Saves.storage_directory + "/slot_2.godsave",JSON.stringify(good_envelope))
	_check(not Saves.load_game(1).ok, "A tampered payload fails its checksum")
	_check(Saves.save_settings({"master_volume":3.0,"fullscreen":true,"autosave_interval":1,"show_tutorial":false}).ok, "Settings persist atomically")
	var settings = Saves.load_settings()
	_check(is_equal_approx(float(settings.master_volume),1.0) and settings.fullscreen and int(settings.autosave_interval) == 30 and not settings.show_tutorial, "Settings load with safe range limits")
	_check(Saves.save_settings({"master_volume":0.2}).ok, "Settings maintain a previous generation")
	_write_text(Saves.storage_directory + "/settings.json","bad data")
	_check(is_equal_approx(float(Saves.load_settings().master_volume),1.0), "Settings recover after corruption")
	_check(Saves.save_settings({"volume":0.37,"ambient":false,"effects":false}).ok, "Main UI audio settings aliases can be saved")
	settings = Saves.load_settings()
	_check(is_equal_approx(float(settings.volume),0.37) and not settings.ambient and not settings.effects, "Main UI audio settings aliases persist")
	if "--long" in OS.get_cmdline_user_args():
		var ancient = preload("res://tests/endurance_world.gd").world()
		var ancient_validation = Saves.validate_state(ancient.state)
		_check(ancient_validation.ok, "An 1800-year world passes the full save schema: " + ancient_validation.message)
		var ancient_save = Saves.save_game(ancient.state,2)
		_check(ancient_save.ok, "An 1800-year world saves: " + ancient_save.message)
		ancient.step(10)
		var expected_population=float(ancient.state.stats.population)
		var expected_rng=str(ancient.state.rng_state)
		var expected_world=JSON.stringify(ancient.state).sha256_text()
		var highest_era = 0
		for settlement in ancient.state.settlements: highest_era = maxi(highest_era,int(settlement.era))
		print("Long save test: year %d, %d settlements, %d recorded lives, highest era %d, population %.0f" % [ancient.state.year, ancient.state.settlements.size(), ancient.state.citizens.overrides.size(), highest_era, ancient.state.stats.population])
		# Release the first world before loading another full ancestral archive.
		ancient=null
		var ancient_load = Saves.load_game(2)
		_check(ancient_load.ok, "An 1800-year world loads: " + ancient_load.message)
		if ancient_load.ok:
			var restored_ancient = Simulation.new()
			restored_ancient.restore(ancient_load.state)
			ancient_load.clear()
			restored_ancient.step(10)
			_check(is_equal_approx(expected_population,float(restored_ancient.state.stats.population)), "Ancient world continuation remains deterministic")
			_check(expected_rng == str(restored_ancient.state.rng_state), "Ancient world random state is preserved")
			_check(expected_world==JSON.stringify(restored_ancient.state).sha256_text(),"Every ancient family, personal history and society consequence resumes identically")
	_cleanup_scratch()
	Saves.storage_directory = Saves.SAVE_DIRECTORY

func _empty_site(sim) -> Vector2i:
	for y in range(4, int(sim.state.height)-4):
		for x in range(4,int(sim.state.width)-4):
			var tile = sim.get_tile(x,y)
			if float(tile.elevation) >= 0.4 and float(tile.elevation) < 0.75 and sim.nearest_settlement(x,y,6.0).is_empty():
				return Vector2i(x,y)
	return Vector2i(0,0)

func _cleanup_scratch():
	var absolute = ProjectSettings.globalize_path(Saves.storage_directory)
	var user_root = ProjectSettings.globalize_path("user://")
	if not absolute.begins_with(user_root) or not Saves.storage_directory.begins_with("user://acceptance_powers_"):
		_check(false,"Refuse to clean paths outside the unique test folder")
		return
	var dir = DirAccess.open(absolute)
	if dir != null:
		for filename in dir.get_files():
			DirAccess.remove_absolute(absolute.path_join(filename))
		DirAccess.remove_absolute(absolute)

func _write_text(path: String, contents: String):
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()

func _check(condition: bool, message: String):
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
