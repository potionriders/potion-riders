import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'package:potion_riders/models/room_model.dart';
import 'package:potion_riders/models/coaster_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =============================================================================
  // USER MANAGEMENT
  // =============================================================================

  /// Controlla se l'utente ha permessi di amministratore
  Future<bool> isUserAdmin(String uid) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      return data['role'] == 'admin';
    }
    return false;
  }

  // NUOVO: Conferma partecipazione di un ingrediente in una stanza
  Future<void> confirmParticipation(String roomId, String userId) async {
    try {
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Stanza non trovata');
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      List<dynamic> participants = roomData['participants'] ?? [];

      // Trova e aggiorna il partecipante
      bool participantFound = false;
      for (int i = 0; i < participants.length; i++) {
        if (participants[i]['userId'] == userId) {
          participants[i]['hasConfirmed'] = true;
          participantFound = true;
          break;
        }
      }

      if (!participantFound) {
        throw Exception('Partecipante non trovato nella stanza');
      }

      await _db.collection('rooms').doc(roomId).update({
        'participants': participants,
      });

      debugPrint('✅ Participation confirmed for user $userId in room $roomId');
    } catch (e) {
      debugPrint('❌ Error confirming participation: $e');
      rethrow;
    }
  }

// NUOVO: Ottiene le stanze dove l'utente partecipa come ingrediente
  Stream<List<RoomModel>> getUserParticipatingRooms(String userId) {
    return _db
        .collection('rooms')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      List<RoomModel> participatingRooms = [];

      for (var doc in snapshot.docs) {
        final roomData = doc.data();
        final participants = roomData['participants'] as List<dynamic>? ?? [];

        // Controlla se l'utente è partecipante (non host)
        bool isParticipant = participants.any((p) =>
            p is Map<String, dynamic> &&
            p['userId'] == userId &&
            roomData['hostId'] != userId);

        if (isParticipant) {
          participatingRooms.add(RoomModel.fromMap(roomData, doc.id));
        }
      }

      return participatingRooms;
    });
  }

// MODIFICATO: Aggiorna il metodo per gestire le stanze dell'utente
  Stream<List<RoomModel>> getUserRooms(String userId) {
    return _db
        .collection('rooms')
        .where('hostId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Ottiene tutte le stanze dell'utente (create + partecipazioni)
  Stream<Map<String, List<RoomModel>>> getAllUserRooms(String userId) {
    late StreamController<Map<String, List<RoomModel>>> controller;

    List<RoomModel> hostingRooms = [];
    List<RoomModel> participatingRooms = [];

    StreamSubscription? hostingSubscription;
    StreamSubscription? participatingSubscription;

    void updateResult() {
      if (!controller.isClosed) {
        controller.add({
          'hosting': hostingRooms,
          'participating': participatingRooms,
        });
      }
    }

    controller = StreamController<Map<String, List<RoomModel>>>(
      onListen: () {
        hostingSubscription = getUserRooms(userId).listen((rooms) {
          hostingRooms = rooms;
          updateResult();
        });

        participatingSubscription =
            getUserParticipatingRooms(userId).listen((rooms) {
          participatingRooms = rooms;
          updateResult();
        });
      },
      onCancel: () {
        hostingSubscription?.cancel();
        participatingSubscription?.cancel();
      },
    );

    return controller.stream;
  }

// MODIFICATO: Controlla se la stanza è pronta per essere completata
  Stream<bool> isRoomReadyToComplete(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;

      RoomModel room = RoomModel.fromMap(snapshot.data()!, snapshot.id);
      return room.isReadyToComplete();
    });
  }

// NUOVO: Ottiene il numero di ingredienti confermati in una stanza
  Stream<int> getConfirmedIngredientsCount(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return 0;

      RoomModel room = RoomModel.fromMap(snapshot.data()!, snapshot.id);
      return room.getConfirmedIngredientsCount();
    });
  }

  Future<Map<String, dynamic>> validateIngredientMatch(String roomId, String userId) async {
    Map<String, dynamic> result = {
      'canJoin': false,
      'reason': '',
      'userIngredient': '',
      'requiredIngredients': <String>[],
      'presentIngredients': <String>[],
      'missingIngredients': <String>[],
    };

    try {
      debugPrint('🔍 Starting validation for roomId: $roomId, userId: $userId');

      // Step 1: Ottieni i dati della stanza
      final roomSnapshot = await _db.collection('rooms').doc(roomId).get();
      if (!roomSnapshot.exists) {
        result['reason'] = 'Stanza non trovata';
        debugPrint('❌ Room not found');
        return result;
      }

      final roomData = roomSnapshot.data() as Map<String, dynamic>;
      debugPrint('📋 Room data obtained');

      // Step 2: Ottieni i dati dell'utente
      final userSnapshot = await _db.collection('users').doc(userId).get();
      if (!userSnapshot.exists) {
        result['reason'] = 'Utente non trovato';
        debugPrint('❌ User not found');
        return result;
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      debugPrint('👤 User data obtained');

      // Step 3: Controlla l'ingrediente dell'utente
      final String? userIngredient = userData['currentIngredientId'] as String?;
      if (userIngredient == null || userIngredient.isEmpty) {
        result['reason'] = 'Non hai un ingrediente assegnato';
        debugPrint('❌ User has no ingredient assigned');
        return result;
      }

      debugPrint('🧪 User ingredient ID: $userIngredient');

      // Step 4: Converti l'ID dell'ingrediente utente in nome - CON DEBUG DETTAGLIATO
      String userIngredientName;
      try {
        debugPrint('🔍 Looking up ingredient name for ID: $userIngredient');
        userIngredientName = await getIngredientNameById(userIngredient);
        debugPrint('✅ User ingredient name resolved: $userIngredientName');
      } catch (e) {
        debugPrint('❌ ERRORE nel risolvere nome ingrediente utente: $e');
        result['reason'] = 'Errore nel recupero del nome ingrediente utente: $e';
        return result;
      }

      // Step 5: Ottieni la ricetta e i suoi ingredienti richiesti
      final String? recipeId = roomData['recipeId'] as String?;
      if (recipeId == null) {
        result['reason'] = 'Stanza senza ricetta associata';
        debugPrint('❌ Room has no recipe');
        return result;
      }

      debugPrint('🧪 Recipe ID: $recipeId');

      final recipeSnapshot = await _db.collection('recipes').doc(recipeId).get();
      if (!recipeSnapshot.exists) {
        result['reason'] = 'Ricetta non trovata';
        debugPrint('❌ Recipe not found');
        return result;
      }

      final recipeData = recipeSnapshot.data() as Map<String, dynamic>;
      List<String> requiredIngredients = List<String>.from(recipeData['requiredIngredients'] ?? []);
      result['requiredIngredients'] = requiredIngredients;

      debugPrint('📋 Required ingredients: $requiredIngredients');
      debugPrint('👤 User ingredient NAME: $userIngredientName');

      // Step 6: Controlla se l'ingrediente dell'utente è richiesto
      if (!requiredIngredients.contains(userIngredientName)) {
        result['reason'] = 'Il tuo ingrediente "$userIngredientName" non è richiesto da questa ricetta';
        debugPrint('❌ User ingredient not required');
        return result;
      }

      debugPrint('✅ User ingredient is required!');

      // Step 7: Analizza gli ingredienti già presenti - CON DEBUG DETTAGLIATO
      List<dynamic> participants = List<dynamic>.from(roomData['participants'] ?? []);
      Set<String> presentIngredientNames = {};

      debugPrint('👥 Found ${participants.length} participants');

      for (int i = 0; i < participants.length; i++) {
        final participant = participants[i];
        if (participant is Map<String, dynamic>) {
          try {
            String participantIngredientId = participant['ingredientId'] as String;
            debugPrint('🔍 Looking up ingredient name for participant $i with ID: $participantIngredientId');
            String participantIngredientName = await getIngredientNameById(participantIngredientId);
            presentIngredientNames.add(participantIngredientName);
            debugPrint('✅ Participant $i ingredient: $participantIngredientName');
          } catch (e) {
            debugPrint('❌ Error getting ingredient name for participant $i: $e');
            // Continua con il prossimo partecipante invece di fermarsi
          }
        }
      }

      result['presentIngredients'] = presentIngredientNames.toList();
      result['missingIngredients'] = requiredIngredients
          .where((ingredient) => !presentIngredientNames.contains(ingredient))
          .toList();

      debugPrint('✅ Present ingredient names: ${presentIngredientNames.toList()}');
      debugPrint('❌ Missing ingredient names: ${result['missingIngredients']}');

      // Step 8: Controlla se l'ingrediente è già presente
      if (presentIngredientNames.contains(userIngredientName)) {
        result['reason'] = 'Il tuo ingrediente "$userIngredientName" è già presente nella stanza';
        debugPrint('❌ User ingredient already present');
        return result;
      }

      // Step 9: TUTTO OK!
      result['canJoin'] = true;
      result['reason'] = 'Match perfetto! Il tuo ingrediente "$userIngredientName" è necessario e mancante.';
      result['userIngredient'] = userIngredientName;

      debugPrint('🎉 VALIDATION SUCCESS - User can join!');
      return result;

    } catch (e) {
      debugPrint('❌ ERRORE GENERALE in validateIngredientMatch: $e');
      result['reason'] = 'Errore durante la validazione: $e';
      return result;
    }
  }

  Future<Map<String, dynamic>> joinRoomWithIngredientValidation(
      String roomId, String userId, String ingredientId) async {
    try {
      debugPrint('🚀 Starting validated join room process...');
      debugPrint('   Room ID: $roomId');
      debugPrint('   User ID: $userId');
      debugPrint('   Ingredient: $ingredientId');

      // Step 1: Validazione completa con matching ingredienti
      final validation = await validateIngredientMatch(roomId, userId);

      if (!validation['canJoin']) {
        return {
          'success': false,
          'error': validation['reason'],
          'validation': validation,
        };
      }

      // Step 2: Double-check che l'ingrediente fornito corrisponda a quello dell'utente
      String ingredientName;
      try {
        ingredientName = await getIngredientNameById(ingredientId);
      } catch (e) {
        return {
          'success': false,
          'error': 'Errore nel recupero del nome ingrediente: $e',
          'validation': validation,
        };
      }

      if (validation['userIngredient'] != ingredientName) {
        return {
          'success': false,
          'error': 'L\'ingrediente fornito "$ingredientName" non corrisponde a quello assegnato "${validation['userIngredient']}"',
          'validation': validation,
        };
      }

      debugPrint('✅ Validation passed, proceeding with join...');

      try {
        // Verifica finale prima del join
        final roomSnapshot = await _db.collection('rooms').doc(roomId).get();
        if (!roomSnapshot.exists) {
          throw Exception('Stanza non trovata');
        }

        final roomData = roomSnapshot.data() as Map<String, dynamic>;
        List<dynamic> participants = List<dynamic>.from(roomData['participants'] ?? []);

        if (participants.length >= 3) {
          throw Exception('La stanza è piena');
        }

        // Verifica che l'utente non sia già presente
        bool userAlreadyPresent = participants.any((p) =>
        p is Map<String, dynamic> && p['userId'] == userId);
        if (userAlreadyPresent) {
          throw Exception('Sei già un partecipante di questa stanza');
        }

        debugPrint('🔄 Adding participant using arrayUnion...');

        String userName;
        try {
          final userDoc = await _db.collection('users').doc(userId).get();
          if (!userDoc.exists) {
            throw Exception('Utente non trovato');
          }
          final userData = userDoc.data() as Map<String, dynamic>;
          userName = userData['nickname'] ?? userData['email'] ?? 'Utente Sconosciuto';
        } catch (e) {
          userName = 'Utente Sconosciuto';
          debugPrint('⚠️ Could not get user name: $e');
        }

        Map<String, dynamic> newParticipant = {
          // ID (necessari per logica)
          'userId': userId,
          'ingredientId': ingredientId,

          'userName': userName,          // ← NUOVO
          'ingredientName': ingredientName,  // ← NUOVO

          // Metadati
          'hasConfirmed': true,
          'joinedAt': DateTime.now().millisecondsSinceEpoch,
        };

        // Update della room con arrayUnion
        await _db.collection('rooms').doc(roomId).update({
          'participants': FieldValue.arrayUnion([newParticipant]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Room updated successfully');

        // Aggiorna l'utente separatamente
        final userSnapshot = await _db.collection('users').doc(userId).get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.data() as Map<String, dynamic>;
          List<dynamic> userRooms = List<dynamic>.from(userData['rooms'] ?? []);
          if (!userRooms.contains(roomId)) {
            userRooms.add(roomId);
          }

          await _db.collection('users').doc(userId).update({
            'rooms': userRooms,
            'lastRoomJoined': roomId,
            'lastRoomJoinedAt': FieldValue.serverTimestamp(),
          });
        }

        return {
          'success': true,
          'message': 'Join completato con successo e partecipazione confermata automaticamente',
          'validation': validation,
          'roomId': roomId,
          'participantInfo': {
            'userName': userName,
            'ingredientName': ingredientName,
          },
        };

      } catch (joinError) {
        debugPrint('❌ Error during join: $joinError');
        return {
          'success': false,
          'error': 'Errore durante il join: $joinError',
          'validation': validation,
        };
      }

    } catch (e) {
      debugPrint('❌ Error in joinRoomWithIngredientValidation: $e');
      return {
        'success': false,
        'error': 'Errore durante la validazione: $e',
        'validation': null,
      };
    }
  }

  Future<Map<String, dynamic>> debugUserState(String userId) async {
    try {
      debugPrint('🔍 DEBUGGING USER STATE for: $userId');

      // 1. Controlla documento utente
      final userDoc = await _db.collection('users').doc(userId).get();
      Map<String, dynamic> userState = {
        'userExists': userDoc.exists,
        'userData': userDoc.exists ? userDoc.data() : null,
      };

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        debugPrint('👤 User data:');
        debugPrint('   currentRecipeId: ${userData['currentRecipeId']}');
        debugPrint('   currentIngredientId: ${userData['currentIngredientId']}');
      }

      // 2. Controlla coasters associati
      final coastersSnapshot = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .get();

      debugPrint('🃏 Coasters with claimedByUserId = $userId: ${coastersSnapshot.docs.length}');
      for (var doc in coastersSnapshot.docs) {
        final data = doc.data();
        debugPrint('   Coaster ${doc.id}:');
        debugPrint('     claimedByUserId: ${data['claimedByUserId']}');
        debugPrint('     isConsumed: ${data['isConsumed']}');
        debugPrint('     isActive: ${data['isActive']}');
        debugPrint('     usedAs: ${data['usedAs']}');
      }

      // 3. Controlla coasters con previousOwner
      final previousCoastersSnapshot = await _db
          .collection('coasters')
          .where('previousOwner', isEqualTo: userId)
          .get();


      userState['activeCoasters'] = coastersSnapshot.docs.length;
      userState['previousCoasters'] = previousCoastersSnapshot.docs.length;

      return userState;
    } catch (e) {
      debugPrint('❌ Error debugging user state: $e');
      return {'error': e.toString()};
    }
  }

  Future<void> completelyDisassociateHostCoaster(String userId) async {
    try {

      await _db.collection('users').doc(userId).update({
        'currentRecipeId': null,
        'currentIngredientId': null,
      });

      final coastersSnapshot = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .get();

      if (coastersSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No coasters found for user $userId');
        return;
      }

      // 3. PROCESSA OGNI COASTER trovato
      for (var coasterDoc in coastersSnapshot.docs) {
        final coasterId = coasterDoc.id;
        final coasterData = coasterDoc.data();


        // DISASSOCIAZIONE COMPLETA E DEFINITIVA
        await _db.collection('coasters').doc(coasterId).update({
          // RIMUOVI COMPLETAMENTE L'ASSOCIAZIONE
          'claimedByUserId': null,
          'usedAs': null,

          // MARCA COME CONSUMATO E STORICO
          'isConsumed': true,
          'consumedAt': FieldValue.serverTimestamp(),
          'previousOwner': userId,
          'completedAsPotion': true,
          'completionType': 'host_potion_completed',

          // BACKUP DEI DATI ORIGINALI
          'originalRecipeId': coasterData['recipeId'],
          'originalIngredientId': coasterData['ingredientId'],
        });

      }

    } catch (e) {
      debugPrint('❌ CRITICAL ERROR in completelyDisassociateHostCoaster: $e');
      rethrow;
    }
  }

  // METODI FACILITATORE DA AGGIUNGERE AL DatabaseService

// =============================================================================
// FACILITATOR METHODS
// =============================================================================

  /// Controlla se un utente è un facilitatore (automaticamente se è admin)
  Future<bool> isFacilitator(String userId) async {
    // Semplice: se sei admin, sei anche facilitatore
    return await isUserAdmin(userId);
  }

  /// Ottieni tutte le stanze aperte che necessitano ingredienti
  Future<List<Map<String, dynamic>>> getRoomsNeedingIngredients() async {
    try {
      debugPrint('🔍 Finding rooms needing ingredients...');

      // Ottieni tutte le stanze non completate
      final roomsSnapshot = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> roomsNeedingHelp = [];

      for (var roomDoc in roomsSnapshot.docs) {
        final roomData = roomDoc.data();
        final roomId = roomDoc.id;

        // Controlla se la stanza ha bisogno di ingredienti
        final participants = List<dynamic>.from(roomData['participants'] ?? []);
        final maxParticipants = 3;

        if (participants.length < maxParticipants) {
          try {
            // Ottieni informazioni sulla ricetta
            final recipeId = roomData['recipeId'] as String;
            final recipeDoc = await _db.collection('recipes').doc(recipeId).get();

            if (recipeDoc.exists) {
              final recipeData = recipeDoc.data() as Map<String, dynamic>;
              final requiredIngredients = List<String>.from(recipeData['requiredIngredients'] ?? []);

              // Calcola ingredienti mancanti
              Set<String> presentIngredients = {};
              for (var participant in participants) {
                if (participant is Map<String, dynamic>) {
                  final ingredientName = participant['ingredientName'] as String?;
                  if (ingredientName != null && ingredientName.isNotEmpty) {
                    presentIngredients.add(ingredientName);
                  }
                }
              }

              final missingIngredients = requiredIngredients
                  .where((ingredient) => !presentIngredients.contains(ingredient))
                  .toList();

              if (missingIngredients.isNotEmpty) {
                roomsNeedingHelp.add({
                  'roomId': roomId,
                  'roomData': roomData,
                  'recipeData': recipeData,
                  'participantsCount': participants.length,
                  'missingIngredients': missingIngredients,
                  'nextIngredientNeeded': missingIngredients.first, // Il primo che manca
                  'presentIngredients': presentIngredients.toList(),
                });
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error processing room $roomId: $e');
            // Continua con la prossima stanza
          }
        }
      }

      // Ordina per urgenza (stanze più piene prima)
      roomsNeedingHelp.sort((a, b) =>
          b['participantsCount'].compareTo(a['participantsCount']));

      debugPrint('✅ Found ${roomsNeedingHelp.length} rooms needing ingredients');
      return roomsNeedingHelp;

    } catch (e) {
      debugPrint('❌ Error getting rooms needing ingredients: $e');
      return [];
    }
  }

  /// Facilitatore completa automaticamente il primo ingrediente mancante in una stanza
  Future<Map<String, dynamic>> facilitatorCompleteIngredient(String facilitatorId, String roomId) async {
    try {
      debugPrint('🤝 Facilitator $facilitatorId completing ingredient in room $roomId');

      // 1. Verifica che sia un facilitatore
      if (!await isFacilitator(facilitatorId)) {
        return {
          'success': false,
          'error': 'Non hai i permessi di facilitatore',
        };
      }

      // 2. Ottieni dati della stanza
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        return {
          'success': false,
          'error': 'Stanza non trovata',
        };
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final participants = List<dynamic>.from(roomData['participants'] ?? []);

      if (participants.length >= 3) {
        return {
          'success': false,
          'error': 'La stanza è già piena',
        };
      }

      // 3. Verifica che il facilitatore non sia già nella stanza
      final isAlreadyParticipant = participants.any((p) =>
      p is Map<String, dynamic> && p['userId'] == facilitatorId);

      if (isAlreadyParticipant) {
        return {
          'success': false,
          'error': 'Sei già un partecipante di questa stanza',
        };
      }

      // 4. Calcola quale ingrediente manca
      final recipeId = roomData['recipeId'] as String;
      final recipeDoc = await _db.collection('recipes').doc(recipeId).get();

      if (!recipeDoc.exists) {
        return {
          'success': false,
          'error': 'Ricetta non trovata',
        };
      }

      final recipeData = recipeDoc.data() as Map<String, dynamic>;
      final requiredIngredients = List<String>.from(recipeData['requiredIngredients'] ?? []);

      // Trova ingredienti già presenti
      Set<String> presentIngredients = {};
      for (var participant in participants) {
        if (participant is Map<String, dynamic>) {
          final ingredientName = participant['ingredientName'] as String?;
          if (ingredientName != null && ingredientName.isNotEmpty) {
            presentIngredients.add(ingredientName);
          }
        }
      }

      // Trova il primo ingrediente mancante
      final missingIngredients = requiredIngredients
          .where((ingredient) => !presentIngredients.contains(ingredient))
          .toList();

      if (missingIngredients.isEmpty) {
        return {
          'success': false,
          'error': 'Tutti gli ingredienti sono già presenti',
        };
      }

      final ingredientToComplete = missingIngredients.first;

      // 5. Trova l'ID dell'ingrediente
      final ingredientsSnapshot = await _db
          .collection('ingredients')
          .where('name', isEqualTo: ingredientToComplete)
          .limit(1)
          .get();

      if (ingredientsSnapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'Ingrediente "$ingredientToComplete" non trovato nel database',
        };
      }

      final ingredientId = ingredientsSnapshot.docs.first.id;

      // 6. Ottieni nome facilitatore
      final facilitatorDoc = await _db.collection('users').doc(facilitatorId).get();
      if (!facilitatorDoc.exists) {
        return {
          'success': false,
          'error': 'Facilitatore non trovato',
        };
      }

      final facilitatorData = facilitatorDoc.data() as Map<String, dynamic>;
      final facilitatorName = facilitatorData['nickname'] ?? facilitatorData['email'] ?? 'Facilitatore';

      // 7. Aggiungi il facilitatore come partecipante
      final newParticipant = {
        'userId': facilitatorId,
        'ingredientId': ingredientId,
        'userName': facilitatorName,
        'ingredientName': ingredientToComplete,
        'hasConfirmed': true,
        'joinedAt': DateTime.now().millisecondsSinceEpoch,
        'isFacilitator': true, // Flag speciale
      };

      await _db.collection('rooms').doc(roomId).update({
        'participants': FieldValue.arrayUnion([newParticipant]),
        'lastUpdated': FieldValue.serverTimestamp(),
        'facilitatorHelped': true,
      });

      // 8. Log dell'azione facilitatore
      try {
        await _db.collection('facilitator_logs').add({
          'facilitatorId': facilitatorId,
          'facilitatorName': facilitatorName,
          'action': 'completed_ingredient',
          'roomId': roomId,
          'ingredientCompleted': ingredientToComplete,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ Error creating facilitator log: $e');
        // Non critico, continua
      }

      debugPrint('✅ Facilitator completed ingredient: $ingredientToComplete');

      return {
        'success': true,
        'ingredientCompleted': ingredientToComplete,
        'roomId': roomId,
        'participantsCount': participants.length + 1,
        'message': 'Ingrediente "$ingredientToComplete" completato con successo!',
      };

    } catch (e) {
      debugPrint('❌ Error in facilitator completion: $e');
      return {
        'success': false,
        'error': 'Errore durante il completamento: $e',
      };
    }
  }

  /// Scanner QR per facilitatori - scansiona stanza e completa ingrediente
  Future<Map<String, dynamic>> facilitatorScanAndComplete(String facilitatorId, String qrCode) async {
    try {
      debugPrint('📱 Facilitator scanning QR: $qrCode');

      // 1. Verifica che sia un facilitatore
      if (!await isFacilitator(facilitatorId)) {
        return {
          'success': false,
          'error': 'Non hai i permessi di facilitatore',
        };
      }

      // 2. Estrai room ID dal QR code
      String roomId = qrCode.trim();

      // Se il QR è un URL, estrai l'ID
      if (qrCode.contains('/room/')) {
        try {
          final uri = Uri.parse(qrCode);
          roomId = uri.pathSegments.last;
        } catch (e) {
          debugPrint('⚠️ Error parsing QR URL: $e');
          // Continua con il QR originale
        }
      }

      // Se il QR contiene altri pattern, puliscilo
      if (roomId.contains('?')) {
        roomId = roomId.split('?').first;
      }

      debugPrint('🎯 Extracted room ID: $roomId');

      // 3. Verifica che la stanza esista
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        return {
          'success': false,
          'error': 'Stanza non trovata. Verifica il QR code.',
        };
      }

      // 4. Completa automaticamente l'ingrediente
      final result = await facilitatorCompleteIngredient(facilitatorId, roomId);

      return result;

    } catch (e) {
      debugPrint('❌ Error in facilitator scan: $e');
      return {
        'success': false,
        'error': 'Errore durante la scansione: $e',
      };
    }
  }

  /// Ottieni statistiche per facilitatori
  Future<Map<String, dynamic>> getFacilitatorStats(String facilitatorId) async {
    try {
      // Statistiche dalle azioni del facilitatore
      final logsSnapshot = await _db
          .collection('facilitator_logs')
          .where('facilitatorId', isEqualTo: facilitatorId)
          .get();

      int totalIngredientsCompleted = 0;
      Map<String, int> ingredientCounts = {};

      for (var log in logsSnapshot.docs) {
        final data = log.data();
        if (data['action'] == 'completed_ingredient') {
          totalIngredientsCompleted++;
          final ingredient = data['ingredientCompleted'] as String;
          ingredientCounts[ingredient] = (ingredientCounts[ingredient] ?? 0) + 1;
        }
      }

      // Stanze attualmente bisognose di aiuto
      final roomsNeedingHelp = await getRoomsNeedingIngredients();

      return {
        'totalIngredientsCompleted': totalIngredientsCompleted,
        'ingredientBreakdown': ingredientCounts,
        'roomsCurrentlyNeedingHelp': roomsNeedingHelp.length,
        'roomsNeedingHelp': roomsNeedingHelp.take(5).toList(), // Prime 5
      };

    } catch (e) {
      debugPrint('❌ Error getting facilitator stats: $e');
      return {};
    }
  }

  /// Ottieni statistiche rapide per il pannello admin
  Future<Map<String, dynamic>> getFacilitatorQuickStats() async {
    try {
      // Stanze attive
      final activeRoomsSnapshot = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: false)
          .get();

      // Stanze bisognose
      final roomsNeedingHelp = await getRoomsNeedingIngredients();

      // Completamenti oggi
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final completedTodaySnapshot = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: true)
          .where('completedAt', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      return {
        'activeRooms': activeRoomsSnapshot.docs.length,
        'roomsNeedingHelp': roomsNeedingHelp.length,
        'completedToday': completedTodaySnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('❌ Error getting facilitator quick stats: $e');
      return {
        'activeRooms': 0,
        'roomsNeedingHelp': 0,
        'completedToday': 0,
      };
    }
  }

  /// Ottieni tutte le statistiche per il pannello admin
  Future<Map<String, dynamic>> getOverallStats() async {
    try {
      // Utenti totali
      final usersSnapshot = await _db.collection('users').get();

      // Coasters attivi
      final activeCoastersSnapshot = await _db
          .collection('coasters')
          .where('isActive', isEqualTo: true)
          .where('claimedByUserId', isNotEqualTo: null)
          .get();

      // Completamenti totali
      final completionsSnapshot = await _db.collection('completions').get();

      // Stanze completate
      final completedRoomsSnapshot = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: true)
          .get();

      return {
        'totalUsers': usersSnapshot.docs.length,
        'activeCoasters': activeCoastersSnapshot.docs.length,
        'completedPotions': completedRoomsSnapshot.docs.length,
        'totalCompletions': completionsSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('❌ Error getting overall stats: $e');
      return {
        'totalUsers': 0,
        'activeCoasters': 0,
        'completedPotions': 0,
        'totalCompletions': 0,
      };
    }
  }

  /// Rimuovi un facilitatore da una stanza (se necessario)
  Future<Map<String, dynamic>> removeFacilitatorFromRoom(String facilitatorId, String roomId) async {
    try {
      debugPrint('🗑️ Removing facilitator $facilitatorId from room $roomId');

      // Verifica permessi
      if (!await isFacilitator(facilitatorId)) {
        return {
          'success': false,
          'error': 'Non hai i permessi di facilitatore',
        };
      }

      // Ottieni dati stanza
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        return {
          'success': false,
          'error': 'Stanza non trovata',
        };
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      List<dynamic> participants = List.from(roomData['participants'] ?? []);

      // Trova e rimuovi il facilitatore
      final initialLength = participants.length;
      participants.removeWhere((participant) =>
      participant is Map<String, dynamic> &&
          participant['userId'] == facilitatorId &&
          participant['isFacilitator'] == true);

      if (participants.length == initialLength) {
        return {
          'success': false,
          'error': 'Facilitatore non trovato nella stanza',
        };
      }

      // Aggiorna la stanza
      await _db.collection('rooms').doc(roomId).update({
        'participants': participants,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Log dell'azione
      try {
        await _db.collection('facilitator_logs').add({
          'facilitatorId': facilitatorId,
          'action': 'removed_from_room',
          'roomId': roomId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ Error creating removal log: $e');
      }

      debugPrint('✅ Facilitator removed from room');

      return {
        'success': true,
        'message': 'Facilitatore rimosso dalla stanza con successo',
      };

    } catch (e) {
      debugPrint('❌ Error removing facilitator from room: $e');
      return {
        'success': false,
        'error': 'Errore durante la rimozione: $e',
      };
    }
  }

  /// Ottieni cronologia delle azioni facilitatore
  Future<List<Map<String, dynamic>>> getFacilitatorHistory(String facilitatorId, {int limit = 20}) async {
    try {
      final logsSnapshot = await _db
          .collection('facilitator_logs')
          .where('facilitatorId', isEqualTo: facilitatorId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return logsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'action': data['action'],
          'roomId': data['roomId'],
          'ingredientCompleted': data['ingredientCompleted'],
          'timestamp': data['timestamp'],
          ...data,
        };
      }).toList();

    } catch (e) {
      debugPrint('❌ Error getting facilitator history: $e');
      return [];
    }
  }

  /// METODO PULITO per completare la stanza
  Future<void> completeRoomAndFreeSlots(String roomId, String currentUserId) async {
    try {
      debugPrint('🎉 STARTING room completion - Room: $roomId, User: $currentUserId');

      // 1. Ottieni dati stanza
      DocumentSnapshot roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Stanza non trovata');
      }

      RoomModel room = RoomModel.fromMap(roomDoc.data() as Map<String, dynamic>, roomDoc.id);
      debugPrint('   Host: ${room.hostId}');

      // 2. Segna stanza come completata
      await _db.collection('rooms').doc(roomId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': currentUserId,
      });
      debugPrint('✅ Room marked as completed');

      try {
        await updatePoints(room.hostId, 12);
        debugPrint('✅ Points assigned to host');

        for (ParticipantModel participant in room.participants) {
          await updatePoints(participant.userId, 3);
        }
        debugPrint('✅ Points assigned to participants');
      } catch (e) {
        debugPrint('⚠️ Error assigning points: $e');
      }

      await completelyDisassociateHostCoaster(room.hostId);


      // 5. Registra completamento per storico
      try {
        await createCompletionRecord(
          room.hostId,
          room.recipeId,
          room.participants.map((p) => p.userId).toList(),
        );
        debugPrint('✅ Completion recorded');
      } catch (e) {
        debugPrint('⚠️ Error recording completion: $e');
      }

      debugPrint('🎉 Room completion process FINISHED SUCCESSFULLY');

    } catch (e) {
      debugPrint('❌ CRITICAL ERROR in room completion: $e');
      rethrow;
    }
  }

  /// VERSIONE MINIMALE che fa solo l'essenziale
  Future<void> completeRoomMinimal(String roomId, String currentUserId) async {
    try {
      print('🚀 MINIMAL room completion');
      print('Room: $roomId, User: $currentUserId');

      // 1. Ottieni dati stanza
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Stanza non trovata');
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final hostId = roomData['hostId'] as String;
      final isCurrentUserHost = (currentUserId == hostId);

      print('Host: $hostId');
      print('Is current user host: $isCurrentUserHost');

      // 2. Segna stanza come completata
      await _db.collection('rooms').doc(roomId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': currentUserId,
      });
      print('✅ Room marked as completed');

      // 3. SOLO punti e pulizia - NIENTE assegnazione automatica
      if (isCurrentUserHost) {
        print('🎭 Processing as HOST');

        // Punti host (12)
        await _db.collection('users').doc(currentUserId).update({
          'points': FieldValue.increment(12),
        });
        print('✅ Host points added (12)');

        // Disassocia coaster e pulisci slot
        await cleanHostAfterCompletion(currentUserId);
        print('✅ Host cleaned after completion');

      } else {
        print('👤 Processing as PARTICIPANT');

        // Punti partecipante (3)
        await _db.collection('users').doc(currentUserId).update({
          'points': FieldValue.increment(3),
        });
        print('✅ Participant points added (3)');

        // Pulisci solo gli slot utente
        await _db.collection('users').doc(currentUserId).update({
          'currentRecipeId': null,
          'currentIngredientId': null,
        });
        print('✅ Participant slots cleared');
      }

      // 4. Completion record (solo se host)
      if (isCurrentUserHost) {
        try {
          await createCompletionRecordSimple(roomId, roomData);
          print('✅ Completion record created');
        } catch (e) {
          print('⚠️ Error creating completion record: $e');
          // Non critico, continua
        }
      }

      print('🎉 MINIMAL completion finished successfully');

    } catch (e) {
      print('❌ Error in minimal completion: $e');
      rethrow;
    }
  }

  /// Pulisce l'host dopo il completamento - SENZA assegnazione automatica
  Future<void> cleanHostAfterCompletion(String hostId) async {
    try {
      print('🧹 Cleaning host after completion: $hostId');

      // 1. Pulisci documento utente
      await _db.collection('users').doc(hostId).update({
        'currentRecipeId': null,
        'currentIngredientId': null,
      });
      print('✅ Host user document cleaned');

      // 2. Disassocia tutti i coasters dell'host
      final coastersSnapshot = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: hostId)
          .get();

      print('Found ${coastersSnapshot.docs.length} coasters to disassociate');

      for (var coasterDoc in coastersSnapshot.docs) {
        try {
          await _db.collection('coasters').doc(coasterDoc.id).update({
            'claimedByUserId': null,
            'usedAs': null,
            'isConsumed': true,
            'previousOwner': hostId,
            'consumedAt': FieldValue.serverTimestamp(),
            'completedAsPotion': true,
          });
          print('✅ Coaster ${coasterDoc.id} disassociated');
        } catch (e) {
          print('⚠️ Error disassociating coaster ${coasterDoc.id}: $e');
          // Continua con il prossimo
        }
      }

      print('🎉 Host cleaning completed');

      // NOTA: NON assegnamo automaticamente nuovi elementi
      // L'host dovrà scansionare un nuovo QR manualmente

    } catch (e) {
      print('❌ Error cleaning host: $e');
      throw e;
    }
  }

  /// Creazione completion record semplificata
  Future<void> createCompletionRecordSimple(String roomId, Map<String, dynamic> roomData) async {
    try {
      final participants = List<dynamic>.from(roomData['participants'] ?? []);
      final participantIds = participants
          .where((p) => p is Map<String, dynamic>)
          .map((p) => (p as Map<String, dynamic>)['userId'] as String)
          .toList();

      await _db.collection('completions').add({
        'roomId': roomId,
        'hostId': roomData['hostId'],
        'recipeId': roomData['recipeId'],
        'participantIds': participantIds,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error creating completion record: $e');
      // Non rilanciare - non è critico
    }
  }

  /// VERSIONE ULTRA-SEMPLICE per test immediato
  Future<void> completeRoomUltraSimple(String roomId, String currentUserId) async {
    try {
      print('⚡ ULTRA-SIMPLE completion');

      // 1. Segna stanza completata
      await _db.collection('rooms').doc(roomId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Room completed');

      // 2. Determina se sei host
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final isHost = (roomData['hostId'] == currentUserId);

      print('Is host: $isHost');

      // 3. Aggiorna SOLO te stesso
      if (isHost) {
        // Host: 12 punti + pulisci tutto
        await _db.collection('users').doc(currentUserId).update({
          'points': FieldValue.increment(12),
          'currentRecipeId': null,
          'currentIngredientId': null,
        });

        // Disassocia coaster
        final coastersSnapshot = await _db
            .collection('coasters')
            .where('claimedByUserId', isEqualTo: currentUserId)
            .get();

        for (var doc in coastersSnapshot.docs) {
          await _db.collection('coasters').doc(doc.id).update({
            'claimedByUserId': null,
            'isConsumed': true,
            'previousOwner': currentUserId,
          });
        }

        print('✅ Host processed');
      } else {
        // Partecipante: 3 punti + pulisci slot
        await _db.collection('users').doc(currentUserId).update({
          'points': FieldValue.increment(3),
          'currentRecipeId': null,
          'currentIngredientId': null,
        });

        print('✅ Participant processed');
      }

      print('🎉 ULTRA-SIMPLE completion done');

    } catch (e) {
      print('❌ ULTRA-SIMPLE completion error: $e');
      rethrow;
    }
  }

  /// Metodo per assegnare manualmente un nuovo elemento (da chiamare dopo)
  Future<void> manuallyAssignNewElement(String userId) async {
    try {
      print('🎲 Manually assigning new element to: $userId');

      // Verifica che l'utente esista
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User not found');
        return;
      }

      // Assegna elemento casuale
      final Random random = Random();
      final bool assignRecipe = random.nextBool();

      if (assignRecipe) {
        // Assegna ricetta casuale
        final recipesSnapshot = await _db.collection('recipes').limit(20).get();
        if (recipesSnapshot.docs.isNotEmpty) {
          final randomIndex = random.nextInt(recipesSnapshot.docs.length);
          final recipeId = recipesSnapshot.docs[randomIndex].id;

          await _db.collection('users').doc(userId).update({
            'currentRecipeId': recipeId,
            'currentIngredientId': null,
          });
          print('✅ Random recipe assigned');
        }
      } else {
        // Assegna ingrediente casuale
        final ingredientsSnapshot = await _db.collection('ingredients').limit(20).get();
        if (ingredientsSnapshot.docs.isNotEmpty) {
          final randomIndex = random.nextInt(ingredientsSnapshot.docs.length);
          final ingredientId = ingredientsSnapshot.docs[randomIndex].id;

          await _db.collection('users').doc(userId).update({
            'currentRecipeId': null,
            'currentIngredientId': ingredientId,
          });
          print('✅ Random ingredient assigned');
        }
      }

    } catch (e) {
      print('❌ Error manually assigning element: $e');
      rethrow;
    }
  }

  Future<bool> shouldUserSeeCoaster(String userId) async {
    try {
      // 1. Controlla documento utente
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final hasRecipe = userData['currentRecipeId'] != null;
      final hasIngredient = userData['currentIngredientId'] != null;

      // 2. Controlla coasters attivi
      final activeCoastersSnapshot = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .where('isConsumed', isEqualTo: false)
          .get();

      final hasActiveCoaster = activeCoastersSnapshot.docs.isNotEmpty;

      debugPrint('🔍 Should user $userId see coaster?');
      debugPrint('   hasRecipe: $hasRecipe');
      debugPrint('   hasIngredient: $hasIngredient');
      debugPrint('   hasActiveCoaster: $hasActiveCoaster');

      return (hasRecipe || hasIngredient) && hasActiveCoaster;
    } catch (e) {
      debugPrint('❌ Error checking if user should see coaster: $e');
      return false;
    }
  }

  Future<bool> canUserGetNewCoaster(String userId) async {
    try {
      // 1. Verifica che l'utente non abbia già un coaster attivo
      QuerySnapshot activeCoasterQuery = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .where('isConsumed', isEqualTo: false)
          .limit(1)
          .get();

      if (activeCoasterQuery.docs.isNotEmpty) {
        debugPrint('❌ User $userId already has an active coaster');
        return false;
      }

      // 2. Verifica che abbia un coaster consumato (precedente completamento)
      QuerySnapshot consumedCoasterQuery = await _db
          .collection('coasters')
          .where('previousOwner', isEqualTo: userId) // NUOVO: usa previousOwner
          .where('isConsumed', isEqualTo: true)
          .limit(1)
          .get();

      if (consumedCoasterQuery.docs.isEmpty) {
        debugPrint('❌ User $userId has no consumed coaster to exchange');
        return false;
      }

      debugPrint('✅ User $userId can get a new coaster');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking if user can get new coaster: $e');
      return false;
    }
  }

  /// NUOVO: Assegna un nuovo coaster a un utente che ha completato una pozione
  Future<bool> assignNewCoasterToUser(String userId) async {
    try {
      debugPrint('🔄 Assigning new coaster to user: $userId');

      // 1. Verifica che l'utente possa ottenere un nuovo coaster
      if (!await canUserGetNewCoaster(userId)) {
        return false;
      }

      // 2. Trova un coaster disponibile
      QuerySnapshot availableCoasterQuery = await _db
          .collection('coasters')
          .where('isActive', isEqualTo: true)
          .where('claimedByUserId', isEqualTo: null)
          .where('isConsumed', isEqualTo: false)
          .limit(1)
          .get();

      if (availableCoasterQuery.docs.isEmpty) {
        debugPrint('❌ No available coasters for assignment');
        return false;
      }

      String newCoasterId = availableCoasterQuery.docs.first.id;
      Map<String, dynamic> newCoasterData = availableCoasterQuery.docs.first.data() as Map<String, dynamic>;

      // 3. Assegna il nuovo coaster all'utente
      await _db.collection('coasters').doc(newCoasterId).update({
        'claimedByUserId': userId,
        'claimedAt': FieldValue.serverTimestamp(),
        'claimReason': 'new_coaster_after_completion',
      });

      // 4. Assegna elemento casuale all'utente basato sul nuovo coaster
      bool useAsRecipe = Random().nextBool(); // 50/50 chance

      if (useAsRecipe) {
        await _db.collection('users').doc(userId).update({
          'currentRecipeId': newCoasterData['recipeId'],
          'currentIngredientId': null,
        });
      } else {
        await _db.collection('users').doc(userId).update({
          'currentRecipeId': null,
          'currentIngredientId': newCoasterData['ingredientId'],
        });
      }

      // 5. Aggiorna il coaster con l'uso scelto
      await _db.collection('coasters').doc(newCoasterId).update({
        'usedAs': useAsRecipe ? 'recipe' : 'ingredient',
      });

      debugPrint('✅ New coaster $newCoasterId assigned to user $userId as ${useAsRecipe ? 'recipe' : 'ingredient'}');
      return true;
    } catch (e) {
      debugPrint('❌ Error assigning new coaster to user: $e');
      return false;
    }
  }

  /// UTILITY: Ottieni statistiche coaster per admin (con nuovo campo previousOwner)
  Future<Map<String, dynamic>> getCoasterStatistics() async {
    try {
      final allCoasters = await _db.collection('coasters').get();

      int totalCoasters = allCoasters.docs.length;
      int activeCoasters = 0;
      int claimedCoasters = 0;
      int consumedCoasters = 0;
      int availableCoasters = 0;
      int orphanedCoasters = 0; // Coasters con previousOwner ma utente non esiste

      for (var doc in allCoasters.docs) {
        final data = doc.data();

        if (data['isActive'] == true) activeCoasters++;
        if (data['claimedByUserId'] != null) claimedCoasters++;
        if (data['isConsumed'] == true) consumedCoasters++;
        if (data['isActive'] == true &&
            data['claimedByUserId'] == null &&
            data['isConsumed'] != true) {
          availableCoasters++;
        }

        // Controlla orphaned (con previousOwner ma utente non esiste)
        if (data['previousOwner'] != null) {
          final userDoc = await _db.collection('users').doc(data['previousOwner']).get();
          if (!userDoc.exists) orphanedCoasters++;
        }
      }

      return {
        'totalCoasters': totalCoasters,
        'activeCoasters': activeCoasters,
        'claimedCoasters': claimedCoasters,
        'consumedCoasters': consumedCoasters,
        'availableCoasters': availableCoasters,
        'orphanedCoasters': orphanedCoasters,
      };
    } catch (e) {
      debugPrint('❌ Error getting coaster statistics: $e');
      return {};
    }
  }

// NUOVO: Metodo per liberare lo slot di un singolo utente
  Future<void> _freeUserSlot(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'currentRecipeId': null,
        'currentIngredientId': null,
      });
      debugPrint('✅ Freed slot for user: $userId');
    } catch (e) {
      debugPrint('❌ Error freeing user slot for $userId: $e');
      // Non rilancia l'errore per non bloccare il completamento della stanza
    }
  }

// NUOVO: Metodo per liberare il proprio slot quando si vede una stanza completata
  Future<void> freeMySlotIfRoomCompleted(String userId) async {
    try {
      // Ottieni i dati dell'utente
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userRooms = List<String>.from(userData['rooms'] ?? []);

      // Controlla se l'utente è in stanze completate
      for (String roomId in userRooms) {
        final roomDoc = await _db.collection('rooms').doc(roomId).get();
        if (roomDoc.exists) {
          final roomData = roomDoc.data() as Map<String, dynamic>;
          final isCompleted = roomData['isCompleted'] ?? false;

          if (isCompleted) {
            // La stanza è completata, libera il tuo slot e assegna nuovo elemento
            await _freeUserSlot(userId);
            await assignRandomGameElement(userId);

            // Rimuovi la stanza completata dalla lista dell'utente
            userRooms.remove(roomId);
            await _db.collection('users').doc(userId).update({
              'rooms': userRooms,
            });

            debugPrint('✅ User $userId freed slot from completed room $roomId');
            break; // Esci dopo il primo match per evitare conflitti
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking/freeing slots for user $userId: $e');
    }
  }

  /// NUOVO: Consuma il sottobicchiere di un utente
  Future<void> consumeUserCoaster(String userId) async {
    try {
      // Trova il coaster dell'utente
      QuerySnapshot coasterQuery = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .where('isConsumed', isEqualTo: false)
          .limit(1)
          .get();

      if (coasterQuery.docs.isNotEmpty) {
        String coasterId = coasterQuery.docs.first.id;

        // Marca come consumato
        await _db.collection('coasters').doc(coasterId).update({
          'isConsumed': true,
          'consumedAt': FieldValue.serverTimestamp(),
        });

        // Rimuovi l'elemento corrente dall'utente
        await _db.collection('users').doc(userId).update({
          'currentRecipeId': null,
          'currentIngredientId': null,
        });
      }
    } catch (e) {
      debugPrint('Error consuming user coaster: $e');
      rethrow;
    }
  }

  /// NUOVO: Riconsegna un sottobicchiere consumato e assegna un nuovo sottobicchiere
  Future<bool> returnConsumedCoasterAndGetNew(String userId) async {
    try {
      // Verifica che l'utente abbia un coaster consumato
      QuerySnapshot consumedQuery = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .where('isConsumed', isEqualTo: true)
          .limit(1)
          .get();

      if (consumedQuery.docs.isEmpty) {
        debugPrint('Nessun sottobicchiere consumato trovato per l\'utente');
        return false;
      }

      String oldCoasterId = consumedQuery.docs.first.id;

      // "Riconsegna" il vecchio coaster (lo disconnettiamo dall'utente)
      await _db.collection('coasters').doc(oldCoasterId).update({
        'claimedByUserId': null,
        'usedAs': null,
      });

      // Trova un nuovo coaster disponibile
      QuerySnapshot availableQuery = await _db
          .collection('coasters')
          .where('isActive', isEqualTo: true)
          .where('claimedByUserId', isEqualTo: null)
          .where('isConsumed', isEqualTo: false)
          .limit(1)
          .get();

      if (availableQuery.docs.isEmpty) {
        debugPrint('Nessun sottobicchiere disponibile per la redistribuzione');
        return false;
      }

      String newCoasterId = availableQuery.docs.first.id;

      // Assegna il nuovo coaster all'utente
      await _db.collection('coasters').doc(newCoasterId).update({
        'claimedByUserId': userId,
      });

      // Reset dello stato utente
      await _db.collection('users').doc(userId).update({
        'currentRecipeId': null,
        'currentIngredientId': null,
      });

      return true;
    } catch (e) {
      debugPrint('Error returning coaster and getting new: $e');
      return false;
    }
  }

  /// NUOVO: Controlla se un utente può ottenere un nuovo sottobicchiere
  Future<bool> canGetNewCoaster(String userId) async {
    try {
      // Verifica che abbia un coaster consumato
      QuerySnapshot consumedQuery = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .where('isConsumed', isEqualTo: true)
          .limit(1)
          .get();

      return consumedQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if user can get new coaster: $e');
      return false;
    }
  }

  /// Ottieni le stanze compatibili per un utente basate sul suo ingrediente
  Future<List<Map<String, dynamic>>> getCompatibleRoomsForUser(
      String userId) async {
    try {
      debugPrint('🔍 Finding compatible rooms for user: $userId');

      // Ottieni l'ingrediente dell'utente
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('Utente non trovato');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userIngredient = userData['currentIngredientId'] as String?;

      if (userIngredient == null) {
        return []; // Nessun ingrediente = nessuna stanza compatibile
      }

      debugPrint('👤 User ingredient: $userIngredient');

      // Ottieni tutte le stanze attive
      final roomsSnapshot = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> compatibleRooms = [];

      for (var roomDoc in roomsSnapshot.docs) {
        final roomData = roomDoc.data();
        final roomId = roomDoc.id;

        // Salta se l'utente è l'host
        if (roomData['hostId'] == userId) continue;

        // Salta se la stanza è piena
        List<dynamic> participants = roomData['participants'] ?? [];
        if (participants.length >= 3) continue;

        // Salta se l'utente è già partecipante
        bool isParticipant = participants
            .any((p) => p is Map<String, dynamic> && p['userId'] == userId);
        if (isParticipant) continue;

        // Controlla la compatibilità degli ingredienti
        final validation = await validateIngredientMatch(roomId, userId);

        if (validation['canJoin']) {
          compatibleRooms.add({
            'roomId': roomId,
            'room': roomData,
            'validation': validation,
            'matchScore': _calculateMatchScore(validation),
          });
        }
      }

      // Ordina per score di compatibilità
      compatibleRooms
          .sort((a, b) => b['matchScore'].compareTo(a['matchScore']));

      debugPrint('✅ Found ${compatibleRooms.length} compatible rooms');
      return compatibleRooms;
    } catch (e) {
      debugPrint('❌ Error finding compatible rooms: $e');
      return [];
    }
  }

  /// Calcola un punteggio di compatibilità per una stanza
  int _calculateMatchScore(Map<String, dynamic> validation) {
    int score = 0;

    // Punti base se può unirsi
    if (validation['canJoin']) score += 100;

    // Punti bonus in base a quanti ingredienti mancano ancora
    List<String> missingIngredients =
        List<String>.from(validation['missingIngredients'] ?? []);
    score += missingIngredients.length *
        10; // Più ingredienti mancano, più interessante è la stanza

    // Punti bonus se la stanza ha già alcuni partecipanti (più vicina al completamento)
    List<String> presentIngredients =
        List<String>.from(validation['presentIngredients'] ?? []);
    score += presentIngredients.length * 5;

    return score;
  }

  /// Ottieni statistiche dettagliate di una ricetta
  Future<Map<String, dynamic>> getRecipeWithStats(String recipeId) async {
    try {
      final recipeDoc = await _db.collection('recipes').doc(recipeId).get();
      if (!recipeDoc.exists) {
        throw Exception('Ricetta non trovata');
      }

      final recipeData = recipeDoc.data() as Map<String, dynamic>;

      // Conta quante volte è stata completata
      final completionsSnapshot = await _db
          .collection('completions')
          .where('recipeId', isEqualTo: recipeId)
          .get();

      // Conta le stanze attive che usano questa ricetta
      final activeRoomsSnapshot = await _db
          .collection('rooms')
          .where('recipeId', isEqualTo: recipeId)
          .where('isCompleted', isEqualTo: false)
          .get();

      return {
        'recipe': recipeData,
        'completionCount': completionsSnapshot.docs.length,
        'activeRoomsCount': activeRoomsSnapshot.docs.length,
        'ingredients': List<String>.from(recipeData['ingredients'] ?? []),
        'popularity': completionsSnapshot.docs.length +
            (activeRoomsSnapshot.docs.length * 2),
      };
    } catch (e) {
      debugPrint('❌ Error getting recipe stats: $e');
      rethrow;
    }
  }

  /// Debug method per vedere tutte le informazioni di matching per un utente
  Future<Map<String, dynamic>> debugUserMatching(String userId) async {
    try {
      final result = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'userId': userId,
      };

      // Informazioni utente
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        result['user'] = {
          'exists': true,
          'nickname': userData['nickname'],
          'currentIngredientId': userData['currentIngredientId'],
          'rooms': userData['rooms'] ?? [],
          'canPlay': userData['currentIngredientId'] != null &&
              (userData['rooms'] as List? ?? []).isEmpty,
        };

        // Se l'utente può giocare, trova stanze compatibili
        if (result['user']['canPlay']) {
          result['compatibleRooms'] = await getCompatibleRoomsForUser(userId);
        }
      } else {
        result['user'] = {'exists': false};
      }

      // Statistiche generali
      final allRoomsSnapshot = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: false)
          .get();

      result['systemStats'] = {
        'totalActiveRooms': allRoomsSnapshot.docs.length,
        'availableRooms': allRoomsSnapshot.docs.where((doc) {
          final data = doc.data();
          List<dynamic> participants = data['participants'] ?? [];
          return participants.length < 3;
        }).length,
      };

      return result;
    } catch (e) {
      debugPrint('❌ Error in debug user matching: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Libera un utente da tutte le stanze attive in modo sicuro
  Future<void> safelyRemoveUserFromAllRooms(String userId) async {
    try {
      debugPrint('🧹 Safely removing user $userId from all rooms...');

      await _db.runTransaction((transaction) async {
        // Trova tutte le stanze attive
        final roomsSnapshot = await _db
            .collection('rooms')
            .where('isCompleted', isEqualTo: false)
            .get();

        for (var roomDoc in roomsSnapshot.docs) {
          final roomData = roomDoc.data();
          List<dynamic> participants =
              List.from(roomData['participants'] ?? []);

          // Rimuovi l'utente se presente
          bool userRemoved = false;
          participants.removeWhere((participant) {
            if (participant is Map<String, dynamic> &&
                participant['userId'] == userId) {
              userRemoved = true;
              return true;
            }
            return false;
          });

          // Se l'utente era presente, aggiorna la stanza
          if (userRemoved) {
            transaction.update(roomDoc.reference, {
              'participants': participants,
            });
            debugPrint('🗑️ Removed user from room: ${roomDoc.id}');
          }
        }

        // Aggiorna l'utente
        final userRef = _db.collection('users').doc(userId);
        transaction.update(userRef, {
          'rooms': [],
          'currentRecipeId': null,
        });
      });

      debugPrint('✅ User safely removed from all rooms');
    } catch (e) {
      debugPrint('❌ Error safely removing user from rooms: $e');
      rethrow;
    }
  }

  // Usa sottobicchiere (come pozione o ingrediente) - versione aggiornata
  Future<bool> useCoaster(String coasterId, String userId, String useAs) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('coasters').doc(coasterId).get();
      if (!doc.exists) return false;

      CoasterModel coaster =
          CoasterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // AGGIORNATO: Controlla anche che non sia consumato
      if (!coaster.isActive ||
          coaster.claimedByUserId != userId ||
          coaster.isConsumed) {
        return false; // Non attivo, non reclamato da questo utente, o già consumato
      }

      // Aggiorna il coaster con l'uso scelto
      await _db.collection('coasters').doc(coasterId).update({
        'usedAs': useAs,
      });

      // Aggiorna l'utente con l'elemento scelto
      if (useAs == 'recipe') {
        await _db.collection('users').doc(userId).update({
          'currentRecipeId': coaster.recipeId,
          'currentIngredientId': null,
        });
      } else if (useAs == 'ingredient') {
        await _db.collection('users').doc(userId).update({
          'currentIngredientId': coaster.ingredientId,
          'currentRecipeId': null,
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error using coaster: $e');
      return false;
    }
  }

  /// Cambia l'uso del sottobicchiere tra pozione e ingrediente - versione aggiornata
  Future<bool> switchCoasterUsage(
      String userId, String coasterId, bool useAsRecipe) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('coasters').doc(coasterId).get();
      if (!doc.exists) return false;

      CoasterModel coaster =
          CoasterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // AGGIORNATO: Verifica che il coaster appartenga all'utente e non sia consumato
      if (coaster.claimedByUserId != userId || coaster.isConsumed) {
        return false;
      }

      // Aggiorna l'uso del coaster
      String newUsage = useAsRecipe ? 'recipe' : 'ingredient';

      await _db.collection('coasters').doc(coasterId).update({
        'usedAs': newUsage,
      });

      // Aggiorna l'utente con l'elemento scelto
      if (useAsRecipe) {
        await _db.collection('users').doc(userId).update({
          'currentRecipeId': coaster.recipeId,
          'currentIngredientId': null,
        });
      } else {
        await _db.collection('users').doc(userId).update({
          'currentIngredientId': coaster.ingredientId,
          'currentRecipeId': null,
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error switching coaster usage: $e');
      return false;
    }
  }

  /// Ottiene il coaster dell'utente come stream - versione aggiornata
  Stream<CoasterModel?> getUserCoasterStream(String userId) {
    return _db
        .collection('coasters')
        .where('claimedByUserId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CoasterModel.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }

  /// Ottiene il coaster dell'utente - versione aggiornata
  Future<CoasterModel?> getUserCoaster(String userId) async {
    try {
      final snapshot = await _db
          .collection('coasters')
          .where('claimedByUserId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return CoasterModel.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('Errore nel recupero del coaster: $e');
      return null;
    }
  }

// =============================================================================
// OVERRIDE DEL METODO JOINROOM ESISTENTE
// =============================================================================

  /// Sovrascrive il metodo joinRoom esistente con la versione validata
  //@override
  //Future<void> joinRoom(
  //    String roomId, String userId, String ingredientId) async {
    //  await joinRoomWithIngredientValidation(roomId, userId, ingredientId);
  //}

  Future<bool> isItemClaimed(String itemId) async {
    // Controlla se è una ricetta
    QuerySnapshot recipeQuery = await _db
        .collection('users')
        .where('currentRecipeId', isEqualTo: itemId)
        .limit(1)
        .get();

    if (recipeQuery.docs.isNotEmpty) {
      return true;
    }

    // Controlla se è un ingrediente
    QuerySnapshot ingredientQuery = await _db
        .collection('users')
        .where('currentIngredientId', isEqualTo: itemId)
        .limit(1)
        .get();

    return ingredientQuery.docs.isNotEmpty;
  }

  Future<void> createUser(
    String uid,
    String email,
    String nickname,
    String photoUrl,
    String house, // NUOVO PARAMETRO CASATA
    String? role,
  ) async {
    try {
      final String gameUuid = const Uuid().v4();
      role ??= 'player';
      await _db.collection('users').doc(uid).set({
        'email': email,
        'nickname': nickname,
        'photoUrl': photoUrl,
        'house': house, // NUOVO CAMPO CASATA
        'role': role ,
        'points': 0,
        'gameUuid': gameUuid,
        'currentRecipeId': null,
        'currentIngredientId': null,
        'rooms': [],
        'completedRooms': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Verifichiamo che esistano ricette e ingredienti
      await seedGameElementsIfNeeded();

      // Assegniamo automaticamente un elemento di gioco
      await assignRandomGameElement(uid);
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

// AGGIUNGI questa nuova funzione per la classifica per casate:

  /// Ottiene la classifica per casate
  Stream<List<Map<String, dynamic>>> getHouseLeaderboard() {
    return _db.collection('users').snapshots().map((snapshot) {
      Map<String, Map<String, dynamic>> houseStats = {
        'Rospo Verde': {'totalPoints': 0, 'playerCount': 0, 'players': []},
        'Gatto Nero': {'totalPoints': 0, 'playerCount': 0, 'players': []},
        'Merlo d\'Oro': {'totalPoints': 0, 'playerCount': 0, 'players': []},
      };

      for (var doc in snapshot.docs) {
        final userData = doc.data();
        final house = userData['house'] as String? ?? 'Senza Casata';
        final points = userData['points'] as int? ?? 0;
        final nickname = userData['nickname'] as String? ?? 'Anonimo';

        if (houseStats.containsKey(house)) {
          houseStats[house]!['totalPoints'] =
              (houseStats[house]!['totalPoints'] as int) + points;
          houseStats[house]!['playerCount'] =
              (houseStats[house]!['playerCount'] as int) + 1;
          (houseStats[house]!['players'] as List).add({
            'nickname': nickname,
            'points': points,
          });
        }
      }

      // Converti in lista e ordina per punti totali
      List<Map<String, dynamic>> houseList = houseStats.entries.map((entry) {
        return {
          'house': entry.key,
          'totalPoints': entry.value['totalPoints'],
          'playerCount': entry.value['playerCount'],
          'averagePoints': entry.value['playerCount'] > 0
              ? (entry.value['totalPoints'] as int) /
                  (entry.value['playerCount'] as int)
              : 0.0,
          'players': entry.value['players'],
        };
      }).toList();

      houseList.sort((a, b) =>
          (b['totalPoints'] as int).compareTo(a['totalPoints'] as int));

      return houseList;
    });
  }

// AGGIUNGI questa funzione helper per ottenere le casate disponibili:

  /// Ottiene la lista delle casate disponibili
  List<Map<String, dynamic>> getAvailableHouses() {
    return [
      {
        'name': 'Rospo Verde',
        'description': 'Saggezza e Natura',
        'color': Colors.green,
        'icon': Icons.pets,
      },
      {
        'name': 'Gatto Nero',
        'description': 'Mistero e Astuzia',
        'color': Colors.purple,
        'icon': Icons.pets,
      },
      {
        'name': 'Merlo d\'Oro',
        'description': 'Coraggio e Lealtà',
        'color': Colors.amber,
        'icon': Icons.pets,
      },
    ];
  }

  /// SOSTITUISCI la funzione createCoasterWithId esistente
  Future<String> createCoasterWithId(
      String coasterId, String recipeId, String ingredientId) async {
    try {
      await _db.collection('coasters').doc(coasterId).set({
        'recipeId': recipeId,
        'ingredientId': ingredientId,
        'isActive': true,
        'claimedByUserId': null,
        'usedAs': null,
        'isConsumed': false, // NUOVO CAMPO
        'consumedAt': null, // NUOVO CAMPO
        'createdAt': FieldValue.serverTimestamp(),
      });

      return coasterId;
    } catch (e) {
      debugPrint('Error creating coaster with specific ID: $e');
      rethrow;
    }
  }

  /// SOSTITUISCI la funzione generateTestCoasters esistente
  Future<void> generateTestCoasters(String uid, int count) async {
    bool isAdmin = await isUserAdmin(uid);
    if (!isAdmin) {
      throw Exception(
          'Non hai i permessi di amministratore per eseguire questa operazione');
    }

    // Ottieni liste di ricette e ingredienti
    QuerySnapshot recipesSnapshot =
        await _db.collection('recipes').limit(60).get();
    QuerySnapshot ingredientsSnapshot =
        await _db.collection('ingredients').limit(60).get();

    List<String> recipeIds = recipesSnapshot.docs.map((doc) => doc.id).toList();
    List<String> ingredientIds =
        ingredientsSnapshot.docs.map((doc) => doc.id).toList();

    if (recipeIds.isEmpty || ingredientIds.isEmpty) {
      throw Exception('Non ci sono ricette o ingredienti nel database');
    }

    // Crea batch per operazioni multiple
    WriteBatch batch = _db.batch();

    for (int i = 0; i < count; i++) {
      // Genera un ID personalizzato per ogni coaster
      String coasterId = _generateShortId();

      // Verifica che non esista già
      DocumentSnapshot existing =
          await _db.collection('coasters').doc(coasterId).get();
      int attempts = 0;
      while (existing.exists && attempts < 10) {
        coasterId = _generateShortId();
        existing = await _db.collection('coasters').doc(coasterId).get();
        attempts++;
      }

      if (attempts >= 10) {
        debugPrint('Impossibile generare ID univoco per coaster $i');
        continue;
      }

      DocumentReference coasterRef = _db.collection('coasters').doc(coasterId);

      int recipeIndex = i % recipeIds.length;
      int ingredientIndex = (i + 3) %
          ingredientIds.length; // Offset per evitare accoppiamenti ovvi

      batch.set(coasterRef, {
        'recipeId': recipeIds[recipeIndex],
        'ingredientId': ingredientIds[ingredientIndex],
        'isActive': true,
        'claimedByUserId': null,
        'usedAs': null,
        'isConsumed': false, // NUOVO CAMPO
        'consumedAt': null, // NUOVO CAMPO
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// AGGIUNGI questa nuova funzione
  Future<Map<String, int>> getCoasterStats() async {
    try {
      QuerySnapshot allCoasters = await _db.collection('coasters').get();

      int total = allCoasters.docs.length;
      int active = 0;
      int claimed = 0;
      int consumed = 0;
      int available = 0;

      for (var doc in allCoasters.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isActive = data['isActive'] ?? true;
        final isClaimed = data['claimedByUserId'] != null;
        final isConsumed = data['isConsumed'] ?? false;

        if (isActive) active++;
        if (isClaimed) claimed++;
        if (isConsumed) consumed++;
        if (isActive && !isClaimed && !isConsumed) available++;
      }

      return {
        'total': total,
        'active': active,
        'claimed': claimed,
        'consumed': consumed,
        'available': available,
      };
    } catch (e) {
      debugPrint('Error getting coaster stats: $e');
      return {};
    }
  }

  /// Ottiene un utente dal database come stream
  Stream<UserModel?> getUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) =>
        snapshot.exists
            ? UserModel.fromMap(snapshot.data()!, snapshot.id)
            : null);
  }

  /// NUOVO: Aggiunge una stanza alla lista dell'utente
  Future<void> addRoomToUser(String userId, String roomId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'rooms': FieldValue.arrayUnion([roomId]),
      });
    } catch (e) {
      debugPrint('Error adding room to user: $e');
      rethrow;
    }
  }

  /// NUOVO: Rimuove una stanza dalla lista dell'utente (quando la stanza viene completata o abbandonata)
  Future<void> removeRoomFromUser(String userId, String roomId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'rooms': FieldValue.arrayRemove([roomId]),
      });
    } catch (e) {
      debugPrint('Error removing room from user: $e');
      rethrow;
    }
  }

  /// NUOVO: Aggiunge una stanza completata alla lista dell'utente
  Future<void> addCompletedRoomToUser(String userId, String roomId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'completedRooms': FieldValue.arrayUnion([roomId]),
      });
    } catch (e) {
      debugPrint('Error adding completed room to user: $e');
      rethrow;
    }
  }

  /// NUOVO: Ottiene le stanze completate di un utente
  Stream<List<RoomModel>> getUserCompletedRooms(String userId) {
    return getUser(userId).asyncMap((user) async {
      if (user == null || user.completedRooms.isEmpty) {
        return <RoomModel>[];
      }

      List<RoomModel> rooms = [];
      for (String roomId in user.completedRooms) {
        try {
          DocumentSnapshot roomDoc =
              await _db.collection('rooms').doc(roomId).get();
          if (roomDoc.exists) {
            rooms.add(RoomModel.fromMap(
                roomDoc.data() as Map<String, dynamic>, roomDoc.id));
          }
        } catch (e) {
          debugPrint('Error getting completed room $roomId: $e');
        }
      }

      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
    });
  }

  // =============================================================================
  // ROOM MANAGEMENT - AGGIORNATO
  // =============================================================================

  /// MIGLIORATO: Crea una nuova stanza e aggiorna l'utente
  Future<String> createRoom(String hostId, String recipeId) async {
    try {
      debugPrint(
          '🏗️ Starting room creation for host: $hostId, recipe: $recipeId');

      // Verifica che l'utente possa creare una stanza
      bool canCreate = await canCreateRoom(hostId);
      debugPrint('📝 Can create room: $canCreate');

      if (!canCreate) {
        throw Exception('User cannot create room - already in active room');
      }

      // PRIMA: Crea la stanza nel database
      debugPrint('📤 Creating room document in Firebase...');
      DocumentReference docRef = await _db.collection('rooms').add({
        'hostId': hostId,
        'recipeId': recipeId,
        'participants': [],
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
      });

      final roomId = docRef.id;
      debugPrint('✅ Room document created successfully with ID: $roomId');

      // DOPO: Aggiungi la stanza alla lista dell'utente (fallimento qui non deve bloccare la stanza)
      try {
        debugPrint('👤 Adding room to user...');
        await addRoomToUser(hostId, roomId);
        debugPrint('✅ Room added to user successfully');
      } catch (userUpdateError) {
        debugPrint(
            '⚠️ Warning: Room created but failed to update user: $userUpdateError');
        // La stanza esiste, ma l'utente potrebbe non avere il riferimento
        // Proviamo a recuperare in modo asincrono
        _retryAddRoomToUser(hostId, roomId);
      }

      return roomId;
    } catch (e) {
      debugPrint('❌ Error creating room: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> _retryAddRoomToUser(String userId, String roomId) async {
    // Retry asincrono fino a 3 volte
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        await addRoomToUser(userId, roomId);
        debugPrint('✅ Successfully added room to user on attempt $attempt');
        return;
      } catch (e) {
        debugPrint('⚠️ Retry $attempt failed: $e');
        if (attempt == 3) {
          debugPrint(
              '❌ All retries failed for adding room $roomId to user $userId');
        }
      }
    }
  }

  /// Ottiene una stanza specifica
  Stream<RoomModel?> getRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snapshot) =>
        snapshot.exists
            ? RoomModel.fromMap(snapshot.data()!, snapshot.id)
            : null);
  }

  /// MIGLIORATO: Completa una stanza e aggiorna tutti gli utenti coinvolti
  Future<void> completeRoom(String roomId) async {
    try {
      // Ottieni i dati della stanza
      DocumentSnapshot roomDoc =
          await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return;

      RoomModel room =
          RoomModel.fromMap(roomDoc.data() as Map<String, dynamic>, roomDoc.id);

      // Segna la stanza come completata
      await _db.collection('rooms').doc(roomId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Lista di tutti gli utenti coinvolti
      List<String> allUserIds = [room.hostId];
      allUserIds.addAll(room.participants.map((p) => p.userId));

      // Aggiorna ogni utente
      for (String userId in allUserIds) {
        await Future.wait([
          // Rimuovi dalla lista delle stanze attive
          removeRoomFromUser(userId, roomId),
          // Aggiungi alla lista delle stanze completate
          addCompletedRoomToUser(userId, roomId),
          // Assegna nuovi elementi casuali
          assignRandomGameElement(userId),
        ]);
      }

      // Assegna punti
      await updatePoints(room.hostId, 10);
      for (ParticipantModel participant in room.participants) {
        await updatePoints(participant.userId, 5);
      }

      // Registra il completamento
      await createCompletionRecord(
        room.hostId,
        room.recipeId,
        room.participants.map((p) => p.userId).toList(),
      );
    } catch (e) {
      debugPrint('Error completing room and updating users: $e');
      rethrow;
    }
  }

  /// MIGLIORATO: Abbandona una stanza (rimuove l'utente e aggiorna i riferimenti)
  Future<void> leaveRoom(String roomId, String userId) async {
    try {
      DocumentSnapshot roomDoc =
          await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return;

      Map<String, dynamic> data = roomDoc.data() as Map<String, dynamic>;

      // Se è l'host, elimina la stanza
      if (data['hostId'] == userId) {
        // Rimuovi la stanza da tutti i partecipanti
        List<dynamic> participants = data['participants'] ?? [];
        for (var participant in participants) {
          if (participant is Map<String, dynamic>) {
            await removeRoomFromUser(participant['userId'], roomId);
          }
        }

        // Elimina la stanza
        await _db.collection('rooms').doc(roomId).delete();
      } else {
        // Rimuovi il partecipante dalla stanza
        List<dynamic> participants = List.from(data['participants'] ?? []);
        participants.removeWhere(
            (p) => p is Map<String, dynamic> && p['userId'] == userId);

        await _db.collection('rooms').doc(roomId).update({
          'participants': participants,
        });
      }

      // Rimuovi la stanza dalla lista dell'utente
      await removeRoomFromUser(userId, roomId);

      // Assegna nuovo elemento casuale
      await assignRandomGameElement(userId);
    } catch (e) {
      debugPrint('Error leaving room: $e');
      rethrow;
    }
  }

  /// Verifica se un utente può creare una nuova stanza
  Future<bool> canCreateRoom(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;

      // CORREZIONE: Chi ha una ricetta (pozione) può sempre creare stanze
      final hasRecipe = userData['currentRecipeId'] != null &&
          userData['currentRecipeId'] != '';

      if (hasRecipe) {
        // Chi ha una pozione può sempre creare stanze per la sua ricetta
        return true;
      }

      // Chi ha solo ingredienti non può creare stanze (può solo unirsi)
      return false;
    } catch (e) {
      debugPrint('Error checking if user can create room: $e');
      return false;
    }
  }

  Future<void> syncUserRooms(String userId) async {
    try {
      debugPrint('🔄 Syncing rooms for user: $userId');

      // Trova tutte le stanze dove l'utente è host o partecipante
      QuerySnapshot hostRooms = await _db
          .collection('rooms')
          .where('hostId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      QuerySnapshot allActiveRooms = await _db
          .collection('rooms')
          .where('isCompleted', isEqualTo: false)
          .get();

      Set<String> userRooms = {};

      // Aggiungi stanze dove è host
      for (var doc in hostRooms.docs) {
        userRooms.add(doc.id);
      }

      // Aggiungi stanze dove è partecipante
      for (var doc in allActiveRooms.docs) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> participants = data['participants'] ?? [];

        for (var participant in participants) {
          if (participant is Map<String, dynamic> &&
              participant['userId'] == userId) {
            userRooms.add(doc.id);
            break;
          }
        }
      }

      // Aggiorna l'utente con le stanze trovate
      await _db.collection('users').doc(userId).update({
        'rooms': userRooms.toList(),
      });

      debugPrint('✅ User rooms synced: ${userRooms.toList()}');
    } catch (e) {
      debugPrint('❌ Error syncing user rooms: $e');
      rethrow;
    }
  }

  Future<String> createRoomSimple(String hostId, String recipeId) async {
    try {
      debugPrint(
          '🏗️ Creating simple room for host: $hostId, recipe: $recipeId');

      DocumentReference docRef = await _db.collection('rooms').add({
        'hostId': hostId,
        'recipeId': recipeId,
        'participants': [],
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
      });

      final roomId = docRef.id;
      debugPrint('✅ Simple room created with ID: $roomId');

      return roomId;
    } catch (e) {
      debugPrint('❌ Error creating simple room: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Verifica se un utente può unirsi a una stanza specifica
  Future<bool> canJoinSpecificRoom(String roomId, String userId) async {
    try {
      final room = await getRoom(roomId).first;

      if (room == null || room.isCompleted) {
        return false;
      }

      // Verifica se l'utente è già nella stanza
      if (room.participants.any((p) => p.userId == userId) ||
          room.hostId == userId) {
        return false;
      }

      // Verifica se c'è ancora spazio nella stanza
      if (room.participants.length >= 3) {
        return false;
      }

      // Verifica se l'utente non è già in un'altra stanza attiva
      return await canCreateRoom(userId);
    } catch (e) {
      debugPrint('Error checking if user can join specific room: $e');
      return false;
    }
  }

  /// NUOVO: Ottiene tutte le stanze aperte (non completate e con spazio disponibile)
  Stream<List<RoomModel>> getAllOpenRooms() {
    return _db
        .collection('rooms')
        .where('isCompleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomModel.fromMap(doc.data(), doc.id))
          .where((room) => room.participants.length < 3)
          .toList();
    });
  }


  Future<void> updatePoints(String uid, int additionalPoints) async {
    try {
      await _db.collection('users').doc(uid).update({
        'points': FieldValue.increment(additionalPoints),
      });
    } catch (e) {
      debugPrint('Error updating points: $e');
      rethrow;
    }
  }

  Future<void> updateUserNickname(String uid, String newNickname) async {
    try {
      // Verifica che il nuovo nickname sia unico
      final bool isUnique = await isNicknameUnique(newNickname);
      if (!isUnique) {
        throw Exception('Il nickname è già in uso');
      }

      // Aggiorna il nickname nel database
      await _db.collection('users').doc(uid).update({
        'nickname': newNickname,
      });

      debugPrint('Nickname updated successfully for user: $uid');
    } catch (e) {
      debugPrint('Error updating nickname: $e');
      rethrow;
    }
  }

  /// Aggiorna un campo specifico dell'utente
  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      await _db.collection('users').doc(uid).update({
        field: value,
      });
    } catch (e) {
      debugPrint('Error updating user field: $e');
      rethrow;
    }
  }

  /// Verifica l'unicità del nickname
  Future<bool> isNicknameUnique(String nickname) async {
    try {
      QuerySnapshot result = await _db
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();
      return result.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking nickname uniqueness: $e');
      return false;
    }
  }

  /// Ottiene informazioni dettagliate su un ingrediente tramite ID
  Future<String> getIngredientNameById(String ingredientId) async {
    try {
      debugPrint('🔍 getIngredientNameById called with ID: $ingredientId');

      final doc = await _db.collection('ingredients').doc(ingredientId).get();

      if (!doc.exists) {
        debugPrint('❌ Document not found for ingredient ID: $ingredientId');
        throw Exception('Ingrediente non trovato per ID: $ingredientId');
      }

      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String;

      debugPrint('✅ Found ingredient name: $name for ID: $ingredientId');
      return name;
    } catch (e) {
      debugPrint('❌ Error in getIngredientNameById for ID $ingredientId: $e');
      rethrow;
    }
  }

  /// Ottiene informazioni dettagliate su una ricetta tramite ID
  Future<String> getRecipeNameById(String recipeId) async {
    try {
      final recipe = await getRecipe(recipeId);
      return recipe?.name ?? 'Ricetta sconosciuta';
    } catch (e) {
      debugPrint('Error getting recipe name: $e');
      return 'Ricetta sconosciuta';
    }
  }

  /// Ottiene statistiche dell'utente
  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      // Conta le stanze completate come host
      QuerySnapshot hostCompletions = await _db
          .collection('completions')
          .where('hostId', isEqualTo: userId)
          .get();

      // Conta le stanze completate come partecipante
      QuerySnapshot allCompletions = await _db.collection('completions').get();
      int participantCompletions = 0;

      for (var doc in allCompletions.docs) {
        // Cast corretto con controllo null
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          List<dynamic> participants = data['participants'] ?? [];
          if (participants.contains(userId)) {
            participantCompletions++;
          }
        }
      }

      return {
        'totalCompletions':
            hostCompletions.docs.length + participantCompletions,
        'hostCompletions': hostCompletions.docs.length,
        'participantCompletions': participantCompletions,
      };
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {
        'totalCompletions': 0,
        'hostCompletions': 0,
        'participantCompletions': 0,
      };
    }
  }

  /// Ottiene la classifica con statistiche aggiuntive
  Stream<List<Map<String, dynamic>>> getDetailedLeaderboard() {
    return _db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> detailedUsers = [];

      for (var doc in snapshot.docs) {
        // Cast corretto con controllo null
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          UserModel user = UserModel.fromMap(data, doc.id);
          Map<String, int> stats = await getUserStats(user.id);

          detailedUsers.add({
            'user': user,
            'stats': stats,
          });
        }
      }

      return detailedUsers;
    });
  }

  /// Rimuove un partecipante da una stanza
  Future<void> removeParticipantFromRoom(String roomId, String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        // Cast corretto con controllo null
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          List<dynamic> participants = List.from(data['participants'] ?? []);

          // Rimuovi il partecipante dalla lista
          participants.removeWhere((participant) =>
              participant is Map<String, dynamic> &&
              participant['userId'] == userId);

          await _db.collection('rooms').doc(roomId).update({
            'participants': participants,
          });
        }
      }
    } catch (e) {
      debugPrint('Error removing participant from room: $e');
      rethrow;
    }
  }

  /// Dismette una stanza e rimuove tutti i partecipanti
  Future<void> dismissRoom(String roomId) async {
    try {
      await _db.collection('rooms').doc(roomId).update({
        'participants': [],
        'isCompleted': true,
        'dismissedAt': FieldValue.serverTimestamp(),
        'dismissReason': 'host_dismissed',
      });
    } catch (e) {
      debugPrint('Error dismissing room: $e');
      rethrow;
    }
  }

  /// Ottiene le stanze aperte (non completate e con posti disponibili)
  Stream<List<RoomModel>> getOpenRooms() {
    return _db
        .collection('rooms')
        .where('isCompleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomModel.fromMap(doc.data(), doc.id))
          .where((room) => room.participants.length < 3)
          .toList();
    });
  }

  /// Libera gli slot degli utenti quando una stanza viene completata o dismessa
  Future<void> freeUserSlots(List<String> userIds) async {
    try {
      WriteBatch batch = _db.batch();

      for (String userId in userIds) {
        DocumentReference userRef = _db.collection('users').doc(userId);
        batch.update(userRef, {
          'currentRecipeId': null,
          'currentIngredientId': null,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error freeing user slots: $e');
      rethrow;
    }
  }

  /// Reclama un coaster e lo assegna come elemento casuale
  /// Reclama un sottobicchiere con controlli di validazione
  Future<bool> claimCoaster(String coasterId, String userId) async {
    try {
      debugPrint('🔍 Attempting to claim coaster: $coasterId for user: $userId');

      // CONTROLLO 1: Verifica che il sottobicchiere esista
      DocumentSnapshot coasterDoc = await _db.collection('coasters').doc(coasterId).get();
      if (!coasterDoc.exists) {
        debugPrint('❌ Coaster $coasterId not found');
        return false;
      }

      final coasterData = coasterDoc.data() as Map<String, dynamic>;

      // CONTROLLO 2: Verifica che il sottobicchiere non sia consumato
      if (coasterData['isConsumed'] == true) {
        debugPrint('❌ Coaster $coasterId is already consumed');
        return false;
      }

      // CONTROLLO 3: Verifica che non sia già reclamato da un altro utente
      final String? currentClaimant = coasterData['claimedByUserId'];
      if (currentClaimant != null && currentClaimant != userId) {
        debugPrint('❌ Coaster $coasterId is already claimed by user: $currentClaimant');
        return false;
      }

      // CONTROLLO 4: Verifica che l'utente non abbia già un sottobicchiere attivo
      final userCoaster = await getUserCoaster(userId);
      if (userCoaster != null && !userCoaster.isConsumed && userCoaster.id != coasterId) {
        debugPrint('❌ User $userId already has an active coaster: ${userCoaster.id}');
        return false;
      }

      // CONTROLLO 5: Se l'utente ha già reclamato questo sottobicchiere, non fare nulla ma restituisci successo
      if (currentClaimant == userId) {
        debugPrint('✅ User $userId already owns coaster $coasterId');
        return true;
      }

      // CONTROLLO 6: Verifica che il sottobicchiere sia attivo
      if (coasterData['isActive'] != true) {
        debugPrint('❌ Coaster $coasterId is not active');
        return false;
      }

      // Esegui il claim
      await _db.collection('coasters').doc(coasterId).update({
        'claimedByUserId': userId,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Coaster $coasterId successfully claimed by user $userId');

      // NON assegnare automaticamente un elemento - l'utente sceglierà
      // nella schermata di selezione

      return true;
    } catch (e) {
      debugPrint('❌ Error claiming coaster: $e');
      return false;
    }
  }

  /// Ottiene un coaster specifico con gestione errori migliorata
  Future<CoasterModel?> getCoaster(String coasterId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('coasters').doc(coasterId).get();
      if (doc.exists) {
        return CoasterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting coaster: $e');
      if (e.toString().contains('permission-denied')) {
        // In caso di problemi di permessi, restituisci un coaster temporaneo
        // che permetterà comunque di procedere con la selezione
        return CoasterModel(
          id: coasterId,
          recipeId: 'temp_recipe_id',
          ingredientId: 'temp_ingredient_id',
          isActive: true,
        );
      }
      return null;
    }
  }

  // =============================================================================
  // GAME ELEMENTS MANAGEMENT
  // =============================================================================

  /// Assegna un elemento di gioco casuale all'utente
  Future<void> assignRandomGameElement(String uid) async {
    try {
      // Otteniamo l'utente per verificare se ha già elementi assegnati
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw Exception('Utente non trovato');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final bool hasRecipe = userData['currentRecipeId'] != null;
      final bool hasIngredient = userData['currentIngredientId'] != null;

      // Se l'utente ha già sia una ricetta che un ingrediente, non facciamo nulla
      if (hasRecipe && hasIngredient) {
        return;
      }

      // Se l'utente ha già un elemento, assegniamo l'altro tipo
      // Altrimenti, scegliamo casualmente
      final Random random = Random();
      bool assignRecipe;

      if (hasRecipe) {
        assignRecipe = false;
      } else if (hasIngredient) {
        assignRecipe = true;
      } else {
        // Equilibriamo leggermente la distribuzione:
        // 40% ricette, 60% ingredienti per facilitare i match
        assignRecipe = random.nextDouble() < 0.4;
      }

      if (assignRecipe) {
        // Otteniamo una ricetta casuale
        final QuerySnapshot recipes =
            await _db.collection('recipes').limit(20).get();
        if (recipes.docs.isNotEmpty) {
          final int randomIndex = random.nextInt(recipes.docs.length);
          final String recipeId = recipes.docs[randomIndex].id;
          assignRecipe;
        }
      } else {
        // Otteniamo un ingrediente casuale
        final QuerySnapshot ingredients =
            await _db.collection('ingredients').limit(20).get();
        if (ingredients.docs.isNotEmpty) {
          final int randomIndex = random.nextInt(ingredients.docs.length);
          final String ingredientId = ingredients.docs[randomIndex].id;
          await assignIngredient(uid, ingredientId);
        }
      }
    } catch (e) {
      debugPrint('Error assigning random game element: $e');
      rethrow;
    }
  }

  /// Assegna una ricetta specifica a un utente
  Future<void> assignRecipe(String uid, String recipeId) async {
    try {
      await _db.collection('users').doc(uid).update({
        'currentRecipeId': recipeId,
        'currentIngredientId': null, // Rimuoviamo l'ingrediente se presente
      });
    } catch (e) {
      debugPrint('Error assigning recipe: $e');
      rethrow;
    }
  }

  /// Assegna un ingrediente specifico a un utente
  Future<void> assignIngredient(String uid, String ingredientId) async {
    try {
      await _db.collection('users').doc(uid).update({
        'currentIngredientId': ingredientId,
        'currentRecipeId': null, // Rimuoviamo la ricetta se presente
      });
    } catch (e) {
      debugPrint('Error assigning ingredient: $e');
      rethrow;
    }
  }

  // =============================================================================
  // COASTER MANAGEMENT
  // =============================================================================

  // =============================================================================
  // RECIPE MANAGEMENT
  // =============================================================================

  /// Ottiene tutte le ricette dal database
  Stream<List<RecipeModel>> getRecipes() {
    return _db.collection('recipes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RecipeModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Ottiene una ricetta specifica dal database
  Future<RecipeModel?> getRecipe(String recipeId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('recipes').doc(recipeId).get();
      if (doc.exists) {
        return RecipeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting recipe: $e');
      return null;
    }
  }

  /// Crea una nuova ricetta nel database
  Future<String> createRecipe(RecipeModel recipe) async {
    try {
      final docRef = await _db.collection('recipes').add(recipe.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating recipe: $e');
      rethrow;
    }
  }

  /// Aggiorna una ricetta esistente
  Future<void> updateRecipe(String recipeId, Map<String, dynamic> data) async {
    try {
      await _db.collection('recipes').doc(recipeId).update(data);
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      rethrow;
    }
  }

  // =============================================================================
  // INGREDIENT MANAGEMENT
  // =============================================================================

  /// Ottiene tutti gli ingredienti dal database
  Stream<List<IngredientModel>> getIngredients() {
    return _db.collection('ingredients').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return IngredientModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Ottiene un ingrediente specifico dal database
  Future<IngredientModel?> getIngredient(String ingredientId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('ingredients').doc(ingredientId).get();
      if (doc.exists) {
        return IngredientModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ingredient: $e');
      return null;
    }
  }

  /// Crea un nuovo ingrediente nel database
  Future<String> createIngredient(IngredientModel ingredient) async {
    try {
      final docRef =
          await _db.collection('ingredients').add(ingredient.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating ingredient: $e');
      rethrow;
    }
  }

  /// Aggiorna un ingrediente esistente
  Future<void> updateIngredient(
      String ingredientId, Map<String, dynamic> data) async {
    try {
      await _db.collection('ingredients').doc(ingredientId).update(data);
    } catch (e) {
      debugPrint('Error updating ingredient: $e');
      rethrow;
    }
  }

  // =============================================================================
  // COMPLETIONS & LEADERBOARD
  // =============================================================================

  /// Crea un record di completamento
  Future<String> createCompletionRecord(
    String hostId,
    String recipeId,
    List<String> participantIds,
  ) async {
    try {
      final docRef = await _db.collection('completions').add({
        'hostId': hostId,
        'recipeId': recipeId,
        'participants': participantIds,
        'completedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating completion record: $e');
      rethrow;
    }
  }

  /// Ottiene la classifica generale
  Stream<List<UserModel>> getLeaderboard() {
    return _db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // =============================================================================
  // COASTER MANAGEMENT
  // =============================================================================

  // Genera un ID breve e leggibile
  String _generateShortId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Crea sottobicchiere
  Future<String> createCoaster(String recipeId, String ingredientId) async {
    try {
      // Genera un ID personalizzato più breve e user-friendly
      String shortId = _generateShortId();

      // Verifica che l'ID non esista già
      DocumentSnapshot existing =
          await _db.collection('coasters').doc(shortId).get();
      int attempts = 0;
      while (existing.exists && attempts < 10) {
        shortId = _generateShortId();
        existing = await _db.collection('coasters').doc(shortId).get();
        attempts++;
      }

      if (attempts >= 10) {
        throw Exception('Impossibile generare un ID univoco');
      }

      // Crea il documento con l'ID personalizzato
      await _db.collection('coasters').doc(shortId).set({
        'recipeId': recipeId,
        'ingredientId': ingredientId,
        'isActive': true,
        'claimedByUserId': null,
        'usedAs': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return shortId;
    } catch (e) {
      debugPrint('Error creating coaster: $e');
      rethrow;
    }
  }

  Future<void> clearCoasters(String uid) async {
    bool isAdmin = await isUserAdmin(uid);
    if (!isAdmin) {
      throw Exception(
          'Non hai i permessi di amministratore per eseguire questa operazione');
    }

    WriteBatch batch = _db.batch();

    // Ottieni tutti i documenti dei sottobicchieri
    QuerySnapshot coastersSnapshot = await _db.collection('coasters').get();
    for (var doc in coastersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Esegui il batch delete
    await batch.commit();
  }

  /// Ottieni tutti i sottobicchieri come stream
  Stream<List<CoasterModel>> getCoasters() {
    return _db.collection('coasters').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CoasterModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // =============================================================================
  // ADMIN FUNCTIONS
  // =============================================================================

  // Popola il database con dati fake per testing
  Future<void> populateWithFakeData(String uid) async {
    bool isAdmin = await isUserAdmin(uid);
    if (!isAdmin) {
      throw Exception(
          'Non hai i permessi di amministratore per eseguire questa operazione');
    }

    // Famiglie di ingredienti e pozioni
    final List<String> families = [
      'Natura',
      'Alchimia',
      'Arcana',
      'Elementale',
      'Onirica'
    ];

    // Crea ingredienti fake
    for (int i = 0; i < 60; i++) {
      String family = families[i % families.length];
      String id = 'ingredient_${i + 1}';

      await _db.collection('ingredients').doc(id).set({
        'name': 'Ingrediente ${i + 1}',
        'description':
            'Un ingrediente di tipo $family. Utile per molte pozioni.',
        'imageUrl': '',
        'family': family,
      });
    }

    // Crea pozioni fake
    for (int i = 0; i < 60; i++) {
      String family = families[i % families.length];
      String id = 'recipe_${i + 1}';

      // Ottieni 3 ingredienti random da famiglie diverse dalla famiglia della pozione
      List<String> requiredIngredients = [];
      List<String> availableFamilies = List.from(families);
      availableFamilies.remove(family);

      for (int j = 0; j < 3; j++) {
        String ingredientFamily =
            availableFamilies[j % availableFamilies.length];
        int baseIndex = families.indexOf(ingredientFamily) * 12;
        requiredIngredients.add('Ingrediente ${baseIndex + (i % 12) + 1}');
      }

      await _db.collection('recipes').doc(id).set({
        'name': 'Pozione ${i + 1}',
        'description': 'Una potente pozione di tipo $family.',
        'requiredIngredients': requiredIngredients,
        'imageUrl': '',
        'family': family,
      });
    }
  }

  // Cancella tutti gli ingredienti e le ricette
  Future<void> clearIngredientsAndRecipes(String uid) async {
    bool isAdmin = await isUserAdmin(uid);
    if (!isAdmin) {
      throw Exception(
          'Non hai i permessi di amministratore per eseguire questa operazione');
    }

    WriteBatch batch = _db.batch();

    // Ottieni tutti i documenti degli ingredienti
    QuerySnapshot ingredientsSnapshot =
        await _db.collection('ingredients').get();
    for (var doc in ingredientsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Ottieni tutti i documenti delle ricette
    QuerySnapshot recipesSnapshot = await _db.collection('recipes').get();
    for (var doc in recipesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Esegui il batch delete
    await batch.commit();
  }

  // Cerca un ingrediente o ricetta tramite ID (es. ID sottobicchiere)
  Future<Map<String, dynamic>?> findItemById(String id) async {
    // Cerca tra le ricette
    DocumentSnapshot recipeDoc = await _db.collection('recipes').doc(id).get();
    if (recipeDoc.exists) {
      Map<String, dynamic> data = recipeDoc.data() as Map<String, dynamic>;
      return {
        'type': 'recipe',
        'data': RecipeModel.fromMap(data, recipeDoc.id),
      };
    }

    // Cerca tra gli ingredienti
    DocumentSnapshot ingredientDoc =
        await _db.collection('ingredients').doc(id).get();
    if (ingredientDoc.exists) {
      Map<String, dynamic> data = ingredientDoc.data() as Map<String, dynamic>;
      return {
        'type': 'ingredient',
        'data': IngredientModel.fromMap(data, ingredientDoc.id),
      };
    }

    return null;
  }

  // Assegna un ingrediente o una ricetta a un utente tramite ID
  Future<bool> assignItemToUser(String userId, String itemId) async {
    var item = await findItemById(itemId);
    if (item == null) return false;

    if (item['type'] == 'recipe') {
      await assignRecipe(userId, itemId);
      return true;
    } else if (item['type'] == 'ingredient') {
      await assignIngredient(userId, itemId);
      return true;
    }

    return false;
  }

  // =============================================================================
  // DATA SEEDING
  // =============================================================================

  /// Controlla se è necessario popolare il database con dati iniziali
  Future<void> seedGameElementsIfNeeded() async {
    try {
      final recipesSnapshot = await _db.collection('recipes').limit(1).get();
      final ingredientsSnapshot =
          await _db.collection('ingredients').limit(1).get();

      // Se non ci sono ricette o ingredienti, creiamone alcuni di base
      if (recipesSnapshot.docs.isEmpty || ingredientsSnapshot.docs.isEmpty) {
        await _seedInitialGameElements();
      }
    } catch (e) {
      debugPrint('Error checking if seeding is needed: $e');
      // Non lanciamo l'eccezione per evitare di bloccare l'applicazione
    }
  }

  /// Popola il database con dati iniziali
  Future<void> _seedInitialGameElements() async {
    try {
      // Crea alcune ricette di base
      final List<Map<String, dynamic>> recipes = [
        {
          'name': 'Pozione dell\'Eureka',
          'description':
              'Un intruglio che stimola la mente e porta grandi idee',
          'requiredIngredients': [
            'Radice di Mandragora',
            'Polvere di Luna',
            'Essenza di Ispirazione'
          ],
          'imageUrl': '',
          'family': 'Creatività'
        },
        {
          'name': 'Elisir della Fortuna',
          'description': 'Garantisce un giorno fortunato a chi lo beve',
          'requiredIngredients': [
            'Quadrifoglio Dorato',
            'Scaglie di Drago',
            'Rugiada dell\'Alba'
          ],
          'imageUrl': '',
          'family': 'Fortuna'
        },
        {
          'name': 'Filtro della Velocità',
          'description': 'Aumenta l\'agilità e i riflessi per breve tempo',
          'requiredIngredients': [
            'Piuma di Fenice',
            'Goccia di Mercurio',
            'Petalo di Rosa Nera'
          ],
          'imageUrl': '',
          'family': 'Movimento'
        },
        {
          'name': 'Infuso della Saggezza',
          'description':
              'Dona temporaneamente conoscenza e saggezza al bevitore',
          'requiredIngredients': [
            'Foglia d\'Acanto',
            'Cristallo di Quarzo',
            'Inchiostro di Seppia'
          ],
          'imageUrl': '',
          'family': 'Conoscenza'
        },
        {
          'name': 'Tonico del Coraggio',
          'description':
              'Elimina la paura e dona coraggio in situazioni difficili',
          'requiredIngredients': [
            'Crine di Leone',
            'Ambra Fossile',
            'Fiore del Vulcano'
          ],
          'imageUrl': '',
          'family': 'Coraggio'
        },
      ];

      // Crea alcuni ingredienti di base
      final List<Map<String, dynamic>> ingredients = [
        {
          'name': 'Radice di Mandragora',
          'description': 'Una radice rara che amplifica le capacità mentali',
          'imageUrl': '',
          'family': 'Erbe'
        },
        {
          'name': 'Polvere di Luna',
          'description':
              'Raccolta durante la luna piena, ha proprietà magiche potenti',
          'imageUrl': '',
          'family': 'Elementi'
        },
        {
          'name': 'Essenza di Ispirazione',
          'description': 'Distillata dai sogni di artisti e inventori',
          'imageUrl': '',
          'family': 'Essenze'
        },
        {
          'name': 'Quadrifoglio Dorato',
          'description':
              'Raro quadrifoglio che porta fortuna a chi lo possiede',
          'imageUrl': '',
          'family': 'Piante'
        },
        {
          'name': 'Scaglie di Drago',
          'description': 'Scaglie luminescenti che emanano energia antica',
          'imageUrl': '',
          'family': 'Creature'
        },
        {
          'name': 'Rugiada dell\'Alba',
          'description': 'Raccolta all\'alba del solstizio d\'estate',
          'imageUrl': '',
          'family': 'Elementi'
        },
        {
          'name': 'Piuma di Fenice',
          'description': 'Incandescente e leggerissima, conferisce rapidità',
          'imageUrl': '',
          'family': 'Creature'
        },
        {
          'name': 'Goccia di Mercurio',
          'description': 'Elemento fluido che accelera i movimenti',
          'imageUrl': '',
          'family': 'Elementi'
        },
        {
          'name': 'Petalo di Rosa Nera',
          'description': 'Raro fiore che cresce solo nelle notti senza luna',
          'imageUrl': '',
          'family': 'Piante'
        },
        {
          'name': 'Foglia d\'Acanto',
          'description': 'Simbolo di saggezza e conoscenza profonda',
          'imageUrl': '',
          'family': 'Erbe'
        },
        {
          'name': 'Cristallo di Quarzo',
          'description': 'Amplifica i pensieri e chiarisce la mente',
          'imageUrl': '',
          'family': 'Minerali'
        },
        {
          'name': 'Inchiostro di Seppia',
          'description': 'Contiene la saggezza degli oceani',
          'imageUrl': '',
          'family': 'Creature'
        },
        {
          'name': 'Crine di Leone',
          'description': 'Simbolo di coraggio e forza interiore',
          'imageUrl': '',
          'family': 'Creature'
        },
        {
          'name': 'Ambra Fossile',
          'description': 'Contiene memorie ancestrali di coraggio',
          'imageUrl': '',
          'family': 'Minerali'
        },
        {
          'name': 'Fiore del Vulcano',
          'description': 'Cresce solo ai bordi dei crateri vulcanici attivi',
          'imageUrl': '',
          'family': 'Piante'
        },
      ];

      // Inserisci le ricette nel database
      for (var recipe in recipes) {
        await _db.collection('recipes').add(recipe);
      }

      // Inserisci gli ingredienti nel database
      for (var ingredient in ingredients) {
        await _db.collection('ingredients').add(ingredient);
      }

      debugPrint('Seed data created successfully');
    } catch (e) {
      debugPrint('Error seeding game elements: $e');
      rethrow;
    }
  }
}
