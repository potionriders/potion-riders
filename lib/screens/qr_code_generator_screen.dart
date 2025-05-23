import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/services/qr_service.dart';

import '../models/coaster_model.dart';

class QRCodeGeneratorScreen extends StatefulWidget {
  const QRCodeGeneratorScreen({super.key});

  @override
  _QRCodeGeneratorScreenState createState() => _QRCodeGeneratorScreenState();
}

class _QRCodeGeneratorScreenState extends State<QRCodeGeneratorScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  TabController? _tabController;

  // Selezione corrente
  String? _selectedRecipeId;
  String? _selectedIngredientId;

  // Dati QR
  String? _qrData;
  String? _qrType;
  bool _isCoaster = false;
  String? _coasterId;

  // Stato di generazione
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      setState(() {
        // Reset selezione quando si cambia tab
        _qrData = null;
        if (_tabController!.index == 0) {
          _qrType = 'recipe';
          _selectedIngredientId = null;
          _isCoaster = false;
        } else if (_tabController!.index == 1) {
          _qrType = 'ingredient';
          _selectedRecipeId = null;
          _isCoaster = false;
        } else {
          _qrType = 'coaster';
          _isCoaster = true;
        }
      });
    });

    // Imposta tipo iniziale
    _qrType = 'recipe';
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generatore QR Code'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pozioni'),
            Tab(text: 'Ingredienti'),
            Tab(text: 'Sottobicchieri'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Pozioni
          _buildRecipesTab(),

          // Tab Ingredienti
          _buildIngredientsTab(),

          // Tab Sottobicchieri
          _buildCoastersTab(),
        ],
      ),
    );
  }

  Widget _buildRecipesTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<RecipeModel>>(
            stream: _dbService.getRecipes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nessuna pozione trovata'));
              }

              final recipes = snapshot.data!;
              return ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return ListTile(
                    title: Text(recipe.name),
                    subtitle: Text('Famiglia: ${recipe.family}'),
                    trailing: Radio<String>(
                      value: recipe.id,
                      groupValue: _selectedRecipeId,
                      onChanged: (value) {
                        setState(() {
                          _selectedRecipeId = value;
                          _generateQRData('recipe', recipe);
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        _selectedRecipeId = recipe.id;
                        _generateQRData('recipe', recipe);
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
        if (_qrData != null && _qrType == 'recipe')
          _buildQRCodeCard(),
      ],
    );
  }

  Widget _buildIngredientsTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<IngredientModel>>(
            stream: _dbService.getIngredients(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nessun ingrediente trovato'));
              }

              final ingredients = snapshot.data!;
              return ListView.builder(
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];
                  return ListTile(
                    title: Text(ingredient.name),
                    subtitle: Text('Famiglia: ${ingredient.family}'),
                    trailing: Radio<String>(
                      value: ingredient.id,
                      groupValue: _selectedIngredientId,
                      onChanged: (value) {
                        setState(() {
                          _selectedIngredientId = value;
                          _generateQRData('ingredient', ingredient);
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIngredientId = ingredient.id;
                        _generateQRData('ingredient', ingredient);
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
        if (_qrData != null && _qrType == 'ingredient')
          _buildQRCodeCard(),
      ],
    );
  }

  Widget _buildCoastersTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CoasterModel>>(
            stream: _dbService.getCoasters(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('Nessun sottobicchiere disponibile'),
                );
              }

              final coasters = snapshot.data!;

              return ListView.builder(
                itemCount: coasters.length,
                itemBuilder: (context, index) {
                  final coaster = coasters[index];

                  return FutureBuilder<Map<String, String?>>(
                    future: _getCoasterDetails(coaster),
                    builder: (context, detailsSnapshot) {
                      final details = detailsSnapshot.data ?? {};
                      final recipeName = details['recipeName'] ?? 'Caricamento...';
                      final ingredientName = details['ingredientName'] ?? 'Caricamento...';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Icon(
                            coaster.claimedByUserId != null
                                ? Icons.lock
                                : Icons.tab,
                            color: coaster.claimedByUserId != null
                                ? Colors.red
                                : Colors.green,
                          ),
                          title: Text('ID: ${coaster.id.substring(0, 8)}...'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pozione: $recipeName'),
                              Text('Ingrediente: $ingredientName'),
                              if (coaster.claimedByUserId != null)
                                Text(
                                  'Già reclamato',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Radio<String>(
                            value: coaster.id,
                            groupValue: _coasterId,
                            onChanged: coaster.claimedByUserId == null
                                ? (value) {
                              setState(() {
                                _coasterId = value;
                                _generateCoasterQRCode(coaster);
                              });
                            }
                                : null,
                          ),
                          onTap: coaster.claimedByUserId == null
                              ? () {
                            setState(() {
                              _coasterId = coaster.id;
                              _generateCoasterQRCode(coaster);
                            });
                          }
                              : null,
                          enabled: coaster.claimedByUserId == null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (_qrData != null && _isCoaster)
          _buildQRCodeCard(),
      ],
    );
  }

  Future<Map<String, String?>> _getCoasterDetails(CoasterModel coaster) async {
    try {
      final recipe = await _dbService.getRecipe(coaster.recipeId);
      final ingredient = await _dbService.getIngredient(coaster.ingredientId);

      return {
        'recipeName': recipe?.name,
        'ingredientName': ingredient?.name,
      };
    } catch (e) {
      return {
        'recipeName': 'Errore',
        'ingredientName': 'Errore',
      };
    }
  }

  void _generateCoasterQRCode(CoasterModel coaster) {
    Map<String, dynamic> data = {
      'type': 'coaster',
      'id': coaster.id,
    };

    setState(() {
      _qrData = _formatQRData(data);
      _isCoaster = true;
    });
  }

  Widget _buildQRCodeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: QrService.generateQrCode(_qrData!, size: 200),
          ),
          const SizedBox(height: 16),
          Text(
            _isCoaster
                ? 'Sottobicchiere: ${_coasterId?.substring(0, 6) ?? ""}'
                : _qrType == 'recipe'
                ? 'Pozione'
                : 'Ingrediente',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Implementare salvataggio QR code
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR code salvato')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Salva QR Code'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _qrData!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dati QR code copiati negli appunti')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copia Dati'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _generateQRData(String type, dynamic item) {
    Map<String, dynamic> data = {
      'type': type,
      'id': item.id,
    };

    setState(() {
      _qrData = _formatQRData(data);
    });
  }

  Future<void> _createCoaster() async {
    if (_selectedRecipeId == null || _selectedIngredientId == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      setState(() {
        _isCoaster = true;
      });

      // Crea un nuovo sottobicchiere nel database
      String id = await _dbService.createCoaster(
        _selectedRecipeId!,
        _selectedIngredientId!,
      );

      _coasterId = id;

      // Genera i dati QR
      Map<String, dynamic> data = {
        'type': 'coaster',
        'id': id,
      };

      setState(() {
        _qrData = _formatQRData(data);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sottobicchiere creato con successo!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la creazione del sottobicchiere: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  String _formatQRData(Map<String, dynamic> data) {
    return data.toString();
  }
}