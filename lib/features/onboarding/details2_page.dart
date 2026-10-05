import 'package:autobus/barrel.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/services.dart';

enum _SetupInputType { text, industrySelection, phone, url }

class _SetupQuestion {
  final String question;
  final String hint;
  final String? inputHint;
  final String emptyMessage;
  final bool multiline;
  final bool optional;
  final _SetupInputType inputType;
  final List<String>? options;

  const _SetupQuestion({
    required this.question,
    required this.hint,
    this.inputHint,
    required this.emptyMessage,
    this.multiline = false,
    this.optional = false,
    this.inputType = _SetupInputType.text,
    this.options,
  });
}

/// Post-signup business setup — Figma DETAILS2–DETAILS8 (Q1–Q8).
class Details2Page extends StatefulWidget {
  final String userEmail;
  final String initialBusinessName;

  const Details2Page({
    super.key,
    this.userEmail = '',
    this.initialBusinessName = '',
  });

  @override
  State<Details2Page> createState() => _Details2PageState();
}

class _Details2PageState extends State<Details2Page> {
  static const _designWidth = 402.0;
  static const _totalQuestions = 8;
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _buttonColor = Color(0xFF2D0C51);
  static const _accentColor = Color(0xFF7F03B9);
  static const _mutedColor = Color(0xFF898989);
  static const _exampleColor = Color(0xFFC7C7C7);
  static const _trackColor = Color(0xFFD9D9D9);
  static const _lineColor = Color(0xFFCBCBCB);
  static const _chipBorderColor = Color(0xFFDFDFDF);

  static const _industryOptions = [
    'E-commerce',
    'Finance',
    'Beauty & Cosmetics',
    'Real Estate & Housing',
    'Bakery',
    'IT & Software',
    'Engineering',
    'Sales & Marketing',
    'Legal',
    'Media',
    'Education',
    'Other',
  ];

  static const _questions = [
    _SetupQuestion(
      question: 'What is your business name?',
      hint: 'The name customer should hear from your chatbot',
      emptyMessage: 'Please enter your business name',
    ),
    _SetupQuestion(
      question: 'Describe your business in one sentence',
      hint: 'A short bio the chatbot can use when someone asks what you do.',
      inputHint:
          'Eg. We sell freshly baked bread and other pasties in Accra.',
      emptyMessage: 'Please describe your business',
      multiline: true,
    ),
    _SetupQuestion(
      question: 'What industry or category are you in?',
      hint:
          'Pick the closest match so we can analyse businesses by sector and use the right language for your market',
      emptyMessage: 'Please select an industry',
      inputType: _SetupInputType.industrySelection,
      options: _industryOptions,
    ),
    _SetupQuestion(
      question: 'Where do you operate or serve customers?',
      hint:
          'City, region, or country your chatbot should mention when customers ask where you are based.',
      inputHint: 'Eg. Accra and surrounding areas',
      emptyMessage: 'Please enter your service area',
    ),
    _SetupQuestion(
      question: 'What is your business address?',
      hint: 'A street address helps local customers find you.',
      inputHint: 'Eg. 14 High Street, Osu, Accra',
      emptyMessage: 'Please enter your business address',
      optional: true,
    ),
    _SetupQuestion(
      question: 'What is your WhatsApp number?',
      hint:
          'Your chatbot can share this when customers want to reach you directly.',
      inputHint: '0244123456',
      emptyMessage: 'Please enter your WhatsApp number',
      inputType: _SetupInputType.phone,
      optional: true,
    ),
    _SetupQuestion(
      question: 'What is your Facebook page URL?',
      hint: 'Optional link your chatbot can share with customers.',
      inputHint: 'https://facebook.com/yourpage',
      emptyMessage: 'Please enter a valid Facebook URL',
      inputType: _SetupInputType.url,
      optional: true,
    ),
    _SetupQuestion(
      question: 'What is your Instagram profile URL?',
      hint: 'Optional link your chatbot can share with customers.',
      inputHint: 'https://instagram.com/yourpage',
      emptyMessage: 'Please enter a valid Instagram URL',
      inputType: _SetupInputType.url,
      optional: true,
    ),
  ];

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessBioController = TextEditingController();
  final TextEditingController _industryOtherController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  late final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  int _currentStep = 0;
  bool _isSaving = false;
  String? _selectedIndustry;

  TextEditingController get _activeController => switch (_currentStep) {
        0 => _businessNameController,
        1 => _businessBioController,
        2 => _industryOtherController,
        3 => _locationController,
        4 => _addressController,
        5 => _whatsappController,
        6 => _facebookController,
        7 => _instagramController,
        _ => _businessNameController,
      };

  _SetupQuestion get _question => _questions[_currentStep];

  bool get _isIndustryStep =>
      _question.inputType == _SetupInputType.industrySelection;

  @override
  void initState() {
    super.initState();
    if (widget.initialBusinessName.isNotEmpty) {
      _businessNameController.text = widget.initialBusinessName;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessBioController.dispose();
    _industryOtherController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  String? _industryValue() {
    if (_selectedIndustry == null) return null;
    if (_selectedIndustry == 'Other') {
      final other = _industryOtherController.text.trim();
      return other.isEmpty ? null : other;
    }
    return _selectedIndustry;
  }

  Future<void> _saveCurrentStep() async {
    switch (_currentStep) {
      case 0:
        final name = _businessNameController.text.trim();
        if (name.isNotEmpty) {
          await _apiService.updateUserProfile(company: name);
        }
      case 1:
        final bio = _businessBioController.text.trim();
        if (bio.isNotEmpty) {
          await _apiService.updateUserProfile(description: bio);
        }
      case 2:
        final industry = _industryValue();
        if (industry != null) {
          await _apiService.updateUserProfile(industry: industry);
        }
      case 3:
        final location = _locationController.text.trim();
        if (location.isNotEmpty) {
          await _apiService.updateUserProfile(location: location);
        }
      case 4:
        final address = _addressController.text.trim();
        if (address.isNotEmpty) {
          await _apiService.updateUserProfile(address: address);
        }
      case 5:
        final whatsapp = _whatsappController.text.trim();
        if (whatsapp.isNotEmpty) {
          await _apiService.updateUserProfile(whatsappNumber: whatsapp);
        }
      case 6:
        final facebook = _facebookController.text.trim();
        if (facebook.isNotEmpty) {
          await _apiService.updateUserProfile(facebookUrl: facebook);
        }
      case 7:
        final instagram = _instagramController.text.trim();
        if (instagram.isNotEmpty) {
          await _apiService.updateUserProfile(instagramUrl: instagram);
        }
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isSaving = true);
    try {
      await _saveCurrentStep();
    } catch (_) {
      // Continue to subscription even if profile update fails.
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        duration: const Duration(milliseconds: 800),
        reverseDuration: const Duration(milliseconds: 500),
        child: SelectPlan(userEmail: widget.userEmail),
      ),
    );
  }

  bool _validateCurrentStep() {
    if (_isIndustryStep) {
      if (_selectedIndustry == null) return false;
      if (_selectedIndustry == 'Other' &&
          _industryOtherController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please specify your industry',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        );
        return false;
      }
      return true;
    }

    final value = _activeController.text.trim();
    if (value.isEmpty) {
      if (_question.optional) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _question.emptyMessage,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  TextInputType get _keyboardType => switch (_question.inputType) {
        _SetupInputType.phone => TextInputType.phone,
        _SetupInputType.url => TextInputType.url,
        _ => TextInputType.text,
      };

  List<TextInputFormatter>? get _inputFormatters =>
      _question.inputType == _SetupInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null;

  bool get _isLastStep => _currentStep >= _questions.length - 1;

  Future<void> _onNext() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSaving = true);
    try {
      await _saveCurrentStep();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (_currentStep < _questions.length - 1) {
      setState(() => _currentStep++);
      return;
    }

    await _finishSetup();
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Widget _buildIndustryChip(String label, double scale) {
    final isSelected = _selectedIndustry == label;
    final borderColor = isSelected ? _accentColor : _chipBorderColor;
    final textColor = isSelected ? _accentColor : _mutedColor;

    return InkWell(
      onTap: _isSaving
          ? null
          : () => setState(() {
                _selectedIndustry = label;
                if (label != 'Other') {
                  _industryOtherController.clear();
                }
              }),
      borderRadius: BorderRadius.circular(30 * scale),
      child: Container(
        height: 37 * scale,
        padding: EdgeInsets.symmetric(horizontal: 14 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(30 * scale),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStepInput(double scale) {
    if (_isIndustryStep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: _industryOptions
                .map((option) => _buildIndustryChip(option, scale))
                .toList(),
          ),
          SizedBox(height: 35 * scale),
          Text(
            'If Other, please specify',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _exampleColor,
            ),
          ),
          SizedBox(height: 8 * scale),
          TextField(
            controller: _industryOtherController,
            enabled: _selectedIndustry == 'Other' && !_isSaving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onNext(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.only(bottom: 8 * scale),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: _lineColor, width: 1),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _lineColor, width: 1),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _accentColor, width: 1),
              ),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _lineColor, width: 1),
              ),
            ),
          ),
        ],
      );
    }

    return TextField(
      controller: _activeController,
      maxLines: _question.multiline ? 3 : 1,
      keyboardType: _keyboardType,
      inputFormatters: _inputFormatters,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _onNext(),
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: _question.inputHint,
        hintStyle: GoogleFonts.poppins(
              fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: _exampleColor,
        ),
        contentPadding: EdgeInsets.only(bottom: 8 * scale),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: _lineColor, width: 1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _lineColor, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _accentColor, width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final buttonWidth = 333 * scale;
    final buttonHeight = 64 * scale;
    final currentQuestion = _currentStep + 1;
    final progress = currentQuestion / _totalQuestions;
    final contentTopGap = _currentStep == 0 ? 112 * scale : 76 * scale;
    final inputTopGap = _isIndustryStep
        ? 18 * scale
        : (_currentStep == 0 ? 58 * scale : 35 * scale);

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 36 * scale),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: SizedBox(
                    height: 32 * scale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_currentStep > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: _isSaving ? null : _onBack,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 32 * scale,
                                minHeight: 32 * scale,
                              ),
                              icon: Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                                size: 22 * scale,
                              ),
                            ),
                          ),
                        Text(
                          'Your Business',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 48 * scale),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10 * scale),
                    child: SizedBox(
                      height: 4 * scale,
                      child: Stack(
                        children: [
                          Container(color: _trackColor),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(color: _accentColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 17 * scale),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: Text(
                    'Question $currentQuestion of $_totalQuestions',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _mutedColor,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24 * scale,
                      contentTopGap,
                      24 * scale,
                      16 * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FigmaSvgIcon(
                          FigmaIcons.ai,
                          size: 70 * scale,
                          color: const Color(0xFF7F03B9),
                        ),
                        SizedBox(height: 10 * scale),
                        Text(
                          _question.question,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 7 * scale),
                        Text(
                          _question.optional
                              ? '${_question.hint} (Optional)'
                              : _question.hint,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: _mutedColor,
                          ),
                        ),
                        SizedBox(height: inputTopGap),
                        _buildStepInput(scale),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Material(
                    color: _buttonColor,
                    borderRadius: BorderRadius.circular(30 * scale),
                    child: InkWell(
                      onTap: _isSaving ? null : _onNext,
                      borderRadius: BorderRadius.circular(30 * scale),
                      child: SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: _isSaving
                            ? Center(
                                child: SizedBox(
                                  width: 22 * scale,
                                  height: 22 * scale,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isLastStep ? 'Finish' : 'Next',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (!_isLastStep) ...[
                                    SizedBox(width: 10 * scale),
                                    Transform.rotate(
                                      angle: -1.5708,
                                      child: Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white,
                                        size: 20 * scale,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  SizedBox(height: 16 * scale),
                  Center(
                    child: TextButton(
                      onPressed: _isSaving ? null : _finishSetup,
                      child: Text(
                        'Save and Finish',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _buttonColor,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 32 * scale),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
