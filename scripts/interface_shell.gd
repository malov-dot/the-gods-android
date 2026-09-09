extends RefCounted

const Art=preload("res://scripts/interface_art.gd")
const PowerHUD=preload("res://scripts/hud_powers.gd")
const MiniMap=preload("res://scripts/hud_minimap.gd")
const GROUPS=[
	["terrain","Terrain","Raise land, carve water, mountains and mineral deposits."],
	["nature","Nature","Shape forests, wildlife, soil and climate."],
	["life","Life","Found settlements and create people."],
	["god","God","Heal, protect and inspire civilizations."],
	["devil","Devil","Offer bargains, corrupt rulers and provoke conflict."],
	["disaster","Disasters","Unleash fire, storms, disease and destruction."]
]
const CATEGORY_COLORS={"terrain":Color("82b8c5"),"nature":Color("a2bd73"),"life":Color("d8c397"),"god":Color("efe0ac"),"devil":Color("d98a79"),"disaster":Color("efac70")}
var app
var hud:Control
var layout_mode="desktop"
var category_buttons=[]
var nav_buttons=[]
var rail:PanelContainer
var rail_box:BoxContainer
var stats_panel:PanelContainer
var utility:HBoxContainer
var time_panel:PanelContainer
var speed_button:Button
var selection_plaque:PanelContainer
var selection_expand:Button
var selection_name:Label
var selection_stats:Label
var selection_art:Control
var minimap:Control
var map_tools:HBoxContainer
var power_ui
var hidden:Control
var status_panel:PanelContainer
var selection_close:Button
var observe_button:Button
var resource_row:HBoxContainer
var resource_captions=[]
var side:Label
var last_selection=""
var menu_button:Button
var _ready_done=false

func build(host):
	app=host
	app.world=app.WorldView.new()
	app.world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.world.tile_clicked.connect(app._on_tile_clicked)
	app.world.tile_hovered.connect(app._on_tile_hovered)
	app.world.person_clicked.connect(app._on_person_clicked)
	app.add_child(app.world)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.z_index=10
	app.add_child(hud)
	stats_panel=panel(hud,8)
	resource_row=HBoxContainer.new()
	resource_row.add_theme_constant_override("separation",16)
	stats_panel.add_child(resource_row)
	app.population_label=stat("population","PEOPLE","0")
	app.age_label=stat("era","AGE","Stone")
	app.faith_label=stat("faith","GOD / DEVIL","25 / 25")
	app.mana_label=stat("essence","ESSENCE","Free")
	app.year_label=stat("year","YEAR","0")
	utility=HBoxContainer.new()
	utility.add_theme_constant_override("separation",4)
	hud.add_child(utility)
	for item in [["people",app._show_people,"Residents: find and influence any person."],["realms",app._show_factions,"Factions: resources, leaders and wars."],["layers",app._show_map_options,"Map overlays: borders, belief, fertility and technology."],["settings",app._show_settings,"Settings: sound, display and saving."]]:
		utility.add_child(icon_button(item[0],"",item[1],item[2]))
	menu_button=icon_button("menu","",app._show_menu,"Menu: save, load, history and help.")
	utility.add_child(menu_button)
	rail=panel(hud,4)
	rail_box=BoxContainer.new()
	rail_box.add_theme_constant_override("separation",2)
	rail.add_child(rail_box)
	observe_button=icon_button("observe","Observe",observe,"Observe the world. Select people or settlements; cancel the active power.",48)
	observe_button.toggle_mode=true
	rail_box.add_child(observe_button)
	for group in GROUPS:
		var button=icon_button("category_"+group[0],group[1],open_power_category.bind(group[0]),group[2],48)
		button.toggle_mode=true
		rail_box.add_child(button)
		var entry={"button":button,"id":group[0],"label":group[1]}
		category_buttons.append(entry)
		nav_buttons.append(entry)
	time_panel=panel(hud,4)
	var times=HBoxContainer.new()
	times.add_theme_constant_override("separation",4)
	time_panel.add_child(times)
	app.pause_button=app._button("Play",app._toggle_pause,48)
	app.pause_button.custom_minimum_size.x=56
	times.add_child(app.pause_button)
	speed_button=app._button("1×",app._show_time_controls,48)
	speed_button.custom_minimum_size=Vector2(70,48)
	speed_button.tooltip_text="Time: choose a speed or pause the world."
	times.add_child(speed_button)
	app.side_label=app._label("",13,app.GOLD)
	app.side_label.custom_minimum_size.x=100
	app.side_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	times.add_child(app.side_label)
	side=app.side_label
	minimap=MiniMap.new()
	minimap.world=app.world
	hud.add_child(minimap)
	map_tools=HBoxContainer.new()
	map_tools.add_theme_constant_override("separation",3)
	hud.add_child(map_tools)
	for item in [["home",func():app.world.reset_camera(),"Fit the entire world (Home)."],["zoom_out",func():app.world.set_zoom(app.world.zoom/1.35),"Zoom out. Pinch or scroll also zooms."],["zoom_in",func():app.world.set_zoom(app.world.zoom*1.35),"Zoom in. Double-click a town for Street View."]]:
		map_tools.add_child(icon_button(item[0],"",item[1],item[2],48))
	selection_plaque=panel(hud,8)
	var selected=HBoxContainer.new()
	selected.add_theme_constant_override("separation",10)
	selection_plaque.add_child(selected)
	selection_art=Art.new()
	selection_art.custom_minimum_size=Vector2(46,46)
	selected.add_child(selection_art)
	var identity=VBoxContainer.new()
	identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation",3)
	selected.add_child(identity)
	selection_name=app._label("",17,app.GOLD)
	selection_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(selection_name)
	selection_stats=app._label("",12,app.LIGHT)
	selection_stats.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(selection_stats)
	selection_expand=icon_button("expand","",expand_selection,"Details: inspect this settlement or person.")
	selected.add_child(selection_expand)
	selection_close=icon_button("close","",clear_selection,"Dismiss this selection.")
	selected.add_child(selection_close)
	selection_plaque.hide()
	status_panel=panel(hud,6)
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	app.status_label=app._paragraph("",12,app.LIGHT)
	app.status_label.max_lines_visible=2
	app.status_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	app.status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(app.status_label)
	status_panel.hide()
	# Legacy controls are kept as data bindings for keyboard actions and save compatibility.
	hidden=Control.new()
	hidden.hide()
	app.add_child(hidden)
	app.world_label=app._label("")
	hidden.add_child(app.world_label)
	app.overlay_select=OptionButton.new()
	for text_ in ["Terrain","Nations","Belief","Fertility","Technology"]: app.overlay_select.add_item(text_)
	hidden.add_child(app.overlay_select)
	app.inspector_box=VBoxContainer.new()
	hidden.add_child(app.inspector_box)
	app.chronicle_box=VBoxContainer.new()
	hidden.add_child(app.chronicle_box)
	for value in [1,5,20,100]:
		var button=app._button(str(value),app._set_speed.bind(value))
		button.toggle_mode=true
		hidden.add_child(button)
		app.speed_buttons.append(button)
	app._build_left(hidden)
	app._build_tutorial(hidden)
	power_ui=PowerHUD.new(app,self)
	power_ui.build(hud)
	_ready_done=true
	layout()

func panel(parent,padding=8):
	var p=PanelContainer.new()
	p.add_theme_stylebox_override("panel",app._style(Color("111e21ed"),Color("766b4b"),4,padding))
	p.mouse_filter=Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	return p

func icon_button(kind,label_,callback,tip,minsize=48):
	var b=Button.new()
	b.custom_minimum_size=Vector2(minsize,maxi(minsize,58 if not label_.is_empty() else minsize))
	b.tooltip_text=tip
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	b.pressed.connect(app._click_sound)
	var icon=Art.new()
	icon.kind=kind
	icon.accent=icon_color(kind)
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	icon.offset_left=9
	icon.offset_right=-9
	icon.offset_top=5 if not label_.is_empty() else 8
	icon.offset_bottom=33 if not label_.is_empty() else minsize-8
	b.add_child(icon)
	b.set_meta("art",icon)
	if not label_.is_empty():
		var caption=app._label(label_,10,app.LIGHT)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top=-21
		caption.offset_bottom=-3
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_child(caption)
		b.set_meta("caption",caption)
	return b

func icon_color(kind):
	if kind.begins_with("category_"): return CATEGORY_COLORS.get(kind.trim_prefix("category_"),app.GOLD)
	if kind.begins_with("power_"):
		for id in PowerHUD.GROUP_IDS:
			if kind.trim_prefix("power_") in PowerHUD.GROUP_IDS[id]: return CATEGORY_COLORS[id]
	return app.GOLD

func stat(kind,caption,value):
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	resource_row.add_child(row)
	var icon=Art.new()
	icon.kind=kind
	icon.custom_minimum_size=Vector2(24,24)
	icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var pair=VBoxContainer.new()
	pair.add_theme_constant_override("separation",0)
	row.add_child(pair)
	var title=app._label(caption,9,app.MUTED)
	pair.add_child(title)
	resource_captions.append(title)
	var number=app._label(value,14,app.LIGHT)
	pair.add_child(number)
	return number

func observe():
	if is_instance_valid(app.modal): app._close_modal()
	power_ui.cancel()
	refresh_selection()

func clear_selection():
	app.selected_id=-1
	app.selected_person_key=""
	app.world.selected_id=-1
	app.world.selected_person_key=""
	refresh_selection()

func expand_selection():
	if not app.selected_person_key.is_empty(): app.community.show_person(app.selected_person_key)
	elif app.selected_id>=0: app._show_context_sheet()

func refresh_selection():
	if not _ready_done: return
	var person=app.sim.get_individual(app.selected_person_key) if not app.selected_person_key.is_empty() else {}
	var town=app.sim.get_settlement(app.selected_id)
	if not person.is_empty():
		selection_art.kind="portrait"
		selection_art.person=person.duplicate()
		selection_art.person.era=town.get("era",0)
		selection_name.text=person.name
		selection_stats.text="%s · %d yr · %d%% influence"%[str(person.role).capitalize(),int(person.age),float(person.influence)*100]
	elif not town.is_empty() and town.population+town.get("orbital_population",0)>0:
		selection_art.kind="category_life"
		selection_name.text=town.name+" · "+app._nation_name(int(town.nation))
		selection_stats.text="%s people · %s · %d%% health"%[app._number(town.population+town.get("orbital_population",0)),app._era_name(town.era),town.health*100]
	else:
		selection_plaque.hide()
		return
	selection_art.queue_redraw()
	selection_plaque.visible=app.selected_power=="inspect" and not power_ui.palette.visible
	layout_selection()

func open_power_category(id):
	power_ui.open_category(id)

func refresh():
	if not _ready_done: return
	app.pause_button.visible=true
	speed_button.visible=true
	app.side_label.hide()
	power_ui.refresh()
	refresh_selection()
	status_panel.visible=app.status_time>0 and not is_instance_valid(app.modal)
	# Keep the glance HUD short; the selected community supplies detailed stats.
	app.population_label.text=_compact(app.sim.state.get("stats",{}).get("population",0))
	app.faith_label.text="%d / %d"%[app.sim.state.get("stats",{}).get("god",0)*100,app.sim.state.get("stats",{}).get("devil",0)*100]
	app.year_label.text=str(app.sim.state.get("year",0))
	if layout_mode!="desktop":
		app.mana_label.get_parent().get_parent().hide()
		app.year_label.text=str(app.sim.state.get("year",0))
		if app.hud_rect().size.x<390:
			app.age_label.text={"Renaissance":"Ren.","Information":"Info","Exploration":"Expl.","Classical":"Class.","Industrial":"Indust.","Medieval":"Mediev."}.get(app.age_label.text,app.age_label.text)

func _compact(value):
	if value>=1000000: return "%.1fM"%(value/1000000.0)
	if value>=10000: return "%.1fk"%(value/1000.0)
	return app._number(value)

func place(control,rect):
	control.position=rect.position
	control.size=rect.size

func layout():
	if not _ready_done: return
	var bounds=app.hud_rect()
	var size_=bounds.size
	hud.position=bounds.position
	hud.size=bounds.size
	layout_mode="desktop" if size_.x>=1100 else ("landscape" if size_.x>size_.y else "portrait")
	app.compact_ui=layout_mode!="desktop"
	var desktop=layout_mode=="desktop"
	var portrait=layout_mode=="portrait"
	rail_box.vertical=desktop
	for entry in category_buttons:
		entry.button.custom_minimum_size=Vector2(56 if desktop else 48,58)
	observe_button.custom_minimum_size=Vector2(56 if desktop else 48,58)
	# The rail becomes a horizontal tray, rather than scaling with the world.
	var rail_size=Vector2(64,426) if desktop else Vector2(356,66)
	place(rail,Rect2(Vector2(16,maxf(100,(size_.y-rail_size.y)*0.5)) if desktop else Vector2((size_.x-rail_size.x)*0.5,size_.y-rail_size.y-8),rail_size))
	resource_row.add_theme_constant_override("separation",18 if desktop else 5)
	for stat_row in resource_row.get_children(): stat_row.get_child(0).custom_minimum_size=Vector2(24,24) if desktop else Vector2(20,20)
	for title in resource_captions: title.visible=desktop
	app.mana_label.get_parent().get_parent().hide()
	app.year_label.get_parent().get_parent().visible=true
	for label_ in [app.population_label,app.faith_label,app.age_label,app.year_label]: label_.add_theme_font_size_override("font_size",14 if desktop else 12)
	place(stats_panel,Rect2(16 if desktop else 8,14 if desktop else 8,1,46 if desktop else 36))
	var utility_children=utility.get_children()
	for i in range(utility_children.size()-1): utility_children[i].visible=desktop
	place(utility,Rect2(size_.x-(256 if desktop else 56),10 if desktop else 4,248 if desktop else 48,48))
	place(time_panel,Rect2(size_.x-170 if desktop else (8 if portrait else size_.x-218),size_.y-72 if desktop else (52 if portrait else 4),154,56))
	map_tools.visible=desktop
	minimap.visible=desktop
	place(minimap,Rect2(16,size_.y-158,140,90))
	place(map_tools,Rect2(16,size_.y-64,152,48))
	place(status_panel,Rect2(size_.x*0.5-minf(260,size_.x*0.5-12),116 if portrait else 72,minf(520,size_.x-24),42))
	power_ui.layout()
	refresh_selection()

func layout_selection():
	var size_=app.hud_rect().size
	var width_=minf(450,size_.x-24)
	var y=size_.y-84 if layout_mode=="desktop" else size_.y-152
	place(selection_plaque,Rect2((size_.x-width_)*0.5,y,width_,68))

func idle_occluders():
	var result=[]
	for control in [stats_panel,utility,time_panel,rail,minimap,map_tools,selection_plaque,status_panel]:
		if control.visible: result.append(control)
	return result

func dispose():
	_ready_done=false
	if power_ui!=null:
		power_ui._built=false
		power_ui.shell=null
		power_ui.app=null
		power_ui=null
	app=null
