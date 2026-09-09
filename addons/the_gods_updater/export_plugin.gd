@tool
extends EditorPlugin

var exporter

func _enter_tree():
	exporter = AndroidUpdaterExport.new()
	add_export_plugin(exporter)

func _exit_tree():
	remove_export_plugin(exporter)
	exporter = null

class AndroidUpdaterExport extends EditorExportPlugin:
	func _get_name(): return "TheGodsUpdater"
	func _supports_platform(platform): return platform is EditorExportPlatformAndroid
	func _get_android_libraries(_platform, _debug):
		return PackedStringArray(["res://addons/the_gods_updater/bin/the-gods-updater-release.aar"])
	func _get_android_dependencies(_platform, _debug):
		return PackedStringArray(["androidx.core:core:1.16.0"])
