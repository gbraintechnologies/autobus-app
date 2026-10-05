import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

class AddCustomerPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? prefill;
  final String? linkOrderId;

  const AddCustomerPage({
    super.key,
    this.existing,
    this.prefill,
    this.linkOrderId,
  });

  bool get isEditing => existing != null;

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  static const _fieldFill = Color(0xFFFAFAFA);
  static const _labelColor = Color(0xFF4E4E4E);
  static const _hintColor = Color(0xFFB7B0B0);
  static const _iconColor = Color(0xFF7F03B9);
  static const _buttonColor = Color(0xFF2D0C51);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _networkController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing ?? widget.prefill;
    _nameController = TextEditingController(text: (c?['name'] ?? '').toString());
    _phoneController = TextEditingController(
      text: (c?['customer_number'] ?? '').toString(),
    );
    _emailController = TextEditingController(text: (c?['email'] ?? '').toString());
    _networkController = TextEditingController(
      text: (c?['network'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  int? get _customerId {
    final raw = widget.existing?['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final name = _nameController.text;
      final phone = _phoneController.text;
      final email = _emailController.text.trim();
      final network = _networkController.text.trim();

      if (widget.isEditing && _customerId != null) {
        await api.updateCustomer(
          _customerId!,
          name: name,
          customerNumber: phone,
          email: email.isEmpty ? null : email,
          network: network.isEmpty ? null : network,
        );
      } else {
        await api.addCustomer(
          name: name,
          customerNumber: phone,
          email: email.isEmpty ? null : email,
          network: network.isEmpty ? null : network,
        );
        final orderId = widget.linkOrderId?.trim();
        if (orderId != null && orderId.isNotEmpty) {
          try {
            await api.saveCustomerFromOrder(orderId);
          } catch (_) {
            // Customer was saved; linking the order is best-effort.
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Customer updated' : 'Customer added',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final title = widget.isEditing ? 'Edit Customer' : 'Add Customer';
    final buttonLabel = _saving
        ? 'Saving…'
        : (widget.isEditing ? 'Save changes' : 'Add customer');

    return LightScreenScaffold(
      title: title,
      titleFontSize: 16,
      creditCategory: CreditCategory.server,
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(35 * scale, 20 * scale, 35 * scale, 32 * scale),
          children: [
            _LabeledPillField(
              scale: scale,
              label: 'Name',
              hintText: 'Enter your full name',
              icon: SFIcons.sf_person_fill,
              controller: _nameController,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: 10 * scale),
            _LabeledPillField(
              scale: scale,
              label: 'Phone',
              hintText: '0244123456',
              icon: SFIcons.sf_phone_fill,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: 10 * scale),
            _LabeledPillField(
              scale: scale,
              label: 'Email(Optional)',
              hintText: 'johndoe@example.com',
              icon: SFIcons.sf_envelope_fill,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 10 * scale),
            _LabeledPillField(
              scale: scale,
              label: 'Network(Optional)',
              controller: _networkController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_saving) _save();
              },
            ),
            SizedBox(height: 40 * scale),
            Material(
              color: _buttonColor,
              borderRadius: BorderRadius.circular(30 * scale),
              child: InkWell(
                onTap: _saving ? null : _save,
                borderRadius: BorderRadius.circular(30 * scale),
                child: SizedBox(
                  height: 64 * scale,
                  child: Center(
                    child: Text(
                      buttonLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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

class _LabeledPillField extends StatelessWidget {
  final double scale;
  final String label;
  final String? hintText;
  final IconData? icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _LabeledPillField({
    required this.scale,
    required this.label,
    this.hintText,
    this.icon,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = 14 * scale.clamp(0.9, 1.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _AddCustomerPageState._labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 8 * scale),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: fontSize,
          ),
          cursorColor: LightScreenTheme.accent,
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              color: _AddCustomerPageState._hintColor,
              fontSize: fontSize,
            ),
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(left: 16 * scale, right: 8 * scale),
                    child: HomeSfIcon(
                      icon: icon!,
                      size: 20 * scale,
                      color: _AddCustomerPageState._iconColor,
                    ),
                  ),
            prefixIconConstraints: icon == null
                ? null
                : BoxConstraints(
                    minWidth: 44 * scale,
                    minHeight: 20 * scale,
                  ),
            filled: true,
            fillColor: _AddCustomerPageState._fieldFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 18 * scale,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30 * scale),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30 * scale),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30 * scale),
              borderSide: BorderSide(
                color: LightScreenTheme.accent,
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30 * scale),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30 * scale),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
