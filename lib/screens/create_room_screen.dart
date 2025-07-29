import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/screens/room_management_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final String recipeId;

  const CreateRoomScreen({super.key, required this.recipeId});

  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  bool _isCreating = false;
  String? _errorMessage;
  String? _debugInfo;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final roomService = Provider.of<RoomService>(context);
    final dbService = DatabaseService();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea Stanza'),
        elevation: 0,
      ),
      body: StreamBuilder<RecipeModel?>(
        stream: dbService.getRecipe(widget.recipeId).asStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final recipe = snapshot.data;
          if (recipe == null) {
            return _buildRecipeNotFound();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PANNELLO DEBUG (TEMPORANEO)
                if (_debugInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DEBUG INFO:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_debugInfo!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Carta della ricetta
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.purple[100]!, Colors.purple[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_pharmacy,
                                color: Colors.purple[800],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'La tua ricetta:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    recipe.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Descrizione della ricetta
                        if (recipe.description.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Text(
                              recipe.description,
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Messaggio di errore
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Pulsanti per creare la stanza
                Row(
                  children: [
                    // Pulsante normale
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isCreating || uid == null
                            ? null
                            : () => _createRoom(context, uid, recipe, roomService, dbService, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isCreating
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Creazione...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Crea Stanza',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipeNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ricetta non trovata',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La ricetta richiesta non esiste o non è più disponibile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Torna Indietro'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebugOptions(String uid, DatabaseService dbService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync User Rooms'),
              subtitle: const Text('Sincronizza riferimenti stanze'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await dbService.syncUserRooms(uid);
                  setState(() {
                    _debugInfo = 'Sincronizzazione completata';
                  });
                } catch (e) {
                  setState(() {
                    _debugInfo = 'Errore sincronizzazione: $e';
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Check User Status'),
              subtitle: const Text('Verifica stato utente'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final user = await dbService.getUser(uid).first;
                  setState(() {
                    _debugInfo = 'User rooms: ${user?.rooms}\nCan create: ${user?.rooms.isEmpty}';
                  });
                } catch (e) {
                  setState(() {
                    _debugInfo = 'Errore verifica: $e';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom(
      BuildContext context,
      String uid,
      RecipeModel recipe,
      RoomService roomService,
      DatabaseService dbService,
      bool useSimpleMethod,
      ) async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
      _debugInfo = null;
    });

    try {
      String roomId;

      if (useSimpleMethod) {
        setState(() {
          _debugInfo = 'Usando metodo semplificato...';
        });

        // USA IL METODO SEMPLIFICATO PER DEBUG
        roomId = await dbService.createRoomSimple(uid, recipe.id);

        // Aggiungi manualmente alla lista dell'utente
        try {
          await dbService.addRoomToUser(uid, roomId);
          setState(() {
            _debugInfo = 'Stanza creata E aggiunta all\'utente!';
          });
        } catch (e) {
          setState(() {
            _debugInfo = 'Stanza creata ma NON aggiunta all\'utente: $e';
          });
        }
      } else {
        // Verifica prima se l'utente può creare una stanza
        final canCreate = await dbService.canCreateRoom(uid);
        if (!canCreate) {
          setState(() {
            _errorMessage = 'Sei già in una stanza attiva. Completa o abbandona la stanza corrente prima di crearne una nuova.';
          });
          return;
        }

        // USA IL METODO NORMALE
        roomId = await dbService.createRoom(uid, recipe.id);
      }

      // IMPORTANTE: Attendi un momento per assicurarti che la stanza sia sincronizzata
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        // Naviga alla gestione della stanza
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoomManagementScreen(roomId: roomId),
          ),
        );

        // Mostra messaggio di successo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Stanza creata! ID: ${roomId.substring(0, 8)}...'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore nella creazione della stanza: ${e.toString()}';
          _debugInfo = 'Dettagli errore: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}