extends SceneTree
## Bounded Android-facing UI checks. Safe-area overrides exercise the actual HUD
## layout without pretending a desktop process is an Android device.
const Saves=preload("res://scripts/save_manager.gd")
const MobileDisplay=preload("res://scripts/mobile_display.gd")
var app
var checks=0
var failures=0

class SafeAreaApp extends "res://scripts/main.gd":
	var fixture_safe=Rect2()
	func hud_rect()->Rect2:
		return fixture_safe if fixture_safe.has_area() else super.hud_rect()

func _initialize(): run.call_deferred()
func check(value:bool,message:String):
	checks+=1
	if not value:
		failures+=1
		push_error("ANDROID LIFECYCLE: "+message)
func settle():
	for unused in range(6): await process_frame
func back():
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
func fits(control:Control,bounds:Rect2,label_:String):
	var rect=control.get_global_rect()
	check(rect.position.x>=bounds.position.x-1 and rect.position.y>=bounds.position.y-1 and rect.end.x<=bounds.end.x+1 and rect.end.y<=bounds.end.y+1,label_+" fits "+str(bounds)+" actual="+str(rect))
func stable(snapshot:String,label_:String):
	check(JSON.stringify(app.sim.state)==snapshot,label_+" preserves every simulation field")
	check(app.game_started and is_instance_valid(app.world) and app.world.sim==app.sim,label_+" keeps the current world connected")

func check_back_navigation():
	var state=JSON.stringify(app.sim.state)
	app.paused=false
	app._show_menu()
	await settle()
	check(is_instance_valid(app.modal) and app.paused,"Menu pauses the running world")
	await back()
	check(not is_instance_valid(app.modal) and not app.paused,"Native Back closes a sheet and restores the prior running state")
	stable(state,"Closing a sheet")
	app.paused=true
	app.shell.power_ui.choose_power("fire")
	await settle()
	check(app.selected_power=="fire" and app.world.active_power=="fire","A destructive power is armed before cancellation")
	app._show_menu()
	await settle()
	await back()
	check(not is_instance_valid(app.modal) and app.selected_power=="fire","Back closes a sheet before canceling the underlying tool")
	await back()
	check(app.selected_power=="inspect" and app.world.active_power=="inspect","The next Back cancels the armed tool")
	check(not app.active_banner.visible and not is_instance_valid(app.modal),"Tool cancellation restores the unobstructed world")
	check(app.shell.observe_button.button_pressed,"Canceled tools return to Observe")
	stable(state,"Canceling an armed tool")
	app.shell.power_ui.open_category("god")
	await settle()
	check(app.shell.power_ui.palette.visible,"Ability tray opens before native Back")
	await back()
	check(not app.shell.power_ui.palette.visible and not is_instance_valid(app.modal),"Back dismisses a power tray without opening Menu")
	for entry in app.shell.category_buttons: check(not entry.button.button_pressed,"Back clears category highlight "+entry.id)
	stable(state,"Closing a power tray")
	await back()
	check(is_instance_valid(app.modal) and app.modal_title.text=="World menu","Back from Observe opens the world menu")
	stable(state,"Opening the world menu")
	await back()
	check(not is_instance_valid(app.modal) and app.paused,"Closing the menu preserves a deliberately paused world")
	stable(state,"Returning from the world menu")
	# Android-only suspend autosaving needs a real Android runtime. The desktop
	# suite still delivers the notification and verifies non-Android isolation.
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await settle()
	stable(state,"Application pause notification")
	if OS.has_feature("android"): check(app.paused,"Android suspension leaves simulation paused")

func check_phone_boundaries():
	app.sim.state.year=10000
	app.sim.state.stats.population=137000
	app.sim.state.stats.god=0.51
	app.sim.state.stats.devil=0.49
	for town in app.sim.state.settlements: town.era=6
	for fixture in [
		{"size":Vector2i(360,800),"scale":1.0,"safe":Rect2(0,0,360,800),"name":"360px"},
		{"size":Vector2i(1080,2400),"scale":3.0,"safe":Rect2(0,24,360,752),"name":"360px at 3x with top/bottom insets"},
		{"size":Vector2i(2400,1080),"scale":3.0,"safe":Rect2(24,0,752,336),"name":"800px landscape at 3x with side/bottom insets"}]:
		root.content_scale_factor=fixture.scale
		root.size=fixture.size
		app.fixture_safe=fixture.safe
		await settle()
		for mode in ["sandbox"]:
			app.sim.state.mode=mode
			app.sim.state.active_side="god"
			app.sim.state.actions_left=3
			app._responsive_layout()
			app._refresh_ui(true)
			await settle()
			var label_=fixture.name+" "+mode
			check(app.get_viewport_rect().size.is_equal_approx(Vector2(fixture.size)/fixture.scale),label_+" uses logical pixels")
			check(app.world.get_global_rect().is_equal_approx(app.get_viewport_rect()),label_+" world stays full viewport")
			check(app.shell.hud.get_global_rect().is_equal_approx(fixture.safe),label_+" HUD honors safe-area origin and extent")
			check(app.age_label.text==("Ren." if fixture.safe.size.x<390 else "Renaissance"),label_+" uses the responsive Renaissance label")
			check(app.year_label.text=="10.0k" and "137" in app.population_label.text,label_+" shows the large year and population")
			for item in [[app.shell.stats_panel,"statistics"],[app.shell.menu_button,"Menu"],[app.shell.time_panel,"time"],[app.shell.rail,"power tray"]]: fits(item[0],fixture.safe,label_+" "+item[1])
			var stats=app.shell.stats_panel.get_global_rect()
			check(not stats.intersects(app.shell.menu_button.get_global_rect()),label_+" statistics stay clear of Menu")
			check(not stats.intersects(app.shell.time_panel.get_global_rect()),label_+" statistics stay clear of time controls")
			for entry in app.shell.category_buttons: check(entry.button.size.x>=48 and entry.button.size.y>=48,label_+" keeps 48px "+entry.id+" target")
			print("ANDROID HUD ",label_,": stats=",stats," safe=",fixture.safe)
			app._show_menu()
			await settle()
			fits(app.modal_panel,fixture.safe,label_+" menu sheet")
			await back()
			app.shell.power_ui.open_category("god")
			await settle()
			fits(app.shell.power_ui.palette,fixture.safe,label_+" abilities")
			await back()
			app.shell.power_ui.choose_power("protect")
			await settle()
			fits(app.active_banner,fixture.safe,label_+" active power")
			await back()
	app.fixture_safe=Rect2()
	root.content_scale_factor=1.0

func run():
	Saves.storage_directory="res://test-output/android-lifecycle-saves"
	root.size=Vector2i(390,844)
	app=SafeAreaApp.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await settle()
	app._close_modal()
	app.set_process(false)
	app.settings.show_tutorial=false
	app.settings.autosave=false
	app.tutorial_active=false
	app.game_started=true
	app.paused=true
	app.sim.new_world({"seed":"android-lifecycle-10400","width":64,"height":48,"nations":2,"mode":"sandbox"})
	app._refresh_ui(true)
	await settle()
	check(not OS.has_feature("android") or not quit_on_go_back,"Android Back is handled without automatically quitting")
	if not OS.has_feature("android"):
		check(MobileDisplay.hud_rect(Vector2(360,800),3.0)==Rect2(0,0,360,800),"Non-Android safe-area helper retains the logical viewport")
	await check_back_navigation()
	await check_phone_boundaries()
	app._stop_audio()
	await create_timer(0.12).timeout
	app.queue_free()
	await process_frame
	print("ANDROID LIFECYCLE ACCEPTANCE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
