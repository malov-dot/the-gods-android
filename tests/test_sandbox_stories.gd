extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Powers=preload("res://scripts/powers.gd")
const Saves=preload("res://scripts/save_manager.gd")
const Journal=preload("res://scripts/story_journal.gd")
const Projects=preload("res://scripts/personal_projects.gd")
var checks=0
var failures=0
var app
func _init(): run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok: failures+=1;push_error("SANDBOX STORIES: "+label)
func world(seed_="Stories"):
	var sim=Sim.new();sim.new_world({"seed":seed_,"width":64,"height":48,"nations":2,"mode":"hotseat","player_side":"devil"});return sim
func nodes(node):
	var all=[node]
	for child in node.get_children(): all.append_array(nodes(child))
	return all
func settle():
	for i in range(8): await process_frame
func capture(name_):
	if DisplayServer.get_name()=="headless" or not "--screenshots" in OS.get_cmdline_user_args(): return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/sandbox-"+name_+".png")
func run():
	Saves.storage_directory="res://test-output/sandbox-stories-saves"
	var sim=world();var powers=Powers.new()
	check(sim.state.mode=="sandbox" and not powers.has_method("ai_turn"),"New worlds are sandbox and no opponent exists")
	var old=sim.state.duplicate(true);old.mode="versus_ai";old.victory="devil";old.actions_left=0;old.ai_actions=100
	sim.restore(old);sim.step(1)
	check(sim.state.year==1 and sim.state.mode=="sandbox" and sim.state.victory=="" and not sim.state.has("actions_left"),"Old completed versus saves resume without turn or victory locks")
	check(powers.set_doctrine(sim,"god","Knowledge").ok and powers.set_doctrine(sim,"devil","Chaos").ok,"Both divine traditions remain accessible")
	var town=sim.state.settlements[0];var ruler=sim.get_individual("p:%d"%int(town.leader))
	check(powers.apply_to_person(sim,"curse_person",ruler.key,"devil").ok and powers.apply_to_person(sim,"purify_person",ruler.key,"god").ok,"Both types of personal influence are free")
	check(Journal.entries(sim).any(func(e):return e.person==ruler.key),"An influenced person appears in the journal")
	# A full family story: appeal, accepted bargain, actual cure, named law and outcome.
	var child_id=int(sim.state.citizens.next_id);town.population+=1;sim._citizens.add(sim,town.id,1)
	var child="c:%d"%child_id
	check(sim._society.link_child(sim,child,[ruler.key]),"A real child links to the ruler")
	sim._society.adjust(sim,ruler.key,{"honor":1})
	var life=sim._society.edit_life(sim,child);life.illness="Fever";life.sick_until=sim.state.year+3
	sim._society.civic.offer_family_promise(sim,sim._society,town,sim.get_individual(child))
	check(Journal.entries(sim).any(func(e):return e.get("patient","")==child and "Offered" in e.title),"A family appeal is discoverable without global news")
	check(powers.apply_to_person(sim,"promise_mercy",ruler.key).ok,"Accept the family promise")
	check(powers.apply_to_person(sim,"heal_person",child).ok,"Heal the named child")
	check(sim.get_individual(child).illness.is_empty() and sim.state.society.promises[-1].status=="fulfilled","The cure resolves this family's promise")
	check(Journal.entries(sim).any(func(e):return e.get("patient","")==child and "Common Relief" in e.detail),"Journal connects cure to actual law and beneficiaries")
	# A real project progresses, stalls and completes with a measurable reward.
	var project_person=sim.get_individual(ruler.key);project_person.role="farmer";project_person.health=1;project_person.happiness=1;project_person.wisdom=1;project_person.illness="";project_person.cursed=false;project_person.imprisoned=false
	sim._society.edit_life(sim,ruler.key).erase("project");town.food=1000
	Projects.annual(sim,sim._society,town,project_person)
	var project=sim._society.life(sim,ruler.key).project;var progress=project.progress
	project_person.illness="Fever";sim.state.year+=1;Projects.annual(sim,sim._society,town,project_person)
	check(project.progress-progress<0.2 and "Illness" in project.obstacle,"Illness visibly slows a saved goal")
	project_person.illness="";project.progress=7.9;var food=town.food
	sim.state.year+=1;Projects.annual(sim,sim._society,town,project_person)
	check(project.status=="completed" and town.food==food+12,"Completed goal delivers its promised food")
	# Restore the actual identity, including a dead ruler who already has a successor.
	var victim=sim.get_individual(ruler.key);var next_id=sim.state.citizens.next_id
	check(sim.kill_individual(victim.key,"Test illness"),"The fixture person dies")
	sim._people_year();var successor=town.leader
	check(powers.apply_to_person(sim,"resurrect_person",victim.key).ok,"The selected dead person returns")
	var revived=sim.get_individual(victim.key)
	check(revived.alive and revived.name==victim.name and child in revived.children and sim.state.citizens.next_id==next_id,"Resurrection retains identity and family without adding a new identity")
	check(town.leader==successor and revived.role=="elder","Returning former rulers respect the current office")
	check(not powers.apply_to_person(sim,"resurrect_person",victim.key).ok,"A living person cannot be duplicated")
	var saved=Saves.save_game(sim.state,0);check(saved.ok,"New stories and resurrected identities validate: "+saved.message)
	var loaded=Saves.load_game(0);check(loaded.ok,"Stories survive disk save/load")
	if loaded.ok:
		var resumed=Sim.new();resumed.restore(loaded.state)
		check(resumed.get_individual(victim.key).alive and resumed.get_individual(victim.key).project.status=="completed","Project and restored life survive reload")
		check(Journal.entries(resumed).any(func(e):return e.get("patient","")==child),"The family story survives reload")
	var malformed=sim.state.duplicate(true);malformed.citizens.overrides[ruler.key].life.project.progress=-1
	check(not Saves.validate_state(malformed).ok,"Malformed project progress is rejected")
	# An already-titled adult heir inherits without replacing their identity.
	var dynasty=world("Dynasty");var court=dynasty.state.settlements[0]
	var parent=dynasty.get_individual("p:%d"%int(court.leader))
	var heir_id=int(dynasty.state.citizens.next_id);court.population+=1;dynasty._citizens.add(dynasty,court.id,1)
	var heir_key="c:%d"%heir_id
	dynasty.state.citizens.overrides[heir_key]={"born":-20}
	dynasty.state.citizens.overrides[parent.key].born=-50
	var heir_named=dynasty._create_person(court,"prophet",heir_key)
	var heir=dynasty.get_individual("p:%d"%int(heir_named.id))
	check(dynasty._society.link_child(dynasty,heir.key,[parent.key]),"Heir fixture records real ancestry")
	var identity_count=dynasty.state.citizens.next_id
	dynasty.kill_individual(parent.key,"Old age");dynasty._people_year()
	check(court.leader==heir_named.id and dynasty.get_individual(heir.key).role=="ruler" and dynasty.state.citizens.next_id==identity_count,"An adult titled heir inherits with the same identity")
	# Return the middle identity in a compact death range; neighbours stay dead.
	var cohort_world=world("Returns");var village=cohort_world.state.settlements[0]
	var first=int(cohort_world.state.citizens.next_id)
	village.population+=5;cohort_world._citizens.add(cohort_world,village.id,5)
	for id in range(first,first+5): cohort_world.kill_individual("c:%d"%id,"Test disaster")
	var registry=cohort_world.state.citizens
	registry.deceased=registry.deceased.filter(func(row):return int(row[0])<first or int(row[0])>=first+5)
	registry.deceased.append([first,5,cohort_world.state.year,village.id,0])
	cohort_world._citizens._death_buckets.clear();cohort_world._citizens._indexed_deaths=0
	var returning_key="c:%d"%(first+2)
	var souls=cohort_world.state.afterlife.heaven+cohort_world.state.afterlife.hell+cohort_world.state.afterlife.wandering
	check(powers.apply_to_person(cohort_world,"resurrect_person",returning_key).ok,"Restore a person from the middle of a death range")
	check(not cohort_world.get_individual("c:%d"%(first+1)).alive and not cohort_world.get_individual("c:%d"%(first+3)).alive,"Split death range preserves both deceased neighbours")
	check(is_equal_approx(cohort_world.state.afterlife.heaven+cohort_world.state.afterlife.hell+cohort_world.state.afterlife.wandering,souls-1),"Return reconciles the pooled afterlife count")
	cohort_world.kill_individual(returning_key,"Test illness")
	check(powers.apply_to_person(cohort_world,"resurrect_person",returning_key).ok and Saves.validate_state(cohort_world.state).ok,"Repeated death and return preserves a valid population registry")
	# Native UI: no game-mode selector, player handoffs or opponent controls.
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await settle()
	app.settings.autosave=false;app.settings.ambient=false;app.settings.voices=false;app._stop_audio();app.set_process(false)
	app._show_new_world();await settle()
	var text=" ".join(nodes(app.modal_body).filter(func(n):return n is Label or n is Button).map(func(n):return n.text))
	check(not "Versus" in text and not "YOUR MANTLE" in text and "single-player" in text,"World creation contains only sandbox choices")
	app._close_modal();app.sim=sim;app.world.sim=sim;app.game_started=true;app.world.frame_world();app._refresh_ui(true)
	app.world_stories.refresh()
	sim.add_event("A royal wedding","First ceremony","royal_wedding",town.x,town.y)
	sim.add_event("Another royal wedding","Second ceremony","royal_wedding",town.x,town.y)
	sim.add_event("A war begins","Two realms take up arms","war_start",town.x,town.y)
	app.world_stories.refresh()
	check(app.world_stories.stories.size()==2 and app.world_stories.stories[0].kind=="war_start","War takes priority and repeat royal weddings are quiet within ten years")
	root.size=Vector2i(390,844);await settle();app._responsive_layout()
	app.community.show_person(child);await settle();await capture("phone-person")
	var buttons=nodes(app.modal_body).filter(func(n):return n is Button)
	check(buttons.any(func(b):return b.text=="Show full stats & biography"),"Full chart remains one tap away")
	check(buttons.any(func(b):return b.has_meta("compact_favorite")),"Profile favorite is a compact 48dp header action")
	app._show_stories();await settle();await capture("phone-journal")
	check(nodes(app.modal_body).any(func(n):return n is Label and "Common Relief" in n.text),"The visible journal explains the resulting law")
	root.size=Vector2i(1440,900);await settle();app._responsive_layout();app.community.show_person(victim.key);await settle();await capture("pc-person")
	app._close_modal();app._show_menu();await settle()
	text=" ".join(nodes(app.modal_body).filter(func(n):return n is Label or n is Button).map(func(n):return n.text))
	check("Lives & stories" in text and not "win" in text.to_lower(),"Menu exposes stories without competition language")
	app._stop_audio();app.queue_free();await settle()
	print("SANDBOX STORIES: %d checks; %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
