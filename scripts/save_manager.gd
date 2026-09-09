extends RefCounted

## JSON payloads are checksummed and replaced by a rename on the same volume.
## Keep the last valid generation alongside each slot for automatic recovery.
const SAVE_VERSION = 1
const FORMAT = "the-gods-save"
const SAVE_DIRECTORY = "user://saves"
const MAX_BYTES = 128000000
const MAX_WORLD_BYTES = 768000000
const SLOTS = [0, 1, 2, 9]
static var storage_directory: String = SAVE_DIRECTORY

static func save_game(state: Dictionary, slot: int = 0) -> Dictionary:
	if slot not in SLOTS:
		return _failure("Choose save slot 1, 2, 3, or autosave.")
	var validation = validate_state(state)
	if not validation.ok:
		return _failure("The world could not be saved: " + validation.message)
	var payload = JSON.stringify(state)
	var bytes=payload.to_utf8_buffer()
	if bytes.size()>MAX_WORLD_BYTES: return _failure("This world's history exceeds the supported save size.")
	var envelope = {
		"format":FORMAT,
		"version":SAVE_VERSION,
		"saved_at":Time.get_datetime_string_from_system(false, true),
		"timestamp":Time.get_unix_time_from_system(),
		"checksum":payload.sha256_text(),
		"payload":payload
	}
	if bytes.size()>=1000000:
		envelope["encoding"]="gzip-base64"
		envelope["decoded_bytes"]=bytes.size()
		envelope.payload=Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_GZIP))
		envelope["encoded_checksum"]=str(envelope.payload).sha256_text()
	var write = _atomic_write(_slot_path(slot), JSON.stringify(envelope))
	if not write.ok:
		return write
	return {"ok":true,"message":"World saved to " + _slot_label(slot) + ".","slot":slot}

static func load_game(slot: int = 0) -> Dictionary:
	if slot not in SLOTS:
		return _failure("Choose save slot 1, 2, 3, or autosave.")
	var path = _slot_path(slot)
	var result = _read_save(path)
	if result.ok:
		result.message = "Loaded " + _slot_label(slot) + "."
		result.recovered = false
		return result
	var backup = _read_save(path + ".bak")
	if backup.ok:
		backup.message = "Recovered the previous valid save for " + _slot_label(slot) + ". The latest save was unavailable or damaged."
		backup.recovered = true
		return backup
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return _failure("This save slot is empty.")
	return _failure("Cannot load " + _slot_label(slot) + ": " + str(result.message) + " No valid backup is available.")

static func list_saves() -> Array:
	var result = []
	for slot in SLOTS:
		var path = _slot_path(slot)
		var exists = FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
		var entry = {"slot":slot,"label":_slot_label(slot),"exists":exists,"ok":false,"year":0,"seed":"","mode":"","population":0,"saved_at":"","recovered":false,"message":"Empty slot"}
		if exists:
			var loaded = load_game(slot)
			entry.ok = loaded.ok
			entry.message = loaded.message
			if loaded.ok:
				var world = loaded.state
				entry.year = int(world.year)
				entry.seed = str(world.get("seed", "Unknown"))
				entry.mode = str(world.get("mode", "sandbox"))
				entry.population = int(world.get("stats", {}).get("population", 0))
				entry.saved_at = str(loaded.get("saved_at", ""))
				entry.recovered = loaded.get("recovered", false)
		result.append(entry)
	return result

static func save_settings(settings: Dictionary) -> Dictionary:
	var allowed = _sanitized_settings(settings)
	var payload = JSON.stringify(allowed)
	return _atomic_write(storage_directory + "/settings.json", JSON.stringify({"version":1,"checksum":payload.sha256_text(),"payload":payload}))

static func load_settings() -> Dictionary:
	var defaults = {"master_volume":0.55,"music_volume":0.5,"sfx_volume":0.7,"volume":0.55,"ambient":true,"effects":true,"fullscreen":false,"autosave":true,"autosave_interval":120,"show_tutorial":true,"reduced_motion":false,"pixel_scale":3,"last_slot":0}
	for path in [storage_directory + "/settings.json", storage_directory + "/settings.json.bak"]:
		var parsed = _read_settings_data(path)
		if not parsed.ok:
			continue
		defaults.merge(_sanitized_settings(parsed.data), true)
		return defaults
	return defaults

static func validate_state(state: Dictionary) -> Dictionary:
	if int(state.get("version", -1)) != SAVE_VERSION:
		return _failure("Unsupported save version. This release reads world version 1.")
	for key in ["width", "height", "year", "next_id"]:
		if not _is_number(state.get(key)):
			return _failure("Missing or invalid world field: " + key + ".")
	var width = int(state.width)
	var height = int(state.height)
	if width < 8 or height < 8 or width > 512 or height > 512:
		return _failure("World dimensions must be between 8 and 512 tiles.")
	if int(state.year) < 0 or int(state.next_id) < 1:
		return _failure("The world clock or identifier counter is invalid.")
	for key in ["tiles", "settlements", "nations", "people", "events", "effects", "wars", "artifacts", "agents", "achievements"]:
		if not state.get(key) is Array:
			return _failure("Missing or invalid collection: " + key + ".")
	for key in ["afterlife", "mana", "stats", "settings", "doctrine"]:
		if not state.get(key) is Dictionary:
			return _failure("Missing or invalid world section: " + key + ".")
	if state.tiles.size() != width * height:
		return _failure("The terrain tile count does not match the world dimensions.")
	if str(state.get("mode", "")) not in ["sandbox", "versus_ai", "hotseat", "online"]:
		return _failure("The game mode is invalid.")
	if str(state.get("player_side", "")) not in ["god", "devil"] or str(state.get("active_side", "")) not in ["god", "devil"]:
		return _failure("The active divine side is invalid.")
	for side in ["god", "devil"]:
		if not _is_number(state.mana.get(side)) or float(state.mana[side]) < 0:
			return _failure("Divine power balances are invalid.")
		if not state.doctrine.get(side) is String:
			return _failure("Divine doctrines are invalid.")
	for side in ["heaven", "hell", "wandering"]:
		if not _is_number(state.afterlife.get(side)) or float(state.afterlife[side]) < 0:
			return _failure("Afterlife totals are invalid.")
	if state.has("story_people"):
		if not state.story_people is Array or state.story_people.size()>32: return _failure("The followed story list is malformed.")
		var followed={}
		for key in state.story_people:
			if not state.has("citizens") or not _known_resident(key,state.citizens) or followed.has(key): return _failure("A followed story refers to an unknown or duplicate person.")
			followed[key]=true
	for tile in state.tiles:
		if not tile is Dictionary:
			return _failure("A terrain tile is malformed.")
		for key in ["elevation", "moisture", "temperature", "fertility", "forest", "ore"]:
			if not _is_number(tile.get(key)) or float(tile[key]) < 0 or float(tile[key]) > 1:
				return _failure("A terrain value is outside its allowed range: " + key + ".")
		if not tile.get("biome") is String or not _is_number(tile.get("owner")):
			return _failure("A terrain tile has an invalid biome or owner.")
	var nation_ids = {}
	for nation in state.nations:
		if not nation is Dictionary or not _is_number(nation.get("id")) or not nation.get("name") is String:
			return _failure("A nation is malformed.")
		if not nation.get("color") is String or not nation.get("allies") is Array or not _is_number(nation.get("aggression")):
			return _failure("A nation's appearance or diplomacy is malformed.")
		if nation_ids.has(int(nation.id)):
			return _failure("Duplicate nation identifiers were found.")
		nation_ids[int(nation.id)] = true
	var settlement_ids = {}
	for town in state.settlements:
		if not town is Dictionary:
			return _failure("A settlement is malformed.")
		for key in ["id", "x", "y", "nation", "population", "food", "wealth", "health", "happiness", "faith", "corruption", "fear", "knowledge", "era", "research", "plague", "drought", "blessing", "protection", "leader", "founded"]:
			if not _is_number(town.get(key)):
				return _failure("A settlement has a missing or invalid " + key + ".")
		if not town.get("name") is String or not town.get("history") is Array or not town.get("buildings") is Array or not town.get("religion") is String:
			return _failure("A settlement's name, history, or buildings are invalid.")
		if not _strings_only(town.buildings):
			return _failure("A settlement's buildings are malformed.")
		for history in town.history:
			if not history is Dictionary or not _is_number(history.get("year")) or not history.get("title") is String or not history.get("detail") is String:
				return _failure("A settlement's history is malformed.")
		if int(town.x) < 0 or int(town.y) < 0 or int(town.x) >= width or int(town.y) >= height:
			return _failure("A settlement is outside the world.")
		if settlement_ids.has(int(town.id)) or not nation_ids.has(int(town.nation)):
			return _failure("Settlement identifiers or nation references are invalid.")
		settlement_ids[int(town.id)] = {"surface":maxi(0,floori(float(town.population))),"orbit":maxi(0,floori(float(town.get("orbital_population",0.0))))}
		if float(town.population) < 0 or float(town.food) < 0 or float(town.wealth) < 0 or float(town.knowledge) < 0:
			return _failure("A settlement contains a negative population or resource balance.")
		for key in ["health", "happiness", "faith", "corruption", "fear"]:
			if float(town[key]) < 0 or float(town[key]) > 1.00001:
				return _failure("A settlement's " + key + " is outside its allowed range.")
		if float(town.faith) + float(town.corruption) > 1.00001 or int(town.era) < 0 or int(town.era) > 30:
			return _failure("A settlement has invalid belief totals or an unsupported age.")
	for key in ["people", "events", "effects", "wars", "artifacts", "agents"]:
		for entry in state[key]:
			if not entry is Dictionary:
				return _failure("An entry in " + key + " is malformed.")
	for person in state.people:
		for key in ["id", "settlement", "age", "lifespan"]:
			if not _is_number(person.get(key)):
				return _failure("A character's " + key + " is invalid.")
		for key in ["name", "role", "alignment"]:
			if not person.get(key) is String:
				return _failure("A character's " + key + " is malformed.")
		if not person.get("alive") is bool or not _strings_only(person.get("traits")):
			return _failure("A character's status or traits are malformed.")
	for event in state.events:
		for key in ["id", "year", "x", "y"]:
			if not _is_number(event.get(key)):
				return _failure("An event's " + key + " is invalid.")
		for key in ["title", "detail", "kind"]:
			if not event.get(key) is String:
				return _failure("An event's " + key + " is malformed.")
		if not _strings_only(event.get("causes")):
			return _failure("An event's causes are malformed.")
	for effect in state.effects:
		if not effect.get("type") is String:
			return _failure("A world effect has an invalid type.")
		for key in ["x", "y", "radius", "until"]:
			if not _is_number(effect.get(key)):
				return _failure("A world effect's " + key + " is invalid.")
	for war in state.wars:
		for key in ["a", "b", "since"]:
			if not _is_number(war.get(key)):
				return _failure("A war's " + key + " is invalid.")
		if not war.get("reason") is String:
			return _failure("A war has an invalid cause.")
	for collection in ["artifacts", "agents"]:
		for presence in state[collection]:
			if not _is_number(presence.get("id")) or not _is_number(presence.get("settlement")) or presence.get("side") not in ["god", "devil"]:
				return _failure("A supernatural presence is malformed.")
	if not _strings_only(state.achievements):
		return _failure("Achievement records are malformed.")
	if state.has("citizens"):
		var registry_check = _validate_citizens(state.citizens, settlement_ids)
		if not registry_check.ok: return registry_check
	if state.has("society"):
		var society_check=_validate_society(state,settlement_ids)
		if not society_check.ok: return society_check
	if state.has("favorite_people"):
		if not state.favorite_people is Array or state.favorite_people.size()>4096 or not state.has("citizens"): return _failure("The favorites list is malformed.")
		var favorites={}
		for key in state.favorite_people:
			if not _known_resident(key,state.citizens) or favorites.has(key): return _failure("A favorite is duplicated or refers to an unknown resident.")
			favorites[key]=true
	if state.has("treaties"):
		if not state.treaties is Array or state.treaties.size()>190: return _failure("Treaties are malformed.")
		var pairs={}
		for treaty in state.treaties:
			if not treaty is Dictionary: return _failure("An agreement is malformed.")
			for field in ["a","b","since","until"]:
				if not _is_number(treaty.get(field)): return _failure("An agreement has an invalid "+field+".")
			if treaty.a==treaty.b or treaty.get("kind") not in ["peace","alliance"] or treaty.until<treaty.since: return _failure("An agreement has invalid terms.")
			var pair="%d:%d"%[mini(treaty.a,treaty.b),maxi(treaty.a,treaty.b)]
			if pairs.has(pair): return _failure("An agreement is duplicated.")
			pairs[pair]=true
	if state.has("transport"):
		var transport=state.transport
		if not transport is Dictionary or not _is_number(transport.get("year")) or not transport.get("missions") is Array or transport.missions.size()>96: return _failure("World transport is malformed.")
		for mission in transport.missions:
			if not mission is Dictionary or mission.get("kind") not in ["fishing","cargo","naval","plane","helicopter","rocket"]: return _failure("A transport mission is malformed.")
			for field in ["town","nation","era","cargo"]:
				if not _is_number(mission.get(field)): return _failure("A transport mission has an invalid "+field+".")
			if not settlement_ids.has(int(mission.town)) or mission.era<0 or mission.era>13 or mission.cargo<0: return _failure("A transport mission has invalid ownership or cargo.")
			if not mission.get("path") is Array or mission.path.is_empty() or mission.path.size()>12000: return _failure("A transport route is malformed.")
			for point in mission.path:
				if not point is Array or point.size()!=2 or not _is_number(point[0]) or not _is_number(point[1]): return _failure("A transport waypoint is malformed.")
				if point[0]<-20 or point[1]<-20 or point[0]>int(state.width)+20 or point[1]>int(state.height)+20: return _failure("A transport route leaves the supported map area.")
	if not _safe_json_value(state, 0):
		return _failure("The world contains non-finite values or unsupported data.")
	return {"ok":true,"message":"World data validated."}

static func _validate_citizens(value, town_ids: Dictionary) -> Dictionary:
	# This optional section extends world version 1. Its absence is a valid old
	# save; simulation.restore builds the initial roster without changing history.
	if not value is Dictionary:
		return _failure("The individual resident registry is malformed.")
	var registry = value
	if not _integer_at_least(registry.get("version"), 1) or int(registry.version) != 1:
		return _failure("Unsupported individual resident registry version.")
	if not _integer_at_least(registry.get("next_id"), 1) or not _integer_at_least(registry.get("revision"), 0):
		return _failure("The resident identity counter is invalid.")
	if not registry.get("cohorts") is Array or not registry.get("residents") is Dictionary or not registry.get("overrides") is Dictionary or not registry.get("named") is Dictionary:
		return _failure("The individual registry collections are malformed.")
	if registry.cohorts.size() > 500000 or registry.overrides.size() > 1500000 or registry.named.size() > 100000:
		return _failure("The individual registry exceeds the supported record count.")
	var issued = []
	var last_end = 1
	for cohort in registry.cohorts:
		if not cohort is Array or cohort.size() != 6:
			return _failure("A resident birth cohort is malformed.")
		for index in range(6):
			if not _is_integer(cohort[index]):
				return _failure("A resident birth cohort contains an invalid value.")
		if int(cohort[0]) < 1 or int(cohort[1]) < 1 or int(cohort[3]) < 0 or int(cohort[5]) < 0:
			return _failure("A resident birth cohort contains an invalid count or origin.")
		var end = int(cohort[0]) + int(cohort[1])
		if end > int(registry.next_id) or end <= int(cohort[0]):
			return _failure("Resident identities exceed their issued counter.")
		if int(cohort[0]) != last_end:
			return _failure("Resident birth cohorts are not in their original issuance order.")
		issued.append([int(cohort[0]), end])
		last_end = end
	if last_end != int(registry.next_id): return _failure("The resident identity counter skips an unissued identity.")
	var living = []
	var represented_towns = {}
	for town_key in registry.residents:
		if not str(town_key).is_valid_int() or not town_ids.has(int(str(town_key))) or str(int(str(town_key))) != str(town_key) or represented_towns.has(int(str(town_key))):
			return _failure("A resident directory refers to an unknown settlement.")
		represented_towns[int(str(town_key))] = true
		var locations = registry.residents[town_key]
		if not locations is Dictionary:
			return _failure("A settlement's resident locations are malformed.")
		for location in ["surface", "orbit"]:
			if not locations.get(location) is Array:
				return _failure("A settlement is missing its " + location + " resident directory.")
			var count = 0
			for interval in locations[location]:
				if not interval is Array or interval.size() != 2 or not _integer_at_least(interval[0],1) or not _integer_at_least(interval[1],1):
					return _failure("A living resident identity range is invalid.")
				var end = int(interval[0]) + int(interval[1])
				if end > int(registry.next_id) or end <= int(interval[0]):
					return _failure("A living resident identity was never issued.")
				living.append([int(interval[0]),end])
				count += int(interval[1])
				if living.size() > 500000:
					return _failure("The living resident registry exceeds its supported range count.")
			if count != int(town_ids[int(str(town_key))].get(location,0)):
				return _failure("A settlement's " + location + " resident directory does not match its population.")
	for town_id in town_ids:
		if not represented_towns.has(town_id) and (int(town_ids[town_id].surface) > 0 or int(town_ids[town_id].orbit) > 0):
			return _failure("A populated settlement is missing its resident directory.")
	living.sort_custom(func(a,b): return a[0] < b[0])
	var prior_end = 1
	var cohort_index = 0
	for interval in living:
		var first = int(interval[0])
		var end = int(interval[1])
		if first < prior_end:
			return _failure("One person appears in more than one living population.")
		prior_end = end
		while cohort_index < issued.size() and int(issued[cohort_index][1]) <= first: cohort_index += 1
		var cursor = first
		var current = cohort_index
		while cursor < end and current < issued.size():
			if int(issued[current][0]) > cursor: break
			cursor = mini(end,int(issued[current][1]))
			if cursor < end: current += 1
		if cursor < end:
			return _failure("A living resident range contains an identity that was never issued.")
	var deceased = registry.get("deceased", [])
	if not deceased is Array or deceased.size() > 1000000:
		return _failure("The deceased resident registry is malformed or exceeds its supported size.")
	var all_membership = living.duplicate()
	for interval in deceased:
		if not interval is Array or interval.size() != 5:
			return _failure("A deceased resident range is malformed.")
		for index in range(5):
			if not _is_integer(interval[index]): return _failure("A deceased resident range contains an invalid value.")
		if int(interval[0]) < 1 or int(interval[1]) < 1 or int(interval[2]) < 0 or int(interval[3]) < 0 or int(interval[4]) not in [0,1]:
			return _failure("A deceased resident range contains an invalid count, date, or location.")
		var end = int(interval[0]) + int(interval[1])
		if end > int(registry.next_id) or end <= int(interval[0]):
			return _failure("A deceased resident identity was never issued.")
		all_membership.append([int(interval[0]),end])
	all_membership.sort_custom(func(a,b): return a[0] < b[0])
	prior_end = 1
	for interval in all_membership:
		if int(interval[0]) < prior_end:
			return _failure("A resident is duplicated or appears in both living and deceased populations.")
		prior_end = int(interval[1])
	var canonical_aliases = {}
	for key in registry.named:
		var alias = registry.named[key]
		if not _person_key(key, "p:") or not _person_key(alias, "c:"):
			return _failure("A named resident alias is malformed.")
		var number = int(str(alias).substr(2))
		if not _identity_issued(number,issued) or canonical_aliases.has(str(alias)):
			return _failure("Named resident aliases reuse or reference an unknown identity.")
		canonical_aliases[str(alias)] = true
	for key in registry.overrides:
		var canonical = str(key)
		if _person_key(key, "p:"): canonical = str(registry.named.get(key,""))
		if not _person_key(canonical,"c:") or not _identity_issued(int(canonical.substr(2)),issued):
			return _failure("A personal record refers to an unknown resident identity.")
		var record = registry.overrides[key]
		if not record is Dictionary:
			return _failure("A personal resident record is malformed.")
		if record.has("last_intervention"):
			var recent=record.last_intervention
			if not recent is Dictionary or not preload("res://scripts/person_interventions.gd").ACTIONS.has(recent.get("action","")): return _failure("A personal visual marker is malformed.")
			if not _is_number(recent.get("year")) or recent.year<0 or recent.year!=floorf(recent.year): return _failure("A personal visual marker has an invalid year.")
			for field in ["label","message"]:
				if not recent.get(field) is String or recent[field].length()>8000: return _failure("A personal visual marker has invalid text.")
		for field in ["health","happiness","faith","corruption","loyalty","ambition","standing","leadership","wisdom","strength","influence"]:
			if record.has(field) and (not _is_number(record[field]) or float(record[field]) < 0 or float(record[field]) > 1.00001):
				return _failure("A personal resident's " + field + " is outside its allowed range.")
		if record.has("faith") and record.has("corruption") and float(record.faith) + float(record.corruption) > 1.00001:
			return _failure("A personal resident has invalid belief totals.")
		for field in ["name","role","goal","location"]:
			if record.has(field) and not record[field] is String:
				return _failure("A personal resident's " + field + " is malformed.")
		if record.has("traits") and not _strings_only(record.traits):
			return _failure("A personal resident's traits are malformed.")
		if record.has("history"):
			if not record.history is Array or record.history.size() > 24: return _failure("A personal resident's history is malformed.")
			for entry in record.history:
				if not entry is Dictionary or not _is_integer(entry.get("year")) or not entry.get("title") is String or not entry.get("detail") is String:
					return _failure("A personal history entry is malformed.")
		if record.has("stats"):
			if not record.stats is Dictionary: return _failure("A personal stat adjustment is malformed.")
			for stat in record.stats:
				if not stat is String or not _is_number(record.stats[stat]) or absf(float(record.stats[stat])) > 1.00001:
					return _failure("A personal stat adjustment is outside its allowed range.")
		if record.has("born") and not _is_integer(record.born): return _failure("A personal birth year is invalid.")
		if record.has("effects"):
			if not record.effects is Array or record.effects.size() > 6: return _failure("A personal influence record is malformed.")
			var action_ids = {}
			for effect in record.effects:
				if not effect is Dictionary or not effect.get("action") is String or effect.get("side") not in ["god","devil"] or not _integer_at_least(effect.get("until"),0) or not effect.get("community") is Dictionary:
					return _failure("A personal influence effect is malformed.")
				if effect.action not in ["heal_person","inspire_person","bless_person","tempt_person","corrupt_person","incite_person"] or action_ids.has(effect.action):
					return _failure("A personal influence effect is unknown or duplicated.")
				action_ids[effect.action] = true
				for field in effect.community:
					if not field is String or not _is_number(effect.community[field]): return _failure("A personal community consequence is invalid.")
	return {"ok":true,"message":"Individual resident registry validated."}

static func _known_resident(key,registry)->bool:
	return _person_key(key,"c:") and int(str(key).substr(2))<int(registry.next_id)

static func _resident_birth(key,registry)->int:
	var edit=registry.overrides.get(key,{})
	if edit.has("born"): return int(edit.born)
	var id=int(str(key).substr(2))
	var low=0; var high=registry.cohorts.size()-1
	while low<=high:
		var mid=(low+high)/2; var cohort=registry.cohorts[mid]
		if id<int(cohort[0]): high=mid-1
		elif id>=int(cohort[0])+int(cohort[1]): low=mid+1
		else:
			var seed=absi((id*92837111+int(cohort[4])*689287499)^(id*1274126177))%2147483647
			return int(cohort[2])-seed%maxi(1,int(cohort[5]))
	return 0

static func _validate_society(state,towns)->Dictionary:
	if not state.has("citizens") or not state.society is Dictionary: return _failure("The society requires its resident registry.")
	var society=state.society; var registry=state.citizens
	if not _is_integer(society.get("version")) or int(society.version)!=1 or not society.get("initialized") is bool or not _integer_at_least(society.get("next_id"),1): return _failure("Unsupported society data.")
	for field in ["laws","crimes","promises","movements"]:
		if not society.get(field) is Array or society[field].size()>100000: return _failure("Society records are malformed or too large.")
	var used={}
	for field in ["laws","crimes","promises"]:
		for record in society[field]:
			if not record is Dictionary or not _integer_at_least(record.get("id"),1) or int(record.id)>=int(society.next_id) or used.has(int(record.id)): return _failure("A public record identity is invalid or duplicated.")
			used[int(record.id)]=true
			if not _known_resident(record.get("actor"),registry) or not _is_integer(record.get("town")) or not towns.has(int(record.town)): return _failure("A public record refers to a missing person or community.")
	for law in society.laws:
		if law.get("kind") not in ["relief","schools","fair_trials","guild_privileges","repression"] or not law.get("name") is String or not law.get("group") is String or not law.get("reason") is String: return _failure("A law is malformed.")
		if not _integer_at_least(law.get("since"),0) or not _integer_at_least(law.get("until"),int(law.since)): return _failure("A law has invalid dates.")
	for crime in society.crimes:
		if not _known_resident(crime.get("victim"),registry) or crime.victim==crime.actor or crime.get("kind") not in ["theft","murder"] or crime.get("status") not in ["hidden","reported","convicted","closed","unsolved","pardoned"]: return _failure("A justice record is malformed.")
		if not _integer_at_least(crime.get("year"),0) or not _is_integer(crime.get("resolved")): return _failure("A crime has invalid dates.")
	for vow in society.promises:
		if not _known_resident(vow.get("patient"),registry) or vow.patient==vow.actor or vow.get("side") not in ["god","devil"] or vow.get("status") not in ["offered","pending","fulfilled","broken","failed","expired"] or not vow.get("outcome") is String: return _failure("A family promise is malformed.")
		if not _integer_at_least(vow.get("since"),0) or not _integer_at_least(vow.get("deadline"),int(vow.since)) or not _is_integer(vow.get("resolved")): return _failure("A promise has invalid dates.")
	var represented={}
	for movement in society.movements:
		if not movement is Dictionary or not _is_integer(movement.get("town")) or not towns.has(int(movement.town)) or represented.has(int(movement.town)): return _failure("An opposition movement is malformed or duplicated.")
		represented[int(movement.town)]=true
		if not _known_resident(movement.get("target"),registry) or (movement.get("organizer")!="" and not _known_resident(movement.get("organizer"),registry)): return _failure("An opposition movement names an unknown resident.")
		if movement.get("status") not in ["quiet","organizing","revolution"] or not _is_number(movement.get("support")) or movement.support<0 or movement.support>1 or not _integer_at_least(movement.get("started"),0): return _failure("An opposition movement has invalid support or dates.")
	for key in registry.overrides:
		var override=registry.overrides[key]
		if not override.has("life"): continue
		var life=override.life
		if not life is Dictionary: return _failure("A personal life record is malformed.")
		if life.has("project"):
			var project=life.project
			if not project is Dictionary or project.get("status") not in ["active","completed","setback"]: return _failure("A personal project is malformed.")
			for field in ["title","role","obstacle","outcome"]:
				if not project.get(field) is String or project[field].length()>1000: return _failure("A project description is invalid.")
			if not _is_number(project.get("progress")) or not _is_number(project.get("target")) or project.target<=0 or project.target>100 or project.progress<0 or project.progress>project.target: return _failure("Project progress is invalid.")
			if not _integer_at_least(project.get("started"),0) or not _integer_at_least(project.get("deadline"),int(project.started)) or not _integer_at_least(project.get("finished"),-1): return _failure("Project dates are invalid.")
		for field in ["revived_until","estate_age"]:
			if life.has(field) and not _integer_at_least(life[field],0): return _failure("A restored life has invalid dates.")
		for field in ["parents","children"]:
			if not life.has(field): continue
			if not life[field] is Array or life[field].size()>(2 if field=="parents" else 100): return _failure("Family links are malformed.")
			var distinct={}
			for relative in life[field]:
				if not _known_resident(relative,registry) or relative==key or distinct.has(relative): return _failure("A family relationship is unknown, self-referencing or duplicated.")
				distinct[relative]=true
				var reverse=registry.overrides.get(relative,{}).get("life",{})
				if not reverse is Dictionary or key not in reverse.get("children" if field=="parents" else "parents",[]): return _failure("A parent and child's family links disagree.")
				var parent=relative if field=="parents" else key
				var child=key if field=="parents" else relative
				if _resident_birth(child,registry)-_resident_birth(parent,registry)<18: return _failure("A recorded parent was not an adult when this child was born.")
		if life.has("spouse") and (not _known_resident(life.spouse,registry) or life.spouse==key): return _failure("A spouse link is invalid.")
		if life.has("married_year"):
			if not _is_integer(life.married_year) or not life.has("spouse"): return _failure("A marriage date is invalid.")
			if int(life.married_year)-_resident_birth(key,registry)<18 or int(life.married_year)-_resident_birth(life.spouse,registry)<18: return _failure("A marriage began before adulthood.")
		for field in ["illness","family_origin","death_cause"]:
			if life.has(field) and not life[field] is String: return _failure("A life description is invalid.")
		for field in ["wanted","death_noted","bribed","exposed","memory_archived"]:
			if life.has(field) and not life[field] is bool: return _failure("A life condition is invalid.")
		for field in ["sick_until","curse_until","possessed_until","prison_until","grief_until","crimes","good_deeds","kills"]:
			if life.has(field) and not _integer_at_least(life[field],0): return _failure("A life condition has an invalid value.")
		for field in ["last_birth","last_deed","last_crime"]:
			if life.has(field) and not _is_integer(life[field]): return _failure("A life event has an invalid date.")
		if life.has("money") and (not _is_number(life.money) or absf(life.money)>10000000): return _failure("Personal wealth is invalid.")
	return {"ok":true,"message":"Families and public consequences validated."}

static func _identity_issued(id: int, issued: Array) -> bool:
	var low = 0
	var high = issued.size() - 1
	while low <= high:
		var middle = (low + high) / 2
		if id < int(issued[middle][0]): high = middle - 1
		elif id >= int(issued[middle][1]): low = middle + 1
		else: return true
	return false

static func _person_key(value, prefix: String) -> bool:
	if not value is String or not value.begins_with(prefix): return false
	var tail = value.substr(prefix.length())
	return tail.is_valid_int() and int(tail) >= 1 and str(int(tail)) == tail

static func _is_integer(value) -> bool:
	return _is_number(value) and absf(float(value)) <= 9007199254740991.0 and float(value) == floorf(float(value))

static func _integer_at_least(value, minimum: int) -> bool:
	return _is_integer(value) and int(value) >= minimum

static func _read_save(path: String) -> Dictionary:
	var read = _read_json(path)
	if not read.ok:
		return read
	var envelope = read.data
	if envelope.get("format", "") != FORMAT:
		return _failure("This file is not a The Gods save.")
	if int(envelope.get("version", -1)) != SAVE_VERSION:
		return _failure("This save uses an unsupported format version.")
	if not envelope.get("payload") is String:
		return _failure("The saved world payload is missing.")
	var payload = str(envelope.payload)
	var encoding=str(envelope.get("encoding","json"))
	if encoding=="gzip-base64":
		if not _integer_at_least(envelope.get("decoded_bytes"),1) or int(envelope.decoded_bytes)>MAX_WORLD_BYTES: return _failure("The compressed world's size is invalid.")
		if payload.sha256_text()!=str(envelope.get("encoded_checksum","")): return _failure("The compressed save checksum failed.")
		var compressed=Marshalls.base64_to_raw(payload)
		if compressed.size()<18 or compressed[0]!=31 or compressed[1]!=139: return _failure("The compressed save header is invalid.")
		var decoded=compressed.decompress(int(envelope.decoded_bytes),FileAccess.COMPRESSION_GZIP)
		if decoded.size()!=int(envelope.decoded_bytes): return _failure("The compressed world could not be decoded.")
		payload=decoded.get_string_from_utf8()
	elif encoding!="json": return _failure("Unsupported save encoding.")
	if payload.sha256_text() != str(envelope.get("checksum", "")):
		return _failure("The saved world checksum failed; the file may be incomplete.")
	var parser = JSON.new()
	if parser.parse(payload) != OK or not parser.data is Dictionary:
		return _failure("The saved world could not be decoded.")
	var world = parser.data
	var validation = validate_state(world)
	if not validation.ok:
		return validation
	return {"ok":true,"message":"World loaded.","state":world,"saved_at":str(envelope.get("saved_at", "")),"timestamp":envelope.get("timestamp", 0)}

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("The file is missing.")
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("The file could not be opened (error %d)." % FileAccess.get_open_error())
	if file.get_length() <= 0 or file.get_length() > MAX_BYTES:
		file.close()
		return _failure("The file size is invalid.")
	var source = file.get_as_text()
	file.close()
	var parser = JSON.new()
	var error = parser.parse(source)
	if error != OK or not parser.data is Dictionary:
		return _failure("Invalid JSON save data.")
	return {"ok":true,"data":parser.data}

static func _read_settings_data(path: String) -> Dictionary:
	var parsed = _read_json(path)
	if not parsed.ok:
		return parsed
	var envelope = parsed.data
	if envelope.get("version", 0) != 1 or not envelope.get("payload", null) is String:
		return _failure("Unsupported settings format.")
	if str(envelope.payload).sha256_text() != str(envelope.get("checksum", "")):
		return _failure("Settings checksum failed.")
	var values = JSON.parse_string(envelope.payload)
	if not values is Dictionary:
		return _failure("Settings payload is malformed.")
	return {"ok":true,"data":values}

static func _atomic_write(path: String, data: String) -> Dictionary:
	if data.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("The save exceeds the supported file size.")
	var directory = ProjectSettings.globalize_path(path.get_base_dir())
	var err = DirAccess.make_dir_recursive_absolute(directory)
	if err != OK:
		return _failure("The save folder could not be created (error %d)." % err)
	var absolute = ProjectSettings.globalize_path(path)
	var temporary = absolute + ".tmp"
	var backup = absolute + ".bak"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("The save could not be written (error %d)." % FileAccess.get_open_error())
	file.store_string(data)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("The save could not be completed (error %d)." % write_error)
	# A corrupt primary must never overwrite a valid recovery copy.
	var had_original = FileAccess.file_exists(absolute)
	var rotated = false
	if had_original:
		var valid_original = _read_json(absolute).ok
		if path.ends_with(".godsave"):
			valid_original = _read_save(absolute).ok
		elif path.ends_with("settings.json"):
			valid_original = _read_settings_data(absolute).ok
		if valid_original:
			if FileAccess.file_exists(backup):
				err = DirAccess.remove_absolute(backup)
				if err != OK:
					return _failure("The previous backup could not be replaced (error %d)." % err)
			err = DirAccess.rename_absolute(absolute, backup)
			if err != OK:
				return _failure("The previous save could not be backed up (error %d)." % err)
			rotated = true
		else:
			err = DirAccess.remove_absolute(absolute)
			if err != OK:
				return _failure("The damaged save could not be replaced (error %d)." % err)
	err = DirAccess.rename_absolute(temporary, absolute)
	if err != OK:
		if rotated:
			DirAccess.rename_absolute(backup, absolute)
		return _failure("The new save could not be installed (error %d). Your previous save was retained." % err)
	return {"ok":true,"message":"Saved."}

static func _safe_json_value(value, depth: int) -> bool:
	if depth > 40:
		return false
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int):
				return false
			if not _safe_json_value(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for item in value:
			if not _safe_json_value(item, depth + 1):
				return false
		return true
	if value is float:
		return is_finite(value)
	return value == null or value is int or value is String or value is StringName or value is bool

static func _sanitized_settings(settings: Dictionary) -> Dictionary:
	var result = {}
	for key in ["master_volume", "music_volume", "sfx_volume", "volume"]:
		if _is_number(settings.get(key)):
			result[key] = clampf(float(settings[key]), 0, 1)
	for key in ["fullscreen", "autosave", "show_tutorial", "reduced_motion", "tutorial_completed", "sound_enabled", "music_enabled", "ambient", "effects", "voices", "event_notices"]:
		if settings.get(key) is bool:
			result[key] = settings[key]
	if _is_number(settings.get("autosave_interval")):
		result.autosave_interval = clampi(int(settings.autosave_interval), 30, 600)
	if _is_number(settings.get("pixel_scale")):
		result.pixel_scale = clampi(int(settings.pixel_scale), 1, 6)
	if _is_number(settings.get("last_slot")) and int(settings.last_slot) in SLOTS:
		result.last_slot = int(settings.last_slot)
	return result

static func _is_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _strings_only(value) -> bool:
	if not value is Array:
		return false
	for entry in value:
		if not entry is String:
			return false
	return true

static func _slot_path(slot: int) -> String:
	return storage_directory + ("/autosave.godsave" if slot == 9 else "/slot_%d.godsave" % (slot + 1))

static func _slot_label(slot: int) -> String:
	return "Autosave" if slot == 9 else "Slot %d" % (slot + 1)

static func _failure(message: String) -> Dictionary:
	return {"ok":false,"message":message}
