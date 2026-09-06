import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String uid;
  final String phoneNumber;
  final String prefix;
  final String firstName;
  final String middleName;
  final String surname;
  final String birthMonth;
  final String birthYear;
  final int age;
  final String email;
  final String country;
  final String houseNoOrName;
  final String streetName;
  final String town;
  final String city;
  final String postcode;
  final String vehicleType;
  final String drivingLicenceNumber;
  final bool registrationCompleted;
  final String status;
  final bool termsAccepted;
  final String referralCodeUsed;
  final String ownReferralCode;
  final String profilePhotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverModel({
    required this.uid,
    required this.phoneNumber,
    required this.prefix,
    required this.firstName,
    required this.middleName,
    required this.surname,
    required this.birthMonth,
    required this.birthYear,
    required this.age,
    required this.email,
    required this.country,
    required this.houseNoOrName,
    required this.streetName,
    required this.town,
    required this.city,
    required this.postcode,
    required this.vehicleType,
    required this.drivingLicenceNumber,
    required this.registrationCompleted,
    required this.status,
    required this.termsAccepted,
    required this.referralCodeUsed,
    required this.ownReferralCode,
    required this.profilePhotoUrl,
    this.createdAt,
    this.updatedAt,
  });

  String get fullName {
    final parts = <String>[
      firstName.trim(),
      middleName.trim(),
      surname.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.join(' ').trim();
  }

  String get phone => phoneNumber.trim();

  String get referralCode {
    final code = ownReferralCode.trim().toUpperCase();
    if (code.isNotEmpty) return code;
    return _generateReferralCode(uid);
  }

  String get selfieUrl => profilePhotoUrl.trim();

  DriverModel copyWith({
    String? uid,
    String? phoneNumber,
    String? prefix,
    String? firstName,
    String? middleName,
    String? surname,
    String? birthMonth,
    String? birthYear,
    int? age,
    String? email,
    String? country,
    String? houseNoOrName,
    String? streetName,
    String? town,
    String? city,
    String? postcode,
    String? vehicleType,
    String? drivingLicenceNumber,
    bool? registrationCompleted,
    String? status,
    bool? termsAccepted,
    String? referralCodeUsed,
    String? ownReferralCode,
    String? profilePhotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      prefix: prefix ?? this.prefix,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      surname: surname ?? this.surname,
      birthMonth: birthMonth ?? this.birthMonth,
      birthYear: birthYear ?? this.birthYear,
      age: age ?? this.age,
      email: email ?? this.email,
      country: country ?? this.country,
      houseNoOrName: houseNoOrName ?? this.houseNoOrName,
      streetName: streetName ?? this.streetName,
      town: town ?? this.town,
      city: city ?? this.city,
      postcode: postcode ?? this.postcode,
      vehicleType: vehicleType ?? this.vehicleType,
      drivingLicenceNumber:
          drivingLicenceNumber ?? this.drivingLicenceNumber,
      registrationCompleted:
          registrationCompleted ?? this.registrationCompleted,
      status: status ?? this.status,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      referralCodeUsed: referralCodeUsed ?? this.referralCodeUsed,
      ownReferralCode: ownReferralCode ?? this.ownReferralCode,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final safeReferralCode = referralCode;
    final now = Timestamp.now();

    return <String, dynamic>{
      // Clean flat fields for all new screens
      'uid': uid.trim(),
      'fullName': fullName.toUpperCase(),
      'phone': phoneNumber.trim(),
      'phoneNumber': phoneNumber.trim(),
      'prefix': prefix.trim().toUpperCase(),
      'firstName': firstName.trim().toUpperCase(),
      'middleName': middleName.trim().toUpperCase(),
      'surname': surname.trim().toUpperCase(),
      'birthMonth': birthMonth.trim().toUpperCase(),
      'birthYear': birthYear.trim(),
      'age': age,
      'email': email.trim().toLowerCase(),
      'country': country.trim().toUpperCase(),
      'houseNoOrName': houseNoOrName.trim().toUpperCase(),
      'streetName': streetName.trim().toUpperCase(),
      'town': town.trim().toUpperCase(),
      'city': city.trim().toUpperCase(),
      'postcode': postcode.trim().toUpperCase(),
      'vehicleType': vehicleType.trim().toUpperCase(),
      'drivingLicenceNumber':
          drivingLicenceNumber.trim().toUpperCase(),
      'registrationCompleted': registrationCompleted,
      'status': status.trim().toUpperCase().isEmpty
          ? 'PENDING'
          : status.trim().toUpperCase(),
      'termsAccepted': termsAccepted,
      'referralCodeUsed': referralCodeUsed.trim().toUpperCase(),
      'referralCode': safeReferralCode,
      'ownReferralCode': safeReferralCode,
      'selfieUrl': profilePhotoUrl.trim(),
      'profilePhotoUrl': profilePhotoUrl.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : now,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : now,

      // Legacy/nested fields kept for backward compatibility
      'personalDetails': <String, dynamic>{
        'prefix': prefix.trim().toUpperCase(),
        'firstName': firstName.trim().toUpperCase(),
        'middleName': middleName.trim().toUpperCase(),
        'surname': surname.trim().toUpperCase(),
        'birthMonth': birthMonth.trim().toUpperCase(),
        'birthYear': birthYear.trim(),
        'age': age,
      },
      'contactDetails': <String, dynamic>{
        'phoneNumber': phoneNumber.trim(),
        'email': email.trim().toLowerCase(),
        'country': country.trim().toUpperCase(),
      },
      'address': <String, dynamic>{
        'houseNoOrName': houseNoOrName.trim().toUpperCase(),
        'streetName': streetName.trim().toUpperCase(),
        'town': town.trim().toUpperCase(),
        'city': city.trim().toUpperCase(),
        'postcode': postcode.trim().toUpperCase(),
      },
      'vehicleDetails': <String, dynamic>{
        'vehicleType': vehicleType.trim().toUpperCase(),
        'drivingLicenceNumber':
            drivingLicenceNumber.trim().toUpperCase(),
      },
      'accountStatus': <String, dynamic>{
        'registrationCompleted': registrationCompleted,
        'status': status.trim().toUpperCase().isEmpty
            ? 'PENDING'
            : status.trim().toUpperCase(),
      },
      'termsAndConditions': <String, dynamic>{
        'accepted': termsAccepted,
      },
      'referralDetails': <String, dynamic>{
        'usedReferralCode': referralCodeUsed.trim().toUpperCase(),
        'ownReferralCode': safeReferralCode,
      },
      'profileImage': <String, dynamic>{
        'photoUrl': profilePhotoUrl.trim(),
      },
    };
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    final String uid = _readString(
      map,
      <String>['uid'],
    );

    final String firstName = _readString(
      map,
      <String>['firstName', 'personalDetails.firstName'],
    );

    final String middleName = _readString(
      map,
      <String>['middleName', 'personalDetails.middleName'],
    );

    final String surname = _readString(
      map,
      <String>['surname', 'lastName', 'personalDetails.surname'],
    );

    final String ownReferralCode = _firstNonEmpty(<String>[
      _readString(map, <String>[
        'ownReferralCode',
        'referralCode',
        'referralDetails.ownReferralCode',
      ]).toUpperCase(),
      _generateReferralCode(uid),
    ]);

    return DriverModel(
      uid: uid,
      phoneNumber: _readString(
        map,
        <String>[
          'phone',
          'phoneNumber',
          'contactDetails.phoneNumber',
        ],
      ),
      prefix: _readString(
        map,
        <String>['prefix', 'personalDetails.prefix'],
      ),
      firstName: firstName,
      middleName: middleName,
      surname: surname,
      birthMonth: _readString(
        map,
        <String>['birthMonth', 'personalDetails.birthMonth'],
      ),
      birthYear: _readString(
        map,
        <String>['birthYear', 'personalDetails.birthYear'],
      ),
      age: _readInt(
        map,
        <String>['age', 'personalDetails.age'],
      ),
      email: _readString(
        map,
        <String>['email', 'contactDetails.email'],
      ),
      country: _readString(
        map,
        <String>['country', 'contactDetails.country'],
      ),
      houseNoOrName: _readString(
        map,
        <String>['houseNoOrName', 'address.houseNoOrName'],
      ),
      streetName: _readString(
        map,
        <String>['streetName', 'address.streetName'],
      ),
      town: _readString(
        map,
        <String>['town', 'address.town'],
      ),
      city: _readString(
        map,
        <String>['city', 'address.city'],
      ),
      postcode: _readString(
        map,
        <String>['postcode', 'address.postcode'],
      ),
      vehicleType: _readString(
        map,
        <String>['vehicleType', 'vehicleDetails.vehicleType'],
      ),
      drivingLicenceNumber: _readString(
        map,
        <String>[
          'drivingLicenceNumber',
          'vehicleDetails.drivingLicenceNumber',
        ],
      ),
      registrationCompleted: _readBool(
        map,
        <String>[
          'registrationCompleted',
          'accountStatus.registrationCompleted',
        ],
      ),
      status: _firstNonEmpty(<String>[
        _readString(map, <String>[
          'status',
          'accountStatus.status',
          'driverStatus',
          'accountStatusValue',
        ]),
        'PENDING',
      ]).toUpperCase(),
      termsAccepted: _readBool(
        map,
        <String>[
          'termsAccepted',
          'termsAndConditions.accepted',
        ],
      ),
      referralCodeUsed: _readString(
        map,
        <String>[
          'referralCodeUsed',
          'usedReferralCode',
          'referralDetails.usedReferralCode',
        ],
      ).toUpperCase(),
      ownReferralCode: ownReferralCode,
      profilePhotoUrl: _readString(
        map,
        <String>[
          'selfieUrl',
          'profilePhotoUrl',
          'photoUrl',
          'profileImageUrl',
          'profileImage.photoUrl',
        ],
      ),
      createdAt: _readDateTime(
        map,
        <String>['createdAt'],
      ),
      updatedAt: _readDateTime(
        map,
        <String>['updatedAt'],
      ),
    );
  }

  factory DriverModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return DriverModel.fromMap(<String, dynamic>{
      'uid': doc.id,
      ...data,
    });
  }

  static String _readString(
    Map<String, dynamic> map,
    List<String> paths,
  ) {
    for (final path in paths) {
      final value = _getNestedValue(map, path);
      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static int _readInt(
    Map<String, dynamic> map,
    List<String> paths,
  ) {
    for (final path in paths) {
      final value = _getNestedValue(map, path);
      if (value == null) continue;

      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  static bool _readBool(
    Map<String, dynamic> map,
    List<String> paths,
  ) {
    for (final path in paths) {
      final value = _getNestedValue(map, path);
      if (value == null) continue;

      if (value is bool) return value;

      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }

      if (value is num) {
        return value != 0;
      }
    }
    return false;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> map,
    List<String> paths,
  ) {
    for (final path in paths) {
      final value = _getNestedValue(map, path);
      if (value == null) continue;

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    }
    return null;
  }

  static dynamic _getNestedValue(
    Map<String, dynamic> map,
    String path,
  ) {
    final keys = path.split('.');
    dynamic current = map;

    for (final key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }

    return current;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static String _generateReferralCode(String uid) {
    final cleanUid = uid.trim().replaceAll('-', '').toUpperCase();

    if (cleanUid.isEmpty) {
      return 'GO1001';
    }

    final base = cleanUid.length >= 6
        ? cleanUid.substring(cleanUid.length - 6)
        : cleanUid.padLeft(6, '0');

    return 'GO$base';
  }
}