extends Control

## The HUD owns placement; this control reads the live world texture and camera.
var world:
	set(value):
		world = value
		queue_redraw()
var _refresh = 0.0
var _touch_index = -1
var _touch_start = Vector2.ZERO
var _touch_cancelled = false

func _ready():
	custom_minimum_size = Vector2(136,90)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	tooltip_text = "World map · click or tap to move the camera"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _process(delta):
	_refresh += delta
	if _refresh >= 0.20:
		_refresh = 0.0
		if is_visible_in_tree(): queue_redraw()

func _world_ready() -> bool:
	return is_instance_valid(world) and world.sim != null and not world.sim.state.is_empty() and int(world.sim.state.get("width",0)) > 0 and int(world.sim.state.get("height",0)) > 0

func map_rect() -> Rect2:
	var available = Rect2(Vector2(4,4),(size-Vector2(8,8)).max(Vector2.ZERO))
	if not _world_ready(): return available
	var dimensions = Vector2(world.sim.state.width,world.sim.state.height)
	var scale_ = minf(available.size.x/dimensions.x,available.size.y/dimensions.y)
	var fitted = dimensions*scale_
	return Rect2(available.position+(available.size-fitted)*0.5,fitted)

func _draw():
	var frame = StyleBoxFlat.new()
	frame.bg_color = Color("15231f")
	frame.border_color = Color("716c4b")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(3)
	draw_style_box(frame,Rect2(Vector2.ZERO,size))
	if not _world_ready(): return
	var rect = map_rect()
	if rect.size.x <= 0 or rect.size.y <= 0: return
	if world._terrain_texture != null: draw_texture_rect(world._terrain_texture,rect,false)
	else: draw_rect(rect,Color("24403d"))
	var state = world.sim.state
	var dimensions = Vector2(state.width,state.height)
	for town in state.get("settlements",[]):
		if int(town.get("population",0))+int(town.get("orbital_population",0)) <= 0: continue
		var p = rect.position+(Vector2(town.x,town.y)+Vector2.ONE*0.5)/dimensions*rect.size
		var color = world._nation_colors.get(int(town.get("nation",-1)),Color("d5ba80"))
		draw_rect(Rect2(p-Vector2(1.5,1.5),Vector2(3,3)),Color("17211e"))
		draw_rect(Rect2(p-Vector2.ONE,Vector2(2,2)),color)
		if int(town.id)==int(world.selected_id):
			draw_rect(Rect2(p-Vector2(2.5,2.5),Vector2(5,5)),Color("f0e3aa"),false,1)
	var camera = camera_rect()
	if camera.has_area():
		draw_rect(camera,Color(0.98,0.92,0.65,0.07))
		draw_rect(camera,Color("13221b"),false,3)
		draw_rect(camera,Color("f1e3a6"),false,1)

func camera_rect() -> Rect2:
	if not _world_ready() or float(world.zoom) <= 0: return Rect2()
	var rect = map_rect()
	var extent = Vector2(world.sim.state.width,world.sim.state.height)*8.0
	var bounds = Rect2(-world._camera/float(world.zoom),world.size/float(world.zoom)).intersection(Rect2(Vector2.ZERO,extent))
	if not bounds.has_area(): return Rect2()
	return Rect2(rect.position+bounds.position/extent*rect.size,bounds.size/extent*rect.size)

func center_at(local_position: Vector2) -> bool:
	if not _world_ready(): return false
	var rect = map_rect()
	if not rect.has_point(local_position) or not rect.has_area(): return false
	var point = (local_position-rect.position)/rect.size
	var state = world.sim.state
	world.center_on_tile(clampi(int(point.x*int(state.width)),0,int(state.width)-1),clampi(int(point.y*int(state.height)),0,int(state.height)-1))
	queue_redraw()
	return true

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_touch_start = event.position
				_touch_cancelled = false
			else:
				_touch_cancelled = true
		elif event.index == _touch_index:
			if not event.canceled and not _touch_cancelled and event.position.distance_to(_touch_start) <= 16.0: center_at(event.position)
			_touch_index = -1
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index==_touch_index and event.position.distance_to(_touch_start)>16.0: _touch_cancelled = true
		accept_event()
	elif event is InputEventMouseButton:
		if event.device != -1 and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: center_at(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		accept_event()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_touch_index = -1
		_touch_cancelled = false
