// coaster_model.dart
class CoasterModel {
  final String id;
  final String recipeId;
  final String ingredientId;
  final bool isActive;
  final String? claimedByUserId;
  final String? usedAs; // "recipe" o "ingredient" o null se non usato

  CoasterModel({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    this.isActive = true,
    this.claimedByUserId,
    this.usedAs,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'ingredientId': ingredientId,
      'isActive': isActive,
      'claimedByUserId': claimedByUserId,
      'usedAs': usedAs,
    };
  }

  factory CoasterModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CoasterModel(
      id: documentId,
      recipeId: map['recipeId'] ?? '',
      ingredientId: map['ingredientId'] ?? '',
      isActive: map['isActive'] ?? true,
      claimedByUserId: map['claimedByUserId'],
      usedAs: map['usedAs'],
    );
  }

  // Crea copia con nuovi campi
  CoasterModel copyWith({
    String? recipeId,
    String? ingredientId,
    bool? isActive,
    String? claimedByUserId,
    String? usedAs,
  }) {
    return CoasterModel(
      id: this.id,
      recipeId: recipeId ?? this.recipeId,
      ingredientId: ingredientId ?? this.ingredientId,
      isActive: isActive ?? this.isActive,
      claimedByUserId: claimedByUserId ?? this.claimedByUserId,
      usedAs: usedAs ?? this.usedAs,
    );
  }
}