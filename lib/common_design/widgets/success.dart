import 'package:autobus/barrel.dart';

class Success extends StatefulWidget {
  const Success({super.key});

  @override
  State<Success> createState() => _SuccessState();
}

class _SuccessState extends State<Success> {
  static const _checkGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<SuccessBloc, SuccessState>(
        builder: (context, state) {
          String displayMessage = 'Account creation was successful!';
          String? nextScreen;
          var userEmail = '';

          if (state is SuccessDisplaying) {
            displayMessage = state.message;
            nextScreen = state.nextScreen;
            userEmail = state.userEmail;
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _checkGreen.withValues(alpha: 0.1),
                        border: Border.all(color: _checkGreen, width: 3),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _checkGreen,
                        size: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    displayMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(flex: 3),
                  CtaButton(
                    onPressed: () {
                      context.read<SuccessBloc>().add(ClearSuccessEvent());

                      if (nextScreen == 'login') {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) =>
                                Signin(initialIdentifier: userEmail),
                          ),
                          (route) => route.isFirst,
                        );
                      } else if (nextScreen == 'subscribe') {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) =>
                                BuyCreditsPage(userEmail: userEmail),
                          ),
                        );
                      } else if (nextScreen == 'onboarding') {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => BusinessOnboarding(
                              nextScreen: 'welcome',
                              userEmail: userEmail,
                            ),
                          ),
                        );
                      } else if (nextScreen == 'welcome') {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const Welcome(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
