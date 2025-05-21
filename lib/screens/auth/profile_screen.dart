import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/models/user_model.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';

import '../../models/ingredient_model.dart';
import '../../models/recipe_model.dart';
import '../../services/ingredient_service.dart';
import '../../services/recipe_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final dbService = DatabaseService();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Non sei autenticato'))
          : StreamBuilder<UserModel?>(
              stream: dbService.getUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final user = snapshot.data;
                if (user == null) {
                  return const Center(child: Text('Utente non trovato'));
                }

                // Ora puoi accedere alle proprietà dell'utente
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar dell'utente
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.nickname.isNotEmpty
                                    ? user.nickname[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Nome utente
                      Text(
                        user.nickname,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Email
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Punti
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                size: 36,
                                color: Colors.amber,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${user.points}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                ),
                              ),
                              Text(
                                'Punti totali',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ruolo
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('Ruolo'),
                        subtitle: Text(user.role),
                        tileColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Pozione/Ingrediente corrente
                      if (user.currentRecipeId != null)
                        _buildRecipeCard(
                          context,
                          dbService as String,
                          user.currentRecipeId!,
                        )
                      else if (user.currentIngredientId != null)
                        _buildIngredientCard(
                          context,
                          dbService as String,
                          user.currentIngredientId!,
                        ),

                      const SizedBox(height: 24),

                      // Pulsante modifica profilo
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implementare schermata di modifica profilo
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Funzionalità in arrivo!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifica profilo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, String recipeId, String s) {
    final recipeService = RecipeService();

    return FutureBuilder<RecipeModel?>(
      future: recipeService.getRecipe(recipeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: const Icon(Icons.science, color: Colors.purple),
            title: const Text('Pozione attuale'),
            subtitle: const Text('Caricamento...'),
            tileColor: Colors.purple[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Errore'),
            subtitle: Text(
              'Impossibile caricare i dettagli: ${snapshot.error}',
            ),
            tileColor: Colors.red[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        final recipe = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.science, color: Colors.purple),
          title: Text(recipe?.name ?? 'Pozione sconosciuta'),
          subtitle: Text(recipe?.family ?? ''),
          tileColor: Colors.purple[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: recipe != null
              ? () {
                  // Mostra dettagli della pozione quando viene cliccata
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(recipe.name),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipe.description),
                          const SizedBox(height: 16),
                          const Text(
                            'Ingredienti necessari:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...recipe.requiredIngredients.map(
                            (ingredient) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(ingredient),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Chiudi'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                }
              : null,
        );
      },
    );
  }

  Widget _buildIngredientCard(
      BuildContext context, String ingredientId, String s) {
    final ingredientService = IngredientService();

    return FutureBuilder<IngredientModel?>(
      future: ingredientService.getIngredient(ingredientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: const Icon(Icons.eco, color: Colors.green),
            title: const Text('Ingrediente attuale'),
            subtitle: const Text('Caricamento...'),
            tileColor: Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Errore'),
            subtitle: Text(
              'Impossibile caricare i dettagli: ${snapshot.error}',
            ),
            tileColor: Colors.red[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        final ingredient = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.eco, color: Colors.green),
          title: Text(ingredient?.name ?? 'Ingrediente sconosciuto'),
          subtitle: Text(ingredient?.family ?? ''),
          tileColor: Colors.green[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: ingredient != null
              ? () {
                  // Azione quando si tocca l'ingrediente
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(ingredient.name),
                      content: Text(ingredient.description),
                      actions: [
                        TextButton(
                          child: const Text('Chiudi'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                }
              : null,
        );
      },
    );
  }
}
