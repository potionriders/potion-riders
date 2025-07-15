import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:potion_riders/services/auth_service.dart';
import 'package:potion_riders/services/database_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String initialNickname;
  final Function(String nickname)? onProfileCompleted; // OPZIONALE
  final String? title; // TITOLO PERSONALIZZABILE
  final bool canGoBack; // SE PUÒ TORNARE INDIETRO

  const CompleteProfileScreen({
    Key? key,
    this.initialNickname = '',
    this.onProfileCompleted, // NON PIÙ REQUIRED
    this.title,
    this.canGoBack = false,
  }) : super(key: key);

  @override
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  bool _isLoading = false;
  final DatabaseService _dbService = DatabaseService();

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);

    // Setup animazioni
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.3,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Avvia animazione
    _animationController.forward();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Completa il tuo profilo'),
        automaticallyImplyLeading: widget.canGoBack, // Mostra freccia indietro solo se permesso
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Avatar dell'utente
                        _buildUserAvatar(authService),

                        const SizedBox(height: 32),

                        // Titolo e descrizione
                        _buildHeader(),

                        const SizedBox(height: 40),

                        // Campo nickname
                        _buildNicknameField(),

                        const SizedBox(height: 32),

                        // Info aggiuntive
                        _buildInfoCard(),

                        const SizedBox(height: 40),

                        // Bottone continua
                        _buildContinueButton(authService),

                        const SizedBox(height: 16),

                        // Bottone logout/indietro
                        _buildSecondaryButton(authService),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserAvatar(AuthService authService) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.purple, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
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
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.onProfileCompleted != null
              ? 'Benvenuto in Potion Riders!'
              : 'Aggiorna il tuo profilo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          widget.onProfileCompleted != null
              ? 'Per iniziare la tua avventura alchemica, abbiamo bisogno di scegliere il tuo nome da esploratore.'
              : 'Modifica il tuo nickname per personalizzare il tuo profilo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Il tuo nickname',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nicknameController,
          decoration: InputDecoration(
            hintText: 'Come vuoi essere chiamato nel gioco?',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Inserisci un nickname';
            }
            if (value.length < 3) {
              return 'Il nickname deve avere almeno 3 caratteri';
            }
            if (value.length > 20) {
              return 'Il nickname non può superare 20 caratteri';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informazioni',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Il nickname sarà visibile agli altri giocatori\n'
                '• Potrai cambiarlo successivamente dalle impostazioni\n'
                '• Deve essere unico nel gioco',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[800],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(AuthService authService) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveProfile(authService),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isLoading ? 0 : 4,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_forward),
            const SizedBox(width: 8),
            Text(
              widget.onProfileCompleted != null ? 'Continua' : 'Salva',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(AuthService authService) {
    if (widget.canGoBack) {
      // Se può tornare indietro, mostra bottone indietro
      return TextButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        child: Text(
          'Annulla',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    } else if (widget.onProfileCompleted != null) {
      // Se è nel flusso onboarding, mostra logout
      return TextButton(
        onPressed: _isLoading ? null : () async {
          await authService.logout();
          // Il logout triggerà automaticamente il rebuild dell'AuthWrapper
        },
        child: Text(
          'Esci e torna al login',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    } else {
      // Se è standalone, non mostra niente
      return const SizedBox.shrink();
    }
  }

  Future<void> _saveProfile(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final nickname = _nicknameController.text.trim();

        // Verifica unicità nickname
        final bool isUnique = await _dbService.isNicknameUnique(nickname);
        if (!isUnique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Il nickname è già in uso, scegline un altro'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (widget.onProfileCompleted != null) {
          // CASO 1: Flusso onboarding - usa callback
          await widget.onProfileCompleted!(nickname);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profilo completato! Ora scegli la tua casata.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // CASO 2: Uso standalone - aggiorna direttamente il database
          final user = authService.currentUser;
          if (user != null) {
            await _dbService.updateUserNickname(user.uid, nickname);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nickname aggiornato con successo!'),
                  backgroundColor: Colors.green,
                ),
              );

              // Se può tornare indietro, lo fa automaticamente
              if (widget.canGoBack) {
                Navigator.pop(context);
              }
            }
          }
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}