extends SceneTree

const Saves=preload("res://scripts/save_manager.gd")
var app
var checks=0
var failures=0
var screenshots=false

func _initialize(): call_deferred("run")
func check(value,message):
	checks+=1
	if not value:
		failures+=1
		push_error("MOBILE UI: "+message)
func settle():
	for i in range(5): await process_frame
func shot(name_):
	if not screenshots: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://test-output/"+name_+".png")==OK,"Captured "+name_)
func modal_fits(label_):
	var rect=app.modal_panel.get_global_rect()
	var size_=root.get_visible_rect().size
	check(rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=size_.x+1 and rect.end.y<=size_.y+1,label_+" fits "+str(size_)+" actual="+str(rect))
	check(app.modal_scroll.size.y>=60,label_+" has a usable scroll area")

func visible_text(node):
	var result=""
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button): result=str(node.text)
	for child in node.get_children(): result+=" "+visible_text(child)
	return result

func run():
	screenshots="--screenshots" in OS.get_cmdline_user_args()
	Saves.storage_directory="res://test-output/mobile-saves"
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app._close_modal()
	app.settings.show_tutorial=false
	app.settings.autosave=false
	app.paused=true
	check(app.sim.has_method("resident_page"),"Every-person directory API is required")
	for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(1440,900)]:
		root.size=dimensions
		await settle()
		app._responsive_layout()
		await settle()
		check(app.compact_ui==(dimensions.x<1100),"Responsive breakpoint")
		if app.compact_ui:
			app._start_tutorial()
			await settle()
			modal_fits("Default mobile introduction")
			check(not app.tutorial_panel.visible,"Introduction does not crowd the mobile map")
			app._close_modal()
			app.tutorial_active=false
		var rect=app.world.get_global_rect()
		check(rect.position.distance_to(Vector2.ZERO)<1 and rect.size.distance_to(root.get_visible_rect().size)<2,"World fills the viewport behind HUD overlays")
		for entry in app.shell.category_buttons: check(entry.button.size.x>=48 and entry.button.size.y>=48,"Touch category target "+entry.label)
		app.selected_id=app.sim.state.settlements[0].id
		app._street_view()
		await settle()
		await shot("responsive-world-"+str(dimensions.x))
		app._show_powers()
		await settle()
		check(app.shell.power_ui.palette.is_visible_in_tree() and not is_instance_valid(app.modal),"Powers open a contextual tray without blocking the map")
		var palette_rect=app.shell.power_ui.palette.get_global_rect()
		check(palette_rect.position.x>=-1 and palette_rect.position.y>=-1 and palette_rect.end.x<=dimensions.x+1 and palette_rect.end.y<=dimensions.y+1,"Ability tray fits viewport")
		app.shell.power_ui.close_palette()
		for method in ["_show_new_world","_show_menu","_show_map_options","_show_guide","_show_settings","_show_atlas","_show_save","_show_load","_show_doctrines","_show_technology"]:
			app.call(method)
			await settle()
			modal_fits(method)
			if dimensions.x==390 and method in ["_show_new_world","_show_menu"]: await shot("responsive"+method)
			app._close_modal()
		app._explain_power("fire")
		await settle()
		modal_fits("Power explanation")
		check("fire" in visible_text(app.modal_panel).to_lower() or "burn" in visible_text(app.modal_panel).to_lower(),"Power explanation describes the actual ability")
		app._select_power("fire")
		app._close_modal()
		check(app.active_banner.visible and app.selected_power=="fire" and app.world.active_power=="fire","Active intervention remains armed on the world")
		check(not app.shell.power_ui.cost_label.text.is_empty() and not app.shell.power_ui.radius_label.text.is_empty(),"Active intervention exposes targeting instructions and radius")
		app._select_power("inspect")
		if app.sim.has_method("resident_page"):
			app._show_people()
			await settle()
			modal_fits("Every-person directory")
			await shot("responsive-people-"+str(dimensions.x))
			var town=app.sim.state.settlements[0]
			var page=app.sim.resident_page(town.id,0,12,"")
			check(page.total>20 and page.people.size()==12,"Directory is paginated, not limited to displayed sprites")
			var person=page.people[0]
			app.community.show_person(person.key)
			await settle()
			modal_fits("Personal profile")
			await shot("responsive-profile-"+str(dimensions.x))
			app.community.preview_action("inspire_person",person.key)
			await settle()
			modal_fits("Personal intervention preview")
			await shot("responsive-influence-"+str(dimensions.x))
			app.community.commit_action("inspire_person",person.key,"god")
			await settle()
			check(not app.community.last_result.is_empty(),"Personal action reports actual outcome")
			app.community.show_factions()
			await settle()
			modal_fits("Faction directory")
			app.community.show_faction(town.nation)
			await settle()
			modal_fits("Faction stats and leaders")
			await shot("responsive-realm-"+str(dimensions.x))
			app._close_modal()
	# Match a 390-CSS-pixel phone with a 3x physical pixel density.
	root.content_scale_factor=3.0
	root.size=Vector2i(1170,2532)
	await settle()
	app._responsive_layout()
	await settle()
	check(app.compact_ui and is_equal_approx(app.get_viewport_rect().size.x,390.0),"High-density phone keeps CSS-sized controls")
	app._show_people()
	await settle()
	modal_fits("High-density resident directory")
	app._close_modal()
	root.content_scale_factor=1.0
	app._stop_audio()
	# Allow the separate audio mixer to release stopped playback before exit.
	await create_timer(0.12).timeout
	app.queue_free()
	await process_frame
	print("MOBILE UI ACCEPTANCE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
