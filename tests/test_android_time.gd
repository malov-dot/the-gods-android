extends SceneTree
## Real ScreenTouch events through the GUI dispatcher, with mouse emulation off.
const Saves=preload("res://scripts/save_manager.gd")
const MobileDisplay=preload("res://scripts/mobile_display.gd")
var app
var checks=0
var failures=0

func _init(): run.call_deferred()
func check(value:bool,message:String):
	checks+=1
	if not value: failures+=1; push_error("ANDROID TIME: "+message)
func settle():
	for i in range(6): await process_frame
func descendants(node):
	var result=[]
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result
func speed_choice(value:int):
	for node in descendants(app.modal):
		if node is Button and node.get_meta("time_speed",0)==value: return node
	return null
func tap_at(point:Vector2):
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new()
		event.index=0; event.position=point; event.pressed=pressed
		root.push_input(event,true)
		await process_frame
	await settle()
func tap(button):
	check(is_instance_valid(button) and button.is_visible_in_tree(),"Native touch has a visible target")
	if is_instance_valid(button): await tap_at(button.get_global_rect().get_center())
func fits(control:Control,label_:String):
	var bounds=app.hud_rect()
	var rect=control.get_global_rect()
	check(rect.position.x>=bounds.position.x-1 and rect.position.y>=bounds.position.y-1 and rect.end.x<=bounds.end.x+1 and rect.end.y<=bounds.end.y+1,label_+" stays inside the usable display")
func capture(label_:String):
	if not "--screenshots" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/android-time-"+label_+".png")

func run():
	Saves.storage_directory="res://test-output/android-time-saves"
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),"Android touch is tested without synthesized mouse clicks")
	check(is_equal_approx(MobileDisplay.android_density(2.625,420),2.625),"Fold uses its 420dpi Android density")
	check(is_equal_approx(MobileDisplay.android_density(0.0,420),2.625),"Devices without the native bridge use logical DPI")
	check(MobileDisplay.android_density(NAN,320)==2.0 and MobileDisplay.android_density(INF,320)==2.0,"Invalid bridge values safely fall back to DPI")
	check(MobileDisplay.android_density(0.0,0)==1.0 and MobileDisplay.android_density(40.0,5000)==1.0,"Unavailable density has a finite fallback")
	check(is_equal_approx(48*MobileDisplay.android_density(2.625,420),126.0),"A 48dp Fold button occupies 126 physical pixels")
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle(); app._close_modal(); app.set_process(false)
	app.settings.autosave=false; app.settings.ambient=false; app._stop_audio()
	app.game_started=true; app.tutorial_active=false; app.paused=true
	app.sim.new_world({"seed":"Native time controls","width":64,"height":48,"nations":2})
	app._refresh_ui(true)
	for fixture in [
		{"name":"fold-cover","size":Vector2i(1248,1972),"density":2.625,"layout":"portrait"},
		{"name":"fold-inner","size":Vector2i(2448,1848),"density":2.625,"layout":"landscape"},
		{"name":"phone-landscape","size":Vector2i(2400,1080),"density":3.0,"layout":"landscape"},
		{"name":"small-phone","size":Vector2i(1080,2400),"density":3.0,"layout":"portrait"}]:
		root.content_scale_factor=fixture.density; root.size=fixture.size
		await settle(); app._responsive_layout(); app._refresh_ui(true); await settle()
		check(app.shell.layout_mode==fixture.layout,fixture.name+" chooses the appropriate phone layout")
		for button in [app.pause_button,app.shell.speed_button,app.shell.menu_button,app.shell.observe_button]:
			check(button.size.x>=48 and button.size.y>=48,fixture.name+" keeps at least 48dp touch targets")
			fits(button,fixture.name+" HUD button")
		for value in [1,5,20,100]:
			app.paused=true
			await tap(app.shell.speed_button)
			check(is_instance_valid(app.modal) and app.modal.get_meta("time_controls",false),fixture.name+" opens time using ScreenTouch")
			if not is_instance_valid(app.modal): continue
			fits(app.modal_panel,fixture.name+" time sheet")
			var choice=speed_choice(value)
			check(is_instance_valid(choice) and choice.size.x>=48 and choice.size.y>=56,"Speed choices have large independent touch targets")
			if value==20: await capture(fixture.name)
			await tap(choice)
			check(app.speed==value and not app.paused and not is_instance_valid(app.modal),"Selecting %d× resumes time and completely dismisses its input layer"%value)
			await tap(app.pause_button)
			check(app.paused,"Pause responds immediately after choosing %d×"%value)
			await tap(app.shell.menu_button)
			check(is_instance_valid(app.modal) and app.modal_title.text=="World menu","Menu remains tappable after choosing %d×"%value)
			app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await settle()
			await tap(app.shell.category_buttons[0].button)
			check(app.shell.power_ui.palette.visible,"Power categories remain tappable after the time sheet closes")
			await tap(app.shell.observe_button)
			check(not app.shell.power_ui.palette.visible,"Observe responds after a speed change")
		await tap(app.shell.speed_button)
		app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await settle()
		check(not is_instance_valid(app.modal) and app.paused,"Back closes time and preserves a paused world")
		app.paused=false
		await tap(app.shell.speed_button)
		await tap_at(Vector2(2,2))
		check(not is_instance_valid(app.modal) and not app.paused,"Touching outside time restores a running world")
		app.paused=true
	# These selectors formerly shared the same mouse-only popup as time.
	app._show_new_world(); await settle()
	for chooser in [app.new_scenario,app.new_size,app.new_difficulty]:
		app.modal_scroll.ensure_control_visible(chooser); await settle()
		await tap(chooser)
		check(is_instance_valid(chooser.choices_layer),"World creation opens a touch choice sheet")
		if not is_instance_valid(chooser.choices_layer): continue
		fits(chooser.choices_panel,"World option choices")
		if chooser==app.new_scenario:
			root.size=Vector2i(2400,1080); await settle()
			fits(chooser.choices_panel,"An open choice sheet after landscape rotation")
			root.size=Vector2i(1080,2400); await settle()
			fits(chooser.choices_panel,"An open choice sheet after portrait rotation")
		var intended=1 if chooser.selected!=1 else 0
		await tap(chooser.choice_buttons[intended])
		check(chooser.selected==intended and not is_instance_valid(chooser.choices_layer),"A world option selects and releases input")
		check(is_instance_valid(app.modal) and app.modal_title.text=="THE GODS","Choosing an option preserves the creation form")
		await tap(chooser)
		app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await settle()
		check(not is_instance_valid(chooser.choices_layer) and is_instance_valid(app.modal),"Back closes only the option sheet")
		if chooser==app.new_scenario:
			await tap(chooser)
			var escape=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
			app._unhandled_key_input(escape); await settle()
			check(not is_instance_valid(chooser.choices_layer) and is_instance_valid(app.modal),"Escape closes only the option sheet on PC")
	app._close_modal(); app.community.show_people(); await settle()
	var town_chooser=app.modal_body.get_child(0)
	await tap(town_chooser)
	var intended_town=town_chooser.get_item_id(1)
	await tap(town_chooser.choice_buttons[1])
	check(app.community.town_id==intended_town and not is_instance_valid(town_chooser.choices_layer),"Residents can switch communities using native touch")
	app._close_modal()
	app.shell.power_ui.choose_power("fire"); await settle()
	var radius=app.shell.power_ui.radius_slider
	var high=radius.get_global_rect().position+Vector2(radius.size.x-4,radius.size.y*0.5)
	await tap_at(high)
	check(app.world.brush_radius==int(radius.max_value),"Native touch reaches the brush slider's upper limit")
	var low=radius.get_global_rect().position+Vector2(4,radius.size.y*0.5)
	var touch_start=InputEventScreenTouch.new(); touch_start.index=0; touch_start.position=high; touch_start.pressed=true
	root.push_input(touch_start,true); await process_frame
	var touch_drag=InputEventScreenDrag.new(); touch_drag.index=0; touch_drag.position=low; touch_drag.relative=low-high
	root.push_input(touch_drag,true); await process_frame
	var touch_end=InputEventScreenTouch.new(); touch_end.index=0; touch_end.position=low; touch_end.pressed=false
	root.push_input(touch_end,true); await settle()
	check(app.world.brush_radius==int(radius.min_value),"Dragging the brush slider works without mouse emulation")
	check(radius._finger==-1,"Releasing a slider frees the touch gesture")
	var canceled=InputEventScreenTouch.new(); canceled.index=0; canceled.position=low; canceled.pressed=true
	root.push_input(canceled,true); await process_frame
	canceled.pressed=false; canceled.canceled=true
	root.push_input(canceled,true); await process_frame
	check(radius._finger==-1,"Android cancellation releases the slider's finger")
	var after_cancel=radius.value
	touch_drag.position=high; root.push_input(touch_drag,true); await settle()
	check(radius.value==after_cancel,"A stray drag after cancellation cannot change the radius")
	radius.editable=false
	await tap_at(high)
	check(radius.value==after_cancel,"Disabled sliders ignore native touch")
	radius.editable=true
	app.shell.observe(); app._show_settings(); await settle()
	for node in descendants(app.modal):
		if node is HSlider:
			app.modal_scroll.ensure_control_visible(node); await settle()
			await tap_at(node.get_global_rect().position+Vector2(node.size.x-4,node.size.y*0.5))
			check(is_equal_approx(app.settings.volume,1.0),"Native touch adjusts the actual audio volume")
			check(node.size.y>=48,"Volume has a 48dp touch area")
	app._close_modal(); app._stop_audio()
	# Time and Back must work even while a large generation yields between frames.
	for town in app.sim.state.settlements: town.population=3000.0; town.food=100000.0
	app.sim.refresh_totals()
	app._advance_world()
	check(app.simulation_busy,"Busy-world fixture is advancing across frames")
	await tap(app.shell.speed_button)
	check(is_instance_valid(app.modal) and app.modal.get_meta("time_controls",false),"A time request does not wait in the world-action queue")
	check(not app.deferred_world_action.is_valid(),"Time controls do not enqueue a hidden action")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not is_instance_valid(app.modal),"Android Back dismisses time during simulation work")
	for i in range(10000):
		if not app.simulation_busy: break
		await process_frame
	check(not app.simulation_busy,"The interrupted generation finishes normally")
	app.paused=true; app._stop_audio(); app.queue_free(); await process_frame
	print("ANDROID TIME ACCEPTANCE: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
