import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/room_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/qr_service.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/user_model.dart';

class RoomManagementScreen extends StatefulWidget {
  final String roomId;
  final String recipeId;

  const RoomManagementScreen({
    super.key,
    required this.roomId,
    required this.recipeId,
  });

  @override
  _RoomManagementScreenState createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  final RoomService _roomService = RoomService();

  String? _qrData;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateQRData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateQRData() {
    _qrData = _roomService.generateQrData(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Stanza'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
            Tab(icon: Icon(Icons.people), text: 'Partecipanti'),
            Tab(icon: Icon(Icons.settings), text: 'Gestione'),
          ],
        ),
      ),
      body: StreamBuilder<RoomModel?>(
        stream: _dbService.getRoom(widget.roomId),
        builder: (context, roomSnapshot) {
          if (roomSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final room = roomSnapshot.data;
          if (room == null) {
            return _buildRoomNotFound();
          }

          return StreamBuilder<RecipeModel?>(
            stream: _dbService.getRecipe(widget.recipeId).asStream(),
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
      ),
    );
  }

  Widget _buildRoomNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Stanza non trovata', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Torna Indietro'),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeTab(RoomModel room, RecipeModel? recipe) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stato della stanza
          _buildRoomStatusCard(room),
          const SizedBox(height: 16),

          // Dettagli ricetta
          if (recipe != null) _buildRecipeCard(recipe),
          const SizedBox(height: 16),

          // QR Code
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'QR Code Stanza',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _qrData != null
                        ? QrService.generateQrCode(_qrData!, size: 200)
                        : const CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('ID Stanza: '),
                      Expanded(
                        child: Text(
                          widget.roomId,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.roomId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID copiato!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Istruzioni
          _buildInstructionsCard(),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab(RoomModel room, RecipeModel? recipe, String? uid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stato generale
          _buildRoomStatusCard(room),
          const SizedBox(height: 16),

          // Progresso ingredienti
          if (recipe != null) _buildIngredientsProgressCard(room, recipe),
          const SizedBox(height: 16),

          // Lista partecipanti dettagliata
          _buildDetailedParticipantsList(room, uid),
        ],
      ),
    );
  }

  Widget _buildManagementTab(RoomModel room, RecipeModel? recipe, String? uid) {
    final bool isHost = room.hostId == uid;
    final bool isParticipant = room.participants.any((p) => p.userId == uid);
    final bool canComplete = room.isReadyToComplete() && isHost && !room.isCompleted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stato della stanza
          _buildRoomStatusCard(room),
          const SizedBox(height: 16),

          // Azioni amministrative
          if (isHost && !room.isCompleted) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Azioni Host',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Completa pozione
                    if (canComplete) ...[
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _completePotion(room),
                        icon: const Icon(Icons.celebration),
                        label: const Text('Completa Pozione'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tutti gli ingredienti sono presenti e confermati!',
                        style: TextStyle(color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.block),
                        label: const Text('Completa Pozione'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getCompletionBlockReason(room),
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Dismetti stanza
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _dismissRoom(room),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Dismetti Stanza'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Azioni partecipante
          if (isParticipant && !room.isCompleted) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Azioni Partecipante',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _leaveRoom(room, uid!),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Abbandona Stanza'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Stato completata
          if (room.isCompleted) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.celebration, size: 48, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Pozione Completata!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tutti i partecipanti hanno ricevuto i punti'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
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
            ),
          ],

          const SizedBox(height: 16),

          // Pulsante torna alla home sempre visibile
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Torna alla Home'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomStatusCard(RoomModel room) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  room.isCompleted ? Icons.check_circle : Icons.access_time,
                  color: room.isCompleted ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  room.isCompleted ? 'Completata' : 'In Corso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: room.isCompleted ? Colors.green : Colors.orange,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text('${room.participants.length}/3'),
                  backgroundColor: room.participants.length >= 3
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Creata:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_formatDateTime(room.createdAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  recipe.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (recipe.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(recipe.description),
            ],
            const SizedBox(height: 12),
            const Text(
              'Ingredienti richiesti:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...recipe.requiredIngredients.map((ingredient) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8),
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

  Widget _buildIngredientsProgressCard(RoomModel room, RecipeModel recipe) {
    final requiredIngredients = recipe.requiredIngredients;
    final participantIngredients = <String>[];

    // Ottieni gli ingredienti dei partecipanti confermati
    for (var participant in room.participants) {
      if (participant.hasConfirmed) {
        // Qui dovresti fare una lookup per ottenere il nome dell'ingrediente
        // Per ora uso l'ID, ma potresti migliorare questo
        participantIngredients.add(participant.ingredientId);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progresso Ingredienti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: participantIngredients.length / requiredIngredients.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                participantIngredients.length >= requiredIngredients.length
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${participantIngredients.length}/${requiredIngredients.length} ingredienti confermati',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),
            ...requiredIngredients.map((ingredient) {
              final isPresent = participantIngredients.contains(ingredient);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isPresent ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isPresent ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ingredient)),
                    if (isPresent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Presente',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedParticipantsList(RoomModel room, String? uid) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Partecipanti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Host
            FutureBuilder<UserModel?>(
              future: _dbService.getUser(room.hostId).first,
              builder: (context, snapshot) {
                final user = snapshot.data;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: const Icon(Icons.science, color: Colors.purple),
                  ),
                  title: Text(user?.nickname ?? 'Host'),
                  subtitle: const Text('Creatore (Pozione)'),
                  trailing: room.hostId == uid
                      ? const Chip(label: Text('Tu'), backgroundColor: Colors.blue)
                      : const Icon(Icons.check_circle, color: Colors.green),
                );
              },
            ),

            // Partecipanti
            ...room.participants.map((participant) =>
                FutureBuilder<UserModel?>(
                  future: _dbService.getUser(participant.userId).first,
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: participant.hasConfirmed
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(
                          Icons.eco,
                          color: participant.hasConfirmed ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(user?.nickname ?? 'Partecipante'),
                      subtitle: const Text('Ingrediente'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (participant.userId == uid)
                            const Chip(label: Text('Tu'), backgroundColor: Colors.blue),
                          const SizedBox(width: 8),
                          Icon(
                            participant.hasConfirmed
                                ? Icons.check_circle
                                : Icons.access_time,
                            color: participant.hasConfirmed ? Colors.green : Colors.orange,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ),

            // Slot vuoti
            if (room.participants.length < 3)
              ...List.generate(3 - room.participants.length, (index) =>
              const ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text('In attesa...'),
                subtitle: Text('Slot libero'),
              ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Istruzioni',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionStep('1', 'Condividi il QR code o l\'ID con i giocatori'),
            _buildInstructionStep('2', 'Aspetta che si uniscano e confermino'),
            _buildInstructionStep('3', 'Quando tutti hanno confermato, completa la pozione'),
            _buildInstructionStep('4', 'Tutti riceveranno i punti automaticamente!'),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _getCompletionBlockReason(RoomModel room) {
    if (room.participants.length < 3) {
      return 'Servono almeno 3 ingredienti (${room.participants.length}/3)';
    }
    if (!room.participants.every((p) => p.hasConfirmed)) {
      final unconfirmed = room.participants.where((p) => !p.hasConfirmed).length;
      return '$unconfirmed partecipanti non hanno ancora confermato';
    }
    return 'Tutti i requisiti sono soddisfatti';
  }

  Future<void> _completePotion(RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completa Pozione'),
        content: const Text(
          'Confermi di voler completare questa pozione? '
              'Tutti i partecipanti riceveranno i punti e la stanza verrà chiusa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await _dbService.completeRoom(widget.roomId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pozione completata! Punti assegnati a tutti.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _dismissRoom(RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismetti Stanza'),
        content: const Text(
          'Confermi di voler dismettere questa stanza? '
              'Tutti i partecipanti verranno rimossi e la stanza verrà chiusa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Dismetti'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Qui dovresti implementare la logica per dismettere la stanza
      // Per ora simulo solo un'azione
      await Future.delayed(const Duration(seconds: 1));

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stanza dismessa.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _leaveRoom(RoomModel room, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abbandona Stanza'),
        content: const Text(
          'Confermi di voler abbandonare questa stanza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Qui dovresti implementare la logica per rimuovere l'utente dalla stanza
      // Per ora simulo solo un'azione
      await Future.delayed(const Duration(seconds: 1));

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hai abbandonato la stanza.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}