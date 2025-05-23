import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/screens/coaster_selection_screen.dart';

class ClaimCoasterByIdScreen extends StatefulWidget {
  const ClaimCoasterByIdScreen({super.key});

  @override
  _ClaimCoasterByIdScreenState createState() => _ClaimCoasterByIdScreenState();
}

class _ClaimCoasterByIdScreenState extends State<ClaimCoasterByIdScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _idController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclama Sottobicchiere'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.tab,
                size: 64,
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Inserisci ID Sottobicchiere',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Inserisci l\'ID del sottobicchiere che hai ricevuto',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Campo input ID
              TextFormField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: 'ID Sottobicchiere',
                  hintText: 'Es: abc123def456',
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci un ID';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 24),

              // Pulsante reclama
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: uid == null ? null : () => _claimCoaster(context, uid),
                icon: const Icon(Icons.check_circle),
                label: const Text('Reclama Sottobicchiere'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Pulsante alternativo per scan QR
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/scan');
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scansiona QR Code invece'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              // Messaggi di errore/successo
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claimCoaster(BuildContext context, String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final coasterId = _idController.text.trim().toUpperCase(); // Convertiamo in maiuscolo per uniformità

      // Verifica se il sottobicchiere esiste
      final coaster = await _dbService.getCoaster(coasterId);

      if (coaster == null) {
        setState(() {
          _errorMessage = 'Sottobicchiere non trovato. Verifica l\'ID inserito.';
          _isLoading = false;
        });
        return;
      }

      // Verifica se è già stato reclamato
      if (coaster.claimedByUserId != null && coaster.claimedByUserId != uid) {
        setState(() {
          _errorMessage = 'Questo sottobicchiere è già stato reclamato da un altro giocatore.';
          _isLoading = false;
        });
        return;
      }

      // Verifica se l'utente l'ha già reclamato
      if (coaster.claimedByUserId == uid) {
        // L'utente l'ha già reclamato, vai alla selezione
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoasterSelectionScreen(
              coasterId: coasterId,
              recipeId: coaster.recipeId,
              ingredientId: coaster.ingredientId,
            ),
          ),
        );
        return;
      }

      // Reclama il sottobicchiere
      final success = await _dbService.claimCoaster(coasterId, uid);

      if (success) {
        setState(() {
          _successMessage = 'Sottobicchiere reclamato con successo!';
          _isLoading = false;
        });

        // Breve pausa per mostrare il messaggio
        await Future.delayed(const Duration(seconds: 1));

        // Naviga alla schermata di selezione
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoasterSelectionScreen(
              coasterId: coasterId,
              recipeId: coaster.recipeId,
              ingredientId: coaster.ingredientId,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Impossibile reclamare il sottobicchiere. Riprova.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore: $e';
        _isLoading = false;
      });
    }
  }
}