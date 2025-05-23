import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/widgets/room_card.dart';
import 'package:potion_riders/screens/create_room_screen.dart';
import 'package:potion_riders/screens/join_room_screen.dart';

class RoomsListScreen extends StatefulWidget {
  const RoomsListScreen({super.key});

  @override
  _RoomsListScreenState createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stanze')),
        body: const Center(child: Text('Devi essere autenticato')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stanze di Gioco'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aperte', icon: Icon(Icons.door_front_door)),
            Tab(text: 'Le Mie', icon: Icon(Icons.person)),
            Tab(text: 'Completate', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Stanze Aperte
          _buildOpenRoomsTab(uid),

          // Tab Le Mie Stanze
          _buildMyRoomsTab(uid),

          // Tab Stanze Completate
          _buildCompletedRoomsTab(uid),
        ],
      ),
      floatingActionButton: StreamBuilder<UserModel?>(
        stream: _dbService.getUser(uid),
        builder: (context, snapshot) {
          final hasRecipe = snapshot.data?.currentRecipeId != null;

          if (!hasRecipe) return const SizedBox();

          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRoomScreen(
                    recipeId: snapshot.data!.currentRecipeId!,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Crea Stanza'),
          );
        },
      ),
    );
  }

  Widget _buildOpenRoomsTab(String uid) {
    return StreamBuilder<List<RoomModel>>(
      stream: _dbService.getOpenRooms(), // Nuovo metodo da aggiungere
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
            // Forza il refresh
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
                    // Vai direttamente alla stanza
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomDetailScreen(roomId: room.id),
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

  Widget _buildMyRoomsTab(String uid) {
    return StreamBuilder<List<RoomModel>>(
      stream: _dbService.getUserRooms(uid), // Nuovo metodo da aggiungere
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data ?? [];
        final myActiveRooms = rooms
            .where((room) => !room.isCompleted)
            .toList();

        if (myActiveRooms.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox,
            title: 'Nessuna stanza attiva',
            message: 'Non sei in nessuna stanza attiva.\nCrea una nuova stanza o unisciti a una esistente!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myActiveRooms.length,
          itemBuilder: (context, index) {
            final room = myActiveRooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RoomCard(
                room: room,
                currentUserId: uid,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomDetailScreen(roomId: room.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedRoomsTab(String uid) {
    return StreamBuilder<List<RoomModel>>(
      stream: _dbService.getUserRooms(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data ?? [];
        final completedRooms = rooms
            .where((room) => room.isCompleted)
            .toList();

        if (completedRooms.isEmpty) {
          return _buildEmptyState(
            icon: Icons.emoji_events,
            title: 'Nessuna stanza completata',
            message: 'Non hai ancora completato nessuna pozione.\nGioca e completa le tue prime pozioni!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedRooms.length,
          itemBuilder: (context, index) {
            final room = completedRooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RoomCard(
                room: room,
                currentUserId: uid,
                onTap: () {
                  // Mostra i dettagli della stanza completata
                  _showCompletedRoomDetails(context, room);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletedRoomDetails(BuildContext context, RoomModel room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stanza Completata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${room.id.substring(0, 8)}...'),
            const SizedBox(height: 8),
            Text('Completata il: ${_formatDate(room.createdAt)}'),
            const SizedBox(height: 16),
            const Text(
              'Punti guadagnati:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Host: +10 punti'),
            Text('Partecipanti: +5 punti ciascuno'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} alle ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Schermata dettaglio stanza
class RoomDetailScreen extends StatelessWidget {
  final String roomId;

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    // Naviga a JoinRoomScreen passando il roomId
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JoinRoomScreen(roomId: roomId),
        ),
      );
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}