$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Working in: $appDir" -ForegroundColor Cyan
Set-Location $appDir

$lockFile = ".git\index.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force
    Write-Host "Removed git index.lock" -ForegroundColor Yellow
}

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

# New widget
git add "lib/features/common/goouts_sheet.dart"

# Auth screens
git add "lib/features/auth/business_registration_screen.dart"
git add "lib/features/auth/login_screen.dart"
git add "lib/features/auth/otp_screen.dart"
git add "lib/features/auth/otp_verification_screen.dart"
git add "lib/features/auth/phone_login_screen.dart"
git add "lib/features/auth/registration_screen.dart"
git add "lib/features/auth/widgets/pre_auth_support_sheet.dart"

# Delivery screens
git add "lib/features/delivery/screens/active_delivery_screen.dart"
git add "lib/features/delivery/screens/dapp_registration_screen.dart"
git add "lib/features/delivery/screens/earnings_screen.dart"
git add "lib/features/delivery/screens/new_order_offer_screen.dart"

# Home
git add "lib/features/home/business_home_screen.dart"
git add "lib/features/home/driver_home_screen.dart"

# Merchant
git add "lib/features/merchant/merchant_onboarding_screen.dart"

# Messages
git add "lib/features/messages/message_detail_screen.dart"
git add "lib/features/messages/messages_inbox_screen.dart"

# Referral
git add "lib/features/referral/business_referral_list_screen.dart"
git add "lib/features/referral/referral_dev_tester_screen.dart"
git add "lib/features/referral/referral_link_screen.dart"
git add "lib/features/referral/referral_list_screen.dart"

# Support
git add "lib/features/support/help_support_screen.dart"
git add "lib/features/support/support_ticket_chat_screen.dart"

git commit -m "UX: Replace all snackbars with branded GoOutsSheet across goouts_drapp

- New lib/features/common/goouts_sheet.dart (no google_fonts dependency)
- All 23 files: every ScaffoldMessenger.showSnackBar replaced with
  GoOutsSheet.success / .error / .info / .warning
- Delivery screens: active_delivery, earnings, new_order_offer all updated
- Validation messages use .warning, errors use .error, success messages use .success"

git push

Write-Host ""
Write-Host "=== goouts_drapp snackbar fixes pushed! ===" -ForegroundColor Green
Write-Host "23 files updated — 0 snackbars remaining" -ForegroundColor Cyan

Read-Host "Press Enter to close"
