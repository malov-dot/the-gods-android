extends RefCounted
## Original 32x48 pixel sprites. Four walking frames and bounded texture cache.
const SIZE=Vector2i(32,48)
const INK=Color("253039")
const SKIN=[Color("edc296"),Color("ce956b"),Color("aa704e"),Color("80513c"),Color("dab087")]
const HAIR=[Color("3b2c29"),Color("674b35"),Color("bd9158"),Color("bbb9a7"),Color("292f33")]
var textures={}
func texture(era:int,flag:Color,seed_:int,role:String,frame:int,sick:bool=false,direction:float=1)->ImageTexture:
	var key="%d:%s:%d:%s:%d:%s:%s"%[era,flag.to_html(),seed_%100,role,frame,sick,direction<0]
	if not textures.has(key):
		if textures.size()>=512: textures.erase(textures.keys()[0])
		var im=pixels(era,flag,seed_,role,frame,sick)
		if direction<0: im.flip_x()
		textures[key]=ImageTexture.create_from_image(im)
	return textures[key]
static func pixels(era:int,flag:Color,seed_:int,role:String,frame:int,sick:bool=false)->Image:
	var im=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8); im.fill(Color.TRANSPARENT)
	var skin=SKIN[absi(seed_)%SKIN.size()]; var hair=HAIR[(absi(seed_)/5)%HAIR.size()]
	if sick: skin=skin.lerp(Color("aba66e"),0.4)
	var fabrics=[Color("708da0"),Color("a77669"),Color("82966a"),Color("b9a27a"),Color("8a789e"),Color("659b96")]
	var cloth=fabrics[(absi(seed_)/7)%fabrics.size()].lerp(flag,0.2)
	var metal=Color("bbd1ce") if era!=2 else Color("b49058")
	var military=role in ["soldier","guard","archer","banner","cavalry"]
	if era<2: cloth=Color("b7a37b").lerp(fabrics[(absi(seed_)/7)%fabrics.size()],0.25)
	if era>=9 and role in ["merchant","politician","judge","leader"]: cloth=Color("42566b").lerp(flag,0.2)
	if role=="healer": cloth=Color("e5e8d4") if era>=9 else Color("acd0b2")
	if role=="leader": cloth=flag.darkened(0.15)
	if role in ["scholar","prophet"]: cloth=Color("dfd9bb")
	if military: cloth=flag.lerp(Color("596b55") if era>=9 else Color("aaa986"),0.55)
	var stride=[0,2,0,-2][frame%4]
	var bob=1 if frame%2==1 else 0
	# A soft stepped ground shadow and independently animated boots.
	_rect(im,8,44,16,2,Color(0.03,0.08,0.08,0.3)); _rect(im,10,43,12,4,Color(0.03,0.08,0.08,0.18))
	for leg in [0,1]:
		var x=11+leg*6; var dy=stride if leg==0 else -stride
		_rect(im,x,33,5,10+dy,INK); _rect(im,x+1,34,3,7+dy,cloth.darkened(0.45))
		_rect(im,x+1,34,1,7+dy,cloth.darkened(0.2)); _rect(im,x-1,42+dy,6,2,Color("493930")); _rect(im,x,42+dy,4,1,Color("8b6950"))
	if role in ["leader","prophet"] and era<8:
		_rect(im,8,19+bob,16,20,cloth.darkened(0.6)); _rect(im,9,21+bob,3,17,cloth.darkened(0.25)); _rect(im,21,21+bob,2,17,cloth.darkened(0.4))
	# Sleeves and hands outline the torso, with shaded cloth folds.
	_rect(im,7,20+bob,18,13,INK)
	_rect(im,8,22+bob,3,9-stride,cloth.darkened(0.25)); _rect(im,22,22+bob,2,9+stride,cloth)
	_rect(im,8,30+bob-stride,3,3,skin.darkened(0.18)); _rect(im,8,30+bob-stride,2,2,skin)
	_rect(im,22,30+bob+stride,3,3,skin.darkened(0.18)); _rect(im,22,30+bob+stride,2,2,skin)
	_rect(im,10,19+bob,12,17,INK); _rect(im,11,20+bob,10,14,cloth)
	_rect(im,11,21+bob,2,11,cloth.lightened(0.24)); _rect(im,19,22+bob,2,11,cloth.darkened(0.3))
	_rect(im,14,23+bob,1,7,cloth.lightened(0.1)); _rect(im,17,28+bob,1,4,cloth.darkened(0.2))
	_rect(im,11,32+bob,10,2,Color("654a36")); _rect(im,15,32+bob,2,2,Color("d7b969")); _rect(im,15,32+bob,1,1,Color("fff0ae"))
	if military and era>=2:
		var armor=metal if era<6 else Color("665d4c")
		if era>=9: armor=Color("566951")
		if era>=12: armor=Color("afc7c5")
		_rect(im,11,21+bob,10,9,armor.darkened(0.4)); _rect(im,12,21+bob,8,7,armor)
		_rect(im,12,21+bob,2,6,armor.lightened(0.25)); _rect(im,16,21+bob,1,8,armor.darkened(0.3))
		for y in [23,26,29]: _rect(im,12,y+bob,8,1,armor.darkened(0.17))
		_rect(im,14,29+bob,4,2,flag)
	elif role=="worker":
		_rect(im,13,24+bob,7,7,Color("806347")); _rect(im,14,25+bob,5,1,Color("b09065"))
	elif role=="leader" and era>=8:
		_rect(im,14,20+bob,4,8,Color("e7dec6")); _rect(im,15,22+bob,2,7,flag)
	# Neck, ears and a multi-tone face: brows, eyes, nose, mouth and jaw.
	_rect(im,14,17+bob,4,3,skin.darkened(0.3)); _rect(im,14,17+bob,3,2,skin)
	_rect(im,10,9+bob,12,9,hair); _rect(im,9,12+bob,14,4,skin.darkened(0.25))
	_rect(im,11,10+bob,10,8,skin); _rect(im,12,10+bob,6,5,skin.lightened(0.16))
	_rect(im,20,11+bob,1,6,skin.darkened(0.25)); _rect(im,12,17+bob,8,1,skin.darkened(0.3))
	_rect(im,12,12+bob,3,1,hair); _rect(im,17,12+bob,3,1,hair)
	_rect(im,12,13+bob,3,1,Color("ecead7")); _rect(im,17,13+bob,3,1,Color("ecead7")); _rect(im,14,13+bob,1,1,INK); _rect(im,19,13+bob,1,1,INK)
	_rect(im,16,13+bob,1,3,skin.darkened(0.18)); _rect(im,16,15+bob,2,1,skin.lightened(0.18)); _rect(im,14,17+bob,4,1,Color("955e51"))
	_rect(im,10,8+bob,12,3,hair); _rect(im,11,8+bob,8,1,hair.lightened(0.3)); _rect(im,10,11+bob,2,4,hair)
	if seed_%4==1: _rect(im,8,10+bob,3,10,hair);_rect(im,21,10+bob,3,10,hair);_rect(im,22,11+bob,1,8,hair.lightened(0.2))
	elif seed_%4==2: _rect(im,11,6+bob,8,3,hair);_rect(im,12,6+bob,4,1,hair.lightened(0.25))
	if seed_%3==0: _rect(im,11,15+bob,1,3,hair); _rect(im,19,15+bob,2,3,hair); _rect(im,12,18+bob,8,1,hair)
	if role=="farmer":
		_rect(im,7,9+bob,18,2,Color("9d793f")); _rect(im,11,6+bob,10,3,Color("dcc078")); _rect(im,12,6+bob,8,1,Color("f5dda0"))
		_rect(im,26,19,1,25,Color("ad8050")); _rect(im,24,18,7,2,metal); _rect(im,24,19,1,3,metal)
	elif role=="worker":
		if era>=8: _rect(im,9,9+bob,14,2,Color("dab051")); _rect(im,11,6+bob,10,3,Color("f2cc6c"))
		_rect(im,26,23,1,19,Color("a37d4c")); _rect(im,23,22,8,2,metal); _rect(im,29,23,2,2,metal.darkened(0.3))
	elif role=="scholar":
		_rect(im,22,27,8,7,Color("6b443c")); _rect(im,23,27,6,5,Color("e6d9ac") if era<11 else Color("7ec9da")); _rect(im,26,28,1,4,Color("a59770"))
	elif role=="healer":
		_rect(im,24,29,7,8,Color("586e64"));_rect(im,26,30,2,5,Color("ebeadb"));_rect(im,25,32,4,1,Color("ebeadb"))
		if era>=9: _rect(im,11,8+bob,10,3,Color("e8ecd9"))
	elif role=="merchant":
		_rect(im,23,29,7,8,Color("825a42"));_rect(im,25,27,3,2,Color("c49a67"))
	elif role=="leader" and era<8:
		_rect(im,10,7+bob,12,2,Color("e3bd58"))
		for x in [10,15,20]: _rect(im,x,5+bob,2,3,Color("f6d779"))
		_rect(im,15,7+bob,2,1,flag)
	elif role=="prophet":
		_rect(im,27,4,1,40,Color("a98751")); _rect(im,25,3,5,4,Color("e7c473")); _rect(im,26,4,3,2,Color("fff0bd"))
	if military:
		if era>=2:
			var helmet=metal if era<6 or era>=12 else Color("59715a")
			_rect(im,9,9+bob,14,2,helmet.darkened(0.4)); _rect(im,11,6+bob,10,4,helmet); _rect(im,12,6+bob,5,1,helmet.lightened(0.3))
			if era in [3,4,5]: _rect(im,15,3+bob,3,4,flag); _rect(im,16,10+bob,1,4,metal)
			if era>=12: _rect(im,11,11+bob,10,3,Color("48738d")); _rect(im,12,11+bob,6,1,Color("b9f4e9"))
		if role=="archer":
			_rect(im,27,17,1,20,Color("ba945c")); _rect(im,29,20,1,14,Color("8b633e")); _rect(im,28,18,1,19,Color("bea679")); _rect(im,24,27,7,1,metal)
		elif era<6:
			if seed_%2==0 or era<3:
				_rect(im,27,9,1,34,Color("aa865a")); _rect(im,26,6,3,4,metal); _rect(im,27,4,1,3,metal.lightened(0.3))
			else:
				_rect(im,27,16,2,14,metal); _rect(im,27,15,1,15,metal.lightened(0.35)); _rect(im,25,30,6,1,Color("dfbd73")); _rect(im,27,31,2,4,Color("825c3f"))
			_rect(im,4,23,6,10,INK); _rect(im,5,24,4,8,flag); _rect(im,6,25,2,6,flag.lightened(0.3)); _rect(im,6,27,2,2,metal)
		else:
			_rect(im,22,27,9,2,Color("435151")); _rect(im,23,26,8,1,metal); _rect(im,23,29,2,4,Color("70563c")); _rect(im,28,25,2,1,Color("728c8f"))
			if era>=12: _rect(im,25,27,5,1,Color("86e6df"))
	if role=="banner":
		_rect(im,24,1,1,43,Color("b69661")); _rect(im,25,1,7,8,flag.darkened(0.3)); _rect(im,25,1,6,6,flag); _rect(im,27,2,2,3,Color("f2d992"))
	return im
static func _rect(im,x,y,w,h,color): im.fill_rect(Rect2i(x,y,w,h),color)
