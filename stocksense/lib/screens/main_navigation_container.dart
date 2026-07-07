import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'alerts_screen.dart';
import 'catalog_screen.dart';
import 'matrix_screen.dart';
import 'system_health_screen.dart';
import 'scanner_screen.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  final String role; // 'executive' or 'operator'

  const MainNavigationContainer({Key? key, required this.role})
      : super(key: key);

  @override
  _MainNavigationContainerState createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState
    extends State<MainNavigationContainer> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _buildNavigation();
  }

  void _buildNavigation() {
    if (widget.role == 'executive') {
      _screens = [
        const DashboardScreen(),
        const AlertsScreen(),
        const CatalogScreen(),
        const MatrixScreen(),
        const SystemHealthScreen(),
      ];
      _navItems = const [
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.layoutDashboard), label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.bell), label: 'Alerts'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.package), label: 'Products'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.trendingUp), label: 'Brands'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.activity), label: 'AI Health'),
      ];
    } else {
      _screens = [
        const CatalogScreen(),
        const AlertsScreen(),
        const ScannerScreen(),
      ];
      _navItems = const [
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.package), label: 'Products'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.bell), label: 'Alerts'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.scan), label: 'Scanner'),
      ];
    }
  }

  void _logout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Log Out', style: TextStyle(color: isDark ? Colors.white : AppTheme.textMainLight)),
        content: Text('Are you sure you want to log out?', style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textMutedLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textMutedLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExec = widget.role == 'executive';
    final roleLabel = isExec ? 'Manager' : 'Staff';
    final roleColor =
        isExec ? AppTheme.primary : AppTheme.secondaryLight;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark
            ? context.cardBg
            : AppTheme.cardBgLight,
        elevation: 1,
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'StockSense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Dark/Light mode toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              final isCurrentlyDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isCurrentlyDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 20,
                  color: isDark
                      ? Colors.white70
                      : AppTheme.textMutedLight,
                ),
                tooltip: isCurrentlyDark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                onPressed: toggleTheme,
              );
            },
          ),
          // Logout
          IconButton(
            icon: Icon(
              LucideIcons.logOut,
              size: 20,
              color: isDark
                  ? Colors.white54
                  : AppTheme.textMutedLight,
            ),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? context.border
                  : AppTheme.borderLight,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark
              ? context.cardBg
              : AppTheme.cardBgLight,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: isDark
              ? context.textMuted
              : AppTheme.textMutedLight,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: _navItems,
        ),
      ),
    );
  }
}
