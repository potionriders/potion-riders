import 'package:flutter/material.dart';
import 'package:potion_riders/screens/scan_item_screen.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/screens/create_room_screen.dart';
import 'package:potion_riders/screens/join_room_screen.dart';
import 'package:potion_riders/screens/leaderboard_screen.dart';

import '../widgets/coaster_card.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Potion Riders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanItemScreen()),
              );
            },
            tooltip: 'Scansiona',
          ),
          // Per gli admin, aggiungi un menu popup con le funzionalità admin
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Amministrazione'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LeaderboardScreen()),
              );
            },
            tooltip: 'Classifica',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Non sei autenticato'))
          : RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isRefreshing = true;
          });
          // Simulazione aggiornamento dati
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            _isRefreshing = false;
          });
        },
        child: StreamBuilder<UserModel?>(
          stream: _dbService.getUser(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = snapshot.data;
            if (user == null) {
              return const Center(child: Text('Utente non trovato'));
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUserProfileCard(context, user),
                  const SizedBox(height: 24),

                  // Costruisci la card con il widget personalizzato
                  HomeScreenCoasterCard(
                    currentRecipeId: user.currentRecipeId,
                    currentIngredientId: user.currentIngredientId,
                    onTapRecipe: () {
                      if (user.currentRecipeId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateRoomScreen(
                              recipeId: user.currentRecipeId!,
                            ),
                          ),
                        );
                      }
                    },
                    onTapIngredient: () {
                      if (user.currentIngredientId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinRoomScreen(),
                          ),
                        );
                      }
                    },
                    onSwitchItem: (showRecipe) async {
                      try {
                        if (showRecipe && user.currentIngredientId != null) {
                          // Passa da ingrediente a pozione
                          await _dbService.updateUserField(uid, 'currentRecipeId', user.currentIngredientId);
                          await _dbService.updateUserField(uid, 'currentIngredientId', null);
                        } else if (!showRecipe && user.currentRecipeId != null) {
                          // Passa da pozione a ingrediente
                          await _dbService.updateUserField(uid, 'currentIngredientId', user.currentRecipeId);
                          await _dbService.updateUserField(uid, 'currentRecipeId', null);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore nel cambiare elemento: $e')),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Sezione promozionale
                  _buildPromotionalSection(context),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanItemScreen()),
          );
        },
        child: const Icon(Icons.qr_code_scanner),
        tooltip: 'Scansiona QR Code',
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context, UserModel user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                user.nickname.isNotEmpty
                    ? user.nickname[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Benvenuto,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${user.points} punti',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionalSection(BuildContext context) {
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
            Row(
              children: [
                Icon(
                  Icons.campaign,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Come giocare',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              context,
              '1',
              'Scansiona un sottobicchiere per ottenere una pozione o un ingrediente',
            ),
            _buildInstructionStep(
              context,
              '2',
              'Crea una stanza se hai una pozione, o unisciti a una stanza se hai un ingrediente',
            ),
            _buildInstructionStep(
              context,
              '3',
              'Completa le pozioni collaborando con altri giocatori per guadagnare punti!',
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LeaderboardScreen()),
                  );
                },
                icon: const Icon(Icons.leaderboard),
                label: const Text('Visualizza classifica'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildErrorSection(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 16),
            Text(
              message,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ],
        ),
      ),
    );
  }
}