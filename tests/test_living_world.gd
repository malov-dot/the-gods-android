extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Transport=preload("res://scripts/world_transport.gd")
const Diplomacy=preload("res://scripts/diplomacy.gd")
const Sound=preload("res://scripts/world_audio.gd")
const Sprites=preload("res://scripts/sprite_people.gd")
const Saves=preload("res://scripts/save_manager.gd")
const News=preload("res://scripts/world_stories.gd")
class SilentProbe extends Node:
	var calls=0
	func play_effect(_kind,_gain=1.0): calls+=1
var checks=0
var failures=0
var app
func _init(): run.call_deferred()
func check(value,message):
	checks+=1
	if not value: failures+=1; push_error("LIVING WORLD: "+message)
func settle():
	for i in range(8): await process_frame
func descendants(node):
	var found=[]
	for child in node.get_children(): found.append(child); found.append_array(descendants(child))
	return found
func equivalent(a,b)->bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b))<0.00000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b
func capture(name_):
	if not "--screenshots" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	await create_timer(0.25).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/living-world-"+name_+".png")
func run():
	Saves.storage_directory="res://test-output/living-world-saves"
	var sim=Sim.new(); sim.new_world({"seed":"A world worth hearing","width":64,"height":48,"nations":2})
	var a=sim.state.settlements[0]; var b=sim.state.settlements[1]
	a.x=14; a.y=20; b.x=28; b.y=20
	for y in range(48):
		for x in range(64): sim.get_tile(x,y).elevation=0.2 if x>=18 and x<=23 else 0.55
	sim.state.terrain_revision+=1
	a.era=7; b.era=7; a.food=300; b.food=0
	sim._trade_and_diffusion()
	var before=a.food+b.food; var rng_before=sim.rng.state
	Transport.annual(sim)
	check(a.food+b.food>before,"Fishing missions contribute actual food")
	check(sim.rng.state==rng_before,"Transport planning does not consume simulation randomness")
	for mission in sim.state.transport.missions:
		if mission.kind!="fishing": continue
		check(mission.path.size()>=8,"Fishing boats leave port on a visible journey")
		for i in range(1,mission.path.size()):
			var prev=mission.path[i-1]; var next=mission.path[i]
			check(abs(prev[0]-next[0])+abs(prev[1]-next[1])==1,"Fishing routes follow adjacent water tiles")
		var old=mission.duplicate(true); old.path=old.path.slice(0,2)
		var migration=Sim.new(); migration.restore(sim.state.duplicate(true))
		migration.state.transport.missions=[old]
		var migration_food=migration.state.settlements[0].food; var migration_rng=migration.rng.state
		Transport.upgrade_routes(migration)
		check(old.path.size()>=8,"Existing saves receive longer fishing routes")
		check(migration.state.settlements[0].food==migration_food and migration.rng.state==migration_rng,"Route migration grants no extra food and uses no randomness")
	check(sim.state.transport.missions.any(func(m):return m.kind=="cargo" and m.cargo>0),"Food trade has a visible cargo voyage")
	sim.state.wars=[{"a":a.nation,"b":b.nation,"since":0,"reason":"Contested waters"}]
	Transport.annual(sim)
	check(sim.state.wars[0].theater=="sea","Opposing coastal civilizations form a naval front")
	check(sim.state.transport.missions.filter(func(m):return m.kind=="naval").size()==2,"Both nations send a fleet")
	check(not sim.state.transport.missions.any(func(m):return m.kind=="cargo"),"War stops peaceful cargo traffic")
	for mission in sim.state.transport.missions:
		check(Transport.position_at(mission,2).distance_to(Transport.position_at(mission,4))>4,"Fishing and naval boats visibly travel in two seconds")
		for t in range(30):
			var point=Transport.position_at(mission,float(t)*1.77)/8
			check(sim.get_tile(int(point.x),int(point.y)).elevation<0.36,"Ships remain on a connected water route")
	check((await Transport.sea_path(sim,[1,1],[60,1])).is_empty(),"Sea routes cannot cross dry land")
	var population_before=a.population+b.population
	sim._conflict_year()
	check(a.population+b.population<population_before and sim.state.wars[0].casualties_a>0,"Naval war has recorded combat casualties")
	sim.state.year=30; sim._conflict_year()
	check(sim.state.wars.is_empty() and not Diplomacy.pact(sim,a.nation,b.nation).is_empty(),"War ends with a bilateral peace treaty")
	check(sim.state.events.any(func(e):return e.kind=="diplomacy" and "peace treaty" in e.title),"Treaty is a clickable world event")
	Diplomacy.sign_agreement(sim,a.nation,b.nation,"alliance",20,a)
	check(Diplomacy.pact(sim,a.nation,b.nation).kind=="alliance","Alliance terms replace an older agreement for the pair")
	sim.state.year=50; Diplomacy.annual(sim)
	check(Diplomacy.pact(sim,a.nation,b.nation).is_empty(),"An expired treaty stops blocking conflict")
	for era in [8,9,10,13]:
		a.era=era; a.buildings=["spaceport"] if era==13 else []
		Transport.annual(sim)
		var missions=sim.state.transport.missions.filter(func(m):return m.town==a.id)
		check(missions.any(func(m):return m.kind=="plane")== (era>=9),"Aircraft follow the civilization's technology")
		check(missions.any(func(m):return m.kind=="helicopter")== (era>=10),"Helicopters appear in the appropriate ages")
		check(missions.any(func(m):return m.kind=="rocket")== (era==13),"Rockets launch from a Space Age spaceport")
	for town in sim.state.settlements: sim._citizens.sync_town(sim,town)
	sim.refresh_totals()
	var saved=Saves.save_game(sim.state,0); check(saved.ok,"Transport and diplomacy save: "+saved.message)
	var loaded=Saves.load_game(0); check(loaded.ok,"Transport and diplomacy load")
	if loaded.ok:
		var resumed=Sim.new(); resumed.restore(loaded.state)
		check(equivalent(resumed.state.transport,sim.state.transport),"Missions survive a disk round trip")
		for i in range(3): sim.step(1); resumed.step(1)
		check(equivalent(sim.state,resumed.state),"Save/load continuation retains world outcomes within JSON floating-point precision")
	var ruler=sim.get_individual("p:%d"%int(a.leader))
	for event in [{"kind":"wedding","title":"A wedding"},{"kind":"person","title":"A cure"},{"kind":"technology","title":"A new era"},{"kind":"politics","title":"A new law"},{"kind":"disaster","title":"A storm"},{"kind":"diplomacy","title":"An alliance expires"},{"kind":"war","title":"A war ends"}]:
		check(not News.is_news(event),"Routine events and duplicate war endings stay out of news: "+event.title)
	for event in [{"kind":"royal_wedding","title":"A royal wedding"},{"kind":"war_start","title":"War is declared"},{"kind":"peace","title":"Peace is declared"},{"kind":"war","title":"A city falls"},{"kind":"diplomacy","title":"An alliance is formed"},{"kind":"diplomacy","title":"A peace treaty is signed"},{"kind":"politics","title":"Civil war in Test"}]:
		check(News.is_news(event),"Major events remain news: "+event.title)
	var speech=Sound.introduction(ruler,a)
	check(ruler.name in speech and a.name in speech and "I lead" in speech and "want" in speech,"Introduction names the selected person, community, status and wants")
	var sick=ruler.duplicate(); sick.illness="Fever"; sick.imprisoned=false
	check("Fever" in Sound.introduction(sick,a) and "get well" in Sound.introduction(sick,a),"Sickness changes what a person says they need")
	sick.imprisoned=true; check("freedom" in Sound.introduction(sick,a),"Imprisonment changes personal priorities")
	for era in range(14):
		check(not Sound.battle_kind(era,0).is_empty(),"Every era has battle Foley")
	for kind in ["steel","bow","hoof","catapult","musket","cannon","rifle","engine","plasma","water","bell"]:
		var stream=Sound.foley(kind)
		check(stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and stream.get_length()>0.3,"Foley has finite stereo PCM: "+kind)
		var playback=stream.instantiate_playback(); playback.start()
		var buffer=playback.mix_audio(1.0,22050)
		var bounded=not buffer.is_empty()
		for sample in buffer: bounded=bounded and is_finite(sample.x) and is_finite(sample.y) and absf(sample.x)<=1 and absf(sample.y)<=1
		check(bounded,"Native mixer produces finite bounded samples: "+kind)
		playback.stop()
		playback=null; stream=null
	for era in range(14):
		var im=Sprites.pixels(era,Color("c38a69"),17,"soldier",0)
		check(im.get_size()==Vector2i(32,48),"High-detail characters use 32 by 48 source pixels")
		check(im.get_data()!=Sprites.pixels(era,Color("c38a69"),17,"soldier",1).get_data(),"Walking frames move limbs")
		if "--screenshots" in OS.get_cmdline_user_args(): im.save_png("res://test-output/sprite-era-%d.png"%era)
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); await settle()
	app.settings.autosave=false; app.settings.ambient=false; app.settings.voices=false; app._stop_audio(); app.set_process(false); app.game_started=true; app.tutorial_active=false
	app._close_modal(); app.sim=sim; app.world.sim=sim; app.world_stories.epoch=-1; app._refresh_ui(true)
	check(app.world_stories.stories.is_empty(),"Loading a world does not flood the HUD with old events")
	var original_audio=app.world_audio; var probe=SilentProbe.new(); app.world_audio=probe
	sim.add_event("A wedding","An ordinary household wedding.","wedding",a.x,a.y)
	app._refresh_ui(); check(app.world_stories.stories.is_empty(),"Ordinary weddings do not create HUD notices")
	sim.add_event("A royal wedding in "+a.name,"Two people join their lives.","royal_wedding",a.x,a.y,["Person: "+ruler.key])
	app._refresh_ui(); check(app.world_stories.stories.size()==1,"Royal weddings appear as notices")
	check(probe.calls==0,"News is silent even with world audio available"); app.world_audio=original_audio; probe.free()
	app.world_stories.show_feed(); await settle()
	var cards=descendants(app.modal_body).filter(func(n):return n is Button and n.has_meta("content_row"))
	check(cards.size()==1,"World notices open an event list")
	cards[0].pressed.emit(); await settle()
	var linked=descendants(app.modal_body).filter(func(n):return n is Button and n.text.begins_with("Meet "))
	check(linked.size()==1,"Event links to the actual participant")
	linked[0].pressed.emit(); await settle()
	check(app.selected_person_key==ruler.key,"Opening an event participant selects the correct person")
	root.size=Vector2i(390,844); await settle(); app._responsive_layout(); await capture("introduction-phone")
	app._close_modal(); app.world.set_zoom(12); app.world.center_on_tile(a.x,a.y); await settle(); await capture("spaceport-street")
	if "--screenshots" in OS.get_cmdline_user_args():
		var boats=sim.state.transport.missions.filter(func(m):return m.kind=="fishing")
		if not boats.is_empty():
			var boat=boats[0]; var p=Transport.position_at(boat,2)/8
			app.world.center_on_tile(p.x,p.y); app.world.set_process(false)
			app.world._time=2; app.world.queue_redraw(); await capture("boats-before")
			app.world._time=6; app.world.queue_redraw(); await capture("boats-after")
			app.world.set_process(true)
			app.world.center_on_tile(a.x,a.y)
	var old_gain=Sound.gain_at(app.world,Vector2(a.x+0.5,a.y+0.5)*8)
	app.world.zoom=0.5
	check(old_gain>Sound.gain_at(app.world,Vector2(a.x+0.5,a.y+0.5)*8),"Zooming out attenuates local battle audio")
	app._stop_audio(); app.queue_free(); await process_frame; await process_frame
	print("LIVING WORLD: %d checks; %d failures"%[checks,failures]); quit(0 if failures==0 else 1)
