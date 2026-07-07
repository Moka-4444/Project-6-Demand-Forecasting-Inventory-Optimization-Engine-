import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_navigation_container.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _statusText = 'Starting up...';
  Timer? _timer;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
    _initialize();
  }

  Future<void> _initialize() async {
    await ApiService.loadSession();
    if (!mounted) return;
    setState(() => _statusText = 'Connecting...');

    final health = await ApiService.checkHealth();
    if (!mounted) return;

    if (health['status'] == 'ok' && health['models_loaded'] == true) {
      setState(() =>
          _statusText = 'Ready — ${health['products_count']} products loaded');
    } else if (health['status'] == 'ok') {
      setState(() => _statusText = 'Connected — loading data...');
    } else {
      setState(() => _statusText = 'Offline — tap to continue anyway');
    }

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        if (_progress < 1.0) {
          _progress += 0.015;
          if (_progress > 1.0) _progress = 1.0;
        } else {
          _timer?.cancel();
          _navigateNext();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    if (!onboardingDone) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else if (ApiService.isAuthenticated) {
      final role = await ApiService.getSavedRole() ?? 'executive';
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => MainNavigationContainer(role: role)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Stack(
        children: [
          // Animated wave background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: WaveShaderPainter(time: _waveController.value),
                );
              },
            ),
          ),

          // Foreground card
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Container(
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: context.cardBg.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: context.textMain,
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Your smart inventory assistant —\nalways know what to order and when.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: context.textMuted.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Progress label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Starting Up',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: context.textMuted,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 6,
                        width: double.infinity,
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progress,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  Color(0xFFFF8A65),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status text
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Skip button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: _navigateNext,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Wave background painter
class WaveShaderPainter extends CustomPainter {
  final double time;

  WaveShaderPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paintNavy = Paint()
      ..color = AppTheme.secondary.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final paintOrange = Paint()
      ..color = AppTheme.primary.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final paintVignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.7),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black);

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final double waveHeight = 25.0 + (i * 10.0);
      final double frequency = 0.005 + (i * 0.002);
      final double speed = (i + 1) * 0.5;

      path.moveTo(0, size.height * 0.5);

      for (double x = 0; x <= size.width; x += 5) {
        final double y = size.height * 0.5 +
            math.sin(x * frequency + (time * speed)) * waveHeight +
            math.cos(x * 0.01 - (time * 0.3)) * 10;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      canvas.drawPath(path, i == 1 ? paintOrange : paintNavy);
    }

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), paintVignette);
  }

  @override
  bool shouldRepaint(covariant WaveShaderPainter oldDelegate) =>
      oldDelegate.time != time;
}
