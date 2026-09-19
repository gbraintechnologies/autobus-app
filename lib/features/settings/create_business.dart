import 'package:autobus/barrel.dart';

class CreateBusinessPage extends StatefulWidget {
  const CreateBusinessPage({super.key});

  @override
  State<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends State<CreateBusinessPage> {
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final companyController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    companyController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a unique email for this business'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a unique username for this business'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    context.read<AuthBloc>().add(
      CreateBusinessEvent(
        email: email,
        username: username,
        company: companyController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated && state.lastBusinessOp == 'created') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Business created. Switch to it from the list.'),
            ),
          );
          Navigator.of(context).pop();
        } else if (state is AuthError && state.source == 'create_business') {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingError(state.message, action: 'creating business')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: dismissAppKeyboard,
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthPageHeader(
                    title: 'Add business',
                    fontWeight: FontWeight.w300,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'This business gets its own email. You can switch to it from this login until you detach it with a password reset.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _label('Business email*'),
                  TextField(
                    onTapOutside: dismissAppKeyboard,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'business@example.com',
                      hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 14),
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('Username*'),
                  TextField(
                    onTapOutside: dismissAppKeyboard,
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Unique username',
                      hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 14),
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('Company name'),
                  TextField(
                    onTapOutside: dismissAppKeyboard,
                    controller: companyController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => dismissAppKeyboard(),
                    decoration: InputDecoration(
                      hintText: 'Optional display name',
                      hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 14),
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: _submitting
                        ? const AutobusLoadingIndicator()
                        : AppButton(
                            buttonText: 'Create business',
                            onPressed: _submit,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
