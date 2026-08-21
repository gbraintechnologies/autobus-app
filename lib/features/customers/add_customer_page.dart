import 'package:autobus/barrel.dart';

class AddCustomerPage extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AddCustomerPage({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _networkController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
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
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Customer updated' : 'Customer added',
            style: GoogleFonts.montserrat(),
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
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.montserrat(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.montserrat(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3F1163)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFA855F7), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit customer' : 'Add customer';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ManageScreenBackButton(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          title,
                          style: ManageScreenStyle.headerTitleStyle(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            onTapOutside: dismissAppKeyboard,
                            style: GoogleFonts.montserrat(color: Colors.white),
                            cursorColor: const Color(0xFFA855F7),
                            decoration: _fieldDecoration('Name'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            onTapOutside: dismissAppKeyboard,
                            style: GoogleFonts.montserrat(color: Colors.white),
                            cursorColor: const Color(0xFFA855F7),
                            decoration: _fieldDecoration(
                              'Phone number',
                              hint: 'e.g. 0550748724',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            onTapOutside: dismissAppKeyboard,
                            style: GoogleFonts.montserrat(color: Colors.white),
                            cursorColor: const Color(0xFFA855F7),
                            decoration: _fieldDecoration(
                              'Email (optional)',
                              hint: 'For email messages',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _networkController,
                            onTapOutside: dismissAppKeyboard,
                            style: GoogleFonts.montserrat(color: Colors.white),
                            cursorColor: const Color(0xFFA855F7),
                            decoration: _fieldDecoration(
                              'Network (optional)',
                              hint: 'Auto-detected if left blank',
                            ),
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: AppButton(
                              buttonText: _saving
                                  ? 'Saving…'
                                  : (widget.isEditing
                                        ? 'Save changes'
                                        : 'Add customer'),
                              onPressed: _saving ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
