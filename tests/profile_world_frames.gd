extends SceneTree
class MeasuredView extends "res://scripts/world_view.gd":
	var draw_us=[]
	var terrain_us=[]
	func _draw():
		var begin=Time.get_ticks_usec(); super._draw(); draw_us.append(Time.get_ticks_usec()-begin)
	func _rebuild_terrain():
		var begin=Time.get_ticks_usec(); super._rebuild_terrain(); terrain_us.append(Time.get_ticks_usec()-begin)
func _init(): run.call_deferred()
func run():
	var sim=load("res://scripts/simulation.gd").new(); sim.new_world({"seed":"12000 rendering","width":160,"height":100,"nations":5,"difficulty":"gentle"})
	for town in sim.state.settlements: town.population=2400; town.food=100000; town.era=10
	sim.refresh_totals(); sim._society.initialize(sim)
	var view=MeasuredView.new(); root.add_child(view); view.size=Vector2(800,600); view.sim=sim
	for i in range(5): await process_frame
	view.draw_us.clear(); view.terrain_us.clear()
	for year in range(5):
		sim.step(1)
		for i in range(6): await process_frame
	view.draw_us.sort()
	print("FRAME PROFILE population=%d draw_median=%.2fms draw_max=%.2fms terrain_refreshes=%d terrain_max=%.2fms"%[sim.state.stats.population,float(view.draw_us[view.draw_us.size()/2])/1000,float(view.draw_us[-1])/1000,view.terrain_us.size(),float(view.terrain_us.max() if not view.terrain_us.is_empty() else 0)/1000])
	view.queue_free(); await process_frame; quit()
