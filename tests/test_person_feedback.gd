extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Powers=preload("res://scripts/powers.gd")
const Feedback=preload("res://scripts/person_interventions.gd")
const Saves=preload("res://scripts/save_manager.gd")
var failures=0
var checks=0
func _init(): run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok: failures+=1;push_error(label)
func nodes(node):
	var result=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
func settle():
	for i in range(8):await process_frame
func capture(name_):
	if DisplayServer.get_name()=="headless" or not "--screenshots" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/person-feedback-"+name_+".png")
func run():
	Saves.storage_directory="res://test-output/person-feedback-saves"
	var sim=Sim.new();sim.new_world({"seed":"Visible personal consequences","width":64,"height":48,"nations":2})
	var powers=Powers.new();var town=sim.state.settlements[0]
	var key=sim.get_individual("p:%d"%int(town.leader)).key
	sim.state.mana={"god":0.0,"devil":0.0}
	for power in Powers.PERSON_CATALOG:
		check(power.cost==0 and not Feedback.description(power.id).is_empty(),"Every personal action is free and explained: "+power.id)
		check(not Feedback.badge(power.id).symbol.is_empty(),"Every action has an identifiable visual cue")
	for power in Powers.CATALOG:check(power.cost==0,"World powers are also free: "+power.id)
	check(powers.apply_to_person(sim,"curse_person",key,"devil").ok,"Curse succeeds with zero essence")
	var marks=Feedback.markers(sim,sim.get_individual(key))
	check(marks[0].action=="curse_person" and marks[0].remaining==8,"Curse has its own marker and exact expiry")
	powers.apply_to_person(sim,"possess_person",key,"devil")
	check(Feedback.markers(sim,sim.get_individual(key)).size()==2,"Concurrent afflictions remain visible")
	powers.apply_to_person(sim,"purify_person",key,"god")
	marks=Feedback.markers(sim,sim.get_individual(key))
	check(marks.size()==1 and marks[0].label.begins_with("Last: Released"),"Purification removes both active markers and records the release")
	powers.apply_to_person(sim,"bless_person",key,"god")
	check(Feedback.markers(sim,sim.get_individual(key))[0].remaining==12,"Blessing marker lasts exactly as long as its real influence")
	sim.state.year+=12
	marks=Feedback.markers(sim,sim.get_individual(key))
	check(marks[0].remaining==0 and "effect ended" in marks[0].label,"Expired effects are identified as history, never active buffs")
	sim._society.adjust(sim,key,{"honor":1.0})
	powers.apply_to_person(sim,"bribe_person",key,"devil")
	check(Feedback.markers(sim,sim.get_individual(key))[0].label.contains("Bribe refused"),"A refused bribe does not claim a law was passed")
	sim.state.mode="sandbox"
	check(powers.apply_to_person(sim,"teach_person",key,"god").ok,"Versus actions also work with zero essence")
	var mana=sim.state.mana.duplicate()
	check(powers.apply(sim,"rain",town.x,town.y,2,"god").ok and sim.state.mana==mana,"World powers do not deduct essence")
	var saved=Saves.save_game(sim.state,0);check(saved.ok,"Save preserves visual feedback: "+saved.message)
	var loaded=Saves.load_game(0);check(loaded.ok,"Feedback save loads")
	if loaded.ok:
		var resumed=Sim.new();resumed.restore(loaded.state)
		check(Feedback.markers(resumed,resumed.get_individual(key))[0].label==Feedback.markers(sim,sim.get_individual(key))[0].label,"Last action marker survives restore")
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await settle()
	app._close_modal();app.settings.autosave=false;app.settings.voices=false;app.settings.ambient=false;app._stop_audio();app.set_process(false)
	app.sim=sim;app.world.sim=sim;app.game_started=true;app.tutorial_active=false;sim.state.mode="sandbox"
	root.size=Vector2i(390,844);await settle();app._responsive_layout()
	app.community.preview_action("curse_person",key);await settle()
	var text_=""
	for node in nodes(app.modal_body):
		if node is Label or node is Button:text_+=node.text+"\n"
	check("Duration" in text_ and "27" in text_ and "22" in text_,"Preview states exact curse effects and duration")
	check(not "Cost" in text_ and not "essence" in text_,"Personal preview contains no currency price")
	app.community.commit_action("curse_person",key,"devil");await settle()
	text_=""
	for node in nodes(app.modal_body):
		if node is Label or node is Button:text_+=node.text+"\n"
	check("→" in text_ and "Cursed" in text_ and "See change on map" in text_,"Result shows actual stat changes, status and map shortcut")
	await capture("profile")
	app._close_modal();app.world.focus_person(key);app.world.set_zoom(8);await settle()
	check(app.shell.status_panel.size.y<=64,"Action toast stays compact so the affected person remains visible")
	await capture("curse-map")
	check(not app.mana_label.get_parent().get_parent().visible,"Unused currency HUD is hidden")
	app._stop_audio();app.queue_free();await process_frame
	print("PERSON FEEDBACK: %d checks; %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
