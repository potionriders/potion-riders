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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Classifica'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.person),
                text: 'Giocatori',
              ),
              Tab(
                icon: Icon(Icons.group),
                text: 'Casate',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlayersLeaderboardTab(),
            _HousesLeaderboardTab(),
          ],
        ),
      ),
    );
  }
}

// Tab per la classifica dei giocatori
class _PlayersLeaderboardTab extends StatelessWidget {
  const _PlayersLeaderboardTab();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid;
    final DatabaseService dbService = DatabaseService();

    return Column(
      children: [
        _buildLeaderboardHeader(context, 'Classifica Giocatori', 'I migliori Potion Riders dell\'evento!'),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: dbService.getLeaderboard(),
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
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: isCurrentUser
                          ? Colors.blue.shade50
                          : (isTopThree ? Colors.purple.shade50 : null),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isCurrentUser
                            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPositionBadge(context, index),
                            const SizedBox(width: 8),
                            _buildHouseIcon(user.house),
                          ],
                        ),
                        title: Text(
                          user.nickname,
                          style: TextStyle(
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                            color: isCurrentUser ? Theme.of(context).primaryColor : null,
                          ),
                        ),
                        subtitle: Text(
                          user.house ?? 'Senza Casata',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getHouseColor(user.house),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${user.points}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isTopThree ? Theme.of(context).primaryColor : null,
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
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Tab per la classifica delle casate
class _HousesLeaderboardTab extends StatelessWidget {
  const _HousesLeaderboardTab();

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Column(
      children: [
        _buildLeaderboardHeader(context, 'Classifica Casate', 'Le casate più attive dell\'evento!'),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: dbService.getHouseLeaderboard(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nessuna casata trovata'));
              }

              final houses = snapshot.data!;

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.builder(
                  itemCount: houses.length,
                  itemBuilder: (context, index) {
                    final house = houses[index];
                    final houseName = house['house'] as String;
                    final totalPoints = house['totalPoints'] as int;
                    final playerCount = house['playerCount'] as int;
                    final averagePoints = house['averagePoints'] as double;
                    final players = house['players'] as List<dynamic>;

                    return Card(
                      elevation: index < 3 ? 4 : 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: index < 3 ? Colors.purple.shade50 : null,
                      child: ExpansionTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPositionBadge(context, index),
                            const SizedBox(width: 8),
                            _buildHouseIcon(houseName),
                          ],
                        ),
                        title: Text(
                          houseName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getHouseColor(houseName),
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '$playerCount giocatori • Media: ${averagePoints.toStringAsFixed(1)} punti',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$totalPoints',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _getHouseColor(houseName),
                              ),
                            ),
                            Text(
                              'punti totali',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        children: [
                          if (players.isNotEmpty) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Membri della casata:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...players.map((player) {
                                    final playerData = player as Map<String, dynamic>;
                                    final nickname = playerData['nickname'] as String;
                                    final points = playerData['points'] as int;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            nickname,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            '$points pts',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Funzioni di utilità condivise
Widget _buildLeaderboardHeader(BuildContext context, String title, String subtitle) {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
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
            color: position == 0 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  } else {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Center(
        child: Text(
          '${position + 1}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

Widget _buildHouseIcon(String? house) {
  IconData icon;
  Color color;

  switch (house) {
    case 'Rospo Verde':
      icon = Icons.pets;
      color = Colors.green;
      break;
    case 'Gatto Nero':
      icon = Icons.pets;
      color = Colors.purple;
      break;
    case 'Merlo d\'Oro':
      icon = Icons.pets;
      color = Colors.amber;
      break;
    default:
      icon = Icons.help_outline;
      color = Colors.grey;
  }

  return Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Icon(
      icon,
      size: 20,
      color: color,
    ),
  );
}

Color _getHouseColor(String? house) {
  switch (house) {
    case 'Rospo Verde':
      return Colors.green;
    case 'Gatto Nero':
      return Colors.purple;
    case 'Merlo d\'Oro':
      return Colors.amber.shade700;
    default:
      return Colors.grey;
  }
}