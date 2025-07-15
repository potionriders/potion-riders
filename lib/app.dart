import 'package:flutter/material.dart';
import 'package:potion_riders/screens/admin_screen.dart';
import 'package:potion_riders/screens/auth/auth_wrapper.dart';
import 'package:potion_riders/screens/scan_item_screen.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/screens/auth/login_screen.dart';
import 'package:potion_riders/screens/auth/complete_profile_screen.dart';
import 'package:potion_riders/screens/home_screen.dart';

class PotionRidersApp extends StatelessWidget {
  const PotionRidersApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Aggiungi altri provider se necessario
        // ChangeNotifierProvider(create: (_) => RoomService()),
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
        // USA AuthWrapper come home - gestirà tutto il routing automaticamente
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,

        // Routes opzionali per navigazione diretta (per debug o casi speciali)
        routes: {
          '/auth': (context) => const AuthWrapper(),
          '/complete-profile': (context) => const CompleteProfileScreen(),
          '/home': (context) => const HomeScreen(),
          '/scan': (context) => const ScanItemScreen(),
          '/admin': (context) => const AdminScreen(),
        },
      ),
    );
  }
}