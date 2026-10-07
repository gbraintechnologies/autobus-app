import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared chat look from the Figma INTELLIGENCE "My AI" frame (3399:4841):
/// person typing = white bubble, AI / business side = purple gradient,
/// no avatars, and the plus-circle / mic / paper-plane composer.
class AppChatStyle {
  AppChatStyle._();

  static const text = Color(0xFF475569);
  static const muted = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);
  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
  );

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / appShellDesignWidth;
}

/// SF Symbol glyph centred in a [size] square (raw glyphs sit high-left in
/// their text box).
class AppChatGlyph extends StatelessWidget {
  const AppChatGlyph(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
    this.fontWeight = FontWeight.w400,
  });

  final IconData icon;
  final double size;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: SFIcon(
          icon,
          fontSize: size * 0.82,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}

/// One chat message. [fromUser] picks the white bubble; otherwise the AI
/// gradient. [alignRight] defaults to [fromUser].
class AppChatBubble extends StatelessWidget {
  const AppChatBubble({
    super.key,
    required this.fromUser,
    this.text,
    this.child,
    this.label,
    this.footer,
    this.failed = false,
    this.alignRight,
    this.onTap,
  });

  final bool fromUser;
  final String? text;
  final Widget? child;
  final String? label;
  final String? footer;
  final bool failed;
  final bool? alignRight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = AppChatStyle.scaleOf(context);
    final right = alignRight ?? fromUser;
    final fg = fromUser ? AppChatStyle.text : Colors.white;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: 300 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: fromUser ? Colors.white : null,
        gradient: fromUser ? null : AppChatStyle.gradient,
        borderRadius: BorderRadius.circular(16 * scale),
        border: failed ? Border.all(color: Colors.redAccent) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: EdgeInsets.only(bottom: 2 * scale),
              child: Text(
                label!,
                style: GoogleFonts.poppins(
                  color: fg.withValues(alpha: 0.75),
                  fontSize: LightScreenTheme.typeMicro,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (child != null) child!,
          if (child != null && (text ?? '').trim().isNotEmpty)
            SizedBox(height: 8 * scale),
          if ((text ?? '').trim().isNotEmpty)
            Text(
              text!,
              style: GoogleFonts.poppins(
                color: fg,
                fontSize: LightScreenTheme.typeBody,
                height: 1.45,
              ),
            ),
        ],
      ),
    );

    return Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            bubble,
            if (footer != null) ...[
              SizedBox(height: 4 * scale),
              Text(
                footer!,
                style: GoogleFonts.poppins(
                  color: failed ? Colors.redAccent : AppChatStyle.muted,
                  fontSize: LightScreenTheme.typeCaption,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Figma chat input: divider, plus-circle, text field, mic, gradient send.
/// Pass null for [onAttach] / [onMic] to hide those buttons.
class AppChatComposer extends StatelessWidget {
  const AppChatComposer({
    super.key,
    required this.controller,
    required this.canSend,
    required this.onSend,
    this.focusNode,
    this.onAttach,
    this.onMic,
    this.listening = false,
    this.busy = false,
    this.hintText = 'Type your message...',
    this.header,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onMic;
  final bool listening;
  final bool busy;
  final String hintText;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final scale = AppChatStyle.scaleOf(context);
    final glyph = 24 * scale.clamp(0.9, 1.05);

    Widget tapGlyph(IconData icon, VoidCallback? onTap, Color color) {
      return InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: EdgeInsets.all(2 * scale),
          child: AppChatGlyph(icon, size: glyph, color: color),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: 12 * scale),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(
              height: 1,
              thickness: 0.5,
              color: AppChatStyle.divider,
            ),
            SizedBox(height: 12 * scale),
            if (header != null) header!,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Row(
                children: [
                  if (onAttach != null) ...[
                    busy
                        ? SizedBox.square(
                            dimension: glyph + 4 * scale,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppChatStyle.muted,
                              ),
                            ),
                          )
                        : tapGlyph(
                            SFIcons.sf_plus_circle,
                            onAttach,
                            AppChatStyle.muted,
                          ),
                    SizedBox(width: 16 * scale),
                  ],
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      cursorColor: LightScreenTheme.accent,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style: GoogleFonts.poppins(
                        color: AppChatStyle.text,
                        fontSize: LightScreenTheme.typeBody,
                      ),
                      decoration: InputDecoration(
                        hintText: listening ? 'Listening…' : hintText,
                        hintStyle: GoogleFonts.poppins(
                          color: AppChatStyle.muted,
                          fontSize: LightScreenTheme.typeBody,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10 * scale,
                        ),
                      ),
                    ),
                  ),
                  if (onMic != null) ...[
                    SizedBox(width: 12 * scale),
                    tapGlyph(
                      SFIcons.sf_microphone,
                      busy ? null : onMic,
                      listening ? LightScreenTheme.accent : AppChatStyle.muted,
                    ),
                  ],
                  SizedBox(width: 16 * scale),
                  InkResponse(
                    onTap: canSend ? onSend : null,
                    radius: 24,
                    child: Opacity(
                      opacity: canSend ? 1 : 0.45,
                      child: Container(
                        width: 40 * scale,
                        height: 40 * scale,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppChatStyle.gradient,
                        ),
                        child: AppChatGlyph(
                          SFIcons.sf_paperplane_fill,
                          size: 20 * scale.clamp(0.9, 1.05),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
