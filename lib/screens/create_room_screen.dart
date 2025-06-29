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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final roomService = Provider.of<RoomService>(context);
    final dbService = DatabaseService();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea Stanza'),
      ),
      body: StreamBuilder<RecipeModel?>(
        stream: dbService.getRecipe(widget.recipeId).asStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final recipe = snapshot.data;
          if (recipe == null) {
            return const Center(child: Text('Ricetta non trovata'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Carta della ricetta
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.science,
                                color: Colors.purple,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      recipe.family,
                                      style: TextStyle(
                                        color: Colors.purple.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (recipe.description.isNotEmpty) ...[
                          Text(
                            recipe.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Ingredienti necessari:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...recipe.requiredIngredients.map((ingredient) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ingredient,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Informazioni sulla creazione
                Card(
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Stai per creare una stanza',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gli altri giocatori potranno unirsi alla tua stanza scansionando '
                              'il QR code o inserendo l\'ID stanza. Avrai bisogno di '
                              '${recipe.requiredIngredients.length} giocatori con gli ingredienti giusti.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Benefici del completamento
                Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Colors.green.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ricompense',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '10',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                Text(
                                  'Punti\n(Host)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.green.shade300,
                            ),
                            Column(
                              children: [
                                Text(
                                  '5',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                Text(
                                  'Punti\n(Ingredienti)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Pulsante di creazione
                _isCreating
                    ? Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Creazione stanza...'),
                      ],
                    ),
                  ),
                )
                    : ElevatedButton.icon(
                  onPressed: uid == null ? null : () => _createRoom(roomService, uid),
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text(
                    'Crea Stanza',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pulsante annulla
                OutlinedButton.icon(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Annulla'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createRoom(RoomService roomService, String uid) async {
    setState(() => _isCreating = true);

    try {
      final roomId = await roomService.createRoom(uid, widget.recipeId);

      if (mounted) {
        // Naviga alla nuova schermata di gestione migliorata
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoomManagementScreen(
              roomId: roomId,
              recipeId: widget.recipeId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la creazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}
