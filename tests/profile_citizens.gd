extends SceneTree

class MeasuredRegistry extends "res://scripts/citizen_registry.gd":
	var timings = {}
	var calls = {}
	func measured(key:String,begin:int):
		timings[key]=int(timings.get(key,0))+Time.get_ticks_usec()-begin
		calls[key]=int(calls.get(key,0))+1
	func _build_index(sim):
		var begin=Time.get_ticks_usec()
		super._build_index(sim)
		measured("build_index",begin)
	func get_person(sim,key:String,include_social:bool=true,include_history:bool=true,identity_only:bool=false)->Dictionary:
		var begin=Time.get_ticks_usec()
		var result=super.get_person(sim,key,include_social,include_history,identity_only)
		measured("get_person",begin)
		return result
	func promote(sim,person:Dictionary,preserve:bool=false):
		var begin=Time.get_ticks_usec()
		super.promote(sim,person,preserve)
		measured("promote",begin)
	func transfer(sim,source:int,destination:int,amount:int,from_location:String="surface",to_location:String="surface")->int:
		var begin=Time.get_ticks_usec()
		var result=super.transfer(sim,source,destination,amount,from_location,to_location)
		measured("transfer",begin)
		return result
	func sync_town(sim,town,initial:bool=false):
		var begin=Time.get_ticks_usec()
		super.sync_town(sim,town,initial)
		measured("sync_town",begin)
	func annual(sim):
		var begin=Time.get_ticks_usec(); super.annual(sim); measured("annual",begin)
	func kill_key(sim,key:String,cause:String="Died in the community")->Dictionary:
		var begin=Time.get_ticks_usec(); var result=super.kill_key(sim,key,cause); measured("kill_key",begin); return result

class MeasuredSimulation extends "res://scripts/simulation.gd":
	var timings = {}
	var calls = {}
	func measured(key:String,begin:int):
		timings[key]=int(timings.get(key,0))+Time.get_ticks_usec()-begin
		calls[key]=int(calls.get(key,0))+1
	func _settlement_year(town:Dictionary,yield_callback:Callable=Callable()):
		var begin=Time.get_ticks_usec()
		await super._settlement_year(town,yield_callback)
		measured("settlement_year",begin)
	func _trade_and_diffusion():
		var begin=Time.get_ticks_usec()
		super._trade_and_diffusion()
		measured("trade_and_diffusion",begin)
	func _people_year():
		var begin=Time.get_ticks_usec()
		super._people_year()
		measured("people_year",begin)
	func _conflict_year():
		var begin=Time.get_ticks_usec()
		super._conflict_year()
		measured("conflict_year",begin)
	func refresh_totals():
		var begin=Time.get_ticks_usec()
		super.refresh_totals()
		measured("refresh_totals",begin)

class MeasuredSociety extends "res://scripts/life_society.gd":
	var timings={}
	func form_families(sim,town,keys,initial=false,yield_callback:Callable=Callable()):
		var begin=Time.get_ticks_usec()
		if yield_callback.is_valid(): await super.form_families(sim,town,keys,initial,yield_callback)
		else: super.form_families(sim,town,keys,initial)
		timings.families=int(timings.get("families",0))+Time.get_ticks_usec()-begin
		return true
	func annual(sim,yield_callback:Callable=Callable()):
		var begin=Time.get_ticks_usec(); var result=await super.annual(sim,yield_callback)
		timings.annual=int(timings.get("annual",0))+Time.get_ticks_usec()-begin
		return result
	func parents_for_birth(sim,town,location="surface",limit:int=-1)->Array:
		var begin=Time.get_ticks_usec(); var result=super.parents_for_birth(sim,town,location,limit)
		timings.births=int(timings.get("births",0))+Time.get_ticks_usec()-begin
		return result
	func work_person(sim,town,key)->Dictionary:
		var begin=Time.get_ticks_usec(); var result=super.work_person(sim,town,key)
		timings.work_person=int(timings.get("work_person",0))+Time.get_ticks_usec()-begin
		return result

func _initialize(): call_deferred("run")

func run():
	var sim=MeasuredSimulation.new()
	sim.new_world({"seed":"Individual actions integration","width":64,"height":48,"nations":3,"difficulty":"gentle"})
	var registry=MeasuredRegistry.new()
	sim._citizens=registry
	if "--checkpoint" in OS.get_cmdline_user_args():
		var path="res://test-output/endurance-world"
		var meta=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
		if FileAccess.get_sha256(path+".gz")!=meta.sha256: push_error("Checkpoint is changing; retry after its writer finishes."); quit(1); return
		var data=JSON.parse_string(FileAccess.get_file_as_bytes(path+".gz").decompress(int(meta.bytes),FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
		sim.restore(data); data.clear()
		sim._citizens=registry; registry.initialize(sim)
		var society=MeasuredSociety.new(); sim._society=society; society.initialize(sim)
		sim.timings.clear(); sim.calls.clear(); registry.timings.clear(); registry.calls.clear(); society.timings.clear()
		var begin=Time.get_ticks_msec(); sim.step(3)
		print("PROFILE year %d: total %.3fs"%[sim.state.year,float(Time.get_ticks_msec()-begin)/1000.0])
		for name_ in sim.timings: print("sim.%s %.3fs"%[name_,float(sim.timings[name_])/1000000])
		for name_ in registry.timings: print("registry.%s %.3fs / %d calls"%[name_,float(registry.timings[name_])/1000000,registry.calls[name_]])
		for name_ in society.timings: print("society.%s %.3fs"%[name_,float(society.timings[name_])/1000000])
		quit(); return
	if "--society" in OS.get_cmdline_user_args():
		var society=MeasuredSociety.new(); sim._society=society
		for town in sim.state.settlements: town.population=4000.0; town.food=100000.0; town.era=10
		sim.refresh_totals(); sim.state.society.initialized=false; society.initialize(sim)
		sim.timings.clear(); sim.calls.clear(); registry.timings.clear(); registry.calls.clear(); society.timings.clear()
		sim.step(5)
		for name_ in sim.timings: print("sim.%s %.3fs"%[name_,float(sim.timings[name_])/1000000])
		for name_ in registry.timings: print("registry.%s %.3fs / %d calls"%[name_,float(registry.timings[name_])/1000000,registry.calls[name_]])
		for name_ in society.timings: print("society.%s %.3fs"%[name_,float(society.timings[name_])/1000000])
		quit(); return
	var key=str(sim.resident_page(int(sim.state.settlements[0].id),0,1).people[0].key)
	var powers=load("res://scripts/powers.gd").new()
	powers.apply_to_person(sim,"bless_person",key,"god")
	var started=Time.get_ticks_msec()
	for i in range(4):
		sim.step(100)
		print("Profile year %d: %.0f people, elapsed%.2fs"%[sim.state.year,sim.state.stats.population,(Time.get_ticks_msec()-started)/1000.0])
		for name_ in sim.timings: print("  sim.%s: %.3fs / %dcalls"%[name_,sim.timings[name_]/1000000.0,sim.calls[name_]])
		for name_ in registry.timings: print("  registry.%s: %.3fs / %dcalls"%[name_,registry.timings[name_]/1000000.0,registry.calls[name_]])
	quit()
