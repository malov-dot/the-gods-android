extends RefCounted
## Short, bounded presentation effects. Real seconds, independent of saved years.
static func draw(view):
	for effect in view.cast_feedback:
		var age=float(effect.age);var alpha=clampf((float(effect.duration)-age)/0.8,0,1)
		var p=(Vector2(effect.x,effect.y)+Vector2.ONE*0.5)*view.TILE
		if not str(effect.person).is_empty():
			for pictured in view._pictured_people:
				if pictured.key==effect.person: p=pictured.position;break
		var screen=p*view.zoom+view._camera
		if not Rect2(Vector2(-200,-200),view.size+Vector2(400,400)).has_point(screen): continue
		var color=Color("ffe293")
		if effect.id in ["fire","meteor","volcano","earthquake","discord"]: color=Color("ff956c")
		elif effect.id in ["cult","idol","demon","forbidden","curse_person","possess_person","tempt_person","corrupt_person"]: color=Color("d69cff")
		elif effect.id in ["heal_person","purify_person","comfort_person","rain","protect"]: color=Color("7df8c6")
		if effect.failed: color=Color("ff817d")
		if effect.queued: color=Color("e8c985")
		var radius=maxf(22,float(effect.radius)*view.TILE*view.zoom)
		if not effect.person.is_empty(): radius=30
		view.draw_set_transform(Vector2.ZERO)
		view.draw_circle(screen,radius,Color(color,0.09*alpha))
		view.draw_arc(screen,radius*(0.8+0.2*sin(age*4)),0,TAU,48,Color(color,alpha),2)
		if not effect.failed and not effect.queued:
			view.draw_set_transform(view._camera.round(),0,Vector2.ONE*view.zoom)
			var r=float(effect.radius)*view.TILE
			match str(effect.id):
				"meteor": view.calamities._meteor(view,p,r,view._time,age,19,view.zoom)
				"fire": view.calamities._fire_ground(view,p,r,view._time,19,view.zoom)
				"volcano": view.calamities._volcano(view,p,r,view._time,19,view.zoom)
				"earthquake": view.calamities._earthquake(view,p,r,view._time,age,19,view.zoom)
				"rain","storm": view.calamities._storm(view,p,r,view._time,19,effect.id=="storm",view.zoom)
				"ice": view.calamities._freeze(view,p,r,view._time,19,view.zoom)
				"drought": view.calamities._drought(view,p,r,19,view.zoom)
				"plague": view.calamities._plague_air(view,p,r,view._time,19,view.zoom)
			view.draw_set_transform(Vector2.ZERO)
			for i in range(12):
				var phase=fposmod(age*0.6+i/12.0,1)
				var particle=screen+Vector2.RIGHT.rotated(i*TAU/12+age)*radius*phase-Vector2(0,phase*30)
				view.draw_circle(particle,2,Color(color,alpha*(1-phase)))
			if not effect.person.is_empty():
				view.draw_line(screen-Vector2(0,95),screen-Vector2(0,15),Color(color,alpha*0.4),6)
		var text=str(effect.label)
		var font_size=16
		var width=minf(view.size.x-24,view._font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+20)
		var box=Rect2(Vector2(clampf(screen.x-width/2,12,maxf(12,view.size.x-width-12)),clampf(screen.y-radius-44,115,maxf(115,view.size.y-170))),Vector2(width,30))
		view.draw_style_box(_box(color,alpha),box)
		view.draw_string(view._font,box.position+Vector2(10,21),text,HORIZONTAL_ALIGNMENT_LEFT,width-20,font_size,Color(color,alpha))

static func _box(color,alpha):
	var box=StyleBoxFlat.new();box.bg_color=Color(0.04,0.09,0.12,0.95*alpha)
	box.border_color=Color(color,alpha);box.set_border_width_all(1);box.set_corner_radius_all(4)
	return box
