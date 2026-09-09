"""Fetch Android members of Godot's official template pack, checking ZIP CRCs."""
import argparse
import io
import json
import pathlib
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
API = f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}"


class RemoteZip(io.RawIOBase):
    def __init__(self, url, length):
        self.url, self.length, self.position = url, length, 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position
    def read(self, amount=-1):
        amount = min(amount if amount >= 0 else self.length-self.position, self.length-self.position)
        chunks = []
        while amount > 0:
            count = min(amount, 16*1024*1024)
            request = urllib.request.Request(self.url, headers={"Range":f"bytes={self.position}-{self.position+count-1}","User-Agent":"The-Gods-build"})
            with urllib.request.urlopen(request, timeout=90) as response:
                if response.status != 206: raise RuntimeError("Expected HTTP range; refusing complete template pack")
                data = response.read(count+1)
            if len(data) != count: raise RuntimeError("Incomplete archive range")
            chunks.append(data)
            amount -= count
            self.position += count
        return b"".join(chunks)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=pathlib.Path, default=pathlib.Path.home()/".cache"/"the-gods-tools"/"4.7.2")
    parser.add_argument("--source", action="store_true", help="Include Gradle source with bundled native libraries")
    args = parser.parse_args()
    names = ["android_release.apk", "android_debug.apk"]
    if args.source: names.append("android_source.zip")
    missing = [name for name in names if not (args.cache/name).exists()]
    if not missing:
        print("Android templates already installed:", args.cache)
        return
    with urllib.request.urlopen(urllib.request.Request(API,headers={"User-Agent":"The-Gods-build"}),timeout=30) as response:
        release = json.load(response)
    asset = next(a for a in release["assets"] if a["name"]==f"Godot_v{VERSION}_export_templates.tpz")
    args.cache.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(RemoteZip(asset["browser_download_url"],asset["size"])) as archive:
        for name in missing:
            print("Downloading",name,flush=True)
            target = args.cache/name
            data = archive.read("templates/"+name)
            temporary = target.with_suffix(target.suffix+".part")
            temporary.write_bytes(data)
            with zipfile.ZipFile(temporary) as template:
                if template.testzip() is not None: raise RuntimeError("Template CRC check failed: "+name)
            temporary.replace(target)
            print("Verified",target,len(data),"bytes",flush=True)


if __name__ == "__main__": main()
