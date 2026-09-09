extends SceneTree

const Saves=preload("res://scripts/save_manager.gd")
var app
var failures=0
var checks=0
var capture=false

func _initialize():
	call_deferred("run")

func check(value:bool,message:String):
	checks+=1
	if not value:
		failures+=1
		push_error("UI CHECK: "+message)

func settle():
	await process_frame
	await process_frame
	await process_frame

func shot(name_:String):
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var err=root.get_texture().get_image().save_png("res://test-output/"+name_+".png")
	check(err==OK,"Captured "+name_)

func run():
	capture="--screenshots" in OS.get_cmdline_user_args()
	Saves.storage_directory="res://test-output/ui-saves"
	DirAccess.make_dir_recursive_absolute("res://test-output")
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(is_instance_valid(app.modal),"Startup offers full new-world configuration")
	await shot("menu")
	app.new_seed.text="UI acceptance"
	app.new_size.select(0)
	app._start_world()
	await settle()
	# Narrow headless windows show the introduction as a sheet; dismiss it as a player would.
	if is_instance_valid(app.modal): app._close_modal()
	check(app.game_started and app.sim.state.width==128,"Start applies map size and enters game")
	check(app.sim.state.seed=="UI acceptance","Start uses selected seed")
	check(app.current_slot==-1,"A new world does not silently overwrite a manual slot")
	var city=app.sim.state.settlements[0]
	app._on_tile_clicked(city.x,city.y,MOUSE_BUTTON_LEFT)
	check(app.selected_id==city.id,"Map click selects settlement")
	if is_instance_valid(app.modal): app._close_modal()
	app._set_category("divine")
	var target=app.sim.get_individual("p:%d"%int(city.leader))
	app.selected_person_key=target.key
	app._select_power("heal")
	app._on_person_clicked(target.key)
	check(is_instance_valid(app.modal) and app.selected_power=="heal","Armed healing opens a preview for the clicked person")
	app.sim._society.edit_life(app.sim,target.key).illness="Fever"
	app.sim._society.edit_life(app.sim,target.key).sick_until=10
	app.community.commit_action("heal_person",target.key,"god")
	check(app.sim.get_individual(target.key).illness.is_empty(),"UI healing cures the selected person's illness")
	app._close_modal()
	app._set_category("infernal")
	app._select_power("possess")
	app.community.commit_action("possess_person",target.key,"devil")
	check(app.sim.get_individual(target.key).possessed,"UI possession changes the selected person")
	app._close_modal()
	app._select_power("inspect")
	for overlay in ["terrain","nations","belief","fertility","technology"]:
		app.world.overlay=overlay
		app.world.invalidate_terrain()
		await settle()
		check(app.world.overlay==overlay,"Overlay switches to "+overlay)
	app.world.overlay="belief"
	app.world.invalidate_terrain()
	app.world.center_on_tile(city.x,city.y)
	await settle()
	await shot("belief")
	app._quick_save()
	check(is_instance_valid(app.modal),"First quick-save opens a slot picker")
	app._perform_save(0)
	check(app.current_slot==0,"Saving chooses current slot")
	check(Saves.load_game(0).get("ok",false),"Saved game validates")
	app.sim.step(8)
	app._load_slot(0)
	check(app.sim.state.year==0,"Loading restores year and all state")
	check(app.paused,"Loading pauses the world")
	app._set_speed(5)
	app._process(0.3)
	check(app.sim.state.year>=1,"Speed controls advance simulation")
	app.paused=true
	app._show_save()
	await settle()
	await shot("saves")
	app._save_slot(0)
	check(app.modal_title.text=="Replace saved world?","Overwriting occupied save requires explicit choice")
	app._close_modal()
	for method in ["_show_history","_show_atlas","_show_technology","_show_doctrines","_show_guide","_show_settings","_show_load"]:
		app.call(method)
		await settle()
		check(is_instance_valid(app.modal) and app.modal_body.get_child_count()>0,"Functional modal "+method)
		var panel=app.modal.get_child(1).get_child(0)
		check(panel.get_global_rect().position.x>=-1 and panel.get_global_rect().end.x<=root.get_visible_rect().size.x+1,"Modal horizontally fits: "+method)
		if method=="_show_guide":
			await shot("guide")
		app._close_modal()
	app._show_event(app.sim.state.events[-1])
	await settle()
	check(app.modal_body.get_child_count()>=5,"Event inspector includes causes")
	await shot("event")
	app._close_modal()
	city=app.sim.state.settlements[0]
	city.population=0
	city.orbital_population=100
	app._inspect_city(city.id)
	check(app.selected_id==city.id,"Orbital-only settlements remain inspectable")
	app._show_new_world()
	app.new_size.select(0)
	app._start_world()
	check(app.sim.state.mode=="sandbox","New games are single-player sandbox")
	check(not app.has_method("_end_turn"),"No turn handoff exists")
	app.settings.ambient=false
	app.settings.effects=false
	app.settings.volume=0.25
	check(Saves.save_settings(app.settings).ok,"UI settings save")
	var prefs=Saves.load_settings()
	check(prefs.ambient==false and prefs.effects==false and is_equal_approx(prefs.volume,0.25),"UI settings roundtrip")
	app._stop_audio()
	# Allow the separate audio mixer to release stopped playback before exit.
	await create_timer(0.12).timeout
	app.queue_free()
	await process_frame
	print("UI ACCEPTANCE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
