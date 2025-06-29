import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:potion_riders/services/database_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _dbService = DatabaseService();

  // Flag per indicare se l'utente è nuovo
  bool _isNewUser = false;

  // Getter per verificare se l'utente è nuovo
  bool get isNewUser => _isNewUser;

  // Metodo per resettare il flag
  void resetNewUserFlag() {
    _isNewUser = false;
    notifyListeners();
  }

  // Stream per lo stato dell'autenticazione
  Stream<String?> get user {
    return _auth.authStateChanges().map((User? user) => user?.uid);
  }

  // Registrazione con email e password
  Future<UserCredential> register(String email, String password, String nickname) async {
    try {
      // Verifichiamo l'unicità del nickname
      final bool isUnique = await _dbService.isNicknameUnique(nickname);

      if (!isUnique) {
        throw FirebaseAuthException(
          code: 'nickname-already-in-use',
          message: 'Il nickname è già in uso, scegline un altro',
        );
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Crea profilo utente nel database
      await _dbService.createUser(
        result.user!.uid,
        email,
        nickname,
      );

      return result;
    } catch (e) {
      debugPrint('Error registering user: $e');
      rethrow;
    }
  }

  // Login con email e password
  Future<UserCredential> login(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }

  // Login con Google - VERSIONE CORRETTA
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Verifica se siamo su web o mobile
      if (kIsWeb) {
        // Processo per Web
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        UserCredential result = await _auth.signInWithPopup(authProvider);

        // Processa l'utente dopo l'autenticazione
        await _processGoogleUser(result);
        return result;
      } else {
        // Processo per mobile
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) return null;

        // Ottieni dettagli autenticazione
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Crea credenziale
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Autenticazione con Firebase
        UserCredential result = await _auth.signInWithCredential(credential);

        // Processa l'utente dopo l'autenticazione
        await _processGoogleUser(result);
        return result;
      }
    } catch (e) {
      debugPrint('Errore accesso con Google: $e');
      rethrow;
    }
  }

  // Metodo separato per processare l'utente Google
  Future<void> _processGoogleUser(UserCredential result) async {
    try {
      final user = result.user!;

      // Verifica se l'utente esiste già nel database con retry
      DocumentSnapshot? userDoc;
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        try {
          userDoc = await _firestore.collection('users').doc(user.uid).get();
          break;
        } catch (e) {
          attempts++;
          if (attempts >= maxAttempts) rethrow;
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }

      // Se è la prima volta che l'utente accede, crea il profilo nel database
      if (userDoc == null || !userDoc.exists) {
        // Verifichiamo l'unicità del nickname
        String nickname = user.displayName ?? 'Giocatore';
        bool isUnique = await _dbService.isNicknameUnique(nickname);

        // Se il nickname non è unico, aggiungiamo un suffisso numerico
        if (!isUnique) {
          int suffix = 1;
          String originalNickname = nickname;
          while (!isUnique && suffix < 100) {
            nickname = '${originalNickname}_$suffix';
            isUnique = await _dbService.isNicknameUnique(nickname);
            suffix++;
          }
        }

        // Crea l'utente nel database
        await _dbService.createUser(
          user.uid,
          user.email ?? '',
          nickname,
          photoUrl: user.photoURL,
        );

        // Imposta il flag che indica un nuovo utente
        _isNewUser = true;
        debugPrint('New user created: ${user.uid}');

        // Attendi un momento per assicurarsi che i dati siano scritti
        await Future.delayed(const Duration(milliseconds: 1000));

        notifyListeners();
      } else {
        debugPrint('Existing user logged in: ${user.uid}');
        _isNewUser = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error processing Google user: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _isNewUser = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out: $e');
      rethrow;
    }
  }

  // Ottieni l'utente corrente (Firebase Auth)
  User? get currentUser => _auth.currentUser;
}