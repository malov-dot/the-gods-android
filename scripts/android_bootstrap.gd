extends Control

## The Android entry point checks a bounded HTTPS manifest before loading the
## simulation. Downloads stay private, and the native bridge checks APK identity.
const Manifest=preload("res://scripts/update_manifest.gd")
const MobileDisplay=preload("res://scripts/mobile_display.gd")
const GOLD=Color("d9bd83")
const LIGHT=Color("e9e6d6")
const MUTED=Color("9faeaa")
signal game_ready
var native
var force_update_check=false
var launch_game_on_success=true
var config_override:Dictionary={}
var config:Dictionary={}
var installed:Dictionary={}
var release:Dictionary={}
var phase="idle"
var request:HTTPRequest
var download_path=""
var status:Label
var detail:Label
var progress:ProgressBar
var action:Button
var offline:Button
var footer:Label
var content:VBoxContainer
var panel:PanelContainer
var last_download_bytes=0
var stalled_seconds=0.0
var phase_time=0.0
var _ready_done=false

func _ready():
	if not OS.has_feature("android") and not force_update_check:
		_launch_game.call_deferred()
		return
	get_tree().quit_on_go_back=false
	MobileDisplay.configure(get_window())
	_build_ui()
	var parsed_config=config_override if not config_override.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://release/android.json"))
	config=parsed_config if parsed_config is Dictionary else {}
	if config.is_empty():
		_issue("Update setup unavailable","The game can still be played offline. Reinstall the latest APK from the download page to restore update checks.")
		return
	if native==null and Engine.has_singleton("TheGodsUpdater"): native=Engine.get_singleton("TheGodsUpdater")
	if native==null:
		_issue("Update setup unavailable","This installation cannot check Android packages. You can play offline or install the latest APK from the download page.")
		return
	var parsed_info=JSON.parse_string(native.get_installed_info())
	installed=parsed_info if parsed_info is Dictionary else {}
	if installed.is_empty() or installed.get("package_name")!=config.package_name:
		_issue("Installation could not be identified","You can play offline and install the latest APK from the download page.")
		return
	footer.text="Your saved worlds stay on this phone · v"+str(installed.get("version_name",config.version_name))
	native.connect("verification_finished",_on_verification_finished)
	native.connect("permission_returned",_on_permission_returned)
	native.connect("installer_returned",_on_installer_returned)
	download_path=native.get_update_path()
	if download_path.is_empty():
		_issue("Not enough storage for updates","Free some space on this phone and reopen The Gods, or play offline.")
		return
	request=HTTPRequest.new()
	request.use_threads=true
	request.request_completed.connect(_on_request_completed)
	add_child(request)
	_check()

func _build_ui():
	var theme_=Theme.new()
	theme_.default_font=preload("res://assets/fonts/inter.ttf")
	theme_.default_font_size=15
	theme=theme_
	var background=ColorRect.new()
	background.color=Color("0c171b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	panel=PanelContainer.new()
	var box=StyleBoxFlat.new()
	box.bg_color=Color("142327")
	box.border_color=Color("766b4b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left=18
	box.content_margin_right=18
	box.content_margin_top=16
	box.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",box)
	add_child(panel)
	content=VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	var top=HBoxContainer.new()
	top.add_theme_constant_override("separation",12)
	content.add_child(top)
	var icon=TextureRect.new()
	icon.texture=preload("res://assets/icon.svg")
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size=Vector2(52,52)
	top.add_child(icon)
	var title=label("THE GODS",34,GOLD)
	title.add_theme_font_override("font",preload("res://assets/fonts/cormorantgaramond.ttf"))
	top.add_child(title)
	content.add_child(HSeparator.new())
	status=label("Checking for updates",19,LIGHT)
	content.add_child(status)
	detail=label("Finding the latest version before your world begins.",14,MUTED)
	content.add_child(detail)
	progress=ProgressBar.new()
	progress.show_percentage=false
	progress.custom_minimum_size.y=8
	progress.modulate=GOLD
	content.add_child(progress)
	action=button("Retry",_primary_action)
	content.add_child(action)
	action.hide()
	offline=button("Play offline",_play_offline)
	content.add_child(offline)
	offline.hide()
	footer=label("Your saved worlds stay on this phone",11,MUTED)
	content.add_child(footer)
	_ready_done=true
	resized.connect(_layout)
	content.minimum_size_changed.connect(_layout.call_deferred)
	_layout()

func label(text_:String,size_:int,color_:Color)->Label:
	var result=Label.new()
	result.text=text_
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size",size_)
	result.add_theme_color_override("font_color",color_)
	return result

func button(text_:String,callback:Callable)->Button:
	var result=Button.new()
	result.text=text_
	result.custom_minimum_size.y=48
	result.pressed.connect(callback)
	for kind in ["normal","hover","pressed","focus"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color("223739") if kind=="normal" else Color("4e4b32")
		style.border_color=GOLD
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		result.add_theme_stylebox_override(kind,style)
	result.add_theme_color_override("font_color",LIGHT)
	return result

func _layout():
	if not _ready_done: return
	MobileDisplay.configure(get_window())
	var safe=MobileDisplay.hud_rect(get_viewport_rect().size,get_window().content_scale_factor)
	var view=safe.size
	var width_=minf(440,view.x-24)
	panel.custom_minimum_size.x=width_
	panel.size=Vector2(width_,0)
	panel.position=safe.position+Vector2((view.x-width_)*0.5,maxf(12,(view.y-panel.size.y)*0.5))

func _set_phase(value:String,title_:String,message:String):
	phase=value
	phase_time=0
	status.text=title_
	detail.text=message
	action.hide()
	offline.hide()
	progress.show()
	progress.value=0
	_layout.call_deferred()

func _check():
	if native==null or request==null:
		_issue("Update setup unavailable","Play offline or install the latest APK from the public download page.")
		return
	request.cancel_request()
	_set_phase("checking","Checking for updates","Finding the latest version before your world begins.")
	request.download_file=""
	request.body_size_limit=32768
	request.timeout=12
	request.max_redirects=5
	request.accept_gzip=true
	var result=request.request(str(config.manifest_url)+"?check="+str(int(Time.get_unix_time_from_system())),PackedStringArray(["Cache-Control: no-cache","User-Agent: TheGods-Android"]))
	if result!=OK: _issue("Could not check for updates","Check your connection and retry, or play the version already on your phone.")

func _on_request_completed(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	if phase not in ["checking","downloading"]: return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		_issue("Update check unavailable" if phase=="checking" else "Download interrupted","Check your connection and retry. Your installed game and saved worlds are unchanged.")
		return
	if phase=="checking":
		var json=JSON.new()
		var parsed=json.parse(body.get_string_from_utf8())
		var validation=Manifest.validate(json.data if parsed==OK else null,str(config.package_name),str(config.channel),str(config.apk_url_prefix))
		if not validation.ok:
			_issue("Release could not be verified",validation.message+" You can retry or play offline.")
			return
		release=validation.release
		if int(release.version_code)<=int(installed.version_code):
			_set_phase("ready","You're up to date","Opening your world…")
			_launch_game.call_deferred()
		else:
			_download.call_deferred()
	else:
		var file=FileAccess.open(download_path,FileAccess.READ)
		if file==null or file.get_length()!=int(release.apk_bytes):
			_issue("Download was incomplete","The update will be downloaded again. Your existing worlds are safe.")
			return
		file.close()
		_set_phase("verifying","Checking the update","Verifying the game package before installation.")
		progress.value=100
		native.verify_apk(download_path,str(release.apk_sha256),int(release.version_code))

func _download():
	if phase!="checking": return
	request.cancel_request()
	_set_phase("downloading","Updating to v"+str(release.version_name),"Downloading the new release. Your saved worlds will be kept.")
	last_download_bytes=0
	stalled_seconds=0
	request.download_file=download_path
	request.body_size_limit=int(release.apk_bytes)
	request.download_chunk_size=262144
	request.timeout=0
	request.accept_gzip=false
	var result=request.request(str(release.apk_url),PackedStringArray(["User-Agent: TheGods-Android","Accept-Encoding: identity"]))
	if result!=OK: _issue("Could not start the download","Check your connection and retry, or play offline.")

func _on_verification_finished(result_json:String):
	if phase!="verifying": return
	var result=JSON.parse_string(result_json)
	if not result is Dictionary or not result.get("ok",false):
		_issue("Update was not installed","The package did not pass verification. Retry to get a fresh copy, or play offline.")
		return
	_offer_install()

func _offer_install():
	if native.can_install_packages():
		_open_installer()
	else:
		_set_phase("permission","Allow game updates","Android needs your permission to install updates from The Gods. Tap Allow updates, enable the switch, then return here.")
		progress.hide()
		action.text="Allow updates"
		action.show()
		offline.show()

func _open_installer():
	_set_phase("installing","Install the new version","Confirm the update in Android, then reopen The Gods. Your saved worlds will be kept.")
	progress.hide()
	var result=str(native.install_verified_apk())
	if result!="opened":
		_issue("Could not open the installer",result+" You can retry or play offline.")
	else:
		action.text="Open installer again"
		action.show()
		offline.show()

func _on_permission_returned(allowed_:bool):
	if phase!="permission": return
	if allowed_: _open_installer()
	else:
		detail.text="Update permission is still off. Tap Allow updates to try again, or play offline."

func _on_installer_returned():
	if phase!="installing": return
	detail.text="If the update was canceled, tap Open installer again. After installation, reopen The Gods to play the new version."

func _primary_action():
	if phase=="permission": native.request_install_permission()
	elif phase=="installing": _open_installer()
	else: _check()

func _issue(title_:String,message:String):
	if request!=null: request.cancel_request()
	_set_phase("error",title_,message)
	progress.hide()
	action.text="Retry"
	action.visible=native!=null and request!=null
	offline.show()

func _process(delta:float):
	if not _ready_done: return
	phase_time+=delta
	if phase=="downloading":
		var downloaded=request.get_downloaded_bytes()
		progress.value=100.0*downloaded/maxi(1,int(release.apk_bytes))
		detail.text="%.1f / %.1f MB · Your saved worlds will be kept."%[downloaded/1048576.0,int(release.apk_bytes)/1048576.0]
		stalled_seconds=stalled_seconds+delta if downloaded==last_download_bytes else 0.0
		last_download_bytes=downloaded
		if stalled_seconds>45: _issue("Download paused","No data has arrived for a while. Check your connection and retry, or play offline.")
	elif phase=="checking": progress.value=10+70*(0.5+0.5*sin(phase_time*1.8))
	elif phase=="verifying" and phase_time>90: _issue("Verification did not finish","Please retry the update, or play offline.")

func _play_offline():
	if request!=null: request.cancel_request()
	_launch_game()

func _launch_game():
	if phase=="launched": return
	phase="launched"
	game_ready.emit()
	if launch_game_on_success: get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and _ready_done and phase!="launched":
		_issue("Update paused","Retry the update check, or play the installed version offline.")
