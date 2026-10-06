import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_field.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/services.dart';

/// Shared tokens for Figma auth/onboarding screens (402px design width).
class AuthScreenTokens {
  AuthScreenTokens._();

  static const designWidth = 402.0;
  static const backgroundColor = Color(0xFFF3F3F7);
  static const buttonColor = Color(0xFF2D0C51);
  static const accentColor = Color(0xFF7F03B9);
  static const labelColor = Color(0xFF4E4E4E);
  static const emptyBorderColor = Color(0xFFDFDFDF);
  static const otpFillColor = Color(0xFFFAFAFA);

  /// Digit boxes from the auth PIN / code frame (51×78, 7px gap, radius 30).
  static const digitBoxWidth = 51.0;
  static const digitBoxHeight = 78.0;
  static const digitBoxGap = 7.0;
  static const digitBoxRadius = 30.0;

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  static double fieldWidth(double scale) => 333 * scale;
  static double fieldHeight(double scale) => 56 * scale;
  static double buttonHeight(double scale) => 64 * scale;
}

class AuthScreenScaffold extends StatelessWidget {
  final Widget child;

  const AuthScreenScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthScreenTokens.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: child),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AuthBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onTap ?? () => Navigator.of(context).maybePop(),
        icon: FigmaSvgIcon(
          FigmaIcons.back,
          size: 20,
          color: Colors.black,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class AuthScreenHeader extends StatelessWidget {
  final double scale;
  final String title;
  final String? subtitle;

  const AuthScreenHeader({
    super.key,
    required this.scale,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AutobusBranding(
          wordmarkFontSize: 20,
          markCircleSize: 30,
          spacing: 12,
        ),
        SizedBox(height: 24 * scale),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 8 * scale),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AuthScreenTokens.labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  final double scale;
  final String label;

  const AuthFieldLabel({super.key, required this.scale, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: AuthScreenTokens.labelColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final double scale;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.scale,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = AuthScreenTokens.fieldWidth(scale);
    final height = AuthScreenTokens.buttonHeight(scale);

    return Center(
      child: Material(
        color: AuthScreenTokens.buttonColor,
        borderRadius: BorderRadius.circular(30 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22 * scale,
                      height: 22 * scale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthLinkText extends StatelessWidget {
  final double scale;
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthLinkText({
    super.key,
    required this.scale,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          prompt,
          style: GoogleFonts.poppins(
            color: AuthScreenTokens.labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 6 * scale),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: GoogleFonts.poppins(
              color: AuthScreenTokens.accentColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthOtpInput extends StatefulWidget {
  final double scale;
  final int length;
  final bool enabled;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const AuthOtpInput({
    super.key,
    required this.scale,
    this.length = 6,
    this.enabled = true,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<AuthOtpInput> createState() => _AuthOtpInputState();
}

class _AuthOtpInputState extends State<AuthOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _notifyChanged() {
    widget.onChanged?.call(_code);
    if (_code.length == widget.length) {
      widget.onCompleted(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxWidth = AuthScreenTokens.digitBoxWidth * widget.scale;
    final boxHeight = AuthScreenTokens.digitBoxHeight * widget.scale;
    final gap = AuthScreenTokens.digitBoxGap * widget.scale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        final filled = _controllers[index].text.isNotEmpty;
        final borderColor = filled
            ? AuthScreenTokens.accentColor
            : AuthScreenTokens.emptyBorderColor;
        final boxBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AuthScreenTokens.digitBoxRadius * widget.scale,
          ),
          borderSide: BorderSide(color: borderColor, width: 1),
        );

        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : gap),
          child: SizedBox(
            width: boxWidth,
            height: boxHeight,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
                height: 1.0,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AuthScreenTokens.otpFillColor,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                enabledBorder: boxBorder,
                focusedBorder: boxBorder,
                disabledBorder: boxBorder,
              ),
              onChanged: (value) {
                setState(() {});
                if (value.isNotEmpty && index < widget.length - 1) {
                  _focusNodes[index + 1].requestFocus();
                } else if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                } else if (value.isEmpty) {
                  _focusNodes[index].requestFocus();
                }
                _notifyChanged();
              },
            ),
          ),
        );
      }),
    );
  }
}

/// Single 4-digit PIN inside an [AuthField].
class AuthPinField extends StatelessWidget {
  final double scale;
  final TextEditingController controller;
  final bool enabled;
  final String hintText;

  const AuthPinField({
    super.key,
    required this.scale,
    required this.controller,
    this.enabled = true,
    this.hintText = 'Enter a 4-digit pin',
  });

  @override
  Widget build(BuildContext context) {
    return AuthField(
      width: AuthScreenTokens.fieldWidth(scale),
      height: AuthScreenTokens.fieldHeight(scale),
      scale: scale,
      icon: Icons.lock_outline,
      controller: controller,
      enabled: enabled,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      hintText: hintText,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }
}
