extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Saves=preload("res://scripts/save_manager.gd")
var failures=0
var checks=0
func _init(): call_deferred("run")
func check(value,label):
	checks+=1
	if not value: failures+=1; push_error("SAVE COMPRESSION: "+label)
func write(path,data):
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
func run():
	Saves.storage_directory="res://test-output/compressed-save-tests"
	var sim=Simulation.new(); sim.new_world({"seed":"Family archive round trip","width":160,"height":100,"nations":5})
	check(Saves.save_game(sim.state,0).ok,"Large worlds save atomically")
	var path=Saves.storage_directory+"/slot_1.godsave"
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(envelope.get("encoding","")=="gzip-base64","Large world payloads are compressed")
	var loaded=Saves.load_game(0)
	check(loaded.ok,"Compressed worlds load with schema and checksum verification")
	if loaded.ok:
		var restored=Simulation.new(); restored.restore(loaded.state)
		check(JSON.stringify(restored.state.citizens)==JSON.stringify(sim.state.citizens),"Compression preserves every family identity and personal record")
	var damaged=envelope.duplicate(true); damaged.payload+="modified"
	write(Saves.storage_directory+"/damaged.godsave",damaged)
	check(not Saves._read_save(Saves.storage_directory+"/damaged.godsave").ok,"Encoded payload corruption is rejected before decompression")
	damaged=envelope.duplicate(true); damaged.decoded_bytes=Saves.MAX_WORLD_BYTES+1
	write(Saves.storage_directory+"/oversized.godsave",damaged)
	check(not Saves._read_save(Saves.storage_directory+"/oversized.godsave").ok,"Inflated output sizes cannot bypass the decoded memory limit")
	damaged=envelope.duplicate(true); damaged.encoding="unknown"
	write(Saves.storage_directory+"/unknown.godsave",damaged)
	check(not Saves._read_save(Saves.storage_directory+"/unknown.godsave").ok,"Unknown codecs are rejected")
	var payload=JSON.stringify(sim.state)
	write(Saves.storage_directory+"/legacy.godsave",{"format":Saves.FORMAT,"version":1,"payload":payload,"checksum":payload.sha256_text()})
	check(Saves._read_save(Saves.storage_directory+"/legacy.godsave").ok,"Existing uncompressed saves remain readable")
	print("Save compression: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
