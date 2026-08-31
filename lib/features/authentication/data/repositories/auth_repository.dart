import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/authentication/domain/models/user_profile.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw AuthException('Failed to fetch user profile: ${e.toString()}');
    }
  }

  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Account creation failed.');
      }

      await user.updateDisplayName(displayName.trim());

      final userProfile = UserProfile(
        uid: user.uid,
        displayName: displayName.trim(),
        email: email.trim(),
        workspaceIds: const [],
        isAnonymous: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(userProfile.toMap(), SetOptions(merge: true));

      return userProfile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code), e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign up failed: ${e.toString()}');
    }
  }

  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Sign in failed.');
      }

      var profile = await getUserProfile(user.uid);
      if (profile == null) {
        // Create initial profile if missing
        profile = UserProfile(
          uid: user.uid,
          displayName: user.displayName ?? email.split('@').first,
          email: user.email ?? email,
          workspaceIds: const [],
          isAnonymous: false,
          createdAt: DateTime.now(),
        );
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(profile.toMap(), SetOptions(merge: true));
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code), e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  Future<UserProfile> signInAnonymously({
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Guest sign in failed.');
      }

      final trimmedName = displayName.trim().isEmpty ? 'Guest User' : displayName.trim();
      await user.updateDisplayName(trimmedName);

      final userProfile = UserProfile(
        uid: user.uid,
        displayName: trimmedName,
        email: 'guest_${user.uid.substring(0, 6)}@splitterbud.local',
        workspaceIds: const [],
        isAnonymous: true,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(userProfile.toMap(), SetOptions(merge: true));

      return userProfile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code), e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Guest sign in failed: ${e.toString()}');
    }
  }

  Future<void> updateDisplayName(String uid, String newName) async {
    try {
      final trimmed = newName.trim();
      if (trimmed.isEmpty) throw const AuthException('Name cannot be empty');

      await _firebaseAuth.currentUser?.updateDisplayName(trimmed);
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({'displayName': trimmed});
    } catch (e) {
      throw AuthException('Failed to update name: ${e.toString()}');
    }
  }

  Future<void> addWorkspaceToUser(String uid, String workspaceId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'workspaceIds': FieldValue.arrayUnion([workspaceId]),
      });
    } catch (e) {
      // Ignored or logged if user doc isn't yet created
    }
  }

  Future<void> removeWorkspaceFromUser(String uid, String workspaceId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'workspaceIds': FieldValue.arrayRemove([workspaceId]),
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'operation-not-allowed':
        return 'This sign-in method is currently disabled.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}
