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
  void _keepCursorAtEnd() {
    final end = _controller.text.length;
    final sel = _controller.selection;
    if (!sel.isValid) return;
    if (sel.baseOffset == end && sel.extentOffset == end) return;
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
          children: [
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: boxes,
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                cursorColor: Colors.transparent,
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
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
          ],
        ),
      ),
    );
  }
}
