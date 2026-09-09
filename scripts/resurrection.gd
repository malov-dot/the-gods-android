extends RefCounted
static func preview(sim,key:String)->Dictionary:
	var person=sim.get_individual(key)
	if person.is_empty() or person.alive: return {"ok":false,"message":"Select a deceased person."}
	var town=sim.get_settlement(int(person.settlement))
	if town.is_empty(): return {"ok":false,"message":"Their former community is missing."}
	if person.location=="surface" and sim.get_tile(int(town.x),int(town.y)).get("elevation",0)<0.36: return {"ok":false,"message":"Restore land beneath their community before returning this person."}
	return {"ok":true,"message":"Return "+person.name+" to their community.","consequence":"Restore this same person, family links and memories. Cure illness and afflictions; allow twenty more years before old age can claim them. Former rulers return as elders; existing marriages and inherited property are respected.","personal":{},"community":{},"duration":20}
static func apply(sim,key:String)->Dictionary:
	var check=preview(sim,key)
	if not check.ok: return check
	var registry=sim.state.citizens;var canonical=sim._society.canonical(sim,key);var id=int(canonical.trim_prefix("c:"))
	var person=sim.get_individual(key);var town=sim.get_settlement(int(person.settlement))
	var found=false
	for i in range(registry.deceased.size()):
		var row=registry.deceased[i];var first=int(row[0]);var end=first+int(row[1])
		if id<first or id>=end: continue
		registry.deceased.remove_at(i)
		if id>first: registry.deceased.append([first,id-first,row[2],row[3],row[4]])
		if id+1<end: registry.deceased.append([id+1,end-id-1,row[2],row[3],row[4]])
		found=true;break
	if not found: return {"ok":false,"message":"This person's death record could not be located."}
	var bucket=sim._citizens._bucket(sim,int(town.id),str(person.location))
	bucket.append([id,1]);bucket.sort_custom(func(a,b):return int(a[0])<int(b[0]))
	sim._citizens._death_buckets.clear();sim._citizens._indexed_deaths=0
	var record=sim._society.edit_life(sim,canonical)
	for field in ["sick_until","curse_until","possessed_until","grief_until"]: record[field]=0
	record.illness="";record.death_noted=false;record.memory_archived=false;record.death_cause="";record.revived_until=int(sim.state.year)+20
	# Do not recreate an estate that has already passed to the family.
	record.money=0.0;record.estate_age=int(sim.state.year)-int(sim.state.citizens.overrides[canonical].get("born",sim.state.year-person.age))
	var spouse=str(record.get("spouse",""))
	if not spouse.is_empty():
		var spouse_record=sim._society.life(sim,spouse)
		if str(spouse_record.get("spouse",""))!=canonical:
			record.erase("spouse");record.erase("married_year")
			sim._society.remember(sim,canonical,"A changed household","Their former spouse has another household. That marriage is respected.")
	if person.role=="ruler" and sim._society.canonical(sim,"p:%d"%int(town.leader))!=canonical: registry.overrides[canonical].role="elder"
	for named in sim.state.people:
		if sim._society.canonical(sim,"p:%d"%int(named.id))==canonical:
			named.alive=true;named.age=int(sim.state.year)-int(named.born);named.lifespan=maxi(int(named.lifespan),int(named.age)+20);named.role=registry.overrides[canonical].get("role",named.role)
	var field="orbital_population" if person.location=="orbit" else "population"
	town[field]=float(town.get(field,0))+1;town.food+=2;town.abandoned=false
	# These are pooled soul counts, not identity-specific destinations. Reconcile
	# one return without making a person's restoration depend on a currency.
	var returning=1.0
	for realm in ["heaven","wandering","hell"]:
		var taken=minf(returning,float(sim.state.afterlife.get(realm,0)))
		sim.state.afterlife[realm]=maxf(0,float(sim.state.afterlife.get(realm,0))-taken)
		returning-=taken
	sim._citizens._changed(sim,true)
	sim._society._work_cache.erase(canonical);sim._society._archive_pending.erase(canonical)
	sim._society.adjust(sim,canonical,{"health":0.6,"happiness":0.12})
	sim._society.remember(sim,canonical,"Returned to life","Divine intervention restored this same life. Memories and family ties survive; old age is held back until year %d."%int(record.revived_until))
	for relative in person.parents+person.children+([spouse] if not spouse.is_empty() else []):
		if not sim._citizens.status(sim,relative).get("alive",false): continue
		sim._society.edit_life(sim,relative).grief_until=0
		sim._society.remember(sim,relative,"A loved one returns",person.name+" has returned to life.")
	return {"ok":true,"message":person.name+" lives again. Their identity, memories and family remain.","duration":20}
