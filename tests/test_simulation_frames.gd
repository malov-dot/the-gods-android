extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Saves=preload("res://scripts/save_manager.gd")
var checks=0
var failures=0
var yielded=0
func _init(): call_deferred("run")
func check(value,label):
	checks+=1
	if not value: failures+=1; push_error("FRAME BUDGET: "+label)
func pump()->bool:
	yielded+=1
	await process_frame
	return true
func replacement(sim)->bool:
	await process_frame
	sim.new_world({"seed":"Replacement world","width":64,"height":48,"nations":2})
	return true
func run():
	var config={"seed":"Responsive generations","width":64,"height":48,"nations":2}
	var synchronous=Simulation.new(); synchronous.new_world(config)
	var framed=Simulation.new(); framed.new_world(config)
	synchronous.step(40)
	await framed.step(40,pump)
	check(yielded>80,"Long simulation yields to real frames throughout the work")
	check(JSON.stringify(synchronous.state)==JSON.stringify(framed.state),"Frame budgeting preserves the exact world, families, events and RNG over forty years")
	await framed.step(10,replacement.bind(framed))
	var fresh=Simulation.new(); fresh.new_world({"seed":"Replacement world","width":64,"height":48,"nations":2})
	check(JSON.stringify(framed.state)==JSON.stringify(fresh.state),"Replacing the world cancels suspended work without modifying the new world")
	Saves.storage_directory="res://test-output/frame-budget-saves"
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	for i in range(6): await process_frame
	app._close_modal(); app.settings.autosave=false; app.settings.ambient=false; app._stop_audio()
	app.tutorial_active=false; app.game_started=true; app.paused=true
	app.sim.new_world(config)
	for town in app.sim.state.settlements: town.population=3000.0; town.food=100000.0
	app.sim.refresh_totals()
	var person=app.sim.resident_page(int(app.sim.state.settlements[0].id),0,1).people[0]
	app._advance_world()
	check(app.simulation_busy,"Large-year work remains pending across frames")
	app.paused=false
	app._on_person_clicked(person.key)
	check(not is_instance_valid(app.modal),"Inspection waits for the current year to finish")
	for i in range(10000):
		if not app.simulation_busy: break
		await process_frame
	for i in range(3): await process_frame
	check(not app.simulation_busy and app.sim.state.year==1,"A queued inspection completes one year without racing another tick")
	check(is_instance_valid(app.modal) and app.selected_person_key==person.key,"The queued inspection opens the intended person's profile")
	app._close_modal()
	check(not app.paused,"Closing the deferred profile restores the original playing state")
	app.paused=true
	app._advance_world()
	app._on_person_clicked(person.key)
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not app.deferred_world_action.is_valid(),"Android Back cancels a queued action immediately")
	for i in range(10000):
		if not app.simulation_busy: break
		await process_frame
	for i in range(3): await process_frame
	check(not is_instance_valid(app.modal),"Canceled requests are not applied at the end of the year")
	app._advance_world()
	app._on_person_clicked(person.key)
	app.sim.new_world({"seed":"Replacement world","width":64,"height":48,"nations":2})
	for i in range(20): await process_frame
	check(not app.simulation_busy and not app.deferred_world_action.is_valid(),"Replacing a busy world drops actions that belonged to its old residents")
	check(JSON.stringify(app.sim.state)==JSON.stringify(fresh.state),"Canceled UI work preserves the fresh world exactly")
	app._stop_audio(); app.queue_free(); await process_frame
	print("Simulation frames: %d checks, %d failures; %d cooperative frame yields"%[checks,failures,yielded])
	quit(0 if failures==0 else 1)
