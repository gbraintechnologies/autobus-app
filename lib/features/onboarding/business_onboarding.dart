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
  });

  final String id;
  final String prompt;
  final String hint;
  final String placeholder;
  final bool multiline;
  final bool required;

  factory _OnboardingQuestion.fromJson(Map<String, dynamic> json) {
    return _OnboardingQuestion(
      id: (json['id'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      hint: (json['hint'] ?? '').toString(),
      placeholder: (json['placeholder'] ?? '').toString(),
      multiline: json['multiline'] != false,
      required: json['required'] != false,
    );
  }
}

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
    hint: 'Helps the chatbot use the right language for your market.',
    placeholder: 'e.g. Food and bakery, retail fashion, logistics',
    multiline: false,
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
        _controllers.putIfAbsent(id, TextEditingController.new).text = value;
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

  void _goNext() {
    if (_current.required && _currentText.length < 2) {
      showAppSnackBar(context, 'Please answer this question to continue.');
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
      final text = _controllers[q.id]?.text.trim() ?? '';
      if (text.isEmpty) {
        if (q.required) {
          showAppSnackBar(context, 'Please answer: ${q.prompt}');
          setState(() => _step = _questions.indexOf(q).clamp(0, _questions.length - 1));
          return;
        }
        continue;
      }
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
        builder: (context) => SelectPlan(userEmail: widget.userEmail),
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
                style: GoogleFonts.montserrat(
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
                style: GoogleFonts.montserrat(
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
                        style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            AppButton(onPressed: _load, buttonText: 'Try again'),
          ],
        ),
      );
    }

    final q = _current;
    final controller = _controllers[q.id]!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.prompt,
            style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w300,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
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
              hintStyle: GoogleFonts.montserrat(
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
            style: GoogleFonts.montserrat(
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
                style: GoogleFonts.montserrat(
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
