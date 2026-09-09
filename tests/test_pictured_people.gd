extends SceneTree

const Simulation=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")
var checks=0
var failures=0
var world
var sim

func _initialize(): call_deferred("run")
func check(value,message):
	checks+=1
	if not value:
		failures+=1
		push_error("PICTURED PEOPLE: "+message)
func settle():
	await process_frame
	await process_frame
	await process_frame

func verify_people(context):
	var seen={}
	for person in world._pictured_people:
		var actual=sim.get_individual(str(person.key))
		check(not actual.is_empty() and actual.alive and actual.location=="surface",context+": every pictured human is an actual living surface resident")
		check(not seen.has(person.key),context+": nobody is pictured twice")
		seen[person.key]=true
	return seen

func run():
	sim=Simulation.new()
	sim.new_world({"seed":"Selectable guards and merchants","width":64,"height":48,"nations":2})
	for tile in sim.state.tiles:
		tile.elevation=0.55
		tile.biome="grass"
		tile.forest=0.0
	for i in range(2):
		var town=sim.state.settlements[i]
		town.x=18+i*24
		town.y=24
		town.era=5
		town.population=450.0
	sim.state.terrain_revision+=1
	sim.refresh_totals()
	world=World.new()
	world.sim=sim
	world.size=Vector2(1200,650)
	root.add_child(world)
	await settle()
	world.set_process(false)
	world.set_zoom(4.5)
	world.center_on_tile(30,24)
	await settle()
	var seen=verify_people("Peace")
	var merchants=[]
	for key in world._reserved_people:
		if world._reserved_people[key].context=="trade":
			merchants.append(key)
			check(seen.has(key) and sim.get_individual(key).role=="merchant","A road walker is an actual merchant and appears exactly once")
	check(not merchants.is_empty(),"Peaceful routes show selectable real merchants")
	if not merchants.is_empty():
		var key=merchants[0]
		var position=world._reserved_people[key].position
		check(world.focus_person(key),"A merchant can be focused on their current route")
		await settle()
		check(world._reserved_people.has(key) and world._reserved_people[key].position.distance_to(position)<0.01,"Changing the camera never reassigns a merchant to another route")
	world.set_zoom(4.5)
	world.center_on_tile(30,24)
	var a=sim.state.settlements[0]
	var b=sim.state.settlements[1]
	sim.state.wars=[{"a":a.nation,"b":b.nation,"front_a":a.id,"front_b":b.id}]
	world.invalidate_terrain()
	await settle()
	seen=verify_people("War")
	var guards=[]
	for key in world._reserved_people:
		if world._reserved_people[key].context=="war":
			guards.append(key)
			check(seen.has(key) and sim.get_individual(key).role=="guard","An army figure is an actual guard and appears exactly once")
	check(guards.size()>4,"Both sides of a real war show actual selectable guards")
	check(world._reserved_people.values().all(func(item):return item.context!="trade"),"Hostile roads contain no fictional trade pedestrians")
	if not guards.is_empty():
		var key=guards[-1]
		var position=world._reserved_people[key].position
		check(world.focus_person(key),"Guard selection can focus the battlefield")
		world.set_zoom(8.0)
		world._camera=world.size*0.5-(position-Vector2(0,4.25))*world.zoom
		world.queue_redraw()
		await settle()
		check(world._reserved_people.has(key) and world._reserved_people[key].position.distance_to(position)<0.01,"Zooming a guard keeps the same identity in the same formation slot")
		var target=(position-Vector2(0,4.25))*world.zoom+world._camera
		check(world._pick_person(target)==key,"A battlefield guard has a working individual hit target")
	world.set_zoom(1.6)
	world.center_on_tile(30,24)
	await settle()
	verify_people("Atlas")
	sim.state.wars=[]
	world.invalidate_terrain()
	await settle()
	check(world._reserved_people.values().all(func(item):return item.context!="war"),"Ended wars immediately release their representative guards")
	world.queue_free()
	await process_frame
	print("PICTURED PEOPLE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
