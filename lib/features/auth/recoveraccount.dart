import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_field.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';

class RecoverAccount extends StatefulWidget {
  const RecoverAccount({super.key});

  @override
  State<RecoverAccount> createState() => _RecoverAccountState();
}

class _RecoverAccountState extends State<RecoverAccount> {
  final _identifierController = TextEditingController();

  bool _looksLikeEmail(String value) => value.contains('@');

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _continue() {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      showAppSnackBar(context, 'Please enter your email or phone number');
      return;
    }

    if (_looksLikeEmail(identifier)) {
      context.read<AuthBloc>().add(CheckEmailExistsEvent(email: identifier));
    } else {
      context.read<AuthBloc>().add(CheckEmailExistsEvent(phone: identifier));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = AuthScreenTokens.scaleOf(context);
    final fieldWidth = AuthScreenTokens.fieldWidth(scale);
    final fieldHeight = AuthScreenTokens.fieldHeight(scale);

    return AuthScreenScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is EmailExists) {
            context.read<AuthBloc>().add(
              SendResetCodeEvent(email: state.email, phone: state.phone),
            );
          } else if (state is ResetCodeSent) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerifyCode(
                  email: state.email,
                  phone: state.phone,
                ),
              ),
            );
          } else if (state is AuthError &&
              (state.source == 'check_email' ||
                  state.source == 'send_reset_code')) {
            showAppSnackBar(
              context,
              userFacingError(state.message, action: 'finding account'),
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
                    title: 'Reset Pin',
                    subtitle: 'Enter your email or phone number',
                  ),
                  SizedBox(height: 32 * scale),
                  AuthFieldLabel(scale: scale, label: 'Email or phone'),
                  SizedBox(height: 8 * scale),
                  AuthField(
                    width: fieldWidth,
                    height: fieldHeight,
                    scale: scale,
                    icon: Icons.person_outline,
                    controller: _identifierController,
                    enabled: !isLoading,
                    hintText: 'name@example.com or phone number',
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _continue(),
                  ),
                  SizedBox(height: 32 * scale),
                  AuthPrimaryButton(
                    scale: scale,
                    label: 'Continue',
                    loading: isLoading,
                    onPressed: _continue,
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
