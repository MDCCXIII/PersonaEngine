@echo off
setlocal

REM ===== Settings =====
set BRANCH=master

REM Move to the folder this script is in
pushd "%~dp0" >nul 2>&1

echo.
echo 🔧 Staging all changes...
git add -A

echo.
echo 📝 Committing (if there are changes)...
git commit -m "sync-up: auto commit latest local changes" || echo No changes to commit.

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
pause
