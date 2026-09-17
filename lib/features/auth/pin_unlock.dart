import 'package:autobus/barrel.dart';

/// PIN-only unlock for a user who already signed in on this device.
class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({
    super.key,
    required this.identifier,
    this.displayName = '',
    this.onUseAnotherAccount,
  });

  final String identifier;
  final String displayName;
  final VoidCallback? onUseAnotherAccount;

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  final _pinKey = GlobalKey<PinDigitInputState>();
  String _pin = '';

  String get _greeting {
    final name = widget.displayName.trim();
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
    final id = widget.identifier.trim();
    if (id.contains('@')) return id.split('@').first;
    return id;
  }

  void _submit() {
    if (_pin.length != 4) return;
    context.read<AuthBloc>().add(
      LoginEvent(identifier: widget.identifier.trim(), password: _pin),
    );
  }

  Future<void> _useAnotherAccount() async {
    await LastLoginStore.clear();
    if (!mounted) return;
    if (widget.onUseAnotherAccount != null) {
      widget.onUseAnotherAccount!();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LogorSign()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
          } else if (state is AuthError && state.source == 'login') {
            _pinKey.currentState?.clear();
            _pin = '';
            showAppSnackBar(
              context,
              userFacingError(state.message, action: 'signing in'),
            );
          }
        },
        builder: (context, state) {
          final bool isLoading = state is AuthLoading;
          return SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AutobusBranding(
                          wordmarkFontSize: 26,
                          markCircleSize: 34,
                          spacing: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _greeting,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.identifier.trim().toLowerCase() !=
                        _greeting.trim().toLowerCase())
                      Text(
                        widget.identifier,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.black45,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    const SizedBox(height: 36),
                    Text(
                      'Enter your PIN',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PinDigitInput(
                      key: _pinKey,
                      enabled: !isLoading,
                      autofocus: true,
                      onChanged: (v) => _pin = v,
                      onCompleted: (_) => _submit(),
                    ),
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            PageTransition(
                              type: PageTransitionType.rightToLeftWithFade,
                              child: const RecoverAccount(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot PIN?',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: AppButton(
                        onPressed: isLoading ? null : _submit,
                        buttonText: isLoading ? 'Unlocking…' : 'Unlock',
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: GestureDetector(
                        onTap: isLoading ? null : _useAnotherAccount,
                        child: Text(
                          'Not you? Sign in with another account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: CustColors.mainCol,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
