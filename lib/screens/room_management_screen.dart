import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
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
  bool _roomExists = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _roomService = Provider.of<RoomService>(context, listen: false);
    _generateQRData();
    _checkRoomExists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateQRData() {
    _qrData = _roomService.generateQrData(widget.roomId);
  }

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
          ? _buildRoomNotFoundState()
          : uid == null
          ? const Center(child: Text('Non sei autenticato'))
          : StreamBuilder<RoomModel?>(
        stream: _dbService.getRoom(widget.roomId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState('Errore nel caricamento: ${snapshot.error}');
          }

          final room = snapshot.data;
          if (room == null) {
            return _buildRoomNotFoundState();
          }

          return FutureBuilder<RecipeModel?>(
            future: _dbService.getRecipe(room.recipeId),
            builder: (context, recipeSnapshot) {
              final recipe = recipeSnapshot.data;

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildQRTab(room, recipe),
                  _buildParticipantsTab(room, recipe, uid),
                  _buildManagementTab(room, recipe, uid),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoomNotFoundState() {
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
              'La stanza richiesta non esiste o non è più disponibile.',
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

  Widget _buildErrorState(String message) {
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRTab(RoomModel room, RecipeModel? recipe) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (recipe != null) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu, color: Colors.purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('ID Stanza', room.id),
                    _buildInfoRow('Stato', room.isCompleted ? 'Completata' : 'In corso'),
                    _buildInfoRow('Partecipanti', '${room.participants.length}/3'),
                    _buildInfoRow('Ingredienti confermati', '${room.getConfirmedIngredientsCount()}/3'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'QR Code della Stanza',
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
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
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
    final isParticipant = room.participants.any((p) => p.userId == uid);
    final userParticipant = isParticipant
        ? room.participants.firstWhere((p) => p.userId == uid)
        : null;
    final hasUserConfirmed = userParticipant?.hasConfirmed ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                              ? 'I punti sono stati assegnati'
                              : 'Ingredienti confermati: ${room.getConfirmedIngredientsCount()}/3',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
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

          if (isParticipant && !hasUserConfirmed && !room.isCompleted) ...[
            Card(
              elevation: 2,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in,
                      size: 32,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Conferma la tua partecipazione',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Clicca qui per confermare che hai portato il tuo ingrediente',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _confirmParticipation(room.id, uid),
                      icon: const Icon(Icons.check),
                      label: const Text('Conferma Partecipazione'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Partecipanti (${room.participants.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (room.participants.isEmpty)
                    const Text(
                      'Nessun partecipante ancora',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...room.participants.map((participant) => _buildParticipantTile(
                      participant,
                      uid,
                      recipe?.requiredIngredients ?? [],
                    )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (isHost && !room.isCompleted) ...[
            StreamBuilder<int>(
              stream: _dbService.getConfirmedIngredientsCount(room.id),
              builder: (context, snapshot) {
                final confirmedCount = snapshot.data ?? 0;
                final canComplete = confirmedCount >= 3;

                return Card(
                  elevation: 2,
                  color: canComplete ? Colors.green[50] : Colors.grey[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          canComplete ? Icons.done_all : Icons.hourglass_empty,
                          size: 32,
                          color: canComplete ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canComplete
                              ? 'Stanza Pronta per il Completamento'
                              : 'In Attesa di Conferme',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: canComplete ? Colors.green[700] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ingredienti confermati: $confirmedCount/3',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: canComplete && !_isProcessing
                              ? () => _completeRoom(room)
                              : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Completa Stanza'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],

          if (!room.isCompleted) ...[
            OutlinedButton.icon(
              onPressed: () => isHost ? _deleteRoom(room) : _leaveRoom(room),
              icon: Icon(isHost ? Icons.delete : Icons.exit_to_app),
              label: Text(isHost ? 'Elimina Stanza' : 'Abbandona Stanza'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isHost ? Colors.red : Colors.orange,
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

  Widget _buildParticipantTile(ParticipantModel participant, String currentUserId, List<String> requiredIngredients) {
    final isCurrentUser = participant.userId == currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
          Icon(
            participant.hasConfirmed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: participant.hasConfirmed ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${participant.userName ?? "Utente Sconosciuto"} - ${participant.ingredientName ?? "Ingrediente Sconosciuto"}'),
                    if (isCurrentUser)
                      const Text(
                        ' (Tu)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Ingrediente: ${participant.ingredientId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  participant.hasConfirmed ? 'Confermato' : 'In attesa di conferma',
                  style: TextStyle(
                    fontSize: 12,
                    color: participant.hasConfirmed ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  Text('Ingredienti confermati: ${room.getConfirmedIngredientsCount()}/3'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!room.isCompleted && isHost) ...[
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

  Future<void> _confirmParticipation(String roomId, String userId) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _dbService.confirmParticipation(roomId, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partecipazione confermata!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel confermare la partecipazione: $e'),
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

  Future<void> _completeRoom(RoomModel room) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final authService = Provider.of<AuthService>(context);
      final uid = authService.currentUser?.uid;
      await _dbService.completeRoomUltraSimple(room.id, uid ?? "");

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
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hai abbandonato la stanza'),
              backgroundColor: Colors.green,
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