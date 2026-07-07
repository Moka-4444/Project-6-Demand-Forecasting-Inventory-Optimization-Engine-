class AlertItem {
  final String itemId;
  final String itemName;
  final double forecastMean;
  final double safetyStock;
  final double reorderPoint;
  final double currentStock;
  final double eoq;
  final String status; // 'critical' or 'warning'

  AlertItem({
    required this.itemId,
    required this.itemName,
    required this.forecastMean,
    required this.safetyStock,
    required this.reorderPoint,
    required this.currentStock,
    required this.eoq,
    required this.status,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'] ?? '',
      forecastMean: (json['forecast_mean'] as num?)?.toDouble() ?? 0.0,
      safetyStock: (json['safety_stock'] as num?)?.toDouble() ?? 0.0,
      reorderPoint: (json['reorder_point'] as num?)?.toDouble() ?? 0.0,
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      eoq: (json['eoq'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'warning',
    );
  }
}
