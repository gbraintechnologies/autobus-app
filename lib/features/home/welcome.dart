import 'package:autobus/barrel.dart';
import 'package:autobus/features/onboarding/onboarding_storage.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  void initState() {
    super.initState();
    print('=== WELCOME SCREEN INITIATED ===');
  }

  @override
  Widget build(BuildContext context) {
    print('=== WELCOME SCREEN BUILDING ===');
    return Scaffold(
      body: _GradientBackground(
        child: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final topGap = screenWidth * 0.1;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: topGap),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Operate Business',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w100,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'With Ai!',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 92,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: topGap),
                            Center(
                              child: SizedBox(
                                width: 220,
                                height: 220,
                                child: Image.asset(
                                  'assets/img/welcomeai.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Center(
                              child: TransparentCtaButton(
                                label: 'Get Started',
                                onPressed: () async {
                                  print('=== GET STARTED BUTTON PRESSED ===');
                                  final authState =
                                      context.read<AuthBloc>().state;
                                  final user = authState is Authenticated
                                      ? authState.user
                                      : null;
                                  if (user is Map) {
                                    final userMap = user is Map<String, dynamic>
                                        ? user
                                        : Map<String, dynamic>.from(user);
                                    await OnboardingStorage()
                                        .markWelcomeCompleted(
                                          OnboardingStorage.userKeyFromMap(
                                            userMap,
                                          ),
                                        );
                                  }
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushReplacement(
                                    Home.routeFromWelcome(),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  final Widget child;
  const _GradientBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF130522), Color(0xFF2D0C51), Color(0xFF130522)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
