import 'package:eco_step/features/auth/domain/repositories/auth_repository.dart';
import 'package:eco_step/features/profile/domain/entities/profile.dart';
import 'package:eco_step/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final AuthRepository _authRepository;

  ProfileRepositoryImpl(this._authRepository);

  @override
  Future<Profile?> getCurrentProfile() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user == null) return null;

      final ref = FirebaseFirestore.instance.collection('users').doc(user.id);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        await ref.set({
          'uid': user.id,
          'fullName': user.name,
          'photoURL': user.profileImageUrl,
          'points': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      final data = snapshot.data() ?? (await ref.get()).data() ?? {};

      return Profile(
        id: user.id,
        email: user.email,
        name: data['fullName'] as String? ?? user.name,
        profileImageUrl: user.profileImageUrl,
        points: (data['points'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('Get Current Profile Error: $e');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await _authRepository.signOut();
  }
}
