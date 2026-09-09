extends RefCounted
const Feedback=preload("res://scripts/person_interventions.gd")

## All human and computer interventions pass through this same rules boundary.
const CATALOG = [
	{"id":"land","name":"Raise Land","category":"world","cost":0,"icon":"^","radius":8,"description":"Lift sea into fertile lowlands; raise existing land gently."},
	{"id":"water","name":"Carve Ocean","category":"world","cost":0,"icon":"~","radius":8,"description":"Submerge terrain. Settlements caught in the water lose their population."},
	{"id":"mountain","name":"Mountains","category":"world","cost":0,"icon":"M","radius":8,"description":"Raise rocky mountains rich in ore."},
	{"id":"forest","name":"Grow Forest","category":"world","cost":0,"icon":"Y","radius":8,"description":"Plant dense forests and enrich the soil."},
	{"id":"fertility","name":"Enrich Soil","category":"world","cost":0,"icon":"+","radius":8,"description":"Restore fertile, moist soil for farms."},
	{"id":"ore","name":"Mineral Veins","category":"world","cost":0,"icon":"*","radius":8,"description":"Deposit ore that supports industry and research."},
	{"id":"warm","name":"Warm Climate","category":"world","cost":0,"icon":"O","radius":8,"description":"Raise temperature and dry the landscape."},
	{"id":"cool","name":"Cool Climate","category":"world","cost":0,"icon":"o","radius":8,"description":"Lower temperature and increase moisture."},
	{"id":"settlement","name":"Found Settlement","category":"life","cost":0,"icon":"H","radius":1,"description":"Place a new settlement on inhabitable land, at least five tiles from another."},
	{"id":"population","name":"Create People","category":"life","cost":0,"icon":"P","radius":4,"description":"Add sixty people and provisions to nearby settlements."},
	{"id":"wildlife","name":"Wildlife","category":"life","cost":0,"icon":"w","radius":4,"description":"Replenish wild food, forest growth, and local provisions."},
	{"id":"heal","name":"Healing Light","category":"divine","cost":0,"icon":"+","radius":4,"description":"Cure plague, restore health, and earn trust through relief."},
	{"id":"rain","name":"Gentle Rain","category":"divine","cost":0,"icon":"/","radius":5,"description":"End drought, water farms, and supply food."},
	{"id":"bless","name":"Blessing","category":"divine","cost":0,"icon":"B","radius":4,"description":"Twenty years of improved harvests and faith."},
	{"id":"protect","name":"Sanctuary","category":"divine","cost":0,"icon":"[]","radius":4,"description":"Protect people against war and hostile powers for twenty years."},
	{"id":"inspire","name":"Inspiration","category":"divine","cost":0,"icon":"!","radius":4,"description":"Expand knowledge and sustain education for fifteen years."},
	{"id":"prophet","name":"Send Prophet","category":"divine","cost":0,"icon":"A","radius":2,"description":"Create a named prophet who teaches faith for forty years."},
	{"id":"relic","name":"Sacred Relic","category":"divine","cost":0,"icon":"R","radius":2,"description":"Place a lasting artifact that encourages faith in its host settlement."},
	{"id":"purify","name":"Purification","category":"divine","cost":0,"icon":"*","radius":4,"description":"Dispel cults, possessions, and infernal pacts; reduce corruption."},
	{"id":"resurrect","name":"Rebirth","category":"divine","cost":0,"icon":"^","radius":2,"description":"Give up to forty souls new lives and new identities in a settlement. To restore someone you knew, open their profile and choose Return This Soul."},
	{"id":"tempt","name":"Temptation","category":"infernal","cost":0,"icon":"$","radius":4,"description":"Exchange instant wealth for corruption and eroded faith."},
	{"id":"pact","name":"Infernal Bargain","category":"infernal","cost":0,"icon":"&","radius":3,"description":"Give prosperity and knowledge for twenty years of growing infernal allegiance."},
	{"id":"cult","name":"Seed Cult","category":"infernal","cost":0,"icon":"C","radius":3,"description":"Establish a hidden cult spreading corruption for twenty-five years."},
	{"id":"possess","name":"Possession","category":"infernal","cost":0,"icon":"X","radius":2,"description":"Possess the ruler for fifteen years, spreading fear and corruption."},
	{"id":"forbidden","name":"Forbidden Knowledge","category":"infernal","cost":0,"icon":"?","radius":4,"description":"Accelerate research immediately, at the price of corruption and health."},
	{"id":"curse","name":"Withering Curse","category":"infernal","cost":0,"icon":"-","radius":4,"description":"Blight harvests for twelve years and inspire fear."},
	{"id":"demon","name":"Summon Demon","category":"infernal","cost":0,"icon":"D","radius":2,"description":"Send a persistent demon to intimidate a settlement for forty years."},
	{"id":"idol","name":"Dark Idol","category":"infernal","cost":0,"icon":"I","radius":2,"description":"Place an enduring artifact that encourages infernal worship."},
	{"id":"fire","name":"Wildfire","category":"disaster","cost":0,"icon":"F","radius":4,"description":"Burn forests, provisions, and homes; sanctuary reduces the losses."},
	{"id":"drought","name":"Drought","category":"disaster","cost":0,"icon":"_","radius":5,"description":"Dry the soil and suppress nearby harvests for fifteen years."},
	{"id":"plague","name":"Plague","category":"disaster","cost":0,"icon":"%","radius":4,"description":"Inflict a fifteen-year disease that can spread to trading neighbors."},
	{"id":"earthquake","name":"Earthquake","category":"disaster","cost":0,"icon":"Z","radius":5,"description":"Damage cities and population; expose fresh mineral deposits."},
	{"id":"meteor","name":"Meteor Strike","category":"disaster","cost":0,"icon":"@","radius":4,"description":"Devastate the impact area and leave a crater with mineral-rich ground."},
	{"id":"storm","name":"Tempest","category":"disaster","cost":0,"icon":"S","radius":5,"description":"Violent rains wreck provisions and buildings while replenishing moisture."},
	{"id":"ice","name":"Deep Freeze","category":"disaster","cost":0,"icon":"#","radius":5,"description":"Freeze farms and bring ten years of crop failure."},
	{"id":"volcano","name":"Volcano","category":"disaster","cost":0,"icon":"V","radius":4,"description":"Raise a volcanic mountain, burn the surrounding land, and destroy exposed homes."},
	{"id":"peace","name":"Concord","category":"divine","cost":0,"icon":"=","radius":3,"description":"End wars involving the chosen nation and calm nearby citizens."},
	{"id":"discord","name":"Incite War","category":"infernal","cost":0,"icon":"!","radius":3,"description":"Push the chosen nation into war with its nearest rival."}
]

const TERRAIN_POWERS = ["land", "water", "mountain", "forest", "fertility", "ore", "warm", "cool", "wildlife", "rain", "fire", "drought", "earthquake", "meteor", "storm", "ice", "volcano"]
const HOSTILE_POWERS = ["tempt", "pact", "cult", "possess", "forbidden", "curse", "demon", "idol", "fire", "drought", "plague", "earthquake", "meteor", "storm", "ice", "volcano", "discord"]

const PERSON_CATALOG = [
	{"id":"resurrect_person","name":"Return This Soul","cost":0,"side":"god","description":"Restore this deceased person with their memories and family.","consequence":"They return to their community, with twenty years of protection from old age. Existing marriages and inherited property are respected."},
	{"id":"infernal_cure","name":"Infernal Cure","cost":0,"side":"devil","description":"Heal this person through the Devil's intervention.","consequence":"Health returns and infernal allegiance grows. An accepted family bargain becomes due."},
	{"id":"curse_person","name":"Personal Curse","cost":0,"side":"devil","description":"Afflict this selected person with eight years of suffering.","consequence":"Health and happiness fall; their work and household are affected."},
	{"id":"possess_person","name":"Possession","cost":0,"side":"devil","description":"Take control of this person's conduct for eight years.","consequence":"Their own authority and job determine whether possession leads to repression or a crime."},
	{"id":"purify_person","name":"Release the Soul","cost":0,"side":"god","description":"Free this person from a curse or possession.","consequence":"Ends the supernatural affliction. Past deeds and their consequences remain."},
	{"id":"bribe_person","name":"Bribe an Official","cost":0,"side":"devil","description":"Offer this official private wealth for a law favoring merchants.","consequence":"Honorable officials refuse; others can pass Guild Privileges."},
	{"id":"pardon_person","name":"Mercy & Pardon","cost":0,"side":"god","description":"Release this person from prison and forgive outstanding offenses.","consequence":"Can encourage reform, but victims can resent the pardon."},
	{"id":"reveal_person","name":"Reveal Their Deeds","cost":0,"side":"god","description":"Expose this person's hidden crimes or corrupt dealings.","consequence":"Investigators gain a lead; an exposed tyrant faces stronger opposition."},
	{"id":"comfort_person","name":"Comfort the Bereaved","cost":0,"side":"god","description":"Ease this person's grief and resentment.","consequence":"Compassion can interrupt a household's cycle of anger."},
	{"id":"teach_person","name":"Gift of Learning","cost":0,"side":"god","description":"Improve this person's wisdom and ability to lead.","consequence":"Children carry learning into adulthood; workers improve their contribution."},
	{"id":"promise_mercy","name":"A Promise of Mercy","cost":0,"side":"god","description":"Accept this adult's promise to serve others if you heal a sick relative.","consequence":"The cure must be cast on the relative. Honor determines whether the adult keeps their word."},
	{"id":"promise_cruelty","name":"A Dark Bargain","cost":0,"side":"devil","description":"Ask for cruel service in return for a family member's cure.","consequence":"After accepting, heal the named relative to collect the promise; authority determines its reach."},
	{"id":"heal_person","name":"Healing Touch","cost":0,"side":"god","description":"Restore this person's health through a witnessed act of care.","consequence":"A healer can carry better care into the community for twelve years. The wider benefit depends on the person's role and influence."},
	{"id":"inspire_person","name":"Spark of Insight","cost":0,"side":"god","description":"Give this person clarity, wisdom, and a reason to pursue their work.","consequence":"Scholars advance research; practical workers improve production for twelve years. Established figures have a wider reach."},
	{"id":"bless_person","name":"Personal Blessing","cost":0,"side":"god","description":"Strengthen this person's faith, loyalty, and standing among their neighbors.","consequence":"A trusted person's example can spread faith through their community for twelve years."},
	{"id":"tempt_person","name":"Private Temptation","cost":0,"side":"devil","description":"Offer this person prosperity in exchange for ambition and infernal allegiance.","consequence":"Wealth and corruption spread farther through influential merchants and community leaders for twelve years."},
	{"id":"corrupt_person","name":"Whisper of Doubt","cost":0,"side":"devil","description":"Undermine this person's faith and loyalty while strengthening corruption.","consequence":"A respected convert can draw others toward the Devil for twelve years. The effect is limited by their actual standing and role."},
	{"id":"incite_person","name":"Feed the Fire","cost":0,"side":"devil","description":"Encourage this person's aggression, ambition, and willingness to challenge authority.","consequence":"Rulers and military figures can spread unrest more widely for twelve years. One intervention does not guarantee war or conquest."}
]

const PERSON_TARGETS={"heal":"heal_person","bless":"bless_person","inspire":"inspire_person","purify":"purify_person","tempt":"tempt_person","pact":"promise_cruelty","possess":"possess_person","curse":"curse_person"}

func get_power(power_id: String) -> Dictionary:
	for power in CATALOG:
		if power.id == power_id:
			if PERSON_TARGETS.has(power_id):
				var result=power.duplicate(true)
				var personal=get_person_power(PERSON_TARGETS[power_id])
				result.description="Select a person. "+personal.description
				result.cost=personal.cost
				return result
			return power
	return {}

func get_person_power(action_id: String) -> Dictionary:
	for power in PERSON_CATALOG:
		if power.id == action_id:
			var result=power.duplicate()
			result.description=Feedback.description(action_id)
			return result
	return {}

func preview_person(sim, action_id: String, key: String, side: String = "god") -> Dictionary:
	var power = get_person_power(action_id)
	if power.is_empty():
		return {"ok":false,"message":"Unknown personal intervention.","cost":0.0,"description":"","consequence":""}
	var result = {"ok":false,"message":"","cost":float(power.cost),"name":str(power.name),"description":str(power.description),"consequence":str(power.consequence),"action":action_id,"person_key":key,"side":str(power.side)}
	if sim == null or not sim.has_method("get_individual") or not sim.has_method("preview_person_influence"):
		result.message = "Individual interventions are unavailable in this world."
		return result
	var state = sim.state
	if state.get("mode", "sandbox") == "sandbox": result.cost = 0.0
	var person = sim.get_individual(key)
	if person.is_empty():
		result.message = "This person could not be found. Select a current resident."
		return result
	if not person.get("alive", false) and action_id!="resurrect_person":
		result.message = "This person is no longer alive."
		return result
	# The simulation builds the forecast from exactly the same role and standing
	# calculation that it uses for application. Never maintain a second estimate.
	var forecast = preload("res://scripts/resurrection.gd").preview(sim,key) if action_id=="resurrect_person" else sim.preview_person_influence(key, action_id, str(power.side))
	if not forecast.get("ok", false):
		result.message = str(forecast.get("message", "This person cannot receive this intervention."))
		return result
	result.consequence = str(forecast.get("consequence", forecast.get("message", power.consequence)))
	result["person_name"] = str(person.get("name", "This person"))
	result["role"] = str(person.get("role", "resident"))
	result["standing"] = float(person.get("standing", 0.0))
	result["influence"] = float(person.get("influence", 0.0))
	for field in ["impact", "duration", "duration_label", "personal", "community"]:
		if forecast.has(field): result[field] = forecast[field].duplicate(true) if forecast[field] is Dictionary or forecast[field] is Array else forecast[field]
	var rule = _personal_authorization(state, power, side)
	result.ok = rule.ok
	result.message = rule.message if not rule.ok else str(forecast.get("message", power.name + " is ready."))
	return result

func apply_to_person(sim, action_id: String, key: String, side: String = "god") -> Dictionary:
	var preview = preview_person(sim, action_id, key, side)
	if not preview.ok:
		var rejected = preview.duplicate(true)
		rejected["required_cost"] = float(preview.get("cost",0.0))
		rejected.cost = 0.0
		return rejected
	if not sim.has_method("apply_person_influence"):
		return _failure("Individual interventions are unavailable in this world.")
	var power = get_person_power(action_id)
	var outcome = preload("res://scripts/resurrection.gd").apply(sim,key) if action_id=="resurrect_person" else sim.apply_person_influence(key, action_id, str(power.side))
	if not outcome.get("ok", false):
		return {"ok":false,"message":str(outcome.get("message", "This intervention could not be completed.")),"cost":0.0}
	Feedback.record(sim,key,action_id,str(outcome.get("message","")))
	preload("res://scripts/story_journal.gd").follow(sim,key)
	var cost = 0.0
	sim.state["powers_used"] = int(sim.state.get("powers_used", 0)) + 1
	sim.refresh_totals()
	var result = outcome.duplicate(true)
	result["cost"] = cost
	result["action"] = action_id
	result["person_key"] = key
	result["consequence"] = str(preview.consequence)
	return result

func _personal_authorization(_state:Dictionary,_power:Dictionary,side:String)->Dictionary:
	if side not in ["god","devil"]: return _failure("Choose a valid divine influence.")
	return {"ok":true,"message":"This intervention is ready."}
func apply(sim, power_id: String, x: int, y: int, radius: int = 3, side: String = "god") -> Dictionary:
	if PERSON_TARGETS.has(power_id): return _failure("Select a person and open Influence to use this personal power.")
	var power = get_power(power_id)
	if power.is_empty():
		return _failure("Unknown power: " + power_id)
	var state = sim.state
	if x < 0 or y < 0 or x >= int(state.get("width", 0)) or y >= int(state.get("height", 0)):
		return _failure("Choose a tile inside the world.")
	if side not in ["god", "devil"]:
		return _failure("Choose God or Devil.")
	var brush=clampi(radius,1,12)
	var targets = _settlements_in_radius(sim, x, y, maxi(brush, 2) + 2)
	var summary = ""
	var news_kind=str(power.category)
	if power_id == "settlement":
		var tile = sim.get_tile(x, y)
		if float(tile.get("elevation", 0.0)) < 0.36 or float(tile.get("elevation", 0.0)) >= 0.86:
			return _failure("Found a settlement on lowland, away from water and high mountains.")
		if not sim.nearest_settlement(x, y, 5.0).is_empty():
			return _failure("Leave at least five tiles between settlements.")
		var founded = _found_settlement(sim, x, y, side)
		if founded.is_empty():
			return _failure("No nation is available to settle this land.")
		targets = [founded]
		summary = str(founded.name) + " was founded by sixty settlers."
	elif power_id == "resurrect":
		if targets.is_empty():
			return _failure("Choose a living settlement to receive the returning souls.")
		var afterlife = state.get("afterlife", {})
		var available = floori(float(afterlife.get("heaven", 0)) + float(afterlife.get("wandering", 0)))
		if available <= 0:
			return _failure("There are no souls in heaven or wandering to return.")
		var returned = mini(40, available)
		var heavenly = minf(float(returned), float(afterlife.get("heaven", 0)))
		afterlife.heaven = maxf(0.0, float(afterlife.get("heaven", 0)) - heavenly)
		afterlife.wandering = maxf(0.0, float(afterlife.get("wandering", 0)) - (returned - heavenly))
		var town = targets[0]
		town.population = float(town.population) + returned
		town.food = float(town.get("food", 0)) + returned * 2
		_shift_belief(town, 0.08, -0.03)
		summary = "%d souls returned to %s." % [returned, town.name]
	elif power_id in ["prophet", "demon", "relic", "idol"]:
		if targets.is_empty():
			return _failure("Choose a settlement for this power.")
		var town = targets[0]
		var artifact = power_id in ["relic", "idol"]
		var collection = state.artifacts if artifact else state.agents
		var actual_side = "god" if power_id in ["prophet", "relic"] else "devil"
		for existing in collection:
			if int(existing.get("settlement", -1)) == int(town.id) and existing.get("side", "") == actual_side:
				if artifact or int(existing.get("created", state.year)) + int(existing.get("lifespan", 40)) > int(state.year):
					return _failure("This settlement already has an active " + ("artifact" if artifact else "emissary") + " of " + actual_side.capitalize() + ".")
		var protection = 0.35 if HOSTILE_POWERS.has(power_id) and int(town.get("protection", 0)) > 0 else 1.0
		_spawn_presence(sim, town, power_id, actual_side, protection)
		summary = str(power.name) + " arrived in " + str(town.name) + "."
	elif power_id == "peace":
		if targets.is_empty():
			return _failure("Choose a settlement whose nation should make peace.")
		var nation_id = int(targets[0].nation)
		var removed = 0
		for index in range(state.wars.size() - 1, -1, -1):
			var war = state.wars[index]
			if int(war.get("a", -1)) == nation_id or int(war.get("b", -1)) == nation_id:
				state.wars.remove_at(index)
				removed += 1
		state["peace_until"] = state.get("peace_until", {})
		state.peace_until[str(nation_id)] = int(state.year) + 20
		for town in targets:
			town.fear = maxf(0.0, float(town.get("fear", 0)) - 0.25)
			town.happiness = minf(1.0, float(town.get("happiness", 0.5)) + 0.15)
			_shift_belief(town, 0.07, -0.03)
		summary = "%d wars ended; a twenty-year peace protects %s's nation." % [removed, targets[0].name]
		if removed>0: news_kind="peace"
	elif power_id == "discord":
		if targets.is_empty():
			return _failure("Choose a settlement whose nation should wage war.")
		var rival = _nearest_rival(sim, targets[0])
		if rival.is_empty():
			return _failure("There is no rival nation to attack.")
		var nation_id = int(targets[0].nation)
		for war in state.wars:
			if (int(war.a) == nation_id and int(war.b) == int(rival.nation)) or (int(war.b) == nation_id and int(war.a) == int(rival.nation)):
				return _failure("These neighboring nations are already at war.")
		if int(state.get("peace_until", {}).get(str(nation_id), 0)) > int(state.year):
			return _failure("Concord protects this nation from war for now.")
		if int(state.get("peace_until", {}).get(str(rival.nation), 0)) > int(state.year):
			return _failure("Concord protects the rival nation from war for now.")
		state.wars.append({"a":nation_id, "b":int(rival.nation), "since":int(state.year), "reason":"An infernal whisper convinced the ruler that conquest would bring salvation."})
		for town in targets:
			_shift_belief(town, -0.07, 0.1)
			town.fear = minf(1.0, float(town.get("fear", 0)) + 0.15)
		summary = str(targets[0].name) + "'s nation declared war on " + str(rival.name) + "'s nation."
		news_kind="war_start"
	else:
		if targets.is_empty() and power_id not in TERRAIN_POWERS:
			return _failure("Choose a tile near a living settlement.")
		var changed_tiles = 0
		if power_id in TERRAIN_POWERS:
			changed_tiles = _alter_terrain(sim, power_id, x, y, brush)
		if targets.is_empty() and changed_tiles == 0:
			return _failure("This power needs land or a nearby settlement.")
		for town in targets:
			_affect_settlement(sim, town, power_id)
		summary = "%s touched %d settlement%s" % [power.name, targets.size(), "" if targets.size() == 1 else "s"]
		if changed_tiles > 0:
			summary += " and %d tiles" % changed_tiles
		summary += "."
	var effect_side = side
	if power.category == "divine":
		effect_side = "god"
	elif power.category == "infernal":
		effect_side = "devil"
	state.effects.append({"type":power_id, "x":x, "y":y, "radius":brush, "started":int(state.year), "until":int(state.year) + 5, "side":effect_side})
	var causes = [str(power.description), "Intervention by " + side.capitalize()]
	for town in targets:
		if HOSTILE_POWERS.has(power_id) and int(town.get("protection", 0)) > 0:
			causes.append("Sanctuary reduced harm in " + str(town.name) + ".")
		var history = town.get("history", [])
		history.append({"year":int(state.year), "title":str(power.name), "detail":summary})
		if history.size() > 60:
			history.pop_front()
		town.history = history
	state["powers_used"] = int(state.get("powers_used", 0)) + 1
	sim.add_event("War is declared" if news_kind=="war_start" else ("Peace is declared" if news_kind=="peace" else str(power.name)), summary, news_kind, x, y, causes)
	sim.refresh_totals()
	return {"ok":true, "message":summary, "cost":0.0, "targets":targets.size()}

func _settlements_in_radius(sim, x: int, y: int, radius: int) -> Array:
	var found = []
	for town in sim.state.get("settlements", []):
		if _residents(town) > 0.0 and Vector2(float(town.x - x), float(town.y - y)).length_squared() <= radius * radius:
			found.append(town)
	found.sort_custom(func(a, b): return Vector2(a.x - x, a.y - y).length_squared() < Vector2(b.x - x, b.y - y).length_squared())
	return found

func _alter_terrain(sim, power_id: String, x: int, y: int, radius: int) -> int:
	var count = 0
	for ty in range(maxi(0, y - radius), mini(int(sim.state.height), y + radius + 1)):
		for tx in range(maxi(0, x - radius), mini(int(sim.state.width), x + radius + 1)):
			if Vector2(tx - x, ty - y).length_squared() > radius * radius:
				continue
			var tile = sim.get_tile(tx, ty)
			if float(tile.get("elevation", 0)) < 0.36 and power_id not in ["land", "water", "mountain", "volcano", "warm", "cool", "ice","meteor","rain","storm","earthquake"]:
				continue
			match power_id:
				"land":
					tile.elevation = clampf(maxf(0.42, float(tile.elevation)) + 0.03, 0.42, 0.8)
					tile.fertility = maxf(0.6, float(tile.get("fertility", 0)))
				"water":
					tile.elevation = 0.2
					tile.forest = 0.0
					tile.owner = -1
				"mountain":
					tile.elevation = minf(1.0, maxf(0.82, float(tile.elevation)) + 0.08)
					tile.ore = maxf(0.7, float(tile.get("ore", 0)))
					tile.fertility = 0.15
					tile.forest = 0.1
				"forest", "wildlife":
					tile.forest = minf(1.0, float(tile.get("forest", 0)) + 0.45)
					tile.fertility = minf(1.0, float(tile.get("fertility", 0)) + 0.15)
				"fertility":
					tile.fertility = 1.0
					tile.moisture = maxf(0.65, float(tile.get("moisture", 0)))
				"ore": tile.ore = 1.0
				"warm":
					tile.temperature = minf(1.0, float(tile.get("temperature", 0.5)) + 0.15)
					tile.moisture = maxf(0.0, float(tile.get("moisture", 0.5)) - 0.1)
				"cool":
					tile.temperature = maxf(0.0, float(tile.get("temperature", 0.5)) - 0.15)
					tile.moisture = minf(1.0, float(tile.get("moisture", 0.5)) + 0.05)
				"rain", "storm":
					tile.moisture = minf(1.0, float(tile.get("moisture", 0.5)) + 0.3)
					tile.fertility = minf(1.0, float(tile.get("fertility", 0.5)) + 0.1)
				"drought":
					tile.moisture = maxf(0.0, float(tile.get("moisture", 0.5)) - 0.5)
					tile.fertility = maxf(0.05, float(tile.get("fertility", 0.5)) - 0.2)
				"fire":
					tile.forest = 0.0
					tile.fertility = maxf(0.1, float(tile.get("fertility", 0.5)) - 0.15)
				"earthquake": tile.ore = minf(1.0, float(tile.get("ore", 0)) + 0.2)
				"meteor":
					tile.elevation = maxf(0.0 if float(tile.elevation)<0.36 else 0.38, float(tile.elevation) - 0.08)
					tile.forest = 0.0
					tile.ore = 1.0
					tile.fertility = 0.12
				"ice":
					tile.temperature = maxf(0.0, float(tile.get("temperature", 0.5)) - 0.35)
					tile.fertility = maxf(0.05, float(tile.get("fertility", 0.5)) - 0.15)
				"volcano":
					var distance = Vector2(tx - x, ty - y).length() / maxf(1.0, radius)
					tile.elevation = maxf(float(tile.elevation), lerpf(0.95, 0.45, distance))
					tile.forest = 0.0
					tile.ore = 1.0
					tile.fertility = 0.3
			_reclassify(tile)
			count += 1
	if count > 0:
		sim.state.terrain_revision = int(sim.state.get("terrain_revision", 0)) + 1
	return count

func _reclassify(tile: Dictionary) -> void:
	var e = float(tile.get("elevation", 0.5))
	if e < 0.36: tile.biome = "ocean"
	elif e < 0.4: tile.biome = "coast"
	elif float(tile.get("temperature", 0.5)) < 0.2: tile.biome = "snow"
	elif e > 0.8: tile.biome = "mountain"
	elif float(tile.get("moisture", 0.5)) < 0.2: tile.biome = "desert"
	elif float(tile.get("moisture", 0.5)) > 0.82 and e < 0.48: tile.biome = "marsh"
	elif float(tile.get("forest", 0)) > 0.5: tile.biome = "forest"
	else: tile.biome = "grass"

func _affect_settlement(sim, town: Dictionary, power_id: String) -> void:
	var strength = 0.35 if HOSTILE_POWERS.has(power_id) and int(town.get("protection", 0)) > 0 else 1.0
	if power_id in ["fire","meteor","earthquake","volcano","storm","ice","drought","plague"] and float(town.get("population",0))>0:
		town["visual_disaster"]=power_id
		town["visual_disaster_started"]=int(sim.state.year)
		town["visual_disaster_until"]=int(sim.state.year)+maxi(3,int(8*strength))
	match power_id:
		"water":
			if float(sim.get_tile(int(town.x), int(town.y)).get("elevation", 0)) < 0.36:
				_harm(sim, town, 1.0, 1.0)
		"population":
			town.population = float(town.population) + 60.0
			town.food = float(town.get("food", 0)) + 120.0
		"wildlife": town.food = float(town.get("food", 0)) + 50.0
		"heal":
			town.plague = 0
			town.health = 1.0
			town.happiness = minf(1.0, float(town.get("happiness", 0.5)) + 0.15)
			_shift_belief(town, 0.1, -0.03)
		"rain":
			town.drought = 0
			town.food = float(town.get("food", 0)) + float(town.population) * 0.8
			_shift_belief(town, 0.06, -0.01)
		"bless":
			town.blessing = maxi(int(town.get("blessing", 0)), 20)
			town.food = float(town.get("food", 0)) + float(town.population) * 0.5
			_shift_belief(town, 0.12, -0.03)
		"protect":
			town.protection = maxi(int(town.get("protection", 0)), 20)
			town.fear = maxf(0.0, float(town.get("fear", 0)) - 0.12)
			_shift_belief(town, 0.08, -0.02)
		"inspire":
			town.knowledge = float(town.get("knowledge", 0)) + 10.0
			town.research = float(town.get("research", 0)) + _research_gift(town, 0.25)
			town.education = maxi(int(town.get("education", 0)), 15)
			_shift_belief(town, 0.06, 0)
		"purify":
			town.cult = 0
			town.possession = 0
			town.pact = 0
			town.fear = maxf(0, float(town.get("fear", 0)) - 0.25)
			_shift_belief(town, 0.08, -0.25)
			for person in sim.state.people:
				if int(person.get("id", -1)) == int(town.get("leader", -2)):
					person.alignment = "god"
					person["possessed_until"] = 0
		"tempt":
			town.wealth = float(town.get("wealth", 0)) + 100.0 * strength
			_shift_belief(town, -0.08 * strength, 0.14 * strength)
		"pact":
			town.wealth = float(town.get("wealth", 0)) + 180.0 * strength
			town.food = float(town.get("food", 0)) + float(town.population) * strength
			town.knowledge = float(town.get("knowledge", 0)) + 15.0 * strength
			town.pact = maxi(int(town.get("pact", 0)), int(20 * strength))
			_shift_belief(town, -0.1 * strength, 0.18 * strength)
		"cult":
			town.cult = maxi(int(town.get("cult", 0)), int(25 * strength))
			_shift_belief(town, -0.05 * strength, 0.1 * strength)
		"possess":
			town.possession = maxi(int(town.get("possession", 0)), int(15 * strength))
			town.fear = minf(1, float(town.get("fear", 0)) + 0.25 * strength)
			_shift_belief(town, -0.12 * strength, 0.15 * strength)
			for person in sim.state.people:
				if int(person.get("id", -1)) == int(town.get("leader", -2)):
					person.alignment = "devil"
					person["possessed_until"] = int(sim.state.year) + int(15 * strength)
		"forbidden":
			town.knowledge = float(town.get("knowledge", 0)) + 25.0 * strength
			town.research = float(town.get("research", 0)) + _research_gift(town, 0.4) * strength
			town.health = maxf(0.15, float(town.get("health", 0.8)) - 0.12 * strength)
			_shift_belief(town, -0.08 * strength, 0.13 * strength)
		"curse":
			town.drought = maxi(int(town.get("drought", 0)), int(12 * strength))
			town.fear = minf(1, float(town.get("fear", 0)) + 0.18 * strength)
			_shift_belief(town, -0.08 * strength, 0.05 * strength)
		"fire": _harm(sim, town, 0.1 * strength, 0.45 * strength)
		"drought":
			town.drought = maxi(int(town.get("drought", 0)), int(15 * strength))
			town.food = float(town.get("food", 0)) * (1.0 - 0.35 * strength)
		"plague":
			town.plague = maxi(int(town.get("plague", 0)), int(15 * strength))
			town.health = maxf(0.1, float(town.get("health", 0.8)) - 0.3 * strength)
			town.fear = minf(1, float(town.get("fear", 0)) + 0.2 * strength)
		"earthquake": _harm(sim, town, 0.2 * strength, 0.4 * strength)
		"meteor": _harm(sim, town, 0.65 * strength, 0.85 * strength)
		"storm": _harm(sim, town, 0.06 * strength, 0.35 * strength)
		"ice":
			town.drought = maxi(int(town.get("drought", 0)), int(10 * strength))
			_harm(sim, town, 0.04 * strength, 0.3 * strength)
		"volcano": _harm(sim, town, 0.5 * strength, 0.8 * strength)

func _harm(sim, town: Dictionary, fraction: float, damage: float) -> void:
	var population = maxf(0.0, float(town.get("population", 0)))
	var deaths = minf(population, population * clampf(fraction, 0, 1))
	town.population = maxf(0, population - deaths)
	town.food = maxf(0, float(town.get("food", 0)) * (1 - damage))
	town.wealth = maxf(0, float(town.get("wealth", 0)) * (1 - damage))
	town.health = maxf(0.1, float(town.get("health", 0.8)) - damage * 0.4)
	town.happiness = maxf(0.05, float(town.get("happiness", 0.5)) - damage * 0.4)
	town.fear = minf(1, float(town.get("fear", 0)) + damage * 0.4)
	if population>0:
		town["visual_damage"]=clampf(float(town.get("visual_damage",0))+damage*0.65,0,0.95)
	if sim.has_method("record_deaths"):
		sim.record_deaths(town, deaths)
	else:
		sim.state.total_deaths = float(sim.state.get("total_deaths", 0)) + deaths
		var heaven = deaths * float(town.get("faith", 0))
		var hell = deaths * float(town.get("corruption", 0))
		sim.state.afterlife.heaven = float(sim.state.afterlife.get("heaven", 0)) + heaven
		sim.state.afterlife.hell = float(sim.state.afterlife.get("hell", 0)) + hell
		sim.state.afterlife.wandering = float(sim.state.afterlife.get("wandering", 0)) + maxf(0, deaths - heaven - hell)
	if _residents(town) <= 0:
		for person in sim.state.people:
			if int(person.get("settlement", -1)) == int(town.id):
				person.alive = false
	if damage >= 0.7 and town.get("buildings", []).size() > 1:
		town.buildings.resize(maxi(1, town.buildings.size() / 2))

func _shift_belief(town: Dictionary, faith_delta: float, corruption_delta: float) -> void:
	var faith = clampf(float(town.get("faith", 0)) + faith_delta, 0, 1)
	var corruption = clampf(float(town.get("corruption", 0)) + corruption_delta, 0, 1)
	if faith + corruption > 1:
		if faith_delta > corruption_delta:
			corruption = 1 - faith
		else:
			faith = 1 - corruption
	town.faith = faith
	town.corruption = corruption

func _research_gift(town: Dictionary, fraction: float) -> float:
	var content = load("res://scripts/content.gd")
	var era = clampi(int(town.get("era", 0)), 0, content.ERAS.size() - 1)
	return maxf(12.0, float(content.ERAS[era].threshold) * fraction)

func _spawn_presence(sim, town: Dictionary, power_id: String, side: String, strength: float) -> void:
	var names = {"prophet":"The Voice of Dawn", "demon":"The Ashen Herald", "relic":"The Ember of Creation", "idol":"The Obsidian Covenant"}
	var id = _next_id(sim.state)
	if power_id in ["relic", "idol"]:
		sim.state.artifacts.append({"id":id,"name":names[power_id],"settlement":int(town.id),"side":side,"power":0.025 * strength,"created":int(sim.state.year)})
	else:
		sim.state.agents.append({"id":id,"name":names[power_id],"type":power_id,"side":side,"settlement":int(town.id),"x":int(town.x),"y":int(town.y),"strength":strength,"lifespan":40,"created":int(sim.state.year)})
		if power_id == "prophet":
			sim.state.people.append({"id":id,"name":"Aurel " + str(town.name),"role":"prophet","settlement":int(town.id),"age":25,"lifespan":65,"alive":true,"traits":["visionary", "compassionate"],"alignment":"god"})
	_shift_belief(town, 0.06 * strength if side == "god" else -0.03 * strength, 0.08 * strength if side == "devil" else -0.02 * strength)

func _next_id(state: Dictionary) -> int:
	var id = int(state.get("next_id", 1))
	state.next_id = id + 1
	return id

func _found_settlement(sim, x: int, y: int, side: String) -> Dictionary:
	var nation_id = -1
	var nearby = sim.nearest_settlement(x, y, 10000.0)
	if not nearby.is_empty():
		nation_id = int(nearby.nation)
	elif not sim.state.get("nations", []).is_empty():
		nation_id = int(sim.state.nations[0].id)
	if sim.has_method("found_settlement"):
		var town = sim.found_settlement(x, y, nation_id, 60)
		if not town.is_empty():
			town.faith = 0.55 if side == "god" else 0.12
			town.corruption = 0.55 if side == "devil" else 0.12
		return town
	if nation_id < 0:
		return {}
	var id = _next_id(sim.state)
	var town = {"id":id,"name":"Haven " + str(id),"x":x,"y":y,"nation":nation_id,"population":60.0,"food":150.0,"wealth":40.0,"health":0.85,"happiness":0.75,"faith":0.55 if side == "god" else 0.12,"corruption":0.55 if side == "devil" else 0.12,"fear":0.05,"knowledge":0.0,"era":0,"research":0.0,"plague":0,"drought":0,"blessing":0,"protection":0,"leader":-1,"founded":int(sim.state.year),"history":[],"religion":"Dawn" if side == "god" else "Ember","buildings":["Hearth"]}
	sim.state.settlements.append(town)
	sim.get_tile(x, y).owner = nation_id
	sim.state.terrain_revision = int(sim.state.get("terrain_revision", 0)) + 1
	return town

func _nearest_rival(sim, town: Dictionary) -> Dictionary:
	var closest = {}
	var distance = INF
	for candidate in sim.state.settlements:
		if int(candidate.nation) == int(town.nation) or float(candidate.population) <= 0:
			continue
		var current = Vector2(candidate.x - town.x, candidate.y - town.y).length_squared()
		if current < distance:
			distance = current
			closest = candidate
	return closest

func set_doctrine(sim, side: String, doctrine: String) -> Dictionary:
	if side not in ["god", "devil"]:
		return _failure("Unknown divine side.")
	var content = load("res://scripts/content.gd")
	if doctrine not in content.DOCTRINES.get(side, []):
		return _failure("Unknown doctrine for " + side.capitalize() + ".")
	sim.state.doctrine[side] = doctrine
	sim.add_event("A new doctrine", side.capitalize() + " declared the doctrine of " + doctrine + ".", "belief", -1, -1, ["Divine doctrine changes the annual growth of belief and civilization."])
	return {"ok":true,"message":side.capitalize() + " follows " + doctrine + "."}

func _failure(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func _residents(town: Dictionary) -> float:
	return maxf(0.0, float(town.get("population", 0))) + maxf(0.0, float(town.get("orbital_population", 0)))
