// lib/src/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;

  // GETTERS PÚBLICOS
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _authService.isLoggedIn;
  bool get isAnonymous => _authService.isAnonymous;

  // DATOS DEL USUARIO PARA UI
  String get userName {
    if (!isLoggedIn) return 'Usuario';
    return _user?.displayName ?? _user?.email?.split('@')[0] ?? 'Usuario';
  }

  String get userEmail {
    if (!isLoggedIn) return '';
    return _user?.email ?? '';
  }

  String get userInitials {
    if (!isLoggedIn) return '?';

    final name = _user?.displayName;
    if (name != null && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        return parts[0][0].toUpperCase();
      }
    }

    final email = _user?.email;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    return '?';
  }

  String get userPhotoUrl => _user?.photoURL ?? '';

  AuthProvider() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();

      if (user != null) {
        if (user.isAnonymous) {
        } else {
        }
      }
    });

    _user = _authService.currentUser;
  }

  Future<void> initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final existingUser = _authService.currentUser;

      if (existingUser != null && !existingUser.isAnonymous) {
      } else {
        await _authService.signInAnonymously();
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithApple() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithApple();
      if (result != null) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  /// Obtener color del avatar basado en el usuario
  Color getAvatarColor() {
    if (!isLoggedIn) {
      return Colors.grey.withAlpha(179); // Gris para anónimo
    }

    // Color basado en email para usuarios logueados
    final email = _user?.email ?? '';
    if (email.isNotEmpty) {
      final hash = email.hashCode;
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.red,
        Colors.teal,
        Colors.indigo,
        Colors.pink,
      ];
      return colors[hash.abs() % colors.length];
    }

    return Colors.blue; // Default
  }

  @override
  void dispose() {
    super.dispose();
  }
}