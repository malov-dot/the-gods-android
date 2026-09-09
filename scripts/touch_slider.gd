extends HSlider
## Keep native mouse/keyboard behavior, and handle touch without enabling global
## mouse emulation (which would duplicate world gestures and casts).
var _finger=-1
var _before_touch=0.0
func _init(): custom_minimum_size.y=48
func _gui_input(event):
	if not editable: return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and _finger<0:
			_finger=event.index; _before_touch=value
			grab_focus(); drag_started.emit()
			_touch_value(event.position.x); accept_event()
		elif event.index==_finger and (not event.pressed or event.canceled):
			_finger=-1; drag_ended.emit(not is_equal_approx(value,_before_touch)); accept_event()
	elif event is InputEventScreenDrag and event.index==_finger:
		_touch_value(event.position.x); accept_event()
func _touch_value(x:float):
	var inset=0.0 if get_theme_constant("center_grabber") else get_theme_icon("grabber").get_width()*0.5
	var position_ratio=clampf((x-inset)/maxf(1,size.x-inset*2),0,1)
	ratio=1.0-position_ratio if is_layout_rtl() else position_ratio
func _notification(what):
	if what==NOTIFICATION_EXIT_TREE or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()): _finger=-1
