class Product {
  final String itemId;
  final String itemName;
  final String brandName;
  final String masterBrand;
  
  // Forecast fields
  final double? forecastMean;
  final double? forecastStd;
  final double? actualMean;
  final int? weeksOfData;
  
  // Inventory fields
  final double? avgDailyDemand;
  final double? safetyStock;
  final double? reorderPoint;
  final double? eoq;
  final double? ordersPerYear;
  final double? currentStock;
  final double? avgUnitPrice;

  Product({
    required this.itemId,
    required this.itemName,
    required this.brandName,
    required this.masterBrand,
    this.forecastMean,
    this.forecastStd,
    this.actualMean,
    this.weeksOfData,
    this.avgDailyDemand,
    this.safetyStock,
    this.reorderPoint,
    this.eoq,
    this.ordersPerYear,
    this.currentStock,
    this.avgUnitPrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Check if details are nested (as in /products/{item_id})
    final forecast = json['forecast'] as Map<String, dynamic>?;
    final inventory = json['inventory'] as Map<String, dynamic>?;

    return Product(
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'] ?? '',
      brandName: json['brand_name'] ?? '',
      masterBrand: json['master_brand'] ?? '',
      
      forecastMean: forecast != null ? (forecast['forecast_mean'] as num?)?.toDouble() : null,
      forecastStd: forecast != null ? (forecast['forecast_std'] as num?)?.toDouble() : null,
      actualMean: forecast != null ? (forecast['actual_mean'] as num?)?.toDouble() : null,
      weeksOfData: forecast != null ? (forecast['weeks_of_data'] as num?)?.toInt() : null,
      
      avgDailyDemand: inventory != null 
          ? (inventory['avg_daily_demand'] as num?)?.toDouble() 
          : (json['avg_daily_demand'] as num?)?.toDouble(),
      safetyStock: inventory != null 
          ? (inventory['safety_stock'] as num?)?.toDouble() 
          : (json['safety_stock'] as num?)?.toDouble(),
      reorderPoint: inventory != null 
          ? (inventory['reorder_point'] as num?)?.toDouble() 
          : (json['reorder_point'] as num?)?.toDouble(),
      eoq: inventory != null 
          ? (inventory['eoq'] as num?)?.toDouble() 
          : (json['eoq'] as num?)?.toDouble(),
      ordersPerYear: inventory != null 
          ? (inventory['orders_per_year'] as num?)?.toDouble() 
          : (json['orders_per_year'] as num?)?.toDouble(),
      currentStock: inventory != null 
          ? (inventory['current_stock'] as num?)?.toDouble() 
          : (json['current_stock'] as num?)?.toDouble(),
      avgUnitPrice: (json['avg_unit_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'brand_name': brandName,
      'master_brand': masterBrand,
      'forecast': {
        'forecast_mean': forecastMean,
        'forecast_std': forecastStd,
        'actual_mean': actualMean,
        'weeks_of_data': weeksOfData,
      },
      'inventory': {
        'avg_daily_demand': avgDailyDemand,
        'safety_stock': safetyStock,
        'reorder_point': reorderPoint,
        'eoq': eoq,
        'orders_per_year': ordersPerYear,
        'current_stock': currentStock,
      }
    };
  }
}
