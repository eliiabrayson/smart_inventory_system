import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // Removing strict facing: CameraFacing.back for better Web/Laptop compatibility
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(appState.translate('scan_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: appState.translate('tooltip_switch_camera'),
            icon: ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                return Icon(
                  controller.facing == CameraFacing.front
                      ? Icons.camera_front_rounded
                      : Icons.camera_rear_rounded,
                );
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  debugPrint("Barcode Scanned: $code");
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          // Scanner Overlay (Visual Guide)
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align barcode within the box",
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: appState.translate('tooltip_close'),
        onPressed: () => Navigator.pop(context),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.close),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
