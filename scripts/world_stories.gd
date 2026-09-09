extends Node
var app
var epoch=-1
var last_id=-1
var stories=[]
var panel:HBoxContainer
var notice:Button
var dismiss:Button
var wedding_years={}
static func is_news(event:Dictionary)->bool:
	var kind=str(event.get("kind","")); var title_=str(event.get("title",""))
	if kind in ["royal_wedding","war_start","peace"]: return true
	if kind=="war": return title_!="A war ends" # The peace treaty is the headline.
	if kind=="diplomacy": return title_ in ["An alliance is formed","A peace treaty is signed"]
	if kind=="politics": return title_.begins_with("Civil war in ") or title_.begins_with("Revolution in ")
	return false
func setup(host):
	app=host
	panel=HBoxContainer.new(); panel.add_theme_constant_override("separation",4); panel.z_index=12; app.shell.hud.add_child(panel)
	notice=app._button("",show_feed,48); notice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; notice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	notice.add_theme_font_size_override("font_size",12); panel.add_child(notice)
	dismiss=app._button("×",func():stories.clear(); panel.hide(),48); dismiss.custom_minimum_size.x=48; dismiss.tooltip_text="Dismiss notices. Events remain in the Chronicle."; panel.add_child(dismiss)
	panel.hide()
func refresh():
	var events=app.sim.state.get("events",[])
	if epoch!=app.sim.generation:
		epoch=app.sim.generation; stories.clear(); wedding_years.clear(); last_id=int(events[-1].id) if not events.is_empty() else -1
	else:
		for event in events:
			if int(event.id)<=last_id: continue
			if is_news(event):
				if event.kind=="royal_wedding":
					var place="%d:%d"%[int(event.get("x",-1)),int(event.get("y",-1))]
					if int(event.year)-int(wedding_years.get(place,-100))<10: continue
					wedding_years[place]=int(event.year)
				stories.push_front(event.duplicate(true))
				if stories.size()>40: stories.pop_back()
		stories.sort_custom(func(a,b):return a.kind!="royal_wedding" if (a.kind=="royal_wedding")!=(b.kind=="royal_wedding") else int(a.id)>int(b.id))
		if not events.is_empty(): last_id=int(events[-1].id)
	panel.visible=not stories.is_empty() and app.settings.get("event_notices",true) and app.game_started and not is_instance_valid(app.modal)
	if not stories.is_empty(): notice.text="✦ "+str(stories[0].title)+"  ·  "+str(stories.size()); notice.tooltip_text="Major news: royal weddings, wars, peace, alliances and revolutions. No notification sounds."
	var size_=app.hud_rect().size
	var width_=minf(360,size_.x-24)
	panel.position=Vector2((size_.x-width_)*0.5,116 if app.shell.layout_mode=="portrait" else 64)
	panel.size=Vector2(width_,48)
func show_feed():
	app._open_modal("World news",Vector2(420,620))
	app.modal_body.add_child(app._paragraph("Wars, peace, alliances and revolutions appear first. Each community announces at most one royal wedding per ten years. Everyday lives stay in personal histories; the Chronicle keeps the wider world history.",13))
	for event in stories:
		app.community.card(app.modal_body,event.title,"Year %d · %s"%[event.year,str(event.kind).capitalize()],app._show_event.bind(event))
	app.modal_body.add_child(app._button("Open the Chronicle",app._show_history,48))
	stories.clear(); panel.hide()
func _process(_delta):
	if app!=null and is_instance_valid(panel) and is_instance_valid(app.modal): panel.hide()
func _exit_tree(): app=null
