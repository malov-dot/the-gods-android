extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Saves=preload("res://scripts/save_manager.gd")
var checks=0
var failures=0
func _init(): call_deferred("run")
func check(value,label):
	checks+=1
	if not value: failures+=1; push_error("CITIZENS: "+label)
func everyone(sim):
	var result={}
	for town in sim.state.settlements:
		var total=sim.resident_page(town.id).total
		for offset in range(0,total,60):
			for person in sim.resident_page(town.id,offset,60).people:result[person.key]=person
	return result
func run():
	var sim=Simulation.new()
	sim.new_world({"seed":"acceptance-2026","width":80,"height":55,"nations":4})
	var town=sim.state.settlements[0]
	var page=sim.resident_page(town.id,0,24)
	check(page.total==floori(town.population),"Every whole resident is in directory")
	check(page.people.size()==24,"Directory is paginated")
	var first=page.people[0]
	var snapshot=JSON.stringify(sim.state)
	var again=sim.get_individual(first.key)
	var visible=sim.individual_keys(town.id,24,first.key)
	var faction=sim.faction_summary(town.nation)
	check(first==again and first.key in visible,"Identity is stable and selectable")
	check(JSON.stringify(sim.state)==snapshot,"All read APIs are state immutable")
	check(faction.leaders.size()>0,"Faction contains its actual ruler")
	var ruler=sim.get_individual("p:%d"%town.leader)
	check(ruler.alive and ruler.role=="ruler","Leader occupies an actual living resident slot")
	var a=sim.preview_person_influence(first.key,"bless_person","god")
	var b=sim.preview_person_influence(ruler.key,"bless_person","god")
	check(b.community.faith>a.community.faith,"Established ruler has wider faith influence than ordinary resident")
	check(not sim.apply_person_influence("c:999999999","bless_person","god").ok,"Unknown identity cannot be influenced")
	check(JSON.stringify(sim.state)==snapshot,"Rejected action leaves state untouched")
	check(sim.apply_person_influence(ruler.key,"bless_person","god").ok,"Personal intervention succeeds")
	check(sim.get_individual(ruler.key).faith>ruler.faith,"Personal belief changes persist")
	check(sim.get_individual(ruler.key).history.size()>0,"Personal intervention records history")
	var valid=Saves.validate_state(sim.state)
	check(valid.ok,"Registry save validation: "+str(valid.get("message","")))
	# Deterministic continuation includes identity selection and all compact records.
	sim.step(120)
	var restored=Simulation.new()
	restored.restore(JSON.parse_string(JSON.stringify(sim.state)))
	for field in sim.state.citizens:
		if JSON.stringify(sim.state.citizens[field])!=JSON.stringify(restored.state.citizens[field]): print("REGISTRY DIFFERENCE ",field," ",JSON.stringify(sim.state.citizens[field]).left(180)," / ",JSON.stringify(restored.state.citizens[field]).left(180))
		if field=="overrides":
			for key in sim.state.citizens.overrides:
				if JSON.stringify(sim.state.citizens.overrides[key])!=JSON.stringify(restored.state.citizens.overrides.get(key,{})):
					print("FIRST RESIDENT DIFFERENCE ",key," ",JSON.stringify(sim.state.citizens.overrides[key])," / ",JSON.stringify(restored.state.citizens.overrides.get(key,{})))
					break
	check(JSON.stringify(sim.state.citizens)==JSON.stringify(restored.state.citizens),"Restoring does not modify an existing registry")
	for year in range(40):
		sim.step(1)
		restored.step(1)
		if absf(sim.state.stats.population-restored.state.stats.population)>0.00001 or sim.state.rng_state!=restored.state.rng_state:
			print("DIVERGENCE year ",sim.state.year," populations ",sim.state.stats.population," / ",restored.state.stats.population)
			for i in range(sim.state.people.size()):
				if i>=restored.state.people.size() or JSON.stringify(sim.state.people[i])!=JSON.stringify(restored.state.people[i]):
					print("PERSON ",sim.state.people[i]," / ",restored.state.people[i] if i<restored.state.people.size() else {})
					break
			break
	check(absf(sim.state.stats.population-restored.state.stats.population)<0.00001,"Save continuation preserves population")
	check(sim.state.rng_state==restored.state.rng_state,"Save continuation preserves random sequence")
	check(JSON.stringify(sim.state.citizens)==JSON.stringify(restored.state.citizens),"Save continuation preserves identity records")
	# Actual settlement migration and colony creation conserve all existing identities.
	var migration=Simulation.new()
	migration.new_world({"seed":"Citizen movements","width":80,"height":55,"nations":2})
	var origin=migration.state.settlements[0]
	var destination=migration.state.settlements[1]
	destination.x=origin.x+12 if origin.x<40 else origin.x-12
	destination.y=origin.y
	for city in migration.state.settlements:city.food=10000.0;city.era=7
	origin.shortage=3
	origin.happiness=0.20
	var before=everyone(migration)
	var next_id=int(migration.state.citizens.next_id)
	migration._migrate(origin)
	migration.refresh_totals()
	var after=everyone(migration)
	var relocated=0
	for key in before:
		if after.has(key) and before[key].settlement!=after[key].settlement:
			relocated+=1
			check(before[key].name==after[key].name and before[key].age==after[key].age,"Migration preserves name and age")
	check(before.keys().all(func(key):return after.has(key)) and before.size()==after.size(),"Migration preserves every resident identity")
	check(relocated>0 and int(migration.state.citizens.next_id)==next_id,"Migration moves people without inventing replacements")
	for tile in migration.state.tiles:tile.elevation=0.5;tile.fertility=0.8;tile.temperature=0.5;tile.moisture=0.5
	migration.state.terrain_revision+=1
	origin.last_expansion=-100
	before=everyone(migration)
	var town_count=migration.state.settlements.size()
	migration._try_expand(origin,100.0)
	migration.refresh_totals()
	after=everyone(migration)
	check(migration.state.settlements.size()==town_count+1,"The actual expansion path creates a colony")
	check(before.size()==after.size() and before.keys().all(func(key):return after.has(key)),"Founding a colony preserves colonists instead of making new people")
	# Orbital movement preserves IDs and location and keeps orbit residents off streets.
	var surface_before=migration.resident_page(origin.id,0,60).people
	origin.population-=5
	origin.orbital_population=5
	migration._citizens.transfer(migration,origin.id,origin.id,5,"surface","orbit")
	migration.refresh_totals()
	var orbit=migration.resident_page(origin.id,0,60).people.filter(func(person):return person.location=="orbit")
	# The orbit entries follow surface entries, so read their own final page too.
	var whole=migration.resident_page(origin.id).total
	orbit=migration.resident_page(origin.id,maxi(0,whole-5),5).people
	check(orbit.size()==5 and orbit.all(func(person):return person.location=="orbit"),"Every orbital resident is accessible in the directory")
	var street=migration.individual_keys(origin.id,40)
	check(orbit.all(func(person):return person.key not in street),"Orbital people never appear as surface citizens")
	# Mortality removes actual people; later population creation never reuses their IDs.
	var victims=migration.resident_page(origin.id,0,5).people
	origin.population-=5.0
	migration.record_deaths(origin,5.0)
	migration.refresh_totals()
	check(victims.all(func(person):return not migration.get_individual(person.key).alive),"Recorded mortality removes the corresponding living identities")
	var dead_age=migration.get_individual(victims[0].key).age
	migration.state.year+=3
	check(migration.get_individual(victims[0].key).age==dead_age,"A deceased person's age remains fixed")
	origin.population+=5.0
	migration.refresh_totals()
	check(victims.all(func(person):return not migration.get_individual(person.key).alive),"New arrivals never resurrect or reuse an old identity")
	check(not migration.apply_person_influence(victims[0].key,"heal_person","god").ok,"Personal healing cannot target deceased residents")
	check(migration.get_individual("c:01").is_empty(),"Noncanonical identifiers cannot create duplicate identities")
	var migrated_save=Saves.validate_state(migration.state)
	check(migrated_save.ok,"Migration, colony, orbit and mortality remain saveable: "+str(migrated_save.get("message","")))
	# Timed influence changes the actual community and ends on its promised year.
	var influence=Simulation.new()
	influence.new_world({"seed":"Personal consequences","width":64,"height":48,"nations":2})
	var community=influence.state.settlements[0]
	var leader_key="p:%d"%int(community.leader)
	var forecast=influence.preview_person_influence(leader_key,"bless_person","god")
	var original_faith=float(community.faith)
	influence.apply_person_influence(leader_key,"bless_person","god")
	for year in range(1,13):influence.state.year=year;influence._citizens.annual(influence)
	check(is_equal_approx(float(community.faith),original_faith+12.0*float(forecast.community.faith)),"Role-weighted annual consequences match their preview for all twelve years")
	var ended_faith=float(community.faith)
	influence.state.year=13
	influence._citizens.annual(influence)
	check(is_equal_approx(community.faith,ended_faith),"Expired influence stops changing the community")
	check(influence.preview_person_influence(leader_key,"incite_person","god").ok==false,"Simulation rejects the wrong deity without relying on UI")
	var guards=influence.role_keys(community.id,"guard",4)
	check(guards.all(func(key):return influence.get_individual(key).role=="guard"),"Efficient role samples only contain real matching residents")
	# Large populations stay compact, and even the final resident page resolves quickly.
	var large=Simulation.new()
	large.new_world({"seed":"Compact population","width":64,"height":48,"nations":2})
	for city in large.state.settlements:city.population=68500.0;city.food=1000000.0
	large.refresh_totals()
	var big_town=large.state.settlements[0]
	var began=Time.get_ticks_msec()
	var last=large.resident_page(big_town.id,68476,24)
	check(last.people.size()==24 and last.total==68500,"The final page of a 68,500-resident community is complete")
	check(Time.get_ticks_msec()-began<1000,"Large directory pagination does not enumerate every resident")
	began=Time.get_ticks_msec()
	var search=large.resident_page(big_town.id,0,24,"healer")
	var search_ms=Time.get_ticks_msec()-began
	check(search.total>0 and search.people.all(func(person):return person.role=="healer"),"Large-population role searches return actual matching people")
	check(search_ms<2000,"Large directory searches avoid expensive full-profile generation")
	print("137k roster: ",JSON.stringify(large.state.citizens).length()," bytes; 68.5k person search ",search_ms," ms")
	check(JSON.stringify(large.state.citizens).length()<100000,"137,000 live identities use compact cohort storage")
	check(Saves.validate_state(large.state).ok,"Large compact rosters satisfy save bounds")
	var old=large.state.duplicate(true)
	old.erase("citizens")
	var upgraded=Simulation.new()
	upgraded.restore(old)
	check(upgraded.resident_page(big_town.id).total==68500,"An old save gains complete resident coverage during restore")
	check(Saves.validate_state(upgraded.state).ok,"Upgraded old saves remain valid")
	var tiny=Simulation.new()
	tiny.new_world({"seed":"Last habitat resident","width":64,"height":48,"nations":2})
	var habitat=tiny.state.settlements[0]
	habitat.population=1.0
	tiny.refresh_totals()
	tiny._people_year()
	var survivor=tiny.get_individual("p:%d"%int(habitat.leader))
	var prior=tiny.get_person(int(habitat.leader))
	prior.role="prophet"
	tiny.state.citizens.overrides[survivor.key].role="prophet"
	habitat.leader=-1
	habitat.population=0.0
	habitat.orbital_population=1.0
	tiny._citizens.transfer(tiny,habitat.id,habitat.id,1,"surface","orbit")
	tiny._people_year()
	check(tiny.get_individual("p:%d"%int(habitat.leader)).key==survivor.key,"An already titled sole survivor takes office without creating another identity")
	check(tiny.state.people.filter(func(person):return person.alive and person.settlement==habitat.id).size()==1,"A one-person habitat never gains ghost leaders")
	_test_membership_updates()
	print("Citizens: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

func _test_membership_updates():
	var sim=Simulation.new(); sim.new_world({"seed":"Resident lookup after household moves","width":64,"height":48,"nations":2})
	var origin=sim.state.settlements[0]; var destination=sim.state.settlements[1]
	var first=int(sim.state.citizens.next_id)
	sim.resident_page(origin.id) # Start with a populated lookup.
	origin.population+=7; sim._citizens.add(sim,origin.id,7)
	for n in range(7):
		var newborn=sim.get_individual("c:%d"%(first+n))
		check(newborn.alive and newborn.age==0 and newborn.settlement==origin.id,"A new child is immediately inspectable in the correct community")
	sim._citizens.transfer(sim,origin.id,destination.id,4); origin.population-=4; destination.population+=4
	for n in range(3,7): check(sim.get_individual("c:%d"%(first+n)).settlement==destination.id,"A partial birth cohort moves without changing identities")
	sim._citizens.transfer(sim,destination.id,destination.id,2,"surface","orbit"); destination.population-=2; destination.orbital_population+=2
	for n in range(5,7): check(sim.get_individual("c:%d"%(first+n)).location=="orbit","Orbital migration updates the selected person's location immediately")
	check(sim.kill_individual("c:%d"%(first+4),"Membership acceptance fixture"),"An individual can die between two surviving resident ranges")
	sim._citizens.transfer(sim,destination.id,origin.id,1); destination.population-=1; origin.population+=1
	sim._citizens.transfer(sim,destination.id,origin.id,2,"orbit","surface"); destination.orbital_population-=2; origin.population+=2
	for n in [0,1,2,3,5,6]:
		var returned=sim.get_individual("c:%d"%(first+n))
		check(returned.alive and returned.settlement==origin.id and returned.location=="surface","Returning residents join adjacent ranges without losing or reviving a person")
	check(not sim.get_individual("c:%d"%(first+4)).alive,"A deceased identity stays deceased when both neighboring households return")
	check(Saves.validate_state(sim.state).ok,"Interleaved births, partial migrations and an individual death remain saveable")
