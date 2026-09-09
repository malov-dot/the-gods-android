"""Fetch only Godot's web template from the official multi-platform archive.

HTTP byte ranges avoid downloading the entire 1.2 GB desktop/mobile template pack.
zipfile verifies the extracted member's CRC before it is written to the cache.
"""
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
        self.downloaded = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position
    def read(self, amount=-1):
        if amount < 0: amount = self.length - self.position
        amount = min(amount, self.length-self.position)
        if amount <= 0: return b""
        if amount > 100_000_000: raise ValueError("Unexpectedly large template member")
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.position}-{self.position+amount-1}", "User-Agent":"The-Gods-build"})
        with urllib.request.urlopen(request, timeout=90) as response:
            if response.status != 206: raise RuntimeError("Server did not honor byte range; refusing full archive download")
            data = response.read(amount+1)
        if len(data) != amount: raise RuntimeError("Incomplete archive range")
        self.position += amount
        self.downloaded += amount
        return data

def main():
    cache = pathlib.Path.home()/".cache"/"the-gods-tools"/"4.7.2"
    target = cache/"web_nothreads_release.zip"
    if target.exists():
        print(target)
        return
    with urllib.request.urlopen(urllib.request.Request(API,headers={"User-Agent":"The-Gods-build"}),timeout=30) as response:
        release=json.load(response)
    asset=next(asset for asset in release["assets"] if asset["name"]==f"Godot_v{VERSION}_export_templates.tpz")
    remote=RemoteZip(asset["browser_download_url"],asset["size"])
    with zipfile.ZipFile(remote) as archive:
        options=[name for name in archive.namelist() if "web" in name and "release" in name]
        print("Available web templates:",options,flush=True)
        name=next(name for name in options if name.endswith("web_nothreads_release.zip"))
        data=archive.read(name)
    cache.mkdir(parents=True,exist_ok=True)
    target.write_bytes(data)
    with zipfile.ZipFile(target) as template:
        if template.testzip() is not None: raise RuntimeError("Web template integrity check failed")
    print(f"Verified {target}; downloaded {remote.downloaded:,} bytes.")

if __name__ == "__main__": main()
