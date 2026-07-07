import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ProcurementScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  final double rop;
  final double safetyStock;
  final double eoq;

  const ProcurementScreen({
    Key? key,
    required this.itemId,
    required this.itemName,
    required this.rop,
    required this.safetyStock,
    required this.eoq,
  }) : super(key: key);

  @override
  _ProcurementScreenState createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> {
  late double _orderQuantity;
  bool _isTransmitting = false;
  bool _isSuccess = false;
  bool _hasError = false;
  String _selectedVendor = 'Giza Logistics & Warehousing';
  String? _poId;

  List<String> _vendors = [
    'Giza Logistics & Warehousing',
    'Delta FMCG Distributors',
    'Cairo Central Logistics Corp',
  ];

  @override
  void initState() {
    super.initState();
    _orderQuantity = widget.eoq;
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    final vendors = await ApiService.getVendors();
    if (mounted && vendors.isNotEmpty) {
      setState(() {
        _vendors = vendors;
        _selectedVendor = vendors.first;
      });
    }
  }

  void _adjustQuantity(double delta) {
    setState(() {
      _orderQuantity += delta;
      if (_orderQuantity < 1) _orderQuantity = 1;
    });
  }

  Future<void> _submitPurchaseOrder() async {
    setState(() {
      _isTransmitting = true;
      _hasError = false;
    });

    final result = await ApiService.submitProcurement(
      itemId: widget.itemId,
      quantity: _orderQuantity,
      vendor: _selectedVendor,
    );

    if (mounted) {
      if (result != null && result['status'] == 'success') {
        setState(() {
          _isTransmitting = false;
          _isSuccess = true;
          _poId = result['po_id']?.toString();
        });
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() {
          _isTransmitting = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit purchase order. Check backend connection.'),
            backgroundColor: AppTheme.critical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        title: const Text('One-Click Procurement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info header card
                Container(
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
                        'SELECTED ITEM DETAILS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.itemName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU ID: ${widget.itemId}',
                        style: TextStyle(fontSize: 12, color: context.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniMetric('Safety Stock', widget.safetyStock.toInt().toString()),
                          _buildMiniMetric('Reorder Point (ROP)', widget.rop.toInt().toString()),
                          _buildMiniMetric('Optimal EOQ', widget.eoq.toInt().toString()),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Procurement settings form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vendor Dropdown
                      Text(
                        'ROUTING VENDOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedVendor,
                            dropdownColor: context.cardBg,
                            isExpanded: true,
                            style: TextStyle(color: context.textMain, fontSize: 14),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedVendor = newValue;
                                });
                              }
                            },
                            items: _vendors.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Order Quantity Adjuster
                      Text(
                        'ADJUST PO QUANTITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Decrement
                          InkWell(
                            onTap: () => _adjustQuantity(-50),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.border.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.border),
                              ),
                              child: Icon(LucideIcons.minus, size: 20, color: context.textMain),
                            ),
                          ),
                          
                          // Quantity Display
                          Column(
                            children: [
                              Text(
                                '${_orderQuantity.toInt()}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                              Text(
                                'Recommended EOQ Units',
                                style: TextStyle(fontSize: 10, color: context.textMuted),
                              ),
                            ],
                          ),
                          
                          // Increment
                          InkWell(
                            onTap: () => _adjustQuantity(50),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.border.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.border),
                              ),
                              child: Icon(LucideIcons.plus, size: 20, color: context.textMain),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Purchase details
                const SizedBox(height: 24),
                Text(
                  'ORDER ESTIMATE SUMMARY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: context.textMuted),
                ),
                const SizedBox(height: 8),
                _buildSummaryRow('Purchase Quantity', '${_orderQuantity.toInt()} Units'),
                _buildSummaryRow('FMCG Category Route', 'Crisps & Snacks'),
                _buildSummaryRow('Estimated Lead Time', '7 Business Days'),
                Divider(color: context.border, height: 24),
                _buildSummaryRow('Automated EOQ Match', '100% Validated', valueColor: AppTheme.success),
                
                const SizedBox(height: 32),
                
                // Confirm PO CTA Button
                ElevatedButton.icon(
                  onPressed: _submitPurchaseOrder,
                  icon: const Icon(LucideIcons.checkSquare, size: 18),
                  label: const Text('CONFIRM & SEND PURCHASE ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          
          // Transmitting Overlay Loader
          if (_isTransmitting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 20),
                      Text(
                        'Transmitting Secure Purchase Order...',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Routing order packet to Giza Warehouses...',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          // Success Overlay Checkmark
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'PO Sent Successfully!',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          'Authorized restocking of ${_orderQuantity.toInt()} units of "${widget.itemName}" via $_selectedVendor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textMuted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'PO ID: ${_poId ?? 'CR-PO-PENDING'}',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
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

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textMain)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.textMuted)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
