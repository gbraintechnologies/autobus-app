import 'dart:math' as math;

import 'package:autobus/barrel.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/services.dart';

/// First-run onboarding. Full-bleed shop photograph with a swipe-to-start.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  static const _completeAt = 0.84;

  late final AnimationController _intro;
  late final CurvedAnimation _introCurve;
  late final Animation<Offset> _slide;
  late final AnimationController _nudge;
  late final AnimationController _settle;

  double _progress = 0;
  double _settleFrom = 0;
  bool _dragging = false;
  bool _locked = false;
  bool _finished = false;
  bool _crossed = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _introCurve = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_introCurve);
    _intro.forward();
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..addListener(_onSettleTick);
  }

  void _onSettleTick() {
    if (!mounted) return;
    setState(() {
      if (_locked) {
        final t = Curves.easeOutCubic.transform(_settle.value);
        _progress = _settleFrom + (1 - _settleFrom) * t;
      } else {
        final t = Curves.elasticOut.transform(_settle.value);
        _progress = (_settleFrom * (1 - t)).clamp(-0.03, 1.0);
      }
    });
    if (_locked && _settle.isCompleted && !_finished) {
      _finished = true;
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted) widget.onFinished();
      });
    }
  }

  double get _idleNudge {
    if (_dragging || _locked || _progress.abs() > 0.001) return 0;
    final t = _nudge.value;
    if (t < 0.42) {
      return Curves.easeOutCubic.transform(t / 0.42) * 0.07;
    }
    if (t < 0.62) return 0.07;
    return (1 - Curves.easeIn.transform((t - 0.62) / 0.38)) * 0.07;
  }

  double get _shown => _progress + _idleNudge;

  void _onDragStart() {
    if (_locked) return;
    _settle.stop();
    HapticFeedback.selectionClick();
    setState(() => _dragging = true);
  }

  void _onDrag(double delta, double travel) {
    if (_locked || travel <= 0) return;
    setState(() {
      _progress = (_progress + delta / travel).clamp(0.0, 1.0);
      if (!_crossed && _progress >= 0.5) {
        _crossed = true;
        HapticFeedback.lightImpact();
      }
      if (_progress < 0.5) _crossed = false;
    });
    if (_progress >= _completeAt) _lockIn();
  }

  void _onDragEnd() {
    if (_locked) return;
    setState(() => _dragging = false);
    if (_progress >= _completeAt) {
      _lockIn();
      return;
    }
    _settleFrom = _progress;
    _settle.duration = const Duration(milliseconds: 700);
    _settle.forward(from: 0);
  }

  void _lockIn() {
    if (_locked) return;
    HapticFeedback.mediumImpact();
    _settleFrom = _progress;
    _settle.duration = const Duration(milliseconds: 320);
    setState(() {
      _locked = true;
      _dragging = false;
    });
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _introCurve.dispose();
    _intro.dispose();
    _nudge.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = _shown.clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF14061F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(-10 * visual, -16 * visual),
              child: Transform.scale(
                scale: 1.08,
                child: Image.asset(
                  FigmaImages.onboardingBackdrop,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.08),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    FadeTransition(
                      opacity: _introCurve,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Run your whole\nbusiness\nfrom one app',
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                height: 1.08,
                                letterSpacing: -0.6,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chats, orders, marketing, and an AI that knows your business — all in one place.',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _nudge,
                      builder: (context, _) {
                        return _SwipeToStart(
                          progress: _shown,
                          locked: _locked,
                          onDragStart: _onDragStart,
                          onDrag: _onDrag,
                          onDragEnd: _onDragEnd,
                          onActivate: _lockIn,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _introCurve,
                child: const _BrandMark(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 30,
          height: 18,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: CustColors.logolight,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: 11,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: CustColors.logodeep,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Autobus',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SwipeToStart extends StatelessWidget {
  final double progress;
  final bool locked;
  final VoidCallback onDragStart;
  final void Function(double delta, double travel) onDrag;
  final VoidCallback onDragEnd;
  final VoidCallback onActivate;

  const _SwipeToStart({
    required this.progress,
    required this.locked,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.onActivate,
  });

  static const _thumb = 56.0;
  static const _inset = 7.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: Colors.white.withValues(alpha: 0.92),
    );

    return Semantics(
      button: true,
      label: 'Swipe to start',
      onTap: locked ? null : onActivate,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = math.max(
            1.0,
            constraints.maxWidth - _inset * 2 - _thumb,
          );
          final t = progress.clamp(0.0, 1.0);
          final thumbLeft = _inset + progress.clamp(-0.04, 1.0) * travel;
          final squash = math.sin(t * math.pi);

          return GestureDetector(
            onHorizontalDragStart: (_) => onDragStart(),
            onHorizontalDragUpdate: (details) =>
                onDrag(details.delta.dx, travel),
            onHorizontalDragEnd: (_) => onDragEnd(),
            onHorizontalDragCancel: onDragEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 70,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(35),
                            color: Colors.transparent,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (!locked)
                        Positioned.fill(
                          child: _ScatteredLabel(
                            text: 'swipe to start',
                            style: labelStyle,
                            thumbX: thumbLeft + _thumb,
                          ),
                        ),
                      Positioned(
                        left: thumbLeft,
                        top: _inset,
                        child: Transform.scale(
                          alignment: Alignment.center,
                          scaleX: 1 + squash * 0.16,
                          scaleY: 1 - squash * 0.08,
                          child: Container(
                            width: _thumb,
                            height: _thumb,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: 1.4,
                              ),
                            ),
                            child: Icon(
                              locked
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScatteredLabel extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double thumbX;

  const _ScatteredLabel({
    required this.text,
    required this.style,
    required this.thumbX,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final origin = (constraints.maxWidth - painter.width) / 2;
        final top = (constraints.maxHeight - painter.height) / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < text.length; i++)
              if (text[i] != ' ') _letter(painter, i, origin, top),
          ],
        );
      },
    );
  }

  Widget _letter(TextPainter painter, int index, double origin, double top) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: index, extentOffset: index + 1),
    );
    if (boxes.isEmpty) return const SizedBox.shrink();
    final box = boxes.first;
    final center = origin + (box.left + box.right) / 2;
    final pass = ((thumbX - center) / 46).clamp(0.0, 1.0);
    final drift = (index.isEven ? 1.0 : -1.0);

    return Positioned(
      left: origin + box.left + drift * 14 * pass,
      top: top - 28 * pass,
      child: Opacity(
        opacity: (1 - pass * 1.2).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: drift * 0.55 * pass,
          child: Text(text[index], style: style),
        ),
      ),
    );
  }
}
