import 'package:flutter/material.dart';

/// Hide the software keyboard. Pass to [TextField.onTapOutside] / [TextFormField.onTapOutside].
void dismissAppKeyboard([PointerDownEvent? _]) {
  FocusManager.instance.primaryFocus?.unfocus();
}
