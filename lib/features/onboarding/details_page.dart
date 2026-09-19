import 'package:autobus/barrel.dart';
import 'package:autobus/features/onboarding/details2_page.dart';
import 'package:autobus/icons/figma_icons.dart';

/// Post-signup setup intro — Figma DETAILS (detail1) 402×874.
class DetailsPage extends StatelessWidget {
  final String userEmail;
  final String initialBusinessName;

  const DetailsPage({
    super.key,
    this.userEmail = '',
    this.initialBusinessName = '',
  });

  static const _designWidth = 402.0;
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _buttonColor = Color(0xFF2D0C51);
  void _onContinue(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        duration: const Duration(milliseconds: 800),
        reverseDuration: const Duration(milliseconds: 500),
        child: Details2Page(
          userEmail: userEmail,
          initialBusinessName: initialBusinessName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = size.width / _designWidth;
    final buttonWidth = 333 * scale;
    final buttonHeight = 64 * scale;
    final heroHeight = 280 * scale;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: Image.asset(
              'assets/img/landingtop.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: heroHeight - (24 * scale)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: FigmaSvgIcon(
                    FigmaIcons.ai,
                    size: 70 * scale,
                    color: const Color(0xFF7F03B9),
                  ),
                ),
                SizedBox(height: 10 * scale),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: Text(
                    'Answer a few questions so your chatbot can talk about '
                    'your business- even before you upload documents or a '
                    'website..',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Material(
                    color: _buttonColor,
                    borderRadius: BorderRadius.circular(30 * scale),
                    child: InkWell(
                      onTap: () => _onContinue(context),
                      borderRadius: BorderRadius.circular(30 * scale),
                      child: SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: Center(
                          child: Text(
                            'Let\u2019s go!',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 48 * scale),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
