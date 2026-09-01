import 'package:autobus/barrel.dart';

enum PinSetupMode { create, change, disable }

/// Create, change, or turn off the app PIN from Password & Security.
class SetupPinPage extends StatefulWidget {
  const SetupPinPage({super.key, required this.mode});

  final PinSetupMode mode;

  @override
  State<SetupPinPage> createState() => _SetupPinPageState();
}

class _SetupPinPageState extends State<SetupPinPage> {
  final GlobalKey<PinDigitInputState> _pinKey = GlobalKey<PinDigitInputState>();
  int _step = 0;
  String _current = '';
  String _first = '';
  String _pin = '';
  String? _localError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is Authenticated) {
        final key = PinLockService.userKeyFrom(auth.user);
        if (key != null && key.isNotEmpty) {
          context.read<PinLockCubit>().bindUser(key, freshLogin: false);
        }
      }
    });
  }

  String get _title {
    switch (widget.mode) {
      case PinSetupMode.create:
        return _step == 0 ? 'Create PIN' : 'Confirm PIN';
      case PinSetupMode.change:
        if (_step == 0) return 'Current PIN';
        if (_step == 1) return 'New PIN';
        return 'Confirm PIN';
      case PinSetupMode.disable:
        return 'Enter PIN';
    }
  }

  String get _subtitle {
    switch (widget.mode) {
      case PinSetupMode.create:
        return _step == 0
            ? 'Choose a 4-digit PIN. You will need it after 10 minutes away.'
            : 'Enter the same PIN again to confirm.';
      case PinSetupMode.change:
        if (_step == 0) return 'Enter your current app PIN.';
        if (_step == 1) return 'Choose a new 4-digit PIN.';
        return 'Enter the new PIN again to confirm.';
      case PinSetupMode.disable:
        return 'Enter your PIN to turn off app lock.';
    }
  }

  int get _lastStep {
    switch (widget.mode) {
      case PinSetupMode.create:
        return 1;
      case PinSetupMode.change:
        return 2;
      case PinSetupMode.disable:
        return 0;
    }
  }

  void _clearField() {
    _pinKey.currentState?.clear();
    setState(() {
      _pin = '';
    });
  }

  Future<void> _onCompleted(String pin) async {
    if (_submitting || context.read<PinLockCubit>().state.busy) return;
    setState(() => _localError = null);

    if (widget.mode == PinSetupMode.create) {
      if (_step == 0) {
        _first = pin;
        setState(() => _step = 1);
        _clearField();
        return;
      }
      if (pin != _first) {
        setState(() {
          _localError = 'PINs do not match';
          _step = 0;
          _first = '';
        });
        _clearField();
        return;
      }
      _submitting = true;
      final ok = await context.read<PinLockCubit>().enable(pin);
      if (!mounted) return;
      _submitting = false;
      if (ok) Navigator.pop(context, true);
      return;
    }

    if (widget.mode == PinSetupMode.change) {
      if (_step == 0) {
        _current = pin;
        setState(() => _step = 1);
        _clearField();
        return;
      }
      if (_step == 1) {
        _first = pin;
        setState(() => _step = 2);
        _clearField();
        return;
      }
      if (pin != _first) {
        setState(() {
          _localError = 'PINs do not match';
          _step = 1;
          _first = '';
        });
        _clearField();
        return;
      }
      _submitting = true;
      final ok = await context.read<PinLockCubit>().changePin(_current, pin);
      if (!mounted) return;
      _submitting = false;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _step = 0;
          _current = '';
          _first = '';
        });
        _clearField();
      }
      return;
    }

    _submitting = true;
    final ok = await context.read<PinLockCubit>().disable(pin);
    if (!mounted) return;
    _submitting = false;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _clearField();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<PinLockCubit, PinLockState>(
        builder: (context, state) {
          final busy = state.busy;
          final error = _localError ?? state.error;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthPageHeader(
                    title: _title,
                    onBack: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),
                  PinDigitInput(
                    key: _pinKey,
                    enabled: !busy,
                    autofocus: true,
                    onChanged: (v) => setState(() => _pin = v),
                    onCompleted: _onCompleted,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Center(
                    child: busy
                        ? const AutobusLoadingIndicator(size: 28)
                        : AppButton(
                            buttonText: _step == _lastStep
                                ? 'Continue'
                                : 'Next',
                            onPressed: _pin.length == 4
                                ? () => _onCompleted(_pin)
                                : null,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
