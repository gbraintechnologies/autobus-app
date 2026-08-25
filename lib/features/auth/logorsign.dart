import 'package:autobus/barrel.dart';

class LogorSign extends StatelessWidget {
  const LogorSign({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;

    // Figma: 428x926
    const figmaH = 926.0;
    final brandingTop = h * (148 / figmaH);
    final bottomPanelH = h * (420 / figmaH);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/img/splash.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(0, 0, 0, 0.8),
                Color.fromRGBO(0, 0, 0, 0.25),
              ],
              stops: [0.24251044, 1],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: brandingTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        AutobusMark(),
                        SizedBox(width: 9),
                        AutobusWordmark(baseColor: Colors.white),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bottomPanelH,
                  child: _BottomPanel(height: bottomPanelH),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Figma bottom panel size: 428x420
    const figmaPanelH = 420.0;
    final s = height / figmaPanelH;

    const panelColor = Color(0xFF2A1447);

    TextStyle tStyle({double size = 14, FontWeight weight = FontWeight.w400}) {
      return GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: weight,
        color: Colors.white,
      );
    }

    return Container(
      width: double.infinity,
      color: panelColor,
      child: Stack(
        children: [
          Positioned(
            left: 26 * s,
            top: 23 * s,
            right: 26 * s,
            child: Text(
              'The power of Ai in your pocket',
              style: tStyle(size: 32, weight: FontWeight.w600),
            ),
          ),
          Positioned(
            left: 26 * s,
            top: 131 * s,
            right: 26 * s,
            child: Text(
              'Agentic business management',
              style: tStyle(size: 16, weight: FontWeight.w400),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 218 * s,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: size.width * 0.25,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          PageTransition(
                            type: PageTransitionType.rightToLeftWithFade,
                            childCurrent: const Signin(),
                            duration: const Duration(milliseconds: 350),
                            reverseDuration: const Duration(milliseconds: 300),
                            child: const Signin(),
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          'Log In',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(height: 40, width: 1.5, color: Colors.white),
                  SizedBox(
                    width: size.width * 0.25,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          PageTransition(
                            type: PageTransitionType.rightToLeftWithFade,
                            childCurrent: const Signup(),
                            duration: const Duration(milliseconds: 350),
                            reverseDuration: const Duration(milliseconds: 300),
                            child: const Signup(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
