extends RefCounted

## Draws consequences of real world events. Animation clocks are local to this
## renderer; the simulation, saves, resources, and global RNG are never changed.
const TILE = 8.0
const SUPPORTED = ["fire", "meteor", "volcano", "earthquake", "storm", "rain", "ice", "drought", "plague", "atomic"]
const MAX_EFFECTS = 32
var _first_seen: Dictionary = {}
var _settlements = null

func supports(kind: String) -> bool:
	return kind in SUPPORTED

func draw_world(view, sim, time: float, zoom: float):
	if sim == null or sim.state.is_empty(): return
	time = time if is_finite(time) else 0.0
	zoom = clampf(zoom, 0.1, 12.0)
	var year = int(sim.state.get("year", 0))
	var alive_keys = {}
	var drawn = 0
	var effects = sim.state.get("effects", [])
	# The most recent interventions have visual priority during rapid sandbox use.
	for index in range(effects.size() - 1, -1, -1):
		var effect = effects[index]
		if not effect is Dictionary: continue
		var kind = str(effect.get("type", ""))
		if not supports(kind) or int(effect.get("until", year)) <= year: continue
		var x = int(effect.get("x", -1))
		var y = int(effect.get("y", -1))
		if x < 0 or y < 0 or x >= int(sim.state.get("width", 0)) or y >= int(sim.state.get("height", 0)): continue
		var p = (Vector2(x, y) + Vector2.ONE * 0.5) * TILE
		var radius = clampf(float(effect.get("radius", 3)), 1.0, 12.0) * TILE
		if kind in ["plague", "drought", "ice"] and not _condition_remains(sim, kind, x, y, radius / TILE + 2.0): continue
		var signature = "%s/%d/%d/%d/%d" % [kind, x, y, int(effect.get("until", 0)), index]
		alive_keys[signature] = true
		if not _visible(view, Rect2(p - Vector2(radius + 110, radius + 150), Vector2(radius * 2 + 220, radius * 2 + 240))): continue
		if not _first_seen.has(signature): _first_seen[signature] = time
		var started = int(effect.get("started", int(effect.get("until", year + 5)) - 5))
		var age = maxf(maxf(0.0, time - float(_first_seen[signature])), maxf(0.0, year - started) * 1.2)
		var seed = x * 97 + y * 193 + index * 53
		match kind:
			"fire": _fire_ground(view, p, radius, time, seed, zoom)
			"earthquake": _earthquake(view, p, radius, time, age, seed, zoom)
			"meteor": _meteor(view, p, radius, time, age, seed, zoom)
			"volcano": _volcano(view, p, radius, time, seed, zoom)
			"storm": _storm(view, p, radius, time, seed, true, zoom)
			"rain": _storm(view, p, radius, time, seed, false, zoom)
			"ice": _freeze(view, p, radius, time, seed, zoom)
			"drought": _drought(view, p, radius, seed, zoom)
			"plague": _plague_air(view, p, radius, time, seed, zoom)
			"atomic": _atomic(view, p, radius, time, age, seed, zoom)
		drawn += 1
		if drawn >= MAX_EFFECTS: break
	for signature in _first_seen.keys():
		if not alive_keys.has(signature): _first_seen.erase(signature)

func draw_town_conditions(view, town: Dictionary, center: Vector2, time: float, zoom: float):
	if not center.is_finite(): return
	time = time if is_finite(time) else 0.0
	var damage = clampf(float(town.get("visual_damage", 0.0)), 0.0, 1.0)
	var plague = maxi(0, int(town.get("plague", 0)))
	var drought = maxi(0, int(town.get("drought", 0)))
	var kind = str(town.get("visual_disaster", ""))
	var year = 0
	var sim = view.get("sim")
	if sim != null: year = int(sim.state.get("year", 0))
	var disaster_active = int(town.get("visual_disaster_until", -1)) > year
	var burning = disaster_active and kind in ["fire", "meteor", "volcano", "atomic"]
	if not burning and plague == 0 and drought == 0 and damage <= 0.02: return
	if not _visible(view, Rect2(center - Vector2(85, 105), Vector2(170, 180))): return
	var seed = int(town.get("id", 0)) * 73
	if zoom < 1.6:
		if burning: _flame(view, center + Vector2(0, -9), 6.0, time, seed)
		if plague > 0: _quarantine_sign(view, center + Vector2(8, 2), int(town.get("era", 0)), 0.8)
		return
	var plots = _layout(town)
	var roof_count = 0
	for entry in plots:
		var local = entry.get("position", Vector2.ZERO)
		if not local is Vector2 or not local.is_finite(): continue
		var p = center + local
		if not _land(view, p) or not _owned(view, town, p, 8.0): continue
		var building_seed = int(entry.get("seed", roof_count + seed))
		var roof = p + Vector2(0, -_roof_height(entry, int(town.get("era", 0))))
		if burning and _noise(building_seed, 7) < maxf(0.45, damage):
			_flame(view, roof + Vector2(-2, 1.5), 5.5 + damage * 7.0, time, building_seed)
			_flame(view, roof + Vector2(3, 2), 3.5 + damage * 5.0, time + 0.7, building_seed + 11)
			_smoke(view, roof + Vector2(1, -3), 7.0 + damage * 8.0, time, building_seed, Color("4d4b50"), 4)
			roof_count += 1
		elif disaster_active and damage > 0.08 and kind == "earthquake" and _noise(building_seed, 3) < damage:
			_dust(view, p, 9.0, time, building_seed, 5)
		if plague > 0 and _noise(building_seed, 21) < 0.48:
			_quarantine_sign(view, p + Vector2(5, -0.5), int(town.get("era", 0)), 1.0)
			# Thin wisps stay beside the door, leaving people and architecture visible.
			for k in range(2):
				var phase = fposmod(time * 0.23 + _noise(building_seed, k + 24), 1.0)
				_pixel(view, p + Vector2(-6 + k * 9, -1 - phase * 6), Vector2(2.5, 1.0), Color(0.66, 0.73, 0.37, (1 - phase) * 0.32))
		if roof_count >= 4: break
	if drought > 0:
		# Withered field rows sit outside the street/building footprint.
		for offset in [Vector2(-42,32),Vector2(35,32)]:
			var field = center + offset
			if _land(view, field) and _owned(view, town, field, 8.0): _withered_field(view, field, seed + int(offset.x))
		_crack(view, center + Vector2(0, 13), 13.0, seed + 4, Color("775b3d"), 0.5)
	if damage > 0.1:
		for k in range(5):
			var debris = center + Vector2((_noise(seed, k) - 0.5) * 64, (_noise(seed, k + 11) - 0.5) * 45)
			if _land(view, debris):
				_pixel(view, debris, Vector2(1.5 + damage * 2, 1.0), Color("615047"))
	if disaster_active and kind == "ice" and drought > 0:
		for k in range(mini(plots.size(), 8)):
			var entry = plots[k]
			var local = entry.get("position", Vector2.ZERO)
			if local is Vector2:
				if not _land(view, center + local) or not _owned(view, town, center + local, 8.0): continue
				var roof = center + local + Vector2(0, -_roof_height(entry, int(town.get("era", 0))))
				_pixel(view, roof + Vector2(-4, 1), Vector2(8, 1.5), Color("d9e9df"))
				for icicle in range(3): _pixel(view, roof + Vector2(-3 + icicle * 3, 2), Vector2(0.5, 1.5 + icicle % 2), Color("aacdd6"))

func _fire_ground(view, p: Vector2, radius: float, time: float, seed: int, zoom: float):
	var count = 8 if zoom >= 1.6 else 4
	for k in range(count):
		var q = _scattered(p, radius, seed, k)
		if not _land(view, q): continue
		_pixel(view, q + Vector2(-3, -1), Vector2(7, 2.5), Color(0.19, 0.13, 0.12, 0.58))
		_flame(view, q, 4.5 + _noise(seed, k + 9) * 7, time, seed + k * 13)
		if k % 3 == 0: _smoke(view, q + Vector2(0, -5), 9.0, time, seed + k, Color("575459"), 3)
	for k in range(8):
		var phase = fposmod(time * 0.6 + _noise(seed, k + 30), 1.0)
		var q = _scattered(p, radius * 0.8, seed + 77, k) + Vector2(phase * 4, -phase * 19)
		_pixel(view, q, Vector2.ONE * 0.5, Color(1.0, 0.62, 0.23, 1 - phase))

func _flame(view, p: Vector2, height: float, time: float, seed: int):
	var flicker = sin(time * 7.0 + seed * 0.19) * 1.2
	var lean = sin(time * 4.2 + seed) * 1.3
	var h = maxf(3.0, height + flicker)
	_polygon(view, [p + Vector2(-3,0), p + Vector2(-3.5,-h*0.36), p + Vector2(-1,-h*0.64), p + Vector2(lean-1,-h), p + Vector2(2,-h*0.63), p + Vector2(3.5,-h*0.32), p + Vector2(3,0)], Color("be422b"))
	_polygon(view, [p + Vector2(-2,0), p + Vector2(-2.5,-h*0.28), p + Vector2(0,-h*0.72), p + Vector2(lean+1,-h*0.58), p + Vector2(2.5,-h*0.25), p + Vector2(2,0)], Color("f17c30"))
	_polygon(view, [p + Vector2(-1,0), p + Vector2(-1.5,-h*0.21), p + Vector2(0.5,-h*0.49), p + Vector2(1.5,-h*0.15), p + Vector2(1,0)], Color("ffd36b"))
	_pixel(view, p + Vector2(-0.5,-1.5), Vector2(1.5,1.5), Color("fff1b0"))

func _smoke(view, p: Vector2, height: float, time: float, seed: int, color: Color, count: int):
	for k in range(clampi(count, 1, 7)):
		var phase = fposmod(time * 0.22 + k / float(maxi(1, count)) + _noise(seed, 3), 1.0)
		var q = p + Vector2(phase * 7.0 + sin(phase * 5.0 + seed) * 2.0, -phase * height * 2.3)
		var width = 3.0 + phase * 7.0
		var tint = Color(color, (1.0 - phase) * 0.43)
		_pixel(view, q + Vector2(-width * 0.5, -1.5), Vector2(width, 3), tint)
		_pixel(view, q + Vector2(-width * 0.3, -3), Vector2(width * 0.6, 6), tint)

func _earthquake(view, p: Vector2, radius: float, time: float, age: float, seed: int, zoom: float):
	var count = 6 if zoom >= 1.6 else 3
	for k in range(count):
		var start = _scattered(p, radius * 0.65, seed, k)
		if not _land(view, start): continue
		_crack(view, start, radius * (0.65 + _noise(seed, k + 8) * 0.5), seed + k * 17, Color("332d2b"), 1.0)
		if age < 6.0: _dust(view, start, radius * 0.3, time, seed + k, 5)
	if age < 2.8:
		view.draw_arc(p, maxf(3.0, fposmod(age * 18.0, radius)), 0, TAU, 24, Color(0.85,0.75,0.56,0.28), 0.75)

func _crack(view, p: Vector2, length: float, seed: int, color: Color, width: float):
	var points = PackedVector2Array()
	var direction = Vector2.RIGHT.rotated(_noise(seed, 4) * TAU)
	var across = direction.orthogonal()
	for k in range(6):
		var q = p + direction * ((k / 5.0 - 0.5) * length) + across * ((_noise(seed, k + 10) - 0.5) * 6.0)
		points.append(_snap(q))
	view.draw_polyline(points, color, width, false)
	view.draw_polyline(PackedVector2Array([points[2], _snap(points[2] + across * 4 + direction * 2), _snap(points[2] + across * 7 + direction * 5)]), color, maxf(0.5, width * 0.6), false)

func _dust(view, p: Vector2, radius: float, time: float, seed: int, count: int):
	for k in range(count):
		var phase = fposmod(time * 0.34 + _noise(seed, k + 5), 1.0)
		var q = _scattered(p, radius, seed, k) + Vector2(phase * 5, -phase * 8)
		_pixel(view, q, Vector2(2.5 + phase * 2.0,1.5), Color(0.73,0.65,0.5,0.5 * (1.0 - phase)))

func _meteor(view, p: Vector2, radius: float, time: float, age: float, seed: int, zoom: float):
	if age < 1.4:
		var t = clampf(age / 1.4, 0, 1)
		var incoming = p + Vector2(-88, -120) * pow(1.0 - t, 1.3)
		_pixel(view, p + Vector2(-5, -1), Vector2(10, 3), Color(0.15,0.11,0.13,0.2 + t * 0.2))
		for k in range(8):
			var q = incoming + Vector2(-k * 3.0,-k * 4.0)
			var size_ = maxf(1.0, 7.0 - k * 0.7)
			_pixel(view, q - Vector2.ONE * size_ * 0.5, Vector2.ONE * size_, Color(1.0,0.46 + k * 0.035,0.15,(1.0-k/9.0) * 0.7))
		_polygon(view, [incoming+Vector2(-3,-2),incoming+Vector2(1,-4),incoming+Vector2(4,-1),incoming+Vector2(3,3),incoming+Vector2(-2,4),incoming+Vector2(-4,1)], Color("594438"))
		_pixel(view, incoming + Vector2(-1,-1), Vector2(2,2), Color("ffcb65"))
		return
	_crater(view, p, radius * 0.6, seed)
	if age < 2.4:
		var pulse = (age - 1.4) / 1.0
		view.draw_arc(p, 3 + pulse * radius * 1.4, 0, TAU, 32, Color(1.0,0.81,0.46,(1.0-pulse) * 0.75), 2.0)
		if pulse < 0.3: _pixel(view, p-Vector2(7,5), Vector2(14,9), Color(1.0,0.93,0.71,0.85*(1-pulse*3)))
		for k in range(9):
			var direction = Vector2.RIGHT.rotated(k * TAU / 9 + seed * 0.01)
			var debris = p + direction * pulse * radius * 1.2 + Vector2(0,-sin(pulse*PI)*12)
			_pixel(view, debris, Vector2(1.5,1), Color("bf824f"))
	_smoke(view, p + Vector2(0,-2), 17.0, time, seed, Color("5c565b"), 6 if zoom >= 1.6 else 3)
	if age < 7.0:
		for k in range(3): _flame(view, p + Vector2((k-1)*5, 1), 4.5, time, seed+k)

func _crater(view, p: Vector2, radius: float, seed: int):
	var outer = PackedVector2Array()
	var inner = PackedVector2Array()
	for k in range(16):
		var direction = Vector2(cos(k * TAU / 16), sin(k * TAU / 16) * 0.54)
		var rough = 0.85 + _noise(seed, k) * 0.25
		outer.append(_snap(p + direction * radius * rough))
		inner.append(_snap(p + direction * radius * rough * 0.73 + Vector2(0,-1)))
	view.draw_colored_polygon(outer, Color("7e6852"))
	view.draw_colored_polygon(inner, Color("393334"))
	view.draw_arc(p+Vector2(0,1), radius*0.62, 0.12, PI-0.12, 15, Color("a28157"), 1.0)
	for k in range(6):
		var q = _scattered(p, radius * 0.7, seed + 82, k)
		_pixel(view,q,Vector2(1.5,0.5),Color("d16b37"))

func _volcano(view, p: Vector2, radius: float, time: float, seed: int, zoom: float):
	var width = maxf(16, radius * 0.85)
	var top = p + Vector2(0,-width * 0.78)
	_polygon(view,[p+Vector2(-width,8),top+Vector2(-5,0),top+Vector2(5,0),p+Vector2(width,8)],Color("554a46"))
	_polygon(view,[p+Vector2(-width,8),top+Vector2(-5,0),top+Vector2(1,2),p+Vector2(-width*0.2,8)],Color("776356"))
	_polygon(view,[top+Vector2(2,1),top+Vector2(5,0),p+Vector2(width,8),p+Vector2(width*0.4,7)],Color("403c3d"))
	_pixel(view,top+Vector2(-5,-0.5),Vector2(10,2.5),Color("ec7738"))
	_pixel(view,top+Vector2(-3,0),Vector2(6,1),Color("ffd279"))
	for river in range(3):
		var end = p + Vector2((river-1)*width*0.56,8 + river%2*6)
		var line = PackedVector2Array([top+Vector2((river-1)*2,1),top.lerp(end,0.32)+Vector2(3,-1),top.lerp(end,0.62)+Vector2(-2,1),end])
		view.draw_polyline(line,Color("a93927"),4.0,false)
		view.draw_polyline(line,Color("ee7130"),2.0,false)
		view.draw_polyline(line,Color("ffc15b"),0.5,false)
	for k in range(8 if zoom >= 1.6 else 4):
		var phase = fposmod(time * 0.48 + _noise(seed,k),1.0)
		var q = top + Vector2((_noise(seed,k+22)-0.5)*width*phase,-sin(phase*PI)*width*0.95)
		_pixel(view,q,Vector2(1.5,2),Color(1.0,0.51,0.2,1.0-phase*0.5))
	_smoke(view,top,28.0,time,seed,Color("4d484f"),7)

func _storm(view, p: Vector2, radius: float, time: float, seed: int, violent: bool, zoom: float):
	var count = (30 if violent else 20) if zoom >= 1.6 else 12
	var speed = 0.8 if violent else 0.48
	var length = 7.0 if violent else 4.0
	for k in range(count):
		var phase = fposmod(time * speed + _noise(seed,k+1),1.0)
		var q = p + Vector2((_noise(seed,k+77)-0.5)*radius*2 + phase*7,(-0.9+phase*1.8)*radius)
		view.draw_line(_snap(q),_snap(q+Vector2(-length*0.35,-length)),Color(0.59,0.8,0.91,0.5 if violent else 0.36),0.5,false)
		if phase > 0.92:
			_pixel(view,q+Vector2(-1,0),Vector2(2,0.5),Color(0.7,0.86,0.89,0.5))
	if violent:
		var cloud = p + Vector2(-radius*0.75,-radius-10)
		_pixel(view,cloud,Vector2(radius*1.5,6),Color(0.19,0.25,0.31,0.48))
		_pixel(view,cloud+Vector2(radius*0.18,-4),Vector2(radius*0.9,11),Color(0.27,0.33,0.39,0.42))
		var lightning = fposmod(time + _noise(seed,6)*4.0,4.7)
		if lightning < 0.13 or (lightning > 0.2 and lightning < 0.25):
			var bolt = PackedVector2Array([p+Vector2(5,-radius-6),p+Vector2(-3,-radius*0.4),p+Vector2(3,-radius*0.42),p+Vector2(-4,2)])
			view.draw_polyline(bolt,Color(0.62,0.76,1.0,0.5),2.5,false)
			view.draw_polyline(bolt,Color("f5f0d6"),0.75,false)

func _freeze(view, p: Vector2, radius: float, time: float, seed: int, zoom: float):
	for k in range(10 if zoom >= 1.6 else 5):
		var q = _scattered(p,radius,seed,k)
		if _land(view,q):
			_pixel(view,q+Vector2(-2,-0.5),Vector2(5,1.5),Color(0.82,0.92,0.91,0.65))
			_pixel(view,q+Vector2(-1,-1),Vector2(3,0.5),Color("eff6e9"))
	for k in range(14 if zoom >= 1.6 else 6):
		var phase = fposmod(time*0.15+_noise(seed,k+30),1.0)
		var q = p+Vector2((_noise(seed,k+51)-0.5)*radius*2+sin(time+k)*2,(phase-0.5)*radius*2)
		_pixel(view,q,Vector2.ONE,Color(0.9,0.96,0.96,0.85))
		if k % 4 == 0:
			_pixel(view,q+Vector2(-0.5,0.25),Vector2(2,0.5),Color("f1faf3"))
			_pixel(view,q+Vector2(0.25,-0.5),Vector2(0.5,2),Color("f1faf3"))

func _drought(view, p: Vector2, radius: float, seed: int, zoom: float):
	for k in range(7 if zoom >= 1.6 else 3):
		var q = _scattered(p,radius*0.8,seed,k)
		if not _land(view,q): continue
		_crack(view,q,6+_noise(seed,k+30)*10,seed+k*37,Color(0.39,0.28,0.16,0.7),0.5)
		_pixel(view,q+Vector2(3,-1),Vector2(2,0.5),Color("c1a064"))

func _withered_field(view, p: Vector2, seed: int):
	_pixel(view,p+Vector2(-6,-4),Vector2(12,8),Color(0.48,0.36,0.2,0.68))
	for row in range(3):
		for column in range(5):
			var q = p + Vector2(column*2.3-5,row*2.5-2)
			_pixel(view,q,Vector2(0.5,1.5),Color("84734a"))
			view.draw_line(q,q+Vector2(1.0,-0.5-_noise(seed,row*5+column)),Color("b09a60"),0.5,false)

func _plague_air(view, p: Vector2, radius: float, time: float, seed: int, zoom: float):
	for k in range(7 if zoom >= 1.6 else 3):
		var phase = fposmod(time*0.18+_noise(seed,k+7),1.0)
		var q = _scattered(p,radius*0.7,seed,k)+Vector2(sin(time+k)*2,-phase*8)
		_pixel(view,q,Vector2(3+phase*3,1.0),Color(0.64,0.72,0.39,0.28*(1-phase)))
		_pixel(view,q+Vector2(1,-2),Vector2.ONE*0.5,Color(0.75,0.79,0.48,0.6*(1-phase)))

func _quarantine_sign(view, p: Vector2, era: int, scale_: float):
	_pixel(view,p+Vector2(0,-5)*scale_,Vector2(0.5,5)*scale_,Color("635644"))
	var color = Color("cab15d") if era >= 8 else Color("a65246")
	_pixel(view,p+Vector2(0.5,-5)*scale_,Vector2(3.5,3)*scale_,color)
	var mark = Color("3b3330") if era >= 8 else Color("edccac")
	_pixel(view,p+Vector2(2,-4.5)*scale_,Vector2(0.5,2)*scale_,mark)
	_pixel(view,p+Vector2(1.25,-3.75)*scale_,Vector2(2,0.5)*scale_,mark)

func _atomic(view, p: Vector2, radius: float, time: float, age: float, seed: int, zoom: float):
	if age < 0.7:
		var alpha = (1.0-age/0.7)*0.75
		_pixel(view,p-Vector2(radius,radius*0.7),Vector2(radius*2,radius*1.4),Color(1,0.94,0.68,alpha))
		view.draw_arc(p,4+age*radius*2,0,TAU,32,Color(1,0.89,0.61,alpha),2)
	_crater(view,p,radius*0.72,seed)
	var rise = minf(1.0,age/2.3)
	var top = p+Vector2(0,-radius*1.7*rise)
	_pixel(view,top+Vector2(-3,0),Vector2(6,maxf(1.0,p.y-top.y)),Color(0.53,0.45,0.4,0.62))
	for k in range(7):
		var offset = Vector2((k-3)*radius*0.2,-sin(k/6.0*PI)*radius*0.24)
		_pixel(view,top+offset-Vector2(radius*0.18,2),Vector2(radius*0.36,8),Color(0.57+0.04*(k%2),0.51,0.46,0.7))
		_pixel(view,top+offset+Vector2(-radius*0.1,-4),Vector2(radius*0.2,12),Color(0.66,0.59,0.5,0.55))
	_smoke(view,p,18.0,time,seed,Color("585057"),4 if zoom>=1.6 else 2)

func _layout(town: Dictionary) -> Array:
	if _settlements == null and ResourceLoader.exists("res://scripts/settlement_painter.gd"):
		var script = load("res://scripts/settlement_painter.gd")
		if script != null and script.can_instantiate(): _settlements = script.new()
	if _settlements != null: return _settlements.layout(town)
	var entries = []
	for k in range(8):
		entries.append({"position":Vector2((k%4-1.5)*20,(k/4)*24-12),"kind":"house","seed":int(town.get("id",0))*17+k})
	return entries

func _condition_remains(sim, kind: String, x: int, y: int, radius: float) -> bool:
	var found_town = false
	var field = "plague" if kind == "plague" else "drought"
	for town in sim.state.get("settlements", []):
		if float(town.get("population", 0)) <= 0: continue
		if Vector2(float(town.get("x", 0)) - x, float(town.get("y", 0)) - y).length_squared() > radius * radius: continue
		found_town = true
		if int(town.get(field, 0)) > 0: return true
	if found_town: return false
	if kind == "plague": return false
	var tile = sim.get_tile(x,y) if sim.has_method("get_tile") else {}
	if tile.is_empty(): return true
	return float(tile.get("temperature", 0.5)) < 0.25 if kind == "ice" else float(tile.get("moisture", 0.5)) < 0.35

func _roof_height(entry: Dictionary, era: int) -> float:
	if entry.has("height"): return clampf(float(entry.height),2,40)
	var kind = str(entry.get("kind","house"))
	if kind in ["castle","temple","cathedral","tower","reactor","spaceport","academy"]: return 17.0
	if kind in ["farm","field","well","hearth"]: return 5.0
	return 9.5 + minf(4.5,era*0.35)

func _land(view, p: Vector2) -> bool:
	return not view.has_method("_is_land") or bool(view._is_land(floori(p.x/TILE),floori(p.y/TILE)))

func _visible(view, rect: Rect2) -> bool:
	return not view.has_method("_visible") or bool(view._visible(rect))

func _owned(view, town: Dictionary, p: Vector2, margin: float) -> bool:
	return not view.has_method("_detail_owns_position") or bool(view._detail_owns_position(town,p,margin))

func _scattered(p: Vector2, radius: float, seed: int, index: int) -> Vector2:
	var angle = _noise(seed,index*2+1)*TAU
	var distance = sqrt(_noise(seed,index*2+2))*radius
	return _snap(p+Vector2(cos(angle),sin(angle)*0.8)*distance)

func _noise(seed: int, salt: int) -> float:
	var value = (seed * 92821 + salt * 68917 + 113) % 1000003
	value = absi((value ^ (value >> 7)) * 48271) % 1000003
	return (value % 1000)/999.0

func _snap(p: Vector2) -> Vector2:
	return (p*2.0).round()*0.5

func _pixel(view, p: Vector2, size_: Vector2, color: Color):
	if not p.is_finite() or not size_.is_finite(): return
	var clean = Vector2(maxf(0.5,size_.x),maxf(0.5,size_.y))
	view.draw_rect(Rect2(_snap(p),clean),color)

func _polygon(view, points: Array, color: Color):
	var packed = PackedVector2Array()
	for point in points: packed.append(_snap(point))
	view.draw_colored_polygon(packed,color)
