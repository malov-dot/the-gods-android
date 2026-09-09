extends RefCounted
## Public events retain their actors. Laws and promises have real annual effects.
const LAW_NAMES={"relief":"Common Relief","schools":"Public Learning","fair_trials":"Fair Trials","guild_privileges":"Guild Privileges","repression":"Edict of Silence"}
const LAW_GROUPS={"relief":"poor households","schools":"children and scholars","fair_trials":"ordinary residents","guild_privileges":"merchants","repression":"the ruler's supporters"}

func next_id(sim)->int:
	var id=int(sim.state.society.next_id)
	sim.state.society.next_id=id+1
	return id

func ensure_council(sim,town,keys,yield_callback:Callable=Callable()):
	var epoch=sim.generation
	if keys.size()<25: return true
	var processed=0
	var roles={"politician":false,"judge":false}
	for key in keys:
		processed+=1
		if yield_callback.is_valid() and processed%64==0:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		var p=sim._society.identity(sim,key)
		if p.get("role","") in roles and p.get("age",0)>=18: roles[p.role]=true
		if roles.politician and roles.judge: return true
	for role in roles:
		if roles[role]: continue
		var best={}; var score=-1.0
		for key in keys:
			processed+=1
			if yield_callback.is_valid() and processed%32==0:
				if not await yield_callback.call() or sim.generation!=epoch: return false
			var p=sim._society.base(sim,key)
			if p.is_empty() or p.age<18 or p.role in ["ruler","politician","judge","prophet"]: continue
			var value=float(p.wisdom)+float(p.leadership)
			if value>score: best=p; score=value
		if not best.is_empty():
			sim._society.edit_life(sim,best.key)
			sim.state.citizens.overrides[best.key].role=role
			sim._society.remember(sim,best.key,"Public office","The community entrusts this person with the work of a "+role+".")
	return true

func pass_law(sim,life,town,actor,kind,reason)->Dictionary:
	for law in sim.state.society.laws:
		if int(law.town)==int(town.id) and law.kind==kind and int(law.until)>int(sim.state.year):
			law.until=int(sim.state.year)+16
			return law
	var law={"id":next_id(sim),"town":int(town.id),"actor":str(actor.key),"kind":kind,"name":LAW_NAMES[kind],"group":LAW_GROUPS[kind],"since":int(sim.state.year),"until":int(sim.state.year)+16,"reason":reason}
	sim.state.society.laws.append(law)
	life.remember(sim,actor.key,"A law is passed",law.name+" benefits "+law.group+". "+reason)
	sim.add_event(law.name+" in "+town.name,actor.name+" enacts "+law.name+" for "+law.group+". "+reason,"politics",town.x,town.y,["Official: "+actor.key])
	return law

func bribe(sim,life,person,town)->String:
	if person.honor>=0.65 and not person.possessed:
		life.adjust(sim,person.key,{"standing":0.08,"honor":0.04})
		town["unrest"]=maxf(0,float(town.get("unrest",0))-0.03)
		return person.name+" refuses the bribe and publicly defends equal treatment. Their standing rises."
	var record=life.edit_life(sim,person.key)
	record.money=float(record.get("money",0))+40
	record.bribed=true
	life.adjust(sim,person.key,{"honor":-0.12,"corruption":0.12})
	pass_law(sim,life,town,person,"guild_privileges","A private payment bought this official's support.")
	return person.name+" accepts 40 wealth and passes Guild Privileges. Merchants gain; workers bear the cost for sixteen years."

func expose(sim,life,person,town)->String:
	var found=false
	for crime in sim.state.society.crimes:
		if crime.actor==person.key and crime.status=="hidden": crime.status="reported"; found=true
	var record=life.edit_life(sim,person.key)
	if record.get("bribed",false) or person.possessed:
		record.exposed=true; found=true
	if not found: return "No hidden crime or corrupt conduct is recorded for "+person.name+". No accusation is invented."
	life.adjust(sim,person.key,{"standing":-0.18})
	if person.role=="ruler": town["unrest"]=clampf(float(town.get("unrest",0))+0.25,0,1)
	else: record.wanted=true
	return "The deeds of "+person.name+" become public. Investigators can pursue recorded crimes; an exposed ruler loses public trust."

func sick_relative(sim,life,person)->Dictionary:
	# Children are offered first, then a spouse or parent. All are real residents.
	var relatives=person.get("children",[]).duplicate()
	if not str(person.get("spouse","")).is_empty(): relatives.append(person.spouse)
	relatives.append_array(person.get("parents",[]))
	for key in relatives:
		var p=sim.get_individual(str(key))
		if not p.is_empty() and p.alive and not str(p.illness).is_empty(): return p
	return {}

func offer_family_promise(sim,life,town,patient):
	for key in life.life(sim,patient.key).get("parents",[]):
		var parent=sim.get_individual(str(key))
		if parent.is_empty() or not parent.alive or parent.role not in ["ruler","politician","judge"]: continue
		for old in sim.state.society.promises:
			if old.actor==parent.key and old.status in ["offered","pending"]: return
		var vow=_promise(sim,parent,patient,"god","offered")
		sim.state.society.promises.append(vow)
		life.remember(sim,parent.key,"A desperate appeal",patient.name+" is sick. This official offers public relief in exchange for a divine cure.")
		sim.add_event("A plea from "+parent.name,"Their child "+patient.name+" is ill. Inspect the parent to accept a promise, then heal the child.","person",town.x,town.y,[parent.key,patient.key])
		return

func _promise(sim,actor,patient,side,status)->Dictionary:
	return {"id":next_id(sim),"actor":actor.key,"patient":patient.key,"town":int(actor.settlement),"side":side,"status":status,"since":int(sim.state.year),"deadline":int(sim.state.year)+8,"resolved":-1,"outcome":""}

func make_promise(sim,life,actor,patient,side)->Dictionary:
	for old in sim.state.society.promises:
		if old.actor==actor.key and old.patient==patient.key and old.status in ["offered","pending"]:
			if old.status=="pending": return {"ok":false,"message":"This family already has an accepted promise. Heal the named relative to resolve it."}
			old.status="pending"; old.side=side; old.deadline=int(sim.state.year)+8
			return {"ok":true,"message":actor.name+" promises "+("public mercy" if side=="god" else "cruel service")+" if you heal "+patient.name+" within eight years."}
	var vow=_promise(sim,actor,patient,side,"pending")
	sim.state.society.promises.append(vow)
	life.remember(sim,patient.key,"A promise for a cure",actor.name+" has bargained for this person's healing.")
	return {"ok":true,"message":actor.name+" promises "+("public mercy" if side=="god" else "cruel service")+" if you heal "+patient.name+" within eight years."}

func fulfill_healing(sim,life,patient_key):
	for vow in sim.state.society.promises:
		if vow.patient!=patient_key or vow.status!="pending" or int(vow.deadline)<int(sim.state.year): continue
		var actor=sim.get_individual(vow.actor)
		if actor.is_empty() or not actor.alive: vow.status="failed"; vow.outcome="The person who made the promise died."; vow.resolved=int(sim.state.year); continue
		var town=sim.get_settlement(int(actor.settlement))
		var honors=actor.honor>=0.42 or actor.possessed
		vow.status="fulfilled" if honors else "broken"
		vow.resolved=int(sim.state.year)
		if honors:
			if actor.role in ["ruler","politician","judge"]:
				pass_law(sim,life,town,actor,"relief" if vow.side=="god" else "repression","A family member was healed in fulfillment of a divine bargain.")
			elif vow.side=="god": _good_deed(sim,life,town,actor,true)
			else: _crime(sim,life,town,actor,false)
			vow.outcome=actor.name+" keeps the promise after the cure; "+("relief reaches the community." if vow.side=="god" else "others suffer for the bargain.")
		else:
			life.adjust(sim,actor.key,{"honor":-0.08,"standing":-0.1})
			vow.outcome=actor.name+" accepts the cure but breaks the promise. The public loses trust."
		life.remember(sim,actor.key,"A promise "+vow.status,vow.outcome)
		life.remember(sim,patient_key,"The price of healing",vow.outcome)
		sim.add_event("A promise "+vow.status,vow.outcome,"person",town.x,town.y,[actor.key,patient_key])

func advance_promises(sim,life):
	for vow in sim.state.society.promises:
		if vow.status not in ["pending","offered"]: continue
		if not sim._citizens.status(sim,vow.actor).get("alive",false) or not sim._citizens.status(sim,vow.patient).get("alive",false): vow.status="failed"; vow.outcome="A death ended the bargain."
		elif int(sim.state.year)>int(vow.deadline): vow.status="expired"; vow.outcome="The promised divine healing did not arrive in time."
		if vow.status not in ["pending","offered"]:
			vow.resolved=int(sim.state.year)
			life.remember(sim,vow.actor,"Promise "+vow.status,vow.outcome)
	# Keep unresolved stories plus recent outcomes. Personal histories retain events.
	_trim(sim,"promises",128,"status",["pending","offered"])
	_trim(sim,"crimes",256,"status",["hidden","reported"])
	sim.state.society.laws=sim.state.society.laws.filter(func(law): return int(law.until)+24>=int(sim.state.year))

func _trim(sim,field,limit,phase,active):
	var records=sim.state.society[field]
	if records.size()<=limit: return
	var kept=[]
	for i in range(records.size()):
		if i>=records.size()-limit or records[i][phase] in active: kept.append(records[i])
	sim.state.society[field]=kept

func annual_town(sim,life,town,stories,yield_callback:Callable=Callable()):
	var epoch=sim.generation
	if int(sim.state.year)%8==int(town.id)%8:
		if yield_callback.is_valid():
			if not await ensure_council(sim,town,life.roster(sim,int(town.id)),yield_callback): return false
		else: ensure_council(sim,town,life.roster(sim,int(town.id)))
	if yield_callback.is_valid():
		if not await _apply_laws(sim,life,town,yield_callback): return false
	else: _apply_laws(sim,life,town)
	var processed=0
	for actor in stories:
		processed+=1
		if yield_callback.is_valid() and processed%16==0:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		if not sim._citizens.status(sim,actor.key).get("alive",false) or actor.imprisoned: continue
		if actor.honor>=0.7 and actor.empathy>=0.45: _good_deed(sim,life,town,actor)
		elif actor.possessed or (actor.honor<=0.28 and actor.resentment>0.35):
			if actor.role in ["ruler","politician","judge"] and actor.possessed:
				pass_law(sim,life,town,actor,"repression","Possession twists the official's authority against their neighbors.")
			else: _crime(sim,life,town,actor,actor.possessed or (actor.honor<0.14 and actor.resentment>0.65))
	_investigate(sim,life,town)
	_opposition(sim,life,town,stories)
	return true

func _apply_laws(sim,life,town,yield_callback:Callable=Callable()):
	var epoch=sim.generation
	var active=[]
	for law in sim.state.society.laws:
		if int(law.town)!=int(town.id) or int(law.until)<=int(sim.state.year): continue
		active.append(law.kind)
		match law.kind:
			"relief": town.food+=town.population*0.04; town.wealth=maxf(0,town.wealth-town.population*0.008); town.happiness+=0.015
			"schools": town.research+=town.population*0.015; town.wealth=maxf(0,town.wealth-town.population*0.006)
			"fair_trials": town.fear=maxf(0,town.fear-0.018)
			"guild_privileges": town.wealth+=town.population*0.012; town.happiness-=0.018; town["unrest"]=clampf(float(town.get("unrest",0))+0.012,0,1)
			"repression": town.fear+=0.025; town.happiness-=0.025; town["unrest"]=clampf(float(town.get("unrest",0))+0.022,0,1)
	if active.is_empty(): return true
	# Group benefits and burdens are applied to actual residents, not only a label.
	var processed=0
	for key in life.roster(sim,int(town.id)):
		processed+=1
		if yield_callback.is_valid() and processed%64==0:
			if not await yield_callback.call() or sim.generation!=epoch: return false
		var p=life.identity(sim,key)
		if p.age<18:
			if "schools" in active: life.adjust(sim,key,{"wisdom":0.012})
			continue
		if "guild_privileges" in active:
			var record=life.edit_life(sim,key)
			if p.role=="merchant": record.money=float(record.get("money",0))+1.5
			elif p.role in ["farmer","worker","artisan"]: record.money=roundf((float(record.get("money",0))-0.2)*100.0)/100.0; life.adjust(sim,key,{"resentment":0.012})
		if "relief" in active: life.adjust(sim,key,{"resentment":-0.006})
	return true

func _good_deed(sim,life,town,actor,forced=false):
	var record=life.edit_life(sim,actor.key)
	if int(sim.state.year)-int(record.get("last_deed",-9))<4 and not forced: return
	record.last_deed=int(sim.state.year); record.good_deeds=int(record.get("good_deeds",0))+1
	life.adjust(sim,actor.key,{"standing":0.025})
	var text_="Shared food with a struggling household."
	match actor.role:
		"ruler","politician","judge":
			pass_law(sim,life,town,actor,"fair_trials" if actor.role=="judge" else ("schools" if actor.wisdom>0.65 else "relief"),"An honorable official answered the needs of residents.")
			text_="Used public office to protect residents."
		"healer": town.health+=0.01; text_="Treated neighbors without demanding payment."
		"scholar": town.research+=2; text_="Shared a discovery and taught younger residents."
		"guard": town.fear=maxf(0,town.fear-0.015); text_="Protected a household from intimidation."
		_: town.food+=2; town.happiness+=0.004
	life.remember(sim,actor.key,"An honorable deed",text_)

func _crime(sim,life,town,actor,murder=false)->Dictionary:
	var record=life.edit_life(sim,actor.key)
	if int(sim.state.year)-int(record.get("last_crime",-9))<4: return {}
	var keys=life.roster(sim,int(town.id))
	if keys.size()<2: return {}
	var victim={}
	var start=life._hash(actor.key,int(sim.state.year))%keys.size()
	for i in range(mini(40,keys.size())):
		var p=sim.get_individual(keys[(start+i)%keys.size()])
		if p.key!=actor.key and p.age>=18 and p.alive: victim=p; break
	if victim.is_empty(): return {}
	var kind="murder" if murder else "theft"
	var crime={"id":next_id(sim),"town":int(town.id),"actor":actor.key,"victim":victim.key,"kind":kind,"year":int(sim.state.year),"status":"hidden","resolved":-1}
	sim.state.society.crimes.append(crime)
	record.last_crime=int(sim.state.year); record.crimes=int(record.get("crimes",0))+1
	if murder:
		record.kills=int(record.get("kills",0))+1
		sim.kill_individual(victim.key,"Murdered by "+actor.name)
		town.fear+=0.04; town.happiness-=0.025
	else:
		record.money=float(record.get("money",0))+4
		var harmed=life.edit_life(sim,victim.key); harmed.money=float(harmed.get("money",0))-4
		life.adjust(sim,victim.key,{"resentment":0.12})
		life.remember(sim,victim.key,"Victim of theft","Lost 4 wealth. Investigators have not yet identified the culprit.")
	life.remember(sim,actor.key,kind.capitalize(),("Killed " if murder else "Stole from ")+victim.name+". The offense is initially hidden from the authorities.")
	if murder: sim.add_event("A murder in "+town.name,victim.name+" has been killed. Inspect residents and justice records to follow the case.","crisis",town.x,town.y,["Victim: "+victim.key])
	return crime

func _investigate(sim,life,town):
	var leader=sim.get_individual("p:%d"%int(town.leader))
	for crime in sim.state.society.crimes:
		if int(crime.town)!=int(town.id) or crime.status not in ["hidden","reported"]: continue
		if not sim._citizens.status(sim,crime.actor).get("alive",false): crime.status="closed"; crime.resolved=int(sim.state.year); continue
		if int(sim.state.year)-int(crime.year)>20: crime.status="unsolved"; crime.resolved=int(sim.state.year); continue
		var chance=0.04+float(town.get("social_security",0))*0.18+(0.3 if crime.status=="reported" else 0.0)
		if not leader.is_empty() and leader.honor<0.3: chance*=0.5
		if float(life._hash(str(crime.id),int(sim.state.year)*61)%1000)/1000.0>=chance: continue
		var criminal=sim.get_individual(crime.actor)
		if criminal.role=="ruler": expose(sim,life,criminal,town); crime.status="reported"; continue
		crime.status="convicted"; crime.resolved=int(sim.state.year)
		var record=life.edit_life(sim,crime.actor)
		record.prison_until=int(sim.state.year)+(12 if crime.kind=="murder" else 3); record.wanted=false
		life.adjust(sim,crime.actor,{"standing":-0.15})
		life.remember(sim,crime.actor,"Convicted of "+crime.kind,"Investigators proved the offense. Imprisoned until year %d."%int(record.prison_until))
		life.remember(sim,crime.victim,"Justice",criminal.name+" was convicted of the offense.")

func _opposition(sim,life,town,stories):
	var ruler=sim.get_individual("p:%d"%int(town.leader))
	if ruler.is_empty() or not ruler.alive: return
	var tyranny=maxf(0,0.5-ruler.honor)*0.6+town.fear*0.2+(0.25 if life.life(sim,ruler.key).get("exposed",false) else 0.0)
	if ruler.possessed: tyranny+=0.25
	town["tyranny"]=clampf(tyranny,0,1)
	var change=tyranny*0.05+maxf(0,0.5-town.happiness)*0.12-0.012
	town["unrest"]=clampf(float(town.get("unrest",0))+change,0,1)
	var movement={}
	for candidate in sim.state.society.movements:
		if int(candidate.town)==int(town.id): movement=candidate; break
	if movement.is_empty():
		movement={"town":int(town.id),"organizer":"","target":ruler.key,"support":0.0,"status":"quiet","started":int(sim.state.year)}
		sim.state.society.movements.append(movement)
	if not sim._citizens.status(sim,movement.organizer).get("alive",false) or movement.organizer==ruler.key:
		movement.organizer=""
		for p in stories:
			if p.key!=ruler.key and p.courage>0.5 and not p.imprisoned and (p.honor>0.55 or p.resentment>0.7): movement.organizer=p.key; break
	movement.target=ruler.key
	var agitator=sim.get_individual(movement.organizer)
	var agitation=0.0
	if not agitator.is_empty() and agitator.alive and not agitator.imprisoned:
		agitation=maxf(0,agitator.resentment-0.5)*0.045+maxf(0,agitator.courage-0.5)*tyranny*0.035
	movement.support=roundf(clampf(float(movement.support)*0.9+float(town.unrest)*0.1+agitation,0,1)*1000000.0)/1000000.0
	if movement.support>=0.28 and movement.status=="quiet" and not agitator.is_empty():
		movement.status="organizing"
		life.remember(sim,agitator.key,"An opposition forms","Organizes neighbors against "+ruler.name+"; public resentment determines support.")
	if movement.support<0.15: movement.status="quiet"
	if movement.support>=0.68 and not agitator.is_empty() and town.population>=35 and int(sim.state.year)-int(town.get("last_revolt",-55))>=35:
		if sim.start_rebellion(town,agitator.key): movement.status="revolution"; movement.support=0.08; town.unrest=0.1
