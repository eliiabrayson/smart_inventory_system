import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'main.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing = false;
  String? _lastScannedCode;
  int _scanCount = 0;
  bool _batchMode = false;
  final List<Map<String, dynamic>> _batchScans = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    // Try to load beep sound, but don't fail if it doesn't exist
    try {
      await _audioPlayer.setSource(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint('Could not load beep sound: $e');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      // If sound fails, just vibrate
      debugPrint('Error playing beep: $e');
    }
  }

  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      debugPrint('Error vibrating: $e');
    }
  }

  Future<void> _toggleTorch() async {
    await controller.toggleTorch();
  }

  Future<void> _processScannedBarcode(String code) async {
    if (_isProcessing) return;
    
    // Prevent duplicate scans of the same code within 2 seconds
    if (_lastScannedCode == code && DateTime.now().millisecondsSinceEpoch % 2000 < 500) {
      return;
    }
    
    setState(() => _isProcessing = true);
    _lastScannedCode = code;
    _scanCount++;

    try {
      // Vibrate and play beep
      await _vibrate();
      await _playBeep();
      
      // Search for product in Firestore
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final query = await FirebaseFirestore.instance
            .collection('products')
            .where('barcode', isEqualTo: code)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final productDoc = query.docs.first;
          final productData = productDoc.data();
          final productId = productDoc.id;
          final productName = productData['name'] ?? 'Unknown';
          final quantity = (productData['quantity'] is num) ? (productData['quantity'] as num).toInt() : 0;
          final price = (productData['price'] is num) ? (productData['price'] as num).toDouble() : 0.0;

          if (quantity > 0) {
            if (_batchMode) {
              // Add to batch
              _batchScans.add({
                'productId': productId,
                'name': productName,
                'qty': 1,
                'amount': price,
                'timestamp': DateTime.now().toIso8601String(),
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Added to batch: $productName (1 @ \$${price.toStringAsFixed(2)})'),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 1),
                    action: SnackBarAction(
                      label: 'View Batch',
                      textColor: Colors.white,
                      onPressed: () => _showBatchDialog(),
                    ),
                  ),
                );
              }
            } else {
              // Auto-record sale
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              
              // Update product quantity
              await FirebaseFirestore.instance.collection('products').doc(productId).update({
                'quantity': FieldValue.increment(-1),
              });

              // Record sale
              await FirebaseFirestore.instance.collection('sales').add({
                'productId': productId,
                'name': productName,
                'qty': 1,
                'amount': price,
                'timestamp': FieldValue.serverTimestamp(),
                'customerEmail': FirebaseAuth.instance.currentUser?.email,
                'ownerEmail': FirebaseAuth.instance.currentUser?.email,
              });

              // Update local state
              await appState.recordSale(
                productId: productId,
                name: productName,
                qty: 1,
                amount: price,
                userEmail: FirebaseAuth.instance.currentUser?.email,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Sale recorded: $productName (1 @ \$${price.toStringAsFixed(2)})'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
            
            // Wait a moment before allowing another scan
            await Future.delayed(const Duration(milliseconds: 1500));
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠ Product out of stock: $productName'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 1000));
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✗ Product not found: $code'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      } else {
        // Demo mode - just return the code
        if (mounted) {
          Navigator.pop(context, code);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing scan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showBatchDialog() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Batch Scans (${_batchScans.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _batchScans.isEmpty
              ? const Center(child: Text('No items in batch'))
              : ListView.builder(
                  itemCount: _batchScans.length,
                  itemBuilder: (context, index) {
                    final item = _batchScans[index];
                    return ListTile(
                      title: Text(item['name']),
                      subtitle: Text('Qty: 1, Amount: \$${item['amount'].toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _batchScans.removeAt(index));
                          Navigator.pop(context);
                          _showBatchDialog();
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _batchScans.clear());
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: _batchScans.isEmpty ? null : () async {
              // Process all batch scans
              for (var item in _batchScans) {
                final productId = item['productId'];
                final productName = item['name'];
                final price = item['amount'];
                
                await FirebaseFirestore.instance.collection('products').doc(productId).update({
                  'quantity': FieldValue.increment(-1),
                });

                await FirebaseFirestore.instance.collection('sales').add({
                  'productId': productId,
                  'name': productName,
                  'qty': 1,
                  'amount': price,
                  'timestamp': FieldValue.serverTimestamp(),
                  'customerEmail': FirebaseAuth.instance.currentUser?.email,
                  'ownerEmail': FirebaseAuth.instance.currentUser?.email,
                });

                await appState.recordSale(
                  productId: productId,
                  name: productName,
                  qty: 1,
                  amount: price,
                  userEmail: FirebaseAuth.instance.currentUser?.email,
                );
              }
              
              setState(() => _batchScans.clear());
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_batchScans.length} sales recorded'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Process All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Product Barcode'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Toggle Flashlight',
          ),
          IconButton(
            onPressed: () {
              setState(() => _batchMode = !_batchMode);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_batchMode ? 'Batch mode enabled' : 'Batch mode disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: Icon(_batchMode ? Icons.playlist_add_check : Icons.playlist_add),
            tooltip: 'Toggle Batch Mode',
          ),
          if (_batchMode && _batchScans.isNotEmpty)
            IconButton(
              onPressed: _showBatchDialog,
              icon: Badge(
                label: Text('${_batchScans.length}'),
                child: const Icon(Icons.shopping_cart),
              ),
              tooltip: 'View Batch',
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isProcessing) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  debugPrint("Barcode Scanned: $code");
                  _processScannedBarcode(code);
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
                style: TextStyle(color: Colors.white, backgroundColor: Colors.black54),
              ),
            ),
          ),
          if (_batchMode)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.playlist_add_check, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Batch Mode (${_batchScans.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.close),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
