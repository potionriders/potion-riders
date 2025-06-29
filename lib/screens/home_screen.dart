import 'package:flutter/material.dart';
import 'package:potion_riders/screens/room_list_screen.dart';
import 'package:potion_riders/screens/scan_item_screen.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/screens/create_room_screen.dart';
import 'package:potion_riders/screens/join_room_screen.dart';
import 'package:potion_riders/screens/leaderboard_screen.dart';
import '../widgets/coaster_card.dart';
import 'admin_screen.dart';
import 'package:potion_riders/screens/claim_coaster_by_id_screen.dart';

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
      body: uid == null
          ? const Center(child: Text('Non sei autenticato'))
          : RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() => _isRefreshing = false);
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

            return CustomScrollView(
              slivers: [
                // Custom App Bar con profilo utente
                _buildSliverAppBar(context, user),

                // Contenuto principale
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card elemento corrente con supporto coaster
                        _buildCurrentElementCard(context, user, uid),
                        const SizedBox(height: 24),

                        // Sezione azioni rapide
                        _buildQuickActionsSection(context, user),
                        const SizedBox(height: 24),

                        // Sezione tutorial
                        _buildTutorialSection(context),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, UserModel user) {
    final authService = Provider.of<AuthService>(context);

    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar utente
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null
                        ? Text(
                      user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Nome utente
                  Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Punti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${user.points} punti',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        // Admin button
        FutureBuilder<bool>(
          future: _dbService.isUserAdmin(authService.currentUser?.uid ?? ''),
          builder: (context, snapshot) {
            if (snapshot.data == true) {
              return IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                ),
                tooltip: 'Amministrazione',
              );
            }
            return const SizedBox();
          },
        ),
        // Leaderboard
        IconButton(
          icon: const Icon(Icons.leaderboard),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LeaderboardScreen()),
          ),
          tooltip: 'Classifica',
        ),
        // Logout
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async => await authService.logout(),
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildCurrentElementCard(BuildContext context, UserModel user, String uid) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Il tuo elemento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Widget del sottobicchiere/elemento con supporto coaster
            StreamBuilder<CoasterModel?>(
              stream: _dbService.getUserCoasterStream(uid),
              builder: (context, coasterSnapshot) {
                final coaster = coasterSnapshot.data;

                return HomeScreenCoasterCard(
                  currentRecipeId: user.currentRecipeId,
                  currentIngredientId: user.currentIngredientId,
                  coaster: coaster,
                  userId: uid,
                  onTapRecipe: () {
                    if (user.currentRecipeId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateRoomScreen(recipeId: user.currentRecipeId!),
                        ),
                      );
                    }
                  },
                  onTapIngredient: () {
                    if (user.currentIngredientId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                      );
                    }
                  },
                  onSwitchItem: (bool useAsRecipe) {
                    // Callback quando l'utente cambia l'uso del coaster
                    // Questo refresh viene gestito automaticamente dal StreamBuilder
                    setState(() {
                      // Force refresh della UI se necessario
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text(
              'Azioni rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Prima costruiamo la lista di azioni in base ai permessi dell'utente
        FutureBuilder<bool>(
          future: _dbService.isUserAdmin(user.uid),
          builder: (context, snapshot) {
            final isAdmin = snapshot.data ?? false;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.qr_code_scanner,
                  title: 'Scansiona QR',
                  subtitle: 'Scansiona un sottobicchiere',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanItemScreen()),
                  ),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.keyboard,
                  title: 'Inserisci ID',
                  subtitle: 'Inserisci manualmente',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClaimCoasterByIdScreen()),
                  ),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.meeting_room,
                  title: 'Stanze',
                  subtitle: 'Vedi tutte le stanze',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomListScreen()),
                  ),
                ),
                if (user.currentRecipeId != null)
                  _buildActionCard(
                    context,
                    icon: Icons.add_circle,
                    title: 'Crea Stanza',
                    subtitle: 'Crea una nuova stanza',
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateRoomScreen(recipeId: user.currentRecipeId!),
                      ),
                    ),
                  )
                else if (user.currentIngredientId != null)
                  _buildActionCard(
                    context,
                    icon: Icons.login,
                    title: 'Unisciti',
                    subtitle: 'Entra in una stanza',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                    ),
                  )
                else if (isAdmin)
                    _buildActionCard(
                      context,
                      icon: Icons.admin_panel_settings,
                      title: 'Admin',
                      subtitle: 'Pannello amministratore',
                      color: Colors.red,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      ),
                    )
                  else
                    _buildActionCard(
                      context,
                      icon: Icons.help_outline,
                      title: 'Tutorial',
                      subtitle: 'Come giocare',
                      color: Colors.amber,
                      onTap: () => _showTutorialDialog(context),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Come giocare',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTutorialStep('1', 'Ottieni un sottobicchiere scansionando o inserendo l\'ID'),
          _buildTutorialStep('2', 'Scegli se usarlo come pozione o ingrediente (puoi cambiare!)'),
          _buildTutorialStep('3', 'Collabora con altri per completare le pozioni'),
          _buildTutorialStep('4', 'Guadagna punti e scala la classifica!'),
        ],
      ),
    );
  }

  Widget _buildTutorialStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue[700],
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

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanItemScreen()),
      ),
      child: const Icon(Icons.qr_code_scanner),
      tooltip: 'Scansiona QR Code',
    );
  }

  void _showTutorialDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Come giocare a Potion Riders'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Benvenuto in Potion Riders!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('1. Ottieni un sottobicchiere dai punti di distribuzione in fiera'),
              const SizedBox(height: 8),
              const Text('2. Scansiona il QR code o inserisci l\'ID manualmente'),
              const SizedBox(height: 8),
              const Text('3. Scegli se usare il lato pozione o ingrediente (puoi cambiare dopo!)'),
              const SizedBox(height: 8),
              const Text('4. Se hai una pozione, crea una stanza'),
              const SizedBox(height: 8),
              const Text('5. Se hai un ingrediente, unisciti a una stanza'),
              const SizedBox(height: 8),
              const Text('6. Completa le pozioni per guadagnare punti!'),
              const SizedBox(height: 16),
              const Text(
                'Punteggi:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Chi ha la pozione: 10 punti'),
              const Text('• Chi porta gli ingredienti: 5 punti'),
              const SizedBox(height: 16),
              const Text(
                'Nuovo!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const Text('• Puoi cambiare l\'uso del sottobicchiere in qualsiasi momento!'),
              const Text('• Usa il pulsante "Flip" nella card per alternare tra pozione e ingrediente'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ho capito!'),
          ),
        ],
      ),
    );
  }
}