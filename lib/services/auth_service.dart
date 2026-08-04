import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userProfile;
  final bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  AuthService() {
    _init();
  }

  void _init() {
    _user = Supabase.instance.client.auth.currentUser;
    if (_user != null) {
      _loadUserProfile();
    }
    
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _loadUserProfile();
      } else {
        _userProfile = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', _user!.id)
        .single();
    
    _userProfile = response;
    notifyListeners();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _user = null;
    _userProfile = null;
    notifyListeners();
  }

  bool get isAdmin => _userProfile?['role'] == 'admin';
  bool get isSeller => _userProfile?['role'] == 'seller';
  bool get isCustomer => _userProfile?['role'] == 'customer';
  bool get isVerified => _userProfile?['is_verified'] ?? false;
}