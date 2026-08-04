import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String userId;
  final bool isResend;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.userId,
    this.isResend = false,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  int _secondsRemaining = 30;
  bool _isResending = false;
  bool _isCheckingVerification = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startVerificationCheck();
    
    // Try to create profile if it doesn't exist
    _ensureProfileExists();
    
    if (widget.isResend) {
      _resendVerification();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      });
    }
  }

  Future<void> _ensureProfileExists() async {
    try {
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();
      
      if (profileResponse == null) {
        // Profile doesn't exist - create it
        print('Profile doesn\'t exist, creating it...');
        await Supabase.instance.client.from('profiles').insert({
          'id': widget.userId,
          'email': widget.email,
          'full_name': 'User',
          'role': 'customer',
          'is_verified': false,
          'verification_sent_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Profile created successfully in verification screen');
      } else {
        print('Profile already exists');
      }
    } catch (e) {
      print('Error ensuring profile exists: $e');
      // Try upsert as fallback
      try {
        await Supabase.instance.client.from('profiles').upsert({
          'id': widget.userId,
          'email': widget.email,
          'full_name': 'User',
          'role': 'customer',
          'is_verified': false,
          'verification_sent_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Profile created via upsert');
      } catch (upsertError) {
        print('Upsert also failed: $upsertError');
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _startVerificationCheck() {
    // Check every 3 seconds if user has verified their email
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isVerified) {
        timer.cancel();
        return;
      }

      try {
        // Refresh the current user session
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final user = session.user;
          if (user.emailConfirmedAt != null) {
            // User has confirmed their email
            await _handleEmailConfirmed();
            timer.cancel();
          }
        }
      } catch (e) {
        // User might not be signed in yet
      }
    });
  }

  Future<void> _handleEmailConfirmed() async {
    setState(() => _isCheckingVerification = true);

    try {
      // First try to update profile
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'is_verified': true,
              'email_confirmed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.userId);
      } catch (e) {
        // If update fails, try upsert
        print('Update failed, trying upsert: $e');
        await Supabase.instance.client.from('profiles').upsert({
          'id': widget.userId,
          'email': widget.email,
          'full_name': 'User',
          'role': 'customer',
          'is_verified': true,
          'email_confirmed_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        _isVerified = true;
        _isCheckingVerification = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Sign out the user so they can login fresh
        await Supabase.instance.client.auth.signOut();
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isCheckingVerification = false);
      print('Error handling email confirmation: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _secondsRemaining = 30;
    });

    try {
      // Try to resend verification
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await Supabase.instance.client.auth.resend(
          email: widget.email,
          type: OtpType.signup,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // If not signed in, try to sign in to trigger resend
        try {
          // This will fail but may trigger a resend
          await Supabase.instance.client.auth.signInWithPassword(
            email: widget.email,
            password: '', // Empty password will trigger resend
          );
        } catch (e) {
          // Expected to fail with invalid credentials, but may have triggered resend
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please check your email for the verification link.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      setState(() => _isResending = false);

      // Restart timer
      if (_timer != null) {
        _timer!.cancel();
      }
      _startTimer();
    } catch (e) {
      setState(() => _isResending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.purple.shade700],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isVerified
                              ? Icons.verified
                              : Icons.email_outlined,
                          size: 60,
                          color: _isVerified ? Colors.green : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isVerified
                            ? 'Email Verified!'
                            : 'Verify Your Email',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isVerified
                            ? 'Redirecting to login...'
                            : 'We sent a verification link to',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!_isVerified) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (!_isVerified) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Please check your email and click the verification link to activate your account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Check spam folder if you don\'t see it',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (!_isVerified) ...[
                        if (_secondsRemaining > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Resend available in ${_secondsRemaining}s',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _secondsRemaining > 0 || _isResending
                                ? null
                                : _resendVerification,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: _secondsRemaining > 0
                                  ? Colors.grey.shade300
                                  : Colors.blue.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isResending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.refresh,
                                    color: _secondsRemaining > 0
                                        ? Colors.grey.shade600
                                        : Colors.white,
                                  ),
                            label: Text(
                              _isResending
                                  ? 'Sending...'
                                  : _secondsRemaining > 0
                                      ? 'Wait ${_secondsRemaining}s'
                                      : 'Resend Verification Email',
                              style: TextStyle(
                                color: _secondsRemaining > 0
                                    ? Colors.grey.shade600
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text('Back to Login'),
                        ),
                      ),
                      if (_isCheckingVerification) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(strokeWidth: 2),
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