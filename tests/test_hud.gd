extends SceneTree
## Structural and interaction acceptance for the game HUD, using actual control
## rectangles and viewport input. Storage is isolated from the player's saves.
const Saves = preload("res://scripts/save_manager.gd")
const RESOLUTIONS = [Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1366,768),Vector2i(844,390),Vector2i(390,844)]
const CATEGORY_EXAMPLES = {"terrain":"land","nature":"forest","life":"population","god":"bless","devil":"pact","disaster":"fire"}
var app
var checks = 0
var failures = 0
var screenshots = false
var tile_inputs = 0
var dimension_label = ""

func _initialize(): call_deferred("run")

func check(value, message):
	checks += 1
	if not value:
		failures += 1
		push_error("HUD ACCEPTANCE [%s]: %s" % [dimension_label,message])

func settle():
	for unused in range(6): await process_frame
	# A full hotseat round now yields between its ten simulated years.
	var deadline=Time.get_ticks_msec()+10000
	while is_instance_valid(app) and app.simulation_busy and app.sim.state.get("mode")=="hotseat" and Time.get_ticks_msec()<deadline:
		await process_frame
	for unused in range(6): await process_frame

func shot(state_name):
	if not screenshots: return
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://test-output/hud-%s-%s.png" % [dimension_label,state_name])==OK,"Captured "+state_name)

func fits(control, description):
	if not is_instance_valid(control): check(false,description+" exists"); return
	var rect=control.get_global_rect()
	var viewport=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	check(rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=viewport.end.x+1 and rect.end.y<=viewport.end.y+1,description+" fits viewport: "+str(rect))

func _union_area(rectangles):
	var xs=[]
	for rect in rectangles: xs.append(rect.position.x); xs.append(rect.end.x)
	xs.sort()
	var area=0.0
	for i in range(xs.size()-1):
		var width=float(xs[i+1])-float(xs[i])
		if width<=0.0001: continue
		var midpoint=(float(xs[i+1])+float(xs[i]))*0.5
		var intervals=[]
		for rect in rectangles:
			if rect.position.x<=midpoint and rect.end.x>=midpoint: intervals.append(Vector2(rect.position.y,rect.end.y))
		intervals.sort_custom(func(a,b):return a.x<b.x)
		var height=0.0
		var end=-INF
		for interval in intervals:
			if interval.x>end: height+=interval.y-interval.x
			elif interval.y>end: height+=interval.y-end
			end=maxf(end,interval.y)
		area+=width*height
	return area

func hud_rectangles():
	var result=[]
	var viewport=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	for control in app.shell.idle_occluders():
		if is_instance_valid(control) and control.is_visible_in_tree(): result.append(control.get_global_rect().intersection(viewport))
	return result

func descendants(node):
	var result=[]
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func visible_text(node):
	var result=""
	for child in [node]+descendants(node):
		if child is Control and child.is_visible_in_tree() and (child is Label or child is Button): result+=" "+str(child.text)
	return result

func check_targets(node, description):
	for child in [node]+descendants(node):
		if child is BaseButton and child.is_visible_in_tree():
			check(child.size.x>=47.5 and child.size.y>=47.5,"48-pixel "+description+" target: "+str(child.name)+" "+str(child.size))

func check_hud_text(node):
	for child in [node]+descendants(node):
		if not child is Label or not child.is_visible_in_tree() or str(child.text).is_empty(): continue
		# Explicit ellipsis is acceptable for contextual descriptions, while
		# untrimmed short HUD labels must actually have room to display.
		if child.text_overrun_behavior!=TextServer.OVERRUN_NO_TRIMMING or child.autowrap_mode!=TextServer.AUTOWRAP_OFF: continue
		var font=child.get_theme_font("font")
		var minimum=font.get_string_size(child.text,HORIZONTAL_ALIGNMENT_LEFT,-1,child.get_theme_font_size("font_size"))
		check(minimum.x<=child.size.x+2.0,"HUD text has horizontal room: "+str(child.text))
		check(child.get_line_height()<=child.size.y+2.0,"HUD text has vertical room: "+str(child.text))

func click_control(control):
	var point=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed=pressed
		event.position=point
		event.global_position=point
		root.push_input(event,true)
		await process_frame
	await settle()

func click_button_named(node, title):
	for child in [node]+descendants(node):
		if child is Button and child.is_visible_in_tree() and child.text==title:
			if is_instance_valid(app.modal_scroll) and app.modal_scroll.is_ancestor_of(child):
				app.modal_scroll.ensure_control_visible(child)
				await settle()
			await click_control(child)
			return
	check(false,"A visible button is available for "+title)

func modal_fits(description):
	check(is_instance_valid(app.modal),description+" opens only as requested")
	if not is_instance_valid(app.modal): return
	fits(app.modal_panel,description)
	check(app.modal_scroll.size.y>=60,description+" has usable scrolling")
	var rect=app.modal_panel.get_global_rect()
	var viewport=root.get_visible_rect().size
	if not app.modal_centered and app.shell.layout_mode=="portrait": check(absf(rect.end.y-(viewport.y-8))<=2,"Portrait details rise from a temporary bottom sheet")
	if not app.modal_centered and app.shell.layout_mode=="landscape": check(absf(rect.end.x-(viewport.x-8))<=2,"Landscape details use a temporary right sheet")
	check_targets(app.modal_panel,description)

func clear_selection():
	app._close_modal()
	app._select_power("inspect")
	app.selected_id=-1
	app.selected_person_key=""
	app.world.selected_id=-1
	app.world.selected_person_key=""
	app._refresh_ui(true)
	await settle()

func check_idle(dimensions):
	var world_rect=app.world.get_global_rect()
	var viewport=root.get_visible_rect().size
	check(world_rect.position.distance_to(Vector2.ZERO)<1 and world_rect.size.distance_to(viewport)<2,"The world fills the entire viewport")
	var expected="desktop" if dimensions.x>=1100 else ("landscape" if dimensions.x>dimensions.y else "portrait")
	check(app.shell.layout_mode==expected,"Layout transforms to "+expected)
	check(app.shell.category_buttons.size()==6,"Six primary power categories are always available")
	var centers=[]
	for entry in app.shell.category_buttons:
		check(entry.button.is_visible_in_tree(),"Category is visible: "+str(entry.id))
		fits(entry.button,"Category "+str(entry.id))
		check(entry.button.size.x>=47.5 and entry.button.size.y>=47.5,"Category has a 48-pixel target: "+str(entry.id))
		centers.append(entry.button.get_global_rect().get_center())
	if centers.size()==6:
		var xmin=INF
		var xmax=-INF
		var ymin=INF
		var ymax=-INF
		for point in centers: xmin=minf(xmin,point.x);xmax=maxf(xmax,point.x);ymin=minf(ymin,point.y);ymax=maxf(ymax,point.y)
		check((ymax-ymin>200 and xmax-xmin<4) if expected=="desktop" else (xmax-xmin>200 and ymax-ymin<4),"Desktop uses a vertical rail; phones use a horizontal tray")
		if expected!="desktop": check(ymin>viewport.y*0.65,"Phone categories stay in reach near the bottom")
	var regions=hud_rectangles()
	var obstruction=_union_area(regions)/maxf(1.0,viewport.x*viewport.y)
	check(obstruction<=0.251,"Idle HUD obstructs no more than 25%% of the world (%.1f%%)"%(obstruction*100))
	print("HUD ",dimension_label,": idle obstruction ",snappedf(obstruction*100,0.1),"%")
	check(not app.shell.selection_plaque.is_visible_in_tree(),"No selection means no permanent inspector")
	check(not app.shell.power_ui.palette.is_visible_in_tree(),"Idle gameplay does not show all abilities")
	check(not app.shell.power_ui.active_strip.is_visible_in_tree(),"Observe mode has no targeting strip")
	if is_instance_valid(app.inspector_box):check(not app.inspector_box.is_visible_in_tree(),"Legacy inspector is not a permanent column")
	if is_instance_valid(app.chronicle_box):check(not app.chronicle_box.is_visible_in_tree(),"Chronicle is available on request rather than as a permanent column")
	for region in app.shell.idle_occluders():
		if not is_instance_valid(region) or not region.is_visible_in_tree():continue
		fits(region,"Idle HUD region "+str(region.name))
		check_targets(region,"HUD")
		check_hud_text(region)
	check(app.pause_button.is_visible_in_tree(),"Pause remains immediately available")
	for stat in [app.population_label,app.age_label,app.faith_label,app.year_label]:
		check(stat.is_visible_in_tree() and not stat.text.is_empty(),"Population, era, allegiance and year remain visible")
	check(not is_instance_valid(app.modal),"Idle game has no blocking sheet")
	await shot("idle")

func check_power_flow():
	var power_ui=app.shell.power_ui
	for category in CATEGORY_EXAMPLES:
		for entry in app.shell.category_buttons:
			if entry.id==category:
				await click_control(entry.button)
				check(entry.button.button_pressed,"Open category has a visible selected state: "+str(category))
		await settle()
		check(power_ui.palette.is_visible_in_tree(),"Category opens its ability palette: "+str(category))
		check(not app.shell.observe_button.button_pressed,"An open category palette does not also highlight Observe")
		fits(power_ui.palette,"Ability palette "+str(category))
		var ids=[]
		for entry in power_ui.ability_buttons:
			ids.append(str(entry.id))
			check(entry.button.custom_minimum_size.y>=48 and entry.button.size.y>=47.5,"Ability has a touch-sized row: "+str(entry.id))
		check(CATEGORY_EXAMPLES[category] in ids,"Category includes its expected tool: "+str(category))
		check(ids.size()>0 and ids.size()<app.powers.CATALOG.size(),"Palette shows a category rather than every power")
		if category=="disaster":await shot("palette")
	# A selected tool closes its temporary palette and exposes its real options.
	for entry in power_ui.ability_buttons:
		if entry.id=="fire": await click_control(entry.button)
	await settle()
	check(app.selected_power=="fire" and app.world.active_power=="fire","Choosing a power arms actual world targeting")
	check(not power_ui.palette.is_visible_in_tree() and power_ui.active_strip.is_visible_in_tree(),"Targeting closes the palette and keeps a compact active strip")
	fits(power_ui.active_strip,"Active power strip")
	check_targets(power_ui.active_strip,"active tool")
	check(not power_ui.cost_label.text.is_empty(),"Targeting instructions remain visible")
	check(not power_ui.radius_label.text.is_empty(),"Actual brush radius remains visible")
	var radius=clampf(4,power_ui.radius_slider.min_value,power_ui.radius_slider.max_value)
	power_ui.radius_slider.value=radius
	await settle()
	check(app.world.brush_radius==int(radius),"Radius control changes the implemented world brush")
	check(str(int(radius)) in power_ui.radius_label.text,"Radius display follows the implemented value")
	await shot("active")
	await click_control(power_ui.help_button)
	await settle()
	modal_fits("Tap-accessible power explanation")
	check("fire" in visible_text(app.modal_panel).to_lower() or "burn" in visible_text(app.modal_panel).to_lower(),"Power help explains the selected ability without hover")
	app._close_modal()
	await settle()
	var before=JSON.stringify(app.sim.state)
	tile_inputs=0
	await click_control(power_ui.cancel_button)
	check(app.selected_power=="inspect" and not power_ui.active_strip.is_visible_in_tree(),"Cancel returns to Observe")
	check(tile_inputs==0 and JSON.stringify(app.sim.state)==before,"Clicking HUD controls never casts through them into the world")
	for entry in app.shell.category_buttons:
		if entry.id=="god": await click_control(entry.button)
	for entry in power_ui.ability_buttons:
		if entry.id=="bless": await click_control(entry.button)
	check(app.selected_power=="bless" and app.world.active_power=="inspect" and not is_instance_valid(app.modal),"Bless arms personal map selection")
	power_ui.cancel()
	power_ui.refresh()
	for entry in app.shell.category_buttons:
		check(not entry.button.button_pressed,"A personal action leaves no world brush armed: "+str(entry.id))
	app._select_power("inspect")
	await settle()
	check(app.shell.observe_button.button_pressed,"Direct Observe selection updates its visible state")
	for entry in app.shell.category_buttons:
		check(not entry.button.button_pressed,"Direct Observe selection clears the previous category: "+str(entry.id))
	power_ui.choose_power("bless")
	await settle()
	if is_instance_valid(app.modal): app._close_modal()
	app.shell.observe()
	await settle()
	check(app.shell.observe_button.button_pressed,"Shell Observe selection updates its visible state")
	for entry in app.shell.category_buttons:
		check(not entry.button.button_pressed,"Shell Observe selection clears the previous category: "+str(entry.id))

func check_context_flow():
	var town=app.sim.state.settlements[0]
	app._on_tile_clicked(town.x,town.y,MOUSE_BUTTON_LEFT)
	app._street_view()
	await settle()
	check(app.selected_id==town.id,"Town selection still resolves the actual settlement")
	check(app.shell.selection_plaque.is_visible_in_tree() and not is_instance_valid(app.modal),"Town selection opens a compact plaque, not a blocking inspector")
	fits(app.shell.selection_plaque,"Selection plaque")
	var viewport=root.get_visible_rect().size
	check(app.shell.selection_plaque.size.x*app.shell.selection_plaque.size.y<=viewport.x*viewport.y*0.15,"Selection plaque remains compact")
	await shot("town")
	var person=app.sim.resident_page(town.id,0,1).people[0]
	app._on_person_clicked(person.key)
	await settle()
	check(app.selected_person_key==person.key,"Person selection preserves their permanent identity")
	check(is_instance_valid(app.modal),"Clicking a person immediately opens their profile")
	await shot("person")
	await settle()
	modal_fits("Expanded personal details")
	check(person.name in visible_text(app.modal_panel),"Expanded profile shows the selected person")
	await click_button_named(app.modal_panel,"Overview")
	await click_button_named(app.modal_panel,"Show full stats & biography")
	check(descendants(app.modal_body).filter(func(node):return node is ProgressBar).size()>=15,"Profile presents a visual chart of personal stats")
	await shot("profile")
	await click_button_named(app.modal_panel,"Family")
	check(app.community.person_tab=="Family","The family tab opens through a touch-sized control")
	modal_fits("Family relationships")
	await click_button_named(app.modal_panel,"Influence")
	await settle()
	modal_fits("Personal influence tab")
	check(app.community.person_tab=="Influence","Detailed stats and powers use deliberate disclosure")
	await click_button_named(app.modal_panel,"History")
	check(app.community.person_tab=="History" and app.community.last_person==person.key,"History tab follows the same person through actual button input")
	await click_button_named(app.modal_panel,"Influence")
	app.community.preview_action("inspire_person",person.key)
	await settle()
	modal_fits("Personal action preview")
	await shot("influence")
	app._close_modal()
	app.community.show_faction(town.nation)
	await settle()
	modal_fits("Faction overview")
	var faction=app.sim.faction_summary(town.nation)
	check(faction.name in visible_text(app.modal_panel),"Faction details retain the real nation")
	await click_button_named(app.modal_panel,"Overview")
	await shot("realm")
	await click_button_named(app.modal_panel,"Leaders")
	await settle()
	modal_fits("Faction leaders")
	check(app.community.faction_tab=="Leaders","Leader details remain explicitly accessible")
	await click_button_named(app.modal_panel,"Towns")
	check(app.community.faction_tab=="Towns","Faction town list opens through its actual tab button")
	await click_button_named(app.modal_panel,"Society")
	check(app.community.faction_tab=="Society","Realm society view exposes public consequences")
	app.community.show_society(int(town.id))
	await settle()
	modal_fits("Laws and justice")
	app._close_modal()
	app._show_save()
	await settle()
	modal_fits("Save sheet")
	await shot("save")
	app._close_modal()
	app._show_load()
	await settle()
	modal_fits("Load sheet")
	await shot("load")
	app._close_modal()
	if root.get_visible_rect().size.x<400:
		app._show_menu()
		await settle()
		modal_fits("World menu")
		await shot("menu")
		app._close_modal()

func check_stat_boundaries():
	# Presentation-only stress data: no simulation ticks or player-save writes.
	var saved_state=app.sim.state.duplicate(true)
	app.status_time=0
	app.shell.status_panel.hide()
	app.sim.state.year=10000
	app.sim.state.stats.population=137000
	for town in app.sim.state.settlements: town.era=6 # Renaissance: the longest era label.
	for mode in ["sandbox"]:
		app.sim.state.mode=mode
		app.sim.state.active_side="god"
		app.sim.state.actions_left=3
		for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
			dimension_label="%dx%d"%[dimensions.x,dimensions.y]
			root.size=dimensions
			await settle()
			app._responsive_layout()
			await clear_selection()
			var stats=app.shell.stats_panel.get_global_rect()
			var menu=app.shell.menu_button.get_global_rect()
			var times=app.shell.time_panel.get_global_rect()
			print("HUD boundary ",dimension_label," ",mode,": resources=",stats," menu=",menu," time=",times)
			check(app.age_label.text=="Renaissance" and app.year_label.text in ["10000","10.0k"] and "137" in app.population_label.text,"Boundary fixture reaches the real population, full era name and compact year bindings")
			fits(app.shell.stats_panel,"Large-value resource strip")
			check(not stats.intersects(menu),"Long era and large statistics stay clear of Menu: "+str(stats)+" vs "+str(menu))
			check(not stats.intersects(times),"Long era and large statistics stay clear of time controls: "+str(stats)+" vs "+str(times))
			check_hud_text(app.shell.stats_panel)
			await shot("large-stats-"+mode)
	app.sim.state=saved_state
	app._refresh_ui(true)

func run():
	screenshots="--screenshots" in OS.get_cmdline_user_args()
	Saves.storage_directory="res://test-output/hud-saves"
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.size=RESOLUTIONS[0]
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app._close_modal()
	app.settings.show_tutorial=false
	app.settings.autosave=false
	app.tutorial_active=false
	app.tutorial_panel.hide()
	app.game_started=true
	app.paused=true
	app.sim.new_world({"seed":"HUD design acceptance","width":96,"height":64,"nations":3,"scenario":"fractured"})
	app.world.sim=app.sim
	app.world.tile_clicked.connect(func(_x,_y,_button):tile_inputs+=1)
	app.world.invalidate_terrain()
	app._refresh_ui(true)
	if "--stats-boundary" in OS.get_cmdline_user_args():
		await check_stat_boundaries()
		app._stop_audio()
		await create_timer(0.12).timeout
		app.queue_free()
		await process_frame
		print("HUD STAT BOUNDARIES: %d checks; %d failures"%[checks,failures])
		quit(1 if failures else 0)
		return
	for dimensions in RESOLUTIONS:
		dimension_label="%dx%d"%[dimensions.x,dimensions.y]
		root.size=dimensions
		await settle()
		app._responsive_layout()
		app.world.frame_world()
		await clear_selection()
		await check_idle(dimensions)
		await check_power_flow()
		await check_context_flow()
	# Logical touch geometry must remain the same on a 3x-density phone.
	dimension_label="390x844-at3x"
	root.content_scale_factor=3.0
	root.size=Vector2i(1170,2532)
	await settle()
	app._responsive_layout()
	await clear_selection()
	check(root.get_visible_rect().size.distance_to(Vector2(390,844))<2,"High DPI preserves the logical phone viewport")
	await check_idle(Vector2i(390,844))
	app._show_people()
	await settle()
	modal_fits("High-DPI resident directory")
	await shot("directory")
	app._close_modal()
	root.content_scale_factor=1.0
	await check_stat_boundaries()
	app._stop_audio()
	# The audio mixer runs separately; allow stopped playback to release before exit.
	await create_timer(0.12).timeout
	app.queue_free()
	await process_frame
	print("HUD ACCEPTANCE: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
