// ===================================================================
// ADMIN SCREEN COMPLETO - Riscrittura Totale
// File: admin_screen.dart
// ===================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/screens/qr_code_generator_screen.dart';
import 'package:potion_riders/screens/direct_import_screen.dart';
import 'package:potion_riders/screens/excel_impor_screen.dart';
import 'package:potion_riders/screens/import_game_data_screen.dart';
import 'package:potion_riders/utils/import_database.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pannello Amministrazione'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Aiuto',
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Accesso non autorizzato'))
          : FutureBuilder<bool>(
        future: _dbService.isUserAdmin(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final isAdmin = snapshot.data ?? false;
          if (!isAdmin) {
            return _buildUnauthorizedView();
          }

          return _buildAdminView(context, uid);
        },
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_accounts,
              size: 72,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Accesso non autorizzato',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Non disponi dei permessi di amministratore necessari per accedere a questa sezione.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Torna Indietro'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminView(BuildContext context, String uid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con info admin
          _buildHeaderCard(),
          const SizedBox(height: 16),

          // Gestione QR Code
          _buildQRCodeManagementCard(context),
          const SizedBox(height: 16),

          // Gestione Database
          _buildDatabaseManagementCard(context, uid),
          const SizedBox(height: 16),

          // Import/Export
          _buildImportExportCard(context),

          // Status message
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildStatusCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade600,
              Colors.purple.shade800,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(width: 12),
                Text(
                  'Pannello Amministrazione',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Gestisci sottobicchieri, database e configurazioni del gioco',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeManagementCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.qr_code,
                  color: Colors.indigo,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Gestione QR Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Genera QR code per sottobicchieri esistenti da distribuire ai giocatori durante l\'evento.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Statistiche coaster
            StreamBuilder<List<CoasterModel>>(
              stream: _dbService.getCoasters(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final coasters = snapshot.data!;
                  final stats = _calculateCoasterStats(coasters);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistiche Sottobicchieri',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Totali', stats['total']!, Colors.blue),
                            _buildStatColumn('Disponibili', stats['available']!, Colors.green),
                            _buildStatColumn('Reclamati', stats['claimed']!, Colors.orange),
                            _buildStatColumn('Consumati', stats['consumed']!, Colors.red),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),

            const SizedBox(height: 20),

            // Bottoni azione
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRCodeGeneratorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Genera QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCoasterListDialog(context),
                    icon: const Icon(Icons.list),
                    label: const Text('Lista Coaster'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildDatabaseManagementCard(BuildContext context, String uid) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Colors.teal,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Gestione Database',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Popola il database con dati di test o cancella tutti i dati esistenti.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _populateDatabase(context, uid),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Popola Database'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _clearDatabase(context, uid),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Cancella Dati'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildImportExportCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.import_export,
                  color: Colors.amber,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Import/Export',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Importa dati da file esterni o esporta configurazioni.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.5,
              children: [
                _buildImportButton(
                  context,
                  'Import Excel',
                  Icons.table_chart,
                  Colors.green,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExcelImportScreen()),
                  ),
                ),
                _buildImportButton(
                  context,
                  'Import Diretto',
                  Icons.code,
                  Colors.blue,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DirectImportScreen()),
                  ),
                ),
                _buildImportButton(
                  context,
                  'Import Dati',
                  Icons.download,
                  Colors.purple,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportGameDataScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton(
      BuildContext context,
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        ),
        child: Row(
          children: [
            Icon(
              _isSuccess ? Icons.check_circle : Icons.error,
              color: _isSuccess ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Helper methods
  Map<String, int> _calculateCoasterStats(List<CoasterModel> coasters) {
    int total = coasters.length;
    int available = 0;
    int claimed = 0;
    int consumed = 0;

    for (var coaster in coasters) {
      if (coaster.isConsumed == true) {
        consumed++;
      } else if (coaster.claimedByUserId != null) {
        claimed++;
      } else {
        available++;
      }
    }

    return {
      'total': total,
      'available': available,
      'claimed': claimed,
      'consumed': consumed,
    };
  }

  void _showCoasterListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lista Sottobicchieri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<CoasterModel>>(
                  stream: _dbService.getCoasters(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text('Errore: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }

                    final coasters = snapshot.data ?? [];

                    if (coasters.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nessun sottobicchiere trovato',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: coasters.length,
                      itemBuilder: (context, index) {
                        final coaster = coasters[index];
                        final isAvailable = coaster.claimedByUserId == null;
                        final isConsumed = coaster.isConsumed ?? false;

                        IconData icon;
                        Color iconColor;
                        String status;

                        if (isConsumed) {
                          icon = Icons.check_circle;
                          iconColor = Colors.red;
                          status = 'CONSUMATO';
                        } else if (!isAvailable) {
                          icon = Icons.lock;
                          iconColor = Colors.orange;
                          status = 'RECLAMATO';
                        } else {
                          icon = Icons.qr_code;
                          iconColor = Colors.green;
                          status = 'DISPONIBILE';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(icon, color: iconColor),
                            ),
                            title: Text(
                              coaster.id,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: iconColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _copyToClipboard(coaster.id),
                                  icon: const Icon(Icons.copy, size: 20),
                                  tooltip: 'Copia ID',
                                ),
                                if (isAvailable)
                                  IconButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const QRCodeGeneratorScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                                    tooltip: 'Genera QR',
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ID copiato: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _populateDatabase(BuildContext context, String uid) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await _dbService.populateWithFakeData(uid);
      setState(() {
        _statusMessage = 'Database popolato con successo!';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante il popolamento: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearDatabase(BuildContext context, String uid) async {
    // Conferma prima di cancellare
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Cancellazione'),
        content: const Text(
          'Sei sicuro di voler cancellare tutti i dati? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await _dbService.clearIngredientsAndRecipes(uid);
      setState(() {
        _statusMessage = 'Dati cancellati con successo!';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante la cancellazione: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guida Amministratore'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestione QR Code',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Genera QR code per sottobicchieri esistenti\n'
                    '• Visualizza statistiche in tempo reale\n'
                    '• Copia ID facilmente per distribuzione',
              ),
              SizedBox(height: 16),
              Text(
                'Gestione Database',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Popola DB: Crea ingredienti e pozioni di esempio\n'
                    '• Cancella Dati: Rimuove tutti gli ingredienti e le pozioni',
              ),
              SizedBox(height: 16),
              Text(
                'Import/Export',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Importa dati da file Excel\n'
                    '• Utilizza import diretti per configurazioni rapide',
              ),
            ],
          ),
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
}