extends RefCounted
## Close-up settlement illustrations. Every coordinate is in world units;
## fine details occupy half-unit pixels and all positions are deterministic.

const CONTENT = preload("res://scripts/content.gd")
const INK = Color("394642")
const WOOD = Color("795943")
const LIGHT_WOOD = Color("ae8555")
const STONE = Color("b5b6a0")
const GLASS = Color("79b6c0")
const PLOTS = [Vector2(-12,-6), Vector2(12,-6), Vector2(-12,18), Vector2(12,18),
	Vector2(-36,-6), Vector2(36,-6), Vector2(-36,18), Vector2(36,18),
	Vector2(-12,-30), Vector2(12,-30), Vector2(-36,-30), Vector2(36,-30),
	Vector2(-12,42), Vector2(12,42), Vector2(-36,42), Vector2(36,42)]


func layout(town: Dictionary) -> Array:
	var result: Array = []
	var era = clampi(int(town.get("era", 0)), 0, 13)
	var amount = clampi(8 + int(sqrt(maxf(float(town.get("population", 0)), 0.0)) * 0.26), 9, 16)
	var unlocked = town.get("buildings", [])
	for i in range(amount):
		var kind = "house"
		if i == 0: kind = "civic"
		elif i == 1: kind = str(CONTENT.ERA_BUILDINGS[era])
		elif i == 6 and era >= 3: kind = "forge" if era < 8 else "workshop"
		elif i == 7 and era >= 1: kind = "farm"
		elif i == 10 and era >= 5 and "castle" in unlocked: kind = "watchtower"
		elif i == 12 and era >= 4 and era < 9: kind = "market"
		elif i == 14 and era >= 9: kind = "garden"
		var seed = int(town.get("id", 0)) * 53 + i * 17
		var roof_height = [8.0,8.0,9.0,11.0,12.0,15.0,15.0,14.0,15.0,18.0,18.0,18.0,19.0,9.0][era]
		if kind == "civic": roof_height = 7.0 if era<2 else (12.0 if era<5 else 16.0)
		elif kind == "hearth": roof_height = 1.0
		elif kind in ["farm","market","garden"]: roof_height = 6.0
		elif kind == "castle": roof_height = 15.0
		elif kind in ["reactor","network","spaceport"]: roof_height = 16.0
		var damage = clampf(float(town.get("visual_damage",0.0)),0.0,1.0)
		if float(town.get("population",0.0))<=0 or (damage>0.48 and float(_hash(seed,91)%100)/100.0<damage): roof_height=1.5
		result.append({"position": PLOTS[i], "kind": kind, "seed": seed, "height": roof_height})
	return result


func era_summary(era: int) -> String:
	return ["Hide shelters, stone hearths and timber tools", "Thatched roundhouses, crops and timber granaries",
		"Mudbrick houses, raised granaries and bronze workshops", "Timber longhouses, masonry forges and iron tools",
		"Tiled villas, columned halls and arched aqueducts", "Half-timbered houses, battlements and stone castles",
		"Plaster townhouses, domed civic halls and printing shops", "Gabled merchant houses, warehouses and navigation towers",
		"Brick terraces, sawtooth factories and smokestacks", "Apartment blocks, paved streets and hospitals",
		"Concrete towers, cooling towers and atomic reactors", "Glass offices, solar roofs and communication dishes",
		"Green terraces, illuminated automation plants and robot gantries", "Habitat domes, solar arrays and rocket launch towers"][clampi(era, 0, 13)]


func draw_ground(view, town, center: Vector2, flag: Color, _time: float):
	var era = clampi(int(town.get("era", 0)), 0, 13)
	var dry = int(town.get("drought", 0)) > 0
	var dirt = Color("9c9a65") if not dry else Color("b49d6b")
	var entries = layout(town)
	for entry in entries:
		var p: Vector2 = center + entry.position
		if not _land(view, p) or not _owns(view,town,p,8.0): continue
		_r(view,p,-9,-7,18,9,dirt)
		_r(view,p,-8,-8,16,1,dirt.lightened(0.04))
		# Short door paths connect every plot to the next east-west street.
		_r(view,p,-1.5,1,3,5,Color("b6ab80") if era < 9 else Color("9daba6"))
		for j in range(3):
			var offset = Vector2(-8 + _hash(entry.seed,j)%16, 2 + j%3)
			_r(view,p+offset,0,0,0.5,0.5,dirt.darkened(0.13))
	var path = Color("b7ab7e")
	if era >= 3: path = Color("a7aaa0")
	if era >= 9: path = Color("5f7171")
	if era >= 12: path = Color("a5bfb6")
	for lane in [-24,0,24]:
		for segment in range(-44,45,4):
			var h = center+Vector2(segment,lane)
			var v = center+Vector2(lane,segment)
			if _land(view,h) and _owns(view,town,h,2.0): _road_piece(view,h,path,era,true,segment)
			if _land(view,v) and _owns(view,town,v,2.0): _road_piece(view,v,path,era,false,segment)
	# Southern lane serves the last row without filling the city with concrete.
	if entries.size() > 12:
		for segment in range(-40,41,4):
			var point = center+Vector2(segment,48)
			if _land(view,point) and _owns(view,town,point,2.0): _road_piece(view,point,path,era,true,segment)
	if era >= 1:
		for offset in [Vector2(-42,32),Vector2(35,32)]:
			if _land(view,center+offset) and _owns(view,town,center+offset+Vector2(3.5,4),4.0): _field(view,center+offset,dry,era,7,8)
	# Small planted corners soften the streets, and indicate irrigation/drought.
	for corner in [Vector2(-29,-19),Vector2(29,19),Vector2(-29,19),Vector2(29,-19)]:
		if not _land(view,center+corner) or not _owns(view,town,center+corner,2.0): continue
		if era >= 9:
			_r(view,center+corner,-2,-2,4,4,Color("c0c1a7"))
			_r(view,center+corner,-1.5,-1.5,3,3,Color("789a65") if not dry else Color("a59564"))
			_r(view,center+corner,-0.5,-3,1,3,WOOD)
			_r(view,center+corner,-1.5,-4,3,2,Color("477c62") if not dry else Color("9e8252"))
	if era >= 3 and era < 9:
		# Low corner masonry, with broad road gaps rather than an enclosing box.
		for sx in [-1,1]:
			for sy in [-1,1]:
				var p = center + Vector2(sx*43,sy*39)
				if _land(view,p) and _owns(view,town,p,2.0):
					_r(view,p,-2,-3,4,3,Color("888e77"))
					_r(view,p,-2,-3,4,0.5,Color("ced0b1"))
	# Settlement colors are carried by banners, never entire fields or roofs.
	if _land(view,center+Vector2(4,4)) and _owns(view,town,center+Vector2(4,4)):
		_l(view,center+Vector2(4,4),center+Vector2(4,-6),Color("d9d1ac"),0.5)
		_r(view,center,4.5,-6,4,2.5,flag)
		_r(view,center,7.5,-5.5,1,1.5,flag.darkened(0.18))


func draw_building(view, entry: Dictionary, town: Dictionary, center: Vector2, flag: Color, time: float):
	var p: Vector2 = (center + Vector2(entry.position)).snapped(Vector2.ONE*0.5)
	if not _land(view,p) or not _land(view,p+Vector2(-5,-2)) or not _land(view,p+Vector2(5,-2)) or not _owns(view,town,p,8.0): return
	var era = clampi(int(town.get("era", 0)), 0, 13)
	var seed = int(entry.seed)
	var kind = str(entry.kind)
	var damage = clampf(float(town.get("visual_damage", 0.0)),0.0,1.0)
	if float(town.get("population", 0.0)) <= 0: damage = 1.0
	var affected = float(_hash(seed,91)%100)/100.0 < damage
	if affected and damage > 0.48:
		_ruin(view,p,era,seed,damage)
		return
	_r(view,p,-6,0,14,2,Color(0.11,0.20,0.16,0.27))
	if kind == "house": _house(view,p,era,seed,flag)
	elif kind == "civic": _civic(view,p,era,flag,seed)
	elif kind == "hearth": _hearth(view,p,time)
	elif kind == "farm": _farm(view,p,era,int(town.get("drought",0))>0)
	elif kind == "granary": _granary(view,p,era)
	elif kind in ["forge","workshop"]: _forge(view,p,era,time)
	elif kind == "aqueduct": _aqueduct(view,p)
	elif kind in ["castle","watchtower"]:
		if era>=8: _security_post(view,p,era,flag,time)
		else: _castle(view,p,flag,kind=="watchtower")
	elif kind == "printing house": _printing_house(view,p,flag)
	elif kind == "harbor": _harbor(view,p,flag)
	elif kind == "factory": _factory(view,p,time)
	elif kind == "hospital": _hospital(view,p)
	elif kind == "reactor": _reactor(view,p,time)
	elif kind == "network": _network(view,p,time)
	elif kind == "automaton foundry": _automation(view,p,time)
	elif kind == "spaceport": _spaceport(view,p,flag,time)
	elif kind == "market": _market(view,p,flag,seed)
	elif kind == "garden": _garden(view,p,era)
	if affected:
		# Actual persistent damage darkens part of a roof and cracks the facade.
		_r(view,p,1,-8,4,2.5,Color(0.18,0.19,0.17,0.72))
		_l(view,p+Vector2(-3,-6),p+Vector2(-2,-4),Color("4c5044"),0.5)
		_l(view,p+Vector2(-2,-4),p+Vector2(-3,-1),Color("4c5044"),0.5)
		_r(view,p,-6,1,3,0.5,Color("615e4c"))
	if int(town.get("plague",0)) > 0 and seed%3 == 0:
		_r(view,p,-4,-4,2,2.5,Color("ded4ab"))
		_r(view,p,-3.5,-4,0.5,2,Color("817d4c"))
		_r(view,p,-4,-3.5,1.5,0.5,Color("817d4c"))


func _house(v,p,era,seed,flag):
	var variation = float(seed%7)/7.0
	var plaster = Color("ddcea8").lerp(Color("bcb89a"),variation*0.5)
	var roof = Color("ad674b").lerp(Color("825f51"),variation*0.5)
	if era == 0:
		# Stitched hide shelter, braced with poles and a dark triangular entrance.
		for row in range(24):
			var w = 1.0 + row*0.5
			_r(v,p,-w*0.5,-12+row*0.5,w,0.5,Color("c9b185") if row<14 else Color("ad956b"))
		_l(v,p+Vector2(0,-13),p+Vector2(-6,0),WOOD,0.5)
		_l(v,p+Vector2(0,-13),p+Vector2(6,0),WOOD,0.5)
		_poly(v,p,[Vector2(0,-5),Vector2(-2.5,0),Vector2(2.5,0)],Color("4f5040"))
		_l(v,p+Vector2(0,-11),p+Vector2(2,-3),Color("877454"),0.5)
		for y in [-8,-6,-4]: _r(v,p,0,y,1.5,0.5,Color("ece0b5"))
		_r(v,p,-7,0,2,1,Color("868879"))
		_r(v,p,5,0,2,1,Color("a8a38c"))
		return
	if era == 1:
		_r(v,p,-5,-6,10,6,Color("b9a17a"))
		_r(v,p,3,-6,2,6,Color("938462"))
		_roof(v,p,13,6,-5,Color("b7a35d"),seed,true)
		for x in [-4,-2,2,4]: _r(v,p,x,-4,0.5,4,Color("978761"))
		_door(v,p,-1.5,-4,3,4,WOOD)
		_r(v,p,-5,0,3,1,Color("cabfa0"))
		_pot(v,p+Vector2(5,0),false)
		return
	if era == 2:
		_box(v,p,13,8,plaster,Color("b5a078"))
		_r(v,p,-7,-9,14,1.5,Color("b39269"))
		_r(v,p,-5.5,-10,11,1,Color("daca99"))
		for y in [-6,-3]:
			for x in [-5,-1,3]: _r(v,p,x,y,3,0.5,Color("b8a482"))
		_door(v,p,-1.5,-5,3,5,WOOD)
		_window(v,p+Vector2(-4,-6),Color("494e41"),false)
		_l(v,p+Vector2(4,-8),p+Vector2(4,-15),WOOD,0.5)
		_l(v,p+Vector2(6,-8),p+Vector2(6,-15),WOOD,0.5)
		for y in [-9,-11,-13]: _r(v,p,4,y,2,0.5,LIGHT_WOOD)
		_pot(v,p+Vector2(-6,0),false)
		return
	if era < 8:
		var height = 9.0 if era < 5 else 12.0
		_box(v,p,13,height,plaster,plaster.darkened(0.22))
		_roof(v,p,15,5,-height,roof if era>=4 else Color("8d8760"),seed,era==3)
		if era == 3:
			for x in [-5,-2,2,5]: _r(v,p,x,-height,0.5,height,WOOD)
			_r(v,p,-6,-3,12,0.5,WOOD)
		elif era == 4:
			_r(v,p,-7,0,14,1,Color("b5b5a0"))
			_r(v,p,-5,-5,1,5,Color("eee0bd"))
			_r(v,p,4,-5,1,5,Color("eee0bd"))
			_r(v,p,-5,-5,10,0.5,Color("e0d3b0"))
		elif era == 5:
			for x in [-5.5,0,5.5]: _r(v,p,x,-height,0.5,height,WOOD)
			_r(v,p,-6,-6.5,12,0.5,WOOD)
			_l(v,p+Vector2(-5.5,-11),p+Vector2(-0.5,-7),WOOD,0.5)
			_l(v,p+Vector2(0.5,-7),p+Vector2(5.5,-11),WOOD,0.5)
		elif era == 6:
			_r(v,p,-6,-7,12,1,Color("efe1b8"))
			_r(v,p,-6,-1,12,1,Color("b0ac8d"))
		elif era == 7:
			# Merchant-era stepped gable and shuttered attic.
			for i in range(4): _r(v,p,-4+i,-height-1-i,8-i*2,1.5,plaster)
			_window(v,p+Vector2(0,-height-1.5),Color("566d68"),false)
		_door(v,p,-1.5,-4.5,3,4.5,WOOD)
		_window(v,p+Vector2(-4,-4.5),Color("dcc58a"),true)
		_window(v,p+Vector2(4,-4.5),Color("94afa0"),true)
		if era >=5:
			_window(v,p+Vector2(-3,-10),Color("dac88a"),era!=6)
			_window(v,p+Vector2(3,-10),Color("78938c"),era!=6)
		_chimney(v,p+Vector2(4,-height-3),3,Color("8c7661"))
		if seed%2==0:
			_r(v,p,-5.5,-1.5,3,1,WOOD)
			for x in [-5,-4,-3]: _r(v,p,x,-2,0.5,0.5,Color("c77f6a"))
		else: _crate(v,p+Vector2(6,0))
		return
	if era==8:
		var brick = Color("ad7761").lerp(Color("937563"),variation)
		_box(v,p,13,14,brick,brick.darkened(0.22))
		_roof(v,p,14,3,-14,Color("637171"),seed,false)
		_bricks(v,p,13,13,brick.lightened(0.19))
		for y in [-11,-6]:
			for x in [-3.5,3.5]: _window(v,p+Vector2(x,y),Color("b5d0c3"),false)
		_door(v,p,-1.5,-4,3,4,Color("526c69"))
		_chimney(v,p+Vector2(4,-17),4,Color("94705c"))
		_r(v,p,-3,0,6,0.5,Color("c2b698"))
		return
	if era<=11:
		var height = 16 + seed%3*3
		var body = Color("c7c8b5") if era<11 else Color("6d9ea7")
		_box(v,p,13,height,body,body.darkened(0.22))
		_r(v,p,-7,-height-1,14,1,Color("dde0cc"))
		_r(v,p,-5,-height-2.5,10,1.5,Color("799592"))
		for y in range(4,height-1,4):
			for x in [-4,0,4]:
				_r(v,p,x-1,-y-1,2,2,Color("a3cdd0") if (seed+y+int(x))%3 else Color("ecdb9c"))
				_r(v,p,x-1,-y+1,2.5,0.5,body.lightened(0.17))
		_door(v,p,-1.5,-3.5,3,3.5,Color("42616a"))
		if era>=10:
			_r(v,p,2,-height-4,3,1.5,Color("c2c9b6"))
			_l(v,p+Vector2(3,-height-3),p+Vector2(3,-height-6),Color("536f70"),0.5)
		if era==11: _solar(v,p+Vector2(-4,-height-3),5,2)
		return
	if era==12:
		_box(v,p,14,19,Color("b6d6c9"),Color("688f97"))
		for y in [-17,-11,-5]:
			_r(v,p,-6,y,11,2,Color("396e7d"))
			_r(v,p,-7,y+2,14,1,Color("d5e5ce"))
			_r(v,p,-6,y+1.5,5,0.5,Color("6fbc85"))
			for x in [-4,0,4]: _r(v,p,x,y,0.5,2,Color("8dccca"))
		_r(v,p,-5,-22,10,3,Color("8daea8"))
		_solar(v,p+Vector2(-4,-23),8,2)
		_r(v,p,5.5,-19,0.5,18,Color("a8efde"))
		_door(v,p,-1.5,-3.5,3,3.5,Color("3a6b7b"))
		return
	# Pressure habitat with faceted cyan dome and a separate airlock.
	_r(v,p,-7,-5,14,5,Color("c7ddd2"))
	for row in range(14):
		var half = sqrt(maxf(0,1.0-pow(1.0-float(row)/14.0,2.0)))*7
		_r(v,p,-half,-12+row*0.5,half*2,0.5,Color("78b8bd") if row<10 else Color("669aab"))
	_r(v,p,-7,-5,14,1,Color("d7ead6"))
	_l(v,p+Vector2(0,-12),p+Vector2(0,-5),Color("b0dad1"),0.5)
	_l(v,p+Vector2(-4,-10),p+Vector2(-5,-5),Color("aad5d0"),0.5)
	_l(v,p+Vector2(4,-10),p+Vector2(5,-5),Color("5c8999"),0.5)
	_r(v,p,-2.5,-5,5,5,Color("9abbb9"))
	_door(v,p,-1.5,-3.5,3,3.5,Color("376479"))
	_r(v,p,-5,-3,1,1,flag.lightened(0.3))
	_solar(v,p+Vector2(8,-4),5,3)


func _civic(v,p,era,flag,seed):
	if era<2:
		# Carved communal standing stone, encircled by small offering rocks.
		for i in range(8):
			var a=i*TAU/8.0
			_r(v,p+Vector2(cos(a)*6,sin(a)*2),-1,-1,2,1.5,Color("a5a68c"))
		_r(v,p,-2,-10,4,10,Color("9aa28c"))
		_r(v,p,-1.5,-11,3,1,Color("b8b99a"))
		_r(v,p,-2,-9,0.5,8,Color("d0cfad"))
		_r(v,p,-0.5,-8,1,1,Color("637565"))
		_l(v,p+Vector2(0,-6),p+Vector2(1,-4),Color("667666"),0.5)
		_r(v,p,-1,-2,2,0.5,Color("717e67"))
	elif era<5:
		# Raised columned hall; actual doorways remain human-sized.
		_r(v,p,-9,-1,18,2,Color("b4b29a"))
		_r(v,p,-8,-3,16,2,Color("d4ccb0"))
		_r(v,p,-7,-11,14,8,Color("797e70"))
		for x in [-6,-2,2,6]:
			_r(v,p,x-1,-11,2,8,Color("d9d3b6"))
			_r(v,p,x-1,-11,0.5,8,Color("ece4c9"))
			_r(v,p,x-1.5,-4,3,1,Color("c2bfa7"))
		_roof(v,p,19,5,-11,Color("ab7859"),seed,false)
		_r(v,p,-1,-13,2,1,flag)
	elif era<8:
		_box(v,p,17,12,Color("c9c4a7"),Color("9b9f8e"))
		_roof(v,p,19,5,-12,Color("787693") if era==5 else Color("bd8162"),seed,false)
		_r(v,p,-3,-22,6,22,Color("d8ccb0"))
		_r(v,p,1,-22,2,22,Color("a7a590"))
		if era==5:
			_roof(v,p,8,7,-22,flag.darkened(0.2),seed,false)
		else:
			_r(v,p,-4,-23,8,1.5,Color("9c9980"))
			for row in range(10):
				var half = sqrt(maxf(0,1-pow(1-float(row)/10,2)))*4
				_r(v,p,-half,-28+row*0.5,half*2,0.5,Color("78a594") if era==6 else Color("9a9cac"))
		_r(v,p,-0.5,-31,1,3,Color("d7c596"))
		_door(v,p,-1.5,-5,3,5,Color("5d6759"))
		_window(v,p+Vector2(0,-19),Color("e3c887"),false)
		for x in [-6,6]: _window(v,p+Vector2(x,-8),Color("c0cdb1"),false)
	else:
		_box(v,p,18,12,Color("c7cfbb"),Color("919f97"))
		_r(v,p,-10,-13,20,1,Color("e1ddbd"))
		for x in [-6,-2,2,6]:
			_r(v,p,x-1,-9,2,5,Color("6d9092"))
			_r(v,p,x-1,-8,2,0.5,Color("a7c5bd"))
		_r(v,p,-3,-22,6,9,Color("bfccba"))
		_r(v,p,-4,-23,8,1,flag.darkened(0.17))
		_r(v,p,-2,-21,4,4,Color("e9dfb6"))
		_l(v,p+Vector2(0,-20),p+Vector2(0,-18.5),INK,0.5)
		_l(v,p+Vector2(0,-18.5),p+Vector2(1,-19),INK,0.5)
		_door(v,p,-2,-4,4,4,Color("4d7076"))
		_r(v,p,-7,0,14,1,Color("d6d4ba"))
		if era>=12:
			_r(v,p,-8,-13.5,16,0.5,Color("7fdfcf"))
			_solar(v,p+Vector2(-7,-15),4,2)


func _hearth(v,p,time):
	for i in range(10):
		var angle=i*TAU/10
		_r(v,p+Vector2(cos(angle)*5,sin(angle)*2),-1,-1,2,1.5,STONE)
	_l(v,p+Vector2(-3,-1),p+Vector2(3,0),WOOD,1)
	_l(v,p+Vector2(-3,0),p+Vector2(3,-1),WOOD,1)
	_r(v,p,-2,-4,4,3,Color("c87c41"))
	_r(v,p,-1,-6-int(time*3)%2,2,5,Color("eab355"))
	_r(v,p,-0.5,-3,1,2,Color("f4dd88"))
	_l(v,p+Vector2(-4,-1),p+Vector2(-3,-8),WOOD,0.5)
	_l(v,p+Vector2(4,-1),p+Vector2(3,-8),WOOD,0.5)
	_l(v,p+Vector2(-3,-8),p+Vector2(3,-8),WOOD,0.5)
	_r(v,p,-1.5,-7,3,2,Color("5f6050"))


func _farm(v,p,era,dry):
	_field(v,p+Vector2(-8,-6),dry,era,16,7)
	if era<=2:
		_r(v,p,-7,-12,6,5,Color("b4a174"))
		_roof(v,p+Vector2(-4,0),8,4,-12,Color("b6a15e"),2,true)
		_door(v,p,-5,-10,2,3,WOOD)
	else:
		_box(v,p+Vector2(1,-5),11,9,Color("b87d5d"),Color("8d694e"))
		_roof(v,p+Vector2(1,-5),13,5,-9,Color("a59668"),2,true)
		_door(v,p,-2,-10,5,5,WOOD)
		_l(v,p+Vector2(-2,-10),p+Vector2(3,-5),Color("c6ae79"),0.5)
		_l(v,p+Vector2(3,-10),p+Vector2(-2,-5),Color("c6ae79"),0.5)
		if era>=8:
			_r(v,p,-9,-2,4,2,Color("63936d"))
			_r(v,p,-8,-4,2,2,Color("729d72"))
			_r(v,p,-9,-1,1.5,1.5,INK)
			_r(v,p,-5.5,-1,1.5,1.5,INK)
	for x in [-8,-4,0,4,8]: _r(v,p,x,0,0.5,2,WOOD)
	_r(v,p,-8,0.5,16,0.5,LIGHT_WOOD)


func _granary(v,p,_era):
	for x in [-6,-2,2,6]:
		_r(v,p,x,-4,1.5,4,Color("8a8667"))
		_r(v,p,x-0.5,-4,2.5,1,Color("c3b791"))
	_r(v,p,-7,-12,15,8,Color("d3ba86"))
	_r(v,p,5,-12,3,8,Color("b19b6b"))
	for y in [-10,-8,-6]: _r(v,p,-7,y,12,0.5,Color("bba273"))
	_roof(v,p,18,5,-12,Color("b4a05d"),4,true)
	_door(v,p,-1.5,-10,3,6,WOOD)
	for y in [-4,-3,-2,-1]: _r(v,p,0,y,3+y*0.25,0.5,Color("bfb58b"))
	for x in [-7,6]: _pot(v,p+Vector2(x,0),false)


func _forge(v,p,era,time):
	if era>=8:
		_workshop(v,p,era,time)
		return
	_box(v,p,14,9,Color("9a9b87") if era<8 else Color("ab816c"),Color("727f73"))
	_roof(v,p,16,4,-9,Color("737e76"),3,false)
	_bricks(v,p,13,8,Color("b1b099"))
	_chimney(v,p+Vector2(4,-12),8,Color("7d8172"))
	_r(v,p,-5,-6,5,6,Color("424d43"))
	_r(v,p,-4.5,-2.5,4,2.5,Color("bc653c"))
	_r(v,p,-3.5,-2,2,1.5,Color("eab663") if sin(time*6)>0 else Color("d9974f"))
	# Anvil, hammer and timber work table distinguish this from housing.
	_r(v,p,2,-3.5,5,1,Color("566464"))
	_r(v,p,3.5,-2.5,2,1.5,Color("66746c"))
	_r(v,p,2.5,-1,4,1,Color("46584f"))
	_l(v,p+Vector2(1,-5),p+Vector2(3,-3),WOOD,0.5)
	_r(v,p,0.5,-5.5,2,1,Color("adb4a3"))
	if int(time*3)%3!=0: _r(v,p,4.5,-22,2,1.5,Color(0.6,0.64,0.6,0.28))


func _workshop(v,p,era,time):
	var body=Color("ab8c70") if era==8 else Color("a6beb0")
	_box(v,p,16,10,body,body.darkened(0.22))
	_r(v,p,-9,-11,18,2,Color("627f82"))
	for x in [-7,-3,1,5]: _r(v,p,x,-10.5,2,0.5,Color("91acaa"))
	_r(v,p,-6,-7,9,7,Color("405e60"))
	_r(v,p,-6,-7,9,1,Color("789c97"))
	_r(v,p,-6,-5.5,9,0.5,Color("71938e"))
	# Open garage: a wheeled engine, lifting beam, and the service door.
	_r(v,p,-4.5,-3.5,5,2,Color("889e96"))
	_r(v,p,-5,-1.5,1.5,1.5,Color("3b5353"))
	_r(v,p,-0.5,-1.5,1.5,1.5,Color("3b5353"))
	_r(v,p,-3,-4.5,2,1,Color("bfcaac"))
	_door(v,p,5,-4,2,4,Color("5c7b7e"))
	_r(v,p,4,-8,3,1,Color("d3c893"))
	if era>=11:
		_solar(v,p+Vector2(-7,-14),7,3)
		_r(v,p,5,-13,2,1,Color("8bdbcd") if int(time*2)%2 else Color("799e96"))
	else: _chimney(v,p+Vector2(5,-11),4,Color("8e998b"))


func _security_post(v,p,era,flag,time):
	_box(v,p,9,9,Color("a9b7a4"),Color("7b968b"))
	_r(v,p,-5,-10,10,1,Color("d4d9be"))
	_r(v,p,-3,-8,6,2,Color("739ba3"))
	_r(v,p,0,-8,0.5,2,Color("b6cfbf"))
	_door(v,p,-1.5,-4,3,4,Color("4b6e6d"))
	_l(v,p+Vector2(0,-10),p+Vector2(0,-22),Color("a4b9ac"),0.5)
	for y in [-18,-15,-12]: _r(v,p,-1.5,y,3,0.5,Color("8fa799"))
	if era>=10:
		# A small rotating radar array makes military infrastructure legible.
		var width=4.0+absf(sin(time*0.5))*4
		_r(v,p,-width*0.5,-22,width,3,Color("88a8a5"))
		_r(v,p,-width*0.5,-22,width,0.5,Color("c2d8c6"))
		_r(v,p,-0.5,-22,0.5,3,Color("bfd3bf"))
	else:
		_r(v,p,0.5,-22,4,2,flag)
		_l(v,p+Vector2(-4,-16),p+Vector2(4,-16),Color("a4b9ac"),0.5)
	_r(v,p,-5,0,10,1,Color("a8b19b"))


func _aqueduct(v,p):
	_r(v,p,-10,-12,20,3,Color("c8c4a9"))
	_r(v,p,-10,-13,20,1,Color("e0d7b8"))
	_r(v,p,-9,-12.5,18,0.5,Color("699eac"))
	for x in [-9,-3,3,9]:
		_r(v,p,x-1,-9,2,9,Color("c4c2a7"))
		_r(v,p,x-1,-9,0.5,8,Color("e0d8b9"))
		_r(v,p,x-1.5,-1,3,1,Color("a9ad97"))
	for x in [-6,0,6]:
		_r(v,p,x-2,-9,4,1,Color("d4cbb0"))
		_r(v,p,x-2.5,-8,1,1,Color("c4c2a7"))
		_r(v,p,x+1.5,-8,1,1,Color("c4c2a7"))
	for y in [-7,-4]:
		for x in [-9,-3,3,9]: _r(v,p,x-1,y,2,0.5,Color("9fa792"))
	_r(v,p,-3,0,6,2,Color("b6baa3"))
	_r(v,p,-2.5,0.5,5,0.5,Color("78adb5"))


func _castle(v,p,flag,small):
	if small:
		_box(v,p,8,18,STONE,STONE.darkened(0.22))
		_bricks(v,p,8,17,Color("8e9a8b"))
		_r(v,p,-5,-19,10,2,Color("b9bfaa"))
		for x in [-5,-1,3]: _r(v,p,x,-21,2,2,Color("c3c7b0"))
		_r(v,p,-0.5,-15,1,4,Color("475d58"))
		_door(v,p,-1.5,-5,3,5,WOOD)
		return
	_box(v,p,20,11,Color("9fae9b"),Color("7e9184"))
	_bricks(v,p,19,10,Color("bec2a9"))
	for x in [-7,7]:
		var t=p+Vector2(x,0)
		_box(v,t,6,19,Color("b2bbaa"),Color("899e91"))
		_r(v,t,-4,-20,8,2,Color("cad0b8"))
		for tooth in [-4,-1,2]: _r(v,t,tooth,-22,2,2,Color("bdc5af"))
		for y in [-16,-9]: _r(v,t,-0.5,y,1,3,Color("4d645b"))
		for y in [-12,-6]: _r(v,t,-3,y,6,0.5,Color("97a492"))
	for x in [-4,0,4]: _r(v,p,x-1,-13,2,2,Color("bec6ac"))
	_r(v,p,-2.5,-7,5,7,Color("4b5d52"))
	_r(v,p,-2,-6.5,4,6.5,Color("76604b"))
	for x in [-1.5,0,1.5]: _r(v,p,x,-6,0.5,6,Color("a28b65"))
	_r(v,p,-2,-3.5,4,0.5,Color("454e43"))
	_l(v,p+Vector2(7,-22),p+Vector2(7,-29),Color("d4ceab"),0.5)
	_r(v,p,7.5,-29,5,2.5,flag)
	_r(v,p,-3,0,6,1,Color("bebba1"))


func _printing_house(v,p,flag):
	_box(v,p,17,13,Color("d6c5a1"),Color("b1a78c"))
	_roof(v,p,19,6,-13,Color("ad7962"),7,false)
	for x in [-6,-2,2,6]: _window(v,p+Vector2(x,-10),Color("9bb6a7"),false)
	_door(v,p,-6,-6,4,6,WOOD)
	_r(v,p,0,-6,7,5,Color("505b4d"))
	# The open shop shows the press screw and a tray of printed sheets.
	_r(v,p,1,-5,0.5,4,LIGHT_WOOD)
	_r(v,p,5,-5,0.5,4,LIGHT_WOOD)
	_r(v,p,1,-5,4.5,0.5,LIGHT_WOOD)
	_r(v,p,3,-5,0.5,2,Color("c6c1a0"))
	_r(v,p,2,-2.5,3,1,Color("e7dbb4"))
	_r(v,p,-7,-7,14,1,flag.darkened(0.18))
	_r(v,p,4,-13,3,3,Color("eee1b9"))
	for y in [-12.5,-11.5]: _r(v,p,4.5,y,2,0.5,Color("7e7e64"))
	_crate(v,p+Vector2(8,0))


func _harbor(v,p,flag):
	# A dry-land warehouse/navigation tower also works for inland towns.
	_box(v,p,18,9,Color("b6ba9e"),Color("939e8a"))
	_roof(v,p,20,5,-9,Color("698e91"),4,false)
	for x in [-6,-2,2,6]: _r(v,p,x,-8,0.5,8,WOOD)
	_door(v,p,-3,-6,6,6,WOOD)
	_r(v,p,-3,-3,6,0.5,LIGHT_WOOD)
	_r(v,p,4,-20,4,15,Color("dfd8b6"))
	_r(v,p,4,-14,4,2,Color("bc795e"))
	_r(v,p,3.5,-21,5,1,Color("596f70"))
	_r(v,p,4.5,-24,3,3,Color("d4ba72"))
	_roof(v,p+Vector2(6,0),5,2,-24,Color("668a86"),0,false)
	_l(v,p+Vector2(-7,-10),p+Vector2(-7,-22),WOOD,0.5)
	_r(v,p,-6.5,-22,4,2,flag)
	_crate(v,p+Vector2(-8,0))
	_crate(v,p+Vector2(9,0))
	_r(v,p,-10,1,20,1,Color("a79470"))


func _factory(v,p,time):
	_box(v,p,20,11,Color("ae7a64"),Color("855f54"))
	_bricks(v,p,20,10,Color("c29478"))
	for x in [-7,-1,5]:
		_poly(v,p,[Vector2(x-3,-11),Vector2(x+2,-16),Vector2(x+3,-11)],Color("5e7778"))
		_l(v,p+Vector2(x-3,-11),p+Vector2(x+2,-16),Color("a8c1b8"),0.5)
	for x in [-7,-2,3]:
		_r(v,p,x,-8,3,3,Color("8aafb0"))
		_r(v,p,x+1.5,-8,0.5,3,Color("506969"))
		_r(v,p,x,-6.5,3,0.5,Color("506969"))
	_door(v,p,-3,-4,6,4,Color("556c69"))
	_chimney(v,p+Vector2(7,-10),17,Color("956851"))
	_chimney(v,p+Vector2(-7,-12),11,Color("a77a60"))
	for i in range(3):
		var phase=fposmod(time*0.3+i/3.0,1.0)
		_r(v,p,7+phase*6,-29-phase*7,3+phase*3,2,Color(0.62,0.66,0.62,0.3*(1-phase)))
	_crate(v,p+Vector2(8,0))


func _hospital(v,p):
	_box(v,p,20,15,Color("d6d6bc"),Color("9fab9f"))
	_r(v,p,-11,-16,22,1,Color("e6e2c7"))
	_r(v,p,-6,-19,12,3,Color("c3c9b3"))
	for y in [-12,-7]:
		for x in [-7,-3,3,7]: _window(v,p+Vector2(x,y),Color("83bbc0"),false)
	_r(v,p,-1,-20,2,6,Color("c66d63"))
	_r(v,p,-3,-18,6,2,Color("c66d63"))
	_r(v,p,-4,-4,8,1,Color("6c9da1"))
	_door(v,p,-2.5,-3,5,3,Color("507e88"))
	_r(v,p,-0.25,-3,0.5,3,Color("b5d3cb"))
	_r(v,p,-5,0,10,1,Color("ccd0b9"))


func _reactor(v,p,time):
	_box(v,p+Vector2(-4,0),11,7,Color("c4cab4"),Color("8ca39a"))
	_r(v,p,-10,-8,12,1,Color("dae0c4"))
	# Hyperboloid cooling tower: broad feet, narrow neck, wider rim.
	for row in range(36):
		var t=float(row)/36.0
		var w=6.5+5.0*pow(absf(t-0.35),1.2)
		_r(v,p,5-w/2,-18+row*0.5,w,0.5,Color("c4cfbd"))
		_r(v,p,5+w/2-2,-18+row*0.5,2,0.5,Color("95aaa4"))
	_r(v,p,0.5,-19,9,1.5,Color("dce0c7"))
	_r(v,p,1.5,-19,7,0.5,Color("667f7c"))
	for i in range(3):
		var phase=fposmod(time*0.23+i/3.0,1.0)
		_r(v,p,2+phase*3,-21-phase*6,5+phase*3,2,Color(0.85,0.90,0.81,0.25*(1-phase)))
	_door(v,p,-7,-4,3,4,Color("567670"))
	_r(v,p,-2,-5,2,2,Color("d8bd60"))
	_r(v,p,-1.5,-4.5,1,1,Color("4d6157"))
	_r(v,p,-10,0,20,1,Color("929e89"))


func _network(v,p,time):
	_box(v,p,19,17,Color("779fa6"),Color("4f7d8a"))
	for y in [-14,-10,-6]:
		_r(v,p,-8,y,16,2,Color("a1c9c6"))
		for x in [-6,-2,2,6]: _r(v,p,x,y,0.5,2,Color("5f929c"))
	_r(v,p,-10,-18,20,1,Color("cedbd0"))
	_solar(v,p+Vector2(-8,-20),8,2)
	_l(v,p+Vector2(4,-18),p+Vector2(4,-25),Color("bdd2c9"),1)
	# Stepped satellite dish with a feed horn.
	for i in range(5): _r(v,p,1+i*0.5,-26+i*0.5,7-i,0.5,Color("d6dfce"))
	_l(v,p+Vector2(4,-24),p+Vector2(7,-28),Color("91b4b2"),0.5)
	_r(v,p,6.5,-28.5,1,1,Color("e4d290") if int(time*2)%2 else Color("93c5bc"))
	_door(v,p,-2,-3.5,4,3.5,Color("466c7c"))
	_r(v,p,8,-14,0.5,13,Color("c6e1d6"))


func _automation(v,p,time):
	_box(v,p,20,12,Color("b3cec4"),Color("759b9e"))
	_r(v,p,-11,-13,22,1,Color("d9e2cb"))
	_r(v,p,-9,-11,18,1,Color("92e1d2"))
	_r(v,p,-8,-8,16,6,Color("395f6d"))
	for x in [-6,0,6]:
		_r(v,p,x-1,-2,3,1,Color("a2beb3"))
		_l(v,p+Vector2(x,-3),p+Vector2(x-1.5,-6),Color("d4c7a0"),1)
		_l(v,p+Vector2(x-1.5,-6),p+Vector2(x+1+sin(time*1.4+x)*0.5,-7),Color("b9c5b2"),1)
		_r(v,p,x,-3,1,1,Color("89dcd4"))
	_r(v,p,-9,0,18,1,Color("99aba1"))
	for x in [-8,-4,0,4,8]: _r(v,p,x,-0.5,2,0.5,Color("d6c877"))
	_solar(v,p+Vector2(-8,-16),7,3)
	_r(v,p,3,-18,5,5,Color("93aaa8"))
	for y in [-17,-15]: _r(v,p,3.5,y,4,0.5,Color("70d5cd"))


func _spaceport(v,p,flag,time):
	_r(v,p,-10,-3,20,4,Color("7c9e9d"))
	_r(v,p,-8,-3,16,0.5,Color("c3d9ce"))
	for x in [-8,-5,-2,1,4,7]: _r(v,p,x,-1,1.5,0.5,Color("d3c994"))
	# Gantry with open metal bracing beside the white launch vehicle.
	for x in [5,9]: _r(v,p,x,-28,0.5,25,Color("90b2b0"))
	for y in range(-27,-3,4):
		_l(v,p+Vector2(5,y),p+Vector2(9,y+4),Color("a5c5bb"),0.5)
		_r(v,p,5,y,4.5,0.5,Color("b0cbbf"))
	_r(v,p,-4,-21,6,15,Color("e2e5ce"))
	_r(v,p,0,-21,2,15,Color("9cbab8"))
	for i in range(12): _r(v,p,-1-i*0.25,-27+i*0.5,0.5+i*0.5,0.5,Color("dbe2d0"))
	_r(v,p,-4,-13,6,1.5,flag.darkened(0.1))
	_r(v,p,-2.5,-19,2,2,Color("6997a6"))
	_poly(v,p,[Vector2(-4,-10),Vector2(-7,-4),Vector2(-4,-5)],Color("bed4c8"))
	_poly(v,p,[Vector2(2,-10),Vector2(5,-4),Vector2(2,-5)],Color("91b1b0"))
	_r(v,p,-3,-6,4,2,Color("5b7980"))
	_r(v,p,1,-22,5,0.5,Color("bad1c7"))
	_r(v,p,8.5,-29,1,1,Color("ecb583") if int(time*2)%2 else Color("93beb1"))
	_solar(v,p+Vector2(-10,-6),4,3)


func _market(v,p,flag,seed):
	_r(v,p,-8,-4,16,4,WOOD)
	_r(v,p,-8,-4,16,0.5,LIGHT_WOOD)
	for x in [-7,7]: _r(v,p,x,-9,0.5,9,WOOD)
	_r(v,p,-9,-9,18,4,Color("e1d2aa"))
	for x in [-8,-4,0,4]: _r(v,p,x,-9,2,4,flag.darkened(0.06))
	_r(v,p,-9,-9.5,18,0.5,flag.lightened(0.17))
	for i in range(9):
		_r(v,p,-6+i*1.5,-4.5,1,1,Color("d69e57") if (i+seed)%2 else Color("86ac63"))
	_crate(v,p+Vector2(-8,0))
	_pot(v,p+Vector2(8,0),false)


func _garden(v,p,era):
	_r(v,p,-8,-5,16,6,Color("a6b9a0"))
	_r(v,p,-7,-4,14,4,Color("6d9c76"))
	for x in [-6,-2,2,6]:
		_r(v,p,x,-6,0.5,5,WOOD)
		_r(v,p,x-1.5,-9,3.5,4,Color("41775d"))
		_r(v,p,x-1,-10,2,1,Color("6b9d6c"))
	_r(v,p,-3,-2,6,0.5,Color("c0c3a0"))
	if era>=12: _solar(v,p+Vector2(-8,-12),4,2)


func _ruin(v,p,era,seed,damage):
	_r(v,p,-8,-5,16,7,Color("6e7760"))
	_r(v,p,-6,-4,12,5,Color("505a4e"))
	for x in [-6,-2,3,6]:
		var height = 1.5 + _hash(seed,int(x))%6*0.5
		_r(v,p,x,-height,2.5,height,Color("8b8c75") if era>1 else Color("817256"))
		_r(v,p,x,-height,2.5,0.5,Color("a6a48a"))
	_l(v,p+Vector2(-5,-4),p+Vector2(3,1),Color("494d41"),1)
	_l(v,p+Vector2(1,-5),p+Vector2(5,0),Color("655d49"),1)
	for i in range(7):
		_r(v,p,-7+_hash(seed,i)%15,-2+_hash(seed+7,i)%5,1.5,1,Color("929179") if i%2 else Color("626c57"))
	if era>=8 and damage<0.95:
		_r(v,p,4,-10,2,8,Color("6e7f74"))
		_l(v,p+Vector2(4.5,-10),p+Vector2(3,-12),Color("7c8c7f"),0.5)


func _road_piece(v,p,color,era,horizontal,segment):
	var extent = Vector2(4,4) if horizontal else Vector2(4,4)
	_r(v,p,-2,-2,extent.x,extent.y,color)
	if era>=3 and era<9:
		_r(v,p,-1.5,-1.5,1.5,0.5,color.lightened(0.12))
		_r(v,p,0.5,0.5,1,0.5,color.darkened(0.1))
	elif era>=9 and era<12 and segment%8==0:
		if horizontal: _r(v,p,-1,0,2,0.5,Color("c6c8a6"))
		else: _r(v,p,0,-1,0.5,2,Color("c6c8a6"))
	elif era>=12:
		_r(v,p,1.5,-2,0.5,4,color.darkened(0.12))
		_r(v,p,-2,1.5,4,0.5,color.darkened(0.12))


func _field(v,p,dry,era,w,h):
	_r(v,p,0,0,w,h,Color("8d8157") if dry else Color("80734e"))
	for row in range(1,int(h),2):
		_r(v,p,0.5,row,w-1,0.5,Color("bcaa6a") if dry else Color("a0b569"))
		for x in range(1,int(w),2):
			_r(v,p,x,row-1,0.5,1,Color("cbb87b") if dry else Color("cfcc78"))
	if era>=4: _r(v,p,0,h-0.5,w,0.5,Color("978967") if dry else Color("7aa7a2"))


func _box(v,p,width,height,front,side):
	_r(v,p,-width/2,-height,width,height,front)
	_r(v,p,width/2-3,-height,3,height,side)
	_r(v,p,-width/2,-height,0.5,height,front.lightened(0.16))
	_r(v,p,-width/2,-0.5,width,0.5,front.darkened(0.25))


func _roof(v,p,width,height,bottom,color,seed,thatch):
	var rows = int(height*2)
	for row in range(rows):
		var half = (width*0.5)*(row+1)/rows
		var y = bottom-height+row*0.5
		var shade = color.lightened(0.07) if row%4==0 else color
		_r(v,p,-half,y,half*2,0.5,shade)
		if half>2: _r(v,p,half*0.35,y,half*0.65,0.5,color.darkened(0.18))
		if row%3==0 and half>2:
			for x in range(-int(half)+1,int(half),3):
				_r(v,p,x+float((row+seed)%2)*0.5,y,0.5,0.5,color.lightened(0.2 if thatch else 0.11))
	_r(v,p,-width/2,bottom,width,0.5,color.darkened(0.27))
	_r(v,p,-1,bottom-height-0.5,2,0.5,color.lightened(0.17))


func _window(v,p,color,shutters):
	_r(v,p,-1.5,-1,3,3,Color("54675d"))
	_r(v,p,-1,-0.5,2,2,color)
	_r(v,p,-0.25,-0.5,0.5,2,Color("b7ba98"))
	_r(v,p,-1,0.25,2,0.5,Color("b7ba98"))
	_r(v,p,-2,2,4,0.5,Color("c4bb99"))
	if shutters:
		_r(v,p,-2.5,-1,1,3,Color("7d9275"))
		_r(v,p,1.5,-1,1,3,Color("657e6c"))


func _door(v,p,x,y,w,h,color):
	_r(v,p,x-0.5,y-0.5,w+1,h+0.5,color.darkened(0.32))
	_r(v,p,x,y,w,h,color)
	_r(v,p,x+w*0.5,y,0.5,h,color.lightened(0.14))
	_r(v,p,x+w-1,y+h*0.6,0.5,0.5,Color("d7bb80"))
	_r(v,p,x-0.5,0,w+1,0.5,Color("b8b393"))


func _chimney(v,p,height,color):
	_r(v,p,-1.5,-height,3,height,color)
	_r(v,p,0.5,-height,1,height,color.darkened(0.2))
	_r(v,p,-2,-height-1,4,1,color.lightened(0.13))
	_r(v,p,-1.5,-height-1,3,0.5,color.darkened(0.45))
	for y in range(2,int(height),3): _r(v,p,-1.5,-y,2,0.5,color.lightened(0.13))


func _bricks(v,p,width,height,color):
	for y in range(2,int(height),3):
		for x in range(-int(width/2)+1,int(width/2)-2,4):
			_r(v,p,x+float(y%2),-y,2.5,0.5,color)


func _pot(v,p,green):
	_r(v,p,-1,-2,2,2,Color("b78a61"))
	_r(v,p,-1.5,-2.5,3,0.5,Color("d0a373"))
	_r(v,p,-0.5,-2,1,0.5,Color("725f47"))
	if green: _r(v,p,-1,-4,2,1.5,Color("6c9564"))


func _crate(v,p):
	_r(v,p,-1.5,-3,3,3,Color("ac9165"))
	_r(v,p,0.5,-3,1,3,Color("7d704e"))
	_l(v,p+Vector2(-1.5,-3),p+Vector2(1,0),Color("6f654a"),0.5)
	_r(v,p,-1.5,-3,3,0.5,Color("d1b384"))


func _solar(v,p,w,h):
	_r(v,p,0,0,w,h,Color("4e738c"))
	_r(v,p,0,0,w,0.5,Color("b0cac2"))
	for x in range(1,int(w),2): _r(v,p,x,0,0.5,h,Color("7ca6b4"))
	_r(v,p,0,h-0.5,w,0.5,Color("34596b"))


func _land(view,p: Vector2) -> bool:
	return view._is_land(floori(p.x/8.0),floori(p.y/8.0))


func _owns(view,town,p: Vector2,margin=0.0) -> bool:
	return not view.has_method("_detail_owns_position") or view._detail_owns_position(town,p,margin)


func _hash(a:int,b:int) -> int:
	return absi((a*92837111+b*689287499) ^ (a*19997+b*7001))%100003


func _r(view,p,x,y,w,h,color):
	view.draw_rect(Rect2((p+Vector2(x,y)).snapped(Vector2.ONE*0.5),Vector2(maxf(0.5,w),maxf(0.5,h)).snapped(Vector2.ONE*0.5)),color)


func _l(view,a,b,color,width=0.5):
	view.draw_line(a.snapped(Vector2.ONE*0.5),b.snapped(Vector2.ONE*0.5),color,width,false)


func _poly(view,p,points,color):
	var polygon = PackedVector2Array()
	for point in points: polygon.append((p+point).snapped(Vector2.ONE*0.5))
	view.draw_colored_polygon(polygon,color)
