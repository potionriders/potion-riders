import 'package:flutter/material.dart';
import 'package:potion_riders/models/coaster_model.dart';
import 'package:potion_riders/models/ingredient_model.dart';
import 'package:potion_riders/models/recipe_model.dart';
import 'package:potion_riders/services/ingredient_service.dart';
import 'package:potion_riders/services/recipe_service.dart';
import 'package:potion_riders/services/database_service.dart';

class HomeScreenCoasterCard extends StatefulWidget {
  final String? currentRecipeId;
  final String? currentIngredientId;
  final CoasterModel? coaster;
  final VoidCallback? onTapRecipe;
  final VoidCallback? onTapIngredient;
  final Function(bool)? onSwitchItem;
  final String? userId; // Aggiunto per gestire il flip

  const HomeScreenCoasterCard({
    super.key,
    this.currentRecipeId,
    this.currentIngredientId,
    this.coaster,
    this.onTapRecipe,
    this.onTapIngredient,
    this.onSwitchItem,
    this.userId,
  });

  @override
  State<HomeScreenCoasterCard> createState() => _HomeScreenCoasterCardState();
}

class _HomeScreenCoasterCardState extends State<HomeScreenCoasterCard>
    with TickerProviderStateMixin {
  final RecipeService _recipeService = RecipeService();
  final IngredientService _ingredientService = IngredientService();
  final DatabaseService _dbService = DatabaseService();

  bool _showRecipe = true;
  RecipeModel? _recipe;
  IngredientModel? _ingredient;
  bool _isLoading = true;
  bool _isFlipping = false;

  // Animation controller per l'effetto flip
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();

    // Inizializza l'animazione di flip
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    // Decidiamo cosa mostrare inizialmente in base a cosa è attualmente selezionato
    _showRecipe = widget.currentRecipeId != null;
    _loadData();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreenCoasterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRecipeId != widget.currentRecipeId ||
        oldWidget.currentIngredientId != widget.currentIngredientId ||
        oldWidget.coaster != widget.coaster) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Se c'è un coaster, carica entrambi gli elementi
      if (widget.coaster != null) {
        _recipe = await _recipeService.getRecipe(widget.coaster!.recipeId);
        _ingredient = await _ingredientService.getIngredient(widget.coaster!.ingredientId);

        // Determina cosa mostrare in base all'uso corrente del coaster
        if (widget.coaster!.usedAs == 'recipe') {
          _showRecipe = true;
        } else if (widget.coaster!.usedAs == 'ingredient') {
          _showRecipe = false;
        } else {
          // Se non è ancora usato, usa la logica precedente
          _showRecipe = widget.currentRecipeId != null;
        }
      } else {
        // Logica originale per elementi singoli
        if (widget.currentRecipeId != null) {
          _recipe = await _recipeService.getRecipe(widget.currentRecipeId!);
          _showRecipe = true;
        }

        if (widget.currentIngredientId != null) {
          _ingredient = await _ingredientService.getIngredient(widget.currentIngredientId!);
          if (widget.currentRecipeId == null) {
            _showRecipe = false;
          }
        }
      }
    } catch (e) {
      print('Errore caricamento dati: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFlip() async {
    if (_isFlipping || widget.coaster == null || widget.userId == null) return;

    setState(() {
      _isFlipping = true;
    });

    try {
      // Inizia l'animazione di flip
      await _flipController.forward();

      // Cambia il lato attivo nel database
      final newUseAsRecipe = !_showRecipe;
      final success = await _dbService.switchCoasterUsage(
        widget.userId!,
        widget.coaster!.id,
        newUseAsRecipe,
      );

      if (success) {
        setState(() {
          _showRecipe = newUseAsRecipe;
        });

        // Notifica il parent del cambio
        if (widget.onSwitchItem != null) {
          widget.onSwitchItem!(_showRecipe);
        }

        // Mostra messaggio di successo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_showRecipe
                ? 'Ora stai usando la pozione!'
                : 'Ora stai usando l\'ingrediente!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Se fallisce, torna indietro
        await _flipController.reverse();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante il cambio. Riprova.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      await _flipController.reverse();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isFlipping = false;
      });

      // Reset dell'animazione
      _flipController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se non c'è un sottobicchiere e nessuno degli elementi è definito
    if (widget.coaster == null && widget.currentRecipeId == null && widget.currentIngredientId == null) {
      return _buildEmptyStateCard(context);
    }

    // Se siamo in caricamento
    if (_isLoading) {
      return _buildLoadingCard(context);
    }

    // Se c'è un sottobicchiere, mostriamo il toggle e gli elementi disponibili
    if (widget.coaster != null) {
      return _buildCoasterCard(context);
    }

    // Altrimenti mostriamo solo l'elemento corrente
    if (_showRecipe && _recipe != null) {
      return _buildRecipeCard(context);
    } else if (!_showRecipe && _ingredient != null) {
      return _buildIngredientCard(context);
    }

    // Fallback
    return _buildEmptyStateCard(context);
  }

  Widget _buildCoasterCard(BuildContext context) {
    final bool hasRecipe = _recipe != null;
    final bool hasIngredient = _ingredient != null;
    final bool canSwitch = hasRecipe && hasIngredient && !_isFlipping;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con pulsante di flip
          if (canSwitch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flip),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sottobicchiere',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Pulsante flip animato
                  AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _flipAnimation.value * 3.14159, // Rotazione di 180 gradi
                        child: ElevatedButton.icon(
                          onPressed: _isFlipping ? null : _handleFlip,
                          icon: _isFlipping
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.flip, size: 18),
                          label: Text(
                            _showRecipe ? 'Usa Ingrediente' : 'Usa Pozione',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showRecipe ? Colors.green : Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Contenuto dinamico con animazione di flip
          AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              // Durante la prima metà dell'animazione mostra il lato corrente
              // Durante la seconda metà mostra il lato opposto
              final showCurrentSide = _flipAnimation.value < 0.5;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Prospettiva
                  ..rotateY(_flipAnimation.value * 3.14159),
                child: _flipAnimation.value < 0.5
                    ? (_showRecipe ? _buildRecipeContent(context) : _buildIngredientContent(context))
                    : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159), // Flip per il lato opposto
                  child: !_showRecipe ? _buildRecipeContent(context) : _buildIngredientContent(context),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeContent(BuildContext context) {
    if (_recipe == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Nessuna pozione disponibile'),
      );
    }

    return InkWell(
      onTap: widget.onTapRecipe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade300,
                  Colors.purple.shade800,
                ],
              ),
            ),
            child: Stack(
              children: [
                if (_recipe!.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.3,
                      child: _recipe!.imageUrl.startsWith('http')
                          ? Image.network(
                        _recipe!.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.white54,
                        ),
                      )
                          : const Icon(
                        Icons.science,
                        size: 64,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.science,
                          size: 36,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recipe!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Chip(
                    label: Text(
                      _recipe!.family,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: Colors.black38,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_recipe!.description.isNotEmpty) ...[
                  Text(
                    _recipe!.description,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Ingredienti necessari:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ..._recipe!.requiredIngredients.map((ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientContent(BuildContext context) {
    if (_ingredient == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Nessun ingrediente disponibile'),
      );
    }

    return InkWell(
      onTap: widget.onTapIngredient,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade300,
                  Colors.green.shade800,
                ],
              ),
            ),
            child: Stack(
              children: [
                if (_ingredient!.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.3,
                      child: _ingredient!.imageUrl.startsWith('http')
                          ? Image.network(
                        _ingredient!.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.white54,
                        ),
                      )
                          : const Icon(
                        Icons.eco,
                        size: 64,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                const Center(
                  child: Icon(
                    Icons.eco,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _ingredient!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _ingredient!.family,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ingredient!.description,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Gli altri metodi rimangono uguali...
  Widget _buildRecipeCard(BuildContext context) {
    if (_recipe == null) {
      return _buildEmptyStateCard(context);
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTapRecipe,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade300,
                    Colors.purple.shade800,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  if (_recipe!.imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.3,
                        child: _recipe!.imageUrl.startsWith('http')
                            ? Image.network(
                          _recipe!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.white54,
                          ),
                        )
                            : const Icon(
                          Icons.science,
                          size: 64,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.science,
                            size: 36,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recipe!.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Chip(
                      label: Text(
                        _recipe!.family,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.black38,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recipe!.description.isNotEmpty) ...[
                    Text(
                      _recipe!.description,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Ingredienti necessari:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._recipe!.requiredIngredients.map((ingredient) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCard(BuildContext context) {
    if (_ingredient == null) {
      return _buildEmptyStateCard(context);
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTapIngredient,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade300,
                    Colors.green.shade800,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  if (_ingredient!.imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.3,
                        child: _ingredient!.imageUrl.startsWith('http')
                            ? Image.network(
                          _ingredient!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.white54,
                          ),
                        )
                            : const Icon(
                          Icons.eco,
                          size: 64,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  const Center(
                    child: Icon(
                      Icons.eco,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _ingredient!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _ingredient!.family,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ingredient!.description,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(width: 16),
            const Text('Caricamento elemento...'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Non hai ancora ricette o ingredienti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Visita uno dei punti di distribuzione in fiera per ottenere il tuo sottobicchiere!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // In una versione completa, qui potrebbe esserci un
                // sistema per scansionare il codice del sottobicchiere
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scansiona un sottobicchiere'),
            ),
          ],
        ),
      ),
    );
  }
}