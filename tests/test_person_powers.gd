extends SceneTree

const Powers = preload("res://scripts/powers.gd")
const Saves = preload("res://scripts/save_manager.gd")
const Simulation = preload("res://scripts/simulation.gd")
var failures = 0
var checks = 0
var powers = Powers.new()

class BoundarySim extends RefCounted:
	var state = {"mode":"versus_ai","victory":"","player_side":"god","active_side":"god","actions_left":3,"mana":{"god":100.0,"devil":100.0},"powers_used":0}
	var rejects = false
	func get_individual(key):
		if key not in ["c:1","c:2"]: return {}
		return {"key":key,"name":"Mira","alive":key == "c:1","standing":0.5,"influence":0.4,"role":"healer"}
	func preview_person_influence(_key,_action,_side):
		return {"ok":true,"message":"Ready.","consequence":"Health +20%; community health +0.4% per year for 12 years.","duration":12,"personal":{"health":0.2},"community":{"health":0.004}}
	func apply_person_influence(_key,_action,_side):
		if rejects: return {"ok":false,"message":"The recipient moved out of range."}
		state["accepted"] = true
		return {"ok":true,"message":"The intervention changed Mira's life."}
	func refresh_totals(): pass

func _initialize(): call_deferred("run")

func run():
	boundary_checks()
	registry_schema_checks()
	if "--rules-only" not in OS.get_cmdline_user_args(): real_simulation_checks()
	print("Personal powers/save: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func boundary_checks():
	check(Powers.PERSON_CATALOG.size()==18,"The catalog includes care, character and political interventions")
	for power in Powers.PERSON_CATALOG:
		if power.id=="resurrect_person": continue # Real resurrection is covered by test_sandbox_stories.
		var sim = BoundarySim.new()
		var before = JSON.stringify(sim.state)
		var forecast = powers.preview_person(sim,power.id,"c:1",power.side)
		check(forecast.ok and forecast.cost == power.cost,"Preview reports the actual cost for " + power.id)
		check(forecast.duration==12 and forecast.consequence.contains("12 years"),"Preview uses the simulation's exact duration and consequence")
		check(JSON.stringify(sim.state)==before,"Preview never changes simulation state")
		var result = powers.apply_to_person(sim,power.id,"c:1",power.side)
		check(result.ok and result.cost==power.cost,"A successful personal intervention reports its actual charge")
		check(is_equal_approx(float(sim.state.mana[power.side]),100.0-float(power.cost)),"Personal interventions leave essence unchanged")
		check(sim.state.actions_left==3,"Legacy turn metadata has no effect")
		check(sim.state.powers_used==1,"Personal interventions count once for world activity")
		var rejected = BoundarySim.new()
		rejected.rejects = true
		before = JSON.stringify(rejected.state)
		result = powers.apply_to_person(rejected,power.id,"c:1",power.side)
		check(not result.ok and JSON.stringify(rejected.state)==before,"Simulation rejection never charges or records a personal action")
	var attempts = [
		{"action":"unknown","key":"c:1","side":"god","changes":{}},
		{"action":"heal_person","key":"missing","side":"god","changes":{}},
		{"action":"heal_person","key":"c:2","side":"god","changes":{}},
		{"action":"heal_person","key":"c:1","side":"unknown","changes":{}},
	]
	for attempt in attempts:
		var sim = BoundarySim.new()
		sim.state.merge(attempt.changes,true)
		var before = JSON.stringify(sim.state)
		var preview = powers.preview_person(sim,attempt.action,attempt.key,attempt.side)
		var result = powers.apply_to_person(sim,attempt.action,attempt.key,attempt.side)
		check(not preview.ok and not result.ok,"Invalid or unavailable personal action is rejected: " + str(attempt))
		check(float(result.get("cost",0))==0.0,"A rejected action reports zero essence spent")
		check(before==JSON.stringify(sim.state),"Rejected personal intervention leaves the entire world unchanged")
	var poor = BoundarySim.new()
	poor.state.mana.god = 0.0
	var detail = powers.preview_person(poor,"heal_person","c:1","god")
	check(detail.ok and detail.cost==0 and detail.consequence.contains("Health +20%"),"Zero essence never blocks an action or hides its consequence")
	var sandbox = BoundarySim.new()
	sandbox.state.mode = "sandbox"
	sandbox.state.mana = {"god":0.0,"devil":0.0}
	check(powers.preview_person(sandbox,"corrupt_person","c:1","god").cost==0.0,"Sandbox preview displays a free personal action")
	check(powers.apply_to_person(sandbox,"corrupt_person","c:1","god").ok,"Sandbox allows either side's personal intervention")
	check(sandbox.state.mana.god==0.0 and sandbox.state.mana.devil==0.0,"Unlimited personal sandbox actions never change essence")

func registry_schema_checks():
	var sim = Simulation.new()
	sim.new_world({"seed":"Registry validation fixture","width":64,"height":48,"nations":2})
	var legacy = sim.state.duplicate(true)
	legacy.erase("citizens")
	legacy.erase("society")
	check(Saves.validate_state(legacy).ok,"Old saves remain valid without an individual registry")
	var town = legacy.settlements[0]
	for settlement in legacy.settlements:
		settlement.population = 0.0
		settlement.orbital_population = 0.0
	town.population = 2.75
	town.orbital_population = 1.5
	var registry = {"version":1,"next_id":5,"revision":0,"cohorts":[[1,4,-20,int(town.id),17,20]],"residents":{str(town.id):{"surface":[[1,2]],"orbit":[[3,1]]}},"deceased":[[4,1,0,int(town.id),0]],"overrides":{"c:2":{"stats":{"wisdom":0.1},"history":[{"year":0,"title":"A lesson","detail":"Shared knowledge."}],"effects":[{"action":"inspire_person","side":"god","until":12,"community":{"research":0.5}}]},"c:4":{"name":"Remembered resident","stats":{"health":-0.2}}},"named":{"p:7":"c:1"}}
	var state = legacy.duplicate(true)
	state.citizens = registry
	check(Saves.validate_state(state).ok,"Compact issued, living, orbital, dead, and individual override records validate")
	var missing_resident = state.duplicate(true)
	missing_resident.settlements[0].population = 3.1
	check(not Saves.validate_state(missing_resident).ok,"A populated settlement cannot silently lose a whole resident from its directory")
	var earlier_registry = state.duplicate(true)
	earlier_registry.citizens.erase("deceased")
	check(Saves.validate_state(earlier_registry).ok,"Registry saves made before death-history support remain compatible")
	var broken = state.duplicate(true)
	broken.citizens.residents[str(town.id)].orbit.append([2,1])
	check(not Saves.validate_state(broken).ok,"One identity cannot appear in both surface and orbital populations")
	broken = state.duplicate(true)
	broken.citizens.deceased.append([1,1,0,int(town.id),0])
	check(not Saves.validate_state(broken).ok,"One identity cannot simultaneously be alive and dead")
	broken = state.duplicate(true)
	broken.citizens.residents[str(town.id)].surface.append([5,1])
	check(not Saves.validate_state(broken).ok,"The registry rejects unissued living identities")
	broken = state.duplicate(true)
	broken.citizens.cohorts.append([2,2,0,int(town.id),9,0])
	check(not Saves.validate_state(broken).ok,"Issued identities cannot be reused in a later cohort")
	broken = state.duplicate(true)
	broken.citizens.overrides["c:2"].stats.wisdom = INF
	check(not Saves.validate_state(broken).ok,"Personal statistics cannot persist non-finite values")
	broken = state.duplicate(true)
	broken.citizens.named["p:8"] = "c:1"
	check(not Saves.validate_state(broken).ok,"Named legacy figures cannot duplicate one canonical resident")

func real_simulation_checks():
	var base = Simulation.new()
	base.new_world({"seed":"Individual actions integration","width":64,"height":48,"nations":3,"difficulty":"gentle"})
	if not base.has_method("get_individual") or not base.has_method("preview_person_influence"):
		check(false,"Individual simulation APIs are installed for integration testing")
		return
	var town_id = int(base.state.settlements[0].id)
	var page = base.resident_page(town_id,0,100)
	check(not page.people.is_empty(),"A real settlement exposes persistent residents")
	if page.people.is_empty(): return
	var key = str(page.people[0].key)
	var original = base.state.duplicate(true)
	for power in Powers.PERSON_CATALOG:
		var sim = Simulation.new()
		sim.restore(original)
		key=str(page.people[0].key)
		if power.id in ["bribe_person","promise_mercy","promise_cruelty"]:
			key=sim.get_individual("p:%d"%int(sim.state.settlements[0].leader)).key
		if power.id in ["promise_mercy","promise_cruelty"]:
			var first=int(sim.state.citizens.next_id)
			sim.state.settlements[0].population+=1
			sim._citizens.add(sim,town_id,1)
			var child="c:%d"%first
			sim._society.link_child(sim,child,[key])
			sim._society.edit_life(sim,child).illness="Fever"
			sim._society.edit_life(sim,child).sick_until=8
		if power.id=="resurrect_person": sim.kill_individual(key,"Test illness")
		sim.state.mode = "sandbox"
		sim.state.player_side = power.side
		sim.state.mana = {"god":1000.0,"devil":1000.0}
		var before = JSON.stringify(sim.state)
		var direct = preload("res://scripts/resurrection.gd").preview(sim,key) if power.id=="resurrect_person" else sim.preview_person_influence(key,power.id,power.side)
		var preview = powers.preview_person(sim,power.id,key,power.side)
		check(preview.ok and direct.ok,"A real personal action has a valid forecast: " + power.id)
		check(preview.consequence == str(direct.get("consequence",direct.get("message",""))),"Player preview exactly matches the shared simulation forecast")
		check(before==JSON.stringify(sim.state),"Real personal preview is read-only")
		var person_before = sim.get_individual(key)
		var result = powers.apply_to_person(sim,power.id,key,power.side)
		check(result.ok,"Personal action changes a real resident: %s (%s)" % [power.id,result.message])
		check(is_equal_approx(float(sim.state.mana[power.side]),1000.0),"Personal actions never charge essence")
		var after = sim.get_individual(key)
		check(JSON.stringify(person_before)!=JSON.stringify(after),"Personal intervention produces persistent individual changes")
		var validation = Saves.validate_state(sim.state)
		check(validation.ok,"Personal intervention leaves a saveable registry: " + validation.message)
		var copy = Simulation.new()
		copy.restore(JSON.parse_string(JSON.stringify(sim.state)))
		check(equivalent(copy.get_individual(key),after),"Individual identity and changes survive a JSON restore")
		copy.step(5)
		sim.step(5)
		check(sim.state.rng_state==copy.state.rng_state and is_equal_approx(float(sim.state.stats.population),float(copy.state.stats.population)),"Individual consequences resume deterministically after saving")
	var sim = Simulation.new()
	sim.restore(original)
	powers.apply_to_person(sim,"bless_person",key,"god")
	Saves.storage_directory = "user://personal_action_tests_"+str(Time.get_ticks_usec())
	var save = Saves.save_game(sim.state,0)
	check(save.ok,"An individual-enhanced world saves atomically: " + save.message)
	var loaded = Saves.load_game(0)
	check(loaded.ok,"An individual-enhanced world loads: " + loaded.message)
	if loaded.ok:
		var restored = Simulation.new()
		restored.restore(loaded.state)
		check(restored.get_individual(key).name==sim.get_individual(key).name,"Saved resident identity retains the same name")
	if "--long" in OS.get_cmdline_user_args():
		var started_at = Time.get_ticks_msec()
		for checkpoint in range(18):
			var lap = Time.get_ticks_msec()
			sim.step(100)
			print("Citizen endurance year %d: %.0f residents, %d cohorts, %d death ranges, %.2fs checkpoint / %.2fs total" % [sim.state.year,sim.state.stats.population,sim.state.citizens.cohorts.size(),sim.state.citizens.get("deceased",[]).size(),(Time.get_ticks_msec()-lap)/1000.0,(Time.get_ticks_msec()-started_at)/1000.0])
		var validation = Saves.validate_state(sim.state)
		check(validation.ok,"An 1800-year identity registry validates: " + validation.message)
		check(Saves.save_game(sim.state,1).ok,"An 1800-year identity registry saves within the file limit")
		check(Saves.load_game(1).ok,"An 1800-year identity registry can be loaded")
		print("Individual long world: year %d, population %.0f, JSON bytes %d" % [sim.state.year,sim.state.stats.population,JSON.stringify(sim.state).to_utf8_buffer().size()])
	cleanup()

func cleanup():
	var path = ProjectSettings.globalize_path(Saves.storage_directory)
	if Saves.storage_directory.begins_with("user://personal_action_tests_"):
		var directory = DirAccess.open(path)
		if directory != null:
			for file in directory.get_files(): DirAccess.remove_absolute(path.path_join(file))
			DirAccess.remove_absolute(path)
	Saves.storage_directory = Saves.SAVE_DIRECTORY

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("PERSONAL ACTION: "+message)

func equivalent(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a == b
