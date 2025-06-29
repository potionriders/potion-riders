import 'package:cloud_firestore/cloud_firestore.dart';

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

  // SOLUZIONE MINIMALE: Sostituisci solo il metodo fromMap nel tuo RoomModel esistente

  factory RoomModel.fromMap(Map<String, dynamic> map, String documentId) {
    try {
      // GESTIONE SICURA DEL TIMESTAMP - QUESTO È IL FIX PRINCIPALE
      DateTime createdAt;
      final createdAtField = map['createdAt'];

      if (createdAtField is Timestamp) {
        createdAt = createdAtField.toDate();
      } else if (createdAtField is DateTime) {
        createdAt = createdAtField;
      } else if (createdAtField == null) {
        // Se il timestamp è ancora pending, usa la data corrente
        print('⚠️ CreatedAt is null/pending, using current time for room $documentId');
        createdAt = DateTime.now();
      } else {
        // Fallback per altri formati
        print('⚠️ Unknown createdAt format: ${createdAtField.runtimeType} for room $documentId');
        createdAt = DateTime.now();
      }

      // GESTIONE SICURA PARTECIPANTI (mantieni la tua logica esistente)
      List<ParticipantModel> participants = [];
      if (map['participants'] != null) {
        participants = (map['participants'] as List)
            .map((participantMap) => ParticipantModel.fromMap(participantMap))
            .toList();
      }

      return RoomModel(
        id: documentId,
        hostId: map['hostId'] ?? '',
        recipeId: map['recipeId'] ?? '',
        participants: participants,
        createdAt: createdAt, // USA IL TIMESTAMP SICURO
        isCompleted: map['isCompleted'] ?? false,
      );
    } catch (e) {
      print('❌ Error parsing RoomModel: $e');
      print('📊 Problematic data: $map');

      // FALLBACK SICURO
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
