class RoomModel {
  final String id;
  final String recipeId;
  final String hostId;
  final List<ParticipantModel> participants;
  final DateTime createdAt;
  final bool isCompleted;

  RoomModel({
    required this.id,
    required this.recipeId,
    required this.hostId,
    required this.participants,
    required this.createdAt,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'hostId': hostId,
      'participants': participants.map((p) => p.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RoomModel(
      id: documentId,
      recipeId: map['recipeId'] ?? '',
      hostId: map['hostId'] ?? '',
      participants: (map['participants'] as List?)
              ?.map((p) => ParticipantModel.fromMap(p))
              .toList() ??
          [],
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  bool isReadyToComplete() {
    // Controlla se tutti gli ingredienti richiesti sono presenti
    // e tutti i partecipanti hanno confermato
    if (participants.length < 3 || isCompleted) {
      return false;
    }

    return participants.every((participant) => participant.hasConfirmed);
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
}
