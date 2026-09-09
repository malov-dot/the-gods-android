extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
class FullHouseholdSearch extends "res://scripts/life_society.gd":
	func parents_for_birth(sim,town,location="surface",_limit:int=-1)->Array:
		return super.parents_for_birth(sim,town,location)
var checks=0
var failures=0
var started=0
var slices=[]
var frames=0
func _init(): call_deferred("run")
func check(ok,label):
	checks+=1
	if not ok: failures+=1; push_error("POPULATION PERFORMANCE: "+label)
func pump()->bool:
	var elapsed=Time.get_ticks_usec()-started
	if elapsed>25000 and "--trace" in OS.get_cmdline_user_args(): print("LONG SLICE ",elapsed/1000.0,"ms ",get_stack())
	if elapsed>=8000:
		slices.append(elapsed/1000.0)
		frames+=1
		await process_frame
		started=Time.get_ticks_usec()
	return true
func fixture(population):
	var sim=Sim.new()
	sim.new_world({"seed":"Large world algorithm equivalence","width":64,"height":48,"nations":3,"difficulty":"gentle"})
	for town in sim.state.settlements:
		town.population=float(population)/3; town.food=100000.0; town.era=10
	sim.refresh_totals(); sim.state.society.initialized=false; sim._society.initialize(sim)
	return sim
func run():
	for population in [12000,20000]:
		var sim=fixture(population)
		var reference=Sim.new(); reference.restore(sim.state.duplicate(true))
		reference._society=FullHouseholdSearch.new(); reference._society.initialize(reference)
		for town in sim.state.settlements:
			var full=sim._society.parents_for_birth(sim,town)
			check(sim._society.parents_for_birth(sim,town,"surface",0).is_empty(),"Zero births avoids searching households")
			check(sim._society.parents_for_birth(sim,town,"surface",3)==full.slice(0,3),"Bounded search returns exactly the same first families")
		reference.step(6)
		slices.clear(); frames=0; started=Time.get_ticks_usec()
		await sim.step(6,pump)
		slices.append((Time.get_ticks_usec()-started)/1000.0)
		check(JSON.stringify(sim.state)==JSON.stringify(reference.state),"%d residents retain exact simulation outcomes and RNG after six years"%population)
		check(frames>6,"Large worlds release the main thread throughout each year")
		slices.sort()
		print("POPULATION %d: %d yielded frames, work slice median %.2fms, p95 %.2fms, maximum %.2fms"%[population,frames,slices[slices.size()/2],slices[int((slices.size()-1)*0.95)],slices[-1]])
		check(slices[-1]<50,"No simulation work slice blocks the main thread for 50ms on this host")
	print("POPULATION PERFORMANCE: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
