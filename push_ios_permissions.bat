@echo off
echo === Pushing iOS permission fixes for goouts_drapp ===
cd /d C:\Users\Maz\goouts\goouts_drapp
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul
git add driver_app/ios/Runner/Info.plist
git commit -m "Add missing iOS permissions: NSCameraUsage, NSPhotoLibrary, NSLocation, NSFaceID"
git push
echo === Done! ===
pause
