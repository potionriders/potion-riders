import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/qr_service.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/screens/coaster_selection_screen.dart';

import 'claim_coaster_by_id_screen.dart';

class ScanItemScreen extends StatefulWidget {
  const ScanItemScreen({super.key});

  @override
  _ScanItemScreenState createState() => _ScanItemScreenState();
}

class _ScanItemScreenState extends State<ScanItemScreen> {
  final DatabaseService _dbService = DatabaseService();

  bool _isScanning = true;
  bool _isProcessing = false;
  String? _scannedData;
  String? _error;
  String? _success;
  Map<String, dynamic>? _parsedData;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona Sottobicchiere'),
        backgroundColor: kIsWeb ? Theme.of(context).primaryColor : null,
      ),
      body: _isScanning
          ? _buildQrScanner(context, uid)
          : _buildResultView(context, uid),
    );
  }

  Widget _buildQrScanner(BuildContext context, String? uid) {
    return Column(
      children: [
        // Banner informativo per il web
        if (kIsWeb)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade100,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assicurati di aver consentito l\'accesso alla fotocamera quando richiesto dal browser',
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),

        // Scanner QR
        Expanded(
          child: QrService.qrScanner((data) async {
            setState(() {
              _isScanning = false;
              _scannedData = data;
              _isProcessing = true;
            });

            if (uid != null) {
              await _processScannedData(context, uid, data);
            }
          }),
        ),

        // Istruzioni e controlli
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kIsWeb
                      ? 'Inquadra il QR code con la fotocamera'
                      : 'Inquadra il QR code del sottobicchiere o elemento',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Per reclamare una pozione o un ingrediente',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Indietro'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClaimCoasterByIdScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Inserisci ID'),
                    ),
                  ],
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Se la fotocamera non funziona, usa "Inserisci ID"',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context, String? uid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isProcessing) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Elaborazione in corso...'),
                ],
              ),
            ),
          ] else if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Errore',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ],
              ),
            ),
          ] else if (_success != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Successo!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _success!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Mostra i dettagli del QR scansionato
          if (_parsedData != null && !_isProcessing) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dati QR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Tipo: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(_getItemTypeLabel(_parsedData!['type'])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'ID: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _parsedData!['id'] ?? 'Sconosciuto',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isScanning = true;
                _error = null;
                _success = null;
                _scannedData = null;
                _parsedData = null;
                _isProcessing = false;
              });
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scansiona un altro QR code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.home),
            label: const Text('Torna alla Home'),
          ),
        ],
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

  Future<void> _processScannedData(BuildContext context, String uid, String data) async {
    try {
      // Analizza i dati del QR code
      Map<String, dynamic> qrData = _parseQRData(data);
      _parsedData = qrData;

      // Caso 1: È un sottobicchiere
      if (qrData.containsKey('type') && qrData['type'] == 'coaster' && qrData.containsKey('id')) {
        await _processCoaster(context, uid, qrData['id']);
      }
      // Caso 2: È una pozione o un ingrediente diretto
      else if (qrData.containsKey('type') && qrData.containsKey('id')) {
        await _processSingleItem(context, uid, qrData['id'], qrData['type']);
      }
      // Caso 3: QR code non valido
      else {
        setState(() {
          _error = 'QR code non valido. Formato non riconosciuto.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Errore durante l\'elaborazione: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processCoaster(BuildContext context, String uid, String coasterId) async {
    try {
      // Verifica se il coaster esiste
      final coaster = await _dbService.getCoaster(coasterId);

      if (coaster == null) {
        setState(() {
          _error = 'Sottobicchiere non trovato. Verifica l\'ID.';
          _isProcessing = false;
        });
        return;
      }

      // Verifica se è già stato reclamato da qualcun altro
      if (coaster.claimedByUserId != null && coaster.claimedByUserId != uid) {
        setState(() {
          _error = 'Questo sottobicchiere è già stato reclamato da un altro giocatore.';
          _isProcessing = false;
        });
        return;
      }

      // Se l'utente l'ha già reclamato, vai alla selezione
      if (coaster.claimedByUserId == uid) {
        setState(() {
          _success = 'Sottobicchiere già tuo! Scegli quale lato utilizzare.';
          _isProcessing = false;
        });

        await Future.delayed(const Duration(milliseconds: 1500));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoasterSelectionScreen(
              coasterId: coasterId,
              recipeId: coaster.recipeId,
              ingredientId: coaster.ingredientId,
            ),
          ),
        );
        return;
      }

      // Reclama il sottobicchiere
      final success = await _dbService.claimCoaster(coasterId, uid);

      if (success) {
        setState(() {
          _success = 'Sottobicchiere reclamato con successo! Scegli quale lato utilizzare.';
          _isProcessing = false;
        });

        await Future.delayed(const Duration(milliseconds: 1500));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoasterSelectionScreen(
              coasterId: coasterId,
              recipeId: coaster.recipeId,
              ingredientId: coaster.ingredientId,
            ),
          ),
        );
      } else {
        setState(() {
          _error = 'Impossibile reclamare il sottobicchiere. Riprova.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Errore durante l\'elaborazione del sottobicchiere: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processSingleItem(BuildContext context, String uid, String itemId, String itemType) async {
    try {
      // Controlla se l'elemento è già stato reclamato
      bool isAlreadyClaimed = await _dbService.isItemClaimed(itemId);

      if (isAlreadyClaimed) {
        setState(() {
          _error = 'Questo elemento è già stato reclamato da un altro utente.';
          _isProcessing = false;
        });
        return;
      }

      // Assegna l'elemento all'utente
      if (itemType == 'recipe') {
        await _dbService.assignRecipe(uid, itemId);
        setState(() {
          _success = 'Pozione aggiunta con successo al tuo profilo!';
          _isProcessing = false;
        });
      } else if (itemType == 'ingredient') {
        await _dbService.assignIngredient(uid, itemId);
        setState(() {
          _success = 'Ingrediente aggiunto con successo al tuo profilo!';
          _isProcessing = false;
        });
      } else {
        setState(() {
          _error = 'Tipo di elemento non valido.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Errore durante l\'elaborazione dell\'elemento: $e';
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic> _parseQRData(String data) {
    try {
      // Rimuovi parentesi graffe e dividi le coppie chiave-valore
      String cleanData = data.replaceAll('{', '').replaceAll('}', '');
      List<String> pairs = cleanData.split(',');

      Map<String, dynamic> result = {};
      for (String pair in pairs) {
        List<String> keyValue = pair.split(':');
        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          String value = keyValue[1].trim();

          // Rimuovi eventuali virgolette
          key = key.replaceAll('\'', '').replaceAll('"', '');
          value = value.replaceAll('\'', '').replaceAll('"', '');

          result[key] = value;
        }
      }

      return result;
    } catch (e) {
      debugPrint('Errore parsing QR data: $e');
      return {};
    }
  }
}
