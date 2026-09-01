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
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  String get pin => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    widget.onChanged?.call('');
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _notify() {
    final value = pin;
    widget.onChanged?.call(value);
    if (value.length == 4) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 16);
    final children = <Widget>[];
    for (var index = 0; index < 4; index++) {
      if (index > 0) children.add(gap);
      children.add(
        SizedBox(
          width: 52,
          child: TextField(
            onTapOutside: dismissAppKeyboard,
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            enabled: widget.enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              counterText: '',
            ),
            onChanged: (val) {
              if (val.isNotEmpty) {
                if (index < 3) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  _focusNodes[index].unfocus();
                }
              } else if (index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
              _notify();
            },
            onTap: () {
              _controllers[index].selection = TextSelection.collapsed(
                offset: _controllers[index].text.length,
              );
            },
            onSubmitted: (_) {
              if (index < 3) _focusNodes[index + 1].requestFocus();
            },
            onEditingComplete: () {},
          ),
        ),
      );
    }
    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
