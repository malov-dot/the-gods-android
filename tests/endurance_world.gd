extends RefCounted
## Reuse a checksummed checkpoint only for identical gameplay source. Simulation
## and save acceptance exercise the same mature world instead of generating it twice.
const Simulation=preload("res://scripts/simulation.gd")
const PATH="res://test-output/endurance-world"
const SOURCES=["simulation.gd","citizen_registry.gd","life_society.gd","civic_story.gd","content.gd","powers.gd","diplomacy.gd","world_transport.gd","person_interventions.gd"]

static func fingerprint()->String:
	var hashes="80x55/four-nations/gentle/endurance/v1"
	for script in SOURCES: hashes+=FileAccess.get_sha256("res://scripts/"+script)
	return hashes.sha256_text()

static func world():
	var sim=Simulation.new()
	var signature=fingerprint()
	var meta=JSON.parse_string(FileAccess.get_file_as_string(PATH+".json")) if FileAccess.file_exists(PATH+".json") else null
	if meta is Dictionary and meta.get("source")==signature and FileAccess.file_exists(PATH+".gz") and FileAccess.get_sha256(PATH+".gz")==meta.get("sha256"):
		var size_=int(meta.get("bytes",0))
		if size_>0 and size_<=1024000000:
			var packed=FileAccess.get_file_as_bytes(PATH+".gz")
			var bytes=packed.decompress(size_,FileAccess.COMPRESSION_GZIP)
			var state=JSON.parse_string(bytes.get_string_from_utf8())
			if state is Dictionary and int(state.get("year",-1))==int(meta.get("year",-2)) and int(state.year)<=1800:
				sim.restore(state)
				state.clear(); bytes.clear(); packed.clear()
				print("ENDURANCE checkpoint: year %d, matching gameplay source %s"%[sim.state.year,signature.substr(0,12)])
	if sim.state.is_empty(): sim.new_world({"seed":"endurance","width":80,"height":55,"nations":4,"difficulty":"gentle"})
	while int(sim.state.year)<1800:
		var began=Time.get_ticks_msec()
		sim.step(mini(100,1800-int(sim.state.year)))
		var bytes=JSON.stringify(sim.state).to_utf8_buffer()
		var file=FileAccess.open(PATH+".gz",FileAccess.WRITE)
		file.store_buffer(bytes.compress(FileAccess.COMPRESSION_GZIP)); file.close()
		var header=FileAccess.open(PATH+".json",FileAccess.WRITE)
		header.store_string(JSON.stringify({"source":signature,"sha256":FileAccess.get_sha256(PATH+".gz"),"bytes":bytes.size(),"year":int(sim.state.year)})); header.close()
		print("LIFETIME year %d: %d residents, %d personal records, %.1f MiB JSON, %.2fs / 100 years"%[sim.state.year,sim.state.stats.population,sim.state.citizens.overrides.size(),float(bytes.size())/1048576.0,float(Time.get_ticks_msec()-began)/1000.0])
	return sim
