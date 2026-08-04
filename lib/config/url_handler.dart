import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/email_confirmation_screen.dart';
import '../screens/auth/login_screen.dart';

class URLHandler {
  static Future<void> handleRedirect(BuildContext context) async {
    try {
      // Get the current session
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        final user = session.user;
        
        // Check if email is confirmed
        if (user.emailConfirmedAt != null) {
          // Update profile
          await Supabase.instance.client
              .from('profiles')
              .update({
                'is_verified': true,
                'email_confirmed_at': DateTime.now().toIso8601String(),
              })
              .eq('id', user.id);
          
          // Navigate to confirmation screen
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const EmailConfirmationScreen(),
              ),
            );
          }
        } else {
          // Check again after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              handleRedirect(context);
            }
          });
        }
      } else {
        // No session, navigate to login
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error handling redirect: $e');
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
    }
  }
}