extends Node
## Bounded, precomputed Foley voices; camera distance controls audibility.
var app
var players=[]
var bank={}
var clock_=0.0
var sequence=0
var last_speech=""
var last_key=""
var speech_time=-10000
var speech_available=false
var voices_enabled=true

func setup(host):
	app=host
	for i in range(4):
		var player=AudioStreamPlayer.new(); add_child(player); players.append(player)
	for kind in ["steel","bow","hoof","catapult","musket","cannon","rifle","engine","plasma","water","bell"]:
		for pan in [-1,0,1]: bank[kind+str(pan)]=foley(kind,pan)

static func foley(kind:String,pan:int=0)->AudioStreamWAV:
	var rate=22050
	var duration=0.8 if kind in ["cannon","catapult","engine","bell"] else 0.32
	var frames=int(rate*duration)
	var data=PackedByteArray(); data.resize(frames*4)
	var noise=RandomNumberGenerator.new(); noise.seed=kind.hash()
	var low=0.0
	for i in range(frames):
		var t=float(i)/rate
		var n=noise.randf_range(-1,1); low=lerpf(low,n,0.12)
		var wave=0.0
		match kind:
			"steel": wave=(sin(TAU*1471*t)+sin(TAU*2387*t)*0.45)*exp(-t*19)*0.32+n*exp(-t*95)*0.35
			"bow": wave=sin(TAU*(210-130*t)*t)*exp(-t*28)*0.35+n*exp(-t*32)*0.25
			"hoof": wave=(sin(TAU*155*t)*0.7+low)*exp(-fmod(t,0.14)*48)*0.5
			"catapult": wave=low*exp(-t*8)*0.9+sin(TAU*75*t)*exp(-t*11)*0.35+n*exp(-t*80)*0.2
			"musket","rifle": wave=n*exp(-t*65)*0.85+low*exp(-t*14)*0.55+sin(TAU*90*t)*exp(-t*32)*0.3
			"cannon": wave=n*exp(-t*38)*0.65+low*exp(-t*5)*1.2+sin(TAU*(65-20*t)*t)*exp(-t*8)*0.5
			"engine": wave=(sin(TAU*80*t)*0.18+sin(TAU*121*t)*0.13+low*0.7)*(0.7+0.3*sin(TAU*17*t))*sin(PI*t/duration)
			"plasma": wave=sin(TAU*(1700-2400*t)*t)*exp(-t*16)*0.4+low*exp(-t*25)*0.3
			"water": wave=low*sin(PI*t/duration)*0.65+n*0.08*sin(PI*t/duration)
			"bell": wave=(sin(TAU*784*t)*0.4+sin(TAU*1569*t)*0.2+sin(TAU*2091*t)*0.12)*exp(-t*4)
		wave*=minf(1,t*1000)*minf(1,(duration-t)*1000)
		data.encode_s16(i*4,int(clampf(wave*(0.45 if pan>0 else 0.8),-0.95,0.95)*32767))
		data.encode_s16(i*4+2,int(clampf(wave*(0.45 if pan<0 else 0.8),-0.95,0.95)*32767))
	var stream=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.stereo=true; stream.mix_rate=rate; stream.data=data
	return stream

static func battle_kind(era:int,tick:int)->String:
	if era>=12: return "plasma" if tick%4 else "engine"
	if era>=9: return "rifle" if tick%4 else "cannon"
	if era>=6: return "musket" if tick%3 else "cannon"
	if era>=4 and tick%5==0: return "catapult"
	if era>=2 and tick%4==0: return "hoof"
	return "bow" if era==1 or tick%3==0 else "steel"

static func gain_at(view,point:Vector2)->float:
	var screen=point*view.zoom+view._camera
	var distance=screen.distance_to(view.size*0.5)/maxf(1,view.size.length()*0.55)
	return clampf((view.zoom-0.8)/5.0,0,1)*clampf(1-distance,0,1)

func play_effect(kind:String,gain:float=0.5,pan:int=0):
	if app==null or not app.settings.get("effects",true) or gain<0.015: return
	for player in players:
		if not player.playing:
			player.stream=bank.get(kind+str(clampi(pan,-1,1)))
			player.volume_db=linear_to_db(clampf(gain,0.001,1))-9
			player.play(); return

func _process(delta):
	if app==null or app.sim.state.is_empty(): return
	var enabled=bool(app.settings.get("voices",true))
	if voices_enabled and not enabled and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): DisplayServer.tts_stop()
	voices_enabled=enabled
	if app.paused or is_instance_valid(app.modal) or not app.settings.get("effects",true):
		for player in players: player.stop()
		return
	clock_-=delta
	if clock_>0: return
	clock_=0.25; sequence+=1
	var loudest=0.0; var source=Vector2.ZERO; var era=0
	for war in app.sim.state.get("wars",[]):
		var pair=app.world.people._front_pair(app.sim,war)
		if pair.size()!=2: continue
		var point=(Vector2(pair[0].x,pair[0].y)+Vector2(pair[1].x,pair[1].y)+Vector2.ONE)*4
		var gain=gain_at(app.world,point)
		if gain>loudest: loudest=gain; source=point; era=maxi(pair[0].era,pair[1].era)
	for mission in app.sim.state.get("transport",{}).get("missions",[]):
		if mission.kind!="naval": continue
		var point=app.world.transport.position_at(mission,app.world._time)
		var gain=gain_at(app.world,point)
		if gain>loudest: loudest=gain; source=point; era=int(mission.era)
	if loudest>0.02:
		play_effect(battle_kind(era,sequence),loudest,-1 if source.x*app.world.zoom+app.world._camera.x<app.world.size.x*0.4 else 1)
	elif sequence%3==0:
		for mission in app.sim.state.get("transport",{}).get("missions",[]):
			var point=app.world.transport.position_at(mission,app.world._time)
			var gain=gain_at(app.world,point)*0.35
			if gain>0.06: play_effect("engine" if mission.kind in ["plane","helicopter","rocket"] else "water",gain); break

static func introduction(person:Dictionary,town:Dictionary)->String:
	if not person.get("alive",false): return "%s is remembered as a %s of %s. Their story lives on through the people they left behind."%[person.name,person.role,town.get("name","this world")]
	var role=str(person.role)
	var opening="I'm %s. I'm %d, and I work as a %s in %s."%[person.name,int(person.age),role,town.get("name","this community")]
	if role=="child": opening="I'm %s. I'm %d years old, and %s is my home."%[person.name,int(person.age),town.get("name","this community")]
	elif role=="ruler": opening="I'm %s, and I lead the people of %s."%[person.name,town.get("name","this community")]
	var status="People here trust my judgment." if person.get("influence",0)>0.65 else "I'm still trying to make my place here."
	if person.get("imprisoned",false): status="I'm in prison. I think about the world outside every day."
	elif not str(person.get("illness","")).is_empty(): status="I've been ill with %s, and it's wearing me down."%person.illness
	elif person.get("grieving",false): status="I've lost someone close to me. It's been hard."
	elif person.get("wanted",false): status="The authorities are looking for me. I can't stay out in the open."
	elif person.get("cursed",false): status="Something dark has taken hold of my life."
	elif person.get("happiness",1)<0.3: status="Things have been difficult. I don't feel content with my life."
	var want="What I want is to "+str(person.get("goal","build a better life.")).to_lower()
	var project=person.get("project",{})
	if project.get("status","")=="completed": want="I finished a project that mattered to me. I'm taking some time before deciding what comes next."
	elif project.get("status","")=="setback": want="My plans didn't work out. I need time to recover and try again."
	if person.get("imprisoned",false): want="More than anything, I want my freedom."
	elif not str(person.get("illness","")).is_empty(): want="I just want to get well and return to my family."
	elif role=="child": want="I want to learn about the world and grow up somewhere safe."
	return opening+" "+status+" "+want

func speak(person:Dictionary,repeat:bool=false)->String:
	var text_=introduction(person,app.sim.get_settlement(int(person.settlement)))
	last_speech=text_
	if not repeat and last_key==person.key and Time.get_ticks_msec()-speech_time<15000: return text_
	last_key=person.key; speech_time=Time.get_ticks_msec()
	if not app.settings.get("voices",true) or not person.get("alive",false) or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return text_
	var voices=DisplayServer.tts_get_voices_for_language("en")
	speech_available=not voices.is_empty()
	if speech_available:
		var seed_=absi(int(person.get("portrait_seed",0)))
		DisplayServer.tts_speak(text_,voices[seed_%voices.size()],int(app.settings.get("volume",0.55)*100),0.96+float(seed_%5)*0.02,0.97,0,true)
	elif repeat: app._toast("No English speech voice is available. Add one in your device's text-to-speech settings.")
	return text_

func stop():
	for player in players:
		player.stop()
		player.stream=null
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): DisplayServer.tts_stop()
func _exit_tree():
	stop(); app=null
