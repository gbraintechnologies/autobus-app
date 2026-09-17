import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';

class ResetPassword extends StatefulWidget {
  final String email;
  final String phone;
  final String code;

  const ResetPassword({
    super.key,
    this.email = '',
    this.phone = '',
    required this.code,
  });

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  String _newPin = '';
  String _confirmPin = '';

  void _submit() {
    if (_newPin.length != 4 || _confirmPin.length != 4) {
      showAppSnackBar(
        context,
        'Please enter and confirm your 4-digit PIN',
      );
      return;
    }

    if (_newPin != _confirmPin) {
      showAppSnackBar(context, 'PINs do not match');
      return;
    }

    context.read<AuthBloc>().add(
      ResetPasswordEvent(
        email: widget.email,
        phone: widget.phone,
        code: widget.code,
        newPassword: _newPin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AuthScreenTokens.scaleOf(context);

    return AuthScreenScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is PasswordResetSuccess) {
            showAppSnackBar(context, state.message);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const Signin()),
              (route) => false,
            );
          } else if (state is AuthError && state.source == 'reset_password') {
            showAppSnackBar(
              context,
              userFacingError(state.message, action: 'resetting password'),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24 * scale,
                8 * scale,
                24 * scale,
                24 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBackButton(),
                  SizedBox(height: 12 * scale),
                  AuthScreenHeader(
                    scale: scale,
                    title: 'New Pin',
                    subtitle: 'Enter your new pin',
                  ),
                  SizedBox(height: 32 * scale),
                  AuthFieldLabel(scale: scale, label: 'New Pin'),
                  SizedBox(height: 8 * scale),
                  PinDigitInput(
                    enabled: !isLoading,
                    onChanged: (v) => _newPin = v,
                  ),
                  SizedBox(height: 16 * scale),
                  AuthFieldLabel(scale: scale, label: 'Confirm Pin'),
                  SizedBox(height: 8 * scale),
                  PinDigitInput(
                    enabled: !isLoading,
                    onChanged: (v) => _confirmPin = v,
                  ),
                  SizedBox(height: 32 * scale),
                  AuthPrimaryButton(
                    scale: scale,
                    label: 'Confirm',
                    loading: isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
