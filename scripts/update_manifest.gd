extends RefCounted

## Treat release metadata as network input. Android also verifies the downloaded
## package's identity, version and signing certificate before offering installation.
const MAX_APK_BYTES=250*1024*1024
const APK_URL_PREFIX="https://github.com/malov-dot/the-gods-android/releases/download/"

static func validate(data, package_name:String, channel:String="stable", url_prefix:String=APK_URL_PREFIX)->Dictionary:
	if not data is Dictionary: return failure("The update service returned an unreadable release.")
	if data.get("schema")!=1: return failure("This release format is not supported.")
	if data.get("package_name")!=package_name or data.get("channel")!=channel:
		return failure("This release belongs to a different game or update channel.")
	if not whole_number(data.get("version_code"),1,2147483647): return failure("The release version is invalid.")
	var version=data.get("version_name","")
	if not version is String or version.is_empty() or version.length()>48: return failure("The release name is invalid.")
	var url=data.get("apk_url","")
	if not url is String or not url.begins_with(url_prefix) or not url.ends_with(".apk") or url.length()>1024 or ".." in url or "?" in url or "#" in url or "\\" in url:
		return failure("The release download address is not trusted.")
	var hash_=data.get("apk_sha256","")
	if not hash_ is String or hash_.length()!=64: return failure("The release checksum is invalid.")
	for character in hash_.to_lower():
		if not character in "0123456789abcdef": return failure("The release checksum is invalid.")
	if not whole_number(data.get("apk_bytes"),1024,MAX_APK_BYTES): return failure("The release download size is invalid.")
	var notes=data.get("notes","")
	if not notes is String or notes.length()>4000: return failure("The release notes are invalid.")
	return {"ok":true,"release":{"version_code":int(data.version_code),"version_name":version,"apk_url":url,"apk_sha256":hash_.to_lower(),"apk_bytes":int(data.apk_bytes),"notes":notes}}

static func whole_number(value,minimum:int,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum

static func failure(message:String)->Dictionary:
	return {"ok":false,"message":message}
