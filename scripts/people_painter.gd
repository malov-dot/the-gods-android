extends RefCounted
## Human-scale, half-unit pixel artwork. Every army represents an active simulation war.

const INK = Color("253335")
const WOOD = Color("936b42")
const STEEL = Color("bdced1")
const GOLD = Color("edc566")
const SKINS = [Color("ecc49a"), Color("cb966c"), Color("a96e4f"), Color("794c39"), Color("d9ab7e")]
const HAIRS = [Color("3d302b"), Color("655040"), Color("bb9358"), Color("b4b5aa"), Color("382c2b")]
const CLOTHES = [Color("bdad79"), Color("779986"), Color("97758a"), Color("b47661"), Color("668597")]
const WEAPONS = ["Flint spears and hide shields", "Hunting bows and spears", "Bronze swords and round shields", "Iron spears and swords", "Legion shields and javelins", "Longbows, swords and siege engines", "Pikes, muskets and cannon", "Flintlock muskets and sailing fleets", "Repeating rifles and field artillery", "Rifles, helmets and tanks", "Assault rifles and armored vehicles", "Optics, body armor and drones", "Plasma rifles and combat drones", "Powered suits, energy weapons and hover armor"]
const STREET_ROUTES = [
	[Vector2.ZERO, Vector2(-36, 0), Vector2(36, 0), Vector2.ZERO],
	[Vector2.ZERO, Vector2(0, -36), Vector2(0, 36), Vector2.ZERO],
	[Vector2.ZERO, Vector2(-24, 0), Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24), Vector2(-24, 0), Vector2.ZERO],
	[Vector2.ZERO, Vector2(-24, 0), Vector2(-24, 24), Vector2(0, 24), Vector2.ZERO],
	[Vector2.ZERO, Vector2(24, 0), Vector2(24, -24), Vector2(0, -24), Vector2.ZERO]
]
var _role_cache_stamp = ""
var _role_cache = {}
var _frame_role_people = {}
var _collecting_wars = false
var _war_slots = {}
var high_detail=false
var sprite_art=preload("res://scripts/sprite_people.gd").new()


func role_people(sim,town_id:int,role:String,limit:int=16) -> Array:
	if sim==null or not sim.has_method("get_individual"): return []
	var stamp=str(sim.get_instance_id())+":"+str(sim.state.get("seed",""))+":"+str(sim.state.get("year",0))+":"+str(sim.state.get("citizens",{}).get("revision",0))
	if stamp!=_role_cache_stamp:
		_role_cache_stamp=stamp
		_role_cache.clear()
		_frame_role_people.clear()
	var bucket=str(town_id)+":"+role+":"+str(limit)
	if _frame_role_people.has(bucket): return _frame_role_people[bucket]
	if not _role_cache.has(bucket):
		var keys=[]
		if sim.has_method("role_keys"):
			keys=sim.role_keys(town_id,role,limit)
		elif sim.has_method("resident_page"):
			for person in sim.resident_page(town_id,0,limit,role).get("people",[]): keys.append(str(person.key))
		_role_cache[bucket]=keys
	var result=[]
	for key in _role_cache[bucket]:
		var person=sim.get_individual(str(key))
		if not person.is_empty() and person.get("alive",false) and person.get("location","surface")=="surface" and int(person.get("settlement",-1))==town_id and str(person.get("role",""))==role:
			result.append(person)
	_frame_role_people[bucket]=result
	return result


func prepare_wars(view,sim,time:float,zoom:float):
	_war_slots.clear()
	_frame_role_people.clear()
	if not view.has_method("reserve_person") or not sim.has_method("get_individual"): return
	# Reserve only soldiers whose current position will actually be drawn. Their
	# civilian sprite is suppressed for this frame, preventing duplicate people.
	_collecting_wars=true
	draw_wars(view,sim,time,zoom)
	_collecting_wars=false


func _military_member(view,sim,town,slot:String,p,era,flag,seed,role,face,phase,activity,zoom):
	if not view.has_method("draw_identified_person") or not sim.has_method("get_individual"):
		if not _collecting_wars:
			if zoom>=1.6: draw_person(view,p,era,flag,seed,role,face,phase,activity)
			else: view._draw_person(p,flag,seed)
		return
	if _collecting_wars:
		var guards=role_people(sim,int(town.id),"guard",16)
		var roster_index=int(slot.get_slice(":",3))+(12 if slot.get_slice(":",2)=="m" else 0)
		if roster_index>=guards.size(): return
		var individual=guards[roster_index]
		if view.person_elsewhere(str(individual.key)): return
		_war_slots[slot]=str(individual.key)
		view.reserve_person(str(individual.key),p,"war")
		return
	var key=str(_war_slots.get(slot,""))
	if key.is_empty(): return
	var individual=sim.get_individual(key)
	view.draw_identified_person(individual,p,era,flag,role,face,phase,activity,1.6)


func weapon_name(era: int) -> String:
	return WEAPONS[clampi(era, 0, WEAPONS.size() - 1)]


func citizens(view, town: Dictionary, center: Vector2, time: float) -> Array:
	var result = []
	var population = maxf(0.0, float(town.get("population", 0.0)))
	if population <= 0.0 or not view._visible(Rect2(center - Vector2(52, 60), Vector2(104, 112))): return result
	var count = mini(ceili(population), clampi(8 + int(sqrt(population) * 0.52), 8, 24))
	var town_id = int(town.get("id", 0))
	var era = clampi(int(town.get("era", 0)), 0, 13)
	var flag = view._nation_colors.get(int(town.get("nation", -1)), Color("b7ad70"))
	var roles = ["farmer", "worker", "citizen", "scholar", "guard", "citizen", "farmer", "worker"]
	var selected_key = str(view.get("selected_person_key") if view.get("selected_person_key")!=null else "")
	var actual_people = []
	var has_registry = view.sim!=null and view.sim.has_method("individual_keys") and view.sim.has_method("get_individual")
	if has_registry:
		for key in view.sim.individual_keys(town_id,count,selected_key):
			var individual = view.sim.get_individual(str(key))
			if individual.is_empty() or not individual.get("alive",false) or individual.get("location","surface")!="surface": continue
			if int(individual.get("settlement",-1))!=town_id: continue
			actual_people.append(individual)
		count = mini(count,actual_people.size())
	var year = int(view.sim.state.get("year", 0)) if view.sim != null else 0
	var active_danger = year <= int(town.get("visual_disaster_until", -1)) and str(town.get("visual_disaster", "")) in ["fire", "meteor", "earthquake", "volcano", "storm", "ice", "atomic", "battle"]
	var safe_routes = []
	for route in STREET_ROUTES: safe_routes.append(_safe_street_route(view, center, route,town))
	var named = []
	if view.sim != null and not has_registry:
		var leader = view.sim.get_person(int(town.get("leader", -1)))
		if not leader.is_empty() and leader.get("alive", false): named.append(leader)
		for person in view.sim.state.get("people", []):
			if person.get("alive", false) and int(person.get("settlement", -1)) == town_id and person.get("role", "") == "prophet":
				named.append(person)
				break
	for i in range(count):
		var seed = absi(town_id * 31 + i * 107)
		var role = str(roles[(i + town_id) % roles.size()])
		var person_name = ""
		var person_key = ""
		var individual = {}
		if has_registry:
			individual = actual_people[i]
			seed = absi(int(individual.get("portrait_seed",seed)))
			role = str(individual.get("role","citizen"))
			person_name = str(individual.get("name",""))
			person_key = str(individual.get("key",""))
		elif i < named.size():
			role = "prophet" if named[i].get("role", "") == "prophet" else "leader"
			seed = int(named[i].get("id", seed))
			person_name = str(named[i].get("name", ""))
		# Foot routes use the street grid shared by the settlement painter.
		var route = safe_routes[seed % safe_routes.size()]
		if route.size() < 2:
			if person_key==selected_key and not person_key.is_empty() and _citizen_allowed(view,center,town): route=[Vector2.ZERO,Vector2.ZERO]
			else: continue
		var activity = "walking"
		var speed = 1.4 + float(seed % 7) * 0.16
		if active_danger and float(town.get("visual_damage", 0.0)) > 0.025:
			activity = "fleeing"
			speed *= 2.25
		elif float(individual.get("health",1.0))<0.35 or (int(town.get("plague", 0)) > 0 and seed % 4 == 1):
			activity = "ill"
			speed *= 0.35
		elif int(town.get("drought", 0)) > 0 and role == "farmer":
			activity = "weary"
			speed *= 0.55
		var route_length = 0.0
		for k in range(route.size()): route_length += route[k].distance_to(route[(k + 1) % route.size()])
		var distance = fposmod(time * speed + float(seed % 191), maxf(route_length,0.01))
		var relative = route[0]
		var movement = Vector2.RIGHT
		for k in range(route.size()):
			var start = route[k]
			var finish = route[(k + 1) % route.size()]
			var length = start.distance_to(finish)
			if distance <= length:
				relative = start.lerp(finish, distance / maxf(length, 0.01))
				movement = (finish - start).normalized()
				break
			distance -= length
		var p = center + relative + Vector2(0, float(seed % 3 - 1))
		if not _citizen_allowed(view,p,town): p = center + relative
		if not _citizen_allowed(view,p,town): continue
		if not _on_screen(view, p, 12.0) and (person_key.is_empty() or person_key!=selected_key): continue
		result.append({"position":p, "era":era, "flag":flag, "seed":seed, "role":role,
			"direction":movement.x if absf(movement.x) > 0.01 else (1.0 if seed % 2 == 0 else -1.0),
			"phase":time * speed * 2.4 + float(seed), "activity":activity, "name":person_name,"key":person_key,"individual":individual,"height":6.5 if role=="child" else 8.5})
	return result


func _safe_street_route(view, center, route,town:Dictionary={}) -> Array:
	# Stop at the first broken street and return over the same connected route.
	# Shrinking a coastal position toward the square would cut across house plots.
	if not _citizen_allowed(view,center,town): return []
	var points = [Vector2.ZERO]
	for i in range(1, route.size()):
		var start = points[-1]
		var finish = route[i]
		var steps = maxi(1, ceili(start.distance_to(finish) / 2.0))
		var last_safe = start
		var blocked = false
		for step in range(1, steps + 1):
			var candidate = start.lerp(finish, float(step) / float(steps))
			if not _citizen_allowed(view,center+candidate,town):
				blocked = true
				break
			last_safe = candidate
		if last_safe.distance_squared_to(start) > 0.01: points.append(last_safe)
		if blocked: break
	if points.size() > 1 and points[-1].distance_squared_to(points[0]) > 0.01:
		for i in range(points.size() - 2, -1, -1): points.append(points[i])
	return points


func _citizen_allowed(view,p:Vector2,town:Dictionary) -> bool:
	if not _land(view,p): return false
	return town.is_empty() or not view.has_method("_detail_owns_position") or view._detail_owns_position(town,p)


func draw_person(view, p: Vector2, era: int, flag: Color, seed: int, role: String, direction: float, phase: float, activity: String):
	if role=="child" and not high_detail:
		_draw_child(view,p,flag,absi(seed),direction,phase,activity)
		return
	if role in ["ruler","monarch","governor"]: role="leader"
	elif role in ["healer","doctor","physician","scientist","teacher"]: role="scholar"
	elif role in ["general","captain","officer"]: role="guard"
	elif role in ["priest","cleric"]: role="prophet"
	elif role in ["engineer","artisan","merchant","builder","miner"]: role="worker"
	if high_detail:
		var walking=activity in ["walk","walking","fleeing","marching","fighting"]
		var frame=int(phase*1.4)%4 if walking else 0
		var sprite=sprite_art.texture(clampi(era,0,13),flag,absi(seed),role,frame,activity=="ill",direction)
		var dimensions=Vector2(8,12)*(0.72 if role=="child" else 1.0)
		view.draw_texture_rect(sprite,Rect2(p+Vector2(-dimensions.x/2,-dimensions.y+1),dimensions),false)
		return
	era = clampi(era, 0, 13)
	seed = absi(seed)
	p = (p * 2.0).round() * 0.5
	var facing = 1.0 if direction >= 0.0 else -1.0
	var marching = activity in ["walk", "walking", "fleeing", "marching"]
	var stride = (0.5 if sin(phase) > 0.0 else -0.5) if marching else 0.0
	var bob = -0.5 if marching and sin(phase * 2.0) > 0.45 else 0.0
	var sick = activity == "ill"
	var skin = SKINS[seed % SKINS.size()]
	if sick: skin = skin.lerp(Color("b5b27a"), 0.52)
	var hair = HAIRS[(seed / 5) % HAIRS.size()]
	var cloth = CLOTHES[(seed / 7) % CLOTHES.size()].lerp(flag, 0.20)
	var military = role in ["guard", "soldier", "archer", "banner"]
	if military: cloth = flag.lerp(Color("a7ad83") if era >= 8 else Color("bcbaa5"), 0.25)
	if era == 0: cloth = Color("af9872")
	if role == "scholar": cloth = Color("bdb5a0") if era < 8 else Color("d7dbca")
	if role == "prophet": cloth = Color("e6d9b0")
	if role == "leader": cloth = flag.darkened(0.25) if era < 8 else Color("344956")
	var trousers = Color("6b6554") if era < 8 else Color("3d5260")
	if military and era >= 9: trousers = Color("65725c")
	var body = p + Vector2(0, bob + (0.5 if sick else 0.0))
	# Ground shadow, distinct boots and legs, then the outlined torso.
	_block(view, p, -2.0, -0.5, 4.5, 1, Color(0.08, 0.16, 0.14, 0.23))
	_block(view, p, -1.5, -3.0, 1.0, 2.5 + stride, INK)
	_block(view, p, 0.5, -3.0, 1.0, 2.5 - stride, INK)
	_block(view, p, -1.0, -3.0, 0.5, 2.0 + stride, trousers)
	_block(view, p, 0.5, -3.0, 0.5, 2.0 - stride, trousers.lightened(0.10))
	_block(view, p, -1.5 + minf(0.0, facing * 0.5), -0.5 + stride, 1.5, 0.5, Color("392f2c"))
	_block(view, p, 0.5 + minf(0.0, facing * 0.5), -0.5 - stride, 1.5, 0.5, Color("392f2c"))
	if role in ["leader", "prophet"] and era < 8:
		_block(view, body, -2.0, -5.5, 4.0, 4.5, cloth.darkened(0.30))
		_block(view, body, -1.5, -4.5, 3.0, 3.0, cloth)
	_block(view, body, -1.5, -6, 3.0, 3.5, INK)
	_block(view, body, -1.0, -5.5, 2.0, 2.5, cloth)
	_block(view, body, -1.0, -5.5, 0.5, 2.0, cloth.lightened(0.18))
	_block(view, body, -1.0, -3.5, 2.0, 0.5, Color("59473b"))
	_block(view, body, 0.0, -3.5, 0.5, 0.5, GOLD)
	if era == 0:
		_block(view, body, -1.0, -5.5, 1.0, 1.5, skin)
	elif era >= 12:
		_block(view, body, -1.5, -5.5, 3.0, 1.0, STEEL)
		_block(view, body, -0.5, -4.5, 1.0, 0.5, Color("8ce5dc"))
	elif military and era >= 2:
		var armor = Color("b98953") if era == 2 else STEEL.darkened(0.25)
		if era >= 9: armor = Color("4c6253")
		_block(view, body, -1.0, -5.5, 2.0, 1.5, armor)
		_block(view, body, -1.0, -5.5, 0.5, 1.5, armor.lightened(0.2))
		_block(view, body, -1.0, -4.0, 2.0, 0.5, flag)
	elif role == "worker":
		_block(view, body, -0.5, -5, 1.5, 2.0, Color("76624b"))
	elif role == "leader" and era >= 8:
		_block(view, body, -0.5, -5.5, 1, 1.5, Color("e1d9bf"))
		_block(view, body, 0.0, -5.0, 0.5, 1.5, flag)
	# Neck, hair outline and a readable face, with eye / nose / cheek pixels.
	_block(view, body, -0.5, -6.5, 1, 1, skin.darkened(0.14))
	_block(view, body, -1.5, -8.5, 3.0, 2.5, hair)
	_block(view, body, -1.0, -8, 2.0, 2.0, skin)
	_block(view, body, -1.0, -8, 2.0, 0.5, hair)
	_block(view, body, -1.0, -8, 0.5, 1.0, hair)
	_block(view, body, -0.5 + facing * 0.5, -7.5, 0.5, 0.5, INK)
	_block(view, body, facing * 1.0 - 0.5, -7.0, 0.5, 0.5, skin.lightened(0.13))
	_block(view, body, 0.0, -6.5, 0.5, 0.5, skin.darkened(0.28))
	# Both arms are visible; the equipped hand is drawn over its tool below.
	var hand_y = -3.5 + (stride if marching else 0.0)
	_block(view, body, -2.0, -5.5, 0.5, 2.0 - stride, cloth.darkened(0.18))
	_block(view, body, -2.0, -3.5 - stride, 0.5, 0.5, skin)
	_block(view, body, 1.5, -5.5, 0.5, 2.0 + stride, cloth)
	_block(view, body, 1.5, hand_y, 0.5, 0.5, skin)
	if role == "farmer":
		_block(view, body, -2, -8.5, 4, 0.5, Color("9d793e"))
		_block(view, body, -1, -9.5, 2, 1, Color("ddbd70"))
		_line(view, body, Vector2(2.5, 0), Vector2(2.5, -6.5), WOOD, 0.5)
		_line(view, body, Vector2(1.5, -6.5), Vector2(4.0, -6.5), STEEL if era >= 2 else Color("8f8e79"), 0.5)
		_block(view, body, 2.0, -4, 1, 0.5, skin)
	elif role == "worker":
		if era >= 8:
			_block(view, body, -1.5, -8.5, 3, 0.5, GOLD)
			_block(view, body, -1, -9, 2, 0.5, Color("e3aa4d"))
		_line(view, body, Vector2(2, -3.5), Vector2(3.5, -6.5), WOOD, 0.5)
		_line(view, body, Vector2(2.5, -7), Vector2(4.5, -6), STEEL, 1)
		_block(view, body, -2.5, -3.5, 1, 1.5, Color("966a43"))
	elif role == "scholar":
		_block(view, body, 1.5, -5.0, 2.5, 2.0, Color("72504c"))
		_block(view, body, 2.0, -4.5, 1.5, 1.0, Color("e3d8ad") if era < 11 else Color("88d8d3"))
		_block(view, body, 2, -3.5, 0.5, 0.5, skin)
		if era >= 6: _block(view, body, -1, -7.5, 2, 0.5, Color("53615f"))
		else: _block(view, body, -1.5, -8.5, 3.0, 0.5, flag.darkened(0.2))
	elif role == "leader":
		if era < 8:
			_block(view, body, -1.5, -9.0, 3.0, 0.5, GOLD)
			for crown_tip in [-1.5, -0.5, 1.0]: _block(view, body, crown_tip, -9.5, 0.5, 1.0, GOLD)
			_block(view, body, -0.5, -9, 0.5, 0.5, flag)
		else:
			_block(view, body, 0.5, -4.5, 0.5, 0.5, GOLD)
	elif role == "prophet":
		_line(view, body, Vector2(2.5, 0), Vector2(2.5, -9.5), WOOD, 0.5)
		_block(view, body, 2.0, -10.0, 1.5, 1.5, GOLD)
		_block(view, body, -1, -6.5, 2, 1, Color("d8d5bf"))
		_block(view, body, 0, -5.5, 0.5, 1, Color("d8d5bf"))
	elif military:
		_helmet(view, body, era, flag, role)
		if role == "banner":
			_line(view, body, Vector2(2.5, 0), Vector2(2.5, -15), WOOD, 0.5)
			_block(view, body, 3, -15, 6, 4, flag.darkened(0.25))
			_block(view, body, 3, -15, 5, 3, flag)
			_block(view, body, 3, -15, 1, 3, flag.lightened(0.3))
			_block(view, body, 5, -14, 1, 1, GOLD)
		else:
			_weapon(view, body, era, flag, seed, role, facing, phase, activity)
	elif seed % 3 == 0:
		_block(view, body, 1.5, -3.5, 2, 1.5, Color("a97e4e"))
		_block(view, body, 2, -4, 1, 0.5, WOOD)
	if activity == "ill":
		_block(view, body, -1, -7.0, 2, 0.5, Color("e2dec1"))
		_block(view, body, 1.5, -5.5, 0.5, 0.5, skin)


func _helmet(view, p, era, flag, role):
	if era <= 1: return
	var metal = Color("bb8d53") if era == 2 else STEEL
	if era >= 8: metal = Color("657964")
	if era >= 12: metal = Color("d6e2df")
	if era in [6, 7]:
		_block(view, p, -2, -8.5, 4, 0.5, INK)
		_block(view, p, -1, -9.5, 2, 1, flag.darkened(0.5))
		_block(view, p, -1.5, -9, 0.5, 1, GOLD)
		return
	if era == 8:
		_block(view, p, -1.5, -9, 3, 1, flag.darkened(0.5))
		_block(view, p, -1.5, -8, 3.5, 0.5, INK)
		return
	_block(view, p, -1.5, -8.5, 3, 1.0, metal.darkened(0.25))
	_block(view, p, -1, -9, 2, 1.0, metal)
	_block(view, p, -1.5, -8, 0.5, 1.5, metal.darkened(0.1))
	if era in [3, 4, 5] and role != "archer":
		_block(view, p, -0.5, -10, 1, 1, flag)
		_block(view, p, 0, -8, 0.5, 1, metal)
	if era >= 12:
		_block(view, p, -1, -8, 2, 1, Color("486278"))
		_block(view, p, -0.5, -8, 1, 0.5, Color("9bf2e5"))


func _draw_child(view,p,flag,seed,facing,phase,activity):
	p=p.snapped(Vector2.ONE*0.5)
	var skin=SKINS[seed%SKINS.size()]
	if activity=="ill": skin=skin.lerp(Color("b5b27a"),0.52)
	var hair=HAIRS[(seed/5)%HAIRS.size()]
	var shirt=CLOTHES[(seed/7)%CLOTHES.size()].lerp(flag,0.16)
	var stride=0.5 if activity in ["walk","walking","fleeing"] and sin(phase)>0 else 0.0
	_block(view,p,-1.5,-0.5,3,1,Color(0.08,0.16,0.14,0.23))
	_block(view,p,-1,-2,0.5,2-stride,INK)
	_block(view,p,0.5,-2,0.5,1.5+stride,INK)
	_block(view,p,-1.5,-0.5-stride,1,0.5,WOOD.darkened(0.3))
	_block(view,p,0.5,-1+stride,1,0.5,WOOD.darkened(0.3))
	_block(view,p,-1.5,-4,3,2.5,INK)
	_block(view,p,-1,-4,2,2,shirt)
	_block(view,p,-1.5,-3.5,0.5,1.5,skin)
	_block(view,p,1,-3.5,0.5,1.5,skin)
	_block(view,p,-1.5,-6.5,3,2.5,hair)
	_block(view,p,-1,-6,2,1.5,skin)
	_block(view,p,-1.5,-6.5,3,0.5,hair.lightened(0.14))
	_block(view,p,0.5 if facing>=0 else -1,-5.5,0.5,0.5,INK)
	_block(view,p,0,-4.5,0.5,0.5,skin.darkened(0.15))


func _weapon(view, p, era, flag, seed, role, facing, phase, activity):
	var fighting = activity == "fighting"
	var tip = Vector2(facing * 5.5, -5.0)
	var h = Vector2(facing * 1.5, -4.0)
	if era <= 4 or era == 5:
		var bow = role == "archer" or (era >= 1 and seed % 4 == 1)
		if bow:
			var bx = facing * 2.5
			_line(view, p, Vector2(bx, -7), Vector2(bx + facing, -5.5), WOOD, 0.5)
			_line(view, p, Vector2(bx + facing, -5.5), Vector2(bx, -3), WOOD, 0.5)
			_line(view, p, Vector2(bx, -7), Vector2(bx, -3), Color("d8cda6"), 0.5)
			_line(view, p, Vector2(bx - facing, -5), Vector2(bx + facing * 3, -5), WOOD, 0.5)
			_block(view, p, bx + facing * 2.5, -5, 0.5, 0.5, STEEL)
			_block(view, p, -facing * 2.0, -6, 0.5, 3, Color("694932"))
		else:
			var sword = era >= 2 and seed % 3 != 0
			var metal = Color("ccad69") if era == 2 else STEEL
			if sword:
				var end = Vector2(facing * (5 if fighting else 2.5), -6.5 + (sin(phase) * 1.5 if fighting else -2))
				_line(view, p, h, end, INK, 1.5)
				_line(view, p, h, end, metal, 0.75)
				_line(view, p, h + Vector2(-1, -0.5), h + Vector2(1, -0.5), GOLD, 0.5)
			else:
				var end = Vector2(facing * 6.5, -6.5) if fighting else Vector2(facing * 2.5, -12)
				_line(view, p, Vector2(facing * 2.5, -0.5), end, WOOD, 0.5)
				_line(view, p, end, end + Vector2(facing * 0.5, -1), metal if era >= 2 else Color("aaa799"), 1)
			var shield = Vector2(-facing * 2.0, -4.0)
			_block(view, p + shield, -1.5, -2, 3, 3.5, INK)
			_block(view, p + shield, -1, -1.5, 2, 2.5, flag if era >= 2 else Color("956d47"))
			_block(view, p + shield, -0.5, -1, 1, 1, metal)
	else:
		var wood_stock = Color("8b593c") if era < 9 else Color("44564d")
		var barrel = STEEL if era < 9 else Color("303c3d")
		if era >= 12: barrel = Color("c5d8d6")
		_line(view, p, Vector2(-facing, -4), Vector2(facing * 2, -5), wood_stock, 1.0)
		_line(view, p, Vector2(facing * 1, -5), tip + Vector2(facing * (1.5 if era < 9 else 0), 0), barrel, 0.5 if era < 9 else 1)
		_line(view, p, Vector2(facing * 2.5, -5), Vector2(facing * 2, -3.5), barrel, 0.5)
		if era >= 11: _line(view, p, Vector2(facing * 2.5, -6), Vector2(facing * 4, -6), Color("24353b"), 0.5)
		if era >= 12: _line(view, p, Vector2(facing * 2, -5), Vector2(facing * 4, -5), Color("88ede0"), 0.5)
		if fighting and fposmod(phase, 7.0) < 0.8:
			var muzzle = tip + Vector2(facing * (2 if era < 9 else 0.5), 0)
			_block(view, p + muzzle, -0.5, -1, 2, 2, Color("a4f4e2") if era >= 12 else Color("ffe49a"))
			_line(view, p + muzzle, Vector2(0, 0), Vector2(facing * 3, -0.5), Color("fff3ba"), 0.5)
	_block(view, p, facing * 1.5 - 0.5, -4.5, 1, 0.5, SKINS[seed % SKINS.size()])


func draw_wars(view, sim, time: float, zoom: float):
	var wars = sim.state.get("wars", [])
	for war_index in range(mini(wars.size(), 6)):
		var war = wars[war_index]
		if war.get("theater","")=="sea": continue
		var pair = _front_pair(sim, war)
		if pair.size() != 2: continue
		var a = pair[0]
		var b = pair[1]
		var pa = (Vector2(a.get("x", 0), a.get("y", 0)) + Vector2.ONE * 0.5) * 8.0
		var pb = (Vector2(b.get("x", 0), b.get("y", 0)) + Vector2.ONE * 0.5) * 8.0
		var corridor = Rect2(pa, Vector2.ZERO).expand(pb).grow(48)
		if not view._visible(corridor): continue
		var axis = (pb - pa).normalized()
		if axis == Vector2.ZERO: axis = Vector2.RIGHT
		var perpendicular = Vector2(-axis.y, axis.x)
		var center = pa.lerp(pb, 0.5)
		var era_a = clampi(int(a.get("era", 0)), 0, 13)
		var era_b = clampi(int(b.get("era", 0)), 0, 13)
		var fa = view._nation_colors.get(int(war.get("a", -1)), Color("edb369"))
		var fb = view._nation_colors.get(int(war.get("b", -1)), Color("71b5cf"))
		var front_gap = 8.0 if maxi(era_a, era_b) < 6 else 19.0
		front_gap = minf(front_gap, maxf(5.0, pa.distance_to(pb) * 0.18))
		var front_a = center - axis * front_gap
		var front_b = center + axis * front_gap
		for side in range(2):
			var town = a if side == 0 else b
			var start = pa if side == 0 else pb
			var front = front_a if side == 0 else front_b
			var advance = axis if side == 0 else -axis
			var era = era_a if side == 0 else era_b
			var flag = fa if side == 0 else fb
			var salt = int(town.get("id", 1)) * 101
			var face = 1.0 if advance.x >= 0.0 else -1.0
			if not _land(view, front):
				for ship in range(2):
					var ship_position = front + perpendicular * (float(ship) - 0.5) * 14.0
					if not sim.state.has("transport") and not _land(view, ship_position) and _on_screen(view, ship_position, 25):
						if not _collecting_wars: _ship(view, ship_position, era, flag, face, time + ship)
			else:
				var number = clampi(int(sqrt(maxf(1.0, float(town.get("population", 0)))) * 0.70), 4, 12)
				var fighters = []
				for unit in range(number):
					var row = unit / 4
					var column = unit % 4
					var position = front + perpendicular * (float(column) - 1.5) * 5.5 - advance * float(row) * 7.0
					position += advance * sin(time * 2.5 + unit * 1.3) * (1.3 if era < 6 else 0.4)
					if not _land(view, position) or not _on_screen(view, position, 18): continue
					fighters.append({"p":position,"slot":"%d:%d:f:%d"%[war_index,side,unit], "seed":salt + unit, "role":"banner" if unit == number - 1 else ("archer" if era in [1, 4, 5] and unit % 4 == 1 else "soldier")})
				fighters.sort_custom(func(x, y): return x.p.y < y.p.y)
				for fighter in fighters:
					var mounted=era>=2 and era<=8 and int(fighter.seed)%5==0 and fighter.role!="banner"
					if mounted and not _collecting_wars and (_war_slots.has(fighter.slot) or not view.has_method("draw_identified_person")): _horse(view,fighter.p,flag,face,time*6+fighter.seed)
					_military_member(view,sim,town,fighter.slot,fighter.p-Vector2(0,3 if mounted else 0),era,flag,fighter.seed,fighter.role,face,time*5+fighter.seed,"fighting",zoom)
				var support = front - advance * 25 + perpendicular * 6
				if not _collecting_wars and _land(view, support) and _on_screen(view, support, 22): _support(view, support, era, flag, face, time)
			# Supply / reinforcement groups march from their own settlement to their own line.
			for unit in range(3):
				var travel = 0.20 + fposmod(time * 0.028 + unit * 0.23 + side * 0.13, 0.70)
				var position = start.lerp(front, travel) + perpendicular * (float(unit) - 1.0) * 4
				if not _on_screen(view, position, 16): continue
				if _land(view, position):
					_military_member(view,sim,town,"%d:%d:m:%d"%[war_index,side,unit],position,era,flag,salt+40+unit,"soldier",face,time*6+unit,"marching",zoom)
				elif unit == 1 and not _collecting_wars and not sim.state.has("transport"): _ship(view, position, era, flag, face, time)
		if not _collecting_wars and _on_screen(view, center, 60):
			_projectiles(view, front_a, front_b, era_a, fa, time, 0)
			_projectiles(view, front_b, front_a, era_b, fb, time, 1)
			# Visible fallen equipment appears only after actual recorded casualties.
			if float(war.get("casualties_a", 0)) + float(war.get("casualties_b", 0)) > 0.0 and _land(view, center):
				_line(view, center, Vector2(-3, 3), Vector2(1, 4), STEEL, 0.5)
				_block(view, center, 3, -1, 2, 2, fa.darkened(0.35))


func _front_pair(sim, war) -> Array:
	var towns_a = []
	var towns_b = []
	var front_a = {}
	var front_b = {}
	for town in sim.state.get("settlements", []):
		if float(town.get("population", 0)) <= 0.0: continue
		if int(town.get("nation", -1)) == int(war.get("a", -2)):
			towns_a.append(town)
			if int(town.get("id", -1)) == int(war.get("front_a", -2)): front_a = town
		elif int(town.get("nation", -1)) == int(war.get("b", -2)):
			towns_b.append(town)
			if int(town.get("id", -1)) == int(war.get("front_b", -2)): front_b = town
	if not front_a.is_empty() and not front_b.is_empty(): return [front_a, front_b]
	var best = INF
	var result = []
	for a in towns_a:
		for b in towns_b:
			var distance = Vector2(a.get("x", 0), a.get("y", 0)).distance_squared_to(Vector2(b.get("x", 0), b.get("y", 0)))
			if distance < best:
				best = distance
				result = [a, b]
	return result


func _projectiles(view, start, target, era, flag, time, side):
	var axis = (target - start).normalized()
	var lateral = Vector2(-axis.y, axis.x)
	for volley in range(3):
		var phase = fposmod(time * (0.85 if era < 6 else 2.0) + float(volley) * 0.29 + float(side) * 0.35, 1.0)
		if phase > 0.65: continue
		var t = phase / 0.65
		var p = start.lerp(target, t) + lateral * (float(volley) - 1.0) * 5.5 + Vector2(0, -5)
		if era < 6:
			if era == 0: continue
			p.y -= sin(t * PI) * 6
			view.draw_line(p - axis * 2, p + axis * 1.5, WOOD, 0.5)
			view.draw_line(p + axis, p + axis * 2, STEEL, 0.75)
		elif era < 12:
			view.draw_line(p - axis * 2, p + axis * 2, Color("ffe5a1"), 0.5)
		else:
			view.draw_line(p - axis * 3, p + axis * 3, flag.lightened(0.55), 1)
			view.draw_line(p - axis * 2, p + axis * 2, Color("d6fff1"), 0.5)
		if t > 0.86:
			_block(view, target + lateral * (float(volley) - 1.0) * 5.5, -1, -1, 2, 0.5, Color("d6bc89"))


func _horse(view,p,flag,face,phase):
	var hide=Color("9d7552"); var mane=Color("3c3430")
	_block(view,p,-6,-5,12,4,INK); _block(view,p,-5.5,-5,11,3,hide)
	_block(view,p,-5,-5,9,0.5,hide.lightened(0.28)); _block(view,p,-5,-2.5,10,0.5,hide.darkened(0.25))
	for leg in range(4):
		var x=-4+leg*2.5; var step_=sin(phase+leg*PI*0.5)*0.7
		_block(view,p,x+step_,-2,0.75,3.5,hide.darkened(0.25)); _block(view,p,x+step_-0.25,1,1.25,0.5,mane)
	_block(view,p,face*4-1,-9,2.5,5,hide); _block(view,p,face*5-1,-9.5,3.5,2,hide)
	_block(view,p,face*5,-10.5,0.5,1,hide); _block(view,p,face*6,-9,0.5,0.5,INK)
	_block(view,p,face*3-0.5,-9,0.75,4,mane); _block(view,p,-2,-5.5,5,3,flag)
	_block(view,p,-1.5,-5.5,4,0.5,flag.lightened(0.3)); _block(view,p,-1,-6,3,1,Color("604b37"))
	_line(view,p,Vector2(-face*5,-4),Vector2(-face*8,-2+sin(phase)),mane,1)
	_line(view,p,Vector2(0,-6),Vector2(face*6,-8),Color("c6ab77"),0.25)

func _support(view, p, era, flag, face, time):
	p = (p * 2).round() * 0.5
	if era < 4: return
	if era < 6:
		# Wheeled timber catapult with sling and a raised throwing arm.
		_block(view, p, -6, -2, 12, 2, Color("644d37"))
		for wheel in [-4, 4]:
			view.draw_circle(p + Vector2(wheel, 0), 2, INK)
			view.draw_circle(p + Vector2(wheel, 0), 1, WOOD)
		_line(view, p, Vector2(-4, -2), Vector2(0, -7), WOOD, 1)
		_line(view, p, Vector2(4, -2), Vector2(0, -7), WOOD, 1)
		var firing=fposmod(time*0.6,1.0)
		var tip=Vector2(lerpf(-face*5,face*4,minf(1,firing*3)),-7-sin(firing*PI)*5)
		_line(view, p, Vector2(0,-4),tip,Color("b39460"),1)
		if firing<0.35: _block(view,p,tip.x-1,tip.y-1,2,1.5,Color("687977"))
		elif firing<0.8:
			var flight=(firing-0.35)/0.45
			_block(view,p,tip.x+face*flight*38,tip.y-sin(flight*PI)*15,1.5,1.5,Color("87928b"))
		_block(view, p, -3, -4, 2, 1, flag)
	elif era < 9:
		# Cannon, iron muzzle, wooden carriage and spoked wheels.
		_line(view, p, Vector2(-face * 7, 0), Vector2(0, -2), WOOD, 1.5)
		_line(view, p, Vector2(-face * 2, -4), Vector2(face * 7, -6), Color("384a4b"), 3)
		_line(view, p, Vector2(-face * 2, -4.5), Vector2(face * 6, -6.5), STEEL.darkened(0.2), 0.5)
		for wheel in [-2, 3]:
			view.draw_circle(p + Vector2(wheel, -1), 2.5, INK)
			view.draw_circle(p + Vector2(wheel, -1), 1.5, WOOD)
			_line(view, p, Vector2(wheel - 1.5, -1), Vector2(wheel + 1.5, -1), Color("c3a67a"), 0.5)
		_block(view, p, -2, -4, 2, 1, flag)
		if fposmod(time, 3) < 0.18: view.draw_circle(p + Vector2(face * 8, -6), 2, Color("ffe4a1"))
	else:
		var armor = Color("6d8064") if era < 12 else Color("a3b9bc")
		_block(view, p, -8, -3, 16, 4, INK)
		if era < 12:
			for wheel in range(6):
				_block(view, p, -7 + wheel * 2.5, -2, 1.5, 2, Color("667473"))
		else:
			_block(view, p, -7, 0, 14, 0.5, Color("7edfdc"))
		_block(view, p, -7, -6, 14, 4, armor.darkened(0.25))
		_block(view, p, -6, -6, 12, 1, armor.lightened(0.1))
		_block(view, p, -4, -8, 7, 3, armor)
		_line(view, p, Vector2(face * 2, -7), Vector2(face * 12, -7.5), armor.darkened(0.4), 1.5)
		_line(view, p, Vector2(face * 2, -7.5), Vector2(face * 12, -8), STEEL, 0.5)
		_block(view, p, -2, -7.5, 3, 1, flag)
		_block(view, p, -3, -9, 3, 1, INK)
		_line(view, p, Vector2(-4, -7), Vector2(-4, -12), INK, 0.5)
		if era >= 11:
			var drone = p + Vector2(9, -18 + sin(time * 2) * 1.5)
			_block(view, drone, -1.5, -1, 3, 2, STEEL)
			_line(view, drone, Vector2(-5, -1), Vector2(5, -1), INK, 0.5)
			for rotor in [-4, 4]:
				_line(view, drone, Vector2(rotor - 2, -2), Vector2(rotor + 2, -2), Color("aabebb"), 0.5)
			_block(view, drone, -0.5, 0, 1, 0.5, Color("83ead7"))


func _ship(view, p, era, flag, face, time):
	p = (p * 2).round() * 0.5
	var waterline = Color(0.71, 0.89, 0.89, 0.58)
	_line(view, p, Vector2(-8, 2), Vector2(8, 2), waterline, 0.5)
	_line(view, p, Vector2(-6, 3.5), Vector2(5, 3.5), Color(waterline, 0.24), 0.5)
	if era < 2:
		for log in range(3): _block(view, p, -5, -1 + log, 10, 0.5, WOOD.lightened(log * 0.07))
		_line(view, p, Vector2(1, -2), Vector2(face * 6, 4), WOOD, 0.5)
		_block(view, p, -1, -5, 2, 3, flag)
		_block(view, p, -0.5, -6, 1, 1, SKINS[era])
		return
	var hull = Color("77553a") if era < 8 else Color("6c8185")
	view.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -3), p + Vector2(9, -3), p + Vector2(6, 1), p + Vector2(-6, 1)]), INK)
	_block(view, p, -7, -3, 14, 2, hull)
	_line(view, p, Vector2(-7, -3), Vector2(7, -3), hull.lightened(0.3), 0.5)
	if era < 8:
		_line(view, p, Vector2(0, -2), Vector2(0, -17), WOOD, 0.5)
		view.draw_colored_polygon(PackedVector2Array([p + Vector2(0.5, -16), p + Vector2(6, -6), p + Vector2(0.5, -6)]), Color("eee0b4"))
		_block(view, p, -0.5, -17, 4, 1.5, flag)
		for oar in range(3): _line(view, p, Vector2(-4 + oar * 4, -1), Vector2(-5 + oar * 4 + sin(time * 2), 3), WOOD, 0.5)
	else:
		_block(view, p, -3, -7, 6, 4, STEEL)
		_block(view, p, -2, -6, 4, 1, Color("415b69"))
		_line(view, p, Vector2(0, -7), Vector2(0, -13), INK, 0.5)
		_block(view, p, 0.5, -12, 4, 2, flag)
		_line(view, p, Vector2(face * 4, -4), Vector2(face * 10, -5), INK, 1)
		if era >= 12: _block(view, p, -6, -1, 12, 0.5, Color("8be8d9"))


func _block(view, p, x, y, width, height, color):
	view.draw_rect(Rect2(p + Vector2(x, y), Vector2(width, height)), color)


func _line(view, p, a, b, color, width):
	view.draw_line(p + a, p + b, color, width)


func _land(view, position) -> bool:
	return view._is_land(floori(position.x / 8.0), floori(position.y / 8.0))


func _on_screen(view, position, extent: float) -> bool:
	return view._visible(Rect2(position - Vector2.ONE * extent, Vector2.ONE * extent * 2))
