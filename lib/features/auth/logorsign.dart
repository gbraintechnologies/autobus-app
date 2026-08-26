import 'package:autobus/barrel.dart';

class LogorSign extends StatelessWidget {
  const LogorSign({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
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
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
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
                ),
                const _BottomPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const panelColor = Color(0xFF2A1447);
    final minPanelH = (size.height * 0.38).clamp(260.0, 400.0);

    TextStyle tStyle({double size = 14, FontWeight weight = FontWeight.w400}) {
      return GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: weight,
        color: Colors.white,
      );
    }

    Widget authLink({
      required String label,
      required VoidCallback onPressed,
    }) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AppFitText(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w200,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minPanelH),
      color: panelColor,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The power of Ai in your pocket',
                style: tStyle(size: 32, weight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                'Agentic business management',
                style: tStyle(size: 16, weight: FontWeight.w400),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: authLink(
                  label: 'Log In',
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
                ),
              ),
              Container(height: 40, width: 1.5, color: Colors.white),
              Expanded(
                child: authLink(
                  label: 'Sign Up',
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
