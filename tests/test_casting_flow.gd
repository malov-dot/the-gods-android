extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Saves=preload("res://scripts/save_manager.gd")
var app
var checks=0
var failures=0
class BusyClock extends "res://scripts/simulation.gd":
	func step(years:int=1,_yield_callback:Callable=Callable()):
		for i in range(3): await Engine.get_main_loop().process_frame
		state.year+=years
func _init(): run.call_deferred()
func check(value,label):
	checks+=1
	if not value: failures+=1;push_error("CASTING: "+label)
func settle():
	for i in range(6): await process_frame
func nodes(node):
	var result=[node]
	for child in node.get_children(): result.append_array(nodes(child))
	return result
func click(point,touch=false):
	for down in [true,false]:
		var event
		if touch:
			event=InputEventScreenTouch.new();event.index=0
		else:
			event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
			event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position=point;event.pressed=down;root.push_input(event,true)
		await process_frame
	await settle()
func choose(group,id,touch=false):
	var button=app.shell.category_buttons.filter(func(b):return b.id==group)[0].button
	await click(button.get_global_rect().get_center(),touch)
	check(app.shell.power_ui.palette.visible,"Category opens immediately while a year is busy")
	var power=app.shell.power_ui.ability_buttons.filter(func(b):return b.id==id)[0].button
	await click(power.get_global_rect().get_center(),touch)
	check(app.selected_power==id and not app.shell.power_ui.palette.visible,"Chosen power is armed immediately: "+id)
func capture(name_):
	if DisplayServer.get_name()=="headless" or not "--screenshots" in OS.get_cmdline_user_args(): return
	await create_timer(0.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/casting-"+name_+".png")
func run():
	Saves.storage_directory="res://test-output/casting-saves"
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await settle()
	app.settings.autosave=false;app.settings.ambient=false;app.settings.voices=false;app._stop_audio()
	app._close_modal();app.set_process(false);app.game_started=true;app.paused=true
	root.size=Vector2i(1440,900);await settle();app._responsive_layout()
	var sim=Sim.new();sim.new_world({"seed":"Casting flow","width":64,"height":48,"nations":2})
	app.sim=sim;app.world.sim=sim;app.world.frame_world();app._refresh_ui(true)
	var town=sim.state.settlements[0];app.world.center_on_tile(town.x,town.y);await settle()
	var target=app.world._camera+(Vector2(town.x,town.y)+Vector2.ONE*0.5)*app.world.TILE*app.world.zoom
	# Use the actual category buttons, ability buttons and map GUI input.
	app.simulation_busy=true
	for pair in [["god","rain"],["devil","cult"],["disaster","fire"]]:
		await choose(pair[0],pair[1])
		await click(target)
	check(app.pending_casts.size()==3,"Rapid casts are retained instead of silently discarded")
	check(sim.state.get("powers_used",0)==0,"A cast never mutates the middle of an unfinished year")
	check(app.world.cast_feedback.size()==3,"Each queued click immediately has a visible acknowledgement")
	app._select_power("inspect");app.simulation_busy=false
	for i in range(3): app._process(0)
	check(sim.state.powers_used==3 and sim.state.effects.slice(-3).map(func(e):return e.type)==["rain","cult","fire"],"Each queued cast retains its original power after selection changes")
	check(town.cult>0 and town.visual_damage>0,"God, Devil and disaster casts change the actual world")
	var snapshot=JSON.stringify(sim.state)
	sim.state.year+=100
	check(app.world.cast_feedback.size()==3,"Accelerated years cannot erase impact feedback")
	app.world._process(4.1)
	check(app.world.cast_feedback.is_empty(),"Impact feedback expires in real seconds and remains bounded")
	sim.restore(JSON.parse_string(snapshot))
	# Native touch has the same area targeting, and ocean impacts work.
	await choose("disaster","meteor",true)
	var water=Vector2i(32,24);sim.get_tile(water.x,water.y).elevation=0.25
	app.world.center_on_tile(water.x,water.y);await settle()
	target=app.world._camera+(Vector2(water)+Vector2.ONE*0.5)*app.world.TILE*app.world.zoom
	await click(target,true)
	check(sim.get_tile(water.x,water.y).elevation<0.25 and sim.state.effects[-1].type=="meteor","Touching the ocean starts an actual meteor impact")
	await capture("meteor-desktop")
	# Healing/curses choose one identity on the map or through a community.
	app.world.center_on_tile(town.x,town.y);await settle()
	await choose("devil","curse")
	check(not is_instance_valid(app.modal) and app.world.active_power=="inspect","A personal shortcut arms map selection, without an unsolicited directory")
	app._on_tile_clicked(town.x,town.y,MOUSE_BUTTON_LEFT);await settle()
	check(app.modal_title.text=="Residents" and app.community.pending_action=="curse_person","Touching a community offers its individual residents")
	var key=sim.get_individual("p:%d"%int(town.leader)).key
	app.community.show_person(key);await settle()
	var cast=nodes(app.modal_body).filter(func(n):return n is Button and n.text.begins_with("Cast on "))[0]
	app.modal_scroll.ensure_control_visible(cast);await settle();await click(cast.get_global_rect().get_center())
	check(sim.get_individual(key).cursed and app.world.selected_person_key==key,"Influence curses the named person and focuses that person on the map")
	check(app.paused and app.modal_title.text=="The consequence","Time stays paused for a compact, readable outcome")
	check(app.world.cast_feedback.any(func(e):return e.person==key and e.id=="curse_person"),"The actual person receives an animated, named visual cue")
	await capture("person-desktop")
	app._close_modal();check(app.paused,"Closing the outcome does not skip past the visible consequence")
	app.world.set_zoom(8);await settle();await capture("person-closeup")
	app.simulation_busy=true;app.shell.power_ui.choose_power("fire")
	app._on_tile_clicked(town.x,town.y,MOUSE_BUTTON_LEFT)
	await click(app.shell.observe_button.get_global_rect().get_center())
	check(app.pending_casts.is_empty() and app.selected_power=="inspect","Observe cancels queued casting immediately during a busy year")
	check(not app.world.cast_feedback.any(func(e):return e.queued),"Canceled powers lose their waiting markers")
	app.shell.power_ui.choose_power("rain");app._on_tile_clicked(town.x,town.y,MOUSE_BUTTON_LEFT)
	var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE
	root.push_input(escape,true);await settle()
	check(app.pending_casts.is_empty(),"Desktop Escape cancels a pending cast without waiting")
	app.simulation_busy=false
	# Artificial three-frame yearly work isolates scheduler behavior from hardware.
	var counts=[]
	for rate in [1,5,20,100]:
		var clock=BusyClock.new();clock.new_world({"seed":"Clock","width":64,"height":48,"nations":2})
		app.sim=clock;app.world.sim=clock;app._set_speed(rate)
		for i in range(180): app._process(1.0/60);await process_frame
		app.paused=true
		while app.simulation_busy: await process_frame
		counts.append(clock.state.year)
	check(counts[0]>=2 and counts[0]<=3,"1x advances about three years in three seconds")
	check(counts[1]>=14 and counts[1]<=15,"5x retains time spent completing yearly work")
	check(counts[2]>counts[1] and counts[3]>=counts[2],"Faster choices advance faster until the work budget is full")
	print("PACING 3 seconds at 1/5/20/100x: ",counts)
	app.pending_casts.clear();app._stop_audio();app.queue_free();await settle()
	print("CASTING FLOW: %d checks; %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
