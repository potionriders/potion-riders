import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/screens/room_management_screen.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class JoinRoomScreen extends StatefulWidget {
  final String? roomId;

  const JoinRoomScreen({super.key, this.roomId});

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final DatabaseService _dbService = DatabaseService();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? _scannedRoomId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      _scannedRoomId = widget.roomId;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Non sei autenticato')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_scannedRoomId != null ? 'Unisciti alla Stanza' : 'Scansiona QR Code'),
        actions: [
          if (_scannedRoomId != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                setState(() {
                  _scannedRoomId = null;
                });
              },
              tooltip: 'Scansiona nuovo QR',
            ),
        ],
      ),
      body: _scannedRoomId != null
          ? _buildRoomDetails(uid)
          : _buildQRScanner(),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        // Istruzioni
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text(
                        'Come unirsi a una stanza',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scansiona il QR code mostrato dal giocatore che ha creato la stanza per unirti automaticamente.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Scanner QR
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.blue,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 250,
                ),
              ),
            ),
          ),
        ),

        // Pulsante manuale
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: OutlinedButton.icon(
            onPressed: _showManualEntryDialog,
            icon: const Icon(Icons.edit),
            label: const Text('Inserisci ID manualmente'),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomDetails(String uid) {
    return StreamBuilder<RoomModel?>(
      stream: _dbService.getRoom(_scannedRoomId!),
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final room = roomSnapshot.data;
        if (room == null) {
          return _buildRoomNotFound(context);
        }

        // NUOVO: Controlla se l'utente è già in questa stanza
        return StreamBuilder<UserModel?>(
          stream: _dbService.getUser(uid),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;

            if (user != null && user.isInRoom(_scannedRoomId!)) {
              // L'utente è già in questa stanza, reindirizza alla gestione
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomManagementScreen(roomId: _scannedRoomId!),
                  ),
                );
              });
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Sei già in questa stanza, reindirizzamento...'),
                  ],
                ),
              );
            }

            return _buildRoomDetailsContent(room, uid);
          },
        );
      },
    );
  }

  Widget _buildRoomDetailsContent(RoomModel room, String uid) {
    final isHost = room.hostId == uid;
    final isParticipant = room.participants.any((p) => p.userId == uid);
    final myParticipant = room.participants.where((p) => p.userId == uid).firstOrNull;
    final hasConfirmed = myParticipant?.hasConfirmed ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stato della stanza
          _buildRoomStatusCard(context, room),
          const SizedBox(height: 16),

          // Informazioni sulla ricetta
          StreamBuilder<RecipeModel?>(
            stream: _dbService.getRecipe(room.recipeId).asStream(),
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
            _buildMemberActions(context, room, uid, isHost, hasConfirmed)
          else
            _buildJoinActions(context, room, uid),
        ],
      ),
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
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Partecipanti: ${room.participants.length + 1}/4'),
                Text('ID: ${room.id.substring(0, 8)}...'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, RecipeModel? recipe) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_pharmacy, color: Colors.purple[600]),
                const SizedBox(width: 8),
                const Text(
                  'Ricetta richiesta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recipe?.name ?? 'Caricamento...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            if (recipe?.description.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                recipe!.description,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(BuildContext context, RoomModel room, String uid) {
    return Card(
      elevation: 2,
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
            const SizedBox(height: 12),

            // Host (chi ha la ricetta)
            FutureBuilder<UserModel?>(
              future: _dbService.getUser(room.hostId).first,
              builder: (context, snapshot) {
                final String name = snapshot.data?.nickname ?? 'Giocatore';
                final bool isCurrentUser = room.hostId == uid;

                return _buildParticipantTile(
                  context: context,
                  name: name + (isCurrentUser ? ' (Tu)' : ''),
                  role: 'Host - Ricetta',
                  hasConfirmed: true,
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
              ...room.participants.map((participant) => FutureBuilder<UserModel?>(
                future: _dbService.getUser(participant.userId).first,
                builder: (context, snapshot) {
                  final String name = snapshot.data?.nickname ?? 'Giocatore';
                  final bool isCurrentUser = participant.userId == uid;

                  return Column(
                    children: [
                      FutureBuilder<String>(
                        future: _dbService.getIngredientNameById(participant.ingredientId),
                        builder: (context, ingredientSnapshot) {
                          final ingredientName = ingredientSnapshot.data ?? 'Caricamento...';

                          return _buildParticipantTile(
                            context: context,
                            name: name + (isCurrentUser ? ' (Tu)' : ''),
                            role: 'Ingrediente - $ingredientName',
                            hasConfirmed: participant.hasConfirmed,
                            isCurrentUser: isCurrentUser,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              )).toList(),

            // Slot liberi
            for (int i = room.participants.length; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      'Slot libero ${i + 1}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser ? Colors.blue[200]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isCurrentUser ? Colors.blue[100] : Colors.grey[300],
            child: Icon(
              Icons.person,
              size: 16,
              color: isCurrentUser ? Colors.blue[700] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (!role.contains('Host'))
            Icon(
              hasConfirmed ? Icons.check_circle : Icons.pending,
              color: hasConfirmed ? Colors.green : Colors.orange,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, color: Colors.green[700], size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stanza completata!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tutti i partecipanti hanno ricevuto i punti.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberActions(BuildContext context, RoomModel room, String uid, bool isHost, bool hasConfirmed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isHost) ...[
          ElevatedButton.icon(
            onPressed: room.participants.isNotEmpty &&
                room.participants.every((p) => p.hasConfirmed)
                ? () => _completeRoom(room)
                : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Completa Pozione'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RoomManagementScreen(roomId: room.id),
              ),
            ),
            icon: const Icon(Icons.settings),
            label: const Text('Gestisci Stanza'),
          ),
        ] else ...[
          if (!hasConfirmed)
            ElevatedButton.icon(
              onPressed: () => _confirmParticipation(room, uid),
              icon: const Icon(Icons.check),
              label: const Text('Conferma Partecipazione'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Partecipazione confermata',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _leaveRoom(room, uid),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Abbandona Stanza'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJoinActions(BuildContext context, RoomModel room, String uid) {
    return StreamBuilder<UserModel?>(
      stream: _dbService.getUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final canJoin = user?.currentIngredientId != null &&
            !room.isCompleted &&
            room.participants.length < 3;

        if (user?.currentIngredientId == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Non hai un ingrediente assegnato. Torna alla home per riceverne uno.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mostra l'ingrediente dell'utente
            FutureBuilder<String>(
              future: _dbService.getIngredientNameById(user!.currentIngredientId!),
              builder: (context, snapshot) {
                final ingredientName = snapshot.data ?? 'Caricamento...';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Il tuo ingrediente: $ingredientName',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: canJoin && !_isProcessing ? () => _joinRoom(room, uid) : null,
              icon: _isProcessing
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.group_add),
              label: Text(_isProcessing ? 'Unendosi...' : 'Unisciti alla Stanza'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && !_isProcessing) {
        setState(() {
          _scannedRoomId = scanData.code;
        });
        controller.pauseCamera();
      }
    });
  }

  void _showManualEntryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inserisci ID Stanza'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'ID Stanza',
            hintText: 'Inserisci l\'ID completo della stanza',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _scannedRoomId = controller.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinRoom(RoomModel room, String uid) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = await _dbService.getUser(uid).first;
      if (user?.currentIngredientId == null) {
        throw Exception('Nessun ingrediente assegnato');
      }

      await _dbService.joinRoom(room.id, uid, user!.currentIngredientId!);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoomManagementScreen(roomId: room.id),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ti sei unito alla stanza con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'unirsi alla stanza: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _confirmParticipation(RoomModel room, String uid) async {
    try {
      // Implementa la logica per confermare la partecipazione
      // Questo dipende dalla tua implementazione esistente
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partecipazione confermata!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella conferma: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeRoom(RoomModel room) async {
    try {
      await _dbService.completeRoom(room.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stanza completata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel completare la stanza: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveRoom(RoomModel room, String uid) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abbandona Stanza'),
        content: const Text('Sei sicuro di voler abbandonare questa stanza?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _dbService.leaveRoom(room.id, uid);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hai abbandonato la stanza'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nell\'abbandonare la stanza: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}