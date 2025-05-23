import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:potion_riders/services/database_service.dart';

class DirectImportScreen extends StatefulWidget {
  const DirectImportScreen({Key? key}) : super(key: key);

  @override
  _DirectImportScreenState createState() => _DirectImportScreenState();
}

class _DirectImportScreenState extends State<DirectImportScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _jsonController = TextEditingController();
  String _statusMessage = '';
  bool _isSuccess = false;
  bool _isProcessing = false;

  // Variabili per il caricamento a blocchi
  int _chunkSize = 6;
  int _totalItems = 0;
  int _processedItems = 0;
  int _successCount = 0;
  int _failCount = 0;
  List<dynamic> _coastersToProcess = [];
  bool _processingChunks = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importazione Diretta JSON'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _jsonController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Incolla qui il tuo JSON...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Dimensione blocco: $_chunkSize'),
                Expanded(
                  child: Slider(
                    value: _chunkSize.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: _chunkSize.toString(),
                    onChanged: (value) {
                      setState(() {
                        _chunkSize = value.toInt();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_processingChunks) ...[
              LinearProgressIndicator(
                value: _totalItems > 0 ? _processedItems / _totalItems : 0,
              ),
              const SizedBox(height: 8),
              Text('Processati $_processedItems di $_totalItems sottobicchieri'),
              Text('Successo: $_successCount | Falliti: $_failCount'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isProcessing ? null : _cancelProcessing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Annulla Importazione'),
              ),
            ] else if (_isProcessing) ...[
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              ElevatedButton(
                onPressed: _processJson,
                child: const Text('Importa JSON'),
              ),
            ],
            if (_statusMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Text(_statusMessage),
              ),
          ],
        ),
      ),
    );
  }

  void _cancelProcessing() {
    setState(() {
      _processingChunks = false;
      _coastersToProcess = [];
      _statusMessage = 'Importazione annullata.';
      _isSuccess = false;
    });
  }

  Future<void> _processJson() async {
    if (_jsonController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Inserisci del JSON prima di importare';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '';
    });

    try {
      // Decodifica e verifica il JSON
      final dynamic decodedJson = json.decode(_jsonController.text);

      // Verifica la struttura del JSON
      if (decodedJson is! Map<String, dynamic> || !decodedJson.containsKey('coasters')) {
        setState(() {
          _statusMessage = 'Il JSON deve essere un oggetto con un campo "coasters"';
          _isSuccess = false;
          _isProcessing = false;
        });
        return;
      }

      final List<dynamic>? coasters = decodedJson['coasters'] as List<dynamic>?;

      if (coasters == null || coasters.isEmpty) {
        setState(() {
          _statusMessage = 'Il campo "coasters" è vuoto o non è un array';
          _isSuccess = false;
          _isProcessing = false;
        });
        return;
      }

      // Inizializza le variabili per il caricamento a blocchi
      _totalItems = coasters.length;
      _processedItems = 0;
      _successCount = 0;
      _failCount = 0;
      _coastersToProcess = List.from(coasters);

      setState(() {
        _processingChunks = true;
        _isProcessing = false;
        _statusMessage = 'Iniziando il caricamento di $_totalItems sottobicchieri in blocchi di $_chunkSize';
        _isSuccess = true;
      });

      // Avvia il caricamento del primo blocco
      _processNextChunk();

    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante l\'elaborazione: $e';
        _isSuccess = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _processNextChunk() async {
    if (!_processingChunks || _coastersToProcess.isEmpty) {
      // Caricamento completato o annullato
      setState(() {
        _processingChunks = false;
        _statusMessage = 'Importazione completata: $_successCount sottobicchieri importati con successo, $_failCount falliti.';
        _isSuccess = _failCount == 0;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Raccogli prima tutti i dati di pozioni e ingredienti disponibili
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

      // Prendi il prossimo blocco di coasters da processare
      int chunkEnd = _chunkSize < _coastersToProcess.length ? _chunkSize : _coastersToProcess.length;
      List<dynamic> currentChunk = _coastersToProcess.sublist(0, chunkEnd);
      _coastersToProcess = _coastersToProcess.sublist(chunkEnd);

      // Processa ogni coaster nel blocco corrente
      for (var coasterData in currentChunk) {
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
              _failCount++;
              print('ID non trovati per: $pozioneName o $ingredienteName');
            } else {
              // Crea il sottobicchiere
              String coasterId = await _dbService.createCoaster(recipeId, ingredientId);
              _successCount++;
              print('Sottobicchiere creato con ID: $coasterId');
            }
          } else {
            _failCount++;
            print('Mancano campi richiesti in: $coasterData');
          }
        } catch (e) {
          _failCount++;
          print('Errore durante l\'elaborazione: $e');
        }

        _processedItems++;
      }

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Processati $_processedItems di $_totalItems sottobicchieri. Successo: $_successCount, Falliti: $_failCount';
        _isSuccess = true;
      });

      // Attendi un breve periodo e poi processa il prossimo blocco
      await Future.delayed(const Duration(milliseconds: 500));
      _processNextChunk();

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Errore durante l\'elaborazione del blocco: $e';
        _isSuccess = false;
        _processingChunks = false;
      });
    }
  }
}