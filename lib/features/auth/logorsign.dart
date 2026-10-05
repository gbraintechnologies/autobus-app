import 'package:autobus/barrel.dart';

class LogorSign extends StatelessWidget {
  const LogorSign({super.key});

  void _openSignin(BuildContext context) {
    Navigator.of(context).push(
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        childCurrent: const Signin(),
        duration: const Duration(milliseconds: 350),
        reverseDuration: const Duration(milliseconds: 300),
        child: const Signin(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingPage(onFinished: () => _openSignin(context));
  }
}
