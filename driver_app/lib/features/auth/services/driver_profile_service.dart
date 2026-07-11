import 'package:cloud_firestore/cloud_firestore.dart';

class DriverProfileService {
  final FirebaseFirestore _firestore;

  DriverProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<bool> driverProfileExists(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('drivers').doc(uid).get();

    return _isDriverProfileCompleted(doc);
  }

  Stream<bool> driverProfileExistsStream(String uid) {
    return _firestore
        .collection('drivers')
        .doc(uid)
        .snapshots()
        .map(_isDriverProfileCompleted);
  }

  bool _isDriverProfileCompleted(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) {
      return false;
    }

    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return false;
    }

    final bool registrationCompleted = _readBool(
      data,
      const <String>[
        'registrationCompleted',
        'profileCompleted',
        'isProfileCompleted',
      ],
    );

    if (registrationCompleted) {
      return true;
    }

    final String status = _readString(
      data,
      const <String>['status'],
    ).toUpperCase();

    final bool statusLooksComplete =
        status == 'LIVE' || status == 'ACTIVE' || status == 'REGISTERED' || status == 'APPROVED';

    final bool hasName =
        _readString(data, const <String>['fullName']).isNotEmpty ||
        _readString(data, const <String>['firstName']).isNotEmpty ||
        _readString(data, const <String>['surname']).isNotEmpty ||
        _readNestedString(
          data,
          const <String>['personalDetails', 'firstName'],
        ).isNotEmpty ||
        _readNestedString(
          data,
          const <String>['personalDetails', 'surname'],
        ).isNotEmpty;

    final bool hasReferralCode =
        _readString(data, const <String>['referralCode']).isNotEmpty ||
        _readString(data, const <String>['ownReferralCode']).isNotEmpty;

    final bool hasVehicle =
        _readString(data, const <String>['vehicleType']).isNotEmpty ||
        _readNestedString(
          data,
          const <String>['vehicleDetails', 'vehicleType'],
        ).isNotEmpty;

    final bool hasSelfie =
        _readString(
          data,
          const <String>[
            'selfieUrl',
            'selfiePath',
            'selfieImageUrl',
            'profileImageUrl',
          ],
        ).isNotEmpty ||
        _readNestedString(
          data,
          const <String>['identityVerification', 'selfieUrl'],
        ).isNotEmpty;

    final bool hasStrongProfileData =
        (hasName && (hasVehicle || hasSelfie || hasReferralCode)) ||
        (statusLooksComplete && (hasName || hasVehicle || hasReferralCode));

    return hasStrongProfileData;
  }

  bool _readBool(
    Map<String, dynamic> data,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is bool) {
        return value;
      }

      if (value is num) {
        return value != 0;
      }

      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized == 'true') {
          return true;
        }
        if (normalized == 'false') {
          return false;
        }
      }
    }

    return fallback;
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value == null) {
        continue;
      }

      final String text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  String _readNestedString(
    Map<String, dynamic> data,
    List<String> path, {
    String fallback = '',
  }) {
    dynamic current = data;

    for (final String key in path) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return fallback;
      }
    }

    if (current == null) {
      return fallback;
    }

    final String text = current.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}