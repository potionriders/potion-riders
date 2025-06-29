import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
// Sostituisci mobile_scanner con qr_code_scanner_plus
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QrService {
  // Genera un widget QR code
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

  // Widget per scanner QR code con supporto web migliorato
  static Widget qrScanner(Function(String) onDetect) {
    return QRScannerWidget(onDetect: onDetect);
  }
}

class QRScannerWidget extends StatefulWidget {
  final Function(String) onDetect;

  const QRScannerWidget({super.key, required this.onDetect});

  @override
  _QRScannerWidgetState createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isScanning = true;

  @override
  void reassemble() {
    super.reassemble();
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        controller?.pauseCamera();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        controller?.resumeCamera();
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Colors.red,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: 250,
          ),
          onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
        ),
        // Overlay con istruzioni
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inquadra il QR code del sottobicchiere',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Assicurati di aver consentito l\'accesso alla fotocamera',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        // Controlli flash (solo mobile)
        if (!kIsWeb)
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.black.withOpacity(0.7),
              mini: true,
              onPressed: () async {
                await controller?.toggleFlash();
              },
              child: const Icon(Icons.flash_on, color: Colors.white),
            ),
          ),
      ],
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      if (_isScanning && scanData.code != null) {
        setState(() {
          _isScanning = false;
        });

        // Pausa la camera per evitare scansioni multiple
        controller.pauseCamera();

        // Chiama la callback con i dati scansionati
        widget.onDetect(scanData.code!);

        // Riprendi la scansione dopo un breve delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
            });
            controller.resumeCamera();
          }
        });
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permesso fotocamera negato'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}