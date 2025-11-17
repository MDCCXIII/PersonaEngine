@echo off
setlocal

REM ===== Settings =====
set BRANCH=master

REM Go to the folder this script is in (your repo root)
cd /d "%~dp0"

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
echo 📋 Copying clipboard helper text...
echo Repo is up to date; use MDCCXIII/PersonaEngine | clip

echo.
echo ✅ Done. Remote now matches your local copy.
echo   (Clipboard text is ready to paste into ChatGPT.)
echo.
pause

