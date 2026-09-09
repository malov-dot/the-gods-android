extends RefCounted

const Content = preload("res://scripts/content.gd")
const CitizenRegistry = preload("res://scripts/citizen_registry.gd")
const LifeSociety = preload("res://scripts/life_society.gd")
const Diplomacy = preload("res://scripts/diplomacy.gd")
const Transport = preload("res://scripts/world_transport.gd")
var _citizens = CitizenRegistry.new()
var generation = 0
var _society = LifeSociety.new()
var state: Dictionary = {}
var rng = RandomNumberGenerator.new()
var _land_cache: Dictionary = {}
var _fertility_cache: Dictionary = {}
var _cache_revision = -1

func new_world(config: Dictionary):
	generation+=1
	var defaults = {"seed":"Genesis", "width":160, "height":100, "nations":5, "mode":"sandbox", "player_side":"god", "scenario":"genesis", "difficulty":"normal"}
	defaults.merge(config, true)
	defaults.mode="sandbox"
	defaults.player_side="god"
	defaults.width = clampi(int(defaults.width), 48, 240)
	defaults.height = clampi(int(defaults.height), 36, 160)
	defaults.nations = clampi(int(defaults.nations), 2, 8)
	rng.seed = str(defaults.seed).hash()
	_land_cache.clear()
	_fertility_cache.clear()
	_cache_revision = -1
	state = {"version":1, "seed":str(defaults.seed), "year":0, "width":defaults.width, "height":defaults.height,
		"tiles":[], "settlements":[], "nations":[], "people":[], "events":[], "effects":[], "wars":[], "artifacts":[], "agents":[], "trade_routes":[],
		"afterlife":{"heaven":0.0, "hell":0.0, "wandering":0.0}, "mana":{"god":0.0, "devil":0.0},
		"stats":{"population":0.0, "god":0.0, "devil":0.0, "neutral":1.0, "settlements":0, "deaths":0.0, "births":0.0},
		"mode":defaults.mode, "player_side":defaults.player_side, "active_side":defaults.player_side, "victory":"", "settings":defaults,
		"next_id":1, "rng_state":"0", "terrain_revision":1, "doctrine":{"god":"Compassion", "devil":"Ambition"}, "achievements":[],
		"total_births":0.0, "total_deaths":0.0, "orbital_population":0.0}
	_citizens = CitizenRegistry.new()
	_society = LifeSociety.new()
	_citizens.initialize(self)
	_generate_terrain()
	for i in range(defaults.nations):
		state.nations.append({"id":i, "name":Content.NATION_NAMES[i], "color":Content.NATION_COLORS[i], "aggression":rng.randf_range(0.2, 0.75), "allies":[], "doctrine":"Tradition"})
		var point = _find_site(-1, -1, 999.0, 12.0)
		if point.x >= 0:
			var town = found_settlement(point.x, point.y, i, rng.randf_range(90, 135))
			_apply_scenario(town, defaults.scenario, i)
	# Unusually barren seeds receive a fertile island so every new world is playable.
	if state.settlements.size() < 2:
		for i in range(2):
			var x = int(state.width / 3) * (i + 1)
			var y = int(state.height / 2)
			for dy in range(-5, 6):
				for dx in range(-5, 6):
					var tile = get_tile(x + dx, y + dy)
					if not tile.is_empty():
						tile.elevation = 0.48
						tile.fertility = 0.8
						update_biome(x + dx, y + dy)
			found_settlement(x, y, i, 110)
	add_event("A world awakens", "%s begins with %d civilizations. Your interventions will become their history." % [state.seed, state.nations.size()], "world")
	refresh_totals()
	_society.initialize(self)
	state.rng_state = str(rng.state)

func _generate_terrain():
	var noise = FastNoiseLite.new()
	noise.seed = int(rng.randi() % 2147483647)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025
	noise.fractal_octaves = 4
	var wet_noise = FastNoiseLite.new()
	wet_noise.seed = int(rng.randi() % 2147483647)
	wet_noise.frequency = 0.045
	for y in range(state.height):
		for x in range(state.width):
			var nx = absf((float(x) / float(state.width - 1) - 0.5) * 2.0)
			var ny = absf((float(y) / float(state.height - 1) - 0.5) * 2.0)
			var edge = pow(maxf(nx, ny), 5.0) * 0.3
			var elev = clampf(0.53 + noise.get_noise_2d(x, y) * 0.46 - edge, 0.05, 0.98)
			var moisture = clampf(0.5 + wet_noise.get_noise_2d(x, y) * 0.62, 0.08, 0.98)
			var temp = clampf(0.88 - ny * 0.76 - maxf(0.0, elev - 0.62) * 1.2, 0.02, 0.96)
			var fertility = clampf(moisture * 0.75 + (1.0 - absf(temp - 0.55)) * 0.3 - maxf(0.0, elev - 0.63) * 2.0, 0.04, 0.96)
			state.tiles.append({"elevation":elev, "moisture":moisture, "temperature":temp, "fertility":fertility, "forest":clampf(moisture * temp * 1.5, 0.0, 1.0), "ore":clampf((elev - 0.35) * 1.4 + rng.randf() * 0.25, 0.0, 1.0), "biome":"grass", "owner":-1})
			update_biome(x, y)

func update_biome(x: int, y: int):
	var t = get_tile(x, y)
	if t.is_empty(): return
	if t.elevation < 0.36: t.biome = "ocean"
	elif t.elevation < 0.395: t.biome = "coast"
	elif t.temperature < 0.2: t.biome = "snow"
	elif t.elevation > 0.76: t.biome = "mountain"
	elif t.moisture < 0.27: t.biome = "desert"
	elif t.moisture > 0.78 and t.elevation < 0.48: t.biome = "marsh"
	elif t.forest > 0.43: t.biome = "forest"
	else: t.biome = "grass"

func _apply_scenario(town: Dictionary, scenario: String, i: int):
	if town.is_empty(): return
	match scenario:
		"fractured":
			town.faith = 0.8 if i % 2 == 0 else 0.08
			town.corruption = 0.08 if i % 2 == 0 else 0.8
			town.era = 3
			town.religion = "Covenant of Dawn" if i % 2 == 0 else "The Ashen Pact"
		"dying":
			town.food = town.population * 0.2
			# A severe opening crisis must still leave survivors who can rebuild.
			town.plague = 8
			town.drought = 12
			town.health = 0.55
			town.happiness = 0.3
		"enlightenment":
			town.era = 6
			town.faith = 0.22
			town.corruption = 0.12
			town.knowledge = 90.0
	for level in range(town.era + 1):
		if not Content.ERA_BUILDINGS[level] in town.buildings: town.buildings.append(Content.ERA_BUILDINGS[level])

func _next_id() -> int:
	var result = int(state.next_id)
	state.next_id = result + 1
	return result

func found_settlement(x: int, y: int, nation: int = -1, population: float = 100.0, town_name: String = "", source_town: int = -1) -> Dictionary:
	var tile = get_tile(x, y)
	if tile.is_empty() or tile.elevation < 0.36 or tile.elevation > 0.86: return {}
	if not nearest_settlement(x, y, 2.0).is_empty(): return {}
	if nation < 0: nation = int(state.nations[0].id) if not state.nations.is_empty() else 0
	if town_name.is_empty(): town_name = Content.PLACE_START[rng.randi_range(0, Content.PLACE_START.size()-1)] + Content.PLACE_END[rng.randi_range(0, Content.PLACE_END.size()-1)]
	var town = {"id":_next_id(), "name":town_name, "x":x, "y":y, "nation":nation, "population":population, "food":population * 1.8, "wealth":55.0,
		"health":0.9, "happiness":0.72, "faith":0.33, "corruption":0.2, "fear":0.1, "knowledge":0.0, "era":0, "research":0.0,
		"plague":0, "drought":0, "blessing":0, "protection":0, "cult":0, "possession":0, "education":0, "pact":0,
		"leader":-1, "founded":state.year, "history":[], "religion":"Ancestral Spirits", "buildings":["hearth"], "shortage":0,
		"pollution":0.0, "last_expansion":state.year, "last_revolt":state.year, "last_schism":state.year, "orbital_population":0.0, "abandoned":false}
	state.settlements.append(town)
	if source_town >= 0: _citizens.transfer(self,source_town,int(town.id),floori(population))
	var ruler = _create_person(town, "ruler")
	town.leader = ruler.id
	_claim_territory(town)
	add_event("%s is founded" % town.name, "Families establish a home on %s land, with %d inhabitants." % [tile.biome, int(population)], "settlement", x, y, ["Habitable terrain", "Available farmland"])
	state.rng_state = str(rng.state)
	return town

func _create_person(town: Dictionary, role: String, preferred:String="") -> Dictionary:
	var age = rng.randi_range(20, 40)
	var person = {"id":_next_id(), "name":Content.PERSON_NAMES[rng.randi_range(0, Content.PERSON_NAMES.size()-1)], "role":role, "settlement":town.id, "age":age, "lifespan":rng.randi_range(58, 88) + int(town.era) * 2, "alive":true, "traits":[Content.TRAITS[rng.randi_range(0, Content.TRAITS.size()-1)]], "alignment":"god" if town.faith >= town.corruption else "devil", "born":state.year-age}
	state.people.append(person)
	if state.has("citizens"):
		_citizens.promote(self,person,false,preferred)
		if not state.citizens.named.has("p:%d"%int(person.id)):
			# A tiny surviving habitat can already have a title for every resident.
			# Its existing resident takes office; creating another named figure
			# must never invent an extra living person outside the population.
			person.alive=false
			if role=="ruler":
				for resident in state.people:
					if not resident.get("alive",false) or int(resident.settlement)!=int(town.id):continue
					var key="p:%d"%int(resident.id)
					var identity=_citizens.status(self,key)
					if identity.is_empty() or not identity.alive:continue
					resident.role="ruler"
					var alias=str(state.citizens.named[key])
					state.citizens.overrides[alias]["role"]="ruler"
					_citizens._changed(self,false)
					state.people.erase(person)
					return resident
	return person

func _claim_territory(town: Dictionary):
	var radius = 4 + mini(int(town.era / 3), 3)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius: continue
			var t = get_tile(town.x + dx, town.y + dy)
			if not t.is_empty() and t.elevation >= 0.36: t.owner = int(town.nation)
	state.terrain_revision += 1

func step(years: int = 1, yield_callback:Callable=Callable()):
	if state.is_empty(): return
	var epoch=generation
	# A replacement world can release its old services while they are suspended.
	# Keep them alive until the generation checks unwind this complete year.
	var active_citizens=_citizens
	var active_society=_society
	# Powers save and restore this same state; resume the exact random sequence.
	rng.state = int(state.get("rng_state", str(rng.state)))
	for unused in range(maxi(0, years)):
		state.year += 1
		var towns = state.settlements.duplicate()
		for town in towns:
			if town.population > 0.0:
				if yield_callback.is_valid(): await _settlement_year(town,yield_callback)
				else: _settlement_year(town)
				if epoch!=generation: return
			if float(town.get("orbital_population",0.0)) > 0.0:
				if yield_callback.is_valid(): await _orbital_year(town,yield_callback)
				else: _orbital_year(town)
				if epoch!=generation: return
			if yield_callback.is_valid():
				if not await yield_callback.call() or epoch!=generation: return
		_trade_and_diffusion()
		Diplomacy.annual(self)
		_conflict_year()
		if yield_callback.is_valid():
			if not await Transport.annual(self,yield_callback) or epoch!=generation: return
		else: Transport.annual(self)
		_people_year()
		active_citizens.annual(self)
		if yield_callback.is_valid():
			if not await active_society.annual(self,yield_callback) or epoch!=generation: return
		else: active_society.annual(self)
		_supernatural_year()
		if state.year % 15 == 0: _natural_event()
		state.effects = state.effects.filter(func(effect): return int(effect.get("until", state.year + 1)) > state.year)
		if state.year == 100: _achievement("centennial")
		if state.year == 1000: _achievement("millennium")
		refresh_totals()
		if yield_callback.is_valid():
			if not await yield_callback.call() or epoch!=generation: return
	state.rng_state = str(rng.state)

func _settlement_year(town: Dictionary,yield_callback:Callable=Callable()):
	var epoch=generation
	var tile = get_tile(town.x, town.y)
	if tile.elevation < 0.36:
		var refuge = _nearest_other(town, 50.0)
		var survivors = floorf(town.population * (0.8 if town.era >= 7 else 0.4))
		if not refuge.is_empty():
			refuge.population += survivors
			_citizens.transfer(self,int(town.id),int(refuge.id),int(survivors))
		else: survivors = 0.0
		if yield_callback.is_valid():
			await _record_deaths(town, town.population - survivors,"surface",true,yield_callback)
			if generation!=epoch: return
		else: _record_deaths(town, town.population - survivors)
		town.population = 0.0
		town.abandoned = true
		add_event("%s is submerged" % town.name, "%d survivors escape to neighboring land." % int(survivors), "disaster", town.x, town.y, ["Sea level above settlement"])
		return
	var era = Content.ERAS[clampi(int(town.era), 0, Content.ERAS.size()-1)]
	var pop = float(town.population)
	var fertility = _local_fertility(town.x, town.y)
	var difficulty = str(state.settings.get("difficulty", "normal"))
	var abundance = 1.18 if difficulty == "gentle" else (0.86 if difficulty == "harsh" else 1.0)
	var carrying = (110.0 + fertility * 245.0) * era.food * abundance
	var god_doctrine = str(state.doctrine.god)
	var devil_doctrine = str(state.doctrine.devil)
	var drought_factor = 0.28 if town.drought > 0 else 1.0
	var production = minf(pop * (1.2 + fertility * 0.75), carrying * 1.6) * drought_factor
	production *= 1.32 if town.blessing > 0 else 1.0
	if god_doctrine == "Stewardship": production *= 1.0 + town.faith * 0.17
	if god_doctrine == "Compassion": production *= 1.0 + town.faith * 0.07
	if town.era >= 12: production *= 1.12
	production += float(town.get("orbital_population", 0.0)) * 0.2
	var stock = town.food * (0.94 if town.era >= 2 else 0.86) + production
	var fed = clampf(stock / maxf(pop, 1.0), 0.0, 1.0)
	town.food = clampf(stock - pop, 0.0, carrying * (4.0 if town.era >= 2 else 2.5))
	town.shortage = int(town.get("shortage", 0)) + 1 if fed < 0.85 else maxi(0, int(town.get("shortage", 0))-2)
	var plague = 0.0
	if town.plague > 0: plague = 0.065 * (1.0 - era.medicine)
	if town.protection > 0: plague *= 0.25
	var pollution = float(town.get("pollution", 0.0))
	if town.era >= 8 and town.era < 12:
		pollution = minf(0.4, pollution + 0.0015)
	elif town.era >= 12 or god_doctrine == "Stewardship": pollution = maxf(0.0, pollution - 0.005)
	town.pollution = pollution
	# Pollution reduces the next harvest as well as public health.
	town.food *= 1.0 - pollution * 0.025
	var health_target = clampf(0.75 + era.medicine * 0.22 + fed * 0.2 - plague * 6.0 - pollution * 0.45, 0.12, 1.0)
	if town.blessing > 0: health_target = minf(1.0, health_target + 0.15)
	town.health = lerpf(town.health, health_target, 0.18)
	var mortality = 0.009 * (1.0 - era.medicine * 0.5) + plague + (1.0-fed) * 0.17 + maxf(0.0, 0.45-town.health) * 0.035
	var expected_deaths = pop * mortality+float(town.get("mortality_carry",0))
	var deaths = floori(expected_deaths)
	town["mortality_carry"]=expected_deaths-deaths
	# Education and longer lives bring a demographic transition in later eras.
	var family_planning=lerpf(1.0,0.45,clampf((float(town.era)-7.0)/6.0,0,1))
	var expected_births = pop * (0.028 + town.happiness * 0.009) * family_planning * fed * town.health * clampf(1.3 - pop / (carrying * 1.4), 0.08, 1.0)+float(town.get("birth_carry",0))
	if yield_callback.is_valid():
		await _record_deaths(town, deaths,"surface",true,yield_callback)
		if generation!=epoch: return
	else: _record_deaths(town, deaths)
	town.population=maxf(0,pop-deaths)
	var parents=_society.parents_for_birth(self,town,"surface",maxi(0,floori(expected_births)))
	var births=mini(floori(expected_births),parents.size())
	town["birth_carry"]=fposmod(expected_births,1.0)
	state.total_births += births
	town.population = maxf(0.0, pop + births - deaths)
	var first_birth=int(state.citizens.next_id)
	_citizens.add(self,int(town.id),births)
	_society.record_births(self,town,first_birth,births,parents)
	_citizens.sync_town(self,town)
	town.wealth = clampf(town.wealth + pop * (0.014 + town.era * 0.004) * fed - pop * 0.01 - pollution, 0.0, 100000.0)
	if town.era >= 2:
		town.wealth = minf(100000.0,town.wealth + pop * float(tile.ore) * 0.002 * mini(town.era,8))
	var happiness_target = clampf(0.35 + fed * 0.4 + town.health * 0.15 - town.fear * 0.28 - town.corruption * 0.08, 0.05, 0.98)
	if god_doctrine == "Order": happiness_target += town.faith * 0.07
	if town.get("pact", 0) > 0:
		town.wealth += 3.0
		town.corruption += 0.003
		happiness_target -= 0.07
	town.happiness = clampf(lerpf(town.happiness, happiness_target, 0.13), 0.0, 1.0)
	town.fear = maxf(0.0, town.fear - 0.008)
	_belief_year(town, fed)
	var research = (1.4 + sqrt(maxf(pop, 0.0)) * 0.22 + town.era * 0.45) * fed * (0.4 + town.happiness * 0.6)
	if town.era >= 2: research *= 0.85 + float(tile.ore)*0.45
	if town.era >= 4: research *= 1.15
	if town.era >= 6: research *= 1.2
	if town.era >= 11: research *= 1.25
	if town.era >= 12: research *= 1.4
	if town.get("education", 0) > 0: research *= 2.2
	if god_doctrine == "Knowledge": research *= 1.0 + town.faith * 0.8
	if devil_doctrine == "Forbidden Knowledge": research *= 1.0 + town.corruption
	if devil_doctrine == "Ambition": town.wealth += town.corruption * pop * 0.012
	town.knowledge += research * 0.08
	town.research += research
	if town.era < Content.ERAS.size()-1 and town.research >= era.threshold:
		town.research -= era.threshold
		town.era += 1
		town.buildings.append(Content.ERA_BUILDINGS[town.era])
		_claim_territory(town)
		add_event("%s enters the %s Age" % [town.name, Content.ERAS[town.era].name], Content.ERAS[town.era].description, "technology", town.x, town.y, ["Accumulated local research", "Food security supports specialists"])
		if town.era == 6: _achievement("renaissance")
	if town.era == 13 and town.wealth > 500 and town.population > 120:
		var emigrants = floorf(minf(1.5, town.population * 0.002))
		town.population -= emigrants
		town.orbital_population = float(town.get("orbital_population", 0.0)) + emigrants
		_citizens.transfer(self,int(town.id),int(town.id),int(emigrants),"surface","orbit")
		town.wealth -= 4.0
		town.research += float(town.orbital_population) * 0.03
		_achievement("spacefarers")
	if town.shortage == 3:
		add_event("Hunger in %s" % town.name, "Failed harvests have exhausted food stores; families may migrate.", "crisis", town.x, town.y, ["Drought" if town.drought > 0 else "Population exceeds local harvests", "Three years of food shortages"])
	if state.year % 5 == int(town.id) % 5:
		_migrate(town)
		_try_expand(town, carrying)
		# Named civic movements, evaluated below, determine revolutions.
		_try_religion(town)
	for field in ["plague", "drought", "blessing", "protection", "cult", "possession", "education", "pact"]:
		town[field] = maxi(0, int(town.get(field, 0)) - 1)
	if town.population < 6.0:
		if yield_callback.is_valid():
			await _record_deaths(town, town.population,"surface",true,yield_callback)
			if generation!=epoch: return
		else: _record_deaths(town, town.population)
		town.population = 0.0
		town.abandoned = true
		add_event("%s falls silent" % town.name, "The last inhabitants are gone; its ruins remain on the map.", "crisis", town.x, town.y, ["Population fell below a viable community"])
	if town.population >= 300: _achievement("first_city")
	if state.year>int(town.get("visual_disaster_until",-1)):
		town["visual_damage"]=maxf(0.0,float(town.get("visual_damage",0))-0.022*fed*town.health)
	_normalize_town(town)

func _belief_year(town: Dictionary, fed: float):
	var faith_delta = 0.0
	var corruption_delta = 0.0
	if town.blessing > 0: faith_delta += 0.0045
	if town.protection > 0: faith_delta += 0.0025
	if town.get("cult", 0) > 0: corruption_delta += 0.004
	if town.get("possession", 0) > 0:
		corruption_delta += 0.005
		town.fear += 0.006
	if fed < 0.8:
		corruption_delta += 0.002 * (1.0-fed)
		faith_delta -= 0.001
	var leader = get_person(int(town.leader))
	if not leader.is_empty() and leader.get("alive", false):
		if "zealous" in leader.traits: faith_delta += 0.001 if leader.alignment == "god" else 0.0
		if "ambitious" in leader.traits: corruption_delta += 0.0008
		if "skeptical" in leader.traits: faith_delta -= 0.0005
	if state.doctrine.god == "Free Will":
		town.fear = maxf(0.0, town.fear - 0.005)
		faith_delta += 0.0005 * town.happiness
	if state.doctrine.devil == "Temptation": corruption_delta += 0.001 * (1.0-town.happiness)
	if state.doctrine.devil == "Chaos": town.happiness = maxf(0.0, town.happiness-town.corruption*0.002)
	if state.doctrine.devil == "Dominion":
		town.fear = minf(1.0, town.fear + town.corruption * 0.003)
		corruption_delta += town.fear * 0.0007
	# Reason erodes only unsupported belief; ongoing witnessed powers overcome it.
	if town.era >= 9:
		faith_delta -= 0.0003 * (town.era-8)
		corruption_delta -= 0.0002 * (town.era-8)
	town.faith = clampf(town.faith + faith_delta, 0.0, 1.0)
	town.corruption = clampf(town.corruption + corruption_delta, 0.0, 1.0)

func _orbital_year(town: Dictionary,yield_callback:Callable=Callable()):
	var epoch=generation
	# Habitats survive the loss of their Earth city and retain its culture.
	var inhabitants = float(town.get("orbital_population",0.0))
	if town.population <= 0.0:
		_belief_year(town,1.0)
		if int(town.get("pact",0)) > 0:
			town.corruption += 0.003
			town.wealth += 3.0
		town.research += inhabitants*0.03*(2.2 if int(town.get("education",0)) > 0 else 1.0)
		for field in ["plague","drought","blessing","protection","cult","possession","education","pact"]:
			town[field] = maxi(0,int(town.get(field,0))-1)
	var expected=inhabitants*0.005+float(town.get("orbit_death_carry",0))
	var deaths=floori(expected)
	town["orbit_death_carry"]=expected-deaths
	if yield_callback.is_valid():
		await _record_deaths(town,deaths,"orbit",true,yield_callback)
		if generation!=epoch: return
	else: _record_deaths(town,deaths,"orbit")
	var expected_births=inhabitants*0.024*clampf(1.0-inhabitants/2000.0,0,1)+float(town.get("orbit_birth_carry",0))
	var parents=_society.parents_for_birth(self,town,"orbit",maxi(0,floori(expected_births)))
	var births=mini(floori(expected_births),parents.size())
	town["orbit_birth_carry"]=fposmod(expected_births,1.0)
	town.orbital_population = maxf(0.0,inhabitants+births-deaths)
	state.total_births += births
	var first_birth=int(state.citizens.next_id)
	_citizens.add(self,int(town.id),births,"orbit")
	_society.record_births(self,town,first_birth,births,parents)
	_citizens.sync_town(self,town)

func _trade_and_diffusion():
	state.trade_routes = []
	var towns = state.settlements
	for i in range(towns.size()):
		var a = towns[i]
		if a.population <= 0: continue
		for j in range(i+1, towns.size()):
			var b = towns[j]
			if b.population <= 0 or _at_war(a.nation, b.nation): continue
			var distance = _distance(a, b)
			var trade_range = minf(Content.ERAS[a.era].trade, Content.ERAS[b.era].trade)
			if distance > trade_range: continue
			if mini(a.era, b.era) < 7 and not _land_connection(a, b): continue
			var amount = 0.0
			if a.food > a.population and b.food < b.population * 0.5:
				amount = minf(a.food-a.population, b.population*0.35)
				a.food -= amount
				b.food += amount
			elif b.food > b.population and a.food < a.population*0.5:
				amount = minf(b.food-b.population, a.population*0.35)
				b.food -= amount
				a.food += amount
			a.wealth += 0.2 + amount * 0.01
			b.wealth += 0.2 + amount * 0.01
			if Diplomacy.pact(self,int(a.nation),int(b.nation)).get("kind","")=="alliance":
				a.wealth+=0.05+amount*0.002; b.wealth+=0.05+amount*0.002
			if a.era > b.era: b.research += (a.era-b.era)*1.2
			elif b.era > a.era: a.research += (b.era-a.era)*1.2
			var contact = 0.0015 if mini(a.era,b.era) < 11 else 0.004
			var fd = (a.faith-b.faith)*contact
			var cd = (a.corruption-b.corruption)*contact
			a.faith -= fd
			b.faith += fd
			a.corruption -= cd
			b.corruption += cd
			if state.year % 20 == 0 and a.religion != b.religion:
				var missionary = a if maxf(a.faith,a.corruption) > maxf(b.faith,b.corruption) else b
				var audience = b if missionary.id == a.id else a
				if maxf(missionary.faith,missionary.corruption) > 0.58 and rng.randf() < 0.06:
					var prior = audience.religion
					audience.religion = missionary.religion
					audience.happiness = maxf(0.0,audience.happiness-0.025)
					add_event("A teaching reaches %s" % audience.name,"Traders bring %s from %s, challenging %s." % [missionary.religion,missionary.name,prior],"religion",audience.x,audience.y,["Trade contact", "Strong neighboring belief"])
			if state.trade_routes.size() < 180: state.trade_routes.append({"a":a.id, "b":b.id, "x1":a.x, "y1":a.y, "x2":b.x, "y2":b.y, "food":amount})

func _conflict_year():
	var ongoing = state.wars.duplicate()
	for war in ongoing:
		var a = _nation_front(int(war.a), int(war.b))
		var b = _nation_front(int(war.b), int(war.a))
		if a.is_empty() or b.is_empty() or state.year - war.since > 28:
			state.wars.erase(war)
			Diplomacy.sign_agreement(self,int(war.a),int(war.b),"peace",15,a if not a.is_empty() else b)
			add_event("A war ends", "Exhausted armies return home after %d years." % (state.year-war.since), "war", -1, -1, [str(war.reason), "Exhaustion or loss of opposing settlements"])
			_achievement("peacekeeper")
			continue
		var power_a = _military(a)
		var power_b = _military(b)
		var casualties_a = minf(a.population * 0.035, power_b * 0.02) * (0.25 if a.protection > 0 else 1.0)
		var casualties_b = minf(b.population * 0.035, power_a * 0.02) * (0.25 if b.protection > 0 else 1.0)
		war["front_a"]=a.id
		war["front_b"]=b.id
		war["casualties_a"]=float(war.get("casualties_a",0))+casualties_a
		war["casualties_b"]=float(war.get("casualties_b",0))+casualties_b
		war["last_battle_year"]=state.year
		for front in [a,b]:
			front["visual_damage"]=minf(0.65,float(front.get("visual_damage",0))+0.012)
			front["visual_disaster"]="battle"
			front["visual_disaster_until"]=state.year+3
		a.population -= casualties_a
		b.population -= casualties_b
		_record_deaths(a, casualties_a)
		_record_deaths(b, casualties_b)
		a.happiness = maxf(0.05, a.happiness-0.009)
		b.happiness = maxf(0.05, b.happiness-0.009)
		a.wealth = maxf(0.0, a.wealth-2.0)
		b.wealth = maxf(0.0, b.wealth-2.0)
		if state.year % 5 == 0:
			if power_a > power_b*1.7 and rng.randf() < 0.23: _conquer(a,b)
			elif power_b > power_a*1.7 and rng.randf() < 0.23: _conquer(b,a)
		if state.year % 10 == 0 and maxi(a.era,b.era) >= 10 and rng.randf() < 0.04:
			var target = b if a.era >= 10 else a
			var lost = target.population * (0.1 if target.protection > 0 else 0.4)
			target.population -= lost
			_record_deaths(target,lost)
			target.plague = maxi(target.plague,12)
			target.drought = maxi(target.drought,12)
			target["visual_damage"]=minf(0.95,float(target.get("visual_damage",0))+0.6)
			target["visual_disaster"]="atomic"
			target["visual_disaster_started"]=state.year
			target["visual_disaster_until"]=state.year+12
			state.effects.append({"type":"atomic", "x":target.x,"y":target.y,"radius":6,"started":state.year,"until":state.year+8})
			add_event("Atomic fire at %s" % target.name, "A desperate war escalates. Fallout poisons harvests for twelve years.", "disaster", target.x,target.y,["Atomic weapons available",str(war.reason),"Escalation during war"])
	if state.year % 10 != 0 or state.wars.size() >= 6: return
	for a in state.settlements:
		if a.population < 60 or a.era < 2: continue
		var b = _nearest_other(a, 30.0, true)
		if b.is_empty() or _at_war(a.nation,b.nation): continue
		if not Diplomacy.pact(self,int(a.nation),int(b.nation)).is_empty(): continue
		var peace = state.get("peace_until",{})
		if int(peace.get(str(a.nation),0)) > state.year or int(peace.get(str(b.nation),0)) > state.year: continue
		var hostility = absf(a.faith-b.faith) + absf(a.corruption-b.corruption)
		var aggression = _nation_aggression(a.nation)
		var cause = "Competition for borderland"
		var chance = 0.007 + aggression * 0.025
		if a.shortage > 2:
			chance += 0.12
			cause = "Food shortages and contested farmland"
		elif hostility > 1.0:
			chance += 0.045
			cause = "Hostile religious allegiances"
		elif a.faith > 0.55 and b.faith > 0.55 and a.religion != b.religion and a.religion != "Ancestral Spirits" and b.religion != "Ancestral Spirits":
			chance += 0.025
			cause = "Rival interpretations of the same divine allegiance"
		var ruler = get_person(a.leader)
		if not ruler.is_empty() and "aggressive" in ruler.traits:
			chance += 0.03
			cause += " under an aggressive ruler"
		if state.doctrine.devil == "Chaos": chance += a.corruption*0.035
		if rng.randf() < chance:
			state.wars.append({"a":a.nation,"b":b.nation,"since":state.year,"reason":cause})
			add_event("War reaches %s and %s" % [a.name,b.name], "Armies contest the frontier; trade between their nations stops.", "war",a.x,a.y,[cause])
			break

func _military(town: Dictionary) -> float:
	return town.population * Content.ERAS[town.era].military * (0.65+town.health*0.35) * (1.25 if "castle" in town.buildings else 1.0)

func _conquer(winner: Dictionary, loser: Dictionary):
	var old_nation = loser.nation
	loser.nation = winner.nation
	loser.happiness = maxf(0.1, loser.happiness-0.15)
	loser.fear = minf(1.0,loser.fear+0.2)
	loser.faith = lerpf(loser.faith,winner.faith,0.15)
	loser.corruption = lerpf(loser.corruption,winner.corruption,0.15)
	_claim_territory(loser)
	add_event("%s is conquered" % loser.name, "Its population now lives under %s rule." % _nation_name(winner.nation), "war",loser.x,loser.y,["Military advantage", "War with " + _nation_name(old_nation)])

func _migrate(town: Dictionary):
	if town.population < 18 or (town.shortage < 2 and town.happiness > 0.35): return
	var destination = _nearest_other(town, 40.0)
	if destination.is_empty() or destination.food < destination.population * 0.4 or _at_war(town.nation,destination.nation): return
	if town.era < 7 and not _land_connection(town,destination): return
	var count = floorf(town.population * 0.08)
	var new_total = destination.population+count
	destination.faith = (destination.faith*destination.population+town.faith*count)/new_total
	destination.corruption = (destination.corruption*destination.population+town.corruption*count)/new_total
	destination.population = new_total
	town.population -= count
	_citizens.transfer(self,int(town.id),int(destination.id),int(count))
	destination.happiness = maxf(0.05,destination.happiness-0.008)
	add_event("Families leave %s" % town.name, "%d people seek food and safety in %s, carrying their beliefs with them." % [int(count),destination.name], "migration",town.x,town.y,["Food shortage" if town.shortage > 1 else "Low happiness", "Neighboring food reserves"])

func _try_expand(town: Dictionary, carrying: float):
	if town.era < 1 or town.population < carrying*0.60 or town.food < town.population or state.year-int(town.last_expansion) < 45: return
	if state.settlements.size() >= 72: return
	var point = _find_site(town.x,town.y,22.0 if town.era < 7 else 42.0,7.0)
	if point.x < 0: return
	if town.era < 7 and not _land_connection(town,{"x":point.x,"y":point.y}): return
	var count = floorf(town.population*0.22)
	var colony = found_settlement(point.x,point.y,town.nation,count,"",int(town.id))
	if colony.is_empty(): return
	town.population -= count
	town.food *= 0.78
	town.last_expansion = state.year
	colony.era = town.era
	colony.faith = town.faith
	colony.corruption = town.corruption
	colony.religion = town.religion
	colony.buildings = town.buildings.duplicate()
	colony.knowledge = town.knowledge*0.6
	colony.happiness = 0.8
	add_event("Settlers depart %s" % town.name, "%d settlers found %s with the tools and beliefs of their homeland." % [int(count),colony.name], "migration",colony.x,colony.y,["Growing population", "Food reserves", "Unoccupied habitable land"])
	if state.settlements.size() >= 10: _achievement("ten_towns")

func _try_revolt(town: Dictionary):
	if town.happiness >= 0.31 or town.population < 35 or state.year-int(town.get("last_revolt",0)) < 55: return
	if rng.randf() > 0.23: return
	town.last_revolt = state.year
	var old = get_person(town.leader)
	if not old.is_empty():
		var fallen=_citizens.kill_key(self,"p:%d"%int(old.id))
		if not fallen.is_empty():
			town.population=maxf(0.0,float(town.population)-1.0)
			_record_deaths(town,1.0,"surface",false)
		old.alive = false
	var ruler = _create_person(town,"ruler")
	town.leader = ruler.id
	var sibling = 0
	for other in state.settlements:
		if other.nation == town.nation and other.population > 0: sibling += 1
	if sibling > 1 and state.nations.size() < 20:
		var nation_id = state.nations.size()
		state.nations.append({"id":nation_id,"name":town.name+" Free State","color":Content.NATION_COLORS[nation_id%Content.NATION_COLORS.size()],"aggression":rng.randf_range(0.15,0.85),"allies":[],"doctrine":"Self-rule"})
		town.nation = nation_id
		_claim_territory(town)
	town.happiness = 0.52
	town.fear *= 0.5
	var losses = town.population*0.025
	town.population -= losses
	_record_deaths(town,losses)
	add_event("Revolution in %s" % town.name, "%s takes power after the old ruler falls; the town demands a new future." % ruler.name,"politics",town.x,town.y,["Sustained low happiness", "Hunger, fear, or war fatigue"])

func _try_religion(town: Dictionary):
	if town.population < 40: return
	var leader = get_person(town.leader)
	var prophet_present = false
	for person in state.people:
		if person.alive and person.settlement == town.id and person.role == "prophet": prophet_present = true
	if not prophet_present and (town.faith > 0.57 or town.corruption > 0.57) and rng.randf() < 0.1:
		var prophet = _create_person(town,"prophet")
		prophet.traits = ["zealous"]
		town.religion = prophet.name+"'s Covenant" if prophet.alignment == "god" else prophet.name+"'s Pact"
		add_event("%s speaks in %s" % [prophet.name,town.name], "A prophet gathers followers into %s. Their teaching will spread through trade." % town.religion,"religion",town.x,town.y,["Strong local allegiance", "A charismatic believer"])
	if town.era >= 6 and town.faith > 0.25 and town.corruption > 0.2 and state.year-int(town.get("last_schism",0)) > 100 and rng.randf() < 0.035:
		town.last_schism = state.year
		var previous = town.religion
		town.religion = "Reformed "+str(leader.get("name",town.name))+" Tradition"
		town.happiness = maxf(0.0,town.happiness-0.12)
		town.fear = minf(1.0,town.fear+0.12)
		if town.faith >= town.corruption:
			town.faith = minf(0.9,town.faith+0.09)
			town.corruption *= 0.8
		else:
			town.corruption = minf(0.9,town.corruption+0.09)
			town.faith *= 0.8
		add_event("The faith of %s splits" % town.name, "Competing teachings divide %s. A new tradition takes hold amid unrest." % previous,"religion",town.x,town.y,["Printing and education", "Competing allegiances", "A century of religious tradition"])
		_achievement("schism")

func _people_year():
	for person in state.people:
		if not person.get("alive",false): continue
		person.age += 1
		var town = get_settlement(int(person.settlement))
		var identity = _citizens.status(self,"p:%d" % int(person.id))
		var resident_died = not identity.is_empty() and not identity.alive
		if town.is_empty() or resident_population(town) <= 0 or person.age >= person.lifespan or resident_died:
			if not resident_died and not identity.is_empty() and identity.alive:
				_citizens.kill_key(self,"p:%d" % int(person.id))
				var field="population" if identity.location=="surface" else "orbital_population"
				town[field]=maxf(0.0,float(town.get(field,0))-1.0)
				_record_deaths(town,1.0,str(identity.location),false)
			person.alive = false
			if not town.is_empty() and resident_population(town) > 0:
				add_event("%s is remembered" % person.name, "The %s dies at age %d; their life becomes part of %s's history." % [person.role,person.age,town.name],"person",town.x,town.y,["End of natural lifespan"])
			continue
		if person.role == "prophet":
			if person.alignment == "god": town.faith = minf(1.0,town.faith+0.003)
			else: town.corruption = minf(1.0,town.corruption+0.003)
	for town in state.settlements:
		if resident_population(town) <= 0: continue
		var leader = get_person(int(town.leader))
		if leader.is_empty() or not leader.get("alive",false) or int(leader.get("settlement",-1))!=int(town.id):
			var heirs=[]
			for child in _society.life(self,"p:%d"%int(town.leader)).get("children",[]):
				var candidate=get_individual(child)
				if not candidate.is_empty() and candidate.alive and candidate.age>=18 and candidate.settlement==town.id and not candidate.imprisoned: heirs.append(candidate)
			heirs.sort_custom(func(a,b):return a.age>b.age if a.age!=b.age else str(a.key)<str(b.key))
			var successor = {}
			if not heirs.is_empty() and _citizens._aliases.has(str(heirs[0].key)):
				successor=get_person(int(str(_citizens._aliases[str(heirs[0].key)]).trim_prefix("p:")))
				successor.role="ruler"
				state.citizens.overrides[str(heirs[0].key)].role="ruler"
				_citizens._changed(self,false)
			else:
				successor = _create_person(town,"ruler",str(heirs[0].key) if not heirs.is_empty() else "")
			successor["predecessor"] = town.leader
			town.leader = successor.id
			if not heirs.is_empty():
				_society.remember(self,"p:%d"%int(successor.id),"Inherited leadership","As the eldest eligible adult child in this community, they inherit their parent's office.")
				town.happiness=minf(1,town.happiness+0.03)
			add_event("%s succeeds in %s" % [successor.name,town.name], "A %s ruler takes responsibility for the settlement." % successor.traits[0],"politics",town.x,town.y,["Previous ruler's death"])
	# Keep recent history and living characters without unlimited accumulation.
	if state.people.size() > 1200:
		var living = state.people.filter(func(person): return person.get("alive",false))
		var dead = state.people.filter(func(person): return not person.get("alive",false))
		state.people = dead.slice(maxi(0,dead.size()-600)) + living

func _supernatural_year():
	for agent in state.agents.duplicate():
		if state.year-int(agent.get("created",0)) >= int(agent.get("lifespan",40)):
			state.agents.erase(agent)
			continue
		var town = get_settlement(int(agent.get("settlement",-1)))
		if town.is_empty() or resident_population(town) <= 0: continue
		var power = float(agent.get("strength",1.0))*0.004
		if str(agent.get("side","god")) == "god":
			town.faith += power
			town.health = minf(1.0,town.health+power)
			if agent.get("type","") == "guardian": town.protection = maxi(town.protection,2)
		else:
			town.corruption += power
			town.wealth += power*200.0
	for artifact in state.artifacts:
		var town = get_settlement(int(artifact.get("settlement",-1)))
		if town.is_empty() or resident_population(town) <= 0: continue
		var pressure = clampf(float(artifact.get("power",0.025)),0.0,0.1)*0.16
		if artifact.get("side","god") == "god":
			town.faith += pressure
			town.food += town.population*pressure
		else:
			town.corruption += pressure
			town.research += pressure*100.0

func _natural_event():
	var alive = state.settlements.filter(func(town): return town.population > 0)
	if alive.is_empty() or rng.randf() > (0.3 if state.settings.get("difficulty","normal") == "gentle" else 0.55): return
	var town = alive[rng.randi_range(0,alive.size()-1)]
	if town.protection > 0: return
	if rng.randf() < 0.5:
		town.drought = maxi(town.drought,rng.randi_range(3,7))
		state.effects.append({"type":"drought","x":town.x,"y":town.y,"radius":4,"started":state.year,"until":state.year+town.drought})
		add_event("Dry skies over %s" % town.name,"Rain fails; stored grain and neighboring trade may preserve the population.","disaster",town.x,town.y,["Natural climate variability"])
	else:
		town.plague = maxi(town.plague,rng.randi_range(3,6))
		state.effects.append({"type":"plague","x":town.x,"y":town.y,"radius":4,"started":state.year,"until":state.year+town.plague})
		add_event("Illness reaches %s" % town.name,"An outbreak threatens the population. Medicine and protection reduce the toll.","disaster",town.x,town.y,["Natural disease outbreak", "Population contact"])

func _record_deaths(town: Dictionary, count: float, location: String = "surface", update_roster: bool = true,yield_callback:Callable=Callable()):
	if update_roster and state.has("citizens"):
		if yield_callback.is_valid():
			if await _citizens.retire(self,int(town.id),floori(maxf(0,count)),location,yield_callback)<0: return
		else: _citizens.retire(self,int(town.id),floori(maxf(0,count)),location)
	count = maxf(0.0,count)
	state.total_deaths = float(state.get("total_deaths",0.0))+count
	var faith = clampf(float(town.faith),0.0,1.0)
	var corruption = clampf(float(town.corruption),0.0,1.0-faith)
	state.afterlife.heaven += count*faith
	state.afterlife.hell += count*corruption
	state.afterlife.wandering += count*(1.0-faith-corruption)

func record_deaths(town: Dictionary, count: float):
	_record_deaths(town,count)

func _normalize_town(town: Dictionary):
	for field in ["faith","corruption","health","happiness","fear"]: town[field] = clampf(float(town.get(field,0.0)),0.0,1.0)
	var combined = town.faith+town.corruption
	if combined > 1.0:
		town.faith /= combined
		town.corruption /= combined
	for field in ["population","food","wealth","knowledge","research"]: town[field] = maxf(0.0,float(town.get(field,0.0)))
	town.era = clampi(int(town.era),0,Content.ERAS.size()-1)

func refresh_totals():
	if state.is_empty(): return
	if state.has("citizens"): _citizens.sync(self,true)
	var pop = 0.0
	var faith = 0.0
	var corruption = 0.0
	var orbit = 0.0
	var surface = 0.0
	var count = 0
	for town in state.settlements:
		_normalize_town(town)
		var habitat = maxf(0.0,float(town.get("orbital_population",0.0)))
		var residents = town.population + habitat
		pop += residents
		surface += town.population
		faith += residents*town.faith
		corruption += residents*town.corruption
		orbit += habitat
		if town.population > 0: count += 1
	state.orbital_population = orbit
	state.stats = {"population":pop,"surface_population":surface,"god":faith/maxf(pop,1.0),"devil":corruption/maxf(pop,1.0),"neutral":maxf(0.0,1.0-(faith+corruption)/maxf(pop,1.0)),"settlements":count,"deaths":float(state.get("total_deaths",0.0)),"births":float(state.get("total_births",0.0)),"orbital_population":orbit}
	if pop < 1.0 and orbit < 1.0 and state.year > 0 and not state.get("extinct",false):
		state["extinct"] = true
		add_event("The last light fades","No living civilization remains. In sandbox, settle new people to begin again.","world")
	elif pop >= 1.0: state["extinct"] = false

func restore(data: Dictionary):
	generation+=1
	state = data.duplicate(true)
	_land_cache.clear()
	_fertility_cache.clear()
	_cache_revision = -1
	rng.seed = str(state.get("seed","Genesis")).hash()
	rng.state = int(state.get("rng_state",str(rng.state)))
	# JSON stores numbers as floats. Dictionary IDs and dimensions must be integral.
	for field in ["year","width","height","next_id","terrain_revision"]: state[field] = int(state.get(field,0))
	for town in state.settlements:
		for field in ["id","x","y","nation","era","leader","founded"]: town[field] = int(town.get(field,0))
		for field in ["cult","possession","education","pact","shortage","last_expansion","last_revolt","last_schism"]: town[field] = int(town.get(field,0))
		for field in ["pollution","orbital_population"]: town[field] = float(town.get(field,0.0))
	# Old competitive saves become unrestricted single-player worlds.
	state.mode="sandbox"; state.victory=""; state.player_side="god"; state.active_side="god"
	state.settings.mode="sandbox"; state.settings.player_side="god"
	for obsolete in ["actions_left","ai_actions","turn","victory_streak","last_victory_year"]: state.erase(obsolete)
	state["total_deaths"] = float(state.get("total_deaths",state.get("stats",{}).get("deaths",0.0)))
	state["total_births"] = float(state.get("total_births",state.get("stats",{}).get("births",0.0)))
	state["trade_routes"] = state.get("trade_routes",[])
	_citizens = CitizenRegistry.new()
	_society = LifeSociety.new()
	_citizens.initialize(self)
	refresh_totals()
	_society.initialize(self)
	Transport.upgrade_routes(self)

func add_event(title: String, detail: String, kind: String = "world", x: int = -1, y: int = -1, causes: Array = []):
	var event = {"id":_next_id(),"year":int(state.year),"title":title,"detail":detail,"kind":kind,"x":x,"y":y,"causes":causes.duplicate()}
	state.events.append(event)
	if state.events.size() > 700: state.events.pop_front()
	if x >= 0:
		var town = nearest_settlement(x,y,5.0)
		if not town.is_empty():
			town.history.append({"year":state.year,"title":title,"detail":detail,"causes":causes.duplicate()})
			if town.history.size() > 30: town.history.pop_front()

func get_settlement(id: int) -> Dictionary:
	for town in state.get("settlements",[]):
		if int(town.id) == id: return town
	return {}

func get_person(id: int) -> Dictionary:
	for person in state.get("people",[]):
		if int(person.id) == id: return person
	return {}

func resident_page(town_id:int,offset:int=0,limit:int=24,query:String="") -> Dictionary:
	return _citizens.page(self,town_id,offset,limit,query)

func get_individual(key:String) -> Dictionary:
	return _citizens.get_person(self,key)

func individual_keys(town_id:int,limit:int=24,selected_key:String="") -> Array[String]:
	return _citizens.keys(self,town_id,limit,selected_key)

func role_keys(town_id:int,role:String,limit:int=16) -> Array[String]:
	return _citizens.role_keys(self,town_id,role,limit)

func preview_person_influence(key:String,action:String,side:String="god") -> Dictionary:
	if action in LifeSociety.PERSONAL_ACTIONS: return _society.preview(self,key,action,side)
	return _citizens.preview(self,key,action,side)

func apply_person_influence(key:String,action:String,side:String="god") -> Dictionary:
	if action in LifeSociety.PERSONAL_ACTIONS: return _society.influence(self,key,action,side)
	return _citizens.influence(self,key,action,side)

func kill_individual(key:String,cause:String)->bool:
	var person=_citizens.kill_key(self,key,cause)
	if person.is_empty(): return false
	var town=get_settlement(int(person.settlement))
	var field="population" if person.location=="surface" else "orbital_population"
	town[field]=maxf(0,float(town.get(field,0))-1)
	_record_deaths(town,1.0,str(person.location),false)
	for named in state.people:
		if str(state.citizens.named.get("p:%d"%int(named.id),""))==person.key: named.alive=false
	return true

func start_rebellion(town:Dictionary,organizer_key:String)->bool:
	var organizer=get_individual(organizer_key)
	if organizer.is_empty() or not organizer.alive or organizer.age<18 or organizer.imprisoned or organizer.settlement!=town.id: return false
	var old=get_person(int(town.leader))
	var old_key=str(state.citizens.named.get("p:%d"%int(town.leader),""))
	if not old.is_empty():
		old.role="deposed ruler"
		state.citizens.overrides[old_key].role="deposed ruler"
		_society.edit_life(self,old_key).prison_until=int(state.year)+10
		_society.remember(self,old_key,"Deposed","An uprising led by "+organizer.name+" ended this reign.")
	var public={}
	for named in state.people:
		if named.alive and str(state.citizens.named.get("p:%d"%int(named.id),""))==organizer.key: public=named; break
	if public.is_empty():
		public={"id":_next_id(),"name":organizer.name,"role":"ruler","settlement":int(town.id),"age":int(organizer.age),"born":int(state.year)-int(organizer.age),"lifespan":maxi(80,int(organizer.age)+20),"alive":true,"traits":organizer.traits.duplicate(),"alignment":"god" if organizer.faith>=organizer.corruption else "devil"}
		state.people.append(public)
		state.citizens.named["p:%d"%int(public.id)]=organizer.key
	public.role="ruler"
	_society.edit_life(self,organizer.key)
	state.citizens.overrides[organizer.key].role="ruler"
	town.leader=int(public.id); town.last_revolt=int(state.year)
	var old_nation=int(town.nation)
	var sibling=0
	for other in state.settlements:
		if int(other.nation)==old_nation and other.population>0: sibling+=1
	var civil_war=sibling>1 and state.nations.size()<20
	if civil_war:
		var id=state.nations.size()
		state.nations.append({"id":id,"name":town.name+" Free State","color":Content.NATION_COLORS[id%Content.NATION_COLORS.size()],"aggression":0.45,"allies":[],"doctrine":"Self-rule"})
		town.nation=id
		state.wars.append({"a":old_nation,"b":id,"since":int(state.year),"reason":"Civil war after "+organizer.name+" led an uprising against the old government."})
		_claim_territory(town)
	town.happiness=0.55; town.fear*=0.4
	for law in state.society.laws:
		if int(law.town)==int(town.id) and law.kind in ["repression","guild_privileges"]: law.until=int(state.year)
	_society.remember(self,organizer.key,"A revolution", "Led an uprising and became ruler."+(" The realm split into civil war." if civil_war else " The old ruler was imprisoned."))
	_citizens._changed(self)
	add_event(("Civil war in " if civil_war else "Revolution in ")+town.name,organizer.name+" leads an uprising against "+str(old.get("name","the government"))+". "+("Rebels and loyalists now fight for the realm." if civil_war else "The old ruler is deposed and imprisoned."),"politics",town.x,town.y,["Organizer: "+organizer.key,"Tyranny and public resentment"])
	return true

func faction_summary(nation_id:int) -> Dictionary:
	var nation={}
	for candidate in state.get("nations",[]):
		if int(candidate.id)==nation_id: nation=candidate; break
	if nation.is_empty(): return {}
	var result={"id":nation_id,"name":str(nation.name),"color":str(nation.color),"population":0.0,"settlements":0,"wealth":0.0,"food":0.0,"era":0,"highest_era":0,"faith":0.0,"corruption":0.0,"stability":0.0,"aggression":float(nation.get("aggression",0.5)),"leaders":[],"wars":[]}
	for town in state.get("settlements",[]):
		if int(town.nation)!=nation_id or resident_population(town)<=0: continue
		var population=resident_population(town)
		result.population+=population
		result.settlements+=1
		result.wealth+=float(town.wealth)
		result.food+=float(town.food)
		result.era=maxi(int(result.era),int(town.era))
		result.faith+=float(town.faith)*population
		result.corruption+=float(town.corruption)*population
		result.stability+=clampf(float(town.happiness)*(1.0-float(town.fear)*0.35),0,1)*population
		var leader=get_individual("p:%d"%int(town.leader))
		if not leader.is_empty() and leader.alive: result.leaders.append(leader)
	for field in ["faith","corruption","stability"]: result[field]/=maxf(1,result.population)
	result.highest_era=result.era
	for war in state.get("wars",[]):
		if int(war.a)==nation_id or int(war.b)==nation_id: result.wars.append(war.duplicate(true))
	result.direction="Contesting borders and committing resources to war." if not result.wars.is_empty() else ("Unrest threatens the current leadership." if result.stability<0.35 else ("Building knowledge, prosperity and settlement growth." if result.stability>0.65 else "Balancing food, belief and the demands of its people."))
	return result

func get_tile(x: int,y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= int(state.get("width",0)) or y >= int(state.get("height",0)): return {}
	return state.tiles[y*int(state.width)+x]

func nearest_settlement(x: int,y: int,radius: float = 12.0) -> Dictionary:
	var nearest = {}
	var best = radius*radius
	for town in state.get("settlements",[]):
		if resident_population(town) <= 0: continue
		var distance = float((town.x-x)*(town.x-x)+(town.y-y)*(town.y-y))
		if distance <= best:
			best = distance
			nearest = town
	return nearest

func resident_population(town: Dictionary) -> float:
	return maxf(0.0,float(town.get("population",0.0)))+maxf(0.0,float(town.get("orbital_population",0.0)))

func _nearest_other(town: Dictionary, radius: float, foreign: bool = false) -> Dictionary:
	var found = {}
	for other in state.settlements:
		if other.id == town.id or other.population <= 0 or (foreign and other.nation == town.nation): continue
		var distance = _distance(town,other)
		if distance < radius:
			radius = distance
			found = other
	return found

func _distance(a: Dictionary,b: Dictionary) -> float:
	return Vector2(float(a.x),float(a.y)).distance_to(Vector2(float(b.x),float(b.y)))

func _local_fertility(x: int,y: int) -> float:
	_refresh_spatial_cache()
	var cache_key = y * int(state.width) + x
	if _fertility_cache.has(cache_key): return float(_fertility_cache[cache_key])
	var amount = 0.0
	var count = 0.0
	for dy in range(-2,3):
		for dx in range(-2,3):
			var tile = get_tile(x+dx,y+dy)
			if tile.is_empty(): continue
			var suitability = clampf(1.0-absf(float(tile.temperature)-0.55)*0.8-maxf(0.0,0.35-float(tile.moisture))*1.3,0.25,1.0)
			amount += float(tile.fertility)*suitability if tile.elevation >= 0.36 else 0.32
			count += 1.0
	var result = amount/maxf(1.0,count)
	_fertility_cache[cache_key] = result
	return result

func _find_site(from_x: int,from_y: int,radius: float,min_distance: float) -> Vector2i:
	var best = Vector2i(-1,-1)
	var score = -1.0
	for unused in range(140):
		var x = rng.randi_range(3,state.width-4)
		var y = rng.randi_range(3,state.height-4)
		if from_x >= 0:
			x = clampi(from_x+rng.randi_range(-int(radius),int(radius)),3,state.width-4)
			y = clampi(from_y+rng.randi_range(-int(radius),int(radius)),3,state.height-4)
			if Vector2(x,y).distance_to(Vector2(from_x,from_y)) > radius: continue
		var tile = get_tile(x,y)
		if tile.elevation < 0.4 or tile.elevation > 0.73 or tile.temperature < 0.22: continue
		if not nearest_settlement(x,y,min_distance).is_empty(): continue
		var candidate = tile.fertility+rng.randf()*0.15
		if candidate > score:
			score = candidate
			best = Vector2i(x,y)
	return best

func _land_connection(a: Dictionary,b: Dictionary) -> bool:
	_refresh_spatial_cache()
	var first = int(a.y)*int(state.width)+int(a.x)
	var second = int(b.y)*int(state.width)+int(b.x)
	var key = str(mini(first,second))+":"+str(maxi(first,second))
	if _land_cache.has(key): return bool(_land_cache[key])
	var steps = maxi(1,int(_distance(a,b)))
	for i in range(1,steps):
		var ratio = float(i)/float(steps)
		var tile = get_tile(int(lerpf(float(a.x),float(b.x),ratio)),int(lerpf(float(a.y),float(b.y),ratio)))
		if tile.is_empty() or tile.elevation < 0.36:
			_land_cache[key] = false
			return false
	_land_cache[key] = true
	return true

func _refresh_spatial_cache():
	var revision = int(state.get("terrain_revision",0))
	if revision != _cache_revision:
		_cache_revision = revision
		_land_cache.clear()
		_fertility_cache.clear()

func _at_war(a: int,b: int) -> bool:
	if a == b: return false
	for war in state.wars:
		if (int(war.a) == a and int(war.b) == b) or (int(war.a) == b and int(war.b) == a): return true
	return false

func _nation_front(a: int,b: int) -> Dictionary:
	var best = {}
	var distance = INF
	for town in state.settlements:
		if town.nation != a or town.population <= 0: continue
		for other in state.settlements:
			if other.nation == b and other.population > 0 and _distance(town,other) < distance:
				best = town
				distance = _distance(town,other)
	return best

func _nation_aggression(id: int) -> float:
	for nation in state.nations:
		if int(nation.id) == id: return float(nation.aggression)
	return 0.4

func _nation_name(id: int) -> String:
	for nation in state.nations:
		if int(nation.id) == id: return str(nation.name)
	return "Unknown"

func _achievement(id: String):
	if id in state.achievements: return
	state.achievements.append(id)
	add_event("Milestone: "+id.replace("_"," ").capitalize(),str(Content.ACHIEVEMENTS.get(id,"History has changed.")),"achievement")
