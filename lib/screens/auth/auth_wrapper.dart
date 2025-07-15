import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/screens/auth/login_screen.dart';
import 'package:potion_riders/screens/home_screen.dart';

import '../house_selection_screen.dart';
import 'complete_profile_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  bool _hasTriggeredCheck = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading durante verifica auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen('Verificando autenticazione...');
        }

        final user = snapshot.data;

        // Se non è autenticato, mostra login
        if (user == null) {
          _resetState();
          return const LoginScreen();
        }

        // Se è un nuovo login, triggera il check onboarding
        if (_currentUser?.uid != user.uid) {
          _currentUser = user;
          _hasTriggeredCheck = false;

          // Triggera check onboarding per utenti esistenti
          // (per nuovi utenti, il stage è già settato in register/google)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_hasTriggeredCheck) {
              _triggerOnboardingCheck();
            }
          });
        }

        // Usa Consumer per ascoltare i cambi di onboarding stage
        return Consumer<AuthService>(
          builder: (context, authService, child) {
            // Se sta ancora controllando lo status, mostra loading
            if (authService.isCheckingStatus) {
              return _buildLoadingScreen('Preparando il tuo profilo...');
            }

            // Mostra la schermata appropriata basata sullo stage
            return _getScreenForStage(authService);
          },
        );
      },
    );
  }

  void _resetState() {
    _currentUser = null;
    _hasTriggeredCheck = false;
  }

  void _triggerOnboardingCheck() {
    if (_hasTriggeredCheck) return;

    _hasTriggeredCheck = true;
    final authService = Provider.of<AuthService>(context, listen: false);

    // Solo se lo stage è ancora "none", controlla lo status
    if (authService.onboardingStage == OnboardingStage.none) {
      debugPrint('🔍 Triggering onboarding check for existing user');
      authService.checkUserOnboardingStatus();
    }
  }

  Widget _getScreenForStage(AuthService authService) {
    debugPrint('🎯 Current stage: ${authService.onboardingStage}');

    switch (authService.onboardingStage) {
      case OnboardingStage.completeProfile:
        return CompleteProfileScreen(
          initialNickname: authService.pendingUserData?['nickname'] ?? '',
          onProfileCompleted: (String nickname) async {
            try {
              await authService.completeProfile(nickname);
            } catch (e) {
              debugPrint('Error completing profile: $e');
              _showError('Errore durante il completamento del profilo: $e');
            }
          },
        );

      case OnboardingStage.selectHouse:
        return HouseSelectionScreen(
          isNewUser: authService.pendingUserData?['authType'] != 'migration',
          onHouseSelected: (String selectedHouse) async {
            try {
              await authService.completeOnboarding(selectedHouse);
            } catch (e) {
              debugPrint('Error completing onboarding: $e');
              _showError('Errore durante la selezione casata: $e');
            }
          },
        );

      case OnboardingStage.none:
      default:
        return const HomeScreen();
    }
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}