import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import '../services/cloud_service.dart';
import '../services/sync_service.dart';

/// Who is logged in. Persists the session so students stay logged in
/// between launches until they log out.
class SessionState extends ChangeNotifier {
  SessionState(this._auth, {CloudService? cloud, SyncService? sync})
      : _cloud = cloud ?? CloudService.instance,
        _sync = sync;

  final AuthRepository _auth;
  final CloudService _cloud;
  final SyncService? _sync;
  static const _key = 'pennypal_session_user';

  AppUser? user;
  UserProfile? profile;
  bool restoring = true;

  bool get isLoggedIn => user != null;
  String get currency => profile?.currency ?? 'USD';

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_key);
      if (id != null) {
        final u = await _auth.findById(id);
        if (u != null && u.isActive) {
          user = u;
          profile = await _auth.profileFor(u.id);
          _sync?.setUser(u.id, isAdmin: u.isAdmin);
        } else {
          await prefs.remove(_key);
        }
      }
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final u = await _auth.login(email, password);
    await _start(u);
    _cloudSignIn(u.email, password);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    String? studentStatus,
  }) async {
    final u = await _auth.register(
        fullName: fullName,
        email: email,
        mobile: mobile,
        password: password,
        studentStatus: studentStatus);
    await _start(u);
    _cloudSignIn(u.email, password);
  }

  /// Cloud sign-in is best effort and never blocks offline use; queued
  /// changes are pushed as soon as it succeeds.
  void _cloudSignIn(String email, String password) {
    _cloud.signIn(email, password).then((_) => _sync?.syncNow());
  }

  Future<void> _start(AppUser u) async {
    user = u;
    profile = await _auth.profileFor(u.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, u.id);
    _sync?.setUser(u.id, isAdmin: u.isAdmin);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _cloud.signOut();
    _sync?.setUser(null);
    user = null;
    profile = null;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    await _auth.saveProfile(p);
    profile = p;
    notifyListeners();
  }

  Future<void> updateDetails(String fullName, String mobile) async {
    await _auth.updateUserDetails(user!.id, fullName: fullName, mobile: mobile);
    user = await _auth.findById(user!.id);
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) =>
      _auth.changePassword(user!.id, current, next);
}
