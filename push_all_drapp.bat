@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "assets/logo/virtual_card.png"
git add "assets/logo/icon_source.png"
git add "driver_app/lib/features/auth/business_registration_screen.dart"
git add "driver_app/lib/features/auth/registration_screen.dart"
git add "driver_app/lib/features/auth/widgets/contact_info_section.dart"
git add "driver_app/lib/services/address_lookup_service.dart"
git add "driver_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/"
git add "driver_app/android/app/src/main/res/"

git commit -m "Address dropdown + thick logo update for goouts_drapp"

git push

echo.
echo === goouts_drapp all changes pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
