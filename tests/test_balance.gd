extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Powers = preload("res://scripts/powers.gd")
const Content = preload("res://scripts/content.gd")
var failures = 0

func _init():
	var arguments = OS.get_cmdline_user_args()
	if "--resources" in arguments:
		_resource_checks()
		quit(0 if failures == 0 else 1)
		return
	if "--orbital" in arguments:
		_orbital_checks()
		quit(0 if failures == 0 else 1)
		return
	if "--benchmark" in arguments:
		_benchmark()
		quit(0)
		return
	var scenarios = ["dying"] if "--dying" in arguments else ["genesis","fractured","dying","enlightenment"]
	for scenario in scenarios:
		for seed_ in ["Balance Alder","Balance Flint"]:
			var sim = Simulation.new()
			sim.new_world({"seed":seed_,"width":64,"height":48,"nations":4,"scenario":scenario,"difficulty":"normal"})
			var initial = sim.state.stats.population
			var minimum = initial
			for year in range(60):
				sim.step()
				minimum = minf(minimum,sim.state.stats.population)
			sim.step(1140)
			var best = 0
			for town in sim.state.settlements:
				if town.population > 0: best = maxi(best,town.era)
			print("NATURAL scenario=%s seed=%s initial=%d early_minimum=%d year=%d population=%d towns=%d era=%s god=%.3f devil=%.3f" % [scenario,seed_,initial,minimum,sim.state.year,sim.state.stats.population,sim.state.stats.settlements,Content.ERAS[best].name,sim.state.stats.god,sim.state.stats.devil])
			if sim.state.stats.population < 1 or best < 8:
				failures += 1
	print("BALANCE AUDIT: %d unattended survival/advancement failures." % failures)
	quit(0 if failures == 0 else 1)

func _benchmark():
	var sim = Simulation.new()
	var began = Time.get_ticks_usec()
	sim.new_world({"seed":"Large benchmark","width":224,"height":140,"nations":8,"difficulty":"gentle"})
	var generation_ms = (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	sim.step(100)
	var early_ms = (Time.get_ticks_usec()-began)/1000.0
	print("BENCH generation224x140=%.1fms first100years=%.1fms towns100=%d" % [generation_ms,early_ms,sim.state.stats.settlements])
	sim.step(900)
	var total = 0.0
	var maximum = 0.0
	var samples = []
	for year in range(50):
		began = Time.get_ticks_usec()
		sim.step()
		var elapsed = (Time.get_ticks_usec()-began)/1000.0
		total += elapsed
		maximum = maxf(maximum,elapsed)
		samples.append(elapsed)
	samples.sort()
	print("BENCH mature224x140 year=%d towns=%d population=%d 50year_mean=%.2fms p95=%.2fms worst=%.2fms" % [sim.state.year,sim.state.stats.settlements,sim.state.stats.population,total/50.0,samples[47],maximum])

func _resource_checks():
	var temperate = Simulation.new()
	temperate.new_world({"seed":"Resource outcome","width":64,"height":48,"nations":2})
	var hot = Simulation.new()
	hot.restore(temperate.state)
	for sim in [temperate,hot]:
		var town = sim.state.settlements[0]
		town.era = 3
		town.population = 400.0
		town.food = 100.0
		for dy in range(-2,3):
			for dx in range(-2,3):
				var tile = sim.get_tile(town.x+dx,town.y+dy)
				tile.elevation = 0.5
				tile.fertility = 0.75
				tile.temperature = 0.55 if sim == temperate else 0.95
				tile.moisture = 0.65 if sim == temperate else 0.01
		sim.state.terrain_revision += 1
		sim._settlement_year(town)
	var wet_food = temperate.state.settlements[0].food
	var dry_food = hot.state.settlements[0].food
	if wet_food <= dry_food: failures += 1
	var poor = Simulation.new()
	poor.new_world({"seed":"Resource outcome","width":64,"height":48,"nations":2})
	var rich = Simulation.new()
	rich.restore(poor.state)
	for sim in [poor,rich]:
		var town = sim.state.settlements[0]
		town.era = 3
		town.food = 1000.0
		sim.get_tile(town.x,town.y).ore = 0.0 if sim == poor else 1.0
		sim._settlement_year(town)
	if rich.state.settlements[0].research <= poor.state.settlements[0].research or rich.state.settlements[0].wealth <= poor.state.settlements[0].wealth: failures += 1
	print("RESOURCES temperate_food=%.2f hot_dry_food=%.2f ore_poor_research=%.2f ore_rich_research=%.2f failures=%d" % [wet_food,dry_food,poor.state.settlements[0].research,rich.state.settlements[0].research,failures])

func _orbital_checks():
	var sim = Simulation.new()
	sim.new_world({"seed":"Orbital belief","width":64,"height":48,"nations":2})
	var town = sim.state.settlements[0]
	town.population = 0.0
	town.orbital_population = 400.0
	town.era = 13
	town.faith = 0.1
	town.corruption = 0.2
	town.cult = 20
	town.possession = 20
	sim.state.agents.append({"id":9000,"side":"devil","settlement":town.id,"strength":1.0,"created":0,"lifespan":40})
	sim.state.artifacts.append({"id":9001,"side":"devil","settlement":town.id,"power":0.025})
	if sim.nearest_settlement(town.x,town.y,1.0).is_empty(): failures += 1
	sim.step(10)
	if town.corruption <= 0.25 or town.cult != 10 or town.possession != 10: failures += 1
	if sim.resident_population(town) < 400 or town.population != 0: failures += 1
	print("ORBITAL population=%.2f corruption=%.3f cult=%d possession=%d failures=%d" % [town.orbital_population,town.corruption,town.cult,town.possession,failures])
