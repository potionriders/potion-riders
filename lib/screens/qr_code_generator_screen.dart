// ===================================================================
// QR CODE GENERATOR - CLASSE COMPLETA con ID Fix
// File: qr_code_generator_screen.dart
// ===================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/qr_service.dart';

class QRCodeGeneratorScreen extends StatefulWidget {
  const QRCodeGeneratorScreen({super.key});

  @override
  _QRCodeGeneratorScreenState createState() => _QRCodeGeneratorScreenState();
}

class _QRCodeGeneratorScreenState extends State<QRCodeGeneratorScreen> {
  final DatabaseService _dbService = DatabaseService();
  String? _qrData;
  String? _selectedCoasterId;
  CoasterModel? _selectedCoaster;
  String _searchQuery = '';
  bool _showOnlyAvailable = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generatore QR Code'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header con info
          _buildInfoCard(),

          // Filtri
          _buildFiltersCard(),

          // Lista coaster
          Expanded(
            child: _buildCoastersList(),
          ),

          // QR Code generato
          if (_qrData != null && _selectedCoaster != null)
            _buildQRCodeSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Generazione QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Seleziona un sottobicchiere esistente dalla lista per generare il suo QR code. '
                'Il QR code permetterà ai giocatori di reclamare il sottobicchiere durante l\'evento.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra di ricerca
          TextField(
            decoration: InputDecoration(
              hintText: 'Cerca per ID coaster...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),

          // Filtro disponibilità
          Row(
            children: [
              Checkbox(
                value: _showOnlyAvailable,
                onChanged: (value) {
                  setState(() {
                    _showOnlyAvailable = value ?? true;
                  });
                },
              ),
              const Text('Mostra solo sottobicchieri disponibili'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoastersList() {
    return StreamBuilder<List<CoasterModel>>(
      stream: _dbService.getCoasters(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore: ${snapshot.error}'),
          );
        }

        final allCoasters = snapshot.data ?? [];

        // Applica filtri
        final filteredCoasters = allCoasters.where((coaster) {
          // Filtro ricerca
          if (_searchQuery.isNotEmpty) {
            if (!coaster.id.toLowerCase().contains(_searchQuery)) {
              return false;
            }
          }

          // Filtro disponibilità
          if (_showOnlyAvailable && coaster.claimedByUserId != null) {
            return false;
          }

          return true;
        }).toList();

        // Calcola statistiche al volo
        final stats = _calculateStats(allCoasters);

        return Column(
          children: [
            // Statistiche inline
            _buildInlineStats(stats),

            // Lista coaster
            Expanded(
              child: filteredCoasters.isEmpty
                  ? _buildEmptyState()
                  : _buildCoasterListView(filteredCoasters),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineStats(Map<String, int> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('Totali', stats['total']!, Colors.blue),
          _buildStatColumn('Disponibili', stats['available']!, Colors.green),
          _buildStatColumn('Reclamati', stats['claimed']!, Colors.orange),
          _buildStatColumn('Consumati', stats['consumed']!, Colors.red),
        ],
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nessun coaster trovato per "$_searchQuery"'
                : 'Nessun coaster disponibile',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (_showOnlyAvailable) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _showOnlyAvailable = false;
                });
              },
              child: const Text('Mostra anche quelli reclamati'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoasterListView(List<CoasterModel> coasters) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coasters.length,
      itemBuilder: (context, index) {
        final coaster = coasters[index];
        return FutureBuilder<Map<String, String?>>(
          future: _getCoasterDetails(coaster),
          builder: (context, detailsSnapshot) {
            final details = detailsSnapshot.data ?? {};
            final recipeName = details['recipeName'] ?? 'Caricamento...';
            final ingredientName = details['ingredientName'] ?? 'Caricamento...';
            final isSelected = _selectedCoasterId == coaster.id;
            final isAvailable = coaster.claimedByUserId == null;
            final isConsumed = coaster.isConsumed ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isSelected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectCoaster(coaster),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icona stato
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getStatusColor(isConsumed, isAvailable).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _getStatusIcon(isConsumed, isAvailable),
                          color: _getStatusColor(isConsumed, isAvailable),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Dettagli coaster
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ID COMPLETO (non più troncato)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID: ${coaster.id}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _copyToClipboard(coaster.id),
                                  child: Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pozione: $recipeName',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Ingrediente: $ingredientName',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(isConsumed, isAvailable).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusText(isConsumed, isAvailable),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(isConsumed, isAvailable),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Radio button
                      Radio<String>(
                        value: coaster.id,
                        groupValue: _selectedCoasterId,
                        onChanged: (value) => _selectCoaster(coaster),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'QR Code Generato',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrService.generateQrCode(_qrData!, size: 200),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sottobicchiere:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                // ID con layout migliorato per evitare troncamento
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _selectedCoaster!.id,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyToClipboard(_selectedCoaster!.id),
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copia ID',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dettagli pozione e ingrediente
                FutureBuilder<Map<String, String?>>(
                  future: _getCoasterDetails(_selectedCoaster!),
                  builder: (context, snapshot) {
                    final details = snapshot.data ?? {};
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.science,
                              size: 16,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pozione: ${details['recipeName'] ?? 'Caricamento...'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.grain,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ingrediente: ${details['ingredientName'] ?? 'Caricamento...'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Informazioni aggiuntive
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Informazioni QR Code',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Questo QR code permetterà ai giocatori di reclamare il sottobicchiere durante l\'evento. '
                      'Assicurati di distribuirlo solo quando necessario.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bottoni azione ridisegnati
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(_qrData!),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copia Dati QR'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareQRCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Condividi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  Map<String, int> _calculateStats(List<CoasterModel> coasters) {
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

  IconData _getStatusIcon(bool isConsumed, bool isAvailable) {
    if (isConsumed) return Icons.check_circle;
    if (!isAvailable) return Icons.lock;
    return Icons.qr_code;
  }

  Color _getStatusColor(bool isConsumed, bool isAvailable) {
    if (isConsumed) return Colors.red;
    if (!isAvailable) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(bool isConsumed, bool isAvailable) {
    if (isConsumed) return 'CONSUMATO';
    if (!isAvailable) return 'RECLAMATO';
    return 'DISPONIBILE';
  }

  void _selectCoaster(CoasterModel coaster) {
    setState(() {
      _selectedCoasterId = coaster.id;
      _selectedCoaster = coaster;
      _generateQRCode(coaster);
    });
  }

  void _generateQRCode(CoasterModel coaster) {
    // Genera i dati QR per il coaster
    Map<String, dynamic> data = {
      'type': 'coaster',
      'id': coaster.id,
    };

    setState(() {
      _qrData = _formatQRData(data);
    });
  }

  String _formatQRData(Map<String, dynamic> data) {
    return jsonEncode(data);  // Usa JSON invece di toString()
  }

  Future<Map<String, String?>> _getCoasterDetails(CoasterModel coaster) async {
    try {
      final recipe = await _dbService.getRecipe(coaster.recipeId);
      final ingredient = await _dbService.getIngredient(coaster.ingredientId);

      return {
        'recipeName': recipe?.name,
        'ingredientName': ingredient?.name,
      };
    } catch (e) {
      return {
        'recipeName': 'Errore caricamento',
        'ingredientName': 'Errore caricamento',
      };
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiato: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareQRCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funzionalità di condivisione da implementare'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}