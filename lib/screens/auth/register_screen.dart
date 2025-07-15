// ===================================================================
// REGISTER SCREEN SEMPLIFICATA
// File: screens/auth/register_screen.dart
// ===================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:potion_riders/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _nickname = '';
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrazione'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo con icona
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.science,
                          size: 60,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Potion Riders',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea il tuo account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Campo Nickname
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Nickname',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci un nickname';
                        }
                        if (value.length < 3) {
                          return 'Il nickname deve avere almeno 3 caratteri';
                        }
                        return null;
                      },
                      onSaved: (value) => _nickname = value!,
                    ),
                    const SizedBox(height: 16),

                    // Campo Email
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci una email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Inserisci una email valida';
                        }
                        return null;
                      },
                      onSaved: (value) => _email = value!,
                    ),
                    const SizedBox(height: 16),

                    // Campo Password
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci una password';
                        }
                        if (value.length < 6) {
                          return 'La password deve avere almeno 6 caratteri';
                        }
                        return null;
                      },
                      onSaved: (value) => _password = value!,
                    ),
                    const SizedBox(height: 24),

                    // Bottone Registrazione
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: () => _register(authService),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Registrati',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('oppure'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bottone Google
                    _isGoogleLoading
                        ? const Center(child: CircularProgressIndicator())
                        : OutlinedButton.icon(
                      onPressed: () => _registerWithGoogle(authService),
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 36,
                        color: Colors.red,
                      ),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'Registrati con Google',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // SEMPLIFICATA: Non gestisce più la navigazione manualmente
  Future<void> _register(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        await authService.register(_email, _password, _nickname);
        // NAVIGAZIONE AUTOMATICA: AuthWrapper gestirà il flusso

      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Si è verificato un errore durante la registrazione';

        if (e.code == 'weak-password') {
          errorMessage = 'La password fornita è troppo debole';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'L\'account esiste già per questa email';
        } else if (e.code == 'nickname-already-in-use') {
          errorMessage = e.message ?? 'Il nickname è già in uso';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la registrazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // SEMPLIFICATA: Non gestisce più la navigazione manualmente
  Future<void> _registerWithGoogle(AuthService authService) async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await authService.signInWithGoogle();
      // NAVIGAZIONE AUTOMATICA: AuthWrapper gestirà il flusso

      if (result != null) {
        // Messaggio opzionale
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accesso effettuato con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la registrazione con Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGoogleLoading = false);
    }
  }
}