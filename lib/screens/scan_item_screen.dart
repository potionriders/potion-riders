import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/qr_service.dart';
import 'package:potion_riders/screens/claim_coaster_by_id_screen.dart';
import 'dart:convert';

class ScanItemScreen extends StatefulWidget {
  const ScanItemScreen({super.key});

  @override
  State<ScanItemScreen> createState() => _ScanItemScreenState();
}

class _ScanItemScreenState extends State<ScanItemScreen> {
  final DatabaseService _dbService = DatabaseService();

  bool _isScanning = true;
  bool _isProcessing = false;
  String? _error;
  String? _success;
  String? _scannedData;
  Map<String, dynamic>? _parsedData;
  int _scanAttempts = 0;
  static const int MAX_SCAN_ATTEMPTS = 5;

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
        title: Text(_isScanning ? 'Scansiona QR Code' : 'Risultato Scansione'),
        actions: [
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _resetScan,
              tooltip: 'Scansiona nuovo QR',
            ),
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.keyboard),
              onPressed: () => _navigateToManualEntry(),
              tooltip: 'Inserisci ID manualmente',
            ),
        ],
      ),
      body: _isScanning ? _buildQRScanner(uid) : _buildResultView(context, uid),
    );
  }

  Widget _buildQRScanner(String? uid) {
    return Column(
      children: [
        // Messaggio di errore se presente
        if (_error != null) _buildErrorMessage(),

        // Area principale scanner
        Expanded(
          flex: kIsWeb ? 3 : 4,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildScannerWidget(uid),
          ),
        ),

        // Informazioni e controlli
        Expanded(
          flex: kIsWeb ? 2 : 1,
          child: _buildControlsSection(),
        ),
      ],
    );
  }

  Widget _buildScannerWidget(String? uid) {
    if (_isProcessing) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Elaborazione in corso...'),
            ],
          ),
        ),
      );
    }

    return QrService.qrScanner((data) async {
      print('🚨 CALLBACK TRIGGERED! Data: $data');
      print('📱 QR Code scansionato dalla camera: $data');

      // Incrementa contatore tentativi
      _scanAttempts++;

      // Mostra immediatamente cosa è stato scansionato
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.qr_code, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('QR Scansionato: ${data.length > 50 ? data.substring(0, 50) + "..." : data}')),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isScanning = false;
        _scannedData = data;
        _isProcessing = true;
        _error = null;
      });

      if (uid != null) {
        await _processScannedData(context, uid, data);
      } else {
        setState(() {
          _error = 'Utente non autenticato';
          _isProcessing = false;
        });
      }
    });
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Errore di Scansione',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _isScanning
                ? 'Inquadra il QR code con la fotocamera'
                : 'Inquadra il QR code del sottobicchiere o elemento',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _scanAttempts > 0
                ? 'Tentativi di scansione: $_scanAttempts/$MAX_SCAN_ATTEMPTS'
                : 'Per reclamare una pozione o un ingrediente',
            style: TextStyle(
              fontSize: 14,
              color: _scanAttempts >= MAX_SCAN_ATTEMPTS ? Colors.red : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Pulsanti principali
          _buildActionButtons(),

          // Warning per web
          if (kIsWeb) _buildWebWarning(),

          // Suggerimenti per problemi di scansione
          if (_scanAttempts >= 3) _buildTroubleshootingTips(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Indietro'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToManualEntry,
            icon: const Icon(Icons.keyboard),
            label: const Text('Inserisci ID'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kIsWeb ? Colors.orange : Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.web, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Su web la camera potrebbe avere limitazioni. Usa "Inserisci ID" come alternativa.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingTips() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Problemi con la scansione?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Assicurati che il QR code sia ben illuminato\n'
                '• Mantieni il dispositivo stabile\n'
                '• Prova ad avvicinare/allontanare la camera\n'
                '• Usa "Inserisci ID" se il problema persiste',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, String? uid) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stato del processing
          if (_isProcessing) _buildProcessingCard(),

          // Risultato successo
          if (_success != null) _buildSuccessCard(),

          // Risultato errore
          if (_error != null && !_isProcessing) _buildErrorCard(),

          // Dati scansionati
          if (_scannedData != null) _buildScannedDataCard(),

          const Spacer(),

          // Pulsanti azione
          _buildResultActions(),
        ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Elaborazione QR Code in corso...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Attendere prego'),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Successo!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(_success!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Errore',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  Text(_error!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dati QR Scansionati',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_parsedData != null) ...[
              Row(
                children: [
                  Icon(Icons.category, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tipo: ${_getItemTypeLabel(_parsedData!['type'])}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.fingerprint, size: 20),
                  const SizedBox(width: 8),
                  Text('ID: ${_parsedData!['id'] ?? 'Sconosciuto'}'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Dati raw:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _scannedData!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scansiona un altro QR code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('Torna alla Home'),
          ),
        ),
      ],
    );
  }

  void _resetScan() {
    setState(() {
      _isScanning = true;
      _error = null;
      _success = null;
      _scannedData = null;
      _parsedData = null;
      _isProcessing = false;
      _scanAttempts = 0;
    });
  }

  void _navigateToManualEntry() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ClaimCoasterByIdScreen(),
      ),
    );
  }

  String _getItemTypeLabel(String? type) {
    switch (type) {
      case 'recipe':
        return 'Pozione';
      case 'ingredient':
        return 'Ingrediente';
      case 'coaster':
        return 'Sottobicchiere';
      default:
        return 'Sconosciuto';
    }
  }

  Future<void> _processScannedData(
      BuildContext context, String uid, String data) async {
    print('🔍 DEBUG: Dati QR scansionati: $data');

    try {
      // Analizza i dati del QR code
      Map<String, dynamic> qrData = _parseQRData(data);
      print('🔍 DEBUG: Dati parsati: $qrData');

      _parsedData = qrData;

      // Se il parsing è vuoto, prova formati alternativi
      if (qrData.isEmpty) {
        print('🚨 DEBUG: Parsing fallito, provo formati alternativi');
        qrData = _tryAlternativeParsing(data);
        _parsedData = qrData;
      }

      if (qrData.isEmpty) {
        setState(() {
          _error = 'QR code non riconosciuto o formato non valido.\n\n'
              'Dati raw: $data\n\n'
              'Prova ad utilizzare "Inserisci ID" se conosci l\'ID del sottobicchiere.';
          _isProcessing = false;
        });
        return;
      }

      // Processa i dati in base al tipo
      await _handleQRData(context, uid, qrData);

    } catch (e) {
      print('❌ DEBUG: Errore processamento QR: $e');
      setState(() {
        _error = 'Errore nell\'elaborazione del QR code: $e';
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic> _parseQRData(String data) {
    try {
      // Prova a parsare come JSON
      return jsonDecode(data);
    } catch (e) {
      print('DEBUG: Non è JSON valido: $e');
      return {};
    }
  }

  Map<String, dynamic> _tryAlternativeParsing(String data) {
    try {
      // Prova a parsare come JSON diretto
      return jsonDecode(data);
    } catch (e) {
      print('❌ DEBUG: Anche JSON fallito: $e');

      // Fallback: cerca pattern noti
      if (data.contains('coaster') || data.contains('recipe') || data.contains('ingredient')) {
        // Prova pattern semplice: type:id
        final parts = data.split(':');
        if (parts.length >= 2) {
          return {
            'type': parts[0].trim(),
            'id': parts[1].trim(),
          };
        }

        // Ultimo tentativo: assume sia un ID semplice
        return {
          'type': 'coaster',
          'id': data.trim(),
        };
      }

      return {};
    }
  }

  Future<void> _handleQRData(
      BuildContext context, String uid, Map<String, dynamic> qrData) async {
    final String? type = qrData['type'];
    final String? id = qrData['id'];

    if (type == null || id == null) {
      setState(() {
        _error = 'QR code incompleto: manca tipo o ID';
        _isProcessing = false;
      });
      return;
    }

    switch (type.toLowerCase()) {
      case 'coaster':
        await _handleCoasterClaim(context, uid, id);
        break;
      case 'recipe':
        await _handleRecipeClaim(context, uid, id);
        break;
      case 'ingredient':
        await _handleIngredientClaim(context, uid, id);
        break;
      default:
        setState(() {
          _error = 'Tipo di QR code non supportato: $type';
          _isProcessing = false;
        });
    }
  }

  Future<void> _handleCoasterClaim(
      BuildContext context, String uid, String coasterId) async {
    print('DEBUG: Tentativo claim coaster: $coasterId');

    try {
      final result = await _dbService.claimCoaster(coasterId, uid);

      setState(() {
        if (result == true) {
          _success = 'Sottobicchiere $coasterId reclamato con successo!';
          if (result != null) {
            _success = _success! + '\nRicetta sbloccata}';
          }
        } else {
          _error = 'Errore nel reclamare il sottobicchiere';
        }
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Errore durante il claim: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleRecipeClaim(
      BuildContext context, String uid, String recipeId) async {
    setState(() {
      _error = 'Claim ricette non ancora implementato';
      _isProcessing = false;
    });
  }

  Future<void> _handleIngredientClaim(
      BuildContext context, String uid, String ingredientId) async {
    setState(() {
      _error = 'Claim ingredienti non ancora implementato';
      _isProcessing = false;
    });
  }
}