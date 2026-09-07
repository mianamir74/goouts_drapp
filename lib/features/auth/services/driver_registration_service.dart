import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/driver_model.dart';

class DriverRegistrationService {
  final FirebaseFirestore _firestore;

  DriverRegistrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> registerDriver(
    DriverModel driver, {
    String collection = 'drivers',
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection(collection).doc(driver.uid);

    final DocumentSnapshot<Map<String, dynamic>> docSnapshot =
        await docRef.get();

    final Map<String, dynamic> existingData =
        docSnapshot.data() ?? <String, dynamic>{};

    final Map<String, dynamic> registrationData =
        Map<String, dynamic>.from(driver.toFirestore());

    registrationData.remove('createdAt');
    registrationData.remove('updatedAt');

    registrationData['updatedAt'] = FieldValue.serverTimestamp();

    if (!docSnapshot.exists || existingData['createdAt'] == null) {
      registrationData['createdAt'] = FieldValue.serverTimestamp();
    }

    registrationData['password'] = FieldValue.delete();
    registrationData['confirmPassword'] = FieldValue.delete();

    await docRef.set(
      registrationData,
      SetOptions(merge: true),
    );
  }
}