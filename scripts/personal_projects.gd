extends RefCounted
## Saved personal goals. Progress uses yearly work and wellbeing, never frame time.
const TITLES={"child":"Complete my education","farmer":"Build a reserve for the next poor harvest","scholar":"Finish a discovery","healer":"Organize a neighborhood clinic","guard":"Make my neighborhood safer","merchant":"Establish a trading household","worker":"Improve the community workshop","artisan":"Create a masterwork","ruler":"Complete a public improvement","politician":"Win support for public services","judge":"Restore trust in justice","prophet":"Teach a new generation"}
static func description(person,goal:Dictionary)->String:
	if goal.is_empty(): return "Find a project that helps my household and community."
	return str(goal.title)+("." if goal.status=="active" else " — "+str(goal.status)+".")
static func annual(sim,life,town,person):
	var record=life.edit_life(sim,person.key)
	var year=int(sim.state.year)
	var goal=record.get("project",{})
	if goal.is_empty() or (goal.status!="active" and year>=int(goal.finished)+3):
		var role="child" if person.age<18 else str(person.role)
		goal={"title":TITLES.get(role,"Build a secure household"),"role":role,"status":"active","progress":0.0,"target":8.0,"started":year,"deadline":year+18,"finished":-1,"obstacle":"","outcome":""}
		record.project=goal
	if goal.status!="active": return
	goal.obstacle=""
	if person.imprisoned: goal.obstacle="Unable to continue in prison"
	elif not person.illness.is_empty(): goal.obstacle="Illness interrupts this project"
	elif person.cursed: goal.obstacle="A curse makes progress difficult"
	elif town.food<town.population*0.2: goal.obstacle="Food shortages divert attention to survival"
	var effort=clampf(person.health*(0.4+person.happiness*0.3+person.wisdom*0.3),0.0,1.0)
	if not goal.obstacle.is_empty(): effort*=0.15
	goal.progress=snappedf(minf(float(goal.target),float(goal.progress)+effort),0.001)
	if goal.progress>=goal.target:
		goal.status="completed"; goal.finished=year
		life.adjust(sim,person.key,{"standing":0.04,"wisdom":0.025})
		match str(goal.role):
			"child":
				life.adjust(sim,person.key,{"wisdom":0.10})
				goal.outcome="Education adds 10 wisdom points and strengthens future work."
			"farmer":
				town.food+=12;goal.outcome="The community receives 12 stored food."
			"scholar","prophet":
				town.research+=12;goal.outcome="Shared knowledge adds 12 community research."
			"healer":
				town.health=minf(1,town.health+0.015);goal.outcome="The clinic improves community health by up to 1.5 points."
			"guard","judge":
				town.fear=maxf(0,town.fear-0.015);goal.outcome="Safer streets reduce community fear by up to 1.5 points."
			_:
				town.wealth+=5;record.money=float(record.get("money",0))+3;goal.outcome="Completed work adds 5 community wealth and 3 household wealth."
		life.remember(sim,person.key,"A goal fulfilled",str(goal.title)+". "+str(goal.outcome))
	elif year>=int(goal.deadline):
		goal.status="setback";goal.finished=year;goal.outcome="This attempt could not be completed. A new project begins after three years."
		life.remember(sim,person.key,"A project set back",str(goal.title)+". "+str(goal.outcome))
