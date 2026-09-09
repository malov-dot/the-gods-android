extends SceneTree

const Calamity = preload("res://scripts/calamity_painter.gd")
const Simulation = preload("res://scripts/simulation.gd")
var failures = 0
var checks = 0

class Recorder extends RefCounted:
	var sim
	var calls = 0
	var invalid = 0
	var furthest = 0.0
	func _is_land(_x, _y): return true
	func _visible(_rect): return true
	func point(p):
		if not p.is_finite(): invalid += 1
		furthest = maxf(furthest,maxf(absf(p.x),absf(p.y)))
	func draw_rect(rect, _color, _filled = true, _width = -1.0, _antialiased = false):
		calls += 1
		point(rect.position)
		point(rect.end)
		if rect.size.x < 0 or rect.size.y < 0: invalid += 1
	func draw_line(a, b, _color, width = -1.0, _antialiased = false):
		calls += 1
		point(a)
		point(b)
		if not is_finite(width): invalid += 1
	func draw_polyline(points, _color, width = -1.0, _antialiased = false):
		calls += 1
		for p in points: point(p)
		if not is_finite(width): invalid += 1
	func draw_colored_polygon(points, _color, _uvs = PackedVector2Array(), _texture = null):
		calls += 1
		for p in points: point(p)
	func draw_arc(p, radius, _start, _end, _count, _color, width = -1.0, _antialiased = false):
		calls += 1
		point(p)
		if not is_finite(radius) or radius < 0 or not is_finite(width): invalid += 1

class ActualCanvas extends Control:
	var sim
	var painter = Calamity.new()
	var frames = 0
	func _is_land(_x, _y): return true
	func _visible(_rect): return true
	func _draw():
		frames += 1
		painter.draw_world(self,sim,3.5,3.0)
		for town in sim.state.settlements:
			painter.draw_town_conditions(self,town,(Vector2(town.x,town.y)+Vector2.ONE*0.5)*8.0,3.5,3.0)

class ClippedRecorder extends Recorder:
	var ownership_checks = 0
	func _detail_owns_position(_town, _point, margin = 0.0):
		ownership_checks += 1
		if not is_equal_approx(float(margin),8.0): invalid += 1
		return false

func _initialize(): call_deferred("run")

func run():
	var sim = Simulation.new()
	sim.new_world({"seed":"Calamity fixture", "width":64, "height":48, "nations":2})
	var town = sim.state.settlements[0]
	var point = (Vector2(town.x,town.y)+Vector2.ONE*0.5)*8.0
	var view = Recorder.new()
	view.sim = sim
	var painter = Calamity.new()
	var largest = 0
	var frames = 0
	for era in range(14):
		for kind in Calamity.SUPPORTED:
			town.era = era
			town.visual_damage = 0.65
			town.visual_disaster = kind
			town.visual_disaster_until = 20
			town.plague = 12 if kind == "plague" else 0
			town.drought = 12 if kind in ["drought","ice"] else 0
			# Missing 'started' exercises compatibility with already saved effects.
			sim.state.effects = [{"type":kind,"x":town.x,"y":town.y,"radius":4,"until":5}]
			var before = JSON.stringify(sim.state)
			for zoom in [0.3,1.6,4.0,12.0]:
				for phase in [0.0,0.8,1.8,4.0,12.0]:
					view.calls = 0
					painter.draw_world(view,sim,phase,zoom)
					painter.draw_town_conditions(view,town,point,phase,zoom)
					largest = maxi(largest,view.calls)
					frames += 1
			if JSON.stringify(sim.state) != before:
				check(false,"Rendering mutated simulation state")
	check(view.invalid == 0,"All disaster primitives remain finite and nonnegative")
	check(view.furthest < 1500,"Primitive coordinates remain within a bounded world footprint")
	check(largest < 800,"One visible calamity and its town use a bounded drawing budget")
	for kind in ["plague","drought","ice"]:
		town.plague = 0
		town.drought = 0
		sim.state.effects = [{"type":kind,"x":town.x,"y":town.y,"radius":3,"started":0,"until":5}]
		view.calls = 0
		painter.draw_world(view,sim,1.0,3.0)
		check(view.calls == 0,"Cured " + kind + " no longer renders an ongoing effect")
	sim.state.effects = []
	for i in range(300): sim.state.effects.append({"type":"storm","x":town.x,"y":town.y,"radius":3,"until":5})
	view.calls = 0
	painter.draw_world(view,sim,1.0,3.0)
	check(view.calls < 2000 and painter._first_seen.size() <= Calamity.MAX_EFFECTS,"Rapid sandbox interventions are capped and old animation clocks are discarded")
	sim.state.effects = [{"type":"meteor","x":town.x,"y":town.y,"radius":4,"started":0,"until":5}]
	var fresh = Calamity.new()
	view.calls = 0
	fresh.draw_world(view,sim,0.0,3.0)
	var incoming_calls = view.calls
	view.calls = 0
	fresh.draw_world(view,sim,3.0,3.0)
	check(incoming_calls != view.calls,"Meteor advances from incoming rock to impact crater while time is paused")
	var clipped = ClippedRecorder.new()
	clipped.sim = sim
	town.visual_disaster = "fire"
	town.visual_disaster_until = 20
	town.visual_damage = 0.0
	town.plague = 4
	town.drought = 0
	painter.draw_town_conditions(clipped,town,point,2.0,3.0)
	check(clipped.ownership_checks > 0 and clipped.calls == 0 and clipped.invalid == 0,"Clipped plots cannot emit rooftop flames or quarantine signs")
	town.visual_disaster = "fire"
	town.visual_damage = 0.5
	town.visual_disaster_until = 20
	town.plague = 4
	town.drought = 4
	sim.state.effects = []
	for kind in Calamity.SUPPORTED: sim.state.effects.append({"type":kind,"x":town.x,"y":town.y,"radius":3,"until":5})
	var actual = ActualCanvas.new()
	actual.sim = sim
	actual.custom_minimum_size = Vector2(800,600)
	root.add_child(actual)
	await process_frame
	await process_frame
	check(actual.frames > 0,"The full fixture executes actual Godot CanvasItem drawing")
	actual.queue_free()
	await process_frame
	print("Calamity painter: %d checks, %d failure(s); %d era/phase/zoom fixtures, peak %d primitives" % [checks,failures,frames,largest])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("CALAMITY: " + message)
