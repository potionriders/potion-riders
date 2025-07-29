import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/screens/room_management_screen.dart';
import 'package:potion_riders/screens/join_room_screen.dart';
import 'package:potion_riders/widgets/room_card.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  _RoomListScreenState createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // NUOVO: 3 tab invece di 2
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        title: const Text('Stanze'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Le Mie Stanze'),
            Tab(icon: Icon(Icons.history), text: 'Completate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyRoomsTab(uid),
          _buildCompletedRoomsTab(uid),
        ],
      ),
    );
  }

  Widget _buildMyRoomsTab(String uid) {
    return StreamBuilder<UserModel?>(
      stream: _dbService.getUser(uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data;
        if (user == null) {
          return _buildErrorState('Utente non trovato');
        }

        return StreamBuilder<List<RoomModel>>(
          stream: _dbService.getUserRooms(uid),
          builder: (context, roomsSnapshot) {
            if (roomsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rooms = roomsSnapshot.data ?? [];
            final activeRooms = rooms.where((room) => !room.isCompleted).toList();

            if (activeRooms.isEmpty) {
              return _buildEmptyState(
                icon: Icons.home_outlined,
                title: 'Nessuna stanza attiva',
                message: 'Non hai stanze attive al momento.\nCrea una nuova stanza o unisciti a una esistente!',
                actionButton: ElevatedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(1); // Vai al tab "Stanze Aperte"
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Cerca Stanze'),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeRooms.length,
                itemBuilder: (context, index) {
                  final room = activeRooms[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMyRoomCard(room, uid),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOpenRoomsTab(String uid) {
    return StreamBuilder<List<RoomModel>>(
      stream: _dbService.getAllOpenRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data ?? [];
        final openRooms = rooms
            .where((room) =>
        !room.isCompleted &&
            room.participants.length < 3 &&
            room.hostId != uid &&
            !room.participants.any((p) => p.userId == uid))
            .toList();

        if (openRooms.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: 'Nessuna stanza aperta',
            message: 'Non ci sono stanze disponibili al momento.\nCreane una tu o attendi che altri giocatori ne creino!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: openRooms.length,
            itemBuilder: (context, index) {
              final room = openRooms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RoomCard(
                  room: room,
                  currentUserId: uid,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JoinRoomScreen(roomId: room.id),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompletedRoomsTab(String uid) {
    return StreamBuilder<List<RoomModel>>(
      stream: _dbService.getUserCompletedRooms(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final completedRooms = snapshot.data ?? [];

        if (completedRooms.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'Nessuna stanza completata',
            message: 'Non hai ancora completato nessuna stanza.\nPartecipa a delle stanze per vedere qui la cronologia!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedRooms.length,
            itemBuilder: (context, index) {
              final room = completedRooms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCompletedRoomCard(room, uid),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyRoomCard(RoomModel room, String uid) {
    final isHost = room.hostId == uid;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomManagementScreen(roomId: room.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con ruolo e stato
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHost ? Colors.purple[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isHost ? 'HOST' : 'PARTECIPANTE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isHost ? Colors.purple[700] : Colors.green[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'IN CORSO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ricetta
              FutureBuilder<String>(
                future: _dbService.getRecipeNameById(room.recipeId),
                builder: (context, snapshot) {
                  final recipeName = snapshot.data ?? 'Caricamento...';
                  return Row(
                    children: [
                      Icon(
                        Icons.local_pharmacy,
                        color: Colors.purple[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recipeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Partecipanti
              Row(
                children: [
                  Icon(
                    Icons.people,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${room.participants.length + 1}/4 partecipanti',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ID: ${room.id.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedRoomCard(RoomModel room, String uid) {
    final isHost = room.hostId == uid;

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
            // Header con ruolo e stato completato
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHost ? Colors.purple[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isHost ? 'HOST' : 'PARTECIPANTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isHost ? Colors.purple[700] : Colors.green[700],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'COMPLETATA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ricetta
            FutureBuilder<String>(
              future: _dbService.getRecipeNameById(room.recipeId),
              builder: (context, snapshot) {
                final recipeName = snapshot.data ?? 'Caricamento...';
                return Row(
                  children: [
                    Icon(
                      Icons.local_pharmacy,
                      color: Colors.purple[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recipeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),

            // Informazioni aggiuntive
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${room.participants.length + 1} partecipanti',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.star,
                  color: Colors.amber[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isHost ? "10" : "5"} punti',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? actionButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 20),
            const Text(
              'Errore',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}