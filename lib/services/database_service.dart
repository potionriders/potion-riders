import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  Future<bool> isItemClaimed(String itemId) async {
    // Controlla se è una ricetta
    QuerySnapshot recipeQuery = await _db.collection('users')
        .where('currentRecipeId', isEqualTo: itemId)
        .limit(1)
        .get();

    if (recipeQuery.docs.isNotEmpty) {
      return true;
    }

    // Controlla se è un ingrediente
    QuerySnapshot ingredientQuery = await _db.collection('users')
        .where('currentIngredientId', isEqualTo: itemId)
        .limit(1)
        .get();

    return ingredientQuery.docs.isNotEmpty;
  }

  Future<void> createUser(
      String uid,
      String email,
      String nickname, {
        String? photoUrl,
        String role = 'player'
      }) async {
    try {
      final String gameUuid = const Uuid().v4();

      await _db.collection('users').doc(uid).set({
        'email': email,
        'nickname': nickname,
        'photoUrl': photoUrl,
        'role': role,
        'points': 0,
        'gameUuid': gameUuid,
        'currentRecipeId': null,
        'currentIngredientId': null,
        'rooms': [], // NUOVO: Lista delle stanze attive
        'completedRooms': [], // NUOVO: Lista delle stanze completate
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

  /// Ottiene un utente dal database come stream
  Stream<UserModel?> getUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
            (snapshot) => snapshot.exists ? UserModel.fromMap(snapshot.data()!, snapshot.id) : null
    );
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

  Stream<List<RoomModel>> getUserRooms(String userId) {
    return _db.collection('rooms')
        .where('hostId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomModel.fromMap(doc.data(), doc.id))
          .toList();
    });
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
          DocumentSnapshot roomDoc = await _db.collection('rooms').doc(roomId).get();
          if (roomDoc.exists) {
            rooms.add(RoomModel.fromMap(roomDoc.data() as Map<String, dynamic>, roomDoc.id));
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
      debugPrint('🏗️ Starting room creation for host: $hostId, recipe: $recipeId');

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
        debugPrint('⚠️ Warning: Room created but failed to update user: $userUpdateError');
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
          debugPrint('❌ All retries failed for adding room $roomId to user $userId');
        }
      }
    }
  }

  /// Ottiene una stanza specifica
  Stream<RoomModel?> getRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map(
            (snapshot) => snapshot.exists ?
        RoomModel.fromMap(snapshot.data()!, snapshot.id) : null
    );
  }

  Future<void> joinRoom(String roomId, String userId, String ingredientId) async {
    try {
      // Verifica che l'utente possa unirsi
      bool canJoin = await canJoinSpecificRoom(roomId, userId);
      if (!canJoin) {
        throw Exception('User cannot join this room');
      }

      // Aggiungi il partecipante alla stanza
      await _db.collection('rooms').doc(roomId).update({
        'participants': FieldValue.arrayUnion([{
          'userId': userId,
          'ingredientId': ingredientId,
          'hasConfirmed': false,
        }]),
      });

      // NUOVO: Aggiungi la stanza alla lista dell'utente
      await addRoomToUser(userId, roomId);
    } catch (e) {
      debugPrint('Error joining room: $e');
      rethrow;
    }
  }

  /// MIGLIORATO: Completa una stanza e aggiorna tutti gli utenti coinvolti
  Future<void> completeRoom(String roomId) async {
    try {
      // Ottieni i dati della stanza
      DocumentSnapshot roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return;

      RoomModel room = RoomModel.fromMap(roomDoc.data() as Map<String, dynamic>, roomDoc.id);

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
      DocumentSnapshot roomDoc = await _db.collection('rooms').doc(roomId).get();
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
        participants.removeWhere((p) => p is Map<String, dynamic> && p['userId'] == userId);

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

  /// MIGLIORATO: Verifica se un utente può creare una stanza usando i riferimenti diretti
  Future<bool> canCreateRoom(String userId) async {
    try {
      debugPrint('🔍 Checking if user $userId can create room...');

      UserModel? user = await getUser(userId).first;
      debugPrint('👤 User found: ${user != null}');

      if (user == null) {
        debugPrint('❌ User not found, cannot create room');
        return false;
      }

      debugPrint('📊 User active rooms: ${user.rooms}');
      debugPrint('✅ Can create room: ${user.rooms.isEmpty}');

      return user.rooms.isEmpty;
    } catch (e) {
      debugPrint('❌ Error checking if user can create room: $e');
      // In caso di errore, permettiamo la creazione (fail-safe)
      return true;
    }
  }

  Future<void> syncUserRooms(String userId) async {
    try {
      debugPrint('🔄 Syncing rooms for user: $userId');

      // Trova tutte le stanze dove l'utente è host o partecipante
      QuerySnapshot hostRooms = await _db.collection('rooms')
          .where('hostId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      QuerySnapshot allActiveRooms = await _db.collection('rooms')
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
          if (participant is Map<String, dynamic> && participant['userId'] == userId) {
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
      debugPrint('🏗️ Creating simple room for host: $hostId, recipe: $recipeId');

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
      if (room.participants.any((p) => p.userId == userId) || room.hostId == userId) {
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
    return _db.collection('rooms')
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

  // =============================================================================
  // METODI ESISTENTI - MANTENUTI INALTERATI
  // =============================================================================

  /// Aggiorna il punteggio di un utente
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
      QuerySnapshot result = await _db.collection('users')
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
      final ingredient = await getIngredient(ingredientId);
      return ingredient?.name ?? 'Ingrediente sconosciuto';
    } catch (e) {
      debugPrint('Error getting ingredient name: $e');
      return 'Ingrediente sconosciuto';
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
      QuerySnapshot hostCompletions = await _db.collection('completions')
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
        'totalCompletions': hostCompletions.docs.length + participantCompletions,
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
    return _db.collection('users')
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
          Map<String, int> stats = await getUserStats(user.uid);

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

  /// Conferma partecipazione (versione corretta)
  Future<void> confirmParticipation(String roomId, String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        // Cast corretto con controllo null
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          List<dynamic> participants = List.from(data['participants'] ?? []);

          for (int i = 0; i < participants.length; i++) {
            if (participants[i] is Map<String, dynamic> &&
                participants[i]['userId'] == userId) {
              participants[i]['hasConfirmed'] = true;
              break;
            }
          }

          await _db.collection('rooms').doc(roomId).update({
            'participants': participants,
          });
        }
      }
    } catch (e) {
      debugPrint('Error confirming participation: $e');
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
    return _db.collection('rooms')
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

  /// Completa una stanza e libera gli slot (versione migliorata)
  Future<void> completeRoomAndFreeSlots(String roomId) async {
    try {
      // Ottieni i dati della stanza
      DocumentSnapshot roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return;

      RoomModel room = RoomModel.fromMap(roomDoc.data() as Map<String, dynamic>, roomDoc.id);

      // Segna la stanza come completata
      await _db.collection('rooms').doc(roomId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Assegna punti all'host (chi ha la ricetta)
      await updatePoints(room.hostId, 10);

      // Assegna punti ai partecipanti (chi ha gli ingredienti)
      for (ParticipantModel participant in room.participants) {
        await updatePoints(participant.userId, 5);
      }

      // Registra il completamento
      await createCompletionRecord(
        room.hostId,
        room.recipeId,
        room.participants.map((p) => p.userId).toList(),
      );

      // Libera gli slot di tutti i partecipanti (incluso l'host)
      List<String> allUserIds = [room.hostId];
      allUserIds.addAll(room.participants.map((p) => p.userId));
      await freeUserSlots(allUserIds);

      // Assegna nuovi elementi casuali a tutti i partecipanti
      for (String userId in allUserIds) {
        await assignRandomGameElement(userId);
      }
    } catch (e) {
      debugPrint('Error completing room and freeing slots: $e');
      rethrow;
    }
  }


  /// Ottiene il coaster dell'utente come stream
  Stream<CoasterModel?> getUserCoasterStream(String userId) {
    return _db.collection('coasters')
        .where('claimedByUserId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CoasterModel.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id
      );
    });
  }

  /// Reclama un coaster e lo assegna come elemento casuale
  Future<bool> claimCoaster(String coasterId, String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('coasters').doc(coasterId).get();
      if (!doc.exists) return false;

      CoasterModel coaster = CoasterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      if (!coaster.isActive || coaster.claimedByUserId != null) {
        return false; // Già reclamato o disattivato
      }

      // Reclama il coaster
      await _db.collection('coasters').doc(coasterId).update({
        'claimedByUserId': userId,
      });

      // NON assegnare automaticamente un elemento - l'utente sceglierà
      // nella schermata di selezione

      return true;
    } catch (e) {
      debugPrint('Error claiming coaster: $e');
      return false;
    }
  }

  /// Usa sottobicchiere (come pozione o ingrediente) - versione migliorata
  Future<bool> useCoaster(String coasterId, String userId, String useAs) async {
    try {
      DocumentSnapshot doc = await _db.collection('coasters').doc(coasterId).get();
      if (!doc.exists) return false;

      CoasterModel coaster = CoasterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      if (!coaster.isActive || coaster.claimedByUserId != userId) {
        return false; // Non attivo o non reclamato da questo utente
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

  /// Ottiene un coaster specifico con gestione errori migliorata
  Future<CoasterModel?> getCoaster(String coasterId) async {
    try {
      DocumentSnapshot doc = await _db.collection('coasters').doc(coasterId).get();
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
        final QuerySnapshot recipes = await _db.collection('recipes').limit(20).get();
        if (recipes.docs.isNotEmpty) {
          final int randomIndex = random.nextInt(recipes.docs.length);
          final String recipeId = recipes.docs[randomIndex].id;
          await assignRecipe;
        }
      } else {
        // Otteniamo un ingrediente casuale
        final QuerySnapshot ingredients = await _db.collection('ingredients').limit(20).get();
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

  /// Cambia l'uso del sottobicchiere tra pozione e ingrediente
  Future<bool> switchCoasterUsage(String userId, String coasterId, bool useAsRecipe) async {
    try {
      DocumentSnapshot doc = await _db.collection('coasters').doc(coasterId).get();
      if (!doc.exists) return false;

      CoasterModel coaster = CoasterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Verifica che il coaster appartenga all'utente
      if (coaster.claimedByUserId != userId) {
        return false;
      }

      // Aggiorna l'uso del coaster
      String newUsage = useAsRecipe ? 'recipe' : 'ingredient';
      await _db.collection('coasters').doc(coasterId).update({
        'usedAs': newUsage,
      });

      // Aggiorna l'elemento assegnato all'utente
      if (useAsRecipe) {
        await assignRecipe(userId, coaster.recipeId);
      } else {
        await assignIngredient(userId, coaster.ingredientId);
      }

      return true;
    } catch (e) {
      debugPrint('Error switching coaster usage: $e');
      return false;
    }
  }

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
      DocumentSnapshot doc = await _db.collection('recipes').doc(recipeId).get();
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
      DocumentSnapshot doc = await _db.collection('ingredients').doc(ingredientId).get();
      if (doc.exists) {
        return IngredientModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
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
      final docRef = await _db.collection('ingredients').add(ingredient.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating ingredient: $e');
      rethrow;
    }
  }

  /// Aggiorna un ingrediente esistente
  Future<void> updateIngredient(String ingredientId, Map<String, dynamic> data) async {
    try {
      await _db.collection('ingredients').doc(ingredientId).update(data);
    } catch (e) {
      debugPrint('Error updating ingredient: $e');
      rethrow;
    }
  }

  /// Controlla se una stanza è pronta per essere completata
  Stream<bool> isRoomReadyToComplete(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;

      RoomModel room = RoomModel.fromMap(snapshot.data()!, snapshot.id);
      return room.isReadyToComplete();
    });
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
    return _db.collection('users')
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
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Crea sottobicchiere
  Future<String> createCoaster(String recipeId, String ingredientId) async {
    try {
      // Genera un ID personalizzato più breve e user-friendly
      String shortId = _generateShortId();

      // Verifica che l'ID non esista già
      DocumentSnapshot existing = await _db.collection('coasters').doc(shortId).get();
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

  // Crea sottobicchiere con ID specifico (per importazione)
  Future<String> createCoasterWithId(String coasterId, String recipeId, String ingredientId) async {
    try {
      // Verifica che l'ID non esista già
      DocumentSnapshot existing = await _db.collection('coasters').doc(coasterId).get();
      if (existing.exists) {
        throw Exception('Coaster con ID $coasterId già esistente');
      }

      // Crea il documento con l'ID specifico
      await _db.collection('coasters').doc(coasterId).set({
        'recipeId': recipeId,
        'ingredientId': ingredientId,
        'isActive': true,
        'claimedByUserId': null,
        'usedAs': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return coasterId;
    } catch (e) {
      debugPrint('Error creating coaster with specific ID: $e');
      rethrow;
    }
  }

  // Genera coasters in bulk per test
  Future<void> generateTestCoasters(String uid, int count) async {
    bool isAdmin = await isUserAdmin(uid);
    if (!isAdmin) {
      throw Exception('Non hai i permessi di amministratore per eseguire questa operazione');
    }

    // Ottieni liste di ricette e ingredienti
    QuerySnapshot recipesSnapshot = await _db.collection('recipes').limit(60).get();
    QuerySnapshot ingredientsSnapshot = await _db.collection('ingredients').limit(60).get();

    List<String> recipeIds = recipesSnapshot.docs.map((doc) => doc.id).toList();
    List<String> ingredientIds = ingredientsSnapshot.docs.map((doc) => doc.id).toList();

    if (recipeIds.isEmpty || ingredientIds.isEmpty) {
      throw Exception('Non ci sono ricette o ingredienti nel database');
    }

    // Crea batch per operazioni multiple
    WriteBatch batch = _db.batch();

    for (int i = 0; i < count; i++) {
      // Genera un ID personalizzato per ogni coaster
      String coasterId = _generateShortId();

      // Verifica che non esista già
      DocumentSnapshot existing = await _db.collection('coasters').doc(coasterId).get();
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
      int ingredientIndex = (i + 3) % ingredientIds.length; // Offset per evitare accoppiamenti ovvi

      batch.set(coasterRef, {
        'recipeId': recipeIds[recipeIndex],
        'ingredientId': ingredientIds[ingredientIndex],
        'isActive': true,
        'claimedByUserId': null,
        'usedAs': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<CoasterModel?> getUserCoaster(String userId) async {
    try {
      // Ottieni tutti i coaster (potrebbe essere limitato se ce ne sono molti)
      final snapshot = await _db.collection('coasters').get();

      // Cerca manualmente il coaster dell'utente
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['claimedByUserId'] == userId) {
          return CoasterModel.fromMap(data, doc.id);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Errore nel recupero del coaster: $e');
      return null;
    }
  }

  Future<void> clearCoasters(String uid) async {
    bool isAdmin = await isUserAdmin(uid);
    if (!isAdmin) {
      throw Exception('Non hai i permessi di amministratore per eseguire questa operazione');
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
      throw Exception('Non hai i permessi di amministratore per eseguire questa operazione');
    }

    // Famiglie di ingredienti e pozioni
    final List<String> families = ['Natura', 'Alchimia', 'Arcana', 'Elementale', 'Onirica'];

    // Crea ingredienti fake
    for (int i = 0; i < 60; i++) {
      String family = families[i % families.length];
      String id = 'ingredient_${i+1}';

      await _db.collection('ingredients').doc(id).set({
        'name': 'Ingrediente ${i+1}',
        'description': 'Un ingrediente di tipo $family. Utile per molte pozioni.',
        'imageUrl': '',
        'family': family,
      });
    }

    // Crea pozioni fake
    for (int i = 0; i < 60; i++) {
      String family = families[i % families.length];
      String id = 'recipe_${i+1}';

      // Ottieni 3 ingredienti random da famiglie diverse dalla famiglia della pozione
      List<String> requiredIngredients = [];
      List<String> availableFamilies = List.from(families);
      availableFamilies.remove(family);

      for (int j = 0; j < 3; j++) {
        String ingredientFamily = availableFamilies[j % availableFamilies.length];
        int baseIndex = families.indexOf(ingredientFamily) * 12;
        requiredIngredients.add('Ingrediente ${baseIndex + (i % 12) + 1}');
      }

      await _db.collection('recipes').doc(id).set({
        'name': 'Pozione ${i+1}',
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
      throw Exception('Non hai i permessi di amministratore per eseguire questa operazione');
    }

    WriteBatch batch = _db.batch();

    // Ottieni tutti i documenti degli ingredienti
    QuerySnapshot ingredientsSnapshot = await _db.collection('ingredients').get();
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
    DocumentSnapshot ingredientDoc = await _db.collection('ingredients').doc(id).get();
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
      final ingredientsSnapshot = await _db.collection('ingredients').limit(1).get();

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
          'description': 'Un intruglio che stimola la mente e porta grandi idee',
          'requiredIngredients': ['Radice di Mandragora', 'Polvere di Luna', 'Essenza di Ispirazione'],
          'imageUrl': '',
          'family': 'Creatività'
        },
        {
          'name': 'Elisir della Fortuna',
          'description': 'Garantisce un giorno fortunato a chi lo beve',
          'requiredIngredients': ['Quadrifoglio Dorato', 'Scaglie di Drago', 'Rugiada dell\'Alba'],
          'imageUrl': '',
          'family': 'Fortuna'
        },
        {
          'name': 'Filtro della Velocità',
          'description': 'Aumenta l\'agilità e i riflessi per breve tempo',
          'requiredIngredients': ['Piuma di Fenice', 'Goccia di Mercurio', 'Petalo di Rosa Nera'],
          'imageUrl': '',
          'family': 'Movimento'
        },
        {
          'name': 'Infuso della Saggezza',
          'description': 'Dona temporaneamente conoscenza e saggezza al bevitore',
          'requiredIngredients': ['Foglia d\'Acanto', 'Cristallo di Quarzo', 'Inchiostro di Seppia'],
          'imageUrl': '',
          'family': 'Conoscenza'
        },
        {
          'name': 'Tonico del Coraggio',
          'description': 'Elimina la paura e dona coraggio in situazioni difficili',
          'requiredIngredients': ['Crine di Leone', 'Ambra Fossile', 'Fiore del Vulcano'],
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
          'description': 'Raccolta durante la luna piena, ha proprietà magiche potenti',
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
          'description': 'Raro quadrifoglio che porta fortuna a chi lo possiede',
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