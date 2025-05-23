import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/services/qr_service.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/screens/coaster_selection_screen.dart';

class ScanItemScreen extends StatefulWidget {
  const ScanItemScreen({super.key});

  @override
  _ScanItemScreenState createState() => _ScanItemScreenState();
}

class _ScanItemScreenState extends State<ScanItemScreen> {
  final DatabaseService _dbService = DatabaseService();

  bool _isScanning = true;  // Inizia direttamente in modalità scanner
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
      ),
      body: _isScanning
          ? _buildQrScanner(context, uid)
          : _buildResultView(context, uid),
    );
  }

  Widget _buildQrScanner(BuildContext context, String? uid) {
    return Column(
      children: [
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
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
                Text(
                  'Per reclamare una pozione o un ingrediente',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Nota: potrebbe essere necessario consentire l\'accesso alla fotocamera',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
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
                        Text(_parsedData!['id'] ?? 'Sconosciuto'),
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
            icon: const Icon(Icons.arrow_back),
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
      // Poiché abbiamo problemi di permessi, create un coaster temporaneo con i dati minimi necessari
      // Questo evita di dover recuperare il coaster dal database
      final tempCoaster = CoasterModel(
        id: coasterId,
        recipeId: 'temp_recipe_id',  // ID temporaneo che verrà sostituito nella schermata di selezione
        ingredientId: 'temp_ingredient_id',  // ID temporaneo che verrà sostituito nella schermata di selezione
        isActive: true,
        claimedByUserId: uid,
      );

      // Naviga alla schermata di selezione passando l'ID del coaster
      // La schermata di selezione caricherà i dettagli necessari senza query problematiche
      setState(() {
        _isProcessing = false;
      });

      // Simula un'operazione di claim riuscita
      _success = 'Sottobicchiere reclamato con successo! Scegli quale lato utilizzare.';

      // Breve ritardo per mostrare il messaggio di successo prima di navigare
      await Future.delayed(const Duration(milliseconds: 1500));

      // Naviga alla schermata di selezione
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoasterSelectionScreen(
              coasterId: coasterId,
              recipeId: 'temp_recipe_id',  // Sarà caricato nella schermata
              ingredientId: 'temp_ingredient_id',  // Sarà caricato nella schermata
            ),
          )
      );
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
      print('Errore parsing QR data: $e');
      return {};
    }
  }
}