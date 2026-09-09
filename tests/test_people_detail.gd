extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Painter = preload("res://scripts/people_painter.gd")
const Content = preload("res://scripts/content.gd")

class ObservedPainter:
	extends "res://scripts/people_painter.gd"
	var fighting_draws = 0
	func draw_person(view, p: Vector2, era: int, flag: Color, seed: int, role: String, direction: float, phase: float, activity: String):
		if activity == "fighting": fighting_draws += 1
		super.draw_person(view,p,era,flag,seed,role,direction,phase,activity)

class PaintHarness:
	extends Control
	var painter = ObservedPainter.new()
	var sim
	var _nation_colors = {1:Color("dc8667"), 2:Color("73b8d3")}
	var _font = ThemeDB.fallback_font
	var zoom = 6.0
	var ocean = false
	var water_tiles = {}
	var frame_time = 8.1
	var mode = "sheet"
	var legacy_draws = 0
	func _is_land(x, y): return not ocean and not water_tiles.has(Vector2i(x,y))
	func _visible(_rect): return true
	func _draw_person(_p, _flag, _seed): legacy_draws += 1
	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color("28443d"))
		if mode == "sheet":
			var roles = ["citizen", "farmer", "worker", "scholar", "leader", "prophet", "soldier", "archer"]
			for era in range(14):
				var origin = Vector2(20 + era % 7 * 220, 30 + int(era / 7) * 475)
				draw_set_transform(Vector2.ZERO)
				draw_string(_font, origin, str(Content.ERAS[era].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eee2bb"))
				for i in range(roles.size()):
					var pos = origin + Vector2((i % 2) * 100, int(i / 2) * 97 + 76)
					draw_set_transform(pos, 0, Vector2.ONE * 6)
					painter.draw_person(self, Vector2.ZERO, era, _nation_colors[1], era * 23 + i, roles[i], 1, frame_time * 4 + i, "fighting" if i >= 6 else "walking")
					draw_set_transform(Vector2.ZERO)
					draw_string(_font, pos + Vector2(-10, 18), roles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("bdd1bc"))
				draw_set_transform(origin + Vector2(105, 444), 0, Vector2.ONE * 5)
				painter._support(self, Vector2.ZERO, era, _nation_colors[1], 1, frame_time)
		else:
			draw_set_transform(Vector2(-180, -780), 0, Vector2.ONE * 5)
			painter.draw_wars(self, sim, frame_time, zoom)

var checks = 0
var failed = 0

func _initialize(): call_deferred("run")

func check(value, label):
	checks += 1
	if not value:
		failed += 1
		push_error("PEOPLE DETAIL: " + label)

func settle():
	await process_frame
	await process_frame
	await process_frame

func run():
	root.size = Vector2i(1570, 990)
	var sim = Simulation.new()
	sim.new_world({"seed":"People detail fixture", "width":64, "height":48, "nations":2})
	var view = PaintHarness.new()
	view.sim = sim
	view.size = Vector2(1570, 990)
	root.add_child(view)
	var town = sim.state.settlements[0]
	var center = Vector2(200, 200)
	var original = JSON.stringify(sim.state)
	var sample = view.painter.citizens(view, town, center, 8.1)
	check(sample.size() > 0 and sample.size() <= 24, "Residents have a bounded human-scale representation")
	check(sample == view.painter.citizens(view, town, center, 8.1), "Drawing at a fixed time is deterministic")
	var later = view.painter.citizens(view, town, center, 8.6)
	check(later[0].position.distance_to(sample[0].position) < 8, "Street walking is continuous across frames")
	for person in sample:
		var relative = person.position - center
		check(minf(minf(absf(relative.x), absf(absf(relative.x) - 24)), minf(absf(relative.y), absf(absf(relative.y) - 24))) <= 2.1, "Resident feet follow streets")
	check(JSON.stringify(sim.state) == original, "Rendering does not change simulation state")
	var empty_town = town.duplicate(true)
	empty_town.population = 0
	empty_town.orbital_population = 400
	check(view.painter.citizens(view, empty_town, center, 8.1).is_empty(), "Orbital inhabitants are never drawn on the surface")
	var dying_town = town.duplicate(true)
	dying_town.population = 2
	check(view.painter.citizens(view, dying_town, center, 8.1).size() <= 2, "Representation never exceeds remaining residents")
	var harmed = town.duplicate(true)
	harmed.visual_damage = 0.5
	harmed.visual_disaster = "fire"
	harmed.visual_disaster_until = sim.state.year + 3
	var fleeing = view.painter.citizens(view, harmed, center, 8.1)
	check(fleeing.all(func(person): return person.activity == "fleeing"), "Actual town damage changes civilian behavior")
	harmed.visual_disaster_until = sim.state.year - 1
	check(view.painter.citizens(view, harmed, center, 8.1).all(func(person): return person.activity != "fleeing"), "Rebuilding after an ended disaster does not keep citizens fleeing")
	harmed.visual_disaster = "plague"
	harmed.visual_disaster_until = sim.state.year + 4
	harmed.plague = 5
	var afflicted = view.painter.citizens(view, harmed, center, 8.1)
	check(afflicted.any(func(person): return person.activity == "ill") and afflicted.all(func(person): return person.activity != "fleeing"), "A plague uses illness even if old building damage remains")
	# A broken road cannot teleport a citizen across the sea or into a house plot.
	for y in range(12,36):
		for x in range(21,24): view.water_tiles[Vector2i(x,y)] = true
	var coast_ok = true
	var continuous = true
	var last_positions = {}
	for frame in range(30):
		for person in view.painter.citizens(view,town,center,20.0 + float(frame) * 0.10):
			var pos = person.position
			var relative = pos-center
			var on_road = minf(minf(absf(relative.x),absf(absf(relative.x)-24)),minf(absf(relative.y),absf(absf(relative.y)-24))) <= 1.1
			coast_ok = coast_ok and on_road and view._is_land(floori(pos.x/8),floori(pos.y/8))
			if last_positions.has(person.seed): continuous = continuous and pos.distance_to(last_positions[person.seed]) < 1.0
			last_positions[person.seed] = pos
	check(coast_ok,"Coastal walkers stay on habitable streets")
	check(continuous,"Coastal walkers turn back continuously at broken roads")
	view.water_tiles.clear()
	await settle()
	if "--screenshots" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-output")
		root.get_texture().get_image().save_png("res://test-output/people-detail-sheet.png")
	# Draw both land and sea conflicts for every technology level; zero wars draws no army.
	var a = town.duplicate(true)
	var b = town.duplicate(true)
	a.id = 501
	a.nation = 1
	a.x = 10
	a.y = 28
	b.id = 502
	b.nation = 2
	b.x = 35
	b.y = 28
	sim.state.settlements = [a, b]
	sim.state.wars = [{"a":1, "b":2, "front_a":a.id, "front_b":b.id, "casualties_a":5.0, "casualties_b":3.0}]
	view.mode = "war"
	for era in range(14):
		a.era = era
		b.era = mini(13, era + 1)
		for navy in [false, true]:
			view.ocean = navy
			view.frame_time += 0.14
			view.queue_redraw()
			await settle()
		check(not view.painter.weapon_name(era).is_empty(), "Technology weapons have a readable name")
	var pairing = view.painter._front_pair(sim, sim.state.wars[0])
	check(pairing[0].id == 501 and pairing[1].id == 502, "Army formations use the actual recorded battle front")
	view.ocean = false
	for y in range(50):
		for x in range(22,25): view.water_tiles[Vector2i(x,y)] = true
	view.painter.fighting_draws = 0
	view.queue_redraw()
	await settle()
	check(view.painter.fighting_draws > 0,"Opposing land forces remain visible on the shores of a river")
	view.water_tiles.clear()
	view.zoom = 1.0
	view.legacy_draws = 0
	view.queue_redraw()
	await settle()
	check(view.legacy_draws > 0, "Atlas retains inexpensive war markers")
	sim.state.wars = []
	view.legacy_draws = 0
	view.queue_redraw()
	await settle()
	check(view.legacy_draws == 0, "Ended wars have no lingering armies")
	view.queue_free()
	print("People detail: %d checks, %d failures" % [checks, failed])
	quit(0 if failed == 0 else 1)
