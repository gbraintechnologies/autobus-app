import 'package:autobus/barrel.dart';
import 'package:autobus/icons/figma_icons.dart';

/// First-run onboarding — Figma ONBOARDING 402×874.
class OnboardingPage extends StatelessWidget {
  final VoidCallback onFinished;

  const OnboardingPage({super.key, required this.onFinished});

  static const _designWidth = 402.0;
  static const _designHeight = 874.0;
  static const _backgroundColor = Colors.white;
  static const _buttonColor = Color(0xFF2D0C51);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = size.width / _designWidth;
    final vScale = size.height / _designHeight;

    final imageWidth = 268.18 * scale;
    final imageHeight = 226 * scale;
    final buttonWidth = 333 * scale;
    final buttonHeight = 64 * scale;
    const titleSize = 20.0;
    const bodySize = 14.0;
    const ctaSize = 16.0;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 35 * scale),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Center(
                child: Image.asset(
                  FigmaImages.onboardingHero,
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 71 * vScale),
              Text(
                'Run your whole business\nfrom one app',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 24 * vScale),
              Text(
                'Chats, orders, marketing, and an AI that knows your '
                'business — all in one place.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                  color: Colors.black,
                ),
              ),
              const Spacer(flex: 2),
              Center(
                child: Material(
                  color: _buttonColor,
                  borderRadius: BorderRadius.circular(30 * scale),
                  child: InkWell(
                    onTap: onFinished,
                    borderRadius: BorderRadius.circular(30 * scale),
                    child: SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get started',
                            style: GoogleFonts.poppins(
                              fontSize: ctaSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10 * scale),
                          FigmaSvgIcon(
                            FigmaIcons.arrowDown,
                            size: 20 * scale.clamp(0.9, 1.1),
                            color: Colors.white,
                            chevronRight: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 64 * vScale),
            ],
          ),
        ),
      ),
    );
  }
}
