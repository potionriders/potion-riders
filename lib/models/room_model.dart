import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String hostId;
  final String recipeId;
  final List<ParticipantModel> participants;
  final DateTime createdAt;
  final bool isCompleted;

  RoomModel({
    required this.id,
    required this.hostId,
    required this.recipeId,
    required this.participants,
    required this.createdAt,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'recipeId': recipeId,
      'participants': participants.map((p) => p.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isCompleted': isCompleted,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map, String documentId) {
    try {
      List<ParticipantModel> participants = [];
      if (map['participants'] != null) {
        participants = (map['participants'] as List<dynamic>)
            .map((p) => ParticipantModel.fromMap(p as Map<String, dynamic>))
            .toList();
      }

      Timestamp? timestamp = map['createdAt'] as Timestamp?;
      DateTime createdAt = timestamp?.toDate() ?? DateTime.now();

      return RoomModel(
        id: documentId,
        hostId: map['hostId'] ?? '',
        recipeId: map['recipeId'] ?? '',
        participants: participants,
        createdAt: createdAt,
        isCompleted: map['isCompleted'] ?? false,
      );
    } catch (e) {
      print('❌ Error parsing RoomModel: $e');
      print('📊 Problematic data: $map');

      return RoomModel(
        id: documentId,
        hostId: map['hostId'] ?? 'error',
        recipeId: map['recipeId'] ?? 'error',
        participants: [],
        createdAt: DateTime.now(),
        isCompleted: false,
      );
    }
  }

  /// Verifica se la stanza è pronta per essere completata
  /// Logica basata sul numero di ingredienti confermati, non sul numero totale di partecipanti
  bool isReadyToComplete() {
    if (isCompleted) {
      return false;
    }

    // Conta solo i partecipanti che hanno confermato la loro partecipazione
    int confirmedIngredientsCount = participants.where((p) => p.hasConfirmed).length;

    // La stanza è pronta quando ci sono almeno 3 ingredienti confermati
    return confirmedIngredientsCount >= 3;
  }

  /// Ottiene il numero di ingredienti confermati nella stanza
  int getConfirmedIngredientsCount() {
    return participants.where((p) => p.hasConfirmed).length;
  }

  /// Verifica se tutti i partecipanti presenti hanno confermato
  bool allParticipantsConfirmed() {
    if (participants.isEmpty) return false;
    return participants.every((p) => p.hasConfirmed);
  }

  /// Verifica se l'utente specificato è l'host della stanza
  bool isHost(String userId) {
    return hostId == userId;
  }

  /// Verifica se l'utente specificato è un partecipante della stanza
  bool isParticipant(String userId) {
    return participants.any((p) => p.userId == userId);
  }

  /// Ottiene il modello partecipante per un utente specifico
  ParticipantModel? getParticipant(String userId) {
    try {
      return participants.firstWhere((p) => p.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Verifica se un utente ha confermato la sua partecipazione
  bool hasUserConfirmed(String userId) {
    final participant = getParticipant(userId);
    return participant?.hasConfirmed ?? false;
  }
}

class ParticipantModel {
  final String userId;
  final String ingredientId;
  final bool hasConfirmed;

  ParticipantModel({
    required this.userId,
    required this.ingredientId,
    this.hasConfirmed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ingredientId': ingredientId,
      'hasConfirmed': hasConfirmed,
    };
  }

  factory ParticipantModel.fromMap(Map<String, dynamic> map) {
    return ParticipantModel(
      userId: map['userId'] ?? '',
      ingredientId: map['ingredientId'] ?? '',
      hasConfirmed: map['hasConfirmed'] ?? false,
    );
  }

  /// Crea una copia del partecipante con stato di conferma aggiornato
  ParticipantModel copyWith({bool? hasConfirmed}) {
    return ParticipantModel(
      userId: userId,
      ingredientId: ingredientId,
      hasConfirmed: hasConfirmed ?? this.hasConfirmed,
    );
  }

  /// Verifica se il partecipante è valido (ha userId e ingredientId)
  bool isValid() {
    return userId.isNotEmpty && ingredientId.isNotEmpty;
  }
}