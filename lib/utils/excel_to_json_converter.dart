import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';

/// Utility class to convert Excel data to JSON
class ExcelToJsonConverter {
  static Future<String> convertExcelToJson(List<int> excelBytes) async {
    // Parse the Excel file
    final excel = Excel.decodeBytes(Uint8List.fromList(excelBytes));

    // Get the first sheet (assuming data is in the first sheet)
    final sheet = excel.tables.keys.first;
    final rows = excel.tables[sheet]!.rows;

    if (rows.isEmpty) {
      throw Exception('Excel file is empty');
    }

    // Extract header row (assuming first row contains headers)
    final headers = rows[0].map((cell) => cell?.value.toString() ?? '').toList();

    // Find required column indices
    final idIndex = headers.indexOf('ID');
    final pozioneIndex = headers.indexOf('Pozione');
    final ingredienteRetroIndex = headers.indexOf('Ingrediente Retro');
    final claimIndex = headers.indexOf('Claim');

    if (pozioneIndex == -1 || ingredienteRetroIndex == -1) {
      throw Exception('Required columns not found. Need at least Pozione and Ingrediente Retro columns.');
    }

    // Create coasters list
    List<Map<String, dynamic>> coasters = [];

    // Skip header row and process data rows
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((cell) => cell?.value == null)) continue;

      Map<String, dynamic> coaster = {};

      // Extract ID if available
      if (idIndex != -1 && row.length > idIndex && row[idIndex]?.value != null) {
        dynamic id = row[idIndex]!.value;
        coaster['id'] = id is int ? id : int.tryParse(id.toString()) ?? i;
      } else {
        coaster['id'] = i;  // Use row number as fallback ID
      }

      // Extract pozione
      if (row.length > pozioneIndex && row[pozioneIndex]?.value != null) {
        coaster['pozione'] = row[pozioneIndex]!.value.toString();
      } else {
        continue;  // Skip if no pozione
      }

      // Extract ingrediente retro
      if (row.length > ingredienteRetroIndex && row[ingredienteRetroIndex]?.value != null) {
        coaster['ingredienteRetro'] = row[ingredienteRetroIndex]!.value.toString();
      } else {
        continue;  // Skip if no ingrediente retro
      }

      // Extract claim if available
      if (claimIndex != -1 && row.length > claimIndex && row[claimIndex]?.value != null) {
        coaster['claim'] = row[claimIndex]!.value.toString();
      }

      coasters.add(coaster);
    }

    // Create final JSON
    Map<String, dynamic> jsonData = {
      "coasters": coasters
    };

    return json.encode(jsonData);
  }

  /// Generate the predefined game elements JSON
  static String getGameElementsJson() {
    Map<String, dynamic> jsonData = {
      "recipes": [
        {
          "name": "Pozione dell'Eureka",
          "description": "Un intruglio che stimola la mente e porta grandi idee",
          "requiredIngredients": ["Radice di Mandragora", "Polvere di Luna", "Essenza di Ispirazione"],
          "imageUrl": "",
          "family": "Creatività"
        },
        {
          "name": "Elisir della Fortuna",
          "description": "Garantisce un giorno fortunato a chi lo beve",
          "requiredIngredients": ["Quadrifoglio Dorato", "Scaglie di Drago", "Rugiada dell'Alba"],
          "imageUrl": "",
          "family": "Fortuna"
        },
        {
          "name": "Filtro della Velocità",
          "description": "Aumenta l'agilità e i riflessi per breve tempo",
          "requiredIngredients": ["Piuma di Fenice", "Goccia di Mercurio", "Petalo di Rosa Nera"],
          "imageUrl": "",
          "family": "Movimento"
        },
        {
          "name": "Infuso della Saggezza",
          "description": "Dona temporaneamente conoscenza e saggezza al bevitore",
          "requiredIngredients": ["Foglia d'Acanto", "Cristallo di Quarzo", "Inchiostro di Seppia"],
          "imageUrl": "",
          "family": "Conoscenza"
        },
        {
          "name": "Tonico del Coraggio",
          "description": "Elimina la paura e dona coraggio in situazioni difficili",
          "requiredIngredients": ["Crine di Leone", "Ambra Fossile", "Fiore del Vulcano"],
          "imageUrl": "",
          "family": "Coraggio"
        }
      ],
      "ingredients": [
        {
          "name": "Radice di Mandragora",
          "description": "Una radice rara che amplifica le capacità mentali",
          "imageUrl": "",
          "family": "Erbe"
        },
        {
          "name": "Polvere di Luna",
          "description": "Raccolta durante la luna piena, ha proprietà magiche potenti",
          "imageUrl": "",
          "family": "Elementi"
        },
        {
          "name": "Essenza di Ispirazione",
          "description": "Distillata dai sogni di artisti e inventori",
          "imageUrl": "",
          "family": "Essenze"
        },
        {
          "name": "Quadrifoglio Dorato",
          "description": "Raro quadrifoglio che porta fortuna a chi lo possiede",
          "imageUrl": "",
          "family": "Piante"
        },
        {
          "name": "Scaglie di Drago",
          "description": "Scaglie luminescenti che emanano energia antica",
          "imageUrl": "",
          "family": "Creature"
        },
        {
          "name": "Rugiada dell'Alba",
          "description": "Raccolta all'alba del solstizio d'estate",
          "imageUrl": "",
          "family": "Elementi"
        },
        {
          "name": "Piuma di Fenice",
          "description": "Incandescente e leggerissima, conferisce rapidità",
          "imageUrl": "",
          "family": "Creature"
        },
        {
          "name": "Goccia di Mercurio",
          "description": "Elemento fluido che accelera i movimenti",
          "imageUrl": "",
          "family": "Elementi"
        },
        {
          "name": "Petalo di Rosa Nera",
          "description": "Raro fiore che cresce solo nelle notti senza luna",
          "imageUrl": "",
          "family": "Piante"
        },
        {
          "name": "Foglia d'Acanto",
          "description": "Simbolo di saggezza e conoscenza profonda",
          "imageUrl": "",
          "family": "Erbe"
        },
        {
          "name": "Cristallo di Quarzo",
          "description": "Amplifica i pensieri e chiarisce la mente",
          "imageUrl": "",
          "family": "Minerali"
        },
        {
          "name": "Inchiostro di Seppia",
          "description": "Contiene la saggezza degli oceani",
          "imageUrl": "",
          "family": "Creature"
        },
        {
          "name": "Crine di Leone",
          "description": "Simbolo di coraggio e forza interiore",
          "imageUrl": "",
          "family": "Creature"
        },
        {
          "name": "Ambra Fossile",
          "description": "Contiene memorie ancestrali di coraggio",
          "imageUrl": "",
          "family": "Minerali"
        },
        {
          "name": "Fiore del Vulcano",
          "description": "Cresce solo ai bordi dei crateri vulcanici attivi",
          "imageUrl": "",
          "family": "Piante"
        }
      ]
    };

    return json.encode(jsonData);
  }
}