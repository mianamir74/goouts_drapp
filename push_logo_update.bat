@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "driver_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/"
git add "driver_app/android/app/src/main/res/"

git commit -m "Update app icon to thick-line logo version"

git push

echo.
echo === goouts_drapp logo pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
