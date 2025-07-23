import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:potion_riders/services/database_service.dart';

class RoomService with ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // Crea una nuova stanza
  Future<String> createRoom(String hostId, String recipeId) async {
    String roomId = await _db.createRoom(hostId, recipeId);
    notifyListeners();
    return roomId;
  }

  // Unisciti a una stanza con gestione migliorata
  Future<Map<String, dynamic>> joinRoom(
      String roomId, String userId, String ingredientId) async {
    try {
      debugPrint('🎯 RoomService: Attempting to join room $roomId');

      final result = await _db.joinRoomWithIngredientValidation(
          roomId, userId, ingredientId);

      if (result['success'] == true) {
        debugPrint('✅ RoomService: Join successful, notifying listeners');
        notifyListeners();
        return result;
      } else {
        debugPrint('❌ RoomService: Join failed - ${result['error']}');
        return result;
      }
    } catch (e) {
      debugPrint('❌ RoomService: Exception during join - $e');
      return {
        'success': false,
        'error': 'Errore del servizio durante il join: $e',
        'validation': null,
      };
    }
  }

// Metodo helper per verificare la compatibilità prima del join
  Future<Map<String, dynamic>> checkRoomCompatibility(
      String roomId, String userId) async {
    try {
      return await _db.validateIngredientMatch(roomId, userId);
    } catch (e) {
      debugPrint('Error checking room compatibility: $e');
      return {
        'canJoin': false,
        'reason': 'Errore durante la verifica di compatibilità: $e',
        'userIngredient': '',
        'requiredIngredients': <String>[],
        'presentIngredients': <String>[],
        'missingIngredients': <String>[],
      };
    }
  }


  // Conferma partecipazione
  Future<bool> confirmParticipation(String roomId, String userId) async {
    try {
      await _db.confirmParticipation(roomId, userId);

      // Controlla se la stanza è pronta per essere completata
      bool isReady = await _db.isRoomReadyToComplete(roomId).first;

      // Se tutti hanno confermato, completa automaticamente la stanza
      if (isReady) {
        await _db.completeRoom(roomId);
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('Error confirming participation: $e');
      return false;
    }
  }

  // Completa una stanza
  Future<bool> completeRoom(String roomId) async {
    try {
      await _db.completeRoom(roomId);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error completing room: $e');
      return false;
    }
  }

  // Genera dati per QR code
  String generateQrData(String roomId) {
    Map<String, dynamic> qrData = {
      'type': 'potion_riders_room',
      'roomId': roomId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(qrData);
  }

  // Analizza dati da QR code
  Map<String, dynamic>? parseQrData(String qrData) {
    try {
      Map<String, dynamic> data = jsonDecode(qrData);
      if (data['type'] == 'potion_riders_room') {
        return data;
      }
      return null;
    } catch (e) {
      print('Error parsing QR data: $e');
      return null;
    }
  }

  // Verifica se un utente può unirsi a una stanza
  Future<bool> canJoinRoom(String roomId, String userId) async {
    try {
      final room = await _db.getRoom(roomId).first;

      if (room == null || room.isCompleted) {
        return false;
      }

      // Verifica se l'utente è già nella stanza
      if (room.participants.any((p) => p.userId == userId) ||
          room.hostId == userId) {
        return false;
      }

      // Verifica se c'è ancora spazio nella stanza (massimo 3 partecipanti)
      if (room.participants.length >= 3) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking if user can join room: $e');
      return false;
    }
  }
}
