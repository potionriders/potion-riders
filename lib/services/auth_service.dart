// ===================================================================
// AUTHSERVICE SEMPLIFICATO - Stop Loop Infinito
// ===================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:potion_riders/services/database_service.dart';

enum OnboardingStage {
  none,           // Utente completo
  completeProfile, // Deve completare profilo
  selectHouse,    // Deve selezionare casata
}

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _dbService = DatabaseService();

  // Stato onboarding
  OnboardingStage _onboardingStage = OnboardingStage.none;
  Map<String, dynamic>? _pendingUserData;
  bool _isCheckingStatus = false; // NUOVO: Previene check multipli

  // Getters
  OnboardingStage get onboardingStage => _onboardingStage;
  Map<String, dynamic>? get pendingUserData => _pendingUserData;
  bool get needsOnboarding => _onboardingStage != OnboardingStage.none;
  bool get isCheckingStatus => _isCheckingStatus;

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

      // Crea l'utente Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // SALVA i dati temporaneamente per l'onboarding
      _pendingUserData = {
        'uid': result.user!.uid,
        'email': email,
        'nickname': nickname,
        'photoUrl': result.user!.photoURL ?? '',
        'authType': 'email',
      };

      // Imposta stage onboarding: per email, parte da selectHouse (nickname già fornito)
      _onboardingStage = OnboardingStage.selectHouse;
      notifyListeners();

      debugPrint('🔥 Email registration completed - Stage: $_onboardingStage');
      return result;
    } catch (e) {
      debugPrint('Error registering user: $e');
      rethrow;
    }
  }

  // Login con email e password
  Future<UserCredential> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // IMPORTANTE: Non chiamare checkUserOnboardingStatus qui
      // Sarà chiamato una volta sola dall'AuthWrapper

      return result;
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }

  // Login con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential result;

      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        result = await _auth.signInWithPopup(authProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        result = await _auth.signInWithCredential(credential);
      }

      // Processa l'utente dopo l'autenticazione
      await _processGoogleUser(result);
      return result;
    } catch (e) {
      debugPrint('Errore accesso con Google: $e');
      rethrow;
    }
  }

  // Processa l'utente Google
  Future<void> _processGoogleUser(UserCredential result) async {
    try {
      final user = result.user!;

      // Verifica se l'utente esiste già nel database
      DocumentSnapshot? userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Nuovo utente Google - prepara nickname unico
        String nickname = user.displayName ?? 'Giocatore';
        bool isUnique = await _dbService.isNicknameUnique(nickname);

        if (!isUnique) {
          int suffix = 1;
          String originalNickname = nickname;
          while (!isUnique && suffix < 100) {
            nickname = '${originalNickname}_$suffix';
            isUnique = await _dbService.isNicknameUnique(nickname);
            suffix++;
          }
        }

        // SALVA i dati temporaneamente per l'onboarding
        _pendingUserData = {
          'uid': user.uid,
          'email': user.email ?? '',
          'nickname': nickname,
          'photoUrl': user.photoURL ?? '',
          'authType': 'google',
        };

        // Imposta stage onboarding: per Google, parte da completeProfile
        _onboardingStage = OnboardingStage.completeProfile;
        notifyListeners();

        debugPrint('🔥 New Google user - Stage: $_onboardingStage');
      } else {
        // Utente esistente - NON chiamare checkUserOnboardingStatus qui
        // Sarà chiamato dall'AuthWrapper
        debugPrint('🔥 Existing Google user logged in');
      }
    } catch (e) {
      debugPrint('Error processing Google user: $e');
      rethrow;
    }
  }

  // SEMPLIFICATO: Controlla lo stato di onboarding UNA VOLTA SOLA
  Future<void> checkUserOnboardingStatus() async {
    if (_isCheckingStatus) {
      debugPrint('🛑 Already checking status, skipping...');
      return;
    }

    _isCheckingStatus = true;
    debugPrint('🔍 Checking user onboarding status...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _onboardingStage = OnboardingStage.none;
        _pendingUserData = null;
        notifyListeners();
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        // Utente auth ma non nel DB - richiede complete profile
        _pendingUserData = {
          'uid': user.uid,
          'email': user.email ?? '',
          'nickname': user.displayName ?? 'Giocatore',
          'photoUrl': user.photoURL ?? '',
          'authType': 'existing',
        };
        _onboardingStage = OnboardingStage.completeProfile;
        debugPrint('🔥 User not in DB - Stage: completeProfile');
        notifyListeners();
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final house = userData['house'] as String?;
      final nickname = userData['nickname'] as String?;

      // Determina quale stage è necessario
      if (nickname == null || nickname.isEmpty) {
        // Manca nickname - complete profile
        _pendingUserData = {
          'uid': user.uid,
          'email': userData['email'] ?? user.email ?? '',
          'nickname': user.displayName ?? 'Giocatore',
          'photoUrl': userData['photoUrl'] ?? user.photoURL ?? '',
          'authType': 'migration',
        };
        _onboardingStage = OnboardingStage.completeProfile;
        debugPrint('🔥 Missing nickname - Stage: completeProfile');
      } else if (house == null || house.isEmpty || house == 'Senza Casata') {
        // Manca casata - select house
        _pendingUserData = {
          'uid': user.uid,
          'email': userData['email'],
          'nickname': userData['nickname'],
          'photoUrl': userData['photoUrl'],
          'authType': 'migration',
        };
        _onboardingStage = OnboardingStage.selectHouse;
        debugPrint('🔥 Missing house - Stage: selectHouse');
      } else {
        // Tutto completo
        _onboardingStage = OnboardingStage.none;
        _pendingUserData = null;
        debugPrint('🔥 User complete - Stage: none');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking user onboarding status: $e');
      _onboardingStage = OnboardingStage.none;
      _pendingUserData = null;
      notifyListeners();
    } finally {
      _isCheckingStatus = false;
    }
  }

  // Completa il profilo (stage 1)
  Future<void> completeProfile(String nickname) async {
    try {
      if (_pendingUserData == null) {
        throw Exception('Nessun dato utente pending per il complete profile');
      }

      // Verifica unicità nickname
      final bool isUnique = await _dbService.isNicknameUnique(nickname);
      if (!isUnique) {
        throw Exception('Il nickname è già in uso, scegline un altro');
      }

      // Aggiorna i dati pending
      _pendingUserData!['nickname'] = nickname;

      // Passa al prossimo stage
      _onboardingStage = OnboardingStage.selectHouse;
      notifyListeners();

      debugPrint('🔥 Profile completed, moving to house selection');
    } catch (e) {
      debugPrint('Error completing profile: $e');
      rethrow;
    }
  }

  // Completa l'onboarding con la casata selezionata (stage 2)
  Future<void> completeOnboarding(String selectedHouse) async {
    try {
      if (_pendingUserData == null) {
        throw Exception('Nessun dato utente pending per l\'onboarding');
      }

      final authType = _pendingUserData!['authType'];

      if (authType == 'migration') {
        // Caso migrazione: aggiorna solo la casata
        await _firestore.collection('users').doc(_pendingUserData!['uid']).update({
          'house': selectedHouse,
        });
      } else {
        // Caso nuovo utente: crea completamente
        await _dbService.createUser(
          _pendingUserData!['uid'],
          _pendingUserData!['email'],
          _pendingUserData!['nickname'],
          _pendingUserData!['photoUrl'],
          selectedHouse,
          'player'
        );
      }

      // Reset flags e dati temporanei
      _onboardingStage = OnboardingStage.none;
      _pendingUserData = null;
      notifyListeners();

      debugPrint('🔥 Onboarding completed with house: $selectedHouse - Stage: none');
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    }
  }

  // Reset dell'onboarding (in caso di errore)
  void resetOnboarding() {
    _onboardingStage = OnboardingStage.none;
    _pendingUserData = null;
    _isCheckingStatus = false;
    notifyListeners();
    debugPrint('🔥 Onboarding reset');
  }

  // Logout
  // Logout corretto che gestisce Web e Mobile
  Future<void> logout() async {
    try {
      // Su Web, GoogleSignIn potrebbe non essere disponibile
      // o potrebbe dare errori, quindi gestiamo separatamente
      if (kIsWeb) {
        // Su Web, basta fare logout da Firebase Auth
        await _auth.signOut();
      } else {
        // Su Mobile, facciamo logout da entrambi
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          // Se Google Sign-In fallisce, continuiamo comunque
          debugPrint('Warning: Google Sign-In logout failed: $e');
        }
        await _auth.signOut();
      }

      // Reset onboarding data
      _onboardingStage = OnboardingStage.none;
      _pendingUserData = null;
      _isCheckingStatus = false;
      notifyListeners();

      debugPrint('🔥 Logout completed');
    } catch (e) {
      debugPrint('Error logging out: $e');
      rethrow;
    }
  }

  // Ottieni l'utente corrente
  User? get currentUser => _auth.currentUser;
}