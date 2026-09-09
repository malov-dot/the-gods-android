extends RefCounted

const GROUP_IDS={
	"terrain":["land","water","mountain","ore"],
	"nature":["forest","fertility","warm","cool","wildlife"],
	"life":["settlement","population"],
	"god":["heal","rain","bless","protect","inspire","prophet","relic","purify","resurrect","peace"],
	"devil":["tempt","pact","cult","possess","forbidden","curse","demon","idol","discord"],
	"disaster":["fire","drought","plague","earthquake","meteor","storm","ice","volcano"]
}
const SHORT_NAMES={"land":"Land","water":"Ocean","mountain":"Mountain","ore":"Minerals","forest":"Forest","fertility":"Fertility","warm":"Warmth","cool":"Cool","wildlife":"Wildlife","settlement":"Settlement","population":"People","heal":"Heal","rain":"Rain","bless":"Bless","protect":"Sanctuary","inspire":"Inspire","prophet":"Prophet","relic":"Relic","purify":"Purify","resurrect":"Rebirth","peace":"Peace","tempt":"Tempt","pact":"Bargain","cult":"Cult","possess":"Possess","forbidden":"Knowledge","curse":"Curse","demon":"Demon","idol":"Idol","discord":"War","fire":"Fire","drought":"Drought","plague":"Plague","earthquake":"Quake","meteor":"Meteor","storm":"Storm","ice":"Freeze","volcano":"Volcano"}
var app
var shell
var palette:PanelContainer
var palette_title:Label
var grid:GridContainer
var palette_note:Label
var ability_buttons=[]
var active_strip:PanelContainer
var active_icon:Control
var name_label:Label
var cost_label:Label
var radius_label:Label
var radius_slider:HSlider
var help_button:Button
var cancel_button:Button
var active_box:BoxContainer
var tool_info:VBoxContainer
var brush_box:VBoxContainer
var tool_buttons:HBoxContainer
var controls_row:HBoxContainer
var group_id="terrain"
var _built=false

func _init(host,owner):
	app=host
	shell=owner

func build(parent):
	palette=shell.panel(parent,10)
	palette.hide()
	var body=VBoxContainer.new()
	body.add_theme_constant_override("separation",7)
	palette.add_child(body)
	var heading=HBoxContainer.new()
	body.add_child(heading)
	palette_title=app._label("TERRAIN",13,app.GOLD)
	palette_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(palette_title)
	heading.add_child(shell.icon_button("close","",close_palette,"Close this ability tray.",48))
	grid=GridContainer.new()
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	body.add_child(grid)
	palette_note=app._paragraph("Select a power. Its effect and reach will appear on the map.",12,app.MUTED)
	body.add_child(palette_note)
	active_strip=shell.panel(parent,8)
	active_strip.hide()
	app.active_banner=active_strip
	active_box=BoxContainer.new()
	active_box.add_theme_constant_override("separation",10)
	active_strip.add_child(active_box)
	tool_info=VBoxContainer.new()
	tool_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tool_info.add_theme_constant_override("separation",3)
	active_box.add_child(tool_info)
	var top=HBoxContainer.new()
	tool_info.add_child(top)
	active_icon=shell.Art.new()
	active_icon.custom_minimum_size=Vector2(28,28)
	top.add_child(active_icon)
	name_label=app._label("",15,app.GOLD)
	name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	cost_label=app._label("",12,app.TEAL)
	top.add_child(cost_label)
	app.active_hint=app._paragraph("",12,app.LIGHT)
	app.active_hint.max_lines_visible=1
	app.active_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	tool_info.add_child(app.active_hint)
	controls_row=HBoxContainer.new()
	controls_row.add_theme_constant_override("separation",8)
	active_box.add_child(controls_row)
	brush_box=VBoxContainer.new()
	brush_box.custom_minimum_size.x=126
	brush_box.add_theme_constant_override("separation",0)
	controls_row.add_child(brush_box)
	radius_label=app._label("Radius · 4 tiles",11,app.MUTED)
	brush_box.add_child(radius_label)
	radius_slider=app.TouchSlider.new()
	radius_slider.custom_minimum_size=Vector2(126,48)
	radius_slider.min_value=1
	radius_slider.max_value=10
	radius_slider.step=1
	radius_slider.value=app.world.brush_radius
	radius_slider.value_changed.connect(func(value):
		app.world.brush_radius=int(value)
		app.brush_slider.value=value
		radius_label.text="Radius · %d tiles"%value
		refresh())
	brush_box.add_child(radius_slider)
	tool_buttons=HBoxContainer.new()
	controls_row.add_child(tool_buttons)
	help_button=shell.icon_button("info","",func():app._explain_power(app.selected_power),"Power details: exact effect and reach.")
	tool_buttons.add_child(help_button)
	cancel_button=shell.icon_button("close","",cancel,"Cancel this power and return to observing (Esc).")
	tool_buttons.add_child(cancel_button)
	_built=true

func open_category(id):
	if not GROUP_IDS.has(id): return
	if is_instance_valid(app.modal): app._close_modal()
	if palette.visible and group_id==id:
		close_palette()
		return
	group_id=id
	app._select_power("inspect")
	app._clear(grid)
	ability_buttons.clear()
	palette_title.text={"god":"GOD · MIRACLES","devil":"DEVIL · TEMPTATIONS","life":"LIFE · CIVILIZATION"}.get(id,id.to_upper())
	for power_id in GROUP_IDS[id]:
		var power=app.powers.get_power(power_id)
		var enabled=allowed(power)
		var button=shell.icon_button("power_"+power_id,SHORT_NAMES.get(power_id,power.name),choose_power.bind(power_id),power.name+"\n"+power.description+("\nUnavailable in this mode or to this deity." if not enabled else ""),64)
		button.toggle_mode=true
		button.button_pressed=app.selected_power==power_id
		# Unavailable powers still disclose their explanation on touch.
		if not enabled:
			button.modulate=Color("8e999b")
			button.pressed.disconnect(choose_power.bind(power_id))
			button.pressed.connect(app._explain_power.bind(power_id))
		grid.add_child(button)
		ability_buttons.append({"button":button,"id":power_id})
	palette_note.text="Area powers: touch the map. Personal powers: touch a person or community."
	palette.show()
	refresh()
	shell.selection_plaque.hide()
	layout()
	palette.modulate.a=0.0
	app.create_tween().tween_property(palette,"modulate:a",1.0,0.12)

func allowed(power):
	return not power.is_empty()

func choose_power(id):
	var power=app.powers.get_power(id)
	if power.is_empty(): return
	if not allowed(power):
		app._explain_power(id)
		return
	app._set_category(power.category)
	app._select_power(id)
	close_palette()
	refresh()

func close_palette():
	palette.hide()
	for entry in shell.category_buttons: entry.button.button_pressed=group_id==entry.id and app.selected_power!="inspect"
	refresh()
	shell.refresh_selection()

func cancel():
	app.pending_casts.clear()
	app.deferred_world_action=Callable()
	app.world.cast_feedback=app.world.cast_feedback.filter(func(e):return not e.queued)
	palette.hide()
	app._select_power("inspect")
	for entry in shell.category_buttons: entry.button.button_pressed=false
	shell.refresh_selection()

func refresh():
	if not _built: return
	var power=app.powers.get_power(app.selected_power)
	active_strip.visible=not power.is_empty() and not palette.visible
	shell.observe_button.button_pressed=app.selected_power=="inspect" and not palette.visible
	for entry in shell.category_buttons:
		entry.button.button_pressed=(group_id==entry.id) if palette.visible else (app.selected_power in GROUP_IDS[entry.id])
	if power.is_empty(): return
	active_icon.kind="power_"+app.selected_power
	active_icon.accent=shell.icon_color(active_icon.kind)
	active_icon.queue_redraw()
	name_label.text=power.name
	cost_label.text="Touch a person" if app.Powers.PERSON_TARGETS.has(app.selected_power) else ("Touch a community" if not app.selected_power in app.Powers.TERRAIN_POWERS and app.selected_power!="settlement" else "Tap the world")
	brush_box.visible=not app.Powers.PERSON_TARGETS.has(app.selected_power)
	app.active_hint.text="Touch a person, or a community to choose someone." if app.Powers.PERSON_TARGETS.has(app.selected_power) else power.description
	var maximum=10
	radius_slider.max_value=maximum
	radius_slider.set_value_no_signal(mini(app.world.brush_radius,maximum))
	radius_label.text="Radius · %d tiles"%int(radius_slider.value)
	layout()

func layout():
	if not _built: return
	var size_=app.hud_rect().size
	var desktop=shell.layout_mode=="desktop"
	var portrait=shell.layout_mode=="portrait"
	grid.columns=3 if desktop else (4 if portrait else 5)
	var count=ability_buttons.size()
	var rows=ceili(float(maxi(1,count))/grid.columns)
	var palette_width=224 if desktop else (minf(340,size_.x-24) if portrait else 400)
	var palette_height=rows*68+102
	palette_note.custom_minimum_size.x=palette_width-20
	palette.custom_minimum_size=Vector2(palette_width,palette_height)
	palette.size=Vector2(palette_width,palette_height)
	palette.position=Vector2(90,clampf(shell.rail.position.y,66,maxf(66,size_.y-palette_height-16))) if desktop else Vector2((size_.x-palette_width)*0.5,size_.y-84-palette_height)
	active_box.vertical=portrait
	app.active_hint.visible=not portrait
	radius_label.visible=not portrait
	if portrait and not app.Powers.PERSON_TARGETS.has(app.selected_power): cost_label.text+=(" · R%d"%int(radius_slider.value)) if not " · R" in cost_label.text else ""
	tool_info.custom_minimum_size.x=0 if portrait else 230
	controls_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_END
	brush_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_BEGIN
	brush_box.custom_minimum_size.x=126
	radius_slider.custom_minimum_size.x=126
	radius_label.text="Radius · %d tiles"%int(radius_slider.value)
	var width_=minf(740,size_.x-360) if desktop else minf(680,size_.x-24)
	var height_=104 if portrait else 78
	active_strip.custom_minimum_size=Vector2(width_,height_)
	active_strip.size=Vector2(width_,height_)
	active_strip.position=Vector2((size_.x-width_)*0.5,size_.y-height_-16 if desktop else size_.y-height_-84)
