import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'package:potion_riders/services/recipe_service.dart';
import 'package:potion_riders/services/ingredient_service.dart';

class CoasterSelectionScreen extends StatefulWidget {
  final String coasterId;
  final String recipeId;
  final String ingredientId;

  const CoasterSelectionScreen({
    super.key,
    required this.coasterId,
    required this.recipeId,
    required this.ingredientId,
  });

  @override
  _CoasterSelectionScreenState createState() => _CoasterSelectionScreenState();
}

class _CoasterSelectionScreenState extends State<CoasterSelectionScreen> {
  final DatabaseService _dbService = DatabaseService();
  final RecipeService _recipeService = RecipeService();
  final IngredientService _ingredientService = IngredientService();

  bool _isLoading = true;
  RecipeModel? _recipe;
  IngredientModel? _ingredient;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _loadCoasterDetails();
  }

  Future<void> _loadCoasterDetails() async {
    setState(() => _isLoading = true);

    try {
      // Recupera i dettagli direttamente dai servizi, senza usare il coaster
      // In questo modo evitiamo problemi di permessi
      if (widget.recipeId != 'temp_recipe_id') {
        // Se abbiamo un ID reale, caricalo
        _recipe = await _recipeService.getRecipe(widget.recipeId);
      } else {
        // Altrimenti, proviamo a caricare una ricetta casuale
        final recipes = await _dbService.getRecipes().first;
        if (recipes.isNotEmpty) {
          _recipe = recipes.first;
        }
      }

      if (widget.ingredientId != 'temp_ingredient_id') {
        // Se abbiamo un ID reale, caricalo
        _ingredient = await _ingredientService.getIngredient(widget.ingredientId);
      } else {
        // Altrimenti, proviamo a caricare un ingrediente casuale
        final ingredients = await _dbService.getIngredients().first;
        if (ingredients.isNotEmpty) {
          _ingredient = ingredients.first;
        }
      }
    } catch (e) {
      print('Errore caricamento dettagli: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli cosa utilizzare'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intestazione
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.help_outline, color: Colors.blue, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Scegli quale lato del sottobicchiere utilizzare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Una volta scelto, non potrai cambiare la tua decisione',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Opzione Pozione
            _buildSelectionCard(
              title: 'Pozione',
              icon: Icons.science,
              color: Colors.purple,
              name: _recipe?.name ?? 'Pozione sconosciuta',
              description: _recipe?.description ?? '',
              family: _recipe?.family ?? '',
              additionalInfo: _recipe != null
                  ? 'Richiede: ${_recipe!.requiredIngredients.join(", ")}'
                  : '',
              onSelect: _isSelecting
                  ? null
                  : () => _selectOption(context, uid, 'recipe'),
            ),

            const SizedBox(height: 16),

            // Opzione Ingrediente
            _buildSelectionCard(
              title: 'Ingrediente',
              icon: Icons.eco,
              color: Colors.green,
              name: _ingredient?.name ?? 'Ingrediente sconosciuto',
              description: _ingredient?.description ?? '',
              family: _ingredient?.family ?? '',
              onSelect: _isSelecting
                  ? null
                  : () => _selectOption(context, uid, 'ingredient'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String name,
    required String description,
    required String family,
    String? additionalInfo,
    VoidCallback? onSelect,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    family,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(description),
                if (additionalInfo != null && additionalInfo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    additionalInfo,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onSelect,
                  icon: Icon(_isSelecting ? Icons.hourglass_empty : Icons.check_circle),
                  label: Text(_isSelecting ? 'Selezione in corso...' : 'Seleziona $title'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectOption(BuildContext context, String? uid, String type) async {
    if (uid == null) return;

    setState(() => _isSelecting = true);

    try {
      // Prima reclama il sottobicchiere se non è già stato fatto
      final coaster = await _dbService.getCoaster(widget.coasterId);
      if (coaster != null && coaster.claimedByUserId == null) {
        await _dbService.claimCoaster(widget.coasterId, uid);
      }

      // Poi usa il sottobicchiere per il tipo selezionato
      final success = await _dbService.useCoaster(widget.coasterId, uid, type);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'recipe'
                ? 'Hai scelto di usare il sottobicchiere come pozione!'
                : 'Hai scelto di usare il sottobicchiere come ingrediente!'),
          ),
        );

        // Ritorna alla home
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception('Impossibile selezionare l\'elemento');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSelecting = false);
    }
  }
}