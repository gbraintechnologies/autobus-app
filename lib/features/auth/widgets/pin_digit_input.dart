import 'package:autobus/barrel.dart';
import 'package:flutter/services.dart';

/// Four-box numeric PIN field used for login, signup, and app lock.
class PinDigitInput extends StatefulWidget {
  const PinDigitInput({
    super.key,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onCompleted,
  });

  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<PinDigitInput> createState() => PinDigitInputState();
}

class PinDigitInputState extends State<PinDigitInput> {
  static const _length = 4;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String get pin => _controller.text;

  void clear() {
    _controller.clear();
    widget.onChanged?.call('');
    if (widget.enabled) {
      _focusNode.requestFocus();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_keepCursorAtEnd);
    _focusNode.addListener(_onFocusChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_keepCursorAtEnd);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// Keep the caret after the last digit so backspace always deletes
  /// from the end, even if the user tapped a box in the middle.
  ///
  /// iOS `deleteBackward` first selects the last character, then deletes
  /// that range. Collapsing that selection immediately makes further
  /// backspaces no-ops (only the first digit is removed).
  void _keepCursorAtEnd() {
    final end = _controller.text.length;
    final sel = _controller.selection;
    if (!sel.isValid) return;
    if (sel.isCollapsed && sel.baseOffset == end) return;

    // Let the IME select the last digit so backspace can delete it.
    if (end > 0 && !sel.isCollapsed && sel.start == end - 1 && sel.end == end) {
      return;
    }

    // Paste / autofill may select the whole value before replacing it.
    if (!sel.isCollapsed && sel.start == 0 && sel.end == end) {
      return;
    }

    _controller.selection = TextSelection.collapsed(offset: end);
  }

  void _onChanged(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == _length) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = pin;
    final activeIndex = value.length == _length ? _length - 1 : value.length;

    final boxes = <Widget>[];
    for (var i = 0; i < _length; i++) {
      final filled = i < value.length;
      final isActive = widget.enabled && _focusNode.hasFocus && i == activeIndex;
      boxes.add(
        SizedBox(
          width: 52,
          child: InputDecorator(
            isEmpty: !filled,
            isFocused: isActive,
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              enabled: widget.enabled,
              counterText: '',
            ),
            child: Text(
              filled ? '•' : ' ',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: 52 * _length + 16 * (_length - 1),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: boxes,
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  // Do not use obscureText: iOS secureTextEntry makes repeated
                  // backspaces fail. Digits are already hidden by the overlay.
                  obscureText: false,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  autofillHints: const <String>[],
                  showCursor: false,
                  cursorColor: Colors.transparent,
                  // Real font metrics are required on iOS; fontSize: 1 leaves
                  // the caret at offset 0 after the first delete, so further
                  // backspaces are ignored.
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      _length,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    ),
                  ],
                  onChanged: _onChanged,
                  onTap: () {
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                  },
                  onTapOutside: dismissAppKeyboard,
                  onEditingComplete: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
