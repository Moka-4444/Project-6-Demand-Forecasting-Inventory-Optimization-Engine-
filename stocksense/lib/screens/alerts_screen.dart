import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/alert_item.dart';
import 'procurement_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<AlertItem> _stockAlerts = [];
  List<Map<String, dynamic>> _expiryAlerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    
    // Fetch Stock alerts and Expiry list in parallel
    final results = await Future.wait([
      ApiService.getAlerts(),
      ApiService.getExpiry(),
    ]);

    if (mounted) {
      setState(() {
        _stockAlerts = results[0] as List<AlertItem>;
        _expiryAlerts = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearExpiryBatch(String itemId, String itemName) async {
    setState(() => _isLoading = true);
    final success = await ApiService.clearExpiry(itemId);
    
    // Remove locally from the list
    if (success) {
      setState(() {
        _expiryAlerts.removeWhere((element) => element['item_id'] == itemId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared expired batch for $itemName successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clear batch. Check backend connection.'),
          backgroundColor: AppTheme.critical,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _triggerProcurement(AlertItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcurementScreen(
          itemId: item.itemId,
          itemName: item.itemName,
          rop: item.reorderPoint,
          safetyStock: item.safetyStock,
          eoq: item.eoq,
        ),
      ),
    ).then((value) {
      // Reload alerts when returning, since ordering adds stock and resolves alerts!
      _loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: context.cardBg,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: context.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Stock alerts'),
              Tab(text: 'Expiry tracking'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStockAlertsTab(),
                _buildExpiryAlertsTab(),
              ],
            ),
    );
  }

  Widget _buildStockAlertsTab() {
    if (_stockAlerts.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.checkCircle2,
        title: 'All SKUs Healthy',
        desc: 'No stock level has breached the calculated Reorder Point (ROP).',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stockAlerts.length,
      itemBuilder: (context, index) {
        final alert = _stockAlerts[index];
        final isCritical = alert.status == 'critical';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCritical ? AppTheme.critical.withOpacity(0.3) : AppTheme.warning.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header line
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isCritical ? AppTheme.critical : AppTheme.warning).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCritical ? 'CRITICAL (Below SS)' : 'WARNING (Below ROP)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isCritical ? AppTheme.critical : AppTheme.warning,
                      ),
                    ),
                  ),
                  Text(
                    'SKU: ${alert.itemId}',
                    style: TextStyle(fontSize: 10, color: context.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Name
              Text(
                alert.itemName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textMain),
              ),
              const SizedBox(height: 16),
              
              // Values comparison grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricCell('Current Stock', '${alert.currentStock.toInt()}', isCritical ? AppTheme.critical : AppTheme.warning),
                  _buildMetricCell('Reorder Point (ROP)', '${alert.reorderPoint.toInt()}', context.textMuted),
                  _buildMetricCell('Recommended EOQ', '${alert.eoq.toInt()}', AppTheme.success),
                ],
              ),
              const SizedBox(height: 16),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _triggerProcurement(alert),
                  icon: const Icon(LucideIcons.shoppingCart, size: 16),
                  label: const Text('ONE-CLICK ORDER NOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpiryAlertsTab() {
    if (_expiryAlerts.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.shieldAlert,
        title: 'No Expiry Risks',
        desc: 'All batches have healthy remaining shelf life values.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expiryAlerts.length,
      itemBuilder: (context, index) {
        final item = _expiryAlerts[index];
        final days = item['days_to_expiry'] as int;
        final isExpired = days <= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpired ? AppTheme.critical.withOpacity(0.3) : AppTheme.warning.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header line
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isExpired ? AppTheme.critical : AppTheme.warning).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isExpired ? 'EXPIRED' : 'NEAR EXPIRY ($days Days)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? AppTheme.critical : AppTheme.warning,
                      ),
                    ),
                  ),
                  Text(
                    'Batch: ${item['batch_no']}',
                    style: TextStyle(fontSize: 10, color: context.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Name
              Text(
                item['item_name'] ?? '',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textMain),
              ),
              const SizedBox(height: 12),
              
              // Batch Quantity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Batch Quantity', style: TextStyle(fontSize: 11, color: context.textMuted)),
                      const SizedBox(height: 2),
                      Text('${item['qty']} Units', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textMain)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _clearExpiryBatch(item['item_id'], item['item_name']),
                    icon: Icon(isExpired ? LucideIcons.trash2 : LucideIcons.tag, size: 14),
                    label: Text(isExpired ? 'DISPOSE & CLEAR' : 'MARK FOR DISCOUNT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpired ? AppTheme.critical : AppTheme.secondaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCell(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String desc}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.success.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
