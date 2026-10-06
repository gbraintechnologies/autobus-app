import 'package:autobus/barrel.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final String? avatarUrl;
  final String? initials;
  final VoidCallback? onTap;

  /// When true (e.g. white or light screen background), initials use [CustColors.mainCol].
  /// Otherwise initials are white.
  final bool onLightBackground;

  /// Dark ring around the photo. Off for the home header avatar.
  final bool showBorder;

  const UserAvatar({
    this.size = 48,
    this.avatarUrl,
    this.initials,
    this.onTap,
    this.onLightBackground = false,
    this.showBorder = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String? url = avatarUrl;
        String chars = initials ?? 'U';

        if (url == null) {
          if (state is Authenticated) {
            final u = state.user;
            chars = (u['fullname'] ?? u['email'] ?? 'User')
                .toString()
                .trim()
                .split(' ')
                .first
                .substring(0, 1)
                .toUpperCase();
            url = (u['profile_picture_url'] ??
                    u['avatar'] ??
                    u['avatar_url'] ??
                    u['photo'] ??
                    u['photo_url'])
                ?.toString();
            if (url != null && url.trim().isEmpty) url = null;
          }
        }

        final fontSize = (size * 0.35).clamp(12, 20).toDouble();
        final initialsColor =
            onLightBackground ? CustColors.mainCol : Colors.white;
        final textStyle = GoogleFonts.poppins(
          color: initialsColor,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        );

        final ring = showBorder ? 1.0 : 0.0;
        final content = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(color: CustColors.mainCol, width: ring)
                : null,
          ),
          alignment: Alignment.center,
          child: url != null
              ? CircleAvatar(
                  radius: (size / 2) - ring,
                  backgroundColor: Colors.transparent,
                  backgroundImage: NetworkImage(url),
                )
              : ClipOval(
                  child: Image.asset(
                    'assets/img/avatar_3d.jpg',
                    width: size - (ring * 2),
                    height: size - (ring * 2),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(chars, style: textStyle),
                    ),
                  ),
                ),
        );

        return GestureDetector(
          onTap:
              onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
          child: content,
        );
      },
    );
  }
}
