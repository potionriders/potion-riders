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

  // Login con Google
  Future<UserCredential?> signInWithGoogleOld() async {
    try {
      // Trigger del flusso di autenticazione
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Se l'utente annulla il login, ritorna null
      if (googleUser == null) return null;

      // Ottieni i dettagli dell'autenticazione dalla richiesta
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Crea una nuova credenziale
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Una volta autenticato, torna il risultato dell'UserCredential
      UserCredential result = await _auth.signInWithCredential(credential);

      // Verifica se l'utente esiste già nel database
      final userDoc = await _firestore.collection('users').doc(result.user!.uid).get();

      // Se è la prima volta che l'utente accede, crea il profilo nel database
      if (!userDoc.exists) {
        // Verifichiamo l'unicità del nickname
        String nickname = result.user!.displayName ?? 'Giocatore';
        bool isUnique = await _dbService.isNicknameUnique(nickname);

        // Se il nickname non è unico, aggiungiamo un suffisso numerico
        if (!isUnique) {
          int suffix = 1;
          while (!isUnique) {
            nickname = '${result.user!.displayName ?? 'Giocatore'}_$suffix';
            isUnique = await _dbService.isNicknameUnique(nickname);
            suffix++;
          }
        }

        await _dbService.createUser(
          result.user!.uid,
          result.user!.email ?? '',
          nickname,
          photoUrl: result.user!.photoURL,
        );

        // Imposta il flag che indica un nuovo utente
        _isNewUser = true;
        debugPrint('New user created: ${result.user!.uid}');
        notifyListeners();
      } else {
        debugPrint('Existing user logged in: ${result.user!.uid}');
      }

      return result;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');

      // Log più dettagliato per le eccezioni di Google Sign-In
      if (e is PlatformException) {
        debugPrint('PlatformException details:');
        debugPrint('  Code: ${e.code}');
        debugPrint('  Message: ${e.message}');
        debugPrint('  Details: ${e.details}');
      }

      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error logging out: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Verifica se siamo su web o mobile
      if (kIsWeb) {
        // Processo per Web
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      } else {
        // Processo per mobile - necessita correzione
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

        // Resto del codice per verificare e creare utente...
        final userDoc = await _firestore.collection('users').doc(result.user!.uid).get();

        if (!userDoc.exists) {
          // Verifichiamo l'unicità del nickname
          String nickname = result.user!.displayName ?? 'Giocatore';
          bool isUnique = await _dbService.isNicknameUnique(nickname);

          // Se il nickname non è unico, aggiungiamo un suffisso numerico
          if (!isUnique) {
            int suffix = 1;
            while (!isUnique) {
              nickname = '${result.user!.displayName ?? 'Giocatore'}_$suffix';
              isUnique = await _dbService.isNicknameUnique(nickname);
              suffix++;
            }
          }

          await _dbService.createUser(
            result.user!.uid,
            result.user!.email ?? '',
            nickname,
            photoUrl: result.user!.photoURL,
          );

          // Imposta il flag che indica un nuovo utente
          _isNewUser = true;
          debugPrint('New user created: ${result.user!.uid}');
          notifyListeners();
        }

        return result;
      }
    } catch (e) {
      debugPrint('Errore accesso con Google: $e');

      if (e is PlatformException) {
        debugPrint('Dettagli PlatformException:');
        debugPrint('  Codice: ${e.code}');
        debugPrint('  Messaggio: ${e.message}');
        debugPrint('  Dettagli: ${e.details}');
      }

      rethrow;
    }
  }

  // Ottieni l'utente corrente (Firebase Auth)
  User? get currentUser => _auth.currentUser;
}