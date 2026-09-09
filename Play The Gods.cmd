@echo off
if exist "%~dp0build\The Gods.exe" (
  start "" "%~dp0build\The Gods.exe"
) else (
  echo The game has not been exported yet. Open project.godot in Godot or run tools\build.ps1.
  pause
)
