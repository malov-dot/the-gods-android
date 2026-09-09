extends RefCounted
## Personal state is sparse; original resident identities and birth cohorts remain
## authoritative. Families link real IDs, including relatives who have died.
const Civic = preload("res://scripts/civic_story.gd")
const Projects = preload("res://scripts/personal_projects.gd")
const ADULT = 18
const PERSONAL_ACTIONS = ["curse_person","possess_person","purify_person","bribe_person","pardon_person","reveal_person","comfort_person","teach_person","promise_mercy","promise_cruelty","infernal_cure"]
var civic=Civic.new()
var _rosters={}
var _roster_revision=-1
var _ready=false
var _work_cache={}
var _archive_pending={}

func initialize(sim):
	var fresh=not sim.state.has("society")
	if fresh: sim.state.society={"version":1,"initialized":false,"laws":[],"crimes":[],"promises":[],"movements":[],"next_id":1}
	for field in ["version","next_id"]: sim.state.society[field]=int(sim.state.society[field])
	for group in ["laws","crimes","promises","movements"]:
		for record in sim.state.society[group]:
			for field in ["id","town","since","until","year","resolved","deadline","started"]:
				if record.has(field): record[field]=int(record[field])
	_archive_pending.clear()
	for key in sim.state.citizens.overrides:
		var override=sim.state.citizens.overrides[key]
		if not override.has("life"): continue
		if override.life.get("death_noted",false) and not override.life.get("memory_archived",false): _archive_pending[key]=true
		for field in ["married_year","last_birth","sick_until","curse_until","possessed_until","prison_until","grief_until","crimes","good_deeds","kills","last_deed","last_crime","revived_until","estate_age"]:
			if override.life.has(field): override.life[field]=int(override.life[field])
		if override.life.has("project"):
			for field in ["started","deadline","finished"]: override.life.project[field]=int(override.life.project[field])
	_ready=true
	_roster_revision=-1
	_work_cache.clear()
	if not sim.state.society.get("initialized",false) and not sim.state.settlements.is_empty():
		for town in sim.state.settlements:
			var people=roster(sim,int(town.id))
			form_families(sim,town,people,true)
			form_families(sim,town,roster(sim,int(town.id),"orbit"),true)
			civic.ensure_council(sim,town,people)
		sim.state.society.initialized=true

func base(sim,key): return sim._citizens.get_person(sim,str(key),false,false)
func identity(sim,key): return sim._citizens.get_person(sim,str(key),false,false,true)
func canonical(sim,key): return str(sim.state.citizens.named.get(str(key),str(key)))
func life(sim,key)->Dictionary:
	return sim.state.citizens.overrides.get(canonical(sim,key),{}).get("life",{})
func edit_life(sim,key)->Dictionary:
	key=canonical(sim,key)
	if not sim.state.citizens.overrides.has(key): sim.state.citizens.overrides[key]={}
	var record=sim.state.citizens.overrides[key]
	if not record.has("life"): record.life={}
	return record.life
func remember(sim,key,title_,detail):
	key=canonical(sim,key)
	if not sim.state.citizens.overrides.has(key): sim.state.citizens.overrides[key]={}
	var record=sim.state.citizens.overrides[key]
	var history=record.get("history",[])
	history.append({"year":int(sim.state.year),"title":title_,"detail":detail})
	record.history=history.slice(maxi(0,history.size()-24))
func adjust(sim,key,changes):
	key=canonical(sim,key)
	if not sim.state.citizens.overrides.has(key): sim.state.citizens.overrides[key]={}
	var record=sim.state.citizens.overrides[key]
	if not record.has("stats"): record.stats={}
	for field in changes: record.stats[field]=roundf(clampf(float(record.stats.get(field,0))+float(changes[field]),-1,1)*1000000.0)/1000000.0
	sim._citizens._changed(sim,false)

func roster(sim,town_id,location="surface")->Array:
	# Only births, deaths and moves change these IDs. Personal moods, laws and
	# reputation can change thousands of times without rebuilding town rosters.
	var revision=int(sim._citizens.membership_revision)
	if _roster_revision!=revision:
		_rosters.clear()
		_roster_revision=revision
	var token="%d:%s"%[town_id,location]
	if not _rosters.has(token):
		var keys=[]
		for segment in sim.state.citizens.residents.get(str(town_id),{}).get(location,[]):
			for id in range(int(segment[0]),int(segment[0])+int(segment[1])): keys.append("c:%d"%id)
		_rosters[token]=keys
	return _rosters[token]

func gender(key)->String:
	var pick=_hash(key,191)%100
	return "Woman" if pick<48 else ("Man" if pick<96 else "Nonbinary")
func orientation(key)->String:
	var pick=_hash(key,277)%100
	return "Straight" if pick<82 else ("Gay" if pick<90 else ("Bisexual" if pick<98 else "Asexual"))
func character(sim,key,field)->float:
	var record=sim.state.citizens.overrides.get(canonical(sim,key),{})
	return clampf(0.08+float(_hash(key,str(field).hash())%850)/1000.0+float(record.get("stats",{}).get(field,0)),0,1)
func _hash(key,salt)->int: return absi((str(key).hash()*92837111)^int(salt)*689287499)%2147483647

func enrich(sim,person,include_promises=true):
	var key=str(person.key)
	var record=life(sim,key)
	person.gender=gender(key)
	person.orientation=orientation(key) if int(person.age)>=ADULT else "Undeclared"
	person.life_stage="Child" if person.age<13 else ("Adolescent" if person.age<ADULT else ("Elder" if person.age>=65 else "Adult"))
	for field in ["honor","empathy","courage","resentment"]: person[field]=character(sim,key,field)
	person.parents=record.get("parents",[]).duplicate()
	person.children=record.get("children",[]).duplicate()
	person.spouse=str(record.get("spouse",""))
	person.married_year=int(record.get("married_year",-1))
	person.marital_status="Single"
	if not person.spouse.is_empty(): person.marital_status="Married" if sim._citizens.status(sim,person.spouse).get("alive",false) else "Widowed"
	person.family_origin=record.get("family_origin","Unrecorded ancestry")
	person.illness=str(record.get("illness","")) if int(record.get("sick_until",0))>=int(sim.state.year) else ""
	person.cursed=int(record.get("curse_until",0))>int(sim.state.year)
	person.possessed=int(record.get("possessed_until",0))>int(sim.state.year)
	person.imprisoned=int(record.get("prison_until",0))>int(sim.state.year)
	person.grieving=int(record.get("grief_until",0))>int(sim.state.year)
	person.wanted=bool(record.get("wanted",false))
	person.crimes=int(record.get("crimes",0))
	person.good_deeds=int(record.get("good_deeds",0))
	person.kills=int(record.get("kills",0))
	person.wealth=maxf(0,float(record.get("money",0))+maxi(0,int(person.age)-ADULT)*(0.7 if person.role in ["merchant","ruler","politician"] else 0.25))
	person.death_cause=str(record.get("death_cause","Population loss, illness, or old age")) if not person.alive else ""
	if not person.illness.is_empty(): person.health=clampf(person.health-0.42,0,1)
	if person.cursed: person.health=clampf(person.health-0.27,0,1); person.happiness=clampf(person.happiness-0.22,0,1)
	if person.grieving: person.happiness=clampf(person.happiness-0.20,0,1)
	if person.imprisoned: person.influence*=0.25
	if person.possessed: person.corruption=maxf(0.85,person.corruption); person.faith=minf(person.faith,0.15)
	person.character="Honorable" if person.honor>=0.7 else ("Dishonorable" if person.honor<=0.3 else "Conflicted")
	person.contribution=contribution(person)
	person.project=record.get("project",{}).duplicate(true)
	if not person.project.is_empty(): person.goal=Projects.description(person,person.project)
	person.promises=[]
	if include_promises:
		for promise in sim.state.society.promises:
			if promise.actor==key or promise.patient==key: person.promises.append(promise.duplicate(true))
	return person

func contribution(person)->Dictionary:
	if not person.alive: return {"activity":"Remembered by family and community"}
	if person.age<ADULT: return {"activity":"Learning and receiving household care"}
	if person.imprisoned: return {"activity":"Imprisoned; unable to work or hold office"}
	var effort=clampf(person.health*(0.55+person.happiness*0.45),0.05,1.0)
	if person.age>=70: effort*=0.6
	var result={"activity":str(person.role).capitalize(),"food":0.0,"wealth":0.0,"research":0.0,"care":0.0,"security":0.0}
	match person.role:
		"farmer": result.food=0.35*effort*(0.5+person.wisdom)
		"worker","artisan": result.wealth=0.025*effort*(0.5+person.strength)
		"merchant": result.wealth=0.05*effort*(0.5+person.wisdom)
		"scholar": result.research=0.09*effort*(0.5+person.wisdom)
		"healer": result.care=effort*(0.5+person.wisdom)
		"guard": result.security=effort*(0.5+person.strength)
		_: result.wealth=0.012*effort
	return result

func work_person(sim,town,key)->Dictionary:
	# Annual work needs a few changing values, not an entire inspector/family
	# model. Cache immutable birth/aptitude data and read live edits every year.
	var edit=sim.state.citizens.overrides.get(key,{})
	if not _work_cache.has(key):
		var registry=sim._citizens
		var id=int(str(key).trim_prefix("c:"))
		var cohort=registry._find_range(sim.state.citizens.cohorts,id)
		var seed=registry._hash(id,int(cohort[4]))
		var raw={}
		for field in ["health","happiness","wisdom","strength"]: raw[field]=0.25+float(registry._hash(id,str(field).hash())%600)/1000.0
		_work_cache[key]={"born":int(cohort[2])-seed%maxi(1,int(cohort[5])),"role":registry.ROLES[seed%registry.ROLES.size()],"traits":[registry.Content.TRAITS[(seed/23)%registry.Content.TRAITS.size()]],"name":registry.Content.PERSON_NAMES[seed%registry.Content.PERSON_NAMES.size()]+" "+registry.SURNAMES[(seed/17)%registry.SURNAMES.size()],"raw":raw,"honor":0.08+float(_hash(key,"honor".hash())%850)/1000.0,"person":{"key":key,"alive":true}}
	var cached=_work_cache[key]
	var p=cached.person
	var record=edit.get("life",{})
	var stats=edit.get("stats",{})
	var traits=edit.get("traits",cached.traits)
	p.age=maxi(0,int(sim.state.year)-int(edit.get("born",cached.born)))
	p.role=str(edit.get("role",cached.role))
	if p.age<ADULT and not edit.has("role"): p.role="child"
	p.name=str(edit.get("name",cached.name))
	p.health=clampf(float(town.health)*0.8+cached.raw.health*0.2,0,1)
	p.happiness=clampf(float(town.happiness)*0.8+cached.raw.happiness*0.2,0,1)
	p.wisdom=maxf(cached.raw.wisdom,0.66) if p.role in ["scholar","healer","prophet"] else cached.raw.wisdom
	p.strength=maxf(cached.raw.strength,0.73) if p.role=="guard" else cached.raw.strength
	if p.age<ADULT: p.wisdom*=float(p.age+2)/20.0; p.strength*=float(p.age+2)/20.0
	if "curious" in traits: p.wisdom+=0.15
	if "skeptical" in traits: p.wisdom+=0.08
	if "aggressive" in traits: p.strength+=0.10
	if "generous" in traits: p.happiness+=0.10
	if "merciful" in traits: p.health+=0.07
	if "cautious" in traits: p.health+=0.06
	for field in ["health","happiness","wisdom","strength"]: p[field]=clampf(p[field]+float(stats.get(field,0)),0,1)
	p.honor=clampf(cached.honor+float(stats.get("honor",0)),0,1)
	p.illness=str(record.get("illness","")) if int(record.get("sick_until",0))>=int(sim.state.year) else ""
	p.cursed=int(record.get("curse_until",0))>int(sim.state.year)
	p.possessed=int(record.get("possessed_until",0))>int(sim.state.year)
	p.imprisoned=int(record.get("prison_until",0))>int(sim.state.year)
	if not p.illness.is_empty(): p.health=clampf(p.health-0.42,0,1)
	if p.cursed: p.health=clampf(p.health-0.27,0,1); p.happiness=clampf(p.happiness-0.22,0,1)
	if int(record.get("grief_until",0))>int(sim.state.year): p.happiness=clampf(p.happiness-0.20,0,1)
	return p

func compatible(sim,a,b)->bool:
	if a.key==b.key or a.age<ADULT or b.age<ADULT or abs(a.age-b.age)>24: return false
	if not a.alive or not b.alive: return false
	var la=life(sim,a.key); var lb=life(sim,b.key)
	if b.key in la.get("parents",[]) or a.key in lb.get("parents",[]): return false
	for parent in la.get("parents",[]):
		if parent in lb.get("parents",[]): return false
	return _attracted(a.key,b.key) and _attracted(b.key,a.key)
func _attracted(a,b)->bool:
	match orientation(a):
		"Gay": return gender(a)==gender(b)
		"Straight": return gender(a)!=gender(b)
		_: return true

func is_royal(sim,person)->bool:
	if reigning(sim,person): return true
	for key in life(sim,person.key).get("parents",[]):
		if reigning(sim,identity(sim,key)): return true
	return false
func reigning(sim,person)->bool:
	if person.is_empty() or not person.get("alive",false): return false
	var town=sim.get_settlement(int(person.settlement))
	return not town.is_empty() and canonical(sim,"p:%d"%int(town.leader))==canonical(sim,str(person.key))
func marry(sim,a,b,initial=false)->bool:
	if not compatible(sim,a,b): return false
	for p in [a,b]:
		var spouse=str(life(sim,p.key).get("spouse",""))
		if not spouse.is_empty() and sim._citizens.status(sim,spouse).get("alive",false): return false
	var year=int(sim.state.year)-int((mini(a.age,b.age)-ADULT)/2) if initial else int(sim.state.year)
	for pair in [[a,b],[b,a]]:
		var record=edit_life(sim,pair[0].key)
		record.spouse=pair[1].key
		record.married_year=year
		remember(sim,pair[0].key,"Marriage","Married %s; their households and futures are joined."%pair[1].name)
	if not initial and (is_royal(sim,a) or is_royal(sim,b)):
		var town=sim.get_settlement(int(a.settlement))
		if not town.is_empty():
			sim.add_event("A royal wedding in "+town.name,"%s and %s marry, joining their households and the ruling family's future."%[a.name,b.name],"royal_wedding",int(town.x),int(town.y),["Person: "+a.key,"Person: "+b.key])
	return true

func link_child(sim,child_key,parent_keys,adopted=false)->bool:
	var child=identity(sim,child_key)
	if child.is_empty() or not life(sim,child_key).get("parents",[]).is_empty(): return false
	var valid=[]
	for key in parent_keys:
		var parent=identity(sim,key)
		if parent.is_empty() or int(parent.age)-int(child.age)<ADULT or key==child_key: return false
		valid.append(str(parent.key))
	if valid.is_empty() or valid.size()>2: return false
	var record=edit_life(sim,child_key)
	record.parents=valid
	record.family_origin="Adopted" if adopted else "Born to this family"
	for key in valid:
		var parent_record=edit_life(sim,key)
		if not parent_record.has("children"): parent_record.children=[]
		if child_key not in parent_record.children: parent_record.children.append(child_key)
		if not adopted: parent_record.last_birth=int(sim.state.year)
		remember(sim,key,"Family grows",("Adopted " if adopted else "Welcomed ")+child.name+" into the family.")
	var names=[]
	for key in valid: names.append(identity(sim,key).name)
	remember(sim,child_key,"A family",("Adopted into " if adopted else "Born into ")+"a household with "+" and ".join(names)+".")
	return true

func form_families(sim,town,keys,initial=false,yield_callback:Callable=Callable()):
	var epoch=sim.generation
	var processed=0
	var singles=[]; var children=[]
	for key in keys:
		processed+=1
		if yield_callback.is_valid() and processed%64==0:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		var p=identity(sim,key)
		if p.is_empty() or not p.alive: continue
		var record=life(sim,key)
		if p.age<ADULT:
			var living_parent=false
			for parent in record.get("parents",[]):
				if sim._citizens.status(sim,parent).get("alive",false): living_parent=true
			if not living_parent and record.get("parents",[]).is_empty(): children.append(p)
		elif p.age<66 and int(record.get("grief_until",0))<=int(sim.state.year):
			var spouse=str(record.get("spouse",""))
			if spouse.is_empty() or not sim._citizens.status(sim,spouse).get("alive",false): singles.append(p)
	var pairs=[]
	# A bounded local search preserves phone performance in large settlements.
	for i in range(singles.size()):
		if yield_callback.is_valid() and i%16==15:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		var a=singles[i]
		var current=str(life(sim,a.key).get("spouse",""))
		if not current.is_empty() and sim._citizens.status(sim,current).get("alive",false): continue
		if not initial and _hash(a.key,int(sim.state.year))%100>=18: continue
		for j in range(i+1,mini(singles.size(),i+33)):
			var b=singles[j]
			if marry(sim,a,b,initial): pairs.append([a,b]); break
	for child in children:
		processed+=1
		if yield_callback.is_valid() and processed%16==0:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		for pair in pairs:
			if life(sim,pair[0].key).get("children",[]).size()>=5: continue
			if mini(pair[0].age,pair[1].age)-child.age<ADULT: continue
			if link_child(sim,child.key,[pair[0].key,pair[1].key],true): break
	return true

func parents_for_birth(sim,town,location="surface",limit:int=-1)->Array:
	var eligible=[]
	if limit==0: return eligible
	for key in roster(sim,int(town.id),location):
		var record=life(sim,key)
		var spouse=str(record.get("spouse",""))
		if spouse.is_empty() or key>spouse: continue
		# A widow's deceased spouse must not trigger a full historical profile
		# lookup every birth season. Membership is indexed independently of history.
		if not sim._citizens.status(sim,spouse).get("alive",false): continue
		if int(sim.state.year)-int(record.get("last_birth",-10))<3 or record.get("children",[]).size()>=6: continue
		var a=identity(sim,key); var b=identity(sim,spouse)
		if a.is_empty() or b.is_empty() or not b.alive or b.settlement!=town.id or b.location!=location: continue
		if a.age<ADULT or b.age<ADULT or a.age>49 or b.age>55: continue
		if (gender(a.key)==gender(b.key) or "Woman" not in [gender(a.key),gender(b.key)]) and int(town.era)<10: continue
		eligible.append([a.key,b.key])
		if limit>0 and eligible.size()>=limit: break
	return eligible

func record_births(sim,town,first,amount,parents):
	for i in range(amount):
		if i>=parents.size(): break
		link_child(sim,"c:%d"%(first+i),parents[i])

func on_death(sim,key,cause="Death in the community"):
	if not _ready: return
	key=canonical(sim,key)
	_work_cache.erase(key)
	var record=life(sim,key)
	if record.get("death_noted",false): return
	# Keep full family consequences for connected/affected lives, while cohort
	# mortality stays compact for residents without a recorded personal event.
	var dead=identity(sim,key)
	var name=dead.get("name",key)
	var relatives=record.get("parents",[]).duplicate()+record.get("children",[]).duplicate()
	if not str(record.get("spouse","")).is_empty(): relatives.append(record.spouse)
	var heirs=[]
	for relative in record.get("children",[])+([record.spouse] if record.has("spouse") else []):
		if sim._citizens.status(sim,relative).get("alive",false) and relative not in heirs: heirs.append(relative)
	var estate_cents=maxi(0,roundi(float(record.get("money",0))*100)+maxi(0,int(dead.get("age",18))-int(record.get("estate_age",18)))*25)
	for i in range(heirs.size()):
		var heir=heirs[i]
		var share=int(estate_cents/heirs.size())+(1 if i<estate_cents%heirs.size() else 0)
		var inheritance=edit_life(sim,heir)
		inheritance.money=float(roundi(float(inheritance.get("money",0))*100)+share)/100.0
		remember(sim,heir,"Inheritance","Inherited %.2f wealth from %s."%[float(share)/100.0,name])
	for relative in relatives:
		if not sim._citizens.status(sim,relative).get("alive",false): continue
		var related=edit_life(sim,relative)
		related.grief_until=int(sim.state.year)+3
		adjust(sim,relative,{"resentment":0.12 if "murder" in cause.to_lower() else 0.02})
		remember(sim,relative,"Bereavement",name+" died. "+cause)
	var changed=edit_life(sim,key)
	changed.death_noted=true
	_archive_pending[key]=true
	changed.death_cause=cause
	remember(sim,key,"Life ends",cause)

func annual(sim,yield_callback:Callable=Callable()):
	if not _ready: initialize(sim)
	var epoch=sim.generation
	for town in sim.state.settlements:
		var keys=roster(sim,int(town.id)).duplicate()+roster(sim,int(town.id),"orbit").duplicate()
		if keys.is_empty(): continue
		var totals={"food":0.0,"wealth":0.0,"research":0.0,"care":0.0,"security":0.0,"honor":0.0,"adults":0}
		var deaths=[]
		var stories=[]
		var processed=0
		for key in keys:
			processed+=1
			if yield_callback.is_valid() and processed%64==0:
				if not await yield_callback.call() or sim.generation!=epoch: return false
			var person=work_person(sim,town,key)
			if person.age>=68+_hash(key,601)%25+mini(20,int(town.era)*2) and int(life(sim,key).get("revived_until",0))<=int(sim.state.year): deaths.append([key,"Died of old age"]); continue
			if not person.illness.is_empty() and _hash(key,int(sim.state.year)*79)%1000<int(65*(1.0-float(town.era)/18.0)):
				deaths.append([key,"Died of "+person.illness.to_lower()]); continue
			if person.age==ADULT:
				remember(sim,key,"Coming of age","Entered adult life and began work as a "+person.role+".")
				var parents=life(sim,key).get("parents",[])
				if not parents.is_empty(): adjust(sim,key,{"honor":(character(sim,parents[0],"honor")-0.5)*0.15})
			if person.age>=ADULT:
				totals.adults+=1; totals.honor+=person.honor
				var work=contribution(person)
				for field in ["food","wealth","research","care","security"]: totals[field]+=float(work.get(field,0))
			var record=life(sim,key)
			Projects.annual(sim,self,town,person)
			if person.illness.is_empty() and _hash(key,int(sim.state.year)*13)%1000 < (18 if town.plague>0 else 3):
				var sick=edit_life(sim,key)
				sick.illness="Fever" if town.plague<=0 else "Plague"
				sick.sick_until=int(sim.state.year)+3
				remember(sim,key,"Illness",sick.illness+" threatens health and keeps this person from their usual work.")
				civic.offer_family_promise(sim,self,town,person)
			if person.imprisoned and int(record.prison_until)==int(sim.state.year)+1:
				remember(sim,key,"Sentence completed","Returns to the community after serving a sentence.")
			if person.age>=ADULT and (person.possessed or _hash(key,int(sim.state.year)*37)%100<5): stories.append(sim.get_individual(key))
		for i in range(deaths.size()):
			var death=deaths[i]
			sim.kill_individual(death[0],death[1])
			if yield_callback.is_valid() and i%32==31:
				if not await yield_callback.call() or sim.generation!=epoch: return false
		for field in ["food","wealth","research"]: town[field]=float(town.get(field,0))+totals[field]
		town.health=clampf(town.health+minf(0.025,totals.care/maxf(1,keys.size())*0.025),0,1)
		town["social_security"]=clampf(totals.security/maxf(1,keys.size())*8,0,1)
		town["social_honor"]=totals.honor/maxi(1,totals.adults)
		town["adult_population"]=totals.adults
		if int(sim.state.year)%3==int(town.id)%3:
			if yield_callback.is_valid():
				if not await form_families(sim,town,roster(sim,int(town.id)),false,yield_callback): return false
				if not await form_families(sim,town,roster(sim,int(town.id),"orbit"),false,yield_callback): return false
			else:
				form_families(sim,town,roster(sim,int(town.id)))
				form_families(sim,town,roster(sim,int(town.id),"orbit"))
		if yield_callback.is_valid():
			if not await civic.annual_town(sim,self,town,stories,yield_callback): return false
		else: civic.annual_town(sim,self,town,stories)
		sim._normalize_town(town)
		if yield_callback.is_valid():
			if not await yield_callback.call() or sim.generation!=epoch: return false
	civic.advance_promises(sim,self)
	if int(sim.state.year)%25==0:
		if yield_callback.is_valid():
			if not await condense_ancestral_history(sim,yield_callback): return false
		else: condense_ancestral_history(sim)
	sim._citizens._changed(sim,false)
	return true

func condense_ancestral_history(sim,yield_callback:Callable=Callable()):
	var epoch=sim.generation
	# Genealogy and lifetime facts survive. Repeated household notices are useful
	# while following a life, but need not fill the save centuries after its end.
	var routine=["Marriage","Family grows","A family","Coming of age","Inheritance","Bereavement","Life ends","An honorable deed","Illness","Sentence completed"]
	var processed=0
	for key in _archive_pending.keys():
		processed+=1
		if yield_callback.is_valid() and processed%64==0:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		var record=sim.state.citizens.overrides.get(key,{})
		var personal=record.get("life",{})
		if not personal.get("death_noted",false) or personal.get("memory_archived",false): _archive_pending.erase(key); continue
		var history=record.get("history",[])
		if history.is_empty() or int(history[-1].year)>=int(sim.state.year)-25: continue
		var major=history.filter(func(entry): return entry.title not in routine)
		record.history=major.slice(maxi(0,major.size()-4))
		for field in ["last_birth","last_deed","last_crime","sick_until","curse_until","possessed_until","prison_until","grief_until"]: personal.erase(field)
		personal.erase("illness")
		personal.erase("project")
		personal.memory_archived=true
		_archive_pending.erase(key)
		if record.get("effects",[]).is_empty(): record.erase("effects")
	return true

func preview(sim,key,action,side)->Dictionary:
	var p=sim.get_individual(key)
	if p.is_empty() or not p.alive: return {"ok":false,"message":"Choose a living person."}
	var expected="god" if action in ["purify_person","pardon_person","reveal_person","comfort_person","teach_person","promise_mercy"] else "devil"
	if side!=expected: return {"ok":false,"message":"This action belongs to "+expected.capitalize()+"."}
	if action in ["bribe_person","promise_mercy","promise_cruelty"] and p.age<ADULT: return {"ok":false,"message":"A child cannot make a political bargain. Select an adult relative or official."}
	if action=="bribe_person" and p.role not in ["ruler","politician","judge"]: return {"ok":false,"message":"Bribery for legislation requires a ruler, politician, or judge."}
	if action in ["bribe_person","promise_mercy","promise_cruelty"] and p.imprisoned: return {"ok":false,"message":"This person is imprisoned and cannot carry out a public bargain."}
	if action in ["promise_mercy","promise_cruelty"]:
		var patient=civic.sick_relative(sim,self,p)
		if patient.is_empty(): return {"ok":false,"message":"This adult has no living sick family member to bargain for."}
		for vow in sim.state.society.promises:
			if vow.actor==p.key and vow.patient==patient.key and vow.status=="pending": return {"ok":false,"message":"This promise is already accepted. Select "+patient.name+" and heal them to resolve it."}
		return {"ok":true,"message":"A family bargain is possible.","duration":8,"duration_label":"8 year deadline","personal":{},"community":{},"consequence":"Heal "+patient.name+" within eight years. "+p.name+" will "+("support relief and fair treatment" if side=="god" else "serve the Devil through repression or a crime")+". Their office and honor affect whether they keep the promise.","patient":patient.key}
	var copy={
		"infernal_cure":"Cure this person's illness and restore health. Infernal allegiance grows, and an accepted family promise becomes due.",
		"curse_person":"Afflict this person for eight years. Illness and lost work distress the household; influential victims can destabilize the community.",
		"possess_person":"Possess this person for eight years. Their actions use their existing job and authority; a possessed ruler can order repression, while a violent resident can commit crimes.",
		"purify_person":"Remove this person's curse and possession, restoring control over their own actions.",
		"bribe_person":"Offer this official wealth to pass Guild Privileges: merchants gain advantages while workers bear the cost. Honorable officials can refuse and expose the bribe.",
		"pardon_person":"Release this prisoner or forgive their outstanding offense. Mercy can inspire reform, but victims may resent impunity.",
		"reveal_person":"Expose this person's recorded hidden crimes or corruption. Investigators can act, and an exposed ruler faces stronger opposition.",
		"comfort_person":"Ease this person's grief and resentment, strengthen family bonds, and encourage honorable conduct.",
		"teach_person":"Help this person learn. Children carry education into their adult work; adults improve their skills and community contribution."}
	if not copy.has(action): return {"ok":false,"message":"Unknown personal action."}
	var duration=8 if action in ["curse_person","possess_person"] else 0
	var label="8 years" if duration>0 else ("Lasting change" if action in ["teach_person","comfort_person"] else ("16 year law if accepted" if action=="bribe_person" else "Immediate"))
	return {"ok":true,"message":"Ready to influence "+p.name+".","duration":duration,"duration_label":label,"personal":{},"community":{},"consequence":copy[action]+" Target: "+p.name+" ("+p.role+")."}

func influence(sim,key,action,side)->Dictionary:
	var forecast=preview(sim,key,action,side)
	if not forecast.ok: return forecast
	var p=sim.get_individual(key); var record=edit_life(sim,p.key)
	var town=sim.get_settlement(int(p.settlement))
	var outcome=forecast.consequence
	match action:
		"infernal_cure":
			record.illness=""; record.sick_until=0
			adjust(sim,p.key,{"health":0.6,"happiness":0.12,"corruption":0.08})
			civic.fulfill_healing(sim,self,p.key)
		"curse_person": record.curse_until=int(sim.state.year)+8; adjust(sim,p.key,{"resentment":0.15})
		"possess_person": record.possessed_until=int(sim.state.year)+8; adjust(sim,p.key,{"honor":-0.25,"resentment":0.15})
		"purify_person": record.curse_until=0; record.possessed_until=0
		"comfort_person": record.grief_until=0; adjust(sim,p.key,{"resentment":-0.35,"honor":0.08,"empathy":0.12})
		"teach_person": adjust(sim,p.key,{"wisdom":0.2,"leadership":0.08})
		"pardon_person":
			record.prison_until=0; record.wanted=false
			adjust(sim,p.key,{"honor":0.1,"resentment":-0.1})
			town.happiness=clampf(town.happiness-0.01,0,1)
			for crime in sim.state.society.crimes:
				if crime.actor!=p.key or crime.status in ["pardoned","closed","unsolved"]: continue
				crime.status="pardoned"; crime.resolved=int(sim.state.year)
				if sim._citizens.status(sim,crime.victim).get("alive",false):
					adjust(sim,crime.victim,{"resentment":0.15})
					remember(sim,crime.victim,"The offender pardoned",p.name+" received a divine pardon. Mercy for the offender can feel unjust to the victim.")
		"reveal_person": outcome=civic.expose(sim,self,p,town)
		"bribe_person": outcome=civic.bribe(sim,self,p,town)
		"promise_mercy","promise_cruelty": outcome=civic.make_promise(sim,self,p,sim.get_individual(forecast.patient),side).get("message",outcome)
	if action in ["curse_person","possess_person"]:
		for relative in p.parents+p.children+([p.spouse] if not p.spouse.is_empty() else []):
			if sim._citizens.status(sim,relative).get("alive",false):
				adjust(sim,relative,{"resentment":0.05,"happiness":-0.03})
				remember(sim,relative,"A loved one afflicted",p.name+" has been "+("cursed" if action=="curse_person" else "possessed")+". Their household is distressed.")
	remember(sim,p.key,action.trim_suffix("_person").replace("_"," ").capitalize(),outcome)
	sim.add_event("An intervention in "+p.name+"'s life",outcome,"person",town.x,town.y,["Selected person: "+p.key,"Role: "+p.role])
	sim._citizens._changed(sim,false)
	return {"ok":true,"message":outcome,"duration":8}

func after_influence(sim,key,action):
	var p=sim.get_individual(key)
	if p.is_empty(): return
	var record=edit_life(sim,p.key)
	if action=="heal_person":
		record.illness=""; record.sick_until=0
		for relative in p.parents+p.children+([p.spouse] if not p.spouse.is_empty() else []):
			if sim._citizens.status(sim,relative).get("alive",false):
				adjust(sim,relative,{"faith":0.04,"resentment":-0.04})
				remember(sim,relative,"A loved one healed",p.name+" received healing; gratitude changes this household's beliefs.")
		civic.fulfill_healing(sim,self,p.key)
	elif action=="bless_person": adjust(sim,p.key,{"honor":0.08,"empathy":0.05})
	elif action in ["tempt_person","corrupt_person"]: adjust(sim,p.key,{"honor":-0.12})
	elif action=="incite_person": adjust(sim,p.key,{"resentment":0.25,"courage":0.12})
