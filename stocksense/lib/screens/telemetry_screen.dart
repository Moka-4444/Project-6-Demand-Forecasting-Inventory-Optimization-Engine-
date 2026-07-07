import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/product.dart';

class TelemetryScreen extends StatefulWidget {
  final String itemId;

  const TelemetryScreen({Key? key, required this.itemId}) : super(key: key);

  @override
  _TelemetryScreenState createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  bool _isLoading = true;
  Product? _product;

  // What-If Simulation State
  double _basePrice = 15.0;
  double _simulatedPrice = 15.0;
  bool _hasPromo = false;
  
  double _baseForecast = 1200.0;
  double _simulatedForecast = 1200.0;
  double _changePercentage = 0.0;
  bool _isSimulating = false;
  List<double> _historyActual = [];
  List<String> _historyWeeks = [];

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getProduct(widget.itemId),
      ApiService.getProductWeeklyHistory(widget.itemId),
    ]);
    final p = results[0] as Product?;
    final history = results[1] as Map<String, dynamic>?;

    if (mounted) {
      setState(() {
        _product = p;
        if (_product != null) {
          _baseForecast = (_product!.forecastMean != null && _product!.forecastMean! > 0)
              ? _product!.forecastMean!
              : 1200.0;
          _simulatedForecast = _baseForecast;
          _basePrice = (_product!.avgUnitPrice != null && _product!.avgUnitPrice! > 0)
              ? _product!.avgUnitPrice!
              : 15.0;
          _simulatedPrice = _basePrice;
        }
        if (history != null) {
          _historyActual = (history['actual_qty'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
          _historyWeeks = (history['weeks'] as List?)?.map((e) => e.toString()).toList() ?? [];
        }
        _isLoading = false;
      });
      _runSimulation();
    }
  }

  Future<void> _runSimulation() async {
    if (_product == null) return;
    
    setState(() {
      _isSimulating = true;
    });

    final results = await ApiService.simulateWhatIf(
      widget.itemId,
      _simulatedPrice,
      _hasPromo ? 1 : 0,
    );

    if (mounted) {
      setState(() {
        if (results != null) {
          _simulatedForecast = (results['simulated_forecast'] as num).toDouble();
          _baseForecast = (results['base_forecast'] as num).toDouble();
          _changePercentage = (results['percent_change'] as num).toDouble();
        } else {
          // Simulation offline fallback calculation for demo purposes
          // Higher price = lower demand, Promo = higher demand
          double priceRatio = _simulatedPrice / _basePrice;
          double priceElasticity = -1.5; // -1.5 price elasticity of demand
          double priceMultiplier = math.pow(priceRatio, priceElasticity).toDouble();
          double promoMultiplier = _hasPromo ? 1.45 : 1.0;
          
          _simulatedForecast = _baseForecast * priceMultiplier * promoMultiplier;
          _changePercentage = ((_simulatedForecast - _baseForecast) / _baseForecast) * 100;
        }
        _isSimulating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: context.bg,
        appBar: AppBar(title: const Text('AI Telemetry')),
        body: Center(
          child: Text('Failed to load item telemetry.', style: TextStyle(color: context.textMain)),
        ),
      );
    }

    final p = _product!;
    final current = p.currentStock ?? 120.0;
    final rop = p.reorderPoint ?? 100.0;
    final ss = p.safetyStock ?? 50.0;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        title: Text(p.brandName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item Header
            Text(
              p.itemId,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 1.5),
            ),
            const SizedBox(height: 2),
            Text(
              p.itemName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textMain),
            ),
            const SizedBox(height: 16),

            // Parameters row cards
            Row(
              children: [
                Expanded(child: _buildMiniCard('Current Stock', current.toInt().toString(), color: current <= rop ? AppTheme.warning : AppTheme.success)),
                const SizedBox(width: 8),
                Expanded(child: _buildMiniCard('Safety Stock', ss.toInt().toString())),
                const SizedBox(width: 8),
                Expanded(child: _buildMiniCard('Reorder Point', rop.toInt().toString())),
              ],
            ),
            const SizedBox(height: 16),

            // AI Forecast chart with simulation overlay
            _buildSimulationChart(),
            const SizedBox(height: 16),

            // What-If Simulation Panel
            _buildWhatIfPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard(String label, String value, {Color color = Colors.white}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: context.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSimulationChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEEP FORECAST TREND',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: context.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '4-Week Demand Graph',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textMain),
          ),
          const SizedBox(height: 20),

          // Custom Painted Chart
          SizedBox(
            height: 150,
            width: double.infinity,
            child: TelemetryChart(
              baseForecast: _baseForecast,
              simulatedForecast: _simulatedForecast,
              changePercentage: _changePercentage,
              historyActual: _historyActual,
              historyWeeks: _historyWeeks,
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 3, color: context.border),
              const SizedBox(width: 6),
              Text('Original Base', style: TextStyle(fontSize: 9, color: context.textMuted)),
              const SizedBox(width: 20),
              Container(width: 10, height: 3, color: _changePercentage >= 0 ? AppTheme.success : AppTheme.critical),
              const SizedBox(width: 6),
              Text('Simulated Dynamic', style: TextStyle(fontSize: 9, color: context.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIfPanel() {
    final hasGain = _changePercentage >= 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulated output display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIMULATION OUTPUT',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 1.0),
              ),
              if (_isSimulating)
                const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_simulatedForecast.toInt()} Units',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textMain),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                hasGain ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                size: 14,
                color: hasGain ? AppTheme.success : AppTheme.critical,
              ),
              const SizedBox(width: 6),
              Text(
                '${hasGain ? "+" : ""}${_changePercentage.toStringAsFixed(1)}% demand change',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasGain ? AppTheme.success : AppTheme.critical,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _hasPromo ? 'with Promo active' : 'due to price shift',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ],
          ),
          Divider(color: context.border, height: 24),

          // Price Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Unit Price (EGP)', style: TextStyle(fontSize: 12, color: context.textMain, fontWeight: FontWeight.bold)),
              Text('${_simulatedPrice.toStringAsFixed(1)} EGP', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: context.border,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: _simulatedPrice,
              min: _basePrice * 0.5,
              max: _basePrice * 1.5,
              divisions: 20,
              onChanged: (val) {
                setState(() {
                  _simulatedPrice = val;
                });
              },
              onChangeEnd: (val) {
                _runSimulation();
              },
            ),
          ),

          // Promo Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Promotional Campaign', style: TextStyle(fontSize: 12, color: context.textMain, fontWeight: FontWeight.bold)),
              Switch(
                value: _hasPromo,
                activeColor: AppTheme.primary,
                activeTrackColor: AppTheme.primary.withOpacity(0.3),
                inactiveThumbColor: context.textMuted,
                inactiveTrackColor: context.border,
                onChanged: (val) {
                  setState(() {
                    _hasPromo = val;
                  });
                  _runSimulation();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TelemetryChart extends StatelessWidget {
  final double baseForecast;
  final double simulatedForecast;
  final double changePercentage;
  final List<double> historyActual;
  final List<String> historyWeeks;

  const TelemetryChart({
    Key? key,
    required this.baseForecast,
    required this.simulatedForecast,
    required this.changePercentage,
    this.historyActual = const [],
    this.historyWeeks = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 150),
      painter: _TelemetryChartPainter(
        baseForecast,
        simulatedForecast,
        changePercentage,
        historyActual,
        historyWeeks,
      ),
    );
  }
}

class _TelemetryChartPainter extends CustomPainter {
  final double baseVal;
  final double simulatedVal;
  final double changePct;
  final List<double> history;
  final List<String> weeks;

  _TelemetryChartPainter(
    this.baseVal,
    this.simulatedVal,
    this.changePct,
    this.history,
    this.weeks,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    
    for (int i = 0; i < 4; i++) {
      double y = size.height * i / 3;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), gridPaint);
    }

    double maxVal = baseVal;
    if (simulatedVal > maxVal) maxVal = simulatedVal;
    for (final v in history) {
      if (v > maxVal) maxVal = v;
    }
    maxVal = maxVal * 1.2;
    if (maxVal <= 0) maxVal = 3000;

    double getX(int index, int total) => 30 + (size.width - 30) * index / (total - 1);
    double getY(double val) => size.height - (size.height * val / maxVal);

    final historyPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (history.length >= 2) {
      final historyPath = Path();
      historyPath.moveTo(getX(0, history.length), getY(history[0]));
      for (int i = 1; i < history.length; i++) {
        historyPath.lineTo(getX(i, history.length), getY(history[i]));
      }
      canvas.drawPath(historyPath, historyPaint);
    } else {
      final historyPath = Path();
      historyPath.moveTo(getX(0, 4), getY(baseVal * 0.85));
      historyPath.lineTo(getX(1, 4), getY(baseVal * 0.95));
      historyPath.lineTo(getX(2, 4), getY(baseVal * 0.9));
      canvas.drawPath(historyPath, historyPaint);
    }

    final lastIdx = history.length >= 2 ? history.length - 1 : 2;
    final lastVal = history.isNotEmpty ? history.last : baseVal * 0.9;
    final aiIdx = history.length >= 2 ? history.length : 3;
    final basePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final basePath = Path();
    basePath.moveTo(getX(lastIdx, aiIdx + 1), getY(lastVal));
    basePath.lineTo(getX(aiIdx, aiIdx + 1), getY(baseVal));
    _drawDashedPath(canvas, basePath, basePaint);

    final simPaint = Paint()
      ..color = changePct >= 0 ? AppTheme.success : AppTheme.critical
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final simPath = Path();
    simPath.moveTo(getX(lastIdx, aiIdx + 1), getY(lastVal));
    simPath.lineTo(getX(aiIdx, aiIdx + 1), getY(simulatedVal));
    canvas.drawPath(simPath, simPaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = Colors.white30;
    for (int i = 0; i < history.length; i++) {
      canvas.drawCircle(Offset(getX(i, history.length >= 2 ? history.length : 4), getY(history[i])), 4, dotPaint);
    }

    dotPaint.color = Colors.white54;
    canvas.drawCircle(Offset(getX(aiIdx, aiIdx + 1), getY(baseVal)), 4, dotPaint);

    dotPaint.color = changePct >= 0 ? AppTheme.success : AppTheme.critical;
    canvas.drawCircle(Offset(getX(aiIdx, aiIdx + 1), getY(simulatedVal)), 5, dotPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 1; i <= 3; i++) {
      double val = maxVal * i / 3;
      double y = getY(val) - 6;
      textPainter.text = TextSpan(
        text: val >= 1000 ? '${(val / 1000).toStringAsFixed(0)}k' : val.toStringAsFixed(0),
        style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y));
    }

    final labels = weeks.isNotEmpty
        ? [...weeks, 'AI']
        : ['W1', 'W2', 'W3', 'W4 (AI)'];
    for (int i = 0; i < labels.length && i <= aiIdx; i++) {
      double x = getX(i, aiIdx + 1) - 12;
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: 8, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, size.height + 6));
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? 6.0 : 4.0;
        if (draw) {
          final extract = metric.extractPath(distance, distance + length);
          canvas.drawPath(extract, paint);
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
