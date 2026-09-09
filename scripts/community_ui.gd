extends RefCounted

const Feedback=preload("res://scripts/person_interventions.gd")
const Art = preload("res://scripts/interface_art.gd")
const PERSON_TABS = ["Overview", "Family", "Influence", "History"]
const FACTION_TABS = ["Overview", "Leaders", "Towns", "Society"]
const ACTION_GROUPS={"Care":["heal_person","infernal_cure","purify_person","comfort_person","teach_person","curse_person"],"Character":["bless_person","inspire_person","tempt_person","corrupt_person","incite_person","possess_person"],"Politics":["bribe_person","reveal_person","pardon_person","promise_mercy","promise_cruelty"]}
var action_group="Care"
var pending_action=""
const STAT_NAMES = {"health":"Health", "happiness":"Happiness", "faith":"God", "corruption":"Devil", "loyalty":"Loyalty", "ambition":"Ambition", "standing":"Standing", "influence":"Influence", "wisdom":"Wisdom", "leadership":"Leadership", "strength":"Strength", "research":"Research", "food":"Food", "knowledge":"Knowledge", "wealth":"Wealth", "fear":"Fear", "aggression":"Aggression"}
var app
var town_id = -1
var offset = 0
var query = ""
var resident_view="Community"
var results
var search_input
var selected_action = ""
var last_person = ""
var last_result = ""
var person_tab = "Overview"
var faction_tab = "Overview"
var last_faction = -1

func _init(host): app = host

func portrait(person, dimension = 44):
	var art = Art.new()
	art.kind = "portrait"
	art.person = person.duplicate()
	var town = app.sim.get_settlement(int(person.get("settlement", -1)))
	art.person.era = town.get("era", 0)
	art.custom_minimum_size = Vector2(dimension, dimension)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.accent = app.TEAL if person.get("faith", 0) >= person.get("corruption", 0) else app.RED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

# Kept as the public row helper used by main's menus and references.
func card(parent, title_, description, callback, accent = Color("b9aa79"), person = {}):
	var button = app._button("", callback, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = title_ + ("\n" + description if not description.is_empty() else "")
	var normal = app._style(Color(0.07, 0.10, 0.09, 0.12), Color("334039"), 3, 0)
	normal.set_border_width_all(0)
	normal.border_width_bottom = 1
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", app._style(Color("263129"), Color(accent, 0.55), 3, 0))
	button.add_theme_stylebox_override("pressed", app._style(Color("303b2e"), accent, 3, 0))
	parent.add_child(button)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 8)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	if not person.is_empty(): row.add_child(portrait(person, 32))
	var lines = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	var heading = app._label(title_, 14, accent)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(heading)
	if not description.is_empty():
		var detail = app._paragraph(description, 11, app.MUTED)
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(detail)
	var remeasure = func():
		if is_instance_valid(button) and is_instance_valid(row):
			button.custom_minimum_size.y = maxf(48, row.get_combined_minimum_size().y + 12)
	lines.minimum_size_changed.connect(func(): remeasure.call_deferred())
	remeasure.call_deferred()
	button.set_meta("content_row", row)
	return button

func _section(parent, title_):
	var label = app._label(title_.to_upper(), 11, app.GOLD)
	label.custom_minimum_size.y = 24
	parent.add_child(label)

func _stat(parent, title_, value, accent = Color("dce3d9")):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 24
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label = app._label(title_, 12, app.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var number = app._label(str(value), 13, accent)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	return row

func _grid(parent):
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 0)
	parent.add_child(grid)
	return grid

func _disclosure(parent, title_, description):
	var body = app._paragraph(description, 12, app.MUTED)
	body.visible = false
	var toggle = app._button(title_, func(): body.visible = not body.visible, 48)
	toggle.custom_minimum_size.x = 48
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode = true
	parent.add_child(toggle)
	parent.add_child(body)
	return toggle

func _tabs(parent, labels, current, callback):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	for title_ in labels:
		var button = app._button(title_, callback.bind(title_), 48)
		button.custom_minimum_size.x = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = title_ == current
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("pressed", app._style(Color("30392b"), app.GOLD, 3, 4))
		row.add_child(button)

func show_people(id = -1):
	var previous_town = town_id
	if id >= 0: town_id = id
	elif app.selected_id >= 0: town_id = app.selected_id
	var towns = []
	var found = false
	for town in app.sim.state.settlements:
		if town.population + town.get("orbital_population", 0) > 0:
			towns.append(town)
			if int(town.id) == town_id: found = true
	if not found and not towns.is_empty(): town_id = int(towns[0].id)
	if previous_town != town_id: offset = 0
	app._open_modal("Residents", Vector2(380, 620))
	app.modal_body.add_theme_constant_override("separation", 4)
	if towns.is_empty():
		_tabs(app.modal_body,["Community","Leaders","Favorites"],resident_view,_select_resident_view)
		results=VBoxContainer.new(); app.modal_body.add_child(results)
		if resident_view=="Community": results.add_child(app._paragraph("No living communities. Favorites still contain the people you followed.",13))
		else: _render_residents()
		return
	var chooser = app.ChoiceButton.new(app,"Choose a community")
	chooser.custom_minimum_size.y = 48
	chooser.add_theme_font_size_override("font_size", 14)
	for town in towns:
		chooser.add_item(town.name + " · " + app._number(town.population + town.get("orbital_population", 0)), int(town.id))
		if int(town.id) == town_id: chooser.select(chooser.item_count - 1)
	chooser.item_selected.connect(func(index): town_id = chooser.get_item_id(index); offset = 0; _render_residents())
	app.modal_body.add_child(chooser)
	_tabs(app.modal_body,["Community","Leaders","Favorites"],resident_view,_select_resident_view)
	var search_row = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 4)
	app.modal_body.add_child(search_row)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Name, role or identity"
	search_input.custom_minimum_size = Vector2(0, 48)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.add_theme_font_size_override("font_size", 13)
	search_input.text = query
	search_input.clear_button_enabled = true
	search_input.text_submitted.connect(func(text_): query = text_.strip_edges(); offset = 0; _render_residents())
	search_row.add_child(search_input)
	var search = app._button("Search", func(): query = search_input.text.strip_edges(); offset = 0; _render_residents(), 48)
	search.custom_minimum_size.x = 64
	search.add_theme_font_size_override("font_size", 13)
	search_row.add_child(search)
	results = VBoxContainer.new()
	results.add_theme_constant_override("separation", 0)
	app.modal_body.add_child(results)
	_render_residents()

func _render_residents():
	if not is_instance_valid(results): return
	app._clear(results)
	if not app.sim.has_method("resident_page"):
		results.add_child(app._paragraph("The resident registry is unavailable.", 13))
		return
	var town=app.sim.get_settlement(town_id)
	if resident_view=="Community" and not town.is_empty():
		var leader=app.sim.get_individual("p:%d"%int(town.leader))
		if not leader.is_empty() and leader.alive:
			_section(results,"Leading this community")
			_resident_card(results,leader)
	if resident_view!="Community":
		results.add_child(app._paragraph("Leaders across all communities." if resident_view=="Leaders" else "People you follow across the whole world, including their history after death. Favorites are saved with this world.",12,app.MUTED))
	var page = _resident_page()
	var total = int(page.get("total", 0))
	if offset >= total and offset > 0:
		offset = maxi(0, int((total - 1) / 12) * 12)
		page = _resident_page()
	_section(results, "%d–%d / %s residents" % [mini(offset + 1, total), mini(offset + 12, total), app._number(total)])
	for person in page.get("people", []):
		_resident_card(results,person)
	if total == 0: results.add_child(app._paragraph("No favorites yet. Tap the star beside a person or Favorite in their profile." if resident_view=="Favorites" and query.is_empty() else "No matches. Try a name, role or identity.", 13))
	var navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 4)
	results.add_child(navigation)
	var previous = app._button("Previous", func(): offset = maxi(0, offset - 12); _render_residents(), 48)
	previous.custom_minimum_size.x = 80
	previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous.disabled = offset <= 0
	navigation.add_child(previous)
	var next = app._button("Next", func(): offset += 12; _render_residents(), 48)
	next.custom_minimum_size.x = 80
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.disabled = offset + 12 >= total
	navigation.add_child(next)
	app.modal_scroll.reset_scroll()

func _select_resident_view(view:String):
	resident_view=view; offset=0
	show_people(town_id)

func _resident_page()->Dictionary:
	if resident_view=="Community": return app.sim.resident_page(town_id,offset,12,query)
	var keys=[]
	if resident_view=="Favorites": keys=app.sim.state.get("favorite_people",[])
	else:
		for town in app.sim.state.settlements:
			var leader=app.sim.get_individual("p:%d"%int(town.leader))
			if not leader.is_empty() and leader.alive and not leader.key in keys: keys.append(leader.key)
	var people=[]
	for key in keys:
		var person=app.sim.get_individual(key)
		if person.is_empty(): continue
		var town=app.sim.get_settlement(int(person.settlement))
		var searchable="%s %s %s %s %s"%[person.name,person.role,person.key,town.get("name",""),app._nation_name(int(person.nation))]
		if not query.is_empty() and not query.to_lower() in searchable.to_lower(): continue
		people.append(person)
	return {"total":people.size(),"people":people.slice(offset,offset+12)}

func _is_leader(person)->bool:
	if not person.get("alive",false): return false
	var town=app.sim.get_settlement(int(person.settlement))
	return not town.is_empty() and str(app.sim.state.citizens.named.get("p:%d"%int(town.leader),""))==str(person.key)

func _resident_card(parent,person):
	var key=str(person.key)
	var row=HBoxContainer.new(); row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	var leader=_is_leader(person)
	var title_=("LEADER · " if leader else "")+person.name
	var town=app.sim.get_settlement(int(person.settlement))
	var detail="%s · %d yrs · %d%% influence"%["Community leader" if leader else str(person.role).capitalize(),int(person.age),float(person.influence)*100]
	if resident_view!="Community": detail+="\n%s · %s"%[town.get("name","Unknown home"),app._nation_name(int(person.nation))]
	if not person.alive: detail+=" · Deceased"
	elif person.get("location","")=="orbit": detail+=" · Orbit"
	var button=card(row,title_,detail,show_person.bind(key),app.GOLD if leader else app.LIGHT,person)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.set_meta("resident_key",key); button.set_meta("leader",leader)
	button.toggle_mode=true; button.button_pressed=key==app.selected_person_key
	var star=app.shell.icon_button("favorite_empty","",_toggle_favorite.bind(key),"Favorite this person. Find them again in Favorites.",48)
	star.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	star.set_meta("favorite_key",key); star.add_to_group("favorite_people_buttons")
	_update_favorite_button(star)
	return button

func _update_favorite_button(button):
	var favorite=button.get_meta("favorite_key","") in app.sim.state.get("favorite_people",[])
	button.toggle_mode=true; button.button_pressed=favorite
	if button.has_meta("art"): button.get_meta("art").kind="favorite" if favorite else "favorite_empty"
	elif button.has_meta("compact_favorite"): button.text="★" if favorite else "☆"
	else: button.text="Favorited · remove" if favorite else "Favorite this person"
	button.tooltip_text="Remove from Favorites" if favorite else "Follow this person in Favorites. Saved with this world."

func _toggle_favorite(key:String):
	var person=app.sim.get_individual(key)
	if person.is_empty(): return
	key=str(person.key)
	var favorites=app.sim.state.get("favorite_people",[]).duplicate()
	if key in favorites: favorites.erase(key)
	else:
		if favorites.size()>=4096: app._toast("Your favorites list is full. Remove a favorite first."); return
		favorites.append(key)
	app.sim.state["favorite_people"]=favorites
	for button in app.get_tree().get_nodes_in_group("favorite_people_buttons"): _update_favorite_button(button)
	if resident_view=="Favorites" and is_instance_valid(results) and results.is_inside_tree(): _render_residents()

func show_person(key):
	var person = app.sim.get_individual(key)
	if person.is_empty():
		app._toast("This resident could not be found.", true)
		return
	key = str(person.key)
	if last_person != key:
		person_tab = "Overview"
		selected_action = ""
	last_person = key
	app.selected_person_key = key
	app.selected_id = int(person.settlement)
	app.world.selected_id = app.selected_id
	app.world.selected_person_key = key
	if not pending_action.is_empty():
		var action=pending_action
		pending_action=""
		preview_action(action,key)
		return
	app._open_modal("Resident", Vector2(380, 620))
	app.modal_body.add_theme_constant_override("separation", 4)
	fill_person(app.modal_body, person, true)
	if app.world_audio!=null: app.world_audio.speak(person)

func _person_header(parent, person, map_action = true):
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	parent.add_child(heading)
	heading.add_child(portrait(person, 44))
	var identity = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	heading.add_child(identity)
	var name_ = app._paragraph(str(person.name), 18, app.GOLD)
	name_.add_theme_font_override("font", app.heading_font)
	identity.add_child(name_)
	identity.add_child(app._paragraph("%s · age %d%s" % [str(person.role).capitalize(), int(person.age), " · Orbit" if person.get("location", "") == "orbit" else ""], 12, app.LIGHT))
	if map_action and person.get("alive", false):
		var map_button = app._button("Map", func(): app._close_modal(); app.world.focus_person(str(person.key)); app._refresh_inspector(), 48)
		map_button.custom_minimum_size.x = 48
		map_button.add_theme_font_size_override("font_size", 12)
		map_button.tooltip_text = "Find this resident's community on the map"
		heading.add_child(map_button)
	if not person.get("alive", true):
		parent.add_child(app._label("Deceased · history preserved", 12, app.RED))
	elif _is_leader(person):
		parent.add_child(app._label("LEADER · "+app.sim.get_settlement(int(person.settlement)).get("name","Community"),12,app.GOLD))
	for mark in Feedback.markers(app.sim,person):
		parent.add_child(app._paragraph(mark.symbol+"  "+mark.label+(" · %d years left"%mark.remaining if mark.remaining>0 else ""),13,mark.color))
	var favorite=app._button("☆",_toggle_favorite.bind(str(person.key)),48)
	favorite.set_meta("favorite_key",str(person.key))
	favorite.set_meta("compact_favorite",true); favorite.custom_minimum_size.x=48
	heading.add_child(favorite); favorite.add_to_group("favorite_people_buttons")
	_update_favorite_button(favorite)

func fill_person(parent, person, full = true):
	_person_header(parent, person)
	if not full:
		_stat(parent, "Health / influence", "%d / %d%%" % [float(person.get("health", 0)) * 100, float(person.get("influence", 0)) * 100])
		parent.add_child(app._button("Open profile", show_person.bind(str(person.key)), 48))
		return
	_tabs(parent, PERSON_TABS, person_tab, _select_person_tab.bind(str(person.key)))
	match person_tab:
		"Stats": _fill_stats(parent,person)
		"Family": _fill_family(parent,person)
		"Influence": _fill_influence(parent, person)
		"History": _fill_history(parent, person)
		_: _fill_overview(parent, person)
	parent.add_child(app._button("Back to residents", show_people.bind(int(person.settlement)), 48))

func _select_person_tab(tab, key):
	person_tab = tab
	show_person(key)

func _fill_overview(parent, person):
	_fill_current_story(parent,person)
	parent.add_child(app._button("Show full stats & biography",func(): person_tab="Stats";show_person(str(person.key)),48))
	parent.add_child(app._button("Open Lives & stories",app._show_stories,48))
	if app.world_audio!=null:
		_disclosure(parent,"In their own words",app.world_audio.introduction(person,app.sim.get_settlement(int(person.settlement))))
		if person.get("alive",false): parent.add_child(app._button("Hear their introduction",func():app.world_audio.speak(person,true),48))

func _fill_current_story(parent,person):
	var need="Building a future in the community."
	var action="inspire_person";var verb="Help with their work"
	if not person.alive: need="This life has ended. Their family and memories remain.";action="resurrect_person";verb="Bring this person back"
	elif not person.illness.is_empty(): need="Sick with "+person.illness+". Healing can restore their work and fulfill a family promise.";action="heal_person";verb="Heal "+person.name
	elif person.cursed or person.possessed: need="A supernatural affliction is disrupting this life and household.";action="purify_person";verb="Release their soul"
	elif person.grieving: need="Grieving a loved one. Comfort can ease resentment and help the household recover.";action="comfort_person";verb="Comfort "+person.name
	elif person.imprisoned: need="Serving a prison sentence. Read their history before choosing mercy.";action="pardon_person";verb="Consider a pardon"
	elif person.age<18: need="Growing up and learning, with a household and a future to protect.";action="teach_person";verb="Support their learning"
	parent.add_child(app._paragraph(need,15,app.LIGHT))
	var glance=_grid(parent)
	_stat(glance,"Health","%d / 100"%int(person.health*100))
	_stat(glance,"Influence","%d / 100"%int(person.influence*100))
	parent.add_child(app._button(verb,preview_action.bind(action,str(person.key)),48))
	var project=person.get("project",{})
	if not project.is_empty():
		_section(parent,"Their current project")
		parent.add_child(app._paragraph(str(project.title),15,app.GOLD))
		var bar=ProgressBar.new();bar.max_value=project.target;bar.value=project.progress;bar.custom_minimum_size.y=18;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(bar)
		parent.add_child(app._paragraph(str(project.status).capitalize()+" · "+("by year %d"%int(project.deadline) if project.status=="active" else str(project.outcome)),12,app.MUTED))
		if not str(project.obstacle).is_empty() and project.status=="active": parent.add_child(app._paragraph(project.obstacle,13,app.RED))
	for vow in person.get("promises",[]):
		if vow.status not in ["offered","pending"]: continue
		var patient=app.sim.get_individual(vow.patient)
		card(parent,"Family appeal · "+str(vow.status),patient.name+" needs healing by year %d."%int(vow.deadline),show_person.bind(str(vow.patient)))
		if vow.status=="offered" and vow.actor==person.key: parent.add_child(app._button("Consider their promise",preview_action.bind("promise_mercy",str(person.key)),48))
	if not person.history.is_empty():
		var event=person.history[-1]
		_disclosure(parent,"Latest: "+str(event.title),"Year %d · "%int(event.year)+str(event.detail))

func _fill_stats(parent, person):
	if app.world_audio!=null:
		var introduction=app.world_audio.introduction(person,app.sim.get_settlement(int(person.settlement)))
		parent.add_child(app._paragraph("“"+introduction+"”",13,app.LIGHT))
		if person.get("alive",false): parent.add_child(app._button("Hear their introduction",func():app.world_audio.speak(person,true),48))
	var town = app.sim.get_settlement(int(person.settlement))
	parent.add_child(app._paragraph(town.get("name", "Unknown home") + " · " + app._nation_name(int(person.get("nation", town.get("nation", -1)))), 12, app.MUTED))
	var stats = _grid(parent)
	_stat(stats,"Gender",person.get("gender","Unrecorded"))
	_stat(stats,"Orientation",person.get("orientation","Undeclared"))
	_stat(stats,"Household",person.get("marital_status","Single"))
	_stat(stats,"Children",str(person.get("children",[]).size()))
	_stat(stats,"Character",person.get("character","Conflicted"),app.TEAL)
	_stat(stats,"Personal wealth",app._number(person.get("wealth",0)))
	var conditions=[]
	if not str(person.get("illness","")).is_empty(): conditions.append(person.illness)
	for flag in ["cursed","possessed","imprisoned","grieving","wanted"]:
		if person.get(flag,false): conditions.append(flag.capitalize())
	if not conditions.is_empty(): parent.add_child(app._paragraph(" · ".join(conditions),13,app.RED))
	if not person.alive: parent.add_child(app._paragraph(person.get("death_cause","Life has ended"),12,app.MUTED))
	_section(parent,"Abilities & character · 0–100")
	var chart=_grid(parent)
	for field in ["health","happiness","influence","standing","wisdom","leadership","strength","ambition","honor","empathy","courage","resentment","loyalty","faith","corruption"]:
		_chart_stat(chart,STAT_NAMES.get(field,str(field).capitalize()),float(person.get(field,0)),app.GOLD if field in ["influence","standing"] else (app.RED if field in ["corruption","resentment"] else app.TEAL))
	var traits = ", ".join(person.get("traits", []))
	if not traits.is_empty(): parent.add_child(app._paragraph(traits.capitalize(), 12, app.TEAL))
	parent.add_child(app._paragraph(str(person.get("goal", "A place in the community")).capitalize(), 12, app.MUTED))
	_section(parent,"This person's impact")
	var contribution=person.get("contribution",{})
	parent.add_child(app._paragraph(str(contribution.get("activity","Contributes to community life")),12,app.LIGHT))
	for field in ["food","wealth","research","care","security"]:
		if float(contribution.get(field,0))>0: _stat(parent,field.capitalize()+" / year","+%.2f"%float(contribution[field]),app.TEAL)
	_stat(parent,"Good deeds / crimes","%d / %d"%[int(person.get("good_deeds",0)),int(person.get("crimes",0))])
	if int(person.get("kills",0))>0: _stat(parent,"Murders committed",str(person.kills),app.RED)
	parent.add_child(app._button("Laws & justice in "+str(town.get("name","this town")),show_society.bind(int(person.settlement)),48))
	parent.add_child(app._label("Identity " + str(person.key), 11, app.MUTED))
	_disclosure(parent, "What do these stats mean?", "Health and happiness describe wellbeing. Wisdom supports learning; leadership, strength and ambition describe abilities. Loyalty is attachment to the community. God and Devil values show allegiance. Standing is reputation; influence combines standing and role to set an intervention's community reach.")

func _fill_influence(parent, person):
	_stat(parent, "Community reach", "%d%% · %s" % [float(person.get("influence", 0)) * 100, str(person.role).capitalize()], app.GOLD)
	if not person.get("alive", false):
		parent.add_child(app._paragraph("Restore this person's own life, memories and family ties.", 13, app.MUTED))
		parent.add_child(app._button("Return This Soul",preview_action.bind("resurrect_person",str(person.key)),48))
		return
	parent.add_child(app._paragraph("Every action targets "+person.name+". Preview the consequences before casting.", 12, app.MUTED))
	_tabs(parent,["Care","Character","Politics"],action_group,_select_action_group.bind(str(person.key)))
	for power in app.Powers.PERSON_CATALOG:
		if power.id not in ACTION_GROUPS[action_group]: continue
		var short_copy = Feedback.description(str(power.id))
		var row_button = card(parent, power.name, short_copy, preview_action.bind(power.id, str(person.key)), app.TEAL if power.side == "god" else app.RED)
		row_button.toggle_mode = true
		row_button.button_pressed = str(power.id) == selected_action
		var content_row = row_button.get_meta("content_row")
		var icon = Art.new()
		icon.kind = "power_" + str(power.id)
		icon.accent = app.TEAL if power.side == "god" else app.RED
		icon.custom_minimum_size = Vector2(28, 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content_row.add_child(icon)
		content_row.move_child(icon, 0)
		if app.sim.state.mode != "sandbox" and power.side != app._current_side():
			# The preview remains reachable and explains the restriction before casting.
			row_button.modulate = Color(0.66, 0.66, 0.66)
	var registry = app.sim.state.get("citizens", {})
	var canonical = str(registry.get("named", {}).get(str(person.key), str(person.key)))
	var active = []
	for effect in registry.get("overrides", {}).get(canonical, {}).get("effects", []):
		if int(effect.get("until", 0)) > int(app.sim.state.year): active.append(effect)
	if not active.is_empty():
		_section(parent, "Active influences")
		for effect in active:
			var power = app.powers.get_person_power(str(effect.get("action", "")))
			_stat(parent, power.get("name", "Influence"), "%d years" % [int(effect.until) - int(app.sim.state.year)], app.GOLD)

func _fill_history(parent, person):
	var history = person.get("history", [])
	if history.is_empty():
		parent.add_child(app._paragraph("No recorded events yet.", 13, app.MUTED))
		return
	for i in range(history.size() - 1, -1, -1):
		var event = history[i]
		if event is Dictionary:
			var title_ = "Year %d · %s" % [int(event.get("year", 0)), str(event.get("title", "A change of fortune"))]
			_disclosure(parent, title_, str(event.get("detail", event.get("message", ""))))
		else:
			parent.add_child(app._paragraph(str(event), 12, app.MUTED))

func show_stats_help():
	app._open_modal("Resident stats", Vector2(380, 520))
	for entry in [["Health & happiness", "Personal wellbeing and contentment. Healing directly restores health."], ["Wisdom & leadership", "Learning and the ability to guide others. Role and standing set community reach."], ["Strength & ambition", "Physical ability and desire to rise. Military and political roles can carry wider consequences."], ["Loyalty & beliefs", "Attachment to the community, God and Devil allegiance. Remaining belief is unaffiliated."], ["Standing & influence", "Reputation and the reach created by reputation and role. Preview an action for its actual community effect."]]:
		_section(app.modal_body, entry[0])
		app.modal_body.add_child(app._paragraph(entry[1], 12, app.MUTED))
	app.modal_body.add_child(app._button("Back to this person", show_person.bind(last_person), 48))

func preview_action(action, key):
	selected_action = action
	for group in ACTION_GROUPS:
		if action in ACTION_GROUPS[group]: action_group=group; break
	var power = app.powers.get_person_power(action)
	if power.is_empty():
		app._toast("Unknown personal intervention.", true)
		return
	var side = power.side if app.sim.state.mode == "sandbox" else app._current_side()
	var preview = app.powers.preview_person(app.sim, action, key, side)
	var person = app.sim.get_individual(key)
	app._open_modal(power.name, Vector2(380, 620))
	app.modal_body.add_theme_constant_override("separation", 4)
	if not person.is_empty(): _person_header(app.modal_body, person, false)
	_stat(app.modal_body, "Duration", str(preview.get("duration_label","%d years"%int(preview.get("duration",12)))), app.GOLD)
	var explanation=str(power.description)
	if action=="bribe_person" and preview.get("ok",false):
		explanation=person.name+(" will refuse. Their standing rises by up to 8 points, honor by 4, and town unrest falls by 3 points." if person.honor>=0.65 and not person.possessed else " will accept 40 private wealth and pass Guild Privileges for 16 years. Merchants benefit; workers lose wealth and grow resentful.")
	app.modal_body.add_child(app._paragraph(explanation, 12, app.LIGHT))
	if action in ["promise_mercy","promise_cruelty"]: app.modal_body.add_child(app._paragraph(str(preview.get("consequence",power.consequence)),13,app.LIGHT))
	var personal = preview.get("personal", {})
	if not personal.is_empty():
		_section(app.modal_body, "Personal · immediate")
		for field in personal:
			_stat(app.modal_body, STAT_NAMES.get(field, str(field).capitalize()), "up to %+.0f points" % [float(personal[field]) * 100])
	var community = preview.get("community", {})
	if not community.is_empty():
		_section(app.modal_body, "Community · each year")
		for field in community:
			var normalized = field in ["health", "happiness", "faith", "corruption", "fear", "aggression"]
			var value = float(community[field]) * (100.0 if normalized else 1.0)
			_stat(app.modal_body, STAT_NAMES.get(field, str(field).capitalize()), "%+.2f %s" % [value, "points" if normalized else "units"], app.TEAL if power.side == "god" else app.RED)
	if not preview.get("ok", false): app.modal_body.add_child(app._paragraph(preview.get("message", "Unavailable"), 12, app.RED))
	var verb="Accept promise" if action in ["promise_mercy","promise_cruelty"] else ("Offer bribe" if action=="bribe_person" else "Cast")
	var apply = app._button(verb+" on "+str(person.get("name","this person")), commit_action.bind(action, key, side), 48)
	apply.disabled = not preview.get("ok", false)
	app.modal_body.add_child(apply)
	_disclosure(app.modal_body, "How this effect is calculated", "Stat points use a 0–100 scale. " + str(preview.get("consequence", power.get("consequence", ""))))
	app.modal_body.add_child(app._button("Back to influence", _return_to_influence.bind(key), 48))

func _return_to_influence(key):
	person_tab = "Influence"
	show_person(key)

func commit_action(action, key, side):
	var before=app.sim.get_individual(key).duplicate(true)
	var result = app.powers.apply_to_person(app.sim, action, key, side)
	last_result = result.get("message", "Their course changes.")
	if result.get("ok", false):
		app.sim.refresh_totals()
		app.world.invalidate_terrain()
		app._refresh_ui(true)
		person_tab = "Influence"
		app._close_modal()
		app._select_power("inspect")
		app.world.focus_person(key)
		app.paused=true
		app.modal_was_paused=true
		app._open_modal("The consequence",Vector2(380,330))
		var power = app.powers.get_person_power(action)
		var after=app.sim.get_individual(key)
		var changes=[]
		for field in ["health","happiness","wisdom","leadership","strength","ambition","honor","empathy","courage","resentment","loyalty","standing","faith","corruption"]:
			var old=roundi(float(before.get(field,0))*100); var now=roundi(float(after.get(field,0))*100)
			if old!=now: changes.append(str(STAT_NAMES.get(field,field.capitalize()))+" %d → %d"%[old,now])
		var town=app.sim.get_settlement(int(after.settlement))
		for field in ["illness","cursed","possessed","imprisoned","grieving","alive"]:
			if before.get(field)!=after.get(field): changes.append(str(field).capitalize()+": "+str(before.get(field))+" → "+("clear" if field=="illness" and str(after.get(field)).is_empty() else str(after.get(field))))
		var actual_label=str(app.sim.state.citizens.overrides.get(str(after.key),{}).get("last_intervention",{}).get("label",""))
		var badge=Feedback.badge(action,actual_label)
		app.world.show_cast_feedback(action,int(town.x),int(town.y),1,badge.label+" · "+str(after.name),str(after.key))
		app.modal_body.add_child(app._paragraph(str(after.name)+" · "+badge.label,17,badge.color))
		if changes.is_empty(): changes.append("No immediate stat change. The outcome below explains what happened.")
		var message = app._paragraph((last_result if action in ["bribe_person","reveal_person","promise_mercy","promise_cruelty"] else power.name+" applied.")+"\n"+" · ".join(changes),13,app.TEAL)
		app.modal_body.add_child(message)
		message.add_theme_color_override("font_color",badge.color)
		var see=app._button("See change on map",func():app._close_modal();app.world.focus_person(key);app._refresh_inspector(),48)
		app.modal_body.add_child(see)
		app.modal_body.add_child(app._paragraph(last_result,13,app.LIGHT))
		app.modal_body.add_child(app._paragraph("Time is paused so you can inspect the change. Press Play when you are ready.",12,app.MUTED))
		app.modal_body.add_child(app._button("Back to their influence",_return_to_influence.bind(key),48))
		app._toast(last_result if action in ["bribe_person","reveal_person"] else power.get("name", "Intervention")+" applied.")
	else:
		if is_instance_valid(app.modal_body): app.modal_body.add_child(app._paragraph(last_result, 12, app.RED))
		app._toast(last_result, true)

func show_factions():
	app._open_modal("Realms", Vector2(380, 620))
	app.modal_body.add_theme_constant_override("separation", 0)
	for nation in app.sim.state.nations:
		var summary = app.sim.faction_summary(int(nation.id))
		var detail = "%s people · %s Age" % [app._number(summary.get("population", 0)), app._era_name(int(summary.get("era", summary.get("highest_era", 0))))]
		var wars = summary.get("wars", []).size()
		if wars > 0: detail += " · %d wars" % wars
		card(app.modal_body, nation.name, detail, show_faction.bind(int(nation.id)), Color(nation.color))
	app.modal_body.add_child(app._button("Settlement atlas", app._show_atlas, 48))

func show_faction(id):
	var faction = app.sim.faction_summary(id)
	if last_faction != id: faction_tab = "Overview"
	last_faction = id
	app._open_modal(faction.get("name", "Realm"), Vector2(380, 620))
	app.modal_body.add_theme_constant_override("separation", 4)
	_tabs(app.modal_body, FACTION_TABS, faction_tab, _select_faction_tab.bind(id))
	match faction_tab:
		"Society":
			for town in app.sim.state.settlements:
				if int(town.nation)==id and app.sim.resident_population(town)>0:
					card(app.modal_body,town.name,"%d%% unrest · %d%% tyranny"%[float(town.get("unrest",0))*100,float(town.get("tyranny",0))*100],show_society.bind(int(town.id)),app.GOLD)
		"Leaders":
			var leaders = faction.get("leaders", [])
			if leaders.is_empty(): app.modal_body.add_child(app._paragraph("No living leaders.", 13))
			for person in leaders:
				card(app.modal_body, person.name, "%s · %d%% standing · %d%% influence" % [str(person.role).capitalize(), float(person.get("standing", 0)) * 100, float(person.get("influence", 0)) * 100], show_person.bind(str(person.key)), app.GOLD, person)
		"Towns":
			for town in app.sim.state.settlements:
				if int(town.nation) == id and town.population + town.get("orbital_population", 0) > 0:
					card(app.modal_body, town.name, "%s people · %s Age" % [app._number(town.population + town.get("orbital_population", 0)), app._era_name(town.era)], _inspect_town.bind(int(town.id)))
		_:
			var stats = _grid(app.modal_body)
			for pair in [["People", faction.get("population", 0)], ["Towns", faction.get("settlements", 0)], ["Food", faction.get("food", 0)], ["Wealth", faction.get("wealth", 0)]]:
				_stat(stats, pair[0], app._number(pair[1]))
			for pair in [["Stability", "stability"], ["Aggression", "aggression"], ["God", "faith"], ["Devil", "corruption"]]:
				_stat(stats, pair[0], "%d%%" % [float(faction.get(pair[1], 0)) * 100])
			_stat(app.modal_body, "Highest age", app._era_name(int(faction.get("era", faction.get("highest_era", 0)))), app.GOLD)
			var leaders = faction.get("leaders", [])
			if not leaders.is_empty():
				_section(app.modal_body, "Leadership")
				var person = leaders[0]
				card(app.modal_body, person.name, str(person.role).capitalize() + " · select to inspect", show_person.bind(str(person.key)), app.GOLD, person)
			var wars = faction.get("wars", [])
			_section(app.modal_body, "Conflict · %d active" % wars.size())
			if wars.is_empty(): app.modal_body.add_child(app._label("At peace", 12, app.TEAL))
			for war in wars:
				var rival = war.b if int(war.a) == id else war.a
				_disclosure(app.modal_body, app._nation_name(int(rival)) + " · since " + str(war.since), str(war.reason))
			_disclosure(app.modal_body, "Realm direction & stats", str(faction.get("direction", "Its future is shaped by its people.")) + "\nStability reflects contentment; aggression is willingness to fight. Food, leaders, beliefs and interventions change these values.")
	app.modal_body.add_child(app._button("All realms", show_factions, 48))

func _select_faction_tab(tab, id):
	faction_tab = tab
	show_faction(id)

func _inspect_town(id):
	app._close_modal()
	app._inspect_city(id)

func _chart_stat(parent,title_,value,accent):
	var cell=VBoxContainer.new()
	cell.add_theme_constant_override("separation",2)
	cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(cell)
	cell.add_child(app._label(title_+"  %d"%roundi(value*100),12,app.LIGHT))
	var bar=ProgressBar.new()
	bar.value=clampf(value*100,0,100)
	bar.show_percentage=false
	bar.custom_minimum_size=Vector2(80,7)
	bar.add_theme_stylebox_override("background",app._style(Color("243338"),Color.TRANSPARENT,3,0))
	bar.add_theme_stylebox_override("fill",app._style(accent,Color.TRANSPARENT,3,0))
	cell.add_child(bar)

func _select_action_group(group,key):
	action_group=group
	_return_to_influence(key)

func _relative_card(parent,key,relation):
	var relative=app.sim.get_individual(str(key))
	if relative.is_empty(): return
	card(parent,relative.name,relation+("" if relative.role=="child" else " · "+str(relative.role).capitalize())+" · age %d"%int(relative.age)+(" · deceased" if not relative.alive else ""),show_person.bind(str(relative.key)),app.GOLD if relative.alive else app.MUTED,relative)

func _fill_family(parent,person):
	_stat(parent,"Household",person.get("marital_status","Single"),app.GOLD)
	parent.add_child(app._paragraph(person.get("family_origin","Ancestry was not recorded before this world began."),12,app.MUTED))
	if not str(person.get("spouse","")).is_empty():
		_relative_card(parent,person.spouse,"Spouse · married in year %d"%int(person.married_year))
	_section(parent,"Parents")
	if person.get("parents",[]).is_empty(): parent.add_child(app._paragraph("No recorded parents. Founding residents begin with unrecorded ancestry.",12,app.MUTED))
	for key in person.get("parents",[]): _relative_card(parent,key,"Parent")
	_section(parent,"Children · %d"%person.get("children",[]).size())
	if person.get("children",[]).is_empty(): parent.add_child(app._paragraph("No children recorded.",12,app.MUTED))
	for key in person.get("children",[]): _relative_card(parent,key,"Child")
	var promises=person.get("promises",[])
	if not promises.is_empty(): _section(parent,"Family promises")
	for vow in promises:
		var patient=app.sim.get_individual(str(vow.patient))
		_disclosure(parent,("Merciful" if vow.side=="god" else "Dark")+" promise · "+vow.status,"A cure for "+str(patient.get("name",vow.patient))+" by year %d. "%int(vow.deadline)+str(vow.get("outcome","")))
		if vow.status in ["offered","pending"]:
			_relative_card(parent,vow.patient,"Needs divine healing")
			if vow.status=="offered": parent.add_child(app._button("Consider this promise",preview_action.bind("promise_mercy",str(vow.actor)),48))
	parent.add_child(app._paragraph("Marriage begins in adulthood. Families share grief and gratitude; children inherit a history and learn from their parents' example.",12,app.MUTED))

func show_society(id):
	var town=app.sim.get_settlement(id)
	if town.is_empty(): return
	app._open_modal(town.name+" · Society",Vector2(400,650))
	var parent=app.modal_body
	_chart_stat(parent,"Public unrest",float(town.get("unrest",0)),app.RED)
	_chart_stat(parent,"Tyranny",float(town.get("tyranny",0)),app.RED)
	_section(parent,"Public office")
	_relative_card(parent,"p:%d"%int(town.leader),"Ruler")
	for role in ["politician","judge"]:
		for key in app.sim.role_keys(id,role,3): _relative_card(parent,key,str(role).capitalize())
	_section(parent,"Laws in force")
	var count=0
	for law in app.sim.state.society.laws:
		if int(law.town)!=id or int(law.until)<=int(app.sim.state.year): continue
		count+=1
		var descriptions={"relief":"Public food relief improves happiness and costs treasury wealth.","schools":"Children gain wisdom and research grows; schools cost public wealth.","fair_trials":"Fair treatment reduces fear.","guild_privileges":"Merchants gain private wealth; workers pay a cost and resentment grows.","repression":"Fear, unhappiness, and opposition grow under state repression."}
		_disclosure(parent,law.name+" · until "+str(int(law.until)),"Benefits "+law.group+". "+descriptions.get(law.kind,"")+" "+law.reason)
		_relative_card(parent,law.actor,"Passed this law")
	if count==0: parent.add_child(app._paragraph("Customary rules; no special law is in force.",12,app.MUTED))
	_section(parent,"Opposition")
	for movement in app.sim.state.society.movements:
		if int(movement.town)!=id: continue
		_stat(parent,str(movement.status).capitalize(),"%d%% support"%roundi(float(movement.support)*100),app.GOLD)
		if not str(movement.organizer).is_empty(): _relative_card(parent,movement.organizer,"Organizer")
	parent.add_child(app._paragraph("Tyranny, exposed corruption, fear and resentment can build opposition. A successful uprising deposes the ruler; a divided realm can enter civil war.",12,app.MUTED))
	_section(parent,"Recent justice records")
	var cases=[]
	for crime in app.sim.state.society.crimes:
		if int(crime.town)==id: cases.append(crime)
	if cases.is_empty(): parent.add_child(app._paragraph("No crimes recorded.",12,app.MUTED))
	for i in range(cases.size()-1,maxi(-1,cases.size()-9),-1):
		var crime=cases[i]
		_disclosure(parent,"Year %d · %s · %s"%[int(crime.year),str(crime.kind).capitalize(),crime.status],"Hidden means the authorities have not identified the culprit. As a deity you can inspect the lives involved.")
		_relative_card(parent,crime.actor,"Perpetrator")
		_relative_card(parent,crime.victim,"Victim")
	parent.add_child(app._button("Residents",show_people.bind(id),48))
