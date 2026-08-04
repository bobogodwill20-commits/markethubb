import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'login_screen.dart';

class EmailConfirmationScreen extends StatefulWidget {
  const EmailConfirmationScreen({super.key});

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String _message = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkEmailConfirmation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailConfirmation() async {
    try {
      // Get the current session
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        final user = session.user;
        
        // Check if email is confirmed
        if (user.emailConfirmedAt != null) {
          // Email is confirmed
          setState(() {
            _isLoading = false;
            _isSuccess = true;
            _message = 'Your email has been successfully verified! 🎉';
          });
          
          // Update profile in database
          await _updateProfileVerified(user.id);
          
          // Auto navigate after 3 seconds
          _timer = Timer(const Duration(seconds: 3), () {
            _navigateToLogin();
          });
        } else {
          // Email not confirmed yet - check again in 2 seconds
          setState(() {
            _isLoading = true;
            _message = 'Waiting for email confirmation...';
          });
          
          // Retry after 2 seconds
          _timer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _checkEmailConfirmation();
            }
          });
        }
      } else {
        // No session - user needs to login
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _message = 'Please login to confirm your email.';
        });
        
        _timer = Timer(const Duration(seconds: 2), () {
          _navigateToLogin();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _updateProfileVerified(String userId) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_verified': true,
            'email_confirmed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      print('✅ Profile updated successfully!');
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.blue.shade900, Colors.purple.shade900]
                : [Colors.blue.shade600, Colors.purple.shade700],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isSuccess 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const SpinKitFadingCircle(
                                color: Colors.blue,
                                size: 50,
                              )
                            : Icon(
                                _isSuccess 
                                    ? Icons.verified
                                    : Icons.error_outline,
                                size: 60,
                                color: _isSuccess ? Colors.green : Colors.red,
                              ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        _isLoading 
                            ? 'Verifying Email...'
                            : _isSuccess 
                                ? 'Email Verified! 🎉'
                                : 'Verification Failed',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      // Message
                      Text(
                        _message,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      if (_isSuccess) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your account is now active! Redirecting to login...',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (!_isLoading && !_isSuccess) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _navigateToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Go to Login'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}