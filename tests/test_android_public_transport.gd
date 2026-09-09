extends SceneTree
## Live-release acceptance. Uses the production bootstrap and its real Godot
## HTTPRequest/TLS/redirect/size-limit path. Android package/installer APIs are
## mocked; only the downloaded file's length and SHA-256 are verified here.
const Bootstrap=preload("res://scripts/android_bootstrap.gd")
const MANIFEST_URL="https://github.com/malov-dot/the-gods-android/releases/latest/download/update.json"
const EXPECTED_BYTES=54235139
const EXPECTED_SHA="db9b5452c91829bdce18a0506e91a7cd86846782583d93effc9bbacf3639d7e6"
const EXPECTED_VERSION=10701
var checks=0
var failures=0
var fixture_directory=""
var evidence={"android_installer_tested":false,"native_package_signature_tested":false,"transport":"Production Godot HTTPRequest over public HTTPS"}

class ObservedBootstrap extends "res://scripts/android_bootstrap.gd":
	var download_attempts=0
	var ready_count=0
	var responses=[]
	func _download():
		download_attempts+=1
		super._download()
	func _on_request_completed(result:int,code:int,headers:PackedStringArray,body:PackedByteArray):
		responses.append({"phase":phase,"result":result,"http_code":code,"body_bytes":body.size(),"downloaded_bytes":request.get_downloaded_bytes()})
		super._on_request_completed(result,code,headers,body)

class HashOnlyBridge extends RefCounted:
	signal verification_finished(result_json:String)
	signal permission_returned(allowed:bool)
	signal installer_returned
	var version_code=10701
	var path=""
	var verify_calls=0
	var permission_calls=0
	var install_calls=0
	var actual_sha=""
	var actual_bytes=0
	var announced_sha=""
	var announced_version=0
	func get_installed_info():
		return JSON.stringify({"package_name":"games.thegods.sandbox","version_code":version_code,"version_name":"Live transport fixture"})
	func get_update_path(): return path
	func verify_apk(file,expected_sha,expected_version):
		verify_calls+=1
		announced_sha=expected_sha
		announced_version=expected_version
		actual_sha=FileAccess.get_sha256(file)
		var apk=FileAccess.open(file,FileAccess.READ)
		actual_bytes=apk.get_length() if apk!=null else 0
		if apk!=null: apk.close()
		var valid=actual_sha==expected_sha and expected_version>version_code
		verification_finished.emit.call_deferred(JSON.stringify({"ok":valid,"message":"Real file SHA checked; native Android package/signature checks are mocked."}))
	func can_install_packages(): return false
	func request_install_permission():
		permission_calls+=1
		permission_returned.emit.call_deferred(false)
	func install_verified_apk():
		install_calls+=1
		return "This transport test never opens an Android installer."

func _initialize(): run.call_deferred()
func check(value:bool,message:String):
	checks+=1
	if not value:
		failures+=1
		push_error("PUBLIC ANDROID TRANSPORT: "+message)

func start_case(version:int,name_:String):
	var bridge=HashOnlyBridge.new()
	bridge.version_code=version
	bridge.path=ProjectSettings.globalize_path(fixture_directory+"/"+name_+".apk")
	var boot=ObservedBootstrap.new()
	boot.force_update_check=true
	boot.launch_game_on_success=false
	boot.native=bridge
	# Use the actual bundled production configuration, including public URL and
	# trusted download prefix. The fixture only changes installed version/storage.
	boot.game_ready.connect(func(): boot.ready_count+=1)
	boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(boot)
	return boot

func until(boot,expected:String,seconds:int)->bool:
	var started=Time.get_ticks_msec()
	var deadline=started+seconds*1000
	var last_phase=""
	var next_progress=started
	while Time.get_ticks_msec()<deadline:
		if boot.phase!=last_phase:
			print("PUBLIC TRANSPORT installed=",boot.native.version_code," phase=",boot.phase)
			last_phase=boot.phase
		if boot.phase==expected: return true
		if boot.phase=="error":
			print("PUBLIC TRANSPORT error: ",boot.status.text," — ",boot.detail.text)
			return false
		if boot.phase=="downloading" and Time.get_ticks_msec()>=next_progress:
			print("PUBLIC TRANSPORT downloaded=",boot.request.get_downloaded_bytes()," / ",EXPECTED_BYTES)
			next_progress=Time.get_ticks_msec()+10000
		await create_timer(0.05).timeout
	return false

func dispose(boot):
	if is_instance_valid(boot.request): boot.request.cancel_request()
	boot.queue_free()
	for unused in range(3): await process_frame

func run():
	root.size=Vector2i(390,844)
	evidence.started_utc=Time.get_datetime_string_from_system(true)
	fixture_directory="res://test-output/android-public-transport-fixtures/"+str(int(Time.get_unix_time_from_system()))
	check(DirAccess.make_dir_recursive_absolute(fixture_directory)==OK,"Isolated live-download storage is available")
	var boot=start_case(EXPECTED_VERSION,"already-current")
	check(boot.config.get("manifest_url","")==MANIFEST_URL,"Uses the published production latest-manifest URL")
	var reached=await until(boot,"launched",25)
	check(reached,"The current installed version reaches game_ready using the public latest manifest")
	check(boot.ready_count==1,"Current version emits game_ready exactly once")
	check(boot.download_attempts==0 and boot.native.verify_calls==0,"Current version starts without requesting an APK")
	check(not FileAccess.file_exists(boot.native.path),"Current-version check creates no APK file")
	check(boot.release.get("version_code",0)==EXPECTED_VERSION,"Public manifest advertises the pinned release version")
	check(boot.responses.size()==1 and boot.responses[0].http_code==200 and boot.responses[0].result==HTTPRequest.RESULT_SUCCESS,"Public latest-manifest redirects and TLS complete successfully")
	evidence.current={"phase":boot.phase,"game_ready":boot.ready_count,"downloads":boot.download_attempts,"responses":boot.responses.duplicate(true)}
	await dispose(boot)
	if reached:
		boot=start_case(EXPECTED_VERSION-1,"older-version-update")
		reached=await until(boot,"permission",180)
		check(reached,"The preceding installed version downloads the public release and reaches permission state")
		check(boot.download_attempts==1 and boot.native.verify_calls==1,"Exactly one real APK download reaches hash verification")
		check(boot.native.actual_bytes==EXPECTED_BYTES,"Downloaded APK has exactly the pinned release length")
		check(boot.native.actual_sha==EXPECTED_SHA,"Downloaded APK matches the pinned released SHA-256")
		check(boot.native.announced_sha==EXPECTED_SHA and boot.native.announced_version==EXPECTED_VERSION,"Public manifest hash/version match the independently pinned release")
		check(boot.responses.size()==2 and boot.responses[1].http_code==200 and boot.responses[1].result==HTTPRequest.RESULT_SUCCESS,"Public APK redirects and TLS complete successfully within production size limits")
		check(boot.request.download_file==boot.native.path and boot.request.body_size_limit==EXPECTED_BYTES,"Production download streams to the isolated file with the exact announced size limit")
		check(boot.native.permission_calls==0 and boot.native.install_calls==0 and boot.ready_count==0,"No Android permission, installer or game launch occurs before the user's next choice")
		check(boot.action.visible and boot.action.text=="Allow updates" and boot.offline.visible,"Permission and offline choices remain available after download")
		evidence.older={"phase":boot.phase,"game_ready":boot.ready_count,"downloads":boot.download_attempts,"bytes":boot.native.actual_bytes,"sha256":boot.native.actual_sha,"responses":boot.responses.duplicate(true),"apk_file":boot.native.path}
		await dispose(boot)
	evidence.checks=checks
	evidence.failures=failures
	evidence.finished_utc=Time.get_datetime_string_from_system(true)
	var report=FileAccess.open("res://test-output/android-public-transport.json",FileAccess.WRITE)
	if report!=null: report.store_string(JSON.stringify(evidence,"  ")); report.close()
	print("PUBLIC ANDROID TRANSPORT: ",checks," checks; ",failures," failures")
	print("LIMIT: Android package/signature APIs, permission settings and installer lifecycle are mocked, not device-tested.")
	quit(1 if failures else 0)
