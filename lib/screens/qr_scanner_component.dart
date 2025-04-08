import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerComponent extends StatefulWidget {
  final Function(String) onQRCodeDetected;
  final bool isCameraOpen;

  const QRScannerComponent({
    Key? key,
    required this.onQRCodeDetected,
    required this.isCameraOpen,
  }) : super(key: key);

  @override
  _QRScannerComponentState createState() => _QRScannerComponentState();
}

class _QRScannerComponentState extends State<QRScannerComponent> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            widget.onQRCodeDetected('');
          },
          icon: Icon(widget.isCameraOpen ? Icons.no_photography : Icons.camera, 
                    color: Colors.white),
          label: Text(widget.isCameraOpen ? 'Close Scanner' : 'Scan Vehicle QR',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(height: 10),
        if (widget.isCameraOpen)
          SizedBox(
            height: 200,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  widget.onQRCodeDetected(barcodes.first.rawValue!);
                }
              },
            ),
          ),
      ],
    );
  }
}