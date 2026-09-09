"""Serve only the exported game to browsers on this PC or the same local network."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class GameHandler(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,".wasm":"application/wasm",".pck":"application/octet-stream"}
    def list_directory(self,path): self.send_error(403,"Directory listing disabled")
    def end_headers(self):
        self.send_header("Cache-Control","no-cache")
        super().end_headers()

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--host",default="0.0.0.0")
parser.add_argument("--port",type=int,default=8093)
parser.add_argument("--directory",type=Path,help="Directory containing the compiled browser game")
args=parser.parse_args()
directory=(args.directory or (Path(__file__).resolve().parent if (Path(__file__).resolve().parent/"index.html").is_file() else Path(__file__).resolve().parent.parent/"build"/"web")).resolve()
if not (directory/"index.html").is_file(): parser.error("Run tools/build_web.ps1 first.")
print(f"The Gods is available on port {args.port}. Only files in {directory} are served.",flush=True)
ThreadingHTTPServer((args.host,args.port),partial(GameHandler,directory=str(directory))).serve_forever()
