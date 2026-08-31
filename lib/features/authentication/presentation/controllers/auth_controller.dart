import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/authentication/data/repositories/auth_repository.dart';
import 'package:splitterbuddy/features/authentication/domain/models/user_profile.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  User? _currentUser;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  AuthController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository() {
    _init();
  }

  User? get currentUser => _currentUser;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _currentUser != null;
  bool get isAnonymous => _userProfile?.isAnonymous ?? _currentUser?.isAnonymous ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get displayName => _userProfile?.displayName ?? _currentUser?.displayName ?? 'User';
  String get uid => _currentUser?.uid ?? '';

  void _init() {
    _currentUser = _authRepository.currentUser;
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      _currentUser = user;
      if (user != null) {
        _listenToProfile(user.uid);
      } else {
        _profileSubscription?.cancel();
        _userProfile = null;
      }
      notifyListeners();
    });

    if (_currentUser != null) {
      _listenToProfile(_currentUser!.uid);
    }
  }

  void _listenToProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _authRepository.streamUserProfile(uid).listen((profile) {
      _userProfile = profile;
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      _userProfile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );
      _userProfile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInAsGuest({required String displayName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authRepository.signInAnonymously(
        displayName: displayName,
      );
      _userProfile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Guest sign in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateDisplayName(String newName) async {
    if (_currentUser == null) return;
    try {
      await _authRepository.updateDisplayName(_currentUser!.uid, newName);
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.signOut();
      _userProfile = null;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
