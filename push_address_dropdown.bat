@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "driver_app/lib/features/auth/widgets/contact_info_section.dart"
git add "driver_app/lib/features/auth/registration_screen.dart"
git add "driver_app/lib/features/auth/business_registration_screen.dart"
git add "driver_app/lib/services/address_lookup_service.dart"

git commit -m "Add postcode-to-address dropdown for driver and business registration"

git push

echo.
echo === goouts_drapp address dropdown pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
