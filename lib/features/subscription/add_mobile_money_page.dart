import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_snackbar.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mobile money details — Figma [Add payment method](`3548:1543`).
class AddMobileMoneyPage extends StatefulWidget {
  const AddMobileMoneyPage({super.key});

  @override
  State<AddMobileMoneyPage> createState() => _AddMobileMoneyPageState();
}

class _AddMobileMoneyPageState extends State<AddMobileMoneyPage> {
  static const _fieldFill = Color(0xFFFAFAFA);
  static const _hintColor = Color(0xFFB7B0B0);

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _onAdd() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, 'Please enter the account name.');
      return;
    }
    if (phone.isEmpty) {
      showAppSnackBar(context, 'Please enter the phone number.');
      return;
    }
    showAppSnackBar(
      context,
      'Mobile money method added.',
      backgroundColor: LightScreenTheme.button,
    );
    // Leave form + type picker; list has no persistence API yet.
    final nav = Navigator.of(context);
    nav.pop();
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final fieldWidth = AuthScreenTokens.fieldWidth(scale);
    final fieldHeight = AuthScreenTokens.fieldHeight(scale);

    return LightScreenScaffold(
      title: 'Add payment method',
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          35 * scale,
          20 * scale,
          35 * scale,
          24 * scale,
        ),
        children: [
          AuthFieldLabel(scale: scale, label: 'Name'),
          SizedBox(height: 8 * scale),
          _PillTextField(
            width: fieldWidth,
            height: fieldHeight,
            scale: scale,
            controller: _nameController,
            hintText: 'Enter name of account',
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _phoneFocus.requestFocus(),
            fillColor: _fieldFill,
            hintColor: _hintColor,
          ),
          SizedBox(height: 10 * scale),
          AuthFieldLabel(scale: scale, label: 'Phone number'),
          SizedBox(height: 8 * scale),
          _PillTextField(
            width: fieldWidth,
            height: fieldHeight,
            scale: scale,
            controller: _phoneController,
            focusNode: _phoneFocus,
            hintText: 'Enter account number',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _onAdd(),
            fillColor: _fieldFill,
            hintColor: _hintColor,
          ),
          SizedBox(height: 92 * scale),
          AuthPrimaryButton(
            scale: scale,
            label: 'Add',
            onPressed: _onAdd,
          ),
        ],
      ),
    );
  }
}

class _PillTextField extends StatelessWidget {
  final double width;
  final double height;
  final double scale;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Color fillColor;
  final Color hintColor;

  const _PillTextField({
    required this.width,
    required this.height,
    required this.scale,
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.textInputAction,
    required this.fillColor,
    required this.hintColor,
    this.focusNode,
    this.inputFormatters,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(30 * scale),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        style: GoogleFonts.poppins(
          fontSize: LightScreenTheme.typeBody,
          color: Colors.black87,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            fontSize: LightScreenTheme.typeBody,
            color: hintColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
