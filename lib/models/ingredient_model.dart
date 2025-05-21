class IngredientModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String family;

  IngredientModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.family,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'family': family,
    };
  }

  factory IngredientModel.fromMap(Map<String, dynamic> map, String documentId) {
    return IngredientModel(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      family: map['family'] ?? '',
    );
  }
}
