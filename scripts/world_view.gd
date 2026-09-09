extends Control
## A self-contained illustrated, pixel-scale atlas of the living simulation.

signal tile_clicked(x: int, y: int, button: int)
signal tile_hovered(x: int, y: int)
signal person_clicked(key: String)

const PersonFeedback=preload("res://scripts/person_interventions.gd")
const TILE = 8.0
const WATER_LEVEL = 0.36
const DRAG_PAINT_POWERS = ["land", "water", "mountain", "forest", "fertility", "ore", "warm", "cool"]
const INK = Color("172c31")
const PALE = Color("e7d6a1")
const Architecture = preload("res://scripts/settlement_painter.gd")
const People = preload("res://scripts/people_painter.gd")
const Calamities = preload("res://scripts/calamity_painter.gd")
const Content = preload("res://scripts/content.gd")
const Transport = preload("res://scripts/world_transport.gd")
const DETAIL_ZOOM = 3.0
const MAX_ZOOM = 12.0
const TOUCH_DRAG_SLOP = 10.0
const PERSON_TARGET_RADIUS = 20.0

var architecture = Architecture.new()
var people = People.new()
var transport = Transport.new()
var calamities = Calamities.new()
var detail_towns_drawn = 0
var detail_people_drawn = 0

var sim = null
var overlay = "terrain"
var selected_id = -1
var selected_person_key: String = ""
var brush_radius = 3
var active_power = "inspect"
var zoom = 1.0

var _camera = Vector2.ZERO
var _camera_initialized = false
var _camera_seed = ""
var _last_size = Vector2.ZERO
var _time = 0.0
var _terrain_key = ""
var _terrain_texture: ImageTexture
var _terrain_image: Image
var _tile_signatures = PackedInt64Array()
var _overlay_texture: ImageTexture
var _overlay_key = ""
var _shore_points = []
var _sea_points = []
var _cloud_points = []
var _panning = false
var _painting = false
var _last_painted = Vector2i(-999, -999)
var _hover = Vector2i(-1, -1)
var _mouse_inside = false
var _font: Font
var _roads = []
var _roads_key = ""
var _nation_colors = {}
var _nation_belief = {}
var _nation_era = {}
var _borders = {}
var _ellipse_textures = {}
var _detail_neighbors = {}
var _pictured_people = []
var _person_occluders = []
var _draw_depth_index = 0
var _reserved_people = {}
var _trade_assigned_people = {}
var _touches = {}
var _touch_primary = -1
var _touch_start = Vector2.ZERO
var _touch_dragged = false
var _touch_multitouch = false
var _touch_start_power = ""
var _last_touch_msec = -100000
var cast_feedback=[]

func show_cast_feedback(id:String,x:int,y:int,radius:int,label_:String,person:String="",queued:bool=false,failed:bool=false):
	cast_feedback=cast_feedback.filter(func(e):return not (e.x==x and e.y==y and e.id==id and e.queued))
	cast_feedback.append({"id":id,"x":x,"y":y,"radius":radius,"label":label_,"person":person,"queued":queued,"failed":failed,"age":0.0,"duration":8.0 if queued or not person.is_empty() else 4.0,"sim":sim,"epoch":sim.generation})
	if cast_feedback.size()>16: cast_feedback.pop_front()
	queue_redraw()


func _ready():
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	mouse_entered.connect(func(): _mouse_inside = true)
	mouse_exited.connect(func():
		_mouse_inside = false
		_hover = Vector2i(-1, -1)
		tile_hovered.emit(-1, -1)
	)
	resized.connect(_on_resize)
	if get_window()!=null: get_window().focus_exited.connect(cancel_touch_gesture)


func _process(delta):
	_time += minf(delta, 0.1)
	for effect in cast_feedback: effect.age+=delta
	cast_feedback=cast_feedback.filter(func(e):return e.age<e.duration and e.sim==sim and e.epoch==sim.generation)
	if sim == null or sim.state.is_empty():
		queue_redraw()
		return
	var key = str(sim.state.get("seed", "")) + ":" + str(sim.state.get("width", 0)) + ":" + str(sim.state.get("height", 0))
	if key != _camera_seed:
		cancel_touch_gesture()
		_camera_seed = key
		invalidate_terrain()
		reset_camera()
	if not _camera_initialized and size.x > 30 and size.y > 30:
		reset_camera()
	if _panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_panning = false
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_painting = false
	# Keyboard navigation also works when the map has focus.
	if has_focus():
		var movement = Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x += 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x -= 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y += 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y -= 1
		_camera += movement * 440.0 * delta
		if movement != Vector2.ZERO: _clamp_camera()
	queue_redraw()


func reset_camera():
	if sim == null or sim.state.is_empty() or size.x < 1 or size.y < 1:
		_camera_initialized = false
		return
	var world_size = Vector2(sim.state.get("width", 160), sim.state.get("height", 100)) * TILE
	zoom = clampf(minf(size.x / world_size.x, size.y / world_size.y) * 0.97, 0.15, MAX_ZOOM)
	_camera = (size - world_size * zoom) * 0.5
	_last_size = size
	_camera_initialized = true


func invalidate_terrain():
	_terrain_key = ""
	_overlay_key = ""
	_roads_key = ""
	queue_redraw()

func frame_world():
	# Begin close enough to fill the display; explicit Fit still shows all borders.
	reset_camera()
	if sim==null or sim.state.is_empty(): return
	_camera_seed=str(sim.state.get("seed",""))+":"+str(sim.state.width)+":"+str(sim.state.height)
	var dimensions=Vector2(sim.state.width,sim.state.height)*TILE
	zoom=clampf(maxf(size.x/dimensions.x,size.y/dimensions.y),0.15,MAX_ZOOM)
	_camera=(size-dimensions*zoom)*0.5
	queue_redraw()


func center_on_tile(x, y):
	_camera = size * 0.5 - Vector2(float(x) + 0.5, float(y) + 0.5) * TILE * zoom
	_clamp_camera()
	queue_redraw()


func set_zoom(value):
	_zoom_at(float(value), size * 0.5)

func focus_settlement(id, street = true):
	var town = sim.get_settlement(int(id)) if sim != null else {}
	if town.is_empty(): return
	selected_id = int(id)
	if street: set_zoom(4.5)
	center_on_tile(town.x, town.y)


func focus_person(key: String) -> bool:
	if sim == null or not sim.has_method("get_individual"): return false
	var individual = sim.get_individual(key)
	if individual.is_empty() or not individual.get("alive",false): return false
	var town = sim.get_settlement(int(individual.get("settlement",-1)))
	if town.is_empty(): return false
	selected_person_key = str(individual.get("key",key))
	selected_id = int(town.id)
	set_zoom(maxf(4.5,zoom))
	if _reserved_people.has(selected_person_key):
		_camera=size*0.5-(_reserved_people[selected_person_key].position-Vector2(0,4))*zoom
		_clamp_camera()
		queue_redraw()
		return true
	center_on_tile(town.x,town.y)
	var center = (Vector2(town.x,town.y)+Vector2.ONE*0.5)*TILE
	if individual.get("location","surface") == "orbit":
		var station = center+Vector2(42,-48) if float(town.get("population",0))>0 or _is_land(int(town.x),int(town.y)) else center
		_camera = size*0.5-station*zoom
	else:
		for person in people.citizens(self,town,center,_time):
			if str(person.get("key",""))==selected_person_key:
				_camera = size*0.5-(person.position-Vector2(0,4))*zoom
				break
	_clamp_camera()
	queue_redraw()
	return true


func _zoom_at(value, pivot):
	var old_zoom = zoom
	zoom = clampf(value, 0.15, MAX_ZOOM)
	_camera = pivot - (pivot - _camera) * (zoom / maxf(0.001, old_zoom))
	_clamp_camera()
	if is_inside_tree(): _update_hover(get_local_mouse_position())
	queue_redraw()


func _clamp_camera():
	if sim == null: return
	var world_size = Vector2(sim.state.get("width", 160), sim.state.get("height", 100)) * TILE * zoom
	var margin = size * 0.28
	_camera.x = clampf(_camera.x, -world_size.x + margin.x, size.x - margin.x)
	_camera.y = clampf(_camera.y, -world_size.y + margin.y, size.y - margin.y)


func _on_resize():
	if _camera_initialized:
		_camera += (size - _last_size) * 0.5
		_last_size = size
	else:
		reset_camera()


func _gui_input(event):
	if sim == null or sim.state.is_empty(): return
	if event is InputEventScreenTouch:
		_handle_touch(event)
		accept_event()
		return
	if event is InputEventScreenDrag:
		_handle_touch_drag(event)
		accept_event()
		return
	if event is InputEventMouseButton:
		# Godot marks mouse events generated from touch with device -1. Native
		# touch is handled above; acting on its emulated mouse would cast twice.
		if event.device == -1 or not _touches.is_empty():
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(zoom * 1.16, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(zoom / 1.16, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
			if event.pressed: grab_focus()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_painting = event.pressed
			if event.pressed:
				grab_focus()
				_last_painted = Vector2i(-999, -999)
				if event.double_click and active_power=="inspect" and _focus_clicked_settlement(event.position):
					accept_event()
					return
				_activate_pointer(event.position)
			accept_event()
	elif event is InputEventMouseMotion:
		if event.device == -1 or not _touches.is_empty(): return
		if _panning:
			_camera += event.relative
			_clamp_camera()
		_update_hover(event.position)
		if _painting and not _panning and sim.state.get("mode", "sandbox") == "sandbox" and active_power in DRAG_PAINT_POWERS:
			_emit_paint()
		accept_event()
	elif event is InputEventMagnifyGesture:
		if _touches.is_empty(): _zoom_at(zoom * event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		if _touches.is_empty():
			_camera -= event.delta * 18.0
			_clamp_camera()
		accept_event()


func _handle_touch(event: InputEventScreenTouch):
	_last_touch_msec = Time.get_ticks_msec()
	var index = int(event.index)
	if event.pressed and not event.canceled:
		if _touches.is_empty():
			_touch_primary = index
			_touch_start = event.position
			_touch_dragged = false
			_touch_multitouch = false
			_touch_start_power = active_power
			_painting = false
			_panning = false
			_mouse_inside = true
			_update_hover(event.position)
			queue_redraw()
			grab_focus()
		_touches[index] = event.position
		if _touches.size()>1:
			_touch_multitouch = true
			_touch_dragged = true
		return
	if not _touches.has(index): return
	var tap = not event.canceled and not _touch_dragged and not _touch_multitouch
	tap = tap and index == _touch_primary and event.position.distance_to(_touch_start)<=TOUCH_DRAG_SLOP
	tap = tap and active_power==_touch_start_power and Rect2(Vector2.ZERO,size).has_point(event.position)
	_touches.erase(index)
	if _touches.is_empty():
		_touch_primary = -1
		_touch_dragged = false
		_touch_multitouch = false
		if tap:
			_last_painted = Vector2i(-999,-999)
			_activate_pointer(event.position)
	else:
		_touch_primary = int(_touches.keys()[0])
		# Remaining fingers can pan, but a pinch can never finish as a tap.
		_touch_dragged = true
		_touch_multitouch = true
	queue_redraw()


func _handle_touch_drag(event: InputEventScreenDrag):
	var index = int(event.index)
	if not _touches.has(index): return
	_last_touch_msec = Time.get_ticks_msec()
	var previous: Vector2 = _touches[index]
	if _touches.size()>=2:
		var indices = _touches.keys()
		var a: Vector2 = _touches[indices[0]]
		var b: Vector2 = _touches[indices[1]]
		var old_midpoint = (a+b)*0.5
		var old_distance = a.distance_to(b)
		_touches[index] = event.position
		a = _touches[indices[0]]
		b = _touches[indices[1]]
		var midpoint = (a+b)*0.5
		var anchor = (old_midpoint-_camera)/zoom
		if old_distance>2.0:
			zoom = clampf(zoom*a.distance_to(b)/old_distance,0.15,MAX_ZOOM)
		_camera = midpoint-anchor*zoom
		_touch_multitouch = true
		_touch_dragged = true
	else:
		_touches[index] = event.position
		if not _touch_dragged and event.position.distance_to(_touch_start)>TOUCH_DRAG_SLOP:
			_touch_dragged = true
			_camera += event.position-_touch_start
		elif _touch_dragged:
			_camera += event.position-previous
	_clamp_camera()
	queue_redraw()


func cancel_touch_gesture():
	_touches.clear()
	_touch_primary = -1
	_touch_dragged = false
	_touch_multitouch = false
	_painting = false
	_panning = false


func _focus_clicked_settlement(position:Vector2) -> bool:
	# Double-click is explicit town navigation; a citizen's generous hit target
	# must not prevent entering Streets. Ordinary clicks still prefer people.
	var tile=((position-_camera)/(TILE*zoom)).floor()
	if not _valid_tile(int(tile.x),int(tile.y)): return false
	var nearest={}
	var distance=8.0
	for town in sim.state.get("settlements",[]):
		if _living_population(town)<=0: continue
		var separation=tile.distance_to(Vector2(town.get("x",0),town.get("y",0)))
		if separation<=distance:
			distance=separation
			nearest=town
	if nearest.is_empty(): return false
	selected_person_key=""
	selected_id=int(nearest.id)
	# Emit the inspected town's anchor so the surrounding interface follows the
	# same choice, without relying on a previously selected settlement.
	tile_clicked.emit(int(nearest.x),int(nearest.y),MOUSE_BUTTON_LEFT)
	focus_settlement(int(nearest.id))
	return true


func _activate_pointer(position: Vector2) -> bool:
	_update_hover(position)
	if active_power == "inspect":
		var key = _pick_person(position)
		if not key.is_empty():
			selected_person_key = key
			person_clicked.emit(key)
			queue_redraw()
			return true
		selected_person_key = ""
	_emit_paint()
	return false


func _pick_person(position: Vector2) -> String:
	if active_power != "inspect": return ""
	var result = ""
	var best_distance = INF
	for person in _pictured_people:
		var key = str(person.get("key",""))
		if key.is_empty(): continue
		if sim != null and sim.has_method("get_individual"):
			var current = sim.get_individual(key)
			if current.is_empty() or not current.get("alive",false) or current.get("location","surface")!="surface": continue
		var height=float(person.get("height",8.5))
		var center: Vector2 = (person.position-Vector2(0,height*0.5))*zoom+_camera
		var target_size = Vector2(maxf(PERSON_TARGET_RADIUS*2,6*zoom),maxf(PERSON_TARGET_RADIUS*2,height*zoom))
		if not Rect2(center-target_size*0.5,target_size).has_point(position): continue
		var hidden = false
		var world_point = (position-_camera)/zoom
		for blocker in _person_occluders:
			if int(blocker.depth)>int(person.get("depth",0)) and blocker.rect.has_point(world_point):
				hidden = true
				break
		if hidden: continue
		var distance = center.distance_squared_to(position)
		if distance<=best_distance:
			best_distance=distance
			result=key
	return result


func _update_hover(position):
	var point = (position - _camera) / (TILE * zoom)
	var tile = Vector2i(floori(point.x), floori(point.y))
	if not _valid_tile(tile.x, tile.y): tile = Vector2i(-1, -1)
	if tile != _hover:
		_hover = tile
		tile_hovered.emit(tile.x, tile.y)


func _emit_paint():
	if _hover.x < 0 or _hover == _last_painted: return
	_last_painted = _hover
	tile_clicked.emit(_hover.x, _hover.y, MOUSE_BUTTON_LEFT)


func _valid_tile(x, y):
	return sim != null and x >= 0 and y >= 0 and x < sim.state.get("width", 0) and y < sim.state.get("height", 0)


func _tile(x, y):
	if not _valid_tile(x, y): return {}
	var index = int(y) * int(sim.state.get("width", 0)) + int(x)
	var tiles = sim.state.get("tiles", [])
	return tiles[index] if index < tiles.size() else {}


func _is_land(x, y):
	return float(_tile(x, y).get("elevation", 0.0)) >= WATER_LEVEL


func _hash(x, y, salt = 0):
	var value = int(x) * 92837111 + int(y) * 689287499 + int(salt) * 283923481
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16)) % 1000003


func _noise(x, y, salt = 0):
	return float(_hash(x, y, salt) % 1000) / 999.0


func _draw():
	_pictured_people.clear()
	_person_occluders.clear()
	_reserved_people.clear()
	_trade_assigned_people.clear()
	_draw_depth_index = 0
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1b25"))
	_draw_background()
	if sim == null or sim.state.is_empty() or sim.state.get("tiles", []).is_empty(): return
	_refresh_cache()
	if _terrain_texture == null: return
	var world_size = Vector2(sim.state.get("width", 160), sim.state.get("height", 100)) * TILE
	draw_set_transform(_camera.round(), 0.0, Vector2.ONE * zoom)
	draw_rect(Rect2(Vector2(-3, -3), world_size + Vector2(6, 6)), Color("395252"), false, 1.0 / zoom)
	draw_texture(_terrain_texture, Vector2.ZERO)
	if _overlay_texture != null and overlay != "terrain":
		draw_texture_rect(_overlay_texture, Rect2(Vector2.ZERO, world_size), false)
	_draw_waters()
	if zoom >= DETAIL_ZOOM: _draw_close_terrain()
	_draw_borders()
	people.high_detail=zoom>=6.0
	people.prepare_wars(self,sim,_time,zoom)
	_draw_roads()
	_draw_settlements()
	_draw_artifacts()
	_draw_effects()
	_draw_wars()
	transport.draw(self,_time)
	_draw_agents()
	_draw_clouds()
	_draw_selection()
	_draw_brush()
	draw_set_transform(Vector2.ZERO)
	_draw_labels()
	_draw_selected_person_label()
	_draw_cartography(world_size)
	preload("res://scripts/cast_visuals.gd").draw(self)


func _draw_background():
	for i in range(45):
		var p = Vector2(_noise(i, 24) * size.x, _noise(i, 86) * size.y)
		var alpha = 0.06 + 0.08 * (0.5 + 0.5 * sin(_time * 0.4 + i))
		draw_rect(Rect2(p, Vector2.ONE), Color(0.66, 0.79, 0.74, alpha))
	# Quiet etched lines frame the ocean when the entire atlas is visible.
	for i in range(1, 8):
		var yy = size.y * float(i) / 8.0
		draw_line(Vector2(0, yy), Vector2(size.x, yy), Color(0.22, 0.40, 0.46, 0.07), 1.0)


func _refresh_cache():
	var state = sim.state
	var key = str(state.get("seed", "")) + ":" + str(state.get("terrain_revision", 0)) + ":" + str(state.get("width", 0)) + ":" + str(state.get("height", 0))
	if key != _terrain_key:
		_rebuild_terrain()
		_terrain_key = key
		_overlay_key = ""
	var year = int(state.get("year", 0))
	var road_key = str(year / 5) + ":" + str(state.get("settlements", []).size()) + ":" + str(state.get("terrain_revision", 0))+":"+str(state.get("wars",[]).size())
	if road_key != _roads_key:
		_build_roads()
		_roads_key = road_key
	var overlay_key = overlay + ":" + str(year) + ":" + str(state.get("terrain_revision", 0))
	if overlay_key != _overlay_key:
		_build_overlay()
		_overlay_key = overlay_key


func _rebuild_terrain():
	var width = int(sim.state.get("width", 160))
	var height = int(sim.state.get("height", 100))
	var full_rebuild = _terrain_image == null or _terrain_image.get_width() != width * int(TILE) or _terrain_image.get_height() != height * int(TILE)
	var min_x = width
	var min_y = height
	var max_x = -1
	var max_y = -1
	if _tile_signatures.size() != width * height:
		_tile_signatures.resize(width * height)
		full_rebuild = true
	# Ownership revisions are common. Comparing the visual fields avoids redrawing
	# the entire atlas when a border changes, and confines brush work to its area.
	var tiles = sim.state.get("tiles", [])
	for index in range(tiles.size()):
		var t = tiles[index]
		var signature = hash(Vector4(float(t.get("elevation", 0)), float(t.get("forest", 0)), float(t.get("moisture", 0)), float(t.get("ore", 0)))) ^ hash(t.get("biome", "ocean"))
		if full_rebuild or signature != _tile_signatures[index]:
			_tile_signatures[index] = signature
			var x = index % width
			var y = int(index / width)
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if max_x < 0: return
	min_x = maxi(0, min_x - 2)
	min_y = maxi(0, min_y - 2)
	max_x = mini(width - 1, max_x + 2)
	max_y = mini(height - 1, max_y + 2)
	if full_rebuild:
		_terrain_image = Image.create(width * int(TILE), height * int(TILE), false, Image.FORMAT_RGBA8)
		_terrain_image.fill(Color("164858"))
		_shore_points.clear()
		_sea_points.clear()
		_cloud_points.clear()
	else:
		var changed = Rect2(Vector2(min_x, min_y) * TILE, Vector2(max_x - min_x + 1, max_y - min_y + 1) * TILE)
		_shore_points = _shore_points.filter(func(point): return not changed.has_point(point))
		_sea_points = _sea_points.filter(func(point): return not changed.has_point(point))
	var art = _terrain_image
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var tile = _tile(x, y)
			var elevation = float(tile.get("elevation", 0.0))
			var biome = str(tile.get("biome", "ocean"))
			var moisture = float(tile.get("moisture", 0.5))
			var base = Color("76a05c")
			var n = _noise(x, y, 4)
			var px = x * int(TILE)
			var py = y * int(TILE)
			if elevation < WATER_LEVEL:
				base = Color("123849").lerp(Color("237b86"), clampf(elevation / WATER_LEVEL, 0.0, 1.0))
				if _is_land(x - 1, y) or _is_land(x + 1, y) or _is_land(x, y - 1) or _is_land(x, y + 1):
					base = base.lerp(Color("52a5a0"), 0.43)
					if _hash(x, y) % 3 == 0: _shore_points.append(Vector2(px + 4, py + 4))
				base = base.lightened(n * 0.035)
				art.fill_rect(Rect2i(px, py, 8, 8), base)
				if n > 0.65:
					art.fill_rect(Rect2i(px + 1, py + 2 + _hash(x, y, 2) % 4, 3, 1), base.lightened(0.045))
				if _hash(x, y, 2) % 67 == 0: _sea_points.append(Vector2(px, py))
				continue
			match biome:
				"coast": base = Color("c7c088").lerp(Color("90ad68"), moisture * 0.65)
				"grass": base = Color("91ae62").lerp(Color("5f975d"), moisture)
				"forest": base = Color("52825a").lerp(Color("387454"), moisture)
				"desert": base = Color("c5a16a").lerp(Color("dcc18a"), n * 0.55)
				"mountain": base = Color("7c8a79").lerp(Color("9b9d83"), n * 0.5)
				"snow": base = Color("c5d9d5").lerp(Color("e4e9dc"), n * 0.7)
				"marsh": base = Color("4c8776").lerp(Color("769877"), n)
				_: base = Color("8aaa67").lerp(Color("629a61"), moisture)
			base = base.lightened((n - 0.5) * 0.12)
			art.fill_rect(Rect2i(px, py, 8, 8), base)
			# Tiny irregular patches prevent the map reading as a checkerboard.
			for k in range(3):
				var xx = px + _hash(x, y, k + 19) % 7
				var yy = py + _hash(x, y, k + 34) % 7
				art.fill_rect(Rect2i(xx, yy, 2, 1), base.lightened(0.055 if k % 2 == 0 else -0.075))
			if biome == "desert":
				if n > 0.60:
					art.fill_rect(Rect2i(px + 1, py + 4, 5, 1), base.darkened(0.12))
					art.fill_rect(Rect2i(px + 2, py + 3, 3, 1), base.lightened(0.12))
			elif biome == "marsh":
				art.fill_rect(Rect2i(px + 1, py + 3, 4, 2), Color("448983"))
				art.fill_rect(Rect2i(px + 5, py + 1, 1, 3), Color("3e6b54"))
			elif biome == "snow" and n > 0.65:
				art.fill_rect(Rect2i(px + 2, py + 3, 3, 1), Color("a6c4c7"))
			# Sand, wet sand, and a bright sea-facing rim define every coast.
			if elevation < 0.60:
				var sand = Color("d5cd9b")
				if not _is_land(x - 1, y):
					art.fill_rect(Rect2i(px, py, 2, 8), sand)
					art.fill_rect(Rect2i(px, py, 1, 8), Color("a9c6b0"))
				if not _is_land(x + 1, y):
					art.fill_rect(Rect2i(px + 6, py, 2, 8), sand)
					art.fill_rect(Rect2i(px + 7, py, 1, 8), Color("a9c6b0"))
				if not _is_land(x, y - 1):
					art.fill_rect(Rect2i(px, py, 8, 2), sand)
					art.fill_rect(Rect2i(px, py, 8, 1), Color("bed0b5"))
				if not _is_land(x, y + 1):
					art.fill_rect(Rect2i(px, py + 6, 8, 2), sand)
					art.fill_rect(Rect2i(px, py + 7, 8, 1), Color("a4bf9f"))
	# Decoration pass overlaps the terrain naturally, like an illustrated atlas.
	for y in range(maxi(1, min_y - 1), mini(height - 1, max_y + 2)):
		for x in range(maxi(1, min_x - 1), mini(width - 1, max_x + 2)):
			var tile = _tile(x, y)
			if float(tile.get("elevation", 0)) < WATER_LEVEL: continue
			var biome = str(tile.get("biome", "grass"))
			var n = _noise(x, y, 9)
			var px = x * int(TILE)
			var py = y * int(TILE)
			if biome == "mountain" or (biome == "snow" and float(tile.get("elevation", 0)) > 0.72):
				if n > 0.2: _pixel_mountain(art, px + 3, py + 6, 6 + _hash(x, y, 11) % 5, biome == "snow" or float(tile.get("elevation", 0)) > 0.82)
			elif float(tile.get("forest", 0)) > n * 1.1 and biome != "desert":
				_pixel_tree(art, px + 1 + _hash(x, y, 41) % 4, py + 4 + _hash(x, y, 42) % 4, _hash(x, y, 11) % 3, biome == "snow")
				if float(tile.get("forest", 0)) > 0.6 and n > 0.25: _pixel_tree(art, px + 4 + _hash(x, y, 43) % 3, py + 2 + _hash(x, y, 44) % 3, _hash(x, y, 12) % 3, biome == "snow")
			elif biome == "grass" and n > 0.985:
				art.set_pixel(px + 4, py + 3, Color("e2d88e"))
				art.set_pixel(px + 2, py + 5, Color("d4b0a0"))
			elif float(tile.get("ore", 0)) > 0.76 and n > 0.70:
				art.fill_rect(Rect2i(px + 2, py + 3, 3, 2), Color("77817a"))
				art.fill_rect(Rect2i(px + 2, py + 3, 2, 1), Color("b3b498"))
	if _terrain_texture == null or full_rebuild:
		_terrain_texture = ImageTexture.create_from_image(art)
	else:
		_terrain_texture.update(art)
	if _cloud_points.is_empty():
		for i in range(9):
			_cloud_points.append(Vector2(_noise(i, 401) * width * TILE, _noise(i, 913) * height * TILE))


func _pixel_tree(art, x, y, kind, snow):
	# Pine or broadleaf silhouettes with a deep underside and lit upper edge.
	art.fill_rect(Rect2i(x - 2, y, 5, 2), Color("36624e"))
	art.fill_rect(Rect2i(x, y - 2, 1, 3), Color("655540"))
	var dark = Color("285e4b")
	var mid = Color("397957")
	var light = Color("5c9766")
	if snow:
		dark = Color("668d8a")
		mid = Color("a8c9be")
		light = Color("d5e4d4")
	if kind == 0:
		art.fill_rect(Rect2i(x - 2, y - 2, 5, 1), dark)
		art.fill_rect(Rect2i(x - 1, y - 5, 3, 3), mid)
		art.fill_rect(Rect2i(x, y - 7, 1, 4), light)
		art.fill_rect(Rect2i(x - 2, y - 3, 3, 1), mid)
	else:
		art.fill_rect(Rect2i(x - 2, y - 4, 5, 3), dark)
		art.fill_rect(Rect2i(x - 2, y - 5, 4, 3), mid)
		art.fill_rect(Rect2i(x - 1, y - 6, 3, 2), light)
		if kind == 2: art.set_pixel(x - 2, y - 4, Color("80a667") if not snow else light)


func _pixel_mountain(art, x, y, peak_height, snow):
	for row in range(peak_height):
		var half_width = int(row * 0.65) + 1
		var left = Color("a4a897")
		var right = Color("687d79")
		if snow and row < peak_height * 0.47:
			left = Color("e5e9d9")
			right = Color("b3cfcc")
		art.fill_rect(Rect2i(x - half_width, y - peak_height + row, half_width, 1), left)
		art.fill_rect(Rect2i(x, y - peak_height + row, half_width + 1, 1), right)
	art.fill_rect(Rect2i(x - 3, y, 8, 1), Color("5a7863"))


func _build_overlay():
	_nation_colors.clear()
	_nation_belief.clear()
	_nation_era.clear()
	_borders.clear()
	for nation in sim.state.get("nations", []):
		_nation_colors[int(nation.get("id", -1))] = Color(str(nation.get("color", "bba46f")))
	var counts = {}
	for town in sim.state.get("settlements", []):
		var nation = int(town.get("nation", -1))
		var pop = maxf(1.0, _living_population(town))
		var belief = Vector2(float(town.get("faith", 0)), float(town.get("corruption", 0)))
		_nation_belief[nation] = _nation_belief.get(nation, Vector2.ZERO) + belief * pop
		_nation_era[nation] = float(_nation_era.get(nation, 0)) + float(town.get("era", 0)) * pop
		counts[nation] = float(counts.get(nation, 0)) + pop
	for nation in counts:
		_nation_belief[nation] /= counts[nation]
		_nation_era[nation] /= counts[nation]
	if overlay == "terrain":
		_overlay_texture = null
		return
	var width = int(sim.state.get("width", 160))
	var height = int(sim.state.get("height", 100))
	var art = Image.create(width, height, false, Image.FORMAT_RGBA8)
	art.fill(Color.TRANSPARENT)
	for y in range(height):
		for x in range(width):
			var tile = _tile(x, y)
			if float(tile.get("elevation", 0)) < WATER_LEVEL: continue
			var nation = int(tile.get("owner", -1))
			var color = Color.TRANSPARENT
			match overlay:
				"nations":
					color = _nation_colors.get(nation, Color("9b9f91"))
					color.a = 0.35 if nation >= 0 else 0.10
					if nation >= 0:
						if not _borders.has(nation): _borders[nation] = []
						if _is_land(x + 1, y) and int(_tile(x + 1, y).get("owner", -1)) != nation:
							_borders[nation].append(Vector2(x + 1, y) * TILE)
							_borders[nation].append(Vector2(x + 1, y + 1) * TILE)
						if _is_land(x, y + 1) and int(_tile(x, y + 1).get("owner", -1)) != nation:
							_borders[nation].append(Vector2(x, y + 1) * TILE)
							_borders[nation].append(Vector2(x + 1, y + 1) * TILE)
						if _is_land(x - 1, y) and int(_tile(x - 1, y).get("owner", -1)) < 0:
							_borders[nation].append(Vector2(x, y) * TILE)
							_borders[nation].append(Vector2(x, y + 1) * TILE)
						if _is_land(x, y - 1) and int(_tile(x, y - 1).get("owner", -1)) < 0:
							_borders[nation].append(Vector2(x, y) * TILE)
							_borders[nation].append(Vector2(x + 1, y) * TILE)
				"belief":
					var belief = _nation_belief.get(nation, Vector2(0.0, 0.0))
					color = Color("83a3a5")
					if belief.x > belief.y: color = color.lerp(Color("f6dc76"), clampf(belief.x * 1.5, 0, 1))
					else: color = color.lerp(Color("d46a92"), clampf(belief.y * 1.5, 0, 1))
					color.a = 0.42 if nation >= 0 else 0.12
				"fertility":
					color = Color("bd7953").lerp(Color("7cd18b"), clampf(float(tile.get("fertility", 0)), 0, 1))
					color.a = 0.50
				"technology":
					color = Color("dbac6c").lerp(Color("87c5ee"), clampf(float(_nation_era.get(nation, 0)) / 13.0, 0, 1))
					color.a = 0.43 if nation >= 0 else 0.1
			art.set_pixel(x, y, color)
	_overlay_texture = ImageTexture.create_from_image(art)
	for nation in _borders:
		_borders[nation] = PackedVector2Array(_borders[nation])


func _draw_borders():
	if overlay != "nations": return
	for nation in _borders:
		if _borders[nation].is_empty(): continue
		var color = _nation_colors.get(nation, PALE).lightened(0.23)
		color.a = 0.75
		draw_multiline(_borders[nation], color, 1.0, false)


func _draw_waters():
	for i in range(_sea_points.size()):
		var p = _sea_points[i]
		var phase = _time * 0.7 + i * 1.97
		var alpha = (0.5 + 0.5 * sin(phase)) * 0.20
		var shift = floorf(sin(phase * 0.4) * 2.0)
		draw_rect(Rect2(p + Vector2(shift, 2), Vector2(6, 1)), Color(0.50, 0.79, 0.78, alpha))
		draw_rect(Rect2(p + Vector2(shift + 2, 4), Vector2(3, 1)), Color(0.50, 0.79, 0.78, alpha * 0.7))
	for i in range(_shore_points.size()):
		var alpha = 0.06 + 0.14 * (0.5 + 0.5 * sin(_time * 1.6 + i * 1.71))
		draw_rect(Rect2(_shore_points[i] + Vector2(-2, 0), Vector2(4, 1)), Color(0.86, 0.92, 0.79, alpha))


func _build_roads():
	_roads.clear()
	var towns = sim.state.get("settlements", [])
	var used = {}
	for town in towns:
		if float(town.get("population", 0)) <= 0: continue
		var a = Vector2(town.get("x", 0), town.get("y", 0))
		var nearest = []
		for other in towns:
			if town.get("id", -1) == other.get("id", -2): continue
			if float(other.get("population",0))<=0: continue
			var b = Vector2(other.get("x", 0), other.get("y", 0))
			var dist = a.distance_to(b)
			if dist > 48 or dist < 1: continue
			nearest.append({"town": other, "dist": dist})
		nearest.sort_custom(func(one, two): return one.dist < two.dist)
		for entry in nearest.slice(0, mini(2, nearest.size())):
			var other = entry.town
			var first_id = mini(int(town.get("id", 0)), int(other.get("id", 0)))
			var last_id = maxi(int(town.get("id", 0)), int(other.get("id", 0)))
			var key = str(first_id) + ":" + str(last_id)
			if used.has(key): continue
			used[key] = true
			var b = Vector2(other.get("x", 0), other.get("y", 0))
			var points = PackedVector2Array()
			var is_water = false
			for i in range(17):
				var t = float(i) / 16.0
				var p = a.lerp(b, t)
				var normal = (b - a).orthogonal().normalized()
				p += normal * sin(t * PI) * sin(t * TAU + first_id) * 0.9
				if not _is_land(roundi(p.x), roundi(p.y)): is_water = true
				points.append((p + Vector2.ONE * 0.5) * TILE)
			_roads.append({"points": points,"town_a":int(town.id),"town_b":int(other.id), "water": is_water, "conflict":sim._at_war(int(town.nation),int(other.nation)), "era": mini(int(town.get("era", 0)), int(other.get("era", 0))), "color": _nation_colors.get(int(town.get("nation", -1)), Color("cbb275")), "seed": first_id + last_id})


func _draw_roads():
	for road in _roads:
		var points = road.points
		if road.water:
			if sim.state.has("transport"): continue
			# Routes over the ocean are represented by the voyagers themselves.
			if road.era >= 2 and not road.get("conflict",false):
				var t = fposmod(_time * 0.009 + float(road.seed) * 0.127, 1.0)
				var p = _route_position(points, t)
				if not _is_land(int(p.x / TILE), int(p.y / TILE)): _draw_ship(p, road.era, road.color)
			continue
		var shade = Color("9b9469") if road.era < 7 else Color("82978c")
		draw_polyline(points, shade.darkened(0.20), 2.5, false)
		draw_polyline(points, shade, 1.0, false)
		if road.era >= 9:
			for i in range(1, points.size(), 3):
				draw_rect(Rect2(points[i], Vector2(1, 1)), Color("d6d2a6"))
		if zoom >= 0.4 and not road.get("conflict",false):
			for i in range(2):
				var t = fposmod(_time * (0.013 if road.era < 8 else 0.035) + float(road.seed) * 0.137 + i * 0.45, 1.0)
				var p = _route_position(points, t)
				if road.era >= 8:
					if zoom>=DETAIL_ZOOM:
						_draw_close_car(p,road.color)
					else:
						draw_rect(Rect2(p + Vector2(-2, -1), Vector2(4, 2)), road.color.lightened(0.3))
				else:
					_draw_trade_person(p,road,i)


func _route_position(points, t):
	var span = t * (points.size() - 1)
	var index = mini(int(span), points.size() - 2)
	return points[index].lerp(points[index + 1], span - index)


func _draw_trade_person(p,road,index):
	if not sim.has_method("resident_page"):
		if not _visible(Rect2(p-Vector2(8,14),Vector2(16,18))): return
		_draw_person(p,road.color,index,road.era)
		return
	var town_id=int(road.get("town_a" if index==0 else "town_b",-1))
	for person in people.role_people(sim,town_id,"merchant",8):
		if _trade_assigned_people.has(str(person.key)): continue
		_trade_assigned_people[str(person.key)]=true
		if not _visible(Rect2(p-Vector2(8,14),Vector2(16,18))) or person_elsewhere(str(person.key)): return
		reserve_person(str(person.key),p,"trade")
		draw_identified_person(person,p,int(road.era),road.color,"merchant",1.0,_time*3+int(person.portrait_seed),"walking",DETAIL_ZOOM)
		return

func _draw_close_car(p, color):
	draw_rect(Rect2(p+Vector2(-5,-1),Vector2(10,4)),Color("293c3f"))
	for x in [-3,3]:
		draw_rect(Rect2(p+Vector2(x,-2),Vector2(1.5,1.5)),Color("253036"))
		draw_rect(Rect2(p+Vector2(x,3),Vector2(1.5,1.5)),Color("253036"))
	draw_rect(Rect2(p+Vector2(-5,-1.5),Vector2(10,4)),color)
	draw_rect(Rect2(p+Vector2(-2,-2.5),Vector2(5,4)),color.lightened(0.18))
	draw_rect(Rect2(p+Vector2(1,-2),Vector2(1.5,3)),Color("a4d1ce"))
	draw_rect(Rect2(p+Vector2(-1.5,-2),Vector2(1,3)),Color("78a8b0"))
	draw_rect(Rect2(p+Vector2(4.5,-1),Vector2(0.5,0.7)),Color("f0d891"))
	draw_rect(Rect2(p+Vector2(4.5,1.5),Vector2(0.5,0.7)),Color("f0d891"))

func _draw_close_ship(p,era,flag):
	p.y+=sin(_time*1.2+p.x)*0.35
	draw_polyline(PackedVector2Array([p+Vector2(-15,1),p+Vector2(-5,5),p+Vector2(9,3)]),Color(0.76,0.9,0.83,0.45),0.7)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-11,-2),p+Vector2(11,-2),p+Vector2(8,4),p+Vector2(-7,4)]),Color("62513f"))
	draw_rect(Rect2(p+Vector2(-8,-3),Vector2(16,5)),Color("b59b68"))
	for k in range(6):
		draw_line(p+Vector2(-7+k*2.5,-2),p+Vector2(-7+k*2.5,1),Color("8c704f"),0.5)
	if era<8:
		draw_rect(Rect2(p+Vector2(-0.5,-20),Vector2(1,22)),Color("6a563d"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-1,-19),p+Vector2(-1,-5),p+Vector2(-8,-5),p+Vector2(-6,-11)]),Color("ebdbad"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(1,-17),p+Vector2(8,-5),p+Vector2(1,-5)]),flag.lightened(0.3))
		draw_line(p+Vector2(-1,-19),p+Vector2(-9,-2),Color("9e9879"),0.5)
	else:
		draw_rect(Rect2(p+Vector2(-6,-7),Vector2(11,6)),Color("bdc9bc"))
		draw_rect(Rect2(p+Vector2(-4,-9),Vector2(5,4)),flag)
		for k in range(4):
			draw_rect(Rect2(p+Vector2(-5+k*2.5,-6),Vector2(1.5,1)),Color("537987"))
		draw_rect(Rect2(p+Vector2(3,-10),Vector2(2,5)),Color("625e53"))


func _draw_ship(p, era, flag):
	if zoom>=DETAIL_ZOOM:
		_draw_close_ship(p,era,flag)
		return
	var sway = floorf(sin(_time * 1.8 + p.x) * 0.6)
	p.y += sway
	draw_line(p + Vector2(-6, 3), p + Vector2(4, 3), Color(0.70, 0.88, 0.85, 0.32), 1)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(5, 0), p + Vector2(2, 3), p + Vector2(-3, 2)]), Color("765e49"))
	if era < 8:
		draw_line(p + Vector2(0, -7), p + Vector2(0, 1), Color("c7b98b"), 1)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-1, -7), p + Vector2(-1, -1), p + Vector2(-5, -1)]), Color("e4dab1"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(1, -5), p + Vector2(4, -1), p + Vector2(1, -1)]), flag.lightened(0.4))
	else:
		draw_rect(Rect2(p + Vector2(-2, -3), Vector2(5, 3)), Color("b9c8bc"))
		draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 2)), flag)


func _draw_settlements():
	_detail_neighbors.clear()
	detail_towns_drawn = 0
	detail_people_drawn = 0
	var towns = sim.state.get("settlements", [])
	# Sorting draws northern houses behind southern houses consistently.
	var ordered = towns.duplicate()
	ordered.sort_custom(func(a, b): return a.get("y", 0) < b.get("y", 0))
	for town in ordered:
		var population = float(town.get("population", 0))
		var orbital = float(town.get("orbital_population", 0))
		var p = (Vector2(town.get("x", 0), town.get("y", 0)) + Vector2.ONE * 0.5) * TILE
		var nation = int(town.get("nation", -1))
		var flag = _nation_colors.get(nation, Color("c9ab6b"))
		if zoom >= DETAIL_ZOOM and _visible(Rect2(p-Vector2(66,80),Vector2(132,145))):
			if population>0 or _is_land(int(town.x),int(town.y)):
				_draw_close_town(town,p,flag)
				if orbital>0: _draw_orbital_marker(p+Vector2(42,-48),flag)
				continue
		if population <= 0:
			_draw_ruins(p, int(town.get("id", 0)))
			if orbital > 0: _draw_orbital_marker(p, flag)
			continue
		var era = int(town.get("era", 0))
		var id = int(town.get("id", 0))
		var buildings = clampi(4 + int(sqrt(population) * 0.37), 4, 30)
		var spread = 8.0 + sqrt(float(buildings)) * 3.1
		var world_box = Rect2(p - Vector2.ONE * (spread + 20), Vector2.ONE * (spread + 20) * 2)
		if not _visible(world_box): continue
		# Cultivated strips, paths, and a town square make cities part of the land.
		if era >= 1:
			for k in range(3 if era < 9 else 2):
				var field = p + Vector2(-spread - 6 + k * 8, 7 + k % 2 * 4)
				var tx = floori(field.x / TILE)
				var ty = floori(field.y / TILE)
				if not _is_land(tx, ty): continue
				draw_rect(Rect2(field, Vector2(7, 6)), Color("aaad63") if k % 2 == 0 else Color("719b58"))
				for row in range(1, 6, 2): draw_line(field + Vector2(0, row), field + Vector2(6, row), Color("667e4b"), 1)
		draw_circle(p, 7.0, Color("a4a377"))
		draw_line(p + Vector2(-spread, 0), p + Vector2(spread, 0), Color("b1a57c"), 2)
		draw_line(p + Vector2(0, -spread + 3), p + Vector2(0, spread - 2), Color("b1a57c"), 2)
		var plots = []
		for k in range(buildings):
			var angle = k * 2.39996 + id * 0.81
			var dist = 7.0 + sqrt(float(k)) * 3.1
			var plot = (p + Vector2(cos(angle) * dist, sin(angle) * dist * 0.75)).round()
			if not _is_land(floori(plot.x / TILE), floori(plot.y / TILE)): continue
			plots.append({"p": plot, "k": k})
		plots.sort_custom(func(a, b): return a.p.y < b.p.y)
		for plot in plots:
			_draw_house(plot.p, era, flag, id + int(plot.k))
		_draw_monument(p + Vector2(0, -2), era, flag, float(town.get("faith", 0)), float(town.get("corruption", 0)))
		if orbital > 0: _draw_orbital_marker(p + Vector2(23, -9), flag)
		# A flag remains identifiable even at the atlas's smallest zoom.
		var pole = p + Vector2(6, -8)
		draw_line(pole + Vector2(0, 5), pole + Vector2(0, -8), Color("e2d7ae"), 1)
		var flutter = 1 if sin(_time * 3.0 + id) > 0 else 0
		draw_colored_polygon(PackedVector2Array([pole + Vector2(1, -8), pole + Vector2(7, -7 + flutter), pole + Vector2(6, -3 + flutter), pole + Vector2(1, -4)]), flag)
		if zoom >= 0.6:
			if sim.has_method("individual_keys"):
				for key in sim.individual_keys(id,mini(6,buildings),selected_person_key):
					var person=sim.get_individual(key)
					if person.is_empty() or not person.get("alive",false) or person.get("location","surface")!="surface" or person_elsewhere(key): continue
					var seed=int(person.portrait_seed)
					var angle=_time*(0.14+seed%5*0.018)+seed*2.3
					var walking=p+Vector2(cos(angle)*(7+seed%6),sin(angle)*(5+seed%6*0.5)+4)
					draw_identified_person(person,walking.round(),era,flag,str(person.role),1.0,_time*3+seed,"walking",DETAIL_ZOOM)
			else:
				for k in range(mini(6, buildings)):
					var angle = _time * (0.14 + k * 0.018) + k * 2.3 + id
					var walking = p + Vector2(cos(angle) * (7 + k), sin(angle) * (5 + k * 0.5) + 4)
					_draw_person(walking.round(), flag, k)
		if int(town.get("plague", 0)) > 0:
			_draw_status(p + Vector2(-13, -19), Color("96c36b"), "!")
		if int(town.get("drought", 0)) > 0:
			_draw_status(p + Vector2(-5, -24), Color("e6b467"), "!")
		if int(town.get("protection", 0)) > 0:
			draw_arc(p, spread + 2, PI, TAU, 24, Color(0.64, 0.87, 0.96, 0.28 + sin(_time * 2) * 0.08), 1)
		if int(town.get("blessing", 0)) > 0:
			for k in range(4):
				var phase = fposmod(_time * 0.23 + k * 0.25, 1.0)
				var spark = p + Vector2((k - 1.5) * 7, -phase * 26)
				draw_rect(Rect2(spark, Vector2.ONE), Color(1.0, 0.9, 0.51, 1 - phase))


func _visible(rect):
	var screen = Rect2(rect.position * zoom + _camera, rect.size * zoom)
	return screen.intersects(Rect2(Vector2.ZERO, size))

func _draw_close_town(town, center, flag):
	detail_towns_drawn+=1
	var appearance=town
	if float(town.get("population",0))<=0:
		appearance=town.duplicate()
		appearance["visual_damage"]=1.0
	architecture.draw_ground(self,appearance,center,flag,_time)
	var depth=[]
	for building in architecture.layout(appearance):
		var p=center+building.position
		if not _is_land(floori(p.x/TILE),floori(p.y/TILE)) or not _detail_owns_position(town,p,8): continue
		depth.append({"y":p.y,"building":building})
	for person in people.citizens(self,town,center,_time):
		if person_elsewhere(str(person.get("key",""))): continue
		if not _detail_owns_position(town,person.position): continue
		depth.append({"y":person.position.y,"person":person})
	depth.sort_custom(func(a,b):return a.y<b.y)
	for entry in depth:
		_draw_depth_index+=1
		if entry.has("building"):
			architecture.draw_building(self,entry.building,appearance,center,flag,_time)
			var building = entry.building
			var foot: Vector2 = center+building.position
			if _is_land(floori((foot.x-5)/TILE),floori((foot.y-2)/TILE)) and _is_land(floori((foot.x+5)/TILE),floori((foot.y-2)/TILE)):
				var roof_height = float(building.get("height",14))+3
				_person_occluders.append({"depth":_draw_depth_index,"rect":Rect2(foot-Vector2(7,roof_height),Vector2(14,roof_height))})
		else:
			var person=entry.person
			if not selected_person_key.is_empty() and str(person.get("key",""))==selected_person_key:
				draw_arc(person.position+Vector2(0,0.5),4.5,0,TAU,24,Color("f0d495"),0.7)
			people.draw_person(self,person.position,int(person.get("era",town.era)),person.get("flag",flag),int(person.get("seed",0)),str(person.get("role","civilian")),float(person.get("direction",1)),float(person.get("phase",0)),str(person.get("activity","walking")))
			PersonFeedback.draw(self,person.position,person.get("individual",{}))
			record_visible_person(person)
			detail_people_drawn+=1
	calamities.draw_town_conditions(self,town,center,_time,zoom)
	if float(town.get("population",0))<=0: return
	if int(town.get("protection",0))>0:
		draw_arc(center,49,PI,TAU,48,Color(0.58,0.85,0.98,0.24),0.8)
	if int(town.get("blessing",0))>0:
		for k in range(8):
			var phase=fposmod(_time*0.20+k*0.123,1.0)
			var p=center+Vector2((k-3.5)*10,20-phase*60)
			draw_rect(Rect2(p,Vector2(0.5,2)),Color(1.0,0.90,0.57,(1-phase)*0.65))

func record_visible_person(person: Dictionary):
	if str(person.get("key","")).is_empty(): return
	var record = person.duplicate()
	record.depth = _draw_depth_index
	_pictured_people.append(record)


func reserve_person(key:String,position:Vector2,context:String):
	if not key.is_empty(): _reserved_people[key]={"position":position,"context":context}


func person_elsewhere(key:String) -> bool:
	return not key.is_empty() and _reserved_people.has(key)


func draw_identified_person(individual:Dictionary,p:Vector2,era:int,flag:Color,role:String,direction:float,phase:float,activity:String,detail_threshold:float=3.0):
	if individual.is_empty() or not individual.get("alive",false) or individual.get("location","surface")!="surface": return
	if not _visible(Rect2(p-Vector2(9,15),Vector2(18,19))): return
	_draw_depth_index+=1
	var key=str(individual.key)
	if key==selected_person_key: draw_arc(p+Vector2(0,0.5),4.5,0,TAU,24,Color("f0d495"),0.7)
	var height=6.5 if role=="child" else 8.5
	if zoom>=detail_threshold:
		people.draw_person(self,p,era,flag,int(individual.portrait_seed),role,direction,phase,activity)
	else:
		_draw_person(p,flag,int(individual.portrait_seed),era)
		height=3.0
	PersonFeedback.draw(self,p,individual)
	record_visible_person({"key":key,"position":p,"seed":int(individual.portrait_seed),"name":str(individual.name),"role":str(individual.role),"height":height})


func _detail_owns_position(town, point, margin=0.0):
	var id=int(town.id)
	var center=(Vector2(town.x,town.y)+Vector2.ONE*0.5)*TILE
	if not _detail_neighbors.has(id):
		var neighbors=[]
		for other in sim.state.settlements:
			if int(other.id)==id or float(other.get("population",0))<=0: continue
			var p=(Vector2(other.x,other.y)+Vector2.ONE*0.5)*TILE
			if p.distance_squared_to(center)<150.0*150.0: neighbors.append(p)
		_detail_neighbors[id]=neighbors
	for neighbor in _detail_neighbors[id]:
		var toward=neighbor-center
		# A footprint stays on its side of the perpendicular boundary.
		if (point-center).dot(toward.normalized())+float(margin)>toward.length()*0.5: return false
	return true

func _draw_close_terrain():
	var first=(-_camera/zoom/TILE).floor()-Vector2(2,3)
	var last=((size-_camera)/zoom/TILE).ceil()+Vector2(2,3)
	var x0=maxi(0,int(first.x))
	var y0=maxi(0,int(first.y))
	var x1=mini(int(sim.state.width)-1,int(last.x))
	var y1=mini(int(sim.state.height)-1,int(last.y))
	for y in range(y0,y1+1):
		for x in range(x0,x1+1):
			var tile=_tile(x,y)
			var h=_hash(x,y,81)
			var p=Vector2(x,y)*TILE
			var center=p+Vector2(2+h%5,2+(h/7)%5)
			var biome=tile.get("biome","grass")
			if float(tile.get("elevation",0))<WATER_LEVEL:
				if h%4==0:
					var glint=0.10+0.13*(0.5+0.5*sin(_time*1.2+h))
					draw_line(center,center+Vector2(3,0),Color(0.62,0.86,0.84,glint),0.5)
					draw_line(center+Vector2(1,1),center+Vector2(5,1),Color(0.66,0.90,0.88,glint*0.6),0.5)
				continue
			if biome in ["grass","forest","marsh"]:
				for k in range(2):
					var blade=p+Vector2(float((h+k*37)%15)*0.5,float((h/5+k*23)%15)*0.5)
					draw_line(blade,blade+Vector2(-0.5,-1.5),Color("527c40"),0.5)
					draw_line(blade+Vector2(0.5,0),blade+Vector2(1,-1),Color("92aa56"),0.5)
				if h%13==0:
					draw_rect(Rect2(center,Vector2(0.5,0.5)),Color("e2d8a6"))
					draw_rect(Rect2(center+Vector2(1,-1),Vector2(0.5,0.5)),Color("c7a6b1"))
				if float(tile.get("forest",0))>0.48 and h%3==0:
					_draw_close_tree(center,h,biome=="marsh")
			elif biome in ["desert","coast"]:
				var sand=Color("bca776") if biome=="desert" else Color("d0c298")
				draw_polyline(PackedVector2Array([p+Vector2(0,5),p+Vector2(2,4.5),p+Vector2(5,4.5),p+Vector2(7,4)]),sand,0.5)
				if h%5==0:
					draw_rect(Rect2(center,Vector2(1.5,1)),Color("a49c7c"))
					draw_rect(Rect2(center-Vector2(0,0.5),Vector2(1,0.5)),Color("e4d6ad"))
			elif biome=="mountain":
				draw_polyline(PackedVector2Array([p+Vector2(2,1),p+Vector2(3,3),p+Vector2(2.5,5),p+Vector2(5,7)]),Color("717f79"),0.5)
				if h%3==0:
					draw_rect(Rect2(center,Vector2(2,1.5)),Color("74817c"))
					draw_line(center,center+Vector2(1.5,0),Color("cad0b5"),0.5)
			else:
				if h%3==0:
					draw_line(center,center+Vector2(2,-0.5),Color("c1d8d1"),0.5)
					draw_rect(Rect2(center+Vector2(0.5,-1),Vector2(0.5,0.5)),Color("f0f0d9"))

func _draw_close_tree(p, seed, swamp=false):
	var tall=7.0+seed%4
	draw_ellipse_pixels(p+Vector2(1,0),Vector2(4.5,1.8),Color(0.10,0.21,0.17,0.25))
	draw_rect(Rect2(p+Vector2(-0.5,-tall+3),Vector2(1.5,tall-2)),Color("655441"))
	draw_line(p+Vector2(0,-3),p+Vector2(2,-5),Color("7e6a45"),0.5)
	var dark=Color("315e47") if not swamp else Color("436951")
	var leaf=Color("4c814e") if not swamp else Color("6a8a54")
	draw_ellipse_pixels(p+Vector2(0,-tall+2),Vector2(4.5,3),dark)
	draw_ellipse_pixels(p+Vector2(-1,-tall+0.5),Vector2(3.6,2.8),leaf)
	draw_ellipse_pixels(p+Vector2(-1.5,-tall-0.5),Vector2(2,1.6),leaf.lightened(0.14))
	for k in range(3):
		var fleck=p+Vector2(-2+(seed+k*3)%5,-tall+float((seed+k)%3))
		draw_rect(Rect2(fleck,Vector2(1,0.5)),leaf.lightened(0.23))

func draw_ellipse_pixels(p, radii, color):
	if not _ellipse_textures.has(radii):
		var pixels=Vector2i(ceili(radii.x*4),ceili(radii.y*4))
		var mask=Image.create(pixels.x,pixels.y,false,Image.FORMAT_RGBA8)
		mask.fill(Color.TRANSPARENT)
		for row in range(pixels.y):
			var yy=(row+0.5-pixels.y*0.5)*0.5
			var half_width=roundi(sqrt(maxf(0.0,1.0-pow(yy/radii.y,2)))*radii.x*2)
			if half_width>0: mask.fill_rect(Rect2i(pixels.x/2-half_width,row,half_width*2,1),Color.WHITE)
		_ellipse_textures[radii]=ImageTexture.create_from_image(mask)
	var texture=_ellipse_textures[radii]
	var dimensions=Vector2(texture.get_size())*0.5
	draw_texture_rect(texture,Rect2(p-dimensions*0.5,dimensions),false,color)


func _draw_house(p, era, flag, seed):
	var n = _noise(seed, 116)
	var wall = Color("d6c698").lerp(Color("a99d7c"), n * 0.45)
	var roof = Color("a96750").lerp(Color("725948"), n)
	draw_rect(Rect2(p + Vector2(-3, 1), Vector2(8, 4)), Color(0.10, 0.22, 0.21, 0.34))
	if era <= 0:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 2), p + Vector2(0, -5), p + Vector2(4, 2)]), wall)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 2), p + Vector2(1, 2)]), Color("9c8260"))
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 2)), Color("4e5743"))
	elif era < 3:
		draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 5)), wall)
		draw_rect(Rect2(p + Vector2(1, -2), Vector2(2, 5)), wall.darkened(0.18))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -2), p + Vector2(-1, -5), p + Vector2(4, -2)]), Color("a69858"))
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 3)), Color("675c47"))
	elif era < 8:
		draw_rect(Rect2(p + Vector2(-3, -3), Vector2(6, 6)), wall)
		draw_rect(Rect2(p + Vector2(1, -3), Vector2(2, 6)), wall.darkened(0.20))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -3), p + Vector2(-1, -7), p + Vector2(4, -3)]), roof)
		draw_line(p + Vector2(-4, -3), p + Vector2(-1, -7), roof.lightened(0.25), 1)
		draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 2)), Color("5c5744"))
		if era >= 4:
			draw_line(p + Vector2(-3, -1), p + Vector2(2, -1), Color("8b7656"), 1)
			draw_rect(Rect2(p + Vector2(-2, -2), Vector2.ONE), Color("edda98"))
	elif era < 11:
		var height = 6 + int(n * 6)
		draw_rect(Rect2(p + Vector2(-3, -height), Vector2(7, height + 3)), Color("a8ac9d"))
		draw_rect(Rect2(p + Vector2(1, -height), Vector2(3, height + 3)), Color("7d9390"))
		draw_rect(Rect2(p + Vector2(-4, -height - 1), Vector2(8, 2)), Color("586c6d"))
		for y in range(-height + 2, 1, 3):
			draw_rect(Rect2(p + Vector2(-2, y), Vector2.ONE), Color("e3cf89"))
			draw_rect(Rect2(p + Vector2(1, y), Vector2.ONE), Color("b4d2c3"))
		if era == 8 and seed % 4 == 0:
			draw_rect(Rect2(p + Vector2(2, -height - 5), Vector2(2, 5)), Color("7b7264"))
			var phase = fposmod(_time * 0.6 + seed, 1.0)
			draw_rect(Rect2(p + Vector2(3 + phase * 4, -height - 7 - phase * 6), Vector2(3, 2)), Color(0.57, 0.66, 0.62, 0.35 * (1 - phase)))
	else:
		var height = 8 + int(n * 14)
		var body = Color("80aeb7").lerp(flag, 0.14)
		draw_rect(Rect2(p + Vector2(-3, -height), Vector2(6, height + 3)), body)
		draw_rect(Rect2(p + Vector2(1, -height), Vector2(2, height + 3)), body.darkened(0.24))
		draw_rect(Rect2(p + Vector2(-2, -height - 2), Vector2(4, 2)), Color("c5dcd1"))
		for y in range(-height + 2, 1, 3):
			draw_line(p + Vector2(-2, y), p + Vector2(0, y), Color("b5ded3"), 1)
		if era >= 12:
			draw_line(p + Vector2(-3, -height), p + Vector2(-3, 1), Color("7ee7d4"), 1)
			if seed % 3 == 0:
				draw_line(p + Vector2(0, -height - 2), p + Vector2(0, -height - 7), Color("a8cdca"), 1)
				draw_rect(Rect2(p + Vector2(0, -height - 7), Vector2.ONE), Color("e9d8a5") if sin(_time * 3 + seed) > 0 else Color("73a5a5"))


func _draw_monument(p, era, flag, faith, corruption):
	var light = Color("e7d9b1") if faith >= corruption else Color("c1a1ab")
	if era < 2:
		draw_rect(Rect2(p + Vector2(-2, -6), Vector2(4, 8)), Color("a0a48c"))
		draw_rect(Rect2(p + Vector2(-2, -6), Vector2(1, 8)), Color("cbd0ab"))
		draw_circle(p + Vector2(-5, 3), 2, Color("c58d50"))
		draw_rect(Rect2(p + Vector2(-5, 1), Vector2(1, 2)), Color("f2cc77"))
	elif era < 5:
		draw_rect(Rect2(p + Vector2(-6, -3), Vector2(12, 6)), light)
		for x in [-4, 0, 4]: draw_rect(Rect2(p + Vector2(x, -3), Vector2(2, 5)), light.darkened(0.20))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -3), p + Vector2(0, -9), p + Vector2(7, -3)]), Color("b28463"))
		draw_rect(Rect2(p + Vector2(-7, 3), Vector2(14, 2)), light.darkened(0.1))
	elif era < 8:
		draw_rect(Rect2(p + Vector2(-5, -6), Vector2(10, 9)), light)
		draw_rect(Rect2(p + Vector2(-2, -12), Vector2(4, 15)), light.darkened(0.08))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -12), p + Vector2(0, -18), p + Vector2(3, -12)]), flag.darkened(0.1))
		draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 4)), Color("475951"))
		draw_rect(Rect2(p + Vector2(-1, -9), Vector2(2, 3)), Color("e7c77a"))
	elif era < 11:
		draw_rect(Rect2(p + Vector2(-6, -5), Vector2(12, 8)), Color("b2bdab"))
		draw_rect(Rect2(p + Vector2(-3, -13), Vector2(6, 16)), Color("d4d2b6"))
		draw_rect(Rect2(p + Vector2(1, -13), Vector2(2, 16)), Color("8aaba4"))
		draw_circle(p + Vector2(-1, -9), 1.8, Color("58746e"))
		draw_rect(Rect2(p + Vector2(-4, -15), Vector2(8, 2)), flag)
	else:
		draw_rect(Rect2(p + Vector2(-7, -2), Vector2(14, 5)), Color("9dbab2"))
		draw_rect(Rect2(p + Vector2(-3, -18), Vector2(6, 21)), Color("b6d9cd"))
		draw_rect(Rect2(p + Vector2(1, -18), Vector2(2, 21)), Color("64969c"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -18), p + Vector2(0, -26), p + Vector2(3, -18)]), Color("d1eadc"))
		draw_arc(p + Vector2(0, -12), 8, 0, TAU, 20, Color("83dbd5"), 1)
		if era >= 13:
			var satellite = p + Vector2(cos(_time * 0.6) * 13, -26 + sin(_time * 0.6) * 4)
			draw_rect(Rect2(satellite, Vector2(3, 2)), Color("e5dfb7"))
			draw_line(satellite + Vector2(-3, 1), satellite + Vector2(6, 1), Color("669dc2"), 1)


func _draw_person(p, color, variation, era=0):
	if zoom>=DETAIL_ZOOM:
		people.draw_person(self,p,int(era),color,int(variation),"civilian",1.0,_time*3+variation,"walking")
		return
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(0.09, 0.2, 0.2, 0.4))
	draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 2)), color.lightened(0.25) if variation % 2 == 0 else Color("d7bf8e"))
	draw_rect(Rect2(p + Vector2(0, -3), Vector2.ONE), Color("e5ca9d"))


func _draw_ruins(p, seed):
	var submerged = not _is_land(int(p.x / TILE), int(p.y / TILE))
	var stone = Color("6c9991") if submerged else Color("949880")
	for k in range(6):
		var offset = Vector2(_noise(k, seed) * 18 - 9, _noise(k, seed + 13) * 10 - 5).round()
		draw_rect(Rect2(p + offset, Vector2(3, 2 + k % 4)), stone.darkened(k * 0.04))
		draw_rect(Rect2(p + offset, Vector2(3, 1)), stone.lightened(0.1))
	if not submerged:
		draw_line(p + Vector2(-6, 5), p + Vector2(7, 5), Color("697754"), 1)


func _living_population(town):
	return maxf(0.0, float(town.get("population", 0))) + maxf(0.0, float(town.get("orbital_population", 0)))


func _draw_orbital_marker(p, flag):
	# The station stays anchored to its former city even after its coast floods.
	# This is the clickable location of the civilization's surviving space colony.
	draw_circle(p, 13, Color(0.31, 0.65, 0.74, 0.12))
	draw_arc(p, 11, 0, TAU, 32, Color(0.64, 0.84, 0.86, 0.65), 1)
	var station = p + Vector2(0, -3)
	draw_rect(Rect2(station + Vector2(-3, -2), Vector2(6, 5)), Color("c9e3d7"))
	draw_rect(Rect2(station + Vector2(-11, -1), Vector2(6, 3)), Color("649bbb"))
	draw_rect(Rect2(station + Vector2(5, -1), Vector2(6, 3)), Color("649bbb"))
	draw_line(station + Vector2(-5, 0), station + Vector2(5, 0), Color("b8d7d0"), 1)
	draw_rect(Rect2(station + Vector2(0, -2), Vector2(2, 2)), flag.lightened(0.3))
	var satellite = p + Vector2.RIGHT.rotated(_time * 0.6) * 11
	draw_rect(Rect2(satellite.round(), Vector2(2, 2)), Color("e4e6b3"))


func _draw_status(p, color, text):
	draw_rect(Rect2(p + Vector2(-3, -6), Vector2(7, 9)), Color("203b39"))
	draw_string(_font, p + Vector2(-1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _draw_artifacts():
	for artifact in sim.state.get("artifacts", []):
		var x = artifact.get("x", -1)
		var y = artifact.get("y", -1)
		if not _valid_tile(x, y):
			var town = sim.get_settlement(int(artifact.get("settlement", -1)))
			if not town.is_empty():
				x = town.get("x", -1)
				y = town.get("y", -1)
		if not _valid_tile(x, y): continue
		var dark = str(artifact.get("side", "god")) == "devil"
		var p = (Vector2(x, y) + Vector2.ONE * 0.5) * TILE + Vector2(-17 if dark else 17, -9)
		var color = Color("cf8dae") if dark else Color("ead68d")
		draw_circle(p, 5, Color(color, 0.13 + sin(_time * 1.8) * 0.04))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(3, 0), p + Vector2(0, 4), p + Vector2(-3, 0)]), color)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 2), color.lightened(0.3), 1)


func _draw_effects():
	calamities.draw_world(self,sim,_time,zoom)
	var year = int(sim.state.get("year", 0))
	for effect in sim.state.get("effects", []):
		if int(effect.get("until", year + 1)) < year: continue
		var p = (Vector2(effect.get("x", 0), effect.get("y", 0)) + Vector2.ONE * 0.5) * TILE
		var radius = maxf(5, float(effect.get("radius", 3)) * TILE)
		var kind = str(effect.get("type", "blessing")).to_lower()
		if calamities.supports(kind): continue
		var salt = int(effect.get("x", 0)) + int(effect.get("y", 0))
		var infernal = str(effect.get("side", "god")) == "devil" or kind in ["fire", "meteor", "volcano", "curse", "corruption", "temptation", "earthquake"]
		var color = Color("e88566") if infernal else Color("e9d98d")
		if kind in ["rain", "flood", "tsunami", "storm"]: color = Color("7ecad6")
		if kind in ["plague", "pestilence", "disease"]: color = Color("a5c56f")
		if kind in ["forest", "life", "heal", "healing", "fertility", "wildlife"]: color = Color("a4dda1")
		if kind in ["ice", "cool"]: color = Color("b1e3ea")
		if kind in ["warm", "drought"]: color = Color("e4b87d")
		if kind in ["tempt", "pact", "cult", "possess", "forbidden", "demon", "idol", "discord"]: color = Color("d793b3")
		var pulse = 0.5 + 0.5 * sin(_time * 2.0 + salt)
		draw_circle(p, radius, Color(color, 0.07 + pulse * 0.035))
		draw_arc(p, radius, _time * 0.2, TAU + _time * 0.2, 48, Color(color, 0.28), 1)
		for k in range(14):
			var angle = _noise(k, salt, 14) * TAU
			var distance = sqrt(_noise(k, salt, 16)) * radius * 0.9
			var phase = fposmod(_time * 0.4 + _noise(k, salt, 18), 1.0)
			var particle = p + Vector2(cos(angle), sin(angle)) * distance
			if kind in ["rain", "flood", "storm", "tsunami"]:
				particle.y += phase * 14 - 7
				draw_line(particle, particle + Vector2(-1, 4), Color(color, 0.6), 1)
			elif kind in ["fire", "meteor", "volcano", "hellfire", "curse"]:
				particle.y -= phase * 13
				draw_rect(Rect2(particle.round(), Vector2(2, 3 - phase * 2)), Color(color.lerp(Color("fbe2a0"), phase), 1 - phase))
			else:
				particle.y -= phase * 8
				draw_rect(Rect2(particle.round(), Vector2.ONE * (1 if k % 3 else 2)), Color(color, sin(phase * PI) * 0.8))
		if "meteor" in kind:
			var head = p + Vector2(-12, -17)
			draw_line(head + Vector2(-24, -30), head, Color(0.94, 0.49, 0.26, 0.30), 4)
			draw_line(head + Vector2(-17, -23), head, Color("f3be75"), 2)
			draw_circle(head, 3, Color("f8e7b3"))
		elif "lightning" in kind or kind == "wrath":
			if sin(_time * 8 + salt) > 0.6:
				draw_polyline(PackedVector2Array([p + Vector2(1, -43), p + Vector2(-5, -22), p + Vector2(3, -23), p]), Color("f4e9b2"), 2)
		elif "tornado" in kind:
			for k in range(6):
				var half = 2 + k * 2
				var center = p + Vector2(sin(_time * 5 + k) * 2, -k * 4)
				draw_line(center - Vector2(half, 0), center + Vector2(half, 0), Color(0.72, 0.82, 0.77, 0.7), 2)
		_draw_power_symbol(kind, p, color, radius, salt)


func _draw_power_symbol(kind, p, color, radius, salt):
	var glow = Color(color, 0.80)
	var center = p + Vector2(0, -13 - sin(_time * 1.4 + salt) * 2)
	match kind:
		"heal", "purify", "resurrect":
			for k in range(3):
				var q = center + Vector2((k - 1) * 11, -abs(k - 1) * 5)
				draw_line(q + Vector2(-3, 0), q + Vector2(3, 0), glow, 1)
				draw_line(q + Vector2(0, -3), q + Vector2(0, 3), glow, 1)
		"protect":
			draw_arc(p, radius * 0.75, PI, TAU, 32, Color("b7e8dc"), 1)
			draw_arc(p, radius * 0.75 - 2, PI + 0.2, TAU - 0.2, 32, Color(color, 0.3), 1)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -4), center + Vector2(4, -4), center + Vector2(3, 1), center + Vector2(0, 4), center + Vector2(-3, 1)]), Color(color, 0.5))
		"bless", "inspire", "prophet", "peace":
			draw_circle(center, 3, glow)
			for k in range(8):
				var direction = Vector2.RIGHT.rotated(k * TAU / 8 + _time * 0.1)
				draw_line(center + direction * 6, center + direction * 10, Color(color, 0.55), 1)
		"pact", "cult", "idol", "forbidden":
			var points = PackedVector2Array()
			for k in range(6): points.append(center + Vector2.UP.rotated(k * TAU * 2 / 5 + _time * 0.08) * 9)
			draw_polyline(points, glow, 1)
			draw_arc(center, 11, 0, TAU, 30, Color(color, 0.4), 1)
		"possess", "demon":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 3), center + Vector2(-3, -4), center + Vector2(0, -6), center + Vector2(3, -4), center + Vector2(4, 3)]), Color("694357"))
			draw_polyline(PackedVector2Array([center + Vector2(-3, -3), center + Vector2(-6, -8), center + Vector2(-5, -4)]), glow, 1)
			draw_polyline(PackedVector2Array([center + Vector2(3, -3), center + Vector2(6, -8), center + Vector2(5, -4)]), glow, 1)
			draw_rect(Rect2(center + Vector2(-2, -2), Vector2.ONE), Color("f1b6ab"))
			draw_rect(Rect2(center + Vector2(1, -2), Vector2.ONE), Color("f1b6ab"))
		"tempt":
			for k in range(4):
				var q = center + Vector2((k - 1.5) * 6, sin(_time * 2 + k) * 3)
				draw_rect(Rect2(q, Vector2(3, 4)), Color("dab16e"))
				draw_line(q, q + Vector2(0, 3), Color("f4d494"), 1)
		"curse", "drought", "earthquake":
			for k in range(4):
				var q = p + Vector2(_noise(k, salt) - 0.5, _noise(k, salt + 4) - 0.5) * radius
				var crack = PackedVector2Array([q + Vector2(-7, -3), q + Vector2(-2, 1), q + Vector2(1, -1), q + Vector2(7, 4)])
				draw_polyline(crack, Color("685c48"), 2 if kind == "earthquake" else 1)
				draw_line(q, q + Vector2(2, -5), Color("685c48"), 1)
		"ice", "cool":
			for k in range(5):
				var q = p + Vector2(_noise(k, salt) - 0.5, _noise(k, salt + 2) - 0.5) * radius * 1.4
				for arm in range(3):
					var direction = Vector2.RIGHT.rotated(arm * PI / 3)
					draw_line(q - direction * 3, q + direction * 3, glow, 1)
		"storm":
			draw_rect(Rect2(center + Vector2(-12, -12), Vector2(24, 5)), Color("779ea2"))
			draw_rect(Rect2(center + Vector2(-7, -16), Vector2(15, 4)), Color("a1bdb8"))
			if sin(_time * 7 + salt) > 0.5:
				draw_polyline(PackedVector2Array([center + Vector2(2, -8), center + Vector2(-2, 0), center + Vector2(3, -1), center + Vector2(0, 7)]), Color("f1e6b5"), 1)
		"volcano":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 3), p + Vector2(-3, -10), p + Vector2(3, -10), p + Vector2(10, 3)]), Color("6e6755"))
			draw_line(p + Vector2(-3, -10), p + Vector2(3, -10), Color("f4bb71"), 2)
			draw_polyline(PackedVector2Array([p + Vector2(0, -9), p + Vector2(3, -5), p + Vector2(2, -3), p + Vector2(6, 2)]), Color("e68655"), 2)
		"warm":
			draw_arc(center, 5, 0, TAU, 16, glow, 1)
			for k in range(8):
				var direction = Vector2.RIGHT.rotated(k * TAU / 8)
				draw_line(center + direction * 7, center + direction * 9, glow, 1)
		"population", "settlement":
			# Celebratory sparks are an effect, never duplicate human identities.
			for k in range(5):
				var spark=center+Vector2((k-2)*4,-4-absf(sin(_time*2+k))*8)
				draw_line(spark-Vector2(1.5,0),spark+Vector2(1.5,0),glow,0.7)
				draw_line(spark-Vector2(0,1.5),spark+Vector2(0,1.5),glow,0.7)
		"wildlife":
			for k in range(4):
				var q = p + Vector2(_noise(k, salt) - 0.5, _noise(k, salt + 3) - 0.5) * radius
				draw_rect(Rect2(q, Vector2(4, 2)), Color("d3b18a"))
				draw_line(q + Vector2(0, 2), q + Vector2(0, 4), Color("8c7858"), 1)
				draw_line(q + Vector2(3, 2), q + Vector2(3, 4), Color("8c7858"), 1)
		"plague":
			for k in range(4):
				var q = center + Vector2(_noise(k, salt) - 0.5, _noise(k, salt + 3) - 0.5) * radius
				draw_circle(q, 4, Color(color, 0.20))
				draw_arc(q, 3, 0, TAU, 10, Color(color, 0.45), 1)
		"discord":
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), glow, 2)
			draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), glow, 2)


func _draw_wars():
	people.draw_wars(self,sim,_time,zoom)

func _draw_legacy_wars():
	for war in sim.state.get("wars", []):
		var a = {}
		var b = {}
		var best = INF
		for one in sim.state.get("settlements", []):
			if one.get("nation", -1) != war.get("a", -2): continue
			for two in sim.state.get("settlements", []):
				if two.get("nation", -1) != war.get("b", -2): continue
				var dist = Vector2(one.get("x", 0), one.get("y", 0)).distance_squared_to(Vector2(two.get("x", 0), two.get("y", 0)))
				if dist < best:
					best = dist
					a = one
					b = two
		if a.is_empty() or b.is_empty(): continue
		var pa = (Vector2(a.x, a.y) + Vector2.ONE * 0.5) * TILE
		var pb = (Vector2(b.x, b.y) + Vector2.ONE * 0.5) * TILE
		var p = pa.lerp(pb, 0.5)
		for k in range(6):
			var t = fposmod(_time * 0.04 + k * 0.13, 1.0)
			var soldier = pa.lerp(pb, t)
			if _is_land(int(soldier.x / TILE), int(soldier.y / TILE)): _draw_person(soldier, Color("d87964"), k)
		var alpha = 0.65 + 0.25 * sin(_time * 3)
		draw_line(p + Vector2(-4, -5), p + Vector2(4, 3), Color(0.96, 0.79, 0.62, alpha), 2)
		draw_line(p + Vector2(4, -5), p + Vector2(-4, 3), Color(0.96, 0.79, 0.62, alpha), 2)


func _draw_agents():
	for agent in sim.state.get("agents", []):
		if not _valid_tile(agent.get("x", -1), agent.get("y", -1)): continue
		var p = (Vector2(agent.get("x", 0), agent.get("y", 0)) + Vector2.ONE * 0.5) * TILE
		var color = Color("efdf96") if str(agent.get("side", "god")) == "god" else Color("d18db3")
		draw_arc(p + Vector2(0, -6), 3, 0, TAU, 16, color, 1)
		# A summoned presence has a winged sigil; it is not a mortal citizen.
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(2,-5),p+Vector2(0,0),p+Vector2(-2,-5)]),color)
		draw_polyline(PackedVector2Array([p+Vector2(-2,-5),p+Vector2(-6,-8),p+Vector2(-4,-2),p]),Color(color,0.6),0.7)
		draw_polyline(PackedVector2Array([p+Vector2(2,-5),p+Vector2(6,-8),p+Vector2(4,-2),p]),Color(color,0.6),0.7)


func _draw_clouds():
	if overlay != "terrain": return
	var world_width = float(sim.state.get("width", 160)) * TILE
	for i in range(_cloud_points.size()):
		var p = _cloud_points[i]
		p.x = fposmod(p.x + _time * (0.5 + i * 0.035), world_width)
		# Transparent flat cloud wisps keep the entire terrain readable.
		var alpha = 0.06 + _noise(i, 200) * 0.035
		draw_rect(Rect2(p + Vector2(5, 11), Vector2(34, 5)), Color(0.08, 0.24, 0.25, alpha * 0.7))
		draw_rect(Rect2(p, Vector2(30, 4)), Color(0.91, 0.96, 0.88, alpha))
		draw_rect(Rect2(p + Vector2(6, -3), Vector2(22, 3)), Color(0.91, 0.96, 0.88, alpha))
		draw_rect(Rect2(p + Vector2(17, 4), Vector2(23, 3)), Color(0.91, 0.96, 0.88, alpha))


func _draw_selection():
	if selected_id < 0: return
	var town = sim.get_settlement(selected_id)
	if town.is_empty(): return
	var p = (Vector2(town.get("x", 0), town.get("y", 0)) + Vector2.ONE * 0.5) * TILE
	var radius = (51.0 if zoom>=DETAIL_ZOOM else 17.0) + sin(_time * 2) * 1.0
	var color = Color("f5e3a3")
	for k in range(4):
		var angle = k * PI * 0.5 + PI * 0.125
		draw_arc(p, radius, angle, angle + PI * 0.25, 10, color, 1.5 / zoom)
		draw_arc(p, radius + 3, angle + 0.1, angle + PI * 0.25 - 0.1, 8, Color(color, 0.35), 1 / zoom)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -radius - 8), p + Vector2(3, -radius - 8), p + Vector2(0, -radius - 4)]), color)


func _draw_brush():
	if not _mouse_inside or _hover.x < 0 or _panning: return
	var p = (Vector2(_hover) + Vector2.ONE * 0.5) * TILE
	var color = Color("e6dab0")
	if active_power == "inspect":
		var box = Rect2(Vector2(_hover) * TILE, Vector2.ONE * TILE)
		draw_rect(box, Color(color, 0.13))
		draw_rect(box, Color(color, 0.7), false, 1 / zoom)
	else:
		if active_power in ["fire", "meteor", "corruption", "curse", "plague", "tempt", "pact", "cult", "possess", "forbidden", "idol", "discord", "volcano", "demon", "drought", "earthquake", "storm", "ice"]: color = Color("f39d8c")
		var radius = (float(brush_radius) + 0.5) * TILE
		draw_circle(p, radius, Color(color, 0.08))
		draw_arc(p, radius, 0, TAU, 64, Color(color, 0.85), 1 / zoom)
		for k in range(4):
			var direction = Vector2.RIGHT.rotated(k * PI * 0.5)
			draw_line(p + direction * (radius - 3 / zoom), p + direction * (radius + 3 / zoom), color, 1 / zoom)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), color, 1 / zoom)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), color, 1 / zoom)


func _draw_labels():
	var towns = sim.state.get("settlements", []).duplicate()
	towns.sort_custom(func(a, b):
		if int(a.get("id", -1)) == int(b.get("id", -1)): return false
		if int(a.get("id", -1)) == selected_id: return true
		if int(b.get("id", -1)) == selected_id: return false
		return _living_population(a) > _living_population(b)
	)
	var occupied = []
	var budget = 12 if zoom < 0.65 else 32
	for town in towns:
		if _living_population(town) <= 0: continue
		if occupied.size() >= budget: break
		var p = (Vector2(town.get("x", 0), town.get("y", 0)) + Vector2.ONE * 0.5) * TILE * zoom + _camera
		if not Rect2(Vector2.ZERO, size).has_point(p): continue
		var text = str(town.get("name", "Settlement"))
		var orbit_only = float(town.get("population", 0)) <= 0 and float(town.get("orbital_population", 0)) > 0
		if orbit_only: text += " · Orbit"
		var selected = int(town.get("id", -1)) == selected_id
		var font_size = 13 if selected else 11
		var text_size = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var label_offset=(54.0 if zoom>=DETAIL_ZOOM else 24.0)*zoom
		var label_pos = p + Vector2(-text_size.x * 0.5, label_offset + 10)
		var box = Rect2(label_pos + Vector2(-5, -font_size - 1), text_size + Vector2(10, 4))
		var overlap = false
		for other in occupied:
			if box.grow(5).intersects(other):
				overlap = true
				break
		if overlap and not selected: continue
		occupied.append(box)
		draw_rect(box, Color(0.055, 0.14, 0.16, 0.88 if selected else 0.70))
		var color = _nation_colors.get(int(town.get("nation", -1)), PALE)
		draw_rect(Rect2(box.position, Vector2(2, box.size.y)), color)
		draw_string(_font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f6e9c5") if selected else Color("e0e4ce"))
		if selected or orbit_only or (zoom > 1.2 and overlay != "terrain"):
			var detail = "%d souls" % int(_living_population(town))
			if orbit_only: detail = "%d souls in orbit" % int(town.get("orbital_population", 0))
			if overlay == "belief": detail = "%d%% faith / %d%% corruption" % [roundi(float(town.get("faith", 0)) * 100), roundi(float(town.get("corruption", 0)) * 100)]
			elif overlay == "technology": detail = Content.ERAS[clampi(int(town.get("era",0)),0,13)].name+" Age"
			var detail_size = _font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			var detail_pos = p + Vector2(-detail_size.x * 0.5, label_offset + 24)
			draw_string_outline(_font, detail_pos, detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color("173339"))
			draw_string(_font, detail_pos, detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c7d1b9"))


func _draw_selected_person_label():
	if selected_person_key.is_empty(): return
	for person in _pictured_people:
		if str(person.get("key",""))!=selected_person_key: continue
		var name = str(person.get("name",""))
		if name.is_empty(): return
		var anchor: Vector2 = (person.position-Vector2(0,float(person.get("height",8.5))+2.5))*zoom+_camera
		var text_size = _font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
		var box = Rect2(anchor-Vector2(text_size.x*0.5+8,22),text_size+Vector2(16,8))
		box.position.x=clampf(box.position.x,3,maxf(3,size.x-box.size.x-3))
		box.position.y=maxf(3,box.position.y)
		draw_rect(box,Color("223249"))
		draw_rect(box,Color("d8bb7a"),false,1)
		draw_string(_font,box.position+Vector2(8,18),name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f4dfb2"))
		return


func _draw_cartography(world_size):
	var color = Color(0.74, 0.76, 0.64, 0.52)
	# Compass, scale, and coordinates remain anchored to the viewport.
	var p = Vector2(size.x - 35, 38)
	draw_line(p + Vector2(0, -15), p + Vector2(0, 15), color, 1)
	draw_line(p + Vector2(-10, 0), p + Vector2(10, 0), color, 1)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -11), p + Vector2(-3, -2), p, p + Vector2(3, -2)]), Color("c2c4a4"))
	draw_string(_font, p + Vector2(-4, -19), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	var tiles = 1
	for candidate in [1, 2, 5, 10, 20, 50, 100]:
		if candidate * TILE * zoom <= 100: tiles = candidate
	var length = tiles * TILE * zoom
	var start = Vector2(18, size.y - 25)
	draw_line(start, start + Vector2(length, 0), color, 1)
	draw_line(start + Vector2(0, -3), start + Vector2(0, 3), color, 1)
	draw_line(start + Vector2(length, -3), start + Vector2(length, 3), color, 1)
	draw_string(_font, start + Vector2(0, 15), "%d tiles" % tiles, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	if size.x>=600:
		var coordinates = ("STREET VIEW  ·  " if zoom>=DETAIL_ZOOM else "ATLAS  ·  ")+"%d%%" % roundi(zoom * 100)
		if _hover.x >= 0: coordinates += "    %d, %d" % [_hover.x, _hover.y]
		var text_width = _font.get_string_size(coordinates, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_font, Vector2(size.x - text_width - 14, size.y - 10), coordinates, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	# Small registration marks reinforce the feeling of a divine atlas.
	for corner in [Vector2.ZERO, Vector2(world_size.x, 0), world_size, Vector2(0, world_size.y)]:
		var screen = _camera + corner * zoom
		if Rect2(Vector2(4, 4), size - Vector2(8, 8)).has_point(screen):
			draw_line(screen - Vector2(4, 0), screen + Vector2(4, 0), color, 1)
			draw_line(screen - Vector2(0, 4), screen + Vector2(0, 4), color, 1)
