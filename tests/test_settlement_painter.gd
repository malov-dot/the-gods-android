extends SceneTree

const Painter = preload("res://scripts/settlement_painter.gd")
const Content = preload("res://scripts/content.gd")

class DrawingProbe:
	extends RefCounted
	var marks = 0
	var invalid_geometry = false
	var land = true
	func _is_land(_x,_y): return land
	func draw_rect(rect:Rect2,_color,_filled=true,_width=-1.0,_antialiased=false):
		marks += 1
		invalid_geometry = invalid_geometry or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<=0 or rect.size.y<=0
	func draw_line(a:Vector2,b:Vector2,_color,_width=-1.0,_antialiased=false):
		marks += 1
		invalid_geometry = invalid_geometry or not a.is_finite() or not b.is_finite()
	func draw_colored_polygon(points,_color,_uvs=PackedVector2Array(),_texture=null):
		marks += 1
		for point in points: invalid_geometry = invalid_geometry or not point.is_finite()

class OwnershipProbe:
	extends DrawingProbe
	var owned=true
	func _detail_owns_position(_town,_point,_margin=0.0): return owned

class Gallery:
	extends Control
	var painter = Painter.new()
	func _is_land(_x,_y): return true
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("13272b"))
		for era in range(14):
			var origin=Vector2((era%7)*320,int(era/7)*355)
			draw_rect(Rect2(origin+Vector2(5,5),Vector2(310,345)),Color("66815d"))
			draw_string(ThemeDB.fallback_font,origin+Vector2(16,26),Content.ERAS[era].name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e9e3c7"))
			draw_set_transform(origin+Vector2(160,196),0,Vector2.ONE*3)
			var town={"id":14,"era":era,"population":450,"buildings":Content.ERA_BUILDINGS.slice(0,era+1)}
			painter.draw_ground(self,town,Vector2.ZERO,Color("dbb375"),2.0)
			var entries=painter.layout(town)
			entries.sort_custom(func(a,b): return a.position.y<b.position.y)
			for entry in entries: painter.draw_building(self,entry,town,Vector2.ZERO,Color("dbb375"),2.0)
			draw_set_transform(Vector2.ZERO)

class ProfiledWorld:
	extends "res://scripts/world_view.gd"
	var drawing_costs=[]
	var terrain_costs=[]
	var town_costs=[]
	func _draw():
		var start=Time.get_ticks_usec()
		super._draw()
		drawing_costs.append(Time.get_ticks_usec()-start)
	func _draw_close_terrain():
		var start=Time.get_ticks_usec()
		super._draw_close_terrain()
		terrain_costs.append(Time.get_ticks_usec()-start)
	func _draw_settlements():
		var start=Time.get_ticks_usec()
		super._draw_settlements()
		town_costs.append(Time.get_ticks_usec()-start)

var checks=0
var failures=0

func _initialize(): call_deferred("run")

func check(condition,message):
	checks+=1
	if not condition:
		failures+=1
		push_error(message)

func run():
	var painter=Painter.new()
	var probe=DrawingProbe.new()
	for era in range(14):
		var town={"id":27,"era":era,"population":500,"buildings":Content.ERA_BUILDINGS.slice(0,era+1)}
		var original=var_to_str(town)
		var entries=painter.layout(town)
		check(entries==painter.layout(town),"Era %d layout is stable"%era)
		check(entries.size()>=9 and entries.size()<=16,"Era %d has bounded representative buildings"%era)
		var slots=[]
		for entry in entries:
			check(not entry.position in slots,"Era %d has distinct plots"%era)
			slots.append(entry.position)
		for damage in [0.0,0.3,0.7,1.0]:
			town.visual_damage=damage
			town.plague=5 if damage>0 else 0
			town.drought=4 if damage>0 else 0
			var before=probe.marks
			painter.draw_ground(probe,town,Vector2(500,500),Color("cfad72"),1.3)
			for entry in entries: painter.draw_building(probe,entry,town,Vector2(500,500),Color("cfad72"),1.3)
			check(probe.marks>before,"Era %d damage %.1f draws"%[era,damage])
		town.erase("visual_damage")
		town.erase("plague")
		town.erase("drought")
		check(original==var_to_str(town),"Drawing never mutates simulation town")
		probe.land=false
		var before=probe.marks
		painter.draw_ground(probe,town,Vector2(500,500),Color("cfad72"),1.3)
		for entry in entries: painter.draw_building(probe,entry,town,Vector2(500,500),Color("cfad72"),1.3)
		check(probe.marks==before,"Submerged towns never draw surface buildings")
		probe.land=true
	check(not probe.invalid_geometry,"All era and damage geometry is finite and nonempty")
	var ownership=OwnershipProbe.new()
	var sample_town={"id":1,"era":13,"population":600,"buildings":Content.ERA_BUILDINGS.duplicate()}
	ownership.owned=false
	painter.draw_ground(ownership,sample_town,Vector2(500,500),Color("cfad72"),0.0)
	for entry in painter.layout(sample_town): painter.draw_building(ownership,entry,sample_town,Vector2(500,500),Color("cfad72"),0.0)
	check(ownership.marks==0,"Foreign-owned ground and plots are completely clipped")
	ownership.owned=true
	painter.draw_ground(ownership,sample_town,Vector2(500,500),Color("cfad72"),0.0)
	check(ownership.marks>0,"Owned plot ground remains visible")
	print("SETTLEMENT DETAIL: ",checks," checks; ",failures," failures")
	if "--benchmark" in OS.get_cmdline_user_args():
		var simulation=load("res://scripts/simulation.gd").new()
		simulation.new_world({"seed":"Architecture Performance","width":160,"height":100,"nations":10})
		var viewport=SubViewport.new()
		viewport.size=Vector2i(1600,960)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var world=ProfiledWorld.new()
		world.size=Vector2(1600,960)
		world.sim=simulation
		viewport.add_child(world)
		await process_frame
		await process_frame
		await process_frame
		for scale in [1.6,3.0,4.5,8.0]:
			world.set_zoom(scale)
			world.center_on_tile(80,50)
			await process_frame
			await process_frame
			world.drawing_costs.clear()
			world.terrain_costs.clear()
			world.town_costs.clear()
			for frame in range(30): await process_frame
			world.drawing_costs.sort()
			var total=0.0
			for cost in world.drawing_costs: total+=cost
			print("DRAW BENCH zoom ",world.zoom,": median ",world.drawing_costs[int(world.drawing_costs.size()/2)]/1000.0," ms; avg ",total/maxi(1,world.drawing_costs.size())/1000.0," ms; towns ",world.detail_towns_drawn)
			world.terrain_costs.sort()
			world.town_costs.sort()
			var terrain_median=0.0 if world.terrain_costs.is_empty() else world.terrain_costs[int(world.terrain_costs.size()/2)]/1000.0
			print("  terrain ",terrain_median," ms; settlements ",world.town_costs[int(world.town_costs.size()/2)]/1000.0," ms")
		viewport.queue_free()
		await process_frame
	if "--gallery" in OS.get_cmdline_user_args():
		var viewport=SubViewport.new()
		viewport.size=Vector2i(2240,710)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var gallery=Gallery.new()
		gallery.size=Vector2(2240,710)
		viewport.add_child(gallery)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image()
		if image:
			image.save_png("res://build/Architecture Detail.png")
			print("Saved build/Architecture Detail.png")
		viewport.queue_free()
	quit(1 if failures else 0)
