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
  final TextEditingController _manualIdController = TextEditingController();

  QRViewController? controller;
  String? _scannedRoomId;
  bool _isProcessing = false;
  bool _showManualEntry = false;
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
    _manualIdController.dispose();
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
          ? _buildRoomDetails(uid)
          : _buildQRScanner(),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        // Messaggio di errore se presente
        if (_lastError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red[100],
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastError!,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _lastError = null),
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
          ),
        ),

        // Controlli
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Inquadra il QR code della stanza',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _showManualEntry = !_showManualEntry);
                        },
                        icon: Icon(_showManualEntry ? Icons.qr_code : Icons.keyboard),
                        label: Text(_showManualEntry ? 'Usa QR' : 'Inserisci ID'),
                      ),
                    ),
                  ],
                ),

                // Input manuale
                if (_showManualEntry) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID Stanza',
                      hintText: 'Inserisci l\'ID della stanza',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_manualIdController.text.isNotEmpty) {
                        setState(() {
                          _scannedRoomId = _manualIdController.text.trim();
                          _lastError = null;
                        });
                      }
                    },
                    child: const Text('Conferma'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isProcessing) return;

      setState(() {
        _isProcessing = true;
      });

      String? roomId = _extractRoomId(scanData.code);

      if (roomId != null) {
        setState(() {
          _scannedRoomId = roomId;
          _lastError = null;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _lastError = 'QR Code non valido per una stanza';
          _isProcessing = false;
        });
      }
    });
  }

  String? _extractRoomId(String? qrData) {
    if (qrData == null || qrData.isEmpty) return null;

    try {
      // Prova a decodificare come JSON
      final decoded = json.decode(qrData);
      if (decoded is Map && decoded.containsKey('roomId')) {
        return decoded['roomId'] as String;
      }
    } catch (e) {
      // Se non è JSON, potrebbe essere solo l'ID della stanza
      if (qrData.length <= 10 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(qrData)) {
        return qrData;
      }
    }

    return null;
  }

  Widget _buildRoomDetails(String uid) {
    return FutureBuilder<RoomModel?>(
      future: _dbService.getRoom(_scannedRoomId!).first,
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final room = roomSnapshot.data;
        if (room == null) {
          return _buildErrorCard(
            'Stanza Non Trovata',
            'La stanza con ID "$_scannedRoomId" non esiste o non è più disponibile.',
            Icons.error,
            Colors.red,
            actionButton: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _scannedRoomId = null;
                  _lastError = null;
                });
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scansiona Nuovo QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        return _buildRoomMatchingContent(room, uid);
      },
    );
  }

  Widget _buildRoomMatchingContent(RoomModel room, String uid) {
    return FutureBuilder<RecipeModel?>(
      future: _dbService.getRecipe(room.recipeId),
      builder: (context, recipeSnapshot) {
        final recipe = recipeSnapshot.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informazioni sulla stanza
              _buildRoomInfoCard(room),

              const SizedBox(height: 16),

              // Ricetta richiesta
              if (recipe != null) _buildRecipeCard(recipe, room),

              const SizedBox(height: 16),

              // Partecipanti attuali
              _buildParticipantsCard(room),

              const SizedBox(height: 16),

              // Controllo matching ingredienti
              _buildCoasterMatchingSection(context, room, recipe, uid),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoasterMatchingSection(BuildContext context, RoomModel room, RecipeModel? recipe, String uid) {
    return FutureBuilder<CoasterModel?>(
      future: _getUserCurrentCoaster(uid),
      builder: (context, coasterSnapshot) {
        final coaster = coasterSnapshot.data;

        // Controlli di base
        if (room.isCompleted) {
          return _buildErrorCard(
            'Stanza Completata',
            'Questa stanza è già stata completata e non accetta nuovi partecipanti.',
            Icons.check_circle,
            Colors.green,
            actionButton: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.home),
              label: const Text('Torna alla Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        if (coaster == null) {
          return _buildErrorCard(
            'Nessun Sottobicchiere',
            'Non hai reclamato nessun sottobicchiere. Scansiona il QR code di un sottobicchiere per iniziare a giocare.',
            Icons.warning,
            Colors.orange,
            actionButton: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.home),
              label: const Text('Torna alla Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        // Controlla se sta usando il coaster come ingrediente
        if (coaster.usedAs != 'ingredient') {
          return _buildErrorCard(
            'Sottobicchiere come Pozione',
            'Stai usando il tuo sottobicchiere come pozione. Per unirti a una stanza, devi usarlo come ingrediente.',
            Icons.science,
            Colors.purple,
            actionButton: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.flip),
              label: const Text('Cambia in Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        // Ora verifica il matching con la ricetta
        if (recipe != null) {
          return _buildCoasterIngredientMatchingCard(room, recipe, coaster, uid);
        }

        return _buildErrorCard(
          'Ricetta Non Trovata',
          'Impossibile caricare la ricetta di questa stanza.',
          Icons.error,
          Colors.red,
        );
      },
    );
  }

  /// Ottiene il coaster attualmente usato dall'utente
  Future<CoasterModel?> _getUserCurrentCoaster(String uid) async {
    try {
      // Usa il metodo corretto del DatabaseService
      return await _dbService.getUserCoaster(uid);
    } catch (e) {
      debugPrint('Error getting user coaster: $e');
      return null;
    }
  }

  /// METODO CORRETTO: Matching degli ingredienti
  Widget _buildCoasterIngredientMatchingCard(RoomModel room, RecipeModel recipe, CoasterModel coaster, String uid) {
    // Ottieni l'ingrediente dal coaster (ID dell'ingrediente sul retro)
    final userIngredientId = coaster.ingredientId;

    // Converti l'ID dell'ingrediente dell'utente nel nome
    return FutureBuilder<String>(
      future: _dbService.getIngredientNameById(userIngredientId),
      builder: (context, userIngredientSnapshot) {
        if (userIngredientSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userIngredientName = userIngredientSnapshot.data ?? 'Ingrediente sconosciuto';

        // Ora ottieni i nomi degli ingredienti già presenti nella stanza
        return FutureBuilder<List<String>>(
          future: _getPresentIngredientNames(room.participants),
          builder: (context, presentIngredientsSnapshot) {
            if (presentIngredientsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final presentIngredientNames = presentIngredientsSnapshot.data ?? [];

            // ========== CONTROLLI DI MATCHING ==========

            // 1. Controlla se l'ingrediente dell'utente è richiesto dalla ricetta
            final isIngredientRequired = recipe.requiredIngredients.contains(userIngredientName);

            // 2. Controlla se l'ingrediente è già presente tra i partecipanti
            final isIngredientAlreadyPresent = presentIngredientNames.contains(userIngredientName);

            // 3. Controlla se la stanza è piena
            final isRoomFull = room.participants.length >= 3;

            // 4. Controlla se l'utente è già partecipante
            final isUserAlreadyParticipant = room.participants.any((p) => p.userId == uid);

            // ========== GESTIONE DEI CASI ==========

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

            // CASO 2: Ingrediente non richiesto dalla ricetta
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

            // CASO 5: MATCH PERFETTO - L'utente può unirsi!
            return _buildSuccessCard(
              'Perfetto Match!',
              'Il tuo ingrediente "$userIngredientName" è necessario per questa ricetta!',
              subtitle: 'Progresso: ${room.participants.length + 1}/3 ingredienti',
              actionButton: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _joinRoomWithQR(room.id, uid),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Join con QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _joinRoomWithId(room.id, uid),
                          icon: const Icon(Icons.login),
                          label: const Text('Join Diretto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 8),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Converte gli ID degli ingredienti dei partecipanti nei nomi
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
            _buildInfoRow('Stato', room.isCompleted ? 'Completata' : 'In corso'),
            _buildInfoRow('Partecipanti', '${room.participants.length}/3'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe, RoomModel room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  'Ricetta da Completare',
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
                fontWeight: FontWeight.w600,
              ),
            ),
            if (recipe.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                recipe.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Ingredienti necessari:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...recipe.requiredIngredients.map((ingredientName) {
              // Controlla se questo ingrediente è già presente
              return FutureBuilder<List<String>>(
                future: _getPresentIngredientNames(room.participants),
                builder: (context, snapshot) {
                  final presentIngredients = snapshot.data ?? [];
                  final isPresent = presentIngredients.contains(ingredientName);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPresent ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPresent ? Colors.green[200]! : Colors.orange[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPresent ? Icons.check_circle : Icons.schedule,
                          size: 16,
                          color: isPresent ? Colors.green[700] : Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ingredientName,
                          style: TextStyle(
                            color: isPresent ? Colors.green[700] : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(RoomModel room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Partecipanti (${room.participants.length}/3)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (room.participants.isEmpty)
              const Text(
                'Sei il primo!',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              )
            else
              ...room.participants.map((participant) => FutureBuilder<String>(
                future: _dbService.getIngredientNameById(participant.ingredientId),
                builder: (context, ingredientSnapshot) {
                  final ingredientName = ingredientSnapshot.data ?? 'Caricamento...';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          participant.hasConfirmed ? Icons.check_circle : Icons.schedule,
                          color: participant.hasConfirmed ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                participant.userId,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.eco, size: 14, color: Colors.green[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    ingredientName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          participant.hasConfirmed ? 'Confermato' : 'In attesa',
                          style: TextStyle(
                            fontSize: 12,
                            color: participant.hasConfirmed ? Colors.green[700] : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
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
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
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

  // ========== METODI DI JOIN ==========

  /// Join tramite QR Code
  Future<void> _joinRoomWithQR(String roomId, String uid) async {
    // Per ora implementa il join diretto
    // In futuro potresti aggiungere logica specifica per QR
    await _joinRoomWithId(roomId, uid);
  }

  /// Join tramite ID diretto
  Future<void> _joinRoomWithId(String roomId, String uid) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastError = null;
    });

    try {
      // Ottieni il coaster dell'utente
      final coaster = await _getUserCurrentCoaster(uid);
      if (coaster == null) {
        throw Exception('Nessun coaster trovato. Reclama un coaster prima di unirti a una stanza.');
      }

      // Usa il metodo del database service per il join validato
      await _dbService.joinRoomWithIngredientValidation(
          roomId,
          uid,
          coaster.ingredientId
      );

      // Successo! Vai alla gestione della stanza
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoomManagementScreen(roomId: roomId),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
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