extends SceneTree

const Simulation=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")

class IdentityFixture:
	extends RefCounted
	var backend=Simulation.new()
	var state={}
	var individuals={}
	func setup():
		backend.new_world({"seed":"Touch identity acceptance","width":64,"height":48,"nations":2})
		state=backend.state
		for tile in state.tiles:
			tile.elevation=0.55
			tile.biome="grass"
			tile.forest=0.0
		state.terrain_revision+=1
		var town=state.settlements[0]
		town.x=32
		town.y=24
		town.era=5
		town.population=240.0
		state.settlements[1].x=5
		state.settlements[1].y=5
		for i in range(3):
			var key=["c:101","p:202","c:303"][i]
			individuals[key]={"key":key,"name":["Ari Brook","Mira Vale","Tarin Elm"][i],"alive":true,"settlement":town.id,"nation":town.nation,"location":"surface","role":["farmer","leader","scholar"][i],"portrait_seed":[1,47,78][i],"health":0.8}
	func get_settlement(id): return backend.get_settlement(id)
	func _at_war(a,b): return backend._at_war(a,b)
	func get_individual(key:String)->Dictionary: return individuals.get(key,{}).duplicate(true)
	func individual_keys(town_id:int,limit:int=24,selected_key:String="")->Array:
		var keys=[]
		for key in individuals:
			var person=individuals[key]
			if person.alive and person.location=="surface" and person.settlement==town_id: keys.append(key)
		var page=keys.slice(0,limit)
		if selected_key in keys and not selected_key in page:
			if page.size()>=limit: page.pop_back()
			page.append(selected_key)
		return page

var world
var sim
var tiles=[]
var people=[]
var checks=0
var failures=0

func _initialize(): call_deferred("run")

func check(value,message):
	checks+=1
	if not value:
		failures+=1
		push_error("TOUCH/PEOPLE: "+message)

func settle():
	await process_frame
	await process_frame
	await process_frame

func touch(index,position,pressed,canceled=false):
	var event=InputEventScreenTouch.new()
	event.index=index
	event.position=position
	event.pressed=pressed
	event.canceled=canceled
	world._gui_input(event)

func drag(index,position):
	var event=InputEventScreenDrag.new()
	event.index=index
	event.position=position
	world._gui_input(event)

func mouse(position,pressed=true,device=0):
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=position
	event.pressed=pressed
	event.device=device
	world._gui_input(event)

func clear_events():
	tiles.clear()
	people.clear()

func controlled_pick_target():
	var point=(world.size*0.5-world._camera)/world.zoom+Vector2(0,4.25)
	world._pictured_people=[{"position":point,"key":"c:101","name":"Ari Brook","depth":1}]
	world._person_occluders=[]
	return world.size*0.5

func run():
	sim=IdentityFixture.new()
	sim.setup()
	world=World.new()
	world.sim=sim
	world.size=Vector2(390,600)
	world.tile_clicked.connect(func(x,y,button):tiles.append(Vector3i(x,y,button)))
	world.person_clicked.connect(func(key):people.append(key))
	root.add_child(world)
	await settle()
	world.set_process(false)
	check(world.focus_person("c:101"),"Directory focus resolves a living person")
	await settle()
	check(world.zoom>=world.DETAIL_ZOOM,"Person focus enters street detail")
	var rendered=[]
	for person in world._pictured_people:
		rendered.append(person.key)
		var actual=sim.get_individual(person.key)
		check(not actual.is_empty() and actual.name==person.name and actual.portrait_seed==person.seed,"A displayed person has their actual identity and portrait")
	check("c:101" in rendered,"Selected directory resident is guaranteed on the street")
	var before=JSON.stringify(sim.state)
	world.people.citizens(world,sim.state.settlements[0],(Vector2(32,24)+Vector2.ONE*0.5)*8,10)
	check(before==JSON.stringify(sim.state),"Resolving and rendering identities never mutates simulation")
	check(not world.focus_person("c:missing"),"Unknown identity cannot be focused")
	sim.individuals["c:303"].alive=false
	check(not world.focus_person("c:303"),"Deceased person cannot be pictured or focused")
	sim.individuals["c:303"].alive=true
	world.active_power="inspect"
	world.set_zoom(3.0)
	var target=controlled_pick_target()
	check(world._pick_person(target+Vector2(18,0))=="c:101","A small person has a minimum 20-pixel touch target")
	check(world._pick_person(target+Vector2(22,0)).is_empty(),"Outside the touch target preserves map selection")
	var pos=world._pictured_people[0].position
	world._person_occluders=[{"depth":2,"rect":Rect2(pos-Vector2(4,9),Vector2(8,10))}]
	check(world._pick_person(target).is_empty(),"A roof drawn in front prevents selecting an occluded body")
	world._person_occluders[0].depth=0
	check(world._pick_person(target)=="c:101","Objects behind a person do not block selection")
	world._person_occluders=[]
	clear_events()
	mouse(target)
	mouse(target,false)
	check(people==["c:101"] and tiles.is_empty(),"Observe clicks the actual person before their settlement")
	clear_events()
	var double_click=InputEventMouseButton.new()
	double_click.button_index=MOUSE_BUTTON_LEFT
	double_click.pressed=true
	double_click.double_click=true
	double_click.position=target
	world._gui_input(double_click)
	check(world.zoom==4.5 and world.selected_person_key.is_empty(),"Double-click explicitly enters Streets even over a selectable person")
	check(tiles.size()==1 and people.is_empty(),"Town navigation emits one settlement inspection without opening a person")
	world.set_zoom(3.0)
	target=controlled_pick_target()
	clear_events()
	touch(4,target,true)
	check(people.is_empty() and tiles.is_empty(),"Touch-down never selects or casts")
	touch(4,target,false)
	check(people==["c:101"] and tiles.is_empty(),"Touch release selects one actual person")
	clear_events()
	world.active_power="fire"
	touch(7,target,true)
	drag(7,target+Vector2(5,3))
	touch(7,target+Vector2(5,3),false)
	check(tiles.size()==1 and people.is_empty(),"Small finger jitter casts one world power and never selects a person")
	clear_events()
	var old_camera=world._camera
	touch(2,target,true)
	drag(2,target+Vector2(35,20))
	touch(2,target+Vector2(35,20),false)
	check(world._camera.distance_to(old_camera)>20,"One-finger drag pans the world")
	check(tiles.is_empty() and people.is_empty(),"Dragging a selected power never casts")
	clear_events()
	var old_zoom=world.zoom
	var left=Vector2(120,300)
	var right=Vector2(220,300)
	var old_anchor=((left+right)*0.5-world._camera)/world.zoom
	touch(3,left,true)
	touch(9,right,true)
	drag(9,right+Vector2(50,0))
	check(is_equal_approx(world.zoom,old_zoom*1.5),"Pinch uses actual two-finger distance")
	var new_anchor=((left+right+Vector2(50,0))*0.5-world._camera)/world.zoom
	check(new_anchor.distance_to(old_anchor)<0.01,"Pinch preserves the world point beneath its moving midpoint")
	touch(3,left,false)
	drag(9,right+Vector2(65,10))
	touch(9,right+Vector2(65,10),false)
	check(tiles.is_empty() and world._touches.is_empty(),"Pinch and its remaining finger never end as a cast")
	touch(1,target,true)
	touch(1,target,false,true)
	check(tiles.is_empty() and world._touches.is_empty(),"A canceled finger cannot cast or leave a stuck gesture")
	touch(0,target,true)
	world.active_power="bless"
	touch(0,target,false)
	check(tiles.is_empty(),"Changing powers during a touch cancels its pending action")
	touch(0,target,true)
	touch(0,Vector2(-20,-20),false)
	check(tiles.is_empty(),"Releasing outside the map cannot cast")
	touch(0,target,true)
	world.cancel_touch_gesture()
	touch(0,target,false)
	check(tiles.is_empty(),"Focus loss or a sheet opening can cancel a pending gesture")
	mouse(target,true,-1)
	mouse(target,false,-1)
	check(tiles.is_empty(),"Touch-emulated mouse events cannot double-activate")
	touch(0,target,true)
	mouse(target,true)
	touch(0,target,false)
	check(tiles.size()==1,"A mouse event during touch cannot duplicate its cast")
	clear_events()
	mouse(target)
	mouse(target,false)
	check(tiles.size()==1,"Normal desktop click behavior is preserved")
	world.active_power="inspect"
	clear_events()
	target=controlled_pick_target()
	sim.individuals["c:101"].alive=false
	mouse(target)
	check(people.is_empty() and tiles.size()==1,"A stale rendered person who died is not selectable")
	sim.individuals["c:101"].alive=true
	sim.individuals["c:101"].location="orbit"
	check(world._pick_person(target).is_empty(),"Orbital residents cannot be picked on surface streets")
	check(world.focus_person("c:101"),"An orbital resident can still be focused from their directory")
	# A compact landscape phone still centers the exact selected pedestrian.
	sim.individuals["c:101"].location="surface"
	world.size=Vector2(844,260)
	world.focus_person("p:202")
	await settle()
	var selected_position=Vector2(INF,INF)
	for person in world._pictured_people:
		if person.key=="p:202": selected_position=(person.position-Vector2(0,4))*world.zoom+world._camera
	check(selected_position.is_finite() and Rect2(Vector2.ZERO,world.size).has_point(selected_position),"Landscape phone focus keeps the selected citizen visible")
	# Exercise Godot's actual viewport routing as well as the gesture unit paths.
	if true:
		var old_emulation=Input.emulate_mouse_from_touch
		var button=Button.new()
		button.position=Vector2(20,20)
		button.size=Vector2(160,60)
		button.text="Touch probe"
		root.add_child(button)
		var presses=[0]
		button.pressed.connect(func():presses[0]+=1)
		await settle()
		for enabled in [false,true]:
			Input.emulate_mouse_from_touch=enabled
			presses[0]=0
			clear_events()
			for down in [true,false]:
				var event=InputEventScreenTouch.new()
				event.position=Vector2(60,40)
				event.index=0
				event.pressed=down
				Input.parse_input_event(event)
				await process_frame
			check(presses[0]==1 and tiles.is_empty(),"Standard GUI button receives one native touch, emulation="+str(enabled))
		button.queue_free()
		await settle()
		world.active_power="fire"
		for enabled in [false,true]:
			Input.emulate_mouse_from_touch=enabled
			clear_events()
			world.cancel_touch_gesture()
			for down in [true,false]:
				var event=InputEventScreenTouch.new()
				event.position=Vector2(300,130)
				event.index=0
				event.pressed=down
				Input.parse_input_event(event)
				await process_frame
			check(tiles.size()==1,"Viewport routes one native map tap without duplicate casting, emulation="+str(enabled))
		Input.emulate_mouse_from_touch=old_emulation
	var real=Simulation.new()
	real.new_world({"seed":"Actual citizen picking","width":64,"height":48,"nations":2})
	if real.has_method("resident_page"):
		world.sim=real
		world.set_process(true)
		await settle()
		var town=real.state.settlements[0]
		var roster=real.resident_page(int(town.id),0,1)
		var last_page=real.resident_page(int(town.id),maxi(0,int(roster.total)-1),1)
		var actual=last_page.people[0]
		check(world.focus_person(str(actual.key)),"A real resident outside the usual visible sample can be focused")
		world.set_process(false)
		await settle()
		var actual_keys=[]
		for person in world._pictured_people:
			actual_keys.append(str(person.key))
			var resolved=real.get_individual(str(person.key))
			check(not resolved.is_empty() and resolved.alive and resolved.location=="surface","Every real street sprite resolves to a living surface identity")
		check(str(actual.key) in actual_keys,"Focus guarantees a real directory resident is rendered")
	world.queue_free()
	await process_frame
	print("TOUCH AND PEOPLE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
