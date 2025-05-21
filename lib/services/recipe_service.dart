// Aggiungi questo file: services/recipe_service.dart

import 'package:flutter/foundation.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/services/database_service.dart';

class RecipeService with ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // Ottieni una ricetta specifica come Stream
  Stream<RecipeModel?> getRecipeStream(String recipeId) {
    return _db.getRecipe(recipeId).asStream();
  }

  // Ottieni una ricetta specifica come Future
  Future<RecipeModel?> getRecipe(String recipeId) {
    return _db.getRecipe(recipeId);
  }

  // Helper per ottenere attributi specifici di una ricetta
  Future<String> getRecipeName(String recipeId) async {
    final recipe = await _db.getRecipe(recipeId);
    return recipe?.name ?? 'Pozione sconosciuta';
  }

  Future<String> getRecipeFamily(String recipeId) async {
    final recipe = await _db.getRecipe(recipeId);
    return recipe?.family ?? 'Famiglia sconosciuta';
  }

  Future<List<String>> getRecipeIngredients(String recipeId) async {
    final recipe = await _db.getRecipe(recipeId);
    return recipe?.requiredIngredients ?? [];
  }

  Future<String> getRecipeImageUrl(String recipeId) async {
    final recipe = await _db.getRecipe(recipeId);
    return recipe?.imageUrl ?? '';
  }

  Future<String> getRecipeDescription(String recipeId) async {
    final recipe = await _db.getRecipe(recipeId);
    return recipe?.description ?? '';
  }
}
