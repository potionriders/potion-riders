class RecipeModel {
  final String id;
  final String name;
  final String description;
  final List<String> requiredIngredients;
  final String imageUrl;
  final String family;

  RecipeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.requiredIngredients,
    required this.imageUrl,
    required this.family,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'requiredIngredients': requiredIngredients,
      'imageUrl': imageUrl,
      'family': family,
    };
  }

  factory RecipeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RecipeModel(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      requiredIngredients: List<String>.from(map['requiredIngredients'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      family: map['family'] ?? '',
    );
  }
}
