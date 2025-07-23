import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/screens/room_management_screen.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'dart:convert';

class JoinRoomScreen extends StatefulWidget {
  final String? roomId;

  const JoinRoomScreen({super.key, this.roomId});

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final DatabaseService _dbService = DatabaseService();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController? controller;
  String? _scannedRoomId;
  bool _isProcessing = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      _scannedRoomId = widget.roomId;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

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
        title: Text(_scannedRoomId != null ? 'Unisciti alla Stanza' : 'Scansiona QR Code'),
        actions: [
          if (_scannedRoomId != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                setState(() {
                  _scannedRoomId = null;
                  _lastError = null;
                });
              },
              tooltip: 'Scansiona nuovo QR',
            ),
        ],
      ),
      body: _scannedRoomId != null
          ? _buildRoomJoinView(uid, _scannedRoomId!)
          : _buildQRScannerView(),
    );
  }

  Widget _buildQRScannerView() {
    return Column(
      children: [
        // Intestazione scanner
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Column(
            children: [
              Icon(Icons.qr_code_scanner, size: 32, color: Colors.blue[700]),
              const SizedBox(height: 8),
              Text(
                'Scansiona il QR Code della stanza',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Punta la fotocamera verso il QR code per unirti automaticamente',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Scanner QR
        Expanded(
          flex: 4,
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.green,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 250,
            ),
          ),
        ),

        // Info e stato
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Processando QR code...'),
                ] else if (_lastError != null) ...[
                  Icon(Icons.error, color: Colors.red[600], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _lastError!,
                    style: TextStyle(color: Colors.red[600]),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Icon(Icons.qr_code, color: Colors.grey[600], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Pronto per la scansione',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomJoinView(String uid, String roomId) {
    return StreamBuilder<RoomModel?>(
      stream: _dbService.getRoom(roomId),
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (roomSnapshot.hasError || !roomSnapshot.hasData) {
          return _buildErrorView('Errore nel caricamento della stanza');
        }

        final room = roomSnapshot.data!;

        return FutureBuilder<RecipeModel?>(
          future: _dbService.getRecipe(room.recipeId) ,
          builder: (context, recipeSnapshot) {
            if (recipeSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (recipeSnapshot.hasError || !recipeSnapshot.hasData) {
              return _buildErrorView('Errore nel caricamento della ricetta');
            }

            final recipe = recipeSnapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRoomInfoCard(room),
                  const SizedBox(height: 16),
                  _buildRecipeCard(recipe),
                  const SizedBox(height: 16),
                  _buildCoasterIngredientMatchingCard(room, recipe, uid),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoomInfoCard(RoomModel room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.meeting_room, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Informazioni Stanza',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('ID Stanza', room.id),
            _buildInfoRow('Host', room.hostId),
            _buildInfoRow('Stato', room.isCompleted ? 'Completata' : 'Attiva'),
            _buildInfoRow('Partecipanti', '${room.participants.length}/3'),
            _buildInfoRow('Creata il', '${room.createdAt.day}/${room.createdAt.month}/${room.createdAt.year}'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_pharmacy, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  'Ricetta Richiesta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recipe.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recipe.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingredienti richiesti:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            ...recipe.requiredIngredients.map((ingredient) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 8,
                    color: Colors.purple[400],
                  ),
                  const SizedBox(width: 8),
                  Text(ingredient),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCoasterIngredientMatchingCard(RoomModel room, RecipeModel recipe, String uid) {
    return FutureBuilder<CoasterModel?>(
      future: _getUserCurrentCoaster(uid),
      builder: (context, coasterSnapshot) {
        if (coasterSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (coasterSnapshot.hasError) {
          return _buildErrorCard(
            'Errore Coaster',
            'Errore nel caricamento del tuo coaster: ${coasterSnapshot.error}',
            Icons.error,
            Colors.red,
          );
        }

        final coaster = coasterSnapshot.data;
        if (coaster == null) {
          return _buildErrorCard(
            'Nessun Coaster',
            'Non hai nessun coaster attivo. Reclama un coaster prima di unirti a una stanza.',
            Icons.credit_card,
            Colors.orange,
            actionButton: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.credit_card),
              label: const Text('Reclama Coaster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        return _buildCoasterMatchingLogic(room, recipe, coaster, uid);
      },
    );
  }

  Widget _buildCoasterMatchingLogic(RoomModel room, RecipeModel recipe, CoasterModel coaster, String uid) {
    final userIngredientId = coaster.ingredientId;

    return FutureBuilder<String>(
      future: _dbService.getIngredientNameById(userIngredientId),
      builder: (context, userIngredientSnapshot) {
        if (userIngredientSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userIngredientName = userIngredientSnapshot.data ?? 'Ingrediente sconosciuto';

        return FutureBuilder<List<String>>(
          future: _getPresentIngredientNames(room.participants),
          builder: (context, presentIngredientsSnapshot) {
            if (presentIngredientsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final presentIngredientNames = presentIngredientsSnapshot.data ?? [];

            // Controlli di matching
            final isIngredientRequired = recipe.requiredIngredients.contains(userIngredientName);
            final isIngredientAlreadyPresent = presentIngredientNames.contains(userIngredientName);
            final isRoomFull = room.participants.length >= 3;
            final isUserAlreadyParticipant = room.participants.any((p) => p.userId == uid);

            // CASO 1: Utente già partecipante
            if (isUserAlreadyParticipant) {
              return _buildSuccessCard(
                'Già Partecipante',
                'Sei già un partecipante di questa stanza!',
                actionButton: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomManagementScreen(roomId: room.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Vai alla Stanza'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            }

            // CASO 2: Ingrediente non richiesto
            if (!isIngredientRequired) {
              return _buildErrorCard(
                'Ingrediente Non Compatibile',
                'Il tuo ingrediente "$userIngredientName" non è richiesto da questa ricetta.',
                Icons.block,
                Colors.red,
                subtitle: 'Ingredienti richiesti: ${recipe.requiredIngredients.join(", ")}',
                actionButton: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Cerca Altra Stanza'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            }

            // CASO 3: Ingrediente già presente
            if (isIngredientAlreadyPresent) {
              final missingIngredients = recipe.requiredIngredients
                  .where((ingredient) => !presentIngredientNames.contains(ingredient))
                  .toList();

              return _buildErrorCard(
                'Ingrediente Già Presente',
                'Un altro partecipante ha già portato "$userIngredientName".',
                Icons.people,
                Colors.orange,
                subtitle: missingIngredients.isNotEmpty
                    ? 'Ingredienti ancora mancanti: ${missingIngredients.join(", ")}'
                    : 'Tutti gli ingredienti sono presenti.',
                actionButton: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Cerca Altra Stanza'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            }

            // CASO 4: Stanza piena
            if (isRoomFull) {
              return _buildErrorCard(
                'Stanza Piena',
                'Questa stanza ha già raggiunto il numero massimo di partecipanti (3).',
                Icons.group,
                Colors.blue,
                actionButton: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Cerca Altra Stanza'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            }

            // CASO 5: MATCH PERFETTO
            return _buildAutoJoinCard(
              'Perfetto Match!',
              'Il tuo ingrediente "$userIngredientName" è necessario per questa ricetta!',
              subtitle: 'Progresso: ${room.participants.length + 1}/3 ingredienti',
              room: room,
              uid: uid,
            );
          },
        );
      },
    );
  }

  Widget _buildAutoJoinCard(String title, String message, {String? subtitle, required RoomModel room, required String uid}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.auto_fix_high, size: 48, color: Colors.green[700]),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Sezione auto-join
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Join Automatico Disponibile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Il tuo ingrediente è perfetto per questa ricetta! Puoi unirti automaticamente con un solo tap.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pulsante join automatico
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _joinRoomWithAutoConfirm(room.id, uid),
                icon: _isProcessing
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.flash_on),
                label: Text(_isProcessing ? 'Unendosi...' : 'Join Automatico'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Pulsante scansiona nuovo QR
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : () {
                  setState(() {
                    _scannedRoomId = null;
                    _lastError = null;
                  });
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scansiona Nuovo QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  side: BorderSide(color: Colors.green[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Torna Indietro'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String title, String message, IconData icon, Color color, {String? subtitle, Widget? actionButton}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(String title, String message, {String? subtitle, Widget? actionButton}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green[700]),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  // Metodi helper
  Future<CoasterModel?> _getUserCurrentCoaster(String uid) async {
    try {
      return await _dbService.getUserCoaster(uid);
    } catch (e) {
      debugPrint('Error getting user coaster: $e');
      return null;
    }
  }

  Future<List<String>> _getPresentIngredientNames(List<ParticipantModel> participants) async {
    List<String> ingredientNames = [];

    for (var participant in participants) {
      try {
        final ingredientName = await _dbService.getIngredientNameById(participant.ingredientId);
        ingredientNames.add(ingredientName);
      } catch (e) {
        debugPrint('Error getting ingredient name for ${participant.ingredientId}: $e');
        ingredientNames.add('Ingrediente sconosciuto');
      }
    }

    return ingredientNames;
  }

  // Metodi QR Scanner
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _handleQRCode(scanData.code!);
      }
    });
  }

  void _handleQRCode(String qrData) {
    setState(() {
      _isProcessing = true;
      _lastError = null;
    });

    try {
      debugPrint('🔍 QR Code scanned: $qrData');

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(qrData);
      } catch (e) {
        setState(() {
          _scannedRoomId = qrData.trim();
          _isProcessing = false;
        });
        return;
      }

      if (data != null && data['type'] == 'potion_riders_room' && data['roomId'] != null) {
        setState(() {
          _scannedRoomId = data?['roomId'];
          _isProcessing = false;
        });
      } else {
        setState(() {
          _lastError = 'QR Code non valido per Potion Riders';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _lastError = 'Errore nella lettura del QR: $e';
        _isProcessing = false;
      });
    }
  }

  // Metodo di join
  Future<void> _joinRoomWithAutoConfirm(String roomId, String uid) async {
    debugPrint('🚀 Starting auto-join with confirmation...');

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastError = null;
    });

    try {
      final coaster = await _getUserCurrentCoaster(uid);
      if (coaster == null) {
        throw Exception('Nessun coaster trovato. Reclama un coaster prima di unirti a una stanza.');
      }

      debugPrint('🎯 Attempting to join room with coaster ingredient: ${coaster.ingredientId}');

      final result = await _dbService.joinRoomWithIngredientValidation(roomId, uid, coaster.ingredientId);

      if (result['success'] == true) {
        debugPrint('🎉 Join successful! Navigating to room management...');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Ti sei unito alla stanza con successo!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 1500));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RoomManagementScreen(roomId: roomId),
            ),
          );
        }
      } else {
        final error = result['error'] ?? 'Errore sconosciuto durante il join';
        debugPrint('❌ Join failed: $error');

        setState(() {
          _lastError = error;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint('❌ Exception during join process: $e');

      setState(() {
        _lastError = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}