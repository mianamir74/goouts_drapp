/// Prevents AppLaunchCoordinator's authStateChanges() StreamBuilder from
/// replacing the widget tree while the login / OTP flow is in progress.
///
/// Usage:
///   AuthFlowGuard.start()  — call at the top of _handleContinue()
///   AuthFlowGuard.end()    — call just before pushAndRemoveUntil in both
///                            LeadPartnerLoginScreen._completeVerificationFlow()
///                            and
///                            LeadPartnerOtpVerificationScreen._completeSuccessfulVerification()
class AuthFlowGuard {
  AuthFlowGuard._();

  static bool _active = false;

  /// True while the OTP login flow is in progress.
  static bool get isActive => _active;

  /// Call at the start of _handleContinue() in LeadPartnerLoginScreen.
  static void start() => _active = true;

  /// Call just before final navigation in LeadPartnerLoginScreen or
  /// LeadPartnerOtpVerificationScreen.
  static void end() => _active = false;
}
