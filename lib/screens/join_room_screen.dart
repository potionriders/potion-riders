import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/services/qr_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/user_model.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  bool _isScanning = false;
  String? _scannedRoomId;
  bool _isJoining = false;
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final roomService = Provider.of<RoomService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unisciti a una Stanza'),
      ),
      body: _isScanning
          ? _buildQrScanner(context, roomService)
          : _scannedRoomId != null
              ? _buildRoomPreview(context, _scannedRoomId!, uid, roomService)
              : _buildJoinForm(context, uid),
    );
  }

  Widget _buildJoinForm(BuildContext context, String? uid) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.meeting_room,
            size: 64,
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Unisciti a una stanza',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Inserisci l\'ID della stanza o scansiona il QR code',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _roomIdController,
            decoration: InputDecoration(
              labelText: 'ID Stanza',
              hintText: 'Inserisci l\'ID della stanza',
              prefixIcon: const Icon(Icons.vpn_key),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: uid == null || _roomIdController.text.isEmpty
                ? null
                : () {
                    setState(() {
                      _scannedRoomId = _roomIdController.text;
                    });
                  },
            icon: const Icon(Icons.login),
            label: const Text('Unisciti'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _isScanning = true);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scansiona QR code'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrScanner(BuildContext context, RoomService roomService) {
    return Column(
      children: [
        Expanded(
          child: QrService.qrScanner((data) {
            final Map<String, dynamic>? roomData =
                roomService.parseQrData(data);
            if (roomData != null) {
              setState(() {
                _isScanning = false;
                _scannedRoomId = roomData['roomId'];
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR code non valido')),
              );
            }
          }),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Inquadra il QR code della stanza',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isScanning = false);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Indietro'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomPreview(
    BuildContext context,
    String roomId,
    String? uid,
    RoomService roomService,
  ) {
    return StreamBuilder<RoomModel?>(
      stream: _dbService.getRoom(roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final room = snapshot.data;
        if (room == null) {
          return _buildRoomNotFound(context);
        }

        // Controlla se l'utente è già nella stanza
        bool isHost = room.hostId == uid;
        bool isParticipant = room.participants.any((p) => p.userId == uid);
        bool hasConfirmed = isParticipant &&
            room.participants.firstWhere((p) => p.userId == uid).hasConfirmed;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoomStatusCard(context, room),
              const SizedBox(height: 16),
              FutureBuilder<RecipeModel?>(
                future: _dbService.getRecipe(room.recipeId),
                builder: (context, recipeSnapshot) {
                  final recipe = recipeSnapshot.data;
                  return _buildRecipeCard(context, recipe);
                },
              ),
              const SizedBox(height: 16),
              _buildParticipantsCard(context, room, uid),
              const SizedBox(height: 24),

              // Azioni disponibili in base allo stato dell'utente
              if (room.isCompleted)
                _buildCompletedCard(context)
              else if (isHost || isParticipant)
                _buildMemberActions(
                    context, room, uid!, isHost, hasConfirmed, roomService)
              else
                _buildJoinActions(context, room, uid!, roomService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoomNotFound(BuildContext context) {
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
              'Stanza non trovata',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La stanza richiesta non esiste o è stata chiusa',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _scannedRoomId = null);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Indietro'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomStatusCard(BuildContext context, RoomModel room) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  room.isCompleted ? Icons.check_circle : Icons.pending,
                  color: room.isCompleted ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Stanza ${room.isCompleted ? 'completata' : 'in corso'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: room.isCompleted ? Colors.green : Colors.orange,
                  ),
                ),
                const Spacer(),
                room.isCompleted
                    ? Chip(
                        label: const Text('Completa'),
                        backgroundColor: Colors.green.shade100,
                        labelStyle: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Chip(
                        label: Text('${room.participants.length}/3'),
                        backgroundColor: room.participants.length >= 3
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        labelStyle: TextStyle(
                          color: room.participants.length >= 3
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ID Stanza:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${room.id.substring(0, 8)}...',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Creata il:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDateTime(room.createdAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, RecipeModel? recipe) {
    if (recipe == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('Caricamento ricetta...'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pozione',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
            const SizedBox(height: 8),
            Text(
              recipe.description,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ingredienti richiesti:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...recipe.requiredIngredients.map((ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
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
    );
  }

  Widget _buildParticipantsCard(
      BuildContext context, RoomModel room, String? uid) {
    return Card(
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
              'Partecipanti',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Host (con la ricetta)
            StreamBuilder<UserModel?>(
              stream: _dbService.getUser(room.hostId),
              builder: (context, snapshot) {
                final String name = snapshot.data?.nickname ?? 'Giocatore';
                final bool isCurrentUser = room.hostId == uid;

                return _buildParticipantTile(
                  context: context,
                  name: name + (isCurrentUser ? ' (Tu)' : ''),
                  role: 'Pozione',
                  hasConfirmed: true, // L'host è sempre confermato
                  isCurrentUser: isCurrentUser,
                );
              },
            ),
            const SizedBox(height: 8),
            // Partecipanti (con ingredienti)
            if (room.participants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Nessun partecipante si è ancora unito',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              ...room.participants
                  .map((participant) => FutureBuilder<UserModel?>(
                        future: _dbService.getUser(participant.userId).first,
                        builder: (context, snapshot) {
                          final String name =
                              snapshot.data?.nickname ?? 'Giocatore';
                          final bool isCurrentUser = participant.userId == uid;

                          return Column(
                            children: [
                              _buildParticipantTile(
                                context: context,
                                name: name + (isCurrentUser ? ' (Tu)' : ''),
                                role: 'Ingrediente',
                                hasConfirmed: participant.hasConfirmed,
                                isCurrentUser: isCurrentUser,
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      )),

            // Mostra slot disponibili rimanenti
            if (room.participants.length < 3)
              ...List.generate(
                  3 - room.participants.length,
                  (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.grey[400],
                            ),
                          ),
                          title: Text(
                            'In attesa di un giocatore...',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      )),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile({
    required BuildContext context,
    required String name,
    required String role,
    required bool hasConfirmed,
    required bool isCurrentUser,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isCurrentUser ? Theme.of(context).primaryColor : Colors.grey[300],
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(role),
      trailing: hasConfirmed
          ? const Icon(
              Icons.check_circle,
              color: Colors.green,
            )
          : const Icon(
              Icons.timer,
              color: Colors.orange,
            ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCompletedCard(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.celebration,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Pozione completata!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tutti i partecipanti hanno ricevuto i loro punti',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.home),
              label: const Text('Torna alla Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberActions(
    BuildContext context,
    RoomModel room,
    String uid,
    bool isHost,
    bool hasConfirmed,
    RoomService roomService,
  ) {
    // Se l'utente ha già confermato, mostra solo lo stato
    if (hasConfirmed) {
      return Column(
        children: [
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hai confermato la tua partecipazione',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'In attesa che tutti gli altri confermino...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Torna alla Home'),
          ),
        ],
      );
    }

    // Altrimenti, permetti all'utente di confermare
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isConfirming
              ? null
              : () => _confirmParticipation(context, room.id, uid, roomService),
          icon: const Icon(Icons.check_circle_outline),
          label: _isConfirming
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Conferma in corso...'),
                  ],
                )
              : const Text('Conferma partecipazione'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _scannedRoomId = null);
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Indietro'),
        ),
      ],
    );
  }

  Widget _buildJoinActions(
    BuildContext context,
    RoomModel room,
    String uid,
    RoomService roomService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<UserModel?>(
          stream: _dbService.getUser(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ElevatedButton(
                onPressed: null,
                child: Text('Caricamento...'),
              );
            }

            final user = snapshot.data;
            final hasIngredient = user?.currentIngredientId != null;

            return ElevatedButton.icon(
              onPressed: !hasIngredient || _isJoining
                  ? null
                  : () => _joinRoom(context, room.id, uid,
                      user!.currentIngredientId!, roomService),
              icon: const Icon(Icons.login),
              label: _isJoining
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Unione in corso...'),
                      ],
                    )
                  : const Text('Unisciti a questa stanza'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (room.participants.length >= 3)
          const Text(
            'La stanza è piena, non è possibile unirsi',
            style: TextStyle(
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _scannedRoomId = null);
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Indietro'),
        ),
      ],
    );
  }

  Future<void> _joinRoom(
    BuildContext context,
    String roomId,
    String userId,
    String ingredientId,
    RoomService roomService,
  ) async {
    setState(() => _isJoining = true);

    try {
      // Verifica se l'utente può unirsi alla stanza
      final canJoin = await roomService.canJoinRoom(roomId, userId);

      if (!canJoin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non puoi unirti a questa stanza')),
        );
        setState(() => _isJoining = false);
        return;
      }

      // Unisci l'utente alla stanza
      final success = await roomService.joinRoom(
        roomId,
        userId,
        ingredientId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ti sei unito alla stanza!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile unirsi alla stanza')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  Future<void> _confirmParticipation(
    BuildContext context,
    String roomId,
    String userId,
    RoomService roomService,
  ) async {
    setState(() => _isConfirming = true);

    try {
      final success = await roomService.confirmParticipation(roomId, userId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partecipazione confermata!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile confermare la partecipazione')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    } finally {
      setState(() => _isConfirming = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
