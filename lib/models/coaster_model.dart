// models/coaster_model.dart
class CoasterModel {
  final String id;
  final String recipeId;
  final String ingredientId;
  final bool isActive;
  final String? claimedByUserId;
  final String? usedAs; // 'recipe' o 'ingredient'
  final bool isConsumed; // NUOVO CAMPO
  final DateTime? createdAt;
  final DateTime? consumedAt; // NUOVO CAMPO - quando è stato consumato

  CoasterModel({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.isActive,
    this.claimedByUserId,
    this.usedAs,
    this.isConsumed = false, // Default false
    this.createdAt,
    this.consumedAt,
  });

  factory CoasterModel.fromMap(Map<String, dynamic> map, String id) {
    return CoasterModel(
      id: id,
      recipeId: map['recipeId'] ?? '',
      ingredientId: map['ingredientId'] ?? '',
      isActive: map['isActive'] ?? true,
      claimedByUserId: map['claimedByUserId'],
      usedAs: map['usedAs'],
      isConsumed: map['isConsumed'] ?? false, // NUOVO
      createdAt: map['createdAt']?.toDate(),
      consumedAt: map['consumedAt']?.toDate(), // NUOVO
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'ingredientId': ingredientId,
      'isActive': isActive,
      'claimedByUserId': claimedByUserId,
      'usedAs': usedAs,
      'isConsumed': isConsumed, // NUOVO
      'createdAt': createdAt,
      'consumedAt': consumedAt, // NUOVO
    };
  }

  // Helper per controllare se può essere usato
  bool get canBeUsed => isActive && !isConsumed && claimedByUserId != null;

  // Helper per controllare se può essere riconsegnato
  bool get canBeReturned => isConsumed && claimedByUserId != null;
}