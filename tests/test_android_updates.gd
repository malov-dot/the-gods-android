extends SceneTree

const Bootstrap=preload("res://scripts/android_bootstrap.gd")
const Manifest=preload("res://scripts/update_manifest.gd")
var checks=0
var failures=0
var server=TCPServer.new()
var peers=[]
var port=18471
var manifest_body=""
var http_code=200
var apk_body=PackedByteArray()
var file_body=PackedByteArray()
var downloads=0
var screenshots=false

class Bridge extends RefCounted:
	signal verification_finished(result_json:String)
	signal permission_returned(allowed:bool)
	signal installer_returned
	var version_code=10400
	var allowed=false
	var accept_package=true
	var install_calls=0
	var verify_calls=0
	var path=""
	func get_installed_info(): return JSON.stringify({"package_name":"games.thegods.sandbox","version_code":version_code,"version_name":"1.4.0"})
	func get_update_path(): return path
	func verify_apk(file,expected_sha,expected_version):
		verify_calls+=1
		var valid=accept_package and FileAccess.get_sha256(file)==expected_sha and expected_version>version_code
		verification_finished.emit.call_deferred(JSON.stringify({"ok":valid,"message":"Fixture package verification"}))
	func can_install_packages(): return allowed
	func request_install_permission():
		allowed=true
		permission_returned.emit.call_deferred(true)
	func install_verified_apk():
		install_calls+=1
		return "opened"

func _initialize(): run.call_deferred()

func check(value:bool,message:String):
	checks+=1
	if not value:
		failures+=1
		push_error("ANDROID UPDATE: "+message)

func _process(_delta):
	while server.is_connection_available():
		peers.append({"peer":server.take_connection(),"buffer":""})
	for entry in peers.duplicate():
		var peer:StreamPeerTCP=entry.peer
		peer.poll()
		var available=peer.get_available_bytes()
		if available>0: entry.buffer+=peer.get_utf8_string(available)
		if "\r\n\r\n" in entry.buffer:
			var route=entry.buffer.split("\r\n")[0].split(" ")[1]
			var body=manifest_body.to_utf8_buffer()
			var code=http_code
			if route.begins_with("/apk/"):
				body=file_body
				code=200
				downloads+=1
			var headers="HTTP/1.1 %d %s\r\nContent-Type: application/octet-stream\r\nContent-Length: %d\r\nConnection: close\r\n\r\n"%[code,"OK" if code==200 else "Unavailable",body.size()]
			peer.put_data(headers.to_utf8_buffer()+body)
			peers.erase(entry)
		elif peer.get_status() in [StreamPeerTCP.STATUS_NONE,StreamPeerTCP.STATUS_ERROR]: peers.erase(entry)
	return false

func sample()->Dictionary:
	return {"schema":1,"channel":"stable","package_name":"games.thegods.sandbox","version_code":10400,"version_name":"1.4.0","apk_url":Manifest.APK_URL_PREFIX+"v1.4.0/The-Gods-Android.apk","apk_sha256":"a".repeat(64),"apk_bytes":4096,"notes":"Android updates."}

func local_release()->Dictionary:
	var data=sample()
	data.apk_url="http://127.0.0.1:%d/apk/game.apk"%port
	data.apk_sha256=apk_body.get_string_from_ascii().sha256_text()
	return data

func start_case(data,version=10400,accept_package=true):
	manifest_body=JSON.stringify(data)
	downloads=0
	var bridge=Bridge.new()
	bridge.version_code=version
	bridge.accept_package=accept_package
	bridge.path=ProjectSettings.globalize_path("res://test-output/android-update-fixtures/update.apk")
	var boot=Bootstrap.new()
	boot.force_update_check=true
	boot.launch_game_on_success=false
	boot.native=bridge
	boot.config_override={"package_name":"games.thegods.sandbox","version_name":"1.4.0","channel":"stable","manifest_url":"http://127.0.0.1:%d/update.json"%port,"apk_url_prefix":"http://127.0.0.1:%d/apk/"%port}
	boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(boot)
	return boot

func until(boot,expected:String):
	var deadline=Time.get_ticks_msec()+6000
	while boot.phase!=expected and Time.get_ticks_msec()<deadline: await create_timer(0.015).timeout
	check(boot.phase==expected,"Expected "+expected+", received "+boot.phase)

func dispose(boot):
	boot.queue_free()
	for i in range(3): await process_frame

func capture(boot,label_):
	for i in range(6): await process_frame
	var rect=boot.panel.get_global_rect()
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(rect),label_+" panel fits")
	for control in [boot.action,boot.offline]:
		if control.visible:
			check(control.size.y>=48,label_+" touch target >=48")
			check(rect.encloses(control.get_global_rect()),label_+" action fits panel")
	if screenshots:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-output/android-launcher-"+label_+".png")==OK,"Capture "+label_)

func run():
	screenshots="--screenshots" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://test-output/android-update-fixtures")
	apk_body="a".repeat(4096).to_utf8_buffer()
	file_body=apk_body
	check(Manifest.validate(sample(),"games.thegods.sandbox").ok,"Valid public release accepted")
	for change in [["schema",2],["package_name","another.game"],["channel","beta"],["version_code",0],["version_code",4.5],["version_code",2147483648],["version_name",""],["apk_url","http://github.com/malov-dot/the-gods-android/releases/download/v1.4.0/game.apk"],["apk_url","https://evil.example/game.apk"],["apk_url",Manifest.APK_URL_PREFIX+"../game.apk"],["apk_sha256","0".repeat(63)],["apk_sha256","z".repeat(64)],["apk_bytes",0],["apk_bytes",Manifest.MAX_APK_BYTES+1],["notes",12]]:
		var data=sample()
		data[change[0]]=change[1]
		check(not Manifest.validate(data,"games.thegods.sandbox").ok,"Reject malformed "+change[0]+" "+str(change[1]).left(40))
	for invalid in [null,[],"bad"]: check(not Manifest.validate(invalid,"games.thegods.sandbox").ok,"Reject non-object release")
	var error=server.listen(port,"127.0.0.1")
	check(error==OK,"Isolated loopback update fixture starts")
	if error!=OK: quit(1); return
	var boot=start_case(local_release())
	await until(boot,"launched")
	check(downloads==0 and boot.native.verify_calls==0,"Current version starts without an APK download")
	await dispose(boot)
	var older=local_release()
	older.version_code=10399
	boot=start_case(older)
	await until(boot,"launched")
	check(downloads==0,"An older manifest cannot downgrade the installed app")
	await dispose(boot)
	root.size=Vector2i(390,844)
	boot=start_case(local_release(),10399)
	await until(boot,"permission")
	check(downloads==1 and boot.native.verify_calls==1,"New release is downloaded and verified before installation permission")
	check(boot.native.install_calls==0,"No install before permission")
	await capture(boot,"permission-390")
	boot.action.pressed.emit()
	await until(boot,"installing")
	check(boot.native.install_calls==1,"Permission return opens the normal installer once")
	boot.native.installer_returned.emit()
	check("canceled" in boot.detail.text,"Canceled installer remains retryable")
	root.size=Vector2i(844,390)
	await capture(boot,"install-844")
	boot.offline.pressed.emit()
	check(boot.phase=="launched","Offline play remains available after a canceled installation")
	await dispose(boot)
	boot=start_case(local_release(),10399,false)
	await until(boot,"error")
	check(boot.native.install_calls==0,"Native certificate rejection never reaches installation")
	await dispose(boot)
	var bad_digest=local_release()
	bad_digest.apk_sha256="0".repeat(64)
	boot=start_case(bad_digest,10399)
	await until(boot,"error")
	check(boot.native.install_calls==0,"Corrupt download never reaches installation")
	await dispose(boot)
	file_body="partial".to_utf8_buffer()
	boot=start_case(local_release(),10399)
	await until(boot,"error")
	check(boot.native.verify_calls==0,"Truncated downloads are rejected before native verification")
	await dispose(boot)
	file_body=apk_body
	http_code=503
	boot=start_case(local_release())
	await until(boot,"error")
	root.size=Vector2i(390,844)
	await capture(boot,"offline-390")
	check(boot.offline.visible,"Unavailable server offers explicit offline play")
	http_code=200
	boot.action.pressed.emit()
	await until(boot,"launched")
	check(downloads==0,"Retry recovers when the server returns")
	await dispose(boot)
	boot=start_case(local_release())
	manifest_body="invalid json"
	await until(boot,"error")
	check(boot.native.install_calls==0,"Invalid network JSON never reaches installation")
	await dispose(boot)
	server.stop()
	peers.clear()
	print("ANDROID UPDATE ACCEPTANCE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
