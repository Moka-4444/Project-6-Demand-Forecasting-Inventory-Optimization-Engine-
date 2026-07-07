import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class MatrixScreen extends StatefulWidget {
  const MatrixScreen({Key? key}) : super(key: key);

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _brands = [];
  int _totalSkus = 0;

  static const _brandColors = [
    AppTheme.primary,
    AppTheme.secondaryLight,
    AppTheme.success,
    AppTheme.warning,
    Colors.blue,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getBrandMatrix();
    if (mounted) {
      setState(() {
        if (data != null) {
          _brands = (data['brands'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _totalSkus = (data['total_skus'] as num?)?.toInt() ?? 0;
        }
        _isLoading = false;
      });
    }
  }

  String _formatVolume(num volume) {
    if (volume >= 1000000) return '${(volume / 1000000).toStringAsFixed(1)}M Units';
    if (volume >= 1000) return '${(volume / 1000).toStringAsFixed(0)}K Units';
    return '${volume.toInt()} Units';
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
        onRefresh: _loadMatrix,
        color: AppTheme.primary,
        backgroundColor: context.cardBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'STRATEGIC MATRIX',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Brand Performance Matrix',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 20),

              if (_brands.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No brand data available.', style: TextStyle(color: context.textMuted)),
                  ),
                )
              else
                ...List.generate(_brands.length, (index) {
                  final brand = _brands[index];
                  final share = (brand['market_share'] as num?)?.toDouble() ?? 0.0;
                  final alerts = (brand['alert_count'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < _brands.length - 1 ? 12 : 0),
                    child: _buildBrandComparisonCard(
                      brandName: brand['brand_name']?.toString() ?? '',
                      volume: _formatVolume(brand['total_volume'] ?? 0),
                      alerts: '$alerts SKUs below ROP',
                      marketShare: share,
                      iconColor: _brandColors[index % _brandColors.length],
                    ),
                  );
                }),

              const SizedBox(height: 24),
              _buildVolumeDistributionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandComparisonCard({
    required String brandName,
    required String volume,
    required String alerts,
    required double marketShare,
    required Color iconColor,
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    brandName,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textMain),
                  ),
                ],
              ),
              Text(
                '${(marketShare * 100).toStringAsFixed(0)}% Share',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Sales Volume', style: TextStyle(fontSize: 10, color: context.textMuted)),
                  const SizedBox(height: 2),
                  Text(volume, style: TextStyle(fontSize: 13, color: context.textMain, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Supply Chain Alert', style: TextStyle(fontSize: 10, color: context.textMuted)),
                  const SizedBox(height: 2),
                  Text(alerts, style: TextStyle(fontSize: 13, color: context.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 4,
              width: double.infinity,
              color: context.border.withOpacity(0.4),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: marketShare.clamp(0.0, 1.0),
                child: Container(color: iconColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeDistributionCard() {
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
            'LOGISTICS SUMMARY',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.textMuted, letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            'Revenue Contrast & Dispatch',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textMain),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Active Brands', '${_brands.length} FMCG Groups'),
          _buildDetailRow('Active SKU Catalog', '$_totalSkus Items'),
          _buildDetailRow('Ensemble ML Coverage', '100% SKU Autonomy'),
          _buildDetailRow('Primary Supplier', 'Delta FMCG Egypt'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.textMuted)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textMain)),
        ],
      ),
    );
  }
}
