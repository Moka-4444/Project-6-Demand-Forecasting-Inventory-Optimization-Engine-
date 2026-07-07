import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'main_navigation_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isManager = true;
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _emailController =
      TextEditingController(text: 'manager@stocksense.com');
  final TextEditingController _passwordController =
      TextEditingController(text: 'password123');

  void _onRoleToggle(bool isManager) {
    setState(() {
      _isManager = isManager;
      _emailController.text =
          isManager ? 'manager@stocksense.com' : 'staff@stocksense.com';
      _errorMessage = null;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainNavigationContainer(
            role: result['role'] as String? ?? (_isManager ? 'executive' : 'operator'),
          ),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login failed. Please check your credentials and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? context.bg : AppTheme.bgLight;
    final cardBg = isDark ? context.cardBg : AppTheme.cardBgLight;
    final textMain = isDark ? context.textMain : AppTheme.textMainLight;
    final textMuted = isDark ? context.textMuted : AppTheme.textMutedLight;
    final border = isDark ? context.border : AppTheme.borderLight;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SVG Logo
                SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 20),

                // App name
                Text(
                  'StockSense',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Smart Inventory Management',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 36),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.critical.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.critical.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.critical,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Role selector
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onRoleToggle(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: _isManager
                                  ? AppTheme.primary.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(7)),
                            ),
                            child: Text(
                              'Manager',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isManager
                                    ? AppTheme.primary
                                    : textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onRoleToggle(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: !_isManager
                                  ? AppTheme.primary.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(7)),
                            ),
                            child: Text(
                              'Staff',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_isManager
                                    ? AppTheme.primary
                                    : textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Email field
                TextField(
                  controller: _emailController,
                  style: GoogleFonts.dmSans(
                      color: textMain, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: context.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: GoogleFonts.dmSans(
                      color: textMain, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline,
                        color: context.textMuted, size: 20),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 28),

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Sign In',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
