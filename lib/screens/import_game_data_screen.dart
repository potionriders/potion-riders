import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'dart:typed_data';

import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class ImportGameDataScreen extends StatefulWidget {
  const ImportGameDataScreen({super.key});

  @override
  _ImportGameDataScreenState createState() => _ImportGameDataScreenState();
}

class _ImportGameDataScreenState extends State<ImportGameDataScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();

  TabController? _tabController;
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  // Contatori per l'importazione
  int _totalItems = 0;
  int _currentProgress = 0;
  int _successItems = 0;
  int _failedItems = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Importazione Dati di Gioco'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pozioni e Ingredienti'),
            Tab(text: 'Sottobicchieri'),
            Tab(text: 'Reset Database'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPotionsIngredientsTab(),
          _buildCoastersTab(),
          _buildResetTab(),
        ],
      ),
    );
  }

  Widget _buildPotionsIngredientsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        'Importa Pozioni e Ingredienti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Seleziona un file JSON contenente pozioni e ingredienti. '
                        'Il file deve avere la struttura corretta con le proprietà "recipes" e "ingredients".',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importPotionsIngredients,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Seleziona File JSON'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_snippet, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Format JSON',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Esempio di formato JSON richiesto:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      '{\n'
                          '  "recipes": [\n'
                          '    {\n'
                          '      "name": "Pozione dell\'Eureka",\n'
                          '      "description": "Un intruglio che stimola...",\n'
                          '      "requiredIngredients": ["Radice di Mandragora", ...],\n'
                          '      "imageUrl": "",\n'
                          '      "family": "Creatività"\n'
                          '    }\n'
                          '  ],\n'
                          '  "ingredients": [\n'
                          '    {\n'
                          '      "name": "Radice di Mandragora",\n'
                          '      "description": "Una radice rara...",\n'
                          '      "imageUrl": "",\n'
                          '      "family": "Erbe"\n'
                          '    }\n'
                          '  ]\n'
                          '}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading && _tabController?.index == 0) _buildProgressSection(),
          if (_statusMessage.isNotEmpty && _tabController?.index == 0) _buildStatusMessage(),
        ],
      ),
    );
  }

  Widget _buildCoastersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tab, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Importa Sottobicchieri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Importa i dati dei sottobicchieri da un file JSON. '
                        'Assicurati di aver prima importato pozioni e ingredienti.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importCoasters,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Seleziona File JSON'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_snippet, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Format JSON',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Esempio di formato JSON richiesto:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      '{\n'
                          '  "coasters": [\n'
                          '    {\n'
                          '      "id": 1,\n'
                          '      "pozione": "Pozione dell\'Eureka",\n'
                          '      "ingredienteRetro": "Radice di Mandragora",\n'
                          '      "claim": "Claim1"\n'
                          '    }\n'
                          '  ]\n'
                          '}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading && _tabController?.index == 1) _buildProgressSection(),
          if (_statusMessage.isNotEmpty && _tabController?.index == 1) _buildStatusMessage(),
        ],
      ),
    );
  }

  Widget _buildResetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Elimina Dati Esistenti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Questa azione eliminerà tutte le pozioni, gli ingredienti e i sottobicchieri dal database. '
                        'Questa operazione non può essere annullata.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Attenzione: questa azione cancellerà tutti i dati di gioco. '
                                  'Importa nuovi dati subito dopo per evitare problemi con l\'app.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _confirmReset,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Elimina tutti i dati'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Elimina solo sottobicchieri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Questa azione eliminerà solo i sottobicchieri, mantenendo pozioni e ingredienti.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _confirmResetCoasters,
                    icon: const Icon(Icons.delete),
                    label: const Text('Elimina sottobicchieri'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading && _tabController?.index == 2) _buildProgressSection(),
          if (_statusMessage.isNotEmpty && _tabController?.index == 2) _buildStatusMessage(),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Operazione in corso...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _totalItems > 0 ? _currentProgress / _totalItems : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Progresso: $_currentProgress / $_totalItems',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Successo: $_successItems | Falliti: $_failedItems',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccess ? Icons.check_circle : Icons.error,
            color: _isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Azioni per importare pozioni e ingredienti
  Future<void> _importPotionsIngredients() async {
    try {
      // Seleziona file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final Uint8List bytes = file.bytes ?? Uint8List(0);

      if (bytes.isEmpty) {
        setState(() {
          _statusMessage = 'File vuoto o non leggibile';
          _isSuccess = false;
        });
        return;
      }

      // Decodifica il file JSON
      final String content = utf8.decode(bytes);
      final dynamic decodedJson = json.decode(content);

      if (decodedJson is! Map<String, dynamic>) {
        setState(() {
          _statusMessage = 'Formato JSON non valido. Deve essere un oggetto con campi "recipes" e "ingredients"';
          _isSuccess = false;
        });
        return;
      }

      final List<dynamic>? recipes = decodedJson['recipes'] as List<dynamic>?;
      final List<dynamic>? ingredients = decodedJson['ingredients'] as List<dynamic>?;

      if (recipes == null || ingredients == null) {
        setState(() {
          _statusMessage = 'Il JSON deve contenere campi "recipes" e "ingredients"';
          _isSuccess = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _statusMessage = '';
        _totalItems = recipes.length + ingredients.length;
        _currentProgress = 0;
        _successItems = 0;
        _failedItems = 0;
      });

      // Importa le pozioni
      for (var recipeData in recipes) {
        if (recipeData is Map<String, dynamic>) {
          try {
            // Verifica che i campi necessari siano presenti
            if (recipeData.containsKey('name') && recipeData.containsKey('family')) {
              List<String> requiredIngredients = [];
              if (recipeData.containsKey('requiredIngredients') && recipeData['requiredIngredients'] is List) {
                requiredIngredients = List<String>.from(recipeData['requiredIngredients']);
              }

              await _dbService.createRecipe(
                RecipeModel(
                  id: '', // ID sarà generato dal database
                  name: recipeData['name'],
                  description: recipeData['description'] ?? '',
                  requiredIngredients: requiredIngredients,
                  imageUrl: recipeData['imageUrl'] ?? '',
                  family: recipeData['family'],
                ),
              );
              _successItems++;
            } else {
              _failedItems++;
            }
          } catch (e) {
            print('Errore importazione pozione: $e');
            _failedItems++;
          }
        } else {
          _failedItems++;
        }

        _currentProgress++;
        if (_currentProgress % 3 == 0) {
          setState(() {});
          await Future.delayed(Duration(milliseconds: 300));
        }
      }

      // Importa gli ingredienti
      for (var ingredientData in ingredients) {
        if (ingredientData is Map<String, dynamic>) {
          try {
            // Verifica che i campi necessari siano presenti
            if (ingredientData.containsKey('name') && ingredientData.containsKey('family')) {
              await _dbService.createIngredient(
                IngredientModel(
                  id: '', // ID sarà generato dal database
                  name: ingredientData['name'],
                  description: ingredientData['description'] ?? '',
                  imageUrl: ingredientData['imageUrl'] ?? '',
                  family: ingredientData['family'],
                ),
              );
              _successItems++;
            } else {
              _failedItems++;
            }
          } catch (e) {
            print('Errore importazione ingrediente: $e');
            _failedItems++;
          }
        } else {
          _failedItems++;
        }

        _currentProgress++;
        if (_currentProgress % 3 == 0) {
          setState(() {});
          await Future.delayed(Duration(milliseconds: 300));
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Importazione completata: $_successItems elementi importati con successo, $_failedItems falliti';
        _isSuccess = _failedItems == 0;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante l\'importazione: $e';
        _isSuccess = false;
      });
    }
  }

  // Azioni per importare sottobicchieri
  Future<void> _importCoasters() async {
    try {
      // Seleziona file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final Uint8List bytes = file.bytes ?? Uint8List(0);

      if (bytes.isEmpty) {
        setState(() {
          _statusMessage = 'File vuoto o non leggibile';
          _isSuccess = false;
        });
        return;
      }

      // Decodifica il file JSON
      final String content = utf8.decode(bytes);
      final dynamic decodedJson = json.decode(content);

      if (decodedJson is! Map<String, dynamic>) {
        setState(() {
          _statusMessage = 'Formato JSON non valido. Deve essere un oggetto con campo "coasters"';
          _isSuccess = false;
        });
        return;
      }

      final List<dynamic>? coasters = decodedJson['coasters'] as List<dynamic>?;

      if (coasters == null) {
        setState(() {
          _statusMessage = 'Il JSON deve contenere un campo "coasters"';
          _isSuccess = false;
        });
        return;
      }

      // Raccogliamo prima tutti i dati di pozioni e ingredienti disponibili
      final recipes = await _dbService.getRecipes().first;
      final ingredients = await _dbService.getIngredients().first;

      // Mappa per risolvere i nomi in ID
      Map<String, String> recipeNameToId = {};
      Map<String, String> ingredientNameToId = {};

      for (var recipe in recipes) {
        recipeNameToId[recipe.name.toLowerCase()] = recipe.id;
      }

      for (var ingredient in ingredients) {
        ingredientNameToId[ingredient.name.toLowerCase()] = ingredient.id;
      }

      setState(() {
        _isLoading = true;
        _statusMessage = '';
        _totalItems = coasters.length;
        _currentProgress = 0;
        _successItems = 0;
        _failedItems = 0;
      });

      // Importa i sottobicchieri
      for (var coasterData in coasters) {
        if (coasterData is Map<String, dynamic>) {
          try {
            // Verifica che i campi necessari siano presenti
            if (coasterData.containsKey('pozione') && coasterData.containsKey('ingredienteRetro')) {
              final pozioneName = coasterData['pozione'].toString().toLowerCase();
              final ingredienteName = coasterData['ingredienteRetro'].toString().toLowerCase();

              String? recipeId = recipeNameToId[pozioneName];
              String? ingredientId = ingredientNameToId[ingredienteName];

              // Se non trovati, prova a cercare corrispondenze parziali
              if (recipeId == null) {
                for (var entry in recipeNameToId.entries) {
                  if (entry.key.contains(pozioneName) || pozioneName.contains(entry.key)) {
                    recipeId = entry.value;
                    break;
                  }
                }
              }

              if (ingredientId == null) {
                for (var entry in ingredientNameToId.entries) {
                  if (entry.key.contains(ingredienteName) || ingredienteName.contains(entry.key)) {
                    ingredientId = entry.value;
                    break;
                  }
                }
              }

              if (recipeId == null || ingredientId == null) {
                print('ID non trovati per pozione "${coasterData['pozione']}" o ingrediente "${coasterData['ingredienteRetro']}"');
                _failedItems++;
              } else {
                // Crea il sottobicchiere
                await _dbService.createCoaster(recipeId, ingredientId);
                _successItems++;
              }
            } else {
              _failedItems++;
            }
          } catch (e) {
            print('Errore importazione sottobicchiere: $e');
            _failedItems++;
          }
        } else {
          _failedItems++;
        }

        _currentProgress++;
        if (_currentProgress % 3 == 0) {
          setState(() {});
          await Future.delayed(Duration(milliseconds: 300));
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Importazione completata: $_successItems sottobicchieri importati con successo, $_failedItems falliti';
        _isSuccess = _failedItems == 0;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante l\'importazione: $e';
        _isSuccess = false;
      });
    }
  }

  // Azioni per il reset del database
  Future<void> _confirmReset() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text(
          'Sei sicuro di voler eliminare tutte le pozioni, gli ingredienti e i sottobicchieri? '
              'Questa operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteAllData();
    }
  }

  Future<void> _confirmResetCoasters() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text(
          'Sei sicuro di voler eliminare tutti i sottobicchieri? '
              'Questa operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteCoasters();
    }
  }

  Future<void> _deleteAllData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.currentUser?.uid;

      if (uid == null) {
        throw Exception('Devi essere autenticato per eseguire questa operazione');
      }

      await _dbService.clearIngredientsAndRecipes(uid);
      await _dbService.clearCoasters(uid);

      setState(() {
        _isLoading = false;
        _statusMessage = 'Tutti i dati sono stati eliminati con successo!';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante l\'eliminazione dei dati: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _deleteCoasters() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.currentUser?.uid;

      if (uid == null) {
        throw Exception('Devi essere autenticato per eseguire questa operazione');
      }

      await _dbService.clearCoasters(uid);

      setState(() {
        _isLoading = false;
        _statusMessage = 'Tutti i sottobicchieri sono stati eliminati con successo!';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante l\'eliminazione dei sottobicchieri: $e';
        _isSuccess = false;
      });
    }
  }
}