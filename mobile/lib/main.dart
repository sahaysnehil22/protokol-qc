import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'data/api_client.dart';
import 'data/sync_manager.dart';
import 'models/models.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API and Sync Manager
  await ApiClient.instance.init();
  await SyncManager.instance.init();

  // Check persisted user session
  User? initialUser;
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('current_user');
  if (userJson != null) {
    try {
      initialUser = User.fromJson(jsonDecode(userJson));
    } catch (_) {}
  }

  runApp(ProtokolApp(initialUser: initialUser));
}

class ProtokolApp extends StatelessWidget {
  final User? initialUser;

  const ProtokolApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textMain,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: initialUser != null
          ? HomeScreen(currentUser: initialUser!)
          : const LoginScreen(),
    );
  }
}
