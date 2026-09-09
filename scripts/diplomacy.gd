extends RefCounted
## Bilateral agreements have gameplay effects and finite terms.
static func pact(sim,a:int,b:int)->Dictionary:
	for treaty in sim.state.get("treaties",[]):
		if int(treaty.until)>int(sim.state.year) and ((int(treaty.a)==a and int(treaty.b)==b) or (int(treaty.a)==b and int(treaty.b)==a)): return treaty
	return {}
static func sign_agreement(sim,a:int,b:int,kind:String,years:int,place:Dictionary={}):
	if a==b: return
	var treaties=sim.state.get("treaties",[])
	treaties=treaties.filter(func(t):return not ((int(t.a)==a and int(t.b)==b) or (int(t.a)==b and int(t.b)==a)))
	treaties.append({"a":a,"b":b,"kind":kind,"since":int(sim.state.year),"until":int(sim.state.year)+years})
	sim.state["treaties"]=treaties
	sim.add_event(("An alliance is formed" if kind=="alliance" else "A peace treaty is signed"),"%s and %s agree to %d years of %s. %s"%[sim._nation_name(a),sim._nation_name(b),years,"alliance" if kind=="alliance" else "peace","They will not attack one another; allied trade brings extra prosperity." if kind=="alliance" else "Their armies stand down and trade can resume."],"diplomacy",int(place.get("x",-1)),int(place.get("y",-1)),["Nations: %d and %d"%[a,b],"Agreement expires in year %d"%(int(sim.state.year)+years)])
static func annual(sim):
	var treaties=sim.state.get("treaties",[])
	for t in treaties:
		if int(t.until)==int(sim.state.year): sim.add_event("An agreement expires","The agreement between %s and %s has reached the end of its term."%[sim._nation_name(t.a),sim._nation_name(t.b)],"diplomacy")
	sim.state["treaties"]=treaties.filter(func(t):return int(t.until)>int(sim.state.year))
	if int(sim.state.year)%20!=0: return
	for route in sim.state.get("trade_routes",[]):
		var a=sim.get_settlement(int(route.a)); var b=sim.get_settlement(int(route.b))
		if a.is_empty() or b.is_empty() or a.nation==b.nation or sim._at_war(a.nation,b.nation) or not pact(sim,a.nation,b.nation).is_empty(): continue
		if minf(a.happiness,b.happiness)>0.6 and absf(a.faith-b.faith)<0.2 and maxf(sim._nation_aggression(a.nation),sim._nation_aggression(b.nation))<0.65:
			sign_agreement(sim,a.nation,b.nation,"alliance",30,a); break
