import 'package:autobus/barrel.dart';
import 'package:flutter/services.dart';

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
  final List<TextEditingController> _newPinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _newPinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );

  final List<TextEditingController> _confirmPinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _confirmPinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );

  String get _newPin => _newPinControllers.map((c) => c.text).join();
  String get _confirmPin => _confirmPinControllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _newPinControllers) {
      c.dispose();
    }
    for (final n in _newPinFocusNodes) {
      n.dispose();
    }
    for (final c in _confirmPinControllers) {
      c.dispose();
    }
    for (final n in _confirmPinFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Widget _buildPinInput({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        return SizedBox(
          width: 52,
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onChanged: (val) {
              if (val.isNotEmpty) {
                if (index < 3) {
                  focusNodes[index + 1].requestFocus();
                } else {
                  focusNodes[index].unfocus();
                }
              } else if (val.isEmpty && index > 0) {
                focusNodes[index - 1].requestFocus();
              }
            },
            onTap: () {
              controllers[index].selection = TextSelection.collapsed(
                offset: controllers[index].text.length,
              );
            },
            onSubmitted: (_) {
              if (index < 3) focusNodes[index + 1].requestFocus();
            },
            onEditingComplete: () {},
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordResetSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const Signin()),
            (route) => false,
          );
        } else if (state is AuthError && state.source == 'reset_password') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Reset Password',
                          style: GoogleFonts.montserrat(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              color: CustColors.mainCol,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: CustColors.mainCol,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 50 * 0.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Center(
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.asset('assets/img/bot.png'),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Padding(
                    padding: EdgeInsets.only(left: 20.0, right: 20.0),
                    child: Text(
                      'New PIN',
                      style: GoogleFonts.montserrat(
                        color: const Color.fromARGB(255, 12, 12, 12),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: _buildPinInput(
                      controllers: _newPinControllers,
                      focusNodes: _newPinFocusNodes,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.only(left: 20.0, right: 20.0),
                    child: Text(
                      'Confirm PIN',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: _buildPinInput(
                      controllers: _confirmPinControllers,
                      focusNodes: _confirmPinFocusNodes,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: Text(
                      'Enter a 4-digit PIN',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Center(
                    child: AppButton(
                      onPressed: () {
                        if (_newPin.length != 4 || _confirmPin.length != 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please enter and confirm your 4-digit PIN',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (_newPin != _confirmPin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PINs do not match'),
                              backgroundColor: Colors.red,
                            ),
                          );
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
                      },
                      buttonText: 'Reset Password',
                    ),
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
