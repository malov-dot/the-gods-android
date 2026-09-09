extends ScrollContainer
## Observe touches before child buttons. Once a swipe begins, cancel the pending
## button press and consume its release so scrolling never opens a resident.
var input_layer:Control
var _finger=-1
var _start=Vector2.ZERO
var _last=Vector2.ZERO
var _dragging=false
var _velocity=0.0
var _last_msec=0

func _ready():
	add_to_group("native_scrolls")
	set_process(false)
func _frontmost()->bool:
	for other in get_tree().get_nodes_in_group("native_scrolls"):
		if other==self or not other.is_visible_in_tree(): continue
		if is_instance_valid(other.input_layer) and is_instance_valid(input_layer) and other.input_layer.z_index>input_layer.z_index: return false
	return true
func _editor_at(node:Node,point:Vector2)->bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
			if child is Slider or child is LineEdit or child is TextEdit: return true
			if _editor_at(child,point): return true
	return false
func _begin_swipe():
	if _dragging: return
	_dragging=true
	propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	scroll_started.emit()
func _finish(canceled:bool=false):
	if canceled and _finger>=0: _begin_swipe()
	_finger=-1
	if _dragging:
		propagate_notification(Control.NOTIFICATION_SCROLL_END)
		scroll_ended.emit()
	_dragging=false
	if canceled: _velocity=0
	set_process(absf(_velocity)>15)
func reset_scroll():
	_finish(true)
	scroll_vertical=0
func _input(event):
	if not is_visible_in_tree() or not _frontmost():
		if _finger>=0: _finish(true)
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _finger>=0:
				_begin_swipe(); _velocity=0
				get_viewport().set_input_as_handled(); return
			if not get_global_rect().has_point(event.position) or _editor_at(self,event.position): return
			_finger=event.index; _start=event.position; _last=_start
			_velocity=0; _last_msec=Time.get_ticks_msec(); set_process(false)
		elif event.index==_finger:
			if _dragging or event.canceled: get_viewport().set_input_as_handled()
			_finish(event.canceled)
	elif event is InputEventScreenDrag and event.index==_finger:
		if not _dragging and absf(event.position.y-_start.y)<=10: return
		_begin_swipe()
		var movement=event.position.y-_last.y
		scroll_vertical-=roundi(movement)
		var now=Time.get_ticks_msec()
		_velocity=clampf(movement/maxf(0.016,float(now-_last_msec)/1000.0),-1800,1800)
		_last=event.position; _last_msec=now
		get_viewport().set_input_as_handled()
func _process(delta):
	if not is_visible_in_tree() or not _frontmost(): _velocity=0; set_process(false); return
	var before=scroll_vertical
	scroll_vertical-=roundi(_velocity*delta)
	_velocity*=exp(-9.0*delta)
	if absf(_velocity)<15 or scroll_vertical==before: _velocity=0; set_process(false)
func _notification(what):
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _finish(true)
