extends SceneTree
const Saves=preload("res://scripts/save_manager.gd")
var app
var failures=0
var checks=0
func _init(): call_deferred("run")
func settle():
	for i in range(6): await process_frame
func check(value,text_):
	checks+=1
	if not value: failures+=1; push_error(text_)
func descendants(node):
	var result=[]
	for child in node.get_children(): result.append(child); result.append_array(descendants(child))
	return result
func capture(label):
	await settle()
	var rect=app.modal_panel.get_global_rect()
	check(rect.position.x>=0 and rect.end.x<=root.size.x+1,"Society sheet fits horizontally: "+label)
	for node in descendants(app.modal_body):
		if node is Button and node.is_visible_in_tree(): check(node.size.y>=48,"Society button has a touch target: "+label)
	if "--screenshots" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/society-%dx%d-%s.png"%[root.size.x,root.size.y,label])
func run():
	Saves.storage_directory="res://test-output/society-ui-saves"
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle(); app._close_modal()
	app.settings.autosave=false; app.settings.ambient=false; app._stop_audio()
	app.tutorial_active=false; app.game_started=true; app.paused=true
	app.sim.new_world({"seed":"Households of Eden","width":80,"height":55,"nations":3})
	var town=app.sim.state.settlements[0]
	var ruler=app.sim.get_individual("p:%d"%int(town.leader))
	app.sim._society.adjust(app.sim,ruler.key,{"honor":1})
	var key="c:%d"%int(app.sim.state.citizens.next_id)
	town.population+=1; app.sim._citizens.add(app.sim,int(town.id),1)
	app.sim._society.link_child(app.sim,key,[ruler.key])
	app.sim._society.edit_life(app.sim,key).illness="Fever"; app.sim._society.edit_life(app.sim,key).sick_until=8
	app.sim._society.civic.offer_family_promise(app.sim,app.sim._society,town,app.sim.get_individual(key))
	app.sim._society.civic.pass_law(app.sim,app.sim._society,town,ruler,"schools","The ruler founded public schools after listening to families.")
	for dimensions in [Vector2i(1366,768),Vector2i(844,390),Vector2i(390,844)]:
		root.size=dimensions; await settle(); app._responsive_layout()
		app._close_modal(); app._select_power("inspect"); app.world.focus_person(ruler.key)
		app._on_person_clicked(ruler.key)
		check(is_instance_valid(app.modal),"Clicking a person opens their profile")
		app.community._select_person_tab("Stats",ruler.key); await capture("profile")
		check(descendants(app.modal_body).filter(func(n):return n is ProgressBar).size()==15,"The profile contains the full stat chart")
		app.community._select_person_tab("Family",ruler.key); await capture("family")
		app.community._select_person_tab("Influence",ruler.key); await capture("care")
		app.community._select_action_group("Politics",ruler.key); await capture("politics")
		app.community.preview_action("promise_mercy",ruler.key); await capture("bargain")
		app.community.show_society(int(town.id)); await capture("society")
		app._close_modal()
	# Exercise the actual tray -> directory -> row -> preview -> cast callbacks.
	app.selected_person_key=""
	app.shell.power_ui.choose_power("curse"); await settle()
	app._on_tile_clicked(town.x,town.y,MOUSE_BUTTON_LEFT); await settle()
	check(app.modal_title.text=="Residents" and app.community.pending_action=="curse_person","A personal toolbar power first asks for its target")
	var rows=descendants(app.community.results).filter(func(node):return node is Button and node.has_meta("content_row"))
	check(not rows.is_empty(),"The target directory contains selectable people")
	if not rows.is_empty():
		rows[0].pressed.emit(); await settle()
		var target=app.selected_person_key
		check(app.community.selected_action=="curse_person" and app.community.pending_action.is_empty(),"Choosing a resident opens the queued personal intervention")
		var casts=descendants(app.modal_body).filter(func(node):return node is Button and node.text.begins_with("Cast on "))
		check(casts.size()==1 and not casts[0].disabled,"The preview exposes one usable Cast button")
		if casts.size()==1:
			casts[0].pressed.emit(); await settle()
			check(app.sim.get_individual(target).cursed,"The actual Cast callback curses the chosen person")
			var untouched=key if target!=key else ruler.key
			check(not app.sim.get_individual(untouched).cursed,"The cast does not curse the rest of the settlement")
	app._close_modal(); app.selected_person_key=""
	app.shell.power_ui.choose_power("heal"); await settle(); app.shell.power_ui.cancel()
	app._on_person_clicked(ruler.key); await settle()
	check(app.modal_title.text=="Resident" and app.community.pending_action.is_empty(),"Canceling a targeting tray prevents a stale intervention on the next person")
	app._close_modal()
	app._stop_audio(); app.queue_free(); await process_frame
	print("Society UI: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
