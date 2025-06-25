import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/calendar.events',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
  );

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    // 모바일 플랫폼이 아닌 경우 모의 로그인
    if (!_isMobilePlatform()) {
      print('Google sign-in not supported on this platform');
      return null;
    }
    
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        // 권한 확인
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          print('Google sign-in successful');
          return account;
        }
      }
      return null;
    } catch (error) {
      print('Error signing in with Google: $error');
      return null;
    }
  }

  Future<bool> isSignedIn() async {
    if (!_isMobilePlatform()) {
      return false;
    }
    
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print('Error checking sign-in status: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_isMobilePlatform()) {
      return;
    }
    
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  GoogleSignInAccount? getCurrentUser() {
    if (!_isMobilePlatform()) {
      return null;
    }
    
    try {
      return _googleSignIn.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    final user = getCurrentUser();
    if (user == null) return null;
    
    try {
      return await user.authHeaders;
    } catch (e) {
      print('Failed to get auth headers: $e');
      return null;
    }
  }

  bool _isMobilePlatform() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}
