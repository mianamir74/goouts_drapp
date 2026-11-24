@echo off
echo === Pushing goouts_drapp postcode fix ===
cd /d C:\Users\Maz\goouts\goouts_drapp
git add driver_app/lib/services/address_lookup_service.dart
git commit -m "Fix postcode lookup: switch Mapbox v6 to v5 API"
git push
echo === goouts_drapp postcode fix pushed! ===
pause
