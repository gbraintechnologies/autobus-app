import 'package:autobus/barrel.dart';

/// Treat missing flag as completed so existing accounts are not forced back.
bool isOnboardingCompleted(Map<String, dynamic>? user) {
  if (user == null) return true;
  final v = user['onboarding_completed'];
  if (v == null) return true;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  if (s.isEmpty) return true;
  return s == 'true' || s == '1' || s == 'yes';
}

class _OnboardingQuestion {
  const _OnboardingQuestion({
    required this.id,
    required this.prompt,
    this.hint = '',
    this.placeholder = '',
    this.multiline = true,
    this.required = true,
    this.options = const [],
  });

  final String id;
  final String prompt;
  final String hint;
  final String placeholder;
  final bool multiline;
  final bool required;
  final List<String> options;

  bool get isSelect => options.isNotEmpty;

  factory _OnboardingQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return _OnboardingQuestion(
      id: (json['id'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      hint: (json['hint'] ?? '').toString(),
      placeholder: (json['placeholder'] ?? '').toString(),
      multiline: json['multiline'] != false,
      required: json['required'] != false,
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }
}

const _industryOptions = <String>[
  'Agriculture & Farming',
  'Automotive',
  'Beauty & Personal Care',
  'Construction & Trades',
  'Education & Training',
  'Energy & Utilities',
  'Fashion & Apparel',
  'Finance & Insurance',
  'Food & Beverage',
  'Government & Public Sector',
  'Healthcare & Wellness',
  'Hospitality & Tourism',
  'Logistics & Transportation',
  'Manufacturing',
  'Media & Entertainment',
  'Nonprofit & Community',
  'Professional Services',
  'Real Estate & Property',
  'Retail & E-commerce',
  'Technology & Software',
  'Other',
];

const _fallbackQuestions = <_OnboardingQuestion>[
  _OnboardingQuestion(
    id: 'business_name',
    prompt: 'What is your business name?',
    hint: 'The name customers should hear from your chatbot.',
    placeholder: 'e.g. Sunrise Bakery',
    multiline: false,
  ),
  _OnboardingQuestion(
    id: 'business_description',
    prompt: 'Describe your business in one sentence.',
    hint: 'A short pitch the chatbot can use when someone asks what you do.',
    placeholder: 'e.g. We bake fresh sourdough and pastries for families in Accra.',
  ),
  _OnboardingQuestion(
    id: 'target_customers',
    prompt: 'Who are your target customers?',
    hint: 'Who should the chatbot speak to — and who is a good fit?',
    placeholder: 'e.g. Busy professionals and households in Greater Accra.',
  ),
  _OnboardingQuestion(
    id: 'products_services',
    prompt: 'What products or services do you offer?',
    hint: 'List the main things you sell or deliver.',
    placeholder: 'e.g. Sourdough loaves, croissants, custom cakes, catering.',
  ),
  _OnboardingQuestion(
    id: 'industry',
    prompt: 'What industry or category are you in?',
    hint: 'Pick the closest match so we can analyze businesses by sector and use the right language for your market.',
    placeholder: 'Select an industry',
    multiline: false,
    options: _industryOptions,
  ),
  _OnboardingQuestion(
    id: 'service_area',
    prompt: 'Where do you operate?',
    hint: 'City, neighborhood, delivery radius, or online only.',
    placeholder: 'e.g. Accra and Tema, plus nationwide delivery',
    multiline: false,
  ),
  _OnboardingQuestion(
    id: 'differentiator',
    prompt: 'What makes your business unique?',
    hint: 'Why should a customer choose you over alternatives?',
    placeholder: 'e.g. Same-day delivery and naturally fermented bread.',
  ),
  _OnboardingQuestion(
    id: 'chatbot_greeting',
    prompt: 'How should your chatbot greet customers?',
    hint: 'Optional. Leave blank to use a friendly default.',
    placeholder: 'e.g. Hi! Welcome to Sunrise Bakery — how can we help today?',
    required: false,
  ),
];

/// Interactive post-signup questionnaire. Answers are indexed into Intelligence.
class BusinessOnboarding extends StatefulWidget {
  const BusinessOnboarding({
    super.key,
    this.nextScreen = 'subscribe',
    this.editMode = false,
    this.userEmail = '',
    this.onCompleted,
  });

  /// After save: `subscribe`, `welcome`, or pop when [editMode] is true.
  final String nextScreen;
  final bool editMode;
  final String userEmail;

  /// When set (e.g. SubscriptionGuard), refresh the parent instead of navigating.
  final VoidCallback? onCompleted;

  @override
  State<BusinessOnboarding> createState() => _BusinessOnboardingState();
}

class _BusinessOnboardingState extends State<BusinessOnboarding> {
  List<_OnboardingQuestion> _questions = List.of(_fallbackQuestions);
  final Map<String, TextEditingController> _controllers = {};
  int _step = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    for (final q in _questions) {
      _controllers[q.id] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _answersFromProfile(dynamic profile) {
    if (profile is! Map) return {};
    final map = Map<String, dynamic>.from(profile);
    final raw = map['answers'] is Map ? Map<String, dynamic>.from(map['answers'] as Map) : map;
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key == 'answers' ||
          key == 'completed_at' ||
          key == 'updated_at' ||
          key == 'version') {
        return;
      }
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) out[key.toString()] = text;
    });
    return out;
  }

  void _ensureControllers(List<_OnboardingQuestion> questions) {
    for (final q in questions) {
      _controllers.putIfAbsent(q.id, TextEditingController.new);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getBusinessOnboarding();
      final rawQuestions = data['questions'];
      var questions = _fallbackQuestions;
      if (rawQuestions is List && rawQuestions.isNotEmpty) {
        questions = rawQuestions
            .whereType<Map>()
            .map((q) => _OnboardingQuestion.fromJson(Map<String, dynamic>.from(q)))
            .where((q) => q.id.isNotEmpty && q.prompt.isNotEmpty)
            .toList();
        if (questions.isEmpty) questions = _fallbackQuestions;
      }
      _ensureControllers(questions);

      final saved = _answersFromProfile(data['profile']);
      if (saved.isEmpty) {
        try {
          final me = await api.getUserProfile();
          final company = (me['company'] ?? '').toString().trim();
          if (company.isNotEmpty &&
              (_controllers['business_name']?.text.trim().isEmpty ?? true)) {
            saved['business_name'] = company;
          }
        } catch (_) {}
      }
      saved.forEach((id, value) {
        _OnboardingQuestion? question;
        for (final q in questions) {
          if (q.id == id) {
            question = q;
            break;
          }
        }
        final text = _canonicalAnswer(question, value);
        _controllers.putIfAbsent(id, TextEditingController.new).text = text;
      });

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = userFacingError(e, action: 'loading your questionnaire');
      });
    }
  }

  _OnboardingQuestion get _current => _questions[_step];

  bool get _isLast => _step >= _questions.length - 1;

  String get _currentText => _controllers[_current.id]?.text.trim() ?? '';

  void _goBack() {
    if (_step == 0) {
      if (widget.editMode) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    setState(() => _step -= 1);
  }

  String _canonicalAnswer(_OnboardingQuestion? question, String value) {
    if (question == null || !question.isSelect) return value;
    final lowered = value.toLowerCase();
    for (final option in question.options) {
      if (option.toLowerCase() == lowered) return option;
    }
    return '';
  }

  bool _isValidAnswer(_OnboardingQuestion question, String text) {
    if (text.isEmpty) return !question.required;
    if (question.isSelect) return question.options.any((o) => o.toLowerCase() == text.toLowerCase());
    return text.length >= 2;
  }

  Future<void> _openOptionPicker(
    _OnboardingQuestion question,
    TextEditingController controller,
  ) async {
    final current = _canonicalAnswer(question, controller.text);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  question.placeholder.isEmpty ? 'Choose a category' : question.placeholder,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick the closest match for your business.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: question.options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = question.options[index];
                      final isSelected = option == current;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? CustColors.mainCol : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: CustColors.mainCol, size: 20)
                            : null,
                        onTap: () => Navigator.pop(ctx, option),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => controller.text = picked);
  }

  void _goNext() {
    if (!_isValidAnswer(_current, _currentText)) {
      showAppSnackBar(
        context,
        _current.isSelect
            ? 'Please select an option to continue.'
            : 'Please answer this question to continue.',
      );
      return;
    }
    if (_isLast) {
      _submit();
      return;
    }
    setState(() => _step += 1);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final answers = <String, String>{};
    for (final q in _questions) {
      final text = _canonicalAnswer(q, _controllers[q.id]?.text.trim() ?? '');
      if (!_isValidAnswer(q, text)) {
        showAppSnackBar(
          context,
          q.isSelect ? 'Please select an option for: ${q.prompt}' : 'Please answer: ${q.prompt}',
        );
        setState(() => _step = _questions.indexOf(q).clamp(0, _questions.length - 1));
        return;
      }
      if (text.isEmpty) continue;
      answers[q.id] = text;
    }

    setState(() => _submitting = true);
    try {
      await context.read<ApiService>().submitBusinessOnboarding(answers);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Your chatbot now knows your business.',
        backgroundColor: CustColors.mainCol,
      );
      _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(
        context,
        userFacingError(e, action: 'saving your business profile'),
      );
    }
  }

  void _finish() {
    if (widget.editMode) {
      Navigator.of(context).pop(true);
      return;
    }
    if (widget.onCompleted != null) {
      widget.onCompleted!();
      return;
    }
    final next = widget.nextScreen;
    if (next == 'welcome') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Welcome()),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const Welcome(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.isEmpty ? 1 : _questions.length;
    final progress = _loading ? 0.0 : (_step + 1) / total;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthPageHeader(
                title: widget.editMode ? 'Update profile' : 'Your business',
                fontWeight: FontWeight.w300,
                onBack: _goBack,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _loading ? null : progress,
                  minHeight: 6,
                  backgroundColor: Colors.black12,
                  color: CustColors.mainCol,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loading
                    ? 'Preparing your questions…'
                    : 'Question ${_step + 1} of $total',
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.editMode
                    ? 'Updating these answers replaces only your business-profile knowledge. Uploaded files and websites stay indexed.'
                    : 'Answer a few questions so your chatbot can talk about your business — even before you upload documents or a website.',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildBody()),
              if (!_loading && _loadError == null) ...[
                const SizedBox(height: 12),
                Center(
                  child: AppButton(
                    onPressed: _submitting ? null : _goNext,
                    buttonText: _submitting
                        ? 'Saving…'
                        : (_isLast ? 'Finish & train chatbot' : 'Continue'),
                  ),
                ),
                if (!_isLast)
                  Center(
                    child: TextButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(
                        'Save and finish',
                        style: GoogleFonts.poppins(
                          color: CustColors.mainCol,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: AutobusLoadingIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            AppButton(onPressed: _load, buttonText: 'Try again'),
          ],
        ),
      );
    }

    final q = _current;
    final controller = _controllers[q.id]!;
    final selected = _canonicalAnswer(q, controller.text);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.prompt,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          if (q.hint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              q.hint,
              style: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w300,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (q.isSelect)
            _IndustrySelectField(
              placeholder: q.placeholder.isEmpty ? 'Select an option' : q.placeholder,
              value: selected,
              onTap: () => _openOptionPicker(q, controller),
            )
          else
            TextField(
              controller: controller,
              onTapOutside: dismissAppKeyboard,
              autofocus: true,
              maxLines: q.multiline ? 5 : 1,
              minLines: q.multiline ? 3 : 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: q.multiline ? TextInputAction.newline : TextInputAction.done,
              onSubmitted: (_) => _goNext(),
              decoration: InputDecoration(
                hintText: q.placeholder,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black38,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black26),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: CustColors.mainCol, width: 1.6),
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          if (!q.required)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Optional',
                style: GoogleFonts.poppins(
                  color: Colors.black38,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IndustrySelectField extends StatelessWidget {
  const _IndustrySelectField({
    required this.placeholder,
    required this.value,
    required this.onTap,
  });

  final String placeholder;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F4F8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasValue
                  ? CustColors.mainCol.withValues(alpha: 0.35)
                  : const Color(0x1A000000),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value : placeholder,
                  style: GoogleFonts.poppins(
                    color: hasValue ? Colors.black87 : Colors.black38,
                    fontSize: 15,
                    fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasValue ? CustColors.mainCol : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
