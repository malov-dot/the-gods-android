extends Control

const Simulation = preload("res://scripts/simulation.gd")
const Powers = preload("res://scripts/powers.gd")
const Saves = preload("res://scripts/save_manager.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Content = preload("res://scripts/content.gd")
const Shell = preload("res://scripts/interface_shell.gd")
const Community = preload("res://scripts/community_ui.gd")
const MobileDisplay = preload("res://scripts/mobile_display.gd")
const ChoiceButton = preload("res://scripts/choice_button.gd")
const TouchSlider = preload("res://scripts/touch_slider.gd")
const TouchScroll = preload("res://scripts/touch_scroll.gd")
const GOLD = Color("d9bd83")
const INK = Color("0c171b")
const PANEL = Color("142327")
const MUTED = Color("9faeaa")
const LIGHT = Color("e9e6d6")
const TEAL = Color("86c8b6")
const RED = Color("da8584")

var sim = Simulation.new()
var powers = Powers.new()
var world
var game_theme: Theme
var heading_font: Font
var settings: Dictionary = {}
var paused = true
var speed = 1
var accumulator = 0.0
var ui_clock = 0.0
var autosave_clock = 0.0
var simulation_busy=false
var simulation_slice_started=0
var deferred_world_action=Callable()
var pending_casts=[]
var lifecycle_save_pending=false
var selected_power = "inspect"
var category = "world"
var selected_id = -1
var current_slot = -1
var modal: Control
var modal_body: VBoxContainer
var modal_title: Label
var modal_was_paused = true
var year_label: Label
var world_label: Label
var population_label: Label
var age_label: Label
var faith_label: Label
var mana_label: Label
var side_label: Label
var pause_button: Button
var tools_box: VBoxContainer
var inspector_box: VBoxContainer
var chronicle_box: VBoxContainer
var status_label: Label
var tool_hint: Label
var power_name: Label
var brush_label: Label
var brush_slider: HSlider
var speed_buttons: Array = []
var tool_buttons: Dictionary = {}
var new_config: Dictionary = {}
var new_seed: LineEdit
var new_scenario: ChoiceButton
var new_size: ChoiceButton
var new_difficulty: ChoiceButton
var hover_x = -1
var hover_y = -1
var status_time = 0.0
var last_event_count = -1
var last_year_shown = -999
var ambience: AudioStreamPlayer
var sounds: AudioStreamPlayer
var world_audio
var world_stories
var game_started = false
var last_autosave_year = 0
var capture_path = ""
var capture_frames = 0
var capture_street = false
var tutorial_index = 0
var tutorial_active = false
var tutorial_label: Label
var tutorial_next: Button
var tutorial_panel: PanelContainer
var tutorial_evidence: Dictionary = {}
var overlay_select: OptionButton
var category_select: OptionButton
var last_event_id = -1
var shell=Shell.new()
var community
var compact_ui=false
var active_banner:PanelContainer
var active_hint:Label
var selected_person_key=""
var modal_panel:PanelContainer
var modal_scroll:ScrollContainer
var modal_desired=Vector2(380,640)
var modal_centered=false
var responsive_grids=[]

const TUTORIAL = [
	["01 / THE LIVING WORLD", "Tap a settlement to inspect it. Drag with one finger or the right mouse button to explore; pinch or scroll to zoom. Double-click a town, or expand its summary and choose Streets, to meet individual people.", "inspect"],
	["02 / SHAPE THE EARTH", "Choose Terrain from the side rail or bottom tray, then Land. The selected power and brush radius appear below. Tap the ocean to raise land; sandbox powers are unlimited.", "world"],
	["03 / A SIGN FROM ABOVE", "Choose the God category, then Bless, and select a person. Read their profile and influence them. Their role and relationships carry the consequences into their community.", "divine"],
	["04 / THE PRICE OF A BARGAIN", "Choose the Devil category and select a person to tempt or curse. Their household can react, and officials can change laws. Both divine traditions are yours to use.", "infernal"],
	["05 / WATCH HISTORY UNFOLD", "Use Play and the speed control to watch generations pass. Open Menu, then Chronicle, and select an event to see its causes.", "time"],
	["06 / YOUR WORLD, REMEMBERED", "Open Menu to save your world. People reveals every resident; Realms shows factions and leaders. Influence an individual to change their community's future.", "done"]
]

func _ready():
	get_window().min_size=Vector2i(360,320)
	MobileDisplay.configure(get_window())
	if OS.has_feature("android"): get_tree().quit_on_go_back=false
	community=Community.new(self)
	settings = Saves.load_settings()
	_build_theme()
	theme = game_theme
	_build_ui()
	_build_audio()
	world_audio=preload("res://scripts/world_audio.gd").new(); add_child(world_audio); world_audio.setup(self)
	world_stories=preload("res://scripts/world_stories.gd").new(); add_child(world_stories); world_stories.setup(self)
	var config = {"seed":"Eden-7401", "width":160, "height":100, "nations":5, "mode":"sandbox", "player_side":"god", "scenario":"genesis", "difficulty":"normal"}
	sim.new_world(config)
	world.sim = sim
	world.frame_world()
	_apply_settings()
	_refresh_ui(true)
	var args = OS.get_cmdline_user_args()
	capture_street = "--capture-street" in args
	for i in range(args.size()):
		if args[i] == "--capture" and i + 1 < args.size():
			capture_path = args[i + 1]
	if capture_path != "":
		game_started = true
		sim.step(40)
		_set_category("divine")
		_select_power("inspect")
		if not sim.state.settlements.is_empty():
			selected_id = sim.state.settlements[0].id
			world.selected_id = selected_id
		_refresh_ui(true)
	else:
		_show_new_world()

func _build_theme():
	game_theme = Theme.new()
	var body_font = FontVariation.new()
	body_font.base_font = preload("res://assets/fonts/inter.ttf")
	body_font.variation_opentype = {"wght":400}
	heading_font = FontVariation.new()
	heading_font.base_font = preload("res://assets/fonts/cormorantgaramond.ttf")
	heading_font.variation_opentype = {"wght":600}
	game_theme.default_font = body_font
	game_theme.default_font_size = 14
	game_theme.set_color("font_color", "Label", LIGHT)
	game_theme.set_color("font_color", "Button", LIGHT)
	game_theme.set_color("font_hover_color", "Button", GOLD)
	game_theme.set_color("font_pressed_color", "Button", GOLD)
	game_theme.set_color("font_disabled_color", "Button", Color("647780"))
	for type in ["Button", "OptionButton"]:
		game_theme.set_stylebox("normal", type, _style(Color("18282cdc"), Color("54605c"), 3, 8))
		game_theme.set_stylebox("hover", type, _style(Color("2b3e3d"), GOLD, 3, 8))
		game_theme.set_stylebox("pressed", type, _style(Color("5b5136"), GOLD, 3, 8))
		game_theme.set_stylebox("focus", type, _style(Color(0,0,0,0), TEAL, 5, 0))
		game_theme.set_stylebox("disabled", type, _style(Color("12212a"), Color("263640"), 5, 12))
	game_theme.set_stylebox("panel", "PanelContainer", _style(PANEL, Color("2a3e47"), 6, 16))
	game_theme.set_stylebox("normal", "LineEdit", _style(INK, Color("3e5358"), 4, 12))
	game_theme.set_stylebox("focus", "LineEdit", _style(INK, GOLD, 4, 12))
	game_theme.set_stylebox("panel", "PopupMenu", _style(INK, GOLD, 5, 8))
	game_theme.set_stylebox("panel", "TooltipPanel", _style(Color("07131c"), GOLD, 5, 12))
	game_theme.set_font_size("font_size", "TooltipLabel", 15)
	game_theme.set_color("font_color", "TooltipLabel", LIGHT)
	game_theme.set_color("font_color", "LineEdit", LIGHT)
	game_theme.set_constant("separation", "VBoxContainer", 9)
	game_theme.set_constant("separation", "HBoxContainer", 9)
	game_theme.set_stylebox("background", "ProgressBar", _style(Color("0c1820"), Color("2a3d43"), 3, 0))
	game_theme.set_stylebox("fill", "ProgressBar", _style(TEAL, TEAL, 3, 0))

func _style(bg: Color, border: Color, radius: int = 4, padding: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func _label(text: String, size: int = 15, color: Color = LIGHT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _paragraph(text: String, size: int = 14, color: Color = MUTED) -> Label:
	var l = _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _title(text: String, size: int = 28) -> Label:
	var l = _label(text, size, GOLD)
	l.add_theme_font_override("font", heading_font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(text: String, callback: Callable, min_height: int = 36) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = maxf(48,min_height)
	b.custom_minimum_size.x = minf(150,maxf(44,float(text.length())*7.2+24))
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text=text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): _dispatch_world_action(callback))
	b.pressed.connect(_click_sound)
	return b

func _dispatch_world_action(callback:Callable):
	if not callback.is_valid(): return
	if shell!=null and (callback.get_object()==shell.power_ui or (callback.get_object()==shell and callback.get_method() in ["open_power_category","observe"])):
		callback.call()
		return
	if simulation_busy and callback.get_method() not in ["_toggle_pause","_set_speed","_show_time_controls","_choose_time_speed","_pause_time_controls","_close_modal"]:
		if not deferred_world_action.is_valid(): deferred_world_action=callback
		_toast("Finishing this year…")
		return
	callback.call()

func _yield_simulation(epoch:int)->bool:
	if not is_inside_tree() or sim.generation!=epoch: return false
	if Time.get_ticks_usec()-simulation_slice_started>=8000:
		await get_tree().process_frame
		if not is_inside_tree() or sim.generation!=epoch: return false
		simulation_slice_started=Time.get_ticks_usec()
	return true

func _advance_world(years:int=1):
	if simulation_busy: return
	simulation_busy=true
	var epoch=sim.generation
	simulation_slice_started=Time.get_ticks_usec()
	await sim.step(years,_yield_simulation.bind(epoch))
	simulation_busy=false
	if not is_inside_tree() or sim.generation!=epoch:
		deferred_world_action=Callable()
		if is_inside_tree(): _refresh_ui(true)
		return
	tutorial_evidence["time"]=true
	# Annual changes refresh statistics and selection without rebuilding powers
	# and relaying out the entire HUD at every accelerated time tick.
	if paused or is_instance_valid(modal) or ui_clock>=0.2:
		ui_clock=0
		_refresh_ui()

func _expand():
	var c = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _line() -> HSeparator:
	var s = HSeparator.new()
	s.add_theme_stylebox_override("separator", _style(Color("30434b"), Color("30434b"), 0, 0))
	s.custom_minimum_size.y = 1
	return s

func _clear(node: Node):
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_ui():
	shell.build(self)
	resized.connect(_responsive_layout)

func _responsive_layout():
	MobileDisplay.configure(get_window())
	shell.layout()
	responsive_grids=responsive_grids.filter(func(grid):return is_instance_valid(grid))
	for grid in responsive_grids: grid.columns=2 if modal_centered and get_viewport_rect().size.x>=900 else 1
	if is_instance_valid(modal_panel):
		var bounds=hud_rect()
		var viewport_size=bounds.size
		var width_=minf(400,viewport_size.x-20)
		var height_=minf(modal_desired.y,viewport_size.y-96)
		var origin=Vector2(viewport_size.x-width_-16,64)
		if modal_centered:
			width_=minf(760,viewport_size.x-24)
			height_=minf(modal_desired.y,viewport_size.y-32)
			origin=(viewport_size-Vector2(width_,height_))*0.5
		elif shell.layout_mode=="portrait":
			width_=viewport_size.x-16
			height_=minf(540,viewport_size.y-100)
			origin=Vector2(8,viewport_size.y-height_-8)
		elif shell.layout_mode=="landscape":
			width_=minf(368,viewport_size.x*0.48)
			height_=viewport_size.y-24
			origin=Vector2(viewport_size.x-width_-8,12)
		if not modal_centered and is_instance_valid(modal_body) and modal_body.size.x>20:
			height_=minf(height_,maxf(190,modal_body.get_combined_minimum_size().y+94))
			if shell.layout_mode=="portrait": origin.y=viewport_size.y-height_-8
		modal_panel.custom_minimum_size=Vector2(width_,height_)
		modal_panel.position=bounds.position+origin
		modal_panel.size=Vector2(width_,height_)
		modal_scroll.custom_minimum_size.y=maxf(60,height_-92)
		modal_title.add_theme_font_size_override("font_size",20)

func hud_rect()->Rect2:
	return MobileDisplay.hud_rect(get_viewport_rect().size,get_window().content_scale_factor)

func _nav_world():
	shell.observe()

func _show_context_sheet():
	_show_town_tab("Overview")

func _show_town_tab(tab_name):
	var town=sim.get_settlement(selected_id)
	if town.is_empty(): return
	_open_modal(town.name,Vector2(400,630))
	modal_body.add_child(_label(_nation_name(town.nation)+" · "+_era_name(town.era)+" Age",13,GOLD))
	var tabs=HBoxContainer.new()
	modal_body.add_child(tabs)
	for label_ in ["Overview","Conditions","Culture"]:
		var button=_button(label_,_show_town_tab.bind(label_),48)
		button.custom_minimum_size.x=0
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode=true
		button.button_pressed=label_==tab_name
		tabs.add_child(button)
	if tab_name=="Overview":
		var data=GridContainer.new()
		data.columns=2
		data.add_theme_constant_override("h_separation",18)
		modal_body.add_child(data)
		for item in [["People",town.population+town.get("orbital_population",0)],["Food",town.food],["Wealth",town.wealth],["Knowledge",town.get("knowledge",0)]]:
			data.add_child(_label(item[0],13,MUTED))
			data.add_child(_label(_number(item[1]),15,LIGHT))
		_meter(modal_body,"Health",town.health,TEAL)
		_meter(modal_body,"Happiness",town.happiness,GOLD)
		if town.era<13: _meter(modal_body,"Next: "+_era_name(town.era+1),town.research/float(Content.ERAS[town.era].threshold),Color("9badca"))
		_belief_bars(modal_body,town.faith,town.corruption)
		if town.get("orbital_population",0)>0: modal_body.add_child(_label("Orbital residents: "+_number(town.orbital_population),13,TEAL))
	elif tab_name=="Conditions":
		modal_body.add_child(_paragraph("Equipment: "+world.people.weapon_name(int(town.era)),13,LIGHT))
		var conditions=[]
		for pair in [["plague","Plague"],["drought","Drought"],["blessing","Blessing"],["protection","Sanctuary"],["pact","Infernal pact"],["curse","Curse"]]:
			if town.get(pair[0],0)>0: conditions.append(pair[1]+" · "+str(town[pair[0]])+" years")
		modal_body.add_child(_paragraph("\n".join(conditions) if not conditions.is_empty() else "No active local conditions.",13,TEAL))
		_meter(modal_body,"Buildings intact",1.0-float(town.get("visual_damage",0)),GOLD)
		var at_war=false
		for war in sim.state.wars:
			if town.nation in [war.a,war.b]:
				at_war=true
				var side_="a" if town.nation==war.a else "b"
				modal_body.add_child(_paragraph("At war with %s · %s losses"%[_nation_name(war.b if side_=="a" else war.a),_number(war.get("casualties_"+side_,0))],13,RED))
		if not at_war: modal_body.add_child(_label("At peace",13,TEAL))
	else:
		modal_body.add_child(_paragraph(town.get("religion","Unwritten traditions"),14,GOLD))
		for figure in sim.state.people:
			if figure.get("alive",false) and figure.get("settlement",-1)==town.id:
				var person=sim.get_individual("p:"+str(figure.id))
				if not person.is_empty(): community.card(modal_body,person.name,str(person.role).capitalize()+" · age "+str(person.age),community.show_person.bind(person.key),GOLD,person)
		if not town.get("buildings",[]).is_empty(): modal_body.add_child(_paragraph("Landmarks: "+", ".join(town.buildings),13,LIGHT))
		modal_body.add_child(_button("Settlement history",_city_history.bind(int(town.id)),48))
	var actions=HBoxContainer.new()
	modal_body.add_child(_line())
	modal_body.add_child(actions)
	for item in [["Streets",func():_close_modal();_street_view()],["People",community.show_people.bind(int(town.id))],["Faction",community.show_faction.bind(int(town.nation))]]:
		var button=_button(item[0],item[1],48)
		button.custom_minimum_size.x=0
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(button)

func _on_person_clicked(key):
	if simulation_busy:
		if Powers.PERSON_TARGETS.has(selected_power): _dispatch_world_action(community.preview_action.bind(Powers.PERSON_TARGETS[selected_power],str(key)))
		else: _dispatch_world_action(_on_person_clicked.bind(key))
		return
	if is_instance_valid(modal): return
	if Powers.PERSON_TARGETS.has(selected_power):
		community.preview_action(Powers.PERSON_TARGETS[selected_power],str(key));return
	if selected_power!="inspect": return
	if shell.power_ui.palette.visible: shell.power_ui.close_palette()
	var person=sim.get_individual(str(key))
	if person.is_empty(): return
	selected_person_key=str(person.key)
	selected_id=int(person.settlement)
	world.selected_id=selected_id
	world.selected_person_key=selected_person_key
	_refresh_inspector()
	community.show_person(selected_person_key)

func _show_people():
	community.show_people()

func _show_factions():
	community.show_factions()

func _show_powers():
	shell.power_ui.open_category(shell.power_ui.group_id)

func _explain_power(id):
	var power=powers.get_power(id)
	_open_modal(power.name,Vector2(650,640))
	modal_body.add_child(_paragraph(power.description,18,LIGHT))
	var allowed=true
	if Powers.PERSON_TARGETS.has(id):
		modal_body.add_child(_paragraph("This power targets one resident. Their profile explains personal, family, and community consequences before you cast.",15))
		if not allowed: modal_body.add_child(_paragraph("This intervention belongs to the other deity.",15,RED))
		var choose=_button("Select a person",func():_close_modal();_select_power(id),48)
		choose.disabled=not allowed
		modal_body.add_child(choose)
		modal_body.add_child(_button("Back to powers",_show_powers,48))
		return
	modal_body.add_child(_paragraph("Choose how far this power reaches. Tap once to use it; drag with one finger to move the map. Desktop terrain tools can also paint while dragging.",15))
	var reach=_label("REACH · %d tiles"%world.brush_radius,13,GOLD)
	modal_body.add_child(reach)
	var slider=TouchSlider.new()
	slider.custom_minimum_size.y=48
	slider.min_value=1
	slider.max_value=10
	slider.step=1
	slider.value=minf(world.brush_radius,slider.max_value)
	slider.value_changed.connect(func(value):world.brush_radius=int(value);brush_slider.value=value;reach.text="REACH · %d tiles"%value)
	modal_body.add_child(slider)
	if not allowed: modal_body.add_child(_paragraph("This intervention is unavailable to your deity in this mode.",15,RED))
	var use=_button("Use on the world",func():_set_category(power.category);_select_power(id);_close_modal(),50)
	use.disabled=not allowed
	modal_body.add_child(use)
	modal_body.add_child(_button("Back to powers",_show_powers,46))

func _show_map_options():
	_open_modal("Read the world",Vector2(620,690))
	var options=[["Natural world","terrain","See the landscape, people, buildings and events."],["Kingdom borders","nations","Color territory by the faction that controls it."],["Faith & corruption","belief","Compare allegiance to God, the Devil and unaffiliated belief."],["Soil fertility","fertility","Find fertile ground that can support farms and communities."],["Technology","technology","Compare the ages reached by different civilizations."]]
	for item in options:
		community.card(modal_body,item[0],item[2],func():world.overlay=item[1];world.invalidate_terrain();overlay_select.select(["terrain","nations","belief","fertility","technology"].find(item[1]));_close_modal())
	community.card(modal_body,"Fit the whole world","Pull the camera back to see every continent.",func():world.reset_camera();_close_modal(),GOLD)

func _show_stories():
	preload("res://scripts/story_journal.gd").show(self)

func _show_menu():
	_open_modal("World menu",Vector2(400,680))
	for item in [["Lives & stories","Return to family appeals and people you follow.",_show_stories],["People","Find residents and influence individual lives.",_show_people],["Factions","Inspect kingdoms and their leaders.",_show_factions],["Map overlays","Compare borders, faith and technology.",_show_map_options],["Save this world","Keep its people, history and your interventions.",_show_save],["Return to a world","Load a saved history and resume from where you left off.",_show_load],["Create a world","Choose a new seed, scenario and world size.",_request_new],["Chronicle","Read what happened and the causes behind it.",_show_history],["Divine teachings","Shape both divine traditions and their effects on society.",_show_doctrines],["Technology","Explore the discoveries and buildings of all fourteen ages.",_show_technology],["How to play","Controls, strategy and explanations of the living world.",_show_guide],["Settings","Adjust sound, display, saving and the introduction.",_show_settings]]:
		community.card(modal_body,item[0],item[1],item[2])

func _header_stat(parent: Node, text: String) -> Label:
	var v = VBoxContainer.new()
	v.custom_minimum_size.x = 126
	v.add_theme_constant_override("separation", 3)
	parent.add_child(v)
	v.add_child(_label(text, 10, MUTED))
	var l = _label("—", 20)
	v.add_child(l)
	return l

func _build_left(parent: Node):
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 228
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("2a3e47"), 6, 12))
	parent.add_child(panel)
	var v = VBoxContainer.new()
	panel.add_child(v)
	var line = HBoxContainer.new()
	v.add_child(line)
	line.add_child(_label("YOUR INFLUENCE", 12, GOLD))
	line.add_child(_expand())
	line.add_child(_button("?", _show_guide, 28))
	var inspect = _button("Observe the world", _select_power.bind("inspect"), 42)
	inspect.tooltip_text = "Inspect civilizations without intervening. Shortcut: Escape."
	v.add_child(inspect)
	var chooser = OptionButton.new()
	category_select = chooser
	chooser.name = "PowerCategory"
	for name_ in ["World shaping", "Life & creation", "Miracles", "Temptations", "Cataclysms"]:
		chooser.add_item(name_)
	chooser.item_selected.connect(func(index):
		category = ["world","life","divine","infernal","disaster"][index]
		_refresh_tools()
	)
	v.add_child(chooser)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	tools_box = VBoxContainer.new()
	tools_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tools_box)
	v.add_child(_line())
	power_name = _label("THE WATCHFUL EYE", 12, GOLD)
	v.add_child(power_name)
	tool_hint = _paragraph("Select a power, then touch the world. Every action leaves a trace.", 13)
	tool_hint.custom_minimum_size.y = 68
	v.add_child(tool_hint)
	brush_label = _label("REACH   3 tiles", 11, MUTED)
	v.add_child(brush_label)
	var brush = HSlider.new()
	brush_slider=brush
	brush.min_value = 1
	brush.max_value = 10
	brush.step = 1
	brush.value = 3
	brush.value_changed.connect(func(value):
		world.brush_radius = int(value)
		brush_label.text = "REACH   %d tiles" % int(value)
	)
	v.add_child(brush)
	v.add_child(_button("Divine teachings", _show_doctrines))
	v.add_child(_button("World atlas", _show_atlas))

func _build_tutorial(parent: Node):
	tutorial_panel = PanelContainer.new()
	tutorial_panel.add_theme_stylebox_override("panel", _style(Color("253c3b"), GOLD, 5, 10))
	tutorial_panel.visible = false
	parent.add_child(tutorial_panel)
	var row = HBoxContainer.new()
	tutorial_panel.add_child(row)
	tutorial_label = _paragraph("", 13, LIGHT)
	row.add_child(tutorial_label)
	tutorial_next = _button("Next", _tutorial_advance)
	row.add_child(tutorial_next)
	row.add_child(_button("Close", func(): tutorial_active = false; tutorial_panel.hide()))

func _refresh_tools():
	_clear(tools_box)
	tool_buttons.clear()
	for p in Powers.CATALOG:
		if p.category != category:
			continue
		var b = _button(p.name, _select_power.bind(p.id), 43)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		b.toggle_mode = true
		b.button_pressed = p.id == selected_power
		b.tooltip_text = p.description
		tools_box.add_child(b)
		tool_buttons[p.id] = b

func _select_power(id: String):
	if Powers.PERSON_TARGETS.has(id):
		selected_power=id
		world.active_power="inspect"
		power_name.text=powers.get_power(id).name
		tool_hint.text="Touch a person to preview this influence. Touch a community to choose a resident."
		if shell.power_ui!=null: shell.power_ui.refresh()
		return
	selected_power = id
	world.active_power = id
	if id == "inspect":
		brush_slider.max_value=10
		power_name.text = "THE WATCHFUL EYE"
		tool_hint.text = "Click a settlement to learn its story. Double-click for Street View. Right-drag to explore."
	else:
		for p in Powers.CATALOG:
			if p.id == id:
				brush_slider.max_value=10
				power_name.text = p.name.to_upper()
				tool_hint.text = p.description
	for key in tool_buttons:
		tool_buttons[key].button_pressed = key == id
	if shell.power_ui!=null: shell.power_ui.refresh()

func _set_category(value: String):
	category=value
	category_select.select(["world","life","divine","infernal","disaster"].find(value))
	_refresh_tools()

func _process(delta):
	if sim.state.is_empty():
		return
	if not simulation_busy and not pending_casts.is_empty():
		var cast=pending_casts.pop_front()
		if cast.sim==sim and cast.epoch==sim.generation: _cast_on_world(cast)
	if not simulation_busy and pending_casts.is_empty() and deferred_world_action.is_valid():
		var action=deferred_world_action
		deferred_world_action=Callable()
		action.call()
	world.queue_redraw()
	if not paused and not is_instance_valid(modal):
		accumulator = minf(accumulator + delta * speed,float(speed))
	if not simulation_busy and pending_casts.is_empty() and not paused and not is_instance_valid(modal):
		var steps = mini(20, int(accumulator))
		if steps > 0:
			var simulation_start=Time.get_ticks_usec()
			var advanced=0
			for i in range(steps):
				_advance_world(1)
				advanced+=1
				if simulation_busy or Time.get_ticks_usec()-simulation_start>12000:
					break
			accumulator -= advanced
			tutorial_evidence["time"] = true
	ui_clock += delta
	autosave_clock += delta
	if ui_clock > 0.45 and not simulation_busy:
		ui_clock = 0
		_refresh_ui()
	if (autosave_clock > 90 or lifecycle_save_pending) and not simulation_busy and game_started and settings.get("autosave", true):
		autosave_clock = 0
		lifecycle_save_pending=false
		var saved = Saves.save_game(sim.state, 9)
		if saved.ok:
			last_autosave_year = sim.state.year
		else:
			_toast(saved.get("message", "Autosave failed"), true)
	if status_time > 0:
		status_time -= delta
		if status_time <= 0:
			status_label.add_theme_color_override("font_color", MUTED)
			status_label.text = ""
	if capture_path != "":
		capture_frames += 1
		if capture_frames == 5 and capture_street: _street_view()
		if capture_frames == 15:
			_capture.call_deferred()

func _capture():
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var result = img.save_png(capture_path)
	print("CAPTURE ", capture_path, " result=", result)
	_stop_audio()
	await get_tree().process_frame
	get_tree().quit(0 if result == OK else 1)

func _refresh_ui(force: bool = false):
	var st = sim.state
	var stats = st.get("stats", {})
	year_label.text = "Year %s" % _number(st.get("year", 0))
	world_label.text = ("%s  /  %s" % [st.get("seed", "Eden"), _scenario_name(st.get("settings", {}).get("scenario","genesis"))]).to_upper()
	population_label.text = _number(stats.get("population", 0))
	faith_label.text = "%d%%  /  %d%%" % [stats.get("god",0)*100,stats.get("devil",0)*100]
	faith_label.tooltip_text = "God / Devil share of the living population. The remainder are unaffiliated."
	var side = _current_side()
	mana_label.text = "Unlimited"
	var highest = 0
	for city in st.get("settlements",[]):
		highest = maxi(highest, int(city.get("era",0)))
	age_label.text = _era_name(highest)
	pause_button.text = "Play" if paused else "Pause"
	pause_button.disabled = false
	shell.speed_button.text = str(speed)+"×"
	shell.speed_button.disabled = false
	for i in range(speed_buttons.size()):
		speed_buttons[i].button_pressed = [1,5,20,100][i] == speed
		speed_buttons[i].disabled = false
	if force or last_year_shown != st.get("year"):
		_refresh_inspector()
		last_year_shown = st.get("year")
	var event_id = st.events[-1].get("id",-1) if st.events.size() > 0 else -1
	if force or last_event_count != st.events.size() or event_id != last_event_id:
		_refresh_chronicle()
		last_event_count = st.events.size()
		last_event_id = event_id
	if force:
		_refresh_tools()
	shell.refresh()
	if world_stories!=null: world_stories.refresh()
	if force: shell.layout()

func _refresh_inspector():
	shell.refresh_selection()
	_clear(inspector_box)
	if selected_person_key!="" and sim.has_method("get_individual"):
		var individual=sim.get_individual(selected_person_key)
		if not individual.is_empty():
			community.fill_person(inspector_box,individual,false)
			return
	var city = sim.get_settlement(selected_id) if selected_id >= 0 else {}
	if city.is_empty() or city.get("population",0)+city.get("orbital_population",0) <= 0:
		selected_id = -1
		world.selected_id = -1
		inspector_box.add_child(_label("THE MORTAL REALM", 12, GOLD))
		inspector_box.add_child(_title("A living world", 25))
		inspector_box.add_child(_paragraph("Each kingdom has its own ambitions. Touch a settlement to discover its story."))
		inspector_box.add_child(_line())
		_belief_bars(inspector_box, sim.state.get("stats",{}).get("god",0),sim.state.get("stats",{}).get("devil",0))
		inspector_box.add_child(_line())
		inspector_box.add_child(_label("KINGDOMS", 11, MUTED))
		for nation in sim.state.get("nations",[]):
			var pop = 0
			var city_id = -1
			for c in sim.state.settlements:
				if c.get("nation",-1) == nation.id and c.get("population",0)+c.get("orbital_population",0)>0:
					pop += int(c.population+c.get("orbital_population",0))
					city_id = c.id
			if pop <= 0:
				continue
			var b = _button(nation.name + "   " + _number(pop), _inspect_city.bind(city_id), 36)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size",13)
			b.add_theme_color_override("font_color", Color(nation.get("color","86c8b6")))
			inspector_box.add_child(b)
		inspector_box.add_child(_line())
		inspector_box.add_child(_label("BEYOND THE VEIL",11,GOLD))
		var souls = sim.state.get("afterlife",{})
		inspector_box.add_child(_paragraph("Heaven  %s\nHell  %s\nWandering  %s" % [_number(souls.get("heaven",0)),_number(souls.get("hell",0)),_number(souls.get("wandering",0))]))
		var wars = sim.state.get("wars",[])
		inspector_box.add_child(_paragraph("%d ongoing wars  ·  %d living settlements" % [wars.size(),sim.state.get("stats",{}).get("settlements",sim.state.settlements.size())],12))
		if sim.state.get("orbital_population",0)>0:
			inspector_box.add_child(_label("THE CELESTIAL FRONTIER",11,GOLD))
			inspector_box.add_child(_paragraph("%s people live in orbital habitats. Their colonies provide research and supplies to Earth." % _number(sim.state.orbital_population),13,TEAL))
		return
	inspector_box.add_child(_label("SETTLEMENT / " + _nation_name(city.get("nation",-1)).to_upper(),11,GOLD))
	inspector_box.add_child(_title(city.name, 27))
	inspector_box.add_child(_label(_era_name(city.get("era",0)) + " · Founded %d" % city.get("founded",0),12,MUTED))
	inspector_box.add_child(_paragraph(Content.ERAS[clampi(int(city.get("era",0)),0,Content.ERAS.size()-1)].description,12))
	inspector_box.add_child(_button("Explore these streets",_street_view,36))
	inspector_box.add_child(_button("Meet every resident",community.show_people.bind(int(city.id)),44))
	inspector_box.add_child(_button("Faction & leaders",community.show_faction.bind(int(city.nation)),44))
	inspector_box.add_child(_line())
	var figures = GridContainer.new()
	figures.columns = 2
	figures.add_theme_constant_override("h_separation",12)
	inspector_box.add_child(figures)
	for item in [["Population",_number(city.population)],["Food reserves",_number(city.get("food",0))],["Wealth",_number(city.get("wealth",0))],["Knowledge",_number(city.get("knowledge",0))]]:
		figures.add_child(_label(item[0],12,MUTED))
		figures.add_child(_label(item[1],14,LIGHT))
	if city.get("orbital_population",0)>0:
		figures.add_child(_label("Orbital population",12,MUTED))
		figures.add_child(_label(_number(city.orbital_population),14,TEAL))
	inspector_box.add_child(_label("MILITARY EQUIPMENT",11,GOLD))
	inspector_box.add_child(_paragraph(world.people.weapon_name(int(city.get("era",0))),13,LIGHT))
	for war in sim.state.get("wars",[]):
		if city.nation in [war.get("a",-1),war.get("b",-1)]:
			var side="a" if city.nation==war.a else "b"
			var rival=war.b if side=="a" else war.a
			inspector_box.add_child(_paragraph("At war with %s\nRecorded military losses: %s"%[_nation_name(rival),_number(war.get("casualties_"+side,0))],12,RED))
	if float(city.get("visual_damage",0))>0.01:
		_meter(inspector_box,"Buildings intact / rebuilding",1.0-float(city.visual_damage),Color("bd9c79"))
	_meter(inspector_box,"Health",city.get("health",0),TEAL)
	_meter(inspector_box,"Happiness",city.get("happiness",0),GOLD)
	if city.get("era",0)<Content.ERAS.size()-1:
		_meter(inspector_box,"Next age: "+_era_name(city.era+1),city.get("research",0)/float(Content.ERAS[city.era].threshold),Color("a995d2"))
	_belief_bars(inspector_box,city.get("faith",0),city.get("corruption",0))
	var conditions: Array = []
	for pair in [["plague","Plague"],["drought","Drought"],["blessing","Blessed"],["protection","Protected"]]:
		if city.get(pair[0],0) > 0:
			conditions.append("%s: %d years" % [pair[1],city[pair[0]]])
	if not conditions.is_empty():
		inspector_box.add_child(_paragraph("\n".join(conditions),12,GOLD))
	inspector_box.add_child(_line())
	inspector_box.add_child(_label("CULTURE & FAITH",11,GOLD))
	inspector_box.add_child(_paragraph(city.get("religion","Unwritten traditions"),14,LIGHT))
	var people: Array = []
	for person in sim.state.get("people",[]):
		if person.get("settlement",-1) == city.id and person.get("alive",true):
			people.append(person)
	for person in people.slice(0,4):
		inspector_box.add_child(_button("%s %s · age %d" % [str(person.get("role","Citizen")).capitalize(),person.get("name","Unknown"),person.get("age",0)],community.show_person.bind("p:"+str(person.id)),44))
	var buildings = city.get("buildings",[])
	if not buildings.is_empty():
		inspector_box.add_child(_line())
		inspector_box.add_child(_label("CITY LANDMARKS",11,GOLD))
		inspector_box.add_child(_paragraph(" · ".join(buildings),12))
	inspector_box.add_child(_button("Follow this civilization", _city_history.bind(city.id)))
	inspector_box.add_child(_button("Return to world", func(): selected_id=-1; world.selected_id=-1; _refresh_inspector()))

func _meter(parent: Node, label_: String, value: float, color: Color):
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation",3)
	parent.add_child(v)
	var normal = clampf(value,0,1)
	v.add_child(_label("%s   %d%%" % [label_,normal*100],12,MUTED))
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.value = normal*100
	bar.add_theme_stylebox_override("fill",_style(color,color,2,0))
	v.add_child(bar)

func _belief_bars(parent: Node, god: float, devil: float):
	_meter(parent,"Faith in God",god,TEAL)
	_meter(parent,"Devil allegiance",devil,RED)
	_meter(parent,"Unaffiliated",maxf(0,1-god-devil),Color("718793"))

func _refresh_chronicle():
	_clear(chronicle_box)
	var events = sim.state.get("events",[])
	for i in range(events.size()-1,maxi(-1,events.size()-4),-1):
		var e = events[i]
		var b = _button("%04d    %s" % [int(e.get("year",0)),e.get("title","An event")],_show_event.bind(e),27)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size",12)
		b.add_theme_stylebox_override("normal",_style(PANEL,PANEL,2,3))
		b.tooltip_text = e.get("detail","")
		chronicle_box.add_child(b)

func _on_tile_hovered(x: int, y: int):
	hover_x=x
	hover_y=y
	if status_time > 0:
		return
	var tile = sim.get_tile(x,y)
	if not tile.is_empty():
		status_label.text = "%s  ·  %d, %d  ·  Fertility %d%%  ·  Rainfall %d%%  ·  %s" % [str(tile.get("biome","land")).capitalize(),x,y,tile.get("fertility",0)*100,tile.get("moisture",0)*100,("Tap to inspect" if compact_ui else "Click to inspect") if selected_power=="inspect" else "Use " + power_name.text.to_lower()]

func _on_tile_clicked(x: int, y: int, button: int):
	if button != MOUSE_BUTTON_LEFT or is_instance_valid(modal): return
	if Powers.PERSON_TARGETS.has(selected_power):
		var action=Powers.PERSON_TARGETS[selected_power]
		var city=sim.nearest_settlement(x,y,8.0)
		if city.is_empty():
			_toast("Touch a person or a community to choose who receives this power.",true)
		else: _dispatch_world_action(_choose_person_in_community.bind(int(city.id),action))
		return
	if selected_power=="inspect":
		if simulation_busy:
			_dispatch_world_action(_on_tile_clicked.bind(x,y,button)); return
		if shell.power_ui.palette.visible: shell.power_ui.close_palette()
		selected_person_key="";world.selected_person_key=""
		var city=sim.nearest_settlement(x,y,8.0)
		selected_id=city.get("id",-1);world.selected_id=selected_id
		_refresh_inspector();shell.refresh_selection()
		tutorial_evidence["inspect"]=selected_id>=0
		return
	var cast={"sim":sim,"epoch":sim.generation,"id":selected_power,"x":x,"y":y,"radius":world.brush_radius,"side":_current_side()}
	if simulation_busy:
		if pending_casts.size()>=16:
			_toast("16 powers are waiting. Let this year finish before casting more.",true);return
		pending_casts.append(cast)
		world.show_cast_feedback(selected_power,x,y,world.brush_radius,"Queued · "+powers.get_power(selected_power).name,"",true)
		_toast("%s queued · finishing this year. %d waiting."%[powers.get_power(selected_power).name,pending_casts.size()])
	else: _cast_on_world(cast)

func _choose_person_in_community(town_id:int,action:String):
	community.show_people(town_id)
	community.pending_action=action
	_toast("Choose the person who receives this power.")

func _cast_on_world(cast:Dictionary):
	var result=powers.apply(sim,cast.id,cast.x,cast.y,cast.radius,cast.side)
	var power=powers.get_power(cast.id)
	_toast(result.get("message","The world changes."),not result.get("ok",false))
	world.show_cast_feedback(cast.id,cast.x,cast.y,cast.radius,power.name if result.ok else "No effect · choose another target","",false,not result.ok)
	if result.get("ok",false):
		world.invalidate_terrain();sim.refresh_totals()
		tutorial_evidence[power.category]=true
		_refresh_ui(true)
		_play_tone(260 if power.category in ["infernal","disaster"] else 520)

func _inspect_city(id: int):
	selected_person_key=""
	world.selected_person_key=""
	selected_id = id
	world.selected_id = id
	var c = sim.get_settlement(id)
	if not c.is_empty():
		world.center_on_tile(c.x,c.y)
	_refresh_inspector()
	shell.refresh_selection()

func _street_view():
	var city=sim.get_settlement(selected_id) if selected_id>=0 else {}
	if city.is_empty():
		for town in sim.state.get("settlements",[]):
			if town.get("population",0)>0:
				city=town
				break
	if city.is_empty():
		_toast("Create a settlement first, then explore its streets.")
		return
	selected_id=city.id
	world.focus_settlement(city.id,true)
	_select_power("inspect")
	_refresh_inspector()

func _current_side() -> String:
	return "devil" if category=="infernal" else "god"
func _toggle_pause():
	paused = not paused
	_refresh_ui()

func _set_speed(value: int):
	speed=value
	accumulator=0
	paused=false
	_refresh_ui()

func _show_time_controls():
	deferred_world_action=Callable()
	_open_modal("The flow of time",Vector2(400,430))
	modal.set_meta("time_controls",true)
	modal_body.add_child(_paragraph("Choose a pace for your world. Selecting a speed resumes time.",14,LIGHT))
	var choices=GridContainer.new()
	choices.columns=2
	choices.add_theme_constant_override("h_separation",10)
	choices.add_theme_constant_override("v_separation",10)
	modal_body.add_child(choices)
	for choice in [[1,"Natural","Watch individual lives."],[5,"Swift","Follow a growing community."],[20,"Generations","See families and kingdoms change."],[100,"Ages","Let history unfold quickly."]]:
		var card=VBoxContainer.new()
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		choices.add_child(card)
		var button=_button("%d× · %s"%[choice[0],choice[1]],_choose_time_speed.bind(choice[0]),56)
		button.toggle_mode=true
		button.button_pressed=speed==choice[0]
		button.set_meta("time_speed",choice[0])
		card.add_child(button)
		card.add_child(_paragraph(choice[2],13,MUTED))
	modal_body.add_child(_button("Keep paused" if modal_was_paused else "Pause the world",_pause_time_controls,52))
	modal_body.add_child(_paragraph("Crowded worlds advance at the pace your device can simulate. Close this panel or use Back to keep your previous pace.",12,MUTED))

func _choose_time_speed(value:int):
	_close_modal()
	_set_speed(value)

func _pause_time_controls():
	_close_modal()
	paused=true
	_refresh_ui()

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode==KEY_ESCAPE and ChoiceButton.close_open_choices(get_tree()):
		get_viewport().set_input_as_handled()
		return
	if event.keycode==KEY_ESCAPE and is_instance_valid(modal):
		_close_modal()
		get_viewport().set_input_as_handled()
		return
	if simulation_busy and event.keycode not in [KEY_ESCAPE,KEY_SPACE,KEY_1,KEY_2,KEY_3,KEY_4,KEY_HOME,KEY_F11]:
		_dispatch_world_action(_unhandled_key_input.bind(event.duplicate()))
		get_viewport().set_input_as_handled()
		return
	if event.keycode==KEY_ESCAPE:
		if is_instance_valid(modal):
			_close_modal()
		else:
			shell.power_ui.cancel()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(modal):
		return
	if event.ctrl_pressed and event.keycode==KEY_S:
		_quick_save()
	elif event.ctrl_pressed and event.keycode==KEY_O:
		_show_load()
	elif event.keycode==KEY_SPACE:
		_toggle_pause()
	elif event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
		_set_speed([1,5,20,100][event.keycode-KEY_1])
	elif event.keycode==KEY_HOME:
		world.reset_camera()
	elif event.keycode==KEY_F11:
		settings.fullscreen = not settings.get("fullscreen",false)
		_apply_settings()
	elif event.keycode==KEY_H:
		_show_history()

func _toast(text: String, error: bool=false):
	status_label.text=text
	status_label.add_theme_color_override("font_color",RED if error else GOLD)
	status_time=5.0
	if shell!=null:
		shell.status_panel.visible=not is_instance_valid(modal)
		shell.layout.call_deferred()

func _number(value) -> String:
	var n = int(value)
	var s = str(absi(n))
	var result=""
	for i in range(s.length()):
		if i>0 and (s.length()-i)%3==0:
			result+=","
		result+=s[i]
	return ("-" if n<0 else "")+result

func _era_name(index: int) -> String:
	return Content.ERAS[clampi(index,0,Content.ERAS.size()-1)].name

func _nation_name(id: int) -> String:
	for n in sim.state.get("nations",[]):
		if n.id==id:
			return n.name
	return "Independent"

func _mode_name(_mode:String)->String:
	return "Sandbox"
func _scenario_name(id: String) -> String:
	return {"genesis":"Genesis","fractured":"The fractured crown","dying":"A dying world","enlightenment":"Age of reason"}.get(id,id)

func _open_modal(title_: String, desired: Vector2 = Vector2(380,640)):
	ChoiceButton.close_open_choices(get_tree())
	if is_instance_valid(world): world.cancel_touch_gesture()
	if shell.power_ui!=null: shell.power_ui.palette.hide()
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	else: modal_was_paused=paused
	paused=true
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.z_index=100
	add_child(modal)
	var dim=ColorRect.new()
	dim.color=Color(0.02,0.04,0.045,0.18)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: _close_modal()
		elif event is InputEventScreenTouch and event.pressed: _close_modal())
	modal.add_child(dim)
	modal_panel=PanelContainer.new()
	modal_desired=desired
	modal_centered=title_=="THE GODS"
	modal_panel.add_theme_stylebox_override("panel",_style(Color("122227fa"),Color("887651"),4,12))
	modal.add_child(modal_panel)
	var body=VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	modal_panel.add_child(body)
	var top=HBoxContainer.new()
	body.add_child(top)
	modal_title=_title(title_,20)
	modal_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	modal_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(modal_title)
	top.add_child(shell.icon_button("close","",_close_modal,"Close this panel and return to the world.",48))
	body.add_child(_line())
	modal_scroll=TouchScroll.new()
	modal_scroll.input_layer=modal
	modal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(modal_scroll)
	modal_body=VBoxContainer.new()
	modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation",8)
	modal_scroll.add_child(modal_body)
	modal_body.minimum_size_changed.connect(_responsive_layout.call_deferred)
	_responsive_layout()
	_responsive_layout.call_deferred()
	modal_panel.modulate.a=0.0
	create_tween().tween_property(modal_panel,"modulate:a",1.0,0.12)

func _close_modal():
	ChoiceButton.close_open_choices(get_tree())
	if community!=null: community.pending_action=""
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=null
	modal_panel=null
	modal_scroll=null
	if not game_started and not sim.state.is_empty():
		game_started=true
	paused=modal_was_paused
	_refresh_ui()

func _request_new():
	if not game_started:
		_show_new_world()
		return
	_open_modal("Create another world?",Vector2(640,390))
	modal_body.add_child(_paragraph("Your current world will be replaced. Save it to keep this history before beginning another.",17,LIGHT))
	modal_body.add_child(_button("Save current world and continue",func():
		var result=Saves.save_game(sim.state,current_slot if current_slot>=0 else 9)
		if result.ok:
			_show_new_world()
		else:
			_toast(result.get("message","Save failed"),true)
	,44))
	modal_body.add_child(_button("Create without saving",_show_new_world,40))

func _show_new_world():
	_open_modal("THE GODS",Vector2(930,790))
	modal_body.add_child(_paragraph("SHAPE THE EARTH. INHERIT ITS STORIES.",12,GOLD))
	modal_body.add_child(_paragraph("Raise continents, awaken civilizations, and decide how you will be remembered. Humanity will make its own choices.",17,LIGHT))
	var grid=GridContainer.new()
	grid.columns=1 if compact_ui else 2
	responsive_grids.append(grid)
	grid.add_theme_constant_override("h_separation",28)
	grid.add_theme_constant_override("v_separation",14)
	modal_body.add_child(grid)
	new_scenario=_form_option(grid,"THE FIRST CHAPTER",["Genesis — a new beginning","The fractured crown — rival kingdoms","A dying world — heal a wounded earth","Age of reason — Renaissance awakening"])
	new_size=_form_option(grid,"WORLD SIZE",["Intimate  ·  128 × 80","Expansive  ·  160 × 100","Vast  ·  224 × 140"])
	new_size.select(1)
	new_difficulty=_form_option(grid,"MORTAL RESILIENCE",["Gentle — forgiving survival","Balanced — prosperity and peril","Harsh — a demanding world"])
	new_difficulty.select(1)
	var seedbox=VBoxContainer.new()
	seedbox.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_child(seedbox)
	seedbox.add_child(_label("WORLD SEED / NAME",11,GOLD))
	var seedrow=HBoxContainer.new()
	seedbox.add_child(seedrow)
	new_seed=LineEdit.new()
	new_seed.text="Eden-%04d" % (randi()%10000)
	new_seed.max_length=40
	new_seed.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	new_seed.custom_minimum_size.y=48
	seedrow.add_child(new_seed)
	var random_seed=_button("Random",func():new_seed.text="Eden-%04d"%(randi()%10000),48)
	random_seed.custom_minimum_size.x=82
	seedrow.add_child(random_seed)
	var scenario_note=_paragraph("Genesis begins with small settlements and unwritten beliefs. Every civilization discovers technology at its own pace, from Stone Age to Space Age.",14,MUTED)
	modal_body.add_child(scenario_note)
	new_scenario.item_selected.connect(func(index):
		scenario_note.text=["Genesis begins with small settlements and unwritten beliefs. Every civilization discovers technology at its own pace, from Stone Age to Space Age.","Rival kingdoms inherit an uneasy world. Borders, diplomacy, and competition for resources turn influence into a political struggle.","A vulnerable population faces scarcity and sickness. Restore the land, guide migration, or profit from desperation.","Renaissance cultures enter an age of discovery. Industry lies ahead, while the spread of knowledge changes the struggle for belief."][index]
	)
	modal_body.add_child(_line())
	var startrow=VBoxContainer.new()
	modal_body.add_child(startrow)
	var create=_button("Bring this world to life",_start_world,54)
	create.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	create.add_theme_color_override("font_color",GOLD)
	startrow.add_child(create)
	startrow.add_child(_button("Load a saved world",_show_load,54))
	var tutorial=CheckButton.new()
	tutorial.custom_minimum_size.y=48
	tutorial.text="Show the six-step introduction"
	tutorial.button_pressed=settings.get("show_tutorial",true)
	tutorial.toggled.connect(func(value):settings.show_tutorial=value;Saves.save_settings(settings))
	modal_body.add_child(tutorial)
	modal_body.add_child(_paragraph("A single-player sandbox. Shape the world with every God and Devil power, freely. Follow people, families and civilizations for as long as you choose.",12,MUTED))

func _form_option(parent:Node,label_:String,choices:Array)->ChoiceButton:
	var v=VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	v.add_child(_label(label_,11,GOLD))
	var o=ChoiceButton.new(self,label_)
	o.custom_minimum_size=Vector2(0,48)
	for c in choices:
		o.add_item(c)
	v.add_child(o)
	return o

func _start_world():
	var sizes=[Vector2i(128,80),Vector2i(160,100),Vector2i(224,140)]
	var dims=sizes[new_size.selected]
	var config={"seed":new_seed.text.strip_edges(),"width":dims.x,"height":dims.y,"nations":5 if new_scenario.selected!=1 else 7,"mode":"sandbox","player_side":"god","scenario":["genesis","fractured","dying","enlightenment"][new_scenario.selected],"difficulty":["gentle","normal","harsh"][new_difficulty.selected]}
	if config.seed=="":
		config.seed="Eden-%04d"%(randi()%10000)
	sim.new_world(config)
	current_slot=-1
	sim.state["session_started"]=Time.get_datetime_string_from_system()
	world.sim=sim
	world.overlay="terrain"
	overlay_select.select(0)
	world.invalidate_terrain()
	world.frame_world()
	selected_id=-1
	world.selected_id=-1
	selected_person_key=""
	world.selected_person_key=""
	game_started=true
	last_event_count=-1
	last_autosave_year=-1
	accumulator=0
	_close_modal()
	paused=true
	speed=1
	_select_power("inspect")
	_set_category("world")
	_refresh_ui(true)
	if settings.get("show_tutorial",true):
		_start_tutorial()
	else:
		tutorial_panel.hide()
		tutorial_active=false
	_toast("A new world awaits your influence. Use Play to let time flow.")

func _start_tutorial():
	tutorial_index=0
	tutorial_active=true
	tutorial_evidence.clear()
	tutorial_panel.hide()
	_update_tutorial()

func _update_tutorial():
	var step=TUTORIAL[tutorial_index]
	_open_modal("First steps · %d / 6"%(tutorial_index+1),Vector2(380,330))
	modal_body.add_child(_paragraph(step[1],14,LIGHT))
	modal_body.add_child(_button("Finish" if tutorial_index==TUTORIAL.size()-1 else "Next",_tutorial_advance,48))
	modal_body.add_child(_button("Explore on my own",func():tutorial_active=false;_close_modal(),48))

func _tutorial_advance():
	tutorial_index+=1
	if tutorial_index>=TUTORIAL.size():
		tutorial_active=false
		tutorial_panel.hide()
		settings.show_tutorial=false
		Saves.save_settings(settings)
		_close_modal()
	else:
		_update_tutorial()

func _show_save():
	_open_modal("Preserve this history",Vector2(780,580))
	modal_body.add_child(_paragraph("Each save preserves the terrain, civilizations, beliefs, figures, and unfolding consequences. Autosave uses its own slot.",15,LIGHT))
	var slots=Saves.list_saves()
	for i in range(3):
		var slot_data={}
		for item in slots:
			if item.get("slot",-1)==i:
				slot_data=item
		var label_="Slot %d  ·  %s"%[i+1,_save_description(slot_data)]
		modal_body.add_child(_button(label_,_save_slot.bind(i),60))
	modal_body.add_child(_paragraph("Ctrl+S saves quickly to your last chosen slot. Browser saves stay in this browser on this device; Windows saves stay in your user data folder. Each is separate from the game installation.",13))

func _save_description(data:Dictionary)->String:
	if data.is_empty() or not data.get("ok",true):
		return "Empty slot" if data.is_empty() else data.get("message","Unreadable save")
	if data.has("exists") and not data.exists:
		return "Empty slot"
	return "%s · Year %d"%[data.get("seed",data.get("name","Saved world")),data.get("year",0)]

func _save_slot(slot:int):
	var existing=Saves.load_game(slot)
	if existing.get("ok",false):
		_open_modal("Replace saved world?",Vector2(650,380))
		var old=existing.get("state",{})
		modal_body.add_child(_paragraph("Slot %d contains %s, year %d. Replace it with the current world?"%[slot+1,old.get("seed","a world"),old.get("year",0)],17,LIGHT))
		modal_body.add_child(_button("Replace slot %d"%(slot+1),_perform_save.bind(slot),46))
		modal_body.add_child(_button("Back to saves",_show_save))
	else:
		_perform_save(slot)

func _perform_save(slot:int):
	var result=Saves.save_game(sim.state,slot)
	if result.ok:
		current_slot=slot
		_close_modal()
	_toast(result.get("message","World saved."),not result.ok)

func _quick_save():
	if current_slot<0:
		_show_save()
		return
	var result=Saves.save_game(sim.state,current_slot)
	_toast(result.get("message","World saved."),not result.ok)

func _show_load():
	_open_modal("Return to a world",Vector2(780,640))
	modal_body.add_child(_paragraph("Loading replaces the world currently on screen. Save it first if you want to keep its latest changes.",15,LIGHT))
	var slots=Saves.list_saves()
	for i in [0,1,2,9]:
		var data={}
		for item in slots:
			if item.get("slot",-1)==i:
				data=item
		var prefix="Autosave" if i==9 else "Slot %d"%(i+1)
		var b=_button(prefix+"  ·  "+_save_description(data),_confirm_load.bind(i),58)
		b.disabled=data.is_empty() or not data.get("ok",true) or not data.get("exists",true)
		modal_body.add_child(b)
	modal_body.add_child(_button("Create a new world",_show_new_world,42))

func _confirm_load(slot:int):
	if not game_started:
		_load_slot(slot)
		return
	_open_modal("Return to a saved history?",Vector2(650,410))
	modal_body.add_child(_paragraph("Your current unsaved changes will be replaced. An autosave of the current world can preserve them before loading.",17,LIGHT))
	modal_body.add_child(_button("Autosave current world, then load",func():
		# Preserve a requested autosave before overwriting its slot.
		var target=Saves.load_game(slot)
		if not target.get("ok",false):
			_toast(target.get("message","Could not load"),true)
			return
		var backup=Saves.save_game(sim.state,9)
		if backup.get("ok",false):
			_restore_world(target.state,slot)
			_toast(target.get("message","History restored."))
		else:
			_toast(backup.get("message","Could not save"),true)
	,44))
	modal_body.add_child(_button("Load without saving",_load_slot.bind(slot),40))

func _load_slot(slot:int):
	var result=Saves.load_game(slot)
	if not result.get("ok",false):
		_toast(result.get("message","Could not load world."),true)
		return
	_restore_world(result.state,slot)
	_toast(result.get("message","History restored."))

func _restore_world(data:Dictionary,slot:int):
	selected_person_key=""
	world.selected_person_key=""
	sim.restore(data)
	game_started=true
	current_slot=slot if slot!=9 else -1
	selected_id=-1
	world.selected_id=-1
	world.sim=sim
	world.invalidate_terrain()
	world.frame_world()
	accumulator=0
	_close_modal()
	paused=true
	_select_power("inspect")
	_set_category("world" if sim.state.mode=="sandbox" else ("divine" if _current_side()=="god" else "infernal"))
	_refresh_ui(true)
	_toast("History restored. Time is paused.")

func _show_event(event:Dictionary):
	_open_modal("An echo through history",Vector2(750,580))
	modal_body.add_child(_label("YEAR %d  /  %s"%[event.get("year",0),str(event.get("kind","world")).to_upper()],12,GOLD))
	modal_body.add_child(_title(event.get("title","An event"),26))
	modal_body.add_child(_paragraph(event.get("detail",""),17,LIGHT))
	var causes=event.get("causes",[])
	modal_body.add_child(_line())
	modal_body.add_child(_label("WHY DID THIS HAPPEN?",12,GOLD))
	if causes.is_empty():
		modal_body.add_child(_paragraph("This event has no additional recorded causes. Direct interventions are recorded at the moment they occur.",15))
	else:
		for cause in causes:
			modal_body.add_child(_paragraph("• "+str(cause),15))
	if event.get("x",-1)>=0:
		modal_body.add_child(_button("Visit this place",func():_close_modal();world.center_on_tile(event.x,event.y),44))
	var linked={}
	for cause in causes:
		for token in str(cause).split(" "):
			if token.begins_with("c:") and not linked.has(token):
				var person=sim.get_individual(token)
				if not person.is_empty():
					linked[token]=true
					modal_body.add_child(_button("Meet "+person.name,community.show_person.bind(token),48))

func _show_history():
	_open_history(-1)

func _city_history(id:int):
	_open_history(id)

func _open_history(city_id:int):
	var city=sim.get_settlement(city_id) if city_id>=0 else {}
	_open_modal("The Chronicle" if city.is_empty() else "The story of "+city.name,Vector2(950,760))
	var search=LineEdit.new()
	search.placeholder_text="Search events, people, and causes…"
	search.custom_minimum_size.y=42
	modal_body.add_child(search)
	var results=VBoxContainer.new()
	modal_body.add_child(results)
	var render=func(query:String):
		_clear(results)
		var events=sim.state.events
		var count=0
		for i in range(events.size()-1,-1,-1):
			var e=events[i]
			if not city.is_empty() and (e.get("x",-100)!=city.x or e.get("y",-100)!=city.y) and not city.name.to_lower() in (e.get("title","")+e.get("detail","")).to_lower():
				continue
			var text=e.get("title","")+" "+e.get("detail","")+" "+str(e.get("causes",[]))
			if query!="" and not query.to_lower() in text.to_lower():
				continue
			var b=_button("YEAR %04d   /   %s"%[e.get("year",0),e.get("title","")],_show_event.bind(e),42)
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT
			b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			b.tooltip_text=e.get("detail","")
			results.add_child(b)
			count+=1
			if count>=150:
				break
		if count==0:
			results.add_child(_paragraph("No recorded events match this search."))
	search.text_changed.connect(render)
	render.call("")

func _show_atlas():
	_open_modal("Atlas of the living world",Vector2(1000,760))
	modal_body.add_child(_paragraph("Independent discoveries, inherited beliefs, and ambitions turn settlements into civilizations. Select one to visit it.",15,LIGHT))
	modal_body.add_child(_button("Explore the ages of humanity",_show_technology,40))
	var sorted=sim.state.settlements.duplicate()
	sorted.sort_custom(func(a,b):return a.get("population",0)+a.get("orbital_population",0)>b.get("population",0)+b.get("orbital_population",0))
	for c in sorted:
		if c.get("population",0)+c.get("orbital_population",0)<=0:
			continue
		var row=VBoxContainer.new()
		modal_body.add_child(row)
		var b=_button(c.name+"  /  "+_nation_name(c.nation),func():_close_modal();_inspect_city(c.id),40)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(b)
		var l=_label("%s souls   ·   %s   ·   %d%% / %d%%"%[_number(c.population+c.get("orbital_population",0)),_era_name(c.get("era",0)),c.get("faith",0)*100,c.get("corruption",0)*100],13,MUTED)
		l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
	modal_body.add_child(_line())
	modal_body.add_child(_title("Relics & emissaries",23))
	for artifact in sim.state.get("artifacts",[]):
		modal_body.add_child(_paragraph("%s · %s"%[artifact.get("name","Relic"),artifact.get("description",artifact.get("side","god"))],14))
	for agent in sim.state.get("agents",[]):
		modal_body.add_child(_paragraph("%s · %s"%[agent.get("name","Emissary"),agent.get("role",agent.get("type","guardian"))],14))
	if sim.state.get("artifacts",[]).is_empty() and sim.state.get("agents",[]).is_empty():
		modal_body.add_child(_paragraph("No supernatural relics or emissaries have appeared yet. Your interventions can change that."))
	modal_body.add_child(_title("Legacies",23))
	var achievements=sim.state.get("achievements",[])
	if achievements.is_empty():
		modal_body.add_child(_paragraph("Your world's great achievements have yet to be written."))
	for achievement in achievements:
		modal_body.add_child(_paragraph(str(achievement).replace("_"," ").capitalize()+" — "+Content.ACHIEVEMENTS.get(achievement,"A mark upon history."),14,GOLD))

func _show_technology():
	_open_modal("The ages of humanity",Vector2(880,750))
	modal_body.add_child(_paragraph("Research belongs to individual civilizations. Trade and neighbors spread discoveries; hunger, disease, war, and isolation can delay them. Inspiration and forbidden knowledge can accelerate progress.",16,LIGHT))
	for i in range(Content.ERAS.size()):
		var era=Content.ERAS[i]
		var population=0
		for city in sim.state.settlements:
			if city.get("era",0)==i:
				population+=int(city.get("population",0)+city.get("orbital_population",0))
		var heading=_title("%02d  /  %s Age"%[i+1,era.name],23)
		heading.add_theme_color_override("font_color",Color(era.color))
		modal_body.add_child(heading)
		modal_body.add_child(_paragraph(era.description,15,LIGHT))
		modal_body.add_child(_paragraph("%s people live in this age  ·  Landmark: %s"%[_number(population),Content.ERA_BUILDINGS[i].capitalize()],12,GOLD))
		modal_body.add_child(_line())

func _show_doctrines():
	_open_modal("Divine teachings",Vector2(780,690))
	modal_body.add_child(_paragraph("A doctrine influences how your followers live. People can reinterpret your intentions, and prosperity alone does not guarantee devotion.",16,LIGHT))
	var sides=["god","devil"]
	for side in sides:
		modal_body.add_child(_title("The way of "+str(side).capitalize(),24))
		modal_body.add_child(_paragraph("Current doctrine: "+sim.state.get("doctrine",{}).get(side,"None"),14,GOLD))
		var doctrines=Content.DOCTRINES.get(side,[])
		var descriptions={"Compassion":"Faith strengthens food production, helping your followers sustain their communities.","Stewardship":"Faith provides a larger farming bonus and encourages cleaner, less polluted land.","Order":"Faith improves the happiness that a community works toward each year.","Knowledge":"Faith boosts research, helping settlements discover new technologies.","Free Will":"Reduces fear each year; happy communities gain faith.","Ambition":"Devil allegiance generates additional wealth each year.","Forbidden Knowledge":"Devil allegiance accelerates technological research.","Temptation":"Unhappy communities become more receptive to the Devil.","Chaos":"Devil allegiance erodes happiness and makes wars more likely.","Dominion":"Devil allegiance spreads fear, and fear strengthens allegiance."}
		for doctrine in doctrines:
			community.card(modal_body,str(doctrine),descriptions.get(str(doctrine),"Shape the way your followers live.")+" Select to adopt this doctrine.",_change_doctrine.bind(side,str(doctrine)),GOLD)
	modal_body.add_child(_line())
	modal_body.add_child(_paragraph("Both divine traditions are yours to shape. All powers are free; your choices change the lives and beliefs of this world.",14))

func _change_doctrine(side:String,doctrine:String):
	if sim.state.get("doctrine",{}).get(side,"")==doctrine:
		return
	var result={"ok":false,"message":"Doctrine unavailable"}
	if powers.has_method("set_doctrine"):
		result=powers.set_doctrine(sim,side,doctrine)
	else:
		sim.state.doctrine[side]=doctrine
		sim.add_event("A new commandment",side.capitalize()+" calls on humanity to follow "+doctrine+".","faith",-1,-1,["A divine doctrine was established."])
		result={"ok":true,"message":"Doctrine established."}
	_toast(result.message,not result.ok)
	_show_doctrines()

func _show_guide():
	_open_modal("The book of creation",Vector2(930,790))
	var sections=[
		["A world with free will","You influence humanity through its environment, beliefs, and opportunities. Settlements gather food, research, trade, migrate, fight, and found new communities. Rulers and prophets have lives of their own. Read their conditions and the Chronicle to understand consequences."],
		["The hands of a deity","Choose a category from the desktop left rail or the phone bottom tray, then select an ability. The targeting strip shows its effect and actual radius. Use its information button for details; cancel returns to Observe. Tap once to act; drag with one finger to pan and pinch with two fingers to zoom. On desktop, right or middle drag pans, scroll and +/- zoom, and sandbox terrain can be painted with left drag. Streets reveals residents and buildings; World returns to observing. Map controls explain overlays and let you fit the whole world."],
		["Every life has a story","Tap a person to open Overview, Family, Influence and History. Inspect their stat chart, gender, adult orientation, age, job, wealth, character and health conditions. Follow spouses, parents and children through their profiles. Adults form households, children grow into work, and elders die. Families share grief, gratitude and inheritance. Later eras bring smaller families; orbital habitats also have limited living space."],
		["Changing a civilization through one person","Influence offers Care, Character and Politics. Healing, curses and possession affect the selected person. Farmers, healers, scholars, guards and officials contribute through their work. Bribe an official to favor merchants; an honorable official may refuse. Accept an adult's promise over a sick relative, then select and heal the relative before the deadline. A kept promise can produce relief or repression; a dishonest adult can break their word. Every preview explains the conditions and price."],
		["Laws, justice and rebellion","Open a realm's Society tab or the Laws & justice button on a profile. Officials can enact relief, schools, fair trials, merchant privileges or repression. Crimes have actual culprits and victims; investigations can lead to prison. Revelation exposes hidden deeds, while pardons affect the victim's trust. Tyranny and resentment build support for a named opposition organizer. A successful uprising deposes the ruler and can split a realm into civil war."],
		["Faith, corruption, and skepticism","Faith in God, Devil allegiance, and unaffiliated belief divide the living population. Miracles and bargains can change allegiance, but health, hunger, fear, rulers, neighbors, and technological skepticism also affect it. Use the belief overlay to see local divisions."],
		["Time and technology","Space pauses or resumes. Keys 1–4 select 1x, 5x, 20x, or 100x time. Each simulation step is one year. Civilizations research independently and learn from neighbors. Eras change farming, medicine, warfare, prosperity, and the relationship between knowledge and belief. Isolation and disaster can delay progress."],
		["God's counterplay","Sanctuary protects communities against hostile powers. Heal important residents, free possessed people, comfort bereaved families, and expose corruption. Bless influential people and spread faith through prophets and relics. The Devil can use personal bargains, bribery, possession, cults and idols. Both sides benefit from keeping their followers alive."],
		["Prosperity and peril","Fertile land and moisture sustain food. Forests, mountains, and resources shape settlement sites. Plague, drought, fire, war, and pollution harm survival. Protection and healing soften the damage. Migration can rescue displaced people. Watch reserves and health when growth accelerates."],
		["Memory, souls, and legacy","Events preserve actual causes. Open the Chronicle, search its history, or follow a specific city. Named figures, religions, artifacts, and emissaries leave continuing effects. Death sends souls to Heaven, Hell, or the wandering realm according to the beliefs of the population."],
		["Saving and comfort","Ctrl+S saves to the current manual slot. Ctrl+O opens load. Three manual slots and a separate autosave preserve worlds. Settings control ambient sound, volume, fullscreen (F11), autosave, and the introduction. Save before creating a different world."]
	]
	for section in sections:
		var section_heading=_title(section[0],23)
		section_heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		modal_body.add_child(section_heading)
		modal_body.add_child(_paragraph(section[1],15,LIGHT))
		modal_body.add_child(_line())
	modal_body.add_child(_button("Show the introduction in my world",func():_close_modal();_start_tutorial(),46))

func _show_settings():
	_open_modal("Shape your experience",Vector2(710,660))
	for item in [["fullscreen","Fullscreen display (F11)",false],["ambient","Ambient music",true],["effects","Battle and world sounds",true],["voices","Spoken character introductions",true],["event_notices","Major world news",true],["autosave","Autosave every 90 seconds",true],["show_tutorial","Show introduction in new sandbox worlds",true]]:
		if item[0]=="fullscreen" and OS.has_feature("android"): continue
		var check=CheckButton.new()
		check.text=item[1]
		check.clip_text=true
		check.custom_minimum_size.y=48
		check.tooltip_text=item[1]
		check.button_pressed=settings.get(item[0],item[2])
		check.toggled.connect(func(value):settings[item[0]]=value;_apply_settings();Saves.save_settings(settings))
		modal_body.add_child(check)
		modal_body.add_child(_paragraph(item[1]+". "+{"fullscreen":"Fill the display; turn off to return to a window.","ambient":"Play the world's quiet background music.","effects":"Hear era-specific battles and vehicles as you zoom nearby, plus interface and power feedback.","voices":"Hear selected residents introduce themselves using an installed English device voice. Their words also appear in the profile. Voice quality and availability depend on the device.","event_notices":"Silent notices for royal weddings, wars, peace, alliances and revolutions. Everyday lives stay in personal histories; the Chronicle keeps the wider history.","autosave":"Keep a separate recovery copy while you play.","show_tutorial":"Teach the main controls when starting a new sandbox."}.get(item[0],""),13))
	modal_body.add_child(_label("MASTER VOLUME",12,GOLD))
	var slider=TouchSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=0.05
	slider.value=settings.get("volume",0.45)
	slider.value_changed.connect(func(value):settings.volume=value;_apply_settings();Saves.save_settings(settings))
	modal_body.add_child(slider)
	modal_body.add_child(_line())
	modal_body.add_child(_paragraph("Android worlds are saved on this phone and kept when you install updates. Uninstalling the app clears its local worlds. Updates are checked each time the app starts." if OS.has_feature("android") else "Desktop worlds are stored on this device. Browser worlds are stored in this browser's local data; use a regular browser window and keep its site data to retain saves. Desktop and browser saves are separate.",15))
	if OS.has_feature("android"):
		modal_body.add_child(_label("The Gods · v"+str(ProjectSettings.get_setting("application/config/version","1.4.0")),13,GOLD))
		modal_body.add_child(_button("Android downloads",func():OS.shell_open("https://github.com/malov-dot/the-gods-android/releases/latest"),48))
	modal_body.add_child(_button("Save world and quit",_save_and_quit,46))
	modal_body.add_child(_button("Return to the world",_close_modal,40))

func _save_and_quit():
	var result=Saves.save_game(sim.state,current_slot if current_slot>=0 else 9)
	if result.ok:
		_quit_game()
	else:
		_toast(result.get("message","Could not save"),true)

func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and ChoiceButton.close_open_choices(get_tree()): return
	if what==NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(world): _responsive_layout.call_deferred()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(modal):
		_close_modal()
		return
	if simulation_busy and what==NOTIFICATION_WM_GO_BACK_REQUEST and (deferred_world_action.is_valid() or not pending_casts.is_empty() or selected_power!="inspect"):
		deferred_world_action=Callable()
		shell.power_ui.cancel()
		return
	if simulation_busy and what in [NOTIFICATION_WM_GO_BACK_REQUEST,NOTIFICATION_WM_CLOSE_REQUEST]:
		_dispatch_world_action(_notification.bind(what))
		return
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(world):
		if is_instance_valid(modal): _close_modal()
		elif selected_power!="inspect" or shell.power_ui.palette.visible: shell.power_ui.cancel()
		else: _show_menu()
	if what==NOTIFICATION_APPLICATION_PAUSED and OS.has_feature("android") and game_started and not sim.state.is_empty():
		if world_audio!=null: world_audio.stop()
		paused=true
		if simulation_busy: lifecycle_save_pending=true
		elif settings.get("autosave",true): Saves.save_game(sim.state,9)
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if game_started and not sim.state.is_empty():
			var result=Saves.save_game(sim.state,9)
			if not result.ok:
				_open_modal("Your world could not be saved",Vector2(640,380))
				modal_body.add_child(_paragraph(result.get("message","Autosave failed."),16,LIGHT))
				modal_body.add_child(_button("Quit without saving",_quit_game,44))
				return
		_quit_game()

func _stop_audio():
	if world_audio!=null: world_audio.stop()
	for player in [ambience,sounds]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null

func _quit_game():
	_stop_audio()
	await get_tree().process_frame
	get_tree().quit()

func _exit_tree():
	if shell!=null: shell.dispose()
	if community!=null: community.app=null

func _build_audio():
	get_tree().auto_accept_quit=false
	ambience=AudioStreamPlayer.new()
	add_child(ambience)
	sounds=AudioStreamPlayer.new()
	add_child(sounds)
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.stereo=false
	var frames=22050*8
	var bytes=PackedByteArray()
	bytes.resize(frames*2)
	for i in range(frames):
		var t=float(i)/22050.0
		# Integer-period harmonics create a seamless, quiet suspended chord.
		var wave=(sin(TAU*110*t)*0.38+sin(TAU*165*t)*0.19+sin(TAU*220*t)*0.12+sin(TAU*261.625*t)*sin(PI*t/8.0)*0.035)
		wave*=0.18*(0.85+0.15*cos(TAU*t/8.0))
		bytes.encode_s16(i*2,int(clampf(wave,-1,1)*32767))
	stream.data=bytes
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	# Godot's WAV mixer includes the end sample; keep it inside the PCM buffer.
	stream.loop_end=frames-1
	ambience.stream=stream
	ambience.volume_db=-15
	ambience.play()

func _apply_settings():
	if not OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen",false) else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,settings.get("volume",0.45))))
	if is_instance_valid(ambience):
		ambience.stream_paused=not settings.get("ambient",true)

func _click_sound():
	_play_tone(440)

func _play_tone(frequency:float):
	if not is_instance_valid(sounds) or not settings.get("effects",true):
		return
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	var bytes=PackedByteArray()
	bytes.resize(4410*2)
	for i in range(4410):
		var t=float(i)/22050.0
		var fade=pow(1.0-float(i)/4410.0,3)
		bytes.encode_s16(i*2,int(sin(t*frequency*TAU)*fade*1800))
	stream.data=bytes
	sounds.stream=stream
	sounds.play()
