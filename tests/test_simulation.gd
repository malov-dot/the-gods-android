extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
var checks = 0

func _init():
	var sim = Simulation.new()
	sim.new_world({"seed":"acceptance-2026", "width":80, "height":55, "nations":4})
	check(sim.state.tiles.size() == 4400,"terrain dimensions")
	check(sim.state.settlements.size() >= 2,"habitable founding sites")
	var twin = Simulation.new()
	twin.new_world({"seed":"acceptance-2026", "width":80, "height":55, "nations":4})
	check(JSON.stringify(sim.state) == JSON.stringify(twin.state),"seed reproducibility")
	sim.step(120)
	check(sim.state.stats.population > 100,"sustainable population at year 120")
	check(sim.state.stats.deaths > 0 and sim.state.stats.births > 0,"demography")
	check(sim.state.afterlife.heaven+sim.state.afterlife.hell+sim.state.afterlife.wandering > 0,"afterlife accounting")
	check(absf(sim.state.afterlife.heaven+sim.state.afterlife.hell+sim.state.afterlife.wandering-sim.state.stats.deaths)<0.0001,"every death has one afterlife destination")
	var saved = JSON.parse_string(JSON.stringify(sim.state))
	var restored = Simulation.new()
	restored.restore(saved)
	sim.step(40)
	restored.step(40)
	check(absf(sim.state.stats.population-restored.state.stats.population) < 0.0001,"save restores deterministic population")
	check(str(sim.state.rng_state) == str(restored.state.rng_state),"persistent RNG")
	var mana = sim.state.mana.god
	sim.refresh_totals()
	sim.refresh_totals()
	check(sim.state.mana.god == mana,"refresh does not regenerate mana twice")
	for town in sim.state.settlements:
		check(town.population >= 0 and town.food >= 0,"nonnegative economy")
		check(town.faith >= 0 and town.corruption >= 0 and town.faith+town.corruption <= 1.000001,"belief simplex")
	var baseline = Simulation.new()
	baseline.new_world({"seed":"medicine", "width":64,"height":48,"nations":2})
	var t = baseline.state.settlements[0]
	t.plague = 10
	t.food = 10000.0
	var primitive = t.duplicate(true)
	primitive.era = 0
	var advanced = t.duplicate(true)
	advanced.era = 9
	baseline._settlement_year(primitive)
	baseline._settlement_year(advanced)
	check(advanced.population > primitive.population,"medicine reduces plague mortality")
	check(Content.ERAS[13].food > Content.ERAS[0].food,"technology improves carrying capacity")
	var orbital = baseline.state.settlements[0]
	orbital.era = 13
	orbital.population = 500.0
	orbital.wealth = 2000.0
	orbital.food = 2000.0
	orbital.plague = 0
	baseline.step(2)
	check(orbital.orbital_population > 0,"space habitats receive actual population")
	for town in baseline.state.settlements: town.population = 0.0
	baseline.step()
	check(baseline.state.stats.population > 0 and baseline.state.stats.population == baseline.state.orbital_population,"orbital survivors count after surface cities are lost")
	var sandbox = Simulation.new()
	sandbox.new_world({"seed":"unrestricted", "mode":"hotseat","width":64,"height":48,"nations":2})
	sandbox.step(2)
	check(sandbox.state.mode == "sandbox" and sandbox.state.year == 2,"legacy mode requests create an unrestricted sandbox")
	var empty = Simulation.new()
	empty.new_world({"seed":"renewal","width":64,"height":48,"nations":2})
	for town in empty.state.settlements: town.population = 0.0
	empty.step(2)
	check(empty.state.victory == "" and empty.state.year == 2,"sandbox extinction leaves editing and time available")
	var old = empty.state.settlements[0]
	var renewed = empty.found_settlement(old.x,old.y,old.nation,80.0)
	empty.step()
	check(not renewed.is_empty() and empty.state.stats.population > 0,"sandbox can restart life after extinction")
	if "--bounded" in OS.get_cmdline_user_args():
		print("PASS bounded simulation: %d assertions"%checks); quit(0); return
	print("PASS core, persistence, medicine, orbital, sandbox, renewal; running 1800-year endurance...")
	var stress = preload("res://tests/endurance_world.gd").world()
	var max_era = 0
	for town in stress.state.settlements: max_era = maxi(max_era,town.era)
	check(stress.state.stats.population > 0,"long-running ecology survives")
	check(max_era == 13,"Stone to Space progression")
	check(stress.state.events.size() <= 700,"bounded event history")
	print("PASS simulation: %d assertions; endurance year %d, population %d, towns %d, highest era %s" % [checks,stress.state.year,int(stress.state.stats.population),stress.state.stats.settlements,Content.ERAS[max_era].name])
	quit(0)

func check(condition: bool,label: String):
	checks += 1
	if not condition:
		push_error("FAIL: "+label)
		quit(1)
		assert(condition,label)
