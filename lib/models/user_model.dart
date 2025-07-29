import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String email;
  final String nickname;
  final String photoUrl;
  final String house;
  final String role;
  final int points;
  final String gameUuid;
  final String? currentRecipeId;
  final String? currentIngredientId;
  final List<String> rooms;
  final List<String> completedRooms;

  UserModel({
    required this.id,
    required this.email,
    required this.nickname,
    required this.photoUrl,
    required this.house,
    required this.role,
    required this.points,
    required this.gameUuid,
    this.currentRecipeId,
    this.currentIngredientId,
    required this.rooms,
    required this.completedRooms,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      nickname: map['nickname'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      house: map['house'] ?? 'Senza Casata',
      role: map['role'] ?? 'player',
      points: map['points'] ?? 0,
      gameUuid: map['gameUuid'] ?? '',
      currentRecipeId: map['currentRecipeId'],
      currentIngredientId: map['currentIngredientId'],
      rooms: List<String>.from(map['rooms'] ?? []),
      completedRooms: List<String>.from(map['completedRooms'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'house': house,
      'role': role,
      'points': points,
      'gameUuid': gameUuid,
      'currentRecipeId': currentRecipeId,
      'currentIngredientId': currentIngredientId,
      'rooms': rooms,
      'completedRooms': completedRooms,
    };
  }

  Color getHouseColor() {
    switch (house) {
      case 'Rospo Verde':
        return Colors.green;
      case 'Gatto Nero':
        return Colors.purple;
      case 'Merlo d\'Oro':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData getHouseIcon() {
    switch (house) {
      case 'Rospo Verde':
        return Icons.pets;
      case 'Gatto Nero':
        return Icons.pets;
      case 'Merlo d\'Oro':
        return Icons.pets;
      default:
        return Icons.help_outline;
    }
  }
}