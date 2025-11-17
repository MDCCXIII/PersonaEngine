@echo off
setlocal enabledelayedexpansion

REM Go to the folder this script is in (repo root)
pushd "%~dp0" >nul 2>&1

REM Capture repo root for relative paths
set "root=%CD%"

REM Temp file to assemble the URL list
set "tmp=%TEMP%\personaengine_raw_urls.txt"
if exist "%tmp%" del "%tmp%"

REM Collect all .lua and .toc files recursively
for /r %%F in (*.lua *.toc) do (
    set "rel=%%F"
    REM Strip the repo root prefix from the full path
    set "rel=!rel:%root%\=!"
    REM Convert backslashes to forward slashes for URLs
    set "rel=!rel:\=/!"
    echo https://raw.githubusercontent.com/MDCCXIII/PersonaEngine/master/!rel!>>"%tmp%"
)

REM Copy the full list to clipboard
type "%tmp%" | clip

REM Optional: clean up temp file
del "%tmp%" >nul 2>&1

popd >nul 2>&1
endlocal
