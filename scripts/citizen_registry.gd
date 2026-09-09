extends RefCounted
## Compact, persistent identities. Cohorts record issuance forever; resident ranges
## record who is alive and where, without allocating one Dictionary per inhabitant.
const Content = preload("res://scripts/content.gd")
const ROLES = ["farmer","worker","merchant","healer","scholar","guard","artisan","farmer","worker","citizen","farmer","citizen"]
const SURNAMES = ["Vale","Reed","Ash","Stone","River","Moss","Brook","Flint","Dawn","Frost","Birch","Field","Wren","Cedar","Hill","Lake","Shore","Rowan","Hearth","Fox"]
var _revision = -1
var membership_revision = 0
var _live = []
var _aliases = {}
var _legacy = {}
var _towns = {}
var _death_buckets = {}
var _indexed_deaths = 0
var _effect_keys={}

func initialize(sim):
	if not sim.state.has("citizens"):
		sim.state.citizens = {"version":1,"next_id":1,"revision":0,"cohorts":[],"residents":{},"overrides":{},"named":{},"deceased":[]}
	var registry = sim.state.citizens
	if not registry.has("deceased"): registry.deceased = []
	for field in ["version","next_id","revision"]: registry[field]=int(registry[field])
	for collection in [registry.cohorts,registry.deceased]:
		for row in collection:
			for i in range(row.size()): row[i]=int(row[i])
	for bucket in registry.residents.values():
		for location in ["surface","orbit"]:
			for row in bucket.get(location,[]): row[0]=int(row[0]); row[1]=int(row[1])
	_effect_keys.clear()
	for key in registry.overrides:
		var edit=registry.overrides[key]
		if not edit.get("effects",[]).is_empty(): _effect_keys[key]=true
		if edit.has("born"): edit.born=int(edit.born)
		for entry in edit.get("history",[]): entry.year=int(entry.year)
		for effect in edit.get("effects",[]): effect.until=int(effect.until)
	sync(sim, true)
	for person in sim.state.people:
		if person.get("alive",false) and not registry.named.has("p:%d" % int(person.id)): promote(sim,person,true)
	_revision = -1

func _changed(sim,membership:bool=true,index_updated:bool=false):
	var previous=int(sim.state.citizens.get("revision",0))
	sim.state.citizens.revision = previous + 1
	if membership: membership_revision+=1
	if membership and not index_updated: _revision = -1
	elif _revision==previous: _revision=previous+1

func _bucket(sim,town_id:int,location:String) -> Array:
	var registry = sim.state.citizens
	var key = str(town_id)
	if not registry.residents.has(key): registry.residents[key] = {"surface":[],"orbit":[]}
	return registry.residents[key][location]

func count(sim,town_id:int,location:String="surface") -> int:
	var total = 0
	for segment in sim.state.get("citizens",{}).get("residents",{}).get(str(town_id),{}).get(location,[]): total += int(segment[1])
	return total

func add(sim,town_id:int,amount:int,location:String="surface",initial:bool=false):
	if amount <= 0: return
	var registry = sim.state.citizens
	var first = int(registry.next_id)
	registry.next_id = first + amount
	registry.cohorts.append([first,amount,int(sim.state.year),town_id,_hash(first,town_id),60 if initial else 0])
	var ranges = _bucket(sim,town_id,location)
	_append_range(ranges,first,amount)
	var indexed=_revision==int(registry.revision)
	if indexed:
		_towns[town_id]=sim.get_settlement(town_id)
		_insert_live_range(first,amount,town_id,location)
	_changed(sim,true,indexed)

func sync(sim,initial:bool=false):
	if not sim.state.has("citizens"): return
	for town in sim.state.settlements:
		sync_town(sim,town,initial)

func sync_town(sim,town,initial:bool=false):
	for location in ["surface","orbit"]:
		var target = maxi(0,floori(float(town.get("population" if location=="surface" else "orbital_population",0.0))))
		var current = count(sim,int(town.id),location)
		if current < target: add(sim,int(town.id),target-current,location,initial)
		elif current > target: retire(sim,int(town.id),current-target,location)

func retire(sim,town_id:int,amount:int,location:String="surface",yield_callback:Callable=Callable()) -> int:
	var epoch=sim.generation
	_build_index(sim)
	var ranges = _bucket(sim,town_id,location)
	var removed = 0
	var remembered=[]
	while amount > 0 and not ranges.is_empty():
		var segment = ranges[0]
		var take = mini(amount,int(segment[1]))
		_remove_live_range(int(segment[0]),take)
		for id in range(int(segment[0]),int(segment[0])+take):
			var key="c:%d"%id
			if sim.state.citizens.overrides.get(key,{}).has("life"): remembered.append(key)
		sim.state.citizens.deceased.append([int(segment[0]),take,int(sim.state.year),town_id,0 if location=="surface" else 1])
		segment[0] = int(segment[0])+take
		segment[1] = int(segment[1])-take
		if int(segment[1]) <= 0: ranges.pop_front()
		removed += take
		amount -= take
	if removed > 0:
		_changed(sim,true,true)
		var processed=0
		for key in remembered:
			processed+=1
			if yield_callback.is_valid() and processed%8==0:
				if not await yield_callback.call() or sim.generation!=epoch: return -1
			sim._society.on_death(sim,key,"Lost to illness, hunger, conflict, or disaster")
	return removed

func transfer(sim,source:int,destination:int,amount:int,from_location:String="surface",to_location:String="surface") -> int:
	if amount <= 0 or (source==destination and from_location==to_location): return 0
	var origin = _bucket(sim,source,from_location)
	var target = _bucket(sim,destination,to_location)
	var moved = 0
	var moved_ranges=[]
	# Whole ranges move; individual identities, edits and birthdays remain unchanged.
	while amount > 0 and not origin.is_empty():
		var segment = origin[-1]
		var take = mini(amount,int(segment[1]))
		var first = int(segment[0])+int(segment[1])-take
		_append_range(target,first,take)
		moved_ranges.append([first,take])
		segment[1] = int(segment[1])-take
		if int(segment[1]) <= 0: origin.pop_back()
		amount -= take
		moved += take
	if moved > 0:
		_compact(target)
		var indexed=_revision==int(sim.state.citizens.revision)
		if indexed:
			_towns[destination]=sim.get_settlement(destination)
			for row in moved_ranges:
				_remove_live_range(int(row[0]),int(row[1]))
				_insert_live_range(int(row[0]),int(row[1]),destination,to_location)
		_changed(sim,true,indexed)
		for person in sim.state.people:
			if not person.get("alive",false) or int(person.settlement)!=source: continue
			var alias = sim.state.citizens.named.get("p:%d" % int(person.id),"")
			if alias.is_empty(): continue
			var id=int(str(alias).trim_prefix("c:"))
			var affected=false
			for segment in moved_ranges:
				if id>=int(segment[0]) and id<int(segment[0])+int(segment[1]): affected=true; break
			if affected:
				if source!=destination and person.role=="ruler":
					person.role="elder"
					var edit=sim.state.citizens.overrides.get(alias,{})
					edit.role="elder"
					sim.state.citizens.overrides[alias]=edit
				person.settlement = destination
	return moved

func kill_key(sim,key:String,cause:String="Died in the community") -> Dictionary:
	var resolved = get_person(sim,key)
	if resolved.is_empty() or not resolved.alive: return {}
	var canonical = sim.state.citizens.named.get(key,key)
	var id = int(str(canonical).trim_prefix("c:"))
	var ranges = _bucket(sim,int(resolved.settlement),str(resolved.location))
	for i in range(ranges.size()):
		var first = int(ranges[i][0])
		var length = int(ranges[i][1])
		if id < first or id >= first+length: continue
		ranges.remove_at(i)
		if id>first: ranges.insert(i,[first,id-first])
		if id<first+length-1: ranges.insert(i if id==first else i+1,[id+1,first+length-id-1])
		sim.state.citizens.deceased.append([id,1,int(sim.state.year),int(resolved.settlement),0 if resolved.location=="surface" else 1])
		_remove_live_range(id,1)
		_changed(sim,true,true)
		sim._society.edit_life(sim,canonical)
		sim._society.on_death(sim,canonical,cause)
		return resolved
	return {}

func promote(sim,person:Dictionary,preserve:bool=false,preferred:String=""):
	var registry = sim.state.citizens
	var key = "p:%d" % int(person.id)
	if registry.named.has(key): return
	var town_id = int(person.settlement)
	var town = sim.get_settlement(town_id)
	if town.is_empty(): return
	# Founders already exist in their initial resident cohort before receiving a title.
	for location in ["surface","orbit"]:
		var target = floori(float(town.get("population" if location=="surface" else "orbital_population",0)))
		if count(sim,town_id,location)<target: add(sim,town_id,target-count(sim,town_id,location),location,true)
	_build_index(sim)
	var chosen = {}
	if not preferred.is_empty():
		var candidate=get_person(sim,preferred)
		if not candidate.is_empty() and candidate.alive and candidate.age>=18 and candidate.settlement==town_id: chosen=candidate
	var fallback_key=""
	for location in ["surface","orbit"]:
		if not chosen.is_empty(): break
		var ranges = registry.residents.get(str(town_id),{}).get(location,[])
		# Do not appoint the first person in the oldest mortality range: that
		# would replace the ruler again in the next year's demographic pass.
		for range_step in range(ranges.size()):
			var segment=ranges[(ranges.size()/2+range_step)%ranges.size()]
			var length = int(segment[1])
			for step in range(mini(length,96)):
				var id = int(segment[0])+(length/2+step)%length
				var ckey = "c:%d" % id
				if _aliases.has(ckey): continue
				var cohort=_find_range(registry.cohorts,id)
				if cohort.is_empty():continue
				var born=int(registry.overrides.get(ckey,{}).get("born",int(cohort[2])-_hash(id,int(cohort[4]))%maxi(1,int(cohort[5]))))
				if int(sim.state.year)-born<18 and not preserve:
					if fallback_key.is_empty():fallback_key=ckey
					continue
				var candidate = get_person(sim,ckey)
				if candidate.is_empty(): continue
				chosen = candidate
				break
			if not chosen.is_empty(): break
		if not chosen.is_empty(): break
	if chosen.is_empty() and not fallback_key.is_empty():chosen=get_person(sim,fallback_key)
	if chosen.is_empty(): return
	var ckey = str(chosen.key)
	registry.named[key] = ckey
	var edit = registry.overrides.get(ckey,{})
	if not preserve:
		person.name = chosen.name
		person.age = chosen.age
		person.born = int(sim.state.year)-int(chosen.age)
		person.traits = chosen.traits.duplicate()
		person.lifespan = maxi(int(person.get("lifespan",80)),int(chosen.age)+20)
	edit.merge({"name":str(person.name),"born":int(person.get("born",sim.state.year-person.age)),"role":str(person.role),"traits":person.get("traits",[]).duplicate()},true)
	registry.overrides[ckey] = edit
	_aliases[ckey]=key
	_changed(sim,false)

func _build_index(sim):
	if not sim.state.has("citizens"): return
	var registry = sim.state.citizens
	if _revision == int(registry.revision): return
	_live.clear()
	_aliases.clear()
	_legacy.clear()
	_towns.clear()
	for town in sim.state.settlements: _towns[int(town.id)] = town
	for person in sim.state.people: _legacy["p:%d" % int(person.id)] = person
	for key in registry.named: _aliases[str(registry.named[key])] = str(key)
	for town_key in registry.residents:
		for location in ["surface","orbit"]:
			for segment in registry.residents[town_key].get(location,[]):
				_live.append([int(segment[0]),int(segment[1]),int(town_key),location])
	_live.sort_custom(func(a,b):return int(a[0])<int(b[0]))
	_revision = int(registry.revision)

func _find_range(ranges:Array,id:int) -> Array:
	var low = 0
	var high = ranges.size()-1
	while low<=high:
		var middle = (low+high)/2
		var item = ranges[middle]
		if id<int(item[0]): high=middle-1
		elif id>=int(item[0])+int(item[1]): low=middle+1
		else: return item
	return []

func _remove_live_range(first:int,amount:int):
	# Mortality changes only the affected intervals. Rebuilding and sorting every
	# resident range for each individual death made old worlds progressively slow.
	var low=0; var high=_live.size()-1
	while low<=high:
		var mid=(low+high)/2
		if int(_live[mid][0])+int(_live[mid][1])<=first: low=mid+1
		else: high=mid-1
	var end=first+amount
	var i=low
	while i<_live.size() and int(_live[i][0])<end:
		var row=_live[i]
		var row_first=int(row[0]); var row_end=row_first+int(row[1])
		_live.remove_at(i)
		if row_first<first: _live.insert(i,[row_first,first-row_first,row[2],row[3]]); i+=1
		if row_end>end: _live.insert(i,[end,row_end-end,row[2],row[3]]); break

func _insert_live_range(first:int,amount:int,town_id:int,location:String):
	# Births and migration update a few sorted intervals, preserving the rest of
	# the lookup instead of rebuilding every community after each moved family.
	var low=0; var high=_live.size()-1
	while low<=high:
		var middle=(low+high)/2
		if int(_live[middle][0])<first: low=middle+1
		else: high=middle-1
	var row=[first,amount,town_id,location]
	if low>0:
		var before=_live[low-1]
		if int(before[0])+int(before[1])==first and int(before[2])==town_id and before[3]==location:
			before[1]=int(before[1])+amount
			row=before; low-=1
		else: _live.insert(low,row)
	else: _live.insert(low,row)
	if low+1<_live.size():
		var after=_live[low+1]
		if int(row[0])+int(row[1])==int(after[0]) and int(after[2])==town_id and after[3]==location:
			row[1]=int(row[1])+int(after[1]); _live.remove_at(low+1)

func _death_record(registry:Dictionary,id:int)->Array:
	# Index append-only death ranges into small ID blocks. Looking up a grandparent
	# must not scan centuries of unrelated deaths, and ranges stay compact in saves.
	while _indexed_deaths<registry.deceased.size():
		var row=registry.deceased[_indexed_deaths]
		for block in range(int(row[0])/1024,(int(row[0])+int(row[1])-1)/1024+1):
			if not _death_buckets.has(block): _death_buckets[block]=[]
			_death_buckets[block].append(row)
		_indexed_deaths+=1
	var candidates=_death_buckets.get(id/1024,[])
	for j in range(candidates.size()-1,-1,-1):
		var row=candidates[j]
		if id>=int(row[0]) and id<int(row[0])+int(row[1]): return row
	return []

func status(sim,key:String) -> Dictionary:
	if not sim.state.has("citizens"): return {}
	var canonical=str(sim.state.citizens.named.get(key,key))
	if not canonical.begins_with("c:") or not canonical.trim_prefix("c:").is_valid_int(): return {}
	var id=int(canonical.trim_prefix("c:"))
	if id<1 or id>=int(sim.state.citizens.next_id) or canonical!="c:%d"%id:return {}
	_build_index(sim)
	var live=_find_range(_live,id)
	if live.is_empty():return {"alive":false}
	return {"alive":true,"settlement":int(live[2]),"location":str(live[3])}

func role_keys(sim,town_id:int,role:String,limit:int=16) -> Array[String]:
	var result:Array[String]=[]
	limit=clampi(limit,1,40)
	var registry=sim.state.get("citizens",{})
	if registry.is_empty():return result
	_build_index(sim)
	for segment in registry.residents.get(str(town_id),{}).get("surface",[]):
		for id in range(int(segment[0]),int(segment[0])+int(segment[1])):
			var cohort=_find_range(registry.cohorts,id)
			if cohort.is_empty():continue
			var key="c:%d"%id
			var edit=registry.overrides.get(key,{})
			var seed=_hash(id,int(cohort[4]))
			var born=int(edit.get("born",int(cohort[2])-seed%maxi(1,int(cohort[5]))))
			var actual_role=str(edit.get("role",ROLES[seed%ROLES.size()]))
			if int(sim.state.year)-born<18 and not edit.has("role"):actual_role="child"
			if actual_role==role:result.append(key)
			if result.size()>=limit:return result
	return result

func get_person(sim,key:String,include_social:bool=true,include_history:bool=true,identity_only:bool=false) -> Dictionary:
	if not sim.state.has("citizens"): return {}
	var registry = sim.state.citizens
	var canonical = str(registry.named.get(key,key))
	if not canonical.begins_with("c:") or not canonical.trim_prefix("c:").is_valid_int(): return {}
	var id = int(canonical.trim_prefix("c:"))
	if id<1 or id>=int(registry.next_id): return {}
	if canonical!="c:%d"%id: return {}
	var cohort = _find_range(registry.cohorts,id)
	if cohort.is_empty(): return {}
	_build_index(sim)
	var live = _find_range(_live,id)
	var edit = registry.overrides.get(canonical,{})
	var born = int(edit.get("born",int(cohort[2])-(_hash(id,int(cohort[4]))%maxi(1,int(cohort[5]))) ))
	var town_id = int(live[2]) if not live.is_empty() else int(cohort[3])
	var year = int(sim.state.year)
	var location = str(live[3]) if not live.is_empty() else "surface"
	if live.is_empty():
		var death=_death_record(registry,id)
		if not death.is_empty():
			year = int(death[2])
			town_id = int(death[3])
			location = "surface" if int(death[4])==0 else "orbit"
	var town = _towns.get(town_id,{})
	var seed = _hash(id,int(cohort[4]))
	var role = str(edit.get("role",ROLES[seed%ROLES.size()]))
	var age = maxi(0,year-born)
	if age<18 and not edit.has("role"): role="child"
	# Titles add aliases; they must never replace a resident's lifelong identity.
	var public_key = canonical
	var name = str(edit.get("name",Content.PERSON_NAMES[seed%Content.PERSON_NAMES.size()]+" "+SURNAMES[(seed/17)%SURNAMES.size()]))
	var stats = edit.get("stats",{})
	var data = {"key":public_key,"name":name,"age":age,"alive":not live.is_empty(),"settlement":town_id,"nation":int(town.get("nation",-1)),"role":role,
		"traits":edit.get("traits",[Content.TRAITS[(seed/23)%Content.TRAITS.size()]]).duplicate(),"portrait_seed":seed,"location":location,"history":edit.get("history",[]).duplicate(true) if include_history else []}
	if identity_only: return data
	for field in ["health","happiness","faith","corruption","loyalty","ambition","standing","leadership","wisdom","strength"]:
		var baseline = 0.25+float(_hash(id,field.hash())%600)/1000.0
		if field in ["health","happiness","faith","corruption"]: baseline=clampf(float(town.get(field,0.5))*0.8+baseline*0.2,0,1)
		if field=="standing": baseline = 0.82 if role=="ruler" else (0.70 if role in ["prophet","politician","judge"] else 0.08+baseline*0.43)
		if field=="leadership" and role=="ruler": baseline=maxf(baseline,0.78)
		if field=="wisdom" and role in ["scholar","healer","prophet"]: baseline=maxf(baseline,0.66)
		if field=="strength" and role=="guard": baseline=maxf(baseline,0.73)
		if age<18 and field in ["standing","leadership","wisdom","strength"]: baseline*=float(age+2)/20.0
		var traits=data.traits
		if "ambitious" in traits and field in ["ambition","leadership"]:baseline+=0.10
		if "curious" in traits and field=="wisdom":baseline+=0.15
		if "aggressive" in traits and field in ["strength","ambition"]:baseline+=0.10
		if "generous" in traits and field in ["loyalty","happiness"]:baseline+=0.10
		if "merciful" in traits and field in ["loyalty","health"]:baseline+=0.07
		if "cautious" in traits and field in ["health","loyalty"]:baseline+=0.06
		if "skeptical" in traits and field=="faith":baseline-=0.12
		if "skeptical" in traits and field=="wisdom":baseline+=0.08
		if "zealous" in traits and field==("faith" if float(town.get("faith",0))>=float(town.get("corruption",0)) else "corruption"):baseline+=0.10
		data[field]=clampf(baseline+float(stats.get(field,0)),0,1)
	var combined = data.faith+data.corruption
	if combined>1: data.faith/=combined; data.corruption/=combined
	var role_reach = 1.0 if role=="ruler" else (0.8 if role in ["prophet","politician","judge"] else (0.46 if role in ["guard","scholar","merchant","healer"] else 0.22))
	data.influence=clampf(role_reach*(0.22+data.standing*0.48+data.leadership*0.18+data.wisdom*0.12)*(0.7+data.health*0.15+data.happiness*0.15),0.01,1)
	data.goal = _goal(data)
	if include_history and data.history.is_empty(): data.history.append({"year":born,"title":"A life begins","detail":"Born into the community of %s." % str(_towns.get(int(cohort[3]),{}).get("name","their homeland"))})
	if include_history and not data.alive: data.history.append({"year":year,"title":"Remembered","detail":"This life ended; its identity is never reused."})
	return sim._society.enrich(sim,data) if include_social and sim.state.has("society") else data

func page(sim,town_id:int,offset:int=0,limit:int=24,query:String="") -> Dictionary:
	limit=clampi(limit,1,60)
	offset=maxi(0,offset)
	var result=[]
	var total=0
	var search=query.strip_edges().to_lower()
	var registry=sim.state.get("citizens",{})
	var town=registry.get("residents",{}).get(str(town_id),{})
	if search.is_empty():
		total=count(sim,town_id)+count(sim,town_id,"orbit")
		var skip=offset
		for location in ["surface","orbit"]:
			for segment in town.get(location,[]):
				if skip>=int(segment[1]): skip-=int(segment[1]); continue
				for n in range(skip,int(segment[1])):
					if result.size()>=limit: break
					result.append(get_person(sim,"c:%d" % (int(segment[0])+n)))
				skip=0
				if result.size()>=limit: break
			if result.size()>=limit: break
	else:
		_build_index(sim)
		for location in ["surface","orbit"]:
			for segment in town.get(location,[]):
				var cohort=[]
				for id in range(int(segment[0]),int(segment[0])+int(segment[1])):
					if cohort.is_empty() or id>=int(cohort[0])+int(cohort[1]):cohort=_find_range(registry.cohorts,id)
					if cohort.is_empty():continue
					var key="c:%d"%id
					var edit=registry.overrides.get(key,{})
					var seed=_hash(id,int(cohort[4]))
					var born=int(edit.get("born",int(cohort[2])-seed%maxi(1,int(cohort[5]))))
					var role=str(edit.get("role",ROLES[seed%ROLES.size()]))
					if int(sim.state.year)-born<18 and not edit.has("role"):role="child"
					var name=str(edit.get("name",Content.PERSON_NAMES[seed%Content.PERSON_NAMES.size()]+" "+SURNAMES[(seed/17)%SURNAMES.size()]))
					if search not in (name+" "+role+" "+key+" "+str(_aliases.get(key,""))).to_lower():continue
					if total>=offset and result.size()<limit: result.append(get_person(sim,key))
					total+=1
	return {"people":result,"total":total,"offset":offset}

func keys(sim,town_id:int,limit:int=24,selected:String="") -> Array[String]:
	var result:Array[String]=[]
	limit=clampi(limit,1,40)
	var registry=sim.state.get("citizens",{})
	var ranges=registry.get("residents",{}).get(str(town_id),{}).get("surface",[])
	for segment in ranges:
		for id in range(int(segment[0]),int(segment[0])+int(segment[1])):
			var person=get_person(sim,"c:%d" % id)
			if not person.is_empty(): result.append(str(person.key))
			if result.size()>=limit: break
		if result.size()>=limit: break
	var important=[]
	for person in sim.state.get("people",[]):
		if person.get("alive",false) and int(person.settlement)==town_id: important.append("p:%d"%int(person.id))
	if not selected.is_empty(): important.append(selected)
	var replace=0
	for key in important:
		var person=get_person(sim,key)
		if person.is_empty() or not person.alive or person.location!="surface" or person.settlement!=town_id: continue
		var canonical=str(person.key)
		if canonical in result: continue
		if result.size()<limit: result.append(canonical)
		else:
			result[result.size()-1-(replace%limit)]=canonical
			replace+=1
	return result

func annual(sim):
	for key in _effect_keys.keys():
		var edit=sim.state.citizens.overrides[key]
		if not edit.has("effects") or edit.effects.is_empty(): _effect_keys.erase(key); continue
		var person=get_person(sim,key)
		if person.is_empty() or not person.alive: edit.effects=[]; _effect_keys.erase(key); continue
		var town=sim.get_settlement(int(person.settlement))
		if town.is_empty(): continue
		var kept=[]
		for effect in edit.effects:
			if int(effect.until)<int(sim.state.year): continue
			for field in effect.community:
				var amount=float(effect.community[field])*(0.25 if person.get("imprisoned",false) else 1.0)
				if field=="aggression":
					for nation in sim.state.nations:
						if int(nation.id)==int(town.nation): nation.aggression=clampf(float(nation.aggression)+amount,0,1)
				else: town[field]=float(town.get(field,0))+amount
			kept.append(effect)
		edit.effects=kept
		if kept.is_empty(): _effect_keys.erase(key)
		sim._normalize_town(town)

func preview(sim,key:String,action:String,side:String) -> Dictionary:
	var expected="god" if action in ["heal_person","inspire_person","bless_person"] else "devil"
	if action not in ["heal_person","inspire_person","bless_person","tempt_person","corrupt_person","incite_person"] or side!=expected: return {"ok":false,"message":"That intervention does not belong to this deity."}
	var person=get_person(sim,key)
	if person.is_empty() or not person.alive: return {"ok":false,"message":"Choose a living resident before intervening."}
	var town=sim.get_settlement(int(person.settlement))
	if town.is_empty(): return {"ok":false,"message":"This person has no living community."}
	var role=str(person.role)
	var reach=float(person.influence)
	var personal={}
	var community={}
	match action:
		"heal_person":
			personal={"health":0.6,"happiness":0.12}
			community={"health":reach*(0.018 if role=="healer" else 0.002),"happiness":reach*0.002}
		"inspire_person":
			personal={"wisdom":0.22,"leadership":0.08,"happiness":0.10}
			community={"research":reach*(7.0 if role in ["scholar","ruler"] else 2.0),"food":reach*(12.0 if role in ["farmer","worker","artisan"] else 2.0),"knowledge":reach*0.7}
		"bless_person":
			personal={"loyalty":0.2,"standing":0.14,"faith":0.24,"corruption":-0.14}
			community={"faith":reach*(0.007 if role in ["ruler","prophet"] else 0.003),"happiness":reach*0.003,"fear":-reach*0.002}
		"tempt_person":
			personal={"ambition":0.24,"corruption":0.2,"faith":-0.08}
			community={"wealth":reach*(8.0 if role in ["ruler","merchant"] else 3.0)*(0.5+person.ambition),"corruption":reach*0.003,"happiness":-reach*0.001}
		"corrupt_person":
			personal={"corruption":0.32,"faith":-0.22,"loyalty":-0.20}
			community={"corruption":reach*(0.007 if role in ["ruler","prophet"] else 0.003),"faith":-reach*0.004,"happiness":-reach*0.002*(1.2-person.loyalty*0.4)}
		"incite_person":
			personal={"ambition":0.2,"strength":0.10,"loyalty":-0.18,"happiness":-0.12}
			community={"aggression":reach*(0.010 if role in ["ruler","guard"] else 0.002)*(0.5+person.strength),"happiness":-reach*0.005,"fear":reach*0.003}
	var details=[]
	var personal_details=[]
	for field in personal: personal_details.append("%s up to %+.0f percentage points"%[str(field).capitalize(),float(personal[field])*100])
	for field in community:
		var change=float(community[field])
		if field in ["health","happiness","faith","corruption","fear","aggression"]:details.append("%s %+.2f percentage points/year"%[str(field).capitalize(),change*100])
		else:details.append("%s %+.2f units/year"%[str(field).capitalize(),change])
	var consequence="Personal: %s (stats stay within 0–100%%). %s's %s role and %.0f%% community influence produce: %s, for 12 years while alive. Repeating this action renews it; other actions can combine."%["; ".join(personal_details),person.name,role,reach*100,"; ".join(details)]
	return {"ok":true,"message":"A personal intervention is ready.","consequence":consequence,"duration":12,"personal":personal,"community":community,"impact":{"influence":reach,"role":role}}

func influence(sim,key:String,action:String,side:String) -> Dictionary:
	var forecast=preview(sim,key,action,side)
	if not forecast.ok: return forecast
	var person=get_person(sim,key)
	var registry=sim.state.citizens
	var canonical=str(registry.named.get(person.key,person.key))
	var edit=registry.overrides.get(canonical,{})
	var stats=edit.get("stats",{})
	for field in forecast.personal: stats[field]=clampf(float(stats.get(field,0))+float(forecast.personal[field]),-1,1)
	edit.stats=stats
	var effects=edit.get("effects",[])
	effects=effects.filter(func(effect):return str(effect.action)!=action and int(effect.until)>=int(sim.state.year))
	effects.append({"action":action,"side":side,"until":int(sim.state.year)+12,"community":forecast.community.duplicate()})
	_effect_keys[canonical]=true
	edit.effects=effects
	var history=edit.get("history",[])
	history.append({"year":int(sim.state.year),"title":action.replace("_person","").capitalize()+" from "+side.capitalize(),"detail":forecast.consequence})
	if history.size()>24: history=history.slice(history.size()-24)
	edit.history=history
	registry.overrides[canonical]=edit
	_changed(sim,false)
	sim._society.after_influence(sim,canonical,action)
	var named_key=str(_aliases.get(canonical,""))
	if not named_key.is_empty():
		var public=sim.get_person(int(named_key.trim_prefix("p:")))
		var updated=get_person(sim,str(person.key))
		if not public.is_empty():public.alignment="god" if updated.faith>=updated.corruption else "devil"
	var town=sim.get_settlement(int(person.settlement))
	sim.add_event("%s is touched by %s"%[person.name,side.capitalize()],forecast.consequence,"person",int(town.x),int(town.y),["Direct intervention: "+action,"Role: "+str(person.role),"Standing %.0f%%; influence %.0f%%"%[person.standing*100,person.influence*100]])
	return {"ok":true,"message":"%s: %s"%[person.name,forecast.consequence],"duration":12}

func _goal(person) -> String:
	if person.age<18: return "Grow, learn, and find a place in the community."
	if person.ambition>0.75 and person.loyalty<0.4: return "Gain standing and challenge the people in power."
	if person.health<0.45: return "Recover and keep the household safe."
	if person.corruption>0.6: return "Seek power through a tempting bargain."
	return {"ruler":"Keep the realm stable and guide its future.","prophet":"Spread a teaching through the community.","healer":"Keep neighbors healthy and share remedies.","scholar":"Make discoveries and pass on knowledge.","guard":"Protect the settlement and prove skill in battle.","farmer":"Provide food and improve the next harvest.","merchant":"Build prosperity through trade.","worker":"Improve the tools and works of the settlement.","artisan":"Create useful goods and earn respect."}.get(person.role,"Care for the household and earn a place in the community.")

func _append_range(ranges,first:int,amount:int):
	if not ranges.is_empty() and int(ranges[-1][0])+int(ranges[-1][1])==first: ranges[-1][1]=int(ranges[-1][1])+amount
	else: ranges.append([first,amount])

func _compact(ranges):
	ranges.sort_custom(func(a,b):return int(a[0])<int(b[0]))
	var i=1
	while i<ranges.size():
		if int(ranges[i-1][0])+int(ranges[i-1][1])==int(ranges[i][0]):
			ranges[i-1][1]=int(ranges[i-1][1])+int(ranges[i][1])
			ranges.remove_at(i)
		else: i+=1

func _hash(a:int,b:int) -> int:
	return absi((a*92837111+b*689287499)^(a*1274126177))%2147483647
