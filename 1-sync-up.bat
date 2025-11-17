@echo off
setlocal

REM ===== Settings =====
set BRANCH=master

REM Move to the folder this script is in
pushd "%~dp0" >nul 2>&1

echo.
echo 🔧 Staging all changes...
git add -A

REM ===== Timestamp builder (YYYY-Mon-DD HH:MM) =====
setlocal enabledelayedexpansion

REM Parse date (MM/DD/YYYY depending on locale)
for /f "tokens=1-3 delims=/- " %%a in ("%date%") do (
    set mm=%%a
    set dd=%%b
    set yyyy=%%c
)

REM Parse time (HH:MM:SS.xx)
for /f "tokens=1-3 delims=:." %%h in ("%time%") do (
    set hh=%%h
    set nn=%%i
    if "!hh:~0,1!"==" " set hh=0!hh:~1!
)

REM Convert month number → short name
set mn=
if "%mm%"=="01" set mn=Jan
if "%mm%"=="02" set mn=Feb
if "%mm%"=="03" set mn=Mar
if "%mm%"=="04" set mn=Apr
if "%mm%"=="05" set mn=May
if "%mm%"=="06" set mn=Jun
if "%mm%"=="07" set mn=Jul
if "%mm%"=="08" set mn=Aug
if "%mm%"=="09" set mn=Sep
if "%mm%"=="10" set mn=Oct
if "%mm%"=="11" set mn=Nov
if "%mm%"=="12" set mn=Dec

set "STAMP=%yyyy%-%mn%-%dd% %hh%:%nn%"
endlocal & set "STAMP=%STAMP%"

echo.
echo 📝 Committing (if there are changes)...
git commit -m "Sync-Up: auto commit [%STAMP%]" || echo No changes to commit.

echo.
echo 🚀 Force pushing local -> origin/%BRANCH% ...
git push origin %BRANCH% --force

echo.
echo 📋 Building raw.githubusercontent.com URL list and copying to clipboard...
call 2-get-raw.bat

echo.
echo ✅ Done. Remote now matches your local copy.
echo   (Clipboard now contains raw URLs for all .lua and .toc files.)
echo.
endlocal
