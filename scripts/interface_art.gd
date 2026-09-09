extends Control

## Original filled HUD emblems on a 32-unit canvas. The HUD supplies accent
## colors for categories, active actions and disabled states.
const People = preload("res://scripts/people_painter.gd")
var kind = "emblem":
	set(value):
		kind = value
		queue_redraw()
var person = {}:
	set(value):
		person = value
		queue_redraw()
var accent = Color("d5ba80"):
	set(value):
		accent = value
		queue_redraw()
var _shade: Color
var _light: Color

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw():
	if size.x <= 0 or size.y <= 0: return
	_shade = accent.darkened(0.55)
	_light = accent.lightened(0.28)
	var c = size*0.5
	if kind == "backdrop":
		draw_rect(Rect2(Vector2.ZERO,size),Color("101b1b"))
		for i in range(48):
			var p = Vector2(fposmod(i*137.51+28,size.x),fposmod(i*i*37.8+40,size.y))
			draw_circle(p,1 if i%4 else 2,Color(0.66,0.69,0.52,0.13))
		return
	if kind == "portrait":
		_draw_portrait()
		return
	if kind == "emblem":
		var r = minf(size.x,size.y)*0.40
		draw_arc(c,r,0,TAU,48,Color(accent,0.55),1)
		draw_arc(c,r*0.72,0,TAU,40,Color(accent,0.18),1)
		var points = PackedVector2Array()
		for i in range(16):
			var angle = -PI/2+i*PI/8
			points.append(c+Vector2(cos(angle),sin(angle))*r*(1.0 if i%2==0 else 0.27))
		draw_colored_polygon(points,accent)
		draw_circle(c,3,Color("111d1d"))
		return
	var scale_ = minf(size.x,size.y)/32.0
	draw_set_transform((size-Vector2.ONE*32.0*scale_)*0.5,0,Vector2.ONE*scale_)
	var icon = str(kind).trim_prefix("power_")
	icon = {"nav_world":"layers","nav_people":"people","nav_realms":"realms","nav_menu":"menu","nav_powers":"essence"}.get(icon,icon)
	_draw_icon(icon)
	draw_set_transform(Vector2.ZERO)

func _draw_portrait():
	draw_style_box(_frame(),Rect2(Vector2.ZERO,size))
	var role = str(person.get("role","citizen"))
	role = {"ruler":"leader","artisan":"worker","merchant":"worker","healer":"scholar","soldier":"guard"}.get(role,role)
	var era = int(person.get("era",0))
	var portrait_seed = int(person.get("portrait_seed",0))
	var bounds = Rect2(-2,-8.5,5.5,9)
	match role:
		"child": bounds = Rect2(-1.5,-6.5,3,7)
		"farmer": bounds = Rect2(-2,-9.5,6.5,10)
		"worker": bounds = Rect2(-2.5,-9,7.5,9.5)
		"scholar": bounds = Rect2(-2,-9,6.5,9.5)
		"leader": bounds = Rect2(-2,-9.5,4,10)
		"prophet": bounds = Rect2(-2,-10,6,10.5)
		"guard", "archer":
			bounds = Rect2(-4,-10,11.5,10.5)
			if era<=5 and role!="archer" and (era<2 or portrait_seed%3==0): bounds = Rect2(-4,-13.5,8,14)
		"banner": bounds = Rect2(-2,-15.5,11.5,16)
	var scale_ = maxf(0.1,minf((size.x-7.0)/bounds.size.x,(size.y-7.0)/bounds.size.y))
	draw_rect(Rect2(Vector2(3,size.y-6),Vector2(maxf(0,size.x-6),3)),Color("263733"))
	draw_set_transform(Vector2(size.x*0.5-bounds.get_center().x*scale_,size.y-4.0),0,Vector2.ONE*scale_)
	People.new().draw_person(self,Vector2.ZERO,era,accent,portrait_seed,role,1,0,"standing")
	draw_set_transform(Vector2.ZERO)

func _draw_icon(icon: String):
	match icon:
		"favorite", "favorite_empty":
			var star=PackedVector2Array()
			for i in range(10):
				var angle=-PI/2+i*PI/5
				star.append(Vector2(16,16)+Vector2(cos(angle),sin(angle))*(13 if i%2==0 else 6))
			if icon=="favorite": draw_colored_polygon(star,accent)
			else:
				star.append(star[0])
				draw_polyline(star,accent,2,true)
		"category_terrain", "mountain":
			_poly([2,27,11,11,16,18,22,5,31,27],_shade)
			_poly([7,27,22,5,28,27],accent)
			_poly([16,14,22,5,25,15,21,12,19,15],_light)
			_poly([3,27,11,11,15,21,11,18,7,27],accent)
		"category_nature", "forest":
			_rect(8,20,3,8,_shade)
			_poly([1,21,9,7,16,21],accent)
			_rect(21,19,3,10,_shade)
			_poly([12,24,17,16,14,16,22,3,30,16,27,16,32,24],accent)
			_poly([22,3,22,24,12,24,17,16,14,16],_light)
		"category_life", "population", "people":
			_person(Vector2(7,17),0.73,_shade)
			_person(Vector2(25,17),0.73,_shade)
			_person(Vector2(16,18),1.0,accent)
			draw_circle(Vector2(15,9),2,_light)
		"category_god", "faith":
			_poly([14,15,3,10,4,17,8,22,14,24],accent)
			_poly([18,15,29,10,28,17,24,22,18,24],accent)
			_poly([13,13,16,10,19,13,20,26,12,26],_light)
			_ring(Vector2(16,6),5,2,accent)
			_rect(3,16,6,2,_shade)
			_rect(23,16,6,2,_shade)
		"category_devil", "demon": _demon()
		"category_disaster", "meteor":
			_poly([5,17,15,5,15,11,29,1,25,13,31,10,21,25],accent)
			_poly([12,20,24,7,19,22],_light)
			_poly([3,20,7,16,14,16,19,21,17,27,11,30,5,27],_shade)
			_poly([5,21,9,18,13,19,12,23,8,25],accent)
		"land":
			_poly([2,22,8,16,15,16,20,20,29,20,30,26,2,26],accent)
			_poly([2,26,30,26,26,30,6,30],_shade)
			_poly([10,11,16,3,22,11,18,11,18,16,14,16,14,11],_light)
		"water":
			for y in [12,21]:
				_poly([2,y+4,6,y+4,12,y-3,16,y-4,15,y+1,20,y+4,30,y+4,30,y+8,2,y+8],accent if y==12 else _shade)
			_poly([4,15,10,8,15,8,12,10,9,15],_light)
		"fertility":
			_poly([3,23,29,23,26,29,6,29],_shade)
			_rect(14,14,3,11,accent)
			_poly([15,17,7,17,3,10,10,10,16,14],accent)
			_poly([16,14,17,7,27,3,26,11,22,15],_light)
			_rect(6,23,20,2,accent)
		"ore", "essence":
			_poly([7,9,16,2,25,9,27,20,16,30,5,20],_shade)
			_poly([7,9,16,2,16,29,5,20],accent)
			_poly([7,9,16,2,25,9,18,13],_light)
			_poly([18,13,25,9,27,20,16,30],accent)
			_poly([7,9,18,13,16,30],_shade)
		"warm": _sun(Vector2(16,16),7)
		"cool", "ice": _snow()
		"settlement", "home": _house()
		"wildlife":
			_poly([9,19,16,14,23,19,25,26,20,29,16,27,12,29,7,26],accent)
			for toe in [Vector2(5,15),Vector2(12,8),Vector2(21,8),Vector2(28,15)]: draw_circle(toe,3.2,_light)
		"heal":
			_poly([3,10,6,5,12,5,16,9,20,5,26,5,29,10,29,16,16,29,3,16],_shade)
			_cross(Vector2(16,16),8,accent)
			_rect(14,8,2,6,_light)
		"rain":
			_cloud()
			for x in [7,16,25]: _poly([x,22,x-3,27,x-2,30,x+1,29,x+2,27],_light)
		"bless":
			_poly([3,24,8,21,13,21,16,24,24,18,29,19,23,26,16,29,8,28],accent)
			_star(Vector2(17,11),9,_light)
		"protect":
			_poly([3,5,16,2,29,5,27,20,23,25,16,30,9,25,5,20],accent)
			_poly([16,6,25,8,23,19,20,23,16,26],_shade)
			_poly([7,8,16,6,16,26,11,22,8,18],_light)
		"inspire":
			_book()
			_star(Vector2(16,8),6,_light)
		"prophet":
			_person(Vector2(14,19),1.0,accent)
			_poly([10,16,18,16,21,29,7,29],accent)
			_rect(25,10,2,20,_shade)
			_star(Vector2(26,8),5,_light)
			_ring(Vector2(14,5),5,1.8,_light)
		"relic":
			_poly([7,7,25,7,23,17,18,21,18,26,24,27,24,30,8,30,8,27,14,26,14,21,9,17],accent)
			_poly([7,7,25,7,23,10,9,10],_light)
			_poly([18,11,23,10,21,16,18,18],_shade)
			_star(Vector2(16,4),4,_light)
		"purify":
			_poly([14,5,24,18,25,24,21,29,12,30,6,26,6,20],accent)
			_poly([11,17,9,23,13,27,8,25,7,21],_light)
			_star(Vector2(24,8),7,_light)
		"resurrect":
			_poly([3,28,8,21,13,25,18,22,28,28],_shade)
			_person(Vector2(16,17),0.8,accent)
			_poly([2,13,7,7,12,13,9,13,9,21,5,21,5,13],_light)
			_poly([22,13,27,7,32,13,29,13,29,21,25,21,25,13],_light)
		"peace":
			_poly([3,18,12,18,7,6,18,12,21,16,25,13,29,16,26,20,20,25,12,25],accent)
			_poly([7,6,12,19,16,17],_light)
			draw_line(Vector2(22,28),Vector2(29,22),_shade,2)
			_poly([24,25,23,21,27,22,29,19,30,23,27,26],_light)
		"tempt": _coins()
		"pact":
			_poly([7,3,24,3,26,7,25,24,28,24,28,29,8,29,5,25,6,8,3,8,3,3],accent)
			_rect(6,3,4,5,_light)
			_rect(9,10,11,2,_shade)
			_rect(9,15,8,2,_shade)
			draw_circle(Vector2(21,22),5,_shade)
			_poly([18,26,20,31,22,28,24,31,25,26],_light)
		"cult":
			_poly([3,27,8,11,16,2,24,11,29,27],accent)
			_poly([10,17,16,9,22,17,20,24,12,24],_shade)
			_rect(12,17,3,2,_light)
			_rect(18,17,3,2,_light)
		"possess":
			_person(Vector2(16,20),1.05,_shade)
			_eye(Vector2(16,11),0.88)
		"forbidden":
			_book()
			_eye(Vector2(16,14),0.70)
		"curse":
			_poly([3,27,13,23,20,24,29,27,29,30,3,30],_shade)
			draw_line(Vector2(16,27),Vector2(16,8),accent,3)
			_poly([15,18,7,16,4,10,9,12,12,13,11,6,15,11],accent)
			_poly([17,15,22,11,25,5,26,12,23,17,17,20],accent)
			_rect(21,22,3,3,_light)
		"idol":
			_poly([10,7,16,3,22,7,23,16,19,21,21,25,27,27,27,30,5,30,5,27,11,25,13,21,9,16],accent)
			_poly([10,7,16,3,16,23,11,25,13,21,9,16],_shade)
			_rect(11,11,3,2,_light)
			_rect(18,11,3,2,_light)
			_rect(9,27,14,2,_light)
		"discord": _swords()
		"fire": _flame()
		"drought":
			_sun(Vector2(22,9),4)
			_poly([2,21,14,19,12,24,17,26,12,30,2,30],accent)
			_poly([18,20,30,22,30,30,17,30,21,26,16,23],_shade)
			_poly([5,17,5,6,8,6,8,10,11,8,12,11,8,14,8,18],accent)
		"plague": _skull()
		"earthquake":
			_poly([2,6,16,3,11,12,17,16,10,22,14,29,2,27],accent)
			_poly([21,3,30,6,30,27,18,29,14,23,23,16,17,12],_shade)
			_poly([3,6,14,4,11,7,3,9],_light)
			_poly([22,4,29,6,29,9,20,7],accent)
		"storm":
			_cloud()
			_poly([16,16,25,16,19,23,24,23,13,32,15,25,10,25],_light)
		"volcano":
			_poly([2,29,10,12,22,12,30,29],_shade)
			_poly([2,29,10,12,15,12,12,21,8,22,8,29],accent)
			_poly([11,12,21,12,21,17,25,23,20,22,17,17,14,21,13,16],_light)
			_poly([13,10,9,3,14,5,16,1,20,4,23,2,20,10],accent)
		"heal_person", "inspire_person", "bless_person", "tempt_person", "corrupt_person", "incite_person":
			_person(Vector2(11,20),1.05,accent)
			match icon:
				"heal_person": _cross(Vector2(24,10),6,_light)
				"inspire_person": _star(Vector2(24,10),7,_light)
				"bless_person":
					_ring(Vector2(11,5),6,2,_light)
					_star(Vector2(26,18),5,_light)
				"tempt_person":
					draw_circle(Vector2(24,10),6,_shade)
					draw_circle(Vector2(24,9),5,_light)
					_rect(23,6,2,6,accent)
				"corrupt_person": _eye(Vector2(23,9),0.67)
				"incite_person": _poly([23,18,18,12,23,5,23,9,28,2,28,14],_light)
		"observe": _eye(Vector2(16,16),1.12)
		"menu":
			for y in [7,14,21]:
				_rect(5,y,22,4,accent)
				_rect(5,y,4,4,_light)
		"settings":
			var points = PackedVector2Array()
			for i in range(32):
				var angle = TAU*float(i)/32.0
				var r = 13.0 if i%4 in [1,2] else 10.0
				points.append(Vector2(16,16)+Vector2(cos(angle),sin(angle))*r)
			draw_colored_polygon(points,accent)
			draw_circle(Vector2(16,16),6,_shade)
			draw_circle(Vector2(16,16),3,_light)
		"pause":
			_rect(7,5,6,23,accent)
			_rect(20,5,6,23,accent)
			_rect(7,5,2,23,_light)
			_rect(20,5,2,23,_light)
		"play":
			_poly([7,3,28,16,7,29],accent)
			_poly([7,3,28,16,7,10],_light)
		"speed":
			_poly([2,6,16,16,2,26],accent)
			_poly([16,6,30,16,16,26],_light)
		"layers":
			_poly([2,23,16,16,30,23,16,30],_shade)
			_poly([2,17,16,10,30,17,16,24],accent)
			_poly([2,10,16,3,30,10,16,17],_light)
		"realms":
			_rect(5,4,3,26,_shade)
			_poly([8,5,17,3,29,6,25,14,27,21,16,18,8,20],accent)
			_poly([8,5,17,3,17,18,8,20],_light)
			_rect(3,28,10,3,accent)
		"zoom_in", "zoom_out":
			_ring(Vector2(13,13),9,4,accent)
			_poly([18,22,22,18,31,27,27,31],_shade)
			_rect(8,12,10,2,_light)
			if icon=="zoom_in": _rect(12,8,2,10,_light)
		"close": _poly([6,3,16,13,26,3,29,6,19,16,29,26,26,29,16,19,6,29,3,26,13,16,3,6],accent)
		"expand":
			_poly([18,4,28,4,28,14,25,14,25,9,18,16,16,14,23,7,18,7],_light)
			_poly([14,28,4,28,4,18,7,18,7,23,14,16,16,18,9,25,14,25],accent)
		"info":
			draw_circle(Vector2(16,16),13,accent)
			_rect(14,14,4,11,_shade)
			_rect(12,23,8,2,_shade)
			draw_circle(Vector2(16,9),2.5,_light)
		"history":
			_book()
			for x in [7,19]:
				_rect(x,13,6,2,_light)
				_rect(x,18,6,2,_light)
		"year":
			_rect(5,3,22,4,accent)
			_rect(5,26,22,4,accent)
			_poly([8,7,24,7,23,12,18,17,23,21,24,26,8,26,9,21,14,17,9,12],_shade)
			_poly([10,7,22,7,21,11,16,16,11,11],_light)
			_poly([10,26,11,23,16,19,21,23,22,26],accent)
		"era":
			_rect(3,25,26,5,_shade)
			_rect(6,20,20,5,accent)
			_rect(9,15,14,5,accent)
			_rect(12,6,8,9,accent)
			_poly([12,6,16,2,20,6],_light)
			_rect(12,6,3,14,_light)
			_rect(6,20,3,5,_light)
		_: _star(Vector2(16,16),12,accent)

func _poly(coords: Array,color: Color):
	var points = PackedVector2Array()
	for i in range(0,coords.size(),2): points.append(Vector2(coords[i],coords[i+1]))
	draw_colored_polygon(points,color)

func _rect(x: float,y: float,w: float,h: float,color: Color):
	draw_rect(Rect2(x,y,w,h),color)

func _ring(center: Vector2,radius: float,width: float,color: Color):
	draw_arc(center,radius-width*0.5,0,TAU,32,color,width)

func _star(center: Vector2,radius: float,color: Color):
	var points = PackedVector2Array()
	for i in range(8):
		var angle = -PI*0.5+float(i)*PI*0.25
		points.append(center+Vector2(cos(angle),sin(angle))*radius*(1.0 if i%2==0 else 0.31))
	draw_colored_polygon(points,color)

func _person(center: Vector2,scale_: float,color: Color):
	draw_circle(center+Vector2(0,-9)*scale_,4.0*scale_,color)
	var points = PackedVector2Array()
	for p in [Vector2(-5,-3),Vector2(5,-3),Vector2(8,3),Vector2(8,9),Vector2(-8,9),Vector2(-8,3)]: points.append(center+p*scale_)
	draw_colored_polygon(points,color)

func _cross(center: Vector2,radius: float,color: Color):
	var w = radius*0.36
	draw_rect(Rect2(center-Vector2(w,radius),Vector2(w*2,radius*2)),color)
	draw_rect(Rect2(center-Vector2(radius,w),Vector2(radius*2,w*2)),color)

func _eye(center: Vector2,scale_: float):
	var points = PackedVector2Array()
	for p in [Vector2(-13,0),Vector2(-7,-6),Vector2(0,-8),Vector2(7,-6),Vector2(13,0),Vector2(7,6),Vector2(0,8),Vector2(-7,6)]: points.append(center+p*scale_)
	draw_colored_polygon(points,accent)
	draw_circle(center,5.3*scale_,_shade)
	draw_circle(center,2.8*scale_,_light)

func _sun(center: Vector2,radius: float):
	for i in range(8):
		var direction = Vector2(cos(i*PI/4),sin(i*PI/4))
		draw_line(center+direction*(radius+2),center+direction*(radius+5),accent,2.5)
	draw_circle(center,radius,accent)
	draw_circle(center-Vector2(2,2),radius*0.46,_light)

func _snow():
	for i in range(6):
		var direction = Vector2(cos(i*PI/3),sin(i*PI/3))
		var normal = Vector2(-direction.y,direction.x)
		draw_line(Vector2(16,16),Vector2(16,16)+direction*13,accent,3)
		for side in [-1,1]: draw_line(Vector2(16,16)+direction*8,Vector2(16,16)+direction*11+normal*4*side,accent,2)
	_star(Vector2(16,16),5,_light)

func _house():
	_rect(6,14,21,15,accent)
	_rect(21,4,4,9,_shade)
	_poly([2,16,16,3,30,16],_shade)
	_poly([2,16,16,3,16,8,7,16],_light)
	_rect(13,20,6,9,_shade)
	_rect(8,19,3,4,_light)
	_rect(21,19,3,4,_light)
	_rect(4,28,25,2,_shade)

func _cloud():
	draw_circle(Vector2(8,14),6,accent)
	draw_circle(Vector2(15,10),7,accent)
	draw_circle(Vector2(24,14),6,accent)
	_rect(7,13,19,7,accent)
	_poly([4,18,28,18,26,21,7,21],_shade)
	draw_circle(Vector2(13,8),3,_light)

func _book():
	_poly([2,6,11,5,16,8,21,5,30,6,30,27,21,26,16,29,11,26,2,27],_shade)
	_poly([4,7,11,7,15,10,15,26,11,24,4,24],accent)
	_poly([17,10,21,7,28,7,28,24,21,24,17,26],accent)
	_rect(4,7,2,17,_light)

func _coins():
	for p in [Vector2(12,23),Vector2(12,19),Vector2(12,15),Vector2(22,26),Vector2(22,22)]:
		draw_rect(Rect2(p-Vector2(8,2),Vector2(16,5)),_shade)
		var points = PackedVector2Array()
		for i in range(20):
			var angle = float(i)*TAU/20.0
			points.append(p-Vector2(0,2)+Vector2(cos(angle),sin(angle))*Vector2(8,3))
		draw_colored_polygon(points,accent)
	draw_circle(Vector2(22,9),7,_shade)
	draw_circle(Vector2(22,8),6,_light)
	_rect(21,4,2,8,accent)

func _demon():
	_poly([5,4,8,11,12,9,20,9,24,11,27,4,29,14,25,23,16,30,7,23,3,14],accent)
	_poly([16,9,20,9,24,11,27,4,29,14,25,23,16,30],_shade)
	_poly([7,16,13,18,12,21,8,20],_light)
	_poly([25,16,19,18,20,21,24,20],_light)
	_poly([12,24,16,26,20,24,18,28,14,28],_light)

func _swords():
	_poly([4,2,10,5,25,24,22,27,5,10],accent)
	_poly([28,2,22,5,7,24,10,27,27,10],_light)
	draw_line(Vector2(5,20),Vector2(13,27),_shade,3)
	draw_line(Vector2(27,20),Vector2(19,27),_shade,3)
	draw_line(Vector2(7,25),Vector2(4,29),accent,3)
	draw_line(Vector2(25,25),Vector2(28,29),accent,3)

func _flame():
	_poly([6,26,3,20,6,12,10,17,13,8,20,1,20,12,26,7,29,19,27,25,22,30,12,30],accent)
	_poly([11,25,10,21,16,14,17,21,22,17,22,25,17,29],_light)

func _skull():
	_poly([7,4,16,2,25,4,29,10,29,19,24,23,24,29,8,29,8,23,3,19,3,10],accent)
	_poly([16,2,25,4,29,10,29,19,24,23,24,29,16,29],_shade)
	_rect(7,12,7,6,_shade)
	_rect(19,12,7,6,_light)
	_poly([16,18,19,22,13,22],_shade)
	for x in [11,16,21]: _rect(x,26,2,4,_light)

func _frame():
	var box = StyleBoxFlat.new()
	box.bg_color = Color("182724")
	box.border_color = Color("4f5743")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box
