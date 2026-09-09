extends RefCounted
## Quiet, on-demand continuity: family appeals, followed people, and consequences.
static func entries(sim)->Array:
	var result=[]
	for vow in sim.state.get("society",{}).get("promises",[]):
		var followed=vow.actor in sim.state.get("favorite_people",[]) or vow.actor in sim.state.get("story_people",[]) or vow.patient in sim.state.get("favorite_people",[])
		if vow.status not in ["offered","pending"] and not followed and int(sim.state.year)-int(vow.resolved)>30: continue
		var actor=sim.get_individual(vow.actor); var patient=sim.get_individual(vow.patient)
		if actor.is_empty() or patient.is_empty(): continue
		var detail="Heal "+patient.name+" by year %d."%int(vow.deadline) if vow.status=="pending" else ("A sick relative needs help. Meet "+actor.name+" to consider their appeal." if vow.status=="offered" else str(vow.outcome))
		for law in sim.state.society.laws:
			if law.actor==vow.actor and int(law.since)>=int(vow.since) and int(law.since)<=maxi(int(vow.resolved),int(vow.since)) and "bargain" in str(law.reason):
				detail+=" "+str(law.name)+" benefits "+str(law.group)+(" until year %d."%int(law.until) if law.until>sim.state.year else "; its term has ended.")
		result.append({"title":actor.name+" · "+str(vow.status).capitalize(),"detail":detail,"person":vow.actor,"patient":vow.patient,"year":maxi(int(vow.since),int(vow.resolved)),"priority":0 if vow.status in ["offered","pending"] else 1,"promise":true})
	# Recently influenced people are followed automatically, with a bounded list.
	var keys=sim.state.get("favorite_people",[]).duplicate()
	for key in sim.state.get("story_people",[]):
		if key not in keys: keys.append(key)
	for key in keys:
		var p=sim.get_individual(key)
		if p.is_empty(): continue
		var history=p.get("history",[])
		var latest=history[-1] if not history.is_empty() else {"title":"A life to follow","detail":str(p.get("goal","")),"year":int(sim.state.year)}
		var detail=str(latest.title)+": "+str(latest.detail)
		var goal=p.get("project",{})
		if not goal.is_empty(): detail+=" Project: "+str(goal.title)+" · "+str(goal.status)+". "+str(goal.get("outcome",""))
		result.append({"title":p.name+(" · Remembered" if not p.alive else " · "+str(p.role).capitalize()),"detail":detail,"person":p.key,"year":int(latest.year),"priority":2,"promise":false})
	result.sort_custom(func(a,b):return a.priority<b.priority if a.priority!=b.priority else a.year>b.year)
	return result
static func follow(sim,key:String):
	if not sim.state.has("citizens"): return
	key=str(sim.state.citizens.named.get(key,key))
	var keys=sim.state.get("story_people",[])
	keys.erase(key);keys.push_front(key)
	sim.state.story_people=keys.slice(0,32)
static func show(app):
	app._open_modal("Lives & stories",Vector2(520,720))
	app.modal_body.add_child(app._paragraph("Family appeals and the people you follow. Silent and available whenever you want to return to a story. Your recent interventions appear here automatically.",13,app.MUTED))
	var rows=entries(app.sim)
	if rows.is_empty(): app.modal_body.add_child(app._paragraph("Select a person and favorite them, or influence their life. Their story will appear here. Family appeals appear when an official has a sick child.",15))
	for row in rows.slice(0,60):
		app.community.card(app.modal_body,row.title,"Year %d · "%row.year+row.detail,app.community.show_person.bind(str(row.person)))
		if row.promise:
			app.modal_body.add_child(app._button("Visit the relative",app.community.show_person.bind(str(row.patient)),48))
	app.modal_body.add_child(app._button("Find people to follow",app._show_people,48))
