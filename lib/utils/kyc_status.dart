// ─────────────────────────────────────────────────────────────────────────────
//  The one place that decides what a kycStatus string means.
//
//  Written 25 August 2026.
//
//  ── ⚠ WHY THIS FILE EXISTS ──────────────────────────────────────────────────
//
//  Reported from a device: "once the selfie submit i get the review
//  notification but still on profile page it still shows verify your identity".
//
//  The backend and this app did not agree on a word.
//
//      kycAutoDecision writes ..... 'approved' | 'pending' | 'rejected'
//      markKycSubmitted writes .... 'pending'
//      the consumer app checked ... kycStatus == 'verified'
//
//  So an applicant who was AUTO-APPROVED — the best outcome the system can
//  produce — was told "Verify your identity" for ever, in five separate places,
//  and would sensibly submit the whole thing again. The record said approved;
//  every screen said unverified.
//
//  ⚠ THE HOST APP ALREADY HANDLED BOTH WORDS:
//
//      final approved = kyc == 'approved' || kyc == 'verified';
//
//  One app had the workaround, the other had the bug, and nothing anywhere said
//  which word was canonical. That is the same failure as idFrontUrl /
//  kycIdFrontUrl / identityDocumentUrl, and as isSeed / isDemo — one fact, two
//  names, only some of them maintained.
//
//  ── ⚠ EVERY READER GOES THROUGH HERE. DO NOT COMPARE THE RAW STRING. ────────
//
//  If a sixth screen needs to know whether somebody is verified, it calls
//  kycStatusFrom(). Adding `== 'verified'` anywhere is how this comes back.
//
//  ⚠ AND DO NOT "TIDY UP" BY DROPPING A SYNONYM. Records written before today
//  carry whichever word was in fashion when they were saved. Removing one
//  silently unverifies real people.
// ─────────────────────────────────────────────────────────────────────────────

enum KycStatus {
  /// Never started, or a value nothing recognises.
  ///
  /// ⚠ UNKNOWN IS TREATED AS "NOT STARTED" BY THE SCREENS, and that is the safe
  /// direction: it invites somebody to verify who may already be verified,
  /// which is mildly annoying. The opposite — treating an unknown word as
  /// approved — would hand out verified status on a typo.
  none,

  /// Submitted and waiting. Either an admin, or the auto-decision put it in the
  /// manual band.
  pending,

  /// Verified. 'approved' is what the backend writes today; 'verified' is what
  /// older records carry.
  approved,

  /// Refused. The applicant may submit again.
  rejected,
}

KycStatus kycStatusFrom(Object? raw) {
  final String s = (raw is String ? raw : '').trim().toLowerCase();
  switch (s) {
    case 'approved':
    case 'verified':
    // Seen on some older driver and business records. Harmless to accept and
    // it costs nothing to be generous on the way IN.
    case 'complete':
    case 'completed':
    // ⚠ driver_app / goouts_drapp only — driver_profile_screen has always
    // accepted this. It is in here so routing that screen through this parser
    // does not quietly unverify anybody carrying the word.
    case 'success':
      return KycStatus.approved;

    case 'pending':
    case 'submitted':
    case 'in_review':
    case 'under_review':
      return KycStatus.pending;

    case 'rejected':
    case 'declined':
    case 'failed':
    // ⚠ driver apps only, same reason as 'success' above.
    case 'needs_support':
      return KycStatus.rejected;

    default:
      return KycStatus.none;
  }
}

extension KycStatusX on KycStatus {
  bool get isApproved => this == KycStatus.approved;
  bool get isPending => this == KycStatus.pending;
  bool get isRejected => this == KycStatus.rejected;

  /// Anything that means "do not ask them to verify again right now".
  bool get isSettledOrWaiting =>
      this == KycStatus.approved || this == KycStatus.pending;

  /// What the person should read on a status line.
  String get label => switch (this) {
        KycStatus.approved => 'Identity verified',
        KycStatus.pending => 'Verification in progress',
        KycStatus.rejected => 'Verification unsuccessful',
        KycStatus.none => 'Verify your identity',
      };
}
