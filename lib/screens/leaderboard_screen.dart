import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/user_model.dart';

class LeaderboardScreen extends StatelessWidget {
  final DatabaseService _dbService = DatabaseService();

  LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classifica'),
      ),
      body: Column(
        children: [
          _buildLeaderboardHeader(context),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _dbService.getLeaderboard(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nessun giocatore trovato'));
                }

                final users = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: () async {
                    // Simulazione aggiornamento dati
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isCurrentUser = user.id == currentUserId;
                      final isTopThree = index < 3;

                      return Card(
                        elevation: isTopThree ? 4 : 1,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: isCurrentUser
                            ? Colors.blue.shade50
                            : (isTopThree ? Colors.purple.shade50 : null),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isCurrentUser
                              ? BorderSide(
                                  color: Colors.blue.shade200, width: 1)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: _buildPositionBadge(context, index),
                          title: Text(
                            user.nickname,
                            style: TextStyle(
                              fontWeight: isTopThree || isCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: isCurrentUser
                              ? const Text('(Tu)',
                                  style: TextStyle(color: Colors.blue))
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${user.points}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isTopThree
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                              Text(
                                'punti',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 32,
              ),
              SizedBox(width: 8),
              Text(
                'Classifica Potion Riders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'I migliori Potion Riders dell\'evento!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPositionBadge(BuildContext context, int position) {
    final topColors = [
      Colors.amber, // Gold - 1° posto
      Colors.grey.shade300, // Silver - 2° posto
      Colors.brown.shade300, // Bronze - 3° posto
    ];

    if (position < 3) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: topColors[position],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${position + 1}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: position == 0 ? Colors.black87 : Colors.white,
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: Colors.purple.shade100,
      child: Text(
        '${position + 1}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.purple.shade800,
        ),
      ),
    );
  }
}
