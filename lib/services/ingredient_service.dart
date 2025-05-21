import 'package:flutter/foundation.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'package:potion_riders/services/database_service.dart';

class IngredientService with ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // Ottieni un ingrediente specifico come Stream
  Stream<IngredientModel?> getIngredientStream(String ingredientId) {
    return _db.getIngredient(ingredientId).asStream();
  }

  // Ottieni un ingrediente specifico come Future
  Future<IngredientModel?> getIngredient(String ingredientId) {
    return _db.getIngredient(ingredientId);
  }

  // Helper per ottenere attributi specifici di un ingrediente
  Future<String> getIngredientName(String ingredientId) async {
    final ingredient = await _db.getIngredient(ingredientId);
    return ingredient?.name ?? 'Ingrediente sconosciuto';
  }

  Future<String> getIngredientFamily(String ingredientId) async {
    final ingredient = await _db.getIngredient(ingredientId);
    return ingredient?.family ?? 'Famiglia sconosciuta';
  }

  Future<String> getIngredientImageUrl(String ingredientId) async {
    final ingredient = await _db.getIngredient(ingredientId);
    return ingredient?.imageUrl ?? '';
  }

  Future<String> getIngredientDescription(String ingredientId) async {
    final ingredient = await _db.getIngredient(ingredientId);
    return ingredient?.description ?? '';
  }
}
