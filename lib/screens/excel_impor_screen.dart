import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/utils/excel_to_json_converter.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'dart:typed_data';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  _ExcelImportScreenState createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _jsonController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  // Excel file info
  String? _excelFileName;
  String? _convertedJson;
  bool _isConverting = false;

  // Import stage
  String _currentStage = ""; // "", "loading", "ingredients", "recipes", "coasters", "completed"
  double _progress = 0.0;

  // Counter for each stage
  int _totalIngredients = 0;
  int _successfulIngredients = 0;
  int _failedIngredients = 0;
  int _skippedIngredients = 0;

  int _totalRecipes = 0;
  int _successfulRecipes = 0;
  int _failedRecipes = 0;
  int _skippedRecipes = 0;

  int _totalCoasters = 0;
  int _successfulCoasters = 0;
  int _failedCoasters = 0;
  int _skippedCoasters = 0;

  // Lists for existing items
  List<RecipeModel> _availableRecipes = [];
  List<IngredientModel> _availableIngredients = [];

  // Maps for name to ID lookups
  Map<String, String> _recipeNameToId = {};
  Map<String, String> _ingredientNameToId = {};

  // Set of existing coasters to avoid duplicates
  Set<String> _existingCoasters = {};

  // For debug info
  List<String> _debugMessages = [];

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _logDebug(String message) {
    print("DEBUG: $message");
    _debugMessages.add(message);
  }

  // Normalize a name by removing special characters and lowercasing
  String _normalizeName(String name) {
    String normalized = name.toLowerCase();
    normalized = normalized.replaceAll("'", "").replaceAll("'", "");
    normalized = normalized.replaceAll("\"", "").replaceAll(",", "");
    normalized = normalized.replaceAll(".", "").replaceAll("-", " ");
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importa da Excel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File selection card
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
                    const Text(
                      'Importa da Excel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Seleziona un file Excel contenente le informazioni dei sottobicchieri. '
                          'Il file deve avere colonne per Pozione, Ingrediente Retro, e opzionalmente ID e Claim.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickExcelFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Seleziona File Excel'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.green,
                      ),
                    ),
                    if (_excelFileName != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'File selezionato: $_excelFileName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Import options
            if (_convertedJson != null) ...[
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
                      const Text(
                        'Importa tutti i dati',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verranno importati in sequenza:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Caricamento degli elementi esistenti'),
                      const Text('2. Ingredienti (salta se già esistono)'),
                      const Text('3. Pozioni (salta se già esistono)'),
                      const Text('4. Sottobicchieri (salta se già esistono)'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _importAllData,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Avvia importazione intelligente'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.purple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _importOnlyCoasters,
                            icon: const Icon(Icons.local_drink),
                            label: const Text('Solo sottobicchieri'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Progress card
            if (_isLoading) ...[
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
                      Text(
                        'Importazione in corso: ${_getStageLabel()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _progress,
                      ),
                      const SizedBox(height: 16),
                      _buildProgressDetails(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Results card - show when completed
            if (_currentStage == "completed") ...[
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
                      const Text(
                        'Riepilogo importazione',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow('Ingredienti', _successfulIngredients, _failedIngredients, _skippedIngredients),
                      const Divider(),
                      _buildResultRow('Pozioni', _successfulRecipes, _failedRecipes, _skippedRecipes),
                      const Divider(),
                      _buildResultRow('Sottobicchieri', _successfulCoasters, _failedCoasters, _skippedCoasters),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status message
            if (_statusMessage.isNotEmpty) _buildStatusMessage(),
            
            // Debug card (always visible)
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informazioni',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Ingredienti nel database: ${_availableIngredients.length}'),
                    Text('Pozioni nel database: ${_availableRecipes.length}'),
                    Text('Sottobicchieri nel database: ${_existingCoasters.length}'),
                    if (_debugMessages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Ultimo messaggio debug: ${_debugMessages.last}'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStageLabel() {
    switch (_currentStage) {
      case "loading":
        return "Caricamento elementi esistenti";
      case "ingredients":
        return "Ingredienti";
      case "recipes":
        return "Pozioni";
      case "coasters":
        return "Sottobicchieri";
      case "completed":
        return "Completata";
      default:
        return "";
    }
  }

  Widget _buildProgressDetails() {
    if (_currentStage == "loading") {
      return const Text('Caricamento elementi esistenti dal database...');
    } else if (_currentStage == "ingredients") {
      return Text('Importazione ingredienti: $_successfulIngredients importati, $_skippedIngredients saltati, $_failedIngredients falliti');
    } else if (_currentStage == "recipes") {
      return Text('Importazione pozioni: $_successfulRecipes importate, $_skippedRecipes saltate, $_failedRecipes fallite');
    } else if (_currentStage == "coasters") {
      return Text('Importazione sottobicchieri: $_successfulCoasters importati, $_skippedCoasters saltati, $_failedCoasters falliti');
    }
    return const SizedBox();
  }

  Widget _buildResultRow(String label, int success, int failed, int skipped) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCounterChip(Icons.check_circle, Colors.green, "Importati", "$success"),
              _buildCounterChip(Icons.skip_next, Colors.orange, "Saltati", "$skipped"),
              _buildCounterChip(Icons.error, Colors.red, "Falliti", "$failed"),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCounterChip(IconData icon, Color color, String label, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            "$label: $count",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
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

  Future<void> _pickExcelFile() async {
    try {
      setState(() {
        _isConverting = true;
        _statusMessage = '';
        _convertedJson = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isConverting = false;
        });
        return;
      }

      final file = result.files.first;
      final excelBytes = file.bytes;

      if (excelBytes == null || excelBytes.isEmpty) {
        setState(() {
          _statusMessage = 'File vuoto o non leggibile. Assicurati che il file sia un XLSX valido.';
          _isSuccess = false;
          _isConverting = false;
        });
        return;
      }

      setState(() {
        _excelFileName = file.name;
      });

      try {
        final jsonStr = await ExcelToJsonConverter.convertExcelToJson(excelBytes);
        
        setState(() {
          _convertedJson = jsonStr;
          _isConverting = false;
          _statusMessage = 'Excel convertito in JSON con successo. Pronto per l\'importazione.';
          _isSuccess = true;
          
          // Count coasters
          final decodedCoasters = json.decode(jsonStr);
          if (decodedCoasters is Map<String, dynamic> && decodedCoasters.containsKey('coasters')) {
            _totalCoasters = (decodedCoasters['coasters'] as List).length;
          }
        });
        
        // Load existing items to show counts in the UI
        _loadExistingItems();
      } catch (e) {
        print('Errore durante la conversione Excel: $e');
        setState(() {
          _isConverting = false;
          _statusMessage = 'Errore durante l\'elaborazione del file Excel: $e';
          _isSuccess = false;
        });
      }
    } catch (e) {
      print('Errore durante la selezione del file: $e');
      setState(() {
        _isConverting = false;
        _statusMessage = 'Errore durante la selezione del file: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _importAllData() async {
    if (_convertedJson == null) {
      setState(() {
        _statusMessage = 'Nessun JSON da importare';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Avvio dell\'importazione intelligente...';
      _isSuccess = true;
      _currentStage = "loading";
      _progress = 0.0;
      
      // Reset counters
      _successfulIngredients = 0;
      _failedIngredients = 0;
      _skippedIngredients = 0;
      _successfulRecipes = 0;
      _failedRecipes = 0;
      _skippedRecipes = 0;
      _successfulCoasters = 0;
      _failedCoasters = 0;
      _skippedCoasters = 0;
    });

    try {
      // 1. Load existing items from database
      await _loadExistingItems();
      
      // 2. Import ingredients (skipping existing ones)
      setState(() {
        _currentStage = "ingredients";
      });
      await _importIngredients();
      
      // 3. Import recipes (skipping existing ones)
      setState(() {
        _currentStage = "recipes";
      });
      await _importRecipes();
      
      // 4. Reload items to make sure we have the latest
      await _loadExistingItems();
      
      // 5. Import coasters (skipping existing ones)
      setState(() {
        _currentStage = "coasters";
      });
      await _importCoasters();
      
      // Mark as completed
      setState(() {
        _currentStage = "completed";
        _isLoading = false;
        _statusMessage = 'Importazione completata con successo!';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante l\'importazione: $e';
        _isSuccess = false;
      });
    }
  }
  
  Future<void> _importOnlyCoasters() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Importazione solo sottobicchieri...';
      _currentStage = "loading";
      _progress = 0.0;
      _successfulCoasters = 0;
      _failedCoasters = 0;
      _skippedCoasters = 0;
    });
    
    try {

      await _loadExistingItems();
      
      // Then import coasters
      setState(() {
        _currentStage = "coasters";
      });
      await _importCoasters();
      
      setState(() {
        _currentStage = "completed";
        _isLoading = false;
        _statusMessage = 'Importazione completata!';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante l\'importazione: $e';
        _isSuccess = false;
      });
    }
  }
  
  Future<void> _loadExistingItems() async {
    setState(() {
      _currentStage = "loading";
      _statusMessage = 'Caricamento elementi esistenti...';
    });
    
    try {
      // Clear old recipe     _availableRecipes.clear();
      _availableIngredients.clear();
      _recipeNameToId.clear();
      _ingredientNameToId.clear();
      _existingCoasters.clear();
      
      // Load recipes
      _availableRecipes = await _dbService.getRecipes().first;
      for (var recipe in _availableRecipes) {
        _recipeNameToId[recipe.name.toLowerCase()] = recipe.id;
      }
      
      // Load ingredients
      _availableIngredients = await _dbService.getIngredients().first;
      for (var ingredient in _availableIngredients) {
        _ingredientNameToId[ingredient.name.toLowerCase()] = ingredient.id;
      }
      
      // Load coasters
      final coasters = await _dbService.getCoasters().first;
      for (var coaster in coasters) {
        _existingCoasters.add('${coaster.recipeId}-${coaster.ingredientId}');
      }
      
      _logDebug('Caricati: ${_availableRecipes.length} pozioni, ${_availableIngredients.length} ingredienti, ${_existingCoasters.length} sottobicchieri');
      
      setState(() {
        _statusMessage += '\nElementi esistenti caricati.';
      });
    } catch (e) {
      _logDebug('Errore caricamento elementi: $e');
      setState(() {
        _statusMessage += '\nErrore caricamento elementi: $e';
      });
    }
  }
  
  Future<void> _importIngredients() async {
    setState(() {
      _currentStage = "ingredients";
      _statusMessage += '\nImportazione ingredienti in corso...';
    });
    
    try {
      // Get predefined ingredients from template
      final gameElementsJson = ExcelToJsonConverter.getGameElementsJson();
      final gameElements = json.decode(gameElementsJson);
      
      if (!gameElements.containsKey('ingredients')) {
        setState(() {
          _statusMessage += '\nTemplate ingredienti non trovato.';
          return;
        });
      }
      
      final ingredients = gameElements['ingredients'] as List;
      _totalIngredients = ingredients.length;
      
      for (int i = 0; i < ingredients.length; i++) {
        try {
          final ingredient = ingredients[i];
          
          // Check if this ingredient already exists
          String ingredientName = ingredient['name'];
          String normalizedName = ingredientName.toLowerCase();
          
          // Check if the ingredient already exists by name
          if (_recipeNameToId.containsKey(normalizedName)) {
            _logDebug('Ingrediente già esistente: $ingredientName');
            _skippedIngredients++;
          } else {
            // Create new ingredient
            String id = await _dbService.createIngredient(
              IngredientModel(
                id: '',
                name: ingredientName,
                description: ingredient['description'] ?? '',
                imageUrl: ingredient['imageUrl'] ?? '',
                family: ingredient['family'] ?? '',
              ),
            );
            
            // Update our maps with the new ingredient
            _ingredientNameToId[normalizedName] = id;
            _logDebug('Ingrediente creato: $ingredientName (ID: $id)');
            _successfulIngredients++;
          }
        } catch (e) {
          print('Errore importazione ingrediente: $e');
          _failedIngredients++;
        }
        
        // Update progress
        setState(() {
          _progress = i / ingredients.length;
        });
        
        // Add small delay to prevent UI freezing
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      setState(() {
        _statusMessage += '\nImportazione ingredienti completata.';
      });
    } catch (e) {
      print('Errore durante l\'importazione degli ingredienti: $e');
      setState(() {
        _statusMessage += '\nErrore durante l\'importazione degli ingredienti.';
      });
    }
  }
  
  Future<void> _importRecipes() async {
    setState(() {
      _currentStage = "recipes";
      _progress = 0.0;
      _statusMessage += '\nImportazione pozioni in corso...';
    });
    
    try {
      // Get predefined recipes from template
      final gameElementsJson = ExcelToJsonConverter.getGameElementsJson();
      final gameElements = json.decode(gameElementsJson);
      
      if (!gameElements.containsKey('recipes')) {
        setState(() {
          _statusMessage += '\nTemplate pozioni non trovato.';
          return;
        });
      }
      
      final recipes = gameElements['recipes'] as List;
      _totalRecipes = recipes.length;
      
      for (int i = 0; i < recipes.length; i++) {
        try {
          final recipe = recipes[i];
          
          // Check if this recipe already exists
          String recipeName = recipe['name'];
          String normalizedName = recipeName.toLowerCase();
          
          // Check if the recipe already exists
          if (_recipeNameToId.containsKey(normalizedName)) {
            _logDebug('Pozione già esistente: $recipeName');
            _skippedRecipes++;
          } else {
            // Create new recipe
            List<String> requiredIngredients = [];
            if (recipe['requiredIngredients'] is List) {
              requiredIngredients = List<String>.from(recipe['requiredIngredients']);
            }
            
            String id = await _dbService.createRecipe(
              RecipeModel(
                id: '',
                name: recipeName,
                description: recipe['description'] ?? '',
                requiredIngredients: requiredIngredients,
                imageUrl: recipe['imageUrl'] ?? '',
                family: recipe['family'] ?? '',
              ),
            );
            
            // Update our maps with the new recipe
            _recipeNameToId[normalizedName] = id;
            _logDebug('Pozione creata: $recipeName (ID: $id)');
            _successfulRecipes++;
          }
        } catch (e) {
          print('Errore importazione pozione: $e');
          _failedRecipes++;
        }
        
        // Update progress
        setState(() {
          _progress = i / recipes.length;
        });
        
        // Add small delay to prevent UI freezing
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      setState(() {
        _statusMessage += '\nImportazione pozioni completata.';
      });
    } catch (e) {
      print('Errore durante l\'importazione delle pozioni: $e');
      setState(() {
        _statusMessage += '\nErrore durante l\'importazione delle pozioni.';
      });
    }
  }
  
  Future<void> _importCoasters() async {
    setState(() {
      _currentStage = "coasters";
      _progress = 0.0;
      _statusMessage += '\nImportazione sottobicchieri in corso...';
    });
    
    try {
      final decodedJson = json.decode(_convertedJson!);
      
      if (!decodedJson.containsKey('coasters')) {
        setState(() {
          _statusMessage += '\nFormato JSON non valido, manca l\'array "coasters".';
          return;
        });
      }
      
      final coasters = decodedJson['coasters'] as List;
      
      if (coasters.isEmpty) {
        setState(() {
          _statusMessage += '\nNessun sottobicchiere da importare.';
          return;
        });
      }
      
      _totalCoasters = coasters.length;
      
      for (int i = 0; i < coasters.length; i++) {
        try {
          final coaster = coasters[i];
          
          if (coaster.containsKey('pozione') && coaster.containsKey('ingredienteRetro')) {
            final pozioneName = coaster['pozione'].toString().toLowerCase();
            final ingredienteName = coaster['ingredienteRetro'].toString().toLowerCase();
            
            _logDebug('Processando coaster: "$pozioneName", "$ingredienteName"');
            
            // Find matching recipe and ingredient
            String? recipeId = null;
            String? ingredientId = null;
            
            // Try exact match for recipe
            if (_recipeNameToId.containsKey(pozioneName)) {
              recipeId = _recipeNameToId[pozioneName];
            } else {
              // Try flexible match for recipe name
              for (var r in _availableRecipes) {
                if (_normalizeName(r.name).contains(_normalizeName(pozioneName)) || 
                    _normalizeName(pozioneName).contains(_normalizeName(r.name))) {
                  recipeId = r.id;
                  break;
                }
              }
            }
            
            // Try exact match for ingredient
            if (_ingredientNameToId.containsKey(ingredienteName)) {
              ingredientId = _ingredientNameToId[ingredienteName];
            } else {
              // Try flexible match for ingredient name
              for (var i in _availableIngredients) {
                if (_normalizeName(i.name).contains(_normalizeName(ingredienteName)) || 
                    _normalizeName(ingredienteName).contains(_normalizeName(i.name))) {
                  ingredientId = i.id;
                  break;
                }
              }
            }
            
            if (recipeId == null || ingredientId == null) {
              _logDebug('ID non trovati per: $pozioneName o $ingredienteName');
              _failedCoasters++;
              continue;
            }
            
            // Check if this combination already exists
            String coasterKey = '$recipeId-$ingredientId';
            if (_existingCoasters.contains(coasterKey)) {
              _logDebug('Sottobicchiere già esistente: $coasterKey');
              _skippedCoasters++;
              continue;
            }
            
            // Create the coaster
            _logDebug('Creazione sottobicchiere: recipeId=$recipeId, ingredientId=$ingredientId');
            await _dbService.createCoaster(recipeId, ingredientId);
            
            // Add to our set of existing coasters
            _existingCoasters.add(coasterKey);
            _successfulCoasters++;
          } else {
            _logDebug('Formato sottobicchiere non valido, manca pozione o ingrediente');
            _failedCoasters++;
          }
        } catch (e) {
          _logDebug('Errore importazione sottobicchiere: $e');
          _failedCoasters++;
        }
        
        // Update progress
        setState(() {
          _progress = i / coasters.length;
        });
        
        // Add small delay to avoid freezing UI
        if (i % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      setState(() {
        _statusMessage += '\nImportazione sottobicchieri completata.';
      });
    } catch (e) {
      _logDebug('Errore durante l\'importazione dei sottobicchieri: $e');
      setState(() {
        _statusMessage += '\nErrore durante l\'importazione dei sottobicchieri.';
      });
    }
  }
  
  String? _findRecipeId(String name) {
    String normalized = _normalizeName(name);
    
    // Try exact match
    for (var recipe in _availableRecipes) {
      if (_normalizeName(recipe.name) == normalized) {
        return recipe.id;
      }
    }
    
    // Try partial match
    for (var recipe in _availableRecipes) {
      if (_normalizeName(recipe.name).contains(normalized) || 
          normalized.contains(_normalizeName(recipe.name))) {
        return recipe.id;
      }
    }
    
    return null;
  }
  
  String? _findIngredientId(String name) {
    String normalized = _normalizeName(name);
    
    // Try exact match
    for (var ingredient in _availableIngredients) {
      if (_normalizeName(ingredient.name) == normalized) {
        return ingredient.id;
      }
    }
    
    // Try partial match
    for (var ingredient in _availableIngredients) {
      if (_normalizeName(ingredient.name).contains(normalized) || 
          normalized.contains(_normalizeName(ingredient.name))) {
        return ingredient.id;
      }
    }
    
    return null;
  }
}
