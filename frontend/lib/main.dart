// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'widgets/main_container.dart';
import 'api_service/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the API service
  await BankingApiService().init();
  
  runApp(const GPayCloneApp());
}

class GPayCloneApp extends StatelessWidget {
  const GPayCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPay Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: GoogleFonts.poppins(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // Give a brief moment for splash effect
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Check if user is logged in
    final isLoggedIn = BankingApiService().isLoggedIn;
    
    if (isLoggedIn) {
      // User is logged in, navigate directly to dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainContainer()),
        );
      }
    } else {
      // User is not logged in, go to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payment,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}