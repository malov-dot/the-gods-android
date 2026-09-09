extends RefCounted
## Presentation reads current personal state, never scans world history or consumes RNG.
const ACTIONS={
	"resurrect_person":["Returned to life","+","e7d4ff","Return this same deceased person with their memories and family. Cure illness and afflictions. Old age is held back for twenty years; existing marriages and inherited property remain."],
	"heal_person":["Healed","+","72edb1","Cure illness. Add up to 60 health and 12 happiness points."],
	"infernal_cure":["Infernal healing","+","f4a979","Cure illness. Add up to 60 health, 12 happiness and 8 Devil belief points."],
	"curse_person":["Cursed","X","c18aff","For 8 years, reduce health by 27 and happiness by 22 points. Add 15 resentment now."],
	"possess_person":["Possessed","!","ff746d","Possess for 8 years: -25 honor and +15 resentment. Officials may impose repression; others may commit crimes."],
	"purify_person":["Released","O","c2f6ee","End this person's curse and possession immediately. Past crimes remain."],
	"bribe_person":["Bribe offered","$","edc66b","Offer an official 40 private wealth. An accepted bribe creates a 16-year law favoring merchants; honorable officials refuse."],
	"pardon_person":["Pardoned","U","81dfd3","Release from prison and clear wanted status. +10 honor, -10 resentment; living victims gain 15 resentment."],
	"reveal_person":["Deeds exposed","?","f5e29b","Report hidden crimes and expose bribery or possession. No evidence means no accusation."],
	"comfort_person":["Comforted","H","f4add1","End grief. Remove up to 35 resentment; add 8 honor and 12 empathy points."],
	"teach_person":["Taught","B","8fcbff","Add up to 20 wisdom and 8 leadership points."],
	"promise_mercy":["Mercy promised","V","90ebd1","Accept a family bargain. Heal the named relative within 8 years; an honest official then supports public relief."],
	"promise_cruelty":["Dark bargain","V","e395d4","Accept a dark bargain. Heal the named relative within 8 years; the adult may then enact repression or commit a crime."],
	"inspire_person":["Inspired","*","9ecaff","Add up to 22 wisdom, 8 leadership and 10 happiness points. Boost this person's community contribution for 12 years."],
	"bless_person":["Blessed","^","ffe293","Raise loyalty, standing and God belief; reduce Devil belief. Spread faith through this person for 12 years."],
	"tempt_person":["Tempted","$","eabb73","Raise ambition and Devil belief; lower God belief and honor. Boost community wealth and corruption for 12 years."],
	"corrupt_person":["Corrupted","X","c29cdb","Raise Devil belief; lower God belief, loyalty and honor. Spread corruption for 12 years."],
	"incite_person":["Incited","!","ffa17c","Raise ambition, strength, courage and resentment; lower loyalty and happiness. Increase community aggression for 12 years."]
}
static func description(action:String)->String: return str(ACTIONS.get(action,["","","",""])[3])
static func badge(action:String,label:String="",remaining:int=0)->Dictionary:
	var data=ACTIONS.get(action,["Changed","*","d1e6e0",""])
	return {"action":action,"label":str(data[0]) if label.is_empty() else label,"symbol":str(data[1]),"color":Color(str(data[2])),"remaining":remaining}
static func markers(sim,person:Dictionary)->Array:
	var result=[]
	if person.is_empty() or not person.get("alive",false): return result
	var registry=sim.state.get("citizens",{})
	var key=str(registry.get("named",{}).get(str(person.key),str(person.key)))
	var edit=registry.get("overrides",{}).get(key,{})
	var life=edit.get("life",{}); var year=int(sim.state.year)
	for item in [["possessed_until","possess_person"],["curse_until","curse_person"]]:
		var remaining=int(life.get(item[0],0))-year
		if remaining>0: result.append(badge(item[1],"",remaining))
	for effect in edit.get("effects",[]):
		var remaining=int(effect.get("until",0))-year
		if remaining>0: result.append(badge(str(effect.action),"",remaining))
	# Instant actions remain identifiable as the LAST action, not a false ongoing buff.
	var recent=edit.get("last_intervention",{})
	if recent is Dictionary and ACTIONS.has(str(recent.get("action",""))) and not result.any(func(m):return m.action==recent.action):
		var last=badge(str(recent.action),"Last: "+str(recent.get("label",ACTIONS[recent.action][0]))+" · year "+str(int(recent.get("year",year))))
		if recent.action in ["curse_person","possess_person","heal_person","inspire_person","bless_person","tempt_person","corrupt_person","incite_person"]:
			last.symbol="o";last.color=Color("9aaeb4");last.label+=" · effect ended"
		result.append(last)
	return result
static func record(sim,key:String,action:String,message:String):
	if not sim.state.has("citizens"): return
	var registry=sim.state.citizens
	key=str(registry.named.get(key,key))
	if not registry.overrides.has(key): registry.overrides[key]={}
	var label=str(ACTIONS[action][0])
	if action=="bribe_person": label="Bribe refused" if "refuses" in message else "Guild Privileges passed"
	if action=="reveal_person" and message.begins_with("No hidden"): label="No hidden crime found"
	registry.overrides[key]["last_intervention"]={"action":action,"label":label,"year":int(sim.state.year),"message":message}
static func draw(view,p:Vector2,person:Dictionary):
	var items=markers(view.sim,person)
	if items.is_empty(): return
	var count=mini(3,items.size())
	var scale_=clampf(2.0/maxf(view.zoom,0.1),0.55,2.0)
	var first=items[0]; var color=first.color
	view.draw_arc(p+Vector2(0,0.5),4.4+sin(view._time*3)*0.35,0,TAU,16,Color(color,0.7),0.5)
	if view.zoom<1.2: return
	for i in range(count):
		var mark=items[i]; var at=p+Vector2((i-(count-1)*0.5)*7*scale_,-15)
		view.draw_rect(Rect2(at-Vector2(3,3)*scale_,Vector2(6,6)*scale_),Color("17212b"))
		view.draw_rect(Rect2(at-Vector2(3,3)*scale_,Vector2(6,6)*scale_),mark.color,false,0.4)
		view.draw_string(ThemeDB.fallback_font,at+Vector2(-2,2)*scale_,mark.symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(4,int(6*scale_)),mark.color)
	if first.action=="possess_person" and first.remaining>0:
		for x in [-1.2,1.2]: view.draw_rect(Rect2(p+Vector2(x,-8),Vector2(0.8,0.5)),color)
	elif first.action=="curse_person" and first.remaining>0:
		for i in range(3):
			var at=p+Vector2(sin(view._time*2+i*2)*4,-fposmod(view._time*3+i*3,11))
			view.draw_rect(Rect2(at,Vector2(0.6,1.2)),color)
