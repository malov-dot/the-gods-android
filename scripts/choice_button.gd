extends Button
## A choice sheet uses ordinary touch-aware Controls. PopupMenu expects mouse
## input and can trap touch-only players in an undismissable embedded window.
signal item_selected(index:int)
var app
var title_="Choose an option"
var items=[]
var selected=-1
var item_count:int:
	get: return items.size()
var choices_layer:Control
var choices_panel:PanelContainer
var choices_scroll:ScrollContainer
var choice_buttons=[]

func _init(host,heading:String="Choose an option"):
	app=host; title_=heading
	custom_minimum_size=Vector2(0,48)
	clip_text=true
	text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	pressed.connect(open_choices)
func _ready():
	add_to_group("game_choices")
	get_viewport().size_changed.connect(_layout_choices)
func add_item(label_:String,id:int=-1):
	items.append({"text":label_,"id":items.size() if id<0 else id})
	if selected<0: select(0)
func select(index:int):
	if index<0 or index>=items.size(): return
	selected=index; text=items[index].text+"  ▾"; tooltip_text=items[index].text
func get_item_id(index:int)->int: return items[index].id
func get_item_text(index:int)->String: return items[index].text
func get_item_count()->int: return items.size()
func open_choices():
	if disabled or items.is_empty(): return
	close_open_choices(get_tree())
	choices_layer=Control.new()
	choices_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choices_layer.z_index=200
	app.add_child(choices_layer)
	var dim=ColorRect.new()
	dim.color=Color(0.02,0.04,0.045,0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed: close_choices()
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: close_choices())
	choices_layer.add_child(dim)
	choices_panel=PanelContainer.new()
	choices_panel.add_theme_stylebox_override("panel",app._style(Color("122227"),app.GOLD,4,12))
	choices_layer.add_child(choices_panel)
	var body=VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	choices_panel.add_child(body)
	var header=HBoxContainer.new()
	body.add_child(header)
	var title_label=app._paragraph(title_,19,app.GOLD)
	header.add_child(title_label)
	header.add_child(app.shell.icon_button("close","",close_choices,"Keep the current choice and return.",48))
	choices_scroll=app.TouchScroll.new()
	choices_scroll.input_layer=choices_layer
	choices_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(choices_scroll)
	var list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	choices_scroll.add_child(list)
	choice_buttons.clear()
	for i in range(items.size()):
		var button=Button.new()
		button.custom_minimum_size.y=64
		button.toggle_mode=true; button.button_pressed=i==selected
		button.pressed.connect(_pick.bind(i))
		list.add_child(button)
		var label_=app._paragraph(items[i].text,14,app.LIGHT)
		label_.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label_.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label_.offset_left=12; label_.offset_right=-12
		label_.offset_top=6; label_.offset_bottom=-6
		button.add_child(label_)
		choice_buttons.append(button)
	_layout_choices()
	_layout_choices.call_deferred()
func _layout_choices():
	if not is_instance_valid(choices_layer): return
	var safe=app.hud_rect()
	var width_=minf(480,safe.size.x-24)
	var height_=minf(safe.size.y-24,80+items.size()*72)
	choices_scroll.custom_minimum_size.y=maxf(48,height_-80)
	choices_panel.position=safe.position+(safe.size-Vector2(width_,height_))*0.5
	choices_panel.size=Vector2(width_,height_)
func _pick(index:int):
	select(index)
	close_choices()
	item_selected.emit(index)
func close_choices():
	if is_instance_valid(choices_layer):
		choices_layer.hide()
		choices_layer.queue_free()
	choices_layer=null; choices_panel=null; choices_scroll=null
	choice_buttons.clear()
func _exit_tree(): close_choices()
static func close_open_choices(tree:SceneTree)->bool:
	var closed=false
	for chooser in tree.get_nodes_in_group("game_choices"):
		if is_instance_valid(chooser.choices_layer): chooser.close_choices(); closed=true
	return closed
