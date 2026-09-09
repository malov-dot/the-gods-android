extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Powers=preload("res://scripts/powers.gd")
const Saves=preload("res://scripts/save_manager.gd")
var checks=0
var failures=0
var powers=Powers.new()
func _init(): call_deferred("run")
func check(value,label):
	checks+=1
	if not value: failures+=1; push_error("LIVING SOCIETY: "+label)
func world(seed_):
	var sim=Simulation.new(); sim.new_world({"seed":seed_,"width":64,"height":48,"nations":2})
	return sim
func new_child(sim,parent):
	var town=sim.get_settlement(int(parent.settlement))
	var id=int(sim.state.citizens.next_id)
	town.population+=1
	sim._citizens.add(sim,int(town.id),1)
	var key="c:%d"%id
	check(sim._society.link_child(sim,key,[parent.key]),"A newborn links to an actual adult parent")
	return sim.get_individual(key)
func run():
	marriage_news()
	families_and_lifecycle()
	bargains_and_laws()
	justice_and_rebellion()
	format_and_target_rules()
	work_profiles_and_caches()
	ancestral_history()
	print("Living society: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
func marriage_news():
	for royal in [false,true]:
		var sim=world("Marriage news")
		var town=sim.state.settlements[0]
		var pair=[]
		for key in sim._society.roster(sim,int(town.id)):
			var a=sim.get_individual(key)
			if (a.role=="ruler")!=royal or a.age<18: continue
			for other in sim._society.roster(sim,int(town.id)):
				var b=sim.get_individual(other)
				if not royal and sim._society.is_royal(sim,b): continue
				if sim._society.compatible(sim,a,b): pair=[a,b]; break
			if not pair.is_empty(): break
		check(pair.size()==2,"A compatible marriage fixture exists")
		if pair.is_empty(): continue
		for person in pair: sim._society.edit_life(sim,person.key).spouse=""
		var before=sim.state.events.size()
		check(sim._society.marry(sim,pair[0],pair[1]),"The marriage succeeds")
		check(sim._society.life(sim,pair[0].key).spouse==pair[1].key and sim._society.life(sim,pair[1].key).spouse==pair[0].key,"Both spouses retain their marriage")
		if royal:
			check(sim.state.events.back().kind=="royal_wedding" and ("Person: "+pair[0].key) in sim.state.events.back().causes,"Royal weddings link to the actual royal participant")
			var child=new_child(sim,pair[0])
			check(sim._society.is_royal(sim,child),"Children of rulers also belong to the royal family")
		else: check(sim.state.events.size()==before,"Ordinary marriages do not flood global news")
func families_and_lifecycle():
	var sim=world("Families and generations")
	var town=sim.state.settlements[0]
	var married=0
	for key in sim._society.roster(sim,int(town.id)):
		var p=sim.get_individual(key)
		check(p.has("honor") and p.has("gender") and p.has("orientation") and p.has("contribution"),"Each person has a life and contribution")
		if p.age<18: check(p.role=="child" and p.orientation=="Undeclared","Children have age-appropriate profiles")
		if p.marital_status=="Married":
			married+=1
			var spouse=sim.get_individual(p.spouse)
			check(spouse.spouse==key and sim._society.compatible(sim,p,spouse),"Marriages are reciprocal, adult, compatible and unrelated")
	check(married>0,"Founding adults form real households")
	var leader=sim.get_individual("p:%d"%int(town.leader))
	var child=new_child(sim,leader)
	check(child.key in sim.get_individual(leader.key).children,"Parent's children list includes the newborn")
	var child_key=child.key
	var destination=sim.state.settlements[1]
	var before=sim.state.stats.population
	sim._citizens.transfer(sim,int(town.id),int(destination.id),1)
	town.population-=1; destination.population+=1
	sim.refresh_totals()
	check(sim.get_individual(child_key).settlement==destination.id and sim.get_individual(child_key).parents==[leader.key],"A migrating child retains their original family")
	var birth_count=int(sim.state.citizens.next_id)
	sim.step(24)
	child=sim.get_individual(child_key)
	check(not child.alive or (child.age==24 and child.role!="child"),"A survivor grows into adult work")
	var natural_births=0
	for id in range(birth_count,int(sim.state.citizens.next_id)):
		var p=sim.get_individual("c:%d"%id)
		if p.family_origin=="Born to this family": natural_births+=1; check(not p.parents.is_empty(),"A new generation records its parents")
	check(natural_births>0,"New generations are born during ordinary simulation")
	var valid=Saves.validate_state(sim.state)
	check(valid.ok,"Family save validates: "+valid.message)
	# Orbit uses the same lifetime rules even after the surface is gone.
	var orbital=world("Orbital families")
	var ot=orbital.state.settlements[0]
	var elder=orbital.get_individual("p:%d"%int(ot.leader))
	orbital.state.citizens.overrides[elder.key].born=-130
	orbital._citizens.transfer(orbital,int(ot.id),int(ot.id),floori(ot.population),"surface","orbit")
	ot.orbital_population=floori(ot.population); ot.population=0
	orbital._society.annual(orbital)
	check(not orbital.get_individual(elder.key).alive,"Orbital residents also age and die")
func bargains_and_laws():
	var sim=world("The cost of a cure")
	var town=sim.state.settlements[0]
	var ruler=sim.get_individual("p:%d"%int(town.leader))
	sim._society.adjust(sim,ruler.key,{"honor":1})
	var child=new_child(sim,ruler)
	sim._society.edit_life(sim,child.key).illness="Fever"
	sim._society.edit_life(sim,child.key).sick_until=8
	var snapshot=JSON.stringify(sim.state)
	var preview=powers.preview_person(sim,"promise_mercy",ruler.key,"god")
	check(preview.ok and child.name in preview.consequence,"The bargain names the actual sick child")
	check(snapshot==JSON.stringify(sim.state),"Reading a bargain preview changes nothing")
	check(powers.apply_to_person(sim,"promise_mercy",ruler.key,"god").ok,"The ruler accepts a family bargain")
	check(not powers.apply_to_person(sim,"promise_mercy",ruler.key,"god").ok,"Duplicate pending bargains are rejected")
	check(sim.state.society.promises.back().status=="pending","A promise awaits the separate cure")
	check(powers.apply_to_person(sim,"heal_person",child.key,"god").ok,"Healing targets the child")
	check(sim.get_individual(child.key).illness.is_empty(),"Healing cures the selected person's illness")
	check(sim.state.society.promises.back().status=="fulfilled","An honorable parent keeps the promise")
	check(sim.state.society.laws.any(func(law):return law.kind=="relief" and law.actor==ruler.key),"The cure produces an actual law from the parent official")
	var food=town.food; var wealth=town.wealth; var happiness=town.happiness
	sim._society.civic._apply_laws(sim,sim._society,town)
	check(town.food>food and town.wealth<wealth and town.happiness>happiness,"Relief changes food, treasury and public happiness")
	var law_count=sim.state.society.laws.size()
	powers.apply_to_person(sim,"bribe_person",ruler.key,"devil")
	check(sim.state.society.laws.size()==law_count,"An honorable ruler refuses a corrupt law")
	sim._society.adjust(sim,ruler.key,{"honor":-2})
	powers.apply_to_person(sim,"bribe_person",ruler.key,"devil")
	check(sim.state.society.laws.any(func(law):return law.kind=="guild_privileges"),"A dishonest official passes the purchased law")
	var merchants=sim.role_keys(int(town.id),"merchant",1)
	if not merchants.is_empty():
		var merchant=sim.get_individual(merchants[0]); sim._society.civic._apply_laws(sim,sim._society,town)
		check(sim.get_individual(merchant.key).wealth>merchant.wealth,"A favored merchant personally receives the policy benefit")
	sim._society.edit_life(sim,child.key).illness="Fever"; sim._society.edit_life(sim,child.key).sick_until=8
	powers.apply_to_person(sim,"promise_cruelty",ruler.key,"devil")
	powers.apply_to_person(sim,"infernal_cure",child.key,"devil")
	check(sim.state.society.promises.back().status=="broken","A dishonorable official can break the bargain after receiving a cure")
	sim._society.adjust(sim,ruler.key,{"honor":2})
	sim._society.edit_life(sim,child.key).illness="Fever"; sim._society.edit_life(sim,child.key).sick_until=8
	powers.apply_to_person(sim,"promise_cruelty",ruler.key,"devil"); powers.apply_to_person(sim,"infernal_cure",child.key,"devil")
	check(sim.state.society.laws.any(func(law):return law.kind=="repression"),"A kept dark bargain imposes actual repression")
	var valid=Saves.validate_state(sim.state); check(valid.ok,"Bargains and laws validate: "+valid.message)
func justice_and_rebellion():
	var sim=world("Crime and civil war")
	var town=sim.state.settlements[0]
	var actor=sim.get_individual(sim.role_keys(int(town.id),"guard",1)[0])
	var crime=sim._society.civic._crime(sim,sim._society,town,actor,false)
	check(not crime.is_empty() and crime.actor==actor.key and crime.victim!=actor.key,"A theft has a real perpetrator and victim")
	powers.apply_to_person(sim,"reveal_person",actor.key,"god")
	check(crime.status=="reported","Revelation exposes the recorded hidden crime")
	for year in range(1,18):
		sim.state.year=year; town.social_security=1.0
		sim._society.civic._investigate(sim,sim._society,town)
		if crime.status=="convicted": break
	check(crime.status=="convicted" and sim.get_individual(actor.key).imprisoned,"Investigation can convict and imprison the culprit")
	check(sim.get_individual(actor.key).contribution.get("security",0)==0,"An imprisoned guard cannot keep working")
	var resentment=sim.get_individual(crime.victim).resentment
	powers.apply_to_person(sim,"pardon_person",actor.key,"god")
	check(not sim.get_individual(actor.key).imprisoned and crime.status=="pardoned","Pardons release the actual prisoner and close the offense")
	check(sim.get_individual(crime.victim).resentment>=resentment,"The victim reacts to a pardon")
	sim.state.year+=5
	var murder=sim._society.civic._crime(sim,sim._society,town,sim.get_individual(actor.key),true)
	check(not murder.is_empty() and not sim.get_individual(murder.victim).alive,"Murder ends the victim's actual persistent life")
	check(sim.get_individual(murder.victim).death_cause.begins_with("Murdered"),"The victim's history identifies the cause of death")
	var leader=sim.get_individual("p:%d"%int(town.leader))
	# If the crime killed a ruler, install an adult successor before the movement.
	if not leader.alive: sim._people_year(); leader=sim.get_individual("p:%d"%int(town.leader))
	sim._society.adjust(sim,leader.key,{"honor":-1})
	sim._society.edit_life(sim,leader.key).exposed=true
	sim._society.edit_life(sim,leader.key).possessed_until=int(sim.state.year)+100
	town.unrest=1.0; town.fear=0.9; town.happiness=0.15; town.last_revolt=-100
	sim.state.settlements[1].nation=int(town.nation)
	var organizer=sim.get_individual(sim.role_keys(int(town.id),"politician",1)[0])
	sim._society.adjust(sim,organizer.key,{"honor":1,"courage":1,"resentment":1})
	sim.state.society.movements=[{"town":int(town.id),"organizer":organizer.key,"target":leader.key,"support":0.8,"status":"organizing","started":0}]
	sim._society.civic._opposition(sim,sim._society,town,[sim.get_individual(organizer.key)])
	check(sim.get_individual("p:%d"%int(town.leader)).key==organizer.key,"The named organizer becomes ruler without inventing another person")
	check(sim.get_individual(leader.key).role=="deposed ruler" and sim.get_individual(leader.key).imprisoned,"The previous ruler is deposed and imprisoned")
	check(sim.state.wars.size()>0 and "Civil war" in sim.state.wars.back().reason,"A divided realm produces an actual simulated civil war")
	sim.refresh_totals()
	var valid=Saves.validate_state(sim.state); check(valid.ok,"Justice and revolution save validates: "+valid.message)
func format_and_target_rules():
	var sim=world("Society validation")
	var town=sim.state.settlements[0]
	var before=JSON.stringify(sim.state)
	for power in Powers.PERSON_TARGETS:
		check(not powers.apply(sim,power,int(town.x),int(town.y)).ok,"A personal power cannot be cast as a town brush: "+power)
	check(before==JSON.stringify(sim.state),"Rejected map uses do not mutate or charge the world")
	var leader=sim.get_individual("p:%d"%int(town.leader))
	var child=new_child(sim,leader)
	var malformed=sim.state.duplicate(true)
	malformed.citizens.overrides[child.key].life.parents=[child.key]
	check(not Saves.validate_state(malformed).ok,"Malformed family cycles are rejected")
	malformed=sim.state.duplicate(true)
	malformed.citizens.overrides[child.key].life.parents=["c:99999999"]
	check(not Saves.validate_state(malformed).ok,"Unissued relatives are rejected")
	malformed=sim.state.duplicate(true)
	malformed.society.promises=[{"id":1,"actor":leader.key,"patient":child.key,"town":int(town.id),"side":"god","status":"impossible","since":0,"deadline":8,"resolved":-1,"outcome":""}]
	malformed.society.next_id=2
	check(not Saves.validate_state(malformed).ok,"Unknown promise states are rejected")
	var legacy=sim.state.duplicate(true); legacy.erase("society")
	for record in legacy.citizens.overrides.values(): record.erase("life")
	var restored=Simulation.new(); restored.restore(legacy)
	check(Saves.validate_state(restored.state).ok and restored.get_individual(child.key).key==child.key,"An old save gains society without changing issued identities")

func work_profiles_and_caches():
	var sim=world("Work must match the visible person")
	var town=sim.state.settlements[0]
	var keys=sim._society.roster(sim,int(town.id)).duplicate()
	for pass_ in range(2):
		for i in range(keys.size()):
			var key=keys[i]
			if pass_==1:
				sim._society.adjust(sim,key,{"wisdom":0.27,"strength":-0.12,"health":0.42,"happiness":-0.18,"honor":0.1})
				var edit=sim.state.citizens.overrides[key]
				edit.role=["farmer","scholar","healer","guard","merchant","politician"][i%6]
				edit.traits=["curious","generous","merciful","aggressive","cautious","skeptical"]
				var record=sim._society.edit_life(sim,key)
				record.curse_until=8 if i%3==0 else 0
				record.illness="Fever"; record.sick_until=3 if i%2==0 else -1
				record.grief_until=4 if i%4==0 else 0
				record.prison_until=6 if i%5==0 else 0
			var shown=sim.get_individual(key)
			var actual=sim._society.work_person(sim,town,key)
			for field in ["health","happiness","wisdom","strength","honor","age"]:
				check(is_equal_approx(float(shown[field]),float(actual[field])),"Yearly work uses the displayed "+field+" after role, condition and stat changes")
			var work=sim._society.contribution(actual)
			for field in ["food","wealth","research","care","security"]:
				check(is_equal_approx(float(shown.contribution.get(field,0)),float(work.get(field,0))),"Actual "+field+" contribution matches the inspector")
	var snapshot=JSON.stringify(sim.state)
	for key in keys: sim._society.work_person(sim,town,key)
	check(snapshot==JSON.stringify(sim.state),"Work caches do not enter or mutate saved world state")
	var victim=keys[0]
	sim.kill_individual(victim,"Cache regression")
	check(victim not in sim._society.roster(sim,int(town.id)),"A death immediately invalidates the cached roster")
	check(not sim._society._work_cache.has(victim),"A dead resident releases their work cache")

func ancestral_history():
	var sim=world("Ancestral memory")
	var parent=sim.get_individual("p:%d"%int(sim.state.settlements[0].leader))
	var child=new_child(sim,parent)
	powers.apply_to_person(sim,"heal_person",parent.key,"god")
	sim.kill_individual(parent.key,"Died during the memory fixture")
	sim.state.year=100
	var before=sim.get_individual(parent.key)
	sim._society.condense_ancestral_history(sim)
	var after=sim.get_individual(parent.key)
	for field in ["age","gender","orientation","role","honor","crimes","good_deeds","kills","death_cause","children","parents","spouse"]:
		check(before[field]==after[field],"Condensed ancestry preserves "+field)
	check(parent.key in sim.get_individual(child.key).parents and child.key in after.children,"Generations remain navigable after history condensation")
	check(after.history.any(func(event):return "Heal" in str(event.title)),"Major direct interventions remain in ancestral history")
	var snapshot=JSON.stringify(sim.state)
	sim._society.condense_ancestral_history(sim)
	check(snapshot==JSON.stringify(sim.state),"Repeated ancestral compaction is stable")
	check(Saves.validate_state(sim.state).ok,"Condensed ancestry passes the complete save schema")
