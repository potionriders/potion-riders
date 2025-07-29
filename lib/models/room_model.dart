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

  // NUOVI CAMPI per i nomi (opzionali per compatibilità)
  final String? userName;
  final String? ingredientName;
  final int? joinedAt;

  ParticipantModel({
    required this.userId,
    required this.ingredientId,
    this.hasConfirmed = false,
    this.userName,
    this.ingredientName,
    this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> result = {
      'userId': userId,
      'ingredientId': ingredientId,
      'hasConfirmed': hasConfirmed,
    };

    // Aggiungi campi opzionali solo se non null
    if (userName != null) result['userName'] = userName!;
    if (ingredientName != null) result['ingredientName'] = ingredientName!;
    if (joinedAt != null) result['joinedAt'] = joinedAt!;

    return result;
  }

  factory ParticipantModel.fromMap(Map<String, dynamic> map) {
    return ParticipantModel(
      userId: map['userId'] ?? '',
      ingredientId: map['ingredientId'] ?? '',
      hasConfirmed: map['hasConfirmed'] ?? false,

      // NUOVI CAMPI - possono essere null per dati vecchi
      userName: map['userName'],
      ingredientName: map['ingredientName'],
      joinedAt: map['joinedAt'],
    );
  }

  /// Crea una copia del partecipante con campi aggiornati
  ParticipantModel copyWith({
    bool? hasConfirmed,
    String? userName,
    String? ingredientName,
    int? joinedAt,
  }) {
    return ParticipantModel(
      userId: userId,
      ingredientId: ingredientId,
      hasConfirmed: hasConfirmed ?? this.hasConfirmed,
      userName: userName ?? this.userName,
      ingredientName: ingredientName ?? this.ingredientName,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  /// Verifica se il partecipante è valido (ha userId e ingredientId)
  bool isValid() {
    return userId.isNotEmpty && ingredientId.isNotEmpty;
  }

  /// Ottieni il nome visualizzato dell'utente (con fallback)
  String getDisplayName() {
    if (userName != null && userName!.isNotEmpty) {
      return userName!;
    }
    return 'Utente ${userId.substring(0, 8)}...'; // Mostra primi 8 caratteri dell'ID
  }

  /// Ottieni il nome visualizzato dell'ingrediente (con fallback)
  String getIngredientDisplayName() {
    if (ingredientName != null && ingredientName!.isNotEmpty) {
      return ingredientName!;
    }
    return 'Ingrediente ${ingredientId.substring(0, 8)}...'; // Mostra primi 8 caratteri dell'ID
  }

  /// Ottieni data/ora di join formattata
  String getJoinedAtFormatted() {
    if (joinedAt != null) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(joinedAt!);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }

  /// Verifica se ha tutti i dati completi (inclusi nomi)
  bool hasCompleteData() {
    return isValid() &&
        userName != null &&
        userName!.isNotEmpty &&
        ingredientName != null &&
        ingredientName!.isNotEmpty;
  }

  @override
  String toString() {
    return 'ParticipantModel(userId: $userId, ingredientId: $ingredientId, '
        'hasConfirmed: $hasConfirmed, userName: $userName, '
        'ingredientName: $ingredientName, joinedAt: $joinedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantModel &&
        other.userId == userId &&
        other.ingredientId == ingredientId &&
        other.hasConfirmed == hasConfirmed &&
        other.userName == userName &&
        other.ingredientName == ingredientName &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
    ingredientId.hashCode ^
    hasConfirmed.hashCode ^
    (userName?.hashCode ?? 0) ^
    (ingredientName?.hashCode ?? 0) ^
    (joinedAt?.hashCode ?? 0);
  }
}