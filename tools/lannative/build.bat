@echo off
rem Builds the loader with MSVC Build Tools 2022 (x64). Usage (run from this folder):
rem   build.bat        -> version.dll      (the normal build)
rem   build.bat dev    -> version.dev.dll  (adds a developer shot runner; do not ship it)
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
rem The script extender needs symbols.bin, made from your own copy of the game (README.md in this folder): stop instead of building without it.
if not exist "%~dp0symbols.bin" (
  echo ERROR: %~dp0symbols.bin is missing. Generate it first: see README.md in this folder.
  exit /b 1
)
rc /nologo /fo lannative.res lannative.rc || exit /b 1
if /I "%~1"=="dev" (
  cl /nologo /O2 /MT /W3 /D_CRT_SECURE_NO_WARNINGS /DLANNATIVE_SHOTRUNNER /LD lannative.c lan_logic.c lan_telemetry.c lannative.res /Fe:version.dev.dll /link /NOLOGO /RELEASE user32.lib kernel32.lib shlwapi.lib || exit /b 1
  echo built: %CD%\version.dev.dll
) else (
  cl /nologo /O2 /MT /W3 /D_CRT_SECURE_NO_WARNINGS /LD lannative.c lan_logic.c lan_telemetry.c lannative.res /Fe:version.dll /link /NOLOGO /RELEASE user32.lib kernel32.lib shlwapi.lib || exit /b 1
  echo built: %CD%\version.dll
)
