extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

class ObservedWorld:
	extends "res://scripts/world_view.gd"
	var orbital_draws = 0
	var orbital_positions = []
	func _draw_orbital_marker(position, flag):
		orbital_draws += 1
		orbital_positions.append(position)
		super._draw_orbital_marker(position, flag)

var world
var sim
var clicks = []
var checks = 0
var failures = 0


func _initialize():
	call_deferred("run")


func check(value, message):
	checks += 1
	if not value:
		failures += 1
		push_error("RENDERER CHECK: " + message)


func settle():
	await process_frame
	await process_frame
	await process_frame


func screen_position(tile):
	return world._camera + (Vector2(tile) + Vector2.ONE * 0.5) * world.TILE * world.zoom


func press(tile, button = MOUSE_BUTTON_LEFT, pressed = true):
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = screen_position(tile)
	world._gui_input(event)


func motion(tile):
	var event = InputEventMouseMotion.new()
	event.position = screen_position(tile)
	event.relative = Vector2(8, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	world._gui_input(event)


func gesture(power, mode):
	world.active_power = power
	sim.state.mode = mode
	clicks.clear()
	press(Vector2i(15, 15))
	motion(Vector2i(16, 15))
	motion(Vector2i(17, 15))
	motion(Vector2i(17, 15))
	press(Vector2i(17, 15), MOUSE_BUTTON_LEFT, false)
	return clicks.size()


func run():
	root.size = Vector2i(960, 720)
	sim = Simulation.new()
	sim.new_world({"seed":"Renderer regression", "width":48, "height":36, "nations":2})
	world = ObservedWorld.new()
	world.sim = sim
	world.size = Vector2(960, 720)
	world.tile_clicked.connect(func(x, y, button): clicks.append(Vector3i(x, y, button)))
	root.add_child(world)
	await settle()
	world.reset_camera()
	for power in ["land", "water", "mountain", "forest", "fertility", "ore", "warm", "cool"]:
		check(gesture(power, "sandbox") == 3, "Sandbox " + power + " paints each distinct tile once")
	for mode in ["sandbox", "versus_ai", "hotseat"]:
		for power in ["inspect", "heal", "bless", "pact", "fire", "population", "settlement", "wildlife"]:
			check(gesture(power, mode) == 1, mode + " " + power + " cannot repeat with a slight drag")
	for mode in ["versus_ai", "hotseat"]:
		check(gesture("land", mode) == 1, "Forbidden editor cannot drag-paint in " + mode + "; click is validated by powers")
	world.active_power = "bless"
	clicks.clear()
	press(Vector2i(15, 15), MOUSE_BUTTON_RIGHT)
	motion(Vector2i(16, 15))
	press(Vector2i(16, 15), MOUSE_BUTTON_RIGHT, false)
	check(clicks.is_empty(), "Right-button panning never casts a power")
	clicks.clear()
	press(Vector2i(15, 15), MOUSE_BUTTON_MIDDLE)
	motion(Vector2i(16, 15))
	press(Vector2i(16, 15), MOUSE_BUTTON_MIDDLE, false)
	check(clicks.is_empty(), "Middle-button panning never casts a power")
	sim.state.mode = "sandbox"
	for layer in ["terrain", "nations", "belief", "fertility", "technology"]:
		world.overlay = layer
		world.invalidate_terrain()
		await settle()
		check(world._terrain_texture != null, layer + " preserves illustrated terrain")
		check((world._overlay_texture == null) == (layer == "terrain"), layer + " builds the expected overlay texture")
	# Civilization life can survive exclusively in orbit after a surface disaster.
	var town = sim.state.settlements[0]
	town.population = 0.0
	town.orbital_population = 125.0
	town.era = 13
	town.abandoned = true
	var tile = sim.get_tile(town.x, town.y)
	tile.elevation = 0.20
	tile.biome = "ocean"
	tile.forest = 0.0
	sim.state.terrain_revision += 1
	sim.refresh_totals()
	world.overlay = "belief"
	world.selected_id = town.id
	world.invalidate_terrain()
	world.center_on_tile(town.x, town.y)
	world.orbital_draws = 0
	world.orbital_positions.clear()
	await settle()
	var anchor = (Vector2(town.x, town.y) + Vector2.ONE * 0.5) * world.TILE
	check(world._living_population(town) == 125.0, "Orbital survivors remain eligible for city labels and belief")
	check(world.orbital_draws > 0, "Orbital-only civilization draws its station despite a flooded surface")
	check(anchor in world.orbital_positions, "Orbital station stays at its selectable settlement coordinate")
	clicks.clear()
	world.active_power = "inspect"
	press(Vector2i(town.x, town.y))
	press(Vector2i(town.x, town.y), MOUSE_BUTTON_LEFT, false)
	check(clicks.size() == 1 and clicks[0].x == town.x and clicks[0].y == town.y, "Orbital station anchor emits the normal settlement selection click")
	var selected = sim.nearest_settlement(town.x, town.y, 2.0)
	check(not selected.is_empty() and selected.id == town.id, "Selection resolves the surviving orbital civilization")
	world.queue_free()
	await process_frame
	print("RENDERER ACCEPTANCE: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
