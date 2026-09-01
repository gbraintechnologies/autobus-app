import 'package:autobus/barrel.dart';

/// Full-screen overlay shown when the session is still valid but the app PIN
/// is required after 10 minutes away.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final GlobalKey<PinDigitInputState> _pinKey = GlobalKey<PinDigitInputState>();
  String _pin = '';
  bool _submitting = false;

  Future<void> _submit(String pin) async {
    if (_submitting) return;
    final cubit = context.read<PinLockCubit>();
    if (cubit.state.busy) return;
    _submitting = true;
    final ok = await cubit.unlock(pin);
    _submitting = false;
    if (!mounted) return;
    if (!ok) {
      _pinKey.currentState?.clear();
      setState(() => _pin = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BlocBuilder<PinLockCubit, PinLockState>(
          builder: (context, state) {
            final busy = state.busy;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
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
                      'Enter PIN',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have been away for over 10 minutes.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 36),
                    PinDigitInput(
                      key: _pinKey,
                      enabled: !busy,
                      autofocus: true,
                      onChanged: (v) => setState(() => _pin = v),
                      onCompleted: _submit,
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.error!,
                        style: GoogleFonts.montserrat(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (busy)
                      const AutobusLoadingIndicator(size: 28)
                    else
                      AppButton(
                        buttonText: 'Unlock',
                        onPressed: _pin.length == 4
                            ? () => _submit(_pin)
                            : null,
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => context.read<AuthBloc>().add(LogoutEvent()),
                      child: Text(
                        'Log out',
                        style: GoogleFonts.montserrat(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
