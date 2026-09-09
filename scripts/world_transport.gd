extends RefCounted
## Annual economy missions are persisted. Rendering never changes resources or RNG.
const WATER=0.36
const LIMIT=96
# A small local flood fill, once per town/year. Never run path finding per frame.
static func fishing_route(sim,port:Array)->Array:
	if port.size()!=2: return []
	var width=int(sim.state.width); var first=int(port[1])*width+int(port[0])
	if sim.get_tile(int(port[0]),int(port[1])).get("elevation",1.0)>=WATER: return []
	var queue=[first]; var parents={first:-1}; var cursor=0; var target=first
	while cursor<queue.size() and cursor<192:
		var key=int(queue[cursor]);cursor+=1;target=key
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var x=key%width+d.x;var y=key/width+d.y
			if absi(x-int(port[0]))>8 or absi(y-int(port[1]))>8: continue
			var next=y*width+x;var tile=sim.get_tile(x,y)
			if parents.has(next) or tile.is_empty() or tile.elevation>=WATER: continue
			parents[next]=key;queue.append(next)
	var path=[]
	while target>=0: path.append([target%width,target/width]);target=int(parents[target])
	path.reverse()
	return path
static func upgrade_routes(sim):
	# Extend old one-tile fishing missions on load without granting any harvest.
	for mission in sim.state.get("transport",{}).get("missions",[]):
		if mission.kind=="fishing" and mission.path.size()<=2 and not mission.path.is_empty():
			var route=fishing_route(sim,mission.path[0])
			if route.size()>mission.path.size(): mission.path=route
static func coast(sim,town)->Array:
	for radius in range(1,9):
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				if absi(dx)!=radius and absi(dy)!=radius: continue
				var x=int(town.x)+dx; var y=int(town.y)+dy
				var tile=sim.get_tile(x,y)
				if not tile.is_empty() and tile.elevation<WATER:
					for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var adjacent=sim.get_tile(x+d.x,y+d.y)
						if not adjacent.is_empty() and adjacent.elevation>=WATER: return [x,y]
	return []
static func sea_path(sim,start:Array,finish:Array,yield_callback:Callable=Callable())->Array:
	var epoch=sim.generation
	if start.size()!=2 or finish.size()!=2: return []
	var width=int(sim.state.width)
	var first=int(start[1])*width+int(start[0]); var target=int(finish[1])*width+int(finish[0])
	var queue=[first]; var parents={first:-1}; var cursor=0
	while cursor<queue.size() and cursor<12000:
		if yield_callback.is_valid() and cursor%128==127:
			if not await yield_callback.call() or sim.generation!=epoch: return []
		var key=int(queue[cursor]); cursor+=1
		if key==target:
			var path=[]
			while key>=0: path.append([key%width,key/width]); key=int(parents[key])
			path.reverse()
			return path
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var x=key%width+d.x; var y=key/width+d.y
			var tile=sim.get_tile(x,y); var next=y*width+x
			if tile.is_empty() or tile.elevation>=WATER or parents.has(next): continue
			parents[next]=key; queue.append(next)
	return []
static func annual(sim,yield_callback:Callable=Callable()):
	var epoch=sim.generation
	var missions=[]; var ports={}
	for town in sim.state.settlements:
		if yield_callback.is_valid():
			if not await yield_callback.call() or sim.generation!=epoch: return false
		if town.population<=0: continue
		var port=coast(sim,town); ports[int(town.id)]=port
		if not port.is_empty() and town.era>=1:
			var route=fishing_route(sim,port)
			var harvest=minf(6,town.population*0.025)*(1.5 if town.era>=8 else 1.0)
			town.food+=harvest; town["fishing_harvest"]=harvest
			if route.size()>2 and missions.size()<LIMIT: missions.append(_mission("fishing",town,route,harvest))
		else: town["fishing_harvest"]=0.0
		if town.era>=9 and missions.size()<LIMIT:
			var loop=[[int(town.x)-6,int(town.y)-3],[int(town.x)+6,int(town.y)-3],[int(town.x)+6,int(town.y)+3],[int(town.x)-6,int(town.y)+3],[int(town.x)-6,int(town.y)-3]]
			missions.append(_mission("plane",town,loop))
			if town.era>=10 and missions.size()<LIMIT: missions.append(_mission("helicopter",town,[[town.x-2,town.y],[town.x+3,town.y+2],[town.x-2,town.y]]))
			if town.era>=13 and "spaceport" in town.buildings and missions.size()<LIMIT: missions.append(_mission("rocket",town,[[town.x+2,town.y],[town.x+2,town.y-20]]))
	# Cap path finding independently of world age or population.
	var sea_searches=0
	for war in sim.state.wars:
		if sea_searches>=6: break
		war["theater"]="land"
		var a=sim._nation_front(int(war.a),int(war.b)); var b=sim._nation_front(int(war.b),int(war.a))
		if a.is_empty() or b.is_empty() or mini(a.era,b.era)<2 or sim._land_connection(a,b): continue
		var path=[]
		if yield_callback.is_valid(): path=await sea_path(sim,ports.get(int(a.id),[]),ports.get(int(b.id),[]),yield_callback)
		else: path=await sea_path(sim,ports.get(int(a.id),[]),ports.get(int(b.id),[]))
		if sim.generation!=epoch: return false
		sea_searches+=1
		if path.size()<2: continue
		war["theater"]="sea"
		for town in [a,b]:
			var route=path.duplicate(true)
			if town.id==b.id: route.reverse()
			if missions.size()<LIMIT:
				var mission=_mission("naval",town,route)
				mission["enemy"]=int(b.nation if town.id==a.id else a.nation); missions.append(mission)
	for route in sim.state.trade_routes:
		if sea_searches>=12 or missions.size()>=LIMIT: break
		var a=sim.get_settlement(int(route.a)); var b=sim.get_settlement(int(route.b))
		if a.is_empty() or b.is_empty() or sim._at_war(a.nation,b.nation) or mini(a.era,b.era)<7 or sim._land_connection(a,b): continue
		sea_searches+=1
		var path=[]
		if yield_callback.is_valid(): path=await sea_path(sim,ports.get(int(a.id),[]),ports.get(int(b.id),[]),yield_callback)
		else: path=await sea_path(sim,ports.get(int(a.id),[]),ports.get(int(b.id),[]))
		if sim.generation!=epoch: return false
		if path.size()>1: missions.append(_mission("cargo",a,path,float(route.food)))
	if yield_callback.is_valid():
		if not await yield_callback.call() or sim.generation!=epoch: return false
	sim.state["transport"]={"year":int(sim.state.year),"missions":missions}
	return true
static func _mission(kind,town,path,cargo=0.0)->Dictionary:
	return {"kind":kind,"town":int(town.id),"nation":int(town.nation),"era":int(town.era),"path":path,"cargo":float(cargo)}
static func position_at(mission,time:float)->Vector2:
	var path=mission.get("path",[])
	if path.is_empty(): return Vector2.ZERO
	var air=mission.kind in ["plane","helicopter","rocket"]
	var fraction=fposmod(time*0.045+float(mission.town)*0.173,1.0)*(path.size()-1)
	if not air:
		# Water paths have adjacent tiles: travel at tiles/second, not an almost
		# imperceptible percentage of a tiny route. Retrace the same path at sea.
		var span=maxf(1,path.size()-1)
		var speed=0.65 if mission.kind=="fishing" else (1.1 if mission.kind=="cargo" else 0.9)
		var distance=fposmod(time*speed+float(mission.town)*0.173*span,span*2)
		fraction=minf(path.size()-1,span-absf(distance-span))
	var index=mini(int(fraction),path.size()-1); var next=mini(index+1,path.size()-1)
	return (Vector2(path[index][0],path[index][1]).lerp(Vector2(path[next][0],path[next][1]),fraction-index)+Vector2.ONE*0.5)*8

func draw(view,time:float):
	for m in view.sim.state.get("transport",{}).get("missions",[]):
		var p=position_at(m,time)
		var heading=(position_at(m,time+0.1)-p).normalized()
		if not view._visible(Rect2(p-Vector2(25,25),Vector2(50,50))): continue
		var flag=view._nation_colors.get(int(m.nation),Color("dab96f"))
		var air=m.kind in ["plane","helicopter","rocket"]
		if air: _aircraft(view,p,m,flag,time)
		elif not view._is_land(int(p.x/8),int(p.y/8)):
			if m.kind=="naval":
				view.people._ship(view,p,int(m.era),flag,-1 if heading.x<0 else 1,time)
				if fposmod(time*1.6+float(m.town),1)<0.18:
					view.draw_rect(Rect2(p+Vector2(7,-4),Vector2(2,1)),Color("ffdc80"))
					view.draw_line(p+Vector2(8,-4),p+Vector2(14,-3),Color("f7d79b"),0.5)
			else:
				view._draw_close_ship(p,int(m.era),flag)
				if m.kind=="fishing":
					for i in range(4): view.draw_line(p+Vector2(5+i,-1),p+Vector2(9+i,3),Color("baa77c"),0.25)
					view.draw_rect(Rect2(p+Vector2(-1,-2),Vector2(2,1)),Color("9fcbd0"))
				elif m.cargo>0:
					for i in range(3): view.draw_rect(Rect2(p+Vector2(-3+i*2,-3),Vector2(1.5,1.5)),Color("bf9a61"))
			view.draw_line(p-heading*7+Vector2(0,3),p-heading*15+heading.orthogonal()*sin(time*3)+Vector2(0,3),Color(0.8,0.95,0.94,0.45),0.5)

func _aircraft(view,p,m,flag,time):
	var ink=Color("253438"); var metal=Color("abbcbb"); var light=Color("e4ebe0")
	p=p.snapped(Vector2.ONE*0.25)
	view.draw_rect(Rect2(p+Vector2(-6,8),Vector2(12,1)),Color(0.05,0.08,0.10,0.18))
	if m.kind=="rocket":
		view.draw_rect(Rect2(p+Vector2(-2,-8),Vector2(4,12)),ink)
		view.draw_rect(Rect2(p+Vector2(-1.5,-7),Vector2(3,10)),light)
		view.draw_rect(Rect2(p+Vector2(-1,-9),Vector2(2,2)),flag)
		view.draw_rect(Rect2(p+Vector2(-3,0),Vector2(6,3)),metal)
		view.draw_rect(Rect2(p+Vector2(-1,3),Vector2(2,4+sin(time*30))),Color("ffb554"))
		view.draw_rect(Rect2(p+Vector2(-0.5,3),Vector2(1,2)),Color("fff2bd"))
		for i in range(5): view.draw_rect(Rect2(p+Vector2(-1-i*0.2,8+i*3),Vector2(2+i*0.4,2)),Color(0.8,0.86,0.86,0.4-i*0.06))
	elif m.kind=="helicopter":
		view.draw_rect(Rect2(p+Vector2(-4,-3),Vector2(8,5)),ink)
		view.draw_rect(Rect2(p+Vector2(-3.5,-2.5),Vector2(7,4)),flag.lerp(metal,0.5))
		view.draw_rect(Rect2(p+Vector2(1,-2.5),Vector2(2.5,2)),Color("6ca9ba"))
		view.draw_rect(Rect2(p+Vector2(-11,-1),Vector2(7,1)),metal)
		view.draw_line(p+Vector2(-11,-3),p+Vector2(-11,1),light,0.5)
		view.draw_line(p+Vector2(-4,3),p+Vector2(4,3),ink,0.5)
		var rotor=Vector2(cos(time*35),sin(time*35)*0.3)*11
		view.draw_line(p-Vector2(0,4)-rotor,p-Vector2(0,4)+rotor,light,0.5)
	else:
		view.draw_rect(Rect2(p+Vector2(-9,-1),Vector2(18,3)),ink)
		view.draw_rect(Rect2(p+Vector2(-8,-1),Vector2(16,2)),metal)
		view.draw_rect(Rect2(p+Vector2(-2,-8),Vector2(4,16)),ink)
		view.draw_rect(Rect2(p+Vector2(-1.5,-7.5),Vector2(3,15)),flag if int(m.era)==9 else light)
		view.draw_rect(Rect2(p+Vector2(3,-1),Vector2(3,1.5)),Color("6396ac"))
		view.draw_rect(Rect2(p+Vector2(-7,-4),Vector2(2,8)),flag)
		if int(m.era)==9:
			view.draw_line(p+Vector2(8,-4),p+Vector2(8,4),Color(0.8,0.9,0.9,0.65),0.5)
			view.draw_rect(Rect2(p+Vector2(-1,-6),Vector2(2,12)),Color("b89c67"))
		else: view.draw_line(p+Vector2(-10,0),p+Vector2(-22,0),Color(0.9,0.95,1,0.35),0.5)
