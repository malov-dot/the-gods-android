extends SceneTree

const Saves = preload("res://scripts/save_manager.gd")
const Content = preload("res://scripts/content.gd")
var app
var checks = 0
var failures = 0
var capture = false
var baseline = {}

func _initialize():
	call_deferred("run")

func check(value, message):
	checks += 1
	if not value:
		failures += 1
		push_error("DETAIL CHECK: " + message)

func settle():
	await process_frame
	await process_frame
	await process_frame

func shot(name_):
	if not capture: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://test-output/" + name_ + ".png") == OK, "Captured " + name_)

func fixture(era):
	app.sim.restore(baseline.duplicate(true))
	for town in app.sim.state.settlements:
		town.era = era
		town.population = 650.0
		town.food = 2400.0
		town.health = 0.94
		town.happiness = 0.85
		town.wealth = 3000.0
		town.plague = 0
		town.drought = 0
		town.buildings = []
		for age in range(era + 1): town.buildings.append(Content.ERA_BUILDINGS[age])
	app.sim.refresh_totals()
	app.selected_id = app.sim.state.settlements[0].id
	app.world.invalidate_terrain()
	app._street_view()
	app._refresh_ui(true)

func run():
	capture = "--screenshots" in OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 960)
	Saves.storage_directory = "res://test-output/detail-saves"
	DirAccess.make_dir_recursive_absolute(Saves.storage_directory)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app._close_modal()
	app.game_started = true
	app.paused = true
	app.sim.new_world({"seed":"Street detail integration", "width":80, "height":55, "nations":2})
	# Deliberately controlled land fixture, with actual simulation towns and nation IDs.
	app.sim.state.settlements.resize(2)
	for i in range(2):
		var town = app.sim.state.settlements[i]
		town.x = 25 + i * 25
		town.y = 27
		town.nation = app.sim.state.nations[i].id
		town.name = ["Dawnwatch", "Emberfall"][i]
	for y in range(18, 37):
		for x in range(16, 60):
			var tile = app.sim.get_tile(x,y)
			tile.elevation = 0.52
			tile.biome = "grass"
			tile.forest = 0.08 if x > 18 and x < 58 else 0.65
			tile.fertility = 0.75
			tile.moisture = 0.65
	app.sim.state.terrain_revision += 1
	app.sim.refresh_totals()
	baseline = app.sim.state.duplicate(true)
	await settle()
	for era in range(14):
		fixture(era)
		var before = JSON.stringify(app.sim.state)
		await settle()
		check(app.world.zoom == 4.5, "Street View focuses era " + str(era))
		check(app.world.detail_towns_drawn >= 1, "Close buildings render era " + str(era))
		check(app.world.detail_people_drawn >= 8 and app.world.detail_people_drawn <= 48, "Bounded citizens render era " + str(era))
		check(JSON.stringify(app.sim.state) == before, "Painting cannot change era " + str(era) + " simulation")
		if era in [0,5,8,9,13]: await shot("detail-era-" + str(era))
	app.world.set_zoom(99)
	check(app.world.zoom == 12.0, "Maximum zoom reveals half-pixel detail at 1200%")
	await settle()
	await shot("detail-maximum-zoom")
	app.world.set_zoom(1.0)
	var town = app.sim.state.settlements[0]
	app.world.center_on_tile(town.x,town.y)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	event.position = app.world._camera + (Vector2(town.x,town.y) + Vector2.ONE * 0.5) * app.world.TILE * app.world.zoom
	app.world._gui_input(event)
	check(app.world.zoom == 4.5, "Double click inspects and focuses the clicked town")
	for era in [5,9]:
		fixture(era)
		town = app.sim.state.settlements[0]
		check(app.powers.apply(app.sim,"discord",town.x,town.y,3,"devil").ok, "War can be incited in fixture")
		app.sim._conflict_year()
		check(not app.sim.state.wars.is_empty(), "Actual war persists")
		if not app.sim.state.wars.is_empty():
			var war = app.sim.state.wars[0]
			check(war.has("front_a") and war.has("front_b"), "Battle records real settlement fronts")
			check(war.get("casualties_a",0) + war.get("casualties_b",0) > 0, "Battle records actual casualties")
		app.world.set_zoom(3.0)
		app.world.center_on_tile(37,27)
		app.world.invalidate_terrain()
		app._refresh_ui(true)
		await settle()
		await shot("detail-war-" + str(era))
		check(app.powers.apply(app.sim,"peace",town.x,town.y,3,"god").ok and app.sim.state.wars.is_empty(), "Concord removes actual battle")
	for power in ["fire","meteor","earthquake","storm","plague","ice","volcano","drought"]:
		fixture(9)
		town = app.sim.state.settlements[0]
		check(app.powers.apply(app.sim,power,town.x,town.y,4,"god").ok, "Actual " + power + " cast")
		check(town.get("visual_disaster","") == power, "Town records " + power + " condition")
		app.world.invalidate_terrain()
		app._refresh_ui(true)
		await settle()
		app.world._time += 1.2
		await settle()
		var before = JSON.stringify(app.sim.state)
		await settle()
		check(JSON.stringify(app.sim.state) == before, "Rendering " + power + " cannot alter losses")
		if power in ["fire","meteor","earthquake","plague"]: await shot("detail-" + power)
		if power == "fire":
			check(town.get("visual_damage",0) > 0, "Actual fire leaves visible damage")
			check(Saves.save_game(app.sim.state,0).ok, "Damaged world saves")
			var loaded = Saves.load_game(0)
			check(loaded.ok and is_equal_approx(loaded.state.settlements[0].visual_damage, town.visual_damage), "Damage survives a save round trip")
	# Original version1 saves contain none of the optional rendering metadata.
	check(Saves.validate_state(baseline).ok, "Original-format state remains valid")
	app.sim.restore(baseline.duplicate(true))
	app._street_view()
	await settle()
	check(app.world.detail_towns_drawn > 0, "Old worlds gain detail without migration")
	var first_town=app.sim.state.settlements[0]
	var second_town=app.sim.state.settlements[1]
	second_town.x=first_town.x+6
	second_town.y=first_town.y
	app.world._detail_neighbors.clear()
	var center=(Vector2(first_town.x,first_town.y)+Vector2.ONE*0.5)*8
	check(not app.world._detail_owns_position(first_town,center+Vector2(36,0),8), "Close towns reserve separate building footprints")
	check(app.world._detail_owns_position(first_town,center+Vector2(12,0),8), "Close towns retain their own central plots")
	await settle()
	await shot("detail-neighboring-towns")
	second_town.population=0
	app.world._build_roads()
	check(app.world._roads.is_empty(), "Travelers never head toward an abandoned surface town")
	# Also render the untouched generator's coast and forests, without fixture landscaping.
	app.sim.new_world({"seed":"Eden-7401","width":160,"height":100,"nations":5})
	await settle()
	app.selected_id=app.sim.state.settlements[0].id
	app._street_view()
	app._refresh_ui(true)
	await settle()
	await shot("detail-natural-world")
	app._stop_audio()
	# Allow the separate audio mixer to release stopped playback before exit.
	await create_timer(0.12).timeout
	app.queue_free()
	await process_frame
	print("DETAIL ACCEPTANCE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
