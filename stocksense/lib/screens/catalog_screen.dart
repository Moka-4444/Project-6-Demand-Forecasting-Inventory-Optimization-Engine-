import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import 'telemetry_screen.dart';
import 'scanner_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  _CatalogScreenState createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  bool _isLoading = true;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _selectedBrand = 'ALL';
  String _searchQuery = '';
  List<String> _brands = ['ALL'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getProducts();
    if (mounted) {
      setState(() {
        _allProducts = list;
        final brandSet = <String>{'ALL'};
        for (final p in list) {
          if (p.masterBrand.isNotEmpty) brandSet.add(p.masterBrand);
        }
        _brands = brandSet.toList();
        _filterProducts();
        _isLoading = false;
      });
    }
  }

  void _filterProducts() {
    List<Product> temp = _allProducts;
    
    // Brand filter
    if (_selectedBrand != 'ALL') {
      temp = temp.where((p) =>
        p.brandName.toLowerCase().contains(_selectedBrand.toLowerCase()) ||
        p.masterBrand.toLowerCase().contains(_selectedBrand.toLowerCase())
      ).toList();
    }
    
    // Search query filter
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((p) => p.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) || p.itemId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    setState(() {
      _filteredProducts = temp;
    });
  }

  void _onBrandSelected(String brand) {
    setState(() {
      _selectedBrand = brand;
      _filterProducts();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: context.cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                TextField(
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: context.textMain, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search 136 SKU items...',
                    hintStyle: TextStyle(color: context.textMuted),
                    prefixIcon: Icon(LucideIcons.search, color: context.textMuted, size: 18),
                    filled: true,
                    fillColor: context.bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Brand Selector Horizontal List
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _brands.length,
                    itemBuilder: (context, index) {
                      final brand = _brands[index];
                      final isSelected = _selectedBrand == brand;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            brand,
                            style: TextStyle(
                              color: isSelected ? Colors.white : context.textMuted,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          backgroundColor: context.bg,
                          elevation: 0,
                          pressElevation: 0,
                          onSelected: (_) => _onBrandSelected(brand),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main list area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: AppTheme.primary,
                        backgroundColor: context.cardBg,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          ).then((value) {
            // Refresh catalog if any scan occurred
            _loadProducts();
          });
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(LucideIcons.scan, color: Colors.white),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    // Determine Stock Status
    final current = product.currentStock ?? 120.0;
    final rop = product.reorderPoint ?? 100.0;
    final ss = product.safetyStock ?? 50.0;

    String statusText = 'HEALTHY';
    Color statusColor = AppTheme.success;
    
    if (current <= ss) {
      statusText = 'CRITICAL';
      statusColor = AppTheme.critical;
    } else if (current <= rop) {
      statusText = 'REORDER';
      statusColor = AppTheme.warning;
    }

    // Progress percentage
    final double maxBar = rop * 1.5;
    double pct = current / maxBar;
    if (pct > 1.0) pct = 1.0;
    if (pct < 0.0) pct = 0.0;

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.border, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TelemetryScreen(itemId: product.itemId),
            ),
          ).then((value) {
            _loadProducts(); // refresh stock on back
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Brand & Status Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${product.brandName.toUpperCase()} • ${product.itemId}',
                    style: TextStyle(fontSize: 10, color: context.textMuted, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(fontSize: 8, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: Product Name
              Text(
                product.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textMain),
              ),
              const SizedBox(height: 12),

              // Row 3: Stock bar status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stock: ${current.toInt()} units',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                  Text(
                    'ROP: ${rop.toInt()}',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: context.border.withOpacity(0.3),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageOpen, size: 48, color: context.textMuted),
          SizedBox(height: 12),
          Text(
            'No Products Found',
            style: TextStyle(color: context.textMain, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Try adjusting your search or brand filters.',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
