import 'package:autobus/barrel.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _userProfileRaw;

  // User profile
  final TextEditingController fullnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ghanaCardController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController staffIdController = TextEditingController();

  // Business profile
  final TextEditingController companyController = TextEditingController();
  final TextEditingController currentBranchController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController facebookUrlController = TextEditingController();
  final TextEditingController whatsappNumberController =
      TextEditingController();
  final TextEditingController linkedinUrlController = TextEditingController();
  final TextEditingController twitterUrlController = TextEditingController();
  final TextEditingController instagramUrlController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _gender;
  String? _profilePictureUrl;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  late final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _apiService.getUserProfile();
      if (!mounted) return;

      _userProfileRaw = Map<String, dynamic>.from(user as Map);

      fullnameController.text = (user['fullname'] ?? user['name'] ?? '')
          .toString();
      phoneController.text = (user['phone'] ?? '').toString();
      emailController.text = (user['email'] ?? '').toString();

      ghanaCardController.text = (user['ghana_card'] ?? '').toString();
      nationalityController.text = (user['nationality'] ?? '').toString();
      staffIdController.text = (user['staff_id'] ?? '').toString();

      companyController.text = (user['company'] ?? '').toString();
      currentBranchController.text = (user['current_branch'] ?? '').toString();
      addressController.text = (user['address'] ?? '').toString();
      locationController.text = (user['location'] ?? '').toString();

      facebookUrlController.text = (user['facebook_url'] ?? '').toString();
      whatsappNumberController.text = (user['whatsapp_number'] ?? '')
          .toString();
      linkedinUrlController.text = (user['linkedin_url'] ?? '').toString();
      twitterUrlController.text = (user['twitter_url'] ?? '').toString();
      instagramUrlController.text = (user['instagram_url'] ?? '').toString();

      _profilePictureUrl = (user['profile_picture_url'] ?? '').toString();
      if (_profilePictureUrl?.trim().isEmpty == true) _profilePictureUrl = null;

      final dob = (user['date_of_birth'] ?? '').toString();
      _dateOfBirth = _tryParseDate(dob);
      dobController.text = _dateOfBirth == null
          ? ''
          : _formatDate(_dateOfBirth!);

      _gender = _normalizeGender(user['gender']);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isPresent(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  ({int completed, int total, int percent, List<String> missingLabels})
  _profileCompletion() {
    // If the backend returns a different set of keys, tweak this list only.
    final fields = <({String label, dynamic value})>[
      (
        label: 'Full name',
        value: _userProfileRaw?['fullname'] ?? _userProfileRaw?['name'],
      ),
      (label: 'Phone', value: _userProfileRaw?['phone']),
      (label: 'Ghana card', value: _userProfileRaw?['ghana_card']),
      (label: 'Nationality', value: _userProfileRaw?['nationality']),
      (label: 'Date of birth', value: _userProfileRaw?['date_of_birth']),
      (label: 'Gender', value: _userProfileRaw?['gender']),
      (label: 'Staff ID', value: _userProfileRaw?['staff_id']),
      (label: 'Company', value: _userProfileRaw?['company']),
      (label: 'Current branch', value: _userProfileRaw?['current_branch']),
      (label: 'Address', value: _userProfileRaw?['address']),
      (label: 'Location', value: _userProfileRaw?['location']),
      (label: 'WhatsApp number', value: _userProfileRaw?['whatsapp_number']),
      (label: 'Facebook URL', value: _userProfileRaw?['facebook_url']),
      (label: 'LinkedIn URL', value: _userProfileRaw?['linkedin_url']),
      (label: 'Twitter/X URL', value: _userProfileRaw?['twitter_url']),
      (label: 'Instagram URL', value: _userProfileRaw?['instagram_url']),
      (label: 'Profile photo', value: _userProfileRaw?['profile_picture_url']),
    ];

    final total = fields.length;
    var completed = 0;
    final missing = <String>[];
    for (final f in fields) {
      if (_isPresent(f.value)) {
        completed += 1;
      } else {
        missing.add(f.label);
      }
    }

    final percent = total == 0 ? 0 : ((completed / total) * 100).round();
    return (
      completed: completed,
      total: total,
      percent: percent.clamp(0, 100),
      missingLabels: missing,
    );
  }

  Widget _profileCompletionCard() {
    final info = _profileCompletion();
    final pct = info.percent;
    final progress = info.total == 0 ? 0.0 : info.completed / info.total;

    final missingTop = info.missingLabels.take(3).toList();
    final missingExtra = info.missingLabels.length - missingTop.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, size: 18, color: CustColors.mainCol),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profile completion',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CustColors.mainCol,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(CustColors.mainCol),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${info.completed} of ${info.total} fields completed',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),
          if (missingTop.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in missingTop)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CustColors.mainCol.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      m,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: CustColors.mainCol,
                      ),
                    ),
                  ),
                if (missingExtra > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+$missingExtra more',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _normalizeGender(dynamic raw) {
    final g = (raw ?? '').toString().trim();
    if (g.isEmpty) return null;
    switch (g.toLowerCase()) {
      case 'm':
      case 'male':
        return 'Male';
      case 'f':
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer not to say':
      case 'prefer_not_to_say':
      case 'unspecified':
        return 'Prefer not to say';
      default:
        return null;
    }
  }

  String? _emptyToSentinel(String value) {
    final t = value.trim();
    return t;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _apiService.updateUserProfile(
        fullname: fullnameController.text.trim(),
        phone: _emptyToSentinel(phoneController.text),
        ghanaCard: _emptyToSentinel(ghanaCardController.text),
        nationality: _emptyToSentinel(nationalityController.text),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        staffId: _emptyToSentinel(staffIdController.text),
        company: _emptyToSentinel(companyController.text),
        currentBranch: _emptyToSentinel(currentBranchController.text),
        address: _emptyToSentinel(addressController.text),
        location: _emptyToSentinel(locationController.text),
        facebookUrl: _emptyToSentinel(facebookUrlController.text),
        whatsappNumber: _emptyToSentinel(whatsappNumberController.text),
        linkedinUrl: _emptyToSentinel(linkedinUrlController.text),
        twitterUrl: _emptyToSentinel(twitterUrlController.text),
        instagramUrl: _emptyToSentinel(instagramUrlController.text),
      );
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updated));
      } catch (_) {}
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Profile updated',
        backgroundColor: const Color(0xFF22C55E),
      );
      setState(() => _loading = true);
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFacingError(e, action: 'saving profile'));
      showAppSnackBar(
        context,
        userFacingError(e, action: 'saving profile'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) return;

    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1400,
      requestFullMetadata: false,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await _apiService.uploadFile(
        file: File(picked.path),
        filename: picked.name,
      );

      await _apiService.patchMyProfileImage(profilePictureUrl: url);
      // Keep local cached user in sync (used by AuthBloc on next session check)
      try {
        final updated = await _apiService.getUserProfile();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updated));
      } catch (_) {}
      if (!mounted) return;

      setState(() => _profilePictureUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  DateTime? _tryParseDate(String input) {
    final v = input.trim();
    if (v.isEmpty) return null;
    try {
      // Handles "YYYY-MM-DD" and iso strings
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      dobController.text = _formatDate(picked);
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    fullnameController.dispose();
    ghanaCardController.dispose();
    nationalityController.dispose();
    dobController.dispose();
    staffIdController.dispose();

    companyController.dispose();
    currentBranchController.dispose();
    addressController.dispose();
    locationController.dispose();
    facebookUrlController.dispose();
    whatsappNumberController.dispose();
    linkedinUrlController.dispose();
    twitterUrlController.dispose();
    instagramUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ProfileBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                const SizedBox(height: 20),

                /// 🔝 Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    /// Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CustColors.mainCol,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                    Text(
                      'Profile',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: _circleIcon(Icons.share_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (_loading)
                  const Expanded(
                    child: Center(child: AutobusLoadingIndicator()),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: Column(
                                  children: [
                                    _profileHeaderCard(context),
                                    const SizedBox(height: 12),
                                    _profileCompletionCard(),
                                    const SizedBox(height: 14),
                                    _sectionCard(
                                      title: 'User Profile',
                                      subtitle:
                                          'Personal information and account details',
                                      child: Column(
                                        children: [
                                          _input(
                                            label: 'Full name',
                                            controller: fullnameController,
                                            hintText: 'Enter your full name',
                                            textInputAction:
                                                TextInputAction.next,
                                            validator: (v) {
                                              if ((v ?? '').trim().isEmpty) {
                                                return 'Full name is required';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Email',
                                            controller: emailController,
                                            readOnly: true,
                                            helperText:
                                                'Email can’t be changed here',
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Phone',
                                            controller: phoneController,
                                            hintText: '0241234567',
                                            keyboardType: TextInputType.phone,
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Ghana card',
                                            controller: ghanaCardController,
                                            hintText: 'GHA-XXXXXXXXXX-X',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Nationality',
                                            controller: nationalityController,
                                            hintText: 'e.g. Ghanaian',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Date of birth',
                                            controller: dobController,
                                            hintText: 'Tap to select (DD/MM/YYYY)',
                                            readOnly: true,
                                            onTap: _pickDateOfBirth,
                                            suffixIcon: Icons.calendar_today,
                                          ),
                                          const SizedBox(height: 20),
                                          _genderDropdown(),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Staff ID',
                                            controller: staffIdController,
                                            hintText: 'Enter your staff ID',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _sectionCard(
                                      title: 'Business Profile',
                                      subtitle:
                                          'Company details and social profiles',
                                      child: Column(
                                        children: [
                                          _input(
                                            label: 'Company',
                                            controller: companyController,
                                            hintText: 'Enter company name',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Current branch',
                                            controller: currentBranchController,
                                            hintText: 'Enter branch name',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Address',
                                            controller: addressController,
                                            hintText: 'Enter street address',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Location',
                                            controller: locationController,
                                            hintText: 'Enter city or region',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'WhatsApp number',
                                            controller:
                                                whatsappNumberController,
                                            hintText: '0241234567',
                                            keyboardType: TextInputType.phone,
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Facebook URL',
                                            controller: facebookUrlController,
                                            hintText: 'https://facebook.com/username',
                                            keyboardType: TextInputType.url,
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'LinkedIn URL',
                                            controller: linkedinUrlController,
                                            hintText: 'https://linkedin.com/in/username',
                                            keyboardType: TextInputType.url,
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Twitter/X URL',
                                            controller: twitterUrlController,
                                            hintText: 'https://x.com/username',
                                            keyboardType: TextInputType.url,
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                          const SizedBox(height: 20),
                                          _input(
                                            label: 'Instagram URL',
                                            controller: instagramUrlController,
                                            hintText: 'https://instagram.com/username',
                                            keyboardType: TextInputType.url,
                                            textInputAction:
                                                TextInputAction.done,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: AppButton(
                                onPressed: _saving
                                    ? () {}
                                    : () => _saveProfile(),
                                buttonText: _saving
                                    ? 'Saving...'
                                    : 'Save Changes',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeaderCard(BuildContext context) {
    final title = fullnameController.text.trim().isEmpty
        ? 'Your profile'
        : fullnameController.text.trim();
    final subtitle = emailController.text.trim().isEmpty
        ? 'Update your details'
        : emailController.text.trim();

    final imgUrl = _profilePictureUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: CustColors.mainCol.withOpacity(0.12),
                  backgroundImage: (imgUrl != null)
                      ? NetworkImage(imgUrl)
                      : null,
                  child: (imgUrl == null)
                      ? const Icon(
                          Icons.person,
                          color: CustColors.mainCol,
                          size: 44,
                        )
                      : null,
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Material(
                    color: CustColors.mainCol,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: _uploadingPhoto
                            ? const AutobusLoadingIndicator(size: 18)
                            : const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.black.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
            child: Text(
              _uploadingPhoto ? 'Uploading...' : 'Change profile photo',
              style: GoogleFonts.montserrat(
                color: CustColors.mainCol,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: CustColors.mainCol.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: CustColors.mainCol,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _genderDropdown() {
    final items = const [
      DropdownMenuItem(value: 'Male', child: Text('Male')),
      DropdownMenuItem(value: 'Female', child: Text('Female')),
      DropdownMenuItem(value: 'Other', child: Text('Other')),
      DropdownMenuItem(
        value: 'Prefer not to say',
        child: Text('Prefer not to say'),
      ),
    ];

    final selected = items.any((item) => item.value == _gender) ? _gender : null;

    return DropdownButtonFormField<String>(
      value: selected,
      items: items,
      onChanged: (v) => setState(() => _gender = v),
      decoration: _underlineDecoration(label: 'Gender'),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool readOnly = false,
    String? helperText,
    String? hintText,
    IconData? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      readOnly: readOnly,
      onTap: onTap,
      onTapOutside: dismissAppKeyboard,
      validator: validator,
      decoration: _underlineDecoration(
        label: label,
        helperText: helperText,
        hintText: hintText,
        suffixIcon: suffixIcon,
        readOnly: readOnly,
      ),
    );
  }

  InputDecoration _underlineDecoration({
    required String label,
    String? helperText,
    String? hintText,
    IconData? suffixIcon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      hintText: hintText,
      hintStyle: GoogleFonts.montserrat(
        color: Colors.black.withOpacity(0.35),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: const UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black.withOpacity(0.25)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: CustColors.mainCol, width: 1.6),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
      ),
      suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
    );
  }

  Widget _circleIcon(dynamic icon) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.85),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: icon is IconData
          ? Icon(icon, color: Colors.black87, size: 18)
          : Iconify(icon, color: Colors.black87, size: 8),
    );
  }
}

class _ProfileBackground extends StatelessWidget {
  final Widget child;
  const _ProfileBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 244, 244, 244),
            Color.fromARGB(255, 240, 240, 240),
            Color.fromARGB(255, 236, 236, 236),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
