extends SceneTree
## Exercise the production PCM through Godot's native mixer across loop edges.
var checks=0
var failures=0

class AudioOnly extends "res://scripts/main.gd":
	func _ready():
		_build_audio()
		ambience.stop()
	func _process(_delta): pass

func _initialize(): run.call_deferred()

func check(value:bool,message:String):
	checks+=1
	if not value:
		failures+=1
		push_error("AUDIO: "+message)

func run():
	var app=AudioOnly.new()
	root.add_child(app)
	var stream:AudioStreamWAV=app.ambience.stream
	var channels=2 if stream.stereo else 1
	var frames=stream.data.size()/2/channels
	check(stream.format==AudioStreamWAV.FORMAT_16_BITS,"Ambient PCM uses the expected sample width")
	check(is_equal_approx(stream.get_length(),8.0),"Ambient clip retains its eight-second duration")
	check(stream.loop_begin>=0 and stream.loop_begin<stream.loop_end,"Loop begins inside the clip")
	var valid_end=stream.loop_end<frames
	check(valid_end,"Inclusive loop end must be a valid sample index, not the frame count")
	# Never deliberately send an invalid buffer to the native audio thread.
	if valid_end:
		var playback=stream.instantiate_playback()
		var mixed_frames=0
		for start in [0.0,7.99,7.9999]:
			playback.start(start)
			var complete=true
			var bounded=true
			var peak=0.0
			var wraps=0
			var previous=playback.get_playback_position()
			# More than ten loops at the default output rate, including odd-sized
			# buffers that put the final source sample inside a mixer batch.
			for i in range(1200):
				var amount=[128,511,4096,8191][i%4]
				var buffer=playback.mix_audio(1.0,amount)
				mixed_frames+=buffer.size()
				complete=complete and buffer.size()==amount
				for sample in buffer:
					bounded=bounded and is_finite(sample.x) and is_finite(sample.y) and absf(sample.x)<=1 and absf(sample.y)<=1
					peak=maxf(peak,absf(sample.x))
				var current=playback.get_playback_position()
				if current<previous: wraps+=1
				previous=current
			check(complete,"Every loop supplies complete audio buffers from %.4f seconds"%start)
			check(bounded and peak>0.01,"Looped samples are audible, finite and bounded")
			check(wraps>=10 and playback.is_playing(),"Native mixer survives repeated loop boundaries")
			playback.stop()
		print("AUDIO mixed frames: ",mixed_frames)
	app._stop_audio()
	app.queue_free()
	await process_frame
	await process_frame
	print("AUDIO: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
