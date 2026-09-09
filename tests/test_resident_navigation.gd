extends SceneTree
const Saves=preload("res://scripts/save_manager.gd")
var app
var checks=0
var failures=0
func _init(): run.call_deferred()
func check(value,message):
	checks+=1
	if not value: failures+=1; push_error("RESIDENTS: "+message)
func settle():
	for i in range(6): await process_frame
func descendants(node):
	var result=[]
	for child in node.get_children(): result.append(child); result.append_array(descendants(child))
	return result
func rows(): return descendants(app.community.results).filter(func(n): return n is Button and n.has_meta("resident_key"))
func touch(point,pressed,canceled=false):
	var event=InputEventScreenTouch.new(); event.position=point; event.pressed=pressed; event.canceled=canceled; event.index=0
	root.push_input(event,true); await process_frame
func tap(button):
	var point=button.get_global_rect().get_center()
	await touch(point,true); await touch(point,false); await settle()
func swipe(button,scroll=null):
	if scroll==null: scroll=app.modal_scroll
	scroll.ensure_control_visible(button); await settle()
	var point=button.get_global_rect().intersection(scroll.get_global_rect()).get_center()
	await touch(point,true)
	for i in range(1,6):
		var event=InputEventScreenDrag.new(); event.index=0; event.position=point-Vector2(0,i*18); event.relative=Vector2(0,-18)
		root.push_input(event,true); await process_frame
	await touch(point-Vector2(0,90),false)
	await settle()
func capture(label_):
	if not "--screenshots" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	await create_timer(0.25).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/residents-"+label_+".png")
func run():
	Saves.storage_directory="res://test-output/resident-navigation-saves"
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle(); app._close_modal(); app.set_process(false)
	app.settings.autosave=false; app.settings.ambient=false; app._stop_audio()
	app.game_started=true; app.tutorial_active=false; app.paused=true
	app.sim.new_world({"seed":"People worth following","width":64,"height":48,"nations":3})
	var town=app.sim.state.settlements[0]
	var leader=app.sim.get_individual("p:%d"%int(town.leader))
	var other_town=app.sim.state.settlements[1]
	var other=app.sim.get_individual("p:%d"%int(other_town.leader))
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),"No mouse emulation masks touch behavior")
	for fixture in [
		{"name":"portrait","size":Vector2i(390,844),"scale":1.0},
		{"name":"landscape","size":Vector2i(844,390),"scale":1.0},
		{"name":"fold-cover","size":Vector2i(1248,1972),"scale":2.625},
		{"name":"fold-inner","size":Vector2i(2448,1848),"scale":2.625}]:
		root.content_scale_factor=fixture.scale; root.size=fixture.size; await settle(); app._responsive_layout()
		app.community.person_tab="Overview"; app.selected_person_key=""; app.community.resident_view="Community"; app.community.show_people(int(town.id)); await settle()
		var first=rows()[0]
		check(first.get_meta("leader") and first.get_meta("resident_key")==leader.key,"Current leader is first and labeled on "+fixture.name)
		check(app.modal_scroll.get_global_rect().has_point(first.get_global_rect().get_center()),"Leader is visible without scrolling on "+fixture.name)
		await capture(fixture.name)
		await swipe(first)
		check(app.modal_title.text=="Residents" and app.selected_person_key.is_empty(),"Swiping a resident does not select them")
		check(app.modal_scroll.scroll_vertical>50,"Native touch scrolls residents on "+fixture.name)
		app.modal_scroll.reset_scroll(); await settle()
		var star=first.get_parent().get_child(1)
		await swipe(star)
		check(app.sim.state.get("favorite_people",[]).is_empty(),"Swiping a star does not favorite a person")
		app.modal_scroll.reset_scroll(); await settle()
		await tap(star)
		check(leader.key in app.sim.state.get("favorite_people",[]),"Tapping a star favorites the correct person")
		check(star.button_pressed and star.get_meta("art").kind=="favorite","Favorite has visible selected state")
		await tap(star)
		check(app.sim.state.favorite_people.is_empty(),"Tapping again removes a favorite")
		await touch(first.get_global_rect().get_center(),true); await touch(first.get_global_rect().get_center(),false,true)
		check(app.modal_title.text=="Residents","Canceled touch cannot open a profile")
		await tap(first)
		check(app.modal_title.text=="Resident" and app.selected_person_key==leader.key,"Tap still opens profile after scrolling or canceling")
		var full_stats=descendants(app.modal_body).filter(func(n):return n is Button and n.text=="Show full stats & biography")[0]
		app.modal_scroll.ensure_control_visible(full_stats); await settle(); await tap(full_stats)
		var profile_star=descendants(app.modal_body).filter(func(n):return n is Button and n.has_meta("favorite_key"))[0]
		app.modal_scroll.ensure_control_visible(profile_star); await settle(); await tap(profile_star)
		check(leader.key in app.sim.state.favorite_people,"Profile offers working favorite control")
		await swipe(profile_star)
		check(leader.key in app.sim.state.favorite_people and app.modal_scroll.scroll_vertical>50,"Profile swipes scroll without toggling favorites")
		app.community._toggle_favorite(leader.key)
		app._close_modal()
	# A long community chooser scrolls independently above the resident sheet.
	app.community.show_people(int(town.id)); await settle()
	var chooser=app.modal_body.get_child(0)
	for i in range(20): chooser.add_item("Touch scrolling choice %d"%i,1000+i)
	await tap(chooser)
	var overlay_scroll=descendants(chooser.choices_layer).filter(func(n):return n is ScrollContainer)[0]
	var behind_scroll=app.modal_scroll.scroll_vertical
	await swipe(chooser.choice_buttons[0],overlay_scroll)
	check(is_instance_valid(chooser.choices_layer) and overlay_scroll.scroll_vertical>50,"Long choice sheets scroll without selecting an item")
	check(app.modal_scroll.scroll_vertical==behind_scroll,"Choice sheet swipe does not scroll the resident list behind it")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await settle()
	check(is_instance_valid(app.modal) and not is_instance_valid(chooser.choices_layer),"Back closes only the topmost choice sheet")
	app.modal_scroll.reset_scroll(); await settle()
	var wheel=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; wheel.position=app.modal_scroll.get_global_rect().get_center()
	root.push_input(wheel,true); await settle()
	check(app.modal_scroll.scroll_vertical>0,"PC mouse wheel scrolling remains available")
	# Both global views are based on permanent identities, across towns and saves.
	app.community.resident_view="Leaders"; app.community.show_people(int(town.id)); await settle()
	var page=app.community._resident_page()
	check(page.total==app.sim.state.settlements.size(),"Leaders view contains every community leader")
	check(rows().all(func(n):return n.get_meta("leader")),"Every leader row has an explicit leader label")
	app.community._toggle_favorite(leader.key); app.community._toggle_favorite(other.key)
	app.community._select_resident_view("Favorites"); await settle()
	check(app.community._resident_page().total==2,"Favorites include people from different towns")
	await capture("favorites")
	app.community.query=other.name; check(app.community._resident_page().total==1,"Favorites search finds a person by name")
	app.community.query=""
	var save=Saves.save_game(app.sim.state,0); check(save.ok,"Favorited world can be saved: "+save.message)
	var loaded=Saves.load_game(0); check(loaded.ok,"Favorited world can be loaded")
	if loaded.ok:
		app.sim.restore(loaded.state)
		check(app.sim.state.favorite_people==[leader.key,other.key],"Favorite identity and order survive real disk save/load")
	var malformed=app.sim.state.duplicate(true); malformed.favorite_people=[leader.key,leader.key]
	check(not Saves.validate_state(malformed).ok,"Duplicate favorites are rejected")
	malformed.favorite_people=["c:999999999"]
	check(not Saves.validate_state(malformed).ok,"Unknown favorite identities are rejected")
	check(app.sim.kill_individual(other.key,"A remembered life"),"Favorite can reach the end of their life")
	check(other.key in app.sim.state.favorite_people and not app.sim.get_individual(other.key).alive,"Deceased favorite retains name, identity and history")
	check(app.community._resident_page().total==2,"Deceased people remain available in Favorites")
	check(Saves.save_game(app.sim.state,0).ok,"A world with a deceased favorite remains saveable")
	app.community._toggle_favorite(other.key); await settle()
	check(app.community._resident_page().total==1 and rows().size()==1,"Removing a favorite updates the visible directory")
	app._close_modal(); app.sim.new_world({"seed":"A different world","width":64,"height":48,"nations":2})
	check(app.sim.state.get("favorite_people",[]).is_empty(),"New worlds start with their own empty favorites")
	app._stop_audio(); app.queue_free(); await process_frame
	print("RESIDENT NAVIGATION: %d checks; %d failures"%[checks,failures]); quit(0 if failures==0 else 1)
