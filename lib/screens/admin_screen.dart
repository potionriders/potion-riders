import 'package:flutter/material.dart';
import 'package:potion_riders/screens/qr_code_generator_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import '../models/coaster_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final adminUserId = authService.currentUser?.uid;

    if (adminUserId == null) {
      return Scaffold(
        body: Center(child: Text('Errore: Utente non autenticato')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pannello Amministrazione'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con informazioni admin
            _buildAdminHeader(authService),
            SizedBox(height: 20),

            // Sezione Generazione QR Code
            _buildQRGenerationSection(),
            SizedBox(height: 20),

            // NUOVA SEZIONE: Gestione Giocatori
            _buildPlayerManagementSection(),
            SizedBox(height: 20),

            // Sezione Facilitatori
            _buildFacilitatorSection(adminUserId),
            SizedBox(height: 20),

            // Statistiche rapide
            _buildQuickStatsSection(adminUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminHeader(AuthService authService) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.admin_panel_settings,
                  size: 30, color: Colors.white),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Benvenuto Amministratore',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${authService.currentUser?.email ?? "Admin"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Admin & Facilitatore',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildQRGenerationSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.indigo, size: 28),
                SizedBox(width: 12),
                Text(
                  'Generazione QR Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRCodeGeneratorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  'Genera QR Code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NUOVA SEZIONE: Gestione Giocatori
  Widget _buildPlayerManagementSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'Gestione Giocatori',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Pulsante Aggiungi Punti
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddPointsDialog(),
                icon: const Icon(Icons.add_circle, size: 24),
                label: const Text(
                  'Aggiungi Punti a Giocatore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),

            SizedBox(height: 12),

            // Pulsante Pulizia Coaster
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCleanCoasterDialog(),
                icon: const Icon(Icons.cleaning_services, size: 24),
                label: const Text(
                  'Pulizia Coaster Giocatore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            // Nel _buildPlayerManagementSection(), dopo gli altri pulsanti:
            SizedBox(height: 12),

// NUOVO: Pulsante Cambia Nome Giocatore
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showChangeNicknameDialog(),
                icon: const Icon(Icons.edit, size: 24),
                label: const Text(
                  'Cambia Nome Giocatore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),

            SizedBox(height: 12),

            // NUOVO: Pulsante Riattiva Coaster Completati
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReactivateCoastersDialog(),
                icon: const Icon(Icons.restore, size: 24),
                label: const Text(
                  'Riattiva Coaster Completati',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitatorSection(String adminUserId) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.purple, size: 28),
                SizedBox(width: 12),
                Text(
                  'Funzioni Facilitatore',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Statistiche facilitatore semplici
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Icon(Icons.door_front_door, color: Colors.blue, size: 24),
                      SizedBox(height: 4),
                      Text(
                        'Stanze Attive',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.help_outline, color: Colors.orange, size: 24),
                      SizedBox(height: 4),
                      Text(
                        'Bisognose Aiuto',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(height: 4),
                      Text(
                        'Completate',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Azioni facilitatore
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _showFacilitatorQRScanner(adminUserId),
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Scansiona Stanza'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRoomsNeedingHelp(adminUserId),
                    icon: Icon(Icons.list),
                    label: Text('Stanze Bisognose'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Nel metodo della classe _AdminScreenState:
  void _showChangeNicknameDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNicknameDialog(),
    );
  }

  Widget _buildQuickStatsSection(String adminUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final users = snapshot.data!.docs;
        final stats = {
          'totalUsers': users.length,
          'activeCoasters': users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['currentRecipeId'] != null;
          }).length,
          'completedPotions': 0,
        };

        return Card(
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.deepOrange, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Statistiche Sistema',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Giocatori Totali',
                      '${stats['totalUsers'] ?? 0}',
                      Icons.people,
                      Colors.indigo,
                    ),
                    _buildStatItem(
                      'Coasters Attivi',
                      '${stats['activeCoasters'] ?? 0}',
                      Icons.qr_code,
                      Colors.blue,
                    ),
                    _buildStatItem(
                      'Pozioni Completate',
                      '${stats['completedPotions'] ?? 0}',
                      Icons.science,
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // =============================================================================
  // METODI DIALOG
  // =============================================================================

  void _showAddPointsDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPointsDialog(),
    );
  }

  void _showCleanCoasterDialog() {
    showDialog(
      context: context,
      builder: (context) => CleanCoasterDialog(),
    );
  }

  // NUOVO: Dialog per riattivare coaster
  void _showReactivateCoastersDialog() {
    showDialog(
      context: context,
      builder: (context) => ReactivateCoastersDialog(),
    );
  }

  // Metodi facilitatore semplificati
  void _showFacilitatorQRScanner(String adminUserId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Funzione facilitatore QR in fase di sviluppo.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showRoomsNeedingHelp(String adminUserId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lista stanze bisognose in fase di sviluppo.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

class ChangeNicknameDialog extends StatefulWidget {
  @override
  _ChangeNicknameDialogState createState() => _ChangeNicknameDialogState();
}

class _ChangeNicknameDialogState extends State<ChangeNicknameDialog> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _nicknameController = TextEditingController();
  String? _selectedUserId;
  String? _selectedUserNickname;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.teal[700]),
          SizedBox(width: 8),
          Text('Cambia Nome Giocatore'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seleziona un giocatore:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: StreamBuilder<List<UserModel>>(
                stream: _dbService.getLeaderboard(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return Center(child: Text('Nessun giocatore trovato'));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelected = _selectedUserId == user.id;

                      return ListTile(
                        selected: isSelected,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              isSelected ? Colors.teal : Colors.grey.shade300,
                          child: Text(
                            user.nickname[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user.nickname),
                        subtitle: Text('Punti: ${user.points}'),
                        onTap: () {
                          setState(() {
                            _selectedUserId = isSelected ? null : user.id;
                            _selectedUserNickname =
                                isSelected ? null : user.nickname;
                            _nicknameController.text =
                                isSelected ? '' : user.nickname;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_selectedUserNickname != null) ...[
              SizedBox(height: 16),
              Text('Nuovo nickname:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: 'Inserisci il nuovo nickname',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
                maxLength: 20,
                onChanged: (value) {
                  setState(() {}); // Per aggiornare il preview
                },
              ),
              if (_nicknameController.text.isNotEmpty &&
                  _nicknameController.text != _selectedUserNickname) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    'Cambierai il nome da "$_selectedUserNickname" a "${_nicknameController.text}"',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal[700],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading ||
                  _selectedUserId == null ||
                  _nicknameController.text.isEmpty ||
                  _nicknameController.text == _selectedUserNickname ||
                  _nicknameController.text.length < 3
              ? null
              : _changeNickname,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[600],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Cambia Nome'),
        ),
      ],
    );
  }

  Future<void> _changeNickname() async {
    if (_selectedUserId == null || _nicknameController.text.isEmpty) return;

    final newNickname = _nicknameController.text.trim();
    if (newNickname.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Il nickname deve avere almeno 3 caratteri'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _dbService.updateUserNickname(_selectedUserId!, newNickname);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nome cambiato da "$_selectedUserNickname" a "$newNickname"',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// =============================================================================
// DIALOG AGGIUNGI PUNTI
// =============================================================================
class AddPointsDialog extends StatefulWidget {
  @override
  _AddPointsDialogState createState() => _AddPointsDialogState();
}

class _AddPointsDialogState extends State<AddPointsDialog> {
  final DatabaseService _dbService = DatabaseService();
  String? _selectedUserId;
  String? _selectedUserNickname;
  int _pointsToAdd = 3;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle, color: Colors.green[700]),
          SizedBox(width: 8),
          Text('Aggiungi Punti'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seleziona un giocatore:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: StreamBuilder<List<UserModel>>(
                stream: _dbService.getLeaderboard(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return Center(child: Text('Nessun giocatore trovato'));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelected = _selectedUserId == user.id;

                      return ListTile(
                        selected: isSelected,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              isSelected ? Colors.green : Colors.grey.shade300,
                          child: Text(
                            user.nickname[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user.nickname),
                        subtitle: Text('Punti attuali: ${user.points}'),
                        onTap: () {
                          setState(() {
                            _selectedUserId = isSelected ? null : user.id;
                            _selectedUserNickname =
                                isSelected ? null : user.nickname;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Text('Punti da aggiungere:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _pointsToAdd = 3),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pointsToAdd == 3
                          ? Colors.green
                          : Colors.grey.shade300,
                      foregroundColor:
                          _pointsToAdd == 3 ? Colors.white : Colors.black54,
                    ),
                    child: Text('3 Punti'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _pointsToAdd = 12),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pointsToAdd == 12
                          ? Colors.green
                          : Colors.grey.shade300,
                      foregroundColor:
                          _pointsToAdd == 12 ? Colors.white : Colors.black54,
                    ),
                    child: Text('12 Punti'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _pointsToAdd = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pointsToAdd == 0 ? Colors.red : Colors.grey.shade300,
                      foregroundColor: _pointsToAdd == 0 ? Colors.white : Colors.black54,
                    ),
                    child: Text('Azzera'),
                  ),
                ),
              ],
            ),
            if (_selectedUserNickname != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Aggiungerai $_pointsToAdd punti a $_selectedUserNickname',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedUserId == null ? null : _addPoints,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Aggiungi'),
        ),
      ],
    );
  }

  Future<void> _addPoints() async {
    if (_selectedUserId == null) return;

    setState(() => _isLoading = true);

    try {
      if (_pointsToAdd == 0) {
        // Azzera i punti (imposta a 0)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_selectedUserId!)
            .update({'points': 0});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Punti di $_selectedUserNickname azzerati con successo'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Aggiungi punti normalmente
        await _dbService.updatePoints(_selectedUserId!, _pointsToAdd);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aggiunti $_pointsToAdd punti a $_selectedUserNickname'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// =============================================================================
// DIALOG PULIZIA COASTER
// =============================================================================
class CleanCoasterDialog extends StatefulWidget {
  @override
  _CleanCoasterDialogState createState() => _CleanCoasterDialogState();
}

class _CleanCoasterDialogState extends State<CleanCoasterDialog> {
  final DatabaseService _dbService = DatabaseService();
  String? _selectedUserId;
  String? _selectedUserNickname;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cleaning_services, color: Colors.orange[700]),
          SizedBox(width: 8),
          Text('Pulizia Coaster'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Questa operazione disassocierà il coaster dal giocatore senza assegnare punti.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[700],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('Seleziona un giocatore attivo:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: StreamBuilder<List<UserModel>>(
                stream: _dbService.getLeaderboard(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final allUsers = snapshot.data ?? [];
                  final activeUsers = allUsers
                      .where((user) =>
                          user.currentRecipeId != null ||
                          user.currentIngredientId != null)
                      .toList();

                  if (activeUsers.isEmpty) {
                    return Center(
                      child: Text(
                        'Nessun giocatore con coaster attivo',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: activeUsers.length,
                    itemBuilder: (context, index) {
                      final user = activeUsers[index];
                      final isSelected = _selectedUserId == user.id;

                      return ListTile(
                        selected: isSelected,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              isSelected ? Colors.orange : Colors.grey.shade300,
                          child: Text(
                            user.nickname[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user.nickname),
                        subtitle: Text('Punti: ${user.points}'),
                        onTap: () {
                          setState(() {
                            _selectedUserId = isSelected ? null : user.id;
                            _selectedUserNickname =
                                isSelected ? null : user.nickname;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_selectedUserNickname != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'ATTENZIONE: Disassocierà il coaster di $_selectedUserNickname SENZA assegnare punti.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed:
              _isLoading || _selectedUserId == null ? null : _cleanCoaster,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Pulisci'),
        ),
      ],
    );
  }

  Future<void> _cleanCoaster() async {
    if (_selectedUserId == null) return;

    setState(() => _isLoading = true);

    try {
      await _dbService.cleanHostAfterCompletion(_selectedUserId!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coaster di $_selectedUserNickname pulito con successo',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la pulizia: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// =============================================================================
// NUOVO: DIALOG RIATTIVA COASTER COMPLETATI
// =============================================================================
class ReactivateCoastersDialog extends StatefulWidget {
  @override
  _ReactivateCoastersDialogState createState() =>
      _ReactivateCoastersDialogState();
}

class _ReactivateCoastersDialogState extends State<ReactivateCoastersDialog> {
  List<String> _selectedCoasters = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.restore, color: Colors.purple[700]),
          SizedBox(width: 8),
          Text('Riattiva Coaster Completati'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                'Seleziona i coaster completati che vuoi rendere nuovamente usabili.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.purple[700],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Coaster completati:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('coasters')
                    .where('isConsumed', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final coasters = snapshot.data?.docs ?? [];

                  if (coasters.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 48, color: Colors.green),
                          SizedBox(height: 8),
                          Text(
                            'Nessun coaster completato trovato',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: coasters.length,
                    itemBuilder: (context, index) {
                      final coaster = coasters[index];
                      final coasterId = coaster.id;
                      final coasterData =
                          coaster.data() as Map<String, dynamic>;
                      final isSelected = _selectedCoasters.contains(coasterId);

                      final previousOwner =
                          coasterData['previousOwner'] as String?;
                      final completedAt =
                          coasterData['consumedAt'] as Timestamp?;

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 2),
                        color: isSelected ? Colors.purple.shade50 : null,
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedCoasters.add(coasterId);
                              } else {
                                _selectedCoasters.remove(coasterId);
                              }
                            });
                          },
                          title: Text(
                            'Coaster ${coasterId.substring(0, 8)}',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (previousOwner != null)
                                Text('Ex proprietario: $previousOwner',
                                    style: TextStyle(fontSize: 12)),
                              if (completedAt != null)
                                Text(
                                  'Completato: ${_formatDate(completedAt.toDate())}',
                                  style: TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          secondary: Icon(
                            Icons.local_drink,
                            color: isSelected ? Colors.purple : Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_selectedCoasters.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Selezionati: ${_selectedCoasters.length} coaster da riattivare',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedCoasters.isEmpty
              ? null
              : _reactivateCoasters,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple[600],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Riattiva (${_selectedCoasters.length})'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _reactivateCoasters() async {
    if (_selectedCoasters.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (String coasterId in _selectedCoasters) {
        final coasterRef =
            FirebaseFirestore.instance.collection('coasters').doc(coasterId);

        batch.update(coasterRef, {
          'isConsumed': false,
          'isActive': true,
          'claimedByUserId': null,
          'usedAs': null,
          'consumedAt': FieldValue.delete(),
          'previousOwner': FieldValue.delete(),
          'completedAsPotion': FieldValue.delete(),
          'completionType': FieldValue.delete(),
          'reactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Riattivati ${_selectedCoasters.length} coaster con successo!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la riattivazione: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
