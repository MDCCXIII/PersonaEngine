@echo off
setlocal

REM ===== Settings =====
set BRANCH=master

REM Move to the folder this script is in
pushd "%~dp0" >nul 2>&1

echo.
echo 🔧 Staging all changes...
git add -A

REM Build pretty timestamp: YYYY-MM-DD HH:MM
for /f "tokens=1-3 delims=/- " %%a in ("%date%") do (
    set yyyy=%%c
    set mm=%%a
    set dd=%%b
)

for /f "tokens=1-3 delims=:." %%h in ("%time%") do (
    set hh=%%h
    set nn=%%i
    REM If hour has leading space (before 10AM), fix it
    if "!hh:~0,1!"==" " set hh=0!hh:~1!
)

set "STAMP=%yyyy%-%mm%-%dd% %hh%:%nn%"


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
