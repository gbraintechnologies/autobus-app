import 'package:autobus/barrel.dart';
import 'package:flutter/services.dart';

class AuthField extends StatelessWidget {
  final double width;
  final double height;
  final double scale;
  final IconData icon;
  final TextEditingController? controller;
  final bool enabled;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final FocusNode? focusNode;
  final Widget? child;

  const AuthField({
    super.key,
    required this.width,
    required this.height,
    required this.scale,
    required this.icon,
    this.controller,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLength,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.hintText,
    this.focusNode,
    this.child,
  });

  static const _hintColor = Color(0xFFB7B0B0);
  static const _accentColor = Color(0xFF7F03B9);

  @override
  Widget build(BuildContext context) {
    const fontSize = 14.0;

    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30 * scale),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        child: Row(
          children: [
            Icon(icon, color: _accentColor, size: 20 * scale),
            SizedBox(width: 12 * scale),
            Expanded(
              child: child ??
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    textInputAction: textInputAction,
                    maxLength: maxLength,
                    inputFormatters: inputFormatters,
                    onSubmitted: onSubmitted,
                    onChanged: onChanged,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      counterText: '',
                      hintText: hintText,
                      hintStyle: GoogleFonts.poppins(
                        fontSize: fontSize,
                        color: _hintColor,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
