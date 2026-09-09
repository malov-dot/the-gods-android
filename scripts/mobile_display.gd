extends RefCounted

static func configure(window:Window):
	var density=window.content_scale_factor
	if OS.has_feature("android"):
		# Android's engine screen scale is capped by the window dimensions. Using
		# it here shrinks a 48dp target to about 29dp on the Fold cover display.
		var native_density=0.0
		if Engine.has_singleton("TheGodsUpdater"):
			var bridge=Engine.get_singleton("TheGodsUpdater")
			if bridge.has_method("get_display_density"): native_density=float(bridge.get_display_density())
		density=android_density(native_density,DisplayServer.screen_get_dpi())
	elif OS.has_feature("web"):
		density=maxf(0.5,DisplayServer.screen_get_scale())
	if not is_equal_approx(window.content_scale_factor,density): window.content_scale_factor=density

static func android_density(native_density:float,reported_dpi:int)->float:
	if is_finite(native_density) and native_density>=0.5 and native_density<=8.0: return native_density
	return float(reported_dpi)/160.0 if reported_dpi>=80 and reported_dpi<=1280 else 1.0

static func hud_rect(viewport_size:Vector2,scale_factor:float)->Rect2:
	var viewport=Rect2(Vector2.ZERO,viewport_size)
	if not OS.has_feature("android"): return viewport
	var safe=DisplayServer.get_display_safe_area()
	if safe.size.x<=0 or safe.size.y<=0: return viewport
	var safe_rect=Rect2(Vector2(safe.position)/scale_factor,Vector2(safe.size)/scale_factor).intersection(viewport)
	return safe_rect if safe_rect.size.x>=300 and safe_rect.size.y>=240 else viewport
