@echo off
setlocal
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/services/fcm_service.dart"
git add "lib/features/delivery/screens/driver_dashboard_screen.dart"
git add "lib/features/delivery/screens/new_order_offer_screen.dart"
git add "lib/features/delivery/screens/active_delivery_screen.dart"
git add "lib/features/delivery/screens/support_training_screen.dart"
git add "lib/features/delivery/screens/safety_toolkit_screen.dart"

REM ── Commit message written to a temp file instead of multiple -m flags ──
REM Long chained -m arguments are a common silent-failure point in .bat
REM files (no error shown, script just carries on). A file avoids that.
set MSGFILE=%TEMP%\goouts_drapp_commit_msg.txt
> "%MSGFILE%" (
  echo Fix broken order accept/decline flow, FCM token save, wire dead buttons
  echo.
  echo - driver_dashboard_screen/new_order_offer_screen: accept/decline now call
  echo   the new acceptFoodOrder/declineFoodOrder Cloud Functions instead of a
  echo   client Firestore update firestore.rules always blocked
  echo - fcm_service: food_drivers checked for a profile before
  echo   drivers/cab_drivers/businesses, so push tokens actually save for food
  echo   delivery drivers
  echo - active_delivery_screen: call-restaurant and navigate-to-restaurant
  echo   buttons wired to tel: and Google Maps
  echo - support_training_screen: Live Chat and FAQs wired to the existing
  echo   support ticket screens; SOS dialog no longer falsely claims to
  echo   auto-contact 999 or share location
  echo - safety_toolkit_screen: same SOS honesty fix, plus Current Location
  echo   now shows real GPS coordinates instead of a hardcoded fake address
)

git commit -F "%MSGFILE%"
if errorlevel 1 (
  echo.
  echo *** COMMIT FAILED - see the error above. Nothing was pushed. ***
  echo.
  pause
  exit /b 1
)

del /F /Q "%MSGFILE%" 2>NUL

git push
if errorlevel 1 (
  echo.
  echo *** PUSH FAILED - see the error above. ***
  echo *** Common cause: GitHub asked to sign in and the window can't show it. ***
  echo *** Try running "git push" by hand in a terminal in this folder. ***
  echo.
  pause
  exit /b 1
)

echo.
echo === goouts_drapp fixes committed AND pushed! ===
echo GitHub Actions (iOS TestFlight) starts automatically on push to main.
echo Check progress at https://github.com/mianamir74/goouts_drapp/actions
echo.
pause
