import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/qr_service.dart';
import 'package:potion_riders/models/recipe_model.dart';

class CreateRoomScreen extends StatefulWidget {
  final String recipeId;

  const CreateRoomScreen({super.key, required this.recipeId});

  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  String? _roomId;
  String? _qrData;
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
            child: _roomId == null
                ? _buildCreateRoomForm(context, recipe, roomService, uid)
                : _buildRoomCreatedContent(context, recipe, roomService),
          );
        },
      ),
    );
  }

  Widget _buildCreateRoomForm(
    BuildContext context,
    RecipeModel recipe,
    RoomService roomService,
    String? uid,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                Text(
                  'Pozione:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingredienti necessari:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                ...recipe.requiredIngredients.map((ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(ingredient),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Crea una stanza per preparare questa pozione',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        Text(
          'Gli altri giocatori potranno unirsi scansionando il QR code',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _isCreating
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                onPressed:
                    uid == null ? null : () => _createRoom(roomService, uid),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Crea Stanza'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
      ],
    );
  }

  Widget _buildRoomCreatedContent(
    BuildContext context,
    RecipeModel recipe,
    RoomService roomService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Stanza creata con successo!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Condividi questo QR code con gli altri giocatori che hanno gli ingredienti necessari.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ID Stanza:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _roomId ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _roomId ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID Stanza copiato')),
                          );
                        },
                        tooltip: 'Copia ID',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _qrData == null
                    ? const SizedBox(
                        height: 250,
                        width: 250,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : QrService.generateQrCode(_qrData!, size: 250),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Istruzioni',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionStep(
                  context,
                  '1',
                  'Mostra il QR code ai giocatori con gli ingredienti richiesti',
                ),
                _buildInstructionStep(
                  context,
                  '2',
                  'Chiedi loro di scansionare il codice con la loro app',
                ),
                _buildInstructionStep(
                  context,
                  '3',
                  'Quando tutti si sono uniti, conferma la tua partecipazione',
                ),
                _buildInstructionStep(
                  context,
                  '4',
                  'Una volta che tutti hanno confermato, la pozione sarà completata automaticamente!',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(
      BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom(RoomService roomService, String uid) async {
    setState(() => _isCreating = true);

    try {
      final roomId = await roomService.createRoom(uid, widget.recipeId);

      setState(() {
        _roomId = roomId;
        _qrData = roomService.generateQrData(roomId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la creazione: $e')),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }
}
