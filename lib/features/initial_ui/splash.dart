import 'package:autobus/barrel.dart';
import 'package:autobus/features/onboarding/onboarding_storage.dart';
import 'package:autobus/icons/figma_icons.dart';

class SplashPge extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashPge({super.key, this.onFinished});

  @override
  State<SplashPge> createState() => _SplashPgeState();
}

class _SplashPgeState extends State<SplashPge> {
  Future<void> _goNext() async {
    print('=== SPLASH BUTTON PRESSED - NAVIGATING ===');
    await OnboardingStorage().markSplashSeen();
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;

              final yourTop = h * (465 / 926);
              final autonomousTop = h * (515 / 926);
              final subtitleTop = h * (585 / 926);
              final buttonTop = h * (690 / 926);

              const textCol = Color(0xFF09050F);
              const brandCol = CustColors.mainCol;

              return Stack(
                children: [
                  SafeArea(
                    child: Stack(
                      children: [
                        Center(
                          child: Image.asset(
                            FigmaImages.splashLogo,
                            width: 125,
                            height: 108,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          top: yourTop,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              "Your",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: textCol,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: autonomousTop,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              "Autonomous",
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: textCol,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: subtitleTop,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              "Business operations assistant!",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: textCol,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: buttonTop,
                          left: (w - 270) / 2,
                          child: SizedBox(
                            width: 270,
                            height: 51,
                            child: ElevatedButton(
                              onPressed: _goNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandCol,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "Get Started",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
