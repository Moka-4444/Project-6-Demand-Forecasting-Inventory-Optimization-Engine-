import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _productsCount = 136;
  int _alertsCount = 12;
  double _stockValue = 0;
  double _monthChangePct = 0;
  List<Map<String, dynamic>> _topProducts = [];

  List<double> _actualSpots = [4200, 5800, 4900, 6200];
  List<double> _forecastSpots = [4400, 5500, 5100, 6000];
  List<String> _weeks = ['W23', 'W24', 'W25', 'W26'];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    // Hit API health and alerts to fetch dynamic counts
    final health = await ApiService.checkHealth();
    final alertsList = await ApiService.getAlerts();
    final inventory = await ApiService.getInventoryReport();
    final flow = await ApiService.getWeeklyFlow();
    
    if (mounted) {
      setState(() {
        if (health['status'] == 'ok') {
          _productsCount = health['products_count'] ?? 136;
        }
        _alertsCount = alertsList.length;
        
        // Calculate dynamic stock value from all products
        double totalUnits = 0.0;
        for (var item in inventory) {
          totalUnits += (item['current_stock'] as num?)?.toDouble() ?? 0.0;
        }
        if (totalUnits > 0) {
          _stockValue = (totalUnits * 0.75) / 1000000; // valuation in Millions (units * avg price $0.75)
        } else {
          _stockValue = 1.95 + (_productsCount * 0.005);
        }

        // Calculate top products by forecast demand
        if (inventory.isNotEmpty) {
          var sorted = List<Map<String, dynamic>>.from(inventory);
          sorted.sort((a, b) => ((b['forecast_mean'] as num?)?.toDouble() ?? 0.0)
              .compareTo((a['forecast_mean'] as num?)?.toDouble() ?? 0.0));
          _topProducts = sorted.take(3).toList();
        }

        if (flow.isNotEmpty && flow['actual_spots'] != null && flow['forecast_spots'] != null) {
          _actualSpots = (flow['actual_spots'] as List).map((e) => (e as num).toDouble()).toList();
          _forecastSpots = (flow['forecast_spots'] as List).map((e) => (e as num).toDouble()).toList();
          _weeks = (flow['weeks'] as List).map((e) => e.toString()).toList();
          _monthChangePct = (flow['month_change_pct'] as num?)?.toDouble() ?? 0.0;
        }
        
        _isLoading = false;
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

    return Scaffold(
      backgroundColor: context.bg,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppTheme.primary,
        backgroundColor: context.cardBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Welcome
                const Text(
                  'EXECUTIVE OVERVIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // KPI grid cards
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        title: 'STOCK VALUE',
                        value: '\$${_stockValue.toStringAsFixed(2)}M',
                        subtitle: '${_monthChangePct >= 0 ? '+' : ''}${_monthChangePct.toStringAsFixed(1)}% vs last week',
                        icon: LucideIcons.dollarSign,
                        color: _monthChangePct >= 0 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKPICard(
                        title: 'RISK PRODUCTS',
                        value: '$_alertsCount Items',
                        subtitle: 'Below safety threshold',
                        icon: LucideIcons.alertTriangle,
                        color: _alertsCount > 0 ? AppTheme.critical : AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Forecast Line Chart Card
                _buildForecastChartCard(),
                const SizedBox(height: 16),

                // Best Sellers
                _buildBestSellersCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: context.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textMain,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChartCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY DEMAND FLOW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: context.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Actual Sales vs AI Forecast',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ENSEMBLE ML',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Custom Painted Line Chart Viewport
          SizedBox(
            height: 195,
            width: double.infinity,
            child: SparkLineChart(
              actualSpots: _actualSpots,
              forecastSpots: _forecastSpots,
              weeks: _weeks,
            ),
          ),
          
          const SizedBox(height: 20),
          // Chart Legend
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildLegendItem('Actual Sales', const Color(0xFF3B82F6), isDashed: false),
              _buildLegendItem('AI Forecast', AppTheme.primary, isDashed: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool isDashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 12,
          alignment: Alignment.center,
          child: isDashed 
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (index) => Container(width: 4, height: 3, color: color)),
                )
              : Container(height: 3, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.textMuted, fontWeight: FontWeight.w600, height: 1.2),
        ),
      ],
    );
  }

  Widget _buildBestSellersCard() {
    if (_topProducts.isEmpty) {
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
            Text('DEMAND DYNAMICS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: context.textMuted)),
            SizedBox(height: 2),
            Text('Top Performing SKUs (Units)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textMain)),
            SizedBox(height: 16),
            Text('No inventory data available.', style: TextStyle(color: context.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    final maxForecast = (_topProducts.first['forecast_mean'] as num?)?.toDouble() ?? 1.0;
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
            'DEMAND DYNAMICS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Top Performing SKUs (Units)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textMain,
            ),
          ),
          const SizedBox(height: 16),
          ..._topProducts.map((p) {
            final name = p['item_name'] ?? '';
            final sku = p['item_id'] ?? '';
            final forecast = (p['forecast_mean'] as num?)?.toDouble() ?? 0.0;
            final pct = maxForecast > 0 ? (forecast / maxForecast).clamp(0.0, 1.0) : 0.5;
            final isLast = _topProducts.last == p;
            return Column(
              children: [
                _buildBestSellerRow(name, sku, forecast.toInt().toString(), pct),
                if (!isLast) Divider(color: context.border, height: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBestSellerRow(String name, String sku, String sales, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Logo placeholder box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.textMain.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.border),
            ),
            child: const Icon(LucideIcons.package, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.textMain,
                  ),
                ),
                Text(
                  'SKU: $sku',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                sales,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              // Mini progress bar for sales share
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMain.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Simple margin extension for lists
extension MarginWidget on Widget {
  Widget marginOnly({double right = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: right),
      child: this,
    );
  }
}

class SparkLineChart extends StatelessWidget {
  final List<double> actualSpots;
  final List<double> forecastSpots;
  final List<String> weeks;

  const SparkLineChart({
    Key? key,
    required this.actualSpots,
    required this.forecastSpots,
    required this.weeks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: _SparkLinePainter(actualSpots, forecastSpots, weeks),
    );
  }
}

class _SparkLinePainter extends CustomPainter {
  final List<double> actual;
  final List<double> forecast;
  final List<String> weeks;

  _SparkLinePainter(this.actual, this.forecast, this.weeks);

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height - 25; // Reserve 25px at bottom for labels
    
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    
    for (int i = 0; i <= 4; i++) {
      double y = chartHeight * i / 4;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), gridPaint);
    }

    double maxVal = 1000.0;
    for (var val in actual) {
      if (val > maxVal) maxVal = val;
    }
    for (var val in forecast) {
      if (val > maxVal) maxVal = val;
    }
    maxVal = maxVal * 1.15; // add 15% padding

    double getX(int index) => 30 + (size.width - 30) * index / (actual.length - 1);
    double getY(double val) => chartHeight - (chartHeight * val / maxVal);

    // Draw actual line (Blue)
    final actualPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final actualPath = Path();
    actualPath.moveTo(getX(0), getY(actual[0]));
    for (int i = 1; i < actual.length; i++) {
      actualPath.lineTo(getX(i), getY(actual[i]));
    }
    canvas.drawPath(actualPath, actualPaint);

    // Draw forecast line (Orange, Dashed)
    final forecastPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final forecastPath = Path();
    forecastPath.moveTo(getX(0), getY(forecast[0]));
    for (int i = 1; i < forecast.length; i++) {
      forecastPath.lineTo(getX(i), getY(forecast[i]));
    }

    _drawDashedPath(canvas, forecastPath, forecastPaint);

    // Draw labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    for (int i = 1; i <= 4; i++) {
      double val = maxVal * i / 4;
      double y = getY(val);
      String label = val >= 1000000 
          ? '${(val / 1000000).toStringAsFixed(1)}M'
          : val >= 1000 
              ? '${(val / 1000).toStringAsFixed(0)}k'
              : val.toStringAsFixed(0);
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - (textPainter.height / 2)));
    }

    for (int i = 0; i < weeks.length; i++) {
      textPainter.text = TextSpan(
        text: weeks[i],
        style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: 8, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      double x = getX(i) - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(x, chartHeight + 8));
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
