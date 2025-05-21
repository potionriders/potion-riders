import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';
import 'package:potion_riders/screens/home_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String _nickname = '';
  bool _isLoading = false;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    // Pre-compila il nickname se disponibile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.currentUser?.displayName != null) {
        setState(() {
          _nickname = auth.currentUser!.displayName!;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa il tuo profilo'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Icona o avatar
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    backgroundImage: authService.currentUser?.photoURL != null
                        ? NetworkImage(authService.currentUser!.photoURL!)
                        : null,
                    child: authService.currentUser?.photoURL == null
                        ? Icon(
                      Icons.person,
                      size: 60,
                      color: Theme.of(context).primaryColor,
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Benvenuto in Potion Riders!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Per iniziare, abbiamo bisogno di qualche informazione in più.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  initialValue: _nickname,
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    hintText: 'Come vuoi essere chiamato nel gioco?',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci un nickname';
                    }
                    return null;
                  },
                  onSaved: (value) => _nickname = value!,
                  onChanged: (value) => _nickname = value,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: () => _saveProfile(authService),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'Inizia a giocare',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    // In caso l'utente voglia annullare, si disconnette
                    await authService.logout();
                    Navigator.pushReplacementNamed(context, '/auth');
                  },
                  child: const Text('Annulla'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        if (authService.currentUser == null) {
          throw Exception('Utente non autenticato');
        }

        final uid = authService.currentUser!.uid;

        // Verifichiamo l'unicità del nickname
        final bool isUnique = await _dbService.isNicknameUnique(_nickname);

        if (!isUnique) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nickname già in uso, scegline un altro')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Aggiorna il nickname in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'nickname': _nickname});

        // Assegna un elemento di gioco casuale se non ne ha già uno
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data();

        if (userData != null &&
            userData['currentRecipeId'] == null &&
            userData['currentIngredientId'] == null) {
          await _dbService.assignRandomGameElement(uid);
        }

        // Vai alla home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}