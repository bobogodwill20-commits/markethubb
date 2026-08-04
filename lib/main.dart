import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/terms_conditions.dart';
import 'screens/auth/email_confirmation_screen.dart';
import 'config/supabase.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/main/main_page.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  
  print('🚀 App starting...');
  print('📦 Initializing storage...');
  
  // Initialize storage bucket with proper error handling
  try {
    await StorageService.initializeBucket();
  } catch (e) {
    print('⚠️ Storage initialization error: $e');
    print('📌 Storage features will work once bucket is properly configured.');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'MarketHub',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainPage(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/confirm-email': (context) => const EmailConfirmationScreen(),
              '/terms': (context) => const TermsConditionsScreen(),
            },
          );
        },
      ),
    );
  }
}