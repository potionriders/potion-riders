import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RoomManagementScreen extends StatefulWidget {
  final String roomId;

  const RoomManagementScreen({super.key, required this.roomId});

  @override
  _RoomManagementScreenState createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen>
    with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late RoomService _roomService;
  late TabController _tabController;
  String? _qrData;
  bool _isProcessing = false;
  bool _roomExists = false; // NUOVO: Flag per verificare l'esistenza della stanza

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _roomService = Provider.of<RoomService>(context, listen: false);
    _generateQRData();
    _checkRoomExists(); // NUOVO: Verifica l'esistenza della stanza
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateQRData() {
    _qrData = _roomService.generateQrData(widget.roomId);
  }

  /// NUOVO: Verifica se la stanza esiste prima di costruire l'interfaccia
  Future<void> _checkRoomExists() async {
    try {
      final room = await _dbService.getRoom(widget.roomId).first;
      setState(() {
        _roomExists = room != null;
      });
    } catch (e) {
      debugPrint('Error checking room existence: $e');
      setState(() {
        _roomExists = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Stanza'),
        bottom: _roomExists ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
            Tab(icon: Icon(Icons.people), text: 'Partecipanti'),
            Tab(icon: Icon(Icons.settings), text: 'Gestione'),
          ],
        ) : null,
      ),
      body: !_roomExists
          ? _buildRoomNotFound()
          : StreamBuilder<RoomModel?>(
        stream: _dbService.getRoom(widget.roomId),
        builder: (context, roomSnapshot) {
          if (roomSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final room = roomSnapshot.data;
          if (room == null) {
            // MIGLIORATO: Se la stanza era presente ma ora non c'è più
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _roomExists = false;
              });
            });
            return _buildRoomNotFound();
          }

          return StreamBuilder<UserModel?>(
            stream: _dbService.getUser(uid!),
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;

              // NUOVO: Verifica che l'utente sia effettivamente in questa stanza
              if (user != null && !user.isInRoom(widget.roomId)) {
                return _buildUserNotInRoom();
              }

              return StreamBuilder<RecipeModel?>(
                stream: _dbService.getRecipe(room.recipeId).asStream(),
                builder: (context, recipeSnapshot) {
                  final recipe = recipeSnapshot.data;

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQRCodeTab(room, recipe),
                      _buildParticipantsTab(room, recipe, uid),
                      _buildManagementTab(room, recipe, uid),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// MIGLIORATO: Schermata quando la stanza non viene trovata
  Widget _buildRoomNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Stanza non trovata',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La stanza richiesta non esiste, è stata eliminata o non sei autorizzato ad accedervi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Torna Indietro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _checkRoomExists,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// NUOVO: Schermata quando l'utente non è più nella stanza
  Widget _buildUserNotInRoom() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_accounts,
              size: 80,
              color: Colors.orange.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Non sei più in questa stanza',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Potresti essere stato rimosso dalla stanza o averla abbandonata.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('Torna alla Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeTab(RoomModel room, RecipeModel? recipe) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Informazioni sulla stanza
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
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Informazioni Stanza',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow('ID Stanza', widget.roomId),
                  _buildInfoRow('Ricetta', recipe?.name ?? 'Caricamento...'),
                  _buildInfoRow('Partecipanti', '${room.participants.length}/3'),
                  _buildInfoRow('Stato', room.isCompleted ? 'Completata' : 'In corso'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // QR Code
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Condividi questa stanza',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _qrData != null
                        ? QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    )
                        : const CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fai scansionare questo QR code agli altri giocatori per unirsi alla stanza',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab(RoomModel room, RecipeModel? recipe, String uid) {
    final isHost = room.hostId == uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stato della stanza
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    room.isCompleted ? Icons.check_circle : Icons.pending,
                    color: room.isCompleted ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.isCompleted ? 'Stanza Completata' : 'Stanza In Corso',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          room.isCompleted
                              ? 'Tutti i partecipanti hanno ricevuto i punti'
                              : 'In attesa che tutti confermino',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista partecipanti
          const Text(
            'Partecipanti',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Host
          FutureBuilder<UserModel?>(
            future: _dbService.getUser(room.hostId).first,
            builder: (context, snapshot) {
              final String name = snapshot.data?.nickname ?? 'Giocatore';
              final bool isCurrentUser = room.hostId == uid;

              return _buildParticipantCard(
                name: name + (isCurrentUser ? ' (Tu)' : ''),
                role: 'Host - ${recipe?.name ?? 'Caricamento...'}',
                hasConfirmed: true,
                isCurrentUser: isCurrentUser,
                isHost: true,
              );
            },
          ),

          // Partecipanti
          if (room.participants.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nessun partecipante ancora',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Condividi il QR code per invitare altri giocatori',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...room.participants.map((participant) {
              return FutureBuilder<UserModel?>(
                future: _dbService.getUser(participant.userId).first,
                builder: (context, snapshot) {
                  final String name = snapshot.data?.nickname ?? 'Giocatore';
                  final bool isCurrentUser = participant.userId == uid;

                  return FutureBuilder<String>(
                    future: _dbService.getIngredientNameById(participant.ingredientId),
                    builder: (context, ingredientSnapshot) {
                      final ingredientName = ingredientSnapshot.data ?? 'Caricamento...';

                      return _buildParticipantCard(
                        name: name + (isCurrentUser ? ' (Tu)' : ''),
                        role: 'Ingrediente - $ingredientName',
                        hasConfirmed: participant.hasConfirmed,
                        isCurrentUser: isCurrentUser,
                        isHost: false,
                      );
                    },
                  );
                },
              );
            }).toList(),

          // Slot liberi
          for (int i = room.participants.length; i < 3; i++)
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Slot libero ${i + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard({
    required String name,
    required String role,
    required bool hasConfirmed,
    required bool isCurrentUser,
    required bool isHost,
  }) {
    return Card(
      elevation: isCurrentUser ? 4 : 2,
      color: isCurrentUser ? Colors.blue[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isHost ? Colors.purple[100] : Colors.green[100],
              child: Icon(
                isHost ? Icons.star : Icons.person,
                color: isHost ? Colors.purple[700] : Colors.green[700],
                size: 20,
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
                      fontSize: 16,
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
            if (!isHost)
              Icon(
                hasConfirmed ? Icons.check_circle : Icons.pending,
                color: hasConfirmed ? Colors.green : Colors.orange,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementTab(RoomModel room, RecipeModel? recipe, String uid) {
    final isHost = room.hostId == uid;
    final isParticipant = room.participants.any((p) => p.userId == uid);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Informazioni generali
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestione Stanza',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  Text('Ruolo: ${isHost ? 'Host' : isParticipant ? 'Partecipante' : 'Osservatore'}'),
                  Text('Stato: ${room.isCompleted ? 'Completata' : 'In corso'}'),
                  Text('Partecipanti: ${room.participants.length}/3'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Azioni disponibili
          if (!room.isCompleted && isHost) ...[
            ElevatedButton.icon(
              onPressed: room.participants.isNotEmpty &&
                  room.participants.every((p) => p.hasConfirmed)
                  ? () => _completeRoom(room)
                  : null,
              icon: const Icon(Icons.check_circle),
              label: const Text('Completa Stanza'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _deleteRoom(room),
              icon: const Icon(Icons.delete),
              label: const Text('Elimina Stanza'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],

          if (!room.isCompleted && isParticipant && !isHost) ...[
            OutlinedButton.icon(
              onPressed: () => _leaveRoom(room),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Abbandona Stanza'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],

          if (room.isCompleted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Stanza completata con successo!\nI punti sono stati assegnati.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _completeRoom(RoomModel room) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteRoom(RoomModel room) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Stanza'),
        content: const Text('Sei sicuro di voler eliminare questa stanza? Questa azione non può essere annullata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isProcessing = true;
      });

      try {
        await _dbService.leaveRoom(room.id, room.hostId);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stanza eliminata con successo'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nell\'eliminare la stanza: $e'),
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
  }

  Future<void> _leaveRoom(RoomModel room) async {
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final uid = authService.currentUser?.uid;

        if (uid != null) {
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
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }
}