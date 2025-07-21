import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrcode_reader_web/qrcode_reader_web.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  List<dynamic> _captureHistory = []; // Usa dynamic per supportare entrambi i tipi

  // Controller per mobile scanner
  MobileScannerController? _mobileScannerController;

  // Configurazioni scanner
  bool _isTransparentMode = false;
  double _scannerSize = 300.0;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    if (kIsWeb) {
      // Logica per web
      setState(() {
        _hasPermission = true;
        result = "Scanner web inizializzato";
      });
      print('DEBUG: Scanner web inizializzato con qrcode_reader_web');
    } else {
      // Logica per Android/iOS
      try {
        _mobileScannerController = MobileScannerController();
        setState(() {
          _hasPermission = true;
          result = "Scanner mobile inizializzato";
        });
        print('DEBUG: Scanner mobile inizializzato con mobile_scanner');
      } catch (e) {
        setState(() {
          _lastError = "Errore inizializzazione mobile: $e";
          result = "Errore scanner mobile";
        });
        print('❌ DEBUG: Errore scanner mobile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Area scanner
        Expanded(
          flex: 4,
          child: _hasPermission
              ? (kIsWeb ? _buildWebScanner() : _buildMobileScanner())
              : _buildNotSupportedView(),
        ),

        // Controlli e informazioni
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Risultato
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastError != null ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastError != null ? Colors.red[200]! : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastError != null ? Icons.error : Icons.info,
                      color: _lastError != null ? Colors.red[700] : Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError ?? result,
                        style: TextStyle(
                          color: _lastError != null ? Colors.red[700] : Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Slider per dimensione scanner
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

              // Bottoni controllo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (kIsWeb)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isTransparentMode = !_isTransparentMode;
                        });
                      },
                      icon: Icon(_isTransparentMode ? Icons.crop_square : Icons.crop_free),
                      label: Text(_isTransparentMode ? 'Quadrato' : 'Trasparente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTransparentMode ? Colors.purple : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),

                  ElevatedButton.icon(
                    onPressed: _testCallback,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  IconButton(
                    onPressed: _showInfo,
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Informazioni Scanner',
                  ),

                  if (_captureHistory.isNotEmpty)
                    IconButton(
                      onPressed: _clearHistory,
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Pulisci cronologia',
                    ),
                ],
              ),
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
                  onDetect: _handleWebQRDetection,
                  targetSize: _scannerSize,
                )
                    : QRCodeReaderSquareWidget(
                  onDetect: _handleWebQRDetection,
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

  Widget _buildMobileScanner() {
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
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Posiziona il QR code davanti alla camera mobile.',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scanner mobile
            Container(
              width: _scannerSize,
              height: _scannerSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 3),
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
                child: MobileScanner(
                  controller: _mobileScannerController,
                  onDetect: _handleMobileQRDetection,
                  overlay: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Indicatore modalità mobile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smartphone,
                    size: 16,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Scanner Mobile Attivo',
                    style: TextStyle(
                      color: Colors.green[700],
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
            _hasPermission ? Icons.error : Icons.camera_alt_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _hasPermission
                ? 'Errore di inizializzazione scanner'
                : 'Scanner non disponibile',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastError ?? 'Verifica i permessi della camera',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _initializeScanner();
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

  void _handleWebQRDetection(QRCodeCapture capture) {
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
      print('DEBUG: Chiamando widget.onDetect per web');
      widget.onDetect(code);
    } catch (e) {
      print('❌ DEBUG: Errore nella callback web: $e');
      setState(() {
        _lastError = 'Errore callback web: $e';
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

  void _handleMobileQRDetection(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    print('🎉 DEBUG: QR rilevato con mobile_scanner: $code');
    print('DEBUG: Barcode data: ${barcodes.first.toString()}');

    setState(() {
      _isProcessing = true;
      result = "QR rilevato: ${code.length > 30 ? '${code.substring(0, 30)}...' : code}";
      _lastError = null;
      _captureHistory.add(capture);
    });

    // Chiama la callback
    try {
      print('DEBUG: Chiamando widget.onDetect per mobile');
      widget.onDetect(code);
    } catch (e) {
      print('❌ DEBUG: Errore nella callback mobile: $e');
      setState(() {
        _lastError = 'Errore callback mobile: $e';
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
        title: Row(
          children: [
            Icon(Icons.info, color: kIsWeb ? Colors.blue : Colors.green),
            const SizedBox(width: 8),
            Text('Scanner QR ${kIsWeb ? "Web" : "Mobile"}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanner ottimizzato per ${kIsWeb ? "applicazioni web utilizzando qrcode_reader_web" : "dispositivi mobile utilizzando mobile_scanner"}.'),
            const SizedBox(height: 12),
            const Text('Caratteristiche:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (kIsWeb) ...[
              const Text('• Due modalità di scansione (quadrata/trasparente)'),
              const Text('• Performance ottimizzate per browser'),
              const Text('• Gestione automatica permessi camera web'),
            ] else ...[
              const Text('• Scanner nativo per dispositivi mobili'),
              const Text('• Performance ottimizzate per Android/iOS'),
              const Text('• Gestione automatica permessi camera mobile'),
            ],
            const Text('• Dimensione personalizzabile'),
            const Text('• Debug completo con logging'),
            const SizedBox(height: 12),
            Text(
              'QR rilevati in questa sessione: ${_captureHistory.length}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              'Piattaforma: ${kIsWeb ? "Web Browser" : "Mobile App"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
    // Pulizia risorse
    _mobileScannerController?.dispose();
    super.dispose();
  }
}