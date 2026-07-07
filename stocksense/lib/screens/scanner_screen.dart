import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'telemetry_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  final TextEditingController _manualInputController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Sweeping laser animation
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _onBarcodeScanned(String barcode) async {
    if (_isProcessing) return;

    final input = barcode.trim().toUpperCase();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid SKU ID.'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final exists = await ApiService.validateSku(input);

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SKU "$input" not found in catalog.'), backgroundColor: AppTheme.critical),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SKU verified: $input — opening telemetry...'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => TelemetryScreen(itemId: input)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        title: const Text('In-App Barcode Scanner'),
      ),
      body: Stack(
        children: [
          // Simulated camera view (dark static grid with camera icon)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Opacity(
                opacity: 0.15,
                child: GridPaper(
                  color: Colors.white,
                  interval: 40.0,
                  subdivisions: 1,
                  child: Container(),
                ),
              ),
            ),
          ),

          // Central viewfinder box
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'POSITION BARCODE WITHIN TARGET AREA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Viewfinder frame
                Stack(
                  children: [
                    Container(
                      width: 260,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.camera,
                          color: Colors.white30,
                          size: 48,
                        ),
                      ),
                    ),
                    
                    // Neon green corners
                    Positioned(
                      top: 0, left: 0,
                      child: _buildCorner(top: true, left: true),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: _buildCorner(top: true, left: false),
                    ),
                    Positioned(
                      bottom: 0, left: 0,
                      child: _buildCorner(top: false, left: true),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: _buildCorner(top: false, left: false),
                    ),
                    
                    // Moving sweeping laser red line
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, child) {
                        return Positioned(
                          top: 10 + (_laserController.value * 160),
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.8),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Simulate automatic scan button
                ElevatedButton.icon(
                  onPressed: () => _onBarcodeScanned('TQT-2-10-00043'),
                  icon: const Icon(LucideIcons.scan, size: 18),
                  label: const Text('SCAN SAMPLE SKU', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                
                const SizedBox(height: 24),
                Text(
                  '— OR ENTER SKU ID MANUALLY —',
                  style: TextStyle(fontSize: 10, color: context.textMuted, fontWeight: FontWeight.bold),
                ),
                
                const SizedBox(height: 12),
                
                // Manual input field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualInputController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. TQT-2-10-00043',
                            fillColor: context.cardBg,
                            filled: true,
                            hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _onBarcodeScanned(_manualInputController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Icon(LucideIcons.arrowRight, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Processing Loader overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text(
                        'Decoding barcode matrix...',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool top, required bool left}) {
    const double length = 20.0;
    const double thickness = 4.0;
    final color = Colors.greenAccent[400]!;

    return SizedBox(
      width: length,
      height: length,
      child: Stack(
        children: [
          // Horizontal line
          Positioned(
            top: top ? 0 : null,
            bottom: !top ? 0 : null,
            left: 0,
            right: 0,
            child: Container(height: thickness, color: color),
          ),
          // Vertical line
          Positioned(
            top: 0,
            bottom: 0,
            left: left ? 0 : null,
            right: !left ? 0 : null,
            child: Container(width: thickness, color: color),
          ),
        ],
      ),
    );
  }
}
