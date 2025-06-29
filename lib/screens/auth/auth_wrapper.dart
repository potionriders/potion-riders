import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/screens/auth/login_screen.dart';
import 'package:potion_riders/screens/auth/complete_profile_screen.dart';
import 'package:potion_riders/screens/home_screen.dart';
import 'package:potion_riders/models/user_model.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final dbService = DatabaseService();

    return StreamBuilder(
      stream: authService.user,
      builder: (_, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final String? userId = snapshot.data;

          if (userId == null) {
            return const LoginScreen();
          }

          // Se l'utente è autenticato, verifica se esiste nel database
          return FutureBuilder<void>(
            future: _waitForUserData(dbService, userId),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Sincronizzazione dati...'),
                      ],
                    ),
                  ),
                );
              }

              if (futureSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Errore: ${futureSnapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            await authService.logout();
                          },
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Ora controlla se è un nuovo utente
              if (authService.isNewUser) {
                // Reset del flag per evitare loop
                authService.resetNewUserFlag();
                return const CompleteProfileScreen();
              }

              // Verifica che l'utente esista effettivamente nel database
              return StreamBuilder<UserModel?>(
                stream: dbService.getUser(userId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Caricamento profilo...'),
                          ],
                        ),
                      ),
                    );
                  }

                  if (userSnapshot.hasError) {
                    return Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Errore caricamento profilo: ${userSnapshot.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                await authService.logout();
                              },
                              child: const Text('Esci e riprova'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final user = userSnapshot.data;
                  if (user == null) {
                    // L'utente non esiste nel database, riporta al completamento profilo
                    return const CompleteProfileScreen();
                  }

                  // Tutto OK, vai alla home
                  return const HomeScreen();
                },
              );
            },
          );
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  // Attende che i dati dell'utente siano disponibili nel database
  Future<void> _waitForUserData(DatabaseService dbService, String userId) async {
    // Attendi un massimo di 10 secondi per la sincronizzazione
    const maxWaitTime = Duration(seconds: 10);
    const checkInterval = Duration(milliseconds: 500);

    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      try {
        final user = await dbService.getUser(userId).first.timeout(
          const Duration(seconds: 2),
        );

        if (user != null) {
          // Utente trovato, esci dal loop
          return;
        }
      } catch (e) {
        // Continua a provare se c'è un errore
        print('Tentativo fallito, riprovo: $e');
      }

      // Attendi prima del prossimo tentativo
      await Future.delayed(checkInterval);
    }

    // Se arriviamo qui, significa che abbiamo aspettato abbastanza
    // Non lanciamo errore, lasciamo che il resto del codice gestisca
  }
}