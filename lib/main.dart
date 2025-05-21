import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:potion_riders/app.dart';
import 'package:potion_riders/firebase_options.dart';
import 'package:potion_riders/services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inizializziamo i dati di gioco se necessario
  final dbService = DatabaseService();
  await dbService.seedGameElementsIfNeeded();

  runApp(const PotionRidersApp());
}