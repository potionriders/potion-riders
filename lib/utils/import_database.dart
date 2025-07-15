import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:potion_riders/services/database_service.dart';

class ImportCoastersJsonScreen extends StatefulWidget {
  const ImportCoastersJsonScreen({super.key});

  @override
  _ImportCoastersJsonScreenState createState() => _ImportCoastersJsonScreenState();
}

class _ImportCoastersJsonScreenState extends State<ImportCoastersJsonScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _jsonController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  List<Map<String, dynamic>> _parsedCoasters = [];
  int _totalCoasters = 0;
  int _processedCoasters = 0;
  int _successfulCoasters = 0;
  int _failedCoasters = 0;

  // Esempio di dati JSON predefiniti
  final String _sampleJson = '''
[
  {
    "pozione": "Pozione dell'Eureka",
    "ingredienteRetro": "Radice di Mandragora"
  },
  {
    "pozione": "Elisir della Fortuna",
    "ingredienteRetro": "Quadrifoglio Dorato"
  }
]
''';

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importa Sottobicchieri (JSON)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
                      const Text(
                        'Importa JSON',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Incolla i dati JSON dei sottobicchieri o carica un file JSON.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _jsonController,
                        decoration: InputDecoration(
                          labelText: 'Dati JSON',
                          hintText: 'Incolla qui il tuo JSON...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste),
                            tooltip: 'Incolla dagli appunti',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data != null && data.text != null) {
                                _jsonController.text = data.text!;
                              }
                            },
                          ),
                        ),
                        maxLines: 10,
                        minLines: 5,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : () => _pickJsonFile(),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Carica file JSON'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : () {
                              _jsonController.text = _sampleJson;
                            },
                            icon: const Icon(Icons.code),
                            label: const Text('Esempio'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading || _jsonController.text.isEmpty
                            ? null
                            : () => _parseJsonText(),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Controlla JSON'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_parsedCoasters.isNotEmpty) ...[
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
                            const Icon(Icons.list_alt, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Sottobicchieri trovati: $_totalCoasters',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Mostra un'anteprima dei primi 3 sottobicchieri
                        if (_parsedCoasters.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Anteprima:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...List.generate(
                                  _parsedCoasters.length > 3 ? 3 : _parsedCoasters.length,
                                      (index) {
                                    final coaster = _parsedCoasters[index];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.tab, size: 20),
                                      title: Text(
                                        'Pozione: ${coaster['pozione']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        'Ingrediente: ${coaster['ingredienteRetro']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  },
                                ),
                                if (_parsedCoasters.length > 3)
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('...e altri'),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (_parsedCoasters.isNotEmpty && _processedCoasters == 0)
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _uploadCoasters(),
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Carica sottobicchieri su Firestore'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Colors.green,
                            ),
                          ),
                        if (_processedCoasters > 0) ...[
                          LinearProgressIndicator(
                            value: _processedCoasters / _totalCoasters,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isLoading ? Colors.blue : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Caricati $_processedCoasters/$_totalCoasters sottobicchieri',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Successo: $_successfulCoasters',
                                style: TextStyle(color: Colors.green[700]),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.error, color: Colors.red[700], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Falliti: $_failedCoasters',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty) _buildStatusMessage(),
            ],
          ),
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

  Future<void> _pickJsonFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    // Modifica nel metodo _pickExcelFile o simile in import_database.dart
    try {
      // Seleziona file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        withData: true,  // Assicurati che questo sia true
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      // Aggiungi log per debugging
      print("Nome file: ${file.name}");
      print("Dimensione file: ${file.size}");
      print("Bytes disponibili: ${file.bytes != null}");

      // Alternative per leggere il file se i bytes sono nulli
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        // Prova a leggere il file dal percorso se i bytes non sono disponibili
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (e) {
          print("Errore lettura file da path: $e");
          bytes = Uint8List(0);
        }
      } else {
        bytes = Uint8List(0);
      }

      if (bytes.isEmpty) {
        setState(() {
          _statusMessage = 'File vuoto o non leggibile. Controlla i log per dettagli.';
          _isSuccess = false;
          _isLoading = false;
        });
        return;
      }

      // Decodifica i bytes come testo UTF-8
      final String content = utf8.decode(bytes);
      _jsonController.text = content;

      setState(() {
        _statusMessage = 'File caricato con successo';
        _isSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante il caricamento del file: $e';
        _isSuccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _parseJsonText() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _parsedCoasters = [];
    });

    try {
      final jsonText = _jsonController.text.trim();
      if (jsonText.isEmpty) {
        setState(() {
          _statusMessage = 'Inserisci i dati JSON';
          _isSuccess = false;
          _isLoading = false;
        });
        return;
      }

      // Decodifica il JSON
      final dynamic decodedJson = json.decode(jsonText);

      if (decodedJson is! List) {
        setState(() {
          _statusMessage = 'Il JSON deve essere un array di oggetti';
          _isSuccess = false;
          _isLoading = false;
        });
        return;
      }

      _parsedCoasters = [];

      // Converti ogni oggetto in un formato coerente
      for (var item in decodedJson) {
        if (item is Map<String, dynamic>) {
          // Controlla se contiene i campi necessari
          if (item.containsKey('pozione') && item.containsKey('ingredienteRetro')) {
            _parsedCoasters.add({
              'pozione': item['pozione'],
              'ingredienteRetro': item['ingredienteRetro'],
              'ingredienti': item['ingredienti'] ?? [],
              'claim': item['claim'] ?? '',
            });
          }
        }
      }

      _totalCoasters = _parsedCoasters.length;

      setState(() {
        _statusMessage = 'JSON analizzato con successo: $_totalCoasters sottobicchieri trovati';
        _isSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante l\'analisi del JSON: $e';
        _isSuccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadCoasters() async {
    if (_parsedCoasters.isEmpty) {
      setState(() {
        _statusMessage = 'Nessun sottobicchiere da caricare';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Caricamento sottobicchieri in corso...';
      _isSuccess = true;
      _processedCoasters = 0;
      _successfulCoasters = 0;
      _failedCoasters = 0;
    });

    try {
      // Recupera le liste di pozioni e ingredienti per trovare gli ID
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

      // Processa ogni sottobicchiere
      for (int i = 0; i < _parsedCoasters.length; i++) {
        final coaster = _parsedCoasters[i];

        try {
          // Cerca gli ID per nome
          final pozioneName = coaster['pozione'].toString().toLowerCase();
          final ingredienteName = coaster['ingredienteRetro'].toString().toLowerCase();

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
            throw Exception('ID non trovati per pozione o ingrediente');
          }

          // Crea il sottobicchiere
          await _dbService.createCoaster(recipeId, ingredientId);
          _successfulCoasters++;
        } catch (e) {
          _failedCoasters++;
          print('Errore durante il caricamento del sottobicchiere ${i + 1}: $e');
        }

        _processedCoasters++;

        // Aggiorna lo stato ogni 5 coaster per non sovraccaricare l'interfaccia
        if (_processedCoasters % 5 == 0 || _processedCoasters == _totalCoasters) {
          setState(() {});
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Caricamento completato: $_successfulCoasters sottobicchieri caricati, $_failedCoasters falliti';
        _isSuccess = _failedCoasters == 0;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore durante il caricamento: $e';
        _isSuccess = false;
      });
    }
  }
}