import 'package:flutter/material.dart';
import 'package:potion_riders/screens/admin_screen.dart';
import 'package:potion_riders/screens/scan_item_screen.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/screens/auth/login_screen.dart';
import 'package:potion_riders/screens/auth/complete_profile_screen.dart';
import 'package:potion_riders/screens/home_screen.dart';

class PotionRidersApp extends StatelessWidget {
  const PotionRidersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RoomService()),
      ],
      child: MaterialApp(
        title: 'Potion Riders',
        theme: ThemeData(
          primarySwatch: Colors.purple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Montserrat',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/auth': (context) => const AuthWrapper(),
          '/complete-profile': (context) => const CompleteProfileScreen(),
          '/home': (context) => const HomeScreen(),
          '/scan': (context) => const ScanItemScreen(),
          '/admin': (context) => const AdminScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder(
      stream: authService.user,
      builder: (_, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final String? userId = snapshot.data;

          if (userId == null) {
            return const LoginScreen();
          }

          // Se l'utente è nuovo e ha bisogno di completare il profilo
          if (authService.isNewUser) {
            // Reset del flag per evitare loop
            authService.resetNewUserFlag();
            // Reindirizza alla schermata di completamento profilo
            return const CompleteProfileScreen();
          }

          // Altrimenti, vai alla home
          return const HomeScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}