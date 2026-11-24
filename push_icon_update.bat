@echo off
echo === Pushing goouts_drapp icon update ===
cd /d C:\Users\Maz\goouts\goouts_drapp
git add driver_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/
git add driver_app/android/app/src/main/res/mipmap-mdpi/ic_launcher.png
git add driver_app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png
git add driver_app/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
git add driver_app/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
git add driver_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
git commit -m "Update app icon to thicker-line GoOuts logo"
git push
echo === goouts_drapp icon pushed! ===
pause
