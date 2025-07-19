import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrcode_reader_web/qrcode_reader_web.dart';

class QrService {
  // Mantiene la stessa interfaccia per la generazione QR
  static Widget generateQrCode(String data,
      {double size = 200.0, Color primaryColor = Colors.black}) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: primaryColor,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: primaryColor,
      ),
    );
  }

  // Mantiene la stessa interfaccia per lo scanner
  static Widget qrScanner(Function(String) onDetect) {
    return QRScannerWidget(onDetect: onDetect);
  }
}

class QRScannerWidget extends StatefulWidget {
  final Function(String) onDetect;

  const QRScannerWidget({super.key, required this.onDetect});

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  String result = "Nessun QR rilevato";
  bool _isProcessing = false;
  bool _hasPermission = false;
  String? _lastError;
  List<QRCodeCapture> _captureHistory = [];

  // Configurazioni scanner
  bool _isTransparentMode = false;
  double _scannerSize = 300.0;

  @override
  void initState() {
    super.initState();
    _initializeWebScanner();
  }

  Future<void> _initializeWebScanner() async {
    if (kIsWeb) {
      setState(() {
        _hasPermission = true;
        result = "Scanner web inizializzato";
      });
      print('DEBUG: Scanner web inizializzato con qrcode_reader_web');
    } else {
      setState(() {
        _lastError = "Questo scanner è ottimizzato solo per il web";
        result = "Errore: Non supportato su mobile";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Area scanner
        Expanded(
          flex: 4,
          child: _hasPermission && kIsWeb
              ? _buildWebScanner()
              : _buildNotSupportedView(),
        ),

        // Controlli e informazioni
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Slider per dimensione scanner
              if (kIsWeb) ...[
                Text(
                  'Dimensione scanner: ${_scannerSize.round()}px',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Slider(
                  value: _scannerSize,
                  min: 200.0,
                  max: 400.0,
                  divisions: 8,
                  onChanged: (value) {
                    setState(() {
                      _scannerSize = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebScanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Istruzioni
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Posiziona il QR code davanti alla camera. Scanner ottimizzato per web.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scanner widget
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: _isTransparentMode
                    ? QRCodeReaderTransparentWidget(
                  onDetect: _handleQRDetection,
                  targetSize: _scannerSize,
                )
                    : QRCodeReaderSquareWidget(
                  onDetect: _handleQRDetection,
                  size: _scannerSize,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Indicatore modalità
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isTransparentMode ? Colors.purple[100] : Colors.blue[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isTransparentMode ? Icons.crop_free : Icons.crop_square,
                    size: 16,
                    color: _isTransparentMode ? Colors.purple[700] : Colors.blue[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isTransparentMode ? 'Modalità Trasparente' : 'Modalità Quadrata',
                    style: TextStyle(
                      color: _isTransparentMode ? Colors.purple[700] : Colors.blue[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotSupportedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            kIsWeb ? Icons.error : Icons.phone_android,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            kIsWeb
                ? 'Errore di inizializzazione'
                : 'Scanner ottimizzato per web',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kIsWeb
                ? 'Ricarica la pagina per riprovare'
                : 'Questo scanner funziona solo nel browser.\nUsa la versione web dell\'app.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (kIsWeb)
            ElevatedButton.icon(
              onPressed: () {
                // Simula un refresh dello stato
                _initializeWebScanner();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  void _handleQRDetection(QRCodeCapture capture) {
    if (_isProcessing) return;

    final String? code = capture.raw;
    if (code == null || code.isEmpty) return;

    print('🎉 DEBUG: QR rilevato con qrcode_reader_web: $code');
    print('DEBUG: Capture data: ${capture.toString()}');

    setState(() {
      _isProcessing = true;
      result = "QR rilevato: ${code.length > 30 ? '${code.substring(0, 30)}...' : code}";
      _lastError = null;
      _captureHistory.add(capture);
    });

    // Chiama la callback
    try {
      print('DEBUG: Chiamando widget.onDetect');
      widget.onDetect(code);
    } catch (e) {
      print('❌ DEBUG: Errore nella callback: $e');
      setState(() {
        _lastError = 'Errore callback: $e';
      });
    }

    // Previene rilevamenti multipli per 2 secondi
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          result = "Pronto per un nuovo QR";
        });
      }
    });
  }

  void _testCallback() {
    print('TEST: Simulando QR rilevato');
    setState(() {
      result = "Test callback...";
    });

    try {
      widget.onDetect('{"type": "coaster", "id": "test123"}');
      setState(() {
        result = "Test completato con successo";
      });
    } catch (e) {
      setState(() {
        _lastError = 'Test fallito: $e';
        result = "Test fallito";
      });
    }
  }

  void _clearHistory() {
    setState(() {
      _captureHistory.clear();
      result = "Cronologia pulita";
    });
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Scanner QR Web'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scanner ottimizzato per applicazioni web utilizzando qrcode_reader_web.'),
            const SizedBox(height: 12),
            const Text('Caratteristiche:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Due modalità di scansione'),
            const Text('• Dimensione personalizzabile'),
            const Text('• Performance ottimizzate per web'),
            const Text('• Gestione automatica permessi camera'),
            const SizedBox(height: 12),
            Text(
              'QR rilevati in questa sessione: ${_captureHistory.length}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // qrcode_reader_web gestisce automaticamente la pulizia delle risorse
    super.dispose();
  }
}