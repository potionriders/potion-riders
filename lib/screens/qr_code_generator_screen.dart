import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/services/qr_service.dart';

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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crea un nuovo sottobicchiere',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seleziona una pozione e un ingrediente per creare un sottobicchiere',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Sezione selezione pozione
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seleziona una pozione',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<List<RecipeModel>>(
                          stream: _dbService.getRecipes(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('Nessuna pozione disponibile');
                            }

                            return DropdownButtonFormField<String>(
                              value: _selectedRecipeId,
                              decoration: const InputDecoration(
                                hintText: 'Seleziona una pozione',
                                border: OutlineInputBorder(),
                              ),
                              items: snapshot.data!.map((recipe) {
                                return DropdownMenuItem<String>(
                                  value: recipe.id,
                                  child: Text(recipe.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRecipeId = value;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sezione selezione ingrediente
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seleziona un ingrediente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<List<IngredientModel>>(
                          stream: _dbService.getIngredients(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('Nessun ingrediente disponibile');
                            }

                            return DropdownButtonFormField<String>(
                              value: _selectedIngredientId,
                              decoration: const InputDecoration(
                                hintText: 'Seleziona un ingrediente',
                                border: OutlineInputBorder(),
                              ),
                              items: snapshot.data!.map((ingredient) {
                                return DropdownMenuItem<String>(
                                  value: ingredient.id,
                                  child: Text(ingredient.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedIngredientId = value;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Pulsante per generare il sottobicchiere
                ElevatedButton.icon(
                  onPressed: _isGenerating
                      ? null
                      : (_selectedRecipeId != null && _selectedIngredientId != null)
                      ? () => _createCoaster()
                      : null,
                  icon: _isGenerating
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.add_circle),
                  label: Text(_isGenerating
                      ? 'Creazione in corso...'
                      : 'Crea Sottobicchiere'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_qrData != null && _isCoaster)
          _buildQRCodeCard(),
      ],
    );
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